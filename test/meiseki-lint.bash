#!/usr/bin/env bash
# Contract: meiseki-lint は textlint だけを走らせる決定論層である。claude / proxy /
# client key を一切要求せず、meiseki の textlint config と本文を npx へ渡し、
# textlint の JSON をそのまま stdout へ流す。exit code は finding なし = 0 /
# finding あり = 1 / 前提エラー・使い方の誤り = 2 で、壊れた出力を finding と
# 取り違えない。`meiseki-lint <file>` と `echo … | meiseki-lint` は同じ結果になる。
# 本物の textlint / network は決して呼ばず、npx の stub と偽 HOME で実測する。
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lint_bin="$repo_root/agent/common/bin/meiseki-lint"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fake_home="$test_root/home"
fnm_bin="$fake_home/.local/share/fnm/aliases/default/bin"
skill_dir="$fake_home/.local/share/meiseki/.agents/skills/meiseki"
config_file="$skill_dir/references/textlint.config.json"
# claude / client key / plugin manifest はあえて置かない。決定論層がそれらを
# 要求しないことを、無い状態で通ることで測る。
mkdir -p "$fnm_bin" "$skill_dir/references"
printf '%s\n' '{}' >"$config_file"

npx_args="$test_root/npx-args.log"
npx_input="$test_root/npx-input.md"
out_file="$test_root/stdout.txt"
err_file="$test_root/stderr.txt"
body_file="$test_root/body.md"

# npx stub: 引数と textlint に渡された原稿を落とし、指定された JSON を返す。
# stderr にもログを吐き、wrapper が stdout を汚さないことを測れるようにする。
cat >"$fnm_bin/npx" <<'NPX'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >"$STUB_NPX_ARGS"
cp -- "${@: -1}" "$STUB_NPX_INPUT"
[[ -z "${STUB_NPX_STDOUT:-}" ]] || printf '%s\n' "$STUB_NPX_STDOUT"
printf '%s\n' 'npx stderr noise' >&2
exit "${STUB_NPX_EXIT:-0}"
NPX
chmod +x "$fnm_bin/npx"

# 本文は改行・日本語・$ / backtick / 先頭末尾空白を含み、欠落を測れる形にする
cat >"$body_file" <<'BODY'
このツールの導入によって得られるメリットがないというわけではない。
untrusted data を含む: $HOME と `backtick` と "quote" と \backslash
   先頭空白と末尾空白
BODY
body_sha="$(sha256sum "$body_file" | awk '{ print $1 }')"

clean_json='[{"filePath":"input.md","messages":[]}]'
finding_json='[{"filePath":"input.md","messages":[{"ruleId":"ja-no-redundant-expression","message":"冗長な表現"}]}]'

status=0
npx_stdout="[]"
npx_exit=0
# node / npx を持たない最小 PATH に固定し、wrapper の fnm 前置だけが npx を
# 見つけられる状態を作る (前置が落ちれば決定論層は死ぬ)
sanitized_path="/usr/bin:/bin"

run_lint() {
  local stdin_source="$1"
  shift
  rm -f "$npx_args" "$npx_input"
  set +e
  HOME="$fake_home" \
    STUB_NPX_ARGS="$npx_args" \
    STUB_NPX_INPUT="$npx_input" \
    STUB_NPX_STDOUT="$npx_stdout" \
    STUB_NPX_EXIT="$npx_exit" \
    PATH="$sanitized_path" \
    "$lint_bin" "$@" <"$stdin_source" >"$out_file" 2>"$err_file"
  status=$?
  set -e
}

fail() {
  echo "meiseki-lint test: $1" >&2
  echo "--- npx args ---" >&2
  cat "$npx_args" >&2 2>/dev/null || true
  echo "--- stdout ---" >&2
  cat "$out_file" >&2 2>/dev/null || true
  echo "--- stderr ---" >&2
  cat "$err_file" >&2 2>/dev/null || true
  exit 1
}

# 1. finding なし (空配列) は exit 0 で、textlint の JSON をそのまま返す
input_file="$test_root/input.md"
cp "$body_file" "$input_file"
npx_stdout="[]"
npx_exit=0
run_lint /dev/null "$input_file"
[[ "$status" -eq 0 ]] || fail "expected exit 0 for clean lint, got $status"
printf '%s\n' '[]' >"$test_root/expected.json"
cmp "$test_root/expected.json" "$out_file" \
  || fail 'stdout must carry the textlint JSON verbatim'

# 本文は 1 byte も欠けずに textlint まで届き、入力ファイルは書き換えない
cmp "$body_file" "$npx_input" \
  || fail 'lint did not pass the body through to textlint verbatim'
[[ "$(sha256sum "$input_file" | awk '{ print $1 }')" == "$body_sha" ]] \
  || fail 'meiseki-lint must not edit the input file in place'

# textlint は upstream package.json の lint script と同じ 4 rule package で呼ばれる
# (1 つでも解決できないと textlint は config 全体を捨てて "No rules found" になる)
for pkg in textlint@14.8.4 \
  textlint-rule-preset-ja-technical-writing@10.0.2 \
  textlint-rule-preset-ai-writing@1.1.0 \
  textlint-rule-prh@6.1.0; do
  grep -Fxq -- "$pkg" "$npx_args" || fail "missing textlint package: $pkg"
done
grep -Eq '&&|>|<|mktemp' "$npx_args" && fail 'npx argv must stay a single command'

# textlint は meiseki の config と JSON formatter で呼ばれる
grep -Fxq -- '-f' "$npx_args" || fail 'missing -f flag for textlint'
grep -Fxq -- 'json' "$npx_args" || fail 'missing json formatter for textlint'
grep -Fxq -- "$config_file" "$npx_args" \
  || fail 'textlint must run with the meiseki textlint config'

# 2. messages が空の結果も clean 扱い (exit 0)
npx_stdout="$clean_json"
npx_exit=0
run_lint /dev/null "$input_file"
[[ "$status" -eq 0 ]] || fail "expected exit 0 for empty messages, got $status"
printf '%s\n' "$clean_json" >"$test_root/expected.json"
cmp "$test_root/expected.json" "$out_file" \
  || fail 'stdout must carry the clean textlint JSON verbatim'

# 3. finding があれば exit 1 で、JSON はそのまま stdout へ出る
npx_stdout="$finding_json"
npx_exit=1
run_lint /dev/null "$input_file"
[[ "$status" -eq 1 ]] || fail "expected exit 1 for findings, got $status"
printf '%s\n' "$finding_json" >"$test_root/expected.json"
cmp "$test_root/expected.json" "$out_file" \
  || fail 'stdout must carry the finding textlint JSON verbatim'

# 4. stdin 形態でも file 形態と同じ結果になる
npx_stdout="$finding_json"
npx_exit=1
run_lint "$body_file"
[[ "$status" -eq 1 ]] || fail "expected exit 1 for stdin findings, got $status"
cmp "$test_root/expected.json" "$out_file" \
  || fail 'stdin mode stdout must match file mode'
cmp "$body_file" "$npx_input" \
  || fail 'stdin mode did not pass the body through to textlint verbatim'

npx_stdout="[]"
npx_exit=0
run_lint "$body_file"
[[ "$status" -eq 0 ]] || fail "expected exit 0 for clean stdin lint, got $status"

# 5. 前提エラー・使い方の誤りは exit 2 で、`meiseki-lint: ` の 1 行を stderr へ
assert_precondition_error() {
  local label="$1"
  [[ "$status" -eq 2 ]] || fail "expected exit 2 for $label, got $status"
  [[ ! -s "$out_file" ]] || fail "stdout must stay empty for $label"
  grep -q '^meiseki-lint: ' "$err_file" \
    || fail "missing 'meiseki-lint: ' diagnostic for $label"
  [[ "$(wc -l <"$err_file")" -eq 1 ]] \
    || fail "diagnostic must be a single line for $label"
}

# textlint を走らせたあとの失敗では、textlint 自身の stderr も呼び出し元へ
# 通す (行数は数えず、判定と診断だけを見る)
assert_unusable_output() {
  local label="$1"
  [[ "$status" -eq 2 ]] || fail "expected exit 2 for $label, got $status"
  [[ ! -s "$out_file" ]] || fail "stdout must stay empty for $label"
  grep -q '^meiseki-lint: ' "$err_file" \
    || fail "missing 'meiseki-lint: ' diagnostic for $label"
}

# textlint が JSON でない何かを吐いた (finding ありと混同しない)
npx_stdout="npm ERR! could not determine executable to run"
npx_exit=1
run_lint /dev/null "$input_file"
assert_unusable_output 'broken textlint output'

# npx が起動できたが何も返さない
npx_stdout=""
npx_exit=127
run_lint /dev/null "$input_file"
assert_unusable_output 'npx produced no output'
npx_stdout="[]"
npx_exit=0

# npx がそもそも入っていない
mv "$fnm_bin/npx" "$fnm_bin/npx.bak"
run_lint /dev/null "$input_file"
assert_precondition_error 'missing npx'
mv "$fnm_bin/npx.bak" "$fnm_bin/npx"

# meiseki が未導入 (textlint config が無い)
mv "$config_file" "$config_file.bak"
run_lint /dev/null "$input_file"
[[ ! -e "$npx_args" ]] || fail 'textlint must not run without the meiseki config'
assert_precondition_error 'meiseki not installed'
mv "$config_file.bak" "$config_file"

# 読めないファイル
run_lint /dev/null "$test_root/no-such-file.md"
[[ ! -e "$npx_args" ]] || fail 'textlint must not run for a missing file'
assert_precondition_error 'missing file'

# 引数が 2 個以上
run_lint /dev/null "$input_file" "$input_file"
[[ ! -e "$npx_args" ]] || fail 'textlint must not run for too many arguments'
assert_precondition_error 'too many arguments'

# 未知の option
run_lint /dev/null --bogus
[[ ! -e "$npx_args" ]] || fail 'textlint must not run for an unknown option'
assert_precondition_error 'unknown option'

# 空入力
run_lint /dev/null
[[ ! -e "$npx_args" ]] || fail 'textlint must not run for empty input'
assert_precondition_error 'empty stdin'

# --help は usage を stderr に出し、textlint を起動しない (stdout は空)
run_lint /dev/null --help
[[ "$status" -eq 2 ]] || fail "expected exit 2 for --help, got $status"
[[ ! -e "$npx_args" ]] || fail 'textlint must not run for --help'
[[ ! -s "$out_file" ]] || fail 'usage must not write to stdout'
grep -q '^usage: meiseki-lint ' "$err_file" || fail 'missing usage line for --help'

echo "meiseki-lint test: pass"
