#!/usr/bin/env bash
# Contract: tracked file は特定ユーザーの home を配布仕様として固定しない。
# dotfiles は macbook (/Users/...) でも別ユーザーでも同じ内容で動くこと。
# runtime が展開する $HOME / ${HOME} / ~ だけが home の正しい綴りである。
# guard 自身も BSD grep (macOS) で動く POSIX ERE に限定する。
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

guard="test/portable-paths.bash"
pattern='(/home/[A-Za-z0-9_][A-Za-z0-9_-]*/|/Users/[A-Za-z0-9_][A-Za-z0-9_-]*/|C:\\Users\\)'

# system prefix (/home/linuxbrew) は user home ではないので、マスクしてから
# 再照合する (行単位の除外だと同じ行の別 user home を見逃す)。
scan_file() {
  grep -EnH "$pattern" "$1" 2>/dev/null \
    | sed 's|/home/linuxbrew/|<linuxbrew>/|g' \
    | grep -E "$pattern" || true
}

# 自己検査: この guard が3種の user home を検知し、linuxbrew を通すこと。
# fixture の literal は連結で組み立て、guard 自身を汚さない。
selftest="$(mktemp -d)"
violations="$(mktemp)"
trap 'rm -rf "$selftest" "$violations"' EXIT
printf '%s\n' "/home/""alice/x" >"$selftest/linux"
printf '%s\n' "/Users/""bob/x" >"$selftest/mac"
printf '%s%s\n' "C:\\Users" "\\carol\\x" >"$selftest/win"
printf '%s\n' "/home/""linuxbrew/bin/brew" >"$selftest/brew"
for fixture in linux mac win; do
  if [[ -z "$(scan_file "$selftest/$fixture")" ]]; then
    echo "guard self-test failed: $fixture user home not detected" >&2
    exit 1
  fi
done
if [[ -n "$(scan_file "$selftest/brew")" ]]; then
  echo 'guard self-test failed: linuxbrew must not be flagged' >&2
  exit 1
fi

git ls-files -z | while IFS= read -r -d '' file; do
  [[ "$file" == "$guard" ]] && continue
  scan_file "$file" >>"$violations"
done

if [[ -s "$violations" ]]; then
  echo 'tracked files must not hard-code a user home path:' >&2
  cat "$violations" >&2
  exit 1
fi

echo 'portable paths contract: ok'
