#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
installer="$repo_root/agent/common/bin/install-agent-runtime"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
fake_home="$test_root/home"
tool_bin="$test_root/tools"
mkdir -p "$fake_home" "$tool_bin"

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
  "$runtime_bin/notify-file-permission.sh" codex 619 2>/dev/null)"
python3 - "$result" <<'PY'
import json
import sys

if json.loads(sys.argv[1]).get("decision") != "allow":
    raise SystemExit("installed absolute notifier rule must allow the call")
PY

result="$(codex execpolicy check --rules "$rules_file" \
  notify-file-permission.sh codex 619 2>/dev/null)"
python3 - "$result" <<'PY'
import json
import sys

if json.loads(sys.argv[1]).get("decision") == "allow":
    raise SystemExit("basename notifier must stay outside the absolute rule")
PY

# bin/install must propagate a runtime-installer failure instead of continuing
# with a stale policy. This PATH provides bootstrap tools but deliberately no
# hash tool, so the helper exits nonzero at its runtime dependency check.
bootstrap_bin="$test_root/bootstrap-tools"
bootstrap_home="$test_root/bootstrap-home"
mkdir -p "$bootstrap_bin" "$bootstrap_home"
for tool_name in dirname ln mkdir cp readlink unlink mv; do
  ln -s "/usr/bin/$tool_name" "$bootstrap_bin/$tool_name"
done
if HOME="$bootstrap_home" PATH="$bootstrap_bin" \
  /bin/bash "$repo_root/bin/install" >/dev/null 2>&1; then
  echo 'bin/install must propagate install-agent-runtime failure' >&2
  exit 1
fi

# curl is optional because it is only a MOCA sink. A host with a hash tool but
# no curl — and no tmux at all — must still receive a working runtime.
no_curl_bin="$test_root/no-curl-tools"
no_curl_home="$test_root/no-curl-home"
mkdir -p "$no_curl_bin" "$no_curl_home"
for tool_name in dirname mkdir cp chmod unlink mktemp sed mv rm sha256sum stat; do
  ln -s "/usr/bin/$tool_name" "$no_curl_bin/$tool_name"
done
HOME="$no_curl_home" PATH="$no_curl_bin" "$installer"
grep -Fx 'CURL_BIN=' \
  "$no_curl_home/.local/bin/.dotfiles-agent-runtime" >/dev/null
test -x "$no_curl_home/.local/bin/notify-file-permission.sh"

# 既に配置済みの旧 dispatcher は、再インストールで撤去されなければならない。
# 残すと PATH 上で生き続け、ack できない経路が復活する
stale_home="$test_root/stale-home"
mkdir -p "$stale_home/.local/bin"
printf '#!/bin/sh\nexit 0\n' >"$stale_home/.local/bin/agent-talk-peer"
chmod 0755 "$stale_home/.local/bin/agent-talk-peer"
HOME="$stale_home" PATH="$tool_bin:/usr/bin:/bin" "$installer"
if test -e "$stale_home/.local/bin/agent-talk-peer"; then
  echo 'installer must remove a previously installed peer dispatcher' >&2
  exit 1
fi

echo 'agent runtime fresh install test: pass'
