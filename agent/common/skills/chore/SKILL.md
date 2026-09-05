---
name: chore
description: 約50行以内の小さなファイル修正を自分で実装・検証・レビューし、local commit まで届ける。大きな変更は deliver へ渡す。
---

# chore

着手前の手書き差分見積もり（追加＋削除）が約50行を超えるなら `deliver` へ持ち替える。
小さな変更では knowledge の共通・project index を読み、自分で編集して必要な検証を行う。

[共通契約の独立レビュー](../deliver/CONTRACT.md#独立レビュー) に従い、目的・差分・検証結果を渡す:

```bash
review "$repo" --kind implementation --result "$result" < "$prompt"
```

有効な指摘を直し、`--kind recheck` で再確認する。修正が広がったら `deliver` へ持ち替えて続ける。
実行障害は共通契約の fallback に従う。未解消 blocking を pass と扱わない。
完了した自分の差分を `git` skill で local commit し、成果と検証・レビュー状態を短く報告する。
この skill だけで push・merge・deploy・release は授権しない。
