---
name: working
description: >-
  task-server が発行した task を 1 件だけ受け取って片付ける薄い worker。
  instant task を優先して claim し、worktree と feature branch を切り、
  修正そのものは $deliver へ、merge は merge へ、release は bump-tag へ渡す。
  delivery が成功した feature branch にだけ push する。繰り返しは /loop が
  供給するので、この skill 自身はループしない。
disable-model-invocation: true
---

# working

user が管理画面のボタンを押すと、task-server が **インスタントタスク**を
発行する。worker はそれを巡回して claim し、実行する。task は Issue と違って
一撃で終わらず、複数の state を経由する — working はその一巡ぶんだけを担う
**薄い worker** である。

判断・実装のどちらも、この skill はほとんど持たない。持っているのは
「どの task を取るか」「どこで作業するか」「どの skill へ渡すか」
「結果をどの state へ戻すか」の 4 つだけである。中身の品質は渡した先の契約
(`$deliver` = `spike` / `polish`、`merge`、`bump-tag`) が保証する。

## 起動条件

user の明示的な `/working` 起動、または user が回す `/loop /working` の各周が
起動根拠である。**1 invocation = 最大 1 task**。task が無ければ何もせず
その旨だけ返して終わる。

**この skill 自身はループしない。** 繰り返しは `/loop` が供給する。
残 task を追いかけて 2 件目へ進んだり、次の周を待って turn を保持したりしない
(sleep・wait loop で turn を保持しない)。1 件片付いたら報告して turn を終える。

## MCP schema について

task の取得・状態遷移は **task-server が提供する MCP tool** を通して行う。
本書は「こう動くべき」という契約であって、実際の tool 名・field 名・state 名は
**まだ確定していない**。ここで具体的な tool 名を名乗ってはならず、確定していない
名前を推測で呼び出してもいけない。**schema が確定したら実際の tool 名へ結線する**
— そのときも本書の手順と授権境界は変えない。

現時点で未確定なものを呼ぶ必要が出たら、呼べないことをそのまま報告して止まる。
迂回してはならない: **HTTP API の直叩き、データベースファイルへの直接書き込みは
しない**。

## 手順

1. **task を 1 件だけ取る**: task-server の MCP tool で待ち行列を見る。
   **instant task (merge / release など system が発行したもの) は通常 task より
   優先して claim する**。同種が複数あるなら 1 件だけ選ぶ。
   ここで取れなければ以降の手順は全て行わない。
2. **claim する前に副作用を起こさない**。一覧を見る段階では、worktree も branch も
   作らず、**`git fetch` を含めて git 操作を一切せず**、ファイルも書かない。
   `git fetch` は remote-tracking ref と `FETCH_HEAD` を書き換える副作用であって、
   例外ではない。claim できて初めて作業を始める。
3. **task と現在地を照合する**: claim 後、task が名指しする repository・branch・
   操作を、実際の作業対象と突き合わせる。**食い違ったら実行しない**。その場合は
   worktree を作る前に、task を適切な state (再割り当て待ち・user 判断待ち等)
   へ戻し、食い違いの内容を報告して終える。ここを飛ばすと、名指しされていない
   repository へ push する事故が起きる。
4. **作業場所を作る** (通常の修正 task のみ): 照合を通ってはじめて git を触る。
   `~/projects/<org>/<repo>` を起点に **`git fetch` で origin を最新化してから**
   **git worktree** を作り、task id 由来の feature/fix branch を切る
   (例 `fix/<task-id>-<slug>`)。**1 task = 1 worktree = 1 branch**。
   既存の worktree を使い回さない。既定ブランチの上で直接作業しない。
5. **中身は `$deliver` へ渡す**: 修正そのものは **`$deliver` を間接利用する**。
   spike / polish の契約・TDD・レビューはそのまま働く — working がそれを
   薄めたり省いたりしない。**task 本文は verbatim で渡す**
   (要約・言い換えをしない)。`$deliver` は **local commit まで**を担う。
   dispatch 先が分岐する task は次へ渡す:
   - **merge task** → `merge` skill
   - **release task** → `bump-tag` skill。task が水準
     (`auto` / `major` / `minor` / `patch` / `first`) を指定していたら
     **それをそのまま渡す**。**勝手に `auto` へ置き換えない。**
   - **dispatch が失敗したら代行しない**: 理由を問わず `bump-tag` の dispatch が
     失敗したとき (runtime の拒否・skill 不在・起動エラーなど) は、
     **release を自力で代行しない** — tag を打つ、push する、version file を
     書き換えるといった手順を手作業で真似ない。
     task を **user の実行待ち**に相当する state へ戻し、
     dispatch が失敗した理由と user 自身の起動が要る旨を報告して終える。
6. **成功した feature branch にだけ push する**: `$deliver` が
   local commit まで到達したときが delivery の成功である。そのときだけ、
   その feature branch へ push する。
   - **force push はしない。**
   - **共有ブランチへは push しない。** 既定ブランチへ載せるのは `merge` の
     仕事であって working の仕事ではない。
   - delivery が失敗・中断したなら push しない。commit の無い branch を
     push で取り繕わない。
7. **結果を state へ戻す**: 完了・失敗・部分成功のいずれも、MCP が提供する
   適切な state へ記録する。**失敗を close 扱いにしない** —
   失敗は失敗の state、判断が要るものは user 判断待ちの state へ返す。
   **tracked file に log を残さない**。
   経緯は receipt と task の state が持つ。
8. **報告する**: 取った task、dispatch 先、作った branch、push の有無と対象、
   戻した state を短く返す。取る task が無かった周も、その 1 行だけ返す。

## push の授権

push はこの skill が自前で持つ権限ではない。**user が発行した task が号令を
運ぶ** — ただし **task が名指しする repository・branch・操作に限り、その task を
保持している間に限る**。授権は task の終了とともに失効する。

- 手順 3 の照合を通っていない push は、授権の外である。
- task を戻したあと、あるいは失効後に push しない。
- **自分の push を授権することになる task を自分で作らない。**
  task を発行するのは user の管理画面であって worker ではない。
- task-server へは MCP でだけ触る。**HTTP API の直叩き、データベースファイルへの
  直接書き込みはしない**。

## 不変条件

- **1 invocation = 最大 1 task**。この skill 自身はループしない
- **claim する前に副作用を起こさない**
- **自分の push を授権することになる task を自分で作らない**
- **HTTP API の直叩き、データベースファイルへの直接書き込みはしない**
- force push しない。共有ブランチへ push しない
- 失敗を close 扱いにしない。判断が要るものは user へ返す
- 判断履歴・TODO・plan・log を tracked file に残さない
- secret・`.env` をコミットしない。task 本文へ秘密を書き戻さない
- 無関係な作業中変更を保護する。破壊的 git 操作
  (checkout/restore/reset/clean/stash) で作業を管理しない
