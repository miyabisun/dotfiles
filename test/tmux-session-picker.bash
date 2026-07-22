#!/usr/bin/env bash
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
    if [[ "$*" == *'@agent_bell'* ]]; then
      printf '%s\n' 0current 0normal-one 1bell-one 0_internal 1bell-two 0normal-two
    else
      printf '%s\n' current normal-one _internal normal-two
    fi
    ;;
  switch-client|attach)
    printf '%s\n' "$*" >>"$TMUX_SESSION_PICKER_TMUX_LOG"
    ;;
  *)
    exit 90
    ;;
esac
TMUX

cat >"$fake_home/.fzf/bin/fzf" <<'FZF'
#!/usr/bin/env bash
tee "$TMUX_SESSION_PICKER_FZF_INPUT" \
  | sed 's/\x1b\[[0-9;]*m//g' \
  | sed -n '1p'
FZF

chmod +x "$fake_bin/tmux" "$fake_home/.fzf/bin/fzf"

PATH="$fake_bin:/usr/bin:/bin" \
  HOME="$fake_home" \
  TMUX_SESSION_PICKER_FZF_INPUT="$fzf_input" \
  TMUX_SESSION_PICKER_TMUX_LOG="$tmux_log" \
  bash "$repo_root/config/tmux/bin/tmux-session-picker"

sed 's/\x1b\[[0-9;]*m//g' "$fzf_input" >"$test_root/plain-input"
cat >"$test_root/expected-picker" <<'EXPECTED'
bell-one
bell-two
normal-one
normal-two
EXPECTED
cmp "$test_root/expected-picker" "$test_root/plain-input"
grep -F $'\033[1;38;5;255;48;5;24mbell-one\033[0m' "$fzf_input" >/dev/null
grep -Fx 'switch-client -t =bell-one' "$tmux_log" >/dev/null

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
