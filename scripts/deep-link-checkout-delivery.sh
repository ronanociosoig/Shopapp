#!/usr/bin/env bash
#
# Dispatches a real shopapp://checkout/delivery deep link via `simctl openurl`
# — the manual check used to confirm the Checkout "Delivery & Extras" deep
# link end-to-end, distinct from what DeepLinkTests.swift already proves at
# the unit level.
#
# Unlike the Promotions deep link, this one carries no id — Checkout doesn't
# need one, it resolves "Delivery & Extras" from its own state (the cart,
# and a saved shipping address) the same way a real user reaching that step
# through the funnel would. That also means it can legitimately refuse: an
# empty cart or no saved address switches to the Cart tab but goes no
# further, landing on the Cart screen itself rather than the funnel step.
# Add an item to the cart and make sure a saved address exists (launch with
# --ui-testing for deterministic stub data) to see the success path instead.
#
# Requires ShopApp to already be installed and running on the target
# simulator — this only dispatches the URL, it doesn't build, install, or
# launch.
#
# Launch with --ui-testing so the app wires up StubAccountRepository (which
# ships a default saved address) instead of the real, server-backed one:
#   xcrun simctl launch booted com.shopapp.demo.app --ui-testing
#
# Usage:
#   scripts/deep-link-checkout-delivery.sh [udid-or-booted]
#   ("booted" picks one booted simulator with no error even when several
#   are booted, and Apple doesn't document which one it picks. Pass an
#   explicit UDID whenever more than one simulator might be booted —
#   `xcrun simctl list devices | grep Booted` to find it.)
#
# Examples:
#   scripts/deep-link-checkout-delivery.sh
#   scripts/deep-link-checkout-delivery.sh 739542F6-D233-40F2-B998-07E064325EB2

set -euo pipefail

TARGET="${1:-booted}"
URL="shopapp://checkout/delivery"

echo "Dispatching $URL to $TARGET"
xcrun simctl openurl "$TARGET" "$URL"

echo
echo "If a system 'Open in \"ShopApp\"?' confirmation sheet appears, tap Open to let the"
echo "dispatch continue through to the app."
