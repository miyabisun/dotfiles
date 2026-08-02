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

# 体験の契約2: 「herdr 既定を活かし、下分割だけ prefix+s」(user 指示)。
# [keys] は完全一致で assert し、意図しない override の追加・削除を退行検知する
assert data['keys'] == {'split_horizontal': 'prefix+s'}, data['keys']
# [keys] 以外のテーブルも増えていないこと (既定で足りるものを override しない)
assert set(data.keys()) == {'keys'}, set(data.keys())
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
