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
    let model = FeatureModel(destination: .newCase(Item.stub))
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

## Module Public API

### Rule: a feature's public API is its repository protocol, its factory, and the data types those require — never the View

`some View` cannot be a protocol requirement's return type — only `associatedtype Body: View`
can, which is `View`'s own definition restated. A hand-written protocol for a SwiftUI view
inherits that same associated-type problem and cannot unify two concrete conforming types the
way a plain service protocol can. The seam belongs at the repository and the factory's
dependencies, never at the View.

```swift
// ✅ Correct — the View is a leaf, hidden behind the factory
public protocol CheckoutFactory {
    associatedtype CheckoutContent: View
    func makeCheckout() -> CheckoutContent
}

// ❌ Never — View can't be the seam
protocol CheckoutViewProtocol: View { }
```

### Rule: never use AnyView to make a view swappable for a test

```swift
// ✅ Correct
public func makeCheckout() -> some View { CheckoutView(model: checkoutModel) }

// ❌ Never
public func makeCheckout() -> AnyView { AnyView(CheckoutView(model: checkoutModel)) }
```

**Why:** `AnyView` erases exactly the static type information SwiftUI's diffing engine needs
to tell an update from a replacement — a real cost paid at every boundary, for a problem
`some View` on a concrete factory method already solves for free.

---

## @_spi Boundaries

### Rule: gate a model's designated initializer behind @_spi(Internals) once a factory exists

```swift
@_spi(Internals)
public init(dependencies: CheckoutDependencies) { /* ... */ }
```

Nothing outside the module should construct the model directly once its factory is the
intended entry point. Deleting the initializer would break the companion `XxxTesting` target
and composition-root snapshot tests, which have a legitimate reason to reach past the factory;
`@_spi` keeps it reachable for them specifically, without advertising it to everyone else.

### Rule: the composition root must never import a feature module via @_spi

```swift
// ✅ Correct — AppModel and RootView only ever see the factory
import Checkout

// ❌ Never — reaching past the factory from the one place that should never need to
@_spi(Internals) import Checkout
```

**Why:** `@_spi(Internals)`/`@_spi(Scenarios)` exist for the companion `XxxTesting` target and
a micro-app's scenario builder specifically — the factory's ordinary public API already
covers what the composition root needs. An `@_spi` import from `AppModel` or `RootView` means
something reached past the front door instead of through the factory.

---

## Dependency Injection

### Rule: models accept dependencies via protocol, never concrete types

```swift
// ✅ Correct — production init requires an explicit repository; no stub default
public init(repository: FeatureRepositoryProtocol, destination: Destination? = nil) { ... }

// In XxxTesting — convenience init supplies the stub so tests need no setup
convenience init(destination: Destination? = nil) {
    self.init(repository: StubFeatureRepository(), destination: destination)
}

// ❌ Never inject a concrete type as a default
init(repository: LiveFeatureRepository = LiveFeatureRepository()) { ... }

// ❌ Never put a stub default on the production init
init(repository: FeatureRepositoryProtocol = StubFeatureRepository()) { ... }
```

Production implementations are injected at the composition root (`Shop/App/Sources`).
The stub default lives in the companion `XxxTesting` target (ADR-0006).
Feature modules must not reference live implementations.

### Rule: package a module's dependencies as one explicit struct, not a shared god object

```swift
// ✅ Correct
public struct CheckoutDependencies {
    public let repository: CheckoutRepository
    public let selectedAddressStore: SelectedAddressStore?
}

// ❌ Never — one field per module, hiding which module actually needs what
public struct AppDependencies {
    public let checkoutRepository: CheckoutRepository
    public let accountRepository: AccountRepository
    // ...
}
```

**Why:** a shared dependencies object makes every module's test satisfy the whole shape to
exercise the one field it actually needs, and lets any module reach a dependency that was
never meant for it.

### Rule: a SwiftUI Environment value defined for one module's internal use stays internal, never promoted to a shared key

```swift
// ✅ Correct
private struct CheckoutCurrencyFormatterKey: EnvironmentKey { /* ... */ }
extension EnvironmentValues {
    var checkoutCurrencyFormatter: NumberFormatter { /* ... */ }   // not public
}

// ❌ Never — a global key any module can read or set
extension EnvironmentValues {
    public var appDependencies: AppDependencies { /* ... */ }
}
```

**Why:** an `EnvironmentKey` fails silently to its `defaultValue` when nobody sets it — there
is no compile error the way there is for a forgotten constructor argument. That is fine for a
formatter; it is the wrong place for anything a module actually depends on to behave
correctly. A global key also makes it reachable, and silently defaultable, from every module
rather than just the one that owns it.

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
