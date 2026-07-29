#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dispatcher_source="$repo_root/agent/common/bin/agent-talk-peer"
test_root="$(mktemp -d)"
body_file=""
race_source=""
bad_mode_file=""
symlink_body=""
cleanup() {
  rm -rf "$test_root"
  rm -f "$body_file" "$race_source" "$bad_mode_file" "$symlink_body"
}
trap cleanup EXIT
trusted_bin="$test_root/trusted-bin"
fake_path_bin="$test_root/fake-path-bin"
mkdir -p "$trusted_bin" "$fake_path_bin"
cp "$dispatcher_source" "$trusted_bin/agent-talk-peer"

cat >"$trusted_bin/agent-talk" <<'AGENT_TALK'
#!/bin/bash
set -euo pipefail
{
  printf 'argc=%s' "$#"
  printf ' <%s>' "$@"
  printf '\n'
} >>"$PEER_SEND_TEST_LOG"
if [[ ! -t 0 ]]; then
  while IFS= read -r line; do
    printf 'stdin=<%s>\n' "$line" >>"$PEER_SEND_TEST_LOG"
  done
fi
AGENT_TALK

cat >"$fake_path_bin/agent-talk" <<'FAKE_AGENT_TALK'
#!/bin/bash
printf 'PATH broker must not run\n' >>"$PEER_SEND_PATH_LOG"
exit 99
FAKE_AGENT_TALK

cat >"$fake_path_bin/dirname" <<'FAKE_DIRNAME'
#!/bin/bash
printf 'PATH dirname must not run\n' >>"$PEER_SEND_PATH_LOG"
exit 99
FAKE_DIRNAME

cat >"$trusted_bin/racing-sha256sum" <<'RACING_SHA'
#!/bin/bash
set -euo pipefail
hash_output="$(/usr/bin/sha256sum "$1")"
if [[ -f "${RACE_REPLACEMENT:-}" ]]; then
  /usr/bin/mv -- "$RACE_REPLACEMENT" "$RACE_SOURCE"
fi
printf '%s\n' "$hash_output"
RACING_SHA

chmod 0755 "$trusted_bin/agent-talk-peer" "$trusted_bin/agent-talk" \
  "$trusted_bin/racing-sha256sum" "$fake_path_bin/agent-talk" \
  "$fake_path_bin/dirname"
dispatcher="$trusted_bin/agent-talk-peer"
printf 'TMUX_BIN=/usr/bin/tmux\nCURL_BIN=/usr/bin/curl\nSHA256_BIN=/usr/bin/sha256sum\nSHA256_MODE=sha256sum\nCP_BIN=/usr/bin/cp\nRM_BIN=/usr/bin/rm\nSTAT_BIN=/usr/bin/stat\nSTAT_MODE=gnu\n' \
  >"$trusted_bin/.dotfiles-agent-runtime"
export PATH="$fake_path_bin:$PATH"
export PEER_SEND_TEST_LOG="$test_root/agent-talk.log"
export PEER_SEND_PATH_LOG="$test_root/path-agent-talk.log"
: >"$PEER_SEND_TEST_LOG"
: >"$PEER_SEND_PATH_LOG"

"$dispatcher" who
"$dispatcher" read 619
"$dispatcher" reply 619 -- 'review result'
"$dispatcher" send codex -- 'hello world'
"$dispatcher" send knowledge/codex --no-reply -- 'done'
printf '%s\n' 'multiline body' | "$dispatcher" send %24
"$dispatcher" send codex -- '--skill is ordinary body text after the delimiter'
body_file="$(mktemp /tmp/agent-knowledge.XXXXXX)"
printf '%s\n' 'knowledge body' >"$body_file"
chmod 0600 "$body_file"
body_hash="$(/usr/bin/sha256sum "$body_file")"
body_hash="${body_hash%% *}"
"$dispatcher" send knowledge/codex --no-reply \
  --body-file "$body_file" --sha256 "$body_hash"

# Deterministically replace the original /tmp pathname after snapshot hashing.
# The broker must still receive the already protected machine-local snapshot.
race_source="$(mktemp /tmp/agent-knowledge.XXXXXX)"
race_replacement="$test_root/race-replacement.txt"
printf '%s\n' 'race safe' >"$race_source"
printf '%s\n' 'race secret' >"$race_replacement"
chmod 0600 "$race_source" "$race_replacement"
race_hash="$(/usr/bin/sha256sum "$race_source")"
race_hash="${race_hash%% *}"
printf 'TMUX_BIN=/usr/bin/tmux\nCURL_BIN=/usr/bin/curl\nSHA256_BIN=%s\nSHA256_MODE=sha256sum\nCP_BIN=/usr/bin/cp\nRM_BIN=/usr/bin/rm\nSTAT_BIN=/usr/bin/stat\nSTAT_MODE=gnu\n' \
  "$trusted_bin/racing-sha256sum" >"$trusted_bin/.dotfiles-agent-runtime"
export RACE_SOURCE="$race_source"
export RACE_REPLACEMENT="$race_replacement"
"$dispatcher" send knowledge/codex --no-reply \
  --body-file "$race_source" --sha256 "$race_hash"

grep -Fx 'argc=1 <who>' "$PEER_SEND_TEST_LOG" >/dev/null
grep -Fx 'argc=2 <read> <619>' "$PEER_SEND_TEST_LOG" >/dev/null
grep -Fx 'argc=4 <reply> <619> <--> <review result>' "$PEER_SEND_TEST_LOG" >/dev/null
grep -Fx 'argc=4 <send> <codex> <--> <hello world>' "$PEER_SEND_TEST_LOG" >/dev/null
grep -Fx 'argc=5 <send> <knowledge/codex> <--no-reply> <--> <done>' \
  "$PEER_SEND_TEST_LOG" >/dev/null
grep -Fx 'argc=2 <send> <%24>' "$PEER_SEND_TEST_LOG" >/dev/null
grep -Fx 'stdin=<multiline body>' "$PEER_SEND_TEST_LOG" >/dev/null
grep -Fx 'argc=4 <send> <codex> <--> <--skill is ordinary body text after the delimiter>' \
  "$PEER_SEND_TEST_LOG" >/dev/null
grep -Fx 'argc=3 <send> <knowledge/codex> <--no-reply>' \
  "$PEER_SEND_TEST_LOG" >/dev/null
grep -Fx 'stdin=<knowledge body>' "$PEER_SEND_TEST_LOG" >/dev/null
grep -Fx 'stdin=<race safe>' "$PEER_SEND_TEST_LOG" >/dev/null
if grep -Fq 'stdin=<race secret>' "$PEER_SEND_TEST_LOG"; then
  echo 'hash-after pathname replacement changed broker bytes' >&2
  exit 1
fi
test ! -s "$PEER_SEND_PATH_LOG"

accepted_count="$(wc -l <"$PEER_SEND_TEST_LOG")"
outside_body="$test_root/outside-body.txt"
printf '%s\n' 'outside body' >"$outside_body"
chmod 0600 "$outside_body"
outside_hash="$(/usr/bin/sha256sum "$outside_body")"
outside_hash="${outside_hash%% *}"
bad_mode_file="$(mktemp /tmp/agent-knowledge.XXXXXX)"
printf '%s\n' 'bad mode' >"$bad_mode_file"
chmod 0644 "$bad_mode_file"
bad_mode_hash="$(/usr/bin/sha256sum "$bad_mode_file")"
bad_mode_hash="${bad_mode_hash%% *}"
symlink_body="$(mktemp /tmp/agent-knowledge.XXXXXX)"
rm -f "$symlink_body"
ln -s "$body_file" "$symlink_body"
for unsafe_args in \
  'send --skill' \
  'send --from' \
  'send --unknown' \
  'send codex --skill deliver' \
  'send codex --from mobile' \
  'send codex --no-reply --skill deliver' \
  "send codex --no-reply --body-file $body_file --sha256 $body_hash" \
  "send knowledge/codex --body-file $body_file --sha256 $body_hash" \
  "send knowledge/codex --no-reply --body-file $body_file --sha256 0000000000000000000000000000000000000000000000000000000000000000" \
  "send knowledge/codex --no-reply --body-file $outside_body --sha256 $outside_hash" \
  "send knowledge/codex --no-reply --body-file $bad_mode_file --sha256 $bad_mode_hash" \
  "send knowledge/codex --no-reply --body-file $symlink_body --sha256 $body_hash" \
  'send --skill deliver' \
  'send codex unquoted body' \
  'read not-an-id' \
  'reply 619 -- body extra' \
  'gc'; do
  read -r -a arg_parts <<<"$unsafe_args"
  if "$dispatcher" "${arg_parts[@]}" 2>/dev/null; then
    printf 'unsafe peer grammar was accepted: %s\n' "$unsafe_args" >&2
    exit 1
  fi
done
test "$(wc -l <"$PEER_SEND_TEST_LOG")" -eq "$accepted_count"
test ! -s "$PEER_SEND_PATH_LOG"
if find "$trusted_bin" -maxdepth 1 -name '.agent-talk-body.*' -print -quit \
  | grep -q .; then
  echo 'private body snapshot was not removed' >&2
  exit 1
fi

# The allowed executable itself must not be a repository symlink.
ln -s "$dispatcher_source" "$test_root/symlink-dispatcher"
if "$test_root/symlink-dispatcher" who 2>/dev/null; then
  echo 'symlinked peer dispatcher must fail closed' >&2
  exit 1
fi

echo 'agent-talk peer dispatcher test: pass'
