# Article Outline
## "AI Writes Fast. Your Safety Net Needs to Be Faster."

**Publication:** Medium
**Series:** Standalone — intended to draw new readers into the broader iOS architecture series
**Companion project:** ShopApp (GitHub link — to be added)
**Estimated read time:** 12–15 minutes

---

## Subtitle

*How making illegal navigation states unrepresentable in SwiftUI builds a three-layer defence — types, tests, and agent instructions — that holds even when AI is writing the code.*

---

## Reader takeaways

*This section should appear near the top of the published article — before the first section heading — as a brief paragraph or a tight list. Its job is to answer the question every reader asks in the first thirty seconds: "Is this worth my time?" The answer here is yes, and these are the reasons.*

By the end of this article, the reader will leave with five things they did not have when they arrived:

**1. A name for a problem they already have**
Most developers using Bool flags for navigation state have felt the pain of it — the defensive-clearing code, the mysterious edge-case bugs, the logic that is hard to follow — without having a precise diagnosis. This article names it: *making illegal states unrepresentable*. It connects a principle from type theory to a concrete, daily Swift problem, and gives the reader a framework they can apply far beyond navigation.

**2. The specific gap in SwiftUI's own programmatic navigation story**
`NavigationStack` is programmatic. Sheets, full-screen covers, alerts, and dialogs are not — not fully. Most developers do not know this gap exists because their apps work on the happy path. This article shows exactly where SwiftUI stops and where one small library picks up, with code demonstrating all four SwiftUI presentation types driven from a single model property.

**3. A testing technique that runs six screens in under one second — with no simulator**
Snapshot testing against model state is not widely understood outside the functional programming community. This article makes it concrete: a six-step checkout funnel, every screen captured, in under a second, with no app launch and no tap sequence. The reader will understand not just how to write these tests but why they catch the specific class of bug that XCUITests miss and that code review cannot reliably find.

**4. A direct answer to the AI coding agent risk they are not yet managing**
AI tools accelerate generation. Nothing in Xcode 26 or Xcode 27 — and nothing on the WWDC 2026 schedule — closes the validation gap that acceleration creates. This article gives the reader a structural response: an architecture where illegal navigation states are inexpressible, combined with a test suite that fails in under a second when a state transition goes missing. The safety net does not depend on careful prompting or thorough code review.

**5. Something to drop into their project today**
The appendix provides a complete `AGENTS.md` file — standing instructions that encode every rule from the article into the project itself, enforced automatically by whatever AI coding agent the team uses. The reader does not need to finish the refactor, adopt a new architecture wholesale, or convince their team before getting value. They copy one file, and the next time their coding agent touches navigation code, it operates within the constraints the article argues for.

---

## Target reader

A mobile developer — iOS, Android, or Flutter — who uses AI coding agents daily, has already been burned by a production regression they didn't see coming, and suspects their test suite isn't keeping up with the speed at which code is being generated.

---

## Narrative arc

The article follows a single thread: **the faster you generate code, the faster your validation loop must be.** The architectural pattern (programmatic navigation) and the tooling (snapshot testing) are the answer to that problem. The reader arrives at them through the pain, not through a feature list.

---

## Section 1 — The Incident (Hook)

**Goal:** Make the reader feel the problem before proposing any solution.

- Open with a production incident that any mobile developer will recognise: a navigation flow that broke silently. Not a crash — those get caught. A wrong screen. A stuck stack. An order confirmation that never appeared.
- The code change that caused it was AI-generated, reviewed and approved in minutes because it looked correct in isolation.
- The test suite passed. Manual QA was not exhaustive enough to cover the specific sequence of taps required to reach the broken state.
- The incident was discovered by a user.

**Tone:** Specific and plain. No dramatisation. The reader has lived a version of this.

---

## Section 2 — Why Navigation State Is Invisible to Most Test Suites

**Goal:** Name the root cause precisely so the solution feels inevitable.

- Traditional SwiftUI navigation scatters state across Bool flags (`isShowingSheet`, `isPresented`), optional bindings, and `NavigationPath` arrays.
- Each flag is local to a view. No single place in the code describes what screens are reachable from a given state.
- Unit tests verify business logic but render nothing.
- XCUITests render everything but require a full app launch, a running simulator, and tap sequences that must mirror exactly how a user navigates — making them expensive to write, slow to run, and brittle to maintain.
- **The gap:** navigation state itself — the question "given this model state, which screen is shown?" — is tested by neither.
- This gap exists in human-written code. It becomes critical when AI agents are contributing code at volume, because neither the AI nor the reviewer has a signal when a navigation transition is silently removed or incorrectly gated.

**Key line:** *Your test suite cannot validate what it cannot see. If navigation state is implicit, it is invisible.*

---

## Section 3 — Making Navigation State Explicit

**Goal:** Introduce the architectural pattern as the solution to the visibility problem, not as a library recommendation. Establish that SwiftUI's own programmatic navigation story has a significant gap that most developers have not noticed — and that this gap is where bugs hide.

---

### 3a — Making illegal states unrepresentable

Before introducing any SwiftUI-specific solution, ground the argument in a principle that applies across every language and platform. This gives the insight weight beyond library preference and connects it to a body of work the reader can explore further.

**The principle**

The phrase *making illegal states unrepresentable* was articulated by Yaron Minsky in the context of OCaml at Jane Street and has since become a touchstone of type-driven design. The idea is precise: if a combination of values in your system is invalid, your types should make that combination inexpressible. Not guarded against — inexpressible. Code that cannot produce an illegal state does not need to defend against one.

> 🔗 Link: Yaron Minsky — *"Making Illegal States Unrepresentable"*, Jane Street Tech Blog
> *(Search: "Yaron Minsky illegal states Jane Street" — verify URL before publishing)*

Richard Feldman brought the same principle to a wider audience with his Elm Conf 2016 talk *"Making Impossible States Impossible"*, which remains one of the clearest explanations of why Boolean flags are a trap.

> 🔗 Link: Richard Feldman — *"Making Impossible States Impossible"*, Elm Conf 2016
> *(YouTube — search: "Richard Feldman Making Impossible States Impossible Elm Conf 2016" — verify URL before publishing)*

**The arithmetic**

The problem with multiple Bool properties is not that they are ugly. It is that they are combinatorially dangerous. Each Bool doubles the number of representable states. Seven Bool properties produce **2⁷ = 128 possible combinations**. In a checkout flow with seven navigation destinations, exactly eight of those combinations are valid: all false, or exactly one true. The remaining **120 are illegal states** — states the app cannot correctly render, that no test suite deliberately covers, and that can be produced silently by any code that sets one flag without clearing another.

| Approach | Representable states | Valid states | Illegal states |
|---|---|---|---|
| 7 Bool properties | 128 | 8 | 120 |
| `destination: Destination?` with 7 cases | 8 | 8 | 0 |

The optional enum does not just reduce the count. It eliminates the entire category.

**The defensive code it generates**

Those 120 illegal states do not disappear from the codebase — they move into logic. Every transition function accumulates a list of things to clear before setting the new thing:

```swift
// The mess that grows around Bool flags
func showProcessing() {
    isShowingAddressForm = false   // clear previous state
    orderOptionsAddress  = nil     // clear previous state
    paymentEntryAddress  = nil     // clear previous state
    confirmedOrder       = nil     // clear previous state
    paymentError         = nil     // clear previous state
    isProcessing         = true    // finally, the one we wanted
}
```

Miss one line and there is a latent bug. Add a new destination later and every existing transition function needs updating — silently, with no compiler assistance. This is the mess that accumulates in real codebases. It is not caused by careless developers. It is caused by a type that makes legal and illegal states equally expressible.

The enum collapses this to a single assignment:

```swift
func showProcessing() {
    destination = .processing   // previous state is gone by definition
}
```

There is nothing to clear. The type does not permit two states to coexist. The function cannot be wrong.

**Why this matters specifically for AI-generated code**

An AI coding agent writing a new transition reads the existing code for patterns. If the pattern it sees is "set the new flag, clear the others", it may set the new flag and miss a clear. Or it may clear the wrong ones. The Bool-flag model gives it 120 ways to produce an unrenderable state. The enum model gives it zero. The safety net is not just the tests — it starts with the type.

> 🔗 Link (optional, Swift-specific): PointFree Episode on "Enum State" or the `swift-navigation` README section on navigation destinations
> *(Verify current URL at pointfree.co before publishing)*

---

### 3b — The gap SwiftUI left open

Begin by acknowledging what SwiftUI does well. `NavigationStack` with path-based navigation is genuinely programmatic: a value goes into the path, a screen appears. But SwiftUI's programmatic model stops at the stack. Everything else — sheets, full-screen covers, alerts, confirmation dialogs, popovers — is governed by Bool flags and scattered optional properties.

Show what a realistic checkout model looks like when written with only SwiftUI's built-in tools:

```swift
// Naive SwiftUI: one property per destination
@Observable final class CheckoutModel {
    var isShowingAddressForm          = false
    var orderOptionsAddress:    ShippingAddress? = nil
    var paymentMethodAddress:   ShippingAddress? = nil
    var paymentEntryAddress:    ShippingAddress? = nil
    var isProcessing                  = false
    var confirmedOrder:         PlacedOrder?     = nil
    var paymentError:           PaymentError?    = nil
}
```

Seven properties. Each one represents a screen that can appear. And nothing in the type system prevents more than one of them being active at the same time. `isProcessing` can be `true` while `paymentError` is non-nil. `confirmedOrder` can be set while `isShowingAddressForm` is still `true`. The compiler will not complain. The bug will be silent until a user finds it.

**This is the gap most developers have not noticed.** They know their app works because it works under the happy path they test manually. The edge cases — rapid taps, background state changes, AI-generated code that sets two properties where it should set one — are invisible.

There is also a second, quieter cost: with seven properties, the question "which screen is currently shown?" requires reading and reasoning about all seven simultaneously. There is no single place in the code that answers it.

---

### 3c — The pattern: one property, one enum

The fix is a single optional property whose type is an enum with one case per reachable destination:

```swift
@Observable final class CheckoutModel {
    var destination: Destination?

    @CasePathable
    enum Destination {
        case addressForm
        case orderOptions(ShippingAddress)
        case paymentMethodSelection(ShippingAddress)
        case paymentEntry(ShippingAddress)
        case processing
        case confirmation(PlacedOrder)
        case paymentFailed(PaymentError)
    }
}
```

- `destination` is `nil` when no overlay or pushed screen is active.
- It holds exactly one case when something is shown.
- Two destinations being active simultaneously is **not representable** in this type. The compiler enforces the invariant that was previously enforced only by developer discipline.
- Every reachable screen is a named case. Removing one is a compiler error. Mistyping a transition is a compiler error.

---

### 3d — How swift-navigation fills the remaining gap

`@Observable` gives you the model property. `@CasePathable` (from `swift-navigation`) gives you the binding syntax that connects that single property to SwiftUI's mixed presentation APIs.

Without `@CasePathable`, you cannot write `.sheet(isPresented:)` or `.fullScreenCover(item:)` against individual cases of an optional enum. You would be back to extracting Bool flags manually. `swift-navigation` solves this with case path bindings:

```swift
// All four presentation styles — one enum, one property
NavigationStack {
    CartView(model: model)
        .navigationDestination(
            isPresented: Binding($model.destination.addressForm)
        ) { AddressFormView(model: model) }
        .navigationDestination(
            item: $model.destination.orderOptions
        ) { address in OrderOptionsView(model: model, address: address) }
        .navigationDestination(
            item: $model.destination.paymentEntry
        ) { address in PaymentEntryView(model: model, address: address) }
}
.sheet(isPresented: Binding($model.destination.processing)) {
    ProcessingView()
}
.fullScreenCover(item: $model.destination.confirmation) { order in
    OrderConfirmationView(model: model, order: order)
}
.sheet(item: $model.destination.paymentFailed) { error in
    PaymentFailedView(model: model, error: error)
}
```

Note what this view is doing: four different SwiftUI presentation APIs — `navigationDestination(isPresented:)`, `navigationDestination(item:)`, `fullScreenCover(item:)`, and `sheet(item:)` — all reading from the same `destination` property, each binding to a specific case. This is what SwiftUI cannot express without the library.

**The point to land:** Most developers reach for `swift-navigation` because they have heard it solves navigation. The more precise reason is that SwiftUI's own programmatic navigation is incomplete. `swift-navigation` extends it to cover every presentation type from a single source of truth. Developers who have not used it are not aware of the gap because their apps appear to work — until the edge case or the AI-generated change that sets two flags at once.

---

### 3e — The dependency concern

Address the objection directly: `swift-navigation` was previously avoided by some teams due to transitive dependencies. That concern is now resolved:

- `@Observable` (iOS 17+) is native to the SDK — `swift-perception` is no longer pulled in
- `swift-navigation` is modular: `SwiftUINavigation` alone is a handful of packages, not the full Composable Architecture ecosystem
- This is not a commitment to the Composable Architecture, to any particular state management pattern, or to any PointFree opinion beyond the navigation primitives themselves

**Note:** Include a before/after dependency graph screenshot from Xcode showing the resolved package graph.

---

## Section 4 — What Explicit State Unlocks

**Goal:** Connect the architectural pattern directly to the testing capability.

- Because `destination` is a plain Swift property, you can set it to any value in a test without launching an app, without tapping, without a simulator.
- `swift-snapshot-testing` renders a SwiftUI view off-screen using UIKit and writes the result to a PNG — in milliseconds, on any machine that can compile Swift.
- The combination means: **every screen in your app is now a unit test.**

```swift
@Test("Payment failed screen renders correctly")
func paymentFailed() async throws {
    let model = CheckoutModel(cart: CartItem.stubs)
    model.destination = .paymentFailed(.cardDeclined)
    assertSnapshot(
        of: CheckoutView(model: model),
        as: .image(layout: .device(config: .iPhone13Pro))
    )
}
```

- No app launch. No simulator. No navigation sequence. One line sets the state; one line captures the screen.
- The PNG is committed to the repository alongside the test. Every future change is diffed against it.

---

## Section 5 — Testing a Full Navigation Flow

**Goal:** Show the pattern at its most compelling — walking a multi-screen funnel programmatically.

### The snapshot funnel test

Show the complete `happyPathFunnel` test from `CheckoutFunnelFlowTests`: six screens, six `assertSnapshot` calls, all async, all resolved with `StubCheckoutRepository(delay: .zero)`. The test runs in under one second.

Highlight what each line is doing:
- Direct model method calls mirror exactly what the UI calls
- No waiting for animations
- No tap coordinates
- The `await` on `submitPayment` is real async — it tests that the async flow resolves to the correct state

### The XCUITest equivalent

Show `CheckoutFunnelUITests.test_happyPath_completesCheckoutFromCartToConfirmation` in full. Same funnel. Then present the comparison:

| Dimension | Snapshot (programmatic) | XCUITest (end-to-end) |
|---|---|---|
| Execution time | < 1 second | ~20 seconds |
| Simulator required | No | Yes |
| Fragility | Immune to label changes | Breaks on any text rename |
| What it exercises | View rendering + model state | Real NavigationStack + animations |
| Production code changes required | None | `.accessibilityLabel` added to payment buttons |

The last row is the one to linger on. The XCUITest required a change to production code — adding `.accessibilityLabel(method.rawValue)` to `PaymentMethodSelectionView` — purely to support the test. The snapshot test required nothing.

---

## Section 6 — The AI Coding Agent Argument

**Goal:** Connect the architecture and testing pattern to the specific risks introduced by AI-assisted development. This is the section that earns the title.

- AI agents generate code quickly, but they generate code in context windows. They do not run the app. They do not navigate the funnel. They cannot know that removing a line from `submitPayment` silently prevents the confirmation screen from ever appearing.
- Code review at speed is not sufficient: a reviewer approving a 200-line AI-generated diff in three minutes is not testing navigation state.
- **With this pattern, the safety net is structural:**
  - A renamed `Destination` case is a compiler error — the build fails before merge
  - A missing state transition (`destination = .confirmation` removed from `submitPayment`) causes the funnel snapshot to diverge from its baseline — the test fails before merge
  - A new screen added by an AI agent without a corresponding snapshot test is visible as an untested branch in code review — not hidden
- **Scale argument:** At 50 developers, code review cannot scale. Automated tests scale. A snapshot baseline that must be deliberately updated (`record: true`) is a gate that does not get tired.
- **The key shift in framing for the team:** You are not asking developers to write more tests. You are asking them to adopt an architecture that makes tests almost automatic — because state is explicit, and explicit state is trivially testable.
- **Include the WWDC 2026 observation here:** Apple invested in UI testing improvements in Xcode 26, then shipped significant AI coding agent features in Xcode 27 with no corresponding testing session at WWDC 2026. The platform is accelerating generation without closing the validation gap. That gap is the developer's responsibility to fill — and this is how.

---

## Section 6b — The Staff+ Framing

**Goal:** Speak directly to the reader who has already diagnosed the problem and carries responsibility for a team. This section should feel like a gear change — from "here is what to do" to "here is why this is the right architectural move at scale." It does not require a heading in the published article; it can flow as the closing paragraphs of Section 6. But it must be written with this reader in mind.

**Who this reader is:** A staff engineer, principal engineer, mobile architect, or engineering manager who is not asking whether AI tools introduce risk — they know they do. They are asking how to address that risk systematically, across a team large enough that individual craft is no longer sufficient.

**The distinction to draw:** A senior engineer writes good code. A staff engineer changes the conditions under which everyone else writes code. The pattern described in this article is not individual craft — it is a systemic intervention. The type system enforces the invariant. The snapshot baseline enforces the test. The AGENTS.md encodes the rule into the tooling. None of these require the architect to be in every code review.

**The three levers:**

1. **The type as policy.** When `destination: Destination?` replaces seven Bool flags, the rule "only one screen active at a time" stops being a convention and becomes a compiler constraint. It applies to the newest developer on the team on their first PR, to the AI agent generating code at 3am, and to the most experienced engineer in a hurry. It does not need to be enforced — it cannot be violated.

2. **The snapshot baseline as a quality gate.** A failing snapshot blocks a merge. It does not ask for a reviewer's attention or depend on manual QA coverage. It does not get tired on a Friday before a release. At scale, the gates that do not require human attention are the only gates that reliably hold.

3. **The AGENTS.md as institutional memory.** Architectural decisions made in a design review decay. They live in a Confluence page nobody reads, in the head of the engineer who was in the meeting, in a PR description from eighteen months ago. Encoding decisions in AGENTS.md means the coding agent enforces them automatically, in every session, for every developer, regardless of tenure. The decision survives staff turnover because it is in the repository, not in a person.

**The line to write in the article:**

> *If you are an individual contributor, this pattern improves your own code. If you are a staff engineer or architect, it gives you something more valuable: a constraint that propagates across your entire team through the type system, the test suite, and the agent instructions — without requiring a mandate, a training session, or a design review. The architecture enforces itself. That is the point.*

**Tone:** Direct, without condescension toward the individual contributor reader who has read this far. The framing is additive — the same pattern delivers more value at scale, not different value.

---

## Section 7 — How the Snapshots Live in Your Repository

**Goal:** Practical, so the reader can act on the article immediately.

- `__Snapshots__` directories are co-located with test source files, not in a separate folder. This is required by `swift-snapshot-testing`'s `#file`-relative lookup and is also the right organisational choice: the snapshot for a test lives next to the test.
- First run records the baseline. Second run asserts against it. If the test fails, the developer sees the diff and either fixes their code or updates the baseline deliberately.
- In CI: run with `record: false` (the default). A snapshot divergence fails the pipeline, exactly like a compilation error or a unit test failure.
- No simulator is needed in CI for snapshot tests — they use off-screen UIKit rendering. This is meaningful: snapshot tests can run on a standard Linux CI runner with the Swift toolchain, without spinning up an iOS simulator, significantly reducing CI cost and time.

**Note:** Include a screenshot of the `__Snapshots__` directory in Xcode's file navigator, and one of a failing snapshot diff.

---

## Section 8 — What This Is Not

**Goal:** Preempt the objections and misconceptions that will appear in comments.

- **Not a replacement for XCUITests.** You still need some. Launch performance, deep links, accessibility, and real system interactions (push notifications, background fetch) require a running app. The argument is that you need far fewer XCUITests when every screen state is covered by snapshots.
- **Not tied to The Composable Architecture.** This pattern uses `@Observable` and a single enum. It requires no opinion about reducers, stores, or effects. It is compatible with any architecture that accepts dependency injection.
- **Not about writing more tests.** It is about writing tests that cost less to maintain and fail at the right moment — before merge, not after deployment.
- **Not a silver bullet.** A snapshot test catches rendering regressions and state mapping bugs. It does not test network requests, animations, or physical device behaviour. Know what it is for.

---

## Section 9 — Where to Start

**Goal:** Give the reader a concrete first step so the article ends with momentum, not friction.

- Pick one feature module. One model. One `destination` enum. One `StubRepository`.
- The first snapshot test is three lines: create the model, set the destination, assert the snapshot.
- Do not refactor the whole app first. Prove the value in one module, make the baseline visible in a PR, let the team see the diff when someone changes the screen.
- Link to the ShopApp companion project on GitHub as a reference implementation.

**Closing line direction:** Return to the incident from Section 1. The developer who made that AI-assisted change would have seen a test failure on their machine, before opening a pull request. The user would never have seen the wrong screen.

---

## Code snippets to include (in order of appearance)

1. Naive Bool-flag model — the before (Section 3a)
2. Illegal states table: 128 vs 8 (Section 3a)
3. Defensive-clearing `showProcessing()` — the mess (Section 3a)
4. `CheckoutModel` — the `destination` enum (Section 3c)
5. Mixed presentation bindings — all four SwiftUI APIs from one property (Section 3d)
6. Single-screen snapshot test — `paymentFailed` (Section 4)
7. `happyPathFunnel` — full funnel snapshot test (Section 5)
8. `test_happyPath_completesCheckoutFromCartToConfirmation` — full XCUITest (Section 5)
9. Comparison table (Section 5)
10. AGENTS.md — abridged version (Appendix)

---

## Visuals to include

1. Dependency graph: `swift-navigation` resolved packages (Section 3e)
2. `__Snapshots__` directory in Xcode file navigator (Section 7)
3. Snapshot test failure diff — before/after PNG (Section 7)
4. One or two of the generated snapshot PNGs themselves — e.g. `step_1_cart` and `step_6_confirmation` — to make the output tangible

---

## Appendix — AGENTS.md: Encoding the Rules for Your Coding Agent

**Goal:** Give the reader something immediately useful they can drop into any project today, independent of whether they adopt every other idea in the article.

### What is AGENTS.md?

Most AI coding agents read a project-level markdown file at startup and use it to understand conventions, constraints, and rules specific to that codebase. The file acts as standing instructions that persist across every session — the agent applies them without being reminded.

Different tools use different filenames for the same concept:

| Tool | File |
|---|---|
| Claude Code | `CLAUDE.md` |
| Cursor | `.cursor/rules/conventions.mdc` |
| GitHub Copilot | `.github/copilot-instructions.md` |
| OpenAI Codex | `AGENTS.md` |

The content is identical regardless of the filename. If a project uses multiple agents, maintain the same file under each tool's expected name (or symlink them).

### What to put in it

The file should encode the rules from this article as direct, unambiguous instructions. Key sections:

**Navigation state rules** — the single destination enum rule and the prohibition on Bool flags, with a brief `Why:` line explaining the illegal-states argument so the agent understands the principle, not just the constraint.

**Snapshot test rules** — every new `Destination` case requires a snapshot test; `record: true` is never committed; stub repositories must use `delay: .zero` in tests; XCUITests are reserved for flows that require a real app process.

**Dependency injection rules** — models accept dependencies via protocol with a stub default; production implementations are injected at the composition root only.

**Module boundary rules** — feature modules must not import other feature modules; violations must be raised before proceeding.

**Failure handling** — what to do when a snapshot test fails (investigate before updating the baseline; a diverging snapshot on a PR with no intentional UI changes is a regression, not an inconvenience).

### Why this matters beyond the article

Encoding rules in AGENTS.md means:
- A new developer joining the project gets the conventions enforced automatically from day one, without reading documentation
- An AI agent contributing a new screen is constrained to the same pattern as every existing screen — it cannot introduce Bool-flag navigation state because the instructions explicitly prohibit it
- The rules survive staff turnover, context switching, and the inevitable drift that happens when conventions live only in people's heads or in a wiki nobody reads

The ShopApp repository includes a complete `AGENTS.md` as a reference. Readers can copy it, trim the project-specific references, and adapt it to their own module structure in under ten minutes.

**Note:** Include the full `AGENTS.md` content as a gist or GitHub link, not inline in the article — it is too long to paste in full without breaking the reading flow. Reference it at the end of the appendix section.

---

## What this article deliberately excludes

- Tuist (covered in previous series — link at the end, do not introduce here)
- The Composable Architecture
- Any discussion of Android or cross-platform tooling (the pattern is iOS/SwiftUI-specific; the title is platform-agnostic to draw the audience in)
- Company-specific context of any kind
