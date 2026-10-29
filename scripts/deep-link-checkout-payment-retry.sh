#!/usr/bin/env bash
#
# Dispatches a real shopapp://checkout/payment-retry deep link via
# `simctl openurl` — the manual check used to confirm the "select a new
# payment method" deep link end-to-end, distinct from what
# DeepLinkTests.swift already proves at the unit level.
#
# This is for a payment problem detected after the customer has already
# left the payment step — a delayed authorization check, a fraud review —
# as opposed to the synchronous decline `submitPayment` already handles via
# the `paymentFailed` sheet. It lands directly on Payment Method, skipping
# Address and Delivery & Extras, rather than resetting to Address the way
# `retryPayment()` does for a decline caught mid-submission.
#
# Like `checkout/delivery`, this carries no id — Checkout resolves the
# shipping address from its own state (the cart, and a saved address) the
# same way a real user reaching that step through the funnel would, and
# legitimately refuses (switches to the Cart tab but goes no further) when
# the cart is empty or there's no saved address.
#
# Requires ShopApp to already be installed and running on the target
# simulator — this only dispatches the URL, it doesn't build, install, or
# launch.
#
# Launch with --ui-testing for deterministic stub data — StubAccountRepository
# ships a default saved address — and add an item to the cart to see the
# success path:
#   xcrun simctl launch booted com.shopapp.demo.app --ui-testing
#
# Usage:
#   scripts/deep-link-checkout-payment-retry.sh [udid-or-booted]
#
# Examples:
#   scripts/deep-link-checkout-payment-retry.sh
#   scripts/deep-link-checkout-payment-retry.sh 739542F6-D233-40F2-B998-07E064325EB2

set -euo pipefail

TARGET="${1:-booted}"
URL="shopapp://checkout/payment-retry"

echo "Dispatching $URL to $TARGET"
xcrun simctl openurl "$TARGET" "$URL"

echo
echo "If a system 'Open in \"ShopApp\"?' confirmation sheet appears, tap Open to let the"
echo "dispatch continue through to the app."
