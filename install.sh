#!/usr/bin/env bash
# home/ 配下のファイルを $HOME に symlink し、パッケージを入れる。
# 何度実行してもよい。既存の実ファイルは ~/.dotfiles-backup/<日時>/ に退避する。
set -o errexit
set -o nounset
set -o pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${DOTFILES_DIR}/home"
BACKUP_DIR="${HOME}/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

link() {
  local src="$1" dst="$2"
  # すでに正しいリンクなら何もしない
  if [ -L "${dst}" ] && [ "$(readlink "${dst}")" = "${src}" ]; then
    return
  fi
  if [ -e "${dst}" ] || [ -L "${dst}" ]; then
    mkdir -p "$(dirname "${BACKUP_DIR}/${dst#"${HOME}"/}")"
    mv "${dst}" "${BACKUP_DIR}/${dst#"${HOME}"/}"
    echo "backup: ${dst} -> ${BACKUP_DIR}/${dst#"${HOME}"/}"
  fi
  mkdir -p "$(dirname "${dst}")"
  ln -s "${src}" "${dst}"
  echo "link:   ${dst} -> ${src}"
}

echo "==> symlink dotfiles"
# Karabiner-Elements はファイル単位の symlink だと変更を検知しないので、ディレクトリごとリンクする
link "${SRC}/.config/karabiner" "${HOME}/.config/karabiner"

# それ以外はファイル単位でリンクする（~/.claude などはツールの状態も置かれるため）
while IFS= read -r -d '' file; do
  rel="${file#"${SRC}"/}"
  case "${rel}" in
    .config/karabiner/*) continue ;;
  esac
  link "${file}" "${HOME}/${rel}"
done < <(find "${SRC}" -type f ! -name '.DS_Store' -print0)

echo "==> machine-local files"
if [ ! -f "${HOME}/.gitconfig.local" ]; then
  printf '[user]\n\temail = \n' > "${HOME}/.gitconfig.local"
  echo "created ~/.gitconfig.local (email を設定してください)"
fi
if [ ! -f "${HOME}/.zshrc.local" ]; then
  printf '# このマシン専用の設定\n# export DATABRICKS_CLUSTER_ID="xxxx-xxxxxx-xxxxxxxx"\n' > "${HOME}/.zshrc.local"
  echo "created ~/.zshrc.local"
fi

if [ "${SKIP_PACKAGES:-0}" = "1" ]; then
  echo "==> skip packages (SKIP_PACKAGES=1)"
  exit 0
fi

if command -v brew >/dev/null 2>&1; then
  echo "==> brew bundle (~/.Brewfile)"
  brew bundle --global
  # share がグループ書き込み可だと compinit が「安全でないディレクトリ」として補完の読み込みを止める
  # （zsh-completions の caveats で Homebrew が案内している対処）
  chmod go-w "$(brew --prefix)/share"
else
  echo "brew が見つかりません。Homebrew を入れてから再実行してください。" >&2
fi

if command -v mise >/dev/null 2>&1; then
  echo "==> mise install"
  mise install
fi
