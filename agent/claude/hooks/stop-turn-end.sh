#!/usr/bin/env bash
set -euo pipefail

# Stop フック: ターン完了を emit-turn-end.sh へ渡す。通知するかどうかの判断
# (workspace 静穏ゲート) は emitter 側が行う。

exec bash "${TURN_END_EMITTER:-${HOME}/.local/bin/emit-turn-end.sh}" claude success
