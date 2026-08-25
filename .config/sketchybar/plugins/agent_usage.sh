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

# Codex has to be asked; Claude reports itself through its status line. The
# collector decides whether a poll is actually due, so calling it every tick is
# cheap -- but it must never hold up the bar, hence the detached subshell.
[ -x "$COLLECTOR" ] && ( "$COLLECTOR" codex-poll >/dev/null 2>&1 & )

shopt -s nullglob
# Group Claude accounts before Codex ones; within a kind the glob is already
# alphabetical (claude, w1, w2, w3 / codex, codex-work), which keeps the
# rotation order stable between ticks.
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
# first three quarters of a quota are not worth a warm colour.
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

# "2d 4h" / "3h 12m" / "8m" -- enough to know whether waiting is an option.
until_reset() {
    local at="$1" left
    case "$at" in ''|-|*[!0-9]*) return ;; esac
    left=$(( at - $(date +%s) ))
    [ "$left" -le 0 ] && { printf 'due'; return; }
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
build_popup() {
    local args=(--remove '/agent_usage\.row\..*/')
    local i=0 f kind label status five week resets updated plan

    # Mark the account carrying the most of this week, since that is the one
    # worth steering work away from.
    local top_label="" top_pct=-1
    for f in "${entries[@]}"; do
        IFS=$'\t' read -r kind label status five week resets updated plan < "$f" || continue
        case "${week%%.*}" in ''|*[!0-9]*) continue ;; esac
        [ "${week%%.*}" -gt "$top_pct" ] && { top_pct="${week%%.*}"; top_label="$label"; }
    done

    for f in "${entries[@]}"; do
        IFS=$'\t' read -r kind label status five week resets updated plan < "$f" || continue
        local row="agent_usage.row.$i" text="" color="$LABEL_COLOR" stale
        case "$status" in
            auth)
                text="signed out -- run: CODEX_HOME=~/.$label codex login"
                color="$RED"
                ;;
            *)
                if [ "$week" = "-" ] && [ "$five" = "-" ]; then
                    text="no quota reported"
                    color="$GREY"
                else
                    [ "$five" != "-" ] && text="5h ${five}%"
                    [ "$week" != "-" ] && text="${text:+$text  }7d ${week}%"
                    local r; r="$(until_reset "$resets")"
                    [ -n "$r" ] && text="$text  resets $r"
                    color="$(pct_color "$week")"
                fi
                ;;
        esac
        stale="$(age_of "$updated")"
        [ -n "$stale" ] && text="$text  ($stale)"
        [ "$label" = "$top_label" ] && [ "$top_pct" -ge 0 ] && text="$text  ←"

        args+=(--add item "$row" popup."$NAME"
               --set "$row" icon="$label"
                            icon.font="$FONT:Bold:12.0"
                            icon.color="$([ "$kind" = codex ] && echo "$MAGENTA" || echo "$BLUE")"
                            icon.padding_left=8
                            label="$text"
                            label.font="$FONT:Regular:12.0"
                            label.color="$color"
                            label.padding_right=8
                            click_script="sketchybar --set $NAME popup.drawing=off")
        i=$(( i + 1 ))
    done

    # A forced refresh is the one action this popup can usefully offer: Codex
    # numbers are cached for minutes at a time.
    args+=(--add item agent_usage.row.refresh popup."$NAME"
           --set agent_usage.row.refresh icon="↻"
                        icon.font="$FONT:Bold:12.0"
                        icon.color="$GREY"
                        icon.padding_left=8
                        label="refresh now"
                        label.font="$FONT:Regular:12.0"
                        label.color="$GREY"
                        label.padding_right=8
                        click_script="AGENT_USAGE_FORCE=1 $COLLECTOR codex-poll >/dev/null 2>&1 & sketchybar --set $NAME popup.drawing=off")

    sketchybar "${args[@]}" >/dev/null
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
        label_text="$label  login"
        color="$RED"
        ;;
    *)
        if [ "$week" != "-" ]; then
            label_text="$label  7d ${week}%"
            color="$(pct_color "$week")"
        elif [ "$five" != "-" ]; then
            label_text="$label  5h ${five}%"
            color="$(pct_color "$five")"
        else
            label_text="$label  --"
            color="$GREY"
        fi
        ;;
esac

# A dimmed icon means the numbers behind it are not fresh.
icon_color="$WHITE"
[ -n "$(age_of "$updated")" ] && icon_color="$GREY"

sketchybar --set "$NAME" drawing=on \
                         icon="󰚩" \
                         icon.color="$icon_color" \
                         label="$label_text" \
                         label.color="$color"
