# iPhone Duo compatibility

**Date:** 2026-10-01
**Git commit:** `5e88e26f5435181dbdf799b5bb5d247d72da5ca7`
**Status:** Tested manually; the app works overall. Some layout changes would improve the experience
but none are required. No automated snapshot coverage exists for this device at the time of writing —
see "What's not covered" below.

## Environment

- **Device type:** `iPhone Duo` (`com.apple.CoreSimulator.SimDeviceType.iPhone-Duo`), model identifier
  `iPhone19,4`.
- **Minimum runtime:** iOS 27.1 — not available under iOS 27.0, the runtime this repo's CI and every
  existing snapshot baseline are currently pinned to (see `.circleci/config.yml`'s `iphone_os`
  parameter and `scripts/regenerate-snapshots.sh`'s defaults).
- **Xcode:** 27.1 (27A9269).
- **Display:** one continuous display port (`LCD`), 2034×1398 px at time of testing, on a single
  resizable scene (`com.apple.CoreSimulator.display.resizableScene = true` in the device's own
  simulator profile) — modeled as one canvas, not two separate hardware panels. Scale factor (needed
  to convert to points for layout reasoning) was not measured.

## What was tested

- The full `ShopApp` scheme built and installed cleanly against a real `iPhone Duo` simulator on the
  iOS 27.1 runtime.
- The app launched successfully — confirmed via a live process ID, not just a successful build.
- The three resizability prerequisites Apple's `app-resizability` Xcode skill checks were verified
  against every target's `project.yml` `info.properties` block (all 9: `ShopApp` plus the 8 micro-apps):
  - Launch screen declared — pass, every target.
  - No `UIRequiresFullScreen` opt-out set — pass, every target. Nothing to migrate.
  - No incomplete iPad-specific orientation override — pass, every target. None declare an
    `~ipad`-suffixed orientation key at all, so there's no partial declaration to complete.
- A full source scan for the five API patterns that most commonly break a resizable or foldable scene
  found **zero occurrences anywhere in the codebase**:
  - `UIScreen.main` / `UIScreen.mainScreen`
  - `interfaceOrientation`
  - `userInterfaceIdiom` / `UI_USER_INTERFACE_IDIOM()`
  - Manual `safeAreaInsets` / `topLayoutGuide` / `bottomLayoutGuide` handling
  - `UIApplicationDelegate`-based (non-scene) lifecycle

  ShopApp is SwiftUI-native throughout and never adopted any of these, so there was nothing to
  migrate going in.

## What works

The app builds, launches, and has been manually exercised on iPhone Duo with no structural changes
required — no crash, no failed launch, no Info.plist or build-setting change needed. The architecture
this repo already follows (model-driven navigation, no hand-rolled UIKit shared-state lookups) turned
out to cost nothing extra to support this device.

## What could be improved

- **No size-class awareness anywhere.** Nothing in the codebase reads `horizontalSizeClass`,
  `verticalSizeClass`, or uses `GeometryReader` to adapt to available width.
  `StoreView.productGrid` hardcodes exactly two products per row regardless of how much width is
  actually available (`Features/Store/Framework/Sources/StoreView.swift`), and `SearchView`'s results
  grid has the same shape of hardcoding. On Duo's much wider unfolded canvas this leaves unused
  horizontal space rather than taking advantage of it.
- **Suggested next step, not yet implemented:** read `@Environment(\.horizontalSizeClass)` in
  `StoreView` and `SearchView` and vary the column count accordingly, rather than a fixed pair.

## What's not covered

No automated snapshot test exists for this device yet. Every snapshot test across all 9 modules
targets a single hardcoded device config, `.image(layout: .device(config: .iPhone13Pro))`. The
`swift-snapshot-testing` release currently pinned in `Package.swift` (1.19.6) has no built-in Duo
`ViewImageConfig` — checked directly against its source at that tag. Adding coverage would need
either:

- a hand-built custom `ViewImageConfig` using this device's real point dimensions (the scale factor
  above still needs measuring), or
- waiting for `swift-snapshot-testing` to ship one upstream.

Until one of those happens, Duo compatibility is a manually-verified property of this app, not a
continuously-verified one — a future regression here would not be caught by CI.

## How to test manually

```bash
xcrun simctl create "iPhone Duo" "iPhone Duo" "iOS27.1"
xcrun simctl boot <udid>

xcodebuild build -scheme ShopApp -destination 'id=<udid>'

xcrun simctl install <udid> <path-to-ShopApp.app>
xcrun simctl launch <udid> com.shopapp.demo.app
```

Requires the iOS 27.1 simulator runtime specifically — the iOS 27.0 runtime this repo's CI and
existing snapshot baselines pin everything else to does not support this device.

## References

- `docs/build-time-baseline.md`, `docs/test-coverage-baseline.md` — the same measured-not-assumed
  convention this document follows.
- Apple's `app-resizability` Xcode skill — the prerequisite checks and legacy-API scan above follow
  its workflow and task registry.
