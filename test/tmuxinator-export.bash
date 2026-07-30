#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skill="$repo_root/agent/common/skills/tmuxinator-export"
script="$skill/scripts/inspect-session.sh"
writer="$skill/scripts/write-project.py"
validator="$skill/scripts/validate-metadata.py"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fake_bin="$test_root/bin"
tmux_log="$test_root/tmux.log"
mkdir -p "$fake_bin"

cat >"$fake_bin/tmux" <<'TMUX'
#!/usr/bin/env python3
import os
import sys

args = sys.argv[1:]
scenario = os.environ.get("TMUX_FAKE_SCENARIO", "normal")
log = os.environ.get("TMUXINATOR_EXPORT_TMUX_LOG")
if log:
    with open(log, "a", encoding="utf-8") as output:
        output.write(" ".join(args) + "\n")

normal = {
    "%10": ["2", "logs", "abcd,100x30,0,0{50x30,0,0,9,49x30,51,0,10}", "0", "2", "%10", "0", "/tmp/project", "tail"],
    "%9": ["2", "logs", "abcd,100x30,0,0{50x30,0,0,9,49x30,51,0,10}", "0", "1", "%9", "1", "/tmp/project", "zsh"],
    "%8": ["1", "agents", "ef0a,100x30,0,0{50x30,0,0,7,49x30,51,0,8}", "1", "2", "%8", "0", "/tmp/project", "codex"],
    "%7": ["1", "agents", "ef0a,100x30,0,0{50x30,0,0,7,49x30,51,0,8}", "1", "1", "%7", "1", "/tmp/project", "claude"],
}
single = ["1", "agent", "ef0a,80x24,0,0,1", "1", "0", "%1", "1", "/tmp/project", "codex"]
session = "settings"
rows = normal
if scenario != "normal":
    rows = {"%1": single.copy()}
if scenario == "internal_session":
    session = "_agent_talkd"
elif scenario == "url":
    rows["%1"][7] = "/tmp/https://private.example"
elif scenario == "credential_assignment":
    rows["%1"][7] = "/tmp/token=example-value"
elif scenario == "compound_credential":
    rows["%1"][7] = "/tmp/AWS_SECRET_ACCESS_KEY=example-value"
elif scenario == "common_path":
    session = "sis-server"
    rows["%1"][1] = "api.server"
    rows["%1"][7] = "/home/user/node_modules/next.js"
elif scenario == "control":
    rows["%1"][1] = "bad\x1bname"
elif scenario == "del_control":
    rows["%1"][7] = "/tmp/bad\x7fpath"
elif scenario == "trailing_tab":
    rows["%1"][8] = "codex\t"
elif scenario == "continuous_tabs":
    rows["%1"][1] = "agent\t\tname"
elif scenario == "layout":
    rows["%1"][2] = "abcd,{"
elif scenario == "newline_forge":
    rows["%1"][1] = "agent\n1\tfake\tef0a,80x24,0,0,1\t1\t0\t%1\t1\t/tmp/project\tcodex"
elif scenario == "pane_mismatch":
    rows["%1"][5] = "%2"

if args[0] == "list-panes":
    print("\n".join(rows))
elif args[0] == "display-message" and args[-1] == "#{session_name}":
    print(session)
elif args[0] == "display-message":
    pane = args[args.index("-t") + 1]
    field = args[-1][2:-1]
    fields = (
        "window_index", "window_name", "window_layout", "window_active",
        "pane_index", "pane_id", "pane_active", "pane_current_path",
        "pane_current_command",
    )
    sys.stdout.write(rows[pane][fields.index(field)] + "\n")
else:
    raise SystemExit(90)
TMUX
chmod +x "$fake_bin/tmux"
test -x "$script"
test -x "$writer"
test -x "$validator"

PATH="$fake_bin:/usr/bin:/bin" TMUX_PANE=%7 \
  TMUXINATOR_EXPORT_TMUX_LOG="$tmux_log" \
  bash "$script" >"$test_root/actual"

cat >"$test_root/expected" <<'EXPECTED'
session	settings
window_index	window_name	window_layout	window_active	pane_index	pane_id	pane_active	pane_current_path	pane_current_command
1	agents	ef0a,100x30,0,0{50x30,0,0,7,49x30,51,0,8}	1	1	%7	1	/tmp/project	claude
1	agents	ef0a,100x30,0,0{50x30,0,0,7,49x30,51,0,8}	1	2	%8	0	/tmp/project	codex
2	logs	abcd,100x30,0,0{50x30,0,0,9,49x30,51,0,10}	0	1	%9	1	/tmp/project	zsh
2	logs	abcd,100x30,0,0{50x30,0,0,9,49x30,51,0,10}	0	2	%10	0	/tmp/project	tail
EXPECTED
cmp "$test_root/expected" "$test_root/actual"
grep -Fx 'display-message -p -t %7 #{session_name}' "$tmux_log" >/dev/null
grep -Fx 'list-panes -s -t =settings -F #{pane_id}' "$tmux_log" >/dev/null
grep -Fx 'display-message -p -t %7 #{pane_current_path}' "$tmux_log" >/dev/null

if env -u TMUX_PANE PATH="$fake_bin:/usr/bin:/bin" \
  bash "$script" >"$test_root/outside.out" 2>&1; then
  echo "inspect-session should fail outside tmux" >&2
  exit 1
fi
grep -F 'run this skill from inside the tmux session' "$test_root/outside.out" >/dev/null

if PATH="$fake_bin:/usr/bin:/bin" TMUX_PANE=%7 TMUX_FAKE_SCENARIO=internal_session \
  bash "$script" >"$test_root/internal.out" 2>&1; then
  echo "inspect-session should reject internal sessions" >&2
  exit 1
fi
grep -Fx 'tmuxinator-export: unsafe or malformed tmux metadata' "$test_root/internal.out" >/dev/null

grep -F 'Stop if it already exists' "$skill/SKILL.md" >/dev/null
grep -F 'Never overwrite or invent a force option' "$skill/SKILL.md" >/dev/null
grep -F 'Do not inspect scrollback, process arguments' "$skill/SKILL.md" >/dev/null
grep -F 'network endpoints, or unclear arguments' "$skill/SKILL.md" >/dev/null
grep -F 'Require `tmux` and `$TMUX_PANE`' "$skill/SKILL.md" >/dev/null
grep -F 'Treat tmuxinator as optional' "$skill/SKILL.md" >/dev/null
grep -F 'continue through inspection and YAML creation' "$skill/SKILL.md" >/dev/null
grep -F 'When tmuxinator is available, run `tmuxinator debug <project>`' \
  "$skill/SKILL.md" >/dev/null
grep -F 'When tmuxinator is unavailable, mark validation as skipped' \
  "$skill/SKILL.md" >/dev/null
grep -F '`mux` launch requires a compatible runtime' "$skill/SKILL.md" >/dev/null
grep -F 'skipped (tmuxinator not available)' "$skill/SKILL.md" >/dev/null
grep -F 'existing `mux` zsh command can select it' "$skill/SKILL.md" >/dev/null
grep -F 'mkdir -p "$HOME/.config/tmuxinator"' "$repo_root/bin/install" >/dev/null

for scenario in url credential_assignment compound_credential control del_control trailing_tab continuous_tabs layout \
  newline_forge pane_mismatch; do
  if PATH="$fake_bin:/usr/bin:/bin" TMUX_PANE=%1 TMUX_FAKE_SCENARIO="$scenario" \
    bash "$script" >"$test_root/$scenario.out" 2>"$test_root/$scenario.err"; then
    echo "inspect-session should reject $scenario metadata" >&2
    exit 1
  fi
  test ! -s "$test_root/$scenario.out"
  grep -Fx 'tmuxinator-export: unsafe or malformed tmux metadata' \
    "$test_root/$scenario.err" >/dev/null
done
if ! PATH="$fake_bin:/usr/bin:/bin" TMUX_PANE=%1 TMUX_FAKE_SCENARIO=common_path \
  bash "$script" >"$test_root/common-path.out" 2>"$test_root/common-path.err"; then
  echo "inspect-session should accept ordinary host-like local path segments" >&2
  exit 1
fi
grep -F $'session\tsis-server' "$test_root/common-path.out" >/dev/null
grep -F $'api.server\tef0a,80x24,0,0,1' "$test_root/common-path.out" >/dev/null
grep -F $'/home/user/node_modules/next.js\tcodex' "$test_root/common-path.out" >/dev/null

project_dir="$test_root/projects"
project="$project_dir/settings.yml"
printf '%s\n' 'name: settings' | "$writer" "$project"
test "$(python3 -c 'import os, sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777)[2:])' "$project")" = 600
grep -Fx 'name: settings' "$project" >/dev/null
if printf '%s\n' 'name: replaced' | "$writer" "$project" \
  >"$test_root/overwrite.out" 2>"$test_root/overwrite.err"; then
  echo "write-project should refuse overwrite" >&2
  exit 1
fi
grep -Fx 'name: settings' "$project" >/dev/null
grep -F 'destination already exists' "$test_root/overwrite.err" >/dev/null

symlink_target="$test_root/symlink-target.yml"
symlink_destination="$project_dir/linked-file.yml"
printf '%s\n' 'name: target' >"$symlink_target"
ln -s "$symlink_target" "$symlink_destination"
if printf '%s\n' 'name: linked' | "$writer" "$symlink_destination" \
  >"$test_root/file-symlink.out" 2>"$test_root/file-symlink.err"; then
  echo "write-project should reject a symlink destination" >&2
  exit 1
fi
grep -Fx 'name: target' "$symlink_target" >/dev/null
grep -F 'destination already exists' "$test_root/file-symlink.err" >/dev/null

symlink_parent="$test_root/symlink-projects"
ln -s "$project_dir" "$symlink_parent"
if printf '%s\n' 'name: linked' | "$writer" "$symlink_parent/linked.yml" \
  >"$test_root/symlink.out" 2>"$test_root/symlink.err"; then
  echo "write-project should reject a symlink config directory" >&2
  exit 1
fi
test ! -e "$project_dir/linked.yml"
grep -F 'config directory must be a real directory' "$test_root/symlink.err" >/dev/null

real_ancestor="$test_root/real-ancestor"
linked_ancestor="$test_root/linked-ancestor"
mkdir -p "$real_ancestor"
ln -s "$real_ancestor" "$linked_ancestor"
if printf '%s\n' 'name: linked' | "$writer" "$linked_ancestor/projects/ancestor.yml" \
  >"$test_root/ancestor.out" 2>"$test_root/ancestor.err"; then
  echo "write-project should reject a symlink ancestor" >&2
  exit 1
fi
test ! -e "$real_ancestor/projects/ancestor.yml"
grep -F 'config directory must be a real directory' "$test_root/ancestor.err" >/dev/null

config_home="$test_root/config"
mkdir -p "$config_home/tmuxinator"
touch "$config_home/tmuxinator/settings.yml"
cat >"$fake_bin/fzf" <<'FZF'
#!/usr/bin/env bash
sed -n '1p'
FZF
cat >"$fake_bin/tmuxinator" <<'TMUXINATOR'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$TMUXINATOR_EXPORT_START_LOG"
TMUXINATOR
chmod +x "$fake_bin/fzf" "$fake_bin/tmuxinator"
PATH="$fake_bin:/usr/bin:/bin" HOME="$test_root/home" \
  XDG_CONFIG_HOME="$config_home" \
  TMUXINATOR_EXPORT_START_LOG="$test_root/start.log" \
  zsh -f -c 'source "$1"; mux' zsh "$repo_root/config/zsh/functions.zsh"
grep -Fx 'start settings' "$test_root/start.log" >/dev/null

override_dir="$test_root/override-projects"
mkdir -p "$override_dir"
touch "$override_dir/portable.yaml"
PATH="$fake_bin:/usr/bin:/bin" HOME="$test_root/home" \
  TMUXINATOR_CONFIG="$override_dir" \
  TMUXINATOR_EXPORT_START_LOG="$test_root/override-start.log" \
  zsh -f -c 'source "$1"; mux' zsh "$repo_root/config/zsh/functions.zsh"
grep -Fx 'start portable' "$test_root/override-start.log" >/dev/null

echo "tmuxinator export test: pass"
