# Build-time baseline, before the API-module split

**Date:** 2026-08-21
**Git commit:** `c38c75299099ba9e0da7dfb33d33d1ae50cfd8cb` (working tree clean at time of measurement)
**Purpose:** a written "before" record, taken ahead of evaluating a production-API / test-API /
MicroApp-dev-support module split (Article 3 — see `ShopAppDocs/article-3-outline.md` and
`ShopAppDocs/Dont_Make_It_Public_draft.txt`). Splitting each feature into more, smaller SPM library
products is expected to have *some* compile-time cost — smaller modules mean more module-boundary
overhead (interface parsing, cross-module optimization barriers) even if per-module work shrinks — and
this record exists so that cost can be measured against a real number instead of guessed at after the
fact. Re-run the same three measurements, same methodology, after the split lands, and diff against this.

## Environment

- **Machine:** Apple M4, 16 GB RAM
- **Xcode:** 26.4 (build 17E192)
- **Swift:** 6.3 driver (swiftlang-6.3.0.123.5, clang-2100.0.123.102)
- **Scheme / destination:** `ShopApp` scheme, `platform=iOS Simulator,id=6BC3B504-CD2B-4F38-9897-87217E9D3B45` (an iPhone 17 Pro simulator)
- **Package graph at measurement time:** 74 targets total (per `xcodebuild`'s own dependency-graph log), spanning 8 feature modules + 8 `XxxTesting` targets + `ShopCore`/`ShopApp` + external dependencies (CasePaths, swift-navigation, swift-snapshot-testing, Replay, swift-syntax and its sub-targets, swift-argument-parser, swift-custom-dump, xctest-dynamic-overlay)

## Methodology

Before the clean-build measurement, both of this project's DerivedData directories and the local
`.build/` were removed, forcing every target (ours and every dependency) to recompile from nothing.
Package checkouts were still resolved from local cache (`Fetching from ... (cached)` for every
dependency in the log — no network re-fetch), so the timings below measure compilation, not package
resolution or download.

Wall-clock (`real`) time from `/usr/bin/time -p` is the number to trust. The `user`/`sys` figures
`/usr/bin/time` reports are **not** reliable here — `xcodebuild` fans work out across many
`swift-frontend` worker processes that aren't direct children of the timed process, so those two
numbers under-report actual CPU time substantially. Don't compare `user`/`sys` before/after; compare
`real` only.

## Results

### 1. Clean build (cold DerivedData + `.build`, full `ShopApp` scheme)

```
xcodebuild build -scheme ShopApp -destination 'platform=iOS Simulator,id=<sim>'
```

**real 48.75s** (user 8.26s, sys 4.06s — see caveat above)

984 compile-related build steps executed; every one of the 74 targets in the dependency graph built
from nothing. `BUILD SUCCEEDED`.

### 2. No-op incremental rebuild (immediately re-run, nothing changed)

```
xcodebuild build -scheme ShopApp -destination 'platform=iOS Simulator,id=<sim>'
```

**real 3.01s** (user 1.27s, sys 0.53s)

The floor cost of invoking `xcodebuild` against this scheme when there is genuinely nothing to do —
package graph resolution, dependency-graph computation, and up-to-date checks across 74 targets, with
no compilation.

### 3. Single-file touch in a leaf feature module

```
touch Features/Store/Framework/Sources/StoreView.swift
xcodebuild build -scheme ShopApp -destination 'platform=iOS Simulator,id=<sim>'
```

**real 3.49s** (user 1.24s, sys 0.42s)

Only the `Store` target recompiled — one `SwiftCompile` of `StoreView.swift`, one `SwiftDriver
Compilation` pass for the `Store` module. Nothing downstream (`ShopCore`, `ShopApp`, or any other
feature module) recompiled or relinked in this run. This is the number most directly relevant to the
API-module split: today, one `Store` library product means "touch anything in Store" and "touch
`Store`'s public API" cost the same to rebuild, because there's only one target to invalidate. After a
split, a change to `Store`'s *implementation* target should ideally still cost close to this — a change
to its *API* target is the case actually worth watching, since that's the one with more downstream
consumers (the composition root, and potentially a MicroApp-dev-support target) that could be forced to
rebuild too.

## What to re-measure after the module split

Repeat all three measurements, same machine, same scheme/destination, same methodology (wipe
DerivedData + `.build` for the clean-build number only; leave build products in place for the two
incremental numbers). Additionally worth adding at that point, since it won't exist as a meaningful
distinction until the split happens:

- Touch a file in a feature's **implementation** target only — expect this to stay close to today's
  3.49s if the split is done well.
- Touch a file that changes a feature's **public API** target — this is the one expected to have a real,
  non-zero cost, since it invalidates the module boundary itself for every downstream consumer.
