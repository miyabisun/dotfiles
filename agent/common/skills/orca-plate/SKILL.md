---
name: orca-plate
description: >-
  会話中の公開済みSCADモデルをOrcaServerのプレートへ保存・更新し、管理画面リンクを返す。
  「このモデルを10個で保存」などの依頼で使う。SCAD制作や印刷開始だけの依頼には使わない。
---

# 公開モデルをプレートへ保存する

OrcaServer MCPを使う。未接続なら[接続手順](../../../orca-mcp.md)を読む。
引数は接続先のtool schema、詳細は[OrcaServerのMCPガイド](https://github.com/miyabi-sunny-side/orca-server/blob/main/docs/mcp.md)で確認する。
モデル制作・STL公開は、その作業の既存経路で完了させる。

1. 会話の成果と`scad_models`の公開キーを照合する。ローカルパスを公開キーとみなさない。
   複数候補なら識別に足りない指定だけ確認する。未公開なら、公開できてから保存へ戻る。
2. 要求された名前・数量・条件を組み立てる。名前の指定がなければモデル名から付ける。
   既存プレートの更新は`plate_get`で現在の版・全構成を読む。
3. 明示された条件だけ、`plate_options`の所持機候補と材料の読取り結果へ照合する。
   機種・ノズルは`required_machine_profile_key`、材料は色の`filament_id`へ保存する。
   工程・品質は`process_profile_key`、ビルドプレートは`bed_type`を使う。
   実機IDを機種profileへ入れない。材料操作は[orca-material](../orca-material/SKILL.md)。
4. `plate_save`を呼ぶ。新規は`id`を省略し、未指定条件はNULLにする。
   更新は外側の`id`、`plate.version`、既存モデルIDを保持し、全モデル・全条件を送る。
   指示されていない既存条件を消さない。機種をNULLへ戻す場合は工程もNULLにする。
5. `plate_get`で名前・個数・4条件を確認し、接続先originに`ui_path`を付けたリンクを返す。
   保存成功と印刷可能を分ける。追加可否を求められたら`printers`で対象実機を特定し、
   `plate_admission`の結果と理由を返す。

「このモデルを10個のプレートとして保存」なら、検索結果のキーを使う。
`plate.models`の1行を`{name: キー, source: キー, quantity: 10}`とする。
未指定の材料・機種・工程・bedを候補のdefaultsから補わない。モデルだけの保存も有効。
AMS slotは自動選択なので、この操作のために質問しない。
保存依頼でキュー追加や印刷開始まで行わず、授権済みの保存に再確認も挟まない。

入力拒否は未保存、通信断・timeoutは結果不明として区別する。
結果不明なら`plate_list/get`で名前・構成・条件を照合し、重複作成を避ける。
更新競合は最新状態を読み、今回の変更だけを反映し直す。競合する利用者の選択は確認する。
