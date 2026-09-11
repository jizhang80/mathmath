#!/bin/sh
# EPIC 03 task 03.12 (arbiter-03 § Q-G). Two scenarios: (1) a fresh install writes no state file; (2) a seeded
# v1 state file migrates to v2, validates, and survives terminate+relaunch byte-identical. Also cmp's the built
# .app's embedded DemoSnapshot against data/demo. xcrun simctl only (D29); no launch-argument test hook exists
# in shipping code. Wired into scripts/gate.sh gate 4 and the swift job of .github/workflows/ci.yml.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_ID="ca.mathmath.app"
DERIVED_DATA="$ROOT/.build/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/mathmath.app"
STATE_FILE_NAME="student-state.json"

if [ ! -d "$APP_PATH" ]; then
    echo "sim-smoke: $APP_PATH not found — build the App with -configuration Debug -derivedDataPath \"$DERIVED_DATA\" first" >&2
    exit 1
fi

SIM_DEST="$("$ROOT/scripts/pick-simulator.sh")"
SIM_NAME="$(printf '%s' "$SIM_DEST" | sed -n 's/.*name=\([^,]*\).*/\1/p')"
SIM_OS="$(printf '%s' "$SIM_DEST" | sed -n 's/.*OS=\([^,]*\).*/\1/p')"
SIM_UDID="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
data = json.load(sys.stdin)["devices"]
name, os_version = sys.argv[1], sys.argv[2]
for runtime, devices in data.items():
    if os_version.replace(".", "-") not in runtime:
        continue
    for d in devices:
        if d.get("isAvailable") and d["name"] == name:
            print(d["udid"]); sys.exit(0)
sys.exit("sim-smoke: no simulator device matching " + name + " / " + os_version)
' "$SIM_NAME" "$SIM_OS")"

xcrun simctl boot "$SIM_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIM_UDID" -b

is_running() { xcrun simctl spawn "$SIM_UDID" launchctl list | grep -q "$BUNDLE_ID"; }

# --- Scenario 1: fresh install writes no state file ---
xcrun simctl uninstall "$SIM_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$SIM_UDID" "$APP_PATH"
xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID"
sleep 3  # [ESTIMATE: settle interval before the process check]
if ! is_running; then
    echo "sim-smoke: $BUNDLE_ID is not running after a fresh-install launch" >&2
    exit 1
fi
DATA_CONTAINER="$(xcrun simctl get_app_container "$SIM_UDID" "$BUNDLE_ID" data)"
STATE_PATH="$DATA_CONTAINER/Library/Application Support/$STATE_FILE_NAME"
if [ -e "$STATE_PATH" ]; then
    echo "sim-smoke: fresh install unexpectedly wrote $STATE_PATH" >&2
    exit 1
fi
echo "sim-smoke: scenario 1 (fresh install, no state file) PASS"

# --- Scenario 2: seeded v1 -> v2 migration, then byte-identical relaunch ---
xcrun simctl terminate "$SIM_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
SEED_PATH="$ROOT/.build/sim-smoke-seed.json"
mkdir -p "$ROOT/.build"
uv run --project "$ROOT/pipeline" python -c "
import json
with open('$ROOT/contracts/examples/student-state.json') as f:
    state = json.load(f)
state['schema_version'] = 1
for node in state['nodes'].values():
    node.pop('remediated', None)
with open('$SEED_PATH', 'w') as f:
    json.dump(state, f)
"
mkdir -p "$DATA_CONTAINER/Library/Application Support"
cp "$SEED_PATH" "$STATE_PATH"

xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID"
sleep 3
if ! is_running; then
    echo "sim-smoke: $BUNDLE_ID is not running after the seeded launch" >&2
    exit 1
fi
if [ ! -e "$STATE_PATH" ]; then
    echo "sim-smoke: seeded state file is missing after launch" >&2
    exit 1
fi
if [ -e "${STATE_PATH}.pre-migration" ]; then
    echo "sim-smoke: a .pre-migration file remains after a successful migration" >&2
    exit 1
fi
uv run --project "$ROOT/pipeline" python -c "
import json
from jsonschema import Draft202012Validator
with open('$ROOT/contracts/schemas/student-state.schema.json') as f:
    schema = json.load(f)
Draft202012Validator.check_schema(schema)
validator = Draft202012Validator(schema)
with open('$STATE_PATH') as f:
    instance = json.load(f)
assert instance['schema_version'] == 2, instance['schema_version']
validator.validate(instance)
print('sim-smoke: migrated state file validates against student-state.schema.json')
"
cp "$STATE_PATH" "$ROOT/.build/sim-smoke-migrated.json"

xcrun simctl terminate "$SIM_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID"
sleep 3
if ! is_running; then
    echo "sim-smoke: $BUNDLE_ID is not running after relaunch" >&2
    exit 1
fi
if ! cmp -s "$ROOT/.build/sim-smoke-migrated.json" "$STATE_PATH"; then
    echo "sim-smoke: the state file changed across a relaunch (load must never write)" >&2
    exit 1
fi
echo "sim-smoke: scenario 2 (v1 -> v2 migration, byte-identical relaunch) PASS"

# --- Embedded snapshot cmp against data/demo ---
# Xcode's file-system-synchronized group copies App/Sources/DemoSnapshot's JSON files flat into the built
# product's resource root (no DemoSnapshot subdirectory survives the build) — confirmed against the real
# built .app; AppShell.resolveSnapshotDir() resolves to that same flat root (§6 decision default).
for f in manifest.json regions.json nodes.json edges.json courses.json landmarks.json sources.json; do
    if ! cmp -s "$APP_PATH/$f" "$ROOT/data/demo/$f"; then
        echo "sim-smoke: $APP_PATH/$f differs from data/demo/$f" >&2
        exit 1
    fi
done
echo "sim-smoke: embedded DemoSnapshot byte-identical to data/demo"
