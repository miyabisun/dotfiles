---
name: orca-material
description: >-
  OrcaServerでフィラメント製品の共通設定、色、AMSへの材料割当・使用順を操作する。
  「同じ製品へ黄を追加」「ノズル温度を変更」「このslotへ割当」などの依頼で使う。
---

# 製品・色・AMSを操作する

OrcaServer MCPを使う。未接続なら[接続手順](../../../orca-mcp.md)を読む。
引数は接続先のtool schema、詳細は[OrcaServerのMCPガイド](https://github.com/miyabi-sunny-side/orca-server/blob/main/docs/mcp.md)で確認する。
会話と`filament_products/product`で対象製品を特定し、必要な操作だけ行う。
製品ID、色ID、設定ID、実機ID、slot IDを取り違えない。

| 依頼 | 読取りと書込み |
| --- | --- |
| 同じ製品へ黄を追加 | 対象製品の色を確認し、未登録なら`filament_color_save`へ`product_id`と`data:{name:"黄",color:"FFFF00FF"}`を渡す。指定済みRGBAがあればその値を使う。共通設定は複製しない。 |
| 共通ノズル温度を218℃へ | 製品の機種別設定を読み、互換候補を`filament_profiles`で確認する。`filament_setting_save`へ既存設定ID、機種・基本profile、既存overridesを保持して変更した温度を送る。全色に反映する。 |
| このAMS slotへ黄を割当 | `printers`と`ams_get`で実機・slot・現在revisionを読み、`ams_assign`へ黄の色IDを送る。解除の依頼なら`filament_id:null`を明示する。 |
| この材料の開始slotを優先 | 依頼された場合だけ`ams_get/resolve`で候補を読み、`ams_prioritize`へ現在の同一材料グループ全件のID・revisionを希望順で送る。 |

温度の更新は全置換なので、依頼されていない差分値を落とさない。
複数の製品・機種・slotが該当する場合は、会話で解決しない指定だけ確認する。
授権済みの可逆操作に毎回確認を追加しない。
保存後は`filament_product`または`ams_get/resolve`で結果を確認する。
AMSの台帳上の割当を、実物の装填変更や印刷中の自動補充順の変更と報告しない。

入力拒否は未保存、通信断・timeoutは結果不明として区別する。
不明時は対象を読み直し、保存済みの色・設定を重複作成しない。
古いrevisionは最新の観測を読み直し、slotの内容が変わっていたら依頼との対応を確認する。
