#!/bin/sh
# The four gates (R-1) for mathmath, as locked in docs/tech-stack.md §3 (web stack, AMENDMENT-v2.8).
# Agents run this before every commit; CI runs the same steps. Exit non-zero on the first failure.
# The frozen native code has its own gate, scripts/gate-native.sh (D50).
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== 1/4 format + lint =="
pnpm format:check
pnpm lint
( cd pipeline && uv run ruff check . && uv run ruff format --check . )

echo "== 2/4 typecheck + contract types =="
pnpm typecheck
pnpm gen:check
( cd pipeline && uv run pyright )

echo "== 3/4 unit + integration tests =="
pnpm test
( cd pipeline && uv run pytest -q )

echo "== 4/4 build + end-to-end (Chromium, WebKit iPad, WebKit iPhone — D29) =="
pnpm build
pnpm e2e

echo "gates green"
