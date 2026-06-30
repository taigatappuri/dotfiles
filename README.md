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
- 指定名のディレクトリを検索して移動する`cdd`関数

## 秘密情報

APIキー、トークン、秘密鍵、パスワードをこのリポジトリへコミットしないでください。必要な秘密情報はchezmoiの暗号化機能、OSの認証情報ストア、または環境ごとの安全な保管先を利用します。
