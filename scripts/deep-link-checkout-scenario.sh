#!/usr/bin/env bash
#
# Experiment: dispatches a real checkoutscenarios://<scenario> deep link to the Checkout
# micro-app (not the production ShopApp) via `simctl openurl` — the manual check used to
# confirm the micro-app's own deep-link support end-to-end, distinct from what
# CheckoutScenarioTests.swift already proves at the unit level (CheckoutScenarioDeepLinkTests).
#
# This is a different deep-link surface from shopapp:// (see deep-link-checkout-*.sh): it
# targets a named CheckoutScenario — a freshly-constructed CheckoutModel from
# CheckoutScenarioFactory, not a live model's real cart/address state — so there's no feature
# host to match, just the scenario's own rawValue as the URL host.
#
# Requires the Checkout micro-app to already be installed and running on the target
# simulator — this only dispatches the URL, it doesn't build, install, or launch:
#   xcrun simctl install booted <path-to-Checkout.app>
#   xcrun simctl launch booted com.shopapp.demo.checkout
#
# Usage:
#   scripts/deep-link-checkout-scenario.sh [scenario-raw-value] [udid-or-booted]
#
# Examples:
#   scripts/deep-link-checkout-scenario.sh
#   scripts/deep-link-checkout-scenario.sh paymentFailed
#   scripts/deep-link-checkout-scenario.sh cart 739542F6-D233-40F2-B998-07E064325EB2
#
# Valid scenario raw values (see CheckoutScenario.swift):
#   cart, emptyCart, addressSelection, orderOptions, paymentMethod, cardEntry,
#   processing, confirmation, paymentFailed

set -euo pipefail

SCENARIO="${1:-cart}"
TARGET="${2:-booted}"
URL="checkoutscenarios://${SCENARIO}"

echo "Dispatching $URL to $TARGET"
xcrun simctl openurl "$TARGET" "$URL"

echo
echo "If a system 'Open in \"Checkout\"?' confirmation sheet appears, tap Open to let the"
echo "dispatch continue through to the app."
