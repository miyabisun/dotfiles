#!/usr/bin/env bash
# bump-tag は release そのものを行う唯一の skill である。task-server の
# release task を授権経路として認めたので、ここで pin するのは
# その経路が広がる方向 — 授権が task の範囲を超える、agent が自分で
# release task を作る、task が名指した水準を勝手に auto へ丸める、
# 通常の delivery や worker loop に release が相乗りする、
# preflight の read-only 検査より先に ref を動かす — を塞ぐ不変条件である。
# assert する文字列は対象ファイルの literal なので、$ や ` を展開させない
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bump_tag="$repo_root/agent/common/skills/bump-tag/SKILL.md"

assert_contains() {
  local file="$1" text="$2"
  grep -Fq -- "$text" "$file" || {
    printf 'missing contract in %s: %s\n' "$file" "$text" >&2
    exit 1
  }
}

assert_absent() {
  local file="$1" text="$2"
  if grep -Fq -- "$text" "$file"; then
    printf 'forbidden phrase in %s: %s\n' "$file" "$text" >&2
    exit 1
  fi
}

# `first` が `second` より前の行に現れることを要求する。単なる存在検査では
# preflight の並べ替え (検査より先に ref を動かす) を検出できない
assert_before() {
  local file="$1" first="$2" second="$3"
  local first_line second_line
  first_line="$(grep -nF -- "$first" "$file" | head -n1 | cut -d: -f1)"
  second_line="$(grep -nF -- "$second" "$file" | head -n1 | cut -d: -f1)"
  if [ -z "$first_line" ] || [ -z "$second_line" ]; then
    printf 'assert_before needs both anchors in %s: %s / %s\n' \
      "$file" "$first" "$second" >&2
    exit 1
  fi
  if [ "$first_line" -ge "$second_line" ]; then
    printf 'wrong order in %s: %s (line %s) must precede %s (line %s)\n' \
      "$file" "$first" "$first_line" "$second" "$second_line" >&2
    exit 1
  fi
}

# 起動制御は本文の授権境界が持つ。frontmatter で model 起動を塞ぐと
# `working` からの正規 dispatch まで道連れに落ちるので、この key は置かない
assert_absent "$bump_tag" 'disable-model-invocation'

# release task は直接起動と同じ「手順」を運ぶが、同じ「範囲」は運ばない。
# 範囲は task が名指したものに限り、保持している間だけ生きる
assert_contains "$bump_tag" 'What a claimed task grants is the same procedure, not the same scope.'
assert_contains "$bump_tag" 'the repository, branch, and operation the task names'
assert_contains "$bump_tag" 'only while a worker skill the user invoked holds it'

# 自作自演の封じ込め。自分の release を授権する task を自分で作らない
assert_contains "$bump_tag" '**Never create the release task that would authorize your own release.**'

# task が水準を名指していたらそれに従う。勝手に auto へ丸めない
assert_contains "$bump_tag" '**Never substitute `auto` for a level the task named.**'

# release は通常の delivery・worker loop に相乗りしない。起動経路は 2 つだけ
assert_contains "$bump_tag" '**Release never rides along with ordinary delivery or a worker loop.**'
assert_contains "$bump_tag" 'release happens in exactly two cases: the user invokes this skill, or a'

# preflight の順序が契約の中心である。read-only 検査が全て通ってから
# はじめて ref を動かす
assert_contains "$bump_tag" 'Verify before you move a local branch or tag.'
assert_contains "$bump_tag" 'updates remote-tracking refs and `FETCH_HEAD`, but no local branch or tag'
assert_contains "$bump_tag" 'and move no ref until this check passes'
# 対象を明示しない merge は、caller がいた branch を fast-forward してしまう
assert_contains "$bump_tag" 'Current branch must be the default branch'
assert_contains "$bump_tag" '`git merge --ff-only origin/<default>`'
assert_contains "$bump_tag" '**fast-forward only**, naming the target'
# sync 後の一致確認。stale な状態に tag を打たせない
assert_contains "$bump_tag" '`HEAD` must match `origin/<default>`'
assert_contains "$bump_tag" 'so a tag is never cut on a stale state'

# preflight は順序が契約そのもの。存在確認だけでは、branch 検証より先に
# ff-only merge を置く並べ替えも、同期確認を merge の前へ動かす並べ替えも通る
assert_before "$bump_tag" 'Current branch must be the default branch' \
  '`git merge --ff-only origin/<default>`'
assert_before "$bump_tag" '`git merge --ff-only origin/<default>`' \
  '`HEAD` must match `origin/<default>`'

# この repository は PUBLIC。private path を binding instruction へ焼かない
# (knowledge-deposit/SKILL.md「この machine の runtime 座標は知識ではない」)
assert_absent "$bump_tag" '/projects/household'

echo 'bump-tag release task contract test: pass'
