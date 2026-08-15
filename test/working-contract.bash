#!/usr/bin/env bash
# working は「薄い worker」であることが存在理由である。判断も実装も持たず、
# 1 task を取って渡し先の契約 ($deliver / merge / bump-tag) に品質を委ねる。
# ここで pin するのは、その薄さが壊れる方向 — 1 invocation で複数 task を
# 追いかける、claim 前に副作用を起こす、自分で自分の push を授権する、
# MCP を迂回して task-server を直接叩く — を塞ぐ不変条件である。
# assert する文字列は対象ファイルの literal なので、$ や ` を展開させない
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
working="$repo_root/agent/common/skills/working/SKILL.md"

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
# 手順の入れ替え (claim より先に git を触る) を検出できない
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

# frontmatter の授権設定は本文に同じ字面があっても代用にならないので、
# 先頭の --- ブロックの中だけを見る
assert_frontmatter_contains() {
  local file="$1" text="$2"
  local front
  front="$(awk 'NR == 1 && $0 != "---" { exit } NR == 1 { next } /^---$/ { exit } { print }' "$file")"
  printf '%s\n' "$front" | grep -Fq -- "$text" || {
    printf 'missing frontmatter contract in %s: %s\n' "$file" "$text" >&2
    exit 1
  }
}

# 推論起動を禁じる。worker は user の /working か /loop の各周だけが起動根拠で、
# model が「今なら task を取れそう」と判断して自走してよい skill ではない
assert_frontmatter_contains "$working" 'disable-model-invocation: true'

# 1 周 1 task。ここが緩むと /loop の外で worker が自走ループになる
assert_contains "$working" '1 invocation = 最大 1 task'
assert_contains "$working" 'この skill 自身はループしない'

# claim できていない task のために worktree・branch・ファイルを作らない
assert_contains "$working" 'claim する前に副作用を起こさない'
# 「副作用なし」と言いながら fetch だけ例外にする退行を塞ぐ。
# git fetch は remote-tracking ref と FETCH_HEAD を書き換える副作用である
assert_contains "$working" '**`git fetch` を含めて git 操作を一切せず**'
assert_contains "$working" '副作用であって、例外ではない'
assert_absent "$working" 'fetch 以外'

# 存在確認だけでは、claim と作業場所づくりを入れ替える手順変更を検出できない。
# claim が最初の git 操作より前にあること自体を固定する
assert_before "$working" '優先して claim する' '**作業場所を作る**'
assert_before "$working" '**claim する前に副作用を起こさない。**' '**作業場所を作る**'
assert_before "$working" '**claim する前に副作用を起こさない。**' \
  '`git fetch` で origin を最新化してから'
assert_before "$working" '**claim する前に副作用を起こさない。**' '**git worktree** を作り'

# task と現在地の照合。名指しされていない repository へ push する事故を防ぐ
assert_contains "$working" '**task と現在地を照合する**'
assert_contains "$working" 'task が名指しする repository・branch・'
assert_contains "$working" '**食い違ったら実行しない**'

# push の授権範囲は task が名指したものに限り、task の終了で失効する
assert_contains "$working" 'task が名指しする repository・branch・操作に限り、その task を'
assert_contains "$working" '保持している間に限る**。授権は task の終了とともに失効する。'

# push できるのは delivery が成功した feature branch だけ
assert_contains "$working" '**成功した feature branch にだけ push する**'
assert_contains "$working" 'local commit まで到達した (= delivery が成功した) ときだけ'
assert_contains "$working" '**force push はしない。**'
assert_contains "$working" '**共有ブランチへは push しない。**'
assert_contains "$working" '既定ブランチへ載せるのは `merge` の'

# bump-tag の起動を runtime が拒否したときは fail-closed。
# tag・push・version 書き換えを手作業で真似ない
assert_contains "$working" '**dispatch が失敗したら代行しない**'
assert_contains "$working" '**release を自力で代行しない**'
assert_contains "$working" '**user の実行待ち**に相当する state へ戻し'

# instant task (merge / release) は user が管理画面から発行した号令なので、
# 通常 task の後ろに積まない
assert_contains "$working" 'instant task (merge / release など system が発行したもの) は通常 task より'
assert_contains "$working" '優先して claim する'

# 中身の品質は渡した先の契約が持つ。working が spike / polish を薄めない
assert_contains "$working" '`$deliver` を間接利用する'
assert_contains "$working" 'task 本文は verbatim で渡す'

# release task の水準は task が持つ。worker が勝手に丸めない
assert_contains "$working" '(`auto` / `major` / `minor` / `patch` / `first`) を指定していたら'
assert_contains "$working" 'それをそのまま渡す'
assert_contains "$working" '勝手に `auto` へ置き換えない'

# 失敗を握り潰すと task が消える。失敗は失敗の state、判断は user 判断待ちへ
assert_contains "$working" '失敗を close 扱いにしない'
assert_contains "$working" '失敗は失敗の state、判断が要るものは user 判断待ちの state へ返す'

# push の授権は task が運ぶ。自分で task を作れば授権を自作できてしまう
assert_contains "$working" '自分の push を授権することになる task を自分で作らない'

# task-server は MCP 越しにだけ触る。迂回路を塞ぐ
assert_contains "$working" 'HTTP API の直叩き、データベースファイルへの直接書き込みはしない'

# この repository は PUBLIC。private path・pane 座標・生の HTTP 手段を
# binding instruction へ焼かない (GLOBAL.md「Project Memory Boundary」)
assert_absent "$working" '/projects/household'
assert_absent "$working" 'w25:p'
assert_absent "$working" 'curl'

echo 'working contract test: pass'
