#!/usr/bin/env bash
# assert する文字列は対象ファイルの literal なので、$ や ` を展開させない
# private path が本文に無いことも literal で見るので tilde も展開させない
# shellcheck disable=SC2016,SC2088
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
spike="$repo_root/agent/common/skills/spike/SKILL.md"
global_rules="$repo_root/agent/common/rules/GLOBAL.md"

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

# TDD の逃げ道を塞ぐ guard は、その step の中だけを見る。file 全体を見ると
# 無関係な節 (方針すり合わせの「理由を1行残す」等) と衝突して、guard の方を
# 緩める圧力になる
assert_absent_in_step() {
  local file="$1"
  local step_anchor="$2"
  local text="$3"
  local step_body
  step_body="$(awk -v anchor="$step_anchor" '
    index($0, anchor) { inside = 1; print; next }
    inside && /^[0-9]+\. \*\*/ { exit }
    inside { print }
  ' "$file")"
  [[ -n "$step_body" ]] || {
    printf 'step not found in %s: %s\n' "$file" "$step_anchor" >&2
    return 1
  }
  if printf '%s\n' "$step_body" | grep -Fq -- "$text"; then
    printf 'forbidden phrase inside "%s" of %s: %s\n' \
      "$step_anchor" "$file" "$text" >&2
    return 1
  fi
}

# TDD は死守: red の観測が必須で、自己免除は存在しない
assert_contains "$spike" 'テスト無きゴールは存在しない'
assert_contains "$spike" '失敗するテストを先に書き (red)、通す (green)'
assert_contains "$spike" 'red を観測できないなら未達として止める'
assert_absent "$spike" '守れない事情があるなら'
assert_absent_in_step "$spike" '**TDD で作る**' '理由を1行'

# ゴール = acceptance テスト + 隣接する既存チェックの全 green
assert_contains "$spike" '変更に隣接する既存 test/build/lint が全て green'
assert_contains "$spike" '黙ってゴールから除外しない'

# formatter / linter は機械的に実行する
assert_contains "$spike" '**formatter / linter を機械的に叩く**'

# counterpart は planning で list_peers により一意固定し、実装レビューは同じ
# pane を使い回す (毎回引き直すと途中で相手が入れ替わる)
assert_contains "$spike" '**反対 runtime の登録 pane**を同じ window、次に同じ session の'
assert_contains "$spike" 'step 1 で固定した同じ pane へ'
assert_contains "$spike" '同じ window、次に同じ session'
assert_contains "$spike" '不在・pane 消失・配達失敗のときだけ self review'

# レビュワーの検査項目: テストの誠実さ・DRY・過度な YAGNI・実行確認
assert_contains "$spike" 'トートロジー'
assert_contains "$spike" '誤魔化し'
assert_contains "$spike" '厳格に blocking とし、修正させる'
assert_contains "$spike" 'このケースは必要か?'
assert_contains "$spike" 'formatter / linter の実行確認'

# DRY blocking は今回 diff 由来の有害な重複に限定 (試作の意図的重複は polish TODO)
assert_contains "$spike" '機構追加なしの局所抽出で消せる'
# TODO を repo へ残す許可は撤去した。落とした案は receipt の follow-up として
# user へ返す (GLOBAL.md「Project Memory Boundary」)
assert_contains "$spike" 'non-blocking の follow-up として'
assert_absent "$spike" 'non-blocking の polish TODO'

# 段階分割の境界: dispatcher 自動判断の受け入れ・commit 授権
assert_contains "$spike" '`$deliver` からの自動判断'
assert_absent "$spike" 'このスキルを推論で選んではならない'
assert_contains "$spike" '1 invocation = 1 local commit'

# 完了条件: v0.1.0 のリリースを目指す (リリース行為自体は bump-tag の権限)
assert_contains "$spike" 'v0.1.0 のリリースを目指す'
assert_contains "$spike" 'bump-tag'
# 目的文だけでなく観測可能な完了条件として組み込まれていること
assert_contains "$spike" 'v0.1.0 readiness'
assert_contains "$spike" 'version が 0.1.0 であること'
assert_contains "$spike" 'リリースを妨げる既知事項'

# 新規プロジェクトの立ち上げ手順
assert_contains "$spike" 'knowledge セクション'
assert_contains "$spike" '共通開発仕様'
assert_contains "$spike" 'rust-svelte-template'
assert_contains "$spike" 'LICENSE は MIT'

# A1. 推奨であって必須ではない。命令形で書くと agent は導入を blocker にする
assert_contains "$spike" '推奨する (必須ではない)'
assert_contains "$spike" '合わないなら使わなくてよい'
assert_contains "$spike" '土台が無いことを着手の障害にしない'
assert_absent "$spike" '導入し、今回の要件に'

# A2. 適用は2分岐。DESIGN.md は「名前が一致したら消す」ではなく
# 「template 由来の web 設計文書なら消す」— project 自身の現在形 docs は残す
assert_contains "$spike" 'Rust + Svelte の web service ならそのまま'
assert_contains "$spike" 'Rust だけのプロジェクト'
assert_contains "$spike" 'client/'
# provenance ではなく今の中身で判定する (既存 repo では由来が辿れない)
assert_contains "$spike" '削除する web frontend のことしか書いていない'
assert_contains "$spike" '**今の中身**で判定する'
assert_absent "$spike" 'DESIGN.md を削除'

# A3. private path を binding instruction に焼かない (GLOBAL の Project Memory
# Boundary と同じ理由)。場所は knowledge ヒアリングが解決する。
# user-home 絶対パスの禁止は repo 全体で test/portable-paths.bash が担う
assert_absent "$spike" '~/projects/sunny-side/rust-svelte-template'
# 既存プロジェクトは土台を入れ替えない。ただし「飛ばす」だけだと推奨は
# 既存 repo へ永久に届かないので、read-only の突き合わせを置く
assert_contains "$spike" '既存プロジェクトでは土台を入れ替えない'
assert_absent "$spike" '既存プロジェクトでは飛ばす'
assert_contains "$spike" '推奨 gap'
# audit が本題を乗っ取ると spike の軽さが壊れる。3つとも不変条件
assert_contains "$spike" 'read-only'
assert_contains "$spike" '今回の本題を止めない'
assert_contains "$spike" '自動で直さない'

# 「適用済み」を固定のファイル一覧で定義すると template の drift で嘘になる
assert_contains "$spike" '固定のファイル一覧ではない'
assert_contains "$spike" 'non-applicable と判定済み'

# 比較範囲に境界が無いと、既存 product の source まで gap 扱いになる。
# 既存が template から分岐しているのは当たり前なので、偽の指摘で溢れて
# 「最短で動かす」が死ぬ。役割で線を引く (ファイル名一覧では引かない)
assert_contains "$spike" 'foundation surface'
assert_contains "$spike" 'product 固有の source'
assert_contains "$spike" '比べない'

# 土台は Rust 向け。非 Rust を突き合わせても意味がない
assert_contains "$spike" 'Rust プロジェクトだけ'
# 見出しが「新規なら」だと、既存 repo の agent は step 0 ごと非該当として
# 飛ばせてしまう。配下に既存向けの文を置いても scope 見出しが優先される
assert_contains "$spike" '土台を確認する'
assert_absent "$spike" '新規プロジェクトなら土台を整える'

# knowledge への問い合わせは「質問」であって「預け入れ」ではない。
# GLOBAL は預け入れだけを intake role の専権にしており、質問は通常の peer 会話。
# 質問に findings を紛れ込ませる抜け道だけを塞ぐ
assert_contains "$spike" '預け入れではない'
assert_contains "$global_rules" 'Depositing findings'
assert_contains "$global_rules" 'Asking knowledge a question is ordinary peer conversation'
assert_contains "$global_rules" 'do not use a question to hand findings over'

# 昇格モデル: 昇格は polish まで。harden は user の v1.0.0 宣言か既存 version が根拠
assert_contains "$spike" '**polish への切り替えを'
assert_contains "$spike" '自動昇格は polish まで'
assert_contains "$spike" '全世界に問いかける'
assert_contains "$spike" 'Cargo.toml'
assert_contains "$spike" '既に 1.0.0 以上'
assert_absent "$spike" '外部公開・release artifact・第三者へ届く出力'
assert_absent "$spike" '**harden への切り替えを'

echo "spike contract test: pass"
