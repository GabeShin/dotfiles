#!/usr/bin/env bash
# Symlink dotfiles via GNU Stow

section "Stow symlinks"

cd "$DOTFILES_DIR"

if is_linux; then
  info "Running stow (skipping macOS-only configs)..."
  stow --adopt . --ignore='sketchybar'
else
  info "Running stow..."
  stow --adopt .
fi

# --adopt moves existing files into the repo; restore our versions
git -C "$DOTFILES_DIR" checkout .

success "Dotfiles symlinked"
