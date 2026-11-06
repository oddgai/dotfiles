# oh-my-zsh は使わず、プロンプトとプラグインは Homebrew で入れたものを読み込む（~/.Brewfile 参照）

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="$HOME/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)

# Homebrew の PATH などを設定する（公式インストーラは ~/.zprofile への追記を案内するが、ここで面倒を見る）
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
BREW_PREFIX="${HOMEBREW_PREFIX:-/opt/homebrew}"

# ---- 履歴 ----
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=10000
setopt extended_history       # 実行時刻も記録する
setopt share_history          # 複数のシェル間で履歴を共有する
setopt hist_expire_dups_first # 上限を超えたら重複から消す
setopt hist_ignore_dups       # 直前と同じコマンドは記録しない
setopt hist_ignore_space      # 先頭が空白のコマンドは記録しない
setopt hist_verify            # !! などの展開結果を実行前に確認する

# ---- ディレクトリ移動・その他 ----
setopt auto_cd auto_pushd pushd_ignore_dups pushd_minus
setopt interactive_comments

# ---- 補完 ----
fpath=("$BREW_PREFIX/share/zsh-completions" "$BREW_PREFIX/share/zsh/site-functions" $fpath)
autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'  # 大文字小文字を区別しない
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors ''
# aws CLI は bash 形式の補完を使う
if command -v aws_completer >/dev/null 2>&1; then
  autoload -Uz bashcompinit && bashcompinit
  complete -C aws_completer aws
fi

# ---- キーバインド ----
bindkey -e
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search   # ↑: 入力途中の文字列で履歴を前方検索
bindkey '^[[B' down-line-or-beginning-search # ↓

# ---- プロンプト (pure) ----
autoload -Uz promptinit && promptinit
prompt pure

# ---- エイリアス ----
export CLICOLOR=1
alias ls='ls -G'
alias la='ls -lAh'
alias g='git'
alias repo='cd "$(ghq list -p | fzf)"'
alias ccd='claude'

# ---- ツール ----
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# Added by Antigravity
export PATH="$HOME/.antigravity/antigravity/bin:$PATH"
# macOS の /usr/bin/curl は CA の失効を反映しないので、Homebrew の curl を優先する
export PATH="$BREW_PREFIX/opt/curl/bin:$PATH"

# マシン固有の設定（DATABRICKS_CLUSTER_ID など）は ~/.zshrc.local に書く
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

[ -f "$HOME/.safe-chain/scripts/init-posix.sh" ] && source "$HOME/.safe-chain/scripts/init-posix.sh" # Safe-chain Zsh initialization script
command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"

# The next line updates PATH for the Google Cloud SDK.
if [ -f "$HOME/Downloads/google-cloud-sdk/path.zsh.inc" ]; then . "$HOME/Downloads/google-cloud-sdk/path.zsh.inc"; fi

# The next line enables shell command completion for gcloud.
if [ -f "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc" ]; then . "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc"; fi

if command -v podman >/dev/null 2>&1; then
  podman_socket="$(podman machine inspect --format '{{.ConnectionInfo.PodmanSocket.Path}}' 2>/dev/null)"
  [ -n "$podman_socket" ] && export DOCKER_HOST="unix://$podman_socket"
  unset podman_socket
fi

# ---- プラグイン ----
[ -f "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && source "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
[ -f "$BREW_PREFIX/share/zsh-you-should-use/you-should-use.plugin.zsh" ] && source "$BREW_PREFIX/share/zsh-you-should-use/you-should-use.plugin.zsh"
# syntax-highlighting は他の ZLE ウィジェット定義より後に読み込む必要があるので最後に置く
[ -f "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] && source "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
