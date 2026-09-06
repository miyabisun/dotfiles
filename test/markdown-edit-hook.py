#!/usr/bin/env python3
"""Isolated contract tests for edit-event routing and lint feedback."""
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
HOOK = ROOT / "agent/common/bin/meiseki-lint-markdown"
loader = importlib.machinery.SourceFileLoader("markdown_hook", str(HOOK))
spec = importlib.util.spec_from_loader(loader.name, loader)
hook = importlib.util.module_from_spec(spec)
loader.exec_module(hook)


class MarkdownEditHook(unittest.TestCase):
    def test_timeout_includes_lint_children(self):
        with tempfile.TemporaryDirectory() as tmp:
            stub = Path(tmp) / "slow-lint"
            stub.write_text("#!/bin/sh\nsleep 4 &\nwait\n")
            stub.chmod(0o755)
            started = time.monotonic()
            self.assertIn("未実行", hook.lint_file(str(stub), "note.md", 1))
            self.assertLess(time.monotonic() - started, 3)

    def test_patch_targets_include_move_destination_and_deduplicate(self):
        event = {"cwd": "/workspace", "tool_name": "apply_patch", "tool_input": {
            "command": """*** Begin Patch
*** Add File: new file.md
+本文
*** Update File: old.md
*** Move to: moved.md
@@
-旧
+新
*** Delete File: removed.md
*** Update File: code.py
@@
-x
+y
*** Update File: new file.md
@@
-旧
+新
*** End Patch"""}}
        self.assertEqual(hook.edited_markdown(event), [
            "/workspace/new file.md", "/workspace/moved.md"])

    def test_tool_routing_and_relative_paths(self):
        for name in ("Edit", "Write", "MultiEdit", "search_replace"):
            self.assertEqual(hook.edited_markdown({"tool_name": name, "cwd": "/repo",
                "tool_input": {"file_path": "日本語 名前.md"}}), ["/repo/日本語 名前.md"])
        for name, data in (("Bash", {"command": "echo hi > note.md"}),
                           ("Read", {"file_path": "note.md"}),
                           ("Write", {"file_path": "note.txt"})):
            self.assertEqual(hook.edited_markdown({"tool_name": name, "tool_input": data}), [])

    def test_integration_feedback_and_no_repository_artifacts(self):
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            stub = work / "lint"
            stub.write_text('''#!/usr/bin/env python3
import json, os, sys
with open(os.environ["CALLS"], "a") as f: f.write(json.dumps(sys.argv[1:]) + "\\n")
print(os.environ["LINT_OUTPUT"])
print("startup diagnostic", file=sys.stderr)
sys.exit(int(os.environ["LINT_STATUS"]))
''')
            stub.chmod(0o755)
            calls = work / "calls"
            event = {"tool_name": "Write", "cwd": tmp, "tool_input": {"file_path": "note.md"}}
            for status, output, expected in (
                (0, "[]", ""),
                (1, '[{"messages":[{"line":2,"column":3,"ruleId":"rule","message":"fix"}]}]', "note.md:2:3 [rule] fix"),
                (1, "broken json", "未実行"),
                (2, "", "startup diagnostic"),
            ):
                result = subprocess.run([str(HOOK)], input=json.dumps(event), text=True,
                    capture_output=True, cwd=tmp, env={**os.environ, "MEISEKI_LINT": str(stub),
                    "CALLS": str(calls), "LINT_OUTPUT": output, "LINT_STATUS": str(status)})
                self.assertEqual(result.returncode, 0, result.stderr)
                if expected:
                    context = json.loads(result.stdout)["hookSpecificOutput"]["additionalContext"]
                    self.assertIn(expected, context)
                else:
                    self.assertEqual(result.stdout, "")
            self.assertEqual([json.loads(line) for line in calls.read_text().splitlines()],
                             [[str(work / "note.md")]] * 4)
            self.assertEqual(sorted(p.name for p in work.iterdir()), ["calls", "lint"])

    def test_grok_reports_diagnostics_to_log(self):
        event = {"tool_name": "search_replace", "tool_input": {"file_path": "note.md"}}
        with tempfile.TemporaryDirectory() as tmp:
            result = subprocess.run([str(ROOT / "agent/grok/hooks/meiseki-lint-markdown.sh")],
                input=json.dumps(event), text=True, capture_output=True,
                env={**os.environ, "GROK_HOME": tmp, "MEISEKI_LINT": "/missing/lint"})
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout, "")
            self.assertIn("未実行", (Path(tmp) / "logs/markdown-lint.log").read_text())


if __name__ == "__main__":
    unittest.main()
