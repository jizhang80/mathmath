#!/bin/sh
# Applies (or updates) the `main` branch ruleset from scripts/branch-ruleset.json (bootstrap Phase 5 step 5).
# Requires `gh` authenticated with admin rights on the repo. Idempotent: updates the ruleset if it exists.
set -eu
REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
NAME="$(python3 -c 'import json;print(json.load(open("scripts/branch-ruleset.json"))["name"])')"
ID="$(gh api "/repos/$REPO/rulesets" -q ".[] | select(.name == \"$NAME\") | .id" || true)"
if [ -n "$ID" ]; then
  gh api -X PUT "/repos/$REPO/rulesets/$ID" --input scripts/branch-ruleset.json -q '.id, .enforcement'
else
  gh api -X POST "/repos/$REPO/rulesets" --input scripts/branch-ruleset.json -q '.id, .enforcement'
fi
