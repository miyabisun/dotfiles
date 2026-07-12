#!/usr/bin/env bash
# PreToolUse(Bash): block commands that can discard uncommitted work.
HOOK_INPUT="$(cat)" exec python3 - <<'PY'
import json
import os
import re
import sys

try:
    data = json.loads(os.environ.get("HOOK_INPUT") or "{}")
except Exception:
    sys.exit(0)

command = (data.get("tool_input") or {}).get("command") or ""
if "git" not in command:
    sys.exit(0)

git_re = re.compile(
    r"(?:^|[;&|(`]|\$\()\s*"
    r"(?:[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*"
    r"git\s+"
    r"(?:(?:-[Cc]|--git-dir|--work-tree)(?:[= ]\S+)?\s+)*"
    r"(\S+)((?:\s+\S+)*)",
    re.M,
)


def dangerous(subcommand, rest):
    tokens = re.split(r"[;&|]", rest or "")[0].split()
    if subcommand == "restore":
        return "--staged" not in tokens or "--worktree" in tokens or "-W" in tokens
    if subcommand == "checkout":
        if any(token in (".", "--", "-f", "--force", "--ours", "--theirs") for token in tokens):
            return True
        return bool(tokens) and tokens[0].startswith("HEAD") and len(tokens) > 1
    if subcommand == "reset":
        return any(token in ("--hard", "--merge", "--keep") for token in tokens)
    if subcommand == "clean":
        return not any(token in ("-n", "--dry-run") for token in tokens)
    if subcommand == "stash":
        return not tokens or tokens[0] not in ("list", "show")
    return False


for match in git_re.finditer(command):
    subcommand, rest = match.group(1), match.group(2)
    if dangerous(subcommand, rest):
        reason = (
            f"Blocked: `git {subcommand}` can discard working-tree changes or untracked files. "
            "Undo only your own edits by editing files back; never discard the tree."
        )
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": reason,
            }
        }))
        sys.exit(0)
PY
