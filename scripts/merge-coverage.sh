#!/usr/bin/env bash
#
# Merges code coverage across every package test target into one aggregate
# report.
#
# Why this exists: there is no single scheme that runs every test target at
# once — each feature's XxxTests is its own SPM package scheme, plus
# ShopAppTests (composition-root tests, hosted inside the ShopApp app target)
# is a separate xcodebuild invocation again. `xcrun xccov view --report` on a
# single .xcresult only reports coverage for whatever that one run touched, so
# adding up each target's own top-line percentage double-counts nothing but
# also never credits one target's tests for exercising another target's code
# (e.g. ShopAppTests exercising ShopCore/Checkout/PastPurchases/Promotions).
# The only way to get a true, de-duplicated, "how much of the app do ALL the
# tests together cover" number is to merge the raw .profdata files with
# llvm-profdata and report against every test binary at once with llvm-cov —
# that's what this script does.
#
# Usage:
#   scripts/merge-coverage.sh [simulator-id]
#
# Output:
#   .build/coverage-merge/<Scheme>.profdata   - raw coverage data per target
#   .build/coverage-merge/<Scheme>.bin        - the test binary that produced it
#   .build/coverage-merge/merged.profdata     - all of the above, merged
#   .build/coverage-merge/<Scheme>.log        - full xcodebuild test output
#   Per-target and merged summary tables printed to stdout.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

SIM_ID="${1:-6BC3B504-CD2B-4F38-9897-87217E9D3B45}"
DD="$REPO_ROOT/.build/coverage-derived-data"
OUT="$REPO_ROOT/.build/coverage-merge"

# Every package test target with a CLI-runnable scheme, plus ShopApp itself
# (whose scheme's test action runs ShopAppTests, the composition-root suite).
# CommonTests is excluded — no .xcscheme exists for it yet.
SCHEMES=(AccountTests CheckoutTests PastPurchasesTests PromotionsTests SearchTests StoreTests SuggestionsTests SupportTests ShopApp)

rm -rf "$OUT"
mkdir -p "$OUT"

echo "Simulator: $SIM_ID"
echo "Derived data (shared across runs, for build speed): $DD"
echo

declare -a PROFDATA_FILES=()
declare -a BINARY_FILES=()
declare -a RAN_OK=()
declare -a SKIPPED=()

for scheme in "${SCHEMES[@]}"; do
    echo "=== $scheme ==="
    if xcodebuild test -scheme "$scheme" \
        -destination "platform=iOS Simulator,id=$SIM_ID" \
        -derivedDataPath "$DD" \
        -enableCodeCoverage YES \
        > "$OUT/$scheme.log" 2>&1
    then
        echo "  tests passed"
    else
        echo "  ⚠️  test run reported failures (see $OUT/$scheme.log) — coverage is still collected for whatever executed"
    fi

    profdata="$DD/Build/ProfileData/$SIM_ID/Coverage.profdata"
    if [[ ! -f "$profdata" ]]; then
        echo "  ⚠️  no Coverage.profdata produced — skipping $scheme"
        SKIPPED+=("$scheme (no profdata)")
        continue
    fi
    cp "$profdata" "$OUT/$scheme.profdata"

    # ShopAppTests is hosted inside ShopApp.app; every other scheme's test
    # bundle is a standalone .xctest named after the scheme itself.
    if [[ "$scheme" == "ShopApp" ]]; then
        binary=$(find "$DD/Build/Products/Debug-iphonesimulator" -path "*ShopAppTests.xctest/ShopAppTests" -type f 2>/dev/null | head -1)
    else
        binary="$DD/Build/Products/Debug-iphonesimulator/$scheme.xctest/$scheme"
    fi
    if [[ -z "${binary:-}" || ! -f "$binary" ]]; then
        echo "  ⚠️  expected test binary not found — skipping $scheme"
        SKIPPED+=("$scheme (no binary)")
        continue
    fi
    cp "$binary" "$OUT/$scheme.bin"

    echo "  per-target totals (this scheme's own coverage only):"
    xcrun llvm-cov report "$binary" -instr-profile="$OUT/$scheme.profdata" \
        -ignore-filename-regex='SourcePackages/checkouts' | tail -3

    PROFDATA_FILES+=("$OUT/$scheme.profdata")
    BINARY_FILES+=("$OUT/$scheme.bin")
    RAN_OK+=("$scheme")
    echo
done

if [[ ${#PROFDATA_FILES[@]} -eq 0 ]]; then
    echo "No coverage data collected from any target — nothing to merge." >&2
    exit 1
fi

echo "Merging ${#PROFDATA_FILES[@]} profiles: ${RAN_OK[*]}"
xcrun llvm-profdata merge -sparse "${PROFDATA_FILES[@]}" -o "$OUT/merged.profdata"

if [[ ${#SKIPPED[@]} -gt 0 ]]; then
    echo "Skipped (excluded from merge): ${SKIPPED[*]}"
fi
echo

# llvm-cov report takes one positional binary and every additional binary via
# repeated -object flags.
primary="${BINARY_FILES[0]}"
extra_object_flags=()
for b in "${BINARY_FILES[@]:1}"; do
    extra_object_flags+=(-object "$b")
done

echo "=== Merged report — our own source only (dependencies excluded) ==="
xcrun llvm-cov report "$primary" "${extra_object_flags[@]}" \
    -instr-profile="$OUT/merged.profdata" \
    -ignore-filename-regex='SourcePackages/checkouts'

echo
echo "=== Merged report — every file including third-party dependencies ==="
xcrun llvm-cov report "$primary" "${extra_object_flags[@]}" \
    -instr-profile="$OUT/merged.profdata" | tail -3
