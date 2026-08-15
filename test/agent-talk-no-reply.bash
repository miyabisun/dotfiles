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

assert_absent() {
  local text="$1"
  if grep -Fq -- "$text" "$talk"; then
    printf 'retired contract still present in %s: %s\n' "$talk" "$text" >&2
    return 1
  fi
}

# 通常返信と一方向送信の使い分けは残る
assert_contains 'When the outbound message itself should end the exchange, set `no_reply`.'
assert_contains 'The daemon makes the one-way intent authoritative'
assert_contains 'Make that result terminal with `no_reply`'
assert_contains 'do not send routine acknowledgement, thanks, receipt'
assert_contains 'That restraint is about the peer channel only'

# agent-talk は簡易的な通話機能。no_reply へ delivery 再開の意味を戻さない
assert_absent 'user-authorized local workflow'
assert_absent '`$polish` / `$spike` delivery'
assert_absent 'permission to mark the delivery complete'
# Material veto という返信例外の儀式も持たない
assert_absent 'Reply to a no-reply brief only when silence would cause material harm'
assert_absent 'Material veto'
assert_absent 'Send at most one veto'
assert_absent 'terminal material veto'

# 待機は軽い規則だけ: turn を保持しない (sleep/wait loop/list_peers polling
# 禁止)、呼び鈴で会話を再開する、sent/queued は受理済みで再送しない。
# delivery 再開契約と marker 義務は持ち込まない
assert_contains '## Waiting for a reply'
assert_contains 'Never hold the turn with sleep, wait loops, or `list_peers` polling'
assert_contains "doorbell resumes the conversation"
assert_contains 'never resend'
assert_absent 'delivery:waiting'
assert_absent 'resume trigger of the'
assert_absent 'reads as a completion report is forbidden'

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
