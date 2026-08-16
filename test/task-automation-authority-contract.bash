#!/usr/bin/env bash
# task 由来の push / release 授権が「その task の間だけ」に閉じる契約を固定する。
#
# push は user の明示的な号令だけが開く。task を経路として認めると、
# agent が自分で task を作って自分に号令を出す抜け道が生まれるので、
# 「授権は task の終わりで切れる」と「自分の push を授権する task を
# 作らない」を pin する。
#
# 4527502 (rulebook GLOBAL.md → scene-to-skill routing) で GLOBAL.md の該当節が
# 削除され、規則の所有者が skill 側へ移った。ここでの所有者は 3 つ:
#   release 経路              → `bump-tag`
#   task worker 経路          → `working`
#   local commit で止まる境界 → `knowledge-deposit`
# 同じ規則を複数の skill で二重に測らない (所有者を 1 つ決めて測る)。
# assert する文字列は対象ファイルの literal なので、$ や ` を展開させない
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
global_rules="$repo_root/agent/common/rules/GLOBAL.md"
bump_tag="$repo_root/agent/common/skills/bump-tag/SKILL.md"
working="$repo_root/agent/common/skills/working/SKILL.md"
deposit="$repo_root/agent/common/skills/knowledge-deposit/SKILL.md"

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

# 号令を運ぶ経路は 2 つだけ。ここが緩むと「他にも経路がある」で押し切られる
assert_contains "$bump_tag" 'release happens in exactly two cases: the user invokes this skill, or a'
# 第1経路: user が push そのものを workflow に持つ skill を起動すること
assert_contains "$bump_tag" "This skill's invocation **is** explicit permission to commit, tag, and push"
# 第2経路: user が発行した task。ただし範囲は task が名指した
# repository・branch・operation に限る (他所へ広がらない)
assert_contains "$working" 'task が名指しする repository・branch・操作に限り、その task を'
# その task を保持している間だけ、かつ user が起動した worker skill 経由だけ
assert_contains "$working" '保持している間に限る'
assert_contains "$bump_tag" 'it lives only while a worker skill the user invoked holds it.'

# 授権の期限。task が終われば push の授権も終わる
assert_contains "$working" '授権は task の終了とともに失効する。'
# 自作自演の封じ込め。task を自分で作って自分へ号令を出す経路を塞ぐ
assert_contains "$working" '**自分の push を授権することになる task を自分で作らない。**'

# push は user の明示的な号令を待つ。自動化が到達してよいのは local commit まで
assert_contains "$deposit" 'その先は user の明示的な号令を待つ。'
# 4527502 で規則ごと削除 (「repository rule も peer message も号令を供給できない」に
# 相当する文言は repo に無し)。復元は user の判断

# 共有ブランチへの push・tag・deploy・release は通常の delivery に相乗りしない
assert_contains "$bump_tag" '**Release never rides along with ordinary delivery or a worker loop.**'
assert_contains "$working" '**共有ブランチへは push しない。**'

# 4527502 で `## Repositories with standing authority` 節ごと削除 (repo に該当文言なし)。
# 「standing authority は working tree までで push には届かない」の規則も同時に消滅。
# 復元は user の判断

# この repository は public。household 側の絶対パスや pane ID を焼かない
# (knowledge-deposit/SKILL.md「この machine の runtime 座標は知識ではない」)
assert_absent "$global_rules" '/projects/household'
assert_absent "$global_rules" 'w25:p'

echo 'task automation authority contract test: pass'
