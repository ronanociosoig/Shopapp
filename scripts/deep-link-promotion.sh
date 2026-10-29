#!/usr/bin/env bash
#
# Dispatches a real shopapp://promotions/<id> deep link via `simctl openurl`
# — the same manual check used to confirm the Promotions deep link
# end-to-end (real OS URL-scheme registration, real dispatch, real
# navigation), distinct from what DeepLinkTests.swift already proves at the
# unit level.
#
# Requires ShopApp to already be installed and running on the target
# simulator — this only dispatches the URL, it doesn't build, install, or
# launch.
#
# Launch with the --ui-testing argument so the app wires up
# StubPromotionsRepository instead of the real, server-backed one (see
# ShopAppMain.swift). Without it, the app's promotions come from
# ShopAppServer's own seed data, which uses different ids for the same
# titles than Promotion.stubs does — this script's default id will dispatch
# but silently fail to match anything:
#   xcrun simctl launch booted com.shopapp.demo.app --ui-testing
#
# A real dispatch surfaces one thing a unit test can't: iOS shows an
# "Open in \"ShopApp\"?" system confirmation sheet before the app ever sees
# the URL, because simctl openurl acts like an external caller (Safari,
# Messages, another app) would, not like the app opening itself. Tap Open by
# hand, or drive it with RocketSim if installed:
#   rocketsim interact tap --label Open --screen latest
#
# Usage:
#   scripts/deep-link-promotion.sh [promotion-id] [udid-or-booted]
#   (defaults: Promotion.stubs[0]'s fixed id — "Weekend Flash Sale" — a real,
#   always-valid match, so running this with no arguments demonstrates the
#   success path; pass any other value, like `uuidgen`'s output, to
#   deliberately exercise the "unknown id, fails safe" path instead.
#   "booted" — picks one booted simulator with no error even when several
#   are booted, and Apple doesn't document which one it picks. Pass an
#   explicit UDID whenever more than one simulator might be booted —
#   `xcrun simctl list devices | grep Booted` to find it.)
#
# Examples:
#   scripts/deep-link-promotion.sh
#   scripts/deep-link-promotion.sh "$(uuidgen)"
#   scripts/deep-link-promotion.sh 00000000-0000-0000-0000-000000000001 739542F6-D233-40F2-B998-07E064325EB2

set -euo pipefail

PROMOTION_ID="${1:-00000000-0000-0000-0000-000000000001}"
TARGET="${2:-booted}"
URL="shopapp://promotions/$PROMOTION_ID"

echo "Dispatching $URL to $TARGET"
xcrun simctl openurl "$TARGET" "$URL"

echo
echo "If a system 'Open in \"ShopApp\"?' confirmation sheet appears, tap Open to let the"
echo "dispatch continue through to the app."
