---
name: knowledge-deposit
description: >-
  再利用する設計判断・共有戦略・教訓を外部knowledgeへ追加・更新し、形式lintと
  担当の内容確認を経て自分の差分をlocal commitする。記録の依頼や、開発で
  持続的な知識が得られたときに使う。
---

# knowledge-deposit

今回限りの進捗は作業報告へ、別のagentが再利用する知識はknowledgeへ置く。
場所と対象は `knowledge-read` で解決し、既読ならその結果を使う。

- 関連indexと既存entryを確認する。project固有なら `projects/<org>/<repo>/`、
  横断なら `library/`、分類が未定なら `inbox/` に直接追加・更新する。
  同じ知識を重ねず、到達に必要なindexだけ追従する。inboxへの二重保存は不要。
- 一次sourceで確かめた事実、userの決定、agentの推論を分け、出典と日付を残す。
  userの決定は中立文と帰属で書き、逐語・秘密・非公開host・runtime座標を保存しない。
- 形式規範はknowledgeの `library/okf/spec.md`、機械検査は既存の
  `scripts/lint --enforce-scope <今回のpath>...` を使う。規則やschemaを作り直さない。
  lintは既知形式しか検出しないため、担当が秘密の混入、内容、出典、重複、参照を確認する。
- 通常更新はこのlintと担当確認で完了する。開発に伴う独立レビューが必要なら
  `deliver/CONTRACT.md` の所有者が関連差分を一緒に扱い、投入だけのレビューを重ねない。
  指摘を新しい承認権限にせず、無関係な既存文書まで修正を広げない。
- `git` skillで自分のpath/hunkだけをstageし、commit対象を確認してlocal commitする。
  他者のstaged差分が別pathなら `git commit --only -- <自分のpath>...` で分離できる。
  この方法は指定pathの作業ツリー全体を含むため、同一pathの他者差分には使わない。
  その場合はhunkを分離できる作業場所を用意し、他者のindexをresetしない。
  hookはindexを検査するので、修正後はcommit対象へ反映する。

lintや保存が失敗したら原因を直し、影響する確認だけをやり直す。
解消できない場合も自分の修正版を作業場所に保ち、理由・保存先・残件と再開条件を短く報告する。
証拠と一時資料はrepo外へ置き、失敗を理由に知識をproject側へ複製しない。
後続のpush・統合等が依頼済みなら対応skillで続け、既存の授権を聞き直さない。
