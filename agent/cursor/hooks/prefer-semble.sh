#!/usr/bin/env bash
# preToolUse hook: nudge the agent to use semble instead of Grep/Glob.
HOOK_INPUT="$(cat)" exec python3 - <<'PY'
import json, os, sys

try:
    data = json.loads(os.environ.get('HOOK_INPUT') or '{}')
except Exception:
    sys.exit(0)

tool = data.get('tool_name') or data.get('toolName') or ''
if tool not in ('Grep', 'Glob'):
    sys.exit(0)

reason = (
    'コード検索なら semble (mcp__semble__search / mcp__semble__find_related) に持ち替える。'
    'semble は意味検索でコード理解に強い (repo=プロジェクトルート or https URL)。'
    'ログ・非コード・厳密なパターンマッチなど semble が不適な場合に限り、'
    'Read 等の別手段に切り替えるか、なぜ Grep/Glob でなければならないかを述べてから再試行すること。'
)
print(json.dumps({
    'permission': 'deny',
    'user_message': reason,
    'agent_message': reason,
}))
PY
