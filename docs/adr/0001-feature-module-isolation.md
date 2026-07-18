# ADR-0001: Feature modules are isolated Swift Package targets

**Date:** 2026-07-18  
**Status:** Accepted

## Context

ShopApp has eight feature areas: Store, Search, Checkout, Account, Promotions, Suggestions, PastPurchases, and Support. A naive approach would place them all in a single target and let them import each other freely. At scale, this creates a dependency web where no module can be built, tested, or reasoned about in isolation. A change in one module can have ripple effects anywhere in the graph, and the build system compiles everything together even when only one module changed.

The alternative — making each feature an independent Swift Package target — enforces isolation at the compiler level. The question is what each target is permitted to depend on.

## Decision

Each feature is a separate `.library` product in `Package.swift`. Feature modules may only depend on the three foundation targets:

- `NetworkFoundation` — HTTP client, URL construction, error decoding
- `DesignSystem` — shared visual components and tokens
- `Common` — domain-agnostic utilities (currency formatting, date helpers, etc.)

No feature module may import another feature module. This rule is documented in a comment directly above the feature targets in `Package.swift` and enforced by the package graph: because no feature target lists another feature as a dependency, attempting an `import` between features produces a compile error.

## Consequences

**Positive**

- Each module compiles and tests independently. A change to Checkout does not force Store to recompile.
- Micro-apps (ADR-0005) can import a single feature target and run it in isolation without pulling in the full application graph.
- Modules can be extracted into separate Swift packages or Tuist projects at a later stage without restructuring dependencies.
- The allowed-dependency boundary is machine-enforceable, not just a convention.

**Negative**

- Features cannot share domain types directly. Cross-module events require the composition root to translate between types (see ADR-0003).
- Cross-module UI composition requires @ViewBuilder injection rather than a direct import (see ADR-0004).
- The composition root (AppModel) must import every feature; it will grow as features are added (see ADR-0002).
