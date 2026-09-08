"""Observe the user-level test gate with isolated repositories and hook events."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

TOOL = Path(__file__).resolve().parents[1] / "agent/common/bin/agent-test"


class AgentTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.env = dict(os.environ, XDG_STATE_HOME=str(self.root / "state"),
                        GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_SYSTEM=os.devnull,
                        GIT_AUTHOR_NAME="test", GIT_AUTHOR_EMAIL="test@example.invalid",
                        GIT_COMMITTER_NAME="test", GIT_COMMITTER_EMAIL="test@example.invalid")
        for key in subprocess.check_output(["git", "rev-parse", "--local-env-vars"], text=True).split():
            self.env.pop(key, None)
        self.git("init", "-q")
        (self.repo / "value").write_text("good")
        self.git("add", ".")
        self.git("commit", "-qm", "init")

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.repo, env=self.env,
                              check=True, capture_output=True, text=True)

    def invoke(self, *args, event=None):
        return subprocess.run(["python3", str(TOOL), *args], cwd=self.repo, env=self.env,
                              input=json.dumps(event) if event else None, text=True,
                              capture_output=True)

    def hook(self, command="git commit -m test", stop=False, session="one"):
        result = self.invoke("hook", event=dict(hook_event_name="Stop" if stop else "PreToolUse",
            cwd=str(self.repo), session_id=session, tool_name="Bash",
            tool_input=dict(command=command)))
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout or "{}")

    def run_tests(self, code="assert True"):
        self.hook("agent-test run -- python3 -c test")
        return self.invoke("run", "--", "python3", "-c", code)

    def test_failed_tests_block_commit_and_completion(self):
        self.assertNotEqual(self.run_tests("assert False").returncode, 0)
        self.assertEqual(self.hook()["hookSpecificOutput"]["permissionDecision"], "deny")
        self.assertEqual(self.hook(stop=True)["decision"], "block")

    def test_success_then_edit_requires_retest(self):
        self.assertEqual(self.run_tests().returncode, 0)
        self.assertEqual(self.hook(), {})
        self.assertEqual(self.hook(stop=True), {})
        (self.repo / "value").write_text("changed")
        self.assertEqual(self.hook()["hookSpecificOutput"]["permissionDecision"], "deny")
        self.assertEqual(self.hook(stop=True)["decision"], "block")

    def test_staging_and_commit_do_not_invalidate_tested_contents(self):
        (self.repo / "value").write_text("changed")
        self.assertEqual(self.run_tests().returncode, 0)
        self.git("add", ".")
        self.assertEqual(self.hook(), {})
        self.git("commit", "-qm", "change")
        self.assertEqual(self.hook(stop=True), {})

    def test_partial_staging_is_not_the_tested_content(self):
        (self.repo / "value").write_text("bad staged")
        self.git("add", ".")
        (self.repo / "value").write_text("fixed but unstaged")
        self.assertEqual(self.run_tests().returncode, 0)
        self.assertEqual(self.hook()["hookSpecificOutput"]["permissionDecision"], "deny")

    def test_staging_deletions_preserves_tested_contents(self):
        (self.repo / "value").unlink()
        self.assertEqual(self.run_tests().returncode, 0)
        self.git("add", "-u")
        self.assertEqual(self.hook(), {})
        self.git("commit", "-qm", "delete")
        self.assertEqual(self.hook(stop=True), {})

    def test_untracked_edits_and_changes_during_tests_invalidate_result(self):
        self.assertEqual(self.run_tests().returncode, 0)
        (self.repo / "new.py").write_text("x=1")
        self.assertEqual(self.hook()["hookSpecificOutput"]["permissionDecision"], "deny")
        self.assertNotEqual(self.run_tests('from pathlib import Path; Path("value").write_text("mutated")').returncode, 0)

    def test_pause_allows_incomplete_report_but_not_commit(self):
        self.run_tests("assert False")
        self.assertEqual(self.invoke("pause").returncode, 0)
        self.assertEqual(self.hook(stop=True), {})
        self.assertEqual(self.hook()["hookSpecificOutput"]["permissionDecision"], "deny")

    def test_unrelated_sessions_and_read_only_commands_are_unaffected(self):
        self.assertEqual(self.hook(stop=True), {})
        self.run_tests("assert False")
        self.assertEqual(self.hook(stop=True, session="other"), {})
        self.assertEqual(self.hook("git status"), {})
        self.assertEqual(self.hook("echo 'git commit -m test'"), {})
        self.assertEqual(self.hook("python3 - <<'PY'\n# user's script\nprint(1)\nPY"), {})
        self.assertEqual(self.hook("cat <<'EOF'\nThis isn't a commit.\nEOF"), {})

    def test_git_c_and_cd_resolve_the_actual_repository(self):
        other = self.root / "other repo"
        other.mkdir()
        subprocess.run(["git", "init", "-q", str(other)], env=self.env, check=True)
        self.assertEqual(self.run_tests().returncode, 0)
        for command in (f'git -C "{other}" commit -m test', f'cd "{other}" && git commit -m test'):
            self.assertEqual(self.hook(command)["hookSpecificOutput"]["permissionDecision"], "deny")

    def test_compound_mutation_and_missing_executable_do_not_pass(self):
        self.assertEqual(self.run_tests().returncode, 0)
        self.assertEqual(self.hook("git add . && git commit -m test")["hookSpecificOutput"]["permissionDecision"], "deny")
        self.hook("agent-test run -- no-such-test-command")
        self.assertNotEqual(self.invoke("run", "--", "no-such-test-command").returncode, 0)
        self.assertEqual(self.hook(stop=True)["decision"], "block")

    def test_registered_hooks_in_both_runtimes(self):
        home = self.root / "home"
        bindir = home / ".local/bin"
        bindir.mkdir(parents=True)
        (bindir / "agent-test").symlink_to(TOOL)
        self.run_tests("assert False")
        for config in ("agent/codex/hooks.json", "agent/claude/settings.json"):
            hooks = json.loads((TOOL.parents[3] / config).read_text())["hooks"]
            for event in ("PreToolUse", "Stop"):
                commands = [h["command"] for group in hooks.get(event, [])
                            for h in group["hooks"] if "agent-test" in h["command"]]
                self.assertEqual(len(commands), 1, (config, event))
                result = subprocess.run(["bash", "-c", commands[0]], cwd=self.repo,
                    env=dict(self.env, HOME=str(home)), text=True, capture_output=True,
                    input=json.dumps(dict(hook_event_name=event, session_id="one",
                        cwd=str(self.repo), tool_input=dict(command="git commit -m test"))))
                self.assertEqual(result.returncode, 0, result.stderr)
                value = json.loads(result.stdout)
                self.assertEqual(value.get("decision") or value["hookSpecificOutput"]["permissionDecision"],
                                 "block" if event == "Stop" else "deny")


if __name__ == "__main__":
    unittest.main()
