#!/usr/bin/env bash
# Delivery skills may commit under GLOBAL git rules; ordinary chat may not.
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
global_rules="$repo_root/agent/common/rules/GLOBAL.md"
spike="$repo_root/agent/common/skills/spike/SKILL.md"
polish="$repo_root/agent/common/skills/polish/SKILL.md"
discuss="$repo_root/agent/common/skills/discuss/SKILL.md"

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
    printf 'forbidden phrase in %s: %s\n' "$file" "$text" >&2
    return 1
  fi
}

# Shared runtime rules: explicit commit request OR a delivery skill whose
# documented workflow includes committing ($spike / $polish / $deliver).
assert_contains "$global_rules" 'NEVER commit unless the user explicitly requests a commit or invokes a delivery'
assert_contains "$global_rules" 'skill whose documented workflow includes committing'
assert_contains "$global_rules" '`$spike`'
assert_contains "$global_rules" '`$polish`'
assert_contains "$global_rules" '`$deliver`'
assert_contains "$global_rules" 'inherits its commit step'
assert_absent "$global_rules" 'NEVER commit unless the user explicitly instructs you to'

# Named delivery skills actually document a commit step.
assert_contains "$spike" '**コミットする**'
assert_contains "$polish" '**コミットする**'

# Compatibility entry `$deliver` inherits the selected stage's commit authority.
deliver="$repo_root/agent/common/skills/deliver/SKILL.md"
assert_contains "$deliver" 'commit 授権を継承する'

# Non-delivery skills are not commit authorization by name alone.
assert_absent "$discuss" '**コミットする**'
assert_absent "$discuss" 'Execute exactly one new local `git commit`'

echo 'delivery commit authority contract test: pass'
