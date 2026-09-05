# delivery の工程と所有者

`deliver` / `spike` / `polish` の工程と所有者はこの文書が持つ。
判断基準・レビュー・停止・報告の共通規則は [CONTRACT.md](CONTRACT.md) が持つ。
サービスの実装済み状況や配備状態はここに固定せず、必要時に実装を確認する。

## 工程一覧

| 工程 | 所有者 | 完了条件 |
|---|---|---|
| 依頼・現在地・既存変更の確認 | delivery 担当 | 目的、対象、権限、保護する作業を把握する |
| 段階選択 | deliver、または段階を指定した user | 新しい体験は spike、既存の改善は polish |
| 方針と達成条件 | delivery 担当 | 必要な知識を読み、検証方法を決める。独立 planning は設計上の不確実性があるとき |
| 実装・検証 | delivery 担当と委譲先 | 達成条件を満たし、変更に必要な checks が通る |
| 独立レビュー | 下記の review 所有者 | 対象差分と証拠を確認する |
| 指摘修正・再確認 | delivery 担当と review 所有者 | 有効な blocking が解消し、修正による回帰がない |
| local commit・結果報告 | delivery 担当 | 実際の成果、検証、レビュー状態、未完了事項を報告する |

担当は受領時に決める。サブエージェントを delivery 担当にしてよい。
部分委譲しても、担当は成果の確認・未解消事項の処理・報告まで責任を持つ。
親は子の開発を重複実行せず、結果と証拠の参照先を受け取る。

## レビュー工程の所有者

独立レビューの所有者は 1 delivery につき 1 つ。実行者を交代しても二重に実施しない。

- **local (既定)**: delivery 担当が独立レビュワーを使い、修正と再確認まで進める。
  親・子のどちらから起動したかでこの責務は変わらない。
- **pipeline (互換経路)**: 起動依頼が「この delivery は pipeline 経路であり、
  独立実装レビューは control plane の review 工程が所有する」と宣言した場合。
  その経路では local の実装レビューを重ねない。担当は検証済み commit と
  証拠を渡し、「外部レビュー待ち」と報告する。宣言だけでレビュー済みにはしない。
  外側は指摘を担当へ戻し、修正後の commit を確認してから統合する責任を持つ。

宣言がなければ local。branch 名や cwd から pipeline 所有を推測しない。
外側の review 工程が動かない場合は、その未完了状態を明示する。
経路を変更する場合は所有者を更新して引き継ぎ、古い経路での完了と混同しない。

### レビューを通らない変更を main line へ入れない

local では検証とレビューを満たしてから delivery を完了とする。
作業保存用の checkpoint は作業 branch に置けるが、完了や統合の証拠にはしない。
pipeline では review 対象 commit と統合対象を一致させる。
実行障害時の扱いは [fallback](CONTRACT.md#fallback-circuit-breaker) に従い、
自己レビューを独立レビューとして報告しない。

## delivery の外側

task の取得・状態保存・haystack の記録は呼び出し元が持つ。
`deliver` の local commit は task 全体の merge / release 完了を意味しない。
push・merge・deploy・release は、それぞれの依頼と対応する skill の責務である。
既に依頼されている外側の工程は local commit 後に続け、同じ授権を聞き直さない。
これらの操作を `deliver` の起動だけで新たに授権しない。
