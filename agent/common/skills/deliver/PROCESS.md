# 外部レビューとの接続

通常は delivery 担当が実装・検証・独立レビュー・指摘修正・local commit まで完遂する。
この文書は外側が review を所有する場合だけ読む。

## レビュー工程の所有者

起動依頼が「この delivery は pipeline 経路であり、独立実装レビューは control plane の review 工程が所有する」
と宣言した場合、local の独立レビューを重ねず、検証済み commit と証拠を渡して「外部レビュー待ち」と報告する。
宣言や commit 自体をレビュー済みとは扱わない。外側は指摘を担当へ戻し、修正後の commit を確認してから統合する。
宣言がなければ local。branch 名や cwd から推測しない。所有者は一つにし、交代時は残件を引き継ぐ。

## delivery の外側

task の取得・状態保存・haystack の記録は呼び出し元が持つ。
local commit は task 全体の merge / release 完了ではない。
既に依頼された後続工程は対応 skill で続け、同じ授権を聞き直さない。
