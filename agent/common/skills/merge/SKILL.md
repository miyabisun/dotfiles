---
name: merge
description: >-
  feature branch を既定ブランチへ載せる通常の入口。remote HEAD から既定ブランチを
  解決し、fast-forward できるならテストもレビューもなしでそのまま前進させて
  force なしで push する。分岐していて rebase が必要なときだけ `rebase` skill へ
  持ち替える。
---

# merge

「マージして」と言われたときの入口。**fast-forward できるなら、それは既定
ブランチを feature の HEAD まで進めるだけの操作である。** 検証フローは要らない。

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
3. **偽なら持ち替える**: 歴史が分岐している。`rebase` skill へ持ち替える。
   持ち替えたことを 1 行伝えるだけでよく、追加の確認は求めない。
4. **後片付けは push のあとだけ**: push が成功したあとにのみ、remote と local の
   feature branch を削除する。

fetch のあとに remote が進んでいると、push が非 fast-forward で弾かれることが
ある。**それは手順 1 からやり直す話であって、重い検証の失敗ではない。**
