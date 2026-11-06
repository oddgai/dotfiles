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
| `install.sh` の `EXTERNAL_SKILLS` | `~/.claude/skills/<名前>/` | 外部の skill。Skills CLI で取得し、中身はリポに置かない |
| `home/.config/ghostty/` `mise/` | `~/.config/...` | ファイル単位でリンク |

秘密情報（SSH 鍵・AWS/Azure 認証・`gh` トークン等）やマシン固有値は **管理対象外**。

`~/.claude/settings.json` は Claude Code 自身や外部ツールが書き込み、auto mode の環境情報（業務リポの構成など）やマシン固有のフックが入る。symlink にすると公開リポの作業ツリーに書かれてしまうため、初回だけコピーし、以後はリポと同期しない。共通化したい設定は手で `home/.claude/settings.json` に反映する。

## 新しい Mac でのセットアップ

```sh
# 1. Homebrew を入れる
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"  # このシェルで brew を使えるようにする（以後は .zshrc が設定する）

# 2. リポジトリを ghq の配置規則（<root>/github.com/oddgai/dotfiles）で取得
#    ~/ghq は ghq のデフォルト root。別の root を使っているマシンならそこに置く
git clone https://github.com/oddgai/dotfiles.git ~/ghq/github.com/oddgai/dotfiles

# 3. Brewfile で使う外部 tap を信頼する（新しい Mac で一度だけ）
brew trust --tap abue-ammar/tinycast atlassian/acli databricks/tap stablyai/orca

# 4. symlink を張り、brew bundle・mise install・外部 skill の取得を実行
~/ghq/github.com/oddgai/dotfiles/install.sh

# 5. マシン固有値を書く（install.sh が案内したものだけ）
#    ~/.gitconfig.local : user.email
#    ~/.zshrc.local     : DATABRICKS_CLUSTER_ID など

# 6. 新しいシェルで設定を読み込む
exec zsh -l
```

既存のファイルは `~/.dotfiles-backup/<日時>/` に退避される。

### コマンドでインストールするもの

インストール一覧は [`home/.Brewfile`](home/.Brewfile) で管理する。次のアプリ・ツールも `install.sh` からまとめて導入される。

| 用途 | アプリ・ツール |
| --- | --- |
| ブラウザ | Google Chrome |
| 入力・周辺機器 | azooKey on macOS、Logi Options+ |
| エディタ・開発環境 | Zed、Orca、Ghostty |
| 動画再生 | IINA、VLC |
| ユーティリティ | Tinycast、f.lux、AppCleaner |
| フォント | HackGen |
| CLI | Codex CLI、GitHub CLI (`gh`)、ghq、lazygit、mise |

azooKey と HackGen は Homebrew の cask として管理する（[azooKey](https://formulae.brew.sh/cask/azookey)、[HackGen](https://formulae.brew.sh/cask/font-hackgen)）。Codex CLI は Brewfile の `npm "@openai/codex"` で管理する。

[Tinycast](https://tinycast.dev/docs/install/) と [Orca](https://github.com/stablyai/homebrew-orca) は外部 tap から導入する。cask 名は tap を含めて指定し、同名の別アプリとの混同を避ける。

### インストール後の手動チェックリスト

- [ ] RunCat Neo を手動でインストール・設定する。
- [ ] デバイス名を変更する: システム設定 → 一般 → 情報 → 名前。
- [ ] すべてのファイル名拡張子を表示する: Finder → 設定 → 詳細 →「すべてのファイル名拡張子を表示」をオン。
- [ ] キーバインドを変更する: システム設定 → キーボード → キーボードショートカット。修飾キーの入れ替えは同画面の「修飾キー」で設定する。具体的な割り当ては未記録のため、変更時にこのチェックリストへ追記する。
- [ ] azooKey: macOS からログアウト・再ログインし、システム設定 → キーボード → 入力ソースの編集 →「+」→ 日本語 → azooKey を追加して選択する（[公式手順](https://github.com/azooKey/azooKey-Desktop#リリース版インストール)）。
- [ ] Logi Options+: Mac を再起動してインストールを反映し、起動後の案内に従って権限とデバイス設定を行う（[Homebrew の案内](https://formulae.brew.sh/cask/logi-options%2B)）。

### マシン固有値と再実行

`user.email` と ghq の root（`ghq.root`）はマシンごとの値なので `~/.gitconfig.local` に書く。
`install.sh` は未設定なら次の順で決めて書き込むので、通常は手で設定しなくてよい。

1. 元の `~/.gitconfig` にあった値（symlink に置き換える前に読み取って引き継ぐ）
2. `ghq.root` のみ: このリポを clone した場所から推定
3. どちらも無ければ書かない（ghq はデフォルトの `~/ghq` を使う）

symlink だけ張りたいときは `SKIP_PACKAGES=1 ./install.sh`。

外部の skill（例: [cloudflare/security-audit-skill](https://github.com/cloudflare/security-audit-skill)）は `install.sh` の `EXTERNAL_SKILLS` に `"<リポ URL> <skill 名>"` で書く。
`install.sh` を実行するたびに最新版で入れ直す。

## 日常運用

- 設定は `~/.zshrc` などを直接編集すればよい（実体はこのリポジトリ）。
- 新しいファイルを管理対象にするときは `home/` 配下に同じパスで置いて `./install.sh` を再実行する。
