# Proposal: Enforcing ShopApp Architecture Rules with Harmonize

Status: R1 to R3 implemented in `ArchitectureRules/` (uncommitted); R4 to R9 still proposal
Branch: `feature/architecture-rules`
Related: `docs/adr/` (ADR-0001 to ADR-0015), `CLAUDE.md`, `AGENTS.md`

## Summary

[Harmonize](https://github.com/perrystreetsoftware/Harmonize) is a Swift linter that expresses architecture rules as ordinary test code. It fits the ADRs that constrain how declarations are shaped: naming, inheritance, attributes, and the shape of `Destination` enums. It cannot express the import-graph rules (ADR-0001, 0003, 0014). Those remain enforced by the SwiftPM package graph, which is already the primary guarantee.

Recommendation: adopt Harmonize for declaration-level rules only, keep the package graph as the authority for module boundaries, and use a plain test for checks that need file paths or runtime behaviour.

## What Harmonize is

- Swift linter from Perry Street Software, Apache-2.0, beta (`2.0.0-beta.2`). Inspired by Konsist and ArchUnit.
- Rules are Swift tests (Quick or XCTest) built on selectors such as `Harmonize.productionCode().classes().withNameEndingWith("ViewModel")` and assertions `assertTrue`, `assertFalse`, `assertEmpty`.
- Each `Rule` carries `title`, `rationale`, `howToFix`, `badExample`, `goodExample`, so failures explain themselves, including to AI agents.
- Parses with SwiftSyntax, not regex.
- `baseline:` accepts known violations and errors when a baseline entry starts passing.
- Requires an empty `.harmonize.yaml` at the project root. `excludes:` is global.

## Constraints

1. **No documented import or file selector.** Public docs show class selection and the `inherits(from:)` predicate only. `files()`, `functions()`, `properties()` and any import inspection were not confirmed in the docs. Rules that depend on imports must stay with SwiftPM.
2. **Run environment is unverified for ShopApp.** Harmonize documents `swift test --package-path <rules-package>` for a standalone package, and `xcodebuild -sdk macosx` in CI. ShopApp is iOS-only and `CLAUDE.md` notes that macOS host builds fail. A standalone rules package should avoid that, but this needs a spike.
3. **Some rules need other tools.** File existence (ADR-0009), file-path predicates, and runtime behaviour (ADR-0015) need a plain XCTest alongside the rules.

## Candidate rules

| # | ADR | Proposed rule | Expressible in Harmonize | Current state |
|---|---|---|---|---|
| R1 | 0007 | Every feature model's `Destination` enum is `@CasePathable` | Yes (class and enum selection) | Holds for the 8 feature models and `AppModel`. Exception: `Core/DesignSystem/App/Sources/DesignSystemApp.swift`, which is a micro-app and not a model. Decide whether to scope it out. |
| R2 | 0012 | Every `@Observable` model is also `@MainActor` | Yes (attribute check) | Holds for all models |
| R3 | 0012 | No `ObservableObject` or `@Published` in feature code | Yes | Holds (no matches) |
| R4 | 0011 | Repository protocols are named `XxxRepository`, with no `Protocol` suffix | Yes (name predicate) | Holds (no `RepositoryProtocol` matches) |
| R5 | 0007, 0008 | No `Bool` navigation flags (`isShowing…`, `show…`) on models. Navigation goes through `destination` or `path`. | Partly (name and type predicates; the name set needs definition) | Holds for models. Only non-navigation `is…` computed properties were found. |
| R6 | 0006 | `Stub*` types are not declared in production targets | Probably, by name plus `excludes`. Unverified whether `productionCode()` already excludes Testing targets. | **Possible drift.** `Shop/App/Sources/ShopAppMain.swift:32-36` selects `StubStoreRepository`, `StubAccountRepository`, and others under an `isUITesting` flag. Not yet checked whether that file imports `*Testing` targets, which would ship stubs in the app. Verify before deciding. |
| R7 | 0002 | Only `ShopCore` references the live `Default*Repository` types | Yes, by name, if the naming is stable | Holds in feature code. `Shop/App` is the expected location. |
| R8 | 0014 | Feature models are built through their `XxxFactory` protocol and do not take concrete repositories | Partly | Not yet checked |
| R9 | 0009, 0010 | Each feature has a `XxxSnapshotTests.swift`, and its `Destination` has a `CaseIterable` extension in the test target | File existence: no (use plain XCTest). `CaseIterable` check: possible. | Not yet checked |

### Rules that stay outside Harmonize

- **ADR-0001, 0003, 0014 (import graph, cross-module callback types):** enforced by the SwiftPM package graph. Harmonize cannot see imports.
- **ADR-0013 (guard inside `load()`):** needs behavioural tests.
- **ADR-0015 (only `AppModel` reads `url.host`):** a plain text-scan test could enforce it, if wanted.

## Suggested spike

1. Done for R1 to R3: standalone rules package at `ArchitectureRules/` with an empty `.harmonize.yaml` at the repo root. Each rule links to its ADR in `rationale`. The package is named `ArchitectureRules` because a local directory named `Harmonize/` collides with the `harmonize` package identity and fails with "cyclic dependency". Rules use Swift Testing (`@Suite` / `@Test`), not XCTest or Quick.
2. Done: `swift test` in `ArchitectureRules/` runs 4 tests and they pass. Negative check: a temporary file with three violations failed all three rules, then was removed. Still open: whether CI needs `xcodebuild -sdk macosx`.
3. Decide on R6 after checking the imports in `Shop/App/Sources/ShopAppMain.swift`.
4. Per `CLAUDE.md`, any rule that changes module-boundary conventions must be mirrored in `AGENTS.md`, `.cursor/rules/conventions.mdc`, and `.github/copilot-instructions.md`.
5. Pin the Harmonize version, since it is beta. The bundled agent skill and Claude Code plugin are optional.

## Open questions

- Does Harmonize's `productionCode()` exclude Testing targets, and can it select by name prefix such as `Stub`?
- Can it run under `swift test` on the iOS-only package, or only on a macOS host?
- Is R6 an intentional UI-test seam, or a violation of ADR-0006?
