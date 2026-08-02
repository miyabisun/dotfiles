#!/usr/bin/env bash
# assert する文字列は対象ファイルの literal なので、$ を展開させない
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config="$repo_root/config/herdr/config.toml"

# 体験の契約1: dotfiles 管理の herdr 設定が存在し、TOML として妥当
test -f "$config"
python3 - "$config" <<'EOF'
import sys, tomllib
with open(sys.argv[1], 'rb') as f:
    data = tomllib.load(f)

# 体験の契約2: 「herdr 既定を活かし、下分割だけ prefix+s」(user 指示) +
# pen の keys.command 3本。[keys] は完全一致で assert し退行検知する。
# ([keys] 以外のテーブルは user が直接育てる領域なので assert しない)
keys = data['keys']
assert set(keys.keys()) == {'split_horizontal', 'command'}, set(keys.keys())
assert keys['split_horizontal'] == 'prefix+s'
assert len(keys['command']) == 3, len(keys['command'])
expected = [
    {'key': 'alt+s', 'type': 'shell', 'command': 'pen save'},
    {'key': 'alt+x', 'type': 'popup', 'command': 'pen close',
     'width': '50%', 'height': '40%'},
    {'key': 'prefix+space', 'type': 'popup', 'command': 'pen picker',
     'width': '90%', 'height': '90%'},
]
actual = sorted(keys['command'], key=lambda c: c['key'])
assert actual == sorted(expected, key=lambda c: c['key']), actual
print('herdr config contract: ok')
EOF

# 体験の契約3: bin/install が config.toml をファイル単位で ~/.config/herdr へ張る
grep -Fq 'mkdir -p "$HOME/.config/herdr"' "$repo_root/bin/install"
grep -Fq 'link "config/herdr/config.toml" "$HOME/.config/herdr"' "$repo_root/bin/install"
# invariant: ~/.config/herdr は herdr ランタイム実ディレクトリ (sock/log/session)。
# dir 単位の link を張ると runtime 状態を dotfiles に巻き込むため、存在しないこと
if grep -Eq 'link "config/herdr" ' "$repo_root/bin/install"; then
  echo 'forbidden: dir-level herdr link in bin/install' >&2
  exit 1
fi

echo "herdr config test: pass"
