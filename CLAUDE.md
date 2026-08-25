# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

macOS dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/). The repo root is the stow package — running `stow .` from `~/dotfiles` symlinks everything into `$HOME`.

## Applying Changes

```bash
cd ~/dotfiles && stow .
```

After editing configs, the symlinks mean changes take effect immediately for most tools. Specific reload commands:

- **tmux**: `prefix + r` (bound to `source-file ~/.tmux.conf`)
- **sketchybar**: `sketchybar --reload` or restart via aerospace (launches on startup)
- **aerospace**: enter service mode (`alt+shift+;`) then press `esc` to reload config
- **nvim**: restart neovim (lazy.nvim auto-detects plugin changes)

## Repository Structure

```
.aerospace.toml          # AeroSpace tiling window manager
.tmux.conf               # tmux with catppuccin theme, tpm plugins
.zshrc                   # zsh with oh-my-zsh, powerlevel10k, pyenv, nvm
.config/
  nvim/                  # Neovim config (lazy.nvim)
  sketchybar/            # macOS menu bar replacement
  agent-notify/          # Claude Code / Codex "turn finished" -> sketchybar badge
  agent-usage/           # Claude / Codex subscription quota -> sketchybar readout
```

## Neovim Architecture

Entry point: `init.lua` → loads `gabe.core` (options, keymaps) then `gabe.lazy` (plugin manager).

Lazy.nvim imports plugins from these subdirectories under `lua/gabe/plugins/`:

| Directory   | Purpose |
|-------------|---------|
| `(root)`    | General plugins (telescope, treesitter, nvim-tree, harpoon, bufferline, etc.) |
| `lsp/`      | Mason + lspconfig |
| `llm/`      | AI assistants (copilot) |
| `mini/`     | mini.nvim modules (surround, pairs, comment, move, etc.) |
| `note/`     | Obsidian, markdown-preview, render-markdown |
| `debug/`    | DAP + dapui + python debug adapter |
| `python/`   | venv-selector |

Each plugin file returns a lazy.nvim plugin spec table. The leader key is `space`.

## Sketchybar Architecture

`sketchybarrc` is the entry point. It sources `colors.sh` and `icons.sh`, then loads items from `items/` directory. Each item has a corresponding script in `plugins/`.

- **Theme**: Catppuccin (Mocha) — color definitions in `colors.sh`
- **Bar items (left)**: apple menu, aerospace workspaces, front app
- **Bar items (right)**: calendar, battery, volume, cpu, weather, slack, agent_notify
- **Helper**: C program in `helper/` for CPU stats (built via `make`)
- Integrates with AeroSpace for workspace indicators

## Agent Notifications

`agent-notify/agent-notify.sh` badges the sketchybar `agent_notify` item when a
Claude Code or Codex agent finishes a turn, labelled with each agent's tmux
window name (e.g. `pokemon  dotfiles  act-2`). State is one file per agent under
`~/.cache/agent-notify`, keyed by tmux pane id; the file records kind, state,
instance and location as separate tab-separated fields so the bar owns
presentation.

**The wiring lives outside this repo** and is not stowed, so a fresh machine
needs it re-added by hand:

- `~/.claude/settings.json` and `~/.claude-worker-{1,2,3}/settings.json` — a
  `hooks` block per file. Each worker has its own independent settings.json
  (only `skills` is symlinked back to `~/.claude`), so all four need it.
  `Stop` -> `claude-done`, `Notification` -> `claude-waiting`,
  `UserPromptSubmit`/`SessionEnd` -> `claude-clear`.
- `~/.codex/config.toml` — `notify = ["<abs path>/agent-notify.sh", "codex-done"]`.
  Must be an absolute path: `notify` is exec'd, not run through a shell.
  `~/.codex-work/config.toml` is a symlink to this file, so both share it.

Badges never time out. A Claude badge clears when you send that session its
next prompt (`UserPromptSubmit`) or quit it (`SessionEnd`). Codex has no "user
replied" event, so codex badges clear once you are visibly looking at their pane
-- kitty frontmost and the pane active in an attached client, re-checked every
`update_freq=5` seconds. Clicking the badge dismisses everything.

Claude Code reads hooks at startup — running sessions need a restart.

## Agent Usage

`agent-usage/agent-usage.sh` feeds the sketchybar `agent_usage` item, which
shows every Claude / Codex subscription at once, so an unbalanced week is
visible before it is expensive. The bar draws a sparkline -- one fixed cell per
account, height by weekly usage -- and names the busiest account once it passes
50%. Clicking opens the full table, which also offers a forced refresh.

The account list comes from the config dirs (`~/.claude`, `~/.claude-worker-*`,
`~/.codex`, `~/.codex-*`), not from which state files happen to exist. An
account you have not opened yet still gets a cell (`·` = not measured, `!` =
signed out); leaving it out entirely would read as "fine" when it means
"unknown", which is exactly the account you might then overload. A new worker
dir shows up on its own, and the cell order never shifts.

Both halves read real server-reported quota, and neither needs a token, a
network call of our own, or a login:

- **Claude** (`claude`, `claude-worker-1..3`) — Claude Code >= 2.1 hands
  `rate_limits.five_hour` / `.seven_day` to the `statusLine` command on stdin.
  The script is that status line: it writes the state file and echoes a line
  back for the session. Free, but it only updates while a session is running,
  so an untouched account goes stale (the bar dims its icon and the popup says
  how old the sample is).
- **Codex** (`codex`, `codex-work`) — no equivalent push, so ask the
  app-server: JSON-RPC `account/rateLimits/read` over `codex app-server`, with
  `CODEX_HOME` selecting the account. Live, but it costs a subprocess, so
  samples are cached (5 min, or 30 min for a signed-out account). The bar asks
  every tick and the script decides whether a poll is actually due.

State is one file per account under `~/.cache/agent-usage`, tab separated —
`kind, label, status, five_pct, week_pct, week_resets_at, updated_at, plan` —
same split as agent-notify, so the bar owns presentation. Accounts are named in
full here (`claude-worker-2`, not agent-notify's `w2`): this item shows one at a
time and has the room, and the full name is the one you type. `status` is `ok`,
`auth` (signed out; the popup prints the `codex login` command to fix it) or
`unknown` (no subscription quota, e.g. an API-key session). Unmeasured numbers
are `-`, never `0`, so idle and unknown stay distinguishable.

The popup is a table, so its rows use a monospace face and fixed-width cells,
with a ten-cell gauge for each window (weekly and five-hour) -- a bar is far
easier to compare down a column than digits are. Both the sparkline and the
table need the monospace face, or the block characters fall back to uneven
widths and stop lining up.

The bar's colour tracks the busiest weekly percentage; the icon turns red only
when an account is signed out, because that is the one problem no percentage
can express.

Two things that are easy to get wrong here:

- `codex app-server` exits when stdin closes, which happens before the async
  reply arrives — the poller holds the pipe open until it answers.
- sketchybar starts at login with a bare PATH that cannot see `codex` (nvm
  keeps it in a versioned directory), so the script extends PATH itself,
  newest node first. Older node versions can be left with a broken or
  XProtect-removed vendor binary, so version order matters.
- A statusLine payload can arrive with no `rate_limits` at all -- early in a
  session, or on a repaint that raced the first response. Writing that through
  would erase a good number, so a quota-less payload never overwrites an
  account that has already reported; its sample just ages instead.

**The Claude wiring lives outside this repo** and is not stowed, so a fresh
machine needs it re-added by hand — a `statusLine` block in each of
`~/.claude/settings.json` and `~/.claude-worker-{1,2,3}/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "\"$HOME\"/.config/agent-usage/agent-usage.sh claude-statusline"
}
```

## AeroSpace Workspace Assignments

Workspaces 1-9 are mapped to specific apps (kitty, Arc, Slack, Notion, ChatGPT, Obsidian, Postman, Docker, DBeaver). Uses `alt` as the primary modifier.

## Theme

Catppuccin Mocha is used consistently across tmux, sketchybar, and neovim (`colorscheme.lua`).
