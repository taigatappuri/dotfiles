#!/usr/bin/env bash
set -euo pipefail

configured_items=()
warning_items=()

log() {
  printf '%s\n' "$*" >&2
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

mark_configured() {
  configured_items+=("$1")
}

mark_warning() {
  warning_items+=("$1")
  log "[WARN]: $1"
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

  mark_warning "sudo command not found, skipped command that requires root: $*"
  return 1
}

install_packages_if_needed() {
  local missing=()
  local cmd

  for cmd in zsh git curl; do
    if ! have_cmd "$cmd"; then
      missing+=("$cmd")
    fi
  done

  if have_cmd apt-get && ! dpkg-query -W -f='${Status}' ca-certificates 2>/dev/null | grep -q 'install ok installed'; then
    missing+=(ca-certificates)
  fi

  if [[ "${#missing[@]}" -eq 0 ]]; then
    return 0
  fi

  log "Installing missing packages: ${missing[*]}"
  if have_cmd apt-get; then
    run_root apt-get update -y || return 0
    run_root apt-get install -y zsh git curl ca-certificates || return 0
    mark_configured "packages installed: zsh git curl ca-certificates"
    return 0
  fi
  if have_cmd dnf; then
    run_root dnf install -y zsh git curl ca-certificates || return 0
    mark_configured "packages installed: zsh git curl ca-certificates"
    return 0
  fi
  if have_cmd yum; then
    run_root yum install -y zsh git curl ca-certificates || return 0
    mark_configured "packages installed: zsh git curl ca-certificates"
    return 0
  fi
  if have_cmd pacman; then
    run_root pacman -Sy --noconfirm zsh git curl ca-certificates || return 0
    mark_configured "packages installed: zsh git curl ca-certificates"
    return 0
  fi
  if have_cmd zypper; then
    run_root zypper --non-interactive install zsh git curl ca-certificates || return 0
    mark_configured "packages installed: zsh git curl ca-certificates"
    return 0
  fi
  if have_cmd brew; then
    brew install zsh git curl || true
    mark_configured "packages installed: zsh git curl"
    return 0
  fi

  mark_warning "can not find a package manager, skipped package installation: ${missing[*]}"
}

current_login_shell() {
  if have_cmd getent; then
    getent passwd "$USER" | awk -F: '{ print $7 }'
    return 0
  fi

  printf '%s\n' "${SHELL:-}"
}

set_default_shell_to_zsh_if_needed() {
  if ! have_cmd zsh; then
    mark_warning "zsh not found, skipped default shell change"
    return 0
  fi

  local zsh_path
  local current_shell
  zsh_path="$(command -v zsh)"
  current_shell="$(current_login_shell)"
  if [[ "$current_shell" == "$zsh_path" ]]; then
    return 0
  fi

  if [[ -r /etc/shells ]] && ! grep -qx "$zsh_path" /etc/shells; then
    run_root sh -c "printf '%s\n' '$zsh_path' >> /etc/shells" || true
  fi

  if have_cmd chsh && chsh -s "$zsh_path" "$USER" 2>/dev/null; then
    mark_configured "default shell set to zsh: $zsh_path"
    return 0
  fi
  if have_cmd usermod && run_root usermod -s "$zsh_path" "$USER" 2>/dev/null; then
    mark_configured "default shell set to zsh: $zsh_path"
    return 0
  fi

  mark_warning "failed to automatically change the default shell; run manually: chsh -s \"$zsh_path\""
}

install_chezmoi_if_needed() {
  if have_cmd chezmoi; then
    return 0
  fi
  if ! have_cmd curl; then
    mark_warning "curl not found, cannot automatically install chezmoi"
    return 1
  fi

  mkdir -p "$HOME/.local/bin"
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$PATH"
  if have_cmd chezmoi; then
    mark_configured "chezmoi installed: $HOME/.local/bin"
    return 0
  fi

  mark_warning "failed to install chezmoi"
  return 1
}

apply_dotfiles_if_needed() {
  local script_dir="$1"
  local diff_output

  if [[ ! -e "$script_dir/dot_zshrc" ]]; then
    log "[ERROR]: chezmoi source not found in this directory: $script_dir"
    exit 2
  fi

  diff_output="$(chezmoi -S "$script_dir" diff)"
  if [[ -z "$diff_output" ]]; then
    return 0
  fi

  chezmoi -S "$script_dir" apply
  mark_configured "dotfiles applied"
}

install_zsh_dependencies_if_needed() {
  local script_path="$HOME/.chezmoiscripts/10-install-zsh-deps.sh"
  local zsh_dir="${ZSH:-$HOME/.oh-my-zsh}"
  local zsh_custom_dir="${ZSH_CUSTOM:-$zsh_dir/custom}"
  local missing=()

  [[ -d "$zsh_dir" ]] || missing+=("oh-my-zsh")
  [[ -d "$zsh_custom_dir/themes/powerlevel10k" ]] || missing+=("powerlevel10k")
  [[ -d "$zsh_custom_dir/plugins/zsh-autosuggestions" ]] || missing+=("zsh-autosuggestions")
  [[ -d "$zsh_custom_dir/plugins/zsh-syntax-highlighting" ]] || missing+=("zsh-syntax-highlighting")

  if [[ "${#missing[@]}" -eq 0 ]]; then
    return 0
  fi
  if [[ ! -x "$script_path" ]]; then
    mark_warning "zsh dependency installer not found: $script_path"
    return 0
  fi

  "$script_path" || {
    mark_warning "failed to install zsh dependencies: ${missing[*]}"
    return 0
  }
  mark_configured "zsh dependencies installed: ${missing[*]}"
}

print_summary() {
  if [[ "${#configured_items[@]}" -eq 0 && "${#warning_items[@]}" -eq 0 ]]; then
    log "No unapplied settings found."
  elif [[ "${#configured_items[@]}" -eq 0 ]]; then
    log "Configured:"
    log "  - none"
  else
    log "Configured:"
    printf '  - %s\n' "${configured_items[@]}" >&2
  fi

  if [[ "${#warning_items[@]}" -gt 0 ]]; then
    log "Warnings:"
    printf '  - %s\n' "${warning_items[@]}" >&2
  fi
}

main() {
  local script_dir
  script_dir="$(cd -- "$(dirname -- "$0")" && pwd -P)"

  install_packages_if_needed
  set_default_shell_to_zsh_if_needed
  install_chezmoi_if_needed || {
    print_summary
    exit 1
  }
  apply_dotfiles_if_needed "$script_dir"
  install_zsh_dependencies_if_needed
  print_summary
}

main "$@"
