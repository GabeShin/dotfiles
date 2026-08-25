#!/usr/bin/env bash
#
# Renders the subscription quota readout from the state files written by
# ~/.config/agent-usage/agent-usage.sh
#
# The bar has room for one account at a time, so the item rotates: one entry
# per tick. Clicking opens a popup with all of them at once, which is the view
# that actually answers "which subscription am I leaning on this week?".

source "$CONFIG_DIR/colors.sh"

STATE_DIR="${AGENT_USAGE_DIR:-$HOME/.cache/agent-usage}"
CURSOR="$STATE_DIR/.cursor"
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
# Group Claude accounts before Codex ones; within a kind the glob is already
# alphabetical (claude, claude-worker-1..3 / codex, codex-work), which keeps
# the rotation order stable between ticks.
claude_files=() codex_files=()
for f in "$STATE_DIR"/*; do
    IFS=$'\t' read -r kind _ < "$f" 2>/dev/null || continue
    case "$kind" in
        claude) claude_files+=("$f") ;;
        codex)  codex_files+=("$f") ;;
    esac
done
entries=("${claude_files[@]}" "${codex_files[@]}")

if [ ${#entries[@]} -eq 0 ]; then
    sketchybar --set "$NAME" drawing=off popup.drawing=off
    exit 0
fi

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
    local i=0 f kind label status five week resets updated plan

    # Mark the account carrying the most of this week: that is the one worth
    # steering the next task away from, and it is the reason to open this at all.
    local top_label='' top_pct=-1
    for f in "${entries[@]}"; do
        IFS=$'\t' read -r kind label status five week resets updated plan < "$f" || continue
        case "${week%%.*}" in ''|*[!0-9]*) continue ;; esac
        if [ "${week%%.*}" -gt "$top_pct" ]; then
            top_pct="${week%%.*}"; top_label="$label"
        fi
    done

    # Column header, so the two numbers never have to be guessed at. The widths
    # mirror the data row below exactly: name, then gauge+percent as one
    # 15-wide block, then the five-hour cell, then the reset.
    add_row head "$TRANSPARENT" \
        "$(printf '%-*s %-15s   %-7s   %s' \
            "$NAME_WIDTH" 'account' 'this week' '5 hours' 'resets')" \
        "$GREY"

    for f in "${entries[@]}"; do
        IFS=$'\t' read -r kind label status five week resets updated plan < "$f" || continue
        local text color dot stale reset_txt
        dot="$([ "$kind" = codex ] && echo "$MAGENTA" || echo "$BLUE")"

        case "$status" in
            auth)
                text="$(printf '%-*s signed out -- run:  CODEX_HOME=~/.%s codex login' \
                        "$NAME_WIDTH" "$label" "$label")"
                color="$RED"
                ;;
            *)
                if [ "$week" = '-' ] && [ "$five" = '-' ]; then
                    text="$(printf '%-*s no subscription quota' "$NAME_WIDTH" "$label")"
                    color="$GREY"
                else
                    reset_txt="$(until_reset "$resets")"
                    text="$(printf '%-*s %s %s   5h %s   %s' \
                            "$NAME_WIDTH" "$label" \
                            "$(gauge "$week")" "$(pct_cell "$week")" \
                            "$(pct_cell "$five")" \
                            "${reset_txt:+in $reset_txt}")"
                    color="$(pct_color "$week")"
                fi
                ;;
        esac

        stale="$(age_of "$updated")"
        [ -n "$stale" ] && text="$text  ($stale)"
        if [ "$label" = "$top_label" ] && [ "$top_pct" -gt 0 ]; then
            text="$text  ← heaviest"
        fi

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
# Bar: one account per tick
# ---------------------------------------------------------------------------
# Advance only on the timer. A statusline write fires agent_usage_changed, and
# letting that advance the rotation would make the display jump around while
# you type.
index=0
[ -f "$CURSOR" ] && read -r index < "$CURSOR" 2>/dev/null
case "$index" in ''|*[!0-9]*) index=0 ;; esac
if [ "$SENDER" = "routine" ] || [ "$SENDER" = "forced" ]; then
    index=$(( (index + 1) % ${#entries[@]} ))
    printf '%s\n' "$index" > "$CURSOR" 2>/dev/null
fi
[ "$index" -ge ${#entries[@]} ] && index=0

IFS=$'\t' read -r kind label status five week resets updated plan < "${entries[$index]}"

case "$status" in
    auth)
        label_text="$label  signed out"
        color="$RED"
        ;;
    *)
        if [ "$week" != '-' ]; then
            label_text="$label  $(pct_int "$week")% this week"
            color="$(pct_color "$week")"
        elif [ "$five" != '-' ]; then
            label_text="$label  $(pct_int "$five")% this 5h"
            color="$(pct_color "$five")"
        else
            label_text="$label  no data"
            color="$GREY"
        fi
        ;;
esac

# A dimmed icon means the numbers behind it are not fresh.
icon_color="$WHITE"
[ -n "$(age_of "$updated")" ] && icon_color="$GREY"

sketchybar --set "$NAME" drawing=on \
                         icon='󰚩' \
                         icon.color="$icon_color" \
                         label="$label_text" \
                         label.color="$color"
