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
