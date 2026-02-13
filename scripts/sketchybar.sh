#!/usr/bin/env bash
# macOS only: Install sketchybar and dependencies

section "Sketchybar setup"

info "Installing sketchybar and jq via brew..."
brew install sketchybar jq

info "Installing fonts..."
brew install --cask font-sf-pro sf-symbols

# Build the C helper
HELPER_DIR="$HOME/.config/sketchybar/helper"
if [[ -d "$HELPER_DIR" ]]; then
  info "Building sketchybar helper..."
  make -C "$HELPER_DIR"
  success "Sketchybar helper built"
else
  warn "Sketchybar helper directory not found at $HELPER_DIR (run stow first)"
fi

success "Sketchybar setup complete"
