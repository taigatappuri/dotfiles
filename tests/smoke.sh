#!/usr/bin/env bash
set -euo pipefail

readonly CI_OS="${CI_OS:-unknown}"
readonly SOURCE_DIR="${SOURCE_DIR:-/workspace}"
readonly CHEZMOI_VERSION="${CHEZMOI_VERSION:-2.70.1}"
readonly CHEZMOI_SHA256="3bd054238e2a95548eee62a6c5b4d9d1352f2c6c69c6d32f3d1964878398f91a"
readonly TEST_USER="dotfiles-ci"
readonly TEST_HOME="/home/$TEST_USER"

log() {
  printf '[%s] %s\n' "$CI_OS" "$*" >&2
}

fail() {
  log "Failure: $*"
  exit 1
}

install_dependencies() {
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      bash ca-certificates coreutils curl diffutils findutils git passwd tar zsh
    return
  fi

  if command -v dnf >/dev/null 2>&1; then
    dnf install -y \
      bash ca-certificates coreutils curl diffutils findutils git shadow-utils tar zsh
    return
  fi

  if command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm \
      bash ca-certificates coreutils curl diffutils findutils git shadow tar zsh
    return
  fi

  fail 'No supported package manager was found'
}

install_chezmoi() {
  local archive
  local archive_name

  archive_name="chezmoi_${CHEZMOI_VERSION}_linux_amd64.tar.gz"
  archive="$(mktemp)"
  curl --fail --location --silent --show-error \
    "https://github.com/twpayne/chezmoi/releases/download/v${CHEZMOI_VERSION}/${archive_name}" \
    --output "$archive"
  printf '%s  %s\n' "$CHEZMOI_SHA256" "$archive" | sha256sum --check --status
  tar --extract --gzip --file "$archive" --directory /usr/local/bin chezmoi
  rm -f "$archive"
  chezmoi --version
}

prepare_test_user() {
  local source_copy="$1"

  useradd --create-home --shell /bin/bash "$TEST_USER"
  cp -a "$SOURCE_DIR/." "$source_copy/"

  # 外部リポジトリの取得はCIの適用検査から分離する。
  rm -rf "$source_copy/dot_chezmoiscripts"
  chown -R "$TEST_USER:$TEST_USER" "$source_copy" "$TEST_HOME"
}

run_as_test_user() {
  runuser --user "$TEST_USER" -- \
    env HOME="$TEST_HOME" USER="$TEST_USER" \
    PATH=/usr/local/bin:/usr/bin:/bin "$@"
}

apply_dotfiles() {
  local source_copy="$1"

  run_as_test_user chezmoi --source "$source_copy" apply
}

hash_managed_files() {
  local output_file="$1"
  local relative_path
  local -a managed_files=(
    .bashrc
    .local/bin/env
    .p10k.zsh
    .profile
    .zshrc
  )

  : >"$output_file"
  for relative_path in "${managed_files[@]}"; do
    [[ -f "$TEST_HOME/$relative_path" ]] ||
      fail "Managed file was not created: $relative_path"
    sha256sum "$TEST_HOME/$relative_path" >>"$output_file"
  done
}

verify_idempotency() {
  local source_copy="$1"
  local before_hashes="$2"
  local after_hashes="$3"
  local diff_output

  apply_dotfiles "$source_copy"
  hash_managed_files "$after_hashes"
  cmp --silent "$before_hashes" "$after_hashes" ||
    fail 'Managed files changed after the second apply'

  diff_output="$(run_as_test_user chezmoi --source "$source_copy" diff)"
  [[ -z "$diff_output" ]] || fail "A diff remains after apply:\n$diff_output"
}

verify_update_script() {
  local source_copy="$1"
  local before_hashes="$2"
  local after_hashes="$3"
  local update_output

  update_output="$(run_as_test_user "$source_copy/update.sh" 2>&1)"
  printf '%s\n' "$update_output" | grep -Eq 'Configured:|No unapplied settings found.' ||
    fail "update.sh did not print a summary:\n$update_output"

  hash_managed_files "$after_hashes"
  cmp --silent "$before_hashes" "$after_hashes" ||
    fail 'Managed files changed after update.sh'
}

verify_shell_syntax() {
  bash -n "$TEST_HOME/.bashrc"
  sh -n "$TEST_HOME/.profile" "$TEST_HOME/.local/bin/env"
  zsh -n "$TEST_HOME/.zshrc" "$TEST_HOME/.p10k.zsh"
}

verify_path_order() {
  local path_output
  local npm_index
  local local_index
  local usr_index

  path_output="$(
    run_as_test_user sh -c '. "$HOME/.local/bin/env"; printf "%s\n" "$PATH"'
  )"
  IFS=: read -r -a path_entries <<<"$path_output"

  npm_index=-1
  local_index=-1
  usr_index=-1
  for i in "${!path_entries[@]}"; do
    case "${path_entries[$i]}" in
      "$TEST_HOME/.npm-global/bin") npm_index="$i" ;;
      "$TEST_HOME/.local/bin") local_index="$i" ;;
      /usr/bin) usr_index="$i" ;;
    esac
  done

  [[ "$npm_index" -ge 0 ]] ||
    fail '.npm-global/bin was not added to PATH'
  [[ "$local_index" -ge 0 ]] ||
    fail '.local/bin was not added to PATH'
  [[ "$npm_index" -lt "$local_index" && "$npm_index" -lt "$usr_index" ]] ||
    fail ".npm-global/bin does not take precedence in PATH: $path_output"
}

main() (
  local temporary_dir
  local source_copy
  local before_hashes
  local after_hashes

  [[ "$EUID" -eq 0 ]] || fail 'Run this script as root inside a container'
  [[ -f "$SOURCE_DIR/dot_zshrc" ]] || fail "chezmoi source was not found: $SOURCE_DIR"

  temporary_dir="$(mktemp -d)"
  trap 'rm -rf "$temporary_dir"' EXIT
  chmod 0755 "$temporary_dir"
  source_copy="$temporary_dir/source"
  before_hashes="$temporary_dir/before.sha256"
  after_hashes="$temporary_dir/after.sha256"
  mkdir -p "$source_copy"

  log 'Installing dependencies'
  install_dependencies
  install_chezmoi
  prepare_test_user "$source_copy"

  log 'Applying dotfiles'
  apply_dotfiles "$source_copy"
  hash_managed_files "$before_hashes"
  verify_idempotency "$source_copy" "$before_hashes" "$after_hashes"
  verify_update_script "$source_copy" "$before_hashes" "$after_hashes"
  verify_shell_syntax
  verify_path_order

  log 'Smoke test passed'
)

main "$@"
