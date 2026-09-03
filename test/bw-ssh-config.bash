#!/usr/bin/env bash
# Contract: bw-ssh-config load <name> restores exactly one config to
# ~/.ssh/conf.d/<name>.conf (mode 600) and never touches the others.
# load-all restores every config. load without a name fails.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bw_ssh_config="$repo_root/bin/bw/bw-ssh-config"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fake_bin="$test_root/bin"
fake_home="$test_root/home"
mkdir -p "$fake_bin" "$fake_home"
export PATH="$fake_bin:$PATH"
export HOME="$fake_home"
export BW_TEST_STORE="$test_root/store"
mkdir -p "$BW_TEST_STORE"

fail() { printf 'bw-ssh-config contract broken: %s\n' "$1" >&2; exit 1; }

# fake rbw: items are <name>.notes files holding base64 of the config
cat > "$fake_bin/rbw" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  unlocked | unlock)
    if [ "${BW_TEST_LOCKED:-0}" = 1 ]; then echo 'fake rbw: locked' >&2; exit 1; fi
    exit 0 ;;
  list)
    for f in "$BW_TEST_STORE"/*.notes; do
      [ -e "$f" ] || continue
      jq -n --arg n "$(basename "$f" .notes)" '{folder: "SSH Config", name: $n}'
    done | jq -s . ;;
  get)
    shift; name=""
    while [ "$#" -gt 0 ]; do case "$1" in
      --folder | --field) shift 2 ;; --raw) shift ;; *) name="$1"; shift ;;
    esac; done
    if [ ! -e "$BW_TEST_STORE/$name.notes" ]; then
      echo "fake rbw: entry not found: $name" >&2; exit 1
    fi
    jq -n --arg n "$(cat "$BW_TEST_STORE/$name.notes")" '{notes: $n}' ;;
  *) echo "fake rbw: unexpected: $1" >&2; exit 1 ;;
esac
STUB
chmod +x "$fake_bin/rbw"

printf 'Host alpha\n  HostName alpha.example\n' | base64 > "$BW_TEST_STORE/alpha.notes"
printf 'Host beta\n  HostName beta.example\n' | base64 > "$BW_TEST_STORE/beta.notes"
conf_dir="$fake_home/.ssh/conf.d"

# 1. load <name> restores only that config, mode 600
"$bw_ssh_config" load alpha > /dev/null
[ "$(cat "$conf_dir/alpha.conf")" = "$(printf 'Host alpha\n  HostName alpha.example')" ] || fail 'alpha.conf content differs'
[ "$(stat -c %a "$conf_dir/alpha.conf")" = 600 ] || fail 'alpha.conf is not mode 600'
[ ! -e "$conf_dir/beta.conf" ] || fail 'load <name> also restored beta'

# 2. load without a name shows usage (exit 1) before touching the vault
rm -rf "$conf_dir"
BW_TEST_LOCKED=1 "$bw_ssh_config" load > "$test_root/usage.out" 2>&1 && fail 'load without name succeeded'
grep -q '^Usage:' "$test_root/usage.out" || fail 'load without name did not print usage'
grep -q 'locked' "$test_root/usage.out" && fail 'load without name reached the vault'
[ ! -e "$conf_dir/beta.conf" ] || fail 'load without name restored beta'

# 3. unknown name fails nonzero and keeps the existing file intact
mkdir -p "$conf_dir"
printf 'OLD\n' > "$conf_dir/no-such.conf"
"$bw_ssh_config" load no-such 2> /dev/null && fail 'load succeeded for missing item'
[ "$(cat "$conf_dir/no-such.conf")" = OLD ] || fail 'failed load clobbered the existing file'
[ -z "$(find "$conf_dir" -name '.*' -type f)" ] || fail 'failed load left a temp file'

# 4. load-all restores every config
"$bw_ssh_config" load-all > /dev/null
[ -e "$conf_dir/alpha.conf" ] || fail 'load-all skipped alpha'
[ "$(cat "$conf_dir/beta.conf")" = "$(printf 'Host beta\n  HostName beta.example')" ] || fail 'beta.conf content differs'
[ "$(stat -c %a "$conf_dir/beta.conf")" = 600 ] || fail 'beta.conf is not mode 600'

echo "bw-ssh-config contract OK"
