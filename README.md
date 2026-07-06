# dotfiles

[chezmoi](https://www.chezmoi.io/)で管理する、Ubuntu、Fedora、Arch Linux向けのシェル環境設定です。

## インストール

```bash
git clone https://github.com/taigatappuri/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

`install.sh`は次のシステム変更を行います。内容を確認してから実行してください。

- OSのパッケージマネージャーでZsh、Git、curl、CA証明書を導入
- ログインシェルをZshへ変更
- chezmoiを`~/.local/bin`へ導入
- このリポジトリの設定をHOMEへ適用
- oh-my-zsh、Powerlevel10k、Zshプラグインを外部リポジトリから取得
- WSL上ではWindows版WezTerm、Monaspace/UDEV Gothicフォント、fastfetch、WezTerm設定を導入

リモートリポジトリを直接指定する場合は、引数または`CHEZMOI_REPO`を利用できます。

```bash
./install.sh https://github.com/taigatappuri/dotfiles.git
```

## 更新

既にクローン済みのリポジトリから、現在の端末に未適用の設定だけを適用します。

```bash
cd ~/dotfiles
./update.sh
```

`update.sh`はパッケージ、ログインシェル、chezmoi、dotfiles、oh-my-zshとZshプラグインを確認し、必要なものだけ設定します。終了前に今回設定した内容と、自動対応できなかった警告を表示します。

## アンインストール

削除対象とオプションを確認してから実行します。

```bash
./uninstall.sh --help
./uninstall.sh --backup-root "$HOME/dotfiles-backup"
```

`--force`と`--purge`は確認やchezmoiデータを含む削除に関係するため、ヘルプを確認せずに使用しないでください。

## 主な設定

- BashとZshのGitエイリアス
- Powerlevel10k
- zsh-autosuggestions
- zsh-syntax-highlighting
- WezTermの赤紫テーマ、WSL Domain起動、fastfetch起動時表示
- 指定名のディレクトリを検索して移動する`cdd`関数

## WezTerm

WSL上で`./install.sh`を実行すると、次の内容をまとめて設定します。

- Windows版WezTermを`winget`で導入
- Windowsユーザーフォントへ`Monaspace Argon NF`と`UDEV Gothic NF`を導入
- WSL側へ`fastfetch`を`~/.local/bin/fastfetch`として導入
- Windows側の`C:\Users\<Windowsユーザー>\.config\wezterm\wezterm.lua`へ設定を配置
- WSL側の`~/.config/wezterm/wezterm.lua`をWindows側設定へのシンボリックリンクにする

WezTerm単体を再セットアップしたい場合:

```bash
bash ~/dotfiles/dot_chezmoiscripts/executable_20-install-wezterm-stack.sh
```

設定の説明は、インストール後に`~/.config/wezterm/README.md`を確認してください。

fastfetch の citron AA の色を変える場合は、`~/.config/wezterm/citron-colors.conf` の数値だけを編集します。

```sh
# ░ の色。黄色がかった白。
CITRON_LIGHT_COLOR=230

# ▒ の色。濃いオレンジ。
CITRON_DARK_COLOR=208
```

AA の形は `~/.config/wezterm/citron.txt` に置きます。`citron.txt` には ANSI エスケープを直接書かず、色は `citron-colors.conf` に分けます。

fastfetch は端末幅が十分に広い時だけ、AA と情報を横並びにします。しきい値は `FASTFETCH_WIDE_THRESHOLD` で変更できます。既定値は `160` 桁です。

