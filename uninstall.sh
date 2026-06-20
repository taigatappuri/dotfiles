#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
使い方:
  ./uninstall.sh [--force] [--backup-root <path>] [--purge]

説明:
  公開レポのセットアップで入れたものを削除します。
  - chezmoi が管理しているファイル/ディレクトリ（.zshrc, .p10k.zsh, .config/gh/config.yml 等）
  - oh-my-zsh（~/.oh-my-zsh）
  - chezmoi のデータ（~/.config/chezmoi, ~/.local/share/chezmoi, ~/.cache/chezmoi, ~/.chezmoiscripts）
  - zsh（OSのパッケージマネージャがある場合）

オプション:
  --backup-root <path>  削除の代わりに退避します（指定した場合のみ）
  --purge               `chezmoi purge` を実行します（source/config/cache を削除するため注意）
  --force               確認プロンプトを省略します（危険）
EOF
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

log() {
  printf '%s\n' "$*" >&2
}

ensure_sudo() {
  :
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
  log "[WARN]: sudo not found; skipping command that requires root: $*"
  return 1
}

set_default_shell_to_bash() {
  local bash_path
  bash_path="$(command -v bash || true)"
  if [[ -z "$bash_path" ]]; then
    log "[WARN]: bash not found; skipping default shell change"
    return 0
  fi

  if have_cmd chsh && chsh -s "$bash_path" "$USER" 2>/dev/null; then
    log "Default shell set to bash: $bash_path"
    return 0
  fi

  if have_cmd usermod && run_root usermod -s "$bash_path" "$USER" 2>/dev/null; then
    log "Default shell set to bash (usermod): $bash_path"
    return 0
  fi

  log "[WARN]: failed to change the default shell automatically"
  log "Run manually: chsh -s \"$bash_path\""
  return 0
}

uninstall_zsh_package() {
  if have_cmd apt-get; then
    run_root apt-get remove --purge -y zsh || true
    run_root apt-get autoremove -y || true
    return 0
  fi
  if have_cmd dnf; then
    run_root dnf remove -y zsh || true
    return 0
  fi
  if have_cmd yum; then
    run_root yum remove -y zsh || true
    return 0
  fi
  if have_cmd pacman; then
    run_root pacman -Rns --noconfirm zsh || true
    return 0
  fi
  if have_cmd zypper; then
    run_root zypper --non-interactive remove zsh || true
    return 0
  fi
  if have_cmd brew; then
    brew uninstall zsh || true
    return 0
  fi

  log "[WARN]: package manager not found; skipping zsh removal"
  return 0
}

purge=false
backup_root=""
force=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge)
      purge=true
      shift
      ;;
    --backup-root)
      backup_root="${2:-}"
      if [[ -z "$backup_root" ]]; then
        usage
        exit 2
      fi
      shift 2
      ;;
    --force)
      force=true
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [[ "$force" != "true" ]]; then
  log "The following actions will be performed:"
  if [[ -n "$backup_root" ]]; then
    log "- Back up managed files to: $backup_root"
  else
    log "- Delete managed files without a backup"
  fi
  log "- Remove oh-my-zsh: $HOME/.oh-my-zsh"
  log "- Remove zsh configuration files such as $HOME/.zshrc"
  log "- Remove chezmoi data such as $HOME/.config/chezmoi"
  log "- Change the default shell to bash when possible"
  log "- Uninstall zsh when possible"
  if [[ "$purge" == "true" ]]; then
    log '- Run chezmoi purge'
  fi
  read -r -p "Continue? [y/N]: " answer
  case "${answer}" in
    y | Y | yes | YES) ;;
    *) exit 0 ;;
  esac
fi

if [[ "$purge" == "true" ]] && have_cmd chezmoi; then
  log 'Running chezmoi purge...'
  chezmoi purge || true
fi

managed=()
if have_cmd chezmoi; then
  mapfile -t managed < <(chezmoi managed)
fi

managed_files=()
managed_dirs=()
for rel in "${managed[@]:-}"; do
  src="${HOME}/${rel}"
  if [[ -L "$src" || -f "$src" ]]; then
    managed_files+=("$rel")
  elif [[ -d "$src" ]]; then
    managed_dirs+=("$rel")
  fi
done

sorted_managed_files="$(
  printf '%s\n' "${managed_files[@]:-}" |
    awk '{ printf "%d\t%s\n", length($0), $0 }' |
    sort -rn |
    cut -f2- |
    sed '/^$/d'
)"

sorted_managed_dirs="$(
  printf '%s\n' "${managed_dirs[@]:-}" |
    awk '{ printf "%d\t%s\n", length($0), $0 }' |
    sort -rn |
    cut -f2- |
    sed '/^$/d'
)"

if [[ -n "$backup_root" ]]; then
  mkdir -p "$backup_root"
fi

while IFS= read -r rel; do
  if [[ -z "$rel" ]]; then
    continue
  fi

  src="${HOME}/${rel}"
  if [[ ! -e "$src" && ! -L "$src" ]]; then
    continue
  fi

  if [[ -n "$backup_root" ]]; then
    dst="${backup_root}/${rel}"
    if [[ "$backup_root" == "$src" || "$backup_root" == "$src/"* ]]; then
      log "Backup destination is inside a managed path: $backup_root"
      log "Choose another destination under $HOME and run the command again"
      exit 1
    fi
    mkdir -p "$(dirname "$dst")"
    mv "$src" "$dst"
  else
    rm -f "$src"
  fi
done <<<"${sorted_managed_files:-}"

while IFS= read -r rel; do
  if [[ -z "$rel" ]]; then
    continue
  fi
  rmdir "${HOME}/${rel}" 2>/dev/null || true
done <<<"${sorted_managed_dirs:-}"

log "Removing oh-my-zsh..."
rm -rf "$HOME/.oh-my-zsh"

log "Removing zsh configuration files..."
rm -f "$HOME/.zshrc" "$HOME/.p10k.zsh" "$HOME/.zsh_history" "$HOME/.z" || true
rm -f "$HOME/.zcompdump" "$HOME/.zcompdump-"* || true

log "Removing chezmoi data..."
rm -rf "$HOME/.chezmoiscripts" "$HOME/.config/chezmoi" "$HOME/.local/share/chezmoi" "$HOME/.cache/chezmoi" || true

if have_cmd chezmoi; then
  chezmoi_path="$(command -v chezmoi || true)"
  if [[ "$chezmoi_path" == "$HOME/.local/bin/chezmoi" ]]; then
    log "Removing chezmoi: $chezmoi_path"
    rm -f "$chezmoi_path"
  fi
fi

log "Restoring bash as the default shell..."
set_default_shell_to_bash

log "Uninstalling zsh..."
uninstall_zsh_package

log "Uninstall completed (log out and back in if required)"
