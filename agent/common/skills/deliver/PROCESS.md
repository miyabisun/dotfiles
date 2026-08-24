# delivery の工程表

この文書は、1 delivery が通る**工程と、その工程の所有者の唯一の正本**である。
段階 skill (`spike` / `polish`) と `working` は、ここに書かれた所有者を
上書きしない。skill 本文と食い違ったときは、この表が正である。

## 経路は 2 つ

- **直接経路**: user が `$deliver` / `$spike` / `$polish` を明示起動する。
  task-server の task を伴わない。commit までで契約が終わる。
- **pipeline 経路**: `working` が task-server から task を claim し、その
  delivery として `$deliver` を起動する。commit の後に push → report →
  review → approve → merge が続く。

## 工程一覧

下の表の並びは**直接経路の実行順**である。pipeline 経路は commit のあとで
順序が変わるので、表の後の「[経路別の実行順](#経路別の実行順)」を見る。

| ID | 工程 | 直接経路 | pipeline 経路 | 備考 |
|---|---|---|---|---|
| P1 | task の受領と現在地の照合 | — (user の依頼文がそのまま契約) | `working` | 食い違ったら着手しない |
| P2 | 作業場所の複製 (worktree・feature branch) | — (現在の作業場所のまま) | `working` | 1 task = 1 worktree = 1 branch |
| P3 | 段階の判定 (spike / polish) | `deliver` | `deliver` | 迷ったら polish |
| P4 | knowledge の読み込み (index・テスト戦略) | 段階 skill (`knowledge-read` の手順) | 同左 | index から入り、関係するリンクだけ辿る |
| P5 | 方針すり合わせ (planning 召喚 1 回) | 段階 skill | 同左 | 両経路で据え置く |
| P6 | 契約化 (達成条件・テスト戦略の決定) | 段階 skill | 同左 | 達成条件は最大3項目 (spike) / 最大5行 (polish)。`spike` は手順 2 で決めたテスト戦略を `knowledge-deposit` で預ける (棚卸しは省くが、この預け入れだけは例外) |
| P7 | 基線正規化 (formatting commit) | `polish` のみ・条件付き最大 1 個 | 同左 | 差分が無ければ no-op |
| P8 | 実装 | 段階 skill (子 agent) | 同左 | 親は同一文脈で実装を続けない |
| P9 | 検証 (テスト・隣接 check・formatter/linter・UI 実測) | 段階 skill | 同左 | 実行不能な check は理由を receipt へ |
| P10 | commit 前 mechanical gate | 段階 skill | 同左 | nonzero なら止まる。経路によらず必須。`polish` は手順 6 の gate、`spike` は手順 3 の green と手順 5 の formatter/linter が当たる |
| P11 | **独立実装レビュー** | **段階 skill (codex exec 召喚)** | **control plane の review 工程** | 所有者は経路ごとに一意 |
| P12 | **blocking の修正と再レビューの巡回** | **段階 skill (pass まで)** | **control plane (`request_changes` → `ready` → 再 delivery)** | 巡回数に上限は無い |
| P13 | commit | 段階 skill | 同左 | local 所有はレビューを通してから commit する。pipeline 所有では commit が review の subject になる |
| P14 | push | — (行わない) | `working` | feature branch にだけ push |
| P15 | 完了の報告 (report) | — (行わない) | `working` | report が review 発行を連れてくる |
| P16 | approve | — (行わない) | control plane (`approved` への昇格と `instant:merge` の発行は同一 tx) | 未レビューの commit を approve しない |
| P17 | merge | `merge` skill (user 起動) | merge worker (`instant:merge` task) | 既定ブランチへの統合 |
| P18 | release | `bump-tag` (user 起動) | `bump-tag` (`working` が dispatch) | 水準の決定は `bump-tag` だけが担う |
| P19 | receipt の報告 | 段階 skill | 段階 skill と `working` | どちらの経路でレビューしたかを残す |

太字にした 2 工程 (P11 独立実装レビュー / P12 blocking の巡回) が、この分割の
要点である。他の工程は両経路で所有者が同じか、経路の外側 (`working`) にあるが、
この 2 工程だけは**経路によって所有者が入れ替わる**。

delivery の外側にある knowledge の棚卸しは工程表に載せない。段階 skill は
棚卸しを工程として持たず、`spike` の預け入れだけが P6 の内側にある。

### 経路別の実行順

表の並びは直接経路の実行順である。pipeline 経路は P13 commit のあとに
P14〜P16 が挟まり、レビューが commit の後ろへ回る。

- **直接経路**: P1 → … → P10 に続けて
  - P11 (独立実装レビュー) → P12 (巡回) → P13 (commit)
  - P19 (receipt)
  - 契約は P13 で終わる。P17 merge と P18 release は user が別途起動する。
- **pipeline 経路**: P1 → … → P10 に続けて
  - P13 (commit) → P14 (push) → P15 (report)
  - P11 (review) → P12 (再巡回) → P16 (approve) → P17 (merge)
  - P19 (receipt)
  - P12 の再巡回は、`request_changes` が対象を `ready` へ戻し、
    P8〜P15 をもう一巡する形になる。

## レビュー工程の所有者

独立実装レビュー (P11) の所有者は、**1 delivery につき必ず 1 つ**である。
二重に持たない。0 個にもしない。

- **既定は local** — 段階 skill が `codex exec` を召喚して所有する。
- **pipeline 所有になるのは**、`working` が claim した task の delivery として
  `$deliver` を起動し、**その旨を明示的に宣言したときだけ**である。
- 段階 skill は pipeline の有無を**推測しない**。宣言が無ければ local へ倒す。
  branch 名・worktree の形・cwd から推測してはならない。推測を許すと、宣言の
  欠落や誤読でレビューが丸ごと省かれる。
- pipeline 所有のとき、段階 skill の**実装レビュー召喚は 0 回**になる。
- **planning 召喚 (P5) 1 回は両経路で据え置く。** planning は merge gate では
  なく、依頼整合の確認と第二の設計空間の探索である。control plane の review は
  それを代替しない。

### レビューを通らない変更を main line へ入れない

どちらの経路でも、**レビューを一度も通らないまま main line へ入る変更を
作らない**。これが両経路に共通する規範である。守り方だけが経路で違う。

- **local 所有**: 未レビューの source 変更を commit しない。commit の前に
  レビューを通す。
- **pipeline 所有**: commit が review の subject である。**未レビューの
  commit を approve / merge しない**。report した commit を review が
  snapshot する。その commit と一致するときにしか `approve` は通らない。
  だから、この不変条件を control plane が機械的に保証する。

ここで言う「source 変更」は delivery の実装変更を指す。意味保存契約のある
formatter が生成した style commit (P7 基線正規化) は、それ自体が独立実装
レビューの対象ではない。ただし pipeline 経路では、**report した commit の
一部として review の subject に含まれる**。

### pipeline 経路で未レビューの変更が残らない根拠

- worker が normal task を `outcome: "done"` で report する。同一 transaction で
  その task の `review` task が発行される。**発行できなければ report ごと
  拒否される** — 未レビューで放置される窓が無い。
- reviewer の `request_changes` は同一 tx で対象を `ready` へ戻す。worker は
  自分の card の `latest_review` で理由を読む。再 report すると次の review が
  `review:<id>~2`、`~3` として発行される。**巡回数に上限は無い**。
- `approve` は対象がまだ `done` で、review が発行された commit のままである
  ことを tx 内で確認してから `approved` へ移す。commit が動いていれば
  `review_subject_changed` 等で拒否される。

したがって pipeline 経路では、**commit した変更は必ず最後の修正まで
レビューされる**。段階 skill が local レビューを重ねる必要は無い。

## 工程表を跨ぐときの規律

工程の所有者を変えるときは、**この表を先に直す**。skill 本文だけを直して表と
食い違わせない。表に無い工程を skill 本文が勝手に増やさない。
