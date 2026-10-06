# Tech stack — locked (bootstrap Phase 5, re-lock for v2.8)

Date: 2026-10-06. Ground truth: `PROJECT-BRIEF-v2.md` + `AMENDMENT-v2.1`–`v2.8` (D24, D29, D31–D36, D41, D42,
D50); `docs/idea.md`. **The harness chose this stack; the owner verifies at requirement level only** (D32 as
revised by v2.8 §3). Preferences input: `claude-tech-stack-preferences.md` — its principle layer (strict typing,
explicit state, thin runtime, boundary validation, observability at the review surface) is binding; its tool
layer is a prior, checked here against current releases. **Every pin below was validated on this date**: the
version is the npm registry's latest on 2026-10-06 unless the row says why not. Agents BLOCK on any spec that
pins a tool this file does not name (CLAUDE.md). A tool change after this lock is recorded in the change log
below; it is not a Q5.

The stack locked on 2026-09-09 for the native iOS app (Swift 6, SwiftUI, SwiftMath, Foundation Models, iCloud)
is **frozen with the native code** (D50). It is preserved in git history at commit `d9c8780`, and its gate is
`scripts/gate-native.sh`.

## 0. How the choice was made

The selection criterion is **which stack Claude builds with the fewest correction rounds, whose failures
surface where the owner looks, and that covers the known future needs**:

- the M5 homework mode (structured math editor + CAS) in the same app;
- an optional app-store wrapper later (D-23);
- no server (D36).

Five consequences follow:

1. **One language, TypeScript strict, for `Core` and the UI** (v2.8 §3a). TypeScript is the preferences doc's
   strongest tier for Claude. One language means `Core` cannot drift from the UI, and the D42 single
   implementation is literally one module that the browser and the pipeline both run.
2. **Compile-time failure over runtime failure.** We use maximal `tsc` strictness and type-aware lint. `Core`'s
   renderer-free boundary (I14) is enforced by the compiler: its tsconfig has no DOM library and no Node types.
3. **The contracts stay the single source of truth.** TypeScript types are *generated* from
   `contracts/schemas/*.json`, the same files the Python pipeline validates against. Runtime validation uses
   those same JSON Schemas. A hand-written Zod mirror would be a second source that can drift, so we use none.
4. **The smallest runtime that does the job.** The app is a static single-page app with no framework server.
   No router or state library is installed until a screen needs one; React's own state suffices for the shell.
5. **Safari is the review surface.** End-to-end tests run on WebKit with the iPad and iPhone profiles, as well
   as on Chromium. WebKit is the closest an agent gets to the owner's device check (D29).

## 1. Choices

| Slot | Choice | Version / pin | Rationale | Validation |
|---|---|---|---|---|
| Language | **TypeScript**, `strict` + `noUncheckedIndexedAccess` + `exactOptionalPropertyTypes` + `erasableSyntaxOnly` | **6.0.3 exact** — not 7.0.2 (the `latest` tag) | Strongest Claude tier; failures at compile time. **Not 7.x:** TypeScript 7.0 (the Go-native compiler, GA 2026-07-08) ships no stable programmatic API, so typescript-eslint's type-aware rules cannot run on it. Its peer range is `>=4.8.4 <6.1.0`, and the TS 7 support request was closed "not planned" pending 7.1. | `npm view typescript-eslint peerDependencies` 2026-10-06 [SOURCED: https://ecorpit.com/typescript-7-migration-readiness-eslint-astro-blockers-2026/; https://www.digitalapplied.com/blog/typescript-7-native-compiler-early-adopter-migration-readiness] |
| Runtime (tooling, CLI) | **Node.js 24 LTS**, running `.ts` directly (built-in type stripping) | `>=24.12.0` (`engines`; CI pins 24.12.0) | The `Core` CLI and scripts run with no build step and no `tsx`. `erasableSyntaxOnly` keeps every file strippable. | Local `node v24.12.0`; `node web/core/src/cli.ts` runs (2026-10-06) |
| Package manager / monorepo | **pnpm workspaces** (`web/*`), pinned via `packageManager` + corepack | **pnpm 12.9.1** | Preferences pick; strict `node_modules` stops phantom imports. 12.x has been out since 2026-08-26, with nine minors since. | `npm view pnpm time` 2026-10-06; install and every gate green locally on 12.9.1 |
| Workspace location | **`web/`** (`web/core`, `web/app`) | — | **Not `packages/`**: macOS's default filesystem is case-insensitive, so `packages/` would collide with the frozen `Packages/` (D50). | — |
| Shared logic | **`@mathmath/core`** — renderer-free; library modules import only relative modules, the contract schemas and Ajv; `src/cli.ts` is the Node entry point | `web/core` | D33, D42, I14. The compile-time half of the boundary is `web/core/tsconfig.json` (`lib: ES2024`, `types: []`); the import half is `web/core/test/boundary.test.ts` (empty = FAIL, with a negative control) | Negative controls run 2026-10-06: `document` in `Core` fails `tsc`, and `console.log` fails ESLint |
| Contract types | **json-schema-to-typescript** generates `web/core/src/generated/contracts.ts` from `contracts/schemas/` | **16.0.0** exact (dev) | Types come from the contracts, never hand-written. `pnpm gen:check` fails on a stale file (gate 2) | Generated over all 9 schemas, and the result typechecks (2026-10-06) |
| Boundary validation | **Ajv** (JSON Schema 2020-12, `allErrors`, `strict` except `strictRequired`) | **8.20.0** exact | Validates against the same JSON Schemas as the pipeline. `strictRequired` is off because the contracts use `anyOf: [{required: …}]` (I8), which is valid 2020-12 but trips Ajv's extra lint. | All 7 `data/demo` files validate; the negative control (a node with neither `expectation_codes` nor `source_ref`) is rejected (2026-10-06) |
| UI | **React** + **react-dom** | **19.3.0** exact | The largest corpus, so Claude's most reliable UI library. Explicit state; no framework server (D36). | npm latest 2026-10-02 |
| Build / dev server | **Vite** + **@vitejs/plugin-react** | **8.3.3** / **6.1.2** exact | Static single-page app output; the preferences pick for a single-page app | npm latest 2026-10-06; `vite build` green |
| PWA (offline, installable) | **vite-plugin-pwa** (Workbox `generateSW`) | **2.0.0** exact | v2.8 §3e: offline after first load, plus a manifest for Add to Home Screen. Using the plugin avoids hand-written service-worker and build config, a weak zone for Claude per the preferences doc. | Peer range now includes `vite ^8.0.0`; the earlier peer conflict is resolved [SOURCED: https://github.com/vite-pwa/vite-plugin-pwa/issues/923]; build emits `sw.js` + `manifest.webmanifest` |
| Map rendering | **SVG** rendered by React; pan/zoom by **d3-zoom** (+ d3-selection). Escalate to Canvas 2D, then **PixiJS** (WebGL), only on measured frame-budget failure | d3-zoom 3.0.0, d3-selection 3.0.0, pixi.js 8.22.0 — **installed by the first task that needs them** | D24: no third-party game engine. SVG nodes are DOM, so end-to-end tests can find, tap and assert them; Canvas would hide the map from the review surface. d3-zoom handles touch pinch on Safari. | npm 2026-10-06. d3-zoom 3.0.0 has been stable since 2021 with no newer release. The few-hundred-node budget is re-measured at the Demo [ESTIMATE: SVG holds for the Demo's ~20 nodes; full-continent counts are measured before M5] |
| Math display | **KaTeX** | **0.19.0** exact | The web standard for LaTeX rendering; synchronous; no fallback renderer needed | npm latest 2026-10-01 |
| Student-state storage | **IndexedDB** via **idb**, plus `navigator.storage.persist()` and file export/import | idb 8.0.4 — **installed by the first persistence task** | v2.8 §9. Installed home-screen web apps are not subject to Safari's 7-day script-storage cap. The Storage API, including `persist()`, is supported since Safari 17 / iOS 17. D-22 measures both at the Demo. | [SOURCED: https://webkit.org/?p=14403; https://developer.mozilla.org/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria] |
| Unit / integration tests | **Vitest** | **5.0.3** exact | The preferences pick; native ESM + TS. Greenfield, so Vitest 5's breaking changes need no migration | Released 2026-09-03; requires Node ≥ 22.12 and Vite ≥ 6.4, both met [SOURCED: https://blog.openreplay.com/vitest-5-changes/] |
| End-to-end tests | **Playwright**, projects `chromium`, `webkit-ipad` (iPad gen 7), `webkit-iphone` (iPhone 15) | **@playwright/test 1.63.0** exact; WebKit 26.6 build | D29 as revised: the agent gate includes WebKit and Chromium | 6/6 green locally 2026-10-06 |
| Lint | **ESLint** flat config + **typescript-eslint** `strictTypeChecked` + **eslint-plugin-react-hooks**; `no-console` (off only for `cli.ts` and `scripts/`) | eslint 10.12.0, typescript-eslint 8.71.1, react-hooks 7.1.1, @eslint/js 10.0.1, globals 17.13.0 | Type-aware rules catch floating promises and unsafe `any`, which are silent at runtime | npm latest 2026-10-06; clean run |
| Format | **Prettier**, `printWidth` 110, scoped to `web/` and the root config files (docs and Markdown are not reformatted) | **3.9.9** exact | One formatter, no debates | npm latest 2026-09-23 |
| Pipeline | **Python 3.14 + uv + ruff + pyright strict + pytest; anthropic, pydantic, sympy** — unchanged from 2026-09-09 | `pipeline/uv.lock` | D41. Until the web `Core` gains L0 and layout, `mathmath_pipeline.core_cli` still runs the Swift `core-cli` via `swift run` (v2.8 §5); the switch to `node web/core/src/cli.ts` is recorded here when it happens | 190 tests green 2026-10-06 |
| Generation model | **`claude-opus-5`** for content generation runs; `claude-haiku-4-5` only where a spec names a mechanical extraction task | Claude API via the `anthropic` SDK | Quality > tokens (I13). Unchanged; pinned by `contracts/ai-usage.md`, and changing it is a contract change. | — |
| CI | **GitHub Actions**: `Web (Core + app, Chromium + WebKit)` on `ubuntu-latest`; `Python pipeline` on `macos-26` (unchanged; its seam test builds the Swift `core-cli`); `Swift (Core + App, iOS simulator)` unchanged (frozen code, D50) | `.github/workflows/ci.yml`; actions/setup-node v7 | Linux runners are enough for Playwright WebKit, and cheaper than macOS | actions/setup-node latest tag `v7.0.0` (2026-10-06) |
| Hooks | **pre-commit**: conventional commits, ruff, Prettier check (web), swift-format (frozen code), I11 time-estimate grep | `.pre-commit-config.yaml` | C8 | — |
| Branch protection | GitHub ruleset on `main`: PR required, required CI checks, no force-push, no deletion | `scripts/branch-ruleset.json` | The `Web` check is added to the required set when the owner approves the ruleset change (§6) | — |
| Demo hosting | **GitHub Pages**, deployed from Actions — set up by the Demo's distribution task | free for public repos | D35 as revised: testers need a URL. The repo is public and already on GitHub, so no new account is needed. The Demo sends no telemetry, so the no-IP constraint (which binds the telemetry endpoint) does not apply. | — |
| Content host + telemetry (M3) | **Cloudflare** static assets + **Worker** → **R2**, with the no-IP configuration — unchanged from the 2026-09-09 lock | free tier | D36. The no-IP controls: Workers Logs off, the "Remove visitor IP headers" managed transform, no Logpull. | [SOURCED: https://developers.cloudflare.com/workers/observability/logs/workers-logs/; https://developers.cloudflare.com/fundamentals/reference/http-headers/] |

**Not chosen, and why:**

- **Next.js:** a server framework for a product with no server (D36).
- **TanStack Router, Zustand:** not needed by a map with overlay screens; added with a recorded reason when a
  task needs one.
- **Tailwind / shadcn:** the Phase 4 design system (`docs/design-system/tokens.css`, `components.css`) is
  already plain CSS custom properties, so plain CSS reuses it verbatim with no dependency.
- **Zod:** would duplicate `contracts/schemas` (see §0.3).
- **Swift compiled to Wasm:** heavy toolchain risk and no reuse benefit once native is frozen.
- **Flutter web:** weaker Claude tier, and its canvas rendering hides the UI from DOM tests.
- **Svelte / Solid:** smaller corpus.
- **Biome:** no type-aware rules.
- **TypeScript 7:** see the Language row; revisit when typescript-eslint supports it.

## 2. Repository layout

```
/
├── web/
│   ├── core/                      # @mathmath/core — renderer-free (I14): src/ (library), src/cli.ts (Node entry, D42),
│   │                              #   src/generated/contracts.ts (generated), scripts/gen-types.ts, test/
│   └── app/                       # @mathmath/app — React + Vite PWA: src/, e2e/ (Playwright), vite/playwright config
├── package.json · pnpm-workspace.yaml · pnpm-lock.yaml · tsconfig.base.json · tsconfig.json
├── eslint.config.js · vitest.config.ts · .prettierrc.json · .prettierignore
├── pipeline/                      # Python (uv), unchanged; calls Core's CLI (D42)
├── data/                          # JSON bundles: Demo hand-written; later pipeline output
├── contracts/schemas/             # single source of truth for data shapes (TS types generated from here)
├── scripts/gate.sh                # the four gates (§3); scripts/gate-native.sh = frozen native gates
├── Packages/ App/                 # FROZEN native iOS code (D50) — read-only
└── .github/workflows/ci.yml · .pre-commit-config.yaml · docs/ contracts/ tasks/ modules/
```

Ownership by domain (a spec's §2 file scope is authoritative):

- **`web/core`:** concept-graph (types, L0, query), map (layout, the map view model), expedition (`StudentState`,
  scheduler, transitions), diagnosis (hypothesis machine), platform (state merge, export/import format).
- **`web/app`:** all rendering, persistence adapter (IndexedDB), bundle loading, service worker, telemetry
  client.
- **`pipeline/`:** curriculum-spine, content-generation, learning-objects validation, telemetry aggregation (W4).

## 3. Gates (R-1) — `scripts/gate.sh`

1. **Format + lint:** `pnpm format:check` (Prettier); `pnpm lint` (ESLint, zero warnings); `ruff check` +
   `ruff format --check` over `pipeline`.
2. **Typecheck + contract types:** `pnpm typecheck` (`tsc` over every tsconfig); `pnpm gen:check` (generated
   contract types up to date); `pyright` strict over `pipeline`.
3. **Unit + integration tests:** `pnpm test` (Vitest); `pytest` over `pipeline`.
4. **Build + end-to-end:** `pnpm build` (Vite + PWA); `pnpm e2e` (Playwright: Chromium, WebKit iPad, WebKit
   iPhone).

Scoped runs for a task: `pnpm vitest run <path>`, `pnpm --filter @mathmath/app exec playwright test <spec>`,
`uv run pytest <path>`.

CI runs the same steps. Physical-device verification (iPad and iPhone Safari, installed to the home screen) is
the owner's, at the wrap-gate, recorded in the acceptance report (D29).

## 4. Deployment model

There is a single deployment and no per-client instances.

- **Student app:** a static build (`web/app/dist`). During the Demo it is served on GitHub Pages; from M3 it is
  served with the content on Cloudflare. It is installed via Add to Home Screen, with no app store (D35).
- **Content:** versioned static JSON with an offline snapshot cached by the service worker (D36).
- **Telemetry (M3):** one Cloudflare Worker + R2 bucket, no read API, no IP retention.

There is no application server, no containers and no Dockerfile.

## 5. Setup performed 2026-10-06

- Created the pnpm workspace (`web/core`, `web/app`); `pnpm install` on pnpm 12.9.1 (corepack enabled for pnpm on
  this Mac); Playwright Chromium and WebKit engines downloaded to the user cache.
- `Core`: contract-type generation, Ajv boundary validation, the `schema` CLI command
  (`node web/core/src/cli.ts schema data/demo` → all files ok), and the I14 boundary test.
- `app`: a toolchain shell that validates the demo bundle through `Core` and renders the node count. It is
  placeholder content, replaced by the Demo EPICs.
- `scripts/gate.sh` replaced by the web gates; the native gates moved verbatim to `scripts/gate-native.sh`.
  Every gate ran green locally: Prettier, ESLint, ruff, `tsc`, gen-check, pyright, Vitest 12/12, pytest 190,
  Vite build, Playwright 6/6.
- CI gained the `Web` job; the `Swift` and `Python pipeline` jobs are unchanged.

## 6. Open at lock (not blocking)

- **Branch ruleset:** add `Web (Core + app, Chromium + WebKit)` to the required checks. Optionally make the frozen
  `Swift` check non-required and path-filtered to `Packages/**`, `App/**`. This is a repository-settings change
  and waits for the owner's approval.
- **GitHub Pages** is enabled by the Demo's distribution task (a repository setting; the owner approves it then).
- **Cloudflare account:** created by the owner at M3.
- **Switch the pipeline from the Swift `core-cli` to the web `Core` CLI** when `Core` gains L0 and layout (v2.8 §5).
- **TypeScript 7:** revisit when typescript-eslint's peer range admits it.

## Change log

| Date | Change |
|---|---|
| 2026-09-09 | Locked (v2 native iOS stack; D32/D33/D41/D42). |
| 2026-10-06 | Re-locked for AMENDMENT-v2.8: web stack chosen by the harness (§0–§1); native stack frozen with the native code (D50); gates, CI and layout replaced. |
