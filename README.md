# dotfiles

[chezmoi](https://www.chezmoi.io/) で管理する dotfiles。どの PC でも同じ環境を再現する。

## 構成

| 層 | ツール | 役割 |
| --- | --- | --- |
| 設定ファイル | **chezmoi** | `.zshrc` などの配置・マシン差分の吸収（テンプレート） |
| ランタイム | **mise** | 言語・CLI ツールのバージョン管理 |
| アプリ | **Homebrew** | CLI / GUI アプリ（`~/.Brewfile`） |

対象 OS: macOS (Apple Silicon) / Linux (WSL2)

## 管理対象

| ソース | 配置先 | 備考 |
| --- | --- | --- |
| `dot_zshrc.tmpl` | `~/.zshrc` | マシン固有値はテンプレート化 |
| `dot_zshenv` | `~/.zshenv` | |
| `dot_gitconfig.tmpl` | `~/.gitconfig` | email はデータ変数 |
| `dot_Brewfile.tmpl` | `~/.Brewfile` | cask / VS Code 拡張は macOS 限定 |
| `run_onchange_install-packages.sh.tmpl` | （実行） | 変更時に `brew bundle` + `mise install` |

秘密情報（SSH 鍵・AWS/Azure 認証・`gh` トークン等）は **管理対象外**。

## 新しい PC でのセットアップ

```sh
# 1. Homebrew を入れる（macOS / Linuxbrew）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. chezmoi と ghq を入れる
brew install chezmoi ghq

# 3. リポジトリを取得
ghq get git@github.com:oddgai/dotfiles.git

# 4. chezmoi 初期化（email / Databricks cluster id を対話入力）
chezmoi init --source "$(ghq root)/github.com/oddgai/dotfiles"

# 5. 差分を確認してから適用
chezmoi diff
chezmoi apply
```

`apply` 時に `run_onchange` が走り、`brew bundle` と `mise install` で
ツールが一括インストールされる。

## 日常運用

| コマンド | 説明 |
| --- | --- |
| `chezmoi edit ~/.zshrc` | 管理下のファイルを編集（ソース側を編集） |
| `chezmoi diff` | 適用前の差分を確認 |
| `chezmoi apply` | 差分を反映 |
| `chezmoi add <file>` | 新しいファイルを管理対象に追加 |
| `chezmoi cd` | ソースディレクトリ（このリポジトリ）へ移動 |

ソースディレクトリはこのリポジトリ
（`~/.config/chezmoi/chezmoi.toml` の `sourceDir`）。

## マシン固有値

`~/.config/chezmoi/chezmoi.toml` の `[data]` で管理する（リポジトリには含めない）。

```toml
[data]
    email = "you@example.com"
    databricksClusterId = "xxxx-xxxxxx-xxxxxxxx"  # 無ければ省略可
```

テンプレートでの分岐:

- OS 別: `{{ if eq .chezmoi.os "darwin" }} ... {{ end }}`
- ホームパス: `{{ .chezmoi.homeDir }}`
- 任意データ: `{{ index . "databricksClusterId" }}`
