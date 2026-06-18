# Self-Improving Dotfiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** dotfiles を「忘れても勝手に改善される」状態にする。ローカル日次とクラウド週次の2系統が改善案を PR として積み、ユーザーはレビューして merge するだけにする。

**Architecture:** 共通手順を skill `dotfiles-self-improvement` に集約し、ローカルのスラッシュコマンド／headless ランナー／OS別スケジューラ（launchd / systemd user timer）と、クラウドの `/schedule` Routine がそれを使う。すべて chezmoi 管理下に置き、変更は source 側（`dot_` 名）を編集。安全網は品質ゲート（verify / content / publicity）＋ GitHub branch protection（PR必須・承認必須）＋保守的変更。

**Tech Stack:** chezmoi, bash, Claude Code CLI (`claude -p`), gh CLI, launchd (macOS), systemd user timer (Linux/WSL2), GitHub branch protection API。

## Global Constraints

- 対象リポジトリ: `oddgai/dotfiles`（**public**）。chezmoi source = `$(chezmoi source-path)`。
- 対象 OS: macOS (Apple Silicon) / Linux (WSL2)。OS固有ファイルは `.chezmoiignore` でゲートする。
- 編集は chezmoi source（`dot_` 名）。`~/` 直下を直接書き換えない。
- マシン固有値はテンプレート化（`{{ .chezmoi.homeDir }}` / OS分岐 / `[data]`）。
- 秘密情報・ランタイム状態（`~/.claude/projects` 等）はコミット禁止。読むのは可。
- 自動改善は **PR のみ**。main へ直 push・自動 merge は禁止。空 PR は作らない。
- ブランチ名: `improve/dotfiles-local-YYYYMMDD` / `improve/dotfiles-cloud-YYYYMMDD`。
- PR 乱立防止の既定上限: open の `improve/dotfiles-*` PR が 3 件以上なら新規作成を skip。
- シェルスクリプトは `#!/usr/bin/env bash` + `set -o errexit -o nounset -o pipefail`。構文検証は `bash -n`。

---

### Task 1: 頭脳 skill `dotfiles-self-improvement`

**Files:**
- Create: `dot_claude/skills/dotfiles-self-improvement/SKILL.md`

**Interfaces:**
- Produces: skill 名 `dotfiles-self-improvement`。Task 2（コマンド）と Task 8（クラウド Routine doc）が参照する。

- [ ] **Step 1: SKILL.md を作成**

Create `dot_claude/skills/dotfiles-self-improvement/SKILL.md`:

```markdown
---
name: dotfiles-self-improvement
description: chezmoi管理の公開dotfilesリポ(oddgai/dotfiles)を安全に自己改善する手順。シグナル源の集め方、保守的な変更規律、品質ゲート(verify-diff / content-review / publicity-review)、chezmoi作法、PR作成フローを定める。/improve-dotfilesコマンドや定期実行・クラウドRoutineからdotfilesの改善PRを作るときに使う。
---

# dotfiles 自己改善

chezmoi で管理する **公開** リポジトリ `oddgai/dotfiles` を安全に少しずつ改善する。
成果物は必ず PR。main への直 push・自動 merge はしない。

## スコープ

- 変更可: リポ全体（`dot_claude/rules/`, `dot_claude/skills/`, `dot_claude/settings.json`,
  `dot_claude/CLAUDE.md`, `*.tmpl`, `dot_Brewfile.tmpl`, `docs/` など）。
- 変更禁止: 秘密情報、マシン固有値（`[data]` や hostname 依存）、ランタイム状態。
  `~/.claude/projects` 等は **読むだけ**、内容のコミットは厳禁。

## シグナル源（改善ネタの見つけ方）

ローカル実行時のみ使える:

- 直近のセッションログ `~/.claude/projects/<encoded-cwd>/*.jsonl` を解析する。
  自分の発話だけ抽出する例:

  \`\`\`bash
  latest=$(ls -t ~/.claude/projects/*/*.jsonl 2>/dev/null | head -1)
  jq -r 'select(.type=="user") | .message.content // empty' "$latest" 2>/dev/null | tail -50
  \`\`\`

  着目するシグナル: ユーザーの修正・やり直し指示／繰り返される同じ指示／
  ループした失敗ステップ／レビュー系 skill が指摘した SKILL.md の箇所。

共通（ローカル・クラウド両方）:

- git 履歴、open issue、リポ内 TODO/FIXME、skill/rules の陳腐化。
- Web 検索で最新の Claude Code / chezmoi / dotfiles 運用の慣行。

## 変更規律（保守的）

- 確信が持てる改善だけ行う。小さく加点的に。
- 1 回の実行で扱う改善は数件まで。
- 検討したが変更しなかったものと理由も PR 本文に残す。

## 品質ゲート（PR 前に通す）

各ゲートは最大 3 回まで内部ループ、3 ゲート全体も最大 3 回まで外側ループ。
「全ゲートで編集なし」または「致命的問題で中止」で終了。

1. **verify-diff**: 編集後のファイルを読み直し、意図を実際に達成したか実証する。
2. **content-review**: SKILL.md / rules の構造・スタイル・冗長性を点検する
   （frontmatter は `name` + `description`、重複排除、簡潔さ）。
3. **publicity-review（最重要・公開リポ）**: `git diff` を走査し、以下を検出したら
   除去またはテンプレート化する。少しでも不安なら **その変更を捨てる**。
   - 秘密・トークン・API キー・`.env` の値
   - ユーザー名入りの絶対パス（→ `{{ .chezmoi.homeDir }}`）
   - 社内/プロジェクト固有名（例: 勤務先名・社内リポ名・Jira ID・インフラ名）や
     private リポの内容
   - セッションログの生引用・個人情報

## chezmoi 作法

- 編集は source 側（`dot_` 名）。`~/` 直下は触らない。
- マシン固有値は `{{ .chezmoi.homeDir }}` / OS 分岐 / `[data]` でテンプレート化。
- merge 後の反映はユーザーが `chezmoi apply` で行う（このループは行わない）。

## PR 作成フロー

1. クリーンな `main` から作業ブランチを切る:
   `improve/dotfiles-local-YYYYMMDD`（ローカル）/ `improve/dotfiles-cloud-YYYYMMDD`（クラウド）。
   日付は `date +%Y%m%d`。
2. 変更をコミット（説明的なメッセージ）。
3. `gh pr create` で PR。本文は次の定型:
   - **変更点**: 何をなぜ変えたか
   - **使ったシグナル**: 一般化した教訓のみ（**セッションログの生引用は禁止**）
   - **見送った項目と理由**
   - **leak チェック結果**: publicity-review で確認した旨
4. 確信ある改善が無ければ PR を作らず終了する（空 PR 禁止）。
```

- [ ] **Step 2: chezmoi が source として認識するか検証**

Run: `cd "$(chezmoi source-path)" && chezmoi cat ~/.claude/skills/dotfiles-self-improvement/SKILL.md | head -5`
Expected: frontmatter（`---` と `name: dotfiles-self-improvement`）が表示される。

- [ ] **Step 3: managed に含まれるか確認**

Run: `chezmoi managed | grep dotfiles-self-improvement`
Expected: `.claude/skills/dotfiles-self-improvement/SKILL.md` が表示される。

- [ ] **Step 4: コミット**

```bash
cd "$(chezmoi source-path)"
git add dot_claude/skills/dotfiles-self-improvement/SKILL.md
git commit -m "feat: add dotfiles-self-improvement skill"
```

---

### Task 2: ローカル入口コマンド `/improve-dotfiles`

**Files:**
- Create: `dot_claude/commands/improve-dotfiles.md`

**Interfaces:**
- Consumes: Task 1 の skill `dotfiles-self-improvement`。
- Produces: スラッシュコマンド `/improve-dotfiles`。Task 3 のランナーが `claude -p "/improve-dotfiles"` で起動する。

- [ ] **Step 1: コマンドファイルを作成**

Create `dot_claude/commands/improve-dotfiles.md`:

```markdown
---
description: dotfilesリポを自己改善し、改善PRを作成する
argument-hint: "[注力したい領域 (任意)]"
allowed-tools: Read, Edit, Write, Glob, Grep, Bash(git:*), Bash(gh:*), Bash(jq:*), Bash(chezmoi:*), Bash(date:*), Bash(rg:*), Bash(ls:*), Bash(cat:*)
---

`dotfiles-self-improvement` skill に従って、このリポジトリ（chezmoi source）を自己改善する。

- シグナル源: **ローカルのセッション振り返り**（`~/.claude/projects/*.jsonl`）を中心に、
  git 履歴・open issue・リポの陳腐化も見る。
- `$ARGUMENTS` が与えられていれば、その領域に注力する。
- 必ず skill の品質ゲート（verify-diff / content-review / publicity-review）を通す。
- 成果物は `improve/dotfiles-local-YYYYMMDD` ブランチの PR。確信ある改善が無ければ何もしない。
- main への直 push・自動 merge はしない。
```

- [ ] **Step 2: render を検証**

Run: `chezmoi cat ~/.claude/commands/improve-dotfiles.md | head -5`
Expected: frontmatter に `description:` と `allowed-tools:` が見える。

- [ ] **Step 3: コミット**

```bash
cd "$(chezmoi source-path)"
git add dot_claude/commands/improve-dotfiles.md
git commit -m "feat: add /improve-dotfiles command"
```

---

### Task 3: headless ランナー `bin/dotfiles-improve.sh`

**Files:**
- Create: `bin/executable_dotfiles-improve.sh`  （chezmoi で `~/bin/dotfiles-improve.sh`、実行権限付き）

**Interfaces:**
- Consumes: コマンド `/improve-dotfiles`（Task 2）。`chezmoi`, `claude`, `gh`, `jq` が PATH 上にあること。
- Produces: `~/bin/dotfiles-improve.sh`。Task 5/6 のスケジューラが絶対パスで起動する。
  環境変数 `DOTFILES_IMPROVE_DRY_RUN=1` で claude 呼び出しをスキップ（テスト用）、
  `DOTFILES_IMPROVE_MAX_OPEN_PR`（既定 3）で乱立上限を上書き。

- [ ] **Step 1: ランナーを作成**

Create `bin/executable_dotfiles-improve.sh`:

```bash
#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# launchd / systemd は最小PATHで起動するため明示的に補う
export PATH="/opt/homebrew/bin:/usr/local/bin:${HOME}/.local/bin:${HOME}/.rd/bin:/usr/bin:/bin"

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
```

- [ ] **Step 2: 構文チェック（失敗しないことを確認）**

Run: `bash -n "$(chezmoi source-path)/bin/executable_dotfiles-improve.sh"`
Expected: 出力なし・終了コード 0（構文エラーなし）。

- [ ] **Step 3: 実行権限付きで配置されるか確認**

Run: `chezmoi managed | grep 'bin/dotfiles-improve.sh'`
Expected: `bin/dotfiles-improve.sh` が表示される（`executable_` 接頭辞により適用時に実行権限が付く）。

- [ ] **Step 4: ドライランで挙動を検証**

```bash
cd "$(chezmoi source-path)"
DOTFILES_IMPROVE_DRY_RUN=1 bash bin/executable_dotfiles-improve.sh
```
Expected: ログに `DRY_RUN=1: would invoke 'claude -p /improve-dotfiles'` が出て、claude を起動せず終了コード 0。`~/.local/state/dotfiles-improve/last-run.log` が生成される。

- [ ] **Step 5: コミット**

```bash
cd "$(chezmoi source-path)"
git add bin/executable_dotfiles-improve.sh
git commit -m "feat: add headless dotfiles-improve runner"
```

---

### Task 4: branch protection 設定スクリプト

**Files:**
- Create: `bin/executable_setup-branch-protection.sh`  （chezmoi で `~/bin/setup-branch-protection.sh`）

**Interfaces:**
- Consumes: `gh`（認証済み）。
- Produces: `~/bin/setup-branch-protection.sh [owner/repo]`。一度実行すれば main が保護される。

- [ ] **Step 1: スクリプトを作成**

Create `bin/executable_setup-branch-protection.sh`:

```bash
#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# main ブランチを保護する（PR必須・承認1件必須・管理者も対象）。
# 承認1件必須により、PR作成者(=自分)は自分のPRを承認できず、headless実行による
# 自動mergeが構造的に不可能になる。
REPO="${1:-oddgai/dotfiles}"

gh api -X PUT "repos/${REPO}/branches/main/protection" --input - <<'JSON'
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": false
}
JSON

echo "branch protection set on ${REPO} main (PR required, 1 approval, enforce_admins=true)"
```

- [ ] **Step 2: 構文チェック**

Run: `bash -n "$(chezmoi source-path)/bin/executable_setup-branch-protection.sh"`
Expected: 出力なし・終了コード 0。

- [ ] **Step 3: コミット**

```bash
cd "$(chezmoi source-path)"
git add bin/executable_setup-branch-protection.sh
git commit -m "feat: add branch protection setup script"
```

- [ ] **Step 4:（外部副作用・実行は手動）保護を適用**

> これは GitHub 側を変更する外部操作。実装者は実行せず、ユーザーに案内する。
> ユーザーが `chezmoi apply` 後に `~/bin/setup-branch-protection.sh` を実行する。
> 確認: `gh api repos/oddgai/dotfiles/branches/main/protection --jq '.required_pull_request_reviews.required_approving_review_count'` が `1` を返す。

---

### Task 5: macOS スケジューラ（launchd）

**Files:**
- Create: `Library/LaunchAgents/com.oddgai.dotfiles-improve.plist.tmpl`  （chezmoi で `~/Library/LaunchAgents/com.oddgai.dotfiles-improve.plist`）
- Modify: `.chezmoiignore`

**Interfaces:**
- Consumes: `~/bin/dotfiles-improve.sh`（Task 3）。
- Produces: launchd ラベル `com.oddgai.dotfiles-improve`（毎日 13:00 起動）。Task 7 が登録する。

- [ ] **Step 1: plist テンプレートを作成**

Create `Library/LaunchAgents/com.oddgai.dotfiles-improve.plist.tmpl`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.oddgai.dotfiles-improve</string>
  <key>ProgramArguments</key>
  <array>
    <string>{{ .chezmoi.homeDir }}/bin/dotfiles-improve.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>13</integer>
    <key>Minute</key>
    <integer>0</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>/tmp/dotfiles-improve.out</string>
  <key>StandardErrorPath</key>
  <string>/tmp/dotfiles-improve.err</string>
</dict>
</plist>
```

- [ ] **Step 2: `.chezmoiignore` に非 darwin ゲートを追加**

`.chezmoiignore` の末尾に追記（既存の karabiner ゲートとは別ブロックでよい）:

```
{{ if ne .chezmoi.os "darwin" -}}
Library/LaunchAgents/com.oddgai.dotfiles-improve.plist
{{ end -}}
```

- [ ] **Step 3: darwin で render & plist 妥当性を検証**

```bash
cd "$(chezmoi source-path)"
chezmoi cat ~/Library/LaunchAgents/com.oddgai.dotfiles-improve.plist > /tmp/check.plist
plutil -lint /tmp/check.plist
```
Expected: `/tmp/check.plist: OK`。`ProgramArguments` の path が絶対パス（`/Users/...`）に展開されている。

- [ ] **Step 4: コミット**

```bash
cd "$(chezmoi source-path)"
git add "Library/LaunchAgents/com.oddgai.dotfiles-improve.plist.tmpl" .chezmoiignore
git commit -m "feat: add macOS launchd agent for daily improve run"
```

---

### Task 6: Linux/WSL2 スケジューラ（systemd user timer）

**Files:**
- Create: `dot_config/systemd/user/dotfiles-improve.service`  （`~/.config/systemd/user/dotfiles-improve.service`）
- Create: `dot_config/systemd/user/dotfiles-improve.timer`  （`~/.config/systemd/user/dotfiles-improve.timer`）
- Modify: `.chezmoiignore`

**Interfaces:**
- Consumes: `~/bin/dotfiles-improve.sh`（Task 3）。systemd の `%h` がホームに展開される。
- Produces: user unit `dotfiles-improve.timer`（毎日 13:00）。Task 7 が enable する。

- [ ] **Step 1: service unit を作成**

Create `dot_config/systemd/user/dotfiles-improve.service`:

```ini
[Unit]
Description=dotfiles self-improvement run

[Service]
Type=oneshot
ExecStart=%h/bin/dotfiles-improve.sh
```

- [ ] **Step 2: timer unit を作成**

Create `dot_config/systemd/user/dotfiles-improve.timer`:

```ini
[Unit]
Description=Run dotfiles self-improvement daily

[Timer]
OnCalendar=*-*-* 13:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

- [ ] **Step 3: `.chezmoiignore` に非 linux ゲートを追加**

`.chezmoiignore` の末尾に追記:

```
{{ if ne .chezmoi.os "linux" -}}
.config/systemd/user/dotfiles-improve.service
.config/systemd/user/dotfiles-improve.timer
{{ end -}}
```

- [ ] **Step 4: ファイルが managed か（darwin では ignore される点も）確認**

Run: `chezmoi cat ~/.config/systemd/user/dotfiles-improve.timer 2>&1 | head -3`
Expected: macOS 実行時は ignore されるため何も出ない（エラー可）。これは正常。
内容自体の確認は次の Step。

- [ ] **Step 5: unit ファイルの中身を目視確認**

Run: `cat "$(chezmoi source-path)/dot_config/systemd/user/dotfiles-improve.timer"`
Expected: `OnCalendar=*-*-* 13:00:00` と `Persistent=true` を含む。

- [ ] **Step 6: コミット**

```bash
cd "$(chezmoi source-path)"
git add dot_config/systemd/user/dotfiles-improve.service dot_config/systemd/user/dotfiles-improve.timer .chezmoiignore
git commit -m "feat: add systemd user timer for daily improve run (linux)"
```

---

### Task 7: スケジューラ登録フック

**Files:**
- Create: `run_onchange_register-scheduler.sh.tmpl`

**Interfaces:**
- Consumes: Task 5 の plist テンプレート、Task 6 の timer。`launchctl`(mac) / `systemctl --user`(linux)。
- Produces: `chezmoi apply` 時に、スケジューラ定義が変わったら自動で再登録する。

- [ ] **Step 1: run_onchange フックを作成**

Create `run_onchange_register-scheduler.sh.tmpl`:

```bash
#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

{{ if eq .chezmoi.os "darwin" -}}
# launchd plist hash: {{ include "Library/LaunchAgents/com.oddgai.dotfiles-improve.plist.tmpl" | sha256sum }}
PLIST="${HOME}/Library/LaunchAgents/com.oddgai.dotfiles-improve.plist"
if [ -f "${PLIST}" ]; then
  launchctl bootout "gui/$(id -u)/com.oddgai.dotfiles-improve" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "${PLIST}"
  echo "launchd agent (re)registered"
fi
{{ else if eq .chezmoi.os "linux" -}}
# systemd timer hash: {{ include "dot_config/systemd/user/dotfiles-improve.timer" | sha256sum }}
if command -v systemctl >/dev/null 2>&1; then
  systemctl --user daemon-reload
  systemctl --user enable --now dotfiles-improve.timer
  echo "systemd user timer enabled"
fi
{{ end -}}
```

- [ ] **Step 2: render を検証（darwin）**

Run: `chezmoi cat ~/.local/share/chezmoi/run_onchange_register-scheduler.sh.tmpl 2>/dev/null || chezmoi execute-template < "$(chezmoi source-path)/run_onchange_register-scheduler.sh.tmpl"`
Expected: darwin では `launchctl bootstrap` を含むスクリプトが描画され、テンプレートエラーが出ない。

- [ ] **Step 3: 構文チェック（描画後）**

```bash
cd "$(chezmoi source-path)"
chezmoi execute-template < run_onchange_register-scheduler.sh.tmpl | bash -n -
```
Expected: 出力なし・終了コード 0。

- [ ] **Step 4: コミット**

```bash
cd "$(chezmoi source-path)"
git add run_onchange_register-scheduler.sh.tmpl
git commit -m "feat: register scheduler on chezmoi apply (launchd/systemd)"
```

---

### Task 8: クラウド週次 Routine の運用ドキュメント

**Files:**
- Create: `docs/self-improving-loop.md`
- Modify: `.chezmoiignore`（`docs` を ignore に追加。まだ無ければ）

**Interfaces:**
- Consumes: Task 1 の skill 思想（自己完結プロンプトに要点を再掲）。
- Produces: `/schedule` 用の Routine プロンプトと設定手順。

- [ ] **Step 1: `.chezmoiignore` に `docs` を追加（未追加なら）**

`.chezmoiignore` に `docs` 行が無ければ追記する（`docs/` を `~/docs` へ配置しないため）:

```
docs
```

確認: `grep -qx docs "$(chezmoi source-path)/.chezmoiignore" && echo present || echo missing`

- [ ] **Step 2: 運用ドキュメントを作成**

Create `docs/self-improving-loop.md`:

````markdown
# 自己改善ループ 運用ガイド

dotfiles を日次（ローカル）＋週次（クラウド）で自己改善する仕組み。
成果はすべて PR。レビューして merge → `chezmoi apply` で反映する。

## 構成

- ローカル日次: launchd(mac)/systemd timer(WSL2) → `~/bin/dotfiles-improve.sh`
  → `claude -p "/improve-dotfiles"` → skill `dotfiles-self-improvement` →（自分のクセを反映）→ PR
- クラウド週次: `/schedule` Routine →（リポレビュー＋Web検索で最新慣行）→ PR

## 初期セットアップ

1. `chezmoi apply`（skill・コマンド・ランナー・スケジューラを配置し登録）
2. `~/bin/setup-branch-protection.sh` を一度実行（main を保護）
3. 下の Routine を `/schedule` で登録

## クラウド Routine プロンプト（/schedule に登録）

スケジュール: 毎週月曜 09:00 JST。対象リポ: `oddgai/dotfiles`。

```
あなたは公開dotfilesリポ oddgai/dotfiles を保守的に自己改善するエージェント。
成果物は必ずPR。mainへの直push・自動mergeはしない。空PRは作らない。

手順:
1. リポを最新のmainで作業。改善ネタは「リポ全体レビュー」「open issue」「Web検索で
   最新のClaude Code / chezmoi / dotfiles運用の慣行」から集める（ローカルのセッション
   ログには触れない）。
2. 確信が持てる小さな改善だけ行う。編集はchezmoiのsource側(dot_名)。マシン固有値は
   {{ .chezmoi.homeDir }} / OS分岐 / [data] でテンプレート化する。
3. PR前に品質ゲートを通す:
   - verify-diff: 編集後ファイルを読み直し意図を達成したか実証
   - content-review: SKILL.md/rulesの構造・冗長性
   - publicity-review(最重要): diffから秘密・トークン・ユーザー名入り絶対パス・
     社内/プロジェクト固有名・private内容・個人情報を検出したら除去。不安なら捨てる。
4. improve/dotfiles-cloud-YYYYMMDD ブランチでPR作成。本文に「変更点／使ったシグナル
   (一般化のみ)／見送った項目と理由／leakチェック結果」を書く。
5. 確信ある改善が無ければ何もしない。
```

## ログ・確認

- ローカル実行ログ: `~/.local/state/dotfiles-improve/last-run.log`
- open な自動PR: `gh pr list --repo oddgai/dotfiles --search "head:improve/dotfiles-"`
- launchd 状態(mac): `launchctl list | grep dotfiles-improve`
- timer 状態(WSL2): `systemctl --user list-timers | grep dotfiles-improve`
````

- [ ] **Step 3: ドキュメントが chezmoi の適用対象外（docs ignore）であることを確認**

Run: `chezmoi managed | grep -c 'self-improving-loop' || true`
Expected: `0`（`docs` は ignore されるため managed に出ない）。

- [ ] **Step 4: コミット**

```bash
cd "$(chezmoi source-path)"
git add docs/self-improving-loop.md .chezmoiignore
git commit -m "docs: add self-improving loop guide and cloud routine prompt"
```

- [ ] **Step 5:（外部副作用・実行は手動）Routine を登録**

> `/schedule` スキルで上記プロンプトを毎週月曜 09:00 JST・対象 `oddgai/dotfiles` で登録する。
> 実装者は登録せず、ユーザーに案内する。

---

### Task 9（任意）: SessionStart で未レビュー PR を通知

**Files:**
- Modify: `dot_claude/settings.json`

**Interfaces:**
- Consumes: `gh`。
- Produces: Claude 起動時に open な自動改善 PR 件数を表示する SessionStart フック。

- [ ] **Step 1: settings.json の SessionStart に通知フックを追加**

`dot_claude/settings.json` の `hooks.SessionStart` 配列に、次の hook オブジェクトを追加する
（既存の superset 通知 hook は残す。配列にもう 1 要素足す）:

```json
{
  "hooks": [
    {
      "type": "command",
      "command": "n=$(gh pr list --repo oddgai/dotfiles --state open --json headRefName --jq '[.[]|select(.headRefName|startswith(\"improve/dotfiles-\"))]|length' 2>/dev/null || echo 0); [ \"${n:-0}\" -gt 0 ] && echo \"📝 未レビューの自動改善PRが ${n}件 あります\" || true"
    }
  ]
}
```

- [ ] **Step 2: JSON 妥当性を検証**

Run: `chezmoi cat ~/.claude/settings.json | jq . > /dev/null && echo valid`
Expected: `valid`（JSON として壊れていない）。

- [ ] **Step 3: コミット**

```bash
cd "$(chezmoi source-path)"
git add dot_claude/settings.json
git commit -m "feat: notify open auto-improve PRs on session start"
```

---

### Task 10: 統合適用と動作確認

**Files:** （新規作成なし。適用と検証のみ）

- [ ] **Step 1: 全体の render とテンプレートエラーが無いことを確認**

Run: `cd "$(chezmoi source-path)" && chezmoi apply --dry-run 2>&1 | grep -iE 'error' || echo "no errors"`
Expected: `no errors`。

- [ ] **Step 2: 適用（ユーザー確認のうえ実施）**

```bash
chezmoi diff   # 変更内容を確認
chezmoi apply  # skill/command/runner/scheduler を配置し、run_onchange で登録
```
Expected: `~/.claude/skills/dotfiles-self-improvement/SKILL.md`, `~/.claude/commands/improve-dotfiles.md`,
`~/bin/dotfiles-improve.sh`（実行可能）が配置され、OS に応じた launchd/systemd 登録メッセージが出る。

- [ ] **Step 3: スケジューラ登録を確認**

macOS: `launchctl list | grep dotfiles-improve` → ラベルが表示される。
WSL2: `systemctl --user list-timers | grep dotfiles-improve` → timer が表示される。

- [ ] **Step 4: ランナーのドライラン（claude を起動せず一連のガードを確認）**

Run: `DOTFILES_IMPROVE_DRY_RUN=1 ~/bin/dotfiles-improve.sh`
Expected: PR 件数チェックを通り、`DRY_RUN=1: would invoke ...` を表示して終了コード 0。

- [ ] **Step 5: branch protection / Routine の手動セットアップを案内**

`~/bin/setup-branch-protection.sh` 実行と、`/schedule` での Routine 登録（Task 8 Step 5）をユーザーに案内する。

---

## Self-Review

- **Spec coverage**: skill(§5)=Task1 / command(§6.1)=Task2 / runner(§6.2)=Task3 /
  scheduler mac(§6.3)=Task5 / scheduler linux(§6.3)=Task6 / register hook(§3-5)=Task7 /
  cloud routine(§7)=Task8 / branch protection(§8)=Task4 / 通知(§9)=Task9 /
  乱立・ログ・空振り(§9)=Task3 に内包。全項目に対応タスクあり。
- **Placeholder scan**: TBD/TODO なし。各ファイルは完全な内容を記載。
- **Type consistency**: ブランチ名 `improve/dotfiles-{local|cloud}-YYYYMMDD`、環境変数
  `DOTFILES_IMPROVE_DRY_RUN` / `DOTFILES_IMPROVE_MAX_OPEN_PR`、ラベル
  `com.oddgai.dotfiles-improve`、unit 名 `dotfiles-improve.timer` を全タスクで一貫使用。
```
