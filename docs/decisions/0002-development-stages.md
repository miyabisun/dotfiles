# 0002: 開発段階別スキルへの deliver 分割 (spike / polish / harden)

## 要約

deliver を開発段階別の3スキルに分割した。**`spike`**(黎明期: ゲート全省略で
最短の動作体験)、**`polish`**(ブラッシュアップ: 隣接チェック+レビュー1回)、
**`harden`**(リリース水準: 旧 deliver のフルパイプラインを逐語承継)。
`deliver` は互換ディスパッチャとして残り、**段階未指定の `$deliver` は従来と
同じ保証の harden として実行される**(暗黙の保証降格なし)。

- 作られるもの: スキル3つ + ディスパッチャ + 本記録
- 消えるもの: なし(旧 deliver の保証は harden が全承継)
- user から見た変化: `$spike` / `$polish` で軽いゲートを明示選択できる。
  `$deliver` の挙動は不変
- user がいま決める必要があること: 無い
- 次の一歩: 実運用で不満が出た箇所を polish で叩き直す

## Decision

deliver のフルパイプラインを `harden` へ canonical path として移し、軽量段階
`spike` / `polish` を新設、`deliver` をディスパッチャ化する。実行契約参照
(テスト4本・consolidate・committer) は harden へ移行する。

## Decision owner

- 3分割・段階定義・全権委任・commit までの完遂: user(下記原文)
- 名称 (spike/polish/harden)・ディスパッチ既定・昇格トリガー・commit 授権境界:
  claude(user の全権委任に基づく実装判断、counterpart 反証を統合)

## Authority evidence

一次根拠は user の /discuss 起動文(settings セッション claude pane、
2026-08-02):

> そもそも、開発のサイクルっていくつか段階があると思うんですよ。
> 1. 黎明期、まず動かして画期的な体験を得る
> 2. ブラッシュアップ、出てきた不満点を叩き直す
> 3. リリース、強固かつ複数視点のセキュリティ・堅牢性を担保
> (中略)
> 従って、deliverを3つのスキルに分割しましょう。
> それぞれのステップについてふさわしいと思う名前を考え、スキル・agentの実装を
> 行ってください。
> 別に後から不満が出たらブラッシュアップすれば良いので、貴方に今回の全権を
> 預けます。コミットするまで頑張ってください。

リスク受容の原文(同上):

> ぶっちゃけ自宅の閉じたLAN内で開発する分に、もしagentが暴走して他のagent
> 乗っ取ったらどうしよう！？なんて考える必要はありません。

## Authorized effects

Allowed:

- スキル新設 (spike/polish/harden)、deliver のディスパッチャ化
- 実行契約参照の移行: test/deliver-*.bash 4本、test/docs-role-contract.bash、
  consolidate/SKILL.md、agents/committer.md
- 本決定記録の作成と、以上を含む local commit 1つ

Forbidden:

- push・deploy・release
- 段階未指定 `$deliver` の保証を弱める変更
- 保護対象の変更: agent/claude/settings.json、discuss/SKILL.md の未コミット
  保護 hunk 2つ、tmuxinator 除去一式、docs/decisions/0001

## Supersedes / updates

- `agent/common/skills/deliver/SKILL.md`: agent-origin (user 採用済) /
  binding instruction。全文をディスパッチャへ置換。旧本文は harden が承継
- `agent/common/skills/consolidate/SKILL.md`・`agent/common/agents/committer.md`
  ・テスト5本: agent-origin / implementation artifact。参照先の
  exact-conformance 移行のみ(意味変更なし)
- `discuss/SKILL.md` の「deliver から呼ばれる場合」等の deliver 語彙: 保護
  hunk と同居のため今回不編集。dispatcher 既定 harden により意味は保たれる。
  用語追従は将来の polish 課題

## Rejected alternatives

- deliver 本文を残し tier 分岐を内蔵する案: 1スキルに3契約が同居し、user の
  「分割しましょう」に反するため却下
- deliver の完全削除: consolidate・テスト・既存の呼び出し習慣を壊すため却下
  (ディスパッチャ残置を採用)
- 変更の性質から spike/polish を自動選択する案: 既存 `$deliver` の保証を
  黙って弱める backward compatibility 違反のため却下 (counterpart 異議2)
- 閉域 LAN 受容を spike/polish の全 security 省略根拠へ一般化する案: user
  原文の受容範囲 (lateral agent takeover) を超えるため却下 (counterpart
  異議3)。secret・権限境界・破壊的データ・外部公開は harden へ強制昇格
- spike の無制限複数 commit: 授権が無境界になるため却下 (counterpart 異議4)。
  既定 1 invocation = 1 commit、複数は起動文の明示許可時のみ

## Non-goals

- 各 agent 定義 (dev/rev/sec 等) の deliver 語彙の全面改稿
- discuss/SKILL.md の編集 (保護 hunk 同居のため)
- GLOBAL ルール・home-development-rules の変更
- 新規 agent の追加 (harden が既存 agent 群をそのまま使用)

## Premises

- 段階未指定 `$deliver` = harden の既定が維持される。降格の既定変更は別途の
  明示的 user decision を要する
- harden は旧 deliver 本文の逐語承継であり、テストの文言 assert は harden 上
  で成立する。崩れたらテストが検出する
- 閉域 LAN 受容は lateral agent takeover に限定される。受容範囲の拡大は user
  の新たな明示だけが行える

## Reopen triggers

- 権限範囲外の変更が必要になった
- 上記 Premises が偽と判明した
- 昇格トリガー列挙が実運用で不足・過剰と判明した (polish で改訂)

## Verification

Mandatory (全て実施済み):

- test/*.bash 全14本 PASS (deliver 系4本は harden 参照へ移行後に PASS)
- consolidate・committer・テストに残る旧参照 grep ゼロ
- 保護対象の不変を git status で確認

Optional: スキル説明文の trigger 品質 (実運用で評価)

## Readiness

| Gate | 判定 | 根拠 |
|---|---|---|
| A. Authority closure | PASS (著者judgment) | user 全権委任原文 + 受容範囲の限定記録 |
| B. Conflict closure | PASS (著者judgment) | 実行契約参照を全て移行、テストで検証。discuss は不編集で dispatcher 既定により非競合 |
| C. Product closure | PASS (著者judgment) | 3段階・名称・既定・昇格トリガー・却下案を記録 |
| D. Risk closure | PASS (著者judgment) | 受容 risk は user-origin で範囲限定、未受容脅威は強制昇格が所有 |
| E. Verification closure | PASS (著者judgment) | テスト14本 + grep、実施済み |
| F. Independent executability | PASS (著者judgment) | 本記録とリポジトリのみで変更対象・非目標・検証・権限を復元可能 |

独立レビュアー (codex %25, broker #988) の実判定: **conditional** —
「default action を適用するなら、少なくとも objection 1〜3 を閉じてから実装へ
進む必要がある」。異議4件 (実行契約参照の移行必須 / 既定 harden / 受容範囲の
限定 / commit 授権の有界化) は**全て採用して実装に反映済み**。discuss の規定
(最大1往復) により再判定照会は行わず、反映内容は上記 Rejected alternatives と
Verification に記録した。
