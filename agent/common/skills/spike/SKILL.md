---
name: spike
description: >-
  黎明期の最速試作。v0.1.0 のリリースを目指し、まず動かして画期的な体験を
  得る。契約儀式・sec ゲート・知識棚卸しは省くが、TDD は死守 (テスト無き
  ゴールは存在しない)、formatter/linter は機械的に実行し、テストの誠実さと
  DRY・過度な YAGNI を見る軽量レビュー1回を通す。明示起動・段階明示・段階
  未指定 $deliver からの自動判断で使う。自動昇格は polish まで (decision
  0003)。push・deploy・release はしない。
---

# spike

目的はただ一つ: **最短で動くものを作り、体験を得る**。spike は
**v0.1.0 のリリースを目指す**段階である — バグを踏まれても「v0.1.0 だから」と
言える粗さで、まず世に出せる形へ向かう (リリース行為そのものは user が
`bump-tag` で行う)。抽象化・設定項目・将来対応・網羅的な堅牢性はあとの
`polish` が引き受ける (decision 0002/0003)。完成度は8割で止めてよく、TODO を
残してよい。ただし**作った分にはテストがある** — テスト無きゴールは存在しない。

## 起動条件

user の明示的な `$spike` 起動、同じ依頼文での段階明示、または段階未指定の
`$deliver` からの自動判断 (dispatcher が選択と根拠を宣言する) が起動根拠。

## 手順

0. **新規プロジェクトなら土台を整える** (既存プロジェクトでは飛ばす):
   - agent-talk で knowledge セクションの登録 pane へ**共通開発仕様**を
     1回だけヒアリングする。不在・無応答は記録して進む。
   - `rust-svelte-template` (~/projects/sunny-side/rust-svelte-template) を
     導入し、今回の要件に**不要なものを削る**
     (例: CLI なら client/ 配下や DESIGN.md を削除)。
   - **LICENSE は MIT** — バグを踏んでも v0.1.0 だから文句を言うなよ、の
     意思表示である。
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
   **v0.1.0 readiness の確認も完了条件に含む**: 新規プロジェクトの該当
   manifest (Cargo.toml 等) は version が 0.1.0 であること、MIT LICENSE と
   土台の不要物除去が済んでいること、そして**リリースを妨げる既知事項**を
   receipt に列挙する (release/push 自体は行わない — それは user の
   `bump-tag`)。既存プロジェクトの manifest が別の 0.x を持つ場合は勝手に
   version を書き換えず、現在値と「v0.1.0 対象外 (既存)」を receipt に記録
   する。

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

## 昇格 (decision 0003)

**自動昇格は polish まで**。`harden` は「v1.0.0 にして**全世界に問いかける**」
と user が宣言した後の段階であり、spike からの強制昇格先にはならない。

- credential・secret の取り扱い、権限・認証・信頼境界の変更、破壊的な
  データ操作 (drop・一括削除・migration) に触れる必要が生じたら、
  **polish への切り替えを宣言して停止する** (レビュー付きの流れで扱う)。
- harden へ直行する例外は1つだけ: project の version (Rust なら Cargo.toml)
  が**既に 1.0.0 以上**なのに spike が起動された時 —
  「これ既に v1.0.0 やん、なんで spike やねん」の状態。
- 将来 `bump-tag` でリリースされ得ることは昇格理由にならない。公開の権限は
  release 操作の明示起動が別途担い、spike 自身は push しない。

閉域 LAN での agent 間リスクの受容 (decision 0002, user-origin) の範囲は
変わらない。受容されたのは lateral agent takeover だけである。

## 不変条件 (全段階共通)

- push・merge・deploy・release はしない
- secret・`.env` をコミットしない。agent-talk journal に秘密を載せない
- 無関係な作業中変更 (他セッションの未コミット作業を含む) を保護する
- 破壊的 git 操作 (checkout/restore/reset/clean/stash) で作業を管理しない
- 既存の有効なテストを green にするための改変・削除をしない
