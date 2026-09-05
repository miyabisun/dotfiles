---
name: merge
description: >-
  feature branch を既定ブランチへ統合する入口。remote HEAD から既定ブランチを
  解決し、fast-forward できるならテストもレビューもなしでそのまま前進させて
  force なしで push し、統合できた feature branch を local と remote から速やかに
  削除する。遅れ・分岐があるときだけ `rebase` で載せ直してから ff する。
  複数本渡されたら 1 本ずつ最後まで直列に回す。
---

# merge

「マージして」と言われたときの入口。**fast-forward できるなら、それは既定
ブランチを feature の HEAD まで進めるだけの操作である。** 検証フローは要らない。
統合が済んだ feature branch は速やかに削除する。

## 手順

1. **origin を最新化し、既定ブランチを解決する**: `git fetch` (必要なら
   `--prune`)。既定ブランチ名は **remote HEAD から解決する** —
   `git symbolic-ref refs/remotes/origin/HEAD` など remote が申告する値を使い、
   `master` や `main` と決め打ちしない。解決できなければ推測せず報告して止まる。
2. **fast-forward できるか見る**:
   `git merge-base --is-ancestor origin/<default> <feature>` が真なら、既定
   ブランチは feature の祖先である。**既定ブランチを feature の HEAD まで
   `--ff-only` で前進させ、force なしで push する。テストも子 agent も
   レビューも行わない。**
3. **偽なら先に載せ直す**: 歴史が分岐しているか feature が遅れている。
   `rebase` skill で feature を `origin/<default>` の上へ載せ直し、戻ってから
   手順 2 の ff で統合する。持ち替えたことを 1 行伝えるだけでよく、追加の確認は
   求めない。
4. **push が成功したら feature branch を速やかに削除する**: local は
   `git branch -d <feature>`、remote は **`git push origin --delete <feature>`**。
   featureが専用worktreeでcheckout中なら、使用していたagentの終了とcleanなことを
   確認し、そのworktreeを `git worktree remove <path>` で外してからbranchを削除する。
   未保存の変更や他者が使用中のworktreeは削除せず、統合成功とcleanup残件を分けて報告する。
   削除済み remote branch の remote-tracking ref を掃除するのは
   **`git fetch --prune`** (または `git remote prune origin`) で、こちらは手元の
   残骸を捨てるだけで remote の branch は消さない。**この 2 つは別の操作である。**
   push に失敗したなら削除しない。

## 複数の feature branch

2 本以上渡されたら **1 本ずつ直列に回す**。1 本統合するたびに既定ブランチは進むので、
次の 1 本は**その時点の最新**を基準に手順 2 で判定し直す。**途中で号令を待たず、
最後の 1 本まで進める。**

feature A と feature B を渡されたときの流れ:

1. A を ff で統合して push (手順 2)
2. A を local と remote から削除 (手順 4)
3. B は進んだ既定ブランチより遅れている → `rebase` で載せ直す (手順 3)
4. B を ff で統合して push
5. B を local と remote から削除

3 本目以降も同じ 1 周を繰り返すだけである。

fetch のあとに remote が進んでいると、push が非 fast-forward で弾かれることが
ある。**それは手順 1 からやり直す話であって、重い検証の失敗ではない。**
