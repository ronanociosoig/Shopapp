#!/usr/bin/env bash
#
# Launches ShopApp on a simulator and opens a screen via the Debug-only
# --agent-route launch argument (see AppModel.swift, EXPERIMENT block). The
# route is read once at startup, so this relaunches the app; it does not
# dispatch a URL, and it needs no URL scheme.
#
# Requires a Debug build of ShopApp already installed on the target simulator.
# A Release build ignores the argument by construction, so this does nothing
# useful against one.
#
# Routes the app currently understands:
#   account/saved-cards                        Account tab with the Saved Cards sheet open
#   search/category/Electronics/product/<id>   Search tab with the product's detail screen open
#                                              (MacBook Air 15" is 00000000-0000-0000-0001-000000000002)
#
# Usage:
#   scripts/agent-route.sh [route] [udid-or-booted]
#   (defaults: account/saved-cards, "booted". Pass an explicit UDID when more
#   than one simulator is booted; find it with `xcrun simctl list devices | grep Booted`.)
#
# Examples:
#   scripts/agent-route.sh
#   scripts/agent-route.sh account/saved-cards 17CC19D6-C277-4FDE-A68B-FC3DA1B71A0A

set -euo pipefail

BUNDLE_ID="com.shopapp.demo.app"
ROUTE="${1:-account/saved-cards}"
TARGET="${2:-booted}"

case "$ROUTE" in
    account/saved-cards) ;;
    search/category/Electronics/product/*) ;;
    *)
        echo "Unknown route: $ROUTE" >&2
        echo "Known routes: account/saved-cards, search/category/<name>/product/<uuid>" >&2
        exit 1
        ;;
esac

echo "Launching $BUNDLE_ID on $TARGET with --agent-route $ROUTE"
xcrun simctl launch --terminate-running-process "$TARGET" "$BUNDLE_ID" --agent-route "$ROUTE"
