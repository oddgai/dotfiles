# 自己改善 dotfiles 設計

- 日付: 2026-06-18 14:44:06
- 対象リポジトリ: `oddgai/dotfiles`（**public** / chezmoi 管理 / macOS + Linux(WSL2)）
- 参考: GENDA記事（Routines自動改善）, SonicGarden記事（self-improving loop）

## 1. 目的

dotfiles を「忘れても勝手に改善される」状態にする。手動起動に依存せず、
ローカル日次とクラウド週次の2系統が改善案を **PR** として積み、ユーザーは
レビューして merge するだけにする。

## 2. 全体方針

- 共通の手順（頭脳）を skill `dotfiles-self-improvement` に一本化（DRY）。
  ローカルコマンドもクラウド Routine もこれに従う。クラウドには skill が
  無い場合があるため、Routine プロンプトに要点を再掲して保険をかける。
- 役割分担で PR 衝突を避ける:
  - **ローカル日次** = 自分の使い方のクセ（セッション履歴。クラウドからは見えない）
  - **クラウド週次** = 外部の最新ベストプラクティス（リポレビュー＋Web検索）
- ローカル/クラウド間に Issue キューは挟まない。各実行が直接 PR を作る簡素な形。
  （SonicGarden 流の Issue キューは将来拡張として残す）

## 3. コンポーネント（すべて chezmoi 管理下）

| # | コンポーネント | source 名 | 役割 |
|---|---|---|---|
| 1 | 頭脳 skill | `dot_claude/skills/dotfiles-self-improvement/SKILL.md` | シグナル源・品質ゲート・leakチェック・chezmoi作法・PR手順を定義 |
| 2 | ローカル入口 | `dot_claude/commands/improve-dotfiles.md` | スラッシュコマンド。手動でも定期でも起動 |
| 3 | headless ランナー | `bin/executable_dotfiles-improve.sh` | 定期実行の実体。リポへ cd → `claude -p "/improve-dotfiles"` → ログ |
| 4 | スケジューラ(mac) | `Library/LaunchAgents/com.oddgai.dotfiles-improve.plist` | launchd 日次（darwin 限定） |
| 4'| スケジューラ(WSL2) | `dot_config/systemd/user/dotfiles-improve.{service,timer}` | systemd user タイマー日次（linux 限定） |
| 5 | 登録フック | `run_onchange_register-scheduler.sh.tmpl` | plist/timer 変更時に launchctl / systemctl --user で登録 |
| 6 | クラウド Routine | `docs/self-improving-loop.md` 内のプロンプト＋`/schedule` 手順 | 週1クラウド実行 |
| 7 | 運用ドキュメント | `docs/self-improving-loop.md` | 全体図・セットアップ・Routine プロンプト |
| 8 | branch protection | `bin/setup-branch-protection.sh`（GitHub側設定、一度実行） | main 直push禁止・承認必須で自動merge構造的に不可 |

## 4. データフロー

```
[ローカル日次] launchd/systemd → ランナー → claude -p /improve-dotfiles
                                              └ skill適用（ローカルlog=自分のクセ）→ 品質ゲート → PR
[クラウド週次] Routine → skill要点適用（repo+Web=最新慣行）→ 品質ゲート → PR
両方 → ユーザーがPRレビュー → merge → 次回 chezmoi apply で反映
```

## 5. 頭脳 skill の定義

### 5.1 スコープ

- 変更可: リポ全体（rules / skills / settings.json / CLAUDE.md / *.tmpl / Brewfile / docs など）
- 変更禁止: 秘密情報、マシン固有値（`[data]` や hostname 依存）、
  ランタイム状態（`~/.claude/projects` 等は読むのみ・コミット厳禁）

### 5.2 シグナル源

- ローカル限定: 直近の `~/.claude/projects/<encoded-cwd>/*.jsonl` を解析
  - ユーザーの修正・やり直し指示 / 繰り返される同じ指示 / ループした失敗 /
    レビュー系 skill の指摘
  - jq で自分の発話だけ抽出するスニペットを同梱
- 共通: git 履歴、open issue、リポ内 TODO/FIXME、skill/rules の陳腐化、
  Web 検索（最新の Claude Code / chezmoi 慣行）

### 5.3 変更規律（保守的）

- 確信が持てる改善だけ。小さく加点的に。
- 検討したが変更しなかったものと理由も PR 本文に書く。

### 5.4 品質ゲート（PR前に通す。各ゲート最大3回 / 全体最大3回ループ）

1. **verify-diff**: 編集後ファイルを読み直し、意図を実際に達成したか実証
2. **content-review**: SKILL.md/rules の構造・スタイル・冗長性
   （frontmatter `name`+`description`、重複排除）
3. **publicity-review（最重要・公開リポ）**: diff を走査して以下を検出したら
   除去/テンプレート化、不安なら中止
   - 秘密・トークン・鍵・`.env` 値
   - ユーザー名入り絶対パス（→ `{{ .chezmoi.homeDir }}`）
   - 社内/プロジェクト固有名（genda, c3, Jira ID, インフラ名 等）・private リポ内容
   - セッションログの生引用・個人情報

### 5.5 chezmoi 作法

- 編集は source 側（`dot_` 名）。`~/` 直下は直接触らない。
- マシン固有値はテンプレート化（`{{ .chezmoi.homeDir }}` / OS分岐 / `[data]`）。

### 5.6 PR 手順

- ブランチ: `improve/dotfiles-{local|cloud}-YYYYMMDD`
- PR 本文の定型: 変更点 / 使ったシグナル（一般化・生ログ禁止） /
  見送った項目と理由 / leak チェック結果
- main へ直push・自動merge は禁止。空PRは作らない（改善がなければ何もしない）。

## 6. ローカル日次の仕組み

### 6.1 入口コマンド `improve-dotfiles.md`

- frontmatter: `description` / `argument-hint`（任意のフォーカス領域） /
  `allowed-tools`（Read, Edit, Write, Bash の git・gh・jq・chezmoi 等）
- 本文: 「`dotfiles-self-improvement` skill に従え。シグナル源=ローカル
  セッション振り返り。`$ARGUMENTS` があればそこに注力。最終成果=PR」

### 6.2 headless ランナー `bin/executable_dotfiles-improve.sh`

1. `cd "$(chezmoi source-path)"` でリポへ
2. `main` を fetch & 最新化、作業ツリーがクリーンか確認
3. 多重起動防止: ロックファイル。open 状態の `improve/dotfiles-*` PR が
   3件以上（既定値、設定可）あれば skip
4. `claude -p "/improve-dotfiles"` を headless 実行（権限はツール許可リストで
   絞る。leak ゲート＋branch protection が安全網）
5. 実行ログを `~/.local/state/dotfiles-improve/last-run.log` に記録。
   改善なしなら何もせず終了

### 6.3 スケジューラ（OS別・chezmoi テンプレート化）

- macOS: `Library/LaunchAgents/com.oddgai.dotfiles-improve.plist`（日次・定時）→ darwin 限定
- WSL2: `dot_config/systemd/user/dotfiles-improve.{timer,service}`（日次）→ linux 限定
- `run_onchange_register-scheduler.sh.tmpl` が OS 判定して
  `launchctl bootstrap` / `systemctl --user enable --now` を実行

## 7. クラウド週次 Routine

- 作成: `/schedule` スキルで cloud routine を登録（週1、例: 毎週月曜 9:00 JST）
- 対象: `oddgai/dotfiles`（クラウドが clone して作業）
- プロンプト: skill を前提にせず要点を自己完結で埋め込む。シグナル源は
  ローカルログ以外＝リポ全体レビュー＋open issue＋Web検索
- 成果: 同じ品質ゲート（特に publicity）を通して
  `improve/dotfiles-cloud-YYYYMMDD` ブランチで PR
- プロンプト全文と `/schedule` 手順は `docs/self-improving-loop.md` に保存

## 8. branch protection（GitHub 側・main）

- PR 必須（直push禁止）
- マージに承認1件以上を要求 → PR 作成者（＝bot も自分のアカウント）は
  自分の PR を承認できないため、headless 実行による自動 merge が構造的に不可能
- `bin/setup-branch-protection.sh` で `gh api` により冪等設定（一度実行すれば OK）
- トレードオフ: 確実に効かせるには `enforce_admins=true`（管理者も対象）が必要。
  すると自身の手動直 push も main には不可になり、全変更が PR 経由になる。
  **安全重視のためデフォルト `enforce_admins=true` を採用**。

## 9. エラー処理・通知・運用

- 多重・乱立防止: ローカルはロックファイル。open の自動 PR が 3件以上（既定値）なら
  新規作成を skip（log 記録）
- 空振り: 確信ある改善がなければ PR を作らない
- 失敗時: ランナーはエラーをログに残し非ゼロ終了。次回スケジュールで再試行
  （systemd は `Persistent=true` で取りこぼし補完、launchd は次回起動時に実行）
- ログ: `~/.local/state/dotfiles-improve/last-run.log`
- 通知: 一次手段は GitHub の PR 通知。加えて任意で SessionStart フックで
  Claude 起動時に「未レビューの自動改善 PR が N件」を表示
- ロールバック: すべて PR 経由なので merge しなければ無害。merge 後の問題は
  revert PR で戻す

## 10. スコープ外（YAGNI）

- ローカル/クラウド間の Issue キュー（将来拡張）
- Slack 等の外部通知（GitHub 通知で足りる）
- シェル設定以外の OS 設定の自動チューニング
```
