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
| `home/.claude/settings.json` | `~/.claude/settings.json` | **リンクしない**。無いときだけコピー（下記） |
| `home/.config/ghostty/` `mise/` | `~/.config/...` | ファイル単位でリンク |
| `home/.config/karabiner/` | `~/.config/karabiner` | ディレクトリごとリンク |

秘密情報（SSH 鍵・AWS/Azure 認証・`gh` トークン等）やマシン固有値は **管理対象外**。

`~/.claude/settings.json` は Claude Code 自身や外部ツールが書き込み、auto mode の環境情報（業務リポの構成など）やマシン固有のフックが入る。symlink にすると公開リポの作業ツリーに書かれてしまうため、初回だけコピーし、以後はリポと同期しない。共通化したい設定は手で `home/.claude/settings.json` に反映する。

## 新しい Mac でのセットアップ

```sh
# 1. Homebrew を入れる
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. このマシンで使う ghq の root を決める（例: ~/ghq, ~/src, ~/Documents/ghq）
GHQ_ROOT=~/ghq

# 3. リポジトリを ghq の配置規則どおりに取得
git clone https://github.com/oddgai/dotfiles.git "$GHQ_ROOT/github.com/oddgai/dotfiles"

# 4. symlink を張り、brew bundle と mise install を実行
"$GHQ_ROOT/github.com/oddgai/dotfiles/install.sh"

# 5. マシン固有値を書く
#    ~/.gitconfig.local : [user] email
#    ~/.zshrc.local     : DATABRICKS_CLUSTER_ID など
```

既存のファイルは `~/.dotfiles-backup/<日時>/` に退避される。

ghq の root は `~/.gitconfig.local` の `ghq.root` に書く（マシンごとに違ってよい）。
`install.sh` は、未設定ならリポを clone した場所（`<root>/github.com/oddgai/dotfiles`）から推定して書き込む。
別の場所に clone したときは `GHQ_ROOT=<path> ./install.sh` で明示する。
symlink だけ張りたいときは `SKIP_PACKAGES=1 ./install.sh`。

## 日常運用

- 設定は `~/.zshrc` などを直接編集すればよい（実体はこのリポジトリ）。
- 新しいファイルを管理対象にするときは `home/` 配下に同じパスで置いて `./install.sh` を再実行する。
