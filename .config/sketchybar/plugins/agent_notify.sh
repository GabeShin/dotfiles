#!/usr/bin/env bash
#
# Renders the pending-agent badge from the state files written by
# ~/.config/agent-notify/agent-notify.sh

source "$CONFIG_DIR/colors.sh"

STATE_DIR="${AGENT_NOTIFY_DIR:-$HOME/.cache/agent-notify}"

# Clicking the badge dismisses everything.
if [ "$SENDER" = "mouse.clicked" ]; then
    rm -f "$STATE_DIR"/* 2>/dev/null
fi

shopt -s nullglob
entries=("$STATE_DIR"/*)

# Codex has no "user replied" event to clear on (its `notify` only fires when a
# turn ends), so retire codex entries once you are demonstrably looking at the
# pane: kitty frontmost and that pane visible in an attached client.
if [ ${#entries[@]} -gt 0 ]; then
    front="$(sketchybar --query front_app 2>/dev/null | jq -r '.label.value // empty')"
    if [ "$front" = "kitty" ]; then
        # Space-delimited on both sides, so pane %7 cannot match pane %77.
        visible=" "
        for session in $(tmux list-clients -F '#{client_session}' 2>/dev/null | sort -u); do
            visible+="$(tmux display-message -p -t "$session" '#{pane_id}' 2>/dev/null) "
        done
        for f in "${entries[@]}"; do
            IFS=$'\t' read -r kind _ _ < "$f" || continue
            [ "$kind" = codex ] || continue
            base="${f##*/}"
            case "$base" in pane-*) ;; *) continue ;; esac
            case "$visible" in
                *" %${base#pane-} "*) rm -f "$f" ;;
            esac
        done
        entries=("$STATE_DIR"/*)
    fi
fi

if [ ${#entries[@]} -eq 0 ]; then
    sketchybar --set "$NAME" drawing=off
    exit 0
fi

label=""
waiting=0
for f in "${entries[@]}"; do
    IFS=$'\t' read -r _ state text < "$f" || continue
    [ "$state" = waiting ] && waiting=1
    label+="${label:+  }${text}"
done

# Red when something is blocked on you, green when it is merely finished.
if [ "$waiting" -eq 1 ]; then
    icon="󱚞"
    color="$RED"
else
    icon="󰚩"
    color="$GREEN"
fi

count=${#entries[@]}
[ "$count" -gt 1 ] && icon="$icon $count"

sketchybar --set "$NAME" drawing=on icon="$icon" icon.color="$color" label="$label"
