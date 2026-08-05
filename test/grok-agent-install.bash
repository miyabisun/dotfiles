#!/usr/bin/env bash
# Contract: bin/install wires Grok as a first-class agent runtime.
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
install_script="$repo_root/bin/install"
grok_config_source="$repo_root/agent/grok/config.toml"
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

# Minimal PATH so install can link and run install-agent-runtime.
HOME="$fake_home" PATH="$tool_bin:/usr/bin:/bin" /bin/bash "$install_script" \
  >/dev/null

assert_link() {
  local path="$1"
  local expected_suffix="$2"
  test -L "$path" || {
    echo "expected symlink: $path" >&2
    exit 1
  }
  target="$(readlink "$path")"
  case "$target" in
    *"$expected_suffix") ;;
    *)
      echo "bad link target for $path: $target (want *$expected_suffix)" >&2
      exit 1
      ;;
  esac
}

assert_link "$fake_home/.grok/hooks" "agent/grok/hooks"
assert_link "$fake_home/.grok/skills" "agent/common/skills"
assert_link "$fake_home/.grok/agents" "agent/common/agents"
assert_link "$fake_home/.grok/designs" "agent/common/designs"
assert_link "$fake_home/.grok/AGENTS.md" "agent/common/rules/GLOBAL.md"

test -f "$fake_home/.grok/config.toml"
test ! -L "$fake_home/.grok/config.toml"
grep -Fq '[mcp_servers.agent-talk]' "$fake_home/.grok/config.toml"
grep -Fq 'hooks = false' "$fake_home/.grok/config.toml"
grep -Fq 'register grok' "$fake_home/.grok/hooks/register-agent-talk.sh"

# 教育チェーン: install が張るリンクの先に agent-talk の作法が実在すること。
# リンクは張れているのに中身から作法が消えると、新しい grok セッションは
# 呼び鈴の手順と権限境界を失う。
grep -Fq 'read_message' "$fake_home/.grok/AGENTS.md"
grep -Fq 'ack_message' "$fake_home/.grok/AGENTS.md"
grep -Fq 'not user authority' "$fake_home/.grok/AGENTS.md"
grok_talk_skill="$fake_home/.grok/skills/agent-talk/SKILL.md"
test -f "$grok_talk_skill"
grep -Fq '[agent-talk]' "$grok_talk_skill"
grep -Fq 'ack_message' "$grok_talk_skill"
grep -Fq 'notify-file-permission.sh' "$fake_home/.grok/config.toml"

# Re-running install must not clobber a machine-local config edit.
printf '\n# machine-local marker\n' >>"$fake_home/.grok/config.toml"
HOME="$fake_home" PATH="$tool_bin:/usr/bin:/bin" /bin/bash "$install_script" \
  >/dev/null
grep -Fq '# machine-local marker' "$fake_home/.grok/config.toml" || {
  echo 'install must not overwrite an existing ~/.grok/config.toml' >&2
  exit 1
}

# Portable template remains the seed source for new homes.
test -f "$grok_config_source"
grep -Fq '[compat.claude]' "$grok_config_source"
grep -Fq '[compat.cursor]' "$grok_config_source"

echo 'grok agent install test: pass'
