---
name: deliver
description: 開発依頼を spike / polish / refactor / slim へ振り分け、検証・レビュー・修正を経て local commit まで届ける。
---

# deliver

目的で振り分ける。明示指定を優先し、未指定なら次から選ぶ。

| 目的 | skill |
|---|---|
| 新しい体験・未稼働のものを動かす | [spike](../spike/SKILL.md) |
| 既存の不満・不具合を解消する | [polish](../polish/SKILL.md) |
| 外から見える挙動を保ち、実装の重複・不要な機構・複雑さを減らす | [refactor](../refactor/SKILL.md) |
| 現在の用途に照らして不要な機能・設定・責務・運用工程を取り除く | [slim](../slim/SKILL.md) |

不具合修正の手段がリファクタリングでも、目的は `polish`。迷ったら polish。
挙動維持の整理は `refactor`、仕様や責務の削減が目的なら `slim`。コード量だけで選ばない。
選んだ skill と [共通契約](CONTRACT.md)、そこから指定された参照を読む。
担当は成果まで引き受ける。分担とレビューの実施条件は共通契約に従う。
この skill は local commit までを授権する。依頼済みの後続工程は対応 skill で続ける。
外側が独立レビューを所有すると明示した場合だけ [PROCESS.md](PROCESS.md) を読む。
