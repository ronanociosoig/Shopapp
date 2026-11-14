#!/usr/bin/env bash
#
# Experiment: opens every CheckoutScenario in the Checkout micro-app, one after another,
# by dispatching checkoutscenarios://<scenario> through deep-link-checkout-scenario.sh.
# It uses the micro-app's own URL scheme, not the production app's shopapp:// links.
#
# The scenario names are read from Features/Checkout/App/Sources/CheckoutScenario.swift,
# so a new case is picked up without editing this script.
#
# Requires the Checkout micro-app to already be installed on the target simulator:
#   xcrun simctl install booted <path-to-Checkout.app>
#   xcrun simctl launch booted com.shopapp.demo.checkout
#
# Usage:
#   scripts/launch-checkout-scenarios.sh [udid-or-booted] [seconds-between]
#
# Examples:
#   scripts/launch-checkout-scenarios.sh
#   scripts/launch-checkout-scenarios.sh booted 3
#   scripts/launch-checkout-scenarios.sh 739542F6-D233-40F2-B998-07E064325EB2 2

set -euo pipefail

TARGET="${1:-booted}"
DELAY="${2:-2}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE="$REPO_ROOT/Features/Checkout/App/Sources/CheckoutScenario.swift"

if [[ ! -f "$SOURCE" ]]; then
    echo "error: cannot find $SOURCE" >&2
    exit 1
fi

# Scenario case declarations only ("    case name" with nothing after it). Switch-statement
# cases ("        case .name:") are indented further and end in a colon, so they don't match.
SCENARIOS=()
while IFS= read -r name; do
    SCENARIOS+=("$name")
done < <(sed -n -E 's/^    case ([a-zA-Z]+)$/\1/p' "$SOURCE")

if [[ ${#SCENARIOS[@]} -eq 0 ]]; then
    echo "error: no scenarios found in $SOURCE" >&2
    exit 1
fi

echo "Opening ${#SCENARIOS[@]} scenarios on $TARGET, ${DELAY}s apart"
for scenario in "${SCENARIOS[@]}"; do
    echo
    echo "== $scenario =="
    "$SCRIPT_DIR/deep-link-checkout-scenario.sh" "$scenario" "$TARGET"
    sleep "$DELAY"
done

echo
# ${SCENARIOS[-1]} needs bash 4.3+; macOS's /bin/bash is 3.2 and aborts with "bad array subscript".
echo "Done. Last scenario opened: ${SCENARIOS[${#SCENARIOS[@]}-1]}"
