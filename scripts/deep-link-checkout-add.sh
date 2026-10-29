#!/usr/bin/env bash
#
# Dispatches a real shopapp://checkout/add/<id>?name=...&price=...&guarantee=...
# deep link via `simctl openurl` — the manual check used to confirm the
# "add to cart" deep link end-to-end, distinct from what DeepLinkTests.swift
# already proves at the unit level.
#
# This is the one deep link in the app that carries the full product record
# in the URL itself rather than just an id to look up — Checkout has no
# product catalog of its own (Store does, and feature modules never import
# each other), so a marketing email's "Add to cart" button has nowhere else
# to get the name/price from. It lands on the same CheckoutFactory.addToCart
# entry point Store/Search/Suggestions already call through the composition
# root (see ADR-0003's Foundation-primitive callback) — not a new method,
# just a new caller of it.
#
# Requires ShopApp to already be installed and running on the target
# simulator — this only dispatches the URL, it doesn't build, install, or
# launch.
#
# Usage:
#   scripts/deep-link-checkout-add.sh [product-id] [name] [price] [guarantee] [udid-or-booted]
#   (defaults: CheckoutProduct.stubs[0] — a MacBook Pro 16" at 2499.99, with
#   the extended guarantee requested, so running this with no arguments
#   demonstrates the success path.)
#
# Examples:
#   scripts/deep-link-checkout-add.sh
#   scripts/deep-link-checkout-add.sh 00000000-0000-0000-0004-000000000006 "Anker USB-C Hub 7-in-1" 49.99 false
#   scripts/deep-link-checkout-add.sh 00000000-0000-0000-0004-000000000001 "MacBook Pro 16\"" 2499.99 true 739542F6-D233-40F2-B998-07E064325EB2

set -euo pipefail

PRODUCT_ID="${1:-00000000-0000-0000-0004-000000000001}"
NAME="${2:-MacBook Pro 16\"}"
PRICE="${3:-2499.99}"
GUARANTEE="${4:-true}"
TARGET="${5:-booted}"

ENCODED_NAME=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$NAME")
URL="shopapp://checkout/add/$PRODUCT_ID?name=$ENCODED_NAME&price=$PRICE&guarantee=$GUARANTEE"

echo "Dispatching $URL to $TARGET"
xcrun simctl openurl "$TARGET" "$URL"

echo
echo "If a system 'Open in \"ShopApp\"?' confirmation sheet appears, tap Open to let the"
echo "dispatch continue through to the app."
