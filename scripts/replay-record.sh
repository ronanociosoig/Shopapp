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
# Every XxxTests.xcscheme now also carries a permanent TZ=UTC entry in that
# same EnvironmentVariables block (see the snapshot date-rendering bug this
# fixed — a fixed instant near midnight UTC rendered as a different calendar
# date depending on the host's timezone). This script only ever adds or
# removes its own REPLAY_RECORD_MODE entry inside that block; it never
# touches TZ's, and never flips shouldUseLaunchSchemeArgsEnv, which must
# stay "NO" permanently now for TZ to take effect at all.
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

# Legacy shape, kept only as a fallback for a scheme that has never had TZ
# (or anything else) added to its EnvironmentVariables block yet.
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
legacy_env_block_template = (
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

# Current shape: TestAction already carries an EnvironmentVariables block
# (at minimum, TZ=UTC). This script only ever adds/removes its own
# REPLAY_RECORD_MODE entry inside that existing block.
entry_re = re.compile(
    r'         <EnvironmentVariable\n'
    r'            key = "REPLAY_RECORD_MODE"\n'
    r'            value = "(once|rewrite)"\n'
    r'            isEnabled = "YES">\n'
    r'         </EnvironmentVariable>\n'
)

def make_entry(mode: str) -> str:
    return (
        '         <EnvironmentVariable\n'
        '            key = "REPLAY_RECORD_MODE"\n'
        f'            value = "{mode}"\n'
        '            isEnabled = "YES">\n'
        '         </EnvironmentVariable>\n'
    )

has_env_block = '<EnvironmentVariables>' in content
is_on = 'REPLAY_RECORD_MODE' in content

if action == 'status':
    if is_on:
        match = entry_re.search(content)
        current_mode = match.group(1) if match else 'unknown'
        print(f'{scheme}: recording ON (REPLAY_RECORD_MODE={current_mode})')
    else:
        print(f'{scheme}: off (normal playback)')
    sys.exit(0)

if action == 'on':
    if is_on:
        new_content = entry_re.sub(make_entry(mode), content, count=1)
        if new_content == content:
            print(f'{scheme}: already on with mode={mode}, nothing to change')
            sys.exit(0)
        with open(path, 'w') as f:
            f.write(new_content)
        print(f'{scheme}: mode updated to REPLAY_RECORD_MODE={mode}')
        sys.exit(0)

    if has_env_block:
        # Insert alongside whatever's already declared (e.g. TZ) — the
        # opening tag is unique per file (one TestAction, one such block).
        new_content = content.replace(
            '<EnvironmentVariables>\n',
            '<EnvironmentVariables>\n' + make_entry(mode),
            1,
        )
        with open(path, 'w') as f:
            f.write(new_content)
        print(f'{scheme}: enabled REPLAY_RECORD_MODE={mode} — remember to run "off" after recording')
        sys.exit(0)

    # Legacy fallback: no EnvironmentVariables block exists at all yet.
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
        testables_close + legacy_env_block_template.format(mode=mode) + test_action_close,
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

    # Always remove just this script's own entry first, regardless of shape
    # — leaves any other declared variable (TZ included) untouched.
    new_content = entry_re.sub('', content, count=1)
    if new_content == content:
        print(f'error: found REPLAY_RECORD_MODE but could not locate its EnvironmentVariable entry to remove', file=sys.stderr)
        sys.exit(1)

    empty_block = '      <EnvironmentVariables>\n      </EnvironmentVariables>\n'
    if empty_block not in new_content:
        # Something else (e.g. TZ) still lives in the block — done, and
        # shouldUseLaunchSchemeArgsEnv stays "NO" since that other
        # variable still needs it.
        with open(path, 'w') as f:
            f.write(new_content)
        print(f'{scheme}: disabled, back to normal playback')
        sys.exit(0)

    # REPLAY_RECORD_MODE was the only variable declared — legacy full
    # revert: drop the now-empty block and flip the flag back to "YES".
    new_content = new_content.replace(empty_block, '', 1)
    new_content = new_content.replace(on_test_action_open, off_test_action_open, 1)
    with open(path, 'w') as f:
        f.write(new_content)
    print(f'{scheme}: disabled, back to normal playback')
    sys.exit(0)
PYEOF
