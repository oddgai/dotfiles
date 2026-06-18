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
