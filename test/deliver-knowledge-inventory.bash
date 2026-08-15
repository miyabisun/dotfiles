#!/usr/bin/env bash
# assert する文字列は対象ファイルの literal なので、$ や ` を展開させない
# shellcheck disable=SC2016,SC2088
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

role="$repo_root/agent/common/agents/knowledge-inventory.md"
adapter="$repo_root/agent/codex/agents/knowledge-inventory.toml"
config="$repo_root/agent/codex/config.toml"
readme="$repo_root/agent/README.md"

assert_contains() {
  local file="$1"
  local text="$2"
  grep -Fq -- "$text" "$file" || {
    printf 'missing contract in %s: %s\n' "$file" "$text" >&2
    return 1
  }
}

# dedicated role: provenance、空batch禁止、安全な1回送信
test -f "$role"
assert_contains "$role" 'source_request.fidelity=reconstructed'
assert_contains "$role" '人間の原文として引用しない'
assert_contains "$role" '空batchを送らない'
assert_contains "$role" 'typoだけの文書修正'
assert_contains "$role" 'agent-knowledge-intake.md'
assert_contains "$role" 'candidate_file'
assert_contains "$role" 'chmod 600 "$candidate_file" "$host_file"'
assert_contains "$role" "trap 'rm -f \"\$candidate_file\" \"\$host_file\"' EXIT HUP INT TERM"
assert_contains "$role" '一回のshell呼び出しの中でtemporary file作成、serialize、scan、'
assert_contains "$role" 'sensitive_pattern'
assert_contains "$role" 'rg -q -i --pcre2 "$sensitive_pattern" "$candidate_file"'
assert_contains "$role" 'URLとhost候補を別に列挙'
assert_contains "$role" '再走査にも候補が残る場合は送信しない'
assert_contains "$role" '該当itemだけを除外またはredact'
assert_contains "$role" 'test "$scan_status" -eq 1 || exit 2'
assert_contains "$role" 'test "$host_status" -eq 1 || exit 2'
assert_contains "$role" 'candidate_file="$(mktemp /tmp/agent-knowledge.XXXXXX)"'
assert_contains "$role" 'host_file="$(mktemp /tmp/agent-knowledge-hosts.XXXXXX)"'

# 送信は MCP の send_message 1回。旧 dispatcher の file-body 経路は撤去済みで、
# その代わりに「scan 後に本文を変えない」規律と、失われた保証の明示が要る。
assert_contains "$role" "\`send_message\` (\`to: 'knowledge/codex'\`, \`no_reply: true\`)"
assert_contains "$role" 'scan後に本文を追記・整形・置換・要約しない'

# exact-body の機械保証が transport から失われている間は fail-closed。
# decision 0002 の受容範囲は lateral agent takeover 限定で、secret 弱体化を
# polish の内側で受容できない (この根拠まで含めて固定する)
assert_contains "$role" '**ただし現在この送信は行わない。`pending`を返して終える。**'
assert_contains "$role" 'lateral agent takeoverに限定'
assert_contains "$role" 'userがこの経路の再開をこの pane で明示承認する'
if grep -Fq -- 'agent-talk-peer' "$role"; then
  echo 'knowledge handoff must not use the retired CLI dispatcher' >&2
  exit 1
fi
# 撤去したのは呼び出しであって言及ではない (「失われた保証」節は --body-file に
# 触れる)。実際の起動形だけを禁止する
if grep -Fq -- '--body-file "$candidate_file"' "$role"; then
  echo 'knowledge handoff must not invoke the removed --body-file form' >&2
  exit 1
fi

alternate_tmp="$(mktemp -d)"
candidate_probe="$(TMPDIR="$alternate_tmp" mktemp /tmp/agent-knowledge.XXXXXX)"
case "$candidate_probe" in
  /tmp/agent-knowledge.*) ;;
  *)
    echo 'knowledge candidate must stay under the dispatcher-approved /tmp root' >&2
    exit 1
    ;;
esac
rm -f "$candidate_probe"
rmdir "$alternate_tmp"
assert_contains "$role" '送信は最大1回'
assert_contains "$role" '自動再送しない'
assert_contains "$role" 'arona-knowledgeでgit操作をしない'
assert_contains "$role" 'knowledgeは開発完了、routing、releaseを決めない'

# role配布: common role + Codex adapter/config。installはdirectory symlinkなので変更不要
test -f "$adapter"
assert_contains "$adapter" 'name = "knowledge-inventory"'
assert_contains "$adapter" '~/.agents/agents/knowledge-inventory.md'
assert_contains "$config" '[agents.knowledge_inventory]'
assert_contains "$config" 'config_file = "agents/knowledge-inventory.toml"'
assert_contains "$readme" '`knowledge-inventory`'

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

printf '%s\n' 'claim: immutable candidate' >"$probe_root/candidate"
validated_hash="$(sha256sum "$probe_root/candidate" | cut -d ' ' -f 1)"
printf '%s\n' 'unvalidated append' >>"$probe_root/candidate"
send_hash="$(sha256sum "$probe_root/candidate" | cut -d ' ' -f 1)"
if [[ "$validated_hash" == "$send_hash" ]]; then
  echo "candidate mutation must invalidate the send hash" >&2
  exit 1
fi

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

scan_failed=0
if rg -q -i --pcre2 "$sensitive_pattern" "$probe_root/missing" 2>/dev/null; then
  echo "missing scan input must not be clean" >&2
  exit 1
else
  scan_status=$?
  [[ "$scan_status" -eq 1 ]] || scan_failed=1
fi
test "$scan_failed" -eq 1

if hash_line="$(sha256sum "$probe_root/missing" 2>/dev/null)"; then
  echo "missing hash input must fail" >&2
  exit 1
fi
test -z "$hash_line"

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

# dedicated roleには書込・release orchestrationを持たせない
assert_contains "$role" 'arona-knowledgeでgit操作をしない'
assert_contains "$role" '`git add`、`git commit`、`git push`を実行しない'
assert_contains "$role" 'release・deploy・pushを行わない'

echo "deliver knowledge inventory contract test: pass"
