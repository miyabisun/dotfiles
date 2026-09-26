---
name: idea
description: >-
  タスクになるか未定の思いつき・構想を、task-serverのアイデアとして記録・調査・破棄・タスク化する。
  「アイデア出し」「アイデアとして残す」「このアイデアを調べて」などの依頼で使う。
---

# idea

アイデアはタスクの手前にあるメモで、状態と実行先を持たない。task-serverのMCP
(`idea_list`・`idea_get`・`idea_create`・`idea_update`・`idea_archive`・`idea_promote`) で扱う。
タスクの登録・範囲変更は [task-creater](../task-creater/SKILL.md) が所有する。

## 記録する

1. `idea_list` (分かれば `product_id` で絞る) で同じ主題のアイデアを探す。
   あれば新規作成せず、そのアイデアへ追記する。
2. `idea_create` で登録する。タイトルだけでもよい。本文 (Markdown) には分かる範囲で次を書く。
   - 元の発言 (引用) と、そこから読み取った狙い
   - 実現案・調べた事実・出典URL
   - 未決の問い
   事実・userの決定・担当の推測を分けて書く。対象productが登録済みなら `product_id` を付ける。
3. 作成したID・タイトル・revisionを短く返す。

「アイデア出し」を頼まれたら、担当が候補を考えて会話で示す。
userが選んだものを1件1アイデアで登録する。登録まで頼まれていれば全件を登録する。

## 調べて育てる

`idea_get` で本文とrevisionを読み、調査結果を足した本文全体を
`idea_update` に `expected_revision` 付きで送る。本文は全置換なので、読んだ内容を落とさない。
conflictなら読み直して追記を統合し、送り直す。

## 破棄する

やめる理由を本文に追記してから `idea_archive` する。アーカイブ後は読めるが編集できない。

## タスクにする

userが明示したときだけ行う。task-createrで元の依頼・範囲・完了条件・実行先を決める。
`idea_promote` には、`body` にタスクの範囲と完了条件、`execution_target` に実行先を渡す。
作られるタスクはdraftのままで、アイデアの本文は変わらない。再実行しても同じタスクが返る。
