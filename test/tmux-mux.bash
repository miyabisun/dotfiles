#!/usr/bin/env bash
# tmux-mux: herdr-aligned picker / cycle / save / close, plus tmux.conf binds.
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mux_bin="$repo_root/config/tmux/bin/tmux-mux"
conf="$repo_root/config/tmux/tmux.conf"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

test -x "$mux_bin" || { echo 'tmux-mux must be executable' >&2; exit 1; }
grep -Fq 'link "config/tmux/bin/tmux-mux" "$HOME/.local/bin"' "$repo_root/bin/install"
grep -Fq 'link "config/tmux/bin/tmux-session-picker" "$HOME/.local/bin"' "$repo_root/bin/install"

fake_bin="$test_root/bin"
fake_home="$test_root/home"
fzf_input="$test_root/fzf-input"
cmd_log="$test_root/cmd.log"
mux_dir="$test_root/mux"
mkdir -p "$fake_bin" "$fake_home/.fzf/bin" "$mux_dir"

cat >"$fake_bin/tmux" <<'TMUX'
#!/usr/bin/env bash
set -euo pipefail
log="${TMUX_MUX_CMD_LOG:-/dev/null}"
case "${1:-}" in
  display-message)
    if [ "${2:-}" = '-p' ]; then
      printf '%s\n' "${TMUX_MUX_CURRENT:-current}"
    else
      printf 'tmux %s\n' "$*" >>"$log"
    fi
    ;;
  list-sessions)
    printf '%s\n' ${TMUX_MUX_SESSIONS:-current normal-one _internal normal-two}
    ;;
  list-panes)
    printf '%s\n' '%1'
    ;;
  has-session)
    name="${4:-${3:-}}"
    name="${name#=}"
    printf '%s\n' ${TMUX_MUX_SESSIONS:-} | grep -Fxq "$name"
    ;;
  switch-client|attach|kill-session|list-windows|capture-pane)
    printf 'tmux %s\n' "$*" >>"$log"
    ;;
  *)
    printf 'tmux %s\n' "$*" >>"$log"
    exit 90
    ;;
esac
TMUX

cat >"$fake_bin/mux" <<'MUX'
#!/usr/bin/env bash
set -euo pipefail
log="${TMUX_MUX_CMD_LOG:-/dev/null}"
printf 'mux %s\n' "$*" >>"$log"
case "${1:-}" in
  ls)
    if [ -d "${MUX_CONFIG:-}" ]; then
      for f in "${MUX_CONFIG}"/*.toml; do
        [ -f "$f" ] || continue
        basename "$f" .toml
      done | LC_ALL=C sort
    fi
    ;;
  snapshot)
    if [ "${TMUX_MUX_SNAPSHOT_FAIL:-0}" = 1 ]; then
      echo 'mux snapshot failed' >&2
      exit 1
    fi
    cat "${TMUX_MUX_SNAPSHOT:-/dev/null}"
    ;;
  save)
    shift
    name=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --force) shift ;;
        *) name="$1"; shift ;;
      esac
    done
    cat >"${MUX_CONFIG}/${name}.toml"
    ;;
  check)
    printf '%s: ok\n' "${2:-}"
    ;;
  '')
    printf 'mux-open %s\n' "${MUX_SELECT:-}" >>"$log"
    ;;
  *)
    exit 90
    ;;
esac
MUX

cat >"$fake_home/.fzf/bin/fzf" <<'FZF'
#!/usr/bin/env bash
set -euo pipefail
# Each invocation appends the list it saw, so Space loops can be inspected.
if [ -n "${TMUX_MUX_FZF_INPUT:-}" ]; then
  tee -a "$TMUX_MUX_FZF_INPUT" >/dev/null
else
  cat >/dev/null
fi
if [ -n "${TMUX_MUX_FZF_ROUND:-}" ]; then
  n=0
  [ -f "$TMUX_MUX_FZF_ROUND" ] && n="$(cat "$TMUX_MUX_FZF_ROUND")"
  n=$((n + 1))
  printf '%s\n' "$n" >"$TMUX_MUX_FZF_ROUND"
  eval "out=\${TMUX_MUX_FZF_OUT_${n}:-}"
  if [ -n "$out" ]; then
    printf '%s\n' "$out"
    exit 0
  fi
  exit 130
fi
if [ -n "${TMUX_MUX_FZF_OUT:-}" ]; then
  printf '%s\n' "$TMUX_MUX_FZF_OUT"
  exit 0
fi
exit 130
FZF

chmod +x "$fake_bin/tmux" "$fake_bin/mux" "$fake_home/.fzf/bin/fzf"

run_mux() {
  PATH="$fake_bin:$fake_home/.fzf/bin:/usr/bin:/bin" \
    HOME="$fake_home" \
    MUX_CONFIG="${MUX_CONFIG:-$mux_dir}" \
    TMUX="${TMUX:-test-socket,1,0}" \
    TMUX_PANE="${TMUX_PANE:-%1}" \
    TMUX_MUX_CMD_LOG="$cmd_log" \
    TMUX_MUX_FZF_INPUT="$fzf_input" \
    TMUX_MUX_CURRENT="${TMUX_MUX_CURRENT:-current}" \
    TMUX_MUX_SESSIONS="${TMUX_MUX_SESSIONS:-current normal-one _internal normal-two}" \
    bash "$mux_bin" "$@"
}

# cycle next/previous: name order, skip _, wrap
: >"$cmd_log"
TMUX_MUX_CURRENT=normal-one run_mux cycle next
grep -Fx 'tmux switch-client -t =normal-two' "$cmd_log" >/dev/null
: >"$cmd_log"
TMUX_MUX_CURRENT=normal-two run_mux cycle next
grep -Fx 'tmux switch-client -t =current' "$cmd_log" >/dev/null
: >"$cmd_log"
TMUX_MUX_CURRENT=current run_mux cycle previous
grep -Fx 'tmux switch-client -t =normal-two' "$cmd_log" >/dev/null
: >"$cmd_log"
TMUX_MUX_CURRENT=only TMUX_MUX_SESSIONS='only _hidden' \
  run_mux cycle next
test ! -s "$cmd_log"

# picker: ● live ∪ ○ saved, skip _, include current, no ANSI
printf '%s\n' 'name = "parked"' >"$mux_dir/parked.toml"
: >"$cmd_log"
rm -f "$fzf_input"
TMUX_MUX_FZF_OUT=$'\n● normal-one' run_mux picker
cat >"$test_root/expected-picker" <<'EXPECTED'
● current
● normal-one
● normal-two
○ parked
EXPECTED
cmp "$test_root/expected-picker" "$fzf_input"
if grep -q $'\033\[' "$fzf_input"; then
  echo 'picker must not colour sessions' >&2
  exit 1
fi
grep -Fx 'tmux switch-client -t =normal-one' "$cmd_log" >/dev/null

# saved が空でも live だけ出せる (pipefail で brace が落ちないこと)
empty_mux="$test_root/empty-mux"
mkdir -p "$empty_mux"
: >"$cmd_log"
rm -f "$fzf_input"
MUX_CONFIG="$empty_mux" TMUX_MUX_FZF_OUT=$'\n● current' run_mux picker
cat >"$test_root/expected-live-only" <<'EXPECTED'
● current
● normal-one
● normal-two
EXPECTED
cmp "$test_root/expected-live-only" "$fzf_input"

# Enter on saved-only restores via mux (fzf shim)
: >"$cmd_log"
TMUX_MUX_FZF_OUT=$'\n○ parked' run_mux picker
grep -Fx 'mux-open parked' "$cmd_log" >/dev/null

# save: snapshot piped to mux save --force <name>
cat >"$test_root/snap.toml" <<'SNAP'
name = "current"
root = "/tmp"
[[windows]]
name = "one"
panes = [""]
SNAP
: >"$cmd_log"
TMUX_MUX_SNAPSHOT="$test_root/snap.toml" run_mux save
test -f "$mux_dir/current.toml"
cmp "$test_root/snap.toml" "$mux_dir/current.toml"
grep -Fx 'mux snapshot' "$cmd_log" >/dev/null
grep -Fx 'mux save --force current' "$cmd_log" >/dev/null
grep -Fx 'tmux display-message saved current' "$cmd_log" >/dev/null

assert_switch_before_kill() {
  local target="$1"
  local neighbor="$2"
  awk -v target="$target" -v neighbor="$neighbor" '
    $0 == "tmux switch-client -t =" neighbor { s = NR }
    $0 == "tmux kill-session -t =" target { k = NR }
    END { exit !(s && k && s < k) }
  ' "$cmd_log" || {
    echo "expected switch to ${neighbor} before kill ${target}" >&2
    cat "$cmd_log" >&2
    exit 1
  }
}

# close: matching snapshot → switch to next visible, then kill
: >"$cmd_log"
printf 's' | TMUX_MUX_SNAPSHOT="$test_root/snap.toml" run_mux close >"$test_root/close.out"
assert_switch_before_kill current normal-one
grep -Fx 'closed current' "$test_root/close.out" >/dev/null
# matching path must not have consumed the unused 's' as a save
test "$(cat "$mux_dir/current.toml")" = "$(cat "$test_root/snap.toml")"

# last visible session: kill without switch (server may end)
: >"$cmd_log"
TMUX_MUX_CURRENT=only TMUX_MUX_SESSIONS='only _hidden' \
  TMUX_MUX_SNAPSHOT="$test_root/snap.toml" run_mux close
grep -Fx 'tmux kill-session -t =only' "$cmd_log" >/dev/null
if grep -q switch-client "$cmd_log"; then
  echo 'last session must not switch-client' >&2
  exit 1
fi

# close unsaved: s saves then kills
rm -f "$mux_dir/fresh.toml"
cat >"$test_root/fresh.toml" <<'SNAP'
name = "fresh"
root = "/tmp"
[[windows]]
name = "one"
panes = [""]
SNAP
: >"$cmd_log"
printf 's' | TMUX_MUX_CURRENT=fresh TMUX_MUX_SNAPSHOT="$test_root/fresh.toml" \
  run_mux close >"$test_root/close-unsaved.out"
test -f "$mux_dir/fresh.toml"
grep -Fx 'mux save --force fresh' "$cmd_log" >/dev/null
# fresh is not in the live list, so neighbor of "fresh" is the first visible
assert_switch_before_kill fresh current

# close dirty: d discards then kills
printf '%s\n' 'name = "stale"' >"$mux_dir/current.toml"
: >"$cmd_log"
printf 'd' | TMUX_MUX_SNAPSHOT="$test_root/snap.toml" run_mux close
assert_switch_before_kill current normal-one
test "$(cat "$mux_dir/current.toml")" = 'name = "stale"'

# close cancel
: >"$cmd_log"
if printf 'C' | TMUX_MUX_SNAPSHOT="$test_root/snap.toml" run_mux close; then
  echo 'cancel must fail the close' >&2
  exit 1
fi
if grep -q kill-session "$cmd_log"; then
  echo 'cancel must not kill-session' >&2
  exit 1
fi
if grep -q switch-client "$cmd_log"; then
  echo 'cancel must not switch-client' >&2
  exit 1
fi

# picker Space: cancel close, stay in list, then Enter moves
round="$test_root/fzf-round"
: >"$cmd_log"
rm -f "$fzf_input" "$round"
printf 'C' | TMUX_MUX_FZF_ROUND="$round" \
  TMUX_MUX_FZF_OUT_1=$'space\n● current' \
  TMUX_MUX_FZF_OUT_2=$'\n● normal-one' \
  TMUX_MUX_SNAPSHOT="$test_root/snap.toml" \
  run_mux picker
test "$(cat "$round")" = 2
if grep -q kill-session "$cmd_log"; then
  echo 'Space cancel must keep the session' >&2
  exit 1
fi
grep -Fx 'tmux switch-client -t =normal-one' "$cmd_log" >/dev/null

# picker Space: successful close of current, then list again / Enter
cp "$test_root/snap.toml" "$mux_dir/current.toml"
: >"$cmd_log"
rm -f "$fzf_input" "$round"
TMUX_MUX_FZF_ROUND="$round" \
  TMUX_MUX_FZF_OUT_1=$'space\n● current' \
  TMUX_MUX_FZF_OUT_2=$'\n● normal-two' \
  TMUX_MUX_SNAPSHOT="$test_root/snap.toml" \
  run_mux picker
test "$(cat "$round")" = 2
assert_switch_before_kill current normal-one
grep -Fx 'tmux switch-client -t =normal-two' "$cmd_log" >/dev/null

# tmux.conf bind contract (source text)
grep -Eq '^bind -n M-h previous-window$' "$conf"
grep -Eq '^bind -n M-l next-window$' "$conf"
grep -Fq "bind -n M-j run-shell 'bash ~/.local/bin/tmux-mux cycle next'" "$conf"
grep -Fq "bind -n M-k run-shell 'bash ~/.local/bin/tmux-mux cycle previous'" "$conf"
grep -Fq "bind Space display-popup -E -w 90% -h 80% 'TMUX_PANE=#{pane_id} bash ~/.local/bin/tmux-mux picker'" "$conf"
grep -Fq "bind C-b display-popup -E -w 90% -h 80% 'TMUX_PANE=#{pane_id} bash ~/.local/bin/tmux-mux picker'" "$conf"
grep -Fq "bind -n M-s run-shell 'TMUX_PANE=#{pane_id} bash ~/.local/bin/tmux-mux save'" "$conf"
grep -Fq "bind -n M-x display-popup -E -w 50% -h 40% 'TMUX_PANE=#{pane_id} bash ~/.local/bin/tmux-mux close'" "$conf"
if grep -Eq '^bind( -n)? b ' "$conf"; then
  echo 'prefix+b sidebar must not be added' >&2
  exit 1
fi

# isolated tmux server: list-keys sees the new binds (no tpm)
if command -v tmux >/dev/null 2>&1; then
  stripped="$test_root/tmux.conf"
  sed '/^# List of plugins/,$d' "$conf" >"$stripped"
  socket="tmux-mux-$$"
  tmux -L "$socket" -f "$stripped" new-session -d -s _probe
  keys="$test_root/list-keys"
  {
    tmux -L "$socket" list-keys -T root
    tmux -L "$socket" list-keys -T prefix
  } >"$keys"
  tmux -L "$socket" kill-server
  grep -E '[[:space:]]M-h[[:space:]]+previous-window' "$keys" >/dev/null
  grep -E '[[:space:]]M-l[[:space:]]+next-window' "$keys" >/dev/null
  grep -E '[[:space:]]M-j[[:space:]].*tmux-mux cycle next' "$keys" >/dev/null
  grep -E '[[:space:]]M-k[[:space:]].*tmux-mux cycle previous' "$keys" >/dev/null
  grep -E '[[:space:]]Space[[:space:]].*tmux-mux picker' "$keys" >/dev/null
  grep -E '[[:space:]]C-b[[:space:]].*tmux-mux picker' "$keys" >/dev/null
  grep -E '[[:space:]]M-s[[:space:]].*tmux-mux save' "$keys" >/dev/null
  grep -E '[[:space:]]M-x[[:space:]].*tmux-mux close' "$keys" >/dev/null
fi

echo 'tmux-mux test: pass'
