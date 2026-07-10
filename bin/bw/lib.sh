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
    require_deps bw jq
    local status
    status=$(bw status | jq -r .status)
    if [ "$status" != "unlocked" ]; then
        echo "Error: Bitwarden vault is locked. Run 'bw login' or 'bw unlock'." >&2
        exit 1
    fi
}

# フォルダ名 -> フォルダ ID (見つからなければ exit 1)
folder_id() {
    local name="$1" id
    id=$(bw list folders --search "$name" \
        | jq -r --arg name "$name" '.[] | select(.name == $name) | .id' | head -n 1)
    if [ -z "$id" ] || [ "$id" = "null" ]; then
        echo "Error: Folder '$name' not found in Bitwarden. Please create it first." >&2
        exit 1
    fi
    printf '%s\n' "$id"
}

# 同名 item を削除 (upsert の前処理。無ければ何もしない)
delete_items_by_name() { # <folder_id> <name>
    local ids id
    ids=$(bw list items --folderid "$1" \
        | jq -r --arg name "$2" '.[] | select(.name == $name) | .id')
    [ -z "$ids" ] && return 0
    while read -r id; do
        if [ -n "$id" ]; then
            bw delete item "$id" > /dev/null
            echo "Deleted existing item: $id"
        fi
    done <<< "$ids"
}

# stdin の item JSON を登録する
create_item() {
    bw encode | bw create item > /dev/null
}

# item を名前で1件取得 (見つからなければ exit 1)
find_item() { # <folder_id> <name>
    local item
    item=$(bw list items --folderid "$1" \
        | jq --arg name "$2" 'map(select(.name == $name)) | first')
    if [ -z "$item" ] || [ "$item" = "null" ]; then
        echo "Error: Item '$2' not found." >&2
        exit 1
    fi
    printf '%s\n' "$item"
}

# フォルダ内の item 名を列挙
list_item_names() { # <folder_id>
    bw list items --folderid "$1" | jq -r '.[].name'
}
