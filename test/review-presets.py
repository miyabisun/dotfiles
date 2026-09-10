"""Exercise both review CLIs with stubs, never the real services."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

REVIEW = Path(__file__).resolve().parents[1] / "agent/common/bin/review"
PASS = dict(verdict="pass", blocking=[])
RECHECK = dict(verdict="pass", items=[dict(id="1", resolved=True, reason="fixed")],
               notes=[])


class ReviewPresets(unittest.TestCase):
    caller = "claude"

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.result = self.root / "result.json"
        self.capture = self.root / "capture.json"
        self.stub = self.root / "codex"
        self.stub.write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys, time
a = sys.argv
claude = '--json-schema' in a
schema = json.loads(a[a.index('--json-schema')+1] if claude else pathlib.Path(a[a.index('--output-schema')+1]).read_text())
pathlib.Path(os.environ['CAPTURE']).write_text(json.dumps(dict(schema=schema, prompt=sys.stdin.read(), args=a, cwd=os.getcwd())))
time.sleep(float(os.environ.get('SLEEP', '0')))
if os.environ.get('OMIT') != '1':
    if claude:
        print(os.environ.get('RAW', json.dumps(dict(type='result', subtype='success', is_error=os.environ.get('ERROR') == '1', structured_output=json.loads(os.environ['REPLY'])))))
    else:
        pathlib.Path(a[a.index('-o')+1]).write_text(os.environ.get('RAW', os.environ['REPLY']))
print('verbose execution log' * 1000, file=sys.stderr)
sys.exit(int(os.environ.get('STATUS', '0')))
''')
        self.stub.chmod(0o755)
        self.env = dict(os.environ, REVIEW_CODEX=str(self.stub), REVIEW_CLAUDE=str(self.stub), CAPTURE=str(self.capture))

    def run_review(self, kind="implementation", reply=None, **env):
        self.env.update(env, REPLY=json.dumps(PASS if reply is None else reply))
        return subprocess.run([str(REVIEW), str(self.root), "--from", self.caller, "--kind", kind,
                               "--result", str(self.result), "--timeout", "1"], input="依頼\n$HOME `literal`\n",
                              text=True, capture_output=True, env=self.env)

    def test_modes_and_quiet_logs(self):
        for kind, reply in [("planning", PASS), ("implementation", PASS), ("recheck", RECHECK)]:
            with self.subTest(kind=kind):
                run = self.run_review(kind, reply)
                self.assertEqual(run.returncode, 0, run.stderr)
                capture = json.loads(self.capture.read_text())
                self.assertEqual(set(capture["schema"]["required"]), set(reply))
                self.assertTrue(capture["prompt"].endswith("依頼\n$HOME `literal`\n"))
                self.assertIn("untrusted data", capture["prompt"])
                self.assertEqual(run.stdout, "")
                self.assertLess(len(run.stderr), 1000)
                self.assertIn("verbose execution log", Path(str(self.result)+".log").read_text())

    def test_routes_to_other_model(self):
        run = self.run_review()
        self.assertEqual(run.returncode, 0, run.stderr)
        capture = json.loads(self.capture.read_text())
        args = capture["args"]
        flag, model = ("--model", "claude-fable-5-1") if self.caller == "codex" else ("-m", "gpt-6-astra")
        self.assertEqual(args[args.index(flag)+1], model)
        if self.caller == "codex":
            self.assertEqual(capture["cwd"], str(self.root))
            self.assertEqual(args[args.index("--tools")+1], "Read,Glob,Grep")
            self.assertIn("--safe-mode", args)
            self.assertIn("--strict-mcp-config", args)

    def test_changes_required_is_valid_result(self):
        reply = dict(PASS, verdict="changes_required", blocking=[
            dict(category="intent", path="x", line=1, issue="broken", required_fix="fix")])
        self.assertEqual(self.run_review(reply=reply).returncode, 0)

    def test_invalid_or_contradictory_result_is_not_pass(self):
        cases = [dict(PASS, blocking=[dict(category="intent", path="x", line=1, issue="x", required_fix="x")]),
                 dict(PASS, verdict="unknown"), {}, [], "invalid JSON shape",
                 dict(PASS, extra="unexpected"), dict(PASS, blocking=[dict(path="x")])]
        for reply in cases:
            with self.subTest(reply=reply):
                run = self.run_review(reply=reply)
                self.assertNotEqual(run.returncode, 0)
                self.assertFalse(self.result.exists())

    def test_recheck_cannot_pass_with_unresolved_findings(self):
        reply = dict(RECHECK, items=[dict(id="1", resolved=False, reason="later")])
        self.assertNotEqual(self.run_review("recheck", reply).returncode, 0)

    def test_planning_validates_findings_and_removes_stale_results(self):
        finding = dict(category="requirements", path="candidate.md", line=3,
                       issue="scope mismatch", required_fix="keep original scope")
        for reply, status in [(dict(verdict="changes_required", blocking=[finding]), 0),
                              (dict(PASS, blocking=[finding]), 1), ({}, 1)]:
            with self.subTest(reply=reply):
                self.result.write_text(json.dumps(PASS))
                run = self.run_review("planning", reply)
                self.assertEqual(run.returncode, status, run.stderr)
                self.assertEqual(self.result.exists(), status == 0)

    def test_only_requirements_and_intent_findings_are_accepted(self):
        for category in ("requirements", "intent", "style"):
            reply = dict(verdict="changes_required", blocking=[dict(
                category=category, path="x", line=1, issue="wrong", required_fix="fix")])
            run = self.run_review(reply=reply)
            self.assertEqual(run.returncode, 1 if category == "style" else 0, run.stderr)

    def test_stale_result_is_removed_on_empty_or_failed_execution(self):
        for env in [dict(OMIT="1"), dict(STATUS="3", OMIT="0")]:
            self.result.write_text(json.dumps(PASS))
            run = self.run_review(**env)
            self.assertNotEqual(run.returncode, 0)
            self.assertFalse(self.result.exists())
            self.assertLess(len(run.stderr), 3000)

    def test_malformed_json_and_timeout_remove_results(self):
        self.assertEqual(self.run_review(RAW="{broken").returncode, 1)
        self.assertFalse(self.result.exists())
        self.result.write_text(json.dumps(PASS))
        self.assertEqual(self.run_review(SLEEP="5").returncode, 124)
        self.assertFalse(self.result.exists())

    def test_symlink_install_finds_timeout(self):
        link = self.root / "review"
        link.symlink_to(REVIEW)
        self.env["REPLY"] = json.dumps(PASS)
        run = subprocess.run([str(link), str(self.root), "--from", self.caller, "--kind", "implementation",
                              "--result", str(self.result)], input="task", text=True,
                             capture_output=True, env=self.env)
        self.assertEqual(run.returncode, 0, run.stderr)


class ClaudePresets(ReviewPresets):
    caller = "codex"

    def test_error_envelope_is_not_pass(self):
        run = self.run_review(ERROR="1")
        self.assertNotEqual(run.returncode, 0)
        self.assertFalse(self.result.exists())

    def test_missing_structured_output_is_not_a_result(self):
        run = self.run_review(RAW=json.dumps(dict(is_error=False, subtype="success", result="pass")))
        self.assertNotEqual(run.returncode, 0)
        self.assertFalse(self.result.exists())

    def test_custom_schema_extracts_only_structured_output(self):
        schema = self.root / "schema.json"
        schema.write_text(json.dumps(dict(type="array", items=dict(type="string"))))
        self.env["REPLY"] = '["custom"]'
        run = subprocess.run([str(REVIEW), str(self.root), "--from", self.caller,
                              "--schema", str(schema), "--result", str(self.result)],
                             input="custom task", text=True, capture_output=True, env=self.env)
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(json.loads(self.result.read_text()), ["custom"])
        self.assertEqual(json.loads(self.capture.read_text())["prompt"], "custom task")


if __name__ == "__main__":
    unittest.main()
