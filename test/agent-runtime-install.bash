#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
installer="$repo_root/agent/common/bin/install-agent-runtime"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
fake_home="$test_root/home"
tool_bin="$test_root/tools"
mkdir -p "$fake_home" "$tool_bin"

link_host_tool() {
  tool_name="$1"
  target_dir="$2"
  tool_path="$(command -v "$tool_name")" || {
    echo "required host tool not found: $tool_name" >&2
    exit 1
  }
  if [ ! -x "$tool_path" ]; then
    echo "host tool is not executable: $tool_path" >&2
    exit 1
  fi
  ln -s "$tool_path" "$target_dir/$tool_name"
}

cat >"$tool_bin/curl" <<'TOOL'
#!/bin/bash
exit 0
TOOL
chmod 0755 "$tool_bin/curl"

HOME="$fake_home" PATH="$tool_bin:/usr/bin:/bin" "$installer"
runtime_bin="$fake_home/.local/bin"
rules_file="$fake_home/.codex/rules/agent-talk.rules"

for runtime_name in emit-turn-end.sh notify-file-permission.sh; do
  test -f "$runtime_bin/$runtime_name"
  test -x "$runtime_bin/$runtime_name"
  test ! -L "$runtime_bin/$runtime_name"
done
test -f "$runtime_bin/.dotfiles-agent-runtime"
test ! -L "$runtime_bin/.dotfiles-agent-runtime"
# tmux backend は撤去済み。pin が tmux 依存を運び直してはならない
if grep -q '^TMUX_BIN=' "$runtime_bin/.dotfiles-agent-runtime"; then
  echo 'runtime pin must not carry a tmux dependency' >&2
  exit 1
fi
# workspace 静穏ゲート用の herdr / jq は optional pin として常に鍵が載る
grep -q '^HERDR_BIN=' "$runtime_bin/.dotfiles-agent-runtime"
grep -q '^JQ_BIN=' "$runtime_bin/.dotfiles-agent-runtime"
test -f "$rules_file"
test ! -L "$rules_file"
grep -Fq "$runtime_bin/notify-file-permission.sh" "$rules_file"

# 旧 peer dispatcher は撤去済み。配置も、それを許可する rule も残ってはならない
if test -e "$runtime_bin/agent-talk-peer"; then
  echo 'installer must not place the retired peer dispatcher' >&2
  exit 1
fi
if grep -Fq 'agent-talk-peer' "$rules_file"; then
  echo 'installed rule must not allow the retired peer dispatcher' >&2
  exit 1
fi

result="$(codex execpolicy check --rules "$rules_file" \
  "$runtime_bin/notify-file-permission.sh" codex 2>/dev/null)"
python3 - "$result" <<'PY'
import json
import sys

if json.loads(sys.argv[1]).get("decision") != "allow":
    raise SystemExit("installed absolute notifier rule must allow the call")
PY

result="$(codex execpolicy check --rules "$rules_file" \
  notify-file-permission.sh codex 2>/dev/null)"
python3 - "$result" <<'PY'
import json
import sys

if json.loads(sys.argv[1]).get("decision") == "allow":
    raise SystemExit("basename notifier must stay outside the absolute rule")
PY

# bin/install must propagate a runtime-installer failure instead of continuing
# with a stale policy. This PATH provides bootstrap tools but deliberately no
# mktemp, so the helper exits nonzero before publishing its sidecar.
bootstrap_bin="$test_root/bootstrap-tools"
bootstrap_home="$test_root/bootstrap-home"
mkdir -p "$bootstrap_bin" "$bootstrap_home"
for tool_name in dirname ln mkdir cp readlink unlink mv; do
  link_host_tool "$tool_name" "$bootstrap_bin"
done
if HOME="$bootstrap_home" PATH="$bootstrap_bin" \
  /bin/bash "$repo_root/bin/install" >/dev/null 2>&1; then
  echo 'bin/install must propagate install-agent-runtime failure' >&2
  exit 1
fi

# Notification runtime needs neither hash/stat tools nor curl to install.
no_curl_bin="$test_root/no-curl-tools"
no_curl_home="$test_root/no-curl-home"
mkdir -p "$no_curl_bin" "$no_curl_home"
for tool_name in dirname mkdir cp chmod unlink mktemp sed mv rm; do
  link_host_tool "$tool_name" "$no_curl_bin"
done
HOME="$no_curl_home" PATH="$no_curl_bin" "$installer"
grep -Fx 'CURL_BIN=' \
  "$no_curl_home/.local/bin/.dotfiles-agent-runtime" >/dev/null
test -x "$no_curl_home/.local/bin/notify-file-permission.sh"

# Exercise the installed files with a PATH containing no hash/stat commands.
for runtime_name in emit-turn-end.sh notify-file-permission.sh; do
  env -i HOME="$no_curl_home" PATH="$no_curl_bin" MOCA_URL=https://notify.invalid \
    "$no_curl_home/.local/bin/$runtime_name" codex
done
cat >"$no_curl_bin/curl" <<'TOOL'
#!/bin/bash
printf '%s\n' "$*" >>"$NOTIFY_TEST_CURL_LOG"
exit "${NOTIFY_TEST_CURL_FAIL:-0}"
TOOL
chmod +x "$no_curl_bin/curl"
export NOTIFY_TEST_CURL_LOG="$test_root/installed-curl.log"
# A legacy sidecar may point to tools that no longer exist. Reinstall replaces
# it with the reduced format.
printf 'SHA256_BIN=/missing/sha256sum\nSHA256_MODE=sha256sum\nCP_BIN=/missing/cp\nRM_BIN=/missing/rm\nSTAT_BIN=/missing/stat\nSTAT_MODE=gnu\n' \
  >>"$no_curl_home/.local/bin/.dotfiles-agent-runtime"
HOME="$no_curl_home" PATH="$no_curl_bin" "$installer"
# The persisted data format contains only the three notification dependencies.
printf 'CURL_BIN=%s\nHERDR_BIN=\nJQ_BIN=\n' "$no_curl_bin/curl" >"$test_root/expected-sidecar"
cmp "$test_root/expected-sidecar" "$no_curl_home/.local/bin/.dotfiles-agent-runtime"
for runtime_name in emit-turn-end.sh notify-file-permission.sh; do
  env -i HOME="$no_curl_home" PATH="$no_curl_bin" MOCA_URL=https://notify.invalid \
    NOTIFY_TEST_CURL_LOG="$NOTIFY_TEST_CURL_LOG" \
    "$no_curl_home/.local/bin/$runtime_name" codex
done
test "$(wc -l <"$NOTIFY_TEST_CURL_LOG")" -eq 2
grep -F 'が完了しました' "$NOTIFY_TEST_CURL_LOG" >/dev/null
grep -F 'でファイル操作の許可が必要です' "$NOTIFY_TEST_CURL_LOG" >/dev/null
# Missing MOCA and a failing destination still return success after migration.
for runtime_name in emit-turn-end.sh notify-file-permission.sh; do
  env -i HOME="$no_curl_home" PATH="$no_curl_bin" \
    "$no_curl_home/.local/bin/$runtime_name" codex
  env -i HOME="$no_curl_home" PATH="$no_curl_bin" MOCA_URL=https://notify.invalid \
    NOTIFY_TEST_CURL_LOG="$NOTIFY_TEST_CURL_LOG" NOTIFY_TEST_CURL_FAIL=22 \
    "$no_curl_home/.local/bin/$runtime_name" codex
done
test "$(wc -l <"$NOTIFY_TEST_CURL_LOG")" -eq 4

# 既に配置済みの旧 dispatcher は、再インストールで撤去されなければならない。
# 残すと PATH 上で生き続け、ack できない経路が復活する
stale_home="$test_root/stale-home"
mkdir -p "$stale_home/.local/bin"
printf '#!/bin/sh\nexit 0\n' >"$stale_home/.local/bin/agent-talk-peer"
chmod 0755 "$stale_home/.local/bin/agent-talk-peer"
ln -s "$repo_root/config/herdr/bin/herdr-addr" "$stale_home/.local/bin/herdr-addr"
HOME="$stale_home" PATH="$tool_bin:/usr/bin:/bin" "$installer"
if test -e "$stale_home/.local/bin/agent-talk-peer"; then
  echo 'installer must remove a previously installed peer dispatcher' >&2
  exit 1
fi

if test -e "$stale_home/.local/bin/herdr-addr" || test -L "$stale_home/.local/bin/herdr-addr"; then
  echo 'installer must remove the retired cross-session address helper' >&2
  exit 1
fi

cp "$runtime_bin/.dotfiles-agent-runtime" "$test_root/sidecar-before"
# Every pinned executable must stay outside the source tree and have no
# whitespace in its path. Rejection must leave an installed sidecar untouched.
staged_root="$test_root/source"
mkdir -p "$staged_root/agent/common/bin" "$staged_root/tools" "$test_root/spaced tools"
cp "$installer" "$staged_root/agent/common/bin/install-agent-runtime"
for rejected_bin in "$staged_root/tools" "$test_root/spaced tools"; do
  for runtime_name in curl herdr jq; do
    if [[ "$runtime_name" == herdr ]]; then
      ln -s /bin/true "$rejected_bin/$runtime_name"
    else
      link_host_tool "$runtime_name" "$rejected_bin"
    fi
    if HOME="$fake_home" PATH="$rejected_bin:$tool_bin:/usr/bin:/bin" \
      "$staged_root/agent/common/bin/install-agent-runtime"; then
      echo "installer accepted a forbidden runtime path: $rejected_bin/$runtime_name" >&2
      exit 1
    fi
    cmp "$runtime_bin/.dotfiles-agent-runtime" "$test_root/sidecar-before"
    rm "$rejected_bin/$runtime_name"
  done
done

echo 'agent runtime fresh install test: pass'
