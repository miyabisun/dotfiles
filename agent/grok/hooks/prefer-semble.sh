#!/usr/bin/env bash
# PreToolUse for Grep/Glob (and Grok aliases): nudge toward semble for code search.
cat <<'EOF'
{
  "decision": "deny",
  "reason": "コード検索なら semble (mcp__semble__search / mcp__semble__find_related) に持ち替える。semble は意味検索でコード理解に強い (repo=プロジェクトルート or https URL)。ログ・非コード・厳密なパターンマッチなど semble が不適な場合に限り、Read 等の別手段に切り替えるか、なぜ Grep/Glob でなければならないかを述べてから再試行すること。"
}
EOF
