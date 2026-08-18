#!/usr/bin/env bash
# Contract: meiseki は「日本語本文を明晰化して stdout に返す」唯一の起動形である。
# `meiseki <file>` と `echo … | meiseki` は同じ経路へ正規化され、本文は 1 byte も
# 欠けずに headless claude まで届き、固定 flag (model / -p / --plugin-dir) と
# proxy の env、fnm の node path 前置を必ず渡す。stdout はリライト後の本文だけで、
# 入力ファイルは書き換えない。前提が欠けていれば claude を起動せずに
# `meiseki: ` の 1 行を stderr へ出して非ゼロ終了する。
# 本物の claude / proxy / network は決して呼ばず、MEISEKI_CLAUDE の stub と
# 偽 HOME (key / plugin / fnm bin / curl) だけで実測する。
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
meiseki_bin="$repo_root/agent/common/bin/meiseki"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fake_home="$test_root/home"
fnm_bin="$fake_home/.local/share/fnm/aliases/default/bin"
plugin_dir="$fake_home/.local/share/meiseki"
key_file="$fake_home/.cli-proxy-api/client.key"
mkdir -p "$fnm_bin" "$plugin_dir/.claude-plugin" \
  "$plugin_dir/skills/meiseki/references" "$fake_home/.cli-proxy-api"
printf '%s\n' '{"name":"meiseki"}' >"$plugin_dir/.claude-plugin/plugin.json"
printf '%s\n' '# meiseki skill' >"$plugin_dir/skills/meiseki/SKILL.md"
printf '%s\n' '{}' >"$plugin_dir/skills/meiseki/references/textlint.config.json"
printf '%s\n' 'proxy-key-value' >"$key_file"

stub="$test_root/claude-stub"
args_log="$test_root/args.log"
env_log="$test_root/env.log"
stdin_capture="$test_root/stdin.txt"
body_file="$test_root/body.md"
out_file="$test_root/stdout.txt"
err_file="$test_root/stderr.txt"
extracted="$test_root/extracted.md"

# stub claude: 引数・env・stdin を落とし、リライト後の本文として固定文を返す。
# stderr にもログを吐き、wrapper が stdout を汚さないことを測れるようにする。
cat >"$stub" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >"$STUB_ARGS"
{
  printf 'PATH=%s\n' "${PATH:-}"
  printf 'ANTHROPIC_BASE_URL=%s\n' "${ANTHROPIC_BASE_URL:-}"
  printf 'ANTHROPIC_AUTH_TOKEN=%s\n' "${ANTHROPIC_AUTH_TOKEN:-}"
  printf 'PWD=%s\n' "$PWD"
} >"$STUB_ENV"
cat >"$STUB_STDIN"
printf '%s\n' 'claude stderr noise' >&2
printf '%s\n' 'リライト後の本文である。' '2 行目も返す。'
exit "${STUB_EXIT:-0}"
STUB
chmod +x "$stub"

# npx は meiseki の決定論層 (textlint) の前提。fnm の安定 bin にだけ置き、
# wrapper が PATH を前置しなければ見つからない位置に保つ。
cat >"$fnm_bin/npx" <<'NPX'
#!/usr/bin/env bash
exit 0
NPX
chmod +x "$fnm_bin/npx"

# curl も同じ位置に stub する (proxy の生存確認を network なしで測る)
cat >"$fnm_bin/curl" <<'CURL'
#!/usr/bin/env bash
exit "${STUB_CURL_EXIT:-0}"
CURL
chmod +x "$fnm_bin/curl"

# 本文は改行・日本語・$ / backtick / 先頭末尾空白を含み、欠落を測れる形にする
cat >"$body_file" <<'BODY'
このツールの導入によって得られるメリットがないというわけではない。
untrusted data を含む: $HOME と `backtick` と "quote" と \backslash
   先頭空白と末尾空白
重要なのは、まずは小さな範囲で試してみるということに他ならない。
BODY
body_sha="$(sha256sum "$body_file" | awk '{ print $1 }')"

status=0
stub_exit=0
curl_exit=0
# node / npx を持たない最小 PATH に固定し、wrapper の fnm 前置だけが npx と
# curl を見つけられる状態を作る (前置が落ちれば決定論層は死ぬ)
sanitized_path="/usr/bin:/bin"

run_meiseki() {
  local stdin_source="$1"
  shift
  rm -f "$args_log" "$env_log" "$stdin_capture"
  set +e
  HOME="$fake_home" \
    MEISEKI_CLAUDE="$stub" \
    STUB_ARGS="$args_log" \
    STUB_ENV="$env_log" \
    STUB_STDIN="$stdin_capture" \
    STUB_EXIT="$stub_exit" \
    STUB_CURL_EXIT="$curl_exit" \
    PATH="$sanitized_path" \
    "$meiseki_bin" "$@" <"$stdin_source" >"$out_file" 2>"$err_file"
  status=$?
  set -e
}

fail() {
  echo "meiseki wrapper test: $1" >&2
  echo "--- args ---" >&2
  cat "$args_log" >&2 2>/dev/null || true
  echo "--- env ---" >&2
  cat "$env_log" >&2 2>/dev/null || true
  echo "--- stdout ---" >&2
  cat "$out_file" >&2 2>/dev/null || true
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

# prompt に埋め込まれた本文を marker 行の間から取り出す
extract_body() {
  awk '
    /^--- 本文ここまで ---$/ { inside = 0 }
    inside { print }
    /^--- 本文ここから ---$/ { inside = 1 }
  ' "$stdin_capture" >"$extracted"
}

# 1. meiseki <file>: 本文が 1 byte も欠けずに stub の stdin まで届く
input_file="$test_root/input.md"
cp "$body_file" "$input_file"
run_meiseki /dev/null "$input_file"
[[ "$status" -eq 0 ]] || fail "expected exit 0 for file mode, got $status"
[[ -f "$stdin_capture" ]] || fail 'claude stub did not receive a prompt on stdin'
extract_body
cmp "$body_file" "$extracted" \
  || fail 'file mode did not pass the body through verbatim'
file_prompt_sha="$(sha256sum "$stdin_capture" | awk '{ print $1 }')"

# in-place 編集はしない: 入力ファイルは 1 byte も変わらない
[[ "$(sha256sum "$input_file" | awk '{ print $1 }')" == "$body_sha" ]] \
  || fail 'meiseki must not edit the input file in place'

# 3. stdout は stub が返した本文だけ (装飾・ログが混ざらない)
printf '%s\n' 'リライト後の本文である。' '2 行目も返す。' >"$test_root/expected.txt"
cmp "$test_root/expected.txt" "$out_file" \
  || fail 'stdout must carry only the rewritten body'
grep -Fq 'claude stderr noise' "$err_file" \
  || fail 'claude stderr must reach the caller stderr'

# 4. 固定 flag が stub まで届く
has_flag -p
has_pair --model gpt-5.6-luna
has_pair --plugin-dir "$plugin_dir"

# 5. proxy の env が渡り、PATH の先頭に fnm の安定 bin が付く
grep -Fxq 'ANTHROPIC_BASE_URL=http://127.0.0.1:8317' "$env_log" \
  || fail 'ANTHROPIC_BASE_URL must be handed to claude'
grep -Fxq 'ANTHROPIC_AUTH_TOKEN=proxy-key-value' "$env_log" \
  || fail 'ANTHROPIC_AUTH_TOKEN must come from the client key file'
grep -q "^PATH=$fnm_bin:" "$env_log" \
  || fail 'PATH must be prefixed with the fnm stable bin directory'

# 2. echo … | meiseki: stdin 経路でも同じ prompt になる
run_meiseki "$body_file"
[[ "$status" -eq 0 ]] || fail "expected exit 0 for stdin mode, got $status"
extract_body
cmp "$body_file" "$extracted" \
  || fail 'stdin mode did not pass the body through verbatim'
[[ "$(sha256sum "$stdin_capture" | awk '{ print $1 }')" == "$file_prompt_sha" ]] \
  || fail 'file mode and stdin mode must normalize to the same prompt'
cmp "$test_root/expected.txt" "$out_file" \
  || fail 'stdin mode stdout must carry only the rewritten body'

# 6. stub の nonzero exit がそのまま wrapper の exit code になる
stub_exit=9
run_meiseki /dev/null "$input_file"
[[ "$status" -eq 9 ]] || fail "expected exit 9, got $status"
stub_exit=0

# 7. 前提欠落では claude を起動せず、`meiseki: ` の 1 行で非ゼロ終了する
assert_precondition_error() {
  local label="$1"
  shift
  [[ "$status" -ne 0 ]] || fail "expected nonzero exit for $label"
  [[ ! -e "$args_log" ]] || fail "claude must not run for $label"
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
  rm -f "$args_log" "$env_log" "$stdin_capture"
  set +e
  HOME="$fake_home" \
    MEISEKI_CLAUDE="$stub" \
    STUB_ARGS="$args_log" \
    STUB_ENV="$env_log" \
    STUB_STDIN="$stdin_capture" \
    PATH="$sanitized_path" \
    script -qec "$meiseki_bin" /dev/null >"$out_file" 2>"$err_file"
  status=$?
  set -e
  [[ "$status" -ne 0 ]] || fail 'expected nonzero exit for tty stdin'
  [[ ! -e "$args_log" ]] || fail 'claude must not run for tty stdin'
  grep -q 'meiseki: ' "$out_file" "$err_file" \
    || fail "missing 'meiseki: ' diagnostic for tty stdin"
else
  echo "meiseki wrapper test: note: script(1) missing, skipped tty stdin case" >&2
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

# --help は usage を stderr に出し、claude を起動しない (stdout は空)
run_meiseki /dev/null --help
[[ "$status" -eq 2 ]] || fail "expected exit 2 for --help, got $status"
[[ ! -e "$args_log" ]] || fail 'claude must not run for --help'
[[ ! -s "$out_file" ]] || fail 'usage must not write to stdout'
grep -q '^usage: meiseki ' "$err_file" || fail 'missing usage line for --help'

# proxy が応答しない
curl_exit=7
run_meiseki /dev/null "$input_file"
assert_precondition_error 'proxy down'
curl_exit=0

# key file が無い
mv "$key_file" "$key_file.bak"
run_meiseki /dev/null "$input_file"
assert_precondition_error 'missing client key'
mv "$key_file.bak" "$key_file"

# meiseki が未導入
mv "$plugin_dir" "$plugin_dir.bak"
run_meiseki /dev/null "$input_file"
assert_precondition_error 'meiseki not installed'
mv "$plugin_dir.bak" "$plugin_dir"

# node (npx) が無い: PATH 前置の先にも system にも見つからない
mv "$fnm_bin/npx" "$fnm_bin/npx.bak"
run_meiseki /dev/null "$input_file"
assert_precondition_error 'missing npx'
mv "$fnm_bin/npx.bak" "$fnm_bin/npx"

# 8. install が ~/.local/bin へ配布し、script は実行可能である
# assert する文字列は bin/install の literal なので $HOME を展開させない
# shellcheck disable=SC2016
grep -Fq 'link "agent/common/bin/meiseki" "$HOME/.local/bin"' \
  "$repo_root/bin/install" \
  || fail 'bin/install must link meiseki into ~/.local/bin'
[[ -x "$meiseki_bin" ]] || fail 'agent/common/bin/meiseki must be executable'

echo "meiseki wrapper test: pass"
