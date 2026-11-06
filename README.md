# dotfiles

macOS (Apple Silicon) 用の dotfiles。`home/` 配下を `$HOME` に symlink して使う。

## 構成

| 層 | ツール | 役割 |
| --- | --- | --- |
| 設定ファイル | `install.sh` | `home/` 配下を `$HOME` に symlink |
| ランタイム | **mise** | 言語・CLI ツールのバージョン管理 |
| アプリ | **Homebrew** | CLI / GUI アプリ（`~/.Brewfile`） |

## 管理対象

`home/` のディレクトリ構成がそのまま `$HOME` 配下に対応する。

| ソース | 配置先 | 備考 |
| --- | --- | --- |
| `home/.zshrc` | `~/.zshrc` | マシン固有値は `~/.zshrc.local` |
| `home/.zshenv` | `~/.zshenv` | |
| `home/.gitconfig` | `~/.gitconfig` | email は `~/.gitconfig.local` |
| `home/.Brewfile` | `~/.Brewfile` | |
| `home/.claude/` | `~/.claude/` | ファイル単位でリンク |
| `home/.config/ghostty/` `mise/` | `~/.config/...` | ファイル単位でリンク |
| `home/.config/karabiner/` | `~/.config/karabiner` | ディレクトリごとリンク |

秘密情報（SSH 鍵・AWS/Azure 認証・`gh` トークン等）やマシン固有値は **管理対象外**。

## 新しい Mac でのセットアップ

```sh
# 1. Homebrew を入れる
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. リポジトリを取得（ghq の root に合わせて ~/Documents/ghq 配下に置く）
git clone https://github.com/oddgai/dotfiles.git ~/Documents/ghq/github.com/oddgai/dotfiles

# 3. symlink を張り、brew bundle と mise install を実行
~/Documents/ghq/github.com/oddgai/dotfiles/install.sh

# 4. マシン固有値を書く
#    ~/.gitconfig.local : [user] email
#    ~/.zshrc.local     : DATABRICKS_CLUSTER_ID など
```

既存のファイルは `~/.dotfiles-backup/<日時>/` に退避される。
symlink だけ張りたいときは `SKIP_PACKAGES=1 ./install.sh`。

## 日常運用

- 設定は `~/.zshrc` などを直接編集すればよい（実体はこのリポジトリ）。
- 新しいファイルを管理対象にするときは `home/` 配下に同じパスで置いて `./install.sh` を再実行する。
