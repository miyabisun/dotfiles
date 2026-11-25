#!/usr/bin/env bash
# Contract: bin/install wires Antigravity CLI (agy): the shared rules, the
# agy-only rules, the agent adapters and a machine-local MCP config seed.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
install_script="$repo_root/bin/install"
mcp_template="$repo_root/agent/antigravity/mcp_config.json"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

tool_bin="$test_root/tools"
mkdir -p "$tool_bin"
for tool_name in tmux curl sheldon; do
  printf '#!/bin/bash\nexit 0\n' >"$tool_bin/$tool_name"
  chmod 0755 "$tool_bin/$tool_name"
done
# agy is not on this PATH: bin/install must not need it.
test_path="$tool_bin:/usr/bin:/bin"
if PATH="$test_path" command -v agy >/dev/null 2>&1; then
  echo 'test setup: agy must not be on the test PATH' >&2
  exit 1
fi

run_install() {
  HOME="$1" PATH="$test_path" /bin/bash "$install_script" >/dev/null
}

assert_link() {
  local path="$1" expected="$repo_root/$2"
  if [ ! -L "$path" ] || [ "$(readlink "$path")" != "$expected" ]; then
    echo "expected $path -> $expected, got: $(readlink "$path" || echo none)" >&2
    exit 1
  fi
}

assert_seeded() {
  local live="$1/.gemini/config/mcp_config.json"
  if [ -L "$live" ] || ! cmp -s "$live" "$mcp_template"; then
    echo "expected $live to be a copy of the template" >&2
    exit 1
  fi
}

snapshot() {
  (cd "$1" && find . -printf '%p %y %l\n' | sort \
    && find . -type f -exec sha256sum {} + | sort)
}

# 1. Fresh home without ~/.gemini.
fresh="$test_root/fresh"
mkdir -p "$fresh"
run_install "$fresh"
assert_link "$fresh/.gemini/AGENTS.md" "agent/common/rules/GLOBAL.md"
assert_link "$fresh/.gemini/config/rules" "agent/antigravity/rules"
assert_link "$fresh/.gemini/config/agents" "agent/antigravity/agents"
assert_seeded "$fresh"
test ! -e "$fresh/.gemini/config/hooks.json"
test ! -e "$fresh/.gemini/antigravity-cli/settings.json"

# 4. A second run changes nothing and succeeds.
before="$(snapshot "$fresh")"
run_install "$fresh"
if [ "$before" != "$(snapshot "$fresh")" ]; then
  echo 'second bin/install changed the home' >&2
  exit 1
fi

# 2. agy's first run leaves an empty mcp_config.json: treat it as unseeded.
empty="$test_root/empty"
mkdir -p "$empty/.gemini/config"
: >"$empty/.gemini/config/mcp_config.json"
run_install "$empty"
assert_seeded "$empty"

# 3. A registered config is kept byte for byte.
kept="$test_root/kept"
mkdir -p "$kept/.gemini/config"
printf '{"mcpServers":{"local":{"serverUrl":"http://example.invalid/mcp"}}}' \
  >"$kept/.gemini/config/mcp_config.json"
kept_before="$(sha256sum <"$kept/.gemini/config/mcp_config.json")"
run_install "$kept"
test "$kept_before" = "$(sha256sum <"$kept/.gemini/config/mcp_config.json")"

echo 'antigravity agent install test: pass'
