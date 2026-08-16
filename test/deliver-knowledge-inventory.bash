#!/usr/bin/env bash
# knowledge-inventory role が repo に持つものを測る:
#   1. role の frontmatter 構造 (name/description/model pin と、余計な key の不在)
#   2. Codex adapter/config の配線と、その TOML が実際に parse できること
#   3. role 本文に埋め込まれた sensitive_pattern / host_pattern を sed で抜き出し、
#      実際に rg へ通して credential/host を fail-closed に捕まえること、および
#      ふつうの語 (keyword, secretary 等) を誤検知しないこと
# coreutils / ripgrep 自体の挙動を確かめ直す assert は持たない
# (依存の受け入れテストは測る意味が無い — GLOBAL.md「テスト」)。
# assert する文字列は対象ファイルの literal なので、$ や ` を展開させない
# shellcheck disable=SC2016,SC2088
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

role="$repo_root/agent/common/agents/knowledge-inventory.md"
adapter="$repo_root/agent/codex/agents/knowledge-inventory.toml"
config="$repo_root/agent/codex/config.toml"

assert_contains() {
  local file="$1"
  local text="$2"
  grep -Fq -- "$text" "$file" || {
    printf 'missing contract in %s: %s\n' "$file" "$text" >&2
    return 1
  }
}

# role 本文 (provenance・送信作法・停止条項の不在・投入形) を literal で固定して
# いた assert 群は削除した。markdown の字面 grep は「文字列が在る」しか証明せず、
# 規則の遵守を測らない (GLOBAL.md「テスト」)。role に埋め込まれた走査 pattern は
# 下で実際に rg へ通して測る
test -f "$role"

# TMPDIR を変えても mktemp /tmp/... が /tmp 配下に出ることの確認は削除した。
# repo のコードを何も通さず coreutils の仕様を測り直すだけ (GLOBAL.md「テスト」)

# role配布: common role + Codex adapter/config。installはdirectory symlinkなので変更不要
test -f "$adapter"
assert_contains "$adapter" 'name = "knowledge-inventory"'
assert_contains "$adapter" '~/.agents/agents/knowledge-inventory.md'
assert_contains "$config" '[agents.knowledge_inventory]'
assert_contains "$config" 'config_file = "agents/knowledge-inventory.toml"'

python3 - "$adapter" "$config" <<'PY'
import sys
import tomllib

for path in sys.argv[1:]:
    with open(path, "rb") as handle:
        tomllib.load(handle)
PY

# roleに埋め込まれた実patternが代表的なbypassをfail-closedにする
sensitive_pattern="$(sed -n "s/^   sensitive_pattern='\(.*\)'$/\1/p" "$role")"
host_pattern="$(sed -n "s/^   host_pattern='\(.*\)'$/\1/p" "$role")"
test -n "$sensitive_pattern"
test -n "$host_pattern"

probe_root="$(mktemp -d)"
trap 'rm -rf "$probe_root"' EXIT
assert_blocked() {
  local value="$1"
  printf '%s\n' "$value" >"$probe_root/candidate"
  if ! rg -q -i --pcre2 "$sensitive_pattern" "$probe_root/candidate" \
      && ! rg -q -i --pcre2 "$host_pattern" "$probe_root/candidate"; then
    printf 'unsafe knowledge candidate bypassed both scans: %s\n' "$2" >&2
    return 1
  fi
}

openai_probe="sk-proj-$(printf 'a%.0s' {1..24})"
slack_probe="xoxb-$(printf 'b%.0s' {1..24})"
aws_session_probe="ASIA$(printf 'C%.0s' {1..16})"
stripe_probe="sk_live_$(printf 'd%.0s' {1..24})"
google_probe="AIza$(printf 'e%.0s' {1..35})"
assert_blocked "$openai_probe" "provider token"
assert_blocked "$slack_probe" "Slack token"
assert_blocked "$aws_session_probe" "AWS session key"
assert_blocked 'aws_secret_access_key = placeholder-value' "credential assignment"
assert_blocked 'apiKey = placeholder-value' "camelCase API key"
assert_blocked 'accessToken = placeholder-value' "camelCase access token"
assert_blocked 'authToken = placeholder-value' "camelCase auth token"
assert_blocked 'clientSecret = placeholder-value' "camelCase client secret"
assert_blocked 'secretKey = placeholder-value' "camelCase secret key"
assert_blocked 'dbPassword = placeholder-value' "camelCase database password"
assert_blocked 'sessionToken = placeholder-value' "camelCase session token"
assert_blocked 'idToken = placeholder-value' "camelCase identity token"
assert_blocked 'consumerSecret = placeholder-value' "camelCase consumer secret"
assert_blocked 'webhookSecret = placeholder-value' "camelCase webhook secret"
assert_blocked 'signingKey = placeholder-value' "camelCase signing key"
assert_blocked 'encryptionKey = placeholder-value' "camelCase encryption key"
assert_blocked "$stripe_probe" "Stripe token"
assert_blocked "$google_probe" "Google API key"
assert_blocked 'https://demo:placeholder@example.com/path' "URL userinfo"
assert_blocked '10.23.45.67' "bare private IPv4"
assert_blocked 'fd12::1' "bare private IPv6"
assert_blocked 'host: database01' "single-label host field"
assert_blocked 'node1.corp' "private suffix host"
assert_blocked 'prod-db.example.com' "bare FQDN"

for safe_label in keyword tokenizer monkey hotkey secretary; do
  printf '%s: documented term\n' "$safe_label" >"$probe_root/candidate"
  if rg -q -i --pcre2 "$sensitive_pattern" "$probe_root/candidate"; then
    printf 'ordinary label must not be treated as a credential: %s\n' "$safe_label" >&2
    exit 1
  fi
done

printf '%s\n' 'token=placeholder-value' 'claim: safe reusable rule' >"$probe_root/candidate"
rg -q -i --pcre2 "$sensitive_pattern" "$probe_root/candidate"
sed -i 's/token=placeholder-value/[redacted]/' "$probe_root/candidate"
if rg -q -i --pcre2 "$sensitive_pattern" "$probe_root/candidate" \
    || rg -q -i --pcre2 "$host_pattern" "$probe_root/candidate"; then
  echo "redacted knowledge candidate must pass rescan" >&2
  exit 1
fi

# 追記で sha256sum の出力が変わることの確認は削除した (coreutils の受け入れテスト)

printf '%s\n' 'project: settings' 'claim: reusable public rule' >"$probe_root/candidate"
if rg -q -i --pcre2 "$sensitive_pattern" "$probe_root/candidate" \
    || rg -q -i --pcre2 "$host_pattern" "$probe_root/candidate"; then
  echo "safe knowledge candidate must pass both scans" >&2
  exit 1
fi

printf '%s\n' 'basis: library/okf/spec.md' 'source: agent/common/skills/polish/SKILL.md' \
  >"$probe_root/candidate"
if rg -q -i --pcre2 "$host_pattern" "$probe_root/candidate"; then
  echo "source paths must not be classified as hosts" >&2
  exit 1
fi

# 存在しないファイルに対する rg / sha256sum の exit status 検査は削除した
# (ripgrep / coreutils の受け入れテスト — GLOBAL.md「テスト」)

# frontmatter は name / description / model の3キーで、各キーがちょうど1回ずつ。
# 本質はキー数ではなく「roleの起動に要らない機構をここへ足さない」ことなので、
# 未知keyは落とし、重複key (後勝ちで挙動が変わる) も落とす。
# model は 3bfd674 の pin なので、キーの存在だけでなく値まで固定する —
# 値を見ないと別modelへ差し替わっても素通りする
frontmatter="$(sed -n '2,/^---$/p' "$role" | sed '$d')"
printf '%s\n' "$frontmatter" | grep -Eq '^name: knowledge-inventory$'
printf '%s\n' "$frontmatter" | grep -Eq '^description: '
printf '%s\n' "$frontmatter" | grep -Fqx 'model: claude-opus-5' || {
  printf 'knowledge-inventory must stay pinned to claude-opus-5 in %s\n' "$role" >&2
  exit 1
}
frontmatter_keys="$(printf '%s\n' "$frontmatter" | grep -Eo '^[a-zA-Z_-]+:' | sort)"
expected_keys="$(printf '%s\n' 'description:' 'model:' 'name:')"
if [ "$frontmatter_keys" != "$expected_keys" ]; then
  printf 'frontmatter keys must be exactly name/description/model once each in %s, got:\n%s\n' \
    "$role" "$frontmatter_keys" >&2
  exit 1
fi

echo "deliver knowledge inventory contract test: pass"
