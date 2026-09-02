# ADR-0011: Each feature module's data layer is abstracted behind a repository protocol

**Date:** 2026-07-18  
**Status:** Accepted · amended 2026-08-31

## Context

Feature models need to load and persist data. Embedding network calls or UserDefaults access directly in a model makes the model untestable: a unit test would require a live network connection, and a snapshot test would depend on non-deterministic responses.

The standard solution is to abstract the data layer behind a protocol. The question is where to draw the boundary: at the level of individual data sources (network client, local cache, UserDefaults) or at a coarser level that groups them into a single interface per model.

## Decision

Each feature module defines a single `XxxRepository` protocol that expresses all data operations the module's model needs. The protocol sits in the feature's framework target alongside the model:

```swift
// In Store module
public protocol StoreRepository: Sendable {
    func fetchProducts(category: String?) async throws -> [StoreProduct]
    func fetchProduct(id: UUID) async throws -> StoreProduct
}
```

Note the name: the protocol is `StoreRepository`, not `StoreRepositoryProtocol`. Every feature module's
repository protocol was renamed to drop the `Protocol` suffix, following the Swift API Design
Guidelines' standard advice against restating a type's kind in its own name — a naming convention, not
an architectural decision, so it isn't recorded as its own ADR.

Three refinements this rule has grown:

- **A module with no data layer has no repository.** `Support`'s content is a static `SupportTopic`
  enum; it has no `SupportRepository`, no stub, no `SupportTesting` target, and `SupportModel.init()`
  takes no arguments. The rule is "abstract the data layer behind a protocol," not "every module
  gets a protocol."
- **A second, narrower protocol for a distinct persistence seam.** Where a module talks to the
  network *and* persists something locally, the local half is its own small protocol —
  `AddressStore` (Account), `OrderStore` (PastPurchases), `SelectedAddressStore` (Checkout) — each
  with a `UserDefaults`-backed conformer and an in-memory test conformer. This keeps `UserDefaults`
  out of the network repository and lets a test swap just the persistence.
- **`Checkout` keeps its protocol in a dependency-free `CheckoutAPI` target**, not the framework, so
  `CheckoutTesting` and the micro-app can import the contract without the implementation (ADR-0001,
  ADR-0016).

The framework target provides one concrete implementation — the live repository — which is the only type the production app uses. It may compose multiple internal data sources (remote and local cache) but those are implementation details, not part of the protocol:

```swift
public struct DefaultStoreRepository: StoreRepository {
    private let remote: RemoteStoreDataSource
    private let local  = LocalStoreDataSource()
    // ...
}
```

The live implementation carries the `Default` prefix precisely because the protocol claimed the plain
name — this is the same pattern `NetworkFoundation` uses for `NetworkClient`/`DefaultNetworkClient`.

The internal `RemoteXDataSource` is a plain `struct`, not a protocol with an implementation —
`Store`, `Account`, `Search`, and `Checkout` all do this. A protocol for the remote source is
introduced *only* when a genuine second implementation exists: `PastPurchases` has one
(`MockRemotePastPurchasesDataSource`, which derives order status deterministically from the order
date), so it — and only it — defines a `RemotePastPurchasesDataSource` protocol.

Note the second thing about this type: it's a `struct`, not a class. Every `DefaultXRepository` and its
internal `RemoteXDataSource` helper holds only `let` properties and delegates all mutation to whatever
it wraps — none of them have identity or state of their own to protect, so per [the Swift Programming
Language's own guidance](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/classesandstructures/)
("prefer structures because they're easier to reason about, and use classes when they're appropriate or
necessary — most of the custom types you define will be structures and enumerations"), struct is the
correct default here, not class. Where a repository's internal cache genuinely holds mutable state
accessed from concurrent `async` contexts (`LocalCache`, the in-memory cache `DefaultStoreRepository`'s
`local` property wraps), that state lives in an `actor`, not a class leaning on `@unchecked Sendable` —
an actor is the type built for exactly that problem. Like the naming convention above, this is a
language-standard default being followed correctly, not a project-specific architectural decision, so
it doesn't warrant its own ADR either — noted here only because the repository abstraction is the type
this default applies to most visibly in this codebase.

The stub implementation lives in the companion `XxxTesting` target (ADR-0006). Feature models accept the protocol as an injected dependency:

```swift
public final class StoreModel {
    private let repository: StoreRepository

    public init(repository: StoreRepository, destination: Destination? = nil) {
        self.repository = repository
        self.destination = destination
    }
}
```

The composition root (ADR-0002) constructs the live repository and injects it. Tests and micro-apps inject the stub.

## Consequences

**Positive**

- Feature models are fully testable without a network connection. Snapshot tests, unit tests, and micro-apps all use the stub.
- Swapping the data layer (e.g. replacing a REST backend with GraphQL, or adding an offline cache) requires only a new conforming type, not changes to the model or view.
- The protocol surface is minimal and intentional: it exposes only the operations the model requires, not every capability of the underlying network client.
- The `Sendable` conformance requirement on the protocol ensures all implementations are safe to use from async contexts.

**Negative**

- Every feature *with a data layer* requires a protocol, a live implementation, and a stub — three types per module. For simple modules this is overhead relative to the complexity being abstracted; `Support`, with no data layer, has none of them.
- The protocol is owned by the feature module, not a shared layer. If two modules need structurally identical operations (e.g. both fetch a paginated list), there is no reuse mechanism short of extracting a shared protocol to `Common`.
