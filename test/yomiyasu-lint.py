#!/usr/bin/env python3
"""Contract: yomiyasu-lint runs the yomiyasu skill's linter that the agent-tools
updater links at ~/.agents/skills/yomiyasu, passing arguments, stdin, stdout and
the exit code through; a missing install is a usage error (exit 2), never clean."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

WRAPPER = Path(__file__).resolve().parents[1] / "agent/common/bin/yomiyasu-lint"


def run(home, *args, stdin=""):
    return subprocess.run([str(WRAPPER), *args], input=stdin, text=True, capture_output=True,
                          env={**os.environ, "HOME": str(home)})


class YomiyasuLint(unittest.TestCase):
    def test_missing_install_is_an_error(self):
        with tempfile.TemporaryDirectory() as home:
            result = run(home, "note.md")
            self.assertEqual(result.returncode, 2)
            self.assertEqual(result.stdout, "")
            self.assertIn("agent-tools", result.stderr)

    def test_passes_arguments_stdin_and_exit_code(self):
        with tempfile.TemporaryDirectory() as home:
            scripts = Path(home) / ".agents/skills/yomiyasu/scripts"
            scripts.mkdir(parents=True)
            (scripts / "yomiyasu_lint.py").write_text(
                "import sys\nprint(repr(sys.argv[1:]), sys.stdin.read())\nsys.exit(1)\n")
            result = run(home, "--json", "名前 空白.md", stdin="本文")
            self.assertEqual(result.returncode, 1)
            self.assertEqual(result.stdout, "['--json', '名前 空白.md'] 本文\n")


if __name__ == "__main__":
    unittest.main()
