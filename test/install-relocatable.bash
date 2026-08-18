#!/usr/bin/env bash
# Contract: bin/install は自己位置から repo root を導出し、空白を含む任意配置で
# 冪等に動く。rc の managed block は BEGIN/END marker で管理し、0 個なら追加、
# 1 個なら丸ごと置換、marker 破損・重複なら rc を変えずに abort する。
# tracked file は legacy root (~/.dotfiles) を機能参照しない。
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

guard="test/install-relocatable.bash"

# legacy root への機能参照が tracked file に残っていないこと。
# (.dotfiles-agent-runtime は runtime file 名であり root 参照ではない)
# 検査 pattern なので展開しない
# shellcheck disable=SC2016
legacy_re='(~|\$HOME|\$\{HOME\})/\.dotfiles'
legacy_hits="$(cd "$repo_root" && git grep -nE "$legacy_re" -- . ":(exclude)$guard" || true)"
if [[ -n "$legacy_hits" ]]; then
  echo 'tracked files must not reference the legacy ~/.dotfiles root:' >&2
  printf '%s\n' "$legacy_hits" >&2
  exit 1
fi

# 空白を含む任意配置へ working tree をコピーする (.git は不要)。
repo_copy="$test_root/re po/dotfiles"
mkdir -p "$repo_copy"
(cd "$repo_root" && tar -cf - --exclude=.git .) | (cd "$repo_copy" && tar -xf -)

fake_bin="$test_root/bin"
mkdir -p "$fake_bin"
# sheldon lock は network を触るため stub で遮る (/usr/bin の実物を shadow)。
cat >"$fake_bin/sheldon" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$fake_bin/sheldon"
run_path="$fake_bin:/usr/bin:/bin"

start_mark='# DOTFILES_START'
end_mark='# DOTFILES_END'

seed_rc() {
  local home="$1"
  mkdir -p "$home"
  printf '%s\n' '# before-sentinel bash' 'export SENTINEL_BASH=1' >"$home/.bashrc"
  printf '%s\n' '# before-sentinel zsh' 'export SENTINEL_ZSH=1' >"$home/.zshrc"
}

run_install() {
  local home="$1"
  HOME="$home" PATH="$run_path" bash "$repo_copy/bin/install"
}

snapshot_home() {
  local home="$1"
  (cd "$home" && find . -mindepth 1 | LC_ALL=C sort | while IFS= read -r p; do
    if [[ -L "$p" ]]; then
      printf 'L %s -> %s\n' "$p" "$(readlink "$p")"
    elif [[ -f "$p" ]]; then
      printf 'F %s %s\n' "$p" "$(sha256sum <"$p" | awk '{ print $1 }')"
    else
      printf 'D %s\n' "$p"
    fi
  done)
}

sha256_file() {
  sha256sum <"$1" | awk '{ print $1 }'
}

home1="$test_root/home1"
seed_rc "$home1"
run_install "$home1" >"$test_root/run1.out"

# 全 managed symlink がコピーした repo を直接指すこと。
managed_links="
.editorconfig .editorconfig
.ssh/config ssh/config
.config/git config/git
.config/nvim config/nvim
.config/tmux config/tmux
.claude/skills agent/common/skills
.claude/agents agent/common/agents
.claude/designs agent/common/designs
.claude/hooks agent/claude/hooks
.claude/CLAUDE.md agent/claude/CLAUDE.md
.claude/GLOBAL.md agent/common/rules/GLOBAL.md
.claude/settings.json agent/claude/settings.json
.config/herdr/config.toml config/herdr/config.toml
.local/bin/herdr-swap config/herdr/bin/herdr-swap
.codex/hooks.json agent/codex/hooks.json
.codex/hooks agent/codex/hooks
.codex/agents agent/codex/agents
.codex/AGENTS.md agent/common/rules/GLOBAL.md
.grok/hooks agent/grok/hooks
.grok/skills agent/common/skills
.grok/agents agent/common/agents
.grok/designs agent/common/designs
.grok/AGENTS.md agent/common/rules/GLOBAL.md
.agents/skills agent/common/skills
.agents/agents agent/common/agents
.agents/designs agent/common/designs
.local/bin/notify-turn-end.sh agent/codex/hooks/notify-turn-end.sh
.local/bin/meiseki agent/common/bin/meiseki
.local/bin/meiseki-lint agent/common/bin/meiseki-lint
.local/bin/meiseki-rewrite agent/common/bin/meiseki-rewrite
.local/bin/tmux-session-picker config/tmux/bin/tmux-session-picker
.local/bin/tmux-mux config/tmux/bin/tmux-mux
.config/sheldon/plugins.toml config/zsh/plugins.toml
"
while read -r link_rel target_rel; do
  [[ -n "$link_rel" ]] || continue
  link_path="$home1/$link_rel"
  expected="$repo_copy/$target_rel"
  if [[ ! -L "$link_path" ]]; then
    echo "managed link missing: $link_rel" >&2
    exit 1
  fi
  actual="$(readlink "$link_path")"
  if [[ "$actual" != "$expected" ]]; then
    echo "managed link $link_rel points to $actual (want $expected)" >&2
    exit 1
  fi
  if [[ "$(realpath "$link_path")" != "$(realpath "$expected")" ]]; then
    echo "managed link $link_rel does not resolve into the repo copy" >&2
    exit 1
  fi
done <<<"$managed_links"

# 実体が repo に無い .deepl.json の link 項目は撤去済みであること。
if [[ -e "$home1/.config/.deepl.json" || -L "$home1/.config/.deepl.json" ]]; then
  echo '.deepl.json must not be linked anymore' >&2
  exit 1
fi

# rc block: 各 rc に marker がちょうど 1 組、内容はコピー先 repo を指し、
# 既存行は保全される。legacy root への参照は書かれない。
for rcname in .bashrc .zshrc; do
  rcfile="$home1/$rcname"
  test "$(grep -cFx "$start_mark" "$rcfile")" -eq 1
  test "$(grep -cFx "$end_mark" "$rcfile")" -eq 1
  grep -qF "$repo_copy/config/bash/exports.sh" "$rcfile"
  grep -qF 'before-sentinel' "$rcfile"
  if grep -qE "$legacy_re" "$rcfile"; then
    echo "$rcname must not reference ~/.dotfiles" >&2
    exit 1
  fi
done
grep -qF "$repo_copy/config/zsh/init.zsh" "$home1/.zshrc"
if grep -qF "$repo_copy/config/zsh/init.zsh" "$home1/.bashrc"; then
  echo '.bashrc must not source the zsh entry point' >&2
  exit 1
fi

# exports.sh は自己位置から bin/bw を解決する (bash / zsh 両方)。
bash_path="$(HOME="$home1" PATH="$run_path" \
  bash -c ". \"$repo_copy/config/bash/exports.sh\"; printf %s \"\$PATH\"")"
case ":$bash_path:" in
  *":$repo_copy/bin/bw:"*) ;;
  *)
    echo "exports.sh (bash) did not add the repo copy bin/bw to PATH" >&2
    exit 1
    ;;
esac
if command -v zsh >/dev/null 2>&1; then
  zsh_path="$(HOME="$home1" PATH="$run_path" \
    zsh -c ". \"$repo_copy/config/bash/exports.sh\"; printf %s \"\$PATH\"")"
  case ":$zsh_path:" in
    *":$repo_copy/bin/bw:"*) ;;
    *)
      echo "exports.sh (zsh) did not add the repo copy bin/bw to PATH" >&2
      exit 1
      ;;
  esac
fi

# 2 回目の実行は状態を 1 bit も変えない (冪等)。
snap1="$(snapshot_home "$home1")"
run_install "$home1" >"$test_root/run2.out"
snap2="$(snapshot_home "$home1")"
if [[ "$snap1" != "$snap2" ]]; then
  echo 'second install run must not change any state:' >&2
  diff <(printf '%s\n' "$snap1") <(printf '%s\n' "$snap2") >&2 || true
  exit 1
fi
test "$(grep -cFx "$start_mark" "$home1/.bashrc")" -eq 1
test "$(grep -cFx "$start_mark" "$home1/.zshrc")" -eq 1

# 既存 block (legacy 内容) は丸ごと新内容へ置換され、前後の行は保全される。
home2="$test_root/home2"
seed_rc "$home2"
for rcname in .bashrc .zshrc; do
  {
    printf '%s\n' "$start_mark"
    # rc に書く fixture 行なので展開しない
    # shellcheck disable=SC2016
    printf '%s\n' '[ -f "$HOME/LEGACY/config/bash/exports.sh" ] && . "$HOME/LEGACY/config/bash/exports.sh"'
    printf '%s\n' "$end_mark"
    printf '%s\n' '# after-sentinel'
  } >>"$home2/$rcname"
done
run_install "$home2" >"$test_root/run-replace.out"
for rcname in .bashrc .zshrc; do
  rcfile="$home2/$rcname"
  test "$(grep -cFx "$start_mark" "$rcfile")" -eq 1
  test "$(grep -cFx "$end_mark" "$rcfile")" -eq 1
  if grep -qF 'LEGACY' "$rcfile"; then
    echo "old block content must be replaced in $rcname" >&2
    exit 1
  fi
  grep -qF "$repo_copy/config/bash/exports.sh" "$rcfile"
  grep -qF 'before-sentinel' "$rcfile"
  grep -qFx '# after-sentinel' "$rcfile"
done

# 破損時は preflight で全 rc を検証してから abort し、破損した rc だけで
# なく「どの rc にも」書き込まない。before/after は全 rc の hash で比べる。
expect_abort_all_rc_unchanged() {
  local home="$1" label="$2" outfile="$3"
  local before_bash before_zsh
  before_bash="$(sha256_file "$home/.bashrc")"
  before_zsh="$(sha256_file "$home/.zshrc")"
  if run_install "$home" >"$outfile" 2>&1; then
    echo "install must abort: $label" >&2
    exit 1
  fi
  if [[ "$before_bash" != "$(sha256_file "$home/.bashrc")" ]]; then
    echo "abort must leave .bashrc untouched: $label" >&2
    exit 1
  fi
  if [[ "$before_zsh" != "$(sha256_file "$home/.zshrc")" ]]; then
    echo "abort must leave .zshrc untouched: $label" >&2
    exit 1
  fi
}

# marker 破損 (start のみ) は全 rc を変えずに abort する。
home3="$test_root/home3"
seed_rc "$home3"
printf '%s\n' "$start_mark" 'broken content without end marker' >>"$home3/.bashrc"
expect_abort_all_rc_unchanged "$home3" 'broken marker pair in .bashrc' \
  "$test_root/run-broken.out"

# 異常が後段の rc にあるケース: bash は marker 無し (正常)、zsh は 2 組。
# preflight が先に全 rc を見るので、bash にも一切書かれない。
home4="$test_root/home4"
seed_rc "$home4"
for _ in 1 2; do
  printf '%s\n' "$start_mark" 'dup' "$end_mark" >>"$home4/.zshrc"
done
expect_abort_all_rc_unchanged "$home4" 'duplicated marker blocks in .zshrc' \
  "$test_root/run-dup.out"

# marker 順序逆 (end が先) も全 rc を変えずに abort する。
home5="$test_root/home5"
seed_rc "$home5"
printf '%s\n' "$end_mark" 'reversed' "$start_mark" >>"$home5/.zshrc"
expect_abort_all_rc_unchanged "$home5" 'reversed markers in .zshrc' \
  "$test_root/run-reversed.out"

echo "install relocatable test: pass"
