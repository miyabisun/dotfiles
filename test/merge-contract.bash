#!/usr/bin/env bash
# merge は「マージして終わり」ではなく polish と同じ作りの配達である。
# ここで pin するのは、その配達が崩れる方向 — 既定ブランチ名を main と
# 決め打ちする、feature ref を直接いじる、緑でないものを force で押し込む、
# push 前に feature branch を消す、製品判断の衝突を agent が勝手に決める —
# を塞ぐ不変条件である。
# assert する文字列は対象ファイルの literal なので、$ や ` を展開させない
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
merge="$repo_root/agent/common/skills/merge/SKILL.md"

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
# 手順の入れ替え (テストの前に押す・push の前に消す) を検出できない
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

# 起動根拠は 2 経路。model 起動は frontmatter では塞げない
# (working から dispatch する必要があるため) ので、本文で授権範囲を書き分ける
assert_contains "$merge" '起動根拠は 2 経路しかなく、push の授権範囲はそれぞれ別に決まる。'
assert_contains "$merge" '**user が `$merge` を直接起動した場合**: その invocation 自体が user の号令'
assert_contains "$merge" '授権の範囲は **user が名指しした repository と feature branch、および'
assert_contains "$merge" '**`working` が merge task から dispatch した場合**: 授権は **その task が'
assert_contains "$merge" '名指しする repository・branch・操作に限り、その task を保持している間に'
assert_contains "$merge" '限る** — 授権は task の終了とともに失効する。'
# どちらの経路でもない自走起動は号令ではない
assert_contains "$merge" 'model が「今なら載せられそう」と判断して自走起動することは'

# 既定ブランチは remote が申告する値で決める。main 決め打ちは事故になる
assert_contains "$merge" 'origin を最新化し、既定ブランチを解決する'
assert_contains "$merge" '`git fetch` (必要なら'
assert_contains "$merge" '`--prune`) で origin を最新にし'
assert_contains "$merge" 'remote HEAD から既定ブランチ名を解決する'
assert_contains "$merge" '`main` と決め打ちしない'
assert_contains "$merge" 'git symbolic-ref refs/remotes/origin/HEAD'
assert_contains "$merge" '既定ブランチ名を決め打ちしない。remote HEAD から解決する'

# 作業は一時 integration ref の上。feature は着手前の姿のまま残る
assert_contains "$merge" '一時 integration ref (branch か worktree) を作る'
assert_contains "$merge" '元の feature ref は更新しない'
# 既定ブランチの上へ rebase する。merge commit で被せない
assert_contains "$merge" 'その integration ref を `origin/<default>` の上へ'
assert_contains "$merge" '**rebase** する。merge commit で被せない。'
assert_contains "$merge" 'コンフリクト解消の結果を feature branch へ push し返さない'

# polish 型の配達: 毎回作る子 agent がハブの親の下で働き、子は push しない
assert_contains "$merge" '子 agent を展開してコンフリクトを'
assert_contains "$merge" '毎回 agent を作成する'
assert_contains "$merge" '親はハブである'
assert_contains "$merge" '**子は push しない。**'
assert_contains "$merge" '緑にする (polish と同じやり方)'
assert_contains "$merge" '親が管理する独立レビューを 1 回通す'

# push できるのは緑かつ pass のときだけ。しかも force なし
assert_contains "$merge" 'テストが緑で、レビューが pass したときだけ'
assert_contains "$merge" 'force なしで'
assert_contains "$merge" 'force で押し通さない'

# 後片付けは push のあとだけ。載っていない成果を消さない
assert_contains "$merge" '**後片付けは push のあとだけ**: push が成功したあとにのみ、remote と local の'
assert_contains "$merge" 'feature branch を削除する。'
assert_contains "$merge" 'push に失敗したら feature branch を削除しない'

# 製品判断の衝突は agent の領分ではない。既定ブランチを触らず user へ返す
assert_contains "$merge" '製品判断になる衝突は、既定ブランチを触らず、task を user 判断待ちの state へ戻す'
assert_contains "$merge" '**agent が勝手に片方を採用しない。**'

# push の授権は task が運ぶ。自分で task を作れば授権を自作できてしまう
assert_contains "$merge" '自分の push を授権することになる task を自分で作らない'

# この repository は PUBLIC。private path を binding instruction へ焼かない。
# force push の具体オプションを書き置くと、いつか誰かが実行例として使う
assert_absent "$merge" '/projects/household'
assert_absent "$merge" '--force'
assert_absent "$merge" 'force-with-lease'

# 手順の順序そのものが契約である。存在確認だけでは、押してからテストする /
# 押す前に feature を消す、という並べ替えが素通りしてしまう。
# 既定ブランチ解決 → integration ref → rebase → 緑かつ pass → push → 削除
assert_before "$merge" 'origin を最新化し、既定ブランチを解決する' \
  '**一時 integration ref (branch か worktree) を作る**'
assert_before "$merge" '**一時 integration ref (branch か worktree) を作る**' \
  '**rebase** する。merge commit で被せない。'
assert_before "$merge" '**rebase** する。merge commit で被せない。' \
  '**緑にする (polish と同じやり方)**'
assert_before "$merge" '**緑にする (polish と同じやり方)**' \
  'テストが緑で、レビューが pass したときだけ'
# push はテストとレビューの後ろ。ここが逆転すると緑でないものが載る
assert_before "$merge" 'テストが緑で、レビューが pass したときだけ' \
  '**force なしで** push する'
assert_before "$merge" '親が管理する独立レビューを 1 回通す' \
  '**force なしで** push する'
# feature branch の削除は push の後ろ。ここが逆転すると載っていない成果が消える
assert_before "$merge" '**force なしで** push する' \
  '**後片付けは push のあとだけ**'
assert_before "$merge" '**force なしで** push する' 'feature branch を削除する。'

echo 'merge contract test: pass'
