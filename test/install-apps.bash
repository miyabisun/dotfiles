#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fake_bin="$test_root/bin"
fake_home="$test_root/home"
log="$test_root/curl.log"
args_log="$test_root/curl-args.log"
tmp_dir="$test_root/tmp"
mkdir -p "$fake_bin" "$fake_home/.local/bin" "$tmp_dir"

make_stub() {
  local name="$1"
  cat >"$fake_bin/$name" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  chmod +x "$fake_bin/$name"
}

make_stub delta
make_stub obscura

cat >"$fake_bin/uname" <<'STUB'
#!/usr/bin/env bash
echo "${INSTALL_APPS_TEST_UNAME:-Darwin}"
STUB
chmod +x "$fake_bin/uname"

cat >"$fake_bin/curl" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

{
  printf '<call>\n'
  printf '%s\n' "$@"
} >>"$INSTALL_APPS_TEST_ARGS_LOG"

url=""
output=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      output="$2"
      shift 2
      ;;
    http*)
      url="$1"
      shift
      ;;
    *) shift ;;
  esac
done

if [ "${INSTALL_APPS_TEST_FAIL_URL:-}" = "$url" ]; then
  exit 22
fi

printf '%s\n' "$url" >>"$INSTALL_APPS_TEST_LOG"
case "$url" in
  https://cursor.com/install) command_name=cursor-agent ;;
  https://chatgpt.com/codex/install.sh) command_name=codex ;;
  *) exit 64 ;;
esac

if [ "${INSTALL_APPS_TEST_FAIL_RUN_URL:-}" = "$url" ]; then
  cat >"$output" <<'INSTALLER'
#!/usr/bin/env bash
exit 23
INSTALLER
  exit 0
fi

cat >"$output" <<INSTALLER
#!/usr/bin/env bash
touch "\$HOME/.local/bin/$command_name"
chmod +x "\$HOME/.local/bin/$command_name"
INSTALLER
STUB
chmod +x "$fake_bin/curl"

PATH="$fake_bin:$fake_home/.local/bin:/usr/bin:/bin" \
  HOME="$fake_home" \
  INSTALL_APPS_TEST_LOG="$log" \
  INSTALL_APPS_TEST_ARGS_LOG="$args_log" \
  TMPDIR="$tmp_dir" \
  bash "$repo_root/bin/install-apps" >"$test_root/first-run.out"

grep -Fx "https://cursor.com/install" "$log" >/dev/null
grep -Fx "https://chatgpt.com/codex/install.sh" "$log" >/dev/null
grep -Fx -- "--proto" "$args_log" >/dev/null
grep -Fx -- "=https" "$args_log" >/dev/null
grep -Fx -- "--tlsv1.2" "$args_log" >/dev/null
grep -Fx -- "-fsSL" "$args_log" >/dev/null
test -x "$fake_home/.local/bin/cursor-agent"
test -x "$fake_home/.local/bin/codex"
test -z "$(find "$tmp_dir" -mindepth 1 -print -quit)"

PATH="$fake_bin:$fake_home/.local/bin:/usr/bin:/bin" \
  HOME="$fake_home" \
  INSTALL_APPS_TEST_LOG="$log" \
  INSTALL_APPS_TEST_ARGS_LOG="$args_log" \
  TMPDIR="$tmp_dir" \
  bash "$repo_root/bin/install-apps" >"$test_root/second-run.out"

test "$(wc -l <"$log")" -eq 2
grep -F "Cursor CLI already installed" "$test_root/second-run.out" >/dev/null
grep -F "Codex CLI already installed" "$test_root/second-run.out" >/dev/null

linux_home="$test_root/linux-home"
linux_tmp="$test_root/linux-tmp"
mkdir -p "$linux_home" "$linux_tmp"
PATH="$fake_bin:/usr/bin:/bin" \
  HOME="$linux_home" \
  INSTALL_APPS_TEST_LOG="$test_root/linux-curl.log" \
  INSTALL_APPS_TEST_ARGS_LOG="$test_root/linux-curl-args.log" \
  INSTALL_APPS_TEST_UNAME="Linux" \
  TMPDIR="$linux_tmp" \
  bash "$repo_root/bin/install-apps" >"$test_root/linux.out"

test ! -e "$test_root/linux-curl.log"
grep -F "skip Cursor/Codex CLIs (macOS only)" "$test_root/linux.out" >/dev/null

failure_home="$test_root/failure-home"
failure_tmp="$test_root/failure-tmp"
mkdir -p "$failure_home" "$failure_tmp"
if PATH="$fake_bin:/usr/bin:/bin" \
  HOME="$failure_home" \
  INSTALL_APPS_TEST_LOG="$test_root/failure-curl.log" \
  INSTALL_APPS_TEST_ARGS_LOG="$test_root/failure-curl-args.log" \
  INSTALL_APPS_TEST_FAIL_URL="https://cursor.com/install" \
  TMPDIR="$failure_tmp" \
  bash "$repo_root/bin/install-apps" >"$test_root/failure.out" 2>&1; then
  echo "install-apps should fail when an installer download fails" >&2
  exit 1
fi

grep -F "Failed to install Cursor CLI" "$test_root/failure.out" >/dev/null
test -z "$(find "$failure_tmp" -mindepth 1 -print -quit)"

run_failure_home="$test_root/run-failure-home"
run_failure_tmp="$test_root/run-failure-tmp"
mkdir -p "$run_failure_home" "$run_failure_tmp"
if PATH="$fake_bin:/usr/bin:/bin" \
  HOME="$run_failure_home" \
  INSTALL_APPS_TEST_LOG="$test_root/run-failure-curl.log" \
  INSTALL_APPS_TEST_ARGS_LOG="$test_root/run-failure-curl-args.log" \
  INSTALL_APPS_TEST_FAIL_RUN_URL="https://cursor.com/install" \
  TMPDIR="$run_failure_tmp" \
  bash "$repo_root/bin/install-apps" >"$test_root/run-failure.out" 2>&1; then
  echo "install-apps should fail when an installer execution fails" >&2
  exit 1
fi

grep -F "Failed to install Cursor CLI" "$test_root/run-failure.out" >/dev/null
test -z "$(find "$run_failure_tmp" -mindepth 1 -print -quit)"

echo "install-apps macOS agent CLI test: pass"
