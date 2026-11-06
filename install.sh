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

# 既存の ~/.gitconfig は symlink に置き換えて退避するので、その前にマシン固有の値を読んでおく
# （~/.gitconfig.local へ引き継ぐ）
old_gitconfig_email=""
old_gitconfig_ghq_root=""
if [ -f "${HOME}/.gitconfig" ] && [ ! -L "${HOME}/.gitconfig" ]; then
  old_gitconfig_email="$(git config --file "${HOME}/.gitconfig" --get user.email || true)"
  old_gitconfig_ghq_root="$(git config --file "${HOME}/.gitconfig" --get-all ghq.root | head -n 1 || true)"
fi

echo "==> symlink dotfiles"
# Karabiner-Elements はファイル単位の symlink だと変更を検知しないので、ディレクトリごとリンクする
link "${SRC}/.config/karabiner" "${HOME}/.config/karabiner"

# settings.json は Claude Code や外部ツール（auto mode の環境情報、各種フック）が書き込み、
# 社外秘やマシン固有の内容が入る。symlink だと公開リポの作業ツリーに書かれるので、無いときだけコピーする
copy_if_missing() {
  local src="$1" dst="$2"
  if [ -e "${dst}" ] || [ -L "${dst}" ]; then
    echo "keep:   ${dst} (既存のファイルを残す)"
    return
  fi
  mkdir -p "$(dirname "${dst}")"
  cp "${src}" "${dst}"
  echo "copy:   ${dst} <- ${src}"
}
copy_if_missing "${SRC}/.claude/settings.json" "${HOME}/.claude/settings.json"

# それ以外はファイル単位でリンクする（~/.claude などはツールの状態も置かれるため）
while IFS= read -r -d '' file; do
  rel="${file#"${SRC}"/}"
  case "${rel}" in
    .config/karabiner/*) continue ;;
    .claude/settings.json) continue ;;
  esac
  link "${file}" "${HOME}/${rel}"
done < <(find "${SRC}" -type f ! -name '.DS_Store' -print0)

echo "==> machine-local files"
if [ ! -f "${HOME}/.gitconfig.local" ]; then
  touch "${HOME}/.gitconfig.local"
  echo "created ~/.gitconfig.local"
fi
gitconfig_local_get() { git config --file "${HOME}/.gitconfig.local" --get "$1" || true; }

if [ -z "$(gitconfig_local_get user.email)" ]; then
  if [ -n "${old_gitconfig_email}" ]; then
    git config --file "${HOME}/.gitconfig.local" user.email "${old_gitconfig_email}"
    echo "set user.email = ${old_gitconfig_email} in ~/.gitconfig.local (元の ~/.gitconfig から引き継ぎ)"
  else
    # shellcheck disable=SC2088  # 案内文なので ~ はそのまま表示する
    echo "~/.gitconfig.local に user.email を設定してください: git config --file ~/.gitconfig.local user.email <email>"
  fi
fi

# ghq.root はマシンごとに違ってよいので ~/.gitconfig.local に書く。
# 優先順: 元の ~/.gitconfig の値 > このリポを clone した場所（<root>/github.com/oddgai/dotfiles）から推定。
# どちらも無ければ書かず、ghq のデフォルト（~/ghq。環境変数 GHQ_ROOT があればそれ）に任せる
if [ -z "$(gitconfig_local_get ghq.root)" ]; then
  ghq_root="${old_gitconfig_ghq_root}"
  ghq_root_source="元の ~/.gitconfig から引き継ぎ"
  if [ -z "${ghq_root}" ]; then
    case "${DOTFILES_DIR}" in
      */github.com/oddgai/dotfiles)
        ghq_root="${DOTFILES_DIR%/github.com/oddgai/dotfiles}"
        ghq_root_source="clone した場所から推定"
        ;;
    esac
  fi
  if [ -n "${ghq_root}" ]; then
    # $HOME 配下なら ~ 表記で書く（展開せず文字列として書き込み、ghq 側で展開させる）
    # shellcheck disable=SC2088
    case "${ghq_root}" in
      "${HOME}"/*) ghq_root="~/${ghq_root#"${HOME}"/}" ;;
    esac
    git config --file "${HOME}/.gitconfig.local" ghq.root "${ghq_root}"
    echo "set ghq.root = ${ghq_root} in ~/.gitconfig.local (${ghq_root_source})"
  else
    echo "ghq.root は未設定のままにします（ghq のデフォルトを使う）"
  fi
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
