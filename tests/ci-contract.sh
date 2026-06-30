#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly REPOSITORY_ROOT
readonly WORKFLOW_FILE="$REPOSITORY_ROOT/.github/workflows/ci.yml"
readonly DEPENDABOT_FILE="$REPOSITORY_ROOT/.github/dependabot.yml"
readonly SMOKE_TEST_FILE="$REPOSITORY_ROOT/tests/smoke.sh"
readonly UPDATE_FILE="$REPOSITORY_ROOT/update.sh"
readonly CHEZMOI_IGNORE_FILE="$REPOSITORY_ROOT/.chezmoiignore"
readonly README_FILE="$REPOSITORY_ROOT/README.md"
BACKTICK="$(printf '\140')"
readonly BACKTICK

fail() {
  printf 'Failure: %s\n' "$*" >&2
  exit 1
}

assert_file() {
  local path="$1"

  [[ -f "$path" ]] || fail "Required file is missing: ${path#"$REPOSITORY_ROOT/"}"
}

assert_contains() {
  local path="$1"
  local expected="$2"

  grep -Fq -- "$expected" "$path" ||
    fail "Required setting is missing from ${path#"$REPOSITORY_ROOT/"}: $expected"
}

assert_regex() {
  local path="$1"
  local expected="$2"

  grep -Eq -- "$expected" "$path" ||
    fail "${path#"$REPOSITORY_ROOT/"} does not match the required format: $expected"
}

assert_not_contains() {
  local path="$1"
  local unexpected="$2"

  if grep -Fq -- "$unexpected" "$path"; then
    fail "Forbidden content found in ${path#"$REPOSITORY_ROOT/"}: $unexpected"
  fi
}

assert_actions_pinned() {
  local action

  while IFS= read -r action; do
    [[ "$action" =~ ^[^@]+@[0-9a-f]{40}$ ]] ||
      fail "GitHub Action is not pinned to a full commit SHA: $action"
  done < <(sed -nE 's/^[[:space:]]*uses:[[:space:]]*([^[:space:]#]+).*/\1/p' "$WORKFLOW_FILE")
}

assert_file "$SMOKE_TEST_FILE"
assert_file "$UPDATE_FILE"
[[ -x "$UPDATE_FILE" ]] || fail 'update.sh is not executable'
bash -n "$UPDATE_FILE"

assert_contains "$SMOKE_TEST_FILE" "CHEZMOI_VERSION=\"\${CHEZMOI_VERSION:-2.70.1}\""
assert_contains "$SMOKE_TEST_FILE" '3bd054238e2a95548eee62a6c5b4d9d1352f2c6c69c6d32f3d1964878398f91a'
assert_contains "$SMOKE_TEST_FILE" 'useradd --create-home'
assert_contains "$SMOKE_TEST_FILE" 'runuser --user'
assert_contains "$SMOKE_TEST_FILE" 'diffutils'
assert_contains "$SMOKE_TEST_FILE" 'cmp --silent'
assert_contains "$SMOKE_TEST_FILE" "chezmoi --source \"\$source_copy\" diff"
assert_contains "$SMOKE_TEST_FILE" "chmod 0755 \"\$temporary_dir\""

assert_contains "$UPDATE_FILE" 'Configured:'
assert_contains "$UPDATE_FILE" 'Warnings:'
assert_contains "$UPDATE_FILE" 'No unapplied settings found.'
assert_contains "$UPDATE_FILE" 'chezmoi -S "$script_dir" apply'
assert_contains "$UPDATE_FILE" 'dotfiles applied'
assert_contains "$UPDATE_FILE" 'zsh dependencies installed'

assert_not_contains "$REPOSITORY_ROOT/uninstall.sh" "log \"- ${BACKTICK}chezmoi purge${BACKTICK}"
assert_not_contains "$REPOSITORY_ROOT/uninstall.sh" "log \"${BACKTICK}chezmoi purge${BACKTICK}"

assert_contains "$CHEZMOI_IGNORE_FILE" 'README.md'
assert_contains "$CHEZMOI_IGNORE_FILE" 'memo.md'
assert_contains "$CHEZMOI_IGNORE_FILE" 'tests/'
assert_contains "$CHEZMOI_IGNORE_FILE" 'docs/'
assert_contains "$CHEZMOI_IGNORE_FILE" 'update.sh'

assert_file "$WORKFLOW_FILE"
assert_file "$DEPENDABOT_FILE"

assert_contains "$WORKFLOW_FILE" 'pull_request:'
assert_contains "$WORKFLOW_FILE" 'workflow_dispatch:'
assert_contains "$WORKFLOW_FILE" 'contents: read'
assert_contains "$WORKFLOW_FILE" 'concurrency:'
assert_contains "$WORKFLOW_FILE" 'timeout-minutes:'
assert_contains "$WORKFLOW_FILE" 'fail-fast: false'
assert_contains "$WORKFLOW_FILE" 'ubuntu:24.04'
assert_contains "$WORKFLOW_FILE" 'fedora:latest'
assert_contains "$WORKFLOW_FILE" 'archlinux:latest'
assert_regex "$WORKFLOW_FILE" 'uses: [^[:space:]#]+@[0-9a-f]{40}([[:space:]]|$)'
assert_contains "$WORKFLOW_FILE" 'name: Quality'
assert_contains "$WORKFLOW_FILE" "name: Smoke test (\${{ matrix.image }})"
assert_contains "$WORKFLOW_FILE" 'name: Check out repository'
assert_actions_pinned

assert_contains "$DEPENDABOT_FILE" 'package-ecosystem: "github-actions"'
assert_contains "$DEPENDABOT_FILE" 'interval: "monthly"'

assert_file "$README_FILE"
assert_contains "$README_FILE" 'Ubuntu'
assert_contains "$README_FILE" 'Fedora'
assert_contains "$README_FILE" 'Arch Linux'
assert_contains "$README_FILE" '## 更新'
assert_contains "$README_FILE" './update.sh'
assert_contains "$README_FILE" '未適用の設定'
assert_not_contains "$README_FILE" '## CI'
assert_not_contains "$README_FILE" 'bash tests/ci-contract.sh'

assert_contains "$SMOKE_TEST_FILE" 'Smoke test passed'
assert_contains "$REPOSITORY_ROOT/uninstall.sh" 'Uninstall completed'

printf 'CI contract tests passed\n'
