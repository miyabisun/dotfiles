---
name: frontend-design
description: >-
  Implement production-grade frontend UI while preserving the Project design
  authority and interaction contract. Use when rendered UI or user interaction
  may change: components, pages, styling, layout, responsive behavior,
  typography, motion, icons, visible states, navigation, focus, touch, or
  accessibility presentation. If applicability is uncertain, use this skill.
---

# Frontend Design

Turn an established product and design intent into cohesive, accessible working
UI. Do not invent a new visual language when the Project already owns one.

## UI surface and authority

Treat a change as UI surface work when it can alter rendered DOM, CSS, tokens,
theme, layout, responsive behavior, typography, motion, images or icons,
components or pages, visible copy or state meaning, routing or navigation,
keyboard, focus or touch behavior, loading/empty/error states, or ARIA and live regions.
Test-only changes, build configuration, dependency maintenance,
generated artifacts, and internal refactors proven not to change appearance or
interaction are outside this boundary.

Resolve design authority before coding:

1. Read the Project root `DESIGN.md`; it is the self-contained authority.
2. In an existing Project without the root file, `docs/DESIGN.md` is a legacy
   fallback; read it for this delivery. Do not merge both files implicitly.
3. Treat shared Sumi, Kinari, or other templates only as bootstrap input. Once
   adapted into the Project root `DESIGN.md`, the Project owns the rules and a
   shared template cannot overwrite them.
4. If no Project authority exists, or existing rules and patterns do not settle
   a visual or interaction choice, stop before implementation. Invoke `designer`
   to establish or update the root `DESIGN.md` when the contract itself must
   change.

Project design and an applicable designer brief override every generic
aesthetic suggestion in this skill, including typography, composition, and
motion advice. A current user requirement that changes the design contract must
be reconciled through `designer` and recorded in root `DESIGN.md` before code
depends on it.

## Workflow

1. Inspect the current interface, implementation stack, reusable components,
   tokens, and affected states.
2. Identify the user outcome and the smallest coherent UI surface that delivers
   it. Preserve established patterns unless the authority intentionally changes.
3. Define observable criteria for the affected states, viewports, and input
   methods. Include loading, empty, error, keyboard/focus, touch, overflow,
   contrast, and reduced motion when relevant.
4. Implement real working code with the Project's components and tokens. Avoid
   one-off values and parallel component recipes.
5. Exercise the changed flow in a real browser and compare the result with the
   criteria and Project authority. Tests and browser evidence serve different
   purposes; keep both when behavior changed.

## Execution quality

- Make hierarchy, primary action, state, and navigation legible before adding
  decoration.
- Choose typography, color, spacing, composition, imagery, and motion because
  they serve the product's tone and task—not because they are generically bold.
- Keep the result context-specific and intentional. Avoid stock AI patterns,
  arbitrary gradients, excessive cards, decorative motion, or novelty that
  weakens comprehension.
- Preserve semantic HTML, keyboard access, visible focus, touch targets,
  responsive layout, readable contrast, and reduced-motion behavior.
- Match implementation complexity to the approved design. A restrained system
  requires precision and consistency; an expressive system may justify richer
  composition and motion.
- Reuse existing assets and icon systems. Do not substitute ad-hoc symbols or
  introduce a new visual vocabulary without a design decision.
