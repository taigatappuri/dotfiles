#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '%s\n' "$*" >&2
}

clone_if_missing() {
  local url="$1"
  local dest="$2"

  if [[ -e "$dest" ]]; then
    return 0
  fi

  log "install: $dest"
  git clone --depth=1 "$url" "$dest" >/dev/null
}

if ! command -v git >/dev/null 2>&1; then
  log "[WARN]: git not found, cannot install zsh dependencies"
  exit 0
fi

ZSH_DIR="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$ZSH_DIR/custom}"

if [[ ! -d "$ZSH_DIR" ]]; then
  log "Cloning oh-my-zsh: $ZSH_DIR"
  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$ZSH_DIR" >/dev/null
fi

mkdir -p "$ZSH_CUSTOM_DIR/plugins" "$ZSH_CUSTOM_DIR/themes"

clone_if_missing https://github.com/romkatv/powerlevel10k.git \
  "$ZSH_CUSTOM_DIR/themes/powerlevel10k"
clone_if_missing https://github.com/zsh-users/zsh-autosuggestions.git \
  "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
clone_if_missing https://github.com/zsh-users/zsh-syntax-highlighting.git \
  "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"

log "zsh dependencies setup complete"
