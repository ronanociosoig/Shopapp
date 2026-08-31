# Design Patterns in a Modern Swift iOS Application

**Status:** Living document
**Scope:** The Gang of Four (GoF) catalog, plus the non-GoF patterns that do more structural work in
this codebase than most of the GoF set does.
**Reference implementation:** every example in this document is real code from ShopApp. File paths are
given so you can read the pattern in situ, not in the abstract.

---

## Why this document exists

Swift developers already have good material for learning the design patterns in isolation:

- **[Hacking with Swift — *Design Patterns*](https://www.hackingwithswift.com/books/design-patterns)**
  — Paul Hudson's free online book. Hacking with Swift is an essential reference for Swift
  developers; tens of thousands use it, and its pattern write-ups are current, idiomatic, and
  clearly explained. Read it for the canonical form of a pattern.
- **[refactoring.guru](https://refactoring.guru/design-patterns/swift)** — strong on intent and
  structure across languages. Its Swift sample code is dated, though: reference-heavy class
  hierarchies and completion handlers, written before `async/await`, actors, `@Observable`, and
  value-type-first Swift.
- The original *Design Patterns* book (1994, C++/Smalltalk), and a number of other Swift blogs,
  courses, and talks — too many to list, several of them good.

This document does not replace any of them — Hacking with Swift's book alone covers far more of the
catalog than the entries here. It trades breadth for a different axis: **every example is a pattern
as it is actually used in one coherent large app**, not an example constructed to teach the pattern.
ShopApp is eight modules with compiler-enforced boundaries, built from the start as a reference —
there is no legacy layer, no "we'd do this differently now," no bad habit encoded in a file nobody
wants to touch. The code shown here is meant to be *copied*: when Adapter appears as a closure typed
on Foundation primitives, that is how the pattern should be written in this codebase, and the other
seven modules write it the same way.

It also answers a question the teaching resources don't: **not "what is the Adapter pattern," but
"where does it actually appear in a real multi-module app, what does it cost, and when does reaching
for it make the code worse."** Several patterns are marked **not used**, with a one-line reason and
no contrived example to fill the gap — an honest "this hasn't come up" teaches a better instinct
than a strained slot-filler.

**Who this is for.** Developers who already know the industry-standard patterns — often from Java,
C#, or C++ — and would reach for their textbook form in Swift. Swift usually applies the same
pattern in a different shape: a `struct` behind a protocol where the diagram shows a class
hierarchy, an `enum` where it shows a `State` interface, a closure where it shows a `Command`
object. Existing pattern knowledge transfers in intent, not always in structure; this document is
where to recalibrate the structure.

Three ideas shape every entry:

1. **Modern Swift subsumes or reshapes many GoF patterns.** `async/await`, actors, `@Observable`,
   `some`/`any`, macros, and a value-type-first idiom mean the 1994 class-diagram form is often not
   the right Swift form — sometimes the whole pattern collapses into one language feature. Each
   entry gives the idiom as it actually appears, not the diagram.

2. **"Which pattern is this?" is the wrong question.** The catalog is a set of names for shapes that
   recur. Naming the shape does not improve the code. The question that does: *what change do I
   expect, and does this structure make that change local?* A pattern applied without a specific
   expected axis of change is just ceremony — extra indirection with no payoff.

3. **A pattern can be right in the book and wrong in your app.** Singleton is in every catalog. It
   is almost always the wrong call in an app you want to test. This document says so, and names the
   alternative the codebase actually uses.

So each entry answers: *is this in ShopApp, where, what does the modern Swift form look like, when
should you reach for it, and when will reaching for it make things worse.*

---

## How ShopApp is organized (context for the examples)

```
Shop/App              the @main entry point; picks live vs. stub repositories
  └─ ShopCore          composition root: AppModel + RootView. The ONLY target that imports every feature.
       ├─ Store  Account  Search  Checkout  Support  Suggestions  Promotions  PastPurchases
       │        8 feature modules. None imports another — a forbidden import is a compile error.
       │        tools/GraphTool ('graph-tool check' vs allowed-dependencies.json) can verify the
       │        rule as a standalone command; it is not yet wired into CI.
       └─ NetworkFoundation  DesignSystem  Common
                Foundation layer. No feature dependencies.
```

Each feature module is four SPM targets: `Framework` (production), `Testing` (stub repository +
convenience initializers), `Tests`, and `App` (a standalone micro-app). `Checkout` additionally
splits a dependency-free `CheckoutAPI` target for its shared value types.

Every feature **model** has the same shape:

```swift
@Observable
public final class StoreModel {
    var destination: Destination?               // one navigation type, an enum (ADR-0007)
    private let repository: StoreRepository     // injected, no default (ADR-0011)

    public init(repository: StoreRepository, destination: Destination? = nil) { … }

    @CasePathable
    public enum Destination: Equatable, Sendable {
        case productDetail(StoreProduct)
        case categoryFilter
    }
}
```

That uniformity is what makes the pattern analysis below meaningful: when eight modules do the same
thing the same way, a deviation is a signal.

---

## Reading guide

Each entry uses this template:

| Field | Meaning |
|---|---|
| **Intent** | One sentence, paraphrased from GoF where applicable. |
| **Status** | `Used` · `Used (framework-provided)` · `Partially used` · `Not currently used`. |
| **Where** | Real file references in this repo, or `—`. |
| **Modern Swift form** | The idiom as it actually appears, not the 1994 class diagram. |
| **Reach for it when** | The specific expected change that makes the indirection pay. |
| **Don't, when** | The misfire this pattern invites. |
| **Divergence** | Where this document's advice differs from Refactoring Guru's Swift page, and why. |

---

# Creational patterns

## Factory Method

**Intent.** Defer the choice of which concrete object to create to a dedicated method, so callers
don't name concrete types.

**Status.** Used — but in four different spellings, which is itself worth studying (see *Divergence*).

**Where.**
- `Features/*/Testing/Sources/*ModelTestSupport.swift` — a `convenience init` on each model that
  defaults the repository to the module's stub:
  ```swift
  public extension StoreModel {
      convenience init(destination: Destination? = nil) {
          self.init(repository: StubStoreRepository(), destination: destination)
      }
  }
  ```
- `Features/Search/App/Sources/SearchScenario.swift` — `SearchScenarioFactory.makeModel(for:)` maps a
  `SearchScenario` enum case to a fully-configured `SearchModel`.
- `Features/Checkout/App/Sources/CheckoutScenario.swift` — `CheckoutScenarioFactory.makeModel(for:)`,
  same idea for Checkout.
- `Features/PastPurchases/Framework/Sources/Repository/PastPurchasesRepository.swift` —
  `DefaultPastPurchasesRepository.mock()`, a static factory returning the live repository wired to a
  mock remote data source.

**Modern Swift form.** A free function, a `static func`, or a `convenience init` — not a
`Creator` protocol with `factoryMethod()` overridden per subclass. Swift's initializers *are*
factory methods; a `convenience init` that picks a default collaborator covers most of what the GoF
pattern is for. When the choice is driven by data (an enum of scenarios), a `struct` with one
`make(for:)` method reads better than an initializer with a giant `switch`.

**Reach for it when.** Constructing the object correctly takes several steps or a collaborator the
caller shouldn't have to know about, and you want that knowledge in exactly one place.

**Don't, when.** The "factory" only forwards its arguments to an initializer with no added decision
or assembly — then it's a rename, not a pattern. Call the initializer.

**Divergence.** Refactoring Guru models this as an abstract `Creator` class with subclasses. In Swift
that hierarchy is almost never worth it — you pay for a class, inheritance, and dynamic dispatch to
express "pick a type," which a `static func` returning a protocol existential (`some StoreRepository`)
does for free. Also note the honest problem in *this* codebase: **four mechanisms for "build a model
already in a displayable state"** (`convenience init` in `Testing`; a second public `convenience
init` in `SearchModel` itself; an `@_spi(Scenarios)` init in `CheckoutModel`; the `*ScenarioFactory`
types). Each is individually defensible; collectively they're a convergence opportunity, tracked as a
candidate ADR. A reference project should show the seam, not paper over it.

---

## Abstract Factory

**Intent.** Produce families of related objects (here: a matched set of repositories — all live, or
all deterministic) behind one interface, so the whole family swaps together.

**Status.** Not currently used as a formal pattern.

**Where.** The informal stand-in is in `Shop/App/Sources/ShopAppMain.swift`:

```swift
let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
appModel = AppModel(
    storeRepository:  isUITesting ? StubStoreRepository()   : DefaultStoreRepository(),
    accountRepository: isUITesting ? StubAccountRepository() : DefaultAccountRepository(),
    …
)
```

**Why it hasn't been formalized.** The family has exactly two members (live, UI-testing) and one
call site. A `RepositoryProviding` protocol with `LiveRepositories` and `UITestRepositories`
conformers would remove the repeated ternary, but at this size the ternary is legible and the
protocol is overhead. The trigger to introduce it: a third environment (a demo build, a
record-fixtures build) or a second call site needing the same set. Until then, noting the absence is
the right move.

**Divergence.** Refactoring Guru's advice ("use it when your code needs to work with various families
of related products") is directionally fine but silent on the cost. In Swift the cost is a protocol
with N methods returning existentials, plus a conformer per environment — real code to maintain. Two
members and one call site do not clear that bar.

---

## Builder

**Intent.** Separate the construction of a complex object from its representation, assembling it
step by step, so the same process can produce different results.

**Status.** Not currently used.

**"Builder" is the most misapplied name in the catalog.** A type with a single `build()` or
`make(…)` that takes its inputs and returns a finished object in one call is a **Factory**, not a
Builder — regardless of what it's called. The Builder pattern specifically requires *incremental
assembly*: a mutable, partially-built instance that successive calls refine (usually through a
fluent interface, sometimes coordinated by a director), where the payoff is step-by-step
configuration the caller drives or validation that spans steps. No partially-built state means it
isn't a Builder. This is worth stating because `SomethingBuilder` gets reached for as a generic
label for "a type that produces another type," which is Factory Method's job. In this codebase the
scenario constructors (`SearchScenarioFactory`, `CheckoutScenarioFactory`) map one enum case to one
finished model in a single call — Factory Methods, and named as such.

**When a real Builder would be justified here.** `CheckoutModel`'s `@_spi(Scenarios)` initializer
already has seven parameters (`cart`, `path`, `destination`, `savedAddresses`, `deliveryOption`,
`extendedGuaranteeItems`, `repository`). If that list keeps growing, or if intermediate validation
between steps becomes necessary (e.g. "you can't set `path` to `.paymentEntry` for an address absent
from `savedAddresses`"), a builder with a `build() throws` that enforces the invariant would earn its
keep. Today the initializer plus `@_spi` gating is enough.

**Divergence.** Refactoring Guru's Swift example builds a `Car` and a manual with parallel builders
and a director. In Swift, a value type with defaulted parameters and a `throws` initializer covers
the common case; parameter packs and result builders cover the exotic case. A director class
coordinating separate builder objects is rarely the shape you want.

---

## Prototype

**Intent.** Create new objects by copying an existing configured instance rather than constructing
from scratch.

**Status.** Not currently used — and largely pre-empted by the language.

**Why.** Swift value types copy on assignment. `StoreProduct.stubs` / `ShippingAddress.stub` in the
`*Testing` targets are shared exemplars, and every use site that mutates one gets an independent copy
for free — that's the *result* Prototype exists to produce, without a `clone()` method or a prototype
registry. Prototype earns its place in a language where copying is expensive or where you're cloning
a live object graph with reference identity; neither applies here.

**Divergence.** Refactoring Guru implements `NSCopying`-style `clone()`. For a `struct`, `clone()` is
`let copy = original` followed by mutation. Don't add the ceremony.

---

## Singleton

**Intent.** Guarantee one instance and a global access point.

**Status.** Deliberately avoided in application code.

**Where the discipline shows.** Nothing in `Shop`, `ShopCore`, or any feature module is a singleton.
The ambient singletons that *do* get touched — `URLSession.shared`, `UserDefaults.standard` — are
never referenced directly by a model. They're constructor parameters with a default:

```swift
public init(client: NetworkClient = DefaultNetworkClient()) { … }         // NetworkClient.swift
public init(defaults: UserDefaults = .standard, key: String) { … }        // UserDefaultsStore.swift
```

So production is a one-liner, and a test injects a `MockNetworkClient` or a scratch `UserDefaults`
without touching global state.

**Reach for it when.** Almost never in an app target. The legitimate cases are process-wide
resources the OS itself models as singletons (the file system, the keychain), and even those are
better wrapped in an injectable protocol.

**Don't, when.** You want "convenient access from anywhere." That convenience is exactly what makes
the object impossible to isolate in a test and impossible to reason about as a dependency. Every
`.shared` you add is a hidden edge in the dependency graph.

**Divergence.** Refactoring Guru presents Singleton neutrally with a thread-safety note. This
document's position is stronger: in an app you intend to test, a mutable singleton is a defect in
waiting. Inject it.

---

# Structural patterns

## Adapter

**Intent.** Convert one type's interface into another that a client expects, so two components that
weren't designed together can collaborate.

**Status.** Used — and it is the single most consistently applied pattern in the codebase.

**Where.** Every cross-module type conversion lives at the composition root, `Shop/Framework/Sources/AppModel.swift`:

```swift
// Store speaks Foundation primitives; Checkout speaks CheckoutProduct. The closure is the adapter.
storeModel.onAddToCart = { id, name, price, wantsGuarantee in
    let product = CheckoutProduct(id: id, name: name, price: price,
                                  supportsExtendedGuarantee: wantsGuarantee)
    checkoutModel.addToCart(product)
}

// syncAddresses() adapts Account's SavedAddress list into Checkout's ShippingAddress list.
public func syncAddresses() {
    checkoutModel.savedAddresses = accountModel.addresses.map { a in
        ShippingAddress(id: a.id, fullName: a.fullName, line1: a.line1, /* … */ isDefault: a.isDefault)
    }
}
```

`onOrderPlaced` (Checkout's `PlacedOrder` → PastPurchases' `PastOrder`) and `onRepeatOrder`
(`PastOrder` lines → `CheckoutProduct`s) are the same shape.

**Modern Swift form.** A closure, not an `Adaptee`-wrapping class. The feature exposes a callback
typed *only* in Foundation primitives (`((UUID, String, Decimal, Bool) -> Void)?`); the composition
root supplies a closure that does the domain-type conversion. The adapter is a few lines assigned at
wiring time, and it lives in the one module allowed to see both sides.

**Reach for it when.** Two modules must exchange data but must not depend on each other's types
(ADR-0001, ADR-0003). The adapter is the price of module isolation, and it's a price worth paying:
the alternative is `import Checkout` inside `Store`, which the package graph rejects at compile time.

**Don't, when.** Both types are already in the same module and you could just add a method or an
`init`. An adapter between two types you own and can edit is usually a missing initializer.

**Divergence.** Refactoring Guru's Swift example wraps a third-party class in an adapter class
conforming to your protocol. That's still valid for genuine third-party types. For *your own* modules,
the closure-typed-on-primitives form here is lighter and keeps the conversion out of both features'
public surfaces.

---

## Bridge

**Intent.** Split an abstraction from its implementation so the two vary independently.

**Status.** Used, uniformly, as the repository layer — and nested one level deeper in two modules.

**Where.**
- **Abstraction:** each feature model depends on a `protocol XxxRepository: Sendable`
  (`Features/*/Framework/Sources/Repository/*Repository.swift`).
- **Implementations, varying independently:** `DefaultStoreRepository` (live network + cache),
  `StubStoreRepository` (in-memory, in `*Testing`), and — for the Replay-backed modules — the same
  `Default*Repository` driven by recorded HAR fixtures. The model doesn't change when the
  implementation does.
- **Nested Bridge:** `DefaultSearchRepository` and `DefaultPastPurchasesRepository` further abstract
  their *remote* half behind `protocol RemoteSearchDataSource` / `RemotePastPurchasesDataSource`,
  with `Default…` and `Mock…` conformers. `Store`, `Account`, and `Checkout` do not — their remote
  data source is a bare concrete `struct`. That's a real inconsistency; the nested protocol is worth
  it only where a `Mock` remote is actually used (PastPurchases' date-derived status simulation),
  and premature elsewhere.

**Modern Swift form.** A protocol with `Sendable` conformance and `async throws` methods, injected via
`init`. The "abstraction" side is the calling model; the "implementor" side is the conforming
`struct`. No `Implementor` base class, no explicit delegation field — the protocol existential
(`any StoreRepository`) or generic parameter is the bridge.

**Reach for it when.** You expect the *how* of a capability to change (REST today, GraphQL later; live
vs. recorded vs. in-memory) without the *what* changing. That's precisely the repository situation.

**Don't, when.** There's one implementation and there will only ever be one. A protocol with a single
conformer that isn't a test double is a layer of indirection with no second axis — you can add the
protocol the day the second implementation appears.

**Divergence.** Refactoring Guru draws Bridge and Strategy as different UML. In idiomatic Swift they
collapse to the same construct — *inject a protocol* — and the distinction is intent, not code:
Bridge is "two hierarchies evolve separately," Strategy is "swap one algorithm." This document treats
"inject a `Sendable` protocol with no production default" as one technique and doesn't split hairs
over which UML it matches.

---

## Facade

**Intent.** Provide one simple interface over a subsystem of several collaborating parts.

**Status.** Used at three distinct scales.

**Where.**
- `Core/Common/Framework/Sources/RemoteDataSourceHelper.swift` — a facade over `URLRequest`
  construction, `NetworkClient`, and `JSONDecoder`. Its doc comment records that it replaced the
  decode/encode boilerplate previously copied into every module's remote data source:
  
  ```swift
  public func get<T: Decodable>(_ path: String) async throws -> T {
      let (data, _) = try await client.data(for: URLRequest(url: baseURL.appending(path: path)))
      return try JSONDecoder().decode(T.self, from: data)
  }
  ```
- `DefaultStoreRepository` — a facade over `RemoteStoreDataSource` + `LocalStoreDataSource`; callers
  see `fetchProducts(category:)`, not the cache-check-then-network dance.
- `AppModel` — a facade over eight feature models and all their wiring; `RootView` receives one
  object.

**Reach for it when.** A recurring task touches three or more collaborators in a fixed sequence, and
callers keep re-implementing that sequence. The facade is where the sequence lives once.

**Don't, when.** The "subsystem" is one object. A facade over a single type is a pass-through.

**Divergence.** None substantive. Note only that a Swift facade is usually a `struct` with methods,
not a class, and that `RemoteDataSourceHelper` being generic over the decoded type (`get<T: Decodable>`)
is what keeps it a facade rather than a leaky base class.

---

## Proxy

**Intent.** Stand in for another object to control access to it — here, to add caching without the
caller knowing.

**Status.** Partially used — a caching proxy in three of the fetch-heavy repositories, plus a
protection proxy in the network layer.

**Where.**

- `LocalStoreDataSource`, `LocalSearchDataSource`, `LocalAccountDataSource` each wrap a
  `Common.LocalCache` (an `actor`) and are consulted before the network:
  
  ```swift
  public func fetchProducts(category: String?) async throws -> [StoreProduct] {
      if let cached = await local.cachedProducts(category: category) { return cached }
      let products = try await remote.fetchProducts(category: category)
      await local.store(products, category: category)
      return products
  }
  ```
- `Promotions`, `Suggestions`, `Support` repositories do **not** cache — undocumented, and arguably
  fine (promotions and suggestions want freshness) but it reads as drift rather than decision.
- `PastPurchases` is different again: its `OrderStore` is a write-through *persistence* layer, not a
  read cache — source of truth, not an accelerator.
- `Core/NetworkFoundation/Framework/Sources/NetworkClient.swift` — `UnimplementedNetworkClient`
  (`fatalError` on use) is a **protection proxy**: it satisfies the type requirement while
  guaranteeing a test that forgot to inject a real client fails loudly instead of hitting the
  network.

**Modern Swift form.** The proxy conforms to the same protocol as its target and holds it as a
private field. When the proxied state is mutable and touched from concurrent `async` contexts, the
storage is an `actor` (`LocalCache`), not a `class` with `@unchecked Sendable` — the actor *is* the
access control the pattern is about.

**Reach for it when.** You want to intercept every call to an object for caching, logging, access
checks, or lazy instantiation, and the caller should stay oblivious.

**Don't, when.** Only some call sites need the interception — then it's a decorator applied
selectively, or just a method on the caller. Also don't reach for it to add caching the network
layer (`URLCache`) already does; check first.

**Divergence.** Refactoring Guru's Swift proxy is a class implementing the subject protocol and
forwarding. Same idea here, with two modern refinements: the forwarded protocol is `Sendable`, and
the cache behind it is actor-isolated rather than lock-guarded.

---

## Decorator

**Intent.** Attach responsibilities to an object dynamically by wrapping it in another object of the
same type.

**Status.** Used, but framework-provided — not hand-authored in app code.

**Where.** Every SwiftUI modifier chain is Decorator: `.badge(model.checkoutModel.itemCount)`,
`.interactiveDismissDisabled()`, `.tabItem { … }` in `RootView.swift` each wrap a view in a new view
that adds one behavior. `ViewModifier` is the pattern's explicit hook, though this codebase currently
composes built-in modifiers rather than defining its own.

**Where it could legitimately appear next.** If cross-cutting behavior needed to wrap a *repository*
— e.g. a `LoggingRepository<Wrapped: StoreRepository>` that logs every call and forwards — that's a
decorator, distinct from the caching proxy above only by intent (add a side effect vs. control
access). None exists today; noting the absence rather than inventing one.

**Divergence.** Refactoring Guru stacks decorator classes over a `DataSource`. In Swift, prefer:
(a) protocol extensions for behavior every conformer should have; (b) a generic wrapper `struct` over
`some Protocol` for opt-in behavior; (c) `ViewModifier` for views. A tower of wrapper classes is the
last resort, not the default.

---

## Composite

**Intent.** Treat individual objects and compositions of objects uniformly through a shared
interface.

**Status.** Used, framework-provided, and leaned into deliberately at module boundaries.

**Where.** SwiftUI's `View` is the composite type — a `Button` and a `VStack` of a hundred views are
both `some View`. This codebase's specific use is **generic `@ViewBuilder` injection** so one
feature's view can host another's without importing it
(`Features/Store/Framework/Sources/StoreView.swift`):

```swift
public struct StoreView<SuggestionRow: View, PromotionBanner: View>: View {
    private let suggestionRow:   () -> SuggestionRow
    private let promotionBanner: () -> PromotionBanner
    // RootView supplies the real SuggestionsView / PromotionBannerView;
    // the micro-app supplies EmptyView via a constrained extension.
}
```

The `where SuggestionRow == EmptyView` extensions let the same view collapse to a simpler
composite when a slot isn't filled.

**Reach for it when.** A container should not know or care whether a child is a leaf or another
container — and, in this codebase specifically, when a view needs to embed UI from a module it's
forbidden to depend on. The generic slot is the seam.

**Don't, when.** You're tempted to make a non-recursive data structure conform to a `Component`
protocol just to match the UML. Composite is for genuinely tree-shaped things.

**Divergence.** Refactoring Guru builds a `Component` protocol with `add`/`remove`/`operation`. SwiftUI
already gives you that; the interesting Swift move is using *generics + `@ViewBuilder` + constrained
extensions* to make optional composite slots ergonomic, which the book's era couldn't express.

---

## Flyweight

**Intent.** Share fine-grained objects to avoid the memory cost of many near-identical instances.

**Status.** Not currently used.

**Why it hasn't come up.** ShopApp renders lists in the dozens, not the hundreds of thousands. The
framework already does the relevant sharing: `List`/`LazyVStack` recycle row views, and Swift string
literals and small `struct`s are cheap. Flyweight earns its complexity at a scale (particle systems,
text layout engines, tile maps) this app doesn't reach.

**Divergence.** Refactoring Guru's tree-rendering example is a fair illustration of the pattern and a
poor fit for typical app code. If your instinct on a normal screen is "I should intern these," measure
first — it's almost always not the bottleneck.

---

# Behavioral patterns

## Strategy

**Intent.** Define a family of interchangeable algorithms behind a common interface and let the
caller pick one.

**Status.** Used pervasively — it's the mechanism behind every injected dependency.

**Where.**
- Every `XxxRepository` protocol is a strategy for data access (live / stub / Replay).
- `NetworkClient` (`Default` / `Mock` / `Unimplemented`) is a strategy for HTTP.
- `SelectedAddressStore`, `AddressStore`, `OrderStore` are strategies for persistence, each with a
  `UserDefaults`-backed conformer and an in-memory test conformer.
- Small behavioral strategies too: `MockRemotePastPurchasesDataSource` derives order status
  *deterministically from the order's date* — a different algorithm than the live "ask the server"
  strategy, behind the same `RemotePastPurchasesDataSource` protocol.

**Modern Swift form.** A protocol parameter on `init` with **no default in the production
initializer** (ADR-0011). Defaults live only in the `*Testing` convenience initializers. The
production model literally cannot be constructed without someone choosing a strategy.

**Reach for it when.** A single decision point has two or more valid implementations and the choice
belongs to the caller or the environment (test vs. production, online vs. offline).

**Don't, when.** There's one algorithm. Wrapping one function in a one-conformer protocol "for
flexibility" is speculative generality — add the protocol when the second algorithm is real.

**Divergence.** Refactoring Guru uses a `Strategy` protocol with concrete `ConcreteStrategyA/B`
classes. Swift's refinement: the strategy is often just a closure (`onAddToCart`), or a `struct`
conforming to a `Sendable` protocol, and the "context" holds it as `let` — no setter, injected once.

---

## Observer

**Intent.** When one object changes state, everything depending on it is notified.

**Status.** Used — framework-provided for view updates, hand-rolled for one cross-module case.

**Where.**
- `@Observable` on every model + SwiftUI's dependency tracking is the primary Observer: a view that
  reads `model.destination` re-renders when it changes, with no `addObserver` call (ADR-0012).
- `RootView.swift` observes **signal properties** on `PastPurchasesModel` and translates them into
  app-level navigation:
  
  ```swift
  .onChange(of: model.pastPurchasesModel.shouldOpenSupport) { _, open in
      guard open else { return }
      model.destination = .support
      model.pastPurchasesModel.shouldOpenSupport = false   // consume the signal
  }
  ```
  `PastPurchasesModel` can't own "present the Support sheet" — that surface belongs to `AppModel` —
  so it raises a flag and the composition root, acting as observer, reacts and resets it.

**Modern Swift form.** `@Observable` (macro-generated observation), not `ObservableObject` +
`@Published`, and certainly not `NotificationCenter` or KVO for in-process model changes. For the
cross-module signal case, `.onChange(of:)` + a consumed boolean/optional is the whole mechanism.

**Reach for it when.** A change has an open-ended set of interested parties, or the producer must not
know its consumers. The signal-property variant specifically: when a model needs to *request*
something it has no authority to do itself.

**Don't, when.** There's exactly one consumer and the producer could just call it. `PastPurchasesModel`
carrying **four** signal properties + one callback is near that line — it's doing enough cross-cutting
coordination that some of it probably wants to be an explicit method on the mediator instead of a flag
the mediator polls.

**Divergence.** Refactoring Guru's Swift Observer is a manual `subscribers: [Observer]` array with
`notify()`. Do not write that in an app with `@Observable`. The manual list is for the rare
non-UI, non-Combine broadcast — and even then `AsyncStream` is usually the better tool now.

---

## State

**Intent.** Let an object alter its behavior when its internal state changes, as if it changed class.

**Status.** Namesake only — the *representation* is here, the *polymorphism* isn't, and that's the
right call.

**Where.** `StoreModel.StoreLoadState` and `SearchModel.SearchState`:

```swift
enum SearchState: Equatable {
    case idle
    case loading
    case results([SearchProduct])
    case empty
    case error(String)
}
```

The view `switch`es over this; there is no `SearchStateIdle` / `SearchStateLoading` type each with
its own `render()`. In Swift, an `enum` with associated values collapses the GoF State hierarchy into
one closed type — you lose per-state method dispatch but gain exhaustiveness checking, `Equatable`
for free, and no allocation.

**Reach for the full GoF State when.** Each state has substantial distinct behavior across *many*
methods, states are added by people who can't edit the original type, or transitions are complex
enough to want a state object that owns them. None of that holds for a load-state enum.

**Don't, when.** You have four states and one `switch`. The enum is the answer.

**Consistency note.** Only `Store` and `Search` model load-state as an enum, and they use *different
vocabularies* (`loaded`/`failed` vs. `results`/`error`, plus Search's explicit `empty`).
`Suggestions`, `Promotions`, `PastPurchases`, `Account` use `isLoading: Bool` + a `try?` that
silently swallows errors into an empty array. Same concern, three treatments — a convergence
candidate (see ADR-0013's own "Negative" section, which flags this).

**Divergence.** Refactoring Guru's Swift State is a protocol with a class per state and a `context`
that swaps them. This document's position: in Swift, reach for the enum first and only escalate to
state objects when the enum's `switch`es genuinely sprawl.

---

## Command

**Intent.** Turn a request into a first-class object, so it can be stored, queued, passed around, or
undone.

**Status.** Partially — the *data* half is used, the *behavior* half (execute/undo) deliberately
isn't.

**Where.** Navigation is modelled as reified requests:
- `Destination` enums carry their payload as a value: `.rateOrder(PastOrder)`, `.confirmation(PlacedOrder)`,
  `.productDetail(StoreProduct)`. A navigation request *is* a value you can construct, store, compare,
  and hand to a test.
- `CheckoutModel.path: [CheckoutStep]` is a command *list* — an ordered, inspectable history of
  funnel steps that `NavigationStack(path:)` renders, and that a test can set wholesale to teleport
  mid-funnel.

**Why no `execute()`/`undo()`.** The enum cases are inert data; SwiftUI's `NavigationStack` and
`.sheet(item:)` are the "invoker" that acts on them. Adding an `execute` would duplicate what the
framework already does. `undo` is `path.removeLast()`. The pattern is present exactly to the depth
that pays.

**Reach for full Command when.** You need undo/redo, a macro/replay system, or to serialize user
actions to a queue. If ShopApp grew an offline-mutation queue ("place this order when back online"),
that queue's entries would be real commands.

**Don't, when.** You're wrapping a single method call in a `Command` object with one `execute()` that
calls it. That's a closure with extra steps — use `() -> Void`.

**Divergence.** Refactoring Guru's Swift example wraps button taps in command objects. In SwiftUI a
button's action *is* a closure and needs no object. The valuable Swift form of Command is the
**enum-with-associated-values as a serializable request**, which the book predates.

---

## Iterator

**Intent.** Access elements of a collection sequentially without exposing its representation.

**Status.** Used two ways — the language's built-in, and one non-obvious structural use.

**Where.**
- `Sequence` / `IteratorProtocol` / `for-in` is the language default; no hand-rolled iterators exist
  or should.
- **Structural test coverage** (ADR-0010): every `Destination` enum and every micro-app `Scenario`
  enum conforms to `CaseIterable`, and tests iterate `.allCases`:
  
  ```swift
  // A snapshot test parametrized over every navigation destination.
  // Adding a case without adding it to the test is impossible — allCases covers it,
  // or the enum doesn't compile as CaseIterable.
  for destination in CheckoutModel.Destination.allCases { … }
  ```
  Here Iterator isn't about hiding a data structure — it's using compiler-synthesized enumeration to
  make "did you test the new case?" a build-time question instead of a review-time one.

**Reach for a custom iterator when.** You're exposing traversal over something that isn't already a
`Collection` (a tree, a paginated remote resource — `AsyncSequence` for the latter).

**Don't, when.** It's an `Array`. `for x in array`.

**Divergence.** Refactoring Guru implements `IteratorProtocol` by hand over a custom collection. Valid,
but rare in app code. The more transferable lesson is the `CaseIterable.allCases` trick for
structural coverage.

---

## Mediator

**Intent.** Define an object that encapsulates how a set of objects interact, so they don't refer to
each other directly.

**Status.** Used — this is the architectural backbone of the app.

**Where.** `AppModel` (`Shop/Framework/Sources/AppModel.swift`) + `RootView`
(`Shop/Framework/Sources/RootView.swift`) are the mediator. The eight feature models are the
colleagues. **No feature module imports another** — `import Search` inside `Checkout` is a compile
error, because no feature target lists another as a dependency. `tools/GraphTool`'s `check`
subcommand can additionally validate the graph against `allowed-dependencies.json` as a standalone
command (not currently run in CI).

All inter-colleague traffic routes through the mediator, via two mechanisms:
- **Compile-time wiring** in `AppModel.init` — primitive-typed closures (the Adapters above).
- **Run-time signal translation** in `RootView` — `.onChange` on colleague signal properties →
  `AppModel.Destination` assignments.

**Reach for it when.** You have N components with many-to-many communication and you're watching the
import graph turn into a mesh. Centralizing the wiring makes each colleague independently
buildable, testable, and runnable in its own micro-app.

**Don't, when.** Two components, one direction of communication. A mediator between two objects is
just a third object in the way. Also watch the failure mode this codebase is near: the mediator
accreting all the logic. `AppModel.init` is ~130 lines of wiring; if it keeps growing, the
translation closures want to become named types.

**Divergence.** Refactoring Guru's Swift Mediator is a protocol with `notify(sender:event:)` and
string/enum event names. This codebase's form is stronger-typed: closures with concrete primitive
signatures, and `.onChange` bindings to typed properties — no stringly-typed event bus. Enforcement
matters to this pattern: the mediator only works while "colleagues don't import each other" holds,
and here the package graph makes a violation a compile error. `graph-tool check` asserts the same
rule against `allowed-dependencies.json` explicitly; wiring it into CI would make the guarantee
legible rather than implicit.

---

## Chain of Responsibility

**Intent.** Pass a request along a chain of handlers until one handles it.

**Status.** Not currently used in application code.

**Why it hasn't come up.** The framework covers the cases that would otherwise need it: SwiftUI's
`.onOpenURL` / `.environment` propagation and the UIKit responder chain are both chains of
responsibility the app consumes rather than builds. ShopApp's own deep-link handling (see
`deep-linking.md`) is currently a single parser, not a chain.

**When it would appear.** If deep-link routing grew several independent handlers ("is this a product
URL? a promo code? a share link?") that each either claim a URL or pass it on, a handler chain would
be the natural shape. It's a plausible future, not a current need — so it's noted, not built.

**Divergence.** None — the pattern simply isn't exercised yet.

---

## Template Method

**Intent.** Define the skeleton of an algorithm in a base type, letting subtypes fill in specific
steps without changing the structure.

**Status.** Not used in its classic (base class + overridden steps) form. The composition-based
equivalent is used.

**Where the equivalent lives.** `RemoteDataSourceHelper.get<T: Decodable>` fixes the skeleton
(build request → `await` → decode `T`) and varies only the path and the decoded type via generics —
no subclass, no `override`. Similarly, the informal `load()` shape shared across models (`set
loading → await repository → assign result`) is a template *by convention*, copy-pasted rather than
inherited.

**Reach for real Template Method when.** You have a genuinely fixed multi-step algorithm with one or
two pluggable steps and the plug points are numerous enough that closures get unwieldy. In Swift,
reach for a **protocol extension** providing the skeleton with `protocol` requirements for the
variable steps — that's the idiomatic form, and it works for `struct`s.

**Don't, when.** The "template" is three lines. The shared `load()` shape is arguably *under*-DRY
right now (five near-copies), but the fix is a small generic helper or a protocol extension, not a
`ModelBase` class — inheritance for four lines of glue isn't worth the coupling.

**Divergence.** Refactoring Guru's Swift Template Method uses a base `class` with `fatalError()`
"abstract" methods. That pattern — runtime crashes standing in for missing compile-time
guarantees — is exactly what protocol requirements exist to prevent. Prefer a protocol extension.

---

## Visitor

**Intent.** Represent an operation to be performed on the elements of an object structure, letting you
add new operations without changing the elements.

**Status.** Not currently used.

**Why.** Visitor solves the "add operations without touching the types" side of the expression
problem, at the cost of making it hard to add new types. Swift `enum`s take the opposite trade
deliberately: they're *closed*, so adding a case is a compile error everywhere it matters (which
ADR-0010 turns into a feature), and adding an operation is just another `switch` or a new function —
no double-dispatch, no `accept(visitor:)`. For a codebase whose navigation and state types are all
closed enums, Visitor would fight the grain. `@CasePathable` case paths cover the ergonomic niceties
(extract/modify one case) without the ceremony.

**When it would appear.** A stable, rarely-extended node hierarchy with many *distinct*
operations layered on over time — an AST for a query language, a document model with export/validate/
render/diff passes. ShopApp has no such structure.

**Divergence.** Refactoring Guru's Swift Visitor is faithful to the book and rarely the right call in
Swift app code. If you reach for it, first ask whether a closed `enum` + free functions gets you
there with less machinery.

---

## Memento

**Intent.** Capture an object's internal state so it can be restored later, without exposing that
state.

**Status.** Minimal — state *is* externalized and restored, but not with true encapsulation.

**Where.** `UserDefaultsStore<T: Codable>`, `UserDefaultsSelectedAddressStore`, `UserDefaultsOrderStore`
persist model state as JSON and reload it on launch. `CheckoutModel.selectedAddressID` is
saved/restored across launches this way.

**Why it's "minimal."** A true Memento hands out an opaque token only the originator can read.
Here the persisted shape is just `Codable` fields — any code can decode `SavedAddress`. That's fine
for this app (the "caretaker" is `UserDefaults`, there's no adversarial access concern), but it means
what's used is "Codable snapshot + a persistence strategy," not the encapsulated-token pattern.

**Reach for full Memento when.** Undo/redo where snapshots must not leak internals, or where the
snapshot format must stay private so it can evolve freely.

**Divergence.** Refactoring Guru's Swift Memento uses `NSKeyedArchiver`. Modern Swift: `Codable` +
whatever store you inject (`UserDefaults`, a file, SwiftData). The originator/caretaker class split
is usually more structure than app persistence needs.

---

## Interpreter

**Intent.** Given a language, define a representation for its grammar and an interpreter that uses the
representation to interpret sentences in the language.

**Status.** Not currently used.

**Why it hasn't come up.** ShopApp has no user-facing expression language. Search is a plain query
string passed to the backend, not a parsed filter DSL.

**When it would appear.** If search grew a query syntax (`price:<100 category:audio in-stock`) parsed
and evaluated on-device, that grammar + evaluator would be an interpreter — most likely expressed in
Swift as an `indirect enum` for the AST plus an `eval` function, not the GoF class-per-production
hierarchy.

**Divergence.** None exercised. Note only that Swift's `indirect enum` is the natural AST
representation, replacing the book's `TerminalExpression`/`NonterminalExpression` classes.

---

# Patterns beyond the GoF set

The GoF catalog is 30 years old and predates the problems that dominate a modular Swift app: wiring,
testability boundaries, and keeping a large graph acyclic. These non-GoF patterns do more load-bearing
work here than half the catalog above.

## Composition Root

**Intent.** Assemble the entire object graph in exactly one place, as close to the entry point as
possible; everything else receives its dependencies.

**Where.** `Shop/App/Sources/ShopAppMain.swift` chooses concrete repositories; `AppModel.init` builds
every model and wires them. Nothing deeper in the graph calls a concrete initializer of another
layer. (ADR-0002.)

**Payoff.** `RootView` holds no navigation `@State` of its own, so the whole app's state is one
injectable `AppModel` — which is what makes composition-root snapshot tests possible.

## Ports and Adapters (Hexagonal)

**Intent.** The application core defines *ports* (protocols it needs); the outside world provides
*adapters* (conforming implementations). The core never depends on I/O.

**Where.** `XxxRepository`, `NetworkClient`, `AddressStore`, `OrderStore`, `SelectedAddressStore` are
ports, owned by the module that needs them. `Default*` (network/UserDefaults) and `Stub*` (in-memory)
are adapters. The feature model — the core — imports none of them concretely.

**Relation to GoF.** This is Bridge + Strategy + Dependency Inversion given an architectural name and
a direction rule ("dependencies point inward"). The direction rule is the part GoF doesn't state.

## Constructor injection with no production default

**Intent.** A production initializer names every collaborator it needs and defaults none of them to a
concrete type. Convenience defaults live only in test-support code.

**Where.** Every feature model. `StoreModel(repository:)` cannot be built without a repository;
`StoreModel()` exists only in `StoreTesting`.

**Payoff.** It's impossible to accidentally ship a model wired to a stub, and impossible to write a
model that secretly reaches for a singleton. The dependency graph is fully visible in the
initializers.

## One navigation type per concern

**Intent.** Each model owns exactly one `destination: Destination?` enum (`@CasePathable`), with one
case per reachable screen/sheet — never `@State var isShowingX: Bool`. Independent concerns
(tab selection vs. modal) get independent types, not merged and not multiplied. (ADR-0007, ADR-0008.)

**Why it's not "just State pattern."** It's about making illegal states unrepresentable: `n` booleans
give `2ⁿ` states, mostly nonsense; one `Destination?` enum gives `n+1`, all valid. The pattern is the
*constraint*, not the enum.

## Signal properties

**Intent.** When a model needs a navigation effect it has no authority to perform (switch tabs, open
another feature's sheet), it exposes a plain observable flag; the composition root observes it via
`.onChange`, performs the effect, and clears the flag.

**Where.** `PastPurchasesModel.shouldOpenSupport`, `.shouldNavigateToCart`, `.orderToRate`.

**Trade-off.** Keeps the model honest about its authority, at the cost of a two-step
raise-then-consume dance and a mediator that has to remember to reset. Works well in ones and twos;
`PastPurchasesModel`'s four of them are a sign that colleague is doing too much coordinating.

## Self-guarding side effects

**Intent.** A method triggered from multiple places (a view's `.task`, the composition root's
`.task`, a retry button) guards *itself* against running when it shouldn't, rather than trusting
every call site to check first. (ADR-0013.)

**Where.** Every model's `load()`:
```swift
guard !suppressAutoLoad, !isLoading, profile == nil, addresses.isEmpty, cards.isEmpty else { return }
```

**Why it's a pattern and not just a guard.** The same unguarded `.task { await model.load() }` bug
was reintroduced independently in six places because the fix was applied once, not written down. The
pattern is "put the invariant in the one method everyone calls," and it's now an ADR precisely so it
stops recurring.

## Structural coverage via `CaseIterable`

**Intent.** Make "you added a case but not a test for it" a compile error, by conforming navigation
and scenario enums to `CaseIterable` and parametrizing tests over `.allCases`. (ADR-0010.)

**Where.** Every `*SnapshotTests` file; every micro-app `Scenario` enum.

---

# Summary

| Pattern | Status | Primary location |
|---|---|---|
| **Creational** | | |
| Factory Method | Used (4 spellings) | `*ModelTestSupport.swift`, `*ScenarioFactory`, `DefaultPastPurchasesRepository.mock()` |
| Abstract Factory | Not used | informal ternary in `ShopAppMain.swift` |
| Builder | Not used | routinely confused with Factory — see the Builder entry |
| Prototype | Not used | pre-empted by value semantics |
| Singleton | Deliberately avoided | injected `URLSession.shared` / `UserDefaults.standard` |
| **Structural** | | |
| Adapter | Used, pervasive | `AppModel.init` closures, `AppModel.syncAddresses()` |
| Bridge | Used, uniform | `*Repository` protocols; nested `Remote*DataSource` in Search/PastPurchases |
| Facade | Used, 3 scales | `RemoteDataSourceHelper`, `Default*Repository`, `AppModel` |
| Proxy | Partially used | `Local*DataSource` caching (Store/Search/Account); `UnimplementedNetworkClient` |
| Decorator | Used (framework) | SwiftUI modifier chains; no hand-authored wrapper yet |
| Composite | Used (framework) | `View` tree; `@ViewBuilder` generic slots in `StoreView`/`CheckoutView` |
| Flyweight | Not used | not at this scale |
| **Behavioral** | | |
| Strategy | Used, pervasive | every injected protocol; `onAddToCart` closures |
| Observer | Used | `@Observable`; `RootView` `.onChange` + signal properties |
| State | Namesake only | `StoreLoadState`, `SearchState` (enums, not state objects) |
| Command | Partially used | `Destination` enums; `CheckoutModel.path: [CheckoutStep]` |
| Iterator | Used | `for-in`; `CaseIterable.allCases` for structural coverage |
| Mediator | Used, backbone | `AppModel` + `RootView`; cross-feature import is a compile error (`graph-tool check` not yet in CI) |
| Chain of Responsibility | Not used | framework responder chain consumed, not built |
| Template Method | Not used (classic) | composition equivalent: `RemoteDataSourceHelper` generics |
| Visitor | Not used | closed enums + `switch` take the opposite expression-problem trade |
| Memento | Minimal | `Codable` + `UserDefaults*Store` (no opaque token) |
| Interpreter | Not used | no on-device query language |
| **Beyond GoF** | | |
| Composition Root | Used | `ShopAppMain.swift`, `AppModel.init` |
| Ports & Adapters | Used | `*Repository`/`NetworkClient`/`*Store` ports; `Default*`/`Stub*` adapters |
| Constructor injection, no prod default | Used, uniform | every feature model `init` |
| One navigation type per concern | Used, uniform | every model's `Destination` enum (ADR-0007/0008) |
| Signal properties | Used | `PastPurchasesModel` flags → `RootView` |
| Self-guarding side effects | Used, uniform | every model's `load()` (ADR-0013) |
| Structural coverage via `CaseIterable` | Used, uniform | every `*SnapshotTests` (ADR-0010) |

---

## Where this document's advice diverges from the common Swift pattern guidance

Hacking with Swift's *Design Patterns* is current and idiomatic, and the points below are largely
consistent with it. They are aimed mainly at the dated Swift sample code on refactoring.guru and at
the habits it still propagates in code review.

1. **Value types first.** Prototype, and much of Builder and Memento, exist to manage the cost and
   safety of copying reference types. Swift `struct`s copy safely and cheaply by default, so those
   patterns shrink to "assign it" or "make it `Codable`."
2. **Protocol + injection replaces most class hierarchies.** Factory Method, Bridge, Strategy,
   Template Method, and State are all shown on Refactoring Guru as base classes with overridden
   methods. In idiomatic Swift they're one technique: *inject a `Sendable` protocol, or a closure,
   with no production default*. Reach for a class hierarchy only when you actually need stored
   inheritance.
3. **`enum` with associated values replaces State, much of Command, and the AST half of Interpreter.**
   Closed, exhaustively-checked, allocation-free. You trade "easy to add a subtype" for "impossible to
   forget a case" — usually the right trade in app code, and ADR-0010 turns it into a testing feature.
4. **Don't hand-roll Observer.** `@Observable` for model→view; `AsyncStream` for non-UI broadcast.
   The `subscribers: [Observer]` array from the book is for a case app code almost never hits.
5. **`fatalError()` is not an abstract method.** Refactoring Guru's Template Method and others use
   `fatalError("override me")`. Protocol requirements give the same "must implement" at compile time.
   Prefer them.
6. **Naming honesty — especially "Builder".** `SomethingBuilder` is routinely used as a generic
   label for any type that constructs another; the large majority of those are Factory Methods —
   one call in, a finished object out, no incremental assembly. The catalog is a shared vocabulary,
   and a type that carries a pattern's name should be that pattern. See the Builder entry.
7. **Enforcement belongs with the pattern.** Mediator holds here because a cross-feature import is a
   compile error — the package graph enforces it. Where a rule can't be a compile error, wire an
   explicit check (`graph-tool check` exists for exactly this, though it isn't in CI yet). A pattern
   you merely intend is a pattern you'll erode.
