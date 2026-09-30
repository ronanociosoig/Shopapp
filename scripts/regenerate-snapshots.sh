#!/usr/bin/env bash
#
# Force-regenerates every committed snapshot reference, across every module,
# against one pinned simulator + OS combination — non-interactively.
#
# Why this exists: swift-snapshot-testing's references are baked to the
# exact simulator/OS they were recorded on (see ADR-0009 — "Images recorded
# on one simulator configuration will fail on another"). CI runs a specific,
# fixed combination (currently iOS 27 / iPhone 17); local development often
# runs on whatever simulator happens to be booted, or on "latest" with no OS
# pinned at all. When those drift, CI's snapshot tests fail for a reason
# that has nothing to do with the actual UI — the committed PNGs are
# correct, just recorded against the wrong device. This re-records every
# reference against CI's exact destination, so "passes in CI" and "passes
# with this script" mean the same thing.
#
# The same drift applies to language/region, not just device/OS: PriceLabel
# renders via `.currency(code: "EUR")`, which pins the currency but not the
# locale — symbol position and separators still follow whatever region the
# simulator happens to be set to (`2.499,99 €` under es_ES vs. `€2,499.99`
# under en_US, pixel-identical otherwise). A simulator's region is a
# persistent Settings.app value with no CI-visible default, so leaving it
# unpinned makes every currency-rendering snapshot depend on an environment
# detail nothing in this repo records. `-testLanguage`/`-testRegion` pin it
# the same way `-destination` pins device/OS.
#
# Mechanism, same one run-tests.sh's reset-snapshots uses and for the same
# reason: xcodebuild-launched tests don't reliably forward the invoking
# shell's environment to the test process (see replay-record.sh's header on
# the identical problem for REPLAY_RECORD_MODE) — so this doesn't try to set
# SNAPSHOT_TESTING_RECORD=all as a shell env var. It deletes the existing
# PNGs and relies on the library's own default record mode (.missing),
# which needs no env var at all. The first run per target is *expected* to
# report failures — that's it writing fresh references, not a regression.
# The second run confirms they now pass.
#
# Usage:
#   scripts/regenerate-snapshots.sh [target|all] [device] [os] [language] [region]
#   (defaults: all, iPhone 17, 27.0, en, US — CI's current combination)
#
# Examples:
#   scripts/regenerate-snapshots.sh                  # everything, CI's destination + locale
#   scripts/regenerate-snapshots.sh Checkout
#   scripts/regenerate-snapshots.sh all "iPhone 17" 27.0 en US
#
# ALWAYS inspect the newly-recorded PNGs under __Snapshots__ before
# committing — a snapshot silently rendering wrong still "passes" against
# itself once re-recorded; only your own eyes catch that, not this script.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Same target list and scheme/snapshot-dir mapping as run-tests.sh, kept in
# sync deliberately — this is the bulk, non-interactive sibling of that
# script's `reset-snapshots`, not a separate source of truth for targets.
TARGETS=(Store Account Search Checkout Support Suggestions Promotions PastPurchases ShopApp)

scheme_for() {
    case "$1" in
        ShopApp) echo "ShopApp" ;;
        *)       echo "$1Tests" ;;
    esac
}

extra_args_for() {
    case "$1" in
        ShopApp) echo "-only-testing:ShopAppTests" ;;
        *)       echo "" ;;
    esac
}

snapshot_dir_for() {
    case "$1" in
        ShopApp) echo "$REPO_ROOT/Shop/Tests/Sources/__Snapshots__" ;;
        *)       echo "$REPO_ROOT/Features/$1/Tests/Sources/__Snapshots__" ;;
    esac
}

is_known_target() {
    local t="$1"
    for known in "${TARGETS[@]}"; do
        [[ "$t" == "$known" ]] && return 0
    done
    return 1
}

targets_for_arg() {
    if [[ "$1" == "all" ]]; then
        printf '%s\n' "${TARGETS[@]}"
    else
        if ! is_known_target "$1"; then
            echo "error: unknown target '$1'. Known targets: ${TARGETS[*]} (or 'all')" >&2
            exit 1
        fi
        echo "$1"
    fi
}

usage() {
    echo "Usage: $0 [target|all] [device] [os]"
    echo "  (defaults: all, iPhone 17, 27.0 — CI's current combination)"
    echo "Known targets: ${TARGETS[*]}"
    exit 1
}

run_target_tests() {
    local target="$1" destination="$2" language="$3" region="$4"
    local scheme extra
    scheme="$(scheme_for "$target")"
    extra="$(extra_args_for "$target")"

    # shellcheck disable=SC2086
    xcodebuild test \
        -scheme "$scheme" \
        -destination "$destination" \
        -testLanguage "$language" -testRegion "$region" \
        $extra 2>&1 | tee /tmp/regenerate-snapshots-last.log \
        | grep -E "Test run with|\*\* TEST (SUCCEEDED|FAILED)|error:" || true
    grep -q "TEST SUCCEEDED" /tmp/regenerate-snapshots-last.log
}

regenerate_one() {
    local target="$1" destination="$2" language="$3" region="$4"
    local dir
    dir="$(snapshot_dir_for "$target")"

    echo "=== $target ==="

    if [[ -d "$dir" ]]; then
        local count
        count="$(find "$dir" -name "*.png" | wc -l | tr -d ' ')"
        if [[ "$count" -gt 0 ]]; then
            find "$dir" -name "*.png" -delete
            echo "  deleted $count existing reference(s) in ${dir#"$REPO_ROOT"/}"
        else
            echo "  no existing references in ${dir#"$REPO_ROOT"/} (nothing to delete)"
        fi
    else
        echo "  no __Snapshots__ directory yet — will be created"
    fi

    echo "  recording pass (expected to report failures — that's it writing fresh references)"
    run_target_tests "$target" "$destination" "$language" "$region" || true

    echo "  confirmation pass (should pass now)"
    if run_target_tests "$target" "$destination" "$language" "$region"; then
        echo "  $target: PASSED — references now match \"$destination\" [$language-$region]"
        return 0
    else
        echo "  $target: FAILED on the confirmation pass — see /tmp/regenerate-snapshots-last.log"
        return 1
    fi
}

ARG="${1:-all}"
[[ "$ARG" == "-h" || "$ARG" == "--help" ]] && usage

DEVICE="${2:-iPhone 17}"
OS_VERSION="${3:-27.0}"
LANGUAGE="${4:-en}"
REGION="${5:-US}"
DESTINATION="platform=iOS Simulator,name=$DEVICE,OS=$OS_VERSION"

echo "Regenerating snapshots against: $DESTINATION [$LANGUAGE-$REGION]"
echo

failures=()
while IFS= read -r target; do
    regenerate_one "$target" "$DESTINATION" "$LANGUAGE" "$REGION" || failures+=("$target")
    echo
done < <(targets_for_arg "$ARG")

if [[ ${#failures[@]} -gt 0 ]]; then
    echo "Failed to regenerate cleanly: ${failures[*]}"
    echo "Inspect /tmp/regenerate-snapshots-last.log for the last one."
    exit 1
fi

echo "All snapshot references regenerated against \"$DESTINATION\" [$LANGUAGE-$REGION]."
echo "Inspect the new PNGs under __Snapshots__ before committing — a snapshot"
echo "that silently renders wrong will still \"pass\" against itself."
