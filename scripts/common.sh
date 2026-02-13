#!/usr/bin/env bash
# Shared helpers for install scripts

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

section() {
  echo ""
  echo -e "${BOLD}==> $*${NC}"
  echo ""
}

is_macos() { [[ "$OSTYPE" == darwin* ]]; }
is_linux() { [[ "$OSTYPE" == linux* ]]; }

has_apt() { command -v apt &>/dev/null; }
has_dnf() { command -v dnf &>/dev/null; }

command_exists() { command -v "$1" &>/dev/null; }

# pkg_install <packages...> — install via the system package manager
pkg_install() {
  if has_apt; then
    sudo apt install -y "$@"
  elif has_dnf; then
    sudo dnf install -y "$@"
  else
    error "No supported package manager found (apt or dnf)"
    return 1
  fi
}

# pkg_update — refresh package index
pkg_update() {
  if has_apt; then
    sudo apt update
  elif has_dnf; then
    sudo dnf check-update || true  # returns exit 100 when updates available
  fi
}
