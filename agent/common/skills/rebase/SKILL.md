---
name: rebase
description: >-
  既定ブランチと分岐した feature branch を rebase して載せる配達。
  fast-forward できないと分かった `merge` から持ち替えて来る。remote HEAD から
  既定ブランチを解決し、一時 integration ref を rebase して、コンフリクトと
  テスト失敗を polish と同じやり方 (毎回作成する子 agent + 独立レビュー1回) で
  解消し、緑かつ pass のときだけ force なしで push する。製品判断になる衝突は
  既定ブランチを触らず user へ返す。
---

# rebase

**既定ブランチと分岐した feature branch を、rebase して既定ブランチへ載せる**。
fast-forward できるなら `merge` がそのまま前進させて終わる — ここへ来るのは
歴史が分岐していて rebase が必要な場合だけである。そのとき「rebase して終わり」
にはできない。rebase は `polish` と同じ作りの配達である。子 agent を展開して
コンフリクトを吸収し、テストを緑にし、独立レビューを通してから、はじめて
既定ブランチへ反映する。緑でないものを載せないことが、この skill の唯一の
存在理由である。

## 起動条件

起動根拠は 2 経路しかなく、push の授権範囲はそれぞれ別に決まる。
**`merge` が fast-forward 不能と判定して持ち替えて来た場合は、その `merge` の
起動根拠と授権範囲をそのまま引き継ぐ** — 持ち替えは新しい授権を作らない。

- **user が `$rebase` / `$merge` を直接起動した場合**: その invocation 自体が
  user の号令である。授権の範囲は **user が名指しした repository と feature
  branch、およびその既定ブランチへの反映操作に限る**。名指しされていない repository・branch
  へは広がらない。
- **`working` が merge task から dispatch した場合**: 授権は **その task が
  名指しする repository・branch・操作に限り、その task を保持している間に
  限る** — 授権は task の終了とともに失効する。

いずれの経路でも、model が「今なら載せられそう」と判断して自走起動することは
号令ではない。**自分の push を授権することになる task を自分で作らない。**

task-server へは MCP でだけ触る。HTTP API の直叩き、データベースファイルへの
直接書き込みはしない。実際の tool 名・field 名・state 名は **まだ確定していない**
ため、本書は「task-server が提供する MCP tool」の抽象で書く。
**schema が確定したら実際の tool 名へ結線する。**

## 作業の分担 (毎回 agent を作成する)

配達のたびに**毎回 agent を作成する**。親の同一長い文脈でファイル変更・
CLI 待ちとログ読み・事実確認を続けてはならない。

- **親が担う**: 既定ブランチの解決、integration ref の管理、レビュワー召喚の
  管理、子への割り当て、子の完了待ち、push の判断。親はハブである。
- **子が担う**: コンフリクト解消の編集、テスト実行の CLI 待ちとログ読み、
  事実確認。子は発火 pane の user 授権を継承する。peer ではない。
- **子は push しない。** remote を変える操作は親だけが行う。

**子 agent の結果待ち**で blocked かつ他に有用な独立作業が無いなら、**現在の
turn を終了して yield しなければならない** (sleep・wait loop で turn を保持
しない)。その turn の最終行に必ず `<!-- delivery:waiting -->` を置く。
yield 直前の最終出力は完了報告と誤認される文言にしない。
契約は push (または user へ戻すこと) まで。途中で止まった rebase は未完了である。

## 手順

1. **origin を最新化し、既定ブランチを解決する**: `git fetch` (必要なら
   `--prune`) で origin を最新にし、**remote HEAD から既定ブランチ名を解決する**。
   `main` と決め打ちしない — `git symbolic-ref refs/remotes/origin/HEAD` や
   `git remote show origin` の HEAD 表示など、remote が申告する値を使う。
   解決できなければ推測せず、その旨を報告して止まる。
2. **一時 integration ref を作る**: feature の HEAD から
   **一時 integration ref (branch か worktree) を作る**。以降の rebase・
   コンフリクト解消・テストは全てその上で行う。
   **元の feature ref は更新しない** — 失敗しても feature は着手前の姿のまま
   残り、やり直しは integration ref を捨てるだけで済む。
3. **rebase する**: その integration ref を `origin/<default>` の上へ
   **rebase** する。merge commit で被せない。rebase が clean に通ったなら
   手順 4 のコンフリクト解消は不要だが、テストとレビューは省略しない。
4. **緑にする (polish と同じやり方)**: コンフリクトとテスト失敗は、
   `polish` と同じ手順で直す。
   - **実装は毎回作成する子 agent が行う。** 親はハブに徹し、同一文脈で
     編集を続けない。
   - **repo 標準のテストを実行し緑にする。** 存在しないチェックを新設しない。
     実行不能なものは理由と影響を receipt に残し、黙って除外しない。
   - 既存の有効なテストを green にするための改変・削除をしない。
   - **親が管理する独立レビューを 1 回通す** (`polish` の
     「レビュワー召喚」と同じ形・同じ fallback)。渡すのは task 本文
     (verbatim)・rebase 後の diff・コンフリクト解消の判断・テスト結果。
     `blocking` を直したら再検証を 1 回だけ通す。
5. **反映する**: **テストが緑で、レビューが pass したときだけ**、
   integration HEAD を `origin/<default>` へ **force なしで** push する。
   - 緑でない、レビューが `changes_required` のまま、あるいは判断が
     user へ回った — このいずれでも push しない。
   - push が非 fast-forward で弾かれたら、force で押し通さない。
     手順 1 からやり直すか、user へ返す。
6. **後片付けは push のあとだけ**: push が成功したあとにのみ、remote と local の
   feature branch を削除する。**push に失敗したら feature branch を削除しない** —
   まだ載っていない成果を消すことになる。一時 integration ref は成否に関わらず
   片付けてよい。
7. **feature へ書き戻さない**: **コンフリクト解消の結果を feature branch へ
   push し返さない。** 解消は既定ブランチへ載せるためのもので、feature の
   歴史を書き換える理由にはならない。
8. **報告する**: 解決した既定ブランチ名、rebase の結果、解消したコンフリクトと
   その分類 (機械的 / 製品判断)、テスト結果、レビューの `verdict`、
   push の有無と対象、feature branch を削除したかを短く返す。
   task の state 更新も MCP 経由で行い、tracked file に log を残さない。

## 製品判断の境界

コンフリクトには 2 種類ある。この線引きが rebase の中核である。

- **機械的な衝突は子 agent が吸収してよい**: import 順、行の重複、
  隣接行の並び、生成物の再生成、両方を残せば足りる追加同士 —
  どちらを採っても製品の振る舞いが変わらないもの。
- **2 つの機能が本当に両立せず、どちらを採るかが製品判断になる衝突は、既定ブランチを触らず、task を user 判断待ちの state へ戻す。**
  **agent が勝手に片方を採用しない。**

判定は「どちらを選んでも user から見える結果が同じか」で行う。
同じなら機械的、変わるなら製品判断である。迷ったら製品判断として扱い、
user へ返す — 誤って止めるコストは、誤って片方の機能を消すコストより遥かに
小さい。

user へ返すときは、衝突した 2 つが何をしようとしていたか、両立しない理由、
選択肢とそれぞれの帰結を receipt に書く。既定ブランチは触らないまま残す。

## 不変条件

- **元の feature ref は更新しない**
- 緑かつ pass のときだけ、**force なしで** push する。force push は一切しない
- **push に失敗したら feature branch を削除しない**
- コンフリクト解消の結果を feature branch へ push し返さない
- 既定ブランチ名を決め打ちしない。remote HEAD から解決する
- **製品判断になる衝突は、既定ブランチを触らず、task を user 判断待ちの state へ戻す**
- **自分の push を授権することになる task を自分で作らない**
- HTTP API の直叩き、データベースファイルへの直接書き込みはしない
- 判断履歴・TODO・plan・review log を tracked file に残さない
- secret・`.env` をコミットしない
- 破壊的 git 操作で他人の作業を巻き込まない。無関係な作業中変更を保護する
