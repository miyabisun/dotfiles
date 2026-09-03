#!/usr/bin/env bash
# Contract: dotfiles の主 checkout で commit / merge すると bin/install が
# 自動で走る (sandbox の sync-checkouts に当たる母艦側の追従)。
#
#   - hooks/run-install は post-commit と post-merge から呼ばれ、主 checkout
#     (linked worktree ではない) のときだけ、その checkout の bin/install を
#     1 回走らせる
#   - bin/install が失敗しても git 操作は失敗させない (exit 0、stderr に 1 行)
#   - bin/install は git checkout の内側で走ったときだけ、repo-local の
#     core.hooksPath を hooks へ向ける (.git の無い配置では何もしない)
#
# 本物の HOME・PATH・~/.gitconfig には触らない。installer は記録するだけの
# stub に差し替えて呼び出し回数を数える。
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

export HOME="$test_root/home"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid
export GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid
mkdir -p "$HOME"

fail() { echo "$*" >&2; exit 1; }

# --- hook 本体: stub installer を持つ偽 repo で呼び出し回数を数える ---------
repo="$test_root/repo"
mkdir -p "$repo/bin" "$repo/hooks"
git -C "$repo" init -q -b master
export INSTALL_CALLS="$test_root/calls"
: >"$INSTALL_CALLS"
cat >"$repo/bin/install" <<'STUB'
#!/bin/sh
echo "$PWD" >>"$INSTALL_CALLS"
echo "stub installer stdout"
echo "stub installer stderr" >&2
exit "${INSTALL_RC:-0}"
STUB
chmod +x "$repo/bin/install"
cp "$repo_root/hooks/run-install" "$repo/hooks/run-install"
chmod +x "$repo/hooks/run-install"
ln -s run-install "$repo/hooks/post-commit"
ln -s run-install "$repo/hooks/post-merge"
git -C "$repo" config core.hooksPath hooks

calls() { wc -l <"$INSTALL_CALLS" | tr -d ' '; }

git -C "$repo" add -A
git -C "$repo" commit -q -m init >"$test_root/out" 2>"$test_root/err"
[[ "$(calls)" == 1 ]] || fail "post-commit in main checkout: expected 1 call, got $(calls)"
[[ "$(tail -n1 "$INSTALL_CALLS")" == "$repo" ]] || fail "installer must run with cwd = checkout root"
[[ ! -s "$test_root/out" && ! -s "$test_root/err" ]] \
  || fail "successful installer must be silent, got: $(cat "$test_root/out" "$test_root/err")"

wt="$test_root/wt"
git -C "$repo" worktree add -q "$wt" -b feature
echo x >"$wt/f"
git -C "$wt" add -A
git -C "$wt" commit -q -m feature
[[ "$(calls)" == 1 ]] || fail "post-commit in linked worktree must not run installer, got $(calls)"

git -C "$repo" merge -q --ff-only feature
[[ "$(calls)" == 2 ]] || fail "post-merge (ff) in main checkout: expected 2 calls, got $(calls)"

echo y >"$repo/g"
git -C "$repo" add -A
INSTALL_RC=1 git -C "$repo" commit -q -m broken >"$test_root/out" 2>"$test_root/err" \
  || fail "installer failure must not fail the commit"
[[ "$(calls)" == 3 ]] || fail "failing installer must still have been invoked once, got $(calls)"
[[ ! -s "$test_root/out" ]] || fail "failing installer must not leak stdout: $(cat "$test_root/out")"
printf '%s\n' "dotfiles: bin/install failed (run it by hand to see why)" >"$test_root/err.expected"
cmp -s "$test_root/err" "$test_root/err.expected" \
  || fail "stderr must be exactly the one-line diagnostic, got: $(od -c "$test_root/err")"
[[ "$(git -C "$repo" log --oneline | wc -l | tr -d ' ')" == 3 ]] || fail "commit 'broken' must exist"

# --- bin/install が hooksPath を配線する ---------------------------------------
copy="$test_root/copy"
mkdir -p "$copy"
(cd "$repo_root" && tar -cf - --exclude=.git .) | (cd "$copy" && tar -xf -)
fake_bin="$test_root/bin"
mkdir -p "$fake_bin"
printf '#!/usr/bin/env bash\nexit 0\n' >"$fake_bin/sheldon"
chmod +x "$fake_bin/sheldon"
run_path="$fake_bin:/usr/bin:/bin"

# .git が無い配置: hooksPath には触れず、install 自体は成功する
PATH="$run_path" bash "$copy/bin/install" >/dev/null || fail "install without .git must succeed"

# git checkout の内側: repo-local の core.hooksPath が hooks になる (2 回目も同じ)
git -C "$copy" init -q -b master
for i in 1 2; do
  PATH="$run_path" bash "$copy/bin/install" >/dev/null || fail "install in checkout must succeed (run $i)"
  [[ "$(git -C "$copy" config --local --get core.hooksPath)" == hooks ]] \
    || fail "install must set core.hooksPath=hooks (run $i)"
done

echo "install-hooks: ok"
