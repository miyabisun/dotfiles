---
name: frontend-design
description: >-
  Project の design authority と interaction contract を保ったまま、
  production 水準の frontend UI を実装する。
  browser-rendered frontend sources (HTML, CSS, JavaScript, or Svelte)
  の編集が delivery に必要だと判断できたときだけ使う。
  CLI/TUI、terminal 専用ツール、Node backend 専用の JavaScript、native UI、
  config、docs、test だけの変更には使わない。拡張子だけでは足りない。
  その frontend sources の変更が必要だと確認できないなら、この skill を使わない。
---

# Frontend Design

確立された product と design の意図を、一貫した accessible な動作する UI へ
変える。Project が既に visual language を持っているなら、新しいものを発明しない。

## UI surface と authority

この skill を読み込むのは、browser-rendered frontend sources の編集が
delivery に必要だと判断できたときだけである。ここでいう source は HTML、CSS、
JavaScript、Svelte である。file の拡張子だけでは足りない。編集が browser
(または webview / Electron) の表示を形づくるものでなければならない。
CLI/TUI・terminal 専用ツール・Node backend 専用の JavaScript は対象外である。
native UI・config・docs・test だけの変更も対象外である。その frontend
sources の変更が必要だと確認できないなら、この skill を使わない。

読み込んだ後は、rendered DOM・CSS・token・theme・layout・responsive な挙動を
変えうる変更を UI surface の作業として扱う。typography・motion・画像・icon・
component・page・目に見える文言や state の意味・routing・navigation も
同じである。keyboard・focus・touch の挙動、loading/empty/error の state、
ARIA と live region も同じである。test だけの変更・build 設定・依存の保守・
生成物・見た目と操作を変えないと証明された内部 refactor は、この境界の外である。

コードを書く前に design authority を解決する。

1. Project root の `DESIGN.md` を読む。これが自己完結した authority である。
2. root の file が無い既存の Project では、`docs/DESIGN.md` が legacy
   fallback である。この delivery ではそれを読む。両方の file を暗黙に
   merge しない。
3. 共有の Sumi・Kinari・その他の template は bootstrap input としてのみ扱う。
   Project root の `DESIGN.md` へ取り込んだ後は、Project が規則を所有し、
   共有 template はそれを上書きできない。
4. Project の authority が無いか、既存の規則と pattern が視覚や操作の
   判断を決められないなら、実装の前に止まる。contract 自体を変える必要が
   あるときは、`designer` を起動して root の `DESIGN.md` を確立または更新する。

Project の design と、適用できる designer の brief は、この skill にある
一般的な美的助言をすべて上書きする。typography・構成・motion の助言も含む。
design contract を変える現在の user 要求は、`designer` を通して reconcile
する。code がそれに依存するより前に、root の `DESIGN.md` へ記録する。

## 手順

1. 現在の interface・実装 stack・再利用できる component・token・影響を受ける
   state を調べる。
2. user の成果と、それを届ける最小で一貫した UI surface を特定する。
   authority が意図的に変わらない限り、確立された pattern を保つ。
3. 影響を受ける state・viewport・入力方法について、観測可能な達成条件を
   定義する。該当するなら loading・empty・error・keyboard/focus・touch・
   overflow・contrast・reduced motion を含める。
4. Project の component と token で、実際に動作するコードを実装する。
   一度きりの値や、並行する component の recipe を避ける。
5. 変更した flow を実際の browser で動かし、結果を達成条件と Project の
   authority と突き合わせる。テストと browser の証拠は目的が違う。
   振る舞いが変わったなら両方を残す。

## 実装の品質

- 装飾を足す前に、階層・主要な action・state・navigation を読めるようにする。
- typography・色・spacing・構成・画像・motion は、product の調子と task に
  役立つから選ぶ — 一般的に大胆だからではない。
- 結果を文脈固有で意図的なものに保つ。ありきたりな AI の pattern・恣意的な
  gradient・過剰な card・装飾的な motion・理解を弱める目新しさを避ける。
- semantic HTML・keyboard での操作・見える focus・touch target を保つ。
  responsive な layout・読める contrast・reduced-motion の挙動も保つ。
- 実装の複雑さを、承認された design に合わせる。抑制された system は正確さと
  一貫性を要求する。表現的な system はより豊かな構成と motion を正当化しうる。
- 既存の asset と icon system を再利用する。design の判断なしに、その場しのぎの
  記号で代用したり、新しい visual vocabulary を導入したりしない。
