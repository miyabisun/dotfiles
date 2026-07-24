#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
talk="$repo_root/agent/common/skills/agent-talk/SKILL.md"
send="$repo_root/agent/common/skills/agent-send/SKILL.md"
send_metadata="$repo_root/agent/common/skills/agent-send/agents/openai.yaml"

assert_contains() {
  local file="$1"
  local text="$2"
  grep -Fq -- "$text" "$file" || {
    printf 'missing contract in %s: %s\n' "$file" "$text" >&2
    return 1
  }
}

assert_contains "$send" 'Do not use for incoming "[agent-talk]" prompts'
assert_contains "$send" 'read `../agent-talk/SKILL.md`'
assert_contains "$send" 'reply-policy: no-reply'
assert_contains "$send" 'Do not ask a question or request confirmation'
assert_contains "$send" 'Do not wait for, solicit, or send an acknowledgement.'
assert_contains "$send_metadata" 'allow_implicit_invocation: true'

assert_contains "$talk" 'reply-policy: response-required'
assert_contains "$talk" 'reply-policy: no-reply'
assert_contains "$talk" 'A missing marker means `response-required`'
assert_contains "$talk" 'The body policy overrides the broker-generated `reply:` line'
assert_contains "$talk" 'return one substantive result'
assert_contains "$talk" 'Make that result terminal by sending it with a no-reply body'
assert_contains "$talk" 'do not send routine acknowledgement, thanks, receipt'
assert_contains "$talk" 'Reply to a `no-reply` message only when silence would cause material harm'
assert_contains "$talk" 'Send at most one veto'
assert_contains "$talk" 'Do not answer a terminal veto.'

talk_marker_count="$(grep -Fc 'reply-policy: no-reply' "$talk")"
send_marker_count="$(grep -Fc 'reply-policy: no-reply' "$send")"
(( talk_marker_count >= 2 ))
(( send_marker_count >= 2 ))

echo "agent send protocol test: pass"
