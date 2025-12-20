#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
EOF
}

log() {
  printf '%s\n' "$*" >&2
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

run_root() {
  if [[ "${EUID:-0}" -eq 0 ]]; then
    "$@"
    return $?
  fi
  if have_cmd sudo; then
    sudo "$@"
    return $?
  fi
  log "[WARN]: sudo command not found, skipping command that requires root: $*"
  return 1
}

install_packages() {
  if have_cmd apt-get; then
    run_root apt-get update -y || return 0
    run_root apt-get install -y zsh git curl ca-certificates || return 0
    return 0
  fi
  if have_cmd dnf; then
    run_root dnf install -y zsh git curl ca-certificates || return 0
    return 0
  fi
  if have_cmd yum; then
    run_root yum install -y zsh git curl ca-certificates || return 0
    return 0
  fi
  if have_cmd pacman; then
    run_root pacman -Sy --noconfirm zsh git curl ca-certificates || return 0
    return 0
  fi
  if have_cmd zypper; then
    run_root zypper --non-interactive install zsh git curl ca-certificates || return 0
    return 0
  fi
  if have_cmd brew; then
    brew install zsh git curl || true
    return 0
  fi

  log "[WARN]: can not find a package manager, skipping automatic installation of zsh"
  return 0
}

set_default_shell_to_zsh() {
  if ! have_cmd zsh; then
    log "[WARN]: zsh not found, skipping default shell change"
    return 0
  fi

  local zsh_path
  zsh_path="$(command -v zsh)"

  if [[ -r /etc/shells ]] && ! grep -qx "$zsh_path" /etc/shells; then
    log "[WARN]: /etc/shells does not contain $zsh_path, attempting to add it"
    run_root sh -c "printf '%s\n' '$zsh_path' >> /etc/shells" || true
  fi

  if have_cmd chsh && chsh -s "$zsh_path" "$USER" 2>/dev/null; then
    log "Default shell set to zsh: $zsh_path"
    return 0
  fi

  if have_cmd usermod && run_root usermod -s "$zsh_path" "$USER" 2>/dev/null; then
    log "Default shell set to zsh (usermod): $zsh_path"
    return 0
  fi

  log "[WARN]: failed to automatically change the default shell"
  log "Please run manually: chsh -s \"$zsh_path\""
  return 0
}

install_chezmoi_if_missing() {
  if have_cmd chezmoi; then
    return 0
  fi

  if ! have_cmd curl; then
    log "[WARN]: curl not found, cannot automatically install chezmoi"
    return 1
  fi

  log "Installing chezmoi: $HOME/.local/bin"
  mkdir -p "$HOME/.local/bin"
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$PATH"

  if ! have_cmd chezmoi; then
    log "[WARN]: failed to install chezmoi"
    return 1
  fi
}

repo="${1:-${CHEZMOI_REPO:-}}"

log "Preparing zsh / git / curl..."
install_packages

log "Setting default shell to zsh..."
set_default_shell_to_zsh

log "Preparing chezmoi..."
install_chezmoi_if_missing

log "Applying dotfiles..."
if [[ -n "${repo}" ]]; then
  chezmoi init --apply "$repo"
else
  script_dir="$(cd -- "$(dirname -- "$0")" && pwd -P)"
  if [[ ! -e "$script_dir/dot_zshrc" ]]; then
    log "[ERROR]: git-repo not specified and chezmoi source not found in this directory: $script_dir"
    log "[HINT]: Run ./install.sh in the directory where you cloned the repository"
    exit 2
  fi
  chezmoi -S "$script_dir" apply
fi

if [[ -x "$HOME/.chezmoiscripts/10-install-zsh-deps.sh" ]]; then
  log "Setting up oh-my-zsh and others..."
  "$HOME/.chezmoiscripts/10-install-zsh-deps.sh" || true
fi

log "Done (please log out/in if necessary to apply the default shell)"
