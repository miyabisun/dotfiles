#!/usr/bin/env bash
# emit-turn-end.sh の MOCA 通知契約:
# agent-talk の呼び鈴で始まったターン (talk) の成功完了は通知しない。
# 確認待ち・許可待ち・異常終了・talk 起点でない完了、および broker への
# turn-end と tmux bell は従来どおり。
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/agent/common/bin/emit-turn-end.sh"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

log="$test_root/log"
: >"$log"
mkdir -p "$test_root/bin" "$test_root/home/.local/share/agent-talk/current"

cat >"$test_root/bin/curl" <<EOF
#!/bin/bash
echo "CURL \$*" >>"$log"
EOF
cat >"$test_root/home/.local/share/agent-talk/current/agent-talk" <<EOF
#!/bin/bash
echo "BROKER \$*" >>"$log"
EOF
# @agent_talk_sent は marker file の有無で答える。TALK 抑止と SENT 抑止を
# 同じ fake が常に "1" を返すと区別できなくなるため、SENT ケースだけが
# marker を置いて有効化する。
cat >"$test_root/bin/tmux" <<EOF
#!/bin/bash
echo "TMUX_CMD \$*" >>"$log"
case "\$1" in
  display-message) echo "settings" ;;
  show-options)
    case "\$*" in
      *@agent_talk_sent*) if [[ -f "$test_root/sent-marker" ]]; then echo "1"; else echo ""; fi ;;
      *) echo "" ;;
    esac
    ;;
  *) : ;;
esac
EOF
chmod +x "$test_root/bin/curl" "$test_root/bin/tmux" \
  "$test_root/home/.local/share/agent-talk/current/agent-talk"

# スクリプトは自身の隣にある runtime pin を読むため、コピーして隔離する。
cp "$script" "$test_root/bin/emit-turn-end.sh"
cat >"$test_root/bin/.dotfiles-agent-runtime" <<EOF
TMUX_BIN=$test_root/bin/tmux
CURL_BIN=$test_root/bin/curl
SHA256_BIN=/usr/bin/sha256sum
SHA256_MODE=sha256sum
CP_BIN=/usr/bin/cp
RM_BIN=/usr/bin/rm
STAT_BIN=/usr/bin/stat
STAT_MODE=gnu
EOF

fail() {
  printf 'emit-turn-end notify contract broken: %s\n' "$1" >&2
  printf 'log:\n%s\n' "$(cat "$log")" >&2
  exit 1
}

run() {
  env -i HOME="$test_root/home" PATH=/usr/bin:/bin MOCA_URL=http://moca.test \
    bash "$test_root/bin/emit-turn-end.sh" "$@" >/dev/null 2>&1 || true
}

run_in_tmux() {
  env -i HOME="$test_root/home" PATH=/usr/bin:/bin MOCA_URL=http://moca.test \
    TMUX=/tmp/fake,1,0 TMUX_PANE='%9' \
    bash "$test_root/bin/emit-turn-end.sh" "$@" >/dev/null 2>&1 || true
}

# talk 起点の成功完了: 通知しない。broker への turn-end は生きている。
: >"$log"
run claude success talk
grep -q "CURL" "$log" && fail "talk+success が通知された"
grep -q "BROKER turn-end" "$log" || fail "talk+success で turn-end が消えた"

# talk 起点でない成功完了: 従来どおり通知する。
: >"$log"
run claude success
grep -q "CURL.*claudeが完了しました" "$log" || fail "通常の完了通知が消えた"

# talk 起点でも、人間の対応が要る状態は通知が残る。
: >"$log"
run claude waiting talk
grep -q "CURL.*確認を求めています" "$log" || fail "talk+waiting の通知が消えた"

: >"$log"
run claude permission talk
grep -q "CURL.*ファイル操作の許可が必要です" "$log" || fail "talk+permission の通知が消えた"

: >"$log"
run claude failed talk
grep -q "CURL.*failedで終了しました" "$log" || fail "talk+failed の通知が消えた"

# talk 起点の成功完了 (tmux 内・SENT なし): 通知だけが消え、
# @agent_bell と turn-end は残る。早期 exit への退行をここで検知する。
: >"$log"
run_in_tmux claude success talk
grep -q "CURL" "$log" && fail "tmux 内の talk+success が通知された"
grep -q "BROKER turn-end" "$log" || fail "tmux 内 talk+success で turn-end が消えた"
grep -q "TMUX_CMD set-option -t %9 @agent_bell 1" "$log" ||
  fail "talk+success で agent_bell が消えた"

# 既存の SENT 抑止: 同一ターン内で send した完了は通知せず、印を消費する。
touch "$test_root/sent-marker"
: >"$log"
run_in_tmux claude success
grep -q "CURL" "$log" && fail "SENT+success が通知された"
grep -q "TMUX_CMD set-option -p -t %9 -u @agent_talk_sent" "$log" ||
  fail "SENT の消費が消えた"
grep -q "TMUX_CMD set-option -t %9 @agent_bell 1" "$log" ||
  fail "agent_bell が消えた"
grep -q "BROKER turn-end" "$log" || fail "SENT+success で turn-end が消えた"

echo "emit-turn-end notify contract: ok"
