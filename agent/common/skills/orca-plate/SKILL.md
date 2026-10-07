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
3. プレートは何を作るか（モデル×個数・材料・仕上がり・開始オプション）だけを持つ。
   機種・ノズル・工程・ビルドプレートはプリンターが持ち、`plate_save`へ送ると入力エラーになる。
   材料は色IDを`filament_id`・`secondary_filament_id`・`support_interface_filament_id`へ入れる。
   色IDは`filaments_search`で引き、製品IDと混同しない。材料操作は[orca-material](../orca-material/SKILL.md)。
   仕上がりはインフィル（`sparse_infill_pattern`・`sparse_infill_density`）、壁（`wall_loops`）、
   `brim_enabled`・`support_enabled`に入れる。開始オプションは`start_options`へ入れる。
   どれも明示された値だけ入れる。
   重い物を支えるパーツなど強度が要ると示されたら、そのプレートの`wall_loops`だけを増やす。
   材料や新規作成の初期値は変えない。壁数の指定がなければその数だけ確認する。
4. `plate_save`を呼ぶ。新規は`id`を省略し、未指定の材料・インフィル・壁はnullにすると
   サーバーが保存済みの初期値とAMS材料を当てる。ブリム・サポートは省略でOFFになる。
   更新は外側の`id`、`plate.version`、既存モデルIDを保持し、全モデル・全条件を送る。
   更新での省略・nullは解除になるので、指示されていない既存条件も`plate_get`の値で送る。
5. `plate_get`で名前・個数・条件を確認し、接続先originに`ui_path`を付けたリンクを返す。
   保存成功と印刷可能を分ける。所要時間は`plate_slice_get`の`printers`をプリンターごとに読む。
   `state`が`ready`なら`seconds`、`failed`なら`reason`（`unfit`は台に乗らない、
   `material_setting`はその機種の材料設定なし、nullなら`error`）、それ以外は計算中と、プリンター名の組で伝える。
   追加可否を求められたら`printers`で対象実機を特定し、`plate_admission`の結果と理由を返す。

「このモデルを10個のプレートとして保存」なら、検索結果のキーを使う。
`plate.models`の1行を`{name: キー, source: キー, quantity: 10}`とする。
条件を自分で補わない。モデルだけの保存も有効。
AMS slotは自動選択なので、この操作のために質問しない。
保存依頼でキュー追加や印刷開始まで行わず、授権済みの保存に再確認も挟まない。

入力拒否は未保存、通信断・timeoutは結果不明として区別する。
結果不明なら`plate_list/get`で名前・構成・条件を照合し、重複作成を避ける。
更新競合は最新状態を読み、今回の変更だけを反映し直す。競合する利用者の選択は確認する。
