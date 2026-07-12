#!/usr/bin/env bash
# PreToolUse(Bash) hook: block git commands that discard working-tree changes
# or untracked files (checkout ./--/-f, restore(worktree), reset --hard,
# clean, stash). Motivated by an incident where an autonomous subagent ran
# `git checkout .` + clean and destroyed uncommitted restyle work (2026-07-03).
# Applies to every Bash tool call, including subagents.
# NOTE: the heredoc occupies stdin for python, so the hook JSON is captured
# first and handed over via an environment variable.
HOOK_INPUT="$(cat)" exec python3 - <<'PY'
import json, os, re, sys

try:
    data = json.loads(os.environ.get('HOOK_INPUT') or '{}')
except Exception:
    sys.exit(0)
cmd = (data.get('tool_input') or {}).get('command') or ''
if 'git' not in cmd:
    sys.exit(0)

# Every `git` invocation in the command line (handles `cd x && git ...`,
# `VAR=1 git ...`, `git -C path ...`, subshells).
GIT_RE = re.compile(
    r'(?:^|[;&|(`]|\$\()\s*'
    r'(?:[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*'
    r'git\s+'
    r'(?:(?:-[Cc]|--git-dir|--work-tree)(?:[= ]\S+)?\s+)*'
    r'(\S+)((?:\s+\S+)*)',
    re.M,
)

def dangerous(sub, rest):
    # Only inspect args up to the next command separator.
    toks = re.split(r'[;&|]', rest or '')[0].split()
    if sub == 'restore':
        # index-only restore is fine; anything touching the worktree is not
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
        print(json.dumps({
            'hookSpecificOutput': {
                'hookEventName': 'PreToolUse',
                'permissionDecision': 'deny',
                'permissionDecisionReason': (
                    f'Blocked by block-git-discard hook: `git {sub}` can discard '
                    'working-tree changes or untracked files. Uncommitted work was '
                    'destroyed this way before. Undo your own edits by editing the '
                    'files back; never discard the tree. (Read-only git such as '
                    'diff/log/show/status and `git stash list|show` stay allowed.)'
                ),
            }
        }))
        sys.exit(0)
sys.exit(0)
PY
