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
    pkg_install git wget gcc make perl
    # stow is not in default AL2023 repos — install from source if missing
    if ! command_exists stow; then
      info "stow not in repos, installing from source..."
      curl -fLo /tmp/stow.tar.gz https://ftp.gnu.org/gnu/stow/stow-2.4.1.tar.gz
      tar xf /tmp/stow.tar.gz -C /tmp
      (cd /tmp/stow-2.4.1 && ./configure && sudo make install)
      rm -rf /tmp/stow-2.4.1 /tmp/stow.tar.gz
      success "stow built from source"
    fi
  else
    error "No supported package manager found (need apt or dnf)"
    exit 1
  fi
  success "Core packages installed"
fi
