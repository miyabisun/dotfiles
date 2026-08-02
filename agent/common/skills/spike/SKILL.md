---
name: spike
description: >-
  黎明期の最速試作。まず動かして画期的な体験を得ることを目的に、契約儀式・
  sec ゲート・知識棚卸しを省いて実装する。ただし TDD は死守 (テスト無き
  ゴールは存在しない)、formatter/linter は機械的に実行し、テストの誠実さと
  DRY・過度な YAGNI を見る軽量レビュー1回を通す。user が明示的に spike を
  起動したとき、または同じ依頼で黎明期段階を明示したときだけ使う。$deliver
  からの暗黙選択は禁止。push・deploy・release はしない。
---

# spike

目的はただ一つ: **最短で動くものを作り、体験を得る**。抽象化・設定項目・
将来対応・網羅的な堅牢性はあとの `polish` / `harden` が引き受ける
(decision 0002)。完成度は8割で止めてよく、TODO を残してよい。ただし
**作った分にはテストがある** — テスト無きゴールは存在しない。

## 起動条件

user の明示的な `$spike` 起動、または同じ依頼文での段階明示だけが起動根拠。
段階未指定の `$deliver` からこのスキルを推論で選んではならない (保証の暗黙降格
禁止)。

## 手順

1. **契約はテストで書く**: 達成条件は最大3項目とし、それぞれを実行可能な
   テストとして表現する。「何が動けば体験できたことになるか」がテスト名に
   なる。ledger・counterpart 照会・独立提案交換は行わない。
2. **TDD で作る**: 失敗するテストを先に書き (red)、通す (green)。この順序に
   自己免除は無い。user が同じ依頼文で明示的に例外を許可した場合のみ省略でき
   (原文を receipt に引用する)、それ以外で red を観測できないなら未達として止める。
   **ゴール = 最大3項目の acceptance テストと、
   変更に隣接する既存 test/build/lint が全て green**。
   実行不能な既存 check は未実行の理由と影響を receipt に記録し、
   黙ってゴールから除外しない。
3. **体験を確かめる**: テストとは別に、実際に動かした証拠を1つ取る —
   実行コマンドと出力、または操作結果。テストが通っても体験が成立しない
   spike は未完成である。
4. **formatter / linter を機械的に叩く**: repo に設定があればそのまま実行し、
   指摘を修正する。未導入で stack に標準のゼロ設定ツールがあるなら導入して
   よい (導入・実施コストが低く効果が大きい。user-origin の標準方針)。
5. **レビュー1回**: レビュー前に `~/.local/bin/agent-talk-peer who` を1回
   実行し、反対 runtime の登録 pane を同じ window、次に同じ session の順で
   一意に固定して、diff・テスト・実行証拠を送り1往復だけ受ける。
   不在・pane 消失・配達失敗のときだけ self review へ fallback し、下記の
   観点を自分に適用してその旨を receipt に書く。
6. **コミットする**: 既定は 1 invocation = 1 local commit。複数 checkpoint
   commit は、起動時の user 依頼文が明示的に許可した場合のみ (その原文を
   receipt に引用し、件数と各 scope を報告する)。English Conventional Commits。
7. **報告する**: 何が動くか、テスト結果、動作証拠、残した TODO と
   non-blocking の質問リスト、次に polish すべき点を短く返す。

## レビュワーが見るもの

レビュワー (counterpart または self review) の検査項目は次に限定する。
ここに無い観点 (網羅的堅牢性・性能・美観) は spike では扱わない。

- **テストの誠実さ (blocking)**: テストを読み、トートロジー (実装の言い換え、
  常に真になる assert、実装と同じ計算式での期待値生成) と誤魔化し (期待値の
  ハードコード合わせ、assert の削除・弱体化、skip での回避、green にする
  ためだけのテスト改変) を検知する。サボりや user に対して不誠実な挙動を
  見つけたら厳格に blocking とし、修正させる。
- **DRY**: 今回の diff が導入した同一知識・同一ロジックの有害な重複で、
  機構追加なしの局所抽出で消せるものだけを blocking とする。試作上の小さな
  意図的重複や、解消に抽象化を要するものは non-blocking の polish TODO に
  落とす。
- **過度な YAGNI (non-blocking)**: 「必要になるかもしれないのに落とされた
  ケース」を見つけたら、TODO として「このケースは必要か?」の質問を残す。
  spike を止めない。質問リストは receipt で user に返す。
- **formatter / linter の実行確認 (blocking)**: 手順4が実際に実行されたか、
  指摘が残っていないかを確認する。
- **scope 確認 (blocking)**: commit 対象が spike の変更だけで、無関係な
  作業中変更を巻き込んでいないか。

## 昇格トリガー (強制)

次に触れる必要が生じたら、このスキルの内側で続行せず、**harden への切り替えを
宣言して停止する**。推奨で済ませてはならない。

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
