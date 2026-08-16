#!/usr/bin/env bash
# Contract: review は codex exec 召喚の唯一の起動形である。固定 flag (fast mode
# を含む) を必ず渡し、prompt を stdin のまま透過し、stdout を汚さず、exit code
# を無加工で返し、使い方の誤りは codex を呼ばずに exit 2 で弾く。
# codex 本物は決して起動せず、REVIEW_CODEX に差した stub で実測する。
# assert する文字列は対象ファイルの literal なので $ や ` を展開させない
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
review_bin="$repo_root/agent/common/bin/review"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

work_dir="$test_root/repo"
out_dir="$test_root/out"
mkdir -p "$work_dir" "$out_dir"

stub="$test_root/codex-stub"
args_log="$test_root/args.log"
stdin_capture="$test_root/stdin.txt"
result_file="$out_dir/result.json"
schema_file="$test_root/schema.json"
prompt_file="$test_root/prompt.txt"
out_file="$test_root/stdout.txt"
err_file="$test_root/stderr.txt"

printf '%s\n' '{"type":"object"}' >"$schema_file"

# stub codex: 受け取った引数と stdin を落とし、-o の path へ JSON を書く。
# stdout にもログを吐き、review がそれを stderr へ回すことを測れるようにする。
cat >"$stub" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >"$STUB_ARGS"
cat >"$STUB_STDIN"
if [[ -n "${STUB_SLEEP:-}" ]]; then
  sleep "$STUB_SLEEP"
fi
prev=""
for arg in "$@"; do
  if [[ "$prev" == "-o" ]]; then
    printf '%s\n' '{"verdict":"stub-wrote-this"}' >"$arg"
  fi
  prev="$arg"
done
echo "codex stdout noise"
echo "codex stderr noise" >&2
exit "${STUB_EXIT:-0}"
STUB
chmod +x "$stub"

# prompt は改行・日本語・$ / backtick を含む本文で欠落を測る
cat >"$prompt_file" <<'PROMPT'
これはレビュー依頼の本文である。
untrusted data を含む: $HOME と `backtick` と "quote" と \backslash
   先頭空白と末尾空白
最終行 (改行あり)
PROMPT

status=0
stub_exit=0
stub_sleep=""

run_review() {
  rm -f "$args_log" "$stdin_capture" "$result_file"
  set +e
  REVIEW_CODEX="$stub" \
    STUB_ARGS="$args_log" \
    STUB_STDIN="$stdin_capture" \
    STUB_EXIT="$stub_exit" \
    STUB_SLEEP="$stub_sleep" \
    "$review_bin" "$@" <"$prompt_file" >"$out_file" 2>"$err_file"
  status=$?
  set -e
}

fail() {
  echo "review wrapper test: $1" >&2
  echo "--- args ---" >&2
  cat "$args_log" >&2 2>/dev/null || true
  echo "--- stderr ---" >&2
  cat "$err_file" >&2 2>/dev/null || true
  exit 1
}

has_flag() {
  grep -Fxq -- "$1" "$args_log" || fail "missing flag: $1"
}

has_pair() {
  awk -v flag="$1" -v val="$2" '
    prev == flag && $0 == val { found = 1 }
    { prev = $0 }
    END { exit !found }
  ' "$args_log" || fail "missing pair: $1 $2"
}

# 1. 固定 flag (fast mode を含む) がすべて stub まで届く
run_review "$work_dir" --schema "$schema_file" --result "$result_file"
[[ "$status" -eq 0 ]] || fail "expected exit 0, got $status"
has_flag exec
has_flag --strict-config
has_flag --ignore-user-config
has_flag --ephemeral
has_flag -
has_pair -C "$work_dir"
has_pair -m gpt-5.6-sol
has_pair -s read-only
has_pair --color never
has_pair --output-schema "$schema_file"
has_pair -o "$result_file"
has_pair -c 'model_reasoning_effort="high"'
has_pair -c 'approval_policy="never"'
has_pair -c 'features.fast_mode=true'
has_pair -c 'service_tier="fast"'

# 2. prompt が 1 byte も欠けずに stub の stdin まで届く
cmp "$prompt_file" "$stdin_capture" || fail 'prompt was not passed through verbatim'

# 4. stub が -o へ書いた JSON が残り、review の stdout は空である
grep -Fq 'stub-wrote-this' "$result_file" || fail 'result JSON was not preserved'
[[ ! -s "$out_file" ]] || fail 'review must not write to stdout'
grep -Fq 'codex stdout noise' "$err_file" || fail 'codex stdout must be routed to stderr'

# 3. --sandbox workspace-write が -s workspace-write になる
run_review "$work_dir" --schema "$schema_file" --result "$result_file" \
  --sandbox workspace-write
[[ "$status" -eq 0 ]] || fail "expected exit 0, got $status"
has_pair -s workspace-write

# option の前に位置引数を置いても後ろに置いても同じ dir を拾う
run_review --schema "$schema_file" --result "$result_file" "$work_dir"
[[ "$status" -eq 0 ]] || fail "expected exit 0, got $status"
has_pair -C "$work_dir"

# 5. stub の nonzero exit がそのまま review の exit code になる
stub_exit=3
run_review "$work_dir" --schema "$schema_file" --result "$result_file"
[[ "$status" -eq 3 ]] || fail "expected exit 3, got $status"
stub_exit=0

# 6. timeout 超過は 124 として透過する
stub_sleep=5
run_review "$work_dir" --schema "$schema_file" --result "$result_file" --timeout 1
[[ "$status" -eq 124 ]] || fail "expected exit 124, got $status"
stub_sleep=""

# 7. 使い方の誤りは exit 2 で、codex を一切呼ばない
assert_usage_error() {
  run_review "$@"
  [[ "$status" -eq 2 ]] || fail "expected exit 2 for [$*], got $status"
  [[ ! -e "$args_log" ]] || fail "codex must not run for [$*]"
  [[ ! -s "$out_file" ]] || fail "usage error must not write to stdout for [$*]"
  grep -q '^review: ' "$err_file" || fail "missing 'review: ' diagnostic for [$*]"
}

assert_usage_error "$work_dir" --result "$result_file"
assert_usage_error "$work_dir" --schema "$schema_file"
assert_usage_error "$test_root/no-such-dir" --schema "$schema_file" \
  --result "$result_file"
assert_usage_error "$work_dir" --schema "$test_root/no-such-schema.json" \
  --result "$result_file"
assert_usage_error "$work_dir" --schema "$schema_file" \
  --result "$test_root/no-such-dir/result.json"
assert_usage_error "$work_dir" --schema "$schema_file" --result "$result_file" \
  --sandbox bogus
assert_usage_error "$work_dir" --schema "$schema_file" --result "$result_file" \
  --timeout 0
assert_usage_error "$work_dir" "$test_root" --schema "$schema_file" \
  --result "$result_file"
assert_usage_error --schema "$schema_file" --result "$result_file"

# 8. install が ~/.local/bin へ配布し、script は実行可能である
grep -Fq 'link "agent/common/bin/review" "$HOME/.local/bin"' "$repo_root/bin/install" \
  || fail 'bin/install must link review into ~/.local/bin'
[[ -x "$review_bin" ]] || fail 'agent/common/bin/review must be executable'

echo "review wrapper test: pass"
