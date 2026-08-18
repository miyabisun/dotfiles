#!/usr/bin/env bash
# Contract: meiseki は「日本語本文を明晰化して stdout に返す」唯一の起動形であり、
# 決定論層 (meiseki-lint) と リライト層 (meiseki-rewrite) を束ねる orchestrator で
# ある。`meiseki <file>` と `echo … | meiseki` は同じ経路へ正規化され、lint を
# ちょうど 1 回呼ぶ。lint が clean (exit 0) なら入力をバイト等価でそのまま返し、
# rewrite を一度も起動しない。finding (exit 1) のときだけ rewrite を 1 回だけ
# 起動して、その stdout と exit code を透過する。lint が exit 2 なら rewrite を
# 起動せずに exit 2 で終わる。findings JSON は成果物ではないので stdout に
# 混ざらない。前提が欠けていれば `meiseki: ` の 1 行を stderr へ出して非ゼロ終了。
# 兄弟 script の本物は決して呼ばず、MEISEKI_LINT / MEISEKI_REWRITE の stub で実測する。
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
meiseki_bin="$repo_root/agent/common/bin/meiseki"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

lint_stub="$test_root/lint-stub"
rewrite_stub="$test_root/rewrite-stub"
lint_calls="$test_root/lint-calls.log"
rewrite_calls="$test_root/rewrite-calls.log"
lint_input="$test_root/lint-input.md"
rewrite_input="$test_root/rewrite-input.md"
body_file="$test_root/body.md"
body_no_newline="$test_root/body-no-newline.md"
rewritten_file="$test_root/rewritten.md"
out_file="$test_root/stdout.txt"
err_file="$test_root/stderr.txt"

# stub lint: 呼ばれた回数と受け取った原稿を落とし、findings JSON を stdout へ
# 吐いて指定の exit code で終わる (JSON が user の stdout に漏れないことを測る)。
cat >"$lint_stub" <<'LINT'
#!/usr/bin/env bash
set -euo pipefail
printf 'call\n' >>"$STUB_LINT_CALLS"
cp -- "${@: -1}" "$STUB_LINT_INPUT"
printf '%s\n' "${STUB_LINT_JSON:-[]}"
exit "${STUB_LINT_EXIT:-0}"
LINT
chmod +x "$lint_stub"

# stub rewrite: 呼ばれた回数と受け取った原稿を落とし、リライト後の本文を返す。
cat >"$rewrite_stub" <<'REWRITE'
#!/usr/bin/env bash
set -euo pipefail
printf 'call\n' >>"$STUB_REWRITE_CALLS"
cp -- "${@: -1}" "$STUB_REWRITE_INPUT"
cat -- "$STUB_REWRITE_STDOUT"
exit "${STUB_REWRITE_EXIT:-0}"
REWRITE
chmod +x "$rewrite_stub"

# 本文は改行・日本語・$ / backtick / 先頭末尾空白を含み、欠落を測れる形にする
cat >"$body_file" <<'BODY'
このツールの導入によって得られるメリットがないというわけではない。
untrusted data を含む: $HOME と `backtick` と "quote" と \backslash
   先頭空白と末尾空白
BODY
# 末尾改行が無い入力: clean のとき 1 byte も足さずに返ることを測る
printf '%s' '末尾に改行が無い一文である' >"$body_no_newline"

cat >"$rewritten_file" <<'REWRITTEN'
このツールの導入にはメリットがある。
REWRITTEN

finding_json='[{"filePath":"input.md","messages":[{"ruleId":"ja-no-redundant-expression","message":"冗長な表現"}]}]'

status=0
lint_exit=0
lint_json="[]"
rewrite_exit=0

run_meiseki() {
  local stdin_source="$1"
  shift
  rm -f "$lint_calls" "$rewrite_calls" "$lint_input" "$rewrite_input"
  set +e
  MEISEKI_LINT="$lint_stub" \
    MEISEKI_REWRITE="$rewrite_stub" \
    STUB_LINT_CALLS="$lint_calls" \
    STUB_LINT_INPUT="$lint_input" \
    STUB_LINT_JSON="$lint_json" \
    STUB_LINT_EXIT="$lint_exit" \
    STUB_REWRITE_CALLS="$rewrite_calls" \
    STUB_REWRITE_INPUT="$rewrite_input" \
    STUB_REWRITE_STDOUT="$rewritten_file" \
    STUB_REWRITE_EXIT="$rewrite_exit" \
    "$meiseki_bin" "$@" <"$stdin_source" >"$out_file" 2>"$err_file"
  status=$?
  set -e
}

fail() {
  echo "meiseki orchestrator test: $1" >&2
  echo "--- stdout ---" >&2
  cat "$out_file" >&2 2>/dev/null || true
  echo "--- stderr ---" >&2
  cat "$err_file" >&2 2>/dev/null || true
  exit 1
}

call_count() {
  [[ -e "$1" ]] || { echo 0; return; }
  wc -l <"$1"
}

# 1. lint が clean なら入力をそのまま返し、rewrite を起動しない
input_file="$test_root/input.md"
cp "$body_file" "$input_file"
lint_exit=0
lint_json="[]"
run_meiseki /dev/null "$input_file"
[[ "$status" -eq 0 ]] || fail "expected exit 0 for clean lint, got $status"
cmp "$body_file" "$out_file" \
  || fail 'clean input must come back byte-for-byte on stdout'
[[ "$(call_count "$rewrite_calls")" -eq 0 ]] \
  || fail 'rewrite must not run when lint is clean'
[[ "$(call_count "$lint_calls")" -eq 1 ]] \
  || fail 'lint must run exactly once'
cmp "$body_file" "$lint_input" \
  || fail 'lint must receive the body verbatim'
[[ "$(sha256sum "$input_file" | awk '{ print $1 }')" \
  == "$(sha256sum "$body_file" | awk '{ print $1 }')" ]] \
  || fail 'meiseki must not edit the input file in place'

# 末尾改行が無い入力に 1 byte も足さない
run_meiseki /dev/null "$body_no_newline"
[[ "$status" -eq 0 ]] || fail "expected exit 0 for clean lint, got $status"
cmp "$body_no_newline" "$out_file" \
  || fail 'clean input without a trailing newline must not gain one'

# stdin 形態でも同じ (バイト等価で返り、rewrite は起動しない)
run_meiseki "$body_no_newline"
[[ "$status" -eq 0 ]] || fail "expected exit 0 for clean stdin lint, got $status"
cmp "$body_no_newline" "$out_file" \
  || fail 'clean stdin input must come back byte-for-byte on stdout'
[[ "$(call_count "$rewrite_calls")" -eq 0 ]] \
  || fail 'rewrite must not run when stdin lint is clean'

# 2. lint が finding を出したときだけ rewrite を 1 回だけ起動する
lint_exit=1
lint_json="$finding_json"
run_meiseki /dev/null "$input_file"
[[ "$status" -eq 0 ]] || fail "expected exit 0 from rewrite, got $status"
[[ "$(call_count "$rewrite_calls")" -eq 1 ]] \
  || fail 'rewrite must run exactly once when lint reports findings'
cmp "$rewritten_file" "$out_file" \
  || fail 'stdout must carry the rewrite output verbatim'
cmp "$body_file" "$rewrite_input" \
  || fail 'rewrite must receive the body verbatim'

# findings JSON は成果物ではない: stdout に混ざらない
if grep -Fq 'ja-no-redundant-expression' "$out_file"; then
  fail 'lint findings JSON must never reach stdout'
fi

# stdin 形態でも同じ
run_meiseki "$body_file"
[[ "$status" -eq 0 ]] || fail "expected exit 0 from stdin rewrite, got $status"
[[ "$(call_count "$rewrite_calls")" -eq 1 ]] \
  || fail 'rewrite must run exactly once for stdin findings'
cmp "$rewritten_file" "$out_file" \
  || fail 'stdin mode stdout must carry the rewrite output verbatim'
cmp "$body_file" "$rewrite_input" \
  || fail 'stdin mode rewrite must receive the body verbatim'

# 3. rewrite の exit code はそのまま透過する
rewrite_exit=9
run_meiseki /dev/null "$input_file"
[[ "$status" -eq 9 ]] || fail "expected exit 9 from rewrite, got $status"
rewrite_exit=0

# 4. lint が exit 2 (前提エラー) なら rewrite を起動せず exit 2 で終わる
lint_exit=2
lint_json="[]"
run_meiseki /dev/null "$input_file"
[[ "$status" -eq 2 ]] || fail "expected exit 2 when lint fails, got $status"
[[ "$(call_count "$rewrite_calls")" -eq 0 ]] \
  || fail 'rewrite must not run when lint cannot judge'
[[ ! -s "$out_file" ]] || fail 'stdout must stay empty when lint cannot judge'
lint_exit=0

# 5. 使い方の誤りでは lint も rewrite も起動せず、`meiseki: ` の 1 行で終わる
assert_precondition_error() {
  local label="$1"
  [[ "$status" -ne 0 ]] || fail "expected nonzero exit for $label"
  [[ "$(call_count "$lint_calls")" -eq 0 ]] || fail "lint must not run for $label"
  [[ "$(call_count "$rewrite_calls")" -eq 0 ]] \
    || fail "rewrite must not run for $label"
  [[ ! -s "$out_file" ]] || fail "stdout must stay empty for $label"
  grep -q '^meiseki: ' "$err_file" \
    || fail "missing 'meiseki: ' diagnostic for $label"
  [[ "$(wc -l <"$err_file")" -eq 1 ]] \
    || fail "diagnostic must be a single line for $label"
}

# 引数なしで stdin が空 (パイプ元が何も出さない)
run_meiseki /dev/null
assert_precondition_error 'empty stdin'

# 引数なしで stdin が tty (pty を張れる環境でだけ測る)
if command -v script >/dev/null 2>&1; then
  rm -f "$lint_calls" "$rewrite_calls"
  set +e
  MEISEKI_LINT="$lint_stub" \
    MEISEKI_REWRITE="$rewrite_stub" \
    STUB_LINT_CALLS="$lint_calls" \
    STUB_LINT_INPUT="$lint_input" \
    STUB_REWRITE_CALLS="$rewrite_calls" \
    STUB_REWRITE_INPUT="$rewrite_input" \
    STUB_REWRITE_STDOUT="$rewritten_file" \
    script -qec "$meiseki_bin" /dev/null >"$out_file" 2>"$err_file"
  status=$?
  set -e
  [[ "$status" -ne 0 ]] || fail 'expected nonzero exit for tty stdin'
  [[ "$(call_count "$lint_calls")" -eq 0 ]] || fail 'lint must not run for tty stdin'
  [[ "$(call_count "$rewrite_calls")" -eq 0 ]] \
    || fail 'rewrite must not run for tty stdin'
  grep -q 'meiseki: ' "$out_file" "$err_file" \
    || fail "missing 'meiseki: ' diagnostic for tty stdin"
else
  echo "meiseki orchestrator test: note: script(1) missing, skipped tty stdin case" >&2
fi

# 読めないファイル
run_meiseki /dev/null "$test_root/no-such-file.md"
assert_precondition_error 'missing file'

unreadable="$test_root/unreadable.md"
cp "$body_file" "$unreadable"
chmod 000 "$unreadable"
run_meiseki /dev/null "$unreadable"
assert_precondition_error 'unreadable file'
chmod 644 "$unreadable"

# 引数が 2 個以上
run_meiseki /dev/null "$input_file" "$unreadable"
assert_precondition_error 'too many arguments'

# 未知の option
run_meiseki /dev/null --bogus
assert_precondition_error 'unknown option'

# --help は usage を stderr に出し、lint も rewrite も起動しない (stdout は空)
run_meiseki /dev/null --help
[[ "$status" -eq 2 ]] || fail "expected exit 2 for --help, got $status"
[[ "$(call_count "$lint_calls")" -eq 0 ]] || fail 'lint must not run for --help'
[[ "$(call_count "$rewrite_calls")" -eq 0 ]] || fail 'rewrite must not run for --help'
[[ ! -s "$out_file" ]] || fail 'usage must not write to stdout'
grep -q '^usage: meiseki ' "$err_file" || fail 'missing usage line for --help'

echo "meiseki orchestrator test: pass"
