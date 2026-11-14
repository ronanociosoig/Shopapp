# Launch-argument routes and `scripts/agent-route.sh`

A companion to the deep-link article. It explains the second entry point into ShopApp's screens, the one used by developers and coding agents, and how the launch script drives it. The article's core message stays on deep links: this document is the mechanism behind one of the options it presents.

## Two ways in, one routing principle

ShopApp has two ways to open a screen from outside the app:

| | Deep link | Launch-argument route |
|---|---|---|
| Who sends it | Any app, web page, push notification, or `simctl openurl` | Only whoever launches the process: Xcode, `simctl launch`, a test harness |
| Channel | `shopapp://` URL, delivered by the OS | `--agent-route` argument, read by the app at startup |
| Available in | Debug and Release | Debug only |
| Who can reach it | Anyone who can open the scheme | Nobody on a device, since an App Store build cannot receive launch arguments |
| Entry point in code | `AppModel.handle(url:)` | `AppModel.dispatchAgentRoute()` |

Both entry points follow the same rule from ADR-0015. The composition root reads only the first path segment to choose a feature by name. The feature decodes everything after that and decides which screen to open. `AppModel` never builds a feature's `Destination`, and never parses a feature's path.

The launch-argument route is therefore not a second navigation system. It is a second way of delivering the same kind of input.

## The launch argument

The app reads the argument once, from the process arguments:

```text
--agent-route account/saved-cards
--agent-route search/category/Electronics/product/00000000-0000-0000-0001-000000000002
```

The first path segment names a feature. The rest is that feature's own grammar.

| Route | Feature | Decoded by | Result |
|---|---|---|---|
| `account/saved-cards` | Account | `AccountModel.handleAgentRoute(_:)` | Account tab, Saved Cards open |
| `search/category/<name>/product/<uuid>` | Search | `SearchModel.handleAgentRoute(_:)` | Search tab, product detail open |

Each feature's handler returns `true` when the route is its own. `AppModel` then selects the matching tab. The search handler looks the product up through its own repository, so the composition root never sees a `SearchProduct` being chosen.

## How the app dispatches a route

1. `ShopAppMain` attaches a `.task` to the root view. It is compiled only in Debug, and it calls `appModel.dispatchAgentRoute()`.
2. `dispatchAgentRoute()` reads the argument and splits it on `/`.
3. It removes the first segment and switches on it. The two cases are the constants in `AgentRouteFeature`, `account` and `search`.
4. For `account`, it calls the synchronous handler. For `search`, it awaits the asynchronous one, because the product lookup goes through the network or the seeded server.
5. If the feature returns `true`, `AppModel` sets `selectedTab`. Nothing else changes in `AppModel`.

The same feature handlers are reached a second way. In `AppModel+DeepLinks.swift`, two `#if DEBUG` cases, `account` and `search`, pass the URL's path segments to the same handlers. That is the URL-based option the article describes. The two options share the feature code, so a route is written once and can be reached either way.

## What `scripts/agent-route.sh` does

The script launches the app with a route. It does not build, install, or dispatch a URL.

```bash
scripts/agent-route.sh [route] [udid-or-booted]
```

- **Defaults:** `account/saved-cards` and `booted`.
- **Validation:** the route must match a known pattern: `account/saved-cards`, or `search/category/Electronics/product/<anything>`. Anything else exits with an error that lists the known routes.
- **Launch:** it runs

  ```bash
  xcrun simctl launch --terminate-running-process "$TARGET" com.shopapp.demo.app --agent-route "$ROUTE"
  ```

  `--terminate-running-process` restarts the app if it is already running, so the route is read on a fresh start.
- **Output:** one line naming the bundle, the target, and the route, then the process ID that `simctl` prints. In measurement it returned 137 to 190 bytes.

Because it only launches, the script needs a Debug build of ShopApp already installed on the target simulator. A Release build ignores the argument by construction, and the script will appear to succeed with no screen change.

### Why the script exists

An agent that wants a screen has two choices with the simulator:

1. **Navigate:** read the accessibility tree, find an element, tap it, and read the tree again, once per step. Every read returns the whole screen's element list.
2. **Launch to the screen:** one command, one short line of output.

For the MacBook Air 15" detail screen, the launch route returned 190 bytes in one tool call. Reaching the same screen through Mobile MCP took seven tool calls and read back about 57,700 bytes, most of it accessibility listings. The figures count bytes returned, not tokens billed by a model session, and only the store listing was measured exactly. The article carries those caveats.

## Release and what it means for installed users

The Release build of this repository contains none of the route's symbols or strings. It was checked by searching every Mach-O binary in the Debug and Release app bundles with `nm` and `strings`. The Debug bundle contains `handleAgentRoute`, `dispatchAgentRoute`, `AgentRouteFeature`, and the route strings. The Release bundle contains none of them.

So an installed App Store user cannot reach the route: no launch argument arrives, and the code is not in the binary.

## Limits

- **One screen state per route.** `SearchModel` holds one `destination`, so a route opens the product directly and skips the Electronics category screen. A route that needs two levels of navigation would need the feature to hold a stack, not a single destination.
- **The script knows the routes.** Its validation lists the route patterns by hand, so adding a route means editing the script as well as the feature. A better design would let the app report its routes, but the script currently has to be kept in step with the code.
- **Coverage is two features.** Account and Search have handlers. Others would need the same pair: a `handleAgentRoute` method and a `case` in `dispatchAgentRoute()`.
- **It needs a simulator.** The script uses `simctl`, so it works only where the simulator tools are available.
- **It doesn't prove the screen content.** The route shows the screen. Confirming the right data appears needs a screenshot or a listing, which costs more and is not part of the measured comparison.

## Where the code lives

| Piece | File |
|---|---|
| Argument reading, dispatch, `AgentRouteFeature` | `Shop/Framework/Sources/AppModel.swift` |
| `#if DEBUG` URL cases for `account` and `search` | `Shop/Framework/Sources/AppModel+DeepLinks.swift` |
| `.task` calling the dispatch | `Shop/App/Sources/ShopAppMain.swift` |
| Account handler | `Features/Account/Framework/Sources/AccountModel.swift` |
| Search handler | `Features/Search/Framework/Sources/SearchModel.swift` |
| Launch script | `scripts/agent-route.sh` (in the ShopApp repository) |

Every code piece in this table is compiled only in Debug builds. The launch script is the only file here that runs outside the app.
