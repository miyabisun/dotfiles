#!/usr/bin/env bash
# Contract: bin/install-apps installs Antigravity CLI (agy) the way the
# official install.sh does (manifest -> tar.gz -> sha512 -> ~/.local/bin/agy)
# but never runs `agy install`, so shell rc files stay untouched.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

manifest_url='https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_amd64.json'
package_url='https://storage.googleapis.com/antigravity-public/antigravity-cli/9.9.9-1/linux-x64/cli_linux_x64.tar.gz'

fake_bin="$test_root/bin"
mkdir -p "$fake_bin"

# The packaged binary records every invocation so `agy install` is observable.
package_root="$test_root/package"
mkdir -p "$package_root"
cat >"$package_root/antigravity" <<'AGY'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$AGY_TEST_CALLS"
[ "${1:-}" = --version ] && echo 9.9.9
exit 0
AGY
chmod +x "$package_root/antigravity"
tar -czf "$test_root/package.tar.gz" -C "$package_root" antigravity
package_sha512="$(sha512sum "$test_root/package.tar.gz" | awk '{ print $1 }')"

cat >"$fake_bin/curl" <<STUB
#!/usr/bin/env bash
set -euo pipefail
url="" output=""
while [ "\$#" -gt 0 ]; do
  case "\$1" in
    -o) output="\$2"; shift 2 ;;
    http*) url="\$1"; shift ;;
    *) shift ;;
  esac
done
printf '%s\n' "\$url" >>"\$AGY_TEST_CURL_LOG"
case "\$url" in
  '$manifest_url')
    sha="\${AGY_TEST_SHA512:-$package_sha512}"
    printf '{\n  "version": "9.9.9",\n  "url": "%s",\n  "sha512": "%s"\n}\n' \
      '$package_url' "\$sha" >"\$output"
    ;;
  '$package_url') cp '$test_root/package.tar.gz' "\$output" ;;
  *) exit 22 ;;
esac
STUB
chmod +x "$fake_bin/curl"

run_step() {
  local home="$1"
  shift
  mkdir -p "$home/.local/bin" "$home/tmp"
  printf '# bash rc\n' >"$home/.bashrc"
  printf '# zsh rc\n' >"$home/.zshrc"
  env "$@" PATH="$fake_bin:$home/.local/bin:/usr/bin:/bin" HOME="$home" \
    TMPDIR="$home/tmp" AGY_TEST_CALLS="$home/calls.log" \
    AGY_TEST_CURL_LOG="$home/curl.log" \
    bash "$repo_root/bin/install-apps" --run-step install_agy >"$home/out.log" 2>&1
}

assert_rc_untouched() {
  test "$(cat "$1/.bashrc")" = '# bash rc'
  test "$(cat "$1/.zshrc")" = '# zsh rc'
  if [ -f "$1/calls.log" ] && grep -q '^install' "$1/calls.log"; then
    echo 'agy install must not run' >&2
    exit 1
  fi
}

# Not installed: fetch, verify and place agy without touching rc files.
fresh="$test_root/fresh"
run_step "$fresh"
test -x "$fresh/.local/bin/agy"
test ! -L "$fresh/.local/bin/agy"
cmp -s "$fresh/.local/bin/agy" "$package_root/antigravity"
grep -Fxq "$manifest_url" "$fresh/curl.log"
assert_rc_untouched "$fresh"
test -z "$(find "$fresh/tmp" -mindepth 1 -print -quit)"

# Already installed: do nothing, fetch nothing.
installed="$test_root/installed"
mkdir -p "$installed/.local/bin"
cp "$package_root/antigravity" "$installed/.local/bin/agy"
before="$(sha256sum <"$installed/.local/bin/agy")"
run_step "$installed"
test ! -e "$installed/curl.log"
test "$before" = "$(sha256sum <"$installed/.local/bin/agy")"
grep -Fq 'Antigravity CLI already installed' "$installed/out.log"
assert_rc_untouched "$installed"

# Checksum mismatch: fail and leave nothing behind.
mismatch="$test_root/mismatch"
if run_step "$mismatch" AGY_TEST_SHA512="$(printf '0%.0s' {1..128})"; then
  echo 'install_agy must fail on a checksum mismatch' >&2
  exit 1
fi
grep -Fq 'Checksum mismatch for Antigravity CLI' "$mismatch/out.log"
test ! -e "$mismatch/.local/bin/agy"
test ! -e "$mismatch/calls.log"
assert_rc_untouched "$mismatch"
test -z "$(find "$mismatch/tmp" -mindepth 1 -print -quit)"

echo 'install-apps agy test: pass'
