# Minimal API as a Contract

**Status:** Living document
**Scope:** The general principle — why a module's public surface is a promise, not a convenience,
and what actually happens when it grows past what's needed. Platform-agnostic in its reasoning;
grounded throughout in this repo's real numbers, not illustrative ones.
**Not in scope here:** the SwiftUI-specific instance of this principle — why `some View` breaks the
protocol-per-type instinct, and what a feature module's public API is instead (repository
protocol, model initializer, data types, never the View). That argument is deep enough to earn its
own treatment; see `ShopAppDocs/Dont_Make_It_Public_draft.txt` and `ShopAppDocs/article-3-outline.md`
for it. This document is the general case that argument is a specific, harder instance of.

---

## Why this document exists

"Keep your public API small" is old, uncontroversial advice — it predates Swift, predates modules,
predates this project. It's also advice developers routinely don't act on, because the cost of
ignoring it is deferred and diffuse (nobody's build gets dramatically slower from one extra
`public` keyword) while the benefit of ignoring it is immediate and local (shipping the feature
without stopping to think about access control). This document exists to make the deferred cost
concrete enough to act on before it compounds, and to state plainly where the general advice
actually cashes out in this specific codebase.

It also exists to correct a temptation this project has already outgrown once. An earlier version
of this reasoning, written against a predominantly UIKit, navigation-controller-based codebase,
proposed a comment as the mechanism for justifying an exception: a developer writes
`// justification: needed by X` next to a `public` declaration, and that's the record. That
mechanism has a real weakness worth naming directly: nothing checks whether the justification is
*true*, only that one was written. `@_spi` (below) is this project's answer to the same problem,
and it's a stronger answer specifically because Swift's compiler enforces the boundary instead of
trusting a comment to be honest.

---

## 1. The core principle

### 1.1 API as a promise, not a convenience

Marking something `public` is not a neutral act. It is:

1. A promise that this shape will remain stable — every caller that starts depending on it is now
   a reason it's expensive to change.
2. An expansion of what every developer touching this module has to hold in their head.
3. A widening of the blast radius of the next change — more callers means more that can break.

None of this is specific to Swift or to this project. It's true of any module boundary in any
language. What differs by language and by project is how *cheap* the mistake is to make, and this
project's answer (below, §3) is that Swift makes it cheaper than most.

### 1.2 The encapsulation hierarchy, extended

The conventional framing is two levels:

```
internal, fileprivate, private     ← default to this
public                             ← only when a real external consumer needs it
```

This project's actual hierarchy has a rung the conventional framing doesn't:

```
internal, fileprivate, private     default
@_spi(GroupName)                   a hole with a guest list — visible only to an
                                    explicit, named importer, checked by the compiler
public                             visible to anyone; the widest, most expensive commitment
```

`@_spi` matters here specifically because the middle case — "one specific caller outside this
module needs this, and nobody else should" — is common and was previously being solved by making
something fully `public` (visible to everyone) to satisfy one caller (who needed it). `CheckoutModel`'s
scenario-construction initializer is the real example: `CheckoutApp`'s scenario glue needs to build
a mid-funnel state no ordinary caller should be able to construct. `@_spi(Scenarios)` lets exactly
that one caller opt in (`@_spi(Scenarios) import Checkout`) while an ordinary `import Checkout`
never sees the initializer at all — not undocumented, not `internal`-and-therefore-invisible to the
one caller who legitimately needs it, but visible to precisely the callers who declare they're
allowed to see it.

**Rule of thumb, updated:** start with `internal`. If exactly one external caller needs it and that
caller is known, reach for `@_spi` before `public`. Escalate to `public` only when the caller is
genuinely anyone — a real product contract, not a workaround for one caller.

---

## 2. What this actually costs — measured on this repo, not estimated

Two documents in this repo already measure the real cost, and they're the numbers to cite here
rather than a synthetic table:

- **`docs/build-time-baseline.md`** — real `xcodebuild` timings on this exact codebase: a clean
  build (48.75s), a genuinely no-op incremental rebuild (3.01s), and a single-file touch in a leaf
  feature module (3.49s, with only that one target recompiling). That last number is the one this
  document's argument actually rests on: today, because each feature is one library product,
  "touch anything in the module" and "touch the module's public API" cost exactly the same to
  rebuild, because there's only one target for the build system to invalidate. A module split that
  separates implementation from public contract only pays off if a change to the *implementation*
  stays close to that 3.49s number while a change to the *public contract* is the one that's
  allowed to cost more — because a public-contract change is the one with real downstream
  consumers. The baseline document exists specifically so that claim can be checked against a real
  before/after number instead of asserted.
- **`docs/test-coverage-baseline.md`** — a related but separate concern: this project's per-module
  coverage, and the real bug it surfaced (five independent recurrences of the same unguarded
  `.task` side effect, ADR-0013) that a *smaller, better-understood* module surface would have made
  easier to catch by inspection, even before any test caught it.

Do not add a dollar-figure or a percentage to this section that isn't backed by a document like
these two. A plausible-sounding number is worse than no number — it borrows the credibility of
real measurement without doing the work, and it's the exact failure mode this project's article
series has been careful to avoid throughout (see, e.g., the Replay and `swift-coverage` articles'
insistence on citing real, run output rather than claimed behavior).

---

## 3. Real enforcement in this repo — not a proposed tool

The earlier version of this document proposed a hypothetical `@agent minimal-api-enforcer` PR
check. This project has something more concrete, in two parts, at two different levels — see
`docs/design-patterns.md`'s Mediator entry and ADR-0001 for the fuller treatment:

- **`tools/GraphTool`** (`graph-tool check` against `allowed-dependencies.json`) — a package-graph
  question: can module X depend on module Y. It reads `Package.swift`'s declared dependencies, and
  a forbidden `import` between feature modules is already a compile error before the tool even
  runs — the tool's job is making the *rule* explicit and machine-checkable, not creating the
  enforcement from nothing. **As of this writing it exists, works, and is not wired into CI** — it
  runs only when someone remembers to run it by hand. That gap is itself worth treating as the
  first, cheapest thing to fix, ahead of anything else in this document.
- **`@_spi(Scenarios)`** (§1.2) — a declaration-level question: who, specifically, may see this one
  symbol. Compiler-enforced at the import site, not comment-enforced at the declaration site.

Neither tool currently checks "is this `public` declaration used outside its module" directly —
that's a real, open gap (a Harmonize-shaped question, in the vocabulary this project's article
series uses for it — an AST/declaration-level check, distinct from `GraphTool`'s package-graph
one) rather than something to claim is already solved.

---

## 4. Tradeoffs — when a wider API is actually the right call

Minimal API is a default, not an absolute. Naming the real exceptions matters more than repeating
the rule, because a rule with no acknowledged exceptions gets applied where it doesn't fit and then
quietly ignored everywhere, including where it does.

**Broad `public` is usually correct for:**
- `DesignSystem` — components meant to be consumed identically by all eight feature modules. A
  narrow API here doesn't reduce coupling, it just adds friction to a type that's supposed to be
  widely shared.
- `Common` / `NetworkFoundation` primitives — domain-agnostic utilities with no meaningful "which
  caller" question; the whole point is that any module can reach for them.
- A deliberately versioned, dependency-free contract target — `CheckoutAPI` (ADR-0001; see
  ADR-0016 once written) is the model: value types and a repository protocol, public, meant to be
  imported by the feature itself, its `Testing` target, and its micro-app, with the implementation
  kept separate specifically so the contract can be stable while the implementation isn't.

**Minimal API is usually correct for:**
- Anything inside a feature's `Framework` target that isn't the model's initializer, the repository
  protocol, the data types the signature requires, or the top-level View — see
  `Dont_Make_It_Public_draft.txt` for why this list is exactly four items and not more, for SwiftUI
  specifically.
- Anything that became `public` to satisfy one caller. That's the `@_spi` case (§1.2), not the
  `public` case.

**The question that actually decides it, either way:** not "does something outside this module
need this" — both branches above pass that test — but "is this a stable contract meant for anyone,
or a narrow accommodation for someone specific." The first is `public`. The second is `@_spi`. Most
mistaken `public` declarations in practice are the second kind mislabeled as the first.

---

## 5. What erodes this, and why enforcement matters more than intent

The failure mode isn't a single bad decision — it's the same one ADR-0013 documents for a
different rule: an invariant enforced by one person's memory, applied correctly the first four
times, and silently skipped the fifth time by someone who didn't know it was a rule at all. A
module's public surface doesn't get bloated by one deliberate choice to abandon minimalism; it
grows one locally-reasonable `public` keyword at a time, each one solving exactly the problem in
front of whoever added it, until the accumulated surface is the entire module.

The fix is the same shape as every other rule in this repo that started as a convention and became
a check: `graph-tool check` for the package-graph half, and — once written — a declaration-level
check for the "is this actually used outside the module" half. Until both exist and run in CI, this
document is a statement of intent, not a guarantee. Say so plainly rather than implying otherwise.

---

## References

- ADR-0001 (feature module isolation), ADR-0005 (micro-apps), ADR-0011 (repository protocol
  abstraction), ADR-0013 (self-guarding side effects, cited above for the erosion pattern)
- `docs/build-time-baseline.md`, `docs/test-coverage-baseline.md` — the real measurements this
  document's cost argument rests on
- `docs/design-patterns.md` — Mediator, Bridge, and Ports & Adapters entries cover the enforcement
  and injection mechanisms this document assumes
- `ShopAppDocs/Dont_Make_It_Public_draft.txt`, `ShopAppDocs/article-3-outline.md` — the
  SwiftUI-specific instance of this principle (what a feature module's public API actually is, and
  why the View isn't part of it)
