---
description: 事前チェックを通してからGitHub PRを作成する
argument-hint: "[PRタイトル (任意)]"
allowed-tools: Read, Grep, Glob, Bash(git:*), Bash(gh:*), Bash(make:*), Bash(mise:*), Bash(npm:*), Bash(pnpm:*)
---

GitHub の Pull Request を作成する。次の手順を順に実行する。

## 1. 事前チェック

リポジトリのチェックコマンドを **自動検出** して実行する（最初に見つかったものを使う）:

- `Makefile` に `check` / `lint` / `test` ターゲットがあれば `make <それ>`
- `mise.toml` にタスクがあれば `mise run check`（または相当）
- `package.json` の scripts に `lint` / `test` があれば該当パッケージマネージャで実行
  （`pnpm-lock.yaml`→pnpm / `package-lock.json`→npm）

該当が無ければスキップしてよい。失敗したら原因を分析して正しく修正し、
（lint ルールの回避や型の握り潰しはしない）パスするまで再実行する。
未コミットの修正が出たら適切なメッセージでコミットする。

## 2. Git 状態の確認

- `git status` と `git diff` で変更を確認。
- ベースブランチを特定（`git merge-base HEAD main` 等）。
- `git log <base>..HEAD --oneline` で PR に入るコミットを確認。コミットメッセージが
  明確かを点検する。

## 3. PR 作成

- 全コミットを読んで変更の全体像を把握する。
- `gh pr create` で PR を作成。本文は次の構成にする:
  - **Summary**: 何を・なぜ変えたか
  - **Test plan**: どう検証したか（実行したチェック・手順）
  - **Related issues**: 関連 issue があれば
- タイトルは `$ARGUMENTS` があればそれを使い、無ければ変更内容から簡潔に生成する。

## 4. 結果

- 作成された PR の URL を表示する。
- CI がある場合は `gh pr checks` で状態を確認するよう案内する。

## 注意

- 事前チェックがあれば必ずパスさせてから PR を作る。回避策で通さない。
- 生成物ディレクトリ（generated 等）や lockfile を不用意に編集しない。
- リポジトリの `CLAUDE.md` / `AGENTS.md` のルールに従う。
