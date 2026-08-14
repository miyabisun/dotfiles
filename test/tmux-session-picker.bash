#!/usr/bin/env bash
# assert する文字列は対象ファイルの literal なので、$ や ` を展開させない
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fake_bin="$test_root/bin"
fake_home="$test_root/home"
fzf_input="$test_root/fzf-input"
tmux_log="$test_root/tmux.log"
mkdir -p "$fake_bin" "$fake_home/.fzf/bin"

cat >"$fake_bin/tmux" <<'TMUX'
#!/usr/bin/env bash
case "$1" in
  display-message)
    printf '%s\n' current
    ;;
  list-sessions)
    printf '%s\n' current normal-one _internal normal-two
    ;;
  list-panes)
    printf '%s\n' '%1'
    ;;
  has-session)
    exit 0
    ;;
  switch-client|attach|list-windows|capture-pane)
    printf '%s\n' "$*" >>"$TMUX_SESSION_PICKER_TMUX_LOG"
    ;;
  *)
    exit 90
    ;;
esac
TMUX

cat >"$fake_bin/mux" <<'MUX'
#!/usr/bin/env bash
case "${1:-}" in
  ls) exit 0 ;;
  *) exit 90 ;;
esac
MUX

cat >"$fake_home/.fzf/bin/fzf" <<'FZF'
#!/usr/bin/env bash
tee "$TMUX_SESSION_PICKER_FZF_INPUT" >/dev/null
if grep -q '^●' "$TMUX_SESSION_PICKER_FZF_INPUT"; then
  printf '\n● normal-one\n'
else
  sed -n '1p' "$TMUX_SESSION_PICKER_FZF_INPUT"
fi
FZF

chmod +x "$fake_bin/tmux" "$fake_bin/mux" "$fake_home/.fzf/bin/fzf"

PATH="$fake_bin:$fake_home/.fzf/bin:/usr/bin:/bin" \
  HOME="$fake_home" \
  MUX_CONFIG="$test_root/empty-mux" \
  TMUX='test-socket,1,0' \
  TMUX_SESSION_PICKER_FZF_INPUT="$fzf_input" \
  TMUX_SESSION_PICKER_TMUX_LOG="$tmux_log" \
  bash "$repo_root/config/tmux/bin/tmux-session-picker"

# wrapper → tmux-mux picker。生存 session を ● で統合し、_internal は出さない。
cat >"$test_root/expected-picker" <<'EXPECTED'
● current
● normal-one
● normal-two
EXPECTED
cmp "$test_root/expected-picker" "$fzf_input"
if grep -q $'\033\[' "$fzf_input"; then
  echo 'picker must not colour sessions any more' >&2
  exit 1
fi
grep -Fx 'switch-client -t =normal-one' "$tmux_log" >/dev/null

rm -f "$fzf_input" "$tmux_log"
env -u TMUX PATH="$fake_home/.fzf/bin:$fake_bin:/usr/bin:/bin" \
  TMUX_SESSION_PICKER_FZF_INPUT="$fzf_input" \
  TMUX_SESSION_PICKER_TMUX_LOG="$tmux_log" \
  zsh -f -c 'source "$1"; a' zsh "$repo_root/config/zsh/functions.zsh"

cat >"$test_root/expected-a" <<'EXPECTED'
current
normal-one
normal-two
EXPECTED
cmp "$test_root/expected-a" "$fzf_input"
grep -Fx 'attach -t =current' "$tmux_log" >/dev/null

rm -f "$fzf_input" "$tmux_log"
env -u TMUX PATH="$fake_home/.fzf/bin:$fake_bin:/usr/bin:/bin" \
  TMUX_SESSION_PICKER_FZF_INPUT="$fzf_input" \
  TMUX_SESSION_PICKER_TMUX_LOG="$tmux_log" \
  zsh -f -c 'source "$1"; a _internal' zsh "$repo_root/config/zsh/functions.zsh"

test ! -e "$fzf_input"
grep -Fx 'attach -t =_internal' "$tmux_log" >/dev/null

echo "tmux session picker test: pass"
