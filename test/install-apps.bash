#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fake_bin="$test_root/bin"
fake_home="$test_root/home"
log="$test_root/curl.log"
args_log="$test_root/curl-args.log"
agent_log="$test_root/agent.log"
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

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{ print $1 }'
  else
    shasum -a 256 "$1" | awk '{ print $1 }'
  fi
}

make_stub delta
make_stub obscura

cat >"$fake_bin/curl" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

{
  printf '<call>\n'
  printf '%s\n' "$@"
} >>"$INSTALL_APPS_TEST_ARGS_LOG"

url=""
output=""
write_out=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      output="$2"
      shift 2
      ;;
    -w)
      write_out="$2"
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
  https://github.com/miyabi-sunny-side/agent-talkd/releases/latest)
    test "$write_out" = '%{redirect_url}'
    printf '%s%s' 'https://github.com/miyabi-sunny-side/agent-talkd/releases/tag/' \
      "${INSTALL_APPS_TEST_LATEST_TAG:-v0.3.2}"
    exit 0
    ;;
  https://github.com/miyabi-sunny-side/agent-talkd/releases/download/v0.3.2/agent-talk-linux-x86_64.tar.gz|\
  https://github.com/miyabi-sunny-side/agent-talkd/releases/download/v0.3.2/agent-talk-macos-aarch64.tar.gz)
    archive_root="${output}.root"
    mkdir -p "$archive_root"
    cat >"$archive_root/agent-talk" <<'AGENT'
#!/bin/sh
case "${1:-}" in
  --version) echo "agent-talk 0.3.2" ;;
  update)
    printf '%s\n' update >>"${INSTALL_APPS_TEST_AGENT_LOG:-/dev/null}"
    exit "${INSTALL_APPS_TEST_AGENT_UPDATE_STATUS:-0}"
    ;;
  ensure-daemon)
    printf '%s\n' ensure-daemon >>"${INSTALL_APPS_TEST_AGENT_LOG:-/dev/null}"
    echo "agent-talk: tmux server not available; daemon not applicable"
    ;;
  *)
    printf '%s\n' '  agent-talk update' '  agent-talk ensure-daemon'
    exit 1
    ;;
esac
AGENT
    chmod +x "$archive_root/agent-talk"
    tar -czf "$output" -C "$archive_root" agent-talk
    rm -rf "$archive_root"
    exit 0
    ;;
  https://github.com/miyabi-sunny-side/agent-talkd/releases/download/v0.3.2/agent-talk-linux-x86_64.tar.gz.sha256|\
  https://github.com/miyabi-sunny-side/agent-talkd/releases/download/v0.3.2/agent-talk-macos-aarch64.tar.gz.sha256)
    archive_path="${output%.sha256}"
    archive_name="$(basename "$archive_path")"
    if [ -n "${INSTALL_APPS_TEST_BAD_AGENT_TALK_CHECKSUM:-}" ]; then
      digest="0000000000000000000000000000000000000000000000000000000000000000"
    elif command -v sha256sum >/dev/null 2>&1; then
      digest="$(sha256sum "$archive_path" | awk '{ print $1 }')"
    else
      digest="$(shasum -a 256 "$archive_path" | awk '{ print $1 }')"
    fi
    printf '%s  %s\n' "$digest" "$archive_name" >"$output"
    exit 0
    ;;
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
  INSTALL_APPS_TEST_AGENT_LOG="$agent_log" \
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
test -x "$fake_home/.local/bin/agent-talk"
test "$("$fake_home/.local/bin/agent-talk" --version)" = "agent-talk 0.3.2"
grep -F "daemon not applicable" "$test_root/first-run.out" >/dev/null
test "$(grep -Fxc ensure-daemon "$agent_log")" -eq 1
test -z "$(find "$tmp_dir" -mindepth 1 -print -quit)"

PATH="$fake_bin:$fake_home/.local/bin:/usr/bin:/bin" \
  HOME="$fake_home" \
  INSTALL_APPS_TEST_LOG="$log" \
  INSTALL_APPS_TEST_ARGS_LOG="$args_log" \
  INSTALL_APPS_TEST_AGENT_LOG="$agent_log" \
  TMPDIR="$tmp_dir" \
  bash "$repo_root/bin/install-apps" >"$test_root/second-run.out"

test "$(grep -Fc 'https://cursor.com/install' "$log")" -eq 1
test "$(grep -Fc 'https://chatgpt.com/codex/install.sh' "$log")" -eq 1
test "$(grep -Fc 'https://github.com/miyabi-sunny-side/agent-talkd/releases/latest' "$log")" -eq 1
test "$(grep -Fc 'agent-talk-linux-x86_64.tar.gz' "$log")" -eq 2
grep -F "Cursor CLI already installed" "$test_root/second-run.out" >/dev/null
grep -F "Codex CLI already installed" "$test_root/second-run.out" >/dev/null
grep -F "Updating agent-talkd via agent-talk update" "$test_root/second-run.out" >/dev/null
test "$(grep -Fxc update "$agent_log")" -eq 1

linux_home="$test_root/linux-home"
linux_tmp="$test_root/linux-tmp"
mkdir -p "$linux_home/.local/bin" "$linux_tmp"
PATH="$fake_bin:/usr/bin:/bin" \
  HOME="$linux_home" \
  INSTALL_APPS_TEST_LOG="$test_root/linux-curl.log" \
  INSTALL_APPS_TEST_ARGS_LOG="$test_root/linux-curl-args.log" \
  TMPDIR="$linux_tmp" \
  bash "$repo_root/bin/install-apps" >"$test_root/linux.out"

grep -Fx "https://cursor.com/install" "$test_root/linux-curl.log" >/dev/null
grep -Fx "https://chatgpt.com/codex/install.sh" "$test_root/linux-curl.log" >/dev/null
test -x "$linux_home/.local/bin/cursor-agent"
test -x "$linux_home/.local/bin/codex"
test "$("$linux_home/.local/bin/agent-talk" --version)" = "agent-talk 0.3.2"
test -z "$(find "$linux_tmp" -mindepth 1 -print -quit)"

legacy_home="$test_root/legacy-home"
legacy_tmp="$test_root/legacy-tmp"
mkdir -p "$legacy_home/.local/bin" "$legacy_tmp"
cat >"$legacy_home/.local/bin/agent-talk" <<'LEGACY_AGENT'
#!/bin/sh
if [ "${1:-}" = "--version" ]; then
  echo "agent-talk 0.3.1"
else
  echo "  agent-talk send <addr> [message]"
fi
LEGACY_AGENT
chmod +x "$legacy_home/.local/bin/agent-talk"
PATH="$fake_bin:$legacy_home/.local/bin:/usr/bin:/bin" \
  HOME="$legacy_home" \
  INSTALL_APPS_TEST_LOG="$test_root/legacy-curl.log" \
  INSTALL_APPS_TEST_ARGS_LOG="$test_root/legacy-curl-args.log" \
  TMPDIR="$legacy_tmp" \
  bash "$repo_root/bin/install-apps" >"$test_root/legacy.out"

test "$("$legacy_home/.local/bin/agent-talk" --version)" = "agent-talk 0.3.2"
test -z "$(find "$legacy_tmp" -mindepth 1 -print -quit)"

update_failure_home="$test_root/update-failure-home"
update_failure_tmp="$test_root/update-failure-tmp"
mkdir -p "$update_failure_home/.local/bin" "$update_failure_tmp"
cat >"$update_failure_home/.local/bin/agent-talk" <<'UPDATE_FAILURE_AGENT'
#!/bin/sh
case "${1:-}" in
  update) exit 23 ;;
  *) printf '%s\n' '  agent-talk update'; exit 1 ;;
esac
UPDATE_FAILURE_AGENT
chmod +x "$update_failure_home/.local/bin/agent-talk"
update_failure_before="$(sha256_file "$update_failure_home/.local/bin/agent-talk")"
if PATH="$fake_bin:$update_failure_home/.local/bin:/usr/bin:/bin" \
  HOME="$update_failure_home" \
  INSTALL_APPS_TEST_LOG="$test_root/update-failure-curl.log" \
  INSTALL_APPS_TEST_ARGS_LOG="$test_root/update-failure-curl-args.log" \
  TMPDIR="$update_failure_tmp" \
  bash "$repo_root/bin/install-apps" >"$test_root/update-failure.out" 2>&1; then
  echo "install-apps should propagate agent-talk update failures" >&2
  exit 1
fi

test "$update_failure_before" = \
  "$(sha256_file "$update_failure_home/.local/bin/agent-talk")"
test "$(grep -Fc 'github.com/miyabi-sunny-side/agent-talkd' \
  "$test_root/update-failure-curl.log" || true)" -eq 0
test -z "$(find "$update_failure_tmp" -mindepth 1 -print -quit)"

invalid_tag_home="$test_root/invalid-tag-home"
invalid_tag_tmp="$test_root/invalid-tag-tmp"
mkdir -p "$invalid_tag_home/.local/bin" "$invalid_tag_tmp"
if PATH="$fake_bin:$invalid_tag_home/.local/bin:/usr/bin:/bin" \
  HOME="$invalid_tag_home" \
  INSTALL_APPS_TEST_LOG="$test_root/invalid-tag-curl.log" \
  INSTALL_APPS_TEST_ARGS_LOG="$test_root/invalid-tag-curl-args.log" \
  INSTALL_APPS_TEST_LATEST_TAG=garbage \
  TMPDIR="$invalid_tag_tmp" \
  bash "$repo_root/bin/install-apps" >"$test_root/invalid-tag.out" 2>&1; then
  echo "install-apps should fail when the latest agent-talk tag is invalid" >&2
  exit 1
fi

grep -F "Cannot determine latest agent-talkd version" "$test_root/invalid-tag.out" >/dev/null
test ! -e "$invalid_tag_home/.local/bin/agent-talk"
test -z "$(find "$invalid_tag_tmp" -mindepth 1 -print -quit)"

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

checksum_home="$test_root/checksum-home"
checksum_tmp="$test_root/checksum-tmp"
mkdir -p "$checksum_home/.local/bin" "$checksum_tmp"
cat >"$checksum_home/.local/bin/agent-talk" <<'OLD_AGENT'
#!/bin/sh
echo "agent-talk 0.1.0"
OLD_AGENT
chmod +x "$checksum_home/.local/bin/agent-talk"
if PATH="$fake_bin:$checksum_home/.local/bin:/usr/bin:/bin" \
  HOME="$checksum_home" \
  INSTALL_APPS_TEST_LOG="$test_root/checksum-curl.log" \
  INSTALL_APPS_TEST_ARGS_LOG="$test_root/checksum-curl-args.log" \
  INSTALL_APPS_TEST_BAD_AGENT_TALK_CHECKSUM=1 \
  TMPDIR="$checksum_tmp" \
  bash "$repo_root/bin/install-apps" >"$test_root/checksum.out" 2>&1; then
  echo "install-apps should fail when the agent-talk checksum does not match" >&2
  exit 1
fi

test "$("$checksum_home/.local/bin/agent-talk" --version)" = "agent-talk 0.1.0"
test -z "$(find "$checksum_tmp" -mindepth 1 -print -quit)"

echo "install-apps Linux/macOS agent CLI test: pass"
