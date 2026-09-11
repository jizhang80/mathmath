#!/bin/sh
# Regenerates App/Sources/DemoSnapshot/ from data/demo/. Never hand-edit the copy; run this script and
# commit its output. Guarded by Packages/Core/Tests/CoreTests/DemoSnapshotSeamTests.swift (byte-identity).
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/data/demo"
DEST="$ROOT/App/Sources/DemoSnapshot"
mkdir -p "$DEST"
for f in manifest.json regions.json nodes.json edges.json courses.json landmarks.json sources.json; do
    cp "$SRC/$f" "$DEST/$f"
done
