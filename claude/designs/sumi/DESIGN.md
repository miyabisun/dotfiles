---
version: alpha
name: Sumi
description: >
  Canonical template of the Sumi design system for self-hosted,
  single-user reader tools. Neutral ink-and-paper chrome with two named
  themes — Washi (和紙, light) and Sumi (墨, dark) — one accent color
  per project, functional color reserved for data semantics. Projects
  consume this template via a docs/DESIGN.md that declares
  "follows Sumi" and records only project-specific overrides
  (accent, data colors, domain components).
colors:
  # --- Neutral chrome: Washi theme (light). Unsuffixed tokens = Washi. ---
  surface: "#fafafa"
  surface-raised: "#ffffff"
  on-surface: "#222222"
  muted: "#4a4a4a"
  border: "#c9c9c4"
  scrim: "rgba(0, 0, 0, 0.4)"
  # --- Per-project accent (template default: amber) ---
  accent: "#9a6a00"
  accent-subtle: "rgba(154, 106, 0, 0.12)"
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

# Sumi — Personal Reader Tools Design System (Template)

## Overview

Sumi (墨 — ink) is the shared visual language for a family of self-hosted,
single-user reader tools — apps whose whole job is displaying a feed or
list of content and letting one person read it. They are dense,
content-first utilities used daily on both a phone (one pane,
gesture-driven) and a PC (two-pane, list + detail).

The personality is **calm, quiet, and tool-like** — closer to a well-worn
paper notebook than a consumer app. The content (text, thumbnails, pages)
supplies all the visual interest; the UI chrome recedes into neutral
ink-and-paper tones. Nothing in the chrome should compete with the content
for attention: no gradients, no colorful icons, no decorative color.

**The audience is one professional web engineer** who lives in the
terminal and reads these apps daily alongside it. Two consequences: the
UI may assume technical literacy (dense information, no onboarding, no
hand-holding), and it should feel at home next to a terminal window.

The ink-and-paper metaphor is literal: the system ships **two named
themes with distinct jobs**.

- **Sumi (墨) — dark, the primary theme.** The default for everyday
  reading on ordinary screens. High contrast and high legibility, but
  easy on the eyes: ink surfaces (#191919, deliberately never pure
  black) with pale text. Design in Sumi first.
- **Washi (和紙) — light, the e-paper theme.** Exists out of necessity:
  dark themes collapse on e-paper displays (colors render too faint).
  Washi therefore optimizes for **maximum contrast** — near-white paper,
  very dark foregrounds. Hue carries little information here: e-paper
  cannot render saturated color reliably, so data colors should be dark
  enough to read as ink first, with hue as a barely-there secondary cue.
  Minimize motion (e-paper ghosting makes animation harmful).

The system takes its name from Sumi, its signature theme. Every color
token exists in both themes; apps switch by swapping CSS custom
properties on a `data-theme` attribute.

Color is a **carrier of meaning, not decoration**. Each project owns exactly
one accent hue used sparingly for "you are here" and "this is the main
action". Additional colors appear only when they encode data (unread state,
rating levels, ID frequency) and are defined per project on top of this base.

**How projects consume this template:** this file
(`~/.claude/designs/sumi/DESIGN.md`) is the canonical original and the only
place where the shared rules are maintained. Each project keeps a small
`docs/DESIGN.md` that (1) declares it follows Sumi, (2) declares its accent
values, and (3) documents its project-specific data colors and domain
components. Project files never restate the shared rules; on conflict, the
project file wins for its own domain, this template wins for the chrome.

## Colors

The palette is neutral grays with a single per-project accent, defined
once per theme: **Washi** (light; the unsuffixed tokens) and **Sumi**
(dark; the `-dark` tokens). Values below are written as Washi / Sumi
pairs. Components never hardcode hex values — they reference the CSS
custom properties, and the `data-theme` attribute decides which theme's
values are live.

- **Surface (#fafafa / #191919):** Page background. Slightly off-white /
  off-black so raised cards read as a layer.
- **Surface Raised (#ffffff / #232323):** Cards, list rows, modals, nav bar.
- **On-Surface (#222222 / #e6e6e6):** Primary text. On Washi this is the
  "maximum contrast" anchor (~15:1 against surface) — never lighten it.
- **Muted (#4a4a4a / #9a9a9a):** Secondary text, captions, metadata, inactive
  tabs, quiet icons. On Washi it must clear 7:1 (AAA) against surface —
  e-paper grayscale quantization washes out mid-grays; on Sumi AA suffices.
- **Border (#c9c9c4 / #333333):** Hairline 1px borders — the primary
  separation tool in this flat system. The Washi value is dark enough for
  a hairline to survive e-paper gray quantization while staying quiet.
- **Accent (template default #9a6a00 / #e0a800):** The project's identity
  color. Used for: active tab indicator, primary action button, focus ring,
  selection highlight, pull-to-refresh "release" state. One accent per
  screen region; if everything is highlighted, nothing is. Because the
  primary button sets surface-raised (white) text on accent, a Washi accent
  must keep white-on-accent ≥ 4.5:1; e-paper-focused projects should go
  darker than this default.
- **Link (#14506e / #7fdbff):** Hyperlinks and reference anchors only.
  The Washi value is ink-dark blue, ≥7:1 against surface.
- **Danger (#8f1d16 / #ff6b6b):** Destructive actions and error text, with
  a subtle background tint (danger-subtle) for error banners. The Washi
  value is ≥7:1 against surface.

**Per-project accent rule:** a project adopts this template wholesale and
declares exactly one accent hue (as a Washi/Sumi pair) in its own
docs/DESIGN.md — that file is the sole authority for the project's accent.
Pick a hue that is distinguishable from sibling projects so each tool is
tellable apart at a glance. When no override is declared, the template
default (amber) applies. Everything else stays identical so the tools
feel like one family.

**Functional data colors** (unread markers, per-ID heat levels, star-rating
bars, live/shorts badges…) are project-domain tokens layered on top and
documented in each project's docs/DESIGN.md. They must: (1) never be used
for chrome, (2) come in Washi+Sumi pairs, (3) stay readable against
surface-raised in both themes. On Washi, design them as a **darkness ramp**:
low relative luminance first (so they read as ink and survive grayscale),
monotonic lightness steps between levels, hue only as a secondary cue.
They are exempt from the one-accent rule because they encode data, not
decoration.

## Typography

One typeface: the platform's `system-ui` stack. No webfonts — these are
fast, self-hosted tools and Japanese text renders best in the OS font.

- **Title (17px / 600):** Screen and thread titles, modal headers. Single
  line, ellipsized.
- **Body (16px / 400 / 1.6):** Reader content — the text the user came to
  read. Never smaller: this is the reading surface.
- **Body Small (14px / 400):** List-row subtitles, secondary content such as
  quoted posts inside modals.
- **Label (15px / 500):** Buttons, tabs, menu actions.
- **Caption (12px / 400):** Timestamps, IDs, counts, metadata. Always in
  `muted` unless carrying a data color.

Five levels only. If a new size feels needed, use weight or `muted` color
instead.

## Layout

Mobile-first single column (max 720px) that expands to a **two-pane
list + detail grid** at ≥768px (list 18–22rem, detail flexible, max 1100px).
Each pane scrolls independently; the viewport itself never scrolls on PC.

Spacing follows a **4px base scale** (4 / 8 / 12 / 16 / 24). Default
rhythm: 8px between sibling cards, 10px card internal padding, 12px gutter
between panes, 16px modal padding. No arbitrary values like 0.3rem or
0.45rem — snap to the scale.

Fixed chrome is minimal: a sticky top nav bar (~3.2rem) and, where a screen
has a primary action, a sticky footer bar. Everything else scrolls.

## Elevation & Depth

The system is **flat**. Hierarchy comes from tonal layers (surface →
surface-raised) plus 1px hairline borders — never from drop shadows on
in-flow content.

Exactly two things float, and only they may cast shadow:

- **Modals / menus:** scrim (`scrim` token) + `0 8px 32px rgba(0,0,0,0.25)`.
- **Image viewer:** near-black full-screen backdrop, no shadow needed.

## Shapes

Soft-rectangle language, three radii only:

- **6px (sm):** buttons, inputs, badges' container cousins — all small controls.
- **8px (md):** cards and list rows.
- **12px (lg):** modals and floating menus.
- **Full (9999px):** count pills (e.g. unread badges) exclusively.

Circular buttons are not used. Never mix radii within one composite control.

## Iconography

Icons are **inline SVG, monochrome, drawn with `currentColor`** on a 24×24
grid: `fill="none" stroke="currentColor" stroke-width="2"
stroke-linecap="round" stroke-linejoin="round"` (Lucide/Feather style).
Default size `1.2em`, aligned to the text baseline.

- **Emoji are banned as UI icons** (🔄 ✏️ ☀ etc.) — they render colorful and
  platform-dependent, breaking the monochrome chrome.
- Text glyphs standing in for icons (▲ ▼ × ✗ ☾ ↑ ↓) are replaced by SVG
  (chevron, x, sun, moon, arrow).
- Icons inherit the color of their text context (`on-surface`, `muted`, or
  accent when active) — never their own hardcoded color.
- Data-visualization glyphs (e.g. star ratings ★) are not chrome and keep
  their functional colors.

## Components

- **Buttons:** Default = surface-raised bg, 1px border, label type, 6px
  radius, 8×14px padding; hover swaps bg to `border`. Primary = accent bg,
  white text — at most one per screen. Quiet = transparent bg for icon
  buttons in bars. Danger = transparent with danger text, reserved for
  destructive menu actions. Disabled = 50% opacity, no pointer.
- **Icon buttons:** 36×36px hit area, quiet or default variant, SVG icon
  centered. Always `aria-label`.
- **Inputs & textareas:** surface bg (one level below the modal/card they
  sit on), 1px border, 6px radius, body type. On focus: border becomes
  `accent` and the UA outline is suppressed in favor of the shared focus
  ring (below). Labels are caption-size muted text above the field.
- **Focus ring (all interactive elements):** `outline: 2px solid` accent at
  60% opacity, `outline-offset: 2px`, applied only on `:focus-visible`.
  The browser default blue ring must never appear.
- **List rows:** card-style (8px radius, surface-raised, 1px border), 8px
  vertical gap, optional 4px left color bar when the row carries a data
  color (rating, unread). Title in label weight, subtitle in caption.
- **Badges / pills:** full-radius, caption type, bold count on a data color
  bg (e.g. unread = project-defined). Whitespace-padded, never icon-bearing.
- **Tabs (top nav):** label type, muted when inactive, on-surface + 2px
  accent underline when active. No background change.
- **Modals:** centered, 12px radius, 16px padding, scrim click / × / Esc to
  close. The × is a quiet icon button (SVG x, not the character ×). Content
  scrolls internally with hidden scrollbars; max-height 80dvh.
- **Menus (context/long-press):** modal-presented stack of full-width
  default buttons, section labels in caption-muted, danger actions last.
- **Empty / loading states:** centered muted body-small text; spinners are
  1.5px-stroke circles in accent, 1.1rem.

## Do's and Don'ts

- Do define every color as a CSS custom property sourced from this file;
  don't hardcode hex values inside components.
- Do use exactly one primary (accent-filled) action per screen.
- Don't use emoji or multicolor glyphs anywhere in the chrome.
- Do suppress the UA focus ring and always substitute the shared
  `:focus-visible` accent ring — never remove focus indication outright.
- Don't introduce new font sizes or radii outside the defined scales.
- Do keep chrome neutral: color in lists and posts must always mean
  something (unread, own-post, rating, ID heat).
- Do maintain WCAG AA (4.5:1) for all text in both themes; data colors on
  borders/bars are exempt but should stay distinguishable.
- Don't animate anything except height/opacity transitions ≤150ms and the
  loading spinner; these are utilitarian tools, not showcases. In Washi,
  prefer no animation at all (e-paper ghosting).
- Do design in Sumi first; verify Washi on e-paper terms (contrast over
  hue), not as a cosmetic light variant.
- Don't rely on hue to carry meaning in Washi — use darkness and weight;
  hue is a secondary cue at best on e-paper.
- Do keep gesture affordances (pull-to-refresh, swipe-back) visually quiet:
  muted text panels, accent only at the "release" threshold.
- Don't restate template rules in a project's docs/DESIGN.md — record only
  the project's accent, data colors, and domain components there.
