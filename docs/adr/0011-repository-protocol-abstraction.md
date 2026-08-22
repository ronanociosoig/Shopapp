# ADR-0011: Each feature module's data layer is abstracted behind a repository protocol

**Date:** 2026-07-18  
**Status:** Accepted

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

The framework target provides one concrete implementation — the live repository — which is the only type the production app uses. It may compose multiple internal data sources (remote and local cache) but those are implementation details, not part of the protocol:

```swift
public final class DefaultStoreRepository: StoreRepository {
    private let remote: RemoteStoreDataSource
    private let local  = LocalStoreDataSource()
    // ...
}
```

The live implementation carries the `Default` prefix precisely because the protocol claimed the plain
name — this is the same pattern `NetworkFoundation` uses for `NetworkClient`/`DefaultNetworkClient`.

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

- Every feature requires a protocol, a live implementation, and a stub. For simple modules, this is overhead relative to the complexity being abstracted.
- The protocol is owned by the feature module, not a shared layer. If two modules need structurally identical operations (e.g. both fetch a paginated list), there is no reuse mechanism short of extracting a shared protocol to `Common`.
