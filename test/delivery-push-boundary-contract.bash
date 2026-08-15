#!/usr/bin/env bash
# 配達スキル (spike / polish) 側の push 境界を固定する。
#
# 「push しない」だけを書くと、外側の worker skill が押す正規の経路まで
# 禁止に読めてしまう。逆に例外だけを書くと配達自身が押し始める。
# 不変条件の1行目と、push の所有者が worker skill である但し書きを
# 両方 pin して、どちらの向きへも崩れないようにする。
# あわせて、手順より先に knowledge を読む導入 (聞く前に読む) も
# 両段階で同じ形であることを固定する。
# assert する文字列は対象ファイルの literal なので、$ や ` を展開させない
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
spike="$repo_root/agent/common/skills/spike/SKILL.md"
polish="$repo_root/agent/common/skills/polish/SKILL.md"

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
# 手順の入れ替え (手順を済ませてから knowledge を読む) を検出できない
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

for skill in "$spike" "$polish"; do
  # 不変条件の1行目。配達スキル自身は押さない
  assert_contains "$skill" '- push・merge・deploy・release はしない'
  # ただし外側の worker skill が押す経路は塞がない。push の所有者を名指す
  assert_contains "$skill" 'feature branch へ push することは妨げない'
  assert_contains "$skill" 'push を所有するのはその worker'
  assert_contains "$skill" 'skill であり、spike / polish 自身ではない'

  # knowledge は手順より先に読む。質問は読んでも曖昧なときだけ
  assert_contains "$skill" '**どの手順よりも先に読む**'
  assert_contains "$skill" 'library/index.md'
  assert_contains "$skill" 'projects/<name>/index.md'
  assert_contains "$skill" '読んでも曖昧なときだけ knowledge へ質問する'
  assert_contains "$skill" '聞く前に読む'

  # この repository は public。household 側の絶対パスを焼かない
  assert_absent "$skill" '/projects/household'
done

# 「先に読む」は存在するだけでは契約にならない。段落が手順より後ろへ動いたら
# 落ちること — 各段階の最初の手順を基準に、knowledge 段落の前後を固定する
assert_before "$spike" '**どの手順よりも先に読む**' '0. **土台を確認する**'
assert_before "$spike" '聞く前に読む' '0. **土台を確認する**'
assert_before "$polish" '**どの手順よりも先に読む**' '1. **方針を独立にすり合わせる'
assert_before "$polish" '聞く前に読む' '1. **方針を独立にすり合わせる'

echo 'delivery push boundary contract test: pass'
