#!/usr/bin/env bash
# PreToolUse hook for Grep/Glob: nudge Claude to switch to semble.
# This is a "pick the better tool" signal, not a hard ban. The reason tells
# Claude to use semble for code search, and to fall back (Read etc.) or state a
# justification only when semble genuinely does not fit (logs, non-code, exact
# pattern matching). Works under auto mode (deny is honored over the classifier).
cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "コード検索なら semble (mcp__semble__search / mcp__semble__find_related) に持ち替える。semble は意味検索でコード理解に強い (repo=プロジェクトルート or https URL)。ログ・非コード・厳密なパターンマッチなど semble が不適な場合に限り、Read 等の別手段に切り替えるか、なぜ Grep/Glob でなければならないかを述べてから再試行すること。"
  }
}
EOF
