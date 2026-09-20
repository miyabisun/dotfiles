# 外部レビューとの接続

通常は delivery 担当が[deliver](SKILL.md) に沿って実装・検証・レビュー・指摘修正・commit・pushまで完遂する。
この文書は外側が実装レビューを所有する場合だけ読む。
事前判断は [task-creater](../task-creater/SKILL.md) が所有し、その結果を引き継ぐ。

## レビュー工程の所有者

起動依頼が、独立実装レビューを外側のreview工程に任せると明示した場合、
local の独立レビューを重ねず、検証済みcommitをpushする。
push先とcommit、証拠を渡して「外部レビュー待ち」と報告する。
knowledge-read で特定した設計判断・規則の文書への参照・適用する節・今回の構成も渡し、外側のレビュー担当が読む。
宣言や commit 自体をレビュー済みとは扱わない。外側は指摘を担当へ戻し、修正後の commit を確認してから統合する。
宣言がなければ local。branch 名や cwd から推測しない。所有者は一つにし、交代時は残件を引き継ぐ。

## delivery の外側

task の取得・状態保存・haystack の記録は呼び出し元が持つ。
commit・pushはtask全体のmerge / release完了ではない。
既に依頼された後続工程は対応 skill で続け、同じ授権を聞き直さない。
