---
version: alpha
name: Kinari
description: >
  Canonical template of the Kinari (生成り) light theme — the
  screen-first companion to the Sumi design system. Projects whose
  users never read them on e-paper pair Sumi (dark, primary) with
  Kinari (light) instead of Washi. Warm unbleached-cloth surfaces,
  sepia ink, and gentle accent sprinkles replace Washi's stark
  contrast-first paper. Consumed the same way as Sumi: a project's
  docs/DESIGN.md declares "dark = Sumi, light = Kinari" and records
  only its accents, data colors, and domain components.
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

# Kinari — Warm Light Theme for Screen-First Tools (Template)

## Overview

Kinari (生成り — unbleached cloth) is the **screen-first light theme** of
the Sumi family. It exists because Washi is not a light theme in the
usual sense: Washi is an *e-paper survival mode* — contrast pushed to the
maximum, hue drained of meaning, motion banned. Rendered on an ordinary
LCD it reads as stark and joyless. Projects that are never used on
e-paper (audio tools, dashboards, editors) deserve a light theme designed
for glass, not for ink particles.

Kinari keeps the family's calm, tool-like personality — content first,
chrome quiet — but swaps Washi's clinical white for **warm unbleached
paper**: cream surfaces, sepia ink, and hairlines the color of aged
cotton. Within that warmth, the project's accents are allowed to
*decorate a little*: subtle accent-tinted fills, colored section
markers, and chips may appear where Washi would demand bare ink. The
result should feel cozy and lightly playful — a stationery desk, not a
photocopy.

**Positioning within the family:**

- **Sumi (墨) — dark, the primary theme.** Unchanged. Design in Sumi
  first; it is the default everywhere.
- **Kinari (生成り) — light, for screens.** This template. The
  `prefers-color-scheme: light` face of projects that are used on
  ordinary displays.
- **Washi (和紙) — light, for e-paper.** Defined in the Sumi template.
  Reader tools that are actually taken to bed on an e-ink device keep
  Washi; they do not adopt Kinari.

A project pairs exactly one light theme with Sumi — Kinari *or* Washi,
never both. The choice is declared in the project's docs/DESIGN.md.

## Colors

Unsuffixed tokens are Kinari values. The dark counterparts are always
Sumi's `-dark` tokens from the Sumi template — Kinari never redefines
them.

- **Surface (#faf6ef):** Page background. Warm cream — visibly warmer
  than Washi's #fafafa, but light enough that raised cards still read
  as a layer above it.
- **Surface Raised (#fffdf8):** Cards, list rows, modals, nav bar.
  Warm white, one step brighter than surface.
- **On-Surface (#3a2f28):** Primary text. Dark sepia ink (~11:1 on
  surface) — warm, but comfortably past AAA. Never pure black: this is
  ink on cloth, not toner on paper.
- **Muted (#6f6257):** Secondary text, captions, metadata, inactive
  tabs. Warm gray-brown, ≥ 4.5:1 (AA) against surface. Kinari does not
  need Washi's AAA rule — LCDs render mid-tones faithfully.
- **Border (#e3d9c9):** Hairline 1px borders in aged-cotton beige.
  Softer than Washi's border on purpose; tonal separation may lean on
  the surface/raised difference more than on hard lines.
- **Accent (primary; template default #9a6a00):** Same contract as
  Sumi: the project's identity color for "you are here" and "the main
  action". Filled primary buttons set white/raised text on accent, so a
  Kinari primary must keep white-on-accent ≥ 4.5:1.
- **Accent sprinkles (the Kinari license):** Unlike Washi, Kinari may
  use `accent-subtle` (and `secondary-subtle`) as *gentle decoration*:
  tinted card headers, hover fills, active-row washes, empty-state
  illustrations. The limits: tints stay ≤ 12% opacity equivalents, body
  text never sits on a tint below AA, and decoration never carries
  meaning that isn't also carried by text or shape (the chrome must
  survive grayscale).
- **Link (#14506e) / Danger (#9c2b1d):** Same roles as Sumi. The danger
  value is nudged warm to sit naturally on cream while keeping ≥ 4.5:1.

**Per-project accents and functional data colors** follow the Sumi
template's rules verbatim (one required primary, optional role-bearing
secondary, data colors documented per project). The only Kinari-specific
change: data colors may use **hue as a first-class cue** — the Washi
darkness-ramp requirement does not apply. Keep data colors ≥ 3:1 against
surface-raised for non-text glyphs and AA for text.

## Everything else

Typography, spacing, radii, layout, elevation, iconography, and
component recipes are **inherited from the Sumi template unchanged** —
Kinari is a palette and a license, not a new system. Two deltas:

- **Motion:** the Washi "no animation" rule does not apply. Kinari
  follows the base Sumi rule (utilitarian transitions ≤ 150ms), and
  honors `prefers-reduced-motion`.
- **Focus ring:** accent at 60% opacity may be too faint on cream —
  verify ≥ 3:1 against surface and darken the ring alpha if needed.

## Do's and Don'ts

- Do design in Sumi first, then verify Kinari as a *warm sibling*, not
  as an inverted Sumi.
- Do let accents decorate quietly (tints, chips, washes) — that is the
  point of Kinari — but keep every meaning readable without color.
- Don't adopt Kinari in a project whose content is read on e-paper;
  that project keeps Washi.
- Don't redefine dark tokens here or per-project — dark is always Sumi.
- Do maintain WCAG AA (4.5:1) for all text; muted text included.
- Don't reach for pure white (#ffffff) or pure black (#000000)
  anywhere — Kinari's identity lives in its warmth.
