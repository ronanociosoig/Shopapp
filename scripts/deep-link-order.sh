#!/usr/bin/env bash
#
# Dispatches a real shopapp://orders/<id> deep link via `simctl openurl` —
# the manual check used to confirm the PastPurchases "Order Detail" deep
# link end-to-end, distinct from what DeepLinkTests.swift already proves at
# the unit level.
#
# Requires ShopApp to already be installed and running on the target
# simulator — this only dispatches the URL, it doesn't build, install, or
# launch.
#
# PastPurchasesRepository has no --ui-testing stub path (unlike Store,
# Account, Checkout, Promotions, Suggestions) — it's always
# DefaultPastPurchasesRepository, which loads from this simulator's local
# UserDefaults order history first and only falls back to the real local
# ShopAppServer when that's empty (see
# DefaultPastPurchasesRepository.fetchOrders()). A device with any order
# history already saved locally — e.g. from a prior real checkout run in the
# simulator — will never see this script's default id, because the local
# store wins and the remote seed (which does carry that id) never gets
# fetched. If the deep link silently lands on the order list instead of a
# detail screen, that's almost certainly why: uninstall the app first to
# clear its UserDefaults and force a fresh remote fetch:
#   xcrun simctl uninstall booted com.shopapp.demo.app
#
# Usage:
#   scripts/deep-link-order.sh [order-id] [udid-or-booted]
#   (default: PastOrder.stubs[0]'s id — the MacBook Pro 16" + Sony
#   headphones order — which ShopAppServer's seed data also uses, so this
#   script's default id resolves the same way regardless of whether the
#   client ends up reading local or remote, as long as local is empty.)
#
# Examples:
#   scripts/deep-link-order.sh
#   scripts/deep-link-order.sh "$(uuidgen)"
#   scripts/deep-link-order.sh 00000000-0000-0000-0009-000000000001 739542F6-D233-40F2-B998-07E064325EB2

set -euo pipefail

ORDER_ID="${1:-00000000-0000-0000-0009-000000000001}"
TARGET="${2:-booted}"
URL="shopapp://orders/$ORDER_ID"

echo "Dispatching $URL to $TARGET"
xcrun simctl openurl "$TARGET" "$URL"

echo
echo "If a system 'Open in \"ShopApp\"?' confirmation sheet appears, tap Open to let the"
echo "dispatch continue through to the app."
