#!/usr/bin/env python3
"""Restore TypeSafe credentials through the real bw-env with an isolated vault."""
import base64
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile


installer = Path(__file__).resolve().parents[1] / "bin/install-envs"
with tempfile.TemporaryDirectory(prefix="install envs ") as work:
    root = Path(work)
    home = root / "home"
    home.mkdir()
    fake_bin = root / "bin"
    fake_bin.mkdir()
    rbw = fake_bin / "rbw"
    rbw.write_text('''#!/usr/bin/env python3
import os, sys
from pathlib import Path
command = sys.argv[1]
with open(os.environ["CALLS"], "a") as log:
    log.write(command + "\\n")
if command == "unlocked":
    sys.exit(1 if os.environ.get("FAIL") == "unlock" else 0)
if command == "unlock":
    sys.exit(1)
if command == "sync":
    sys.exit(1 if os.environ.get("FAIL") == "sync" else 0)
assert sys.argv[1:] == ["get", "--folder", "Env Files", "typesafe", "--raw"]
print(Path(os.environ["VAULT"]).read_text())
sys.exit(1 if os.environ.get("FAIL") == "get" else 0)
''')
    rbw.chmod(0o755)
    vault = root / "vault.json"
    calls = root / "calls"
    log = ""
    env = {**os.environ, "HOME": str(home), "PATH": f"{fake_bin}:{os.environ['PATH']}",
           "VAULT": str(vault), "CALLS": str(calls)}
    target = home / ".config/typesafe/env"

    def store(content):
        vault.write_text(json.dumps({"notes": base64.b64encode(content.encode()).decode()}))

    def run(*args, fail="", succeeds=True):
        global log
        result = subprocess.run(["bash", str(installer), *args], cwd=root,
                                env={**env, "FAIL": fail}, text=True, capture_output=True)
        log += result.stdout + result.stderr
        assert (result.returncode == 0) == succeeds, result.stderr
        return result

    run("--help")
    run("unknown", succeeds=False)
    assert not calls.exists(), "help/invalid arguments must not access the vault"
    initial = "TYPESAFE_API_KEY=sentinel_initial_secret\n"
    store(initial)
    run()
    assert target.read_text() == initial
    assert stat.S_IMODE(target.stat().st_mode) == 0o600
    assert stat.S_IMODE(target.parent.stat().st_mode) == 0o700
    assert calls.read_text().splitlines().index("sync") < calls.read_text().splitlines().index("get")

    updated = "TYPESAFE_API_KEY=sentinel_updated_secret\n"
    store(updated)
    for failure in ("unlock", "sync", "get"):
        run(fail=failure, succeeds=False)
        assert target.read_text() == initial, "failed restore must preserve existing credentials"
        assert list(target.parent.iterdir()) == [target], "temporary files must be removed"
    store("")
    run(succeeds=False)
    assert target.read_text() == initial
    store(updated)
    run()
    assert target.read_text() == updated

    # Refuse unexpected paths without writing through links or into directories.
    target.unlink()
    outside = root / "outside"
    outside.write_text(initial)
    target.symlink_to(outside)
    run(succeeds=False)
    assert target.is_symlink() and outside.read_text() == initial
    target.unlink()
    target.mkdir()
    run(succeeds=False)
    assert not list(target.iterdir())
    target.rmdir()
    target.parent.rmdir()
    external_dir = root / "external"
    external_dir.mkdir()
    target.parent.symlink_to(external_dir, target_is_directory=True)
    run(succeeds=False)
    assert not list(external_dir.iterdir())
    assert "sentinel_initial_secret" not in log and "sentinel_updated_secret" not in log

print("install-envs: pass")
