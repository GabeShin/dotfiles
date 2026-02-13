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
- **Bar items (right)**: calendar, battery, volume, cpu, weather, slack
- **Helper**: C program in `helper/` for CPU stats (built via `make`)
- Integrates with AeroSpace for workspace indicators

## AeroSpace Workspace Assignments

Workspaces 1-9 are mapped to specific apps (kitty, Arc, Slack, Notion, ChatGPT, Obsidian, Postman, Docker, DBeaver). Uses `alt` as the primary modifier.

## Theme

Catppuccin Mocha is used consistently across tmux, sketchybar, and neovim (`colorscheme.lua`).
