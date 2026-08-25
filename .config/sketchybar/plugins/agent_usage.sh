#!/usr/bin/env bash
#
# Renders the subscription quota readout from the state files written by
# ~/.config/agent-usage/agent-usage.sh
#
# The bar shows all six accounts as a sparkline -- one fixed cell each, height
# by weekly usage -- so an imbalance is visible as a shape without waiting for
# anything to rotate. Clicking opens the full table.

source "$CONFIG_DIR/colors.sh"

STATE_DIR="${AGENT_USAGE_DIR:-$HOME/.cache/agent-usage}"
COLLECTOR="$HOME/.config/agent-usage/agent-usage.sh"

# sketchybarrc keeps FONT as a plain shell variable, so it does not reach
# plugin processes -- carry the same default rather than emitting ":Bold:12.0".
FONT="${FONT:-SF Pro}"
# The popup is a table, and a table needs fixed-width cells to be readable at a
# glance. SF Pro is proportional, so the rows use the same monospace face the
# agent_notify badge already relies on.
MONO="MesloLGL Nerd Font"
NAME_WIDTH=16   # "claude-worker-1" is 15 characters

# Codex has to be asked; Claude reports itself through its status line. The
# collector decides whether a poll is actually due, so calling it every tick is
# cheap -- but it must never hold up the bar, hence the detached subshell.
[ -x "$COLLECTOR" ] && ( "$COLLECTOR" codex-poll >/dev/null 2>&1 & )

shopt -s nullglob
# Enumerate the accounts that *exist*, not the ones that happen to have
# reported. An account you have not opened since this item was installed has no
# state file, and leaving it out entirely reads as "fine" when it means
# "unknown" -- which is exactly the account you might then overload. Deriving
# the list from the config dirs also means a new worker shows up on its own,
# and fixes the rotation order instead of letting it depend on what has run.
accounts=()   # kind <TAB> label <TAB> state file
_seen=' '
add_account() {
    local kind="$1" dir="$2" label
    [ -d "$dir" ] || return 0
    label="${dir##*/}"; label="${label#.}"
    case "$_seen" in *" $label "*) return 0 ;; esac
    _seen+="$label "
    accounts+=("$kind"$'\t'"$label"$'\t'"$STATE_DIR/$label")
}
for d in "$HOME"/.claude "$HOME"/.claude-worker-*; do add_account claude "$d"; done
for d in "$HOME"/.codex   "$HOME"/.codex-*;         do add_account codex  "$d"; done

if [ ${#accounts[@]} -eq 0 ]; then
    sketchybar --set "$NAME" drawing=off popup.drawing=off
    exit 0
fi

# Load one account's numbers into acc_*. A missing state file is "pending":
# the account is real, it just has not reported yet.
read_account() {
    local rec="$1"
    IFS=$'\t' read -r acc_kind acc_label acc_file <<< "$rec"
    acc_status=pending acc_five='-' acc_week='-' acc_resets='-' acc_updated='-' acc_plan='-'
    [ -f "$acc_file" ] || return 0
    IFS=$'\t' read -r _ _ acc_status acc_five acc_week acc_resets acc_updated acc_plan \
        < "$acc_file" 2>/dev/null || acc_status=pending
    return 0
}

# Colour tracks how close to the cap you are, not how much you have used: the
# first half of a quota is not worth a warm colour.
pct_color() {
    local pct="${1%%.*}"
    case "$pct" in
        ''|*[!0-9]*) echo "$GREY";   return ;;
    esac
    if   [ "$pct" -ge 90 ]; then echo "$RED"
    elif [ "$pct" -ge 75 ]; then echo "$ORANGE"
    elif [ "$pct" -ge 50 ]; then echo "$YELLOW"
    else                         echo "$GREEN"
    fi
}

# Whole percents only. A tenth of a percent of a weekly quota is noise, and
# "93%" is quicker to read than "93.2%".
pct_int() {
    local v="$1" i f
    case "$v" in ''|*[!0-9.]*) printf '%s' '-'; return ;; esac
    i="${v%%.*}"; f="${v#*.}"
    [ "$f" = "$v" ] && f=0
    f="${f:0:1}"
    case "$f" in ''|*[!0-9]*) f=0 ;; esac
    [ "$f" -ge 5 ] && i=$(( i + 1 ))
    printf '%d' "${i:-0}"
}

# Right-aligned percent cell, or "--" when there is nothing to show.
pct_cell() {
    local n; n="$(pct_int "$1")"
    if [ "$n" = "-" ]; then printf '%4s' '--'; else printf '%3d%%' "$n"; fi
}

# Ten cells of bar. Far easier to compare down a column than digits are, which
# is the whole point of this popup.
gauge() {
    local pct="${1%%.*}" filled i out=''
    case "$pct" in ''|*[!0-9]*) printf '%10s' ''; return ;; esac
    [ "$pct" -gt 100 ] && pct=100
    filled=$(( (pct + 5) / 10 ))
    # Never round a live account down to an empty bar -- 1% should still show.
    [ "$filled" -eq 0 ] && [ "$pct" -gt 0 ] && filled=1
    for (( i = 0; i < 10; i++ )); do
        if [ "$i" -lt "$filled" ]; then out+='█'; else out+='░'; fi
    done
    printf '%s' "$out"
}

# "2d 4h" / "3h 12m" / "8m" -- enough to know whether waiting is an option.
until_reset() {
    local at="$1" left
    case "$at" in ''|-|*[!0-9]*) return ;; esac
    left=$(( at - $(date +%s) ))
    [ "$left" -le 0 ] && { printf 'any moment'; return; }
    if   [ "$left" -ge 86400 ]; then printf '%dd %dh' $(( left / 86400 )) $(( left % 86400 / 3600 ))
    elif [ "$left" -ge 3600 ];  then printf '%dh %dm' $(( left / 3600 ))  $(( left % 3600 / 60 ))
    else                             printf '%dm' $(( left / 60 ))
    fi
}

# How stale is this sample? Claude only reports while a session is running, so
# an untouched account goes quiet -- say so rather than implying it is current.
age_of() {
    local updated="$1" age
    case "$updated" in ''|-|*[!0-9]*) return ;; esac
    age=$(( $(date +%s) - updated ))
    if   [ "$age" -lt 300 ];   then return
    elif [ "$age" -lt 3600 ];  then printf '%dm ago' $(( age / 60 ))
    elif [ "$age" -lt 86400 ]; then printf '%dh ago' $(( age / 3600 ))
    else                            printf '%dd ago' $(( age / 86400 ))
    fi
}

# ---------------------------------------------------------------------------
# Popup: every account at once
# ---------------------------------------------------------------------------
add_row() {
    # add_row <id> <dot-color> <text> <text-color>
    popup_args+=(--add item "agent_usage.row.$1" popup."$NAME"
                 --set "agent_usage.row.$1"
                       icon='●'
                       icon.font="$FONT:Bold:11.0"
                       icon.color="$2"
                       icon.padding_left=8
                       icon.padding_right=6
                       label="$3"
                       label.font="$MONO:Regular:12.0"
                       label.color="$4"
                       label.padding_right=10
                       click_script="sketchybar --set $NAME popup.drawing=off")
}

build_popup() {
    popup_args=(--remove '/agent_usage\.row\..*/')
    local i=0 rec

    # Column header, so the two numbers never have to be guessed at. The widths
    # mirror the data rows below exactly: name, then each window as a 15-wide
    # gauge-plus-percent block, then the reset.
    add_row head "$TRANSPARENT" \
        "$(printf '%-*s %-15s   %-15s   %s' \
            "$NAME_WIDTH" 'account' 'this week' '5 hours' 'resets')" \
        "$GREY"

    for rec in "${accounts[@]}"; do
        read_account "$rec"
        local text color dot stale reset_txt
        dot="$([ "$acc_kind" = codex ] && echo "$MAGENTA" || echo "$BLUE")"

        case "$acc_status" in
            pending)
                text="$(printf '%-*s not measured yet -- open a session to populate' \
                        "$NAME_WIDTH" "$acc_label")"
                color="$GREY"
                ;;
            auth)
                text="$(printf '%-*s signed out -- run:  CODEX_HOME=~/.%s codex login' \
                        "$NAME_WIDTH" "$acc_label" "$acc_label")"
                color="$RED"
                ;;
            *)
                if [ "$acc_week" = '-' ] && [ "$acc_five" = '-' ]; then
                    text="$(printf '%-*s no subscription quota' "$NAME_WIDTH" "$acc_label")"
                    color="$GREY"
                else
                    reset_txt="$(until_reset "$acc_resets")"
                    # Both windows get a gauge: the five-hour number is the one
                    # that stops you today, and a bar is what makes it legible.
                    text="$(printf '%-*s %s %s   %s %s   %s' \
                            "$NAME_WIDTH" "$acc_label" \
                            "$(gauge "$acc_week")" "$(pct_cell "$acc_week")" \
                            "$(gauge "$acc_five")" "$(pct_cell "$acc_five")" \
                            "${reset_txt:+in $reset_txt}")"
                    color="$(pct_color "$acc_week")"
                fi
                ;;
        esac

        stale="$(age_of "$acc_updated")"
        [ -n "$stale" ] && text="$text  ($stale)"

        add_row "$i" "$dot" "$text" "$color"
        i=$(( i + 1 ))
    done

    # A forced refresh is the one action this popup can usefully offer: Codex
    # numbers are cached for minutes at a time.
    popup_args+=(--add item agent_usage.row.refresh popup."$NAME"
                 --set agent_usage.row.refresh
                       icon='↻'
                       icon.font="$FONT:Bold:11.0"
                       icon.color="$GREY"
                       icon.padding_left=8
                       icon.padding_right=6
                       label='refresh now'
                       label.font="$MONO:Regular:12.0"
                       label.color="$GREY"
                       label.padding_right=10
                       click_script="AGENT_USAGE_FORCE=1 $COLLECTOR codex-poll >/dev/null 2>&1 & sketchybar --set $NAME popup.drawing=off")

    sketchybar "${popup_args[@]}" >/dev/null
}

if [ "$SENDER" = "mouse.clicked" ]; then
    build_popup
    sketchybar --set "$NAME" popup.drawing=toggle
    exit 0
fi

# ---------------------------------------------------------------------------
# Bar: all six accounts at once
# ---------------------------------------------------------------------------
# One cell per account in a fixed order, so a position always means the same
# account and the shape of the row *is* the distribution -- which is the thing
# worth noticing. This replaced a rotation that showed one account per tick:
# three minutes to learn what a glance can tell you, with the account you
# cared about likely off-screen at the moment you looked.
SPARK=('▁' '▂' '▃' '▄' '▅' '▆' '▇' '█')

spark_cell() {
    local pct="${1%%.*}" i
    case "$pct" in ''|*[!0-9]*) printf '%s' '·'; return ;; esac
    [ "$pct" -gt 100 ] && pct=100
    i=$(( pct * 8 / 100 ))
    [ "$i" -gt 7 ] && i=7
    printf '%s' "${SPARK[$i]}"
}

line='' worst_pct=-1 worst_label='' any_auth=0
for rec in "${accounts[@]}"; do
    read_account "$rec"
    case "$acc_status" in
        auth)    line+='!'; any_auth=1 ;;
        pending) line+='·' ;;
        *)
            if [ "$acc_week" = '-' ]; then
                line+='·'
            else
                line+="$(spark_cell "$acc_week")"
                if [ "${acc_week%%.*}" -gt "$worst_pct" ]; then
                    worst_pct="${acc_week%%.*}"
                    worst_label="$acc_label"
                fi
            fi
            ;;
    esac
done

# Naming the busiest account only earns its space once it is actually busy.
# Below half, the number alone is enough and the bar stays quiet.
if [ "$worst_pct" -lt 0 ]; then
    label_text="$line  no data"
    color="$GREY"
elif [ "$worst_pct" -ge 50 ]; then
    label_text="$line  $worst_label ${worst_pct}%"
    color="$(pct_color "$worst_pct")"
else
    label_text="$line  ${worst_pct}%"
    color="$(pct_color "$worst_pct")"
fi

# The label carries magnitude, so let the icon carry "something needs a look":
# a signed-out account cannot be measured at all, and no percentage will say so.
icon_color="$WHITE"
[ "$any_auth" -eq 1 ] && icon_color="$RED"

sketchybar --set "$NAME" drawing=on \
                         icon='󰚩' \
                         icon.color="$icon_color" \
                         label="$label_text" \
                         label.color="$color"
