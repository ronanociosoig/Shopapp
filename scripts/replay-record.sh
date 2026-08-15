#!/usr/bin/env bash
#
# Toggles REPLAY_RECORD_MODE injection into an Xcode scheme's TestAction.
#
# Why this exists: xcodebuild-launched tests don't inherit the invoking
# shell's environment the way `swift test` does, and the SIMCTL_CHILD_*
# prefix (which works for `simctl launch`/`spawn`) does not reach a test
# process launched via `xcodebuild test`. The only way to get
# REPLAY_RECORD_MODE into that process is to declare it in the scheme's own
# TestAction/EnvironmentVariables block — so recording is a scheme edit, not
# a flag. This script makes that edit (and, just as importantly, reverts it)
# instead of hand-editing XML each time.
#
# A scheme left in recording mode silently re-records on every future test
# run instead of replaying a committed fixture — always run `off` again
# after recording. `on` and `off` are idempotent; running either twice, or
# `status` at any point, is always safe.
#
# Usage:
#   scripts/replay-record.sh on [once|rewrite] [scheme]   (default: once, StoreTests)
#   scripts/replay-record.sh off [scheme]                 (default: StoreTests)
#   scripts/replay-record.sh status [scheme]               (default: StoreTests)
#
# Examples:
#   scripts/replay-record.sh on
#   scripts/replay-record.sh on rewrite
#   scripts/replay-record.sh on once AccountTests
#   scripts/replay-record.sh off
#   scripts/replay-record.sh status

set -euo pipefail

ACTION="${1:-}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME_DIR="$REPO_ROOT/.swiftpm/xcode/xcshareddata/xcschemes"

usage() {
    echo "Usage:"
    echo "  $0 on [once|rewrite] [scheme]   (default: once, StoreTests)"
    echo "  $0 off [scheme]                 (default: StoreTests)"
    echo "  $0 status [scheme]              (default: StoreTests)"
    exit 1
}

MODE=""
case "$ACTION" in
    on)
        MODE="${2:-once}"
        SCHEME="${3:-StoreTests}"
        if [[ "$MODE" != "once" && "$MODE" != "rewrite" ]]; then
            echo "error: mode must be 'once' or 'rewrite', got '$MODE'" >&2
            exit 1
        fi
        ;;
    off|status)
        SCHEME="${2:-StoreTests}"
        ;;
    *)
        usage
        ;;
esac

SCHEME_FILE="$SCHEME_DIR/$SCHEME.xcscheme"

if [[ ! -f "$SCHEME_FILE" ]]; then
    echo "error: scheme file not found: $SCHEME_FILE" >&2
    exit 1
fi

python3 - "$ACTION" "$SCHEME_FILE" "$SCHEME" "$MODE" <<'PYEOF'
import re
import sys

action, path, scheme, mode = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

with open(path) as f:
    content = f.read()

# These blocks are boilerplate shared by every scheme built from the same
# template (see StoreTests.xcscheme) — none of it references the scheme name,
# so the same literal blocks work for any XxxTests.xcscheme following the
# same shape.

off_test_action_open = (
    '   <TestAction\n'
    '      buildConfiguration = "Debug"\n'
    '      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"\n'
    '      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"\n'
    '      shouldUseLaunchSchemeArgsEnv = "YES"\n'
    '      shouldAutocreateTestPlan = "YES">\n'
)

on_test_action_open = (
    '   <TestAction\n'
    '      buildConfiguration = "Debug"\n'
    '      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"\n'
    '      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"\n'
    '      shouldUseLaunchSchemeArgsEnv = "NO"\n'
    '      shouldAutocreateTestPlan = "YES">\n'
)

env_block_template = (
    '      <EnvironmentVariables>\n'
    '         <EnvironmentVariable\n'
    '            key = "REPLAY_RECORD_MODE"\n'
    '            value = "{mode}"\n'
    '            isEnabled = "YES">\n'
    '         </EnvironmentVariable>\n'
    '      </EnvironmentVariables>\n'
)

testables_close = '      </Testables>\n'
test_action_close = '   </TestAction>'

is_on = 'REPLAY_RECORD_MODE' in content

if action == 'status':
    if is_on:
        match = re.search(r'value = "(once|rewrite)"', content)
        current_mode = match.group(1) if match else 'unknown'
        print(f'{scheme}: recording ON (REPLAY_RECORD_MODE={current_mode})')
    else:
        print(f'{scheme}: off (normal playback)')
    sys.exit(0)

if action == 'on':
    if is_on:
        new_content = re.sub(r'value = "(once|rewrite)"', f'value = "{mode}"', content)
        if new_content == content:
            print(f'{scheme}: already on with mode={mode}, nothing to change')
            sys.exit(0)
        with open(path, 'w') as f:
            f.write(new_content)
        print(f'{scheme}: mode updated to REPLAY_RECORD_MODE={mode}')
        sys.exit(0)

    if off_test_action_open not in content:
        print(
            f'error: {path} does not match the expected off-state TestAction block. '
            'Edit it by hand — this script only handles the known on/off shapes.',
            file=sys.stderr,
        )
        sys.exit(1)

    content = content.replace(off_test_action_open, on_test_action_open, 1)
    content = content.replace(
        testables_close + test_action_close,
        testables_close + env_block_template.format(mode=mode) + test_action_close,
        1,
    )
    with open(path, 'w') as f:
        f.write(content)
    print(f'{scheme}: enabled REPLAY_RECORD_MODE={mode} — remember to run "off" after recording')
    sys.exit(0)

if action == 'off':
    if not is_on:
        print(f'{scheme}: already off, nothing to change')
        sys.exit(0)

    if on_test_action_open not in content:
        print(
            f'error: {path} has REPLAY_RECORD_MODE set but does not match the expected '
            'on-state TestAction block. Edit it by hand.',
            file=sys.stderr,
        )
        sys.exit(1)

    content = content.replace(on_test_action_open, off_test_action_open, 1)
    new_content = re.sub(
        r'\n      <EnvironmentVariables>\n.*?\n      </EnvironmentVariables>\n',
        '\n',
        content,
        count=1,
        flags=re.DOTALL,
    )
    if new_content == content:
        print(f'error: found REPLAY_RECORD_MODE but could not locate the EnvironmentVariables block to remove', file=sys.stderr)
        sys.exit(1)

    with open(path, 'w') as f:
        f.write(new_content)
    print(f'{scheme}: disabled, back to normal playback')
    sys.exit(0)
PYEOF
