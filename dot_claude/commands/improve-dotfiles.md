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
