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

  ```bash
  latest=$(ls -t ~/.claude/projects/*/*.jsonl 2>/dev/null | head -1)
  jq -r 'select(.type=="user") | .message.content // empty' "$latest" 2>/dev/null | tail -50
  ```

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
