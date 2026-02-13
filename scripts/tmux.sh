#!/usr/bin/env bash
# Install tmux and TPM

section "Tmux setup"

if ! command_exists tmux; then
  info "Installing tmux..."
  if is_macos; then
    brew install tmux
  elif is_linux; then
    pkg_install tmux
  fi
  success "tmux installed"
else
  success "tmux already installed"
fi

# Install TPM (Tmux Plugin Manager)
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  info "Installing TPM..."
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  success "TPM installed"
else
  success "TPM already installed"
fi

info "Run 'prefix + I' inside tmux to install plugins"
