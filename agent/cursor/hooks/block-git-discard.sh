#!/usr/bin/env bash
# beforeShellExecution hook: block git commands that discard working-tree changes.
# Cursor adapter for agent/hooks/block-git-discard logic (Claude: PreToolUse Bash).
HOOK_INPUT="$(cat)" exec python3 - <<'PY'
import json, os, re, sys

try:
    data = json.loads(os.environ.get('HOOK_INPUT') or '{}')
except Exception:
    sys.exit(0)
cmd = data.get('command') or ''
if 'git' not in cmd:
    sys.exit(0)

GIT_RE = re.compile(
    r'(?:^|[;&|(`]|\$\()\s*'
    r'(?:[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*'
    r'git\s+'
    r'(?:(?:-[Cc]|--git-dir|--work-tree)(?:[= ]\S+)?\s+)*'
    r'(\S+)((?:\s+\S+)*)',
    re.M,
)

def dangerous(sub, rest):
    toks = re.split(r'[;&|]', rest or '')[0].split()
    if sub == 'restore':
        return '--staged' not in toks or '--worktree' in toks or '-W' in toks
    if sub == 'checkout':
        if any(t in ('.', '--', '-f', '--force', '--ours', '--theirs') for t in toks):
            return True
        return bool(toks) and toks[0].startswith('HEAD') and len(toks) > 1
    if sub == 'reset':
        return any(t in ('--hard', '--merge', '--keep') for t in toks)
    if sub == 'clean':
        return not any(t in ('-n', '--dry-run') for t in toks)
    if sub == 'stash':
        return not toks or toks[0] not in ('list', 'show')
    return False

for m in GIT_RE.finditer(cmd):
    sub, rest = m.group(1), m.group(2)
    if dangerous(sub, rest):
        reason = (
            f'Blocked: `git {sub}` can discard working-tree changes or untracked files. '
            'Undo your own edits by editing the files back; never discard the tree.'
        )
        print(json.dumps({
            'permission': 'deny',
            'user_message': reason,
            'agent_message': reason,
        }))
        sys.exit(0)
print(json.dumps({'permission': 'allow'}))
PY
