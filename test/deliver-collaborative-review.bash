#!/usr/bin/env bash
# spike / polish keep independent planning; consolidate does not invent a
# shipping-gate security stage.
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
spike="$repo_root/agent/common/skills/spike/SKILL.md"
polish="$repo_root/agent/common/skills/polish/SKILL.md"
consolidate="$repo_root/agent/common/skills/consolidate/SKILL.md"
sec="$repo_root/agent/common/agents/sec.md"
committer="$repo_root/agent/common/agents/committer.md"

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

for skill in "$spike" "$polish"; do
  assert_contains "$skill" 'pane の runtime が担う。'
  assert_contains "$skill" 'runtime へ投げ直すことはできない'
  assert_contains "$skill" 'レビュワーは**同期召喚する `codex exec` の1プロセス**である'
  assert_absent "$skill" 'レビュワーは**発火 pane と同じ space の `review` タブ・常に1名**'
  assert_absent "$skill" 'review タブは原則として実務担当ではない'
  assert_absent "$skill" '担当 grok → レビュワーは claude と codex の**両方**'
  assert_contains "$skill" '**最初の brief に自分の案を入れない。**'
  assert_contains "$skill" '**同じターンで自分の案を起草する。**'
  assert_absent "$skill" 'grok is the default worker'
done

assert_contains "$sec" '# severity'
assert_contains "$sec" 'impact (何が失われるか) と exploitability'
assert_contains "$sec" '- Critical:'
assert_contains "$sec" '- High:'
assert_contains "$sec" '- Medium:'
assert_contains "$sec" '- Low:'
assert_contains "$sec" 'severityの引き下げやdismissには'

assert_contains "$committer" 'このrole自身はcommitを実行しない。'
assert_absent "$consolidate" 'Use `sec` when consolidation crosses trust'

echo "deliver collaborative review contract test: pass"
