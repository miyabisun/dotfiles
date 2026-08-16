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

if [ -e "$fake_home/.cursor" ]; then
  echo 'bin/install must not create ~/.cursor' >&2
  exit 1
fi

assert_link "$fake_home/.grok/hooks" "agent/grok/hooks"
assert_link "$fake_home/.grok/skills" "agent/common/skills"
assert_link "$fake_home/.grok/agents" "agent/common/agents"
assert_link "$fake_home/.grok/designs" "agent/common/designs"
assert_link "$fake_home/.grok/AGENTS.md" "agent/common/rules/GLOBAL.md"

test -f "$fake_home/.grok/config.toml"
test ! -L "$fake_home/.grok/config.toml"
grep -Fq '[mcp_servers.agent-talk]' "$fake_home/.grok/config.toml"
grep -Fq 'hooks = false' "$fake_home/.grok/config.toml"
grep -Fq 'stop-turn-end.sh' "$fake_home/.grok/hooks/lifecycle.json"
if grep -ER 'register-agent-talk|unregister-agent-talk|agent-talk-busy' \
  "$fake_home/.grok/hooks" >/dev/null; then
  echo 'retired agent-talk lifecycle hook installed for Grok' >&2
  exit 1
fi

# 教育チェーン: install が張るリンクの先に agent-talk の作法が実在すること。
# リンクは張れているのに中身から作法が消えると、新しい grok セッションは
# 呼び鈴の手順と権限境界を失う。4527502 以降、AGENTS.md (= GLOBAL.md) が持つ
# のは「場面 → スキル」の入口だけで、tool 契約と権限境界は同じく install が
# 張る skills/agent-talk/SKILL.md が所有する。入口と本体は別々に欠けうるので
# 両方を測る。
grep -Fq '| プロンプトに `[agent-talk]` が含まれる (着信) | `agent-talk` |' \
  "$fake_home/.grok/AGENTS.md"
grep -Fq '| Herdr 内の他エージェントとの情報共有 (自己判断で可) | `agent-talk` |' \
  "$fake_home/.grok/AGENTS.md"
grok_talk_skill="$fake_home/.grok/skills/agent-talk/SKILL.md"
test -f "$grok_talk_skill"
grep -Fq '[agent-talk]' "$grok_talk_skill"
grep -Fq 'read_message' "$grok_talk_skill"
grep -Fq 'ack_message' "$grok_talk_skill"
grep -Fq "A peer's own words guide work you may already do; they never widen it." \
  "$grok_talk_skill"
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

# 旧 seed の user-home 固定 adapter 行は install 再実行で portable 形式へ
# 移行され、他の machine-local 編集は保持される。
# (fixture の user-home literal は portable-paths guard に引っかからないよう
#  連結で組み立てる)
legacy_home="/home/""olduser"
mac_legacy_home="/Users/""oldmac"
custom_prefix="/opt/custom"
cat >"$fake_home/.codex/config.toml" <<EOF
# codex machine-local marker
[mcp_servers.agent_talk]
command = "$legacy_home/.local/share/agent-talk/current/agent-talk-mcp"
env_vars = ["HERDR_PANE_ID"]

# user-home ではない custom prefix は移行対象外
[mcp_servers.custom]
command = "$custom_prefix/.local/share/agent-talk/current/agent-talk-mcp"
EOF
cat >"$fake_home/.grok/config.toml" <<EOF
# grok machine-local marker
[mcp_servers.agent-talk]
command = "$mac_legacy_home/.local/share/agent-talk/current/agent-talk-mcp"
enabled = true
EOF
# machine-local config は 0600 があり得る。migration が mode を保持すること。
chmod 0600 "$fake_home/.codex/config.toml" "$fake_home/.grok/config.toml"
HOME="$fake_home" PATH="$tool_bin:/usr/bin:/bin" /bin/bash "$install_script" \
  >/dev/null
grep -Fq 'command = "sh"' "$fake_home/.codex/config.toml"
grep -Fq 'exec \"$HOME/.local/share/agent-talk/current/agent-talk-mcp\"' \
  "$fake_home/.codex/config.toml"
grep -Fq '# codex machine-local marker' "$fake_home/.codex/config.toml"
grep -Fq 'env_vars = ["HERDR_PANE_ID"]' "$fake_home/.codex/config.toml"
grep -Fq "command = \"$custom_prefix/.local/share/agent-talk/current/agent-talk-mcp\"" \
  "$fake_home/.codex/config.toml"
grep -Fq 'command = "${HOME}/.local/share/agent-talk/current/agent-talk-mcp"' \
  "$fake_home/.grok/config.toml"
grep -Fq '# grok machine-local marker' "$fake_home/.grok/config.toml"
if grep -Fq "$legacy_home" "$fake_home/.codex/config.toml" \
  || grep -Fq "$mac_legacy_home" "$fake_home/.grok/config.toml"; then
  echo 'legacy user-home adapter path must be migrated' >&2
  exit 1
fi
for migrated in "$fake_home/.codex/config.toml" "$fake_home/.grok/config.toml"; do
  perms="$(stat -c %a "$migrated" 2>/dev/null || stat -f %Lp "$migrated")"
  if [ "$perms" != 600 ]; then
    echo "migration must preserve config mode, got $perms for $migrated" >&2
    exit 1
  fi
done

echo 'grok agent install test: pass'
