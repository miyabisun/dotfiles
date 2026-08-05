#!/usr/bin/env bash
# PreToolUse: block git commands that discard working-tree changes.
# Accepts Grok (toolInput.command) and Claude-style (tool_input.command) payloads.
# Denies with Grok-native {"decision":"deny"} (Claude hookSpecificOutput also works).
HOOK_INPUT="$(cat)" exec python3 - <<'PY'
import json
import os
import re
import sys

try:
    data = json.loads(os.environ.get("HOOK_INPUT") or "{}")
except Exception:
    sys.exit(0)

tool_input = data.get("toolInput") or data.get("tool_input") or {}
command = ""
if isinstance(tool_input, dict):
    command = tool_input.get("command") or ""
if not command:
    command = data.get("command") or ""
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
        print(
            json.dumps(
                {
                    "decision": "deny",
                    "reason": (
                        f"Blocked by block-git-discard hook: `git {subcommand}` can discard "
                        "working-tree changes or untracked files. Uncommitted work was "
                        "destroyed this way before. Undo your own edits by editing the "
                        "files back; never discard the tree. (Read-only git such as "
                        "diff/log/show/status and `git stash list|show` stay allowed.)"
                    ),
                }
            )
        )
        sys.exit(0)
sys.exit(0)
PY
