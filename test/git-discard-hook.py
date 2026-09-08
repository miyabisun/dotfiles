#!/usr/bin/env python3
"""Observe hook decisions without executing any supplied shell command."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SAFE = (
    "echo hi", "git status", "git diff", "git log", "git show HEAD",
    "git checkout feature", "git restore --staged file", "git reset HEAD file",
    "git clean -n", "git clean --dry-run", "git stash list", "git stash show",
)
DANGEROUS = (
    "git checkout .", "git checkout -- file", "git checkout -f feature",
    "git checkout --ours file", "git checkout HEAD file", "git restore file",
    "git restore --staged --worktree file", "git restore --staged -W file",
    "git reset --hard", "git reset --merge", "git reset --keep", "git clean -fd",
    "git stash", "git stash push", "git stash pop", "git stash drop",
    "cd repo && git -C path reset --hard", "VAR=1 git checkout .",
)

with tempfile.TemporaryDirectory(prefix="git discard home ") as temp:
    home = Path(temp)
    tools = home / "tools"
    tools.mkdir()
    # Resolving installed directory symlinks must not require GNU readlink -f.
    (tools / "readlink").write_text("#!/bin/sh\nexit 1\n")
    (tools / "readlink").chmod(0o755)
    for runtime in ("claude", "codex", "grok"):
        directory = home / f".{runtime}"
        directory.mkdir()
        (directory / "hooks").symlink_to(ROOT / f"agent/{runtime}/hooks")
        config = ROOT / {"claude": "agent/claude/settings.json",
                         "codex": "agent/codex/hooks.json",
                         "grok": "agent/grok/hooks/guards.json"}[runtime]
        commands = [hook["command"]
                    for group in json.loads(config.read_text())["hooks"]["PreToolUse"]
                    for hook in group["hooks"] if "block-git-discard" in hook["command"]]
        assert len(commands) == 1, runtime

        def invoke(payload):
            result = subprocess.run(["bash", "-c", commands[0]], input=payload,
                text=True, capture_output=True, cwd=directory / "hooks",
                env={**os.environ, "HOME": temp, "PATH": f"{tools}:{os.environ['PATH']}"}, timeout=5)
            assert result.returncode == 0, (runtime, payload, result.stderr)
            assert not result.stderr, (runtime, payload, result.stderr)
            return json.loads(result.stdout) if result.stdout else None

        payload_keys = ("tool_input", "toolInput", None) if runtime == "grok" else ("tool_input",)
        for key in payload_keys:
            for command in SAFE + DANGEROUS:
                tool_input = {"command": command}
                result = invoke(json.dumps({key: tool_input} if key else tool_input))
                if command in SAFE:
                    assert result is None, (runtime, command, result)
                elif runtime == "grok":
                    assert result["decision"] == "deny", result
                    assert "working-tree changes or untracked files" in result["reason"], result
                    assert set(result) == {"decision", "reason"}, result
                else:
                    output = result["hookSpecificOutput"]
                    assert output["hookEventName"] == "PreToolUse", result
                    assert output["permissionDecision"] == "deny", result
                    assert "working-tree changes or untracked files" in output["permissionDecisionReason"], result
        for payload in ("", "{", "{}", '{"tool_input": {"command": ""}}'):
            assert invoke(payload) is None, (runtime, payload)
        if runtime == "grok":
            assert invoke(json.dumps({"toolInput": {"command": "git status"},
                                     "tool_input": {"command": "git reset --hard"}})) is None
            assert invoke(json.dumps({"toolInput": {}, "command": "git reset --hard"}))["decision"] == "deny"
print("git-discard registered hooks: safe/dangerous, payload/output, symlink paths: pass")
