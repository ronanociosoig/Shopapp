# ADR-0012: Feature models use @Observable, not ObservableObject

**Date:** 2026-07-18  
**Status:** Accepted · amended 2026-08-31

## Context

SwiftUI views need to re-render when model state changes. The established pattern before iOS 17 was `ObservableObject` with `@Published` properties, accessed from views via `@ObservedObject` or `@StateObject`. This approach has two friction points:

1. **Coarse invalidation.** Any `@Published` change triggers re-render for all views observing the object, even if they only read properties that did not change. Granular re-renders require manual splitting into smaller objects.
2. **Boilerplate.** Every observable property requires `@Published`. Forgetting the annotation causes silent failures where the view does not update.

iOS 17 introduced the `Observation` framework with the `@Observable` macro, which tracks property access at a finer granularity and eliminates the per-property annotation.

## Decision

All feature models are marked `@Observable` **and `@MainActor`**:

```swift
@MainActor
@Observable
public final class StoreModel {
    var loadState: StoreLoadState = .idle
    var selectedCategory: String?
    var destination: Destination?
    // ...
}
```

Models exist to be read and mutated from SwiftUI views, which are already main-actor-isolated, so whole-class `@MainActor` is the honest default: `load()` and every state transition are safe by construction, with no per-method `@MainActor` annotations to keep in sync. `AppModel` and all eight feature models follow this uniformly. Async work *inside* a model (`Task { await repository.… }`) still runs off the main actor — only the model's own state access is serialised. A `@MainActor` model means a test that touches it runs in a `@MainActor` suite (`@Suite … @MainActor struct XxxModelTests`).

Views access the model directly, without a property wrapper:

```swift
struct StoreView: View {
    @Bindable var model: StoreModel
    // ...
}
```

`@Bindable` is used where the view needs a two-way binding into the model (e.g. `$model.destination`). For read-only access, no wrapper is needed at all — `@Observable` models passed as `let` or `var` properties are tracked automatically.

The project targets iOS 17 as its minimum deployment target, which makes `@Observable` available unconditionally. There is no need to maintain an `ObservableObject` fallback.

## Consequences

**Positive**

- Re-renders are scoped to the specific properties a view reads. A view observing only `model.loadState` does not re-render when `model.destination` changes.
- No `@Published` annotations — any stored property is tracked automatically. Adding a property to the model does not require remembering an annotation.
- `@Observable` models are plain classes, straightforward to construct and inject in tests without SwiftUI infrastructure.
- `@Bindable` is explicit: a view signals at its declaration site that it needs write access to the model, as opposed to `@ObservedObject` which always provides it.
- Whole-class `@MainActor` serialises every state transition without per-method annotation, and makes the model's concurrency contract identical across all eight features.

**Negative**

- `@Observable` requires iOS 17. Projects supporting earlier versions must maintain a parallel `ObservableObject` implementation or use a compatibility shim.
- The `@Observable` macro is a source transformation that can obscure synthesised code during debugging. Property access tracking happens behind the scenes.
- `@Observable` classes cannot currently be used with `@StateObject`; views that need to own the model's lifetime use `@State` with `@Observable` types directly.
