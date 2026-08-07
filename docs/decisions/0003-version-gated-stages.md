# 0003: version でゲートする段階昇格と、spike/polish 自動判断への既定変更

> **Superseded (部分)**: Decision 2 の version gate (「version が既に 1.0.0
> 以上なら harden」) と「gate は依頼文の段階明示より優先される」条項は
> decision 0004 で廃止された。harden の入口は user のリリース号令のみ。
> その他の決定 (自動昇格は polish まで、spike の v0.1.0 立ち上げ、段階未指定
> `$deliver` の spike/polish 自動判断) は現行のまま。

## 要約

harden への入口は決定的 gate ただ1つになった:
user の「v1.0.0 にして**全世界に問いかける**」宣言
(明示的な `$harden` 起動はこの宣言と**同値**)、または
project の version が**既に 1.0.0 以上**であること。自動昇格は polish までで
止まり、spike は v0.1.0 のリリースを目指す段階として新規プロジェクトの
立ち上げ手順 (knowledge ヒアリング・rust-svelte-template・MIT) を持つ。段階
未指定の `$deliver` は gate 判定後、**spike / polish の自動判断** (宣言つき、
迷ったら polish) になった。

- user から見た変化: v0.x の開発が harden の重装備に阻まれなくなる。
  「リリースされ得るから harden」という却下は条文上不可能になった
- user がいま決める必要があること: 無い
- 次の一歩: pen v0.1.0 を spike で開発する

## Decision

1. spike の完了条件に「v0.1.0 のリリースを目指す」を追加 (リリース行為は
   user の `bump-tag` が担う)。新規プロジェクトは knowledge セクションへの
   共通開発仕様ヒアリング・rust-svelte-template 導入と不要物削除・MIT LICENSE
   から始める。
2. 昇格は version でゲートする: 自動昇格は polish まで。harden へ進むのは
   決定的 gate のみ — (a) user の v1.0.0 宣言 (明示的な `$harden` 起動は宣言と
   同値)、(b) project の version が既に 1.0.0 以上。gate は依頼文の段階明示
   より優先される。secret・権限境界・破壊的データは polish (レビュー1回+
   不変条件) で扱う。「将来リリースされ得る」は昇格理由にならない。
3. 段階未指定 `$deliver` の既定を harden から「gate 判定 → 非該当なら
   spike/polish 自動判断」へ変更。gate 非該当時に、リスクや成果物の重さからの
   推論で harden を選択することを禁止。

## Decision owner

user (下記原文)。条文化は claude。

## Authority evidence

user 原文 (settings セッション claude pane、2026-08-02):

> spikeスキルの完了条件に「v0.1.0のリリースを目指す」を入れ、チューニングを
> 施してください。
> - knowledgeセクションに共通開発仕様をヒアリングする
> - rust-svelte-templateを導入し、今回の要件として必要ないものを削る
>   - 例えばpen-cliであればclientディレクトリ配下や、DESIGN.mdを削除
>   - LISENCEは全てMIT バグ踏んでもv0.1.0だから文句言うなよの意味
> - v1.0.0の昇格はpolishで磨ききってからとする
>   - deliverを使う時は全世界にドヤりながら問いかける時のみ
>   - そんな日はまず来ないので、権限の昇格はpolishまでしか行わない
>   - 逆にRustのCargo.tomlを見て、これ既にv1.0.0やん、なんでspikeやねんって
>     なった時のみ昇格させる
> polish -> deliverへの昇格も同様です。私がv1.0.0にして全世界に問いかけようと
> 判断した後のみに変更してください。

同ターン内の追加指示 (dispatcher 既定変更):

> deliver初期状態も変更しましょうか。(中略) spikeとpolishを切り替えて自動判断
> するにとどめてください。

背景 (直接の契機): pen の spike 開発が「release artifact に触れるため harden へ
強制昇格」と却下された。「v0.1.0はhardenなんですか？v1.0.0を作る時だけですよね」
という user の指摘のとおり、旧トリガーの「外部公開・release artifact」が
「将来リリースされ得る成果物」まで拡大解釈可能だった。

## Supersedes / updates

- decision 0002 の次の2点を supersede する (0002 の Premises が予告した
  「別途の明示的 user decision」が本書):
  - 「secret・権限境界・破壊的データ・外部公開は spike/polish から harden へ
    強制昇格」→ 自動昇格は polish まで
  - 「段階未指定 `$deliver` = harden 既定」→ spike/polish 自動判断
- agent/common/skills/{spike,polish,deliver,harden}/SKILL.md:
  agent-origin (user 採用済) / binding instruction。本決定への整合更新
- test/spike-contract.bash・test/stage-escalation-contract.bash:
  implementation artifact。契約の静的検証

## Rejected alternatives

- 旧トリガー文言の部分修正 (「この作業の効果として外部に出るもののみ」) に
  留める案: user はより根本の「version ゲート」方針を明示したため、部分修正
  ではなく昇格モデル自体を置換
- harden の廃止: 将来の v1.0.0 宣言時と既存 1.0.0+ project のために維持

## Premises

- リリースの権限は `bump-tag` の明示起動が単独で担う (spike/polish は push
  しない)。これが崩れる場合は昇格モデルを再開する
- 閉域 LAN のリスク受容 (0002) の範囲は不変

## Verification

- bash test/spike-contract.bash / test/stage-escalation-contract.bash:
  旧トリガー文言の不在と新モデルの条文を静的検証 (red-first で作成)
- test/*.bash 全件 PASS

## Readiness

短縮判定 (polish 相当の変更): 独立レビュアー = counterpart (settings codex)。
レビュー結果は broker メッセージを参照。
