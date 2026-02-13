#!/usr/bin/env bash
# Install language version managers: nvm, pyenv, pipx

section "Language managers"

# nvm
if [[ ! -d "$HOME/.nvm" ]]; then
  info "Installing nvm..."
  PROFILE=/dev/null bash -c "$(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh)"
  success "nvm installed"
else
  success "nvm already installed"
fi

# pyenv
if [[ ! -d "$HOME/.pyenv" ]]; then
  info "Installing pyenv..."
  if is_linux; then
    # pyenv build dependencies
    if has_apt; then
      pkg_install make build-essential libssl-dev zlib1g-dev \
        libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
        libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
        libffi-dev liblzma-dev
    elif has_dnf; then
      pkg_install gcc make zlib-devel bzip2 bzip2-devel readline-devel \
        sqlite sqlite-devel openssl-devel tk-devel libffi-devel xz-devel \
        wget
    fi
  fi
  curl -fsSL https://pyenv.run | bash
  success "pyenv installed"
else
  success "pyenv already installed"
fi

# pipx
if ! command_exists pipx; then
  info "Installing pipx..."
  if is_macos; then
    brew install pipx
  elif is_linux; then
    if has_apt; then
      pkg_install pipx
    elif has_dnf; then
      pkg_install pipx 2>/dev/null || {
        info "pipx not in dnf repos, installing via pip..."
        pkg_install python3-pip
        python3 -m pip install --user pipx
      }
    fi
  fi
  pipx ensurepath 2>/dev/null || true
  success "pipx installed"
else
  success "pipx already installed"
fi
