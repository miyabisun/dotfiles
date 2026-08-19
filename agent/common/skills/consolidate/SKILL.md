---
name: consolidate
description: >-
  本当に重複した概念と production のロジックを、振る舞い・互換性・performance
  を保ったまま明確な所有へ集約する。user が明示的に consolidate を起動したとき、
  または検証済みの local commit として届ける本格的な DRY 目的の refactor を
  求めたときにだけ使う。重複を inventory して分類し、見せかけの類似を退け、
  安全に移行し、結果を独立に検証する。push・deploy・release はしない。
---

# consolidate

振る舞いを保つ集約を、検証済みの local commit 1 個として配達する。
最適化の対象は変更の局所性と明確な所有であって、削除行数ではない。

明示的な `$consolidate` 起動は local commit を 1 個授権する。このファイルにある
inventory・review・formatter・親所有の commit の規則を適用する。追加の出荷段階を
発明したり、別の起動を要求したりしない。

## 入力

| 引数 | 必須 | 意味 |
|---|---|---|
| `target` | yes | 調査対象の subsystem・概念・パターン・重複 |
| `constraints` | no | 互換性・performance・階層・移行の制限 |

自由文だけが渡されたら `target` の意味になる。

## consolidated の定義

該当する成果をすべて満たすことを求める:

1. inventory が、具体的な重複箇所とその呼び出し元を特定している。
2. 各箇所が証拠付きで `merge`・`share-primitive`・`keep-separate` のいずれかに
   分類されている。
3. 統合した箇所が、同じドメイン概念・不変条件・変更理由を表している —
   単に構文が似ているだけではない。
4. 集約後の実装が、明確な所有者と依存方向を 1 つずつ持っている。
5. 古い production 経路と不要になった adapter が、安全なときに削除されている。
   shadow 実装がうっかり生きたまま残っていない。
6. 観測可能な振る舞い・公開互換性・エラー意味論・関連する performance が
   保たれている。依頼が明示的にそれらを変える場合を除く。
7. 新しい抽象化が、重複を flag・分岐・漏れのある generic 型・依存循環・雑多な
   utility の掃き溜めに置き換えていない。
8. 回帰テストと独立レビューが結果を証明している。

## 集約の inventory

この inventory を会話の receipt に記録する:

```json
{
  "inventory": [
    {
      "sites": ["path:symbol", "path:symbol"],
      "decision": "merge|share-primitive|keep-separate",
      "reason": "shared concept and change coupling, or reason to remain separate",
      "owner": "target module or package"
    }
  ],
  "baseline": ["behavior, API, performance, and dependency evidence"],
  "retired_paths": ["removed duplicate implementation"],
  "architecture_checks": ["dependency and ownership evidence"]
}
```

名前だけから inventory をでっち上げない。定義・呼び出し元・データフロー・
エラー・テスト・変更境界を追跡する。

## 1. 発見して分類する

意味的な兄弟を見つけられる広さで target を検索し、各候補を文脈の中で読む。
次を記録する:

- 公開・内部の呼び出し元;
- 入力・出力・副作用・エラー・順序・ライフサイクル;
- ドメインの不変条件と所有;
- テストと fixture;
- 依存方向と release/version の境界;
- performance に敏感な経路。

次の判定テストを使う:

```text
same concept
AND same invariants
AND same reasons to change
AND a natural owner exists
AND sharing reduces future coordinated edits
AND the shared API is simpler than the duplicates
```

これが成り立たなければ `share-primitive` か `keep-separate` を選ぶ。独立した
bounded context・プラットフォーム方針・ライフサイクルの違い・今たまたま似て
いるだけのコードをまたいで DRY を強制しない。

target が広い、または曖昧なときは `leader` を使って成果の範囲を絞る。既存の
カバレッジだけでは振る舞いが保たれることを独立に証明できないときは、
`strategist` と `strategy-rev` を使う。公開互換性や performance にリスクが
あるときも同じである。

## 2. baseline を確立する

production のロジックを変える前に:

1. 既存の focused な suite と authoritative な suite を実行する。
2. 保つ価値があるのに覆われていない振る舞いへ characterization test を足す。
3. 該当する場合は公開 API/schema の snapshot を記録する。
4. 代表的なエラーと edge case の振る舞いを記録する。
5. performance に敏感なコードについて benchmark か資源計測を記録する。
6. 既存の architecture tool か repository-native の query で、依存/階層の状態を
   採取する。

characterization test に、偶然そうなっている private な構造を焼き付けない。
baseline が既に失敗しているなら、元からある失敗と task が起こした失敗を分けて
示し、green な出発点だと主張しない。

## 3. 抽象化より先に所有を設計する

`merge` と決めた箇所ごとに、次を明示する:

- 正統な所有者と、それがその概念を所有する理由;
- 実際の consumer が必要とする最小で安定した API;
- 移行後の依存方向;
- 移行順序と削除時点;
- 互換性のための adapter。本当に必要なときだけ;
- consumer が振る舞いを保つことの証明。

次を持ち込む設計は退ける。boolean のモード引数・共有 core の中の consumer 固有の
分岐・曖昧な `utils` 所有・循環依存・呼び出し元より単純な語彙を持たない抽象化である。

## 4. 筋の通った slice 単位で移行する

最小で安全な手順を実装する:

1. 正統な実装を導入する、または選ぶ。
2. consumer を移行し、筋の通った slice ごとに対象を絞ったチェックを行う。
3. 退役した実装・死んだ adapter・不要になったテストを削除する。
4. 残った参照と並行する production 経路を検索する。
5. 該当する suite 全体と、architecture/performance のチェックを実行する。

一時的な adapter には、文書化された削除条件が必要である。互換性が許すかぎり、
同じ delivery の中で削除するのが望ましい。書き込みできる正を 2 つ残さない。

親は自分で実装してもよいし、範囲を区切った移行を `dev` へ委譲してもよい。
並列化してよいのは独立した consumer の群だけである。並列の agent に、正統な
所有者や共有 contract を同時に編集させない。

## 5. 集約を検証する

テキスト上の diff が小さくても、独立した `rev` を必ず立てる。元の target・
inventory・baseline・所有設計・退役した経路・完全な diff・実行したチェックを
渡す。次に答えさせる:

- `keep-separate` の箇所を誤って統合していないか?
- 所有者はドメインと依存方向に合っているか?
- 重複が flag・分岐・adapter・テストへ移っていないか?
- 1 つの振る舞い変更を、正となる 1 箇所で行えるようになったか?
- 古い production 経路は実際に到達不能か、削除されているか?
- 互換性・エラー・並行性・performance は保たれているか?

集約が境界をまたぐという理由で、止まったり追加の儀式を要求したりしない。
対象の境界は trust・auth・tenant・serialization・SQL・URL・filesystem・
command・secret・破壊的データである。この skill の中で続ける。止まるのは、
第三者に害を与えるとき、または犯罪に見えるときだけである。

修正のあとは、影響を受ける characterization/全体のチェックを回し直し、退役経路の
検索をもう一度点検する。所有や API の実質的な再設計には、新しい全体 `rev` が要る。
指摘リストだけの修正は、締めに `inspector` を使ってよい。

## 6. commit して報告する

レビューが通ったら、親が該当する repo-native の formatter/linter を実行し、
この構造化 receipt を会話に記録する (1 行の要約ではなく):

```json
{
  "approved": true,
  "applicability": "checked|not_applicable",
  "requested_files": ["path"],
  "formatter_added_files": [],
  "check": "pass|n/a",
  "reason": ""
}
```

この親が計測した receipt が formatter receipt である。独立した formatter 役職は
要らない。影響を受ける first-party 実装 workspace の他所に出る機械的な formatter
の出力は、範囲の限られた maintenance である。集約を止める自動的な理由にはならない。

`committer` へ渡すのは、その構造化 receipt であって親の要約ではない。
`committer` を起動するのは、その receipt と集約の全条件が通ったあとだけである。
要求したファイル、開示した maintenance ファイル、明示的な `$consolidate` の授権を渡す。
その承認済み staging receipt を受けたら、親所有の commit 手順に従う。staged ファイルと cached diff を receipt と突き合わせて検証する。提案された message をそのまま使い、親の文脈でちょうど 1 個の local Conventional Commit を作り、そのあと検証する。
push しない。

会話の receipt を次で拡張する:

```json
{
  "consolidated": true,
  "decisions": [{"sites": [], "decision": "merge", "owner": "...", "reason": "..."}],
  "retired_paths": [],
  "preservation_evidence": [],
  "architecture_evidence": [],
  "formatter": {"result": "approved", "applicability": "checked|not_applicable"},
  "commit": "<hash> <subject>"
}
```

調査の結果、健全な集約が見つからなければ、見た目だけの変更をしたり空の refactor
を commit したりしない。inventory と、実装を分けたままにする証拠を添えて
`consolidated=false` を返す。
