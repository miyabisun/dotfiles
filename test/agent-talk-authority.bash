#!/usr/bin/env bash
# agent-talk の実配線を測る: Codex / Grok の MCP 設定、Claude の permission、
# 退役 hook と dispatcher が復活していないこと、そして exec-policy の実判定。
# GLOBAL.md / SKILL.md / README.md の本文を grep する検査は持たない
# (markdown の字面 grep は測る意味が無い — GLOBAL.md「テスト」)。
# Contract literals intentionally keep backticks unexpanded.
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
claude_settings="$repo_root/agent/claude/settings.json"
codex_rules_template="$repo_root/agent/codex/rules/agent-talk.rules"
runtime_installer="$repo_root/agent/common/bin/install-agent-runtime"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
codex_rules="$test_root/agent-talk.rules"
notifier_command="$HOME/.local/bin/notify-file-permission.sh"
sed \
  -e "s|@NOTIFY_FILE_PERMISSION@|$notifier_command|g" \
  "$codex_rules_template" >"$codex_rules"

assert_contains() {
  local file="$1"
  local text="$2"
  grep -Fq -- "$text" "$file" || {
    printf 'missing contract in %s: %s\n' "$file" "$text" >&2
    return 1
  }
}

assert_absent() {
  local file="$1"
  local text="$2"
  if grep -Fq -- "$text" "$file"; then
    printf 'retired contract still present in %s: %s\n' "$file" "$text" >&2
    return 1
  fi
}

# GLOBAL.md と agent-talk SKILL.md の本文を固定していた assert 群 (tool 契約・
# 配達契約・権限境界・退役記述の不在) は削除した。markdown の字面 grep は
# 「文字列が在る」しか証明しない — GLOBAL.md「テスト」
codex_config="$repo_root/agent/codex/config.toml"
assert_contains "$codex_config" '[mcp_servers.agent_talk]'
# adapter は daemon と同じ release から動かす。PATH 解決や ~/.local/bin の
# 複製へ戻すと、update.timer が daemon だけ進めて version skew が復活する。
# Codex は MCP command を shell 非経由で spawn するため、sh -c が $HOME を
# 展開して exec で release 実体へ置き換わる (user-home 固定を持ち込まない)
assert_contains "$codex_config" 'command = "sh"'
assert_contains "$codex_config" 'exec \"$HOME/.local/share/agent-talk/current/agent-talk-mcp\"'
assert_absent "$codex_config" 'command = "agent-talk-mcp"'
assert_absent "$codex_config" '.local/bin/agent-talk-mcp'
# user-home 固定 path の検査は test/portable-paths.bash が tracked file 全体に
# 対して測るので、ここでは重複して持たない
assert_contains "$codex_config" 'HERDR_PANE_ID'
assert_contains "$codex_config" 'HERDR_SOCKET_PATH'
# tmux backend 撤去後、TMUX 系の forward は復活させない
assert_absent "$codex_config" '"TMUX"'

grok_config="$repo_root/agent/grok/config.toml"
assert_contains "$grok_config" '[mcp_servers.agent-talk]'
# Grok は [mcp_servers.*] の文字列を load-time に ${VAR} 展開する (docs 契約)
assert_contains "$grok_config" 'command = "${HOME}/.local/share/agent-talk/current/agent-talk-mcp"'
assert_absent "$grok_config" 'command = "agent-talk-mcp"'
assert_absent "$grok_config" '.local/bin/agent-talk-mcp'
# user-home 固定 path は portable-paths.bash が repo 全体で測る (同上)
assert_contains "$grok_config" 'hooks = false'
assert_contains "$grok_config" '[compat.claude]'
assert_contains "$grok_config" '[compat.cursor]'
assert_contains "$grok_config" '[mcp_servers.obscura]'
assert_contains "$grok_config" '[mcp_servers.semble]'
assert_contains "$grok_config" 'Bash(bw:*)'
# bin/install の grok 配線 (hooks / config.toml / AGENTS.md) を字面 grep して
# いた assert は削除した。grok-agent-install.bash が fake HOME で本物の
# bin/install を実行して symlink と config seed を実測し、
# install-relocatable.bash の managed_links 表も同じ link を検証している

# 権限境界 (peer と user の区別・秘密の非送信・standing authority) と lifecycle
# 記述を固定していた assert 群も削除した。同じ理由 — markdown の字面 grep は
# 規則が守られることを証明しない
for retired_hook in \
  "$repo_root/agent/claude/hooks/register-agent-talk.sh" \
  "$repo_root/agent/claude/hooks/unregister-agent-talk.sh" \
  "$repo_root/agent/claude/hooks/agent-talk-busy.sh" \
  "$repo_root/agent/cursor/hooks/agent-talk-busy.sh" \
  "$repo_root/agent/grok/hooks/register-agent-talk.sh" \
  "$repo_root/agent/grok/hooks/unregister-agent-talk.sh" \
  "$repo_root/agent/grok/hooks/agent-talk-busy.sh"; do
  if [[ -e "$retired_hook" ]]; then
    echo "retired lifecycle hook still exists: $retired_hook" >&2
    exit 1
  fi
done
assert_contains "$repo_root/agent/grok/hooks/stop-turn-end.sh" 'emit-turn-end.sh}" grok success'
assert_absent "$repo_root/agent/common/bin/emit-turn-end.sh" 'turn-end'
assert_absent "$repo_root/agent/common/bin/emit-turn-end.sh" 'current/agent-talk'

python3 - "$claude_settings" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    settings = json.load(handle)

allowed = settings["permissions"]["allow"]
expected = {"Bash(~/.local/bin/notify-file-permission.sh:*)"}
missing = expected.difference(allowed)
if missing:
    raise SystemExit(f"missing Claude permission entries: {sorted(missing)}")
retired = [entry for entry in allowed if "agent-talk-peer" in entry]
if retired:
    raise SystemExit(f"retired dispatcher still allowed: {retired}")
PY

test -f "$codex_rules"
assert_contains "$codex_rules_template" 'pattern = ["@NOTIFY_FILE_PERMISSION@"]'
if grep -Fq '@AGENT_TALK_PEER@' "$codex_rules_template"; then
  echo 'Codex rules must not carry a dispatcher placeholder' >&2
  exit 1
fi
if grep -Fq 'pattern = ["agent-talk"]' "$codex_rules"; then
  echo 'Codex rule must not allow every current and future agent-talk subcommand' >&2
  exit 1
fi

result="$(codex execpolicy check --rules "$codex_rules" \
  "$notifier_command" codex 619 2>/dev/null)"
python3 - "$result" <<'PY'
import json
import sys

if json.loads(sys.argv[1]).get("decision") != "allow":
    raise SystemExit("permission notifier must be allowed")
PY

# 撤去した dispatcher は絶対パスでも basename でも許可されてはならない
for unsafe_command in \
  "$HOME/.local/bin/agent-talk-peer send %24 --no-reply -- done" \
  'agent-talk-peer who' \
  'notify-file-permission.sh codex 619' \
  'agent-talk who' \
  'agent-talk read 619' \
  'agent-talk reply 619' \
  'agent-talk send %24 -- body' \
  'agent-talk send %24 --skill deliver -- body' \
  'agent-talk send %24 --from mobile -- body'; do
  read -r -a command_parts <<<"$unsafe_command"
  result="$(codex execpolicy check --rules "$codex_rules" \
    "${command_parts[@]}" 2>/dev/null)"
  python3 - "$unsafe_command" "$result" <<'PY'
import json
import sys

command, raw = sys.argv[1:]
if json.loads(raw).get("decision") == "allow":
    raise SystemExit(f"raw broker command must not be allowed: {command}")
PY
done

for denied_command in register gc update run; do
  result="$(codex execpolicy check --rules "$codex_rules" \
    agent-talk "$denied_command" placeholder 2>/dev/null)"
  python3 - "$denied_command" "$result" <<'PY'
import json
import sys

command_name, raw = sys.argv[1:]
decision = json.loads(raw).get("decision")
if decision == "allow":
    raise SystemExit(f"agent-talk {command_name} must not be broadly allowed")
PY
done

result="$(codex execpolicy check --rules "$codex_rules" \
  tmux send-keys -t %24 unsafe 2>/dev/null)"
python3 - "$result" <<'PY'
import json
import sys

if json.loads(sys.argv[1]).get("decision") == "allow":
    raise SystemExit("raw tmux send-keys must not be broadly allowed")
PY

result="$(codex execpolicy check --rules "$codex_rules" \
  "$notifier_command" codex 619 2>/dev/null)"
python3 - "$result" <<'PY'
import json
import sys

if json.loads(sys.argv[1])["decision"] != "allow":
    raise SystemExit("permission notifier must be allowed")
PY

# Shell wrappers and pipelines stay outside the narrow allow rules. Peer
# conversation runs in-process over MCP, so no shell form is needed at all.
for wrapped_command in \
  "$notifier_command codex 619" \
  "$notifier_command codex 619 | grep settings"; do
  result="$(codex execpolicy check --rules "$codex_rules" \
    bash -lc "$wrapped_command" 2>/dev/null)"
  python3 - "$result" <<'PY'
import json
import sys

if json.loads(sys.argv[1]).get("decision") == "allow":
    raise SystemExit("shell-wrapped agent-talk must stay outside the narrow allow")
PY
done

# bin/install が install-agent-runtime を呼ぶ字面 grep は削除した。
# agent-runtime-install.bash が hash tool 抜きの PATH で本物の bin/install を
# 実行し、installer 失敗が非ゼロで伝播することを実測している

# agent/README.md の記述を固定していた assert 群は削除した (markdown の字面 grep)
assert_contains "$runtime_installer" '@NOTIFY_FILE_PERMISSION@'
assert_contains "$runtime_installer" 'agent/common/bin/notify-file-permission.sh'
assert_contains "$runtime_installer" 'if [[ -L "$RUNTIME_TARGET" ]]'
# 撤去した dispatcher は「置かない」だけでなく「既存を消す」こと
assert_contains "$runtime_installer" 'rm -f "$RUNTIME_BIN/agent-talk-peer"'
if grep -Fq 'agent/common/bin/agent-talk-peer' "$runtime_installer"; then
  echo 'installer must not copy the retired dispatcher' >&2
  exit 1
fi

if grep -Fq 'link "agent/codex/rules/agent-talk.rules"' "$runtime_installer"; then
  echo 'runtime-writable exec-policy must not symlink back into the repository' >&2
  exit 1
fi

echo 'agent-talk authority contract test: pass'
