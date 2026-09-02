# ADR-0001: Feature modules are isolated Swift Package targets

**Date:** 2026-07-18  
**Status:** Accepted · amended 2026-08-31

## Context

ShopApp has eight feature areas: Store, Search, Checkout, Account, Promotions, Suggestions, PastPurchases, and Support. A naive approach would place them all in a single target and let them import each other freely. At scale, this creates a dependency web where no module can be built, tested, or reasoned about in isolation. A change in one module can have ripple effects anywhere in the graph, and the build system compiles everything together even when only one module changed.

The alternative — making each feature an independent Swift Package target — enforces isolation at the compiler level. The question is what each target is permitted to depend on.

## Decision

Each feature is a separate `.library` product in `Package.swift`. Feature modules may only depend on the three foundation targets:

- `NetworkFoundation` — HTTP client, URL construction, error decoding
- `DesignSystem` — shared visual components and tokens
- `Common` — domain-agnostic utilities (currency formatting, date helpers, etc.)

A feature may additionally depend on its **own** dependency-free contract target — an `XxxAPI` library holding value types plus the repository protocol, which the feature, its `XxxTesting` target, and its micro-app can all import without pulling in the implementation. `Checkout` is the first to split one (`CheckoutAPI`); see ADR-0016.

No feature module may import **another** feature module. Enforcement is layered:

1. **The package graph** — the primary, always-on guarantee. Because no feature target lists another feature as a dependency, attempting an `import` between features is a compile error.
2. **`allowed-dependencies.json`** — a machine-readable statement of the layering (`App → Feature, Foundation`; `Feature → Foundation`; `Foundation → nothing`). It gives tools and reviewers the rule in one place, and makes a `Package.swift` edit that *adds* a forbidden dependency edge catchable before any code imports across it.
3. **`tools/GraphTool`** (`graph-tool check`) parses the actual package graph and exits non-zero on any edge that violates `allowed-dependencies.json`. It runs as a standalone command; it is not yet wired into CI.

## Consequences

**Positive**

- Each module compiles and tests independently. A change to Checkout does not force Store to recompile.
- Micro-apps (ADR-0005) can import a single feature target and run it in isolation without pulling in the full application graph.
- Modules can be extracted into separate Swift packages or Tuist projects at a later stage without restructuring dependencies.
- The allowed-dependency boundary is enforced by the compiler today, and additionally checkable with `graph-tool check` against `allowed-dependencies.json` — not just a convention.

**Negative**

- Features cannot share domain types directly. Cross-module events require the composition root to translate between types (see ADR-0003).
- Cross-module UI composition requires @ViewBuilder injection rather than a direct import (see ADR-0004).
- The composition root (AppModel) must import every feature; it will grow as features are added (see ADR-0002).
