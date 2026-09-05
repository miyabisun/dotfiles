"""Exercise the installed command with a fake Codex, never the real service."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

REVIEW = Path(__file__).resolve().parents[1] / "agent/common/bin/review"
PASS = dict(verdict="pass", blocking=[], non_blocking=[], evidence_integrity="checked",
            scope_check="checked", formatter_linter_check="checked")
RECHECK = dict(verdict="pass", items=[dict(id="1", resolved=True, reason="fixed")],
               evidence_integrity=dict(verdict="clean", findings=[]), notes=[])


class ReviewPresets(unittest.TestCase):
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
schema = json.loads(pathlib.Path(a[a.index('--output-schema')+1]).read_text())
pathlib.Path(os.environ['CAPTURE']).write_text(json.dumps(dict(schema=schema, prompt=sys.stdin.read())))
time.sleep(float(os.environ.get('SLEEP', '0')))
if os.environ.get('OMIT') != '1':
    pathlib.Path(a[a.index('-o')+1]).write_text(os.environ.get('RAW', os.environ['REPLY']))
print('verbose execution log' * 1000)
sys.exit(int(os.environ.get('STATUS', '0')))
''')
        self.stub.chmod(0o755)
        self.env = dict(os.environ, REVIEW_CODEX=str(self.stub), CAPTURE=str(self.capture))

    def run_review(self, kind="implementation", reply=None, **env):
        self.env.update(env, REPLY=json.dumps(PASS if reply is None else reply))
        return subprocess.run([str(REVIEW), str(self.root), "--kind", kind,
                               "--result", str(self.result), "--timeout", "1"], input="依頼\n$HOME `literal`\n",
                              text=True, capture_output=True, env=self.env)

    def test_modes_and_quiet_logs(self):
        for kind, reply in [("implementation", PASS), ("recheck", RECHECK),
                            ("planning", dict(dissatisfaction="x", minimal_plan="x",
                                              regression_evidence="x", ux_risks="x"))]:
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

    def test_changes_required_is_valid_result(self):
        reply = dict(PASS, verdict="changes_required", blocking=[
            dict(path="x", line=1, issue="broken", required_fix="fix")])
        self.assertEqual(self.run_review(reply=reply).returncode, 0)

    def test_invalid_or_contradictory_result_is_not_pass(self):
        cases = [dict(PASS, blocking=[dict(path="x", line=1, issue="x", required_fix="x")]),
                 dict(PASS, verdict="unknown"), {}, [], "invalid JSON shape",
                 dict(PASS, extra="unexpected"), dict(PASS, blocking=[dict(path="x")])]
        for reply in cases:
            with self.subTest(reply=reply):
                run = self.run_review(reply=reply)
                self.assertNotEqual(run.returncode, 0)
                self.assertFalse(self.result.exists())

    def test_recheck_cannot_pass_with_unresolved_or_bad_evidence(self):
        for reply in [dict(RECHECK, items=[dict(id="1", resolved=False, reason="later")]),
                      dict(RECHECK, evidence_integrity=dict(verdict="cheating", findings=["x"]))]:
            self.assertNotEqual(self.run_review("recheck", reply).returncode, 0)

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
        run = subprocess.run([str(link), str(self.root), "--kind", "implementation",
                              "--result", str(self.result)], input="task", text=True,
                             capture_output=True, env=self.env)
        self.assertEqual(run.returncode, 0, run.stderr)


if __name__ == "__main__":
    unittest.main()
