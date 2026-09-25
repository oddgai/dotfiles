#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail
set -o posix

input=$(cat)

CTX=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
MODEL=$(printf '%s' "$input" | jq -r '.model.display_name // .model.id // "?"')
VERSION=$(printf '%s' "$input" | jq -r '.version // "?"')
# セッションのAPI換算コスト(USD)。サブスクでも算出される
COST=$(printf '%s' "$input" | jq -r '.cost.total_cost_usd // empty')

# 使用制限（Claude.ai サブスクのみ。初回APIレスポンス後に出現し、各枠は独立に欠けうる）
FIVE=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
FIVE_RESET=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
WEEK=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# リセット時刻(Unix秒)から「HhMm left」を組み立てる
remaining() {
  now=$(date +%s)
  rem=$(( $1 - now ))
  if [ "$rem" -lt 0 ]; then rem=0; fi
  printf '%dh%02dm left' "$(( rem / 3600 ))" "$(( (rem % 3600) / 60 ))"
}

line="${CTX}% context used | ${MODEL}"

if [ -n "$FIVE" ]; then
  if [ -n "$FIVE_RESET" ]; then
    line="${line} | session $(printf '%.0f' "$FIVE")% ($(remaining "$FIVE_RESET"))"
  else
    line="${line} | session $(printf '%.0f' "$FIVE")%"
  fi
fi

if [ -n "$WEEK" ]; then
  line="${line} | weekly $(printf '%.0f' "$WEEK")%"
fi

if [ -n "$COST" ]; then
  line="${line} | \$$(printf '%.2f' "$COST")"
fi

line="${line} | v${VERSION}"
echo "$line"
