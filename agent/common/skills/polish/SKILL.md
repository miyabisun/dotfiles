---
name: polish
description: >-
  ブラッシュアップ段階の配達。動いているものに対する具体的な不満・issue を
  受け取り、修正・回帰テスト・変更隣接チェック・counterpart レビュー1回を経て
  1つの local commit で返す。user が明示的に polish を起動したとき、または同じ
  依頼でブラッシュアップ段階を明示したときだけ使う。$deliver からの暗黙選択は
  禁止。secret・権限境界・破壊的データ・外部公開に触れる場合は harden へ強制
  昇格する。push・deploy・release はしない。
---

# polish

**動いているものを、出てきた不満に沿って叩き直す** (decision 0002)。新規の
体験づくりは `spike`、リリース水準の保証は `harden` の仕事であり、このスキルは
その中間 — 実利のある品質改善を軽い足取りで積む。

## 起動条件

user の明示的な `$polish` 起動、または同じ依頼文での段階明示だけが起動根拠。
段階未指定の `$deliver` からこのスキルを推論で選んではならない。

## 手順

1. **不満を契約にする**: 依頼文の不満・issue を観測可能な達成条件に変換する
   (最大5行)。user 原文は verbatim で保持する。ledger の JSON 儀式・独立提案
   交換・二段階照合は行わない。
2. **直す**: 最小の変更で不満を解消する。設計の作り直しが必要だと分かったら、
   その場で拡張せず「harden で扱うべき」と報告して縮小する。
3. **検証する**:
   - 変更に隣接する既存チェック (テスト・build・lint) を repo 標準コマンドで
     実行する。存在しないものを新設しない。
   - 直したバグ1件につき回帰テスト1本を実用的な範囲で追加する。
     困難なら理由を receipt に1行で書く。
   - formatter/linter は repo に既存の設定があれば直接実行する。独立 formatter
     ゲートは立てない。
4. **レビュー1回**: counterpart pane が利用可能なら、user 原文 (verbatim)・
   diff・実行済みチェックを送り実装レビューを1往復だけ受ける。blocking は
   修正して focused closure、それ以外は記録して進む。counterpart 不在・配達
   失敗・期限超過は self diff-review へ fallback し、その旨を receipt に記す。
5. **コミットする**: 1 invocation = 1 local commit。English Conventional
   Commits。知識棚卸しは行わない (harden 専用)。
6. **報告する**: 解消した不満と証拠、残る不満、追加した回帰テスト、review の
   結果を短く返す。

## 昇格トリガー (強制)

次のいずれかに触れる変更が必要になったら、polish の内側で続行せず、**harden
への切り替えを宣言して停止する**か、authority gap として user へ1点だけ問う。
推奨で済ませてはならない。

- credential・secret・`.env` 系の取り扱い
- 権限・認証・信頼境界の変更
- 破壊的なデータ操作 (drop・一括削除・migration)
- 外部公開・release artifact・第三者へ届く出力

閉域 LAN での agent 間リスクの受容 (decision 0002, user-origin) はこの列挙を
免除しない。受容されたのは lateral agent takeover だけである。

## 不変条件 (全段階共通)

- push・merge・deploy・release はしない
- secret・`.env` をコミットしない。agent-talk journal に秘密を載せない
- 無関係な作業中変更 (他セッションの未コミット作業を含む) を保護する
- 破壊的 git 操作 (checkout/restore/reset/clean/stash) で作業を管理しない
- 既存の有効なテストを green にするための改変・削除をしない
