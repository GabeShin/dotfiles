#!/usr/bin/env bash
#
# Records "this agent wants you" state for the sketchybar `agent_notify` item.
#
# Called from Claude Code hooks and from Codex's `notify` program. State is one
# small file per agent, keyed by tmux pane -- a pane hosts at most one
# interactive agent, so the pane is a natural identity and means we never have
# to parse the hook payload.
#
# Usage: agent-notify.sh <claude-done|claude-waiting|claude-clear|codex-done>
#
# Extra arguments are ignored, which is what lets Codex call this directly:
# Codex appends its own JSON payload as the final argument.

set -u

STATE_DIR="${AGENT_NOTIFY_DIR:-$HOME/.cache/agent-notify}"
EVENT="${1:-}"

# A pane hosts one agent, so the pane id is the state key. Outside tmux, fall
# back to the parent pid so at least concurrent agents don't collide.
if [ -n "${TMUX_PANE:-}" ]; then
    key="pane-${TMUX_PANE#%}"
else
    key="pid-$PPID"
fi
state_file="$STATE_DIR/$key"

notify_bar() {
    # The bar may not be running (logged out, sketchybar crashed); never fail
    # the hook over it.
    command -v sketchybar >/dev/null 2>&1 && sketchybar --trigger agent_notified >/dev/null 2>&1
    return 0
}

if [ "$EVENT" = "claude-clear" ]; then
    rm -f "$state_file"
    notify_bar
    exit 0
fi

case "$EVENT" in
    claude-done)    kind=claude; state=done ;;
    claude-waiting) kind=claude; state=waiting ;;
    codex-done)     kind=codex;  state=done ;;
    *)
        echo "agent-notify: unknown event '${EVENT}'" >&2
        exit 2
        ;;
esac

# Which instance is this? The claude-worker-N wrappers export CLAUDE_CONFIG_DIR
# and codex-work exports CODEX_HOME, so the config dir names the instance.
if [ "$kind" = codex ]; then
    case "${CODEX_HOME:-}" in
        "") instance=codex ;;
        *)  instance="${CODEX_HOME##*/}"; instance="${instance#.}" ;;
    esac
else
    case "${CLAUDE_CONFIG_DIR:-}" in
        "") instance=claude ;;
        *)  instance="${CLAUDE_CONFIG_DIR##*/}"
            instance="${instance#.}"
            ;;
    esac
fi

# Where is it? The tmux window name is the useful handle, but most windows are
# left at their default shell name -- fall back to the project directory then.
# The session comes along too: several sessions run at once and a window name
# like "dotfiles" is only unique within one of them.
where="" session=""
if [ -n "${TMUX_PANE:-}" ] && command -v tmux >/dev/null 2>&1; then
    IFS='|' read -r session where < <(
        tmux display-message -p -t "$TMUX_PANE" '#S|#W' 2>/dev/null)
fi
case "$where" in
    "" | zsh | bash | fish | sh | node | claude.exe | codex)
        where="$(basename "${CLAUDE_PROJECT_DIR:-$PWD}")"
        ;;
esac

mkdir -p "$STATE_DIR" || exit 0
# kind, state, instance, location, session -- tab separated, one line, no JSON
# parser needed. Presentation is the bar's job, so keep the fields separate.
# The instance is written in full: the bar shows the location, and reaches for
# the session, then the instance, only to tell apart two agents whose windows
# share a name.
printf '%s\t%s\t%s\t%s\t%s\n' "$kind" "$state" "$instance" "$where" "$session" > "$state_file"
notify_bar
