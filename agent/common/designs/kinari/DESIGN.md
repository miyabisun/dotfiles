---
version: alpha
name: Kinari
description: >
  Kinari (生成り) light theme の正式 template — Sumi デザインシステムと
  対になる screen 優先の theme である。user が e-paper で決して読まない
  project は、Washi ではなく Kinari (light) を Sumi (dark, primary) と
  組み合わせる。温かい未晒しの布の surface、sepia のインク、控えめな accent
  sprinkles が、Washi のそっけない contrast 優先の紙を置き換える。Sumi と
  ともに bootstrap input として使い、該当する規則を project の自己完結した
  root DESIGN.md へ適合させる。
colors:
  # --- Neutral chrome: Kinari (light). Unsuffixed tokens = Kinari. ---
  # Dark theme tokens are NOT defined here — the dark theme is always
  # Sumi; use the -dark values from ~/.claude/designs/sumi/DESIGN.md.
  surface: "#faf6ef"
  surface-raised: "#fffdf8"
  on-surface: "#3a2f28"
  muted: "#6f6257"
  border: "#e3d9c9"
  scrim: "rgba(58, 47, 40, 0.4)"
  # --- Per-project primary accent (template default: amber, as Sumi) ---
  accent: "#9a6a00"
  accent-subtle: "rgba(154, 106, 0, 0.10)"
  # --- Per-project secondary accent (optional; no template default) ---
  # Same contract as Sumi: declare secondary + secondary-subtle only
  # with an explicit persistent role distinct from primary.
  # --- Feedback ---
  link: "#14506e"
  danger: "#9c2b1d"
  danger-subtle: "#f9e9e4"
---

# Kinari — screen 優先の tool 向けの温かい light theme (テンプレート)

## 概要

Kinari (生成り — 未晒しの布) は Sumi family の **screen 優先の light theme**
である。Kinari が存在するのは、Washi が通常の意味での light theme では
ないからである。Washi は *e-paper 生存 mode* である — contrast を最大まで
上げ、色相から意味を抜き、motion を禁じている。普通の LCD に描画すると、
それは無愛想で味気なく見える。audio tool・dashboard・editor のように、
e-paper で決して使われない project がある。そこにはインク粒子ではなく、
ガラスのために設計された light theme がふさわしい。

Kinari は family の静かで道具的な性格を保つ — content が先、chrome は
静かに。ただし Washi の臨床的な白は **温かい未晒しの紙** へ置き換える。
cream の surface、sepia のインク、古びた綿の色をした hairline である。
その温かさの中で、project の accent は *少しだけ装飾する* ことを許される。
Washi なら素のインクを求める場所に、控えめな accent tint の fill・色付きの
section marker・chip が現れてよい。結果は居心地よく、軽く遊び心のあるものに
感じられるのが望ましい — 文房具の机であって、複写機のコピーではない。

**family の中での位置づけ:**

- **Sumi (墨) — dark、primary な theme。** 変更なし。まず Sumi で設計する。
  どこでも既定である。
- **Kinari (生成り) — light、screen 向け。** この template である。普通の
  display で使われる project の `prefers-color-scheme: light` の顔である。
- **Washi (和紙) — light、e-paper 向け。** Sumi template で定義されている。
  e-ink 端末で実際に寝室へ持ち込まれる reader tool は Washi を保ち、
  Kinari を採用しない。

project は Sumi にちょうど 1 つの light theme を組み合わせる — Kinari
*または* Washi であり、両方は使わない。この選択は project root の
`DESIGN.md` で宣言する。

## 色

接尾の無い token は Kinari の値である。dark の対応物は常に Sumi template の
`-dark` token である — Kinari はそれを決して再定義しない。

- **Surface (#faf6ef):** ページの背景。温かい cream — Washi の #fafafa より
  目に見えて温かいが、raised な card がその上の layer として読める程度には
  明るい。
- **Surface Raised (#fffdf8):** card・list row・modal・nav bar。surface より
  一段明るい温かい白。
- **On-Surface (#3a2f28):** 主要なテキスト。暗い sepia のインク (surface 上で
  ~11:1) — 温かいが、AAA を余裕で超える。純黒は決して使わない。これは布の上の
  インクであって、紙の上のトナーではない。
- **Muted (#6f6257):** 副次的なテキスト・caption・メタデータ・inactive な tab。
  温かい灰褐色で、surface に対して ≥ 4.5:1 (AA)。Kinari は Washi の AAA 規則を
  必要としない — LCD は中間調を忠実に描画する。
- **Border (#e3d9c9):** 古びた綿色の beige による hairline の 1px border。
  意図的に Washi の border より柔らかい。色調の分離は、硬い線よりも
  surface/raised の差に頼ってよい。
- **Accent (primary; template default #9a6a00):** Sumi と同じ contract である。
  「ここにいる」と「主要な操作」を表す project の identity color である。
  塗りつぶした primary button は accent の上に white/raised のテキストを置く。
  そのため Kinari の primary は white-on-accent を ≥ 4.5:1 に保つ。
- **Accent sprinkles (the Kinari license):** Washi と違い、Kinari は
  `accent-subtle` (と `secondary-subtle`) を *穏やかな装飾* として使ってよい。
  色を付けた card header、hover の塗り、active な行の wash、empty state の
  挿絵である。制限は次のとおりである。tint は ≤ 12% の opacity 相当に留める。
  body のテキストは AA を下回る tint の上に決して置かない。装飾が運んでよい
  意味は、テキストや形も運んでいるものに限る (chrome はグレースケールでも
  生き残らなければならない)。
- **Link (#14506e) / Danger (#9c2b1d):** Sumi と同じ役割である。danger の値は、
  ≥ 4.5:1 を保ちながら cream 上で自然になじむよう、温かい側へ寄せてある。

**project ごとの accent と機能的な data color** は、Sumi template の規則に
そのまま従う。必須の primary が 1 つ、役割を持つ secondary は任意、
data color は project ごとに文書化する。Kinari 固有の変更は 1 つだけである。
data color は **色相を第一級の手がかり** として使ってよく、Washi の暗さ ramp
の要件は適用されない。data color は、テキスト以外の字形では surface-raised に
対して ≥ 3:1、テキストでは AA を保つ。

## その他のすべて

typography・spacing・radii・layout・elevation・iconography・component の
recipe は変えない。**Sumi template からそのまま継承する**。Kinari は palette と
license であって、新しい system ではない。差分は 2 つある:

- **Motion:** Washi の「アニメーション禁止」の規則は適用されない。Kinari は
  基本の Sumi 規則 (実用的な transition は ≤ 150ms) に従い、
  `prefers-reduced-motion` を尊重する。
- **Focus ring:** opacity 60% の accent は cream の上では淡すぎることがある。
  surface に対して ≥ 3:1 を検証し、必要なら ring の alpha を暗くする。

## すること・しないこと

- する: まず Sumi で設計し、それから Kinari を *温かい兄弟* として検証する。
  反転した Sumi としてではない。
- する: accent に静かな装飾をさせる (tint・chip・wash)。それが Kinari の
  要点である。ただし、あらゆる意味を色なしで読めるように保つ。
- しない: content が e-paper で読まれる project に Kinari を採用しない。
  その project は Washi を保つ。
- しない: ここでも project ごとにも dark token を再定義しない — dark は
  常に Sumi である。
- する: すべてのテキストで WCAG AA (4.5:1) を維持する。muted のテキストも含む。
- しない: どこでも純白 (#ffffff) や純黒 (#000000) に手を伸ばさない — Kinari の
  identity はその温かさに宿る。
