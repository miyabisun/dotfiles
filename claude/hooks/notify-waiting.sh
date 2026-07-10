#!/usr/bin/env bash
set -euo pipefail

# Notification hook: 権限申請・質問で止まったときだけ通知する。
# プロンプト放置 (60秒 idle) でも Notification は飛んでくるが、
# ターン完了後の放置で「確認を求めています」が誤爆するので message で弾く。
MSG="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("message",""))' 2>/dev/null || true)"

case "${MSG}" in
    *permission*)
        exec bash ~/.local/bin/emit-turn-end.sh claude waiting
        ;;
    *)
        # 未知のメッセージはフィルタ調整用に記録だけして黙る
        printf '%s [skip] %s\n' "$(date '+%F %T')" "${MSG}" >> ~/.claude/notification-skip.log
        ;;
esac
exit 0
