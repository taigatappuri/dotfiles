#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '%s\n' "$*" >&2
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

is_wsl() {
  [[ -n "${WSL_DISTRO_NAME:-}" ]] ||
    grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null
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

install_fastfetch() {
  if [[ -x "$HOME/.local/bin/fastfetch" ]] || have_cmd fastfetch; then
    log "fastfetch already installed"
    return 0
  fi

  if ! have_cmd curl || ! have_cmd tar; then
    log "[WARN]: curl or tar not found, skipping fastfetch installation"
    return 0
  fi

  local arch
  case "$(uname -m)" in
    x86_64 | amd64) arch="amd64" ;;
    aarch64 | arm64) arch="aarch64" ;;
    *)
      log "[WARN]: unsupported fastfetch architecture: $(uname -m)"
      return 0
      ;;
  esac

  local api_url
  local archive_url
  local version
  local tmp_dir
  local archive
  local extracted_root
  api_url="https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest"

  archive_url="$(
    curl -fsSL "$api_url" |
      sed -nE "s/.*\"browser_download_url\": \"([^\"]*fastfetch-linux-${arch}\\.tar\\.gz)\".*/\\1/p" |
      head -n 1
  )"

  if [[ -z "$archive_url" ]]; then
    log "[WARN]: could not find fastfetch release asset"
    return 0
  fi

  version="${archive_url#*/download/}"
  version="${version%%/*}"
  tmp_dir="$(mktemp -d)"
  archive="$tmp_dir/fastfetch.tar.gz"

  log "Installing fastfetch: $version"
  curl -fL "$archive_url" -o "$archive"
  tar -xzf "$archive" -C "$tmp_dir"

  extracted_root="$(
    find "$tmp_dir" -type f -path '*/usr/bin/fastfetch' -printf '%h\n' |
      sed 's#/usr/bin$##' |
      head -n 1
  )"

  if [[ -z "$extracted_root" ]]; then
    log "[WARN]: fastfetch archive layout was not recognized"
    rm -rf "$tmp_dir"
    return 0
  fi

  mkdir -p "$HOME/.local/opt" "$HOME/.local/bin"
  rm -rf "$HOME/.local/opt/fastfetch-$version"
  cp -a "$extracted_root" "$HOME/.local/opt/fastfetch-$version"
  ln -sfn "$HOME/.local/opt/fastfetch-$version/usr/bin/fastfetch" "$HOME/.local/bin/fastfetch"
  rm -rf "$tmp_dir"
}

install_windows_wezterm() {
  if ! is_wsl || ! have_cmd powershell.exe; then
    return 0
  fi

  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command - <<'PWSH' | sed 's/\r$//'
$ErrorActionPreference = "Stop"

$weztermPaths = @(
  "$env:ProgramFiles\WezTerm\wezterm.exe",
  "$env:LOCALAPPDATA\Programs\WezTerm\wezterm.exe"
)

$exists = $false
foreach ($path in $weztermPaths) {
  if (Test-Path $path) {
    $exists = $true
    break
  }
}
if (-not $exists -and (Get-Command wezterm.exe -ErrorAction SilentlyContinue)) {
  $exists = $true
}

if ($exists) {
  Write-Host "WezTerm already installed"
  exit 0
}

$winget = Get-Command winget.exe -ErrorAction SilentlyContinue
if (-not $winget) {
  Write-Warning "winget.exe not found; install WezTerm manually from https://wezterm.org/"
  exit 0
}

Write-Host "Installing WezTerm with winget"
winget install --id Wez.WezTerm --exact --source winget --accept-package-agreements --accept-source-agreements --silent
PWSH
}

install_windows_fonts() {
  if ! is_wsl || ! have_cmd powershell.exe; then
    return 0
  fi

  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command - <<'PWSH' | sed 's/\r$//'
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression.FileSystem

$fontDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
$fontRegistry = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
New-Item -ItemType Directory -Force -Path $fontDir | Out-Null

function Install-FontArchive {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Url,
    [string]$Pattern = ".*\.(ttf|otf)$"
  )

  $work = Join-Path ([System.IO.Path]::GetTempPath()) ("dotfiles-font-" + [Guid]::NewGuid().ToString("N"))
  $zip = Join-Path $work "$Name.zip"
  $extract = Join-Path $work "extract"
  New-Item -ItemType Directory -Force -Path $work, $extract | Out-Null

  try {
    Write-Host "Installing font archive: $Name"
    Invoke-WebRequest -Uri $Url -OutFile $zip
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $extract)

    Get-ChildItem -Path $extract -Recurse -File |
      Where-Object { $_.Name -match $Pattern } |
      ForEach-Object {
        $destination = Join-Path $fontDir $_.Name
        Copy-Item $_.FullName $destination -Force
        $kind = if ($_.Extension -ieq ".otf") { "OpenType" } else { "TrueType" }
        New-ItemProperty -Path $fontRegistry -Name "$($_.BaseName) ($kind)" -Value $_.Name -PropertyType String -Force | Out-Null
      }
  } finally {
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
  }
}

function Get-LatestReleaseAssetUrl {
  param(
    [Parameter(Mandatory = $true)][string]$Repository,
    [Parameter(Mandatory = $true)][string]$AssetPattern
  )

  $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases/latest"
  $asset = $release.assets |
    Where-Object { $_.name -match $AssetPattern } |
    Select-Object -First 1

  if (-not $asset) {
    throw "Release asset not found: $Repository / $AssetPattern"
  }

  return $asset.browser_download_url
}

function Test-FontRegistered {
  param([Parameter(Mandatory = $true)][string]$Pattern)

  $properties = (Get-ItemProperty -Path $fontRegistry -ErrorAction SilentlyContinue).PSObject.Properties.Name
  return [bool]($properties | Where-Object { $_ -like $Pattern } | Select-Object -First 1)
}

if (Test-FontRegistered "*Monaspace*Argon*") {
  Write-Host "Monaspace Argon NF already installed"
} else {
  Install-FontArchive `
    -Name "Monaspace Nerd Font" `
    -Url "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Monaspace.zip" `
    -Pattern ".*\.(ttf|otf)$"
}

if (Test-FontRegistered "*UDEV*Gothic*NF*") {
  Write-Host "UDEV Gothic NF already installed"
} else {
  $udevUrl = Get-LatestReleaseAssetUrl `
    -Repository "yuru7/udev-gothic" `
    -AssetPattern "UDEVGothic_NF.*\.zip$"

  Install-FontArchive `
    -Name "UDEV Gothic NF" `
    -Url $udevUrl `
    -Pattern ".*\.(ttf|otf)$"
}
PWSH
}

windows_user_profile_path() {
  powershell.exe -NoProfile -Command '[Environment]::GetFolderPath("UserProfile")' |
    tr -d '\r'
}

install_wezterm_config() {
  local template_dir="$HOME/.local/share/dotfiles/wezterm"
  local script_dir
  local repo_template_dir
  local template="$template_dir/wezterm.lua"
  local readme="$template_dir/README.md"
  local wsl_user="${USER:-$(id -un)}"
  local wsl_distro="${WEZTERM_WSL_DISTRO:-${WSL_DISTRO_NAME:-Ubuntu}}"
  local target_config
  local target_readme

  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
  repo_template_dir="$(cd -- "$script_dir/.." 2>/dev/null && pwd -P)/dot_local/share/dotfiles/wezterm"
  if [[ ! -r "$template" && -r "$repo_template_dir/wezterm.lua" ]]; then
    template_dir="$repo_template_dir"
    template="$template_dir/wezterm.lua"
    readme="$template_dir/README.md"
  fi

  if [[ ! -r "$template" ]]; then
    log "[WARN]: WezTerm template not found: $template"
    return 0
  fi

  if is_wsl && have_cmd powershell.exe && have_cmd wslpath; then
    local windows_profile
    local windows_profile_wsl
    local windows_config_lua

    windows_profile="$(windows_user_profile_path)"
    windows_profile_wsl="$(wslpath -u "$windows_profile")"
    target_config="$windows_profile_wsl/.config/wezterm/wezterm.lua"
    target_readme="$windows_profile_wsl/.config/wezterm/README.md"

    mkdir -p "$(dirname "$target_config")" "$HOME/.config/wezterm"

    sed \
      -e "s/__WSL_USER__/$wsl_user/g" \
      -e "s/__WSL_DISTRO__/$wsl_distro/g" \
      "$template" >"$target_config"

    if [[ -r "$readme" ]]; then
      cp "$readme" "$target_readme"
    fi

    windows_config_lua="$(wslpath -w "$target_config")"
    windows_config_lua="${windows_config_lua//\\//}"
    cat >"$windows_profile_wsl/.wezterm.lua" <<EOF
-- 本体は $windows_config_lua。
-- WezTerm がこのファイルを先に読んだ場合も、同じ設定へ転送する。
return dofile("$windows_config_lua")
EOF

    if [[ -e "$HOME/.config/wezterm/wezterm.lua" && ! -L "$HOME/.config/wezterm/wezterm.lua" ]]; then
      mv "$HOME/.config/wezterm/wezterm.lua" "$HOME/.config/wezterm/wezterm.lua.backup.$(date +%Y%m%d%H%M%S)"
    fi
    ln -sfn "$target_config" "$HOME/.config/wezterm/wezterm.lua"
  else
    target_config="$HOME/.config/wezterm/wezterm.lua"
    target_readme="$HOME/.config/wezterm/README.md"
    mkdir -p "$(dirname "$target_config")"
    sed \
      -e "s/__WSL_USER__/$wsl_user/g" \
      -e "s/__WSL_DISTRO__/$wsl_distro/g" \
      "$template" >"$target_config"
    if [[ -r "$readme" ]]; then
      cp "$readme" "$target_readme"
    fi
  fi

  log "WezTerm config installed: $target_config"
}

main() {
  install_fastfetch
  install_windows_wezterm
  install_windows_fonts
  install_wezterm_config
}

main "$@"
