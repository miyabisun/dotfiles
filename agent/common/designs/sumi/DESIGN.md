---
version: alpha
name: Sumi
description: >
  self-hosted・single-user の reader tool のための Sumi デザインシステムの
  正式 template。中立な ink-and-paper の chrome、2 つの named theme —
  Washi (和紙, light) と Sumi (墨, dark) —、project ごとに最大 2 色の accent
  (必須の primary と任意の secondary。それぞれが独立した持続的な役割を担う)、
  そして data semantics のために予約された機能的な色からなる。project は
  この file を bootstrap input として使い、該当する規則を自己完結した
  project root の DESIGN.md へ適合させる。
colors:
  # --- Neutral chrome: Washi theme (light). Unsuffixed tokens = Washi. ---
  surface: "#fafafa"
  surface-raised: "#ffffff"
  on-surface: "#222222"
  muted: "#4a4a4a"
  border: "#c9c9c4"
  scrim: "rgba(0, 0, 0, 0.4)"
  # --- Per-project primary accent (template default: amber) ---
  accent: "#9a6a00"
  accent-subtle: "rgba(154, 106, 0, 0.12)"
  # --- Per-project secondary accent (optional; no template default) ---
  # Projects that need a second persistent role (subscribed state,
  # on/online status, character-identity emphasis) declare secondary +
  # secondary-subtle as a Washi/Sumi pair with the same structure as
  # accent. Omit entirely if the project only needs one accent.
  # --- Feedback ---
  link: "#14506e"
  danger: "#8f1d16"
  danger-subtle: "#fdeeee"
  # --- Sumi theme (dark) equivalents: suffix -dark ---
  surface-dark: "#191919"
  surface-raised-dark: "#232323"
  on-surface-dark: "#e6e6e6"
  muted-dark: "#9a9a9a"
  border-dark: "#333333"
  scrim-dark: "rgba(0, 0, 0, 0.6)"
  accent-dark: "#e0a800"
  accent-subtle-dark: "rgba(224, 168, 0, 0.15)"
  # secondary-dark / secondary-subtle-dark: declared per-project alongside
  # the Washi values above. No template default.
  link-dark: "#7fdbff"
  danger-dark: "#ff6b6b"
  danger-subtle-dark: "#3a1a1a"
typography:
  title-md:
    fontFamily: system-ui
    fontSize: 17px
    fontWeight: 600
    lineHeight: 1.3
  body-md:
    fontFamily: system-ui
    fontSize: 16px
    fontWeight: 400
    lineHeight: 1.6
  body-sm:
    fontFamily: system-ui
    fontSize: 14px
    fontWeight: 400
    lineHeight: 1.5
  label-md:
    fontFamily: system-ui
    fontSize: 15px
    fontWeight: 500
    lineHeight: 1.2
  caption:
    fontFamily: system-ui
    fontSize: 12px
    fontWeight: 400
    lineHeight: 1.4
spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 24px
  gutter: 12px
rounded:
  sm: 6px
  md: 8px
  lg: 12px
  full: 9999px
components:
  button:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.on-surface}"
    typography: "{typography.label-md}"
    rounded: "{rounded.sm}"
    padding: 8px
  button-hover:
    backgroundColor: "{colors.border}"
  button-primary:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.surface-raised}"
    typography: "{typography.label-md}"
    rounded: "{rounded.sm}"
    padding: 8px
  button-quiet:
    backgroundColor: "transparent"
    textColor: "{colors.muted}"
    rounded: "{rounded.sm}"
  button-danger:
    backgroundColor: "transparent"
    textColor: "{colors.danger}"
    rounded: "{rounded.sm}"
  icon-button:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.sm}"
    size: 36px
  input:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    typography: "{typography.body-md}"
    rounded: "{rounded.sm}"
    padding: 8px
  card:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.md}"
    padding: 10px
  modal:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.lg}"
    padding: 16px
  badge:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.surface-raised}"
    typography: "{typography.caption}"
    rounded: "{rounded.full}"
    padding: 4px
---

# Sumi — 個人向け reader tool のデザインシステム (テンプレート)

## 概要

Sumi (墨 — ink) は、self-hosted・single-user の reader tool 群が共有する
視覚言語である。対象の app は、content の feed や list を表示し、1 人の
人間がそれを読めるようにすることだけを仕事とする。情報密度が高く content
優先の道具であり、スマートフォン (1 pane・ジェスチャー駆動) と PC
(2 pane・list + detail) の両方で毎日使われる。

性格は **穏やかで、静かで、道具のようである** — consumer app よりも、
使い込んだ紙のノートに近い。視覚的な面白さはすべて content (テキスト・
サムネイル・ページ) が担い、UI chrome は中立な ink-and-paper の色調へ
引き下がる。chrome の中に、content と注意を奪い合うものがあってはならない:
グラデーションも、カラフルな icon も、装飾的な色も使わない。

**想定利用者は 1 人のプロの web エンジニア**である。その人は terminal に
住み、その隣でこれらの app を毎日読む。帰結は 2 つある。UI は技術
リテラシーを前提にしてよい (高密度な情報・onboarding なし・手取り足取りの
案内なし)。そして、terminal window の隣に置いても違和感のないものにする。

ink-and-paper という比喩は文字どおりである。この system は **役割の異なる
2 つの named theme** を備える。

- **Sumi (墨) — dark、primary な theme。** 通常の画面での日常的な読書に
  おける既定である。contrast と可読性が高く、それでいて目に優しい: 淡い
  テキストを載せた ink の surface (#191919 であり、意図的に純黒には
  しない)。まず Sumi で設計する。
- **Washi (和紙) — light、e-paper 向けの theme。** 必要に迫られて存在する。
  dark theme は e-paper display 上で破綻する。色が薄くしか出ないためである。
  そのため Washi は **contrast の最大化** に最適化する。ほぼ白の紙と、暗い
  前景を使う。ここでは色相が運ぶ情報は少ない。e-paper は彩度の高い色を確実
  には描けない。したがって data color は、まず ink として読める暗さにする。
  色相は、かろうじて働く副次的な手がかりとしてのみ使う。motion は最小に
  する。e-paper の残像により、アニメーションは有害になるためである。

この system の名は、その象徴となる theme である Sumi に由来する。すべての
color token は両方の theme に存在し、app は `data-theme` 属性上の CSS
custom property を差し替えて切り替える。

色は **装飾ではなく意味の担い手** である。各 project は **1〜2 個の accent
色相**を所有する。必須の **primary** は、「いま自分はここにいる」「これが
主要な操作である」と示すために控えめに使う。任意の **secondary** は、その
project が表に出す必要のある、独立で持続的な役割に使う。たとえば
subscribed 状態、online 状態、キャラクター identity の強調である。primary
と secondary の両方を宣言する場合、役割を重ねてはならない。primary は
**意図の前景** を、secondary は **状態の背景** を示す。追加の色は、data を
符号化するときだけ現れる。未読状態、評価の段階、ID の頻度などがこれに
あたる。これらの色は accent の上へ重ね、project ごとに定義する。

**project がこの template を取り込む方法:** この file を bootstrap 素材と
して使う。そのうえで、該当する規則を自己完結した project root の
`DESIGN.md` へ複写し、適合させる。その project が所有する file を、chrome・
accent・data color・ドメイン component に関する唯一の継続 authority と
する。今後の template の変更によって、Project が暗黙に更新されることは
ない。Project の文書と実装を明示的にレビューして取り込む。

## 色

palette は中立なグレーと、project ごとに 1 色の accent からなる。定義は
theme ごとに一度だけ行う。**Washi** は light 用で、接尾辞のない token を
使う。**Sumi** は dark 用で、`-dark` token を使う。以下の値は Washi / Sumi
の対として記す。component が hex 値を直接埋め込むことはない。CSS custom
property を参照し、有効な theme の値は `data-theme` 属性で決まる。

- **Surface (#fafafa / #191919):** ページの背景。わずかに off-white /
  off-black とし、raised な card を層として読めるようにする。
- **Surface Raised (#ffffff / #232323):** card、list row、modal、nav bar。
- **On-Surface (#222222 / #e6e6e6):** 主要なテキスト。Washi ではこれが
  「contrast 最大」の基準点であり (surface に対して ~15:1)、これを明るく
  しない。
- **Muted (#4a4a4a / #9a9a9a):** 副次的なテキスト、caption、メタデータ、
  inactive な tab、目立たない icon。Washi では surface に対して 7:1 (AAA)
  を満たさなければならない — e-paper のグレースケール量子化は中間グレーを
  飛ばすためである。Sumi では AA で足りる。
- **Border (#c9c9c4 / #333333):** hairline の 1px border であり、この
  フラットな system における主要な区切り手段である。Washi の値は、目立た
  ないままで hairline が e-paper のグレー量子化を生き延びる程度に暗い。
- **Accent (primary; template default #9a6a00 / #e0a800):** その project の
  identity color である。用途は、active な tab indicator と primary action
  button である。focus ring、選択ハイライト、pull-to-refresh の "release"
  状態にも使う。1 つの画面領域につき、primary accent は 1 つとする。すべて
  を強調すれば、何も強調されない。primary button には、accent の上に
  surface-raised (白) のテキストを置く。そのため、Washi の primary は
  white-on-accent で ≥ 4.5:1 を保たなければならない。e-paper を主眼とする
  project は、この既定よりも暗くする。
- **Secondary (optional; no template default):** 2 つ目の identity color で
  ある。その project が primary から独立して表へ出す必要のある、**独立で
  持続的な役割** に予約する。該当する役割は、subscribed / on-air /
  connected の状態である。キャラクター identity の強調 (マスコット色) や、
  ドメイン上の "alive" indicator も含む。project は `secondary` +
  `secondary-subtle` (Washi/Sumi の対) として宣言してよい。宣言した場合は、
  chrome (icon-button、badge、toggle の ON 状態) に色を付けてよい。ただし、
  primary がすでに所有する領域には決して使わない。primary と secondary は、
  別々の仕事として読めなければならない。装飾の上に装飾を重ねてはならない。
  contrast の要件は primary と同じである。使わない場合は token ごと省く。
- **Link (#14506e / #7fdbff):** ハイパーリンクと参照 anchor だけに使う。
  Washi の値は ink のように暗い青で、surface に対して ≥7:1 である。
- **Danger (#8f1d16 / #ff6b6b):** 破壊的な操作と error のテキストに使う。
  error banner には、控えめな背景の色味 (danger-subtle) を添える。Washi の
  値は surface に対して ≥7:1 である。

**project ごとの accent 規則:** この template を bootstrap input として
使う。そのうえで project は、primary accent を自身の project root の
`DESIGN.md` へ Washi/Sumi の対として宣言する。その file を、その project の
accent に関する唯一の authority とする。project は任意で secondary accent
も宣言できる。その場合は、project 内で secondary が担う役割を併記する。
明示的な役割がない場合、secondary を宣言してはならない。primary は、兄弟
project どうしを一目で見分けられるように選ぶ。secondary は、同じ project
内で primary と区別できるように選ぶ。上書きの宣言がなければ、template の
既定 (amber・primary のみ) を適用する。それ以外はすべて同一に保ち、tool
群が 1 つの家族として感じられるようにする。

**機能的な data color** は、その上に重ねる project ドメインの token で
ある。未読マーカー、ID ごとの heat 段階、星評価の bar、live/shorts の badge
などがこれにあたる。各 project の root `DESIGN.md` に記載する。満たすべき
条件は 3 つある。(1) chrome に使わない、(2) Washi+Sumi の対で用意する、
(3) 両方の theme で surface-raised に対して読める。Washi では
**暗さの傾斜** として設計する。まず相対輝度を低くし、ink として読め、
グレースケールを生き延びるようにする。段階どうしの明度の刻みは単調に
する。色相は副次的な手がかりにのみ使う。これらは装飾ではなく data を
符号化するため、accent の規則の対象外である。

## タイポグラフィ

書体は 1 つだけで、platform の `system-ui` スタックを使う。webfont は
使わない。これらは高速で self-hosted な tool であり、日本語も OS の font で
もっともよく描画されるためである。

- **Title (17px / 600):** 画面と thread の title、modal の header。1 行に
  収め、省略記号で切る。
- **Body (16px / 400 / 1.6):** reader の content であり、user が読みに来た
  テキストそのものである。これより小さくしない: ここが読むための面である。
- **Body Small (14px / 400):** list row の subtitle、modal 内の引用投稿の
  ような副次的な content。
- **Label (15px / 500):** button、tab、menu の操作。
- **Caption (12px / 400):** タイムスタンプ、ID、件数、メタデータ。data
  color を担うとき以外は常に `muted` で表示する。

段階は 5 つだけである。新しいサイズが必要に思えたら、代わりに weight か
`muted` の色を使う。

## レイアウト

モバイル優先の単一カラム (最大 720px) を基本とし、≥768px で **2 pane の
list + detail grid** へ広がる。list は 18–22rem、detail は可変で最大
1100px とする。pane はそれぞれ独立にスクロールし、PC では viewport 自体は
スクロールしない。

spacing は **4px の基本スケール** (4 / 8 / 12 / 16 / 24) に従う。既定の
リズムは、兄弟 card の間が 8px、card 内部の padding が 10px である。pane 間
の gutter は 12px、modal の padding は 16px とする。0.3rem や 0.45rem の
ような任意の値は使わない — スケールに吸着させる。

固定される chrome は最小限である。sticky な top nav bar (~3.2rem) を置く。
画面に primary action がある場合は、sticky な footer bar も置く。それ以外は
すべてスクロールする。

## 高さと奥行き

この system は **フラット** である。階層は、色調の層 (surface →
surface-raised) と 1px の hairline border から生まれる。in-flow な content
への drop shadow からは決して生まれない。

浮くものはちょうど 2 つであり、shadow を落としてよいのはそれだけである:

- **Modals / menus:** scrim (`scrim` token) + `0 8px 32px rgba(0,0,0,0.25)`。
- **Image viewer:** ほぼ黒の全画面の背景。shadow は要らない。

## 形状

角の丸い矩形の語彙で、radius は 3 つだけである:

- **6px (sm):** button、input、badge の同類にあたる容器 — 小さな control
  すべてに使う。
- **8px (md):** card と list row。
- **12px (lg):** modal と浮遊する menu。
- **Full (9999px):** 件数の pill (例: 未読 badge) にのみ使う。

円形の button は使わない。1 つの複合 control の中で radius を混ぜない。

## アイコン

icon は **inline SVG で、モノクロで、`currentColor` で描く**。24×24 の
グリッド上に置き、`fill="none" stroke="currentColor" stroke-width="2"
stroke-linecap="round" stroke-linejoin="round"` (Lucide/Feather 様式) と
する。既定のサイズは `1.2em` で、テキストの baseline に揃える。

- **絵文字を UI icon として使うことを禁じる** (🔄 ✏️ ☀ など) — カラフルかつ
  platform 依存で描画され、モノクロの chrome を壊すためである。
- icon の代わりに使うテキストグリフ (▲ ▼ × ✗ ☾ ↑ ↓) は SVG (chevron、x、
  sun、moon、arrow) に置き換える。
- icon はテキスト文脈の色 (`on-surface`、`muted`、active なら accent) を
  継承する — 自前の固定色は決して持たない。
- データ可視化のグリフ (例: 星評価の ★) は chrome ではなく、機能的な色を
  保つ。

## コンポーネント

- **Buttons:** Default は surface-raised の背景と 1px の border を持つ。
  label type、6px の radius、8×14px の padding とする。hover では背景を
  `border` に差し替える。Primary は accent の背景に白いテキストで、1 画面につき最大
  1 つとする。Quiet は透明な背景で、bar の中の icon button に使う。Danger
  は透明な背景に danger のテキストで、破壊的な menu 操作に予約する。
  Disabled は 50% の不透明度で、pointer を無効にする。
- **Icon buttons:** 36×36px の hit area、quiet または default の variant、
  中央に置いた SVG icon とする。`aria-label` を必ず付ける。
- **Inputs & textareas:** 背景は surface とする (載っている modal/card より
  1 段下)。1px の border、6px の radius、body type とする。focus 時は border
  が `accent` になる。UA の outline は抑止し、共通の focus ring (下記) を
  使う。label は field の上に置く caption サイズの muted テキストである。
- **Focus ring (all interactive elements):** accent を不透明度 60% にして
  `outline: 2px solid` を引く。`outline-offset: 2px` を付け、
  `:focus-visible` のときだけ適用する。ブラウザ既定の青い ring は決して
  現れさせない。
- **List rows:** card 風 (8px の radius、surface-raised、1px の border) と
  し、垂直方向の gap は 8px とする。row が data color (評価、未読) を担う
  ときは、左に 4px の色 bar を任意で付ける。title は label の weight、
  subtitle は caption で表示する。
- **Badges / pills:** full の radius、caption type とする。data color の背景
  の上に太字の件数を置く (例: 未読は project ごとに定義)。余白で padding を
  取り、icon は載せない。
- **Tabs (top nav):** label type とする。inactive では muted、active では
  on-surface に 2px の accent の下線を付ける。背景は変えない。
- **Top-level navigation:** すべての tab と primary view は、router に裏付け
  られた安定した URL を持つ。ナビゲーションはブラウザの履歴 entry を作り、
  直接読み込みと再読み込みは同じ view を復元する。選択中の primary tab を、
  揮発する component state だけに保持しない。
- **Modals:** 中央に配置し、12px の radius、16px の padding とし、scrim の
  クリック・×・Esc で閉じる。× は quiet な icon button (文字の × では
  なく SVG の x) である。content は内部でスクロールし、スクロールバーは
  隠す。max-height は 80dvh とする。
- **Menus (context/long-press):** modal で提示する、全幅の default button を
  積んだものとする。セクションの label は caption の muted、danger の操作は
  最後に置く。
- **Empty / loading states:** 中央寄せの muted な body-small のテキストと
  する。spinner は accent の 1.5px stroke の円で、1.1rem とする。

## すること・しないこと

- する: すべての色を、この file を出所とする CSS custom property として定義
  する。component の内部に hex 値を直接書かない。
- する: 1 画面につき primary (accent で塗る) の操作をちょうど 1 つ置く。
- しない: chrome のどこにも絵文字や多色のグリフを使わない。
- する: UA の focus ring を抑止し、常に共通の `:focus-visible` の accent ring
  で置き換える — focus の表示そのものを消さない。
- しない: 定義されたスケールの外に、新しい font サイズや radius を持ち込ま
  ない。
- する: chrome を中立に保つ。list と投稿の中の色は、常に何かを意味しなければ
  ならない (未読、自分の投稿、評価、ID の heat)。
- する: 両方の theme で、すべてのテキストについて WCAG AA (4.5:1) を維持
  する。border や bar の上の data color は対象外だが、見分けられる状態を
  保つ。
- しない: ≤150ms の height/opacity の transition と loading spinner を除いて、
  何もアニメーションさせない。これらは実用の道具であって、見せ物では
  ない。Washi では、そもそもアニメーションを使わないことを優先する
  (e-paper の残像)。
- する: まず Sumi で設計する。Washi は見た目上の light 版としてではなく、
  e-paper の条件 (色相より contrast) で検証する。
- しない: Washi では色相に意味を運ばせない — 暗さと weight を使う。e-paper
  では色相はよくても副次的な手がかりである。
- する: ジェスチャーのアフォーダンス (pull-to-refresh、swipe-back) は視覚的な
  表現を控えめに保つ。muted なテキスト panel を使う。accent は "release" の
  閾値でだけ使う。
- する: bootstrap のあと、project root の `DESIGN.md` を自己完結に保つ。本質
  的な規則を、この外部 template に依存させたまま残さない。
