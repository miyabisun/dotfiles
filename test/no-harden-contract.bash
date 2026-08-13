#!/usr/bin/env bash
# Household delivery has no shipping-gate stage. Iteration is spike / polish.
# Work stops only for harm to another company or likely crime.
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
global_rules="$repo_root/agent/common/rules/GLOBAL.md"
cursor_global="$repo_root/agent/cursor/rules/global.mdc"
skills_dir="$repo_root/agent/common/skills"
deliver="$skills_dir/deliver/SKILL.md"
discuss="$skills_dir/discuss/SKILL.md"
polish="$skills_dir/polish/SKILL.md"
consolidate="$skills_dir/consolidate/SKILL.md"

assert_contains() {
  local file="$1"
  local text="$2"
  grep -Fq -- "$text" "$file" || {
    printf 'missing contract in %s: %s\n' "$file" "$text" >&2
    return 1
  }
}

assert_no_token() {
  local path="$1"
  local hits
  hits="$(grep -Rni --exclude-dir=.git -e 'harden' "$path" || true)"
  if [ -n "$hits" ]; then
    printf 'forbidden token in %s:\n%s\n' "$path" "$hits" >&2
    return 1
  fi
}

# 1. AGENTS.md surface and SKILLS carry no shipping-gate token or skill.
if [ -e "$skills_dir/harden" ]; then
  printf 'forbidden skill path still exists: %s\n' "$skills_dir/harden" >&2
  exit 1
fi
assert_no_token "$global_rules"
assert_no_token "$cursor_global"
assert_no_token "$skills_dir"

# 2. Delivery is a two-way dispatcher. Discuss has the same two phases.
#    Commit authority does not name a third stage.
assert_contains "$deliver" 'spike / polish'
assert_contains "$deliver" '迷ったら polish'
assert_contains "$deliver" 'commit 授権を継承する'
assert_contains "$discuss" '$discuss spike|polish'
assert_contains "$discuss" '**spike / polish を自動判断**'
assert_contains "$discuss" '**迷ったら polish**'
assert_contains "$global_rules" '`$spike`'
assert_contains "$global_rules" '`$polish`'
assert_contains "$global_rules" '`$deliver`'
assert_contains "$cursor_global" '`$spike`'
assert_contains "$cursor_global" '`$polish`'
assert_contains "$cursor_global" '`$deliver`'

# 3. The only reasons to stop requested work live in GLOBAL.md.
assert_contains "$global_rules" '## Stopping work'
assert_contains "$global_rules" '他社への迷惑'
assert_contains "$global_rules" '犯罪行為'
assert_contains "$global_rules" 'only when it would harm another company'
assert_contains "$global_rules" 'appears to be a crime'
assert_contains "$cursor_global" '## Stopping work'
assert_contains "$cursor_global" '他社への迷惑'
assert_contains "$cursor_global" '犯罪行為'

# polish must not stop the delivery to demand another invocation.
assert_contains "$polish" '規模が大きくても追加号令を求めず、この delivery の内側で続行する'
assert_contains "$polish" '追加号令や段階の切り替えで止めない'
if grep -Fq -- '`$spike` 再依頼' "$polish" || grep -Fq -- '$spike` 再依頼' "$polish"; then
  printf 'polish still demands another invocation\n' >&2
  exit 1
fi

# Active skills are self-contained. Historical decision docs are not current
# contract.
if grep -Rne '0002\|0003\|0004' --include='SKILL.md' "$skills_dir"; then
  printf 'active skills still cite retired stage decisions\n' >&2
  exit 1
fi

# consolidate produces the formatter receipt it hands to committer.
assert_contains "$consolidate" 'This parent-measured receipt is the formatter receipt'
assert_contains "$consolidate" 'An independent'
assert_contains "$consolidate" 'formatter role is not required'

echo 'no-harden contract test: pass'
