# dotfiles

macOS and Linux dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Quick Start

```bash
git clone git@github.com:GabeShin/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install
```

The install script handles everything: system packages, stow symlinks, zsh + plugins, tmux + tpm, neovim, CLI tools, and language managers.

Works on **macOS**, **Ubuntu/Debian**, and **Amazon Linux 2023**.

### AeroSpace (optional, macOS only)

```bash
./install-aerospace
```

Installs the [AeroSpace](https://github.com/nikitabobko/AeroSpace) tiling window manager and [borders](https://github.com/FelixKratz/JankyBorders).

## What's Included

| Config | File/Directory | Notes |
|--------|---------------|-------|
| Neovim | `.config/nvim/` | lazy.nvim, LSP, DAP, Treesitter |
| Zsh | `.zshrc` | oh-my-zsh, powerlevel10k, autosuggestions |
| Tmux | `.tmux.conf` | catppuccin theme, tpm, vim-tmux-navigator |
| AeroSpace | `.aerospace.toml` | Tiling WM with workspace assignments |
| Sketchybar | `.config/sketchybar/` | macOS menu bar (catppuccin mocha) |

## What `./install` Does

1. **System packages** — Homebrew (macOS) or apt/dnf (Linux), plus stow, git, curl, gcc
2. **Stow symlinks** — links configs into `$HOME` (skips sketchybar on Linux)
3. **Zsh** — oh-my-zsh, powerlevel10k, zsh-autosuggestions, zsh-autocomplete, zsh-syntax-highlighting, you-should-use
4. **Tmux** — tmux + TPM (run `prefix + I` inside tmux to install plugins)
5. **Neovim** — brew on macOS, appimage on Linux (plugins auto-install on first launch)
6. **CLI tools** — eza, zoxide, lazygit, jq, fzf, ripgrep
7. **Language managers** — nvm, pyenv, pipx
8. **Sketchybar** — macOS only: sketchybar, SF Pro fonts, helper build

## Manual Steps After Install

- Open a new terminal (or `exec zsh`) to load the new shell config
- Inside tmux: `prefix + I` to install tmux plugins
- Neovim plugins and LSPs install automatically on first launch
