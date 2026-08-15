#!/usr/bin/env bash
set -euo pipefail

# Codex appends one JSON notification argument to the configured command.
PAYLOAD="${1:-}"
THREAD_ID=""
if [[ "${PAYLOAD}" =~ \"thread-id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
    THREAD_ID="${BASH_REMATCH[1]}"
fi

# is-subagent.sh は自分と同じディレクトリに居る。installer が
# ~/.local/bin へ張る symlink 経由の起動でも repo 内の実体へ届くよう、
# 自己位置は symlink を 1 段解決してから確定する (installer は絶対パスで張る)。
SELF_PATH="${BASH_SOURCE[0]}"
if [[ -L "${SELF_PATH}" ]]; then
    SELF_PATH="$(readlink "${SELF_PATH}")"
fi
SELF_DIR="$(cd -- "$(dirname -- "${SELF_PATH}")" && pwd -P)"

# Suppress completion announcements from every subagent kind, including the
# automatic approval reviewer. If identification fails, preserve the parent's
# notification rather than silently dropping it.
if [[ -n "${THREAD_ID}" ]] \
    && bash "${SELF_DIR}/is-subagent.sh" "${THREAD_ID}"; then
    exit 0
fi

# 通知するかどうかの判断 (workspace 静穏ゲート) は emitter 側が行う。
exec bash "${CODEX_NOTIFY_EMITTER:-${HOME}/.local/bin/emit-turn-end.sh}" codex success
