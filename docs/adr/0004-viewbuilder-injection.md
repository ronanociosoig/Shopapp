# ADR-0004: Cross-module UI is injected via @ViewBuilder generics, not imports

**Date:** 2026-07-18  
**Status:** Accepted

## Context

`StoreView` needs to embed two pieces of UI that live in other modules: a row of product suggestions from the Suggestions module, and a promotion banner strip from the Promotions module. Under the isolation rule (ADR-0001), Store cannot import either of these modules.

Two approaches were considered:

1. **Shared view protocol in Common.** Define `SuggestionRowView: View` as a protocol in `Common` that `Suggestions` conforms to and `Store` accepts. This adds protocol maintenance overhead and still requires coordination across module boundaries whenever the interface changes.
2. **@ViewBuilder generic injection.** Make `StoreView` generic over opaque `View` types. The call site in the composition root passes the concrete views. `Store` knows nothing about their types.

## Decision

`StoreView` is generic over two `View` type parameters:

```swift
public struct StoreView<SuggestionRow: View, PromotionBanner: View>: View {
    private let suggestionRow:   () -> SuggestionRow
    private let promotionBanner: () -> PromotionBanner

    public init(
        model: StoreModel,
        @ViewBuilder suggestionRow:   @escaping () -> SuggestionRow,
        @ViewBuilder promotionBanner: @escaping () -> PromotionBanner
    )
}
```

Convenience extensions with `EmptyView` defaults cover the cases where one or both slots are unused — the micro-app, snapshot tests, and DesignSystem catalog can all use `StoreView(model:)` without supplying views from other modules.

The composition root in `RootView` supplies the concrete types:

```swift
StoreView(model: model.storeModel) {
    SuggestionsRow(model: model.suggestionsModel)
} promotionBanner: {
    PromotionBannerView(model: model.promotionsModel)
}
```

## Consequences

**Positive**

- `Store`, `Suggestions`, and `Promotions` remain fully independent. None imports the other.
- Adding or removing an injection slot in `StoreView` is a compiler-enforced change: all call sites must be updated.
- Micro-apps and tests can use `StoreView(model:)` without needing stub implementations of the injected views.
- The pattern extends naturally to any feature view that hosts content from other modules.

**Negative**

- The generic parameters appear in the type signature everywhere `StoreView` is used, which adds visual noise.
- The number of type parameters grows if more injection slots are added. Beyond two or three, the signature becomes unwieldy.
- The composition root must know about all injection relationships; this is consistent with ADR-0002 but does concentrate knowledge there.
