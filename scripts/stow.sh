#!/usr/bin/env bash
# Symlink dotfiles via GNU Stow

section "Stow symlinks"

cd "$DOTFILES_DIR"

if is_linux; then
  info "Running stow (skipping macOS-only configs)..."
  stow . --ignore='sketchybar'
else
  info "Running stow..."
  stow .
fi

success "Dotfiles symlinked"
