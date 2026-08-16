#!/usr/bin/env bash
# dotfiles 管理の herdr 設定を、herdr 公式 validator (`herdr config check`) に
# 食わせる実挙動テスト。
#
# repo の config/ は既に XDG レイアウト (config/herdr/config.toml) なので、
# XDG_CONFIG_HOME を repo の config/ へ向ければ validator が repo の実体を
# そのまま検証する。TOML の妥当性だけでなく、未知の設定キーや不正な keybinding も
# validator が診断する (実測済み) ため、期待値の写経は持たない。
#
# ネガティブ対照: 壊れた config を一時ディレクトリに置いて同じコマンドを叩き、
# rc が 0 以外になることを確認する。validator が指定先を実際に読んでいる証拠で、
# これが無いと「常に ok を返す実装」でもこのテストは通ってしまう。
#
# 実測: config.toml が存在しないと validator は既定値で ok を返す。よって
# 「dotfiles が herdr 設定を持っていること」は存在検査で別に固定する。
#
# 隣接する契約はここに持たない: bin/install の link は
# test/install-relocatable.bash が実際に install を走らせて確認し、
# herdr-swap の挙動は test/herdr-swap.bash が fake socket で測っている。
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_home="$repo_root/config"
config="$config_home/herdr/config.toml"

fail() {
  printf 'herdr config test: %s\n' "$*" >&2
  exit 1
}

# 道具が無いときは skip せず fail する。「herdr が無いから通った」を作らない
command -v herdr >/dev/null 2>&1 \
  || fail 'herdr が無いのでこのテストを実行できない'
[ -f "$config" ] || fail "dotfiles 管理の herdr 設定が無い: $config"

# 本体: repo の config/ を XDG_CONFIG_HOME に据えて公式 validator へ通す
# (XDG 仕様では相対 path は未設定扱いで無視されるため絶対 path を渡す)
env XDG_CONFIG_HOME="$config_home" herdr config check \
  || fail "herdr config check が repo の設定を通さなかった: $config"

# --- ネガティブ対照 -------------------------------------------------------
tmp_config_home="$(mktemp -d)"
trap 'rm -rf "$tmp_config_home"' EXIT
mkdir -p "$tmp_config_home/herdr"

# stdin から壊れた config 本文を受け取り、validator が拒否することを確認する
expect_reject() {
  local label="$1"
  cat >"$tmp_config_home/herdr/config.toml"
  if env XDG_CONFIG_HOME="$tmp_config_home" herdr config check >/dev/null 2>&1; then
    fail "壊れた設定が通ってしまった (validator が指定先を読んでいない): $label"
  fi
}

expect_reject 'TOML parse error' <<'EOF'
broken = [
EOF

expect_reject 'invalid keybinding' <<'EOF'
[keys]
split_horizontal = "not+a+key"
EOF

expect_reject 'unknown config key' <<'EOF'
[keys]
bogus_action = "prefix+z"
EOF

echo "herdr config test: pass"
