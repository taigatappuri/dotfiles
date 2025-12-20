## install
1. このレポジトリを `~/dotfiles` として clone
2. ./install.sh 

## uninstall
./uninstall.sh

## エイリアス
g='git'
gs='git status -sb'
gl='git log --oneline --graph --decorate'
gd='git diff'
gdc='git diff --cached'
ga='git add'
gc='git commit'
gco='git checkout'
gb='git branch'
gp='git push'
gpl='git pull --rebase'

cdd: 再帰的にディレクトリを走査してただ1つ見つかったら移動。同名ディレクトリを複数見つけたらすべてのパスを報告