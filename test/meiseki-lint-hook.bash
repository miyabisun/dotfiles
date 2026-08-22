#!/usr/bin/env bash
# Contract: Edit|Write の PostToolUse hook は、編集された file が *.md のときだけ
# meiseki-lint をその 1 ファイルへ掛ける。finding は編集した agent が読める形で
# additionalContext に載せ、rc=2 や起動不能は「lint 未実行」として clean と
# 区別できる形で返す。hook 自身は advisory なので常に exit 0 で、出力がある
# ときは必ず妥当な JSON である。
# 本物の meiseki-lint / npx / network は決して呼ばず、MEISEKI_LINT の stub で実測する。
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hook="$repo_root/agent/claude/hooks/meiseki-lint-markdown.sh"
settings="$repo_root/agent/claude/settings.json"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fake_home="$test_root/home"
stub="$test_root/meiseki-lint-stub"
args_log="$test_root/args.log"
call_log="$test_root/calls.log"
out_file="$test_root/stdout.txt"
err_file="$test_root/stderr.txt"
mkdir -p "$fake_home"

# meiseki-lint stub: 呼ばれた回数と引数を落とし、指定の stdout / exit code を返す。
cat >"$stub" <<'STUB'
#!/usr/bin/env bash
printf 'call\n' >>"$STUB_CALLS"
printf 'argc=%s\n' "$#" >>"$STUB_ARGS"
for arg in "$@"; do printf 'arg=%s\n' "$arg" >>"$STUB_ARGS"; done
[[ -z "${STUB_STDOUT:-}" ]] || printf '%s\n' "$STUB_STDOUT"
exit "${STUB_EXIT:-0}"
STUB
chmod +x "$stub"

status=0
stub_stdout=""
stub_exit=0
lint_bin="$stub"

fail() {
  echo "meiseki-lint-hook test: $1" >&2
  echo "--- stub args ---" >&2
  cat "$args_log" >&2 2>/dev/null || true
  echo "--- hook stdout ---" >&2
  cat "$out_file" >&2 2>/dev/null || true
  echo "--- hook stderr ---" >&2
  cat "$err_file" >&2 2>/dev/null || true
  exit 1
}

run_hook() {
  local payload="$1"
  : >"$args_log"
  : >"$call_log"
  set +e
  printf '%s' "$payload" \
    | HOME="$fake_home" \
      MEISEKI_LINT="$lint_bin" \
      STUB_CALLS="$call_log" \
      STUB_ARGS="$args_log" \
      STUB_STDOUT="$stub_stdout" \
      STUB_EXIT="$stub_exit" \
      bash "$hook" >"$out_file" 2>"$err_file"
  status=$?
  set -e
  [[ "$status" -eq 0 ]] || fail "hook must always exit 0, got $status"
}

payload_for() {
  jq -n --arg path "$1" '{tool_name:"Edit",tool_input:{file_path:$path}}'
}

call_count() { grep -c '^call$' "$call_log" || true; }

assert_not_called() {
  local label="$1"
  [[ "$(call_count)" -eq 0 ]] || fail "meiseki-lint must not run for $label"
  [[ ! -s "$out_file" ]] || fail "output must stay empty for $label"
}

assert_called_once_with() {
  local expected="$1" label="$2"
  [[ "$(call_count)" -eq 1 ]] \
    || fail "expected exactly one meiseki-lint call for $label, got $(call_count)"
  grep -Fxq 'argc=1' "$args_log" \
    || fail "path must reach meiseki-lint as a single argument for $label"
  local got
  got="$(sed -n 's/^arg=//p' "$args_log")"
  [[ "$got" == "$expected" ]] \
    || fail "expected argument [$expected] for $label, got [$got]"
}

context_of() {
  jq -er '.hookSpecificOutput
    | select(.hookEventName == "PostToolUse")
    | .additionalContext' "$out_file"
}

# 1. *.md 以外は meiseki-lint を起動しない (出力も無い)
stub_exit=0
stub_stdout=""
for other in "$test_root/main.rs" "$test_root/notes.txt" "$test_root/README" \
  "$test_root/not-markdown.mdx" "$test_root/dir.md/file.rs"; do
  run_hook "$(payload_for "$other")"
  assert_not_called "$other"
done

# 2. file_path が空・欠落でも起動しない
run_hook "$(payload_for '')"
assert_not_called 'an empty file_path'
run_hook '{"tool_name":"Edit","tool_input":{}}'
assert_not_called 'a missing file_path'

# 3. *.md は 1 回だけ、その path を 1 引数として受け取る
md_file="$test_root/doc.md"
run_hook "$(payload_for "$md_file")"
assert_called_once_with "$md_file" 'a markdown file'

# 4. rc=0 (clean) は無出力
[[ ! -s "$out_file" ]] || fail 'a clean lint must produce no output'

# 5. rc=1 は path・行・ruleId・message を additionalContext に載せる。
# meiseki-lint は本文を temp へ写して textlint に掛けるため、JSON の filePath は
# 編集された file ではない。報告する path は hook が知る編集対象でなければならない。
finding_json="$(jq -c -n '[{
  filePath: "/tmp/meiseki-work/input.md",
  messages: [
    {ruleId:"ja-no-redundant-expression",message:"冗長な表現である",line:12,column:3},
    {ruleId:"ja-no-weak-phrase",message:"弱い表現",line:20,column:1}
  ]
}]')"
stub_stdout="$finding_json"
stub_exit=1
run_hook "$(payload_for "$md_file")"
assert_called_once_with "$md_file" 'a markdown file with findings'
jq -e . "$out_file" >/dev/null || fail 'finding output must be valid JSON'
finding_context="$(context_of)" || fail 'finding output must carry additionalContext'
for needle in "$md_file" "12" "ja-no-redundant-expression" "冗長な表現である" \
  "20" "ja-no-weak-phrase" "弱い表現"; do
  grep -Fq -- "$needle" <<<"$finding_context" \
    || fail "additionalContext must mention [$needle]"
done
if grep -Fq -- '/tmp/meiseki-work/input.md' <<<"$finding_context"; then
  fail 'additionalContext must report the edited path, not the lint work path'
fi

# 6. message に改行・引用符・backslash が混ざっても JSON は壊れない
nasty_json="$(jq -c -n '[{
  filePath: "input.md",
  messages: [{
    ruleId: "ja-technical-writing/sentence-length",
    message: "壊し文字: \"quote\" と \\backslash と\n改行 と `backtick`",
    line: 1,
    column: 1
  }]
}]')"
stub_stdout="$nasty_json"
stub_exit=1
run_hook "$(payload_for "$md_file")"
jq -e . "$out_file" >/dev/null || fail 'output must stay valid JSON for nasty messages'
nasty_context="$(context_of)" || fail 'nasty output must carry additionalContext'
grep -Fq -- '"quote"' <<<"$nasty_context" || fail 'quote in message was lost'
grep -Fq -- '\backslash' <<<"$nasty_context" || fail 'backslash in message was lost'
grep -Fq -- '改行' <<<"$nasty_context" || fail 'newline part of message was lost'

# 7. rc=2 は「lint 未実行」として返る (clean と区別できる)
stub_stdout=""
stub_exit=2
run_hook "$(payload_for "$md_file")"
jq -e . "$out_file" >/dev/null || fail 'rc=2 output must be valid JSON'
unrun_context="$(context_of)" || fail 'rc=2 output must carry additionalContext'
grep -Fq -- '未実行' <<<"$unrun_context" \
  || fail 'rc=2 must be reported as "lint 未実行", not as clean'

# 8. 起動不能 (実行ファイルが無い) も同じ「未実行」経路
lint_bin="$test_root/no-such-meiseki-lint"
run_hook "$(payload_for "$md_file")"
jq -e . "$out_file" >/dev/null || fail 'a missing lint binary must produce valid JSON'
missing_context="$(context_of)" || fail 'missing binary must carry additionalContext'
grep -Fq -- '未実行' <<<"$missing_context" \
  || fail 'a missing lint binary must be reported as "lint 未実行"'
lint_bin="$stub"

# 9. 空白・記号・日本語を含む path も 1 引数のまま届く
stub_stdout=""
stub_exit=0
for weird in "$test_root/with space.md" "$test_root/日本語 名前.md" \
  "$test_root/quote'and\"sym.md" "$test_root/dollar \$HOME & semi;.md"; do
  run_hook "$(payload_for "$weird")"
  assert_called_once_with "$weird" 'a path with spaces or symbols'
done

# 10. settings.json が Edit|Write の PostToolUse としてこの hook を配線している
jq -e '[.hooks.PostToolUse[]
  | select(.matcher == "Edit|Write")
  | .hooks[]
  | select(.command == "bash \"$HOME/.claude/hooks/meiseki-lint-markdown.sh\"")
  | select(.timeout >= 30)] | length == 1' "$settings" >/dev/null \
  || fail 'settings.json must wire the markdown lint hook on Edit|Write with a timeout'

echo "meiseki-lint-hook test: pass"
