#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bw_env="$repo_root/bin/bw/bw-env"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fake_bin="$test_root/bin"
mkdir -p "$fake_bin"
export PATH="$fake_bin:$PATH"
export BW_TEST_LOG="$test_root/rbw-args.log"
export BW_TEST_FOLDER="Env Files"
export BW_TEST_ITEMS="demo"
export BW_TEST_NOTES="$test_root/notes.txt"
: > "$BW_TEST_LOG"

# rbw の代役。呼び出し引数を記録し、diff が書き込み系を呼ばないことを検証できるようにする
cat > "$fake_bin/rbw" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$BW_TEST_LOG"

case "${1:-}" in
  unlocked | unlock) exit 0 ;;
  list)
    if [ "${BW_TEST_LIST_FAIL:-0}" = 1 ]; then
      echo "fake rbw: cannot talk to the agent" >&2
      exit 1
    fi
    jq -n --arg folder "$BW_TEST_FOLDER" --arg names "$BW_TEST_ITEMS" \
      '$names | split("\n") | map(select(length > 0) | {folder: $folder, name: .})'
    ;;
  get)
    shift
    name=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --folder) shift 2 ;;
        --raw) shift ;;
        --field) shift 2 ;;
        *)
          name="$1"
          shift
          ;;
      esac
    done
    if ! printf '%s\n' "$BW_TEST_ITEMS" | grep -qxF -- "$name"; then
      echo "fake rbw: entry not found: $name" >&2
      exit 1
    fi
    jq -n --arg name "$name" --rawfile notes "$BW_TEST_NOTES" '{name: $name, notes: $notes}'
    ;;
  add | rm)
    echo "fake rbw: '$1' must not be called by a read-only command" >&2
    exit 1
    ;;
  *)
    echo "fake rbw: unexpected command: $1" >&2
    exit 1
    ;;
esac
STUB
chmod +x "$fake_bin/rbw"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_eq() { # <label> <expected> <actual>
  if [ "$2" != "$3" ]; then
    printf 'FAIL: %s\nexpected:\n%s\nactual:\n%s\n' "$1" "$2" "$3" >&2
    exit 1
  fi
}

out=""
err=""
code=0
run_diff() { # <args...>
  code=0
  out=$("$bw_env" diff "$@" 2> "$test_root/stderr.txt") || code=$?
  err=$(cat "$test_root/stderr.txt")
}

# fixture: コメント / 空行 / export 接頭辞 / 値内の '=' / 重複キー / 引用符の差
cat > "$test_root/remote.env" <<'EOF'
# stored by bw-env
PORT=3000

DATABASE_PATH=/srv/legacy/app.db
export EXPORTED=shared
URL=https://example.test/?a=1&b=2
DUPE=winner
DUPE=loser
BW_ONLY=stored-only
QUOTED="wrapped"
EOF

cat > "$test_root/local.env" <<'EOF'
  # edited by hand
PORT=3000
DATABASE_PATH=/srv/current/app.db
EXPORTED=shared
URL=https://example.test/?a=1&b=2
DUPE=winner
LOCAL_ONLY=working-copy
QUOTED=wrapped
lowercase_ok=9
EOF

base64 < "$test_root/remote.env" > "$BW_TEST_NOTES"

# 1. 既定出力は記号とキー名だけ (値を含まない) で、キー順に安定している
run_diff demo "$test_root/local.env"
assert_eq "default exit code" 1 "$code"
expected_default="- BW_ONLY
~ DATABASE_PATH
+ LOCAL_ONLY
~ QUOTED
+ lowercase_ok
# demo vs $test_root/local.env: 2 differ, 1 bitwarden-only, 2 local-only, 4 identical"
assert_eq "default output" "$expected_default" "$out"

# 2. 差分行の構造検査: 記号 + 妥当なキー名のみ
while read -r line; do
  [ -z "$line" ] && continue
  case "$line" in
    '#'*) continue ;;
  esac
  printf '%s\n' "$line" | grep -qE '^[-+~] (<withheld>|[A-Za-z_][A-Za-z0-9_]*)$' \
    || fail "unexpected line in default output: $line"
done <<< "$out"

# 3. 既定出力に値が漏れない
values_only=$(printf '%s\n' "$out" | grep -v '^#')
for value in 3000 /srv/legacy/app.db /srv/current/app.db shared \
  'https://example.test/?a=1&b=2' winner loser stored-only working-copy wrapped 9; do
  # 空値は「どの行にも一致する」ため検査対象にしない
  [ -z "$value" ] && continue
  if printf '%s\n' "$values_only" | grep -qF -- "$value"; then
    fail "value leaked into default output: $value"
  fi
done

# 4. 順序が安定している
first_run="$out"
run_diff demo "$test_root/local.env"
assert_eq "stable ordering" "$first_run" "$out"

# 5. --values で値を表示する
run_diff --values demo "$test_root/local.env"
assert_eq "--values exit code" 1 "$code"
expected_values="- BW_ONLY
    bitwarden: stored-only
~ DATABASE_PATH
    bitwarden: /srv/legacy/app.db
    local:     /srv/current/app.db
+ LOCAL_ONLY
    local:     working-copy
~ QUOTED
    bitwarden: \"wrapped\"
    local:     wrapped
+ lowercase_ok
    local:     9
# demo vs $test_root/local.env: 2 differ, 1 bitwarden-only, 2 local-only, 4 identical"
assert_eq "--values output" "$expected_values" "$out"

# 6. -v は --values の別名で、位置に依存しない
run_diff demo "$test_root/local.env" -v
assert_eq "-v exit code" 1 "$code"
assert_eq "-v output" "$expected_values" "$out"

# 7. 差分なしは exit 0 で要約だけ
run_diff demo "$test_root/remote.env"
assert_eq "identical exit code" 0 "$code"
assert_eq "identical output" \
  "# demo vs $test_root/remote.env: 0 differ, 0 bitwarden-only, 0 local-only, 7 identical" "$out"

# 8. '--' 以降はオプションとして解釈しない ('-' で始まるファイル名を渡せる)
cp "$test_root/local.env" "$test_root/-dash.env"
pushd "$test_root" > /dev/null
run_diff demo -- -dash.env
popd > /dev/null
assert_eq "-- exit code" 1 "$code"
case "$err" in
  *'unknown option'*) fail "'--' did not stop option parsing: $err" ;;
esac

# 9. ローカルファイル不在
run_diff demo "$test_root/missing.env"
assert_eq "missing file exit code" 2 "$code"
assert_eq "missing file message" "Error: env file not found at $test_root/missing.env" "$err"

# 10. item 不在 (一覧の取得は成功している)
run_diff absent "$test_root/local.env"
assert_eq "missing item exit code" 2 "$code"
assert_eq "missing item message" "Error: env 'absent' not found in 'Env Files' folder." "$err"

# 11. 一覧そのものが取れない場合は item 不在と区別する
BW_TEST_LIST_FAIL=1 run_diff demo "$test_root/local.env"
assert_eq "list failure exit code" 2 "$code"
case "$err" in
  *"Error: could not list 'Env Files' folder."*) ;;
  *) fail "list failure message not reported: $err" ;;
esac
case "$err" in
  *'not found in'*) fail "list failure misreported as a missing item: $err" ;;
esac

# 12. notes が空
: > "$BW_TEST_NOTES"
run_diff demo "$test_root/local.env"
assert_eq "empty notes exit code" 2 "$code"
case "$err" in
  *"Error: could not read env 'demo' (notes are empty or not base64)."*) ;;
  *) fail "empty notes message not reported: $err" ;;
esac

# 13. notes が base64 でない
printf 'not base64 at all !!!\n' > "$BW_TEST_NOTES"
run_diff demo "$test_root/local.env"
assert_eq "malformed notes exit code" 2 "$code"
case "$err" in
  *"Error: could not read env 'demo' (notes are empty or not base64)."*) ;;
  *) fail "malformed notes message not reported: $err" ;;
esac
base64 < "$test_root/remote.env" > "$BW_TEST_NOTES"

# 14. パーサ自体が失敗した場合を差分ありと混同しない
bad_bin="$test_root/badbin"
mkdir -p "$bad_bin"
for broken in awk sort; do
  cat > "$bad_bin/$broken" <<'STUB'
#!/usr/bin/env bash
echo "injected failure" >&2
exit 1
STUB
  chmod +x "$bad_bin/$broken"
  code=0
  out=$(PATH="$bad_bin:$PATH" "$bw_env" diff demo "$test_root/local.env" 2> "$test_root/stderr.txt") \
    || code=$?
  err=$(cat "$test_root/stderr.txt")
  assert_eq "broken $broken exit code" 2 "$code"
  case "$err" in
    *'could not parse the stored env'* | *'could not read or parse env file at'* | *'could not sort the env key list'*) ;;
    *) fail "broken $broken was not reported as an error: $err" ;;
  esac
  case "$out" in
    *' differ, '*) fail "broken $broken produced a diff report: $out" ;;
  esac
  rm -f "$bad_bin/$broken"
done
rmdir "$bad_bin"

# 15. 存在するが読めないローカルファイルを「ローカルにキーが無い」と誤読しない
if [ "$(id -u)" -ne 0 ]; then
  cp "$test_root/local.env" "$test_root/unreadable.env"
  chmod 000 "$test_root/unreadable.env"
  run_diff demo "$test_root/unreadable.env"
  assert_eq "unreadable file exit code" 2 "$code"
  # 下位 (bash のリダイレクト失敗) の stderr も残すため、包含で判定する
  case "$err" in
    *"Error: could not read or parse env file at $test_root/unreadable.env"*) ;;
    *) fail "unreadable file was not reported as an error: $err" ;;
  esac
  chmod 600 "$test_root/unreadable.env"
fi

# 16. 複数行の値: 継続行をキー行と誤認して値の断片を出力しない
cat > "$test_root/ml-remote.env" <<'EOF'
PORT=3000
PRIVATE_KEY="-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiGCwAggSjAgEAAoIBAQCstoredChunkAAAAAAAAAAAAAAA=
SecondLineOfTheStoredKeyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
-----END PRIVATE KEY-----"
AFTER_KEY=tail-value
EOF
cat > "$test_root/ml-local.env" <<'EOF'
PORT=3000
PRIVATE_KEY="-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiGCwAggSjAgEAAoIBAQCstoredChunkAAAAAAAAAAAAAAA=
SecondLineOfTheLocalKeyBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=
-----END PRIVATE KEY-----"
AFTER_KEY=tail-value
EOF
base64 < "$test_root/ml-remote.env" > "$BW_TEST_NOTES"
run_diff demo "$test_root/ml-local.env"
assert_eq "multiline exit code" 1 "$code"
assert_eq "multiline output" "~ PRIVATE_KEY
# demo vs $test_root/ml-local.env: 1 differ, 0 bitwarden-only, 0 local-only, 2 identical" "$out"
for fragment in '-----BEGIN PRIVATE KEY-----' '-----END PRIVATE KEY-----' \
  MIIEvQIBADANBgkqhkiGCwAggSjAgEAAoIBAQCstoredChunkAAAAAAAAAAAAAAA \
  SecondLineOfTheStoredKeyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA \
  SecondLineOfTheLocalKeyBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB tail-value; do
  if printf '%s\n' "$out" | grep -qF -- "$fragment"; then
    fail "multiline value fragment leaked into default output: $fragment"
  fi
done
# 同じ複数行値なら一致と判定する (畳み込みが値の比較を壊していない)
run_diff demo "$test_root/ml-remote.env"
assert_eq "multiline identical exit code" 0 "$code"
assert_eq "multiline identical output" \
  "# demo vs $test_root/ml-remote.env: 0 differ, 0 bitwarden-only, 0 local-only, 3 identical" "$out"

# 引用符を付けずに貼られた PEM も畳む (引用符が無いと断片が漏れていた)
cat > "$test_root/pem-remote.env" <<'EOF'
PORT=3000
PRIVATE_KEY=-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiGCwAggSjAgEAAoIBAQCbareStoredChunkAAAAAAAAAAA
SECRETTAILCHUNKabcdefghijklmnop==
-----END PRIVATE KEY-----
AFTER_KEY=tail-value
EOF
cat > "$test_root/pem-local.env" <<'EOF'
PORT=3000
PRIVATE_KEY=-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiGCwAggSjAgEAAoIBAQCbareStoredChunkAAAAAAAAAAA
LOCALTAILCHUNKqrstuvwxyz012345==
-----END PRIVATE KEY-----
AFTER_KEY=tail-value
EOF
base64 < "$test_root/pem-remote.env" > "$BW_TEST_NOTES"
run_diff demo "$test_root/pem-local.env"
assert_eq "bare pem exit code" 1 "$code"
assert_eq "bare pem output" "~ PRIVATE_KEY
# demo vs $test_root/pem-local.env: 1 differ, 0 bitwarden-only, 0 local-only, 2 identical" "$out"
for fragment in SECRETTAILCHUNKabcdefghijklmnop LOCALTAILCHUNKqrstuvwxyz012345 \
  MIIEvQIBADANBgkqhkiGCwAggSjAgEAAoIBAQCbareStoredChunkAAAAAAAAAAA '-----BEGIN'; do
  if printf '%s\n' "$out" | grep -qF -- "$fragment"; then
    fail "bare pem fragment leaked into default output: $fragment"
  fi
done

# 引用符内のバックスラッシュで値を飲み込み、後続のキーを黙って落とさない
for quoted in 'WIN_PATH="C:\tmp\\"' "PATH_SQ='C:\\tmp\\'"; do
  {
    printf '%s\n' "$quoted"
    printf 'SECRET_TOKEN=shared-token\nTAIL_KEY=shared-tail\n'
  } > "$test_root/bs-remote.env"
  cp "$test_root/bs-remote.env" "$test_root/bs-local.env"
  printf 'EXTRA_LOCAL=only-here\n' >> "$test_root/bs-local.env"
  base64 < "$test_root/bs-remote.env" > "$BW_TEST_NOTES"
  run_diff demo "$test_root/bs-local.env"
  assert_eq "backslash [$quoted] exit code" 1 "$code"
  assert_eq "backslash [$quoted] output" "+ EXTRA_LOCAL
# demo vs $test_root/bs-local.env: 0 differ, 0 bitwarden-only, 1 local-only, 3 identical" "$out"
done

# 解釈できない行は黙って捨てず、行番号を添えて exit 2 で止まる (行の内容は出さない)
cat > "$test_root/broken.env" <<'EOF'
GOOD=1
BAD KEY=secret-in-a-broken-line
EOF
base64 < "$test_root/remote.env" > "$BW_TEST_NOTES"
run_diff demo "$test_root/broken.env"
assert_eq "unparsable line exit code" 2 "$code"
case "$err" in
  *"$test_root/broken.env: line 2: cannot parse as KEY=value"*) ;;
  *) fail "unparsable line was not reported with its line number: $err" ;;
esac
if printf '%s\n' "$err" "$out" | grep -qF -- 'secret-in-a-broken-line'; then
  fail "unparsable line content leaked into the report"
fi

# 値が '=' だけの行や値内の '=' は正規の KEY=value として扱う (値は最初の '=' で分割)
cat > "$test_root/eq-remote.env" <<'EOF'
FOO==
TOKEN===
EQ_IN_VALUE=a=b=c
EMPTY=
EOF
cat > "$test_root/eq-local.env" <<'EOF'
FOO==
TOKEN====
EQ_IN_VALUE=a=b=c
EMPTY=
EOF
base64 < "$test_root/eq-remote.env" > "$BW_TEST_NOTES"
run_diff demo "$test_root/eq-local.env"
assert_eq "equals-only value exit code" 1 "$code"
assert_eq "equals-only value output" "~ TOKEN
# demo vs $test_root/eq-local.env: 1 differ, 0 bitwarden-only, 0 local-only, 3 identical" "$out"
run_diff --values demo "$test_root/eq-local.env"
assert_eq "equals-only value with --values" "~ TOKEN
    bitwarden: ==
    local:     ===
# demo vs $test_root/eq-local.env: 1 differ, 0 bitwarden-only, 0 local-only, 3 identical" "$out"

# 引用符なしで折り返された base64 の途中行: 代入として比較するが既定ではキー名を伏せる
# (構文上は正規の KEY=value なので拒否はしない。名前自体が値の断片になるため出さない)
for chunk in 'SECRETPADCHUNKabcdefghijklmnop==' 'q0G94fxav0M8SWHPyo5FWpEsecret='; do
  {
    printf 'CERT_DATA=MIIEvQIBADANBgkqhkiGCwAggSjAgEAAoIBAQC\n'
    printf '%s\n' "$chunk"
  } > "$test_root/chunk-local.env"
  printf 'CERT_DATA=MIIEvQIBADANBgkqhkiGCwAggSjAgEAAoIBAQC\n' > "$test_root/chunk-remote.env"
  base64 < "$test_root/chunk-remote.env" > "$BW_TEST_NOTES"
  run_diff demo "$test_root/chunk-local.env"
  assert_eq "wrapped chunk [$chunk] exit code" 1 "$code"
  assert_eq "wrapped chunk [$chunk] output" "+ <withheld>
# 1 key name(s) withheld: they look like a base64 value wrapped without quotes; quote the value, or use --values to see them
# demo vs $test_root/chunk-local.env: 0 differ, 0 bitwarden-only, 1 local-only, 1 identical" "$out"
  if printf '%s\n' "$out" | grep -qF -- "${chunk%%=*}"; then
    fail "wrapped base64 chunk leaked into the default output: $chunk"
  fi
  # --values は明示的な opt-in なので実名と値を出す
  run_diff --values demo "$test_root/chunk-local.env"
  printf '%s\n' "$out" | grep -qF -- "${chunk%%=*}" \
    || fail "--values did not show the withheld key: $chunk"
done
base64 < "$test_root/remote.env" > "$BW_TEST_NOTES"

# 伏せ字は行の長さではなく「直前の行が base64 本体」という文脈で決める。
# 末尾空白 1 個 / CRLF / 15文字以下の tail でも外れないこと。
body='AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
run_chunk_case() { # <label> <tail line (remote)> <tail line (local)>
  printf 'BLOB=%s\n%s\n' "$body" "$2" > "$test_root/wrap-remote.env"
  printf 'BLOB=%s\n%s\n' "$body" "$3" > "$test_root/wrap-local.env"
  base64 < "$test_root/wrap-remote.env" > "$BW_TEST_NOTES"
  run_diff demo "$test_root/wrap-local.env"
  assert_eq "wrapped [$1] exit code" 1 "$code"
  while read -r line; do
    case "$line" in
      '#'*) continue ;;
      '+ <withheld>' | '- <withheld>' | '~ <withheld>') continue ;;
      '') continue ;;
      *) fail "wrapped [$1] printed a name: $line" ;;
    esac
  done <<< "$out"
}

# (a) padding の後に末尾空白が1個
run_chunk_case 'trailing space' 'SECRETTAILCHUNKstoredab= ' 'SECRETTAILCHUNKlocalxyz= '
for fragment in SECRETTAILCHUNKstoredab SECRETTAILCHUNKlocalxyz; do
  printf '%s\n' "$out" | grep -qF -- "$fragment" && fail "trailing space bypassed the mask: $fragment"
done

# (b) CRLF (本体行も tail 行も CR で終わる、本物の CRLF ファイル)
printf 'BLOB=%s\r\nSECRETTAILCHUNKstoredab=\r\n' "$body" > "$test_root/wrap-remote.env"
printf 'BLOB=%s\r\nSECRETTAILCHUNKlocalxyz=\r\n' "$body" > "$test_root/wrap-local.env"
base64 < "$test_root/wrap-remote.env" > "$BW_TEST_NOTES"
run_diff demo "$test_root/wrap-local.env"
assert_eq "wrapped [crlf] exit code" 1 "$code"
while read -r line; do
  case "$line" in
    '#'* | '') continue ;;
    '+ <withheld>' | '- <withheld>' | '~ <withheld>') continue ;;
    *) fail "wrapped [crlf] printed a name: $line" ;;
  esac
done <<< "$out"
for fragment in SECRETTAILCHUNKstoredab SECRETTAILCHUNKlocalxyz; do
  printf '%s\n' "$out" | grep -qF -- "$fragment" && fail "CRLF bypassed the mask: $fragment"
done

# (c) tail が 16 文字未満
run_chunk_case 'short tail' 'SECRETTAILstor=' 'X49GiXQ4ykg='
for fragment in SECRETTAILstor X49GiXQ4ykg; do
  printf '%s\n' "$out" | grep -qF -- "$fragment" && fail "short tail bypassed the mask: $fragment"
done
base64 < "$test_root/remote.env" > "$BW_TEST_NOTES"

# 空行やコメントで区切られた正規のキーは伏せない (折り返しの文脈は物理的に直前の行だけ)
for sep in '# just a comment' ''; do
  printf 'BLOB=%s\n' "$body" > "$test_root/sep-remote.env"
  printf 'BLOB=%s\n%s\nLONGENVIRONMENTKEY=\n' "$body" "$sep" > "$test_root/sep-local.env"
  base64 < "$test_root/sep-remote.env" > "$BW_TEST_NOTES"
  run_diff demo "$test_root/sep-local.env"
  assert_eq "separated key [${sep:-blank line}] exit code" 1 "$code"
  assert_eq "separated key [${sep:-blank line}] output" "+ LONGENVIRONMENTKEY
# demo vs $test_root/sep-local.env: 0 differ, 0 bitwarden-only, 1 local-only, 1 identical" "$out"
done
base64 < "$test_root/remote.env" > "$BW_TEST_NOTES"

# パーサ出力の mark が壊れていたら伏せ字を諦めずに exit 2 (fail-closed)
mark_bin="$test_root/markbin"
mkdir -p "$mark_bin"
# 2フィールド(値あり) / 2フィールド(値が空) / 1フィールド / mark が不正値 / キーが空
for record in 'PORT\002 3000' 'PORT\002' 'PORT' '2\002PORT\0023000' '0\002\0023000'; do
  cat > "$mark_bin/awk" <<STUB
#!/usr/bin/env bash
printf '$record\n'
STUB
  chmod +x "$mark_bin/awk"
  code=0
  out=$(PATH="$mark_bin:$PATH" "$bw_env" diff demo "$test_root/local.env" 2> "$test_root/stderr.txt") \
    || code=$?
  err=$(cat "$test_root/stderr.txt")
  assert_eq "broken record [$record] exit code" 2 "$code"
  case "$err" in
    *'missing chunk mark'* | *'empty key'*) ;;
    *) fail "broken record [$record] was not rejected: $err" ;;
  esac
  case "$out" in
    *' differ, '*) fail "broken record [$record] produced a diff report: $out" ;;
  esac
done
rm -rf "$mark_bin"

# 16文字以上でも正規の代入は拒否しない (値内 '=' と空値の契約を守る)
cat > "$test_root/long-remote.env" <<'EOF'
LONGENVIRONMENTKEY=
ABCDEFGHIJKLMNOP==
EQ_IN_VALUE=a=b=c
VERYLONGKEYNAMEHERE=stored-value
EOF
cat > "$test_root/long-local.env" <<'EOF'
LONGENVIRONMENTKEY=
ABCDEFGHIJKLMNOP==
EQ_IN_VALUE=a=b=d
VERYLONGKEYNAMEHERE=local-value
EOF
base64 < "$test_root/long-remote.env" > "$BW_TEST_NOTES"
run_diff demo "$test_root/long-local.env"
assert_eq "long plain key exit code" 1 "$code"
# 16文字以上の英数字キーでも、値を持つ行は正規の代入なので名前を出す
assert_eq "long plain key output" "~ EQ_IN_VALUE
~ VERYLONGKEYNAMEHERE
# demo vs $test_root/long-local.env: 2 differ, 0 bitwarden-only, 0 local-only, 2 identical" "$out"
run_diff --values demo "$test_root/long-local.env"
assert_eq "long plain key with --values" "~ EQ_IN_VALUE
    bitwarden: a=b=c
    local:     a=b=d
~ VERYLONGKEYNAMEHERE
    bitwarden: stored-value
    local:     local-value
# demo vs $test_root/long-local.env: 2 differ, 0 bitwarden-only, 0 local-only, 2 identical" "$out"
base64 < "$test_root/remote.env" > "$BW_TEST_NOTES"

# 値の前後の TAB だけが違う場合を「一致」と報告しない
printf 'TOKEN=\tsameval\nOTHER=1\n' > "$test_root/tab-remote.env"
printf 'TOKEN=sameval\nOTHER=1\n' > "$test_root/tab-local.env"
base64 < "$test_root/tab-remote.env" > "$BW_TEST_NOTES"
run_diff demo "$test_root/tab-local.env"
assert_eq "leading tab exit code" 1 "$code"
assert_eq "leading tab output" "~ TOKEN
# demo vs $test_root/tab-local.env: 1 differ, 0 bitwarden-only, 0 local-only, 1 identical" "$out"
printf 'TOKEN=sameval\t\nOTHER=1\n' > "$test_root/tab-remote.env"
base64 < "$test_root/tab-remote.env" > "$BW_TEST_NOTES"
run_diff demo "$test_root/tab-local.env"
assert_eq "trailing tab exit code" 1 "$code"
assert_eq "trailing tab output" "~ TOKEN
# demo vs $test_root/tab-local.env: 1 differ, 0 bitwarden-only, 0 local-only, 1 identical" "$out"
base64 < "$test_root/remote.env" > "$BW_TEST_NOTES"

# 閉じない引用符は exit 2 (残りを1つの値に飲み込んだまま報告しない)
cat > "$test_root/unterm.env" <<'EOF'
K="never closes
MORE=1
EOF
run_diff demo "$test_root/unterm.env"
assert_eq "unterminated quote exit code" 2 "$code"
case "$err" in
  *"unterminated quoted value for K (starts at line 1)"*) ;;
  *) fail "unterminated quote was not reported: $err" ;;
esac

# リテラルの '\n' を含む単一行値と実改行の複数行値を同一視しない
printf 'K="a\\nb"\n' > "$test_root/esc-remote.env"
printf 'K="a\nb"\n' > "$test_root/esc-local.env"
base64 < "$test_root/esc-remote.env" > "$BW_TEST_NOTES"
run_diff demo "$test_root/esc-local.env"
assert_eq "escaped newline exit code" 1 "$code"
assert_eq "escaped newline output" "~ K
# demo vs $test_root/esc-local.env: 1 differ, 0 bitwarden-only, 0 local-only, 0 identical" "$out"
base64 < "$test_root/remote.env" > "$BW_TEST_NOTES"

# 17. 未知オプション / 余剰引数 / name 欠落
run_diff --bogus demo "$test_root/local.env"
assert_eq "unknown option exit code" 2 "$code"
assert_eq "unknown option message" "Error: unknown option '--bogus'" "$err"

run_diff demo "$test_root/local.env" extra
assert_eq "too many arguments exit code" 2 "$code"
assert_eq "too many arguments message" \
  "Error: too many arguments (expected: diff <name> [file])" "$err"

run_diff
assert_eq "missing name exit code" 2 "$code"
case "$out" in
  *'Usage: bw-env'*) ;;
  *) fail "missing name did not print usage" ;;
esac

# 18. 既存サブコマンドの挙動が変わっていない
keys_out=$("$bw_env" keys demo)
assert_eq "keys output" "PORT
DATABASE_PATH
URL
DUPE
DUPE
BW_ONLY
QUOTED" "$keys_out"
assert_eq "list output" "demo" "$("$bw_env" list)"
assert_eq "get output" "/srv/legacy/app.db" "$("$bw_env" get demo DATABASE_PATH)"
usage_code=0
"$bw_env" > /dev/null 2>&1 || usage_code=$?
assert_eq "bare usage exit code" 1 "$usage_code"

# 19. diff は読み取り専用: 書き込み系の rbw 呼び出しが一度も無い
# 先に stub 自体が使われたことを確かめる (ログが空なら下の検査は無条件に通ってしまう)
grep -qE '^get ' "$BW_TEST_LOG" || fail "fake rbw was not used: $BW_TEST_LOG has no read call"
grep -qE '^list ' "$BW_TEST_LOG" || fail "fake rbw was not used: $BW_TEST_LOG has no list call"
if grep -qE '^(add|rm)( |$)' "$BW_TEST_LOG"; then
  fail "a write command reached rbw: $(grep -E '^(add|rm)( |$)' "$BW_TEST_LOG")"
fi

echo "bw-env diff test: pass"
