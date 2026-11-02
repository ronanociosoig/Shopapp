# DesignSystem

**Scope:** shared visual language — color tokens and reusable components — for every feature module.
**Not in scope:** architecture/code-shape rationale. That lives in `docs/adr/`; this module owns *how
things look*, ADRs own *how code is organized*. A screen's navigation pattern is an ADR question; a
screen's button radius is a question for this file.

## The rule

**A shared component has exactly one look, defined once, here. A screen that wants a different look
for a shared component changes the component, not itself.**

Concretely:

- `PrimaryButton`, `LoadingView`, `ErrorView`, `PriceLabel` are the only sanctioned way to render their
  respective UI, across all 8 feature modules.
- No call site hand-rolls a competing version of a component that already exists here (a second
  "primary-looking" button built from a bare `Button` + manual padding/background/corner radius is a
  bug, not a style choice).
- No call site takes a parameter that lets it opt out of this module's shape for just that one screen
  (see below). If a screen's design genuinely calls for a different look, that's a decision about the
  *component*, made once, that every caller then inherits — not a per-screen flag.

## Why this is written down

This module originally let a single screen render `PrimaryButton` as a capsule (`isPill: true`) to
match a Figma reference for the Checkout "Shipping Address" screen, while every other screen kept the
existing `cornerRadius: 12` shape. It compiled, it passed tests, and it still produced a button that
looked like it belonged to a different app the moment you moved from Cart to Address. The fix wasn't a
better flag — it was deleting the flag: one shape, chosen once, inherited everywhere. That incident is
why this rule is a README and not tribal knowledge.

The failure mode to watch for is specifically **reference material (a Figma mockup, a design-team
ask) landing as a per-screen override** instead of prompting a real "do we change the component"
decision. A new mockup disagreeing with the current component is a legitimate reason to *change the
component* — it's never a reason to let one screen quietly diverge.

## How to apply this

- Building a screen and an existing component already covers the UI element you need → use it as-is.
- A new mockup shows that element looking different from what the component currently renders → that's
  a proposal to change the component for every caller, not a parameter for your screen. Raise it
  explicitly; don't thread a style override through the call site.
- The UI element doesn't exist here yet → add it here, not inline in the feature module, even if only
  one screen uses it today — the next screen that needs it should find it already built, not rebuild
  it slightly differently.

## What's here today

**Colors** (`DSColor.swift`) — `dsPrimary`, `dsSecondary`, `dsSuccess`, `dsDestructive`, `dsWarning`,
`dsBackground`, `dsSurface`, `dsBorder`. Available both as `Color` statics and as `ShapeStyle` statics
(`.foregroundStyle(.dsPrimary)` and `Color.dsPrimary` both work).

**Components** (`DSComponents.swift`) — `LoadingView`, `ErrorView`, `PrimaryButton`, `PriceLabel`.
