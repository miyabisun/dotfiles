#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
installer="$repo_root/agent/common/bin/install-agent-runtime"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
fake_home="$test_root/home"
tool_bin="$test_root/tools"
mkdir -p "$fake_home" "$tool_bin"

for tool_name in tmux curl; do
  cat >"$tool_bin/$tool_name" <<'TOOL'
#!/bin/bash
exit 0
TOOL
  chmod 0755 "$tool_bin/$tool_name"
done

HOME="$fake_home" PATH="$tool_bin:/usr/bin:/bin" "$installer"
runtime_bin="$fake_home/.local/bin"
rules_file="$fake_home/.codex/rules/agent-talk.rules"

for runtime_name in agent-talk-peer emit-turn-end.sh notify-file-permission.sh; do
  test -f "$runtime_bin/$runtime_name"
  test -x "$runtime_bin/$runtime_name"
  test ! -L "$runtime_bin/$runtime_name"
done
test -f "$runtime_bin/.dotfiles-agent-runtime"
test ! -L "$runtime_bin/.dotfiles-agent-runtime"
test -f "$rules_file"
test ! -L "$rules_file"
grep -Fq "$runtime_bin/agent-talk-peer" "$rules_file"
grep -Fq "$runtime_bin/notify-file-permission.sh" "$rules_file"
if grep -Fq '@AGENT_TALK_PEER@' "$rules_file"; then
  echo 'installed rule still contains a dispatcher placeholder' >&2
  exit 1
fi

# Fresh install succeeds without the later install-apps broker. Until that
# regular broker arrives, the dispatcher fails closed.
if "$runtime_bin/agent-talk-peer" who 2>/dev/null; then
  echo 'dispatcher must fail closed before agent-talk is installed' >&2
  exit 1
fi

cat >"$runtime_bin/agent-talk" <<'AGENT_TALK'
#!/bin/bash
printf '%s\n' "$*" >>"$FRESH_INSTALL_AGENT_TALK_LOG"
AGENT_TALK
chmod 0755 "$runtime_bin/agent-talk"
export FRESH_INSTALL_AGENT_TALK_LOG="$test_root/agent-talk.log"
: >"$FRESH_INSTALL_AGENT_TALK_LOG"
"$runtime_bin/agent-talk-peer" who
grep -Fx 'who' "$FRESH_INSTALL_AGENT_TALK_LOG" >/dev/null

result="$(codex execpolicy check --rules "$rules_file" \
  "$runtime_bin/agent-talk-peer" who 2>/dev/null)"
python3 - "$result" <<'PY'
import json
import sys

if json.loads(sys.argv[1]).get("decision") != "allow":
    raise SystemExit("installed absolute dispatcher rule must allow who")
PY

result="$(codex execpolicy check --rules "$rules_file" \
  agent-talk-peer who 2>/dev/null)"
python3 - "$result" <<'PY'
import json
import sys

if json.loads(sys.argv[1]).get("decision") == "allow":
    raise SystemExit("basename dispatcher must stay outside the absolute rule")
PY

# bin/install must propagate a runtime-installer failure instead of continuing
# with a stale policy. This PATH provides bootstrap tools but deliberately no
# tmux, so the helper exits nonzero at its first runtime dependency check.
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

# curl is optional because it is only a MOCA sink. A host with tmux and a hash
# tool but no curl must still receive a working dispatcher and rules.
no_curl_bin="$test_root/no-curl-tools"
no_curl_home="$test_root/no-curl-home"
mkdir -p "$no_curl_bin" "$no_curl_home"
for tool_name in dirname mkdir cp chmod unlink mktemp sed mv rm sha256sum stat; do
  ln -s "/usr/bin/$tool_name" "$no_curl_bin/$tool_name"
done
ln -s "$tool_bin/tmux" "$no_curl_bin/tmux"
HOME="$no_curl_home" PATH="$no_curl_bin" "$installer"
grep -Fx 'CURL_BIN=' \
  "$no_curl_home/.local/bin/.dotfiles-agent-runtime" >/dev/null
test -x "$no_curl_home/.local/bin/agent-talk-peer"

echo 'agent runtime fresh install test: pass'
