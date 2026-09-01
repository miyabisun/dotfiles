#!/usr/bin/env bash
# Contract: bw-ssh-key generate creates an ed25519 pair in a private temp dir,
# pushes it straight into Bitwarden, prints only the public key, and cleans up.
# public/private print exactly one field each. Nothing ever lands under ~/.ssh.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bw_ssh_key="$repo_root/bin/bw/bw-ssh-key"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fake_bin="$test_root/bin"
fake_home="$test_root/home"
runtime_dir="$test_root/runtime"
mkdir -p "$fake_bin" "$fake_home" "$runtime_dir"
export PATH="$fake_bin:$PATH"
export HOME="$fake_home"
export XDG_RUNTIME_DIR="$runtime_dir"
export BW_TEST_LOG="$test_root/rbw-args.log"
export BW_TEST_STORE="$test_root/store"
export BW_TEST_KEYGEN_LOG="$test_root/keygen-args.log"
mkdir -p "$BW_TEST_STORE"
: > "$BW_TEST_LOG"
: > "$BW_TEST_KEYGEN_LOG"

fail() { printf 'bw-ssh-key contract broken: %s\n' "$1" >&2; exit 1; }

# fake rbw: store items as files (<name>.password / <name>.notes)
cat > "$fake_bin/rbw" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$BW_TEST_LOG"
case "${1:-}" in
  unlocked | unlock) exit 0 ;;
  list)
    for f in "$BW_TEST_STORE"/*.password; do
      [ -e "$f" ] || continue
      name="$(basename "$f" .password)"
      jq -n --arg n "$name" '{folder: "SSH Keys", name: $n}'
    done | jq -s . ;;
  get)
    shift; name=""
    while [ "$#" -gt 0 ]; do case "$1" in
      --folder | --field) shift 2 ;; --raw) shift ;; *) name="$1"; shift ;;
    esac; done
    if [ ! -e "$BW_TEST_STORE/$name.password" ]; then
      echo "fake rbw: entry not found: $name" >&2; exit 1
    fi
    jq -n --arg p "$(cat "$BW_TEST_STORE/$name.password")" \
          --arg n "$(cat "$BW_TEST_STORE/$name.notes")" \
          '{data: {password: $p}, notes: $n}' ;;
  add)
    if [ "${BW_TEST_ADD_FAIL:-0}" = 1 ]; then
      echo 'fake rbw: add rejected' >&2; exit 1
    fi
    name="${*: -1}"
    { IFS= read -r pub; IFS= read -r _blank; cat; } > "$BW_TEST_STORE/$name.notes.tmp"
    head -n 1 <<< "$pub" > "$BW_TEST_STORE/$name.password"
    mv "$BW_TEST_STORE/$name.notes.tmp" "$BW_TEST_STORE/$name.notes" ;;
  rm) name="${*: -1}"; rm -f "$BW_TEST_STORE/$name".* ;;
  *) echo "fake rbw: unexpected: $1" >&2; exit 1 ;;
esac
STUB
chmod +x "$fake_bin/rbw"

# fake ssh-keygen: record args, write synthetic pair to -f target
cat > "$fake_bin/ssh-keygen" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$BW_TEST_KEYGEN_LOG"
out=""; prev=""
for a in "$@"; do [ "$prev" = "-f" ] && out="$a"; prev="$a"; done
[ -n "$out" ] || { echo 'fake ssh-keygen: no -f' >&2; exit 1; }
printf '%s\n' 'SYNTHETIC-PRIVATE-KEY' > "$out"
printf '%s\n' 'ssh-ed25519 AAAASYNTH test-comment' > "$out.pub"
STUB
chmod +x "$fake_bin/ssh-keygen"

# 1. generate: pushes to Bitwarden, prints only the public key
out="$("$bw_ssh_key" generate sandbox)"
grep -qx 'ssh-ed25519 AAAASYNTH test-comment' <<< "$out" || fail "public key not printed: $out"
grep -q 'SYNTHETIC-PRIVATE-KEY' <<< "$out" && fail 'private key leaked to generate stdout'
grep -q -- '-t ed25519' "$BW_TEST_KEYGEN_LOG" || fail 'ssh-keygen not called with -t ed25519'
grep -q -- '-N ' "$BW_TEST_KEYGEN_LOG" || fail 'passphrase flag missing'
[ "$(cat "$BW_TEST_STORE/sandbox.password")" = 'ssh-ed25519 AAAASYNTH test-comment' ] || fail 'stored password is not the public key'
grep -q 'SYNTHETIC-PRIVATE-KEY' "$BW_TEST_STORE/sandbox.notes" || fail 'stored notes is not the private key'

# 2. temp hygiene: key files are gone, and nothing was written under $HOME
keyfile="$(awk '{for(i=1;i<=NF;i++) if($i=="-f"){print $(i+1)}}' "$BW_TEST_KEYGEN_LOG" | head -n 1)"
case "$keyfile" in
  "$runtime_dir"/*) ;;
  *) fail "key generated outside XDG_RUNTIME_DIR: $keyfile" ;;
esac
[ ! -e "$keyfile" ] || fail 'private key file survived generate'
[ ! -e "$keyfile.pub" ] || fail 'public key file survived generate'
[ ! -e "$fake_home/.ssh" ] || fail 'generate touched ~/.ssh'

# 3. generate refuses to overwrite an existing item
if "$bw_ssh_key" generate sandbox > "$test_root/dup.out" 2>&1; then
  fail 'generate overwrote an existing item'
fi
grep -q 'sandbox' "$test_root/dup.out" || fail 'refusal message lacks the item name'

# 4. public / private print exactly one field each
[ "$("$bw_ssh_key" public sandbox)" = 'ssh-ed25519 AAAASYNTH test-comment' ] || fail 'public printed wrong content'
priv="$("$bw_ssh_key" private sandbox)"
grep -qx 'SYNTHETIC-PRIVATE-KEY' <<< "$priv" || fail 'private printed wrong content'
grep -q 'ssh-ed25519' <<< "$priv" && fail 'private leaked the public key'

# 5. unknown item fails nonzero
"$bw_ssh_key" public no-such-key 2>/dev/null && fail 'public succeeded for missing item'

# 6. temp fallback chain: XDG unset -> TMPDIR, both unset -> /tmp
last_keyfile() { awk '{for(i=1;i<=NF;i++) if($i=="-f"){print $(i+1)}}' "$BW_TEST_KEYGEN_LOG" | tail -n 1; }
tmpdir_case="$test_root/tmpdir-fallback"
mkdir -p "$tmpdir_case"
env -u XDG_RUNTIME_DIR TMPDIR="$tmpdir_case" "$bw_ssh_key" generate fb-tmpdir > /dev/null
case "$(last_keyfile)" in
  "$tmpdir_case"/*) ;;
  *) fail "TMPDIR fallback not used: $(last_keyfile)" ;;
esac
env -u XDG_RUNTIME_DIR -u TMPDIR "$bw_ssh_key" generate fb-tmp > /dev/null
case "$(last_keyfile)" in
  /tmp/*) ;;
  *) fail "/tmp fallback not used: $(last_keyfile)" ;;
esac

# 7. failure path: rbw add rejected -> nonzero, no leak, temp dir fully removed
if BW_TEST_ADD_FAIL=1 "$bw_ssh_key" generate fb-fail > "$test_root/fail.out" 2> /dev/null; then
  fail 'generate succeeded although rbw add failed'
fi
grep -q 'SYNTHETIC-PRIVATE-KEY' "$test_root/fail.out" && fail 'private key leaked on failure'
failed_key="$(last_keyfile)"
[ ! -e "$failed_key" ] || fail 'private key survived failed generate'
[ ! -e "$(dirname "$failed_key")" ] || fail 'temp dir survived failed generate'
[ -e "$BW_TEST_STORE/fb-fail.password" ] && fail 'failed generate left a stored item'

# 8. success also removes the whole temp dir, even when the base path contains a quote
quote_dir="$test_root/quo'te"
mkdir -p "$quote_dir"
XDG_RUNTIME_DIR="$quote_dir" "$bw_ssh_key" generate fb-quote > /dev/null
quote_key="$(last_keyfile)"
case "$quote_key" in
  "$quote_dir"/*) ;;
  *) fail "quoted runtime dir not used: $quote_key" ;;
esac
[ ! -e "$(dirname "$quote_key")" ] || fail 'temp dir survived under quoted path'
[ ! -e "$(dirname "$keyfile")" ] || fail 'temp dir survived successful generate'

# 9. no implicit default name: save/load without a name refuse with usage
for sub in save load; do
  if "$bw_ssh_key" "$sub" > /dev/null 2>&1; then
    fail "$sub without a name succeeded (implicit 'default' name survived)"
  fi
done
# removed subcommands stay removed
"$bw_ssh_key" cat sandbox > /dev/null 2>&1 && fail 'cat subcommand still exists'

# 10. filename keeps its default: save with only a name proceeds to the
# ~/.ssh/id_rsa existence check instead of rejecting with usage
if "$bw_ssh_key" save only-name > "$test_root/save-name.out" 2>&1; then
  fail 'save with a bare name succeeded without key files'
fi
grep -q 'id_rsa' "$test_root/save-name.out" || fail 'save did not fall back to id_rsa'

echo 'bw-ssh-key contract: ok'
