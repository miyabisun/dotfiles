---
name: knowledge-read
description: >-
  開発開始時や対象product/repositoryの切替時に、外部knowledgeから関連する
  設計判断・共有テスト戦略を読む。同じ対象の既読情報は再利用する。
---

# knowledge-read

対象の実装・CI・テスト設定を事実として確認し、knowledgeで意図・背景・共有戦略を補う。
共通知識を各repositoryのAGENTS.md等へ複製しない。

1. 依頼のproduct名と対象repositoryのremote・一次文書を照合して対象を定める。
   cwdやworktreeのdirectory名だけで判断しない。別対象へ移ったら解決し直す。
2. knowledgeの場所は `$KNOWLEDGE_REPO`、または今回明示されたcheckoutを使う。
   未設定・読めない場合はその不足を伝え、一次情報で進められる作業を続ける。
   実際に必要な未確定方針だけを尋ね、pathや方針を捏造しない。
3. 対象の `projects/<org>/<repo>/index.md` から、今回に関係する判断・テスト戦略を読む。
   bundle名が不明なら `projects/index.md` を使い、旧名の探索にだけcatalogを使う。
   横断事項は `library/index.md` の該当リンクへ進む。全区画や利用者profileを一括で読まない。
   公開範囲・認証・アクセス制御・アプリの責務を扱う実装やレビューでは、解決したknowledgeの
   `library/policies/security-by-exposure.md` を正本として読む。
4. 対象・読んだpath・今回の判断に必要な要点を会話内で把握し、同じ対象の既読情報は再利用する。
   更新の兆候や矛盾が出た文書だけ再確認する。新しいsessionではこの入口から解決する。
   委譲・レビューには解決済みcheckoutと関連文書のpath、適用する節、今回の構成・要件を渡し、
   受け手が正本を読めるようにする。本文や方針を各skillへ複製しない。
   全履歴や全knowledgeの転送、永続cacheの新設は要らない。

適用する方針とテスト戦略が必要な範囲で分かったら実装へ進む。
bundleや戦略が無ければ実装・CIの現状から検証方法を決め、未確認の意図は未確認と扱う。
knowledgeと一次情報が食い違えば差を示し、背景の記録を現行の命令や挙動と取り違えない。
