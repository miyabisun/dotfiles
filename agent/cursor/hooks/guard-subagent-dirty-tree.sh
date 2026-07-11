#!/usr/bin/env bash
# subagentStart hook: gate subagent launches when the working tree is dirty.
HOOK_INPUT="$(cat)" exec python3 - <<'PY'
import json, os, subprocess, sys

r = subprocess.run(['git', 'status', '--porcelain'],
                   capture_output=True, text=True)
if r.returncode != 0:
    sys.exit(0)
dirty = [l for l in r.stdout.splitlines() if l.strip()]
if not dirty:
    sys.exit(0)

listing = '\n'.join(dirty[:10]) + ('\n…' if len(dirty) > 10 else '')
reason = (
    f'作業ツリーに未コミット変更が {len(dirty)} 件あります。'
    'サブエージェント起動前に確認してください。'
    '推奨: 先にコミットする / 変更が無関係なら承認して続行。\n'
    + listing
)
print(json.dumps({
    'permission': 'ask',
    'user_message': reason,
}))
PY
