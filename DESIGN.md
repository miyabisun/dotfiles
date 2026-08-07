# DESIGN.md

このリポジトリの design authority。対象は terminal workspace (herdr) の
keyboard interaction であり、web UI・色・typography の規則は持たない
(テーマは catppuccin 固定のみ)。ここに無い判断は
config/herdr/config.toml の現状に従う。

## hjkl 2層モデル

herdr のタブ・workspace 操作は hjkl を2層で使う。両層は同じ方向対応を
共有する: h/l = タブ左/右、j/k = workspace 下/上。

| 層   | キー                   | 意味                                    | 性格               |
|------|------------------------|-----------------------------------------|--------------------|
| 移動 | alt+h / alt+l          | タブ左/右へ focus 移動                  | 直接キー・連打向き |
| 移動 | alt+j / alt+k          | workspace 下/上へ focus 移動            | 直接キー・連打向き |
| 交換 | prefix+ctrl+h / l      | focused tab を左/右の隣と入れ替え       | prefix 層・低頻度  |
| 交換 | prefix+ctrl+j / k      | focused workspace を下/上の隣と入れ替え | prefix 層・低頻度  |

- herdr 既定の prefix+p / prefix+n (タブ移動) は温存し、alt 層と併存する。
- 交換層の追加・変更が移動層の bind を変えてはならない。

## 交換 (swap) の意味論

- 交換対象は focused tab / focused workspace とその隣。端 (先頭・末尾) では
  wrap しない。端での交換要求は silent no-op で成功 (exit 0) 扱い。
- 交換後も focus は同じ tab / workspace に残る (対象が位置ごと動く)。
- 実装は herdr 組込み action ではなく、socket API (tab.move /
  workspace.move) を呼ぶ config/herdr/bin/herdr-swap。insert_index は
  「削除前の並びに対する位置」で、next = 現在位置+2、previous = 現在位置-1。

## shell binding の出力契約

keys.command (type = "shell") から呼ぶ helper は:

- 正常時: stdout / stderr とも無出力、exit 0。
- 失敗時: stderr に `<helper名>: <理由>` を1行出して nonzero。stdout は使わない。

## 検証方法

この contract の検証はブラウザ実測ではなく herdr socket API の観測で行う:
操作前後の tab.list / workspace.list の並びと focused / active_tab_id を
比較する。

## その他の確定 bind

prefix+s = 下 (上下) 分割、prefix+comma = settings、
alt+s / alt+x / prefix+space = pen (workspace 保存 / 削除 / picker)。
prefix 二度押しは herdr がリテラル prefix 送出に予約しており割当不可。
