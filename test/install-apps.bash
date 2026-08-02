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
mux_log="$test_root/mux.log"
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

cat >"$fake_bin/uname" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  -s) printf '%s\n' "${INSTALL_APPS_TEST_UNAME_S:-Linux}" ;;
  -m) printf '%s\n' "${INSTALL_APPS_TEST_UNAME_M:-x86_64}" ;;
  *) exit 64 ;;
esac
STUB
chmod +x "$fake_bin/uname"

cat >"$fake_bin/shasum" <<'STUB'
#!/usr/bin/env bash
if [ "${1:-}" != -a ] || [ "${2:-}" != 256 ]; then
  exit 64
fi
shift 2
sha256sum "$@"
STUB
chmod +x "$fake_bin/shasum"

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
  https://github.com/miyabisun/mux/releases/latest)
    test "$write_out" = '%{redirect_url}'
    printf '%s%s' 'https://github.com/miyabisun/mux/releases/tag/' \
      "${INSTALL_APPS_TEST_MUX_LATEST_TAG:-v0.1.1}"
    exit 0
    ;;
  https://github.com/miyabisun/mux/releases/download/v0.1.1/mux-linux-x86_64.tar.gz|\
  https://github.com/miyabisun/mux/releases/download/v0.1.1/mux-macos-aarch64.tar.gz)
    archive_root="${output}.root"
    mkdir -p "$archive_root"
    cat >"$archive_root/mux" <<'MUX'
#!/bin/sh
case "${1:-}" in
  --version) echo "mux ${INSTALL_APPS_TEST_MUX_VERSION:-0.1.1}" ;;
  --help)
    printf '%s\n' \
      'Select, validate, and launch tmux projects' \
      '  update    Update mux from the latest GitHub Release'
    ;;
  update)
    printf '%s\n' update >>"${INSTALL_APPS_TEST_MUX_LOG:-/dev/null}"
    exit "${INSTALL_APPS_TEST_MUX_UPDATE_STATUS:-0}"
    ;;
  *) exit 1 ;;
esac
MUX
    chmod +x "$archive_root/mux"
    printf '%s\n' license >"$archive_root/LICENSE"
    if [ -n "${INSTALL_APPS_TEST_MUX_EXTRA_MEMBER:-}" ]; then
      printf '%s\n' unexpected >"$archive_root/unexpected"
      tar -czf "$output" -C "$archive_root" mux LICENSE unexpected
    else
      tar -czf "$output" -C "$archive_root" mux LICENSE
    fi
    rm -rf "$archive_root"
    exit 0
    ;;
  https://github.com/miyabi-sunny-side/pen-cli/releases/latest)
    test "$write_out" = '%{redirect_url}'
    printf '%s%s' 'https://github.com/miyabi-sunny-side/pen-cli/releases/tag/' \
      "${INSTALL_APPS_TEST_PEN_LATEST_TAG:-v0.1.0}"
    exit 0
    ;;
  https://github.com/miyabi-sunny-side/pen-cli/releases/download/v0.1.0/pen-linux-x86_64.tar.gz|\
  https://github.com/miyabi-sunny-side/pen-cli/releases/download/v0.1.0/pen-macos-aarch64.tar.gz|\
  https://github.com/miyabi-sunny-side/pen-cli/releases/download/v0.1.2/pen-linux-x86_64.tar.gz|\
  https://github.com/miyabi-sunny-side/pen-cli/releases/download/v0.1.2/pen-macos-aarch64.tar.gz)
    archive_root="${output}.root"
    mkdir -p "$archive_root"
    if [ -n "${INSTALL_APPS_TEST_PEN_LEGACY_ARCHIVE:-}" ]; then
      cat >"$archive_root/pen" <<'PEN'
#!/bin/sh
echo 'pen — suspend and restore herdr workspaces'
PEN
    else
      cat >"$archive_root/pen" <<'PEN'
#!/bin/sh
if [ "${1:-}" = "--version" ]; then
  echo "pen ${PEN_STUB_VERSION:-0.1.0}"
  exit 0
fi
echo 'pen — suspend and restore herdr workspaces'
PEN
    fi
    chmod +x "$archive_root/pen"
    printf '%s\n' license >"$archive_root/LICENSE"
    tar -czf "$output" -C "$archive_root" pen LICENSE
    rm -rf "$archive_root"
    exit 0
    ;;
  https://github.com/miyabi-sunny-side/pen-cli/releases/download/v0.1.0/pen-linux-x86_64.tar.gz.sha256|\
  https://github.com/miyabi-sunny-side/pen-cli/releases/download/v0.1.0/pen-macos-aarch64.tar.gz.sha256|\
  https://github.com/miyabi-sunny-side/pen-cli/releases/download/v0.1.2/pen-linux-x86_64.tar.gz.sha256|\
  https://github.com/miyabi-sunny-side/pen-cli/releases/download/v0.1.2/pen-macos-aarch64.tar.gz.sha256)
    archive_path="${output%.sha256}"
    archive_name="$(basename "$archive_path")"
    if [ -n "${INSTALL_APPS_TEST_BAD_PEN_CHECKSUM:-}" ]; then
      digest="0000000000000000000000000000000000000000000000000000000000000000"
    else
      digest="$(sha256sum "$archive_path" | awk '{ print $1 }')"
    fi
    printf '%s  %s\n' "$digest" "$archive_name" >"$output"
    exit 0
    ;;
  https://github.com/miyabisun/mux/releases/download/v0.1.1/mux-linux-x86_64.tar.gz.sha256|\
  https://github.com/miyabisun/mux/releases/download/v0.1.1/mux-macos-aarch64.tar.gz.sha256)
    archive_path="${output%.sha256}"
    archive_name="$(basename "$archive_path")"
    if [ -n "${INSTALL_APPS_TEST_BAD_MUX_CHECKSUM:-}" ]; then
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
  INSTALL_APPS_TEST_MUX_LOG="$mux_log" \
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
test -x "$fake_home/.local/bin/mux"
test "$("$fake_home/.local/bin/mux" --version)" = "mux 0.1.1"
test -x "$fake_home/.local/bin/pen"
"$fake_home/.local/bin/pen" | grep -Fq 'pen — suspend and restore herdr workspaces'
test "$("$fake_home/.local/bin/pen" --version)" = "pen 0.1.0"
grep -F "daemon not applicable" "$test_root/first-run.out" >/dev/null
test "$(grep -Fxc ensure-daemon "$agent_log")" -eq 1
test -z "$(find "$tmp_dir" -mindepth 1 -print -quit)"

PATH="$fake_bin:$fake_home/.local/bin:/usr/bin:/bin" \
  HOME="$fake_home" \
  INSTALL_APPS_TEST_LOG="$log" \
  INSTALL_APPS_TEST_ARGS_LOG="$args_log" \
  INSTALL_APPS_TEST_AGENT_LOG="$agent_log" \
  INSTALL_APPS_TEST_MUX_LOG="$mux_log" \
  TMPDIR="$tmp_dir" \
  bash "$repo_root/bin/install-apps" >"$test_root/second-run.out"

test "$(grep -Fc 'https://cursor.com/install' "$log")" -eq 1
test "$(grep -Fc 'https://chatgpt.com/codex/install.sh' "$log")" -eq 1
test "$(grep -Fc 'https://github.com/miyabi-sunny-side/agent-talkd/releases/latest' "$log")" -eq 1
test "$(grep -Fc 'agent-talk-linux-x86_64.tar.gz' "$log")" -eq 2
test "$(grep -Fc 'https://github.com/miyabisun/mux/releases/latest' "$log")" -eq 1
test "$(grep -Fc 'mux-linux-x86_64.tar.gz' "$log")" -eq 2
grep -F "Cursor CLI already installed" "$test_root/second-run.out" >/dev/null
grep -F "Codex CLI already installed" "$test_root/second-run.out" >/dev/null
grep -F "Updating agent-talkd via agent-talk update" "$test_root/second-run.out" >/dev/null
test "$(grep -Fxc update "$agent_log")" -eq 1
grep -F "Updating mux via mux update" "$test_root/second-run.out" >/dev/null
test "$(grep -Fxc update "$mux_log")" -eq 1
grep -F "pen v0.1.0 already installed" "$test_root/second-run.out" >/dev/null
test "$(grep -Fc 'pen-linux-x86_64.tar.gz' "$log")" -eq 2

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
test "$("$linux_home/.local/bin/mux" --version)" = "mux 0.1.1"
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

prepare_mux_case() {
  local home="$1"
  local tmp="$2"

  mkdir -p "$home/.local/bin" "$tmp"
  cp "$fake_home/.local/bin/cursor-agent" "$home/.local/bin/cursor-agent"
  cp "$fake_home/.local/bin/codex" "$home/.local/bin/codex"
  cp "$fake_home/.local/bin/agent-talk" "$home/.local/bin/agent-talk"
}

darwin_home="$test_root/darwin-home"
darwin_tmp="$test_root/darwin-tmp"
prepare_mux_case "$darwin_home" "$darwin_tmp"
PATH="$fake_bin:$darwin_home/.local/bin:/usr/bin:/bin" \
  HOME="$darwin_home" \
  INSTALL_APPS_TEST_LOG="$test_root/darwin-curl.log" \
  INSTALL_APPS_TEST_ARGS_LOG="$test_root/darwin-curl-args.log" \
  INSTALL_APPS_TEST_UNAME_S=Darwin \
  INSTALL_APPS_TEST_UNAME_M=arm64 \
  TMPDIR="$darwin_tmp" \
  bash "$repo_root/bin/install-apps" >"$test_root/darwin.out"

test "$("$darwin_home/.local/bin/mux" --version)" = "mux 0.1.1"
grep -F "mux-macos-aarch64.tar.gz" "$test_root/darwin-curl.log" >/dev/null
grep -F "pen-macos-aarch64.tar.gz" "$test_root/darwin-curl.log" >/dev/null
test -x "$darwin_home/.local/bin/pen"
test -z "$(find "$darwin_tmp" -mindepth 1 -print -quit)"

mux_update_failure_home="$test_root/mux-update-failure-home"
mux_update_failure_tmp="$test_root/mux-update-failure-tmp"
prepare_mux_case "$mux_update_failure_home" "$mux_update_failure_tmp"
cp "$fake_home/.local/bin/mux" "$mux_update_failure_home/.local/bin/mux"
mux_update_failure_before="$(sha256_file "$mux_update_failure_home/.local/bin/mux")"
if PATH="$fake_bin:$mux_update_failure_home/.local/bin:/usr/bin:/bin" \
  HOME="$mux_update_failure_home" \
  INSTALL_APPS_TEST_LOG="$test_root/mux-update-failure-curl.log" \
  INSTALL_APPS_TEST_ARGS_LOG="$test_root/mux-update-failure-curl-args.log" \
  INSTALL_APPS_TEST_MUX_UPDATE_STATUS=23 \
  TMPDIR="$mux_update_failure_tmp" \
  bash "$repo_root/bin/install-apps" >"$test_root/mux-update-failure.out" 2>&1; then
  echo "install-apps should propagate mux update failures" >&2
  exit 1
fi

test "$mux_update_failure_before" = \
  "$(sha256_file "$mux_update_failure_home/.local/bin/mux")"
test ! -e "$test_root/mux-update-failure-curl.log" \
  || test "$(grep -Fc 'github.com/miyabisun/mux' \
    "$test_root/mux-update-failure-curl.log" || true)" -eq 0
test -z "$(find "$mux_update_failure_tmp" -mindepth 1 -print -quit)"

unknown_mux_home="$test_root/unknown-mux-home"
unknown_mux_tmp="$test_root/unknown-mux-tmp"
prepare_mux_case "$unknown_mux_home" "$unknown_mux_tmp"
cat >"$unknown_mux_home/.local/bin/mux" <<'UNKNOWN_MUX'
#!/bin/sh
echo "another mux"
UNKNOWN_MUX
chmod +x "$unknown_mux_home/.local/bin/mux"
unknown_mux_before="$(sha256_file "$unknown_mux_home/.local/bin/mux")"
if PATH="$fake_bin:$unknown_mux_home/.local/bin:/usr/bin:/bin" \
  HOME="$unknown_mux_home" \
  INSTALL_APPS_TEST_LOG="$test_root/unknown-mux-curl.log" \
  INSTALL_APPS_TEST_ARGS_LOG="$test_root/unknown-mux-curl-args.log" \
  TMPDIR="$unknown_mux_tmp" \
  bash "$repo_root/bin/install-apps" >"$test_root/unknown-mux.out" 2>&1; then
  echo "install-apps should refuse an unrecognized mux target" >&2
  exit 1
fi

grep -F "Refusing to replace unrecognized mux target" "$test_root/unknown-mux.out" >/dev/null
test "$unknown_mux_before" = "$(sha256_file "$unknown_mux_home/.local/bin/mux")"
test ! -e "$test_root/unknown-mux-curl.log" \
  || test "$(grep -Fc 'github.com/miyabisun/mux' \
    "$test_root/unknown-mux-curl.log" || true)" -eq 0
test -z "$(find "$unknown_mux_tmp" -mindepth 1 -print -quit)"

unsupported_mux_home="$test_root/unsupported-mux-home"
unsupported_mux_tmp="$test_root/unsupported-mux-tmp"
prepare_mux_case "$unsupported_mux_home" "$unsupported_mux_tmp"
if PATH="$fake_bin:$unsupported_mux_home/.local/bin:/usr/bin:/bin" \
  HOME="$unsupported_mux_home" \
  INSTALL_APPS_TEST_LOG="$test_root/unsupported-mux-curl.log" \
  INSTALL_APPS_TEST_ARGS_LOG="$test_root/unsupported-mux-curl-args.log" \
  INSTALL_APPS_TEST_UNAME_S=FreeBSD \
  INSTALL_APPS_TEST_UNAME_M=x86_64 \
  TMPDIR="$unsupported_mux_tmp" \
  bash "$repo_root/bin/install-apps" >"$test_root/unsupported-mux.out" 2>&1; then
  echo "install-apps should reject unsupported mux platforms" >&2
  exit 1
fi

grep -F "mux does not support FreeBSD-x86_64" "$test_root/unsupported-mux.out" >/dev/null
test ! -e "$unsupported_mux_home/.local/bin/mux"
test -z "$(find "$unsupported_mux_tmp" -mindepth 1 -print -quit)"

invalid_mux_tag_home="$test_root/invalid-mux-tag-home"
invalid_mux_tag_tmp="$test_root/invalid-mux-tag-tmp"
prepare_mux_case "$invalid_mux_tag_home" "$invalid_mux_tag_tmp"
if PATH="$fake_bin:$invalid_mux_tag_home/.local/bin:/usr/bin:/bin" \
  HOME="$invalid_mux_tag_home" \
  INSTALL_APPS_TEST_LOG="$test_root/invalid-mux-tag-curl.log" \
  INSTALL_APPS_TEST_ARGS_LOG="$test_root/invalid-mux-tag-curl-args.log" \
  INSTALL_APPS_TEST_MUX_LATEST_TAG=garbage \
  TMPDIR="$invalid_mux_tag_tmp" \
  bash "$repo_root/bin/install-apps" >"$test_root/invalid-mux-tag.out" 2>&1; then
  echo "install-apps should fail when the latest mux tag is invalid" >&2
  exit 1
fi

grep -F "Cannot determine latest mux version" "$test_root/invalid-mux-tag.out" >/dev/null
test ! -e "$invalid_mux_tag_home/.local/bin/mux"
test "$(grep -Fc '/releases/download/' "$test_root/invalid-mux-tag-curl.log" || true)" -eq 0
test -z "$(find "$invalid_mux_tag_tmp" -mindepth 1 -print -quit)"

bad_mux_checksum_home="$test_root/bad-mux-checksum-home"
bad_mux_checksum_tmp="$test_root/bad-mux-checksum-tmp"
prepare_mux_case "$bad_mux_checksum_home" "$bad_mux_checksum_tmp"
if PATH="$fake_bin:$bad_mux_checksum_home/.local/bin:/usr/bin:/bin" \
  HOME="$bad_mux_checksum_home" \
  INSTALL_APPS_TEST_LOG="$test_root/bad-mux-checksum-curl.log" \
  INSTALL_APPS_TEST_ARGS_LOG="$test_root/bad-mux-checksum-curl-args.log" \
  INSTALL_APPS_TEST_BAD_MUX_CHECKSUM=1 \
  TMPDIR="$bad_mux_checksum_tmp" \
  bash "$repo_root/bin/install-apps" >"$test_root/bad-mux-checksum.out" 2>&1; then
  echo "install-apps should fail when the mux checksum does not match" >&2
  exit 1
fi

grep -F "Checksum mismatch for mux" "$test_root/bad-mux-checksum.out" >/dev/null
test ! -e "$bad_mux_checksum_home/.local/bin/mux"
test -z "$(find "$bad_mux_checksum_tmp" -mindepth 1 -print -quit)"

unsafe_mux_archive_home="$test_root/unsafe-mux-archive-home"
unsafe_mux_archive_tmp="$test_root/unsafe-mux-archive-tmp"
prepare_mux_case "$unsafe_mux_archive_home" "$unsafe_mux_archive_tmp"
if PATH="$fake_bin:$unsafe_mux_archive_home/.local/bin:/usr/bin:/bin" \
  HOME="$unsafe_mux_archive_home" \
  INSTALL_APPS_TEST_LOG="$test_root/unsafe-mux-archive-curl.log" \
  INSTALL_APPS_TEST_ARGS_LOG="$test_root/unsafe-mux-archive-curl-args.log" \
  INSTALL_APPS_TEST_MUX_EXTRA_MEMBER=1 \
  TMPDIR="$unsafe_mux_archive_tmp" \
  bash "$repo_root/bin/install-apps" >"$test_root/unsafe-mux-archive.out" 2>&1; then
  echo "install-apps should reject unexpected mux archive members" >&2
  exit 1
fi

grep -F "Unsafe archive member for mux" "$test_root/unsafe-mux-archive.out" >/dev/null
test ! -e "$unsafe_mux_archive_home/.local/bin/mux"
test -z "$(find "$unsafe_mux_archive_tmp" -mindepth 1 -print -quit)"

wrong_mux_version_home="$test_root/wrong-mux-version-home"
wrong_mux_version_tmp="$test_root/wrong-mux-version-tmp"
prepare_mux_case "$wrong_mux_version_home" "$wrong_mux_version_tmp"
if PATH="$fake_bin:$wrong_mux_version_home/.local/bin:/usr/bin:/bin" \
  HOME="$wrong_mux_version_home" \
  INSTALL_APPS_TEST_LOG="$test_root/wrong-mux-version-curl.log" \
  INSTALL_APPS_TEST_ARGS_LOG="$test_root/wrong-mux-version-curl-args.log" \
  INSTALL_APPS_TEST_MUX_VERSION=9.9.9 \
  TMPDIR="$wrong_mux_version_tmp" \
  bash "$repo_root/bin/install-apps" >"$test_root/wrong-mux-version.out" 2>&1; then
  echo "install-apps should reject a mux binary with the wrong version" >&2
  exit 1
fi

grep -F "mux binary version does not match" "$test_root/wrong-mux-version.out" >/dev/null
test ! -e "$wrong_mux_version_home/.local/bin/mux"
test -z "$(find "$wrong_mux_version_tmp" -mindepth 1 -print -quit)"

update_pen_home="$test_root/update-pen-home"
update_pen_tmp="$test_root/update-pen-tmp"
prepare_mux_case "$update_pen_home" "$update_pen_tmp"
cp "$fake_home/.local/bin/mux" "$update_pen_home/.local/bin/mux"
cat >"$update_pen_home/.local/bin/pen" <<'OLD_PEN'
#!/bin/sh
if [ "${1:-}" = "--version" ]; then
  echo "pen 0.0.9"
  exit 0
fi
echo 'pen — suspend and restore herdr workspaces'
OLD_PEN
chmod +x "$update_pen_home/.local/bin/pen"
update_pen_before="$(sha256_file "$update_pen_home/.local/bin/pen")"
PATH="$fake_bin:$update_pen_home/.local/bin:/usr/bin:/bin" \
  HOME="$update_pen_home" \
  INSTALL_APPS_TEST_LOG="$test_root/update-pen-curl.log" \
  INSTALL_APPS_TEST_ARGS_LOG="$test_root/update-pen-curl-args.log" \
  TMPDIR="$update_pen_tmp" \
  bash "$repo_root/bin/install-apps" >"$test_root/update-pen.out"
grep -F "pen v0.1.0 installed" "$test_root/update-pen.out" >/dev/null
if grep -Fq "==> pen v0.1.0 already installed" "$test_root/update-pen.out"; then
  echo "recognized old pen should be replaced, not treated as current" >&2
  exit 1
fi
update_pen_after="$(sha256_file "$update_pen_home/.local/bin/pen")"
test "$update_pen_before" != "$update_pen_after"
test "$("$update_pen_home/.local/bin/pen" --version)" = "pen 0.1.0"
test -z "$(find "$update_pen_tmp" -mindepth 1 -print -quit)"

legacy_idem_home="$test_root/legacy-idem-home"
legacy_idem_tmp="$test_root/legacy-idem-tmp"
prepare_mux_case "$legacy_idem_home" "$legacy_idem_tmp"
cp "$fake_home/.local/bin/mux" "$legacy_idem_home/.local/bin/mux"
PATH="$fake_bin:$legacy_idem_home/.local/bin:/usr/bin:/bin" \
  HOME="$legacy_idem_home" \
  INSTALL_APPS_TEST_LOG="$test_root/legacy-idem-curl.log" \
  INSTALL_APPS_TEST_ARGS_LOG="$test_root/legacy-idem-curl-args.log" \
  INSTALL_APPS_TEST_PEN_LEGACY_ARCHIVE=1 \
  TMPDIR="$legacy_idem_tmp" \
  bash "$repo_root/bin/install-apps" >"$test_root/legacy-idem-1.out"
grep -F "pen v0.1.0 installed" "$test_root/legacy-idem-1.out" >/dev/null
legacy_idem_hash="$(sha256_file "$legacy_idem_home/.local/bin/pen")"
PATH="$fake_bin:$legacy_idem_home/.local/bin:/usr/bin:/bin" \
  HOME="$legacy_idem_home" \
  INSTALL_APPS_TEST_LOG="$test_root/legacy-idem-curl.log" \
  INSTALL_APPS_TEST_ARGS_LOG="$test_root/legacy-idem-curl-args.log" \
  INSTALL_APPS_TEST_PEN_LEGACY_ARCHIVE=1 \
  TMPDIR="$legacy_idem_tmp" \
  bash "$repo_root/bin/install-apps" >"$test_root/legacy-idem-2.out"
grep -F "pen v0.1.0 already installed" "$test_root/legacy-idem-2.out" >/dev/null
test "$legacy_idem_hash" = "$(sha256_file "$legacy_idem_home/.local/bin/pen")"
test -z "$(find "$legacy_idem_tmp" -mindepth 1 -print -quit)"

future_strict_home="$test_root/future-strict-home"
future_strict_tmp="$test_root/future-strict-tmp"
prepare_mux_case "$future_strict_home" "$future_strict_tmp"
cp "$fake_home/.local/bin/mux" "$future_strict_home/.local/bin/mux"
if PATH="$fake_bin:$future_strict_home/.local/bin:/usr/bin:/bin" \
  HOME="$future_strict_home" \
  INSTALL_APPS_TEST_LOG="$test_root/future-strict-curl.log" \
  INSTALL_APPS_TEST_ARGS_LOG="$test_root/future-strict-curl-args.log" \
  INSTALL_APPS_TEST_PEN_LATEST_TAG=v0.1.2 \
  INSTALL_APPS_TEST_PEN_LEGACY_ARCHIVE=1 \
  TMPDIR="$future_strict_tmp" \
  bash "$repo_root/bin/install-apps" >"$test_root/future-strict.out" 2>&1; then
  echo "a future banner-only pen release must be rejected" >&2
  exit 1
fi
grep -F "pen binary does not look like pen in release v0.1.2" "$test_root/future-strict.out" >/dev/null
test ! -e "$future_strict_home/.local/bin/pen"
test -z "$(find "$future_strict_tmp" -mindepth 1 -print -quit)"

legacy_pen_home="$test_root/legacy-pen-home"
legacy_pen_tmp="$test_root/legacy-pen-tmp"
prepare_mux_case "$legacy_pen_home" "$legacy_pen_tmp"
cp "$fake_home/.local/bin/mux" "$legacy_pen_home/.local/bin/mux"
cat >"$legacy_pen_home/.local/bin/pen" <<'LEGACY_PEN'
#!/bin/sh
echo 'pen — suspend and restore herdr workspaces'
LEGACY_PEN
chmod +x "$legacy_pen_home/.local/bin/pen"
PATH="$fake_bin:$legacy_pen_home/.local/bin:/usr/bin:/bin" \
  HOME="$legacy_pen_home" \
  INSTALL_APPS_TEST_LOG="$test_root/legacy-pen-curl.log" \
  INSTALL_APPS_TEST_ARGS_LOG="$test_root/legacy-pen-curl-args.log" \
  TMPDIR="$legacy_pen_tmp" \
  bash "$repo_root/bin/install-apps" >"$test_root/legacy-pen.out"
grep -F "pen v0.1.0 installed" "$test_root/legacy-pen.out" >/dev/null
test "$("$legacy_pen_home/.local/bin/pen" --version)" = "pen 0.1.0"
test -z "$(find "$legacy_pen_tmp" -mindepth 1 -print -quit)"

bad_pen_checksum_home="$test_root/bad-pen-checksum-home"
bad_pen_checksum_tmp="$test_root/bad-pen-checksum-tmp"
prepare_mux_case "$bad_pen_checksum_home" "$bad_pen_checksum_tmp"
cp "$fake_home/.local/bin/mux" "$bad_pen_checksum_home/.local/bin/mux"
if PATH="$fake_bin:$bad_pen_checksum_home/.local/bin:/usr/bin:/bin" \
  HOME="$bad_pen_checksum_home" \
  INSTALL_APPS_TEST_LOG="$test_root/bad-pen-checksum-curl.log" \
  INSTALL_APPS_TEST_ARGS_LOG="$test_root/bad-pen-checksum-curl-args.log" \
  INSTALL_APPS_TEST_BAD_PEN_CHECKSUM=1 \
  TMPDIR="$bad_pen_checksum_tmp" \
  bash "$repo_root/bin/install-apps" >"$test_root/bad-pen-checksum.out" 2>&1; then
  echo "install-apps should fail when the pen checksum does not match" >&2
  exit 1
fi
grep -F "Checksum mismatch for pen" "$test_root/bad-pen-checksum.out" >/dev/null
test ! -e "$bad_pen_checksum_home/.local/bin/pen"
test -z "$(find "$bad_pen_checksum_tmp" -mindepth 1 -print -quit)"

unknown_pen_home="$test_root/unknown-pen-home"
unknown_pen_tmp="$test_root/unknown-pen-tmp"
prepare_mux_case "$unknown_pen_home" "$unknown_pen_tmp"
cp "$fake_home/.local/bin/mux" "$unknown_pen_home/.local/bin/mux"
cat >"$unknown_pen_home/.local/bin/pen" <<'UNKNOWN_PEN'
#!/bin/sh
echo "another pen"
UNKNOWN_PEN
chmod +x "$unknown_pen_home/.local/bin/pen"
unknown_pen_before="$(sha256_file "$unknown_pen_home/.local/bin/pen")"
if PATH="$fake_bin:$unknown_pen_home/.local/bin:/usr/bin:/bin" \
  HOME="$unknown_pen_home" \
  INSTALL_APPS_TEST_LOG="$test_root/unknown-pen-curl.log" \
  INSTALL_APPS_TEST_ARGS_LOG="$test_root/unknown-pen-curl-args.log" \
  TMPDIR="$unknown_pen_tmp" \
  bash "$repo_root/bin/install-apps" >"$test_root/unknown-pen.out" 2>&1; then
  echo "install-apps should refuse an unrecognized pen target" >&2
  exit 1
fi
grep -F "Refusing to replace unrecognized pen target" "$test_root/unknown-pen.out" >/dev/null
test "$unknown_pen_before" = "$(sha256_file "$unknown_pen_home/.local/bin/pen")"
test ! -e "$test_root/unknown-pen-curl.log" \
  || test "$(grep -Fc 'pen-cli' "$test_root/unknown-pen-curl.log" || true)" -eq 0
test -z "$(find "$unknown_pen_tmp" -mindepth 1 -print -quit)"

echo "install-apps Linux/macOS agent CLI test: pass"
