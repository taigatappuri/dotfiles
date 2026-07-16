local wezterm = require("wezterm")

local config = wezterm.config_builder()
local act = wezterm.action

local wsl_user = "__WSL_USER__"
local wsl_distro = "__WSL_DISTRO__"
local wsl_home = "/home/" .. wsl_user

config.colors = {
  foreground = "#f3e8ff",
  background = "#120914",
  cursor_bg = "#d8b4fe",
  cursor_fg = "#120914",
  cursor_border = "#d8b4fe",
  selection_fg = "#f8f1ff",
  selection_bg = "#4a274f",
  scrollbar_thumb = "#5b2f63",
  split = "#7e4f88",

  ansi = {
    "#1a0f1d",
    "#c45a8d",
    "#8fbf8f",
    "#d7b26d",
    "#9f8fe8",
    "#c084fc",
    "#8ecfc8",
    "#f3e8ff",
  },
  brights = {
    "#5b4561",
    "#e879b3",
    "#b6d7a8",
    "#f5d0a9",
    "#c4b5fd",
    "#f0abfc",
    "#b5f0e8",
    "#fff7ff",
  },

  tab_bar = {
    background = "#120914",
    active_tab = {
      bg_color = "#c084fc",
      fg_color = "#16081a",
      intensity = "Bold",
    },
    inactive_tab = {
      bg_color = "#241326",
      fg_color = "#d8bfdc",
    },
    inactive_tab_hover = {
      bg_color = "#3a1c3f",
      fg_color = "#f3e8ff",
    },
  },
}

config.window_background_opacity = 0.85
config.macos_window_background_blur = 24
config.text_background_opacity = 1.0
-- Windows 標準の最小化・最大化・閉じるボタンを表示する。
config.window_decorations = "TITLE | RESIZE"
config.window_padding = {
  left = 12,
  right = 12,
  top = 10,
  bottom = 8,
}

-- 英数字と日本語でメトリクスがずれないよう、日本語対応の等幅フォントを
-- 主フォントにする。本文には Nerd Fonts 加工前の UDEV Gothic を使い、加工時に
-- 追加された小さな記号グリフが一部の日本語文字より優先されるのを防ぐ。
-- Nerd Font のアイコンは WezTerm 内蔵の Symbols Nerd Font Mono が補完する。
local text_font = wezterm.target_triple:find("windows")
    and "UDEV Gothic"
  -- Ubuntu 22.04 の Mono TTC は一部の漢字を半角の字送りで返すため使わない。
  or "Noto Sans CJK JP"

config.font = wezterm.font_with_fallback({
  -- Noto Sans CJK JP の英字はプロポーショナルなので、英数字は等幅に固定する。
  "JetBrains Mono",
  text_font,
  "Symbols Nerd Font Mono",
})
config.font_size = 10.5
-- アクセント記号や日本語グリフの上端がセル境界で切れない余白を確保する。
config.line_height = 1.20
-- 全角2セルの正しい字送りを保ちつつ、文字間の余白を少し詰める。
config.cell_width = 0.85
config.harfbuzz_features = {
  -- WezTerm 20240203 と Noto Sans Mono CJK の組み合わせでは、一部の漢字列が
  -- 2セルのまま半角相当の字送りでシェーピングされ、小さく見えることがある。
  -- 端末表示では合字よりセル幅の安定性を優先する。
  "calt=0",
  "clig=0",
  "liga=0",
  "dlig=0",
}
config.freetype_load_target = "Light"
config.freetype_render_target = "HorizontalLcd"

-- Windows では WSL Domain として Ubuntu を開く。
-- default_prog は WSL 内で実行され、fastfetch 表示後に zsh へ入る。
if wezterm.target_triple:find("windows") then
  config.default_domain = "WSL:" .. wsl_distro
  config.wsl_domains = {
    {
      name = "WSL:" .. wsl_distro,
      distribution = wsl_distro,
      default_cwd = wsl_home,
      default_prog = { wsl_home .. "/.local/bin/wezterm-start-zsh" },
    },
  }
else
  config.default_prog = { wsl_home .. "/.local/bin/wezterm-start-zsh" }
end

-- タブバー
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = false
config.tab_bar_at_bottom = false
config.tab_max_width = 28
config.show_new_tab_button_in_tab_bar = false
config.show_tab_index_in_tab_bar = false
config.switch_to_last_active_tab_when_closing_tab = true

-- スクロールと選択
config.scrollback_lines = 20000
config.enable_scroll_bar = true
config.mouse_wheel_scrolls_tabs = false
config.alternate_buffer_wheel_scroll_speed = 1
config.selection_word_boundary = " \t\n{}[]()\"'`,;:"
config.quick_select_patterns = {
  "https?://\\S+",
  "[\\w.-]+@[\\w.-]+\\.[A-Za-z]{2,}",
  "[A-Fa-f0-9]{7,40}",
  "(?:[\\w.-]+/)+[\\w.-]+:\\d+",
}

-- ホイール1刻みの移動量を小さくして、スクロールの体感をなめらかにする。
config.mouse_bindings = {
  {
    event = { Down = { streak = 2, button = { WheelUp = 2 } } },
    mods = "NONE",
    action = act.ScrollByLine(-1),
  },
  {
    event = { Down = { streak = 2, button = { WheelDown = 2 } } },
    mods = "NONE",
    action = act.ScrollByLine(1),
  },
}

-- IME と描画
config.use_ime = true
config.animation_fps = 120
config.max_fps = 120

-- tmux 風の Leader。Ctrl-a を2回押すと Ctrl-a を送る。
config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1200 }

local pane_shortcut_help = [[
ペイン操作
  Ctrl-a -       下に分割
  Ctrl-a \       右に分割
  Ctrl-a h/j/k/l ペイン移動
  Ctrl-a ←/↓/↑/→ ペインサイズ変更
  Ctrl-a z       ズーム切替
  Ctrl-a q       ペインを閉じる

その他
  Ctrl-a c       新規タブ
  Ctrl-a n/p     次/前のタブ
  Ctrl-a 1..9    タブ番号へ移動
  Ctrl-a ? / F1  このヘルプ
]]

local show_pane_shortcut_help = wezterm.action_callback(function(_window, pane)
  pane:inject_output("\r\n" .. pane_shortcut_help:gsub("\n", "\r\n") .. "\r\n")
end)

config.keys = {
  { key = "a", mods = "LEADER|CTRL", action = act.SendKey({ key = "a", mods = "CTRL" }) },

  -- タブ
  { key = "c", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
  { key = "x", mods = "LEADER", action = act.CloseCurrentTab({ confirm = true }) },
  { key = "n", mods = "LEADER", action = act.ActivateTabRelative(1) },
  { key = "p", mods = "LEADER", action = act.ActivateTabRelative(-1) },
  { key = "[", mods = "LEADER", action = act.ActivateTabRelative(-1) },
  { key = "]", mods = "LEADER", action = act.ActivateTabRelative(1) },

  -- ペイン分割
  { key = "-", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
  { key = "\\", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
  { key = "q", mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) },

  -- ペイン移動
  { key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
  { key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
  { key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
  { key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },

  -- ペインサイズ変更
  { key = "LeftArrow", mods = "LEADER", action = act.AdjustPaneSize({ "Left", 5 }) },
  { key = "DownArrow", mods = "LEADER", action = act.AdjustPaneSize({ "Down", 3 }) },
  { key = "UpArrow", mods = "LEADER", action = act.AdjustPaneSize({ "Up", 3 }) },
  { key = "RightArrow", mods = "LEADER", action = act.AdjustPaneSize({ "Right", 5 }) },

  -- 便利操作
  { key = "f", mods = "LEADER", action = act.Search("CurrentSelectionOrEmptyString") },
  { key = "s", mods = "LEADER", action = act.QuickSelect },
  { key = "Space", mods = "LEADER", action = act.ActivateCopyMode },
  { key = "r", mods = "LEADER", action = act.ReloadConfiguration },
  { key = "?", mods = "LEADER|SHIFT", action = show_pane_shortcut_help },
  { key = "F1", mods = "NONE", action = show_pane_shortcut_help },
  { key = "Enter", mods = "ALT", action = act.ToggleFullScreen },

  -- OS 標準に近いコピー・ペースト
  { key = "c", mods = "CTRL|SHIFT", action = act.CopyTo("Clipboard") },
  { key = "v", mods = "CTRL|SHIFT", action = act.PasteFrom("Clipboard") },
}

for i = 1, 9 do
  table.insert(config.keys, {
    key = tostring(i),
    mods = "LEADER",
    action = act.ActivateTab(i - 1),
  })
end

-- タブタイトルを短く保つ
wezterm.on("format-tab-title", function(tab)
  local title = tab.active_pane.title
  title = title:gsub("^.-[/\\]", "")

  local index = tab.tab_index + 1
  local bg = tab.is_active and "#c084fc" or "#241326"
  local fg = tab.is_active and "#16081a" or "#d8bfdc"

  return {
    { Background = { Color = bg } },
    { Foreground = { Color = fg } },
    { Text = " " .. index .. ":" .. title .. " " },
  }
end)

-- 右上に日時・ワークスペース・ドメインを表示する
wezterm.on("update-right-status", function(window, pane)
  local date = wezterm.strftime("%m/%d %H:%M")
  local workspace = window:active_workspace()
  local domain = pane:get_domain_name()

  window:set_right_status(wezterm.format({
    { Foreground = { Color = "#e9d5ff" } },
    { Text = " " .. workspace .. " " },
    { Foreground = { Color = "#f0abfc" } },
    { Text = domain .. " " },
    { Foreground = { Color = "#f5d0a9" } },
    { Text = date .. " " },
  }))
end)

return config
