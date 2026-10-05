#!/bin/sh
# config/sync-checkouts/sync-checkouts の回帰テスト。一時 directory に bare origin と常設 checkout を
# 作り、副作用 (fetch / ff / 有効化) を隔離して観測する。
set -eu

cd "$(dirname "$0")/.."
sync="$PWD/config/sync-checkouts/sync-checkouts"

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

command -v git >/dev/null 2>&1 || fail "git が見つからない"
[ -x "$sync" ] || fail "sync-checkouts が無い"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM
export HOME="$tmp/home"
mkdir -p "$HOME"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

# origin と、それを進めるための作業 clone
git init -q --bare "$tmp/origin.git"
git clone -q "$tmp/origin.git" "$tmp/author" 2>/dev/null
( cd "$tmp/author" && echo 1 > f && git add f && git commit -q -m one && git push -q origin HEAD:main )

# 常設 checkout (旧 HEAD): 追従する / dirty / detached / upstream 無し / 分岐 /
# 未追跡 file だけ / 取り込む file と同名の未追跡 file
for name in follow dirty detached noupstream diverged untracked collide; do
	git clone -q -b main "$tmp/origin.git" "$tmp/$name" 2>/dev/null
done
( cd "$tmp/dirty" && echo x > f )
( cd "$tmp/detached" && git checkout -q --detach )
( cd "$tmp/noupstream" && git branch -q --unset-upstream )
( cd "$tmp/diverged" && echo local > g && git add g && git commit -q -m local )
diverged_head=$(git -C "$tmp/diverged" rev-parse HEAD)
( cd "$tmp/untracked" && echo stray > stray )
( cd "$tmp/collide" && echo mine > incoming )

# origin を進めてから、既に最新の checkout を 1 つ作る
( cd "$tmp/author" && echo 2 > f && echo theirs > incoming && git add f incoming && git commit -q -m two && git push -q origin HEAD:main )
git clone -q -b main "$tmp/origin.git" "$tmp/current" 2>/dev/null
new=$(git -C "$tmp/author" rev-parse HEAD)
old=$(git -C "$tmp/follow" rev-parse HEAD)
[ "$new" != "$old" ] || fail "test setup: origin が進んでいない"

# 有効化 stub: 呼ばれた回数と cwd を記録する ($PWD は生成先の script で展開させる)
act="$tmp/act"
# shellcheck disable=SC2016
printf '#!/bin/sh\necho "$PWD" >> "%s/act.log"\n' "$tmp" > "$act"
chmod +x "$act"

# list: 先頭は存在しない path (他を止めないことを見る)。~ 展開も 1 件混ぜる
# (literal の ~ を list に書くのが仕様なので、ここでは展開させない)
mkdir -p "$HOME/projects"
ln -s "$tmp/current" "$HOME/projects/current"
# shellcheck disable=SC2088
printf '%s\t%s\n' \
	"$tmp/missing" "$act" \
	"$tmp/follow" "$act" \
	"~/projects/current" "$act" \
	"$tmp/dirty" "$act" \
	"$tmp/detached" "-" \
	"$tmp/noupstream" "$act" \
	"$tmp/diverged" "$act" \
	"$tmp/untracked" "-" \
	"$tmp/collide" "-" \
	> "$tmp/list"

out=$("$sync" "$tmp/list" 2>&1) || fail "sync-checkouts が非 0 で終わった: $out"

# 1. origin が進んだ checkout だけが ff で追従する
[ "$(git -C "$tmp/follow" rev-parse HEAD)" = "$new" ] || fail "follow が追従していない"
[ "$(git -C "$tmp/dirty" rev-parse HEAD)" = "$old" ] || fail "dirty が動いてしまった"
[ "$(git -C "$tmp/detached" rev-parse HEAD)" = "$old" ] || fail "detached が動いてしまった"
[ "$(git -C "$tmp/noupstream" rev-parse HEAD)" = "$old" ] || fail "upstream 無しが動いてしまった"
[ "$(git -C "$tmp/diverged" rev-parse HEAD)" = "$diverged_head" ] || fail "非 ff の checkout が動いてしまった"
[ "$(cat "$tmp/dirty/f")" = "x" ] || fail "dirty の作業内容が失われた"
[ -f "$tmp/diverged/g" ] || fail "分岐側の local commit の内容が失われた"
[ "$(git -C "$tmp/untracked" rev-parse HEAD)" = "$new" ] || fail "未追跡 file だけの checkout が追従していない"
[ "$(cat "$tmp/untracked/stray")" = "stray" ] || fail "未追跡 file が失われた"
[ "$(git -C "$tmp/collide" rev-parse HEAD)" = "$old" ] || fail "未追跡 file を上書きする ff が進んだ"
[ "$(cat "$tmp/collide/incoming")" = "mine" ] || fail "同名の未追跡 file が上書きされた"

# 2. 有効化は未適用の SHA ごとに、その directory で 1 回 (follow と、stamp の無い current)
[ -f "$tmp/act.log" ] || fail "有効化が呼ばれていない"
[ "$(wc -l < "$tmp/act.log")" -eq 2 ] || fail "有効化の回数が 2 ではない: $(cat "$tmp/act.log")"
grep -qx "$tmp/follow" "$tmp/act.log" || fail "有効化が follow 以外で呼ばれた: $(cat "$tmp/act.log")"

# 3. 既に最新 (~ 展開経由) の checkout は HEAD が動かない
[ "$(git -C "$tmp/current" rev-parse HEAD)" = "$new" ] || fail "current が最新になっていない"

# 4. 2 回目は何も変わらず、有効化も増えない
out=$("$sync" "$tmp/list" 2>&1) || fail "2 回目が非 0: $out"
[ "$(wc -l < "$tmp/act.log")" -eq 2 ] || fail "2 回目で有効化が再実行された"

# 5. 各 entry の結果が 1 行ずつ log に出る (missing / skip も黙らない)
for key in missing follow current dirty detached noupstream diverged untracked collide; do
	printf '%s\n' "$out" | grep -q "$key" || fail "log に $key の行が無い: $out"
done
printf '%s\n' "$out" | grep -q "noupstream skip no-upstream" || fail "upstream 無しの理由が log に無い: $out"
printf '%s\n' "$out" | grep -q "diverged skip not-ff" || fail "非 ff の理由が log に無い: $out"
printf '%s\n' "$out" | grep -q "collide skip not-ff" || fail "未追跡 file 衝突の理由が log に無い: $out"

echo "PASS: sync-checkouts contract"

# A failed activation is retried even when HEAD no longer changes.
printf '%s\t%s\n' "$tmp/current" "test -f '$tmp/ready' && '$act'" > "$tmp/retry-list"
"$sync" "$tmp/retry-list" > /dev/null
before_count=$(wc -l < "$tmp/act.log")
touch "$tmp/ready"
"$sync" "$tmp/retry-list" > /dev/null
[ "$(wc -l < "$tmp/act.log")" -eq "$((before_count + 1))" ] || fail 'activation was not retried'
"$sync" "$tmp/retry-list" > /dev/null
[ "$(wc -l < "$tmp/act.log")" -eq "$((before_count + 1))" ] || fail 'successful activation repeated'
echo 'PASS: already merged HEAD and failed activation converge once'

# A manual second invocation cannot race the timer's fetch/activation.
exec 8> "$HOME/.local/state/sync-checkouts/lock"
flock 8
if "$sync" "$tmp/list" > /dev/null 2>&1; then fail 'parallel sync accepted'; fi
flock -u 8
echo 'PASS: parallel sync excluded'
