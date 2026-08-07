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
expected_keys = {'split_horizontal', 'settings', 'command', 'next_tab',
                 'previous_tab', 'next_workspace', 'previous_workspace'}
assert set(keys.keys()) == expected_keys, set(keys.keys())
assert keys['split_horizontal'] == 'prefix+s'
# split_horizontal=prefix+s が既定の settings を shadow するため、iTerm の
# Cmd+, の指癖に合わせて prefix+comma へ明示移設する
assert keys['settings'] == 'prefix+comma', keys['settings']
# hjkl は2層: alt+hjkl = 移動 (直接・連打向き)、prefix+ctrl+hjkl = 交換
# (keys.command の herdr-swap 経由。tmux 時代の並び替え層)。
# タブは左右 (h/l)、workspace は上下 (j/k)。herdr 既定の prefix 系は残す。
# nav 配列に prefix+ctrl が残ると交換層と二重割当になるため完全一致で見る
assert keys['previous_tab'] == ['prefix+p', 'alt+h'], keys['previous_tab']
assert keys['next_tab'] == ['prefix+n', 'alt+l'], keys['next_tab']
assert keys['next_workspace'] == ['alt+j'], keys['next_workspace']
assert keys['previous_workspace'] == ['alt+k'], keys['previous_workspace']
assert len(keys['command']) == 7, len(keys['command'])
expected = [
    {'key': 'alt+s', 'type': 'shell', 'command': 'pen save'},
    {'key': 'alt+x', 'type': 'popup', 'command': 'pen close',
     'width': '50%', 'height': '40%'},
    {'key': 'prefix+space', 'type': 'popup', 'command': 'pen picker',
     'width': '90%', 'height': '90%'},
    # 交換層: 方向は移動層と同じ対応 (h/l=タブ左右、j/k=workspace 下上)
    {'key': 'prefix+ctrl+h', 'type': 'shell', 'command': 'herdr-swap tab previous'},
    {'key': 'prefix+ctrl+l', 'type': 'shell', 'command': 'herdr-swap tab next'},
    {'key': 'prefix+ctrl+j', 'type': 'shell', 'command': 'herdr-swap workspace next'},
    {'key': 'prefix+ctrl+k', 'type': 'shell', 'command': 'herdr-swap workspace previous'},
]
actual = sorted(keys['command'], key=lambda c: c['key'])
assert actual == sorted(expected, key=lambda c: c['key']), actual
print('herdr config contract: ok')
EOF

# 交換層の実体: herdr-swap は実行可能な整形式 python で、install が PATH へ張る
swap="$repo_root/config/herdr/bin/herdr-swap"
test -x "$swap" || { echo 'herdr-swap must be executable' >&2; exit 1; }
python3 -m py_compile "$swap"
grep -Fq 'link "config/herdr/bin/herdr-swap" "$HOME/.local/bin"' "$repo_root/bin/install"

# design authority: root DESIGN.md が interaction contract を単一で持つ
# (frontend-design skill の authority 規則。docs/DESIGN.md は legacy fallback
# なので新設しない)
design="$repo_root/DESIGN.md"
test -f "$design"
if [ -f "$repo_root/docs/DESIGN.md" ]; then
  echo 'authority must stay in root DESIGN.md only' >&2
  exit 1
fi
grep -Fq '交換後も focus は同じ tab / workspace に残る' "$design"
grep -Fq 'wrap しない' "$design"
grep -Fq '削除前の並びに対する位置' "$design"
grep -Fq 'prefix+ctrl+h' "$design"
# 運用 runtime 証跡 (pane ID 等) を design 文書に書かない
if grep -Eq 'w[0-9]+:p[0-9]+' "$design"; then
  echo 'DESIGN.md must not carry runtime pane IDs' >&2
  exit 1
fi

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
