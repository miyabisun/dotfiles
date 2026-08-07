#!/usr/bin/env bash
# assert する文字列は対象ファイルの literal なので、$ や ` を展開させない
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
spike="$repo_root/agent/common/skills/spike/SKILL.md"
polish="$repo_root/agent/common/skills/polish/SKILL.md"
dispatcher="$repo_root/agent/common/skills/deliver/SKILL.md"
harden="$repo_root/agent/common/skills/harden/SKILL.md"
committer="$repo_root/agent/common/agents/committer.md"
decision3="$repo_root/docs/decisions/0003-version-gated-stages.md"
decision4="$repo_root/docs/decisions/0004-harden-as-shipping-gate.md"

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

# harden の入口は user のリリース号令のみ (decision 0004)。version 単独 gate は
# 全 surface から消えている
assert_contains "$harden" "the user's explicit release call"
assert_contains "$harden" 'A version number alone never selects harden'
assert_absent "$harden" 'at or above 1.0.0'
assert_absent "$dispatcher" '既に 1.0.0 以上'
assert_absent "$polish" '既に 1.0.0 以上'

# dispatcher: gate は号令 (明示 $harden 同値) のみ。非該当は spike/polish 自動判断
assert_contains "$dispatcher" 'まず決定的 gate を判定する'
assert_contains "$dispatcher" '明示的な `$harden` 起動はこの号令と同値'
assert_contains "$dispatcher" 'version は gate ではない'
assert_contains "$dispatcher" 'spike / polish を自動判断'
assert_contains "$dispatcher" '迷ったら polish'
assert_contains "$dispatcher" 'リスクや成果物の重さからの推論で harden を選んではならない'
assert_absent "$dispatcher" 'なんで spike やねん'

# polish: 全 version の成熟レーン (v1.0.0 は通過点)
assert_contains "$polish" 'どの version でも'
assert_contains "$polish" '通過点'
assert_contains "$polish" 'リリース号令'
assert_absent "$polish" 'v1.0.0 へ磨き上げる'
assert_contains "$polish" '`$deliver` からの自動判断'
assert_absent "$polish" 'このスキルを推論で選んではならない'

# polish: 大規模再作成は $spike 再依頼として user へ返す (自動転送・部分実装・
# 自動縮小なし)
assert_contains "$polish" '`$spike` 再依頼'
assert_contains "$polish" '部分実装を delivery 扱いせず'
assert_contains "$polish" '書きかけの変更は破棄せず'
assert_absent "$polish" '「harden で扱うべき」'
assert_absent "$polish" '縮小'

# polish: harden-review-sensitive は契約時分類と final diff 再判定の両方
# (advisory であって自動昇格でない)
assert_contains "$polish" 'harden-review-sensitive'
assert_contains "$polish" '出荷判断の前に `$harden` での見直しを推奨'
assert_contains "$polish" '自動で harden を起動したり'
assert_contains "$polish" 'final diff で harden-review-sensitive を再判定し'
assert_contains "$polish" '契約時分類との差分を契約と receipt に反映する'

# spike: version は昇格根拠にならず、v1.0.0+ では互換性影響を判定して続行
assert_contains "$spike" 'spike は spike のまま進む'
assert_contains "$spike" '互換性影響'
assert_contains "$spike" 'next major work'
assert_absent "$spike" 'なんで spike やねん'
assert_absent "$spike" 'harden へ直行する例外'

# harden: 出荷ゲート。検証範囲 = 前回 Harden-Verified marker からの累積 diff、
# marker 不在の初回は全 tracked product state。semver 推奨を必ず返す
assert_contains "$harden" 'Harden-Verified: true'
assert_contains "$harden" 'cumulative diff'
assert_contains "$harden" 'entire tracked product state'
assert_contains "$harden" '"semver_recommendation"'
assert_contains "$harden" '`bump-tag`'

# harden: 累積 scope は宣言でなく配線 — ledger に持ち、契約時に解決し、
# risk 分類・checks・実装レビュー・security manifest が受け取り、trailer は
# 累積範囲全体の通過を主張する
assert_contains "$harden" '"shipping_gate"'
assert_contains "$harden" 'Resolve the shipping-gate baseline at contract time'
assert_contains "$harden" 'not from the current task diff alone'
assert_contains "$harden" 'shipping_gate.cumulative_paths'
assert_contains "$harden" 'the current task diff plus the cumulative shipping'
assert_contains "$harden" 'entire cumulative range'
assert_contains "$harden" 'AND the shipping-gate verification covered the entire cumulative range'

# harden: 累積列挙は契約時の値で凍結しない — baseline は固定、range/paths は
# 各 gate (実装レビュー送信前・security freeze 時・closure fix 後) で
# frozen/current candidate snapshot から再列挙し、mutation は旧証拠を無効化、
# 最終評価は final frozen cumulative diff に対して行う
assert_contains "$harden" 're-enumerated at every later gate'
assert_contains "$harden" 'from the current candidate snapshot before'
assert_contains "$harden" 'from that frozen snapshot first'
assert_contains "$harden" 'Every mutation invalidates the previously enumerated candidate evidence.'
assert_contains "$harden" 'against the final frozen cumulative diff'
assert_contains "$harden" 're-enumerate the range and'

# harden: 修正0件の正常系でも baseline は進む (trailer 付き empty commit)
assert_contains "$harden" 'zero eligible files'
assert_contains "$harden" '--allow-empty'
assert_contains "$committer" '--allow-empty'
assert_contains "$committer" 'chore(release): record shipping-gate verification'

# committer: trailer 契約。旧「段階未指定 $deliver = harden」互換句は廃止
assert_contains "$committer" 'Harden-Verified: true'
assert_absent "$committer" '互換: 段階未指定'

# decision 0004: 号令のみの入口と出荷ゲートを記録し、0003 の version 条項を
# supersede する。0003 側にも supersede 注記がある
test -f "$decision4"
assert_contains "$decision4" 'リリース号令'
assert_contains "$decision4" 'Harden-Verified: true'
assert_contains "$decision4" '0003'
assert_contains "$decision3" 'decision 0004'

echo "stage escalation contract test: pass"
