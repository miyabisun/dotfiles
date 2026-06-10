#!/usr/bin/env bash
# PostToolUse hook for WebFetch: remind to use Obscura as a second arrow when
# WebFetch came back insufficient (403 / blocked / empty / JS-required).
# Non-blocking: WebFetch already ran. If WebFetch was fine, ignore this.
cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "WebFetch の結果が 403 / アクセス拒否 / 空 / 「取得できません」/ JS必須 など不十分だった場合は、即座に Obscura で二の矢を継ぐこと: Bash で `obscura fetch <url> --eval \"document.body.innerText\"`（または obscura MCP）。WebFetch で十分取得できていれば何もしなくてよい。"
  }
}
EOF
