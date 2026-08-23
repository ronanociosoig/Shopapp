# scripts/

Small CLI helpers for workflows that would otherwise mean hand-editing XML or
retyping the same `xcodebuild` invocation. Each script is self-contained;
run one with no arguments (or see its own header comment) for full usage.

## run-tests.sh

Runs one or all of the feature-module test schemes via `xcodebuild` (the only
way to run them — see the root `CLAUDE.md`/`AGENTS.md`, plain `swift test`
fails outright), and resets stale snapshot references so they get
re-recorded on the next run.

```
scripts/run-tests.sh list
scripts/run-tests.sh test <target|all> [device]
scripts/run-tests.sh reset-snapshots <target|all> [name-substring]
```

- `list` — prints the known targets (the 8 feature modules, plus `ShopApp`
  for the composition-root `ShopAppTests`).
- `test` — runs the given target's scheme (or all of them) against a
  simulator, default device `iPhone 17`.
- `reset-snapshots` — lists the `__Snapshots__` PNGs matching a target
  (optionally filtered by a filename substring), lets you pick which to
  delete, then reminds you of the two-run workflow: the next `test` run
  fails on purpose while recording new references, the one after that
  should pass. Always inspect a newly-recorded PNG before committing it — a
  snapshot failure with no intentional UI change is a regression, not a
  baseline to paper over.

## replay-record.sh

Toggles `REPLAY_RECORD_MODE` on/off for a test scheme, to re-record a
[Replay](https://github.com/mattt/Replay) HAR fixture against a real local
backend (see `~/Projects/ShopAppServer`) instead of replaying the committed
one. Exists because `xcodebuild test` doesn't forward the invoking shell's
environment to the test process the way `swift test` does, so the env var
has to be injected via the scheme itself — this script makes (and reverts)
that scheme edit instead of hand-editing it each time.

```
scripts/replay-record.sh on [once|rewrite] [scheme]   (default: once, StoreTests)
scripts/replay-record.sh off [scheme]                 (default: StoreTests)
scripts/replay-record.sh status [scheme]              (default: StoreTests)
```

A scheme left in recording mode silently re-records on every future run —
always run `off` again after recording.

## merge-coverage.sh

Computes true, de-duplicated code coverage across *every* package test
target at once. No single scheme runs all of them together, and adding up
each target's own top-line percentage would double-count nothing but also
never credit one target's tests for exercising another's code (e.g.
`ShopAppTests` exercising `ShopCore`/`Checkout`/`PastPurchases`/`Promotions`).
This merges the raw `.profdata` files with `llvm-profdata` and reports
against every test binary at once with `llvm-cov`.

```
scripts/merge-coverage.sh [simulator-id]
```

Output lands in `.build/coverage-merge/`: each target's own `.profdata`/
`.bin`/`.log`, the merged `merged.profdata`, and per-target + merged summary
tables printed to stdout.
