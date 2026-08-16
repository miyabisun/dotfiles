#!/usr/bin/env bash
# commit 授権の所有者は `git` skill のブランチフロー。タスク用の作業ブランチ上の
# commit は通常の配達作業で追加の許可を要さず、共有ブランチへの直接 commit だけを
# 塞ぐ。配達スキル (`$spike` / `$polish`) は user の明示起動を起動根拠に持ち、
# workflow に commit 手順を持つ。`$deliver` は自前の commit 手順を持たず、選んだ
# 段階から授権を継承する。ordinary chat はどれにも当たらない。
# 4527502 (rulebook GLOBAL.md → scene-to-skill routing) で GLOBAL.md の commit 節が
# 削除され、規則の所有者が上記の各 skill へ移った。
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
global_rules="$repo_root/agent/common/rules/GLOBAL.md"
git_rules="$repo_root/agent/common/skills/git/SKILL.md"
spike="$repo_root/agent/common/skills/spike/SKILL.md"
polish="$repo_root/agent/common/skills/polish/SKILL.md"
deliver="$repo_root/agent/common/skills/deliver/SKILL.md"
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

# commit 授権の所有者は `git` skill。入口の「場面 → スキル」表からそこへ導く行が
# 消えると、所有者側だけ測っていても契約が切れる
assert_contains "$global_rules" '| git コマンドでの操作 | `git` |'

# 作業ブランチ上の commit は通常の配達作業であり、追加の許可を要さない
assert_contains "$git_rules" 'タスク用の作業ブランチ上では自発的に進めてよい'
assert_contains "$git_rules" '新ブランチ作成 → commit → そのブランチの push は通常の配達作業であり、'
assert_contains "$git_rules" '追加の許可は不要'
# 授権が届かない先。ここが緩むと共有ブランチが直接叩かれる
assert_contains "$git_rules" '共有ブランチ (デフォルトブランチや他者が作業中のブランチ) へ直接'
# 4527502 で「standing authority を与える repository」の規則ごと削除 (repo に該当文言なし)。復元は user の判断
assert_absent "$global_rules" 'NEVER commit unless the user explicitly instructs you to'

# Named delivery skills: user の明示起動が起動根拠で、workflow に commit 手順がある
assert_contains "$spike" 'user の明示的な `$spike` 起動、同じ依頼文での段階明示、または段階未指定の'
assert_contains "$polish" 'user の明示的な `$polish` 起動、同じ依頼文での段階明示、または段階未指定の'
assert_contains "$spike" '**コミットする**'
assert_contains "$polish" '**コミットする**'

# Compatibility entry `$deliver` inherits the selected stage's commit authority.
assert_contains "$deliver" '`$deliver` 自体に commit 手順は無い'
assert_contains "$deliver" 'commit 授権を継承する'

# Non-delivery skills are not commit authorization by name alone.
assert_absent "$discuss" '**コミットする**'
assert_absent "$discuss" 'Execute exactly one new local `git commit`'

echo 'delivery commit authority contract test: pass'
