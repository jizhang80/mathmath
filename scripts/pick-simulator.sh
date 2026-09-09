#!/bin/sh
# Prints an xcodebuild destination for the newest available iPhone simulator, e.g.
#   platform=iOS Simulator,name=iPhone 17,OS=26.4
# Used by scripts/gate.sh and CI so the destination never depends on a runtime that is not installed.
# Override with MATHMATH_SIM="platform=iOS Simulator,name=...,OS=...".
if [ -n "${MATHMATH_SIM:-}" ]; then echo "$MATHMATH_SIM"; exit 0; fi
xcrun simctl list devices available -j | python3 -c '
import json, sys, re
data = json.load(sys.stdin)["devices"]
best = None
for runtime, devices in data.items():
    m = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not m: continue
    version = (int(m.group(1)), int(m.group(2)))
    for d in devices:
        if d.get("isAvailable") and d["name"].startswith("iPhone"):
            key = (version, d["name"])
            if best is None or key > best[0]: best = (key, d["name"], f"{version[0]}.{version[1]}")
if best is None: sys.exit("no available iPhone simulator")
print(f"platform=iOS Simulator,name={best[1]},OS={best[2]}")
'
