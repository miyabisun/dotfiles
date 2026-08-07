#!/usr/bin/env bash
# herdr-swap の挙動契約を fake socket で固定する。
#
# herdr の tab.move / workspace.move の insert_index は「削除前の並びに対する
# 位置」である (実疎通で確認済み)。next = 現在位置+2、previous = 現在位置-1。
# 端では wrap せず成功 no-op。この意味論が退行すると並び替えが「動かない」
# 「二つ飛ぶ」になるため、送信された move request を丸ごと assert する。
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
swap="$repo_root/config/herdr/bin/herdr-swap"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

# fake herdr server: 接続ごとに JSON 1行を受け、method に応じて fixture を
# 返す。move 系は params を moves.jsonl へ記録する。
fake_server() {
  local mode="$1"
  python3 - "$workdir" "$mode" <<'EOF' &
import json, os, socket, sys, threading

workdir, mode = sys.argv[1], sys.argv[2]
path = os.path.join(workdir, "herdr.sock")

# focused workspace = wB (index 1 / 3件)。wB の active tab = wB:t2 (index 1 / 3件)
workspaces = [
    {"workspace_id": "wA", "focused": False, "active_tab_id": "wA:t1"},
    {"workspace_id": "wB", "focused": mode != "nofocus", "active_tab_id": "wB:t2"},
    {"workspace_id": "wC", "focused": False, "active_tab_id": "wC:t1"},
]
tabs = [
    {"tab_id": "wA:t1", "workspace_id": "wA"},
    {"tab_id": "wB:t1", "workspace_id": "wB"},
    {"tab_id": "wB:t2", "workspace_id": "wB"},
    {"tab_id": "wB:t3", "workspace_id": "wB"},
    {"tab_id": "wC:t1", "workspace_id": "wC"},
]
if mode == "edge":
    # active tab を末尾に、focused workspace を先頭にする
    workspaces[1]["active_tab_id"] = "wB:t3"
    workspaces[0]["focused"] = True
    workspaces[1]["focused"] = False

server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
server.bind(path)
server.listen(8)
open(os.path.join(workdir, "ready"), "w").close()

def handle(conn):
    with conn:
        raw = b""
        while not raw.endswith(b"\n"):
            chunk = conn.recv(65536)
            if not chunk:
                return
            raw += chunk
        request = json.loads(raw.decode())
        method = request["method"]
        if method == "workspace.list":
            result = {"type": "workspace_list", "workspaces": workspaces}
        elif method == "tab.list":
            result = {"type": "tab_list", "tabs": tabs}
        elif method in ("tab.move", "workspace.move"):
            if mode == "error":
                conn.sendall((json.dumps({"id": request["id"], "error": {"code": "tab_move_failed", "message": "boom"}}) + "\n").encode())
                return
            with open(os.path.join(workdir, "moves.jsonl"), "a") as f:
                f.write(json.dumps({"method": method, "params": request["params"]}) + "\n")
            result = {"type": "ok"}
        else:
            result = {"type": "ok"}
        conn.sendall((json.dumps({"id": request["id"], "result": result}) + "\n").encode())

while True:
    conn, _ = server.accept()
    threading.Thread(target=handle, args=(conn,), daemon=True).start()
EOF
  server_pid=$!
  for _ in $(seq 1 50); do
    [ -f "$workdir/ready" ] && return 0
    sleep 0.1
  done
  echo "fake server did not start" >&2
  return 1
}

reset_case() {
  kill "$server_pid" 2>/dev/null || true
  wait "$server_pid" 2>/dev/null || true
  rm -f "$workdir/herdr.sock" "$workdir/ready" "$workdir/moves.jsonl"
}

run_swap() {
  HERDR_SOCKET_PATH="$workdir/herdr.sock" "$swap" "$@"
}

moves() {
  cat "$workdir/moves.jsonl" 2>/dev/null || true
}

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" != "$actual" ]; then
    printf '%s:\n  expected: %s\n  actual:   %s\n' "$label" "$expected" "$actual" >&2
    exit 1
  fi
}

# tab next: index 1 → insert_index 3 (削除前基準の +2)
fake_server normal
run_swap tab next
assert_eq "tab next" \
  '{"method": "tab.move", "params": {"tab_id": "wB:t2", "insert_index": 3}}' \
  "$(moves)"
reset_case

# tab previous: index 1 → insert_index 0
fake_server normal
run_swap tab previous
assert_eq "tab previous" \
  '{"method": "tab.move", "params": {"tab_id": "wB:t2", "insert_index": 0}}' \
  "$(moves)"
reset_case

# workspace next: index 1 → insert_index 3
fake_server normal
run_swap workspace next
assert_eq "workspace next" \
  '{"method": "workspace.move", "params": {"workspace_id": "wB", "insert_index": 3}}' \
  "$(moves)"
reset_case

# workspace previous: index 1 → insert_index 0
fake_server normal
run_swap workspace previous
assert_eq "workspace previous" \
  '{"method": "workspace.move", "params": {"workspace_id": "wB", "insert_index": 0}}' \
  "$(moves)"
reset_case

# 端: 末尾 tab の next / 先頭 workspace の previous は move を送らず成功 no-op
fake_server edge
run_swap tab next
run_swap workspace previous
assert_eq "edge no-op sends no move" "" "$(moves)"
reset_case

# API error は握り潰さない: nonzero + stderr
fake_server error
if err="$(run_swap tab next 2>&1)"; then
  echo "expected nonzero on API error" >&2
  exit 1
fi
case "$err" in
  *boom*) ;;
  *) echo "stderr should carry the API error: $err" >&2; exit 1 ;;
esac
reset_case

# focused workspace が無い場合も nonzero
fake_server nofocus
if run_swap tab next 2>/dev/null; then
  echo "expected nonzero when no workspace is focused" >&2
  exit 1
fi
reset_case

# 引数エラーと HERDR_SOCKET_PATH 未設定は usage/理由を出して nonzero
if "$swap" tab sideways 2>/dev/null; then
  echo "expected nonzero on bad arguments" >&2
  exit 1
fi
if env -u HERDR_SOCKET_PATH "$swap" tab next 2>/dev/null; then
  echo "expected nonzero without HERDR_SOCKET_PATH" >&2
  exit 1
fi

# 存在しない socket への接続失敗 (OSError) も握り潰さない
if HERDR_SOCKET_PATH="$workdir/nonexistent.sock" "$swap" tab next 2>/dev/null; then
  echo "expected nonzero on connect failure" >&2
  exit 1
fi

echo "herdr-swap behavior test: pass"
