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

`agent-notify/agent-notify.sh` records when a Claude Code or Codex agent wants
you, and the sketchybar `agent_notify` item draws one chip per agent in the
**centre** of the bar, labelled with that agent's tmux window name. State is one
file per agent under `~/.cache/agent-notify`, keyed by tmux pane id; the file
records kind, state, instance and location as separate tab-separated fields so
the bar owns presentation.

Centre, not right: a blocked agent is an interrupt, and the middle of the screen
is where the eye already is. The centre is otherwise empty, so the cluster costs
nothing when nothing is waiting.

One chip per agent rather than one label for all of them, because the two states
mean different things and used to be flattened into whichever was loudest -- a
single blocked agent turned the whole badge red, hiding that the others had
merely finished. The states are told apart by **fill, not hue**: blocked is a
solid pill, finished is plain text. Red-vs-green is the pair that collapses
under the common colour-vision deficiencies, and it is also the wrong emphasis,
since only one of the two states is asking you for anything.

**Clicking a chip goes to that agent** -- switches the tmux client to its
session, selects its window and pane, and raises kitty. Dismissing was all the
old badge could do, which left you knowing that *something* wanted you and still
hunting for it. Right-click clears a single chip; clicking the (invisible)
anchor clears everything.

Several panes legitimately share a window name -- three windows called
`dotfiles` is normal -- so a colliding name earns the instance that
distinguishes it (`dotfiles·worker-2`), and only then. The instance is recorded
in full: it is no longer a bar label, so there is nothing to abbreviate for
width.

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

Chips never time out. A Claude chip clears when you send that session its next
prompt (`UserPromptSubmit`) or quit it (`SessionEnd`). Codex has no "user
replied" event, so codex chips clear once you are visibly looking at their pane
-- kitty frontmost and the pane active in an attached client, re-checked every
`update_freq=5` seconds.

What is currently drawn is read back from sketchybar rather than remembered in a
file: `--reload` wipes every item, so a note on disk would go on claiming the
chips existed for as long as the bar ran without them.

Claude Code reads hooks at startup — running sessions need a restart.

## Agent Usage

`agent-usage/agent-usage.sh` feeds the sketchybar `agent_usage` item, which
shows every Claude / Codex subscription at once, so an unbalanced week is
visible before it is expensive. The bar draws one small bar chart per account --
a fixed slot each, height by weekly usage, against a faint track -- followed by
an arrow naming **where to work next**. A maxed-out account fills its slot and
turns the icon orange; it is recorded as 100% because whatever the exact figure,
none of it is available to you. Clicking any part of the row opens the full
table, which also offers a forced refresh.

Each account is its own sketchybar item, not a cell in one label. A label is a
single string with a single colour, so the previous sparkline had to pick one
colour for all six accounts, and it chose the worst account's -- painting five
healthy accounts in the colour of the one that was spent. The distribution was
the entire reason to draw six cells, and it was the one thing the drawing could
not express.

The trailing hint names the account with the most room in whichever window would
stop it first, because a low weekly figure is no use if the five-hour window is
nearly spent. It used to name the *busiest* account, which is the one account
you already cannot use.

The slots are allocated empty at config-parse time by `items/agent_usage.sh`,
not created on demand. Right-hand items are laid out from the right edge inward
in the order they are added, but only while the config is being parsed; items
added later, at runtime, land at the far right of the bar instead. Allocating
the slots up front is what keeps the cluster beside its icon and off the clock's
toes. Unused slots draw nothing, so the pool is simply generous (12), and a new
account fills the next free one without a reload.

The bars need the faint track behind them: eighth-block characters grow from the
baseline, so without one a quiet account is a two-pixel dash floating in space,
indistinguishable from a rendering artefact and impossible to read a height
against. The divider between Claude and Codex is `┃`; `┊` renders as blank space
in this font, which made the two halves look like one row with a gap in it.

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
- **Claude, when idle or maxed out** — an account nobody has opened never runs
  its status line, and an exhausted one *cannot* open a session at all, so the
  account most worth seeing was the one that never reported. A one-turn
  `claude -p --output-format stream-json` settles both: it emits a
  `rate_limit_event` whose `unifiedWindows` carry the same five-hour and
  seven-day figures the status line does, plus real `resetsAt` epochs — and it
  emits them on a *refused* request too. `utilization` there is a fraction, not
  a percentage. A refused probe costs nothing (`total_cost_usd: 0`, zero
  tokens), so a spent account is re-checked every thirty minutes; a successful
  one spends a turn, so an account that already has numbers is only re-measured
  daily. The intervals run from the last write by *either* collector, and the
  status line writes on every repaint — so an account you actually work in keeps
  itself fresh for nothing and is never probed. Only idle accounts spend a turn. The probe runs haiku from
  an empty directory — the windows are account-wide, so the cheapest model
  reports the same numbers, and not loading a CLAUDE.md cuts the cost about
  tenfold.

  Two rules keep the probe from fighting the status line: it never blanks a
  sample it failed to refresh, and it will not mark an account signed out while
  a live session is still reporting real numbers for it (a credential can be
  too stale for a new process while an open session still holds a working
  token).
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

Each account's bar carries its own colour, so a spent account is red while the
healthy ones stay green. The icon speaks for the cluster and so carries what no
single account's colour can: orange when an account is out of quota, red when
one is signed out -- the one problem no percentage can express.

Both collectors take a lock before running. A lock is a directory plus the
owner's pid: `mkdir` is the atomic part, and the pid is what lets the next run
tell "still working" from "died holding it" — without it a leaked lock silently
disables collection until it ages out.

Two things that are easy to get wrong here:

- `codex app-server` exits when stdin closes, which happens before the async
  reply arrives — the poller holds the pipe open until it answers.
- sketchybar starts at login with a bare PATH that cannot see `codex` (nvm
  keeps it in a versioned directory), so the script extends PATH itself,
  newest node first. Older node versions can be left with a broken or
  XProtect-removed vendor binary, so version order matters.
- `local a="$1" b="$DIR/$a"` does not work: bash expands every argument to
  `local` before assigning any of them, so `$a` is either unset (with `set -u`)
  or, worse, a leftover from the caller's scope. Declare on separate lines.
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
