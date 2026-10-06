#!/bin/sh
# FROZEN native gates (D50, AMENDMENT-v2.8 §2): the Swift Core + App checks as locked on 2026-09-09.
# Run only when something under Packages/ or App/ changes; the project gate is scripts/gate.sh.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIM="$("$ROOT/scripts/pick-simulator.sh")"
echo "simulator destination: $SIM"

echo "== 1/4 format + lint =="
xcrun swift-format lint --strict --recursive --configuration "$ROOT/.swift-format" "$ROOT/Packages" "$ROOT/App/Sources"
( cd "$ROOT/pipeline" && uv run ruff check . && uv run ruff format --check . )

echo "== 2/4 typecheck =="
( cd "$ROOT/pipeline" && uv run pyright )

echo "== 3/4 Core: build + test on the iOS simulator (D29) =="
( cd "$ROOT/Packages/Core" && swift build -c release --product core-cli )
( cd "$ROOT/Packages/Core" && xcodebuild test -quiet -scheme Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO )
( cd "$ROOT/Packages/Rendering" && xcodebuild test -quiet -scheme Rendering -destination "$SIM" CODE_SIGNING_ALLOWED=NO )

echo "== 4/4 App build on the simulator + pipeline tests =="
xcodebuild build -quiet -workspace "$ROOT/App/mathmath.xcworkspace" -scheme mathmath -destination "$SIM" -configuration Debug -derivedDataPath "$ROOT/.build/DerivedData" CODE_SIGNING_ALLOWED=NO
"$ROOT/scripts/sim-smoke.sh"
( cd "$ROOT/pipeline" && uv run pytest -q )

echo "gates green"
