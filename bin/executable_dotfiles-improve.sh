#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# launchd / systemd は最小PATHで起動するため明示的に補う。
# macOS(Apple Silicon)=/opt/homebrew、Linux/WSL2(linuxbrew)=/home/linuxbrew/.linuxbrew、
# mise のランタイム shims も両OSで通す（存在しないパスは無視されるだけ）。
export PATH="/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:${HOME}/.local/bin:${HOME}/.local/share/mise/shims:${HOME}/.rd/bin:/usr/bin:/bin"

MAX_OPEN_PR="${DOTFILES_IMPROVE_MAX_OPEN_PR:-3}"
DRY_RUN="${DOTFILES_IMPROVE_DRY_RUN:-0}"
REPO_SLUG="oddgai/dotfiles"

STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/dotfiles-improve"
LOG="${STATE_DIR}/last-run.log"
LOCK_DIR="${STATE_DIR}/run.lock"
mkdir -p "${STATE_DIR}"

# 全出力をログにも残す
exec > >(tee "${LOG}") 2>&1
echo "=== dotfiles-improve $(date '+%Y-%m-%d %H:%M:%S') ==="

# 多重起動防止（mkdir はアトミック。flock 不要で mac/linux 共通）
if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
  echo "another run in progress; exit"
  exit 0
fi
trap 'rmdir "${LOCK_DIR}" 2>/dev/null || true' EXIT

# 前提コマンド確認
for c in chezmoi git gh; do
  if ! command -v "$c" >/dev/null 2>&1; then echo "missing command: $c; abort"; exit 1; fi
done

REPO="$(chezmoi source-path)"
cd "${REPO}"

# 作業ツリーがクリーンか
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "working tree dirty; abort"
  exit 1
fi

git fetch --quiet origin main || true
git checkout --quiet main
git pull --quiet --ff-only origin main || true

# PR 乱立ガード
open_pr="$(gh pr list --repo "${REPO_SLUG}" --state open --json headRefName \
  --jq '[.[] | select(.headRefName | startswith("improve/dotfiles-"))] | length' 2>/dev/null || echo 0)"
echo "open auto PRs: ${open_pr}"
if [ "${open_pr:-0}" -ge "${MAX_OPEN_PR}" ]; then
  echo "open auto PRs >= ${MAX_OPEN_PR}; skip"
  exit 0
fi

if [ "${DRY_RUN}" = "1" ]; then
  echo "DRY_RUN=1: would invoke 'claude -p /improve-dotfiles'"
  exit 0
fi

if ! command -v claude >/dev/null 2>&1; then echo "missing command: claude; abort"; exit 1; fi

claude -p "/improve-dotfiles" \
  --permission-mode acceptEdits \
  --allowedTools "Read Edit Write Glob Grep Bash(git:*) Bash(gh:*) Bash(jq:*) Bash(chezmoi:*) Bash(date:*) Bash(rg:*) Bash(ls:*) Bash(cat:*)" \
  || echo "claude exited non-zero"

echo "=== done $(date '+%H:%M:%S') ==="
