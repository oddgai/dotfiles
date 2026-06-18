# 自己改善ループ — クラウド週次

概要は [self-improving-loop.md](./self-improving-loop.md) を参照。

## 役割

Claude Code の最新機能・設定への追従。`/schedule` のクラウド Routine が
Web 収集とリポ現状レビューに基づいて Claude Code 設定を改善する。
クラウドはローカルのセッションログにアクセスできないため、Web 収集が主軸。

## 登録（/schedule）

- スケジュール: 毎週月曜 09:00 JST（cron `0 0 * * 1` UTC）
- 対象リポ: `oddgai/dotfiles`
- ブランチ: `improve/dotfiles-cloud-YYYY-MM-DD`

下のプロンプトを `/schedule` に登録する。

## Routine プロンプト

このリポは **公開** かつ **chezmoi 管理**（source 側ファイルは `dot_` 接頭辞）。

```
あなたは公開dotfilesリポ oddgai/dotfiles の Claude Code 設定を週次で改善する
エージェントです。このリポは chezmoi 管理で、設定ファイルは source 側の dot_ 接頭辞
（例: dot_claude/settings.json は ~/.claude/settings.json に対応）。
成果物は必ず PR。main への直 push・自動 merge はしない。空 PR は作らない。

## タスク
情報を収集し、改善点があれば feature ブランチを作成して PR を開く。

### 1. 情報収集
WebSearch / WebFetch で Claude Code の最新情報を収集:
- 公式ドキュメント・リリースノート
- 新しい環境変数・設定オプション・hooks イベントの追加
- 廃止予定・変更された設定
- コミュニティで話題の設定・ベストプラクティス

### 2. 現状確認（chezmoi source。パスは dot_ 接頭辞）
- dot_claude/settings.json
- dot_claude/CLAUDE.md
- dot_claude/rules/ 配下の全ファイル
- dot_claude/skills/ 配下の全ファイル
- dot_claude/commands/ 配下の全ファイル
（agents 設定があれば dot_claude/agents/ も。無ければ読み飛ばす）

### 3. 改善判断基準
- settings.json に未設定の有用な新オプション・環境変数がある
- permissions の allow/deny に追加・削除すべきエントリがある
- hooks に追加できる便利な自動化がある
- skill・rules・CLAUDE.md に陳腐化した情報や追加すべき内容がある

### 4. 品質ゲート（PR 前に必ず通す）
- verify-diff: 編集後ファイルを読み直し、意図を達成したか実証
- content-review: SKILL.md / rules の構造・冗長性
- publicity-review（最重要・公開リポ）: diff から秘密・トークン・API キー・
  ユーザー名入り絶対パス・社内/プロジェクト固有名・private 内容・個人情報を
  検出したら除去。不安なら その変更を捨てる
- chezmoi 作法: 編集は source 側（dot_ 名）。マシン固有値は
  {{ .chezmoi.homeDir }} / OS 分岐 / [data] でテンプレート化

### 5. PR 作成
改善点がある場合:
1. improve/dotfiles-cloud-YYYY-MM-DD ブランチを作成（日付は date +%Y-%m-%d）
2. 変更をコミット
3. 日本語で PR を作成（タイトル・本文とも日本語）
4. PR 本文に「情報収集結果」「変更理由」「見送った項目と理由」「leak チェック結果」を明記
改善点が無ければ何もしないで終了する。

## 注意事項
- 変更は保守的に。確信が持てない変更はしない
- コメント・説明文は日本語で記述
- 既存の設定スタイル・フォーマットを維持する
- JSON の追加・変更時はキーのアルファベット順を保つ
- main への直 push・自動 merge はしない
```
