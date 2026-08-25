#!/usr/bin/env bash
#
# Records per-account quota state for the sketchybar `agent_usage` item.
#
# Six subscriptions (four Claude config dirs, two Codex homes) are easy to
# unbalance, and an unbalanced week costs money. This collects what each
# account has actually spent so the bar can show it.
#
# Two producers, one state format:
#
#   claude-statusline  Claude Code >= 2.1 hands the live rate limits to the
#                      statusLine command on stdin, so reading them costs
#                      nothing: no token, no network, no login. This mode
#                      doubles as the status line itself, echoing a line to
#                      stdout for the session it was called from.
#   codex-poll         Codex pushes nothing, so ask its app-server
#                      (`account/rateLimits/read`) and cache the answer.
#
# State is one file per account under ~/.cache/agent-usage, tab separated:
#
#   kind  label  status  five_pct  week_pct  week_resets_at  updated_at  plan
#
# status is ok, auth (signed out -- the number cannot be fetched until you log
# in again) or unknown (nothing measured yet). Unknown numbers are "-", never
# 0, so the bar can tell an idle account from an unmeasured one. Presentation
# is the bar's job, so the fields stay separate and raw -- same split as
# agent-notify.
#
# Usage: agent-usage.sh <claude-statusline|codex-poll>

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

write_state() {
    # write_state <key> <kind> <label> <status> <five> <week> <resets> <plan>
    local key="$1" kind="$2" label="$3" status="$4"
    local five="$5" week="$6" resets="$7" plan="$8"
    mkdir -p "$STATE_DIR" || return 0
    # Write via a temp file: the bar reads this directory on a timer and must
    # never see a half-written line.
    local tmp="$STATE_DIR/.tmp.$key.$$"
    if printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$kind" "$label" "$status" "$five" "$week" "$resets" "$(date +%s)" "$plan" \
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
    local keep_previous=''
    if [ "$status" = unknown ] && [ -f "$STATE_DIR/$instance" ]; then
        local prev_status
        IFS=$'\t' read -r _ _ prev_status _ < "$STATE_DIR/$instance" 2>/dev/null
        [ "${prev_status:-}" = ok ] && keep_previous=1
    fi

    if [ -z "$keep_previous" ]; then
        write_state "$instance" claude "$instance" "$status" \
            "$five" "$week" "$UNKNOWN" "$UNKNOWN"
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
    local key="$1" file="$STATE_DIR/$key" status updated age max
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
    LOCK_DIR="$STATE_DIR/.lock.codex"
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        # Reclaim a lock left behind by a killed poller.
        if [ -n "$(find "$LOCK_DIR" -maxdepth 0 -mmin +5 2>/dev/null)" ]; then
            rmdir "$LOCK_DIR" 2>/dev/null
            mkdir "$LOCK_DIR" 2>/dev/null || exit 0
        else
            exit 0
        fi
    fi
    trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

    # Label these the way agent-notify does: the config dir names the account.
    codex_poll_home "$HOME/.codex"      codex      codex
    codex_poll_home "$HOME/.codex-work" codex-work codex-work

    notify_bar
}

case "$MODE" in
    claude-statusline) claude_statusline ;;
    codex-poll)        codex_poll ;;
    *)
        echo "agent-usage: unknown mode '${MODE}'" >&2
        echo "usage: agent-usage.sh <claude-statusline|codex-poll>" >&2
        exit 2
        ;;
esac
