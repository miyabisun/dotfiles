#!/usr/bin/env bash
# assert する文字列は対象ファイルの literal なので、$ や ` を展開させない
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
deliver="$repo_root/agent/common/skills/harden/SKILL.md"
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

# 計画フェーズ: 独立提案を先に作り、その後で突合する
assert_contains "$deliver" '### 1a. Co-author the contract with the counterpart'
# 担当→レビュワー行列と authority 境界 (grok 既定・両レビュワー・委譲不可)
assert_contains "$deliver" 'grok is the default worker'
assert_contains "$deliver" 'the reviewer set is Claude Code and Codex (both)'
assert_contains "$deliver" 'cannot delegate implementation to grok on its own'
assert_contains "$deliver" 'never silently reassign the'
assert_contains "$deliver" 'applies to each member of'
assert_contains "$deliver" '"worker": {"runtime": "claude|codex|grok"'
assert_contains "$deliver" '"reviewers": [{"runtime": "...", "independence"'
assert_contains "$deliver" 'judge and record it per'
assert_contains "$deliver" 'Do not include a proposed contract in this first brief.'
assert_contains "$deliver" 'Draft the local proposal
in the same turn that sends the brief'
assert_contains "$deliver" 'structurally enforced rather than a matter of'
assert_contains "$deliver" 'one check that asks two questions, not one'
assert_contains "$deliver" 'does the integrated contract contain a defect that neither'
assert_contains "$deliver" '{"aligned": true, "material_mismatches": [], "corrections": [], "summary": "..."}'
assert_contains "$deliver" 'Never resolve a disagreement by runtime precedence'
assert_contains "$deliver" 'one
independent-proposal exchange and one reconciliation exchange'
assert_absent "$deliver" '### 1a. Cross-check the plan with the counterpart'
assert_absent "$deliver" 'planning_review'

# security は両側で実施し、和集合を閉じる
assert_contains "$deliver" 'Treat every security-sensitive change as high risk.'
assert_contains "$deliver" "keep the implementation runtime's independent \`sec\` gate"
assert_contains "$deliver" 'add an independent security review from every reviewer pane'
assert_contains "$deliver" 'three receipts: local + Claude + Codex'
assert_contains "$deliver" 'their findings form one blocking union'
assert_contains "$deliver" '### 5a. Freeze and run the independent security reviews'
assert_absent "$deliver" 'run two independent security reviews'
assert_contains "$deliver" 'Treat the results as a union, not a vote.'
assert_absent "$deliver" 'Treat the two results'
assert_contains "$deliver" 'Every receipt is an equal blocker.'
assert_absent "$deliver" 'Both receipts are equal blockers.'
assert_contains "$deliver" "Do not reveal any reviewer's initial findings to"
assert_contains "$deliver" 'before every initial receipt exists'
assert_contains "$deliver" 'Do not impose a round cap on this gate.'

# security gate は formatter の後 (凍結した bytes と commit する bytes を一致させる)
assert_contains "$deliver" 'The security gate runs after `formatter`, not before it'
assert_contains "$deliver" 'the reviewed bytes are not
the committed bytes'
assert_contains "$deliver" 'security-sensitive:   implement → full checks → reviewer implementation'
assert_contains "$deliver" 'local sec + every reviewer sec independently'
assert_contains "$deliver" 'staged_snapshot_matches_security_manifest'
# risk table の high 行も新しい順序と矛盾しないこと
assert_absent "$deliver" 'independent `rev` + `sec` → `formatter`'
assert_contains "$deliver" '`formatter` → security gate when security-sensitive → commit'
assert_contains "$deliver" 'AND for security-sensitive work, every required security receipt approves the current frozen snapshot'

# 凍結 manifest
assert_contains "$deliver" 'a content hash per reviewed file'
assert_contains "$deliver" 'Do not mutate the reviewed files while any security review is in flight.'
assert_contains "$deliver" 'Give the local sec role and every reviewer pane'
assert_contains "$deliver" '"runtime": "claude|codex|grok|null"'
assert_contains "$deliver" '"review_snapshot"'
assert_contains "$deliver" '"security_review"'

# hard rules
assert_contains "$deliver" 'never treat one security reviewer as a substitute'
assert_contains "$deliver" 'Never average, outvote, or silently drop a security finding'
assert_contains "$deliver" "Never count the implementing agent's self-review as an independent security"
assert_contains "$deliver" 'Any mutation after the security freeze invalidates every receipt'
assert_contains "$deliver" 'never read the
  counterpart proposal before drafting the local one'

# sec role: severity の共有基準
assert_contains "$sec" '# severity'
assert_contains "$sec" 'impact (何が失われるか) と exploitability'
assert_contains "$sec" '- Critical:'
assert_contains "$sec" '- High:'
assert_contains "$sec" '- Medium:'
assert_contains "$sec" '- Low:'
assert_contains "$sec" 'severityの引き下げやdismissには'

# committer: 承認された snapshot と staged bytes の一致を検証する
assert_contains "$committer" 'security manifestがある場合は、stage後のcontent hashをmanifestと照合する'
assert_contains "$committer" '"staged_snapshot_matches_security_manifest": true,'
assert_contains "$committer" '片方の承認をもう片方の代用として扱わない。'

# consolidate は自前で security gate を持たず deliver の位置に従う
assert_contains "$consolidate" "Run \`harden\`'s two independent security reviews at the point"
assert_absent "$consolidate" 'Use `sec` when consolidation crosses trust'

echo "deliver collaborative review contract test: pass"
