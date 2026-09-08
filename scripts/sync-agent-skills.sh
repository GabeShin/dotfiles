#!/usr/bin/env bash
# Sync canonical agent skills from ~/dotfiles/agent-skills into a repo's
# .claude/skills/.
#
#   scripts/sync-agent-skills.sh ~/personal/jaksam
#   scripts/sync-agent-skills.sh ~/personal/jaksam ~/personal/agent-rotom
#   scripts/sync-agent-skills.sh --check ~/personal/jaksam     # report drift only
#
# These are NOT symlinked. The skill has to survive being read from a fresh
# clone or a CI checkout, where nothing outside the repo exists -- so it is a
# real copy, committed to the repo. That means it can drift, which is what
# --check is for.
#
# agent-skills/ is excluded from stow (see .stow-local-ignore): it is a source
# directory, not something to link into $HOME.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/agent-skills"
CHECK=0
DRIFT=0
[ "${1:-}" = "--check" ] && { CHECK=1; shift; }

[ $# -eq 0 ] && { echo "usage: $(basename "$0") [--check] <repo-path>..." >&2; exit 2; }

for repo in "$@"; do
  if [ ! -d "$repo/.git" ]; then
    echo "!! $repo is not a git repo -- skipped" >&2
    continue
  fi
  echo "==> $repo"
  for skill in "$SRC"/*/; do
    name="$(basename "$skill")"
    dest="$repo/.claude/skills/$name"
    if [ "$CHECK" = 1 ]; then
      if [ ! -d "$dest" ]; then
        echo "    $name: ABSENT"
        DRIFT=1
      elif diff -rq "$skill" "$dest" >/dev/null 2>&1; then
        echo "    $name: in sync"
      else
        echo "    $name: DRIFTED"
        # `|| true`: diff exits 1 when files differ, and under `set -o pipefail`
        # that non-zero propagates through the pipe and set -e kills the loop --
        # so checking two repos only ever reported the first one to drift. A
        # drift reporter that stops at the first drift is worse than none.
        { diff -rq "$skill" "$dest" 2>&1 || true; } | sed 's/^/        /'
        DRIFT=1
      fi
    else
      mkdir -p "$(dirname "$dest")"
      rm -rf "$dest"
      cp -R "$skill" "$dest"
      chmod +x "$dest"/scripts/*.sh 2>/dev/null || true
      echo "    $name: synced"
    fi
  done
done

if [ "$CHECK" = 1 ]; then
  # Non-zero means "drift found", after reporting every repo -- not "gave up".
  exit "$DRIFT"
fi

cat <<'EOF'

Copies are written but not committed -- review and commit them in each repo.
EOF
