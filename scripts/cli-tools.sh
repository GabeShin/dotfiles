#!/usr/bin/env bash
# Install CLI tools: eza, zoxide, lazygit, jq, fzf, ripgrep

section "CLI tools"

if is_macos; then
  info "Installing CLI tools via brew..."
  brew install eza zoxide lazygit jq fzf ripgrep
  success "CLI tools installed"

elif is_linux; then
  # Detect architecture
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64)  EZA_ARCH="x86_64-unknown-linux-gnu"; LG_ARCH="Linux_x86_64"; FZF_ARCH="linux_amd64"; RG_ARCH="x86_64-unknown-linux-musl" ;;
    aarch64) EZA_ARCH="aarch64-unknown-linux-gnu"; LG_ARCH="Linux_arm64"; FZF_ARCH="linux_arm64"; RG_ARCH="aarch64-unknown-linux-gnu" ;;
    *)       warn "Unsupported architecture: $ARCH — some tools may be skipped" ;;
  esac

  # jq — available in both apt and dnf
  info "Installing jq..."
  pkg_install jq

  # fzf
  if ! command_exists fzf; then
    info "Installing fzf..."
    if has_apt; then
      pkg_install fzf
    else
      FZF_VERSION=$(curl -s "https://api.github.com/repos/junegunn/fzf/releases/latest" | grep -Po '"tag_name": "v?\K[^"]*')
      curl -fLo /tmp/fzf.tar.gz "https://github.com/junegunn/fzf/releases/latest/download/fzf-${FZF_VERSION}-${FZF_ARCH}.tar.gz"
      tar xf /tmp/fzf.tar.gz -C /tmp fzf
      sudo install /tmp/fzf /usr/local/bin
      rm -f /tmp/fzf /tmp/fzf.tar.gz
    fi
    success "fzf installed"
  else
    success "fzf already installed"
  fi

  # ripgrep
  if ! command_exists rg; then
    info "Installing ripgrep..."
    if has_apt; then
      pkg_install ripgrep
    else
      RG_VERSION=$(curl -s "https://api.github.com/repos/BurntSushi/ripgrep/releases/latest" | grep -Po '"tag_name": "\K[^"]*')
      curl -fLo /tmp/rg.tar.gz "https://github.com/BurntSushi/ripgrep/releases/latest/download/ripgrep-${RG_VERSION}-${RG_ARCH}.tar.gz"
      tar xf /tmp/rg.tar.gz -C /tmp
      sudo install "/tmp/ripgrep-${RG_VERSION}-${RG_ARCH}/rg" /usr/local/bin
      rm -rf "/tmp/ripgrep-${RG_VERSION}-${RG_ARCH}" /tmp/rg.tar.gz
    fi
    success "ripgrep installed"
  else
    success "ripgrep already installed"
  fi

  # eza
  if ! command_exists eza; then
    info "Installing eza..."
    if has_apt; then
      sudo mkdir -p /etc/apt/keyrings
      wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
      echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
      sudo apt update
      sudo apt install -y eza
    elif has_dnf; then
      sudo dnf install -y eza 2>/dev/null || {
        info "eza not in dnf repos, installing from GitHub..."
        curl -fLo /tmp/eza.tar.gz "https://github.com/eza-community/eza/releases/latest/download/eza_${EZA_ARCH}.tar.gz"
        tar xf /tmp/eza.tar.gz -C /tmp
        sudo install /tmp/eza /usr/local/bin
        rm -f /tmp/eza /tmp/eza.tar.gz
      }
    fi
    success "eza installed"
  else
    success "eza already installed"
  fi

  # zoxide
  if ! command_exists zoxide; then
    info "Installing zoxide..."
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    success "zoxide installed"
  else
    success "zoxide already installed"
  fi

  # lazygit
  if ! command_exists lazygit; then
    info "Installing lazygit..."
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    curl -fLo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_${LG_ARCH}.tar.gz"
    tar xf /tmp/lazygit.tar.gz -C /tmp lazygit
    sudo install /tmp/lazygit /usr/local/bin
    rm -f /tmp/lazygit /tmp/lazygit.tar.gz
    success "lazygit installed"
  else
    success "lazygit already installed"
  fi

  success "CLI tools installed"
fi
