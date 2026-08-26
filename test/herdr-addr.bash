#!/usr/bin/env bash
# Contract: herdr-addr は label 1 個から「送れる宛先」までを 1 コマンドで引く。
#
#   <workspace>        その workspace の agent を全件
#   <workspace>/<tab>  その tab の agent 1 体
#   <tab>              呼び出し元と同じ workspace の tab
#
# 出力は header 無しの TSV: label / pane / runtime / state / pid / uds / cwd。
# uds が無いときは `-`。推測はしない — 曖昧・不在・複数一致は nonzero で止める。
#
# herdr は PATH 上の fake に差し替え、cc-socks は一時 directory に本物の UNIX
# socket を作って実測する。本物の herdr session にも /tmp/cc-socks にも触らない。
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
addr="$repo_root/config/herdr/bin/herdr-addr"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fake_bin="$test_root/bin"
sock_dir="$test_root/cc-socks"
mkdir -p "$fake_bin" "$sock_dir"

out_file="$test_root/stdout.txt"
err_file="$test_root/stderr.txt"

# 実在する UNIX socket だけが宛先になる。ふつうのファイルでは代用しない。
# bind した socket の inode は、作ったプロセスが去ったあとも残る。
make_socket() {
  perl -MIO::Socket::UNIX -e '
    IO::Socket::UNIX->new(Local => $ARGV[0], Listen => 1) or die "$ARGV[0]: $!\n";
  ' "$1"
  [[ -S "$1" ]] || { echo "socket was not created: $1" >&2; exit 1; }
}

# w1 = settings (chat=1 agent, work=1 agent, git=agent 無し, knowledge=tab 名の衝突用)
# w2 = knowledge (chat=1 agent, review=2 agent, codex=socket 無しの非 claude)
cat >"$test_root/snapshot.json" <<'SNAPSHOT'
{"id":"cli:api:snapshot","result":{"snapshot":{
"workspaces":[
 {"workspace_id":"w1","label":"settings","focused":true},
 {"workspace_id":"w2","label":"knowledge","focused":false}],
"tabs":[
 {"tab_id":"w1:t1","workspace_id":"w1","label":"chat"},
 {"tab_id":"w1:t5","workspace_id":"w1","label":"work"},
 {"tab_id":"w1:t3","workspace_id":"w1","label":"git"},
 {"tab_id":"w1:t9","workspace_id":"w1","label":"knowledge"},
 {"tab_id":"w1:t7","workspace_id":"w1","label":"nometa"},
 {"tab_id":"w1:t8","workspace_id":"w1","label":"broken"},
 {"tab_id":"w2:t1","workspace_id":"w2","label":"chat"},
 {"tab_id":"w2:t2","workspace_id":"w2","label":"review"},
 {"tab_id":"w2:t3","workspace_id":"w2","label":"codex"}],
"agents":[
 {"pane_id":"w1:p1","tab_id":"w1:t1","workspace_id":"w1","agent":"claude","agent_status":"working","cwd":"/repo/settings"},
 {"pane_id":"w1:p5","tab_id":"w1:t5","workspace_id":"w1","agent":"claude","agent_status":"done","cwd":"/repo/settings"},
 {"pane_id":"w2:p1","tab_id":"w2:t1","workspace_id":"w2","agent":"claude","agent_status":"done","cwd":"/repo/knowledge"},
 {"pane_id":"w2:p2","tab_id":"w2:t2","workspace_id":"w2","agent":"claude","agent_status":"done","cwd":"/repo/knowledge"},
 {"pane_id":"w2:p4","tab_id":"w2:t2","workspace_id":"w2","agent":"claude","agent_status":"done","cwd":"/repo/knowledge"},
 {"pane_id":"w2:p3","tab_id":"w2:t3","workspace_id":"w2","agent":"codex","agent_status":"done","cwd":"/repo/knowledge"},
 {"pane_id":"w1:p7","tab_id":"w1:t7","workspace_id":"w1","cwd":"/repo/settings"},
 {"pane_id":"w1:p8","tab_id":"w1:t8","workspace_id":"w1","agent":"claude","agent_status":"done","cwd":"/repo/settings"}],
"panes":[],"focused_workspace_id":"w1","focused_tab_id":"w1:t1","focused_pane_id":"w1:p1"}}}
SNAPSHOT

# process-info: 無関係なプロセスが並び、claude の `name` は version 文字列で
# "claude" ではない。pid の選別を name に頼っていないことを測る。
write_process_info() {
  local pane="$1" pid="$2"
  cat >"$test_root/proc-$pane.json" <<PROC
{"id":"cli:pane:process_info","result":{"process_info":{
"foreground_process_group_id":$pid,"shell_pid":11111,"pane_id":"$pane",
"foreground_processes":[
 {"argv":["caffeinate","-i"],"argv0":"caffeinate","name":"caffeinate","pid":77257,"cwd":"/repo"},
 {"argv":["agent-talk-mcp"],"argv0":"agent-talk-mcp","name":"agent-talk-mcp","pid":77258,"cwd":"/repo"},
 {"argv":["claude"],"argv0":"claude","name":"2.1.239","pid":$pid,"cwd":"/repo"}]},
"type":"pane_process_info"}}
PROC
}

write_process_info w1:p1 59269
write_process_info w1:p5 59804
write_process_info w2:p1 60001
write_process_info w2:p2 60002
write_process_info w2:p4 60004
write_process_info w2:p3 60003
write_process_info w1:p7 60007

# w1:p8 の process-info は壊れた JSON を返す
printf '%s\n' '{"result":{"process_info":' >"$test_root/proc-w1:p8.json"

# codex の pane (w2:p3) だけ socket を作らない
for pid in 59269 59804 60001 60002 60004 60007; do
  make_socket "$sock_dir/$pid.sock"
done

cat >"$fake_bin/herdr" <<FAKE
#!/usr/bin/env bash
set -euo pipefail
if [[ "\$1" == "api" && "\$2" == "snapshot" ]]; then
  cat "$test_root/snapshot.json"
  exit 0
fi
if [[ "\$1" == "pane" && "\$2" == "process-info" && "\$3" == "--pane" ]]; then
  fixture="$test_root/proc-\$4.json"
  [[ -f "\$fixture" ]] || { echo "fake herdr: no fixture for \$4" >&2; exit 1; }
  cat "\$fixture"
  exit 0
fi
echo "fake herdr: unexpected: \$*" >&2
exit 1
FAKE
chmod +x "$fake_bin/herdr"

status=0
run() {
  set +e
  env "PATH=$fake_bin:$PATH" \
    "CLAUDE_CODE_MESSAGING_SOCKET=$sock_dir/59269.sock" \
    "$@" >"$out_file" 2>"$err_file"
  status=$?
  set -e
}

# pane 内から呼ぶ (HERDR_WORKSPACE_ID あり) / pane 外から呼ぶ (無し)
in_pane() { run env HERDR_WORKSPACE_ID=w1 "$addr" "$@"; }
outside_pane() { run env -u HERDR_WORKSPACE_ID "$addr" "$@"; }

fail() {
  echo "herdr-addr test: $1" >&2
  echo "--- stdout ---" >&2; cat "$out_file" >&2 2>/dev/null || true
  echo "--- stderr ---" >&2; cat "$err_file" >&2 2>/dev/null || true
  exit 1
}

assert_out() {
  local want="$1"
  [[ "$(cat "$out_file")" == "$want" ]] \
    || fail "expected output:
$want
actual:
$(cat "$out_file")"
}

# 1. workspace/tab は 1 体を uds まで解決する
outside_pane settings/chat
[[ "$status" -eq 0 ]] || fail "expected exit 0, got $status"
assert_out "$(printf 'settings/chat\tw1:p1\tclaude\tworking\t59269\t%s\t/repo/settings' "$sock_dir/59269.sock")"

# 2. workspace 単体はぶら下がる agent を全件、pane 順で返す
#    (agent の無い tab は出さない。socket の無い agent は uds が `-`)
outside_pane knowledge
[[ "$status" -eq 0 ]] || fail "expected exit 0, got $status"
assert_out "$(printf 'knowledge/chat\tw2:p1\tclaude\tdone\t60001\t%s\t/repo/knowledge
knowledge/review\tw2:p2\tclaude\tdone\t60002\t%s\t/repo/knowledge
knowledge/codex\tw2:p3\tcodex\tdone\t60003\t-\t/repo/knowledge
knowledge/review\tw2:p4\tclaude\tdone\t60004\t%s\t/repo/knowledge' \
  "$sock_dir/60001.sock" "$sock_dir/60002.sock" "$sock_dir/60004.sock")"

# 3. pane 内の bare label は自分の workspace の tab として引ける
in_pane chat
[[ "$status" -eq 0 ]] || fail "expected exit 0, got $status"
assert_out "$(printf 'settings/chat\tw1:p1\tclaude\tworking\t59269\t%s\t/repo/settings' "$sock_dir/59269.sock")"

# 4. pane 外の bare label は workspace としてだけ引ける。tab 名では引けない
outside_pane work
[[ "$status" -ne 0 ]] || fail 'bare tab label must not resolve outside a pane'
grep -q 'HERDR_WORKSPACE_ID' "$err_file" || fail "stderr should name the missing scope: $(cat "$err_file")"

# 5. bare label が workspace 名と自 workspace の tab 名の両方に当たったら
#    推測せず止める (fixture の w1 には knowledge という tab がある)
in_pane knowledge
[[ "$status" -ne 0 ]] || fail 'ambiguous bare label must not resolve'
grep -q 'ambiguous' "$err_file" || fail "stderr should say it is ambiguous: $(cat "$err_file")"

# 6. 単体指定で tab に agent が複数ぶら下がっていたら、先頭を選ばず止める
outside_pane knowledge/review
[[ "$status" -ne 0 ]] || fail 'a tab with several agents must not resolve to one'
grep -q 'w2:p2' "$err_file" || fail "stderr should list the candidates: $(cat "$err_file")"

# 7. 単体指定で socket が無ければ nonzero。宛先として使えないものを黙って返さない
outside_pane knowledge/codex
[[ "$status" -ne 0 ]] || fail 'a target without a socket must not exit 0'
[[ ! -s "$out_file" ]] || fail 'a failed single lookup must not print a row'
grep -q 'codex' "$err_file" || fail "stderr should name the target: $(cat "$err_file")"

# 8. 知らない label は nonzero。存在する label を stderr で示す
outside_pane nosuch
[[ "$status" -ne 0 ]] || fail 'unknown label must be nonzero'
grep -q 'settings' "$err_file" || fail "stderr should list known labels: $(cat "$err_file")"
outside_pane settings/nosuch
[[ "$status" -ne 0 ]] || fail 'unknown tab must be nonzero'

# 9. 引数の誤りは exit 2
outside_pane
[[ "$status" -eq 2 ]] || fail "expected exit 2 with no argument, got $status"
outside_pane a b
[[ "$status" -eq 2 ]] || fail "expected exit 2 with two arguments, got $status"
outside_pane a/b/c
[[ "$status" -eq 2 ]] || fail "expected exit 2 for a three-part label, got $status"

# 10. runtime / state が欠けていても列がずれない (空欄は空欄のまま残る)
outside_pane settings/nometa
[[ "$status" -eq 0 ]] || fail "expected exit 0, got $status"
assert_out "$(printf 'settings/nometa\tw1:p7\t\t\t60007\t%s\t/repo/settings' "$sock_dir/60007.sock")"

# 11. process-info が壊れた JSON を返したら握り潰さず nonzero。
#     pid が読めないまま「socket 無し」で成功してはならない
outside_pane settings/broken
[[ "$status" -ne 0 ]] || fail 'a broken process-info must not exit 0'
outside_pane settings
[[ "$status" -ne 0 ]] || fail 'a broken process-info must not be swallowed in a listing'

# 12. workspace label が重複していたら先頭を選ばず止める
cp "$test_root/snapshot.json" "$test_root/snapshot.orig.json"
perl -0pi -e 's/\{"workspace_id":"w2","label":"knowledge","focused":false\}/{"workspace_id":"w2","label":"knowledge","focused":false},\n {"workspace_id":"w3","label":"knowledge","focused":false}/' "$test_root/snapshot.json"
outside_pane knowledge
[[ "$status" -ne 0 ]] || fail 'a duplicated workspace label must not resolve'
grep -q 'ambiguous' "$err_file" || fail "stderr should say it is ambiguous: $(cat "$err_file")"
outside_pane knowledge/chat
[[ "$status" -ne 0 ]] || fail 'a duplicated workspace label must not resolve for a tab either'
cp "$test_root/snapshot.orig.json" "$test_root/snapshot.json"

# 13. herdr が失敗したら握り潰さず nonzero
cat >"$fake_bin/herdr" <<'BROKEN'
#!/usr/bin/env bash
echo "herdr: boom" >&2
exit 1
BROKEN
chmod +x "$fake_bin/herdr"
outside_pane settings/chat
[[ "$status" -ne 0 ]] || fail 'a failing herdr must not be swallowed'

# 14. install が ~/.local/bin へ配布し、script は実行可能である
grep -Fq 'link "config/herdr/bin/herdr-addr" "$HOME/.local/bin"' "$repo_root/bin/install" \
  || fail 'bin/install must link herdr-addr into ~/.local/bin'
[[ -x "$addr" ]] || fail 'config/herdr/bin/herdr-addr must be executable'

echo "herdr-addr test: pass"
