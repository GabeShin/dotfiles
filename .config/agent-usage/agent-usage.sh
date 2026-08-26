#!/usr/bin/env bash
#
# Records per-account quota state for the sketchybar `agent_usage` item.
#
# Six subscriptions (four Claude config dirs, two Codex homes) are easy to
# unbalance, and an unbalanced week costs money. This collects what each
# account has actually spent so the bar can show it.
#
# Three producers, one state format:
#
#   claude-statusline  Claude Code >= 2.1 hands the live rate limits to the
#                      statusLine command on stdin, so reading them costs
#                      nothing: no token, no network, no login. This mode
#                      doubles as the status line itself, echoing a line to
#                      stdout for the session it was called from.
#   claude-probe       An idle account never runs its status line, and a
#                      maxed-out one cannot even open a session -- so the
#                      account most worth seeing would be the one that never
#                      reports. A one-turn `claude -p --output-format
#                      stream-json` emits a rate_limit_event carrying the same
#                      windows the status line does, on refused requests too,
#                      which makes both cases measurable. Free when refused,
#                      one cheap haiku turn otherwise.
#   codex-poll         Codex pushes nothing, so ask its app-server
#                      (`account/rateLimits/read`) and cache the answer.
#
# State is one file per account under ~/.cache/agent-usage, tab separated:
#
#   kind  label  status  five_pct  week_pct  week_resets_at  updated_at  plan  note
#
# status is one of:
#
#   ok        measured and usable
#   limited   out of quota and refusing work; note says when it comes back
#   auth      signed out, and no number can be fetched until you log in again
#   unknown   reported, but carries no subscription quota (an API-key session)
#
# The bar synthesises a fifth, "pending", for an account with no file at all.
# note is free text from whatever the source said, e.g. when a limit resets.
#
# Unknown numbers are "-", never 0, so the bar can tell an idle account from an
# unmeasured one. Presentation is the bar's job, so the fields stay separate and
# raw -- same split as agent-notify.
#
# Usage: agent-usage.sh <claude-statusline|codex-poll|claude-probe>

set -u

STATE_DIR="${AGENT_USAGE_DIR:-$HOME/.cache/agent-usage}"
MODE="${1:-}"

# sketchybar is launched at login, so it inherits a bare PATH that cannot see
# `codex` -- nvm keeps it in a versioned directory that moves on every node
# upgrade, so glob for it rather than naming a version. Appended, not
# prepended, so an interactive shell's own choices still win.
_dirs=(/opt/homebrew/bin /usr/local/bin "$HOME/.local/bin" "$HOME/bin")
# Newest node first: several versions can be installed at once, and only the
# current one is sure to have a working codex -- an upgraded-away version can
# be left behind with its vendor binary missing, which fails at run time
# rather than at `command -v`.
while IFS= read -r _d; do _dirs+=("$_d"); done < <(
    ls -d "$HOME"/.nvm/versions/node/*/bin 2>/dev/null | sort -Vr
)
for _dir in "${_dirs[@]}"; do
    [ -d "$_dir" ] || continue
    case ":$PATH:" in
        *":$_dir:"*) ;;
        *) PATH="$PATH:$_dir" ;;
    esac
done
unset _dirs _dir _d
export PATH

UNKNOWN='-'
LOCK_DIR=""   # set by codex_poll; the EXIT trap needs it at global scope

# How long a cached Codex sample stays good. The bar asks for a poll every
# tick and this is what makes that cheap: quotas move slowly, and a signed-out
# account will not fix itself, so stop asking it so often.
CODEX_REFRESH_OK="${AGENT_USAGE_CODEX_REFRESH:-300}"
CODEX_REFRESH_AUTH="${AGENT_USAGE_CODEX_REFRESH_AUTH:-1800}"

# How long each Claude probe result stays good. An exhausted account is the one
# case worth re-checking often -- it is the account you cannot open a session
# in, so the probe is the only thing that can tell you when it frees up, and a
# refused request is free (zero tokens, zero cost). A probe that succeeds costs
# a turn, so an account that already has numbers is only re-measured daily.
#
# Note these intervals are measured against the last write from *either*
# collector, and the status line writes on every repaint -- so an account you
# actually work in keeps itself fresh for nothing and is never probed. Only
# genuinely idle accounts ever spend a turn.
CLAUDE_PROBE_PENDING="${AGENT_USAGE_PROBE_PENDING:-900}"    # never measured
CLAUDE_PROBE_LIMITED="${AGENT_USAGE_PROBE_LIMITED:-1800}"   # out of quota (free)
CLAUDE_PROBE_OK="${AGENT_USAGE_PROBE_OK:-86400}"            # numbers going stale
# The window figures are account-wide, so the cheapest model reports the same
# numbers as the expensive one: haiku from an empty directory costs about a
# tenth of what the default model with this repo's CLAUDE.md loaded does.
CLAUDE_PROBE_MODEL="${AGENT_USAGE_PROBE_MODEL:-claude-haiku-4-5-20251001}"

# A lock is a directory (mkdir is the atomic part) plus the owner's pid, which
# is what lets the next run tell "still working" from "died holding it". Without
# the pid a leaked lock silently disables collection until it ages out, and the
# EXIT trap alone does not survive a kill.
take_lock() {
    local name="$1" owner
    local dir="$STATE_DIR/.lock.$name"
    if ! mkdir "$dir" 2>/dev/null; then
        owner="$(cat "$dir/pid" 2>/dev/null)"
        case "${owner:-}" in
            ''|*[!0-9]*) ;;   # nothing recorded -- assume the owner is gone
            *) kill -0 "$owner" 2>/dev/null && return 1 ;;
        esac
        rm -rf "$dir" 2>/dev/null
        mkdir "$dir" 2>/dev/null || return 1
    fi
    printf '%s\n' "$$" > "$dir/pid" 2>/dev/null
    LOCK_DIR="$dir"
    trap release_lock EXIT INT TERM HUP
    return 0
}

release_lock() {
    [ -n "${LOCK_DIR:-}" ] && rm -rf "$LOCK_DIR" 2>/dev/null
    return 0
}

write_state() {
    # write_state <key> <kind> <label> <status> <five> <week> <resets> <plan> [note]
    local key="$1" kind="$2" label="$3" status="$4"
    local five="$5" week="$6" resets="$7" plan="$8" note="${9:-}"
    mkdir -p "$STATE_DIR" || return 0
    # Write via a temp file: the bar reads this directory on a timer and must
    # never see a half-written line.
    local tmp="$STATE_DIR/.tmp.$key.$$"
    if printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$kind" "$label" "$status" "$five" "$week" "$resets" "$(date +%s)" \
        "$plan" "$note" \
        > "$tmp" 2>/dev/null
    then
        mv -f "$tmp" "$STATE_DIR/$key" 2>/dev/null
    fi
    rm -f "$tmp" 2>/dev/null
    return 0
}

# Nudge the bar, but never fail a hook or a status line over it.
notify_bar() {
    command -v sketchybar >/dev/null 2>&1 &&
        sketchybar --trigger agent_usage_changed >/dev/null 2>&1
    return 0
}

# Percentages earn colour only once they matter: quiet below 75%, then warmer.
colorize() {
    local pct="$1" int
    int="${pct%%.*}"
    case "$int" in
        ''|*[!0-9]*) printf '%s%%' "$pct"; return ;;
    esac
    if   [ "$int" -ge 90 ]; then printf '\033[31m%s%%\033[0m' "$pct"
    elif [ "$int" -ge 75 ]; then printf '\033[33m%s%%\033[0m' "$pct"
    else                         printf '\033[2m%s%%\033[0m'  "$pct"
    fi
}

# ---------------------------------------------------------------------------
# claude-statusline
# ---------------------------------------------------------------------------
# Runs on every status line repaint, so it must stay cheap: one jq, one write.

claude_statusline() {
    local payload
    payload="$(cat)"

    # The config dir names the account, spelled out: claude, claude-worker-1,
    # claude-worker-2, claude-worker-3. agent-notify shortens these to w1/w2/w3
    # because it packs several agents into one label, but this item shows one
    # account at a time and has the room, and the full name is what you type.
    local instance
    case "${CLAUDE_CONFIG_DIR:-}" in
        "") instance=claude ;;
        *)  instance="${CLAUDE_CONFIG_DIR##*/}"
            instance="${instance#.}"
            ;;
    esac

    # Dump the raw payload when debugging: the statusLine schema is not
    # something we control, and this is the only place it can be observed.
    if [ -n "${AGENT_USAGE_DEBUG:-}" ]; then
        mkdir -p "$STATE_DIR" 2>/dev/null
        printf '%s\n' "$payload" > "$STATE_DIR/.debug.$instance.json" 2>/dev/null
    fi

    local fields five week model dir
    # `// empty` on every lookup: these fields are absent for API-key auth and
    # on any version that stops sending them, and a missing quota must degrade
    # to "-" rather than to a confident 0%.
    fields="$(printf '%s' "$payload" | jq -r '
        def pct: if type == "number" then (. * 10 | round / 10 | tostring) else "-" end;
        [ (.rate_limits.five_hour.used_percentage | pct)
        , (.rate_limits.seven_day.used_percentage | pct)
        , (.model.display_name // "")
        , ((.workspace.current_dir // .cwd // "") | split("/") | last // "")
        ] | @tsv' 2>/dev/null)"
    IFS=$'\t' read -r five week model dir <<< "$fields"

    five="${five:-$UNKNOWN}"
    week="${week:-$UNKNOWN}"

    # No quota in the payload means this session is not on a subscription plan
    # (API key, Bedrock, Vertex) -- there is no weekly limit to report.
    local status=ok
    [ "$five" = "$UNKNOWN" ] && [ "$week" = "$UNKNOWN" ] && status=unknown

    # A payload can arrive without rate limits even on a subscription -- early
    # in a session, or on a repaint that raced the first response. Never let
    # that erase a real number: keep the previous sample and let its age show
    # instead. Only an account that has never reported writes "unknown".
    local keep_previous='' prev_status='' prev_resets="$UNKNOWN"
    if [ -f "$STATE_DIR/$instance" ]; then
        IFS=$'\t' read -r _ _ prev_status _ _ prev_resets _ \
            < "$STATE_DIR/$instance" 2>/dev/null
        [ "$status" = unknown ] && [ "${prev_status:-}" = ok ] && keep_previous=1
    fi

    if [ -z "$keep_previous" ]; then
        # The status line has no reset time in it -- only the probe does -- so
        # carry forward whatever the last probe found instead of blanking the
        # column every time the bar repaints.
        write_state "$instance" claude "$instance" "$status" \
            "$five" "$week" "${prev_resets:-$UNKNOWN}" "$UNKNOWN"
        notify_bar
    fi

    # Now render the status line itself. The account is worth naming here: with
    # four of these open at once, knowing which one you are typing into matters.
    local dim=$'\033[2m' reset=$'\033[0m'
    local out="${dim}${instance}${reset}"
    [ -n "$dir" ]   && out+=" ${dim}${dir}${reset}"
    [ -n "$model" ] && out+=" ${dim}·${reset} ${model}"
    [ "$five" != "$UNKNOWN" ] && out+=" ${dim}·${reset} 5h $(colorize "$five")"
    [ "$week" != "$UNKNOWN" ] && out+=" ${dim}·${reset} 7d $(colorize "$week")"
    printf '%s\n' "$out"
}

# ---------------------------------------------------------------------------
# codex-poll
# ---------------------------------------------------------------------------

# Ask one Codex home for its rate limits. `codex app-server` speaks JSON-RPC on
# stdin/stdout and shuts down when stdin closes -- which it would do before the
# async reply lands, so hold the pipe open until the answer arrives.
codex_rate_limits() {
    local home="$1"
    perl -e '
        $| = 1;
        print qq({"jsonrpc":"2.0","id":0,"method":"initialize","params":{"clientInfo":{"name":"agent-usage","title":"agent-usage","version":"1"}}}\n);
        select(undef, undef, undef, 1.5);
        print qq({"jsonrpc":"2.0","method":"initialized"}\n);
        select(undef, undef, undef, 0.3);
        print qq({"jsonrpc":"2.0","id":1,"method":"account/rateLimits/read","params":{}}\n);
        select(undef, undef, undef, 12);
    ' 2>/dev/null | CODEX_HOME="$home" codex app-server 2>/dev/null |
        grep -m1 -E '"id":1|"error"'
}

# True when the cached sample for this account is still new enough to keep.
state_fresh() {
    local key="$1" status updated age max
    local file="$STATE_DIR/$key"
    [ -n "${AGENT_USAGE_FORCE:-}" ] && return 1
    [ -f "$file" ] || return 1
    IFS=$'\t' read -r _ _ status _ _ _ updated _ < "$file" || return 1
    case "${updated:-}" in ''|*[!0-9]*) return 1 ;; esac
    age=$(( $(date +%s) - updated ))
    if [ "$status" = auth ]; then max="$CODEX_REFRESH_AUTH"; else max="$CODEX_REFRESH_OK"; fi
    [ "$age" -lt "$max" ]
}

codex_poll_home() {
    local home="$1" key="$2" label="$3" reply fields five week resets plan

    [ -d "$home" ] || return 0
    state_fresh "$key" && return 0
    reply="$(codex_rate_limits "$home")"

    # No reply at all: the app-server never answered. Leave the last known
    # sample in place rather than overwriting it with nothing.
    [ -n "$reply" ] || return 0

    # A signed-out account cannot report a quota, and that is worth showing
    # distinctly -- it is the one failure the bar can tell you how to fix.
    case "$reply" in
        *401*|*Unauthorized*|*unauthorized*)
            write_state "$key" codex "$label" auth \
                "$UNKNOWN" "$UNKNOWN" "$UNKNOWN" "$UNKNOWN"
            return 0
            ;;
    esac

    # Codex reports a window per model as well as an account-wide one, and the
    # window length is the only thing identifying which is which: ~300 minutes
    # is the rolling five-hour cap, ~10080 the weekly one. Take the worst
    # number in each bucket -- the tightest limit is what will actually stop
    # you -- and the soonest reset.
    fields="$(printf '%s' "$reply" | jq -r '
        def pct: if type == "number" then (. * 10 | round / 10 | tostring) else "-" end;
        ( .result.rateLimits // {} ) as $top
        | [ $top, ( (.result.rateLimitsByLimitId // {}) | .[] ) ]
        | map(select(type == "object"))
        | map(.primary, .secondary)
        | map(select(type == "object"))                      as $w
        | ( $w | map(select(.windowDurationMins <= 600)))    as $short
        | ( $w | map(select(.windowDurationMins >= 10000)))  as $long
        | [ ( $short | map(.usedPercent) | max | pct )
          , ( $long  | map(.usedPercent) | max | pct )
          , ( $long  | map(.resetsAt) | map(select(type == "number")) | min
              | if type == "number" then tostring else "-" end )
          , ( $top.planType // "-" )
          ] | @tsv' 2>/dev/null)"

    IFS=$'\t' read -r five week resets plan <<< "$fields"
    five="${five:-$UNKNOWN}"
    week="${week:-$UNKNOWN}"

    local status=ok
    [ "$five" = "$UNKNOWN" ] && [ "$week" = "$UNKNOWN" ] && status=unknown

    write_state "$key" codex "$label" "$status" \
        "$five" "$week" "${resets:-$UNKNOWN}" "${plan:-$UNKNOWN}"
}

codex_poll() {
    command -v codex >/dev/null 2>&1 || exit 0
    command -v perl  >/dev/null 2>&1 || exit 0
    command -v jq    >/dev/null 2>&1 || exit 0

    mkdir -p "$STATE_DIR" || exit 0
    # One poller at a time. Each call spawns an app-server for a dozen seconds,
    # so a pile-up would be worse than a skipped sample.
    take_lock codex || exit 0

    # Label these the way agent-notify does: the config dir names the account.
    codex_poll_home "$HOME/.codex"      codex      codex
    codex_poll_home "$HOME/.codex-work" codex-work codex-work

    notify_bar
}


# ---------------------------------------------------------------------------
# claude-probe
# ---------------------------------------------------------------------------

# When may this account be probed again? Cheapest first: an account with real
# numbers barely needs it, an exhausted one benefits most.
claude_probe_due() {
    local key="$1" status updated age max
    local file="$STATE_DIR/$key"
    [ -n "${AGENT_USAGE_FORCE:-}" ] && return 0
    [ -f "$file" ] || return 0
    IFS=$'\t' read -r _ _ status _ _ _ updated _ < "$file" 2>/dev/null || return 0
    case "${updated:-}" in ''|*[!0-9]*) return 0 ;; esac
    age=$(( $(date +%s) - updated ))
    case "${status:-}" in
        limited) max="$CLAUDE_PROBE_LIMITED" ;;
        ok)      max="$CLAUDE_PROBE_OK" ;;
        *)       max="$CLAUDE_PROBE_PENDING" ;;
    esac
    [ "$age" -ge "$max" ]
}

claude_probe_one() {
    local dir="$1" key="$2" raw fields five week resets status note

    [ -d "$dir" ] || return 0
    claude_probe_due "$key" || return 0

    # Run from an empty directory: the probe wants the account's quota, not
    # whatever CLAUDE.md happens to sit in the working tree, and loading one
    # multiplies the cost of the turn for no benefit.
    local probe_cwd="$STATE_DIR/.probe-cwd"
    mkdir -p "$probe_cwd" || return 0

    local model_args=()
    [ -n "$CLAUDE_PROBE_MODEL" ] && model_args=(--model "$CLAUDE_PROBE_MODEL")

    # `alarm` rather than a shell timeout: macOS has no timeout(1), and a
    # wedged probe must not sit on the lock.
    raw="$(
        cd "$probe_cwd" &&
        CLAUDE_CONFIG_DIR="$dir" perl -e 'alarm 150; exec @ARGV' \
            claude -p --output-format stream-json --verbose --max-turns 1 \
            "${model_args[@]}" hi </dev/null 2>/dev/null
    )"
    [ -n "$raw" ] || return 0

    # Claude Code emits a rate_limit_event carrying the same windows the status
    # line reports -- on a refused request too, which is what makes a maxed-out
    # account measurable at all. utilization is a fraction, not a percentage.
    fields="$(printf '%s\n' "$raw" | jq -s -r '
        def pct: if type == "number" then (. * 1000 | round / 10 | tostring) else "-" end;
        ( map(select(.type == "rate_limit_event")) | last | .rate_limit_info // {} ) as $r
        | ( map(select(.type == "result")) | last // {} ) as $res
        | ( $r.unifiedWindows // {} ) as $w
        | [ ( $w.five_hour.utilization  | pct )
          , ( $w.seven_day.utilization  | pct )
          , ( $w.seven_day.resetsAt // "-" | tostring )
          , ( if ($r.status == "rejected" or $r.overageStatus == "rejected")
              then "limited" else "ok" end )
          # Keep only the clause that says when it comes back; the rest of the
          # message is a suggestion the bar has no room for.
          , ( $res.result // ""
              | gsub("[\t\n]"; " ")
              | split(" · ") | map(select(test("reset"; "i"))) | join(" · ")
              | sub("^your "; "") )
          ] | @tsv' 2>/dev/null)"

    IFS=$'\t' read -r five week resets status note <<< "$fields"

    if [ "${five:--}" = '-' ] && [ "${week:--}" = '-' ]; then
        # No windows came back. An expired login is worth saying out loud --
        # it is the one failure you can act on, and it will not fix itself --
        # but keep the last known numbers, since they are still the best guess
        # at where the account stood. Anything else (network, a wedged probe)
        # leaves the sample entirely alone.
        case "$raw" in
            *"Failed to authenticate"*|*"OAuth session expired"*|*"Please run /login"*)
                local p_status p_five p_week p_resets p_updated
                p_status='' p_five="$UNKNOWN" p_week="$UNKNOWN"
                p_resets="$UNKNOWN" p_updated=0
                if [ -f "$STATE_DIR/$key" ]; then
                    IFS=$'\t' read -r _ _ p_status p_five p_week p_resets p_updated _ \
                        < "$STATE_DIR/$key" 2>/dev/null
                fi
                # A running session reporting real numbers outranks a probe that
                # could not start one: the credential may be too stale for a new
                # process while a live session still holds a working token. Only
                # call it signed out once nothing is reporting any more, or the
                # two writers just overwrite each other every few seconds.
                case "${p_updated:-}" in ''|*[!0-9]*) p_updated=0 ;; esac
                if [ "${p_status:-}" = ok ] &&
                   [ $(( $(date +%s) - p_updated )) -lt 600 ]; then
                    return 0
                fi
                write_state "$key" claude "$key" auth \
                    "${p_five:-$UNKNOWN}" "${p_week:-$UNKNOWN}" "${p_resets:-$UNKNOWN}" \
                    "$UNKNOWN" 'login expired'
                ;;
        esac
        return 0
    fi

    write_state "$key" claude "$key" "${status:-ok}" \
        "${five:--}" "${week:--}" "${resets:--}" "$UNKNOWN" "${note:-}"
}

# Is this directory an account, or just something sitting next to one? Claude
# Code creates `<config-dir>.lock` while it writes its config, and a glob of
# `.claude-worker-*` matches that happily. Getting this wrong is not cosmetic:
# the probe runs `claude` against whatever it is handed, and doing that to a
# lock directory *creates* a config skeleton inside it, which then reports back
# as an account that is signed out.
#
# Two independent guards, because they fail differently: a dotted suffix is a
# lock or backup artefact and never an account, and a real account carries the
# settings.json this whole feature runs from. A signed-out account still has
# one, so the genuine "signed out" case is untouched.
is_claude_account() {
    local dir="$1"
    local key="$2"
    case "$key" in *.*) return 1 ;; esac
    [ -f "$dir/settings.json" ] || return 1
    return 0
}

claude_probe() {
    command -v claude >/dev/null 2>&1 || exit 0
    command -v jq     >/dev/null 2>&1 || exit 0
    command -v perl   >/dev/null 2>&1 || exit 0

    mkdir -p "$STATE_DIR" || exit 0
    # One prober at a time: each probe is a whole claude process.
    take_lock claude || exit 0

    local dir key
    for dir in "$HOME"/.claude "$HOME"/.claude-worker-*; do
        [ -d "$dir" ] || continue
        key="${dir##*/}"; key="${key#.}"
        is_claude_account "$dir" "$key" || continue
        claude_probe_one "$dir" "$key"
    done

    notify_bar
}

case "$MODE" in
    claude-statusline) claude_statusline ;;
    codex-poll)        codex_poll ;;
    claude-probe)      claude_probe ;;
    *)
        echo "agent-usage: unknown mode '${MODE}'" >&2
        echo "usage: agent-usage.sh <claude-statusline|codex-poll|claude-probe>" >&2
        exit 2
        ;;
esac
