#!/usr/bin/env bash
# PreToolUse(Workflow) hook: gate workflow launches on a dirty working tree.
#
# Root cause of the 2026-07-03 incident was launching a dev-cycle while the
# tree held uncommitted work (which an agent then discarded). Prompt rules and
# the model's own memory are advisory; this hook makes the gate structural:
# a Workflow tool call with uncommitted changes escalates to the human
# (permissionDecision "ask") instead of silently proceeding.
#
# Clean tree / not a git repo -> silent allow.
HOOK_INPUT="$(cat)" exec python3 - <<'PY'
import json, os, subprocess, sys

r = subprocess.run(['git', 'status', '--porcelain'],
                   capture_output=True, text=True)
if r.returncode != 0:
    sys.exit(0)  # not a git repo: nothing to protect
dirty = [l for l in r.stdout.splitlines() if l.strip()]
if not dirty:
    sys.exit(0)

listing = '\n'.join(dirty[:10]) + ('\n…' if len(dirty) > 10 else '')
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'ask',
        'permissionDecisionReason': (
            f'作業ツリーに未コミット変更が {len(dirty)} 件あります。'
            'ワークフローのエージェントが未コミット変更を壊した事故が過去にあるため、'
            '起動前に確認してください。推奨: 先にコミットする / EnterWorktree で'
            '隔離してから起動する / この変更が無関係・保護不要なら承認して続行。\n'
            + listing
        ),
    }
}))
PY
