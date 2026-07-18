# Agent Instructions

This file is read by AI coding agents (Claude Code, Cursor, GitHub Copilot, and others)
to understand the rules and conventions of this project. Follow every rule here before
generating or modifying any code.

---

## Navigation State

### Rule: one model, one destination property, one enum

Every model that owns navigation must express all reachable destinations as a single
optional enum property. No exceptions.

```swift
// ✅ Correct
@Observable final class FeatureModel {
    var destination: Destination?

    @CasePathable
    enum Destination {
        case detail(Item)
        case settings
        case error(AppError)
    }
}
```

### Rule: never use Bool properties or multiple optionals for navigation state

```swift
// ❌ Never add properties like these
var isShowingDetail    = false
var isShowingSettings  = false
var activeError: AppError? = nil
```

**Why:** n Bool properties create 2ⁿ representable states. Most are illegal. The type
system cannot prevent them and the codebase accumulates defensive-clearing code to work
around them. A single `Destination?` enum with n cases has exactly n+1 representable
states — nil and each case — all of which are valid. Illegal states become inexpressible.

### Rule: use swift-navigation case path bindings in views

Connect the destination enum to SwiftUI presentation APIs using `@CasePathable` bindings.
Do not extract Bool flags manually.

```swift
// ✅ Correct — all presentation types driven from one property
.navigationDestination(isPresented: Binding($model.destination.settings)) {
    SettingsView()
}
.sheet(item: $model.destination.error) { error in
    ErrorView(error: error)
}
.fullScreenCover(item: $model.destination.detail) { item in
    DetailView(item: item)
}

// ❌ Never derive presentation state by comparing against the enum manually
.sheet(isPresented: .constant(model.destination == .settings)) { ... }
```

### Rule: never use NavigationLink(destination:)

Use `.navigationDestination(item:)` or `.navigationDestination(isPresented:)` with a
model-driven binding. Hard-coded `NavigationLink` destinations bypass the model and make
the navigation state untestable.

---

## Snapshot Tests

### Rule: every new Destination case requires a snapshot test

When you add a new case to any `Destination` enum, you must:

1. Add the case to the `CaseIterable` conformance in the feature's test file
2. Write a named snapshot test for that destination
3. Run the tests once locally to record the baseline PNG
4. Commit the baseline PNG alongside the code change

```swift
// In FeatureTests/Sources/FeatureSnapshotTests.swift

extension FeatureModel.Destination: CaseIterable {
    public static var allCases: [FeatureModel.Destination] {
        [...existing cases..., .newCase(Item.stub)]
    }
}

@Test("New screen renders correctly")
func newScreen() async throws {
    let model = FeatureModel()
    model.destination = .newCase(Item.stub)
    assertSnapshot(
        of: FeatureView(model: model),
        as: .image(layout: .device(config: .iPhone13Pro)),
        named: "destination_new_case"
    )
}
```

### Rule: never set record: true in a committed test

`record: true` is for local baseline creation only. It must never appear in committed
code. CI runs with the default (`record: false`); a diverging snapshot is a test failure.

### Rule: stub repositories must use delay: .zero in tests

```swift
// ✅ Correct — resolves instantly so async state is testable
let model = FeatureModel(repository: StubFeatureRepository(delay: .zero))

// ❌ Never use a real or defaulted delay in a snapshot test
let model = FeatureModel(repository: StubFeatureRepository()) // default delay blocks
```

### Rule: do not write XCUITests for screens already covered by snapshots

XCUITests are reserved for flows that require a real app process: deep links, push
notifications, system permission dialogs, and cross-process interactions. If a screen
state can be set by mutating a model property, it must be covered by a snapshot test,
not an XCUITest.

---

## Dependency Injection

### Rule: models accept dependencies via protocol, never concrete types

```swift
// ✅ Correct — stub is the default; tests and previews work with zero configuration
init(repository: FeatureRepositoryProtocol = StubFeatureRepository()) { ... }

// ❌ Never inject a concrete type as a default
init(repository: LiveFeatureRepository = LiveFeatureRepository()) { ... }
```

Production implementations are injected at the composition root (`Shop/App/Sources`).
Feature modules must not reference live implementations.

---

## Module Boundaries

### Rule: feature modules must not import other feature modules

The dependency graph is strictly layered:

```
Shop/App  →  any feature module
Feature   →  Core/DesignSystem, Core/Common, Core/NetworkFoundation
Core      →  no feature deps
```

If you need to pass a type between two features, define it in `Core/Common`.
Cross-feature wiring belongs exclusively in `Shop/App/Sources`.

If you find yourself writing `import Search` inside `Checkout`, stop — that is an
architecture violation. Raise it before proceeding.

---

## What To Do When a Snapshot Test Fails

1. **Do not immediately update the baseline.** Understand why it changed first.
2. If the change is intentional (a deliberate UI update), re-record locally with
   `record: true`, verify the new PNG looks correct, then commit both the code and
   the updated PNG.
3. If the change is unintentional, fix the code — not the baseline.
4. A failing snapshot on a PR that has no intentional UI changes is a regression.
   Treat it as a build failure.

---

## File Naming for Other Tools

This file is named `AGENTS.md` for compatibility with OpenAI Codex-based agents.
The same content should be placed in the appropriate file for other tools:

| Tool | File |
|---|---|
| Claude Code | `CLAUDE.md` |
| Cursor | `.cursor/rules/conventions.mdc` |
| GitHub Copilot | `.github/copilot-instructions.md` |
| OpenAI Codex | `AGENTS.md` |

Keep the content identical across all files that exist in the project.
