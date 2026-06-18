# 自己改善ループ 運用ガイド（概要）

dotfiles を自己改善する仕組み。**ローカル日次**と**クラウド週次**の2系統があり、
役割が違う。成果はすべて PR。レビューして merge → `chezmoi apply` で反映する。

## 役割分担

| 系統 | 実行 | シグナル源 | 主な対象 | 詳細 |
| --- | --- | --- | --- | --- |
| ローカル日次 | launchd(mac)/systemd(WSL2) | 自分の使い方のクセ（セッションログ）＋リポ全体 | リポ全体 | [self-improving-local.md](./self-improving-local.md) |
| クラウド週次 | `/schedule` Routine | Web 検索（Claude Code の最新機能・設定） | Claude Code 設定 | [self-improving-cloud.md](./self-improving-cloud.md) |

クラウドはローカルのセッションログにアクセスできないため、Web 収集で最新追従を担う。
ローカルは自分の操作履歴から学ぶ。役割が違うので PR が衝突しにくい。

## 共通の安全設計（公開リポ前提）

- 成果物は必ず PR。main への直 push・自動 merge はしない。空 PR は作らない。
- 品質ゲート3段（PR 前に通す）:
  - verify-diff: 編集後ファイルを読み直し意図を達成したか実証
  - content-review: 構造・冗長性
  - **publicity-review（最重要）**: 秘密・トークン・ユーザー名入り絶対パス・
    社内/プロジェクト固有名・個人情報を diff から検出したら除去。不安なら捨てる。
- chezmoi 作法: 編集は source 側（`dot_` 名）。マシン固有値は
  `{{ .chezmoi.homeDir }}` / OS 分岐 / `[data]` でテンプレート化。
- 共通の手順は skill `dotfiles-self-improvement` に集約。

## 初期セットアップ

1. `chezmoi apply`（skill・コマンド・ランナー・スケジューラを配置し登録）
2. `~/bin/setup-branch-protection.sh` を一度実行（main を保護）
3. クラウド週次を `/schedule` で登録（[self-improving-cloud.md](./self-improving-cloud.md) 参照）
