---
description: GitHub PRを変更内容・CI・品質の観点でレビューする
argument-hint: "[PR番号 (省略時は現在ブランチのPR)]"
allowed-tools: Read, Grep, Glob, Bash(git:*), Bash(gh:*)
---

GitHub の Pull Request をレビューする。次の手順を実行する。

## 1. PR 情報の取得

- `$ARGUMENTS` に PR 番号があれば `gh pr view <番号>`、無ければ `gh pr view`（現在ブランチの PR）。
- `gh pr diff [<番号>]` で全差分を取得する。

## 2. 変更の分析

差分だけに頼らず、変更ファイルを **Read で実際に開いて** 文脈ごと理解する
（import・型定義・関連コードまで確認）。次の観点で見る:

- コード品質・ベストプラクティス・命名の一貫性
- バグの可能性、エラーハンドリング漏れ
- パフォーマンス上の懸念
- セキュリティ上の問題（秘密情報の混入、入力検証漏れ等）
- テストの有無（新規機能にテストがあるか）
- ハードコードされた値、未使用 import/変数

リポジトリに `CLAUDE.md` / `AGENTS.md` があれば、そのルールへの準拠も確認する。

## 3. CI 状態の確認

- `gh pr checks [<番号>]` で全チェックの状態を見る。
- 失敗があれば、どれが・なぜ失敗したかをログから特定し、レビューでブロッカーとして明記する。

## 4. 構造化フィードバック

次の形式で出力する:

### Summary
この PR が何をするか。

### CI Status
各チェックと状態（マージには全て green が前提）。

### Changes Reviewed
ファイルと主要な変更点（`file:line` 形式で参照）。

### Issues Found
重大度別に整理する。
- **Critical**: バグ・セキュリティ・データ破壊（必須修正）
- **Major**: 設計上の問題・パフォーマンス（修正すべき）
- **Minor**: スタイル・規約・改善（任意）

### Positive Aspects
良い実装・うまい解決を挙げる。

### Suggestions
改善提案。

### Approval Status
- ✅ APPROVED — CI green・Critical 無し・マージ可
- ⚠️ APPROVED WITH COMMENTS — CI green・Minor のみ・マージ可
- ❌ CHANGES REQUESTED — Critical あり、または CI 失敗（要修正）

## 注意

- CI が失敗していれば自動的に CHANGES REQUESTED。
- 差分だけでなく実ファイルを読んで文脈を理解する。
- 指摘は具体的・建設的に。`file:line` で位置を示す。
