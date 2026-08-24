---
name: working
description: >-
  task-server の task を 1 件だけ claim して片付ける薄い worker。中身は $deliver へ、
  merge は merge へ、release は bump-tag へ渡し、成功時だけ push して report する。
disable-model-invocation: true
---

# working

task-server の task を 1 巡ぶんだけ担う**薄い worker** である。判断・実装のどちらも
持たず、中身の品質は渡した先の契約 (`$deliver`、`merge`、`bump-tag`) が保証する。

## 起動条件

user の `/working` 起動と `/loop /working` の各周が起動根拠である。**1 invocation = 最大
1 task** — instant task を通常 task より優先して 1 件だけ claim する。**この skill 自身
はループしない**。繰り返しは `/loop` が供給する。残 task を追いかけず、sleep・wait loop
で turn を保持しない。

## 正本はどこにあるか

- **工程と所有者**: `$deliver` の `PROCESS.md` が正本。working は P1 (受領と照合)、
  P2 (複製)、P14 (push)、P15 (report)、P19 (receipt) だけを持ち、順序も同書に従う。
- **wire protocol**: tool 名・endpoint・state 名は task-server の README と schema へ
  委ね、書き写さない。**task-server が worker に公開している surface だけを使う**。

## 安全核

- **claim する前に副作用を起こさない**。worktree と branch を作らず、ファイルへ書き込まず、
  **`git fetch` を含めて git 操作を一切しない** (`git fetch` は remote-tracking ref と
  `FETCH_HEAD` を書き換える副作用であって例外ではない)。
- **task と現在地を照合する**。task が名指しする repository・branch・操作を突き合わせ、
  **食い違ったら実行しない** — worktree を作らず、理由と証拠を `outcome: "blocked"` の report で返す。
- **1 task = 1 worktree = 1 branch**。worktree を使い回さず、既定ブランチ上で作業しない。
- **task 本文は verbatim で `$deliver` へ渡す** (要約・言い換えをしない)。あわせて
  **pipeline 所有を宣言する**: 「この delivery は pipeline 経路であり、独立実装レビューは
  control plane の review 工程が所有する」。段階 skill はこれを推測せず、宣言が欠けたら
  安全側へ倒れて local でレビューする (control plane の review と重なるが 0 個よりよい)。
- **dispatch 先**は merge task → `merge`、release task → `bump-tag` (水準 `auto` /
  `major` / `minor` / `patch` / `first` の指定はそのまま渡し、勝手に `auto` へ換えない)。
  **dispatch が失敗しても代行しない** — tag・push・version file を手作業で真似ず、
  `outcome: "blocked"` の report に失敗の理由・証拠と、user 自身の起動が要る旨を書く。
- **結果は report の `outcome` で返す**。**失敗を close 扱いにしない** — 停止したなら
  理由と証拠を添えて返し、判断が要るものは user へ返す。review の発行・`approve`・
  merge の発行・state 遷移は control plane が所有する。

## push の授権

push はこの skill が自前で持つ権限ではない。**user が発行した task が号令を運ぶ** —
ただし **task が名指しする repository・branch・操作に限り、その task を保持している
間に限る**。授権は task の終了とともに失効し、照合を通っていない push、report を
返したあとや失効後の push は授権の外である。**自分の push を授権することになる task を
作らない。force push しない。共有ブランチへ push しない**。既定ブランチへ載せるのは
`merge` の仕事である。失敗・中断したなら push せず、commit の無い branch を取り繕わない。

## 不変条件

- 判断履歴・TODO・plan・log を tracked file に残さない
- secret・`.env` をコミットせず、task 本文へ秘密を書き戻さない
- DB ファイルへ直接書き込まない。control plane が所有する遷移を worker が書かない
- 無関係な作業中変更を保護し、破壊的 git 操作 (checkout/restore/reset/clean/stash) で
  作業を管理しない
