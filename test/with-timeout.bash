#!/usr/bin/env bash
# Contract: with-timeout は「実行を秒数で打ち切る」を 1 つだけやる。
# timeout(1) が使えるならそれを使い、gtimeout、どちらも無ければ perl へ落ちる。
# どの経路でも観測できる挙動は同じ — 時間切れは 124、それ以外は子の exit code
# をそのまま返し、stdin と引数は素通しする。
# PATH を組み替えて各経路を実測するので、本物の timeout の有無に依存しない。
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
with_timeout="$repo_root/agent/common/bin/with-timeout"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

# 経路を選ぶための PATH。base には perl と、子として動かす実行ファイルだけを
# 置く。timeout / gtimeout は case ごとに stub を足して生やす。
base_bin="$test_root/base-bin"
mkdir -p "$base_bin"
for tool in perl bash env cat sleep; do
  tool_path="$(command -v "$tool")" || { echo "missing tool: $tool" >&2; exit 1; }
  ln -s "$tool_path" "$base_bin/$tool"
done

args_log="$test_root/args.log"
stdin_capture="$test_root/stdin.txt"
out_file="$test_root/stdout.txt"
err_file="$test_root/stderr.txt"
prompt_file="$test_root/prompt.txt"

cat >"$prompt_file" <<'PROMPT'
標準入力は 1 byte も欠けずに子へ届く。
$HOME と `backtick` と "quote" と \backslash
PROMPT

# timeout / gtimeout の stub。受け取った引数を記録し、子は起動しない。
make_stub() {
  local name="$1" dir="$2"
  mkdir -p "$dir"
  cat >"$dir/$name" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$@" >"$args_log"
exit 7
STUB
  chmod +x "$dir/$name"
}

# 子として使う実行ファイル: stdin を落とし、指定秒 sleep し、指定 code で終わる。
child="$test_root/child"
cat >"$child" <<CHILD
#!/usr/bin/env bash
cat >"$stdin_capture"
[[ -n "\${CHILD_SLEEP:-}" ]] && sleep "\$CHILD_SLEEP"
exit "\${CHILD_EXIT:-0}"
CHILD
chmod +x "$child"

status=0
run() {
  local path="$1"
  shift
  rm -f "$args_log" "$stdin_capture"
  set +e
  PATH="$path" "$with_timeout" "$@" <"$prompt_file" >"$out_file" 2>"$err_file"
  status=$?
  set -e
}

fail() {
  echo "with-timeout test: $1" >&2
  echo "--- stderr ---" >&2
  cat "$err_file" >&2 2>/dev/null || true
  exit 1
}

# 1. timeout(1) があるときは真っ先にそれへ委譲する (引数も exit code も素通し)
timeout_bin="$test_root/timeout-bin"
make_stub timeout "$timeout_bin"
run "$timeout_bin:$base_bin" 3 "$child" alpha
[[ "$status" -eq 7 ]] || fail "expected the stub's exit 7, got $status"
[[ "$(cat "$args_log")" == "$(printf '3\n%s\nalpha' "$child")" ]] \
  || fail "timeout stub received: $(cat "$args_log")"

# 2. timeout が無く gtimeout があるときは gtimeout へ委譲する
gtimeout_bin="$test_root/gtimeout-bin"
make_stub gtimeout "$gtimeout_bin"
run "$gtimeout_bin:$base_bin" 3 "$child" beta
[[ "$status" -eq 7 ]] || fail "expected the stub's exit 7, got $status"
[[ "$(cat "$args_log")" == "$(printf '3\n%s\nbeta' "$child")" ]] \
  || fail "gtimeout stub received: $(cat "$args_log")"

# 3. どちらも無ければ perl 経路。時間内に終われば子の exit code を透過し、
#    stdin は 1 byte も欠けずに子へ届く
CHILD_EXIT=5 run "$base_bin" 30 "$child"
[[ "$status" -eq 5 ]] || fail "expected the child's exit 5, got $status"
cmp "$prompt_file" "$stdin_capture" || fail 'stdin was not passed through verbatim'
# 呼び出し側は子の stderr をログとして読む。打ち切り機構が黙っていること。
[[ ! -s "$err_file" ]] || fail "perl path must not write to stderr: $(cat "$err_file")"

# 4. perl 経路の時間切れは 124
CHILD_SLEEP=30 run "$base_bin" 1 "$child"
[[ "$status" -eq 124 ]] || fail "expected 124 on timeout, got $status"

# 5. perl 経路で signal 死した子は 128+signal になる
killer="$test_root/killer"
cat >"$killer" <<'KILLER'
#!/usr/bin/env bash
kill -TERM $$
KILLER
chmod +x "$killer"
run "$base_bin" 30 "$killer"
[[ "$status" -eq 143 ]] || fail "expected 143 for SIGTERM, got $status"

# 6. 時間切れは子が起動した孫まで道連れにする。GNU timeout の既定は子を
#    専用のプロセスグループへ入れてグループごと signal するので、perl 経路も
#    そこへ揃える。直接の子だけを kill すると孫が居座り、出力 FD を握ったまま
#    残るため呼び出し側が実質的に打ち切れない。
spawner="$test_root/spawner"
grandchild_pid_file="$test_root/grandchild.pid"
cat >"$spawner" <<SPAWNER
#!/usr/bin/env bash
sleep 30 &
echo \$! >"$grandchild_pid_file"
wait
SPAWNER
chmod +x "$spawner"
rm -f "$grandchild_pid_file"
run "$base_bin" 1 "$spawner"
[[ "$status" -eq 124 ]] || fail "expected 124 on timeout, got $status"
[[ -s "$grandchild_pid_file" ]] || fail 'spawner did not record the grandchild pid'
grandchild_pid="$(cat "$grandchild_pid_file")"
if kill -0 "$grandchild_pid" 2>/dev/null; then
  kill -KILL "$grandchild_pid" 2>/dev/null || true
  fail "grandchild $grandchild_pid survived the timeout"
fi

# 孫が出力 FD を握ったままだと、呼び出し側の読み手に EOF が来ない。ファイルへ
# のリダイレクトでは観測できないので、pipe で読み切れるところまで測る。
eof_marker="$test_root/eof.done"
rm -f "$eof_marker" "$grandchild_pid_file"
(
  PATH="$base_bin" "$with_timeout" 1 "$spawner" 2>/dev/null | cat >/dev/null || true
  : >"$eof_marker"
) &
reader_pid=$!
for _ in $(seq 1 100); do
  [[ -e "$eof_marker" ]] && break
  sleep 0.1
done
if [[ ! -e "$eof_marker" ]]; then
  kill -KILL "$reader_pid" 2>/dev/null || true
  if [[ -s "$grandchild_pid_file" ]]; then
    kill -KILL "$(cat "$grandchild_pid_file")" 2>/dev/null || true
  fi
  fail 'stdout pipe never reached EOF after the timeout'
fi
wait "$reader_pid" 2>/dev/null || true

# 7. 使い方の誤りは exit 2 で、子を一切起動しない
assert_usage_error() {
  run "$base_bin" "$@"
  [[ "$status" -eq 2 ]] || fail "expected exit 2 for [$*], got $status"
  [[ ! -e "$stdin_capture" ]] || fail "child must not run for [$*]"
  grep -q '^with-timeout: ' "$err_file" || fail "missing diagnostic for [$*]"
}

assert_usage_error
assert_usage_error 3
assert_usage_error 0 "$child"
assert_usage_error abc "$child"

# 8. install が ~/.local/bin へ配布し、script は実行可能である
grep -Fq 'link "agent/common/bin/with-timeout" "$HOME/.local/bin"' "$repo_root/bin/install" \
  || fail 'bin/install must link with-timeout into ~/.local/bin'
[[ -x "$with_timeout" ]] || fail 'agent/common/bin/with-timeout must be executable'

echo "with-timeout test: pass"
