#!/usr/bin/env bash
#
# Runs one (or all) feature-module test schemes via xcodebuild, and can reset
# snapshot references so they get re-recorded on the next run.
#
# Why this exists: `xcodebuild test -scheme XxxTests -destination '...'` is
# the only way to run these tests (see CLAUDE.md — plain `swift test` fails
# outright, this is an iOS-only package), and doing that by hand per-module
# every time is tedious. This wraps that invocation, and adds a
# `reset-snapshots` command for the ordinary "a snapshot legitimately needs
# updating" workflow: delete the stale reference(s), run the target once
# (swift-snapshot-testing writes the new reference and fails that run on
# purpose — this is expected, not a bug), then run it again to confirm it
# now passes. Always inspect a newly-recorded PNG before committing it —
# see CLAUDE.md: "a snapshot failure with no intentional UI change is a
# regression, not a baseline update."
#
# Usage:
#   scripts/run-tests.sh list
#   scripts/run-tests.sh test <target|all> [device]
#   scripts/run-tests.sh reset-snapshots <target|all> [name-substring]
#
# Examples:
#   scripts/run-tests.sh list
#   scripts/run-tests.sh test Support
#   scripts/run-tests.sh test all
#   scripts/run-tests.sh test Checkout "iPhone 17 Pro"
#   scripts/run-tests.sh reset-snapshots Support account_help
#   scripts/run-tests.sh reset-snapshots all

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_DEVICE="iPhone 17"

# target name -> (scheme, extra xcodebuild args, snapshot dir)
# ShopApp's tests aren't their own scheme — they're a -only-testing filter on
# the ShopApp scheme (see CLAUDE.md's "Full app" vs "Per-module" sections).
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

usage() {
    echo "Usage:"
    echo "  $0 list"
    echo "  $0 test <target|all> [device]              (default device: $DEFAULT_DEVICE)"
    echo "  $0 reset-snapshots <target|all> [name-substring]"
    echo
    echo "Targets: ${TARGETS[*]}"
    exit 1
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

run_one_test() {
    local target="$1" device="$2"
    local scheme extra
    scheme="$(scheme_for "$target")"
    extra="$(extra_args_for "$target")"

    echo "=== $target ($scheme) on \"$device\" ==="
    # shellcheck disable=SC2086
    if xcodebuild test \
        -scheme "$scheme" \
        -destination "platform=iOS Simulator,name=$device" \
        $extra 2>&1 | tee /tmp/run-tests-last.log | grep -E "Test run with|\*\* TEST (SUCCEEDED|FAILED)|error:"; then
        :
    fi
    if grep -q "TEST SUCCEEDED" /tmp/run-tests-last.log; then
        echo "$target: PASSED"
        return 0
    else
        echo "$target: FAILED — full log: /tmp/run-tests-last.log"
        return 1
    fi
}

cmd_list() {
    echo "Targets: ${TARGETS[*]}"
}

cmd_test() {
    local arg="${1:-}" device="${2:-$DEFAULT_DEVICE}"
    [[ -z "$arg" ]] && usage

    local failures=()
    while IFS= read -r target; do
        run_one_test "$target" "$device" || failures+=("$target")
        echo
    done < <(targets_for_arg "$arg")

    if [[ ${#failures[@]} -gt 0 ]]; then
        echo "Failed: ${failures[*]}"
        exit 1
    fi
    echo "All requested targets passed."
}

cmd_reset_snapshots() {
    local arg="${1:-}" pattern="${2:-}"
    [[ -z "$arg" ]] && usage

    local dirs=()
    while IFS= read -r target; do
        dirs+=("$(snapshot_dir_for "$target")")
    done < <(targets_for_arg "$arg")

    local matches=()
    for dir in "${dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r -d '' file; do
            matches+=("$file")
        done < <(find "$dir" -name "*.png" -print0 | { [[ -n "$pattern" ]] && grep -zi "$pattern" || cat; })
    done

    if [[ ${#matches[@]} -eq 0 ]]; then
        echo "No snapshot files matched (target: $arg, pattern: '${pattern:-<none>}')."
        exit 0
    fi

    echo "Matched ${#matches[@]} snapshot file(s):"
    local i=1
    for f in "${matches[@]}"; do
        echo "  [$i] ${f#"$REPO_ROOT"/}"
        i=$((i + 1))
    done

    echo
    read -r -p "Delete which? (comma-separated indices, 'all', or blank to cancel): " selection
    [[ -z "$selection" ]] && { echo "Cancelled."; exit 0; }

    local to_delete=()
    if [[ "$selection" == "all" ]]; then
        to_delete=("${matches[@]}")
    else
        IFS=',' read -ra indices <<< "$selection"
        for idx in "${indices[@]}"; do
            idx="$(echo "$idx" | tr -d '[:space:]')"
            if ! [[ "$idx" =~ ^[0-9]+$ ]] || (( idx < 1 || idx > ${#matches[@]} )); then
                echo "error: invalid index '$idx'" >&2
                exit 1
            fi
            to_delete+=("${matches[$((idx - 1))]}")
        done
    fi

    for f in "${to_delete[@]}"; do
        rm -v "$f"
    done

    echo
    echo "Deleted ${#to_delete[@]} file(s). Next steps:"
    echo "  1. $0 test $arg     — this run is EXPECTED to fail; it records new reference(s)."
    echo "  2. Inspect the new PNG(s) under __Snapshots__ — verify they look right."
    echo "  3. $0 test $arg     — should pass now."
    echo "  4. git add the new PNG(s) and commit alongside the code that changed them."
}

case "${1:-}" in
    list)            cmd_list ;;
    test)            shift; cmd_test "$@" ;;
    reset-snapshots) shift; cmd_reset_snapshots "$@" ;;
    *)               usage ;;
esac
