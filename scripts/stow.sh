#!/usr/bin/env bash
# Symlink dotfiles via GNU Stow

section "Stow symlinks"

cd "$DOTFILES_DIR"

snapshot_dir="$(mktemp -d)"
snapshot_list="$snapshot_dir/files.zlist"

cleanup_snapshot() {
  rm -rf "$snapshot_dir"
}

snapshot_repo_state() {
  git -C "$DOTFILES_DIR" ls-files -z --cached --others --exclude-standard > "$snapshot_list"

  while IFS= read -r -d '' path; do
    mkdir -p "$snapshot_dir/$(dirname "$path")"
    cp -pP "$DOTFILES_DIR/$path" "$snapshot_dir/$path"
  done < "$snapshot_list"
}

restore_repo_state() {
  while IFS= read -r -d '' path; do
    mkdir -p "$DOTFILES_DIR/$(dirname "$path")"
    cp -pP "$snapshot_dir/$path" "$DOTFILES_DIR/$path"
  done < "$snapshot_list"
}

trap cleanup_snapshot EXIT
snapshot_repo_state

if is_linux; then
  info "Running stow (skipping macOS-only configs)..."
  stow --adopt . --ignore='sketchybar|\.aerospace\.toml'
else
  info "Running stow..."
  stow --adopt .
fi

# --adopt moves existing files into the repo; restore the repo state we started with
restore_repo_state

success "Dotfiles symlinked"
