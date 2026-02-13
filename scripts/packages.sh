#!/usr/bin/env bash
# Install core system packages

section "System packages"

if is_macos; then
  if ! command_exists brew; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for the rest of this session
    if [[ -f /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
    success "Homebrew installed"
  else
    success "Homebrew already installed"
  fi

  info "Installing core packages via brew..."
  brew install stow git curl make
  success "Core packages installed"

elif is_linux; then
  info "Updating package index and installing core packages..."
  pkg_update
  if has_apt; then
    pkg_install stow git curl wget gpg build-essential
  elif has_dnf; then
    sudo dnf groupinstall -y "Development Tools"
    pkg_install stow git curl wget gcc make
  else
    error "No supported package manager found (need apt or dnf)"
    exit 1
  fi
  success "Core packages installed"
fi
