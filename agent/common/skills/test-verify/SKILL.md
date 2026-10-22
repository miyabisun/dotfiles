---
name: test-verify
description: >-
  新規・変更コードのTDD、既存テストの選択、build/lintとcommit前の実検証を行うときに使う。Markdownは既存の形式検査と内容確認で検証する。
---

# 変更に必要な検証を行う

入力は変更する挙動、関連実装・呼出し元、knowledgeの共有テスト戦略、repoの検証設定。
仕様と成功条件が分かったら実装前から使い、テストコマンドはrepoが所有するものを選ぶ。

- 新規・変更する副作用のない処理はすべて、期待する挙動のテスト → 意図した失敗 → 最小実装 → 整理の順に進める。
  既存挙動を保つ整理は既存テストを再利用し、未検証の挙動だけ先に補う。
- 判断・計算を副作用から分ける。stubや一時directoryで隔離できるコードは結果を観測する。
  実際の起動・外部への作用は必要な範囲で実行して確かめ、mockの保証範囲を広げない。
- Markdownの字面、ライブラリの仕様、常に真の比較をテストしない。
  Markdownのみなら既存の形式lint/validatorと参照・内容の確認を行う。
- commitの前に、対象repoのformatterの検査（書き換えない検査モード）とlinterを、テストと同じ実行で通す。
  repoが一括の検証コマンド（`npm run verify` など）を持てばそれを使う。無ければ言語標準の検査をテストと連ねる。
  Rustなら `cargo fmt --check` と `cargo clippy --all-targets -- -D warnings` である。
  linterとformatterで確かめていない差分をcommitしない。CIやpush後の検査に任せない。buildも通す。
- UI実測はWebならfrontend-design、Androidならandroid-ui-checkへ渡す。

対象repoで `agent-test run -- <formatterの検査・linter・テストを含む既存コマンドと引数>` を実行する。
stage・検証・commitは別コマンドにし、検証後に編集したら影響範囲を再検証する。
空の成功コマンドで代用せず、必須検証とhookを迂回しない。各repoへのGit hook配布はしない。
赤状態の途中作業は許すが、未通過でcommit・完了にしない。中断報告なら `agent-test pause` を使う。
これはcommitの許可ではなく、hookはTDDの順序や網羅性も証明しない。

出力は実行コマンド、結果、対象差分/版、mock境界、未確認と実際の障害。
必要な検証が通ったら、[change-review](../change-review/SKILL.md)とgitによる配達へ渡す。
新しい差分・失敗・未解決懸念がなければ検証を際限なく広げない。
