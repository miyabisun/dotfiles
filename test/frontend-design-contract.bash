#!/usr/bin/env bash
# Frontend design dispatch and authority contract shared by every delivery stage.
# Assertions intentionally use single-quoted Markdown literals with backticks.
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
frontend="$repo_root/agent/common/skills/frontend-design/SKILL.md"
designer="$repo_root/agent/common/agents/designer.md"
readme="$repo_root/agent/README.md"
sumi="$repo_root/agent/common/designs/sumi/DESIGN.md"
kinari="$repo_root/agent/common/designs/kinari/DESIGN.md"

assert_contains() {
  local file="$1"
  local text="$2"
  grep -Fq -- "$text" "$file" || {
    printf 'missing frontend contract in %s: %s\n' "$file" "$text" >&2
    return 1
  }
}

assert_absent() {
  local file="$1"
  local text="$2"
  if grep -Fq -- "$text" "$file"; then
    printf 'obsolete frontend contract in %s: %s\n' "$file" "$text" >&2
    return 1
  fi
}

# Every delivery stage must deterministically load the implementation skill when
# rendered UI or interaction may change, defaulting toward use when uncertain.
for stage in spike polish harden; do
  skill="$repo_root/agent/common/skills/$stage/SKILL.md"
  assert_contains "$skill" 'rendered UI or user interaction may change'
  assert_contains "$skill" '`frontend-design`'
  assert_contains "$skill" '迷ったら適用する'
  assert_contains "$skill" '実ブラウザ'
done

# The implementation skill owns the detailed UI-surface boundary and resolves
# Project authority before offering generic aesthetic guidance.
assert_contains "$frontend" '## UI surface and authority'
assert_contains "$frontend" 'Project root `DESIGN.md`'
assert_contains "$frontend" '`docs/DESIGN.md` is a legacy'
assert_contains "$frontend" 'fallback; read it for this delivery'
assert_contains "$frontend" 'Do not merge both files implicitly'
assert_contains "$frontend" 'bootstrap input'
assert_contains "$frontend" 'Project design and an applicable designer brief override'
assert_contains "$frontend" 'Invoke `designer`'
assert_contains "$frontend" 'rendered DOM'
assert_contains "$frontend" 'ARIA and live regions'

boundary_files="$(grep -RlF --include='SKILL.md' 'rendered DOM' \
  "$repo_root/agent/common/skills" || true)"
[[ "$boundary_files" == "$frontend" ]] || {
  printf 'UI surface boundary must have one owner, found:\n%s\n' \
    "$boundary_files" >&2
  exit 1
}

# Designer and project docs follow copy-then-own: root is canonical, docs is
# legacy-only, and shared templates do not remain an external authority.
assert_contains "$designer" 'ルートの `DESIGN.md` を正'
assert_contains "$designer" '`docs/DESIGN.md` は legacy fallback'
assert_contains "$designer" '暗黙にmergeしない'
assert_contains "$designer" 'bootstrap input'

assert_contains "$readme" 'root `DESIGN.md`'
assert_contains "$readme" 'bootstrap inputs'
assert_absent "$readme" 'Projects only keep a thin'

for template in "$sumi" "$kinari"; do
  assert_contains "$template" 'project root `DESIGN.md`'
  assert_contains "$template" 'bootstrap'
  assert_absent "$template" "project's docs/DESIGN.md"
done

echo 'frontend design contract test: pass'
