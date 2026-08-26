#!/usr/bin/env bash
#
# Renders the pending-agent chips from the state files written by
# ~/.config/agent-notify/agent-notify.sh
#
# One chip per agent rather than one label for all of them, because the two
# states mean different things and used to be flattened into whichever was
# loudest: a single agent blocked on you turned the whole badge red, hiding
# that three others had merely finished.
#
# The states are told apart by *fill*, not by hue -- blocked is a solid pill,
# finished is plain text. Red-vs-green is the pair that collapses under the
# common colour-vision deficiencies, and it is also the wrong emphasis: only
# one of these two states is asking you for anything.
#
# Also invoked as `agent_notify.sh focus <key>` from a chip's click_script.

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

STATE_DIR="${AGENT_NOTIFY_DIR:-$HOME/.cache/agent-notify}"
SELF="$CONFIG_DIR/plugins/agent_notify.sh"
SIG_FILE="$STATE_DIR/.chips"
# sketchybarrc keeps FONT as a plain shell variable, so it never reaches plugin
# processes -- carry the same default rather than emitting ":Semibold:13.0".
FONT="${FONT:-SF Pro}"
MONO="MesloLGL Nerd Font"   # the agent glyphs are Nerd Font; SF renders blank

# ---------------------------------------------------------------------------
# Chip click: go to the agent, do not merely dismiss it
# ---------------------------------------------------------------------------
# Dismissing was all the old badge could do, which left you knowing that
# *something* wanted you and still hunting for it. Left click focuses the pane;
# right click clears just that chip.
if [ "${1:-}" = focus ]; then
    key="${2:-}"
    [ -n "$key" ] || exit 0
    pane="%${key#pane-}"

    if [ "${BUTTON:-left}" != right ] && [ "${key#pane-}" != "$key" ]; then
        if tmux has-session 2>/dev/null && \
           tmux display-message -p -t "$pane" '#{session_name}' >/dev/null 2>&1; then
            # One call does session, window and pane: switch-client resolves a
            # pane id all the way down, so the agent's session comes with it.
            #
            # Deliberately no -c. A client is addressed by its tty path, and a
            # suspended client keeps that path -- so `-c /dev/ttys000` picks
            # whichever of the two tmux finds first, which was the suspended
            # one. The session switch then landed on a client nobody was
            # looking at, while select-pane still worked (it acts on the window,
            # not through a client) -- so the pane moved and the session did
            # not. Left to itself, tmux uses the most recently used client,
            # which is the one in front of you.
            tmux switch-client -t "$pane" 2>/dev/null
            tmux select-window -t "$pane" 2>/dev/null
            tmux select-pane   -t "$pane" 2>/dev/null
            open -a kitty 2>/dev/null
        fi
    fi

    rm -f "$STATE_DIR/$key"
    sketchybar --trigger agent_notified >/dev/null 2>&1
    exit 0
fi

# Clicking the anchor dismisses everything.
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

# ---------------------------------------------------------------------------
# Read every agent first: a chip's label depends on the others
# ---------------------------------------------------------------------------
keys=() states=() labels=() insts=() sessions=()
for f in "${entries[@]}"; do
    IFS=$'\t' read -r _ e_state e_inst e_where e_sess < "$f" || continue
    keys+=("${f##*/}")
    states+=("$e_state")
    labels+=("${e_where:-$e_inst}")
    insts+=("$e_inst")
    sessions+=("${e_sess:-}")
done

n=${#keys[@]}

# Several panes legitimately share a window name -- a "dotfiles" window in each
# of two sessions is normal. Identical chips would be unreadable, so a colliding
# name earns a qualifier, and only then: the tmux session first, since that is
# how the windows are actually told apart, and the agent instance only if even
# the session does not separate them (two agents in one window).
# Each pass compares against a snapshot taken before it, never against the array
# it is editing: qualifying one label in place would otherwise hide the clash
# from the very entries still to be visited, and the last of three identical
# names would be left bare.
snap=()
dup_at() {
    local i="$1" j
    for (( j = 0; j < n; j++ )); do
        [ "$j" -ne "$i" ] && [ "${snap[$j]}" = "${snap[$i]}" ] && return 0
    done
    return 1
}

snap=("${labels[@]}")
for (( i = 0; i < n; i++ )); do
    dup_at "$i" || continue
    [ -n "${sessions[$i]}" ] && labels[$i]="${sessions[$i]}/${labels[$i]}"
done

snap=("${labels[@]}")
for (( i = 0; i < n; i++ )); do
    dup_at "$i" || continue
    labels[$i]="${labels[$i]}·${insts[$i]#claude-}"
done

# ---------------------------------------------------------------------------
# Draw
# ---------------------------------------------------------------------------
# Chips are added and removed as agents come and go, but only when the set
# actually changes -- rebuilding every five seconds would flicker. What is
# currently drawn is read back from sketchybar rather than remembered on disk:
# `--reload` wipes every item, and a note in a file would go on claiming the
# chips existed for as long as the bar ran without them.
sig="$n"
for (( i = 0; i < n; i++ )); do sig+="|${keys[$i]}:${states[$i]}:${labels[$i]}"; done
drawn="$(sketchybar --query bar 2>/dev/null | jq -r '.items[]' \
         | grep '^agent_notify\.chip\.' | sort | tr '\n' ' ')"
want=''
for (( i = 0; i < n; i++ )); do want+="agent_notify.chip.${keys[$i]} "; done
want="$(printf '%s' "$want" | tr ' ' '\n' | sort | tr '\n' ' ')"
[ "$(cat "$SIG_FILE" 2>/dev/null)" = "$sig" ] && [ "$drawn" = "$want" ] && exit 0

sketchybar --remove '/agent_notify\.chip\..*/' >/dev/null 2>&1

if [ "$n" -eq 0 ]; then
    printf '%s\n' "$sig" > "$SIG_FILE"
    sketchybar --set agent_notify drawing=off >/dev/null 2>&1
    exit 0
fi

args=()
for (( i = 0; i < n; i++ )); do
    name="agent_notify.chip.${keys[$i]}"
    if [ "${states[$i]}" = waiting ]; then
        # Blocked on you: a solid pill. Loud on purpose, and legible as a shape
        # even where the colour is not.
        icon="$AGENT_WAITING"
        args+=(--add item "$name" center
               --set "$name"
                     icon="$icon"
                     icon.font="$MONO:Bold:14.0"
                     icon.color="$BG0"
                     icon.padding_left=9
                     icon.padding_right=5
                     label="${labels[$i]}"
                     label.font="$FONT:Bold:13.0"
                     label.color="$BG0"
                     label.padding_right=10
                     label.shadow.drawing=off
                     background.drawing=on
                     background.color="$RED"
                     background.corner_radius=9
                     background.height=22
                     background.border_width=0
                     click_script="$SELF focus ${keys[$i]}")
    else
        # Finished a turn: nothing is waiting on you, so say so quietly.
        args+=(--add item "$name" center
               --set "$name"
                     icon="$AGENT_DONE"
                     icon.font="$MONO:Bold:14.0"
                     icon.color="$BLUE"
                     icon.padding_left=6
                     icon.padding_right=5
                     label="${labels[$i]}"
                     label.font="$FONT:Semibold:13.0"
                     label.color="$WHITE"
                     label.padding_right=6
                     background.drawing=off
                     click_script="$SELF focus ${keys[$i]}")
    fi
done

sketchybar "${args[@]}" >/dev/null
sketchybar --set agent_notify drawing=off >/dev/null 2>&1
printf '%s\n' "$sig" > "$SIG_FILE"
