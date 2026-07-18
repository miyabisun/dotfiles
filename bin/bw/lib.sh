# bin/bw 各コマンドから source される共通処理 (直接実行しない)
set -euo pipefail

require_deps() {
    local cmd
    for cmd in "$@"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: '$cmd' command not found." >&2
            exit 1
        fi
    done
}

require_unlocked() {
    require_deps rbw jq
    # agent が未起動/ロック中なら pinentry で unlock を促す
    rbw unlocked &> /dev/null || rbw unlock
}

# フォルダ内の item 名を列挙
list_item_names() { # <folder>
    rbw list --fields folder,name --raw \
        | jq -r --arg f "$1" '.[] | select(.folder == $f) | .name'
}

# item を名前で1件取得して JSON を返す (見つからなければ rbw がエラーを出す)
get_item_raw() { # <folder> <name>
    rbw get --folder "$1" "$2" --raw
}

# item の notes を取り出す (無ければ exit 1)
get_item_notes() { # <folder> <name>
    local notes
    notes=$(get_item_raw "$1" "$2" | jq -r '.notes // empty')
    if [ -z "$notes" ]; then
        echo "Error: item '$2' has no notes content." >&2
        exit 1
    fi
    printf '%s\n' "$notes"
}

# 同名 item を削除 (upsert の前処理。無ければ何もしない)
delete_items_by_name() { # <folder> <name>
    rbw rm --folder "$1" "$2" &> /dev/null || true
}

# stdin のバッファ (1行目 = password, 空行, 以降 = notes) で item を登録する。
# rbw add は stdin が TTY でなければエディタを開かず stdin をそのまま読む。
# 注意: rbw は notes 中の '#' 始まりの行を落とすため、コメントを含み得る内容は
# 呼び出し側で base64 エンコードして渡すこと。
rbw_add_item() { # <folder> <name>
    rbw add --folder "$1" "$2"
}
