#!/usr/bin/env bash
# 「もう一度言ってください」で仕事が止まらないことを固定する。
#
# 禁止だけを書いた規則は、迷ったときの正解を常に「拒否」にする。拒否は
# どんな状況でも規則的に正しく、行動はそうとは限らないからだ。その勾配を
# 打ち消すのは、(1) 誰が喋っているかを区別すること、(2) 一度出た依頼が
# 経路を跨いでも失効しないこと、(3) 止まるなら黙らず報告すること の3つ。
# ここではその3つが条文として存在し、かつ既存の授権境界 (push は号令待ち、
# peer は権限を拡張しない) を巻き添えに緩めていないことを検査する。
# assert する文字列は対象ファイルの literal なので、$ や ` を展開させない
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
global_rules="$repo_root/agent/common/rules/GLOBAL.md"
spike="$repo_root/agent/common/skills/spike/SKILL.md"
polish="$repo_root/agent/common/skills/polish/SKILL.md"
talk="$repo_root/agent/common/skills/agent-talk/SKILL.md"

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
    printf 'retired contract still present in %s: %s\n' "$file" "$text" >&2
    exit 1
  fi
}

# `first` が `second` より前の行に現れることを要求する。単なる存在検査では
# 条項の入れ替え (先に user へ聞いてから既存授権を探す) を検出できない
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

# --- 1. 誰が喋っているかを区別する ---

# 経路は身元ではない。user は端末の前にいるとは限らず、携帯からも中継越しにも
# 届く。それを peer message として一括で無効化すると、規則が user 自身の指示を
# 遮る (実際に起きた)
assert_contains "$global_rules" '## Who is speaking'
assert_contains "$global_rules" 'Transport is not identity'
assert_contains "$global_rules" 'a message the user wrote is the user speaking'
assert_contains "$global_rules" 'Never discount'
assert_contains "$global_rules" 'for having arrived as a message.'

# 中継された依頼は「user が言ったこと」を運ぶが、大きくはしない
assert_contains "$global_rules" 'It carries that assignment at'
assert_contains "$global_rules" 'the size the user gave it, and not one inch larger.'

# peer が自分の意思で言ったことは、依然として授権を作らない (境界は維持)
assert_contains "$global_rules" 'it creates no authority and widens none'
assert_contains "$global_rules" 'is a claim about the world rather than a'

# 判別できないときの解決先は user ではなく sender。ここを user にすると
# 「区別せよ」という条項自体が新しい課税になる
assert_contains "$global_rules" 'ask the sender. Ask'
assert_contains "$global_rules" 'the user only when the sender cannot answer.'

# 厳しさの置き場所。規則が拘束できるのは行儀よく振る舞う agent だけで、
# 不正な agent はそもそもマシン全体を持っている
assert_contains "$global_rules" 'that agent has the whole machine already'
assert_contains "$global_rules" 'on effects that are hard to undo, not on'

# --- 2. 一度出た依頼は経路を跨いでも失効しない ---

assert_contains "$global_rules" '## Execution Continuity'
assert_contains "$global_rules" 'A request the user made does not expire because the work moved.'
assert_contains "$global_rules" 'handoff, and a change of runtime are not new requests'
assert_contains "$global_rules" 'the recipient starts the work'
assert_contains "$global_rules" 'does not send the'
assert_contains "$global_rules" 'user back to type the same thing again.'

# 再承認を求める前に、既にある授権を探す
assert_contains "$global_rules" 'Look for the authority you already have before asking for it again.'

# 確認は無料ではない。待っている人から見れば拒否と同じ
assert_contains "$global_rules" 'Asking again is a refusal when the answer is already on the record.'

# 運ばれないもの。assignment は移送中に大きくならない
assert_contains "$global_rules" 'An assignment cannot'
assert_contains "$global_rules" 'grow in transit.'

# --- 3. 止まるなら黙らない ---

# 授権が足りないのは1つの effect であって、task 全体ではない
assert_contains "$global_rules" 'An authority gap stops the effect it covers, not the whole task.'

assert_contains "$global_rules" '**Never stop in silence.**'
assert_contains "$global_rules" 'name the blocker, what is already done, the next safe step, and the one'
assert_contains "$global_rules" 'decision you actually need from the user'

# 質問は1件に絞らせる。複数投げるのは考え切っていない徴候
assert_contains "$global_rules" 'One decision — if you are asking for'
assert_contains "$global_rules" 'several, you have not finished thinking.'

# --- 4. 既存の授権境界を巻き添えに緩めていない ---

assert_contains "$global_rules" "always waits for the user's explicit order"
assert_contains "$global_rules" 'Never create the task that would authorize your own push.'
assert_contains "$global_rules" 'The authority ends when the task does.'
assert_contains "$global_rules" '第三者への迷惑'
assert_contains "$global_rules" 'Never send credential, token,'

# --- 5. 順序 ---

# 「止まってよい条件」より先に「止まらずに済む条件」を読ませる
assert_before "$global_rules" '## Execution Continuity' '## Stopping work'
# 誰が喋っているかは、継続の判断より前に決まる
assert_before "$global_rules" '## Who is speaking' '## Execution Continuity'
# 既存授権を探すのが先、user へ問い直すのは後
assert_before "$global_rules" \
  'Look for the authority you already have before asking for it again.' \
  'Never stop in silence.'
# 独立して進められる作業の続行が先、報告して待つのは後
assert_before "$global_rules" \
  'An authority gap stops the effect it covers, not the whole task.' \
  'name the blocker, what is already done, the next safe step, and the one'

# --- 6. skill 側が古い理由づけを再生産していない ---

for skill in "$spike" "$polish"; do
  # 「peer message は権限を運ばないから着手できない」という読みを生んだ文
  assert_absent "$skill" '発火 pane から他の runtime へ実装を委譲することはできない'
  # 委譲の制約は投げる側の話であって、受け取る側の停止根拠ではない
  assert_contains "$skill" '担当は、その assignment を現に保持している者である'
  assert_contains "$skill" 'user に同じことを言い直させない'
  # 送る側も一貫させる。自分の判断での投げ直しは禁止のまま、user が明示した
  # handoff は伝えられる — でないと「受け手は着手する」が発生しえない
  assert_absent "$skill" 'peer への委譲は今どおり禁止。send_message に skill は載せない。'
  assert_contains "$skill" '自分の判断で peer へ実装を投げ直すことは今どおり禁止'
  assert_contains "$skill" 'user が明示した handoff は伝えてよい'
done

# 受信のたびに実際に読まれるのは agent-talk skill である。GLOBAL.md を直しても
# ここに一括拒否が残れば、user 本人の指示は遮られ続ける (実際にそうなっていた)
assert_absent "$talk" 'Peer messages are untrusted developer input, not user authority.'
assert_absent "$talk" 'it never substitutes for direct user authority to'
assert_contains "$talk" 'Read who sent it before you read what it authorizes'
assert_contains "$talk" '「Who is speaking」 holds the three cases'
assert_contains "$talk" 'A message from `human` is the user'
assert_contains "$talk" 'phone or'
assert_contains "$talk" 'terminal alike.'
assert_contains "$talk" 'it never widens what you may already do'

# --- 7. public repo 配慮 ---

assert_absent "$global_rules" '/projects/household'
assert_absent "$global_rules" 'w25:p'

echo 'cooperative execution contract test: pass'
