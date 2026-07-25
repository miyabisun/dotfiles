#!/usr/bin/env bash
# assert する文字列は対象ファイルの literal なので、$ や ` を展開させない
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
deliver="$repo_root/agent/common/skills/deliver/SKILL.md"
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

assert_contains "$deliver" 'commit execution stays with the'
assert_contains "$deliver" 'without asking the user to repeat or reconfirm'
assert_contains "$deliver" 'Use the receipt'"'"'s proposed subject and body verbatim.'
assert_contains "$deliver" 'Execute exactly one new local `git commit` directly in the parent context.'
assert_contains "$deliver" 'Verify the result with `git status --short` and `git log -1 --stat`'
assert_contains "$deliver" 'It must not execute `git commit`.'
assert_contains "$deliver" 'Never push.'

assert_contains "$committer" 'このrole自身はcommitを実行しない。'
assert_contains "$committer" '`git commit`は実行しない。'
assert_contains "$committer" '"staged_files": ["path"]'
assert_contains "$committer" '"cached_diff_check": "pass"'
assert_contains "$committer" '"proposed_commit": {"subject": "type(scope): summary", "body": ""}'

assert_contains "$consolidate" '`deliver`'"'"'s parent-owned commit sequence exactly'
assert_contains "$consolidate" 'use the proposed message verbatim'
assert_contains "$consolidate" 'exactly one local Conventional Commit in the parent context'
assert_contains "$consolidate" 'Never push.'

echo "deliver commit ownership test: pass"
