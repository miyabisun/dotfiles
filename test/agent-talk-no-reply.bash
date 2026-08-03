#!/usr/bin/env bash
# assert する文字列は対象ファイルの literal なので、$ や ` を展開させない
# shellcheck disable=SC2016,SC2088
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
talk="$repo_root/agent/common/skills/agent-talk/SKILL.md"

assert_contains() {
  local text="$1"
  grep -Fq -- "$text" "$talk" || {
    printf 'missing contract in %s: %s\n' "$talk" "$text" >&2
    return 1
  }
}

assert_contains 'When the outbound message itself should end the exchange, set `no_reply`.'
assert_contains 'The daemon makes the one-way intent authoritative'
assert_contains 'Make that result terminal with `no_reply`'
assert_contains 'do not send routine acknowledgement, thanks, receipt'
assert_contains 'Reply to a no-reply brief only when silence would cause material harm'
assert_contains 'Send at most one veto'
assert_contains 'Do not answer a terminal veto.'

if grep -Fq 'reply-policy:' "$talk"; then
  echo 'body reply-policy markers must not remain after CLI migration' >&2
  exit 1
fi
if grep -Fq 'agent-send' "$talk"; then
  echo 'agent-talk must not depend on the retired agent-send skill' >&2
  exit 1
fi
test ! -e "$repo_root/agent/common/skills/agent-send"

echo "agent-talk no-reply contract test: pass"
