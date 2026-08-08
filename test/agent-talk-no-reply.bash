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
# no_reply / 返信不要 is peer-channel only; does not end user-authorized local work
assert_contains 'control only whether'
assert_contains 'you must send a peer reply'
assert_contains 'do **not** end an in-flight'
assert_contains 'user-authorized local workflow'
assert_contains 'continue that workflow'
assert_contains 'same turn'
assert_contains 'That restraint is about the peer channel only'

# 待機契約 (中央): 依存 blocked + 有用な独立作業なし → turn 終了は MUST。
# sleep/wait loop/list_peers polling での turn 保持禁止、reply doorbell は
# 同一 delivery の再開 trigger、sent/queued は受理済みで再送禁止、yield 前の
# 最終出力は未完了を明示し完了報告と誤認させない
assert_contains '## Waiting for a reply'
assert_contains 'no other useful independent work remains'
assert_contains 'mandatory, not optional'
assert_contains 'Never hold the turn with sleep, wait loops, or `list_peers` polling'
assert_contains 'resume trigger of the'
assert_contains 'never resend'
assert_contains '返信待ちで一旦 turn を終了する。doorbell でこの delivery を自動再開する'
assert_contains 'reads as a completion report is forbidden'

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
