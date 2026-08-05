#!/usr/bin/env bash
# emit-turn-end.sh の MOCA 通知契約:
# agent-talk の呼び鈴で始まったターン (talk) の成功完了は通知しない。
# 確認待ち・許可待ち・異常終了・talk 起点でない完了、および broker への
# turn-end は従来どおり。
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
chmod +x "$test_root/bin/curl" \
  "$test_root/home/.local/share/agent-talk/current/agent-talk"

# スクリプトは自身の隣にある runtime pin を読むため、コピーして隔離する。
cp "$script" "$test_root/bin/emit-turn-end.sh"
cat >"$test_root/bin/.dotfiles-agent-runtime" <<EOF
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
  (cd "$test_root" && env -i HOME="$test_root/home" PATH=/usr/bin:/bin \
    MOCA_URL=http://moca.test \
    bash "$test_root/bin/emit-turn-end.sh" "$@" >/dev/null 2>&1) || true
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
grep -q "BROKER turn-end" "$log" || fail "通常成功で turn-end が消えた"

# talk 起点でも、人間の対応が要る状態は通知が残る。
: >"$log"
run claude waiting talk
grep -q "CURL.*claudeが確認を求めています" "$log" || fail "talk+waiting の通知が消えた"

: >"$log"
run claude permission talk
grep -q "CURL.*でファイル操作の許可が必要です" "$log" || fail "talk+permission の通知が消えた"

: >"$log"
run claude failed talk
grep -q "CURL.*claudeがfailedで終了しました" "$log" || fail "talk+failed の通知が消えた"

echo "emit-turn-end notify contract: ok"
