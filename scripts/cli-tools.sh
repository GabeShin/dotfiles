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
    x86_64)  EZA_ARCH="x86_64-unknown-linux-gnu"; LG_ARCH="Linux_x86_64" ;;
    aarch64) EZA_ARCH="aarch64-unknown-linux-gnu"; LG_ARCH="Linux_arm64" ;;
    *)       warn "Unsupported architecture: $ARCH — some tools may be skipped" ;;
  esac

  # jq, fzf, ripgrep — available in both apt and dnf
  info "Installing jq, fzf, ripgrep..."
  pkg_install jq fzf ripgrep

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
