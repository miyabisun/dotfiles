# 0004: harden を出荷ゲートにし、入口を user のリリース号令だけにする

## 要約

harden への入口は **user のリリース号令ただ1つ**になった (明示的な `$harden`
起動はこの号令と同値)。decision 0003 が持っていたもう1つの gate —
project の version が既に 1.0.0 以上なら harden — は**廃止**。version 値は
どの段階も強制しない。段階は作業の性質と user の判断だけで決まる:
体験づくり = spike、不満直し = polish (全 version)、出荷 = harden。

- user から見た変化: v1.0.0 後も日常の改善は polish の軽さで進み、
  厳格さは「出荷の瞬間」と「危険な場所に触れた時の進言」に集約される
- user がいま決める必要があること: 無い
- 次の一歩: v1.0.0 到達プロダクトの改善を polish で回し、最初のリリース
  号令で harden の出荷ゲートを実走させる

## Decision

1. **harden の入口はリリース号令のみ。** 「リリースして v1.0.0 にしたい」等、
   出荷ゲートの実行を明示した user の命令だけが harden を起動する。明示的な
   `$harden` 起動は号令と同値。文中に "release" が現れるだけの文は号令では
   ない。version 値・リスク・成果物の重さからの推論で harden を選ばない。
2. **harden は出荷ゲート。** 検証対象は現在の task だけでなく、**前回の
   harden 検証点から現在の凍結 snapshot までの累積 diff**。検証点は commit
   message の `Harden-Verified: true` trailer で識別し、harden の delivery
   commit 自身が次回の baseline になる。trailer を持つ commit が1つも無い
   初回は、baseline を推定せず全 tracked product state を対象にする。
   harden は累積 diff の semver 推奨 (major / minor / patch) を根拠付きで
   必ず返す。version の書き換え・tag・release は従来どおり user の
   `bump-tag` だけが担う。
3. **大規模な再作成は spike のやり直し。** polish が bounded な修正で済まない
   全面的な作り直しを検出したら、部分実装・自動転送をせず、理由と `$spike`
   再依頼文を user へ返す。切り替えを決めるのは user。
4. **polish は全 version の成熟レーン。** v1.0.0 は卒業ではなく通過点。
   harden-review-sensitive な変更 (secret・credential / 認証・権限・信頼境界 /
   破壊的データ操作 / 公開 API 互換) は polish の内側で完遂しつつ、最終報告で
   「出荷判断の前に `$harden` での見直しを推奨」を必ず進言する (advisory。
   自動昇格・block はしない)。
5. **v1.0.0 以上での spike は互換性を宣言して続行。** 契約段階で既存の公開
   契約への互換性影響を判定し、破壊するなら「next major work:
   v<現 major+1>.0.0 系の作業」と receipt に明示する。spike は止まらず、
   version file も変更しない。

decision 0003 の Decision 2 (b)「version が既に 1.0.0 以上なら harden」と
「gate は依頼文の段階明示より優先される」条項は本 decision が supersede する。
0003 のその他 (自動昇格は polish まで、spike の v0.1.0 立ち上げ手順、
段階未指定 `$deliver` の spike/polish 自動判断) は変わらない。

## 非目標

- 自動昇格・自動段階転換の新設 (切り替えは常に user の明示)
- version manifest の変更・tag 作成・push・release (すべて user の権限)
- 第4の stage や新 role の追加

## Decision owner

user (下記原文)。条文化は claude。

## Authority evidence

user 原文 (settings セッション claude pane、2026-08-07):

> 整理します。
> - 大規模な再作成はspikeのやり直しとする -> これは良さそう
> - hardenへの昇格は「リリースしてv1.0.0にしたい」という号令のみにする

> なるほど、hardenは出荷する段階でガチガチに検証・検品を行い、必要があれば
> 修正を行う。
> harden(v1.0.0化)後も修正がある度にpolishは行う、v1.0.0後のプロダクトで
> polishでの作業中セキュリティを弄るみたいなセンシティブな場所への修正を
> 加えた場合、ユーザーにhardenで見直してもらうよう進言する
> こんな使い分けなら無理無く運用出来そうですかね？

> (v1.0.0 後の spike について) Nim言語とかを見るとやっぱりv1.0.0には特別な
> 思い入れがあるので、それをぶっ壊してしまうのはどうかなーと思うんですよね。
> まぁ、それをやったらv2.0.0が出来るんだよって話で良い気がしますが。

> この5点を開発系SKILLSに盛り込んでください。
