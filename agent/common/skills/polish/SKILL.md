---
name: polish
description: >-
  ブラッシュアップ段階の配達。動いているものに対する具体的な不満・issue を
  受け取り、修正・回帰テスト・変更隣接チェック・counterpart レビュー1回を経て
  1つの local commit で返し、0.x を v1.0.0 へ磨き上げていく。明示起動・段階
  明示・段階未指定 $deliver からの自動判断で使う。harden へ進むのは user の
  v1.0.0 宣言後、または version が既に 1.0.0 以上の時のみ (decision 0003)。
  push・deploy・release はしない。
---

# polish

**動いているものを、出てきた不満に沿って叩き直し、0.x を v1.0.0 へ磨き上げる**
(decision 0002/0003)。新規の体験づくりは `spike` の仕事であり、polish は成熟へ
向かう本流 — 実利のある品質改善を軽い足取りで積む。

## 起動条件

user の明示的な `$polish` 起動、同じ依頼文での段階明示、または段階未指定の
`$deliver` からの自動判断 (dispatcher が選択と根拠を宣言する) が起動根拠。

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
4. **レビュー1回**: レビュー前に `~/.local/bin/agent-talk-peer who` を1回
   実行し、反対 runtime の登録 pane を同じ window、次に同じ session の順で
   一意に固定して、user 原文 (verbatim)・diff・実行済みチェックを送り実装
   レビューを1往復だけ受ける。blocking は修正して focused closure、それ以外は
   記録して進む。不在・pane 消失・配達失敗・期限超過のときだけ self
   diff-review へ fallback し、その旨を receipt に記す。

   レビュワーの検査項目 (spike と横並び):
   - **テストの誠実さ (blocking)**: テストを読み、トートロジー (実装の
     言い換え、常に真になる assert) と誤魔化し (期待値のハードコード合わせ、
     assert の削除・弱体化、skip での回避) を検知する。サボり・不誠実は厳格に
     修正させる。直したバグに回帰テストが付いているかも見る。
   - **DRY**: 今回の diff が導入した有害な重複で、
     機構追加なしの局所抽出で消せるものだけを blocking とする。
     それ以外は non-blocking の TODO。
   - **過度な YAGNI (non-blocking)**: 落とされたケースに
     「このケースは必要か?」の質問を残し、receipt で user に返す。
   - **formatter / linter の実行確認 (blocking)** と、commit 対象が今回の
     変更だけかの **scope 確認 (blocking)**。
5. **コミットする**: 1 invocation = 1 local commit。English Conventional
   Commits。知識棚卸しは行わない (harden 専用)。
6. **報告する**: 解消した不満と証拠、残る不満、追加した回帰テスト、review の
   結果を短く返す。

## 昇格 (decision 0003)

`harden` へ進むのは次の2つの場合だけ。それ以外の自動昇格は存在しない。

- user が「v1.0.0 にして**全世界に問いかける**」と宣言した後。
- project の version (Rust なら Cargo.toml) が**既に 1.0.0 以上**の時。

credential・secret・権限境界・破壊的データ操作は polish の内側で扱う —
レビュー1回と不変条件 (secret 非コミット・push なし・破壊的 git 禁止) が
その守りである。将来リリースされ得ることは昇格理由にならない。閉域 LAN での
agent 間リスクの受容 (decision 0002, user-origin) の範囲は変わらない。

## 不変条件 (全段階共通)

- push・merge・deploy・release はしない
- secret・`.env` をコミットしない。agent-talk journal に秘密を載せない
- 無関係な作業中変更 (他セッションの未コミット作業を含む) を保護する
- 破壊的 git 操作 (checkout/restore/reset/clean/stash) で作業を管理しない
- 既存の有効なテストを green にするための改変・削除をしない
