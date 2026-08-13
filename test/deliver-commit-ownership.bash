#!/usr/bin/env bash
# consolidate owns one local commit; committer never runs git commit.
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
committer="$repo_root/agent/common/agents/committer.md"
consolidate="$repo_root/agent/common/skills/consolidate/SKILL.md"

assert_contains() {
  local file="$1"
  local text="$2"
  grep -Fq -- "$text" "$file" || {
    printf 'missing contract in %s: %s\n' "$file" "$text" >&2
    return 1
  }
}

assert_contains "$committer" 'このrole自身はcommitを実行しない。'
assert_contains "$committer" '`git commit`は実行しない。'
assert_contains "$committer" '"staged_files": ["path"]'
assert_contains "$committer" '"cached_diff_check": "pass"'
assert_contains "$committer" '"proposed_commit": {"subject": "type(scope): summary", "body": ""}'

assert_contains "$consolidate" 'parent-owned commit sequence'
assert_contains "$consolidate" 'use the proposed message verbatim'
assert_contains "$consolidate" 'exactly one local Conventional Commit in the parent context'
assert_contains "$consolidate" 'Never push.'

echo "deliver commit ownership test: pass"
