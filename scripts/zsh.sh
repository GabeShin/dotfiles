#!/usr/bin/env bash
# Install zsh, oh-my-zsh, and plugins

section "Zsh setup"

# Install zsh
if ! command_exists zsh; then
  info "Installing zsh..."
  if is_macos; then
    brew install zsh
  elif is_linux; then
    pkg_install zsh
  fi
  success "zsh installed"
else
  success "zsh already installed"
fi

# Install oh-my-zsh
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  info "Installing oh-my-zsh..."
  RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  success "oh-my-zsh installed"
else
  success "oh-my-zsh already installed"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Install powerlevel10k theme
if [[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
  info "Installing powerlevel10k..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
  success "powerlevel10k installed"
else
  success "powerlevel10k already installed"
fi

# Install plugins (bash 3.2 compatible — no associative arrays)
clone_plugin() {
  local name="$1" url="$2"
  if [[ ! -d "$ZSH_CUSTOM/plugins/$name" ]]; then
    info "Installing $name..."
    git clone --depth=1 "$url" "$ZSH_CUSTOM/plugins/$name"
    success "$name installed"
  else
    success "$name already installed"
  fi
}

clone_plugin zsh-autosuggestions    https://github.com/zsh-users/zsh-autosuggestions
clone_plugin zsh-autocomplete       https://github.com/marlonrichert/zsh-autocomplete
clone_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting
clone_plugin you-should-use         https://github.com/MichaelAquilina/zsh-you-should-use
