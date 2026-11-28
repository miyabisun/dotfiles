---
name: knowledge-read
description: >-
  開発開始時や対象 repository 切替時に、$KNOWLEDGE_REPO/MEMORY.md と関連する
  規範・プロジェクト固有の地雷を読む。同じ対象の既読情報は再利用する。
---

# knowledge-read

対象の実装・CI・テスト設定を事実として確認し、`$KNOWLEDGE_REPO` で共通規範・コード外の地雷を補う。
共通知識を各 repository の `README.md` や `AGENTS.md` へ複製しない。

1. 依頼の対象 repo を remote と一次文書から特定する。別対象へ移ったら確認し直す。
2. `$KNOWLEDGE_REPO`（または明示された checkout）の `MEMORY.md` を読む。
   未設定・読めない場合は不足だけ伝え、一次情報で進められる作業を続ける。
3. 今回に関係するファイルだけを直前に開く。無関係な `projects/` や `profile/` を一括で読まない。
   - プロジェクト固有の地雷・物理実測: `projects/<repo>.md`（存在する場合）
   - 公開範囲・認証・アクセス制御: `rules/security-by-exposure.md`
   - Web / native UI の作成・変更: [design-context](../design-context/SKILL.md)
   - CI・release 経路: [project-architecture](../project-architecture/SKILL.md)
4. 同じセッション内で既読の情報は再利用する。委譲先には関連 path と要件だけ渡し、本文を複製しない。

メモと現行コード・設定が食い違えば今の事実を優先し、現在のユーザー要求は過去のメモより優先する。
