# 自己改善ループ — ローカル日次

概要は [self-improving-loop.md](./self-improving-loop.md) を参照。

## 役割

自分の使い方のクセ（直近のセッションログ）＋リポ全体をシグナル源に、
日次で改善 PR を作る。クラウドからは見えないローカル固有の情報を扱う。

## 仕組み

```
launchd(mac) / systemd timer(WSL2)
  → ~/bin/dotfiles-improve.sh
    → claude -p "/improve-dotfiles"
      → skill dotfiles-self-improvement（シグナル収集 → 品質ゲート → PR）
```

- スケジュール: 毎日 13:00（plist / systemd timer。取りこぼしは次回補完）
- ブランチ: `improve/dotfiles-local-YYYYMMDD`
- ランナーは多重起動防止（ロック）と PR 乱立ガード（open の自動 PR が既定 3 件以上なら skip）を持つ
- 環境変数: `DOTFILES_IMPROVE_DRY_RUN=1`（claude を起動せず確認）、
  `DOTFILES_IMPROVE_MAX_OPEN_PR`（乱立上限の上書き、既定 3）

## セットアップ

1. `chezmoi apply` — skill・コマンド・ランナー・スケジューラを配置し、
   `run_onchange` が launchd / systemd user timer を登録
2. `~/bin/setup-branch-protection.sh` を一度実行（main を保護）

## ログ・確認

- 実行ログ: `~/.local/state/dotfiles-improve/last-run.log`
- ドライラン: `DOTFILES_IMPROVE_DRY_RUN=1 ~/bin/dotfiles-improve.sh`
- launchd 状態(mac): `launchctl list | grep dotfiles-improve`
- timer 状態(WSL2): `systemctl --user list-timers | grep dotfiles-improve`
- open な自動 PR: `gh pr list --repo oddgai/dotfiles --search "head:improve/dotfiles-"`
