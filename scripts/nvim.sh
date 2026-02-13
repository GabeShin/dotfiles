#!/usr/bin/env bash
# Install Neovim

section "Neovim setup"

if ! command_exists nvim; then
  info "Installing neovim..."
  if is_macos; then
    brew install neovim
  elif is_linux; then
    ARCH=$(uname -m)
    case "$ARCH" in
      x86_64)  NVIM_APPIMAGE="nvim-linux-x86_64.appimage" ;;
      aarch64) NVIM_APPIMAGE="nvim-linux-arm64.appimage" ;;
      *)       error "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    info "Downloading neovim appimage ($ARCH)..."
    curl -fLo /tmp/nvim.appimage "https://github.com/neovim/neovim/releases/latest/download/${NVIM_APPIMAGE}"
    chmod u+x /tmp/nvim.appimage
    # Extract instead of running directly — avoids FUSE dependency on Amazon Linux / containers
    (
      cd /tmp
      ./nvim.appimage --appimage-extract >/dev/null 2>&1
    )
    sudo rm -rf /opt/nvim
    sudo mv /tmp/squashfs-root /opt/nvim
    sudo ln -sf /opt/nvim/AppRun /usr/local/bin/nvim
    rm -f /tmp/nvim.appimage
  fi
  success "neovim installed"
else
  success "neovim already installed"
fi

info "Lazy.nvim and Mason will auto-install plugins/LSPs on first launch"
