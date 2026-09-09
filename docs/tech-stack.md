# Tech stack — locked (bootstrap Phase 5)

Date: 2026-09-09. Ground truth: `PROJECT-BRIEF-v2.md` + `AMENDMENT-v2.1`–`v2.5` (D24, D29, D31–D36,
D41, D42); `docs/idea.md`. Preferences input: `claude-tech-stack-preferences.md` — its principle layer
(strict typing, explicit state, thin runtime, boundary validation, observability at the review surface)
is binding; its web-tool layer is overridden by D32/D33 for the iOS app and by D41 for the pipeline.
**Every pin below was validated on this date**; the citation is the validation. Agents BLOCK on any spec
that pins a tool this file does not name (CLAUDE.md).

## 1. Choices

| Slot | Choice | Version / pin | Rationale | Validation |
|---|---|---|---|---|
| Student app language | **Swift 6** (language mode 6, strict concurrency `complete`) | toolchain: Swift 6.3.3 (Xcode 26.6, 17F113) on this Mac; package `swift-tools-version: 6.2` so any Xcode 26.x builds it | D32; strict typing + compile-time failure surface (preferences meta-principle) | Local: `swift --version`, `xcodebuild -version` 2026-09-09. Xcode 26.6 ships Swift 6.3 and iOS 26.5 SDK [SOURCED: https://developer.apple.com/news/releases/?id=06252026a] |
| UI | **SwiftUI**; map on **`Canvas`**; first-party **SpriteKit** only if a few-hundred-node map demands it (D24/D32) | OS frameworks | D32 | — (OS-provided) |
| Deployment target | **iOS / iPadOS 18.0** | `IPHONEOS_DEPLOYMENT_TARGET = 18.0`; `Core` platforms `.iOS(.v18)`, `.macOS(.v15)` | D34 as amended (v2.4 §5) | Simulator runtimes installed locally: iOS 18.3, 18.6, 26.0–26.4 (`xcrun simctl list runtimes`) |
| Shared logic | Swift Package **`Core`** (library) + **`core-cli`** (executable) — Foundation only | `Packages/Core` | D33, D42, I14 | `CoreTests` asserts the import boundary (empty scan = FAIL, C3); `swift test` green 2026-09-09 |
| Math display | **SwiftMath**, imported only by the `Packages/Rendering` package | **1.7.3 exact** (`Package.swift` `exact:` and the app's `XCRemoteSwiftPackageReference`) | D32 — the one third-party app dependency; WKWebView + KaTeX fallback per item is designed in the Demo rendering spike | Latest release 1.7.3 (2026-08-03) [SOURCED: https://github.com/mgriebling/SwiftMath/releases]; `swift-tools-version 5.7`, iOS 11+/macOS 12+, no dependencies [SOURCED: https://github.com/mgriebling/SwiftMath/blob/main/Package.swift]; resolved and linked into the app build 2026-09-09 |
| Persistence | **`Codable` JSON** in Application Support; state types in `Core` | OS APIs | D32 as amended (v2.4 §1); SwiftData removed | — |
| Sync | **iCloud** (Drive document container or CloudKit) — chosen at M3 | OS APIs | D36; platform Q1 | Deferred to M3 by ruling |
| Tier 1 | **Foundation Models** framework, `@Generable` guided generation | OS framework, iOS 26+ | D32, D34 | Runs in the iOS 26+ simulator when the host Mac has Apple Intelligence enabled [SOURCED: https://developer.apple.com/forums/thread/787199; https://developer.apple.com/forums/thread/815397]; macOS 26 required for development [SOURCED: https://azamsharp.com/2025/06/18/the-ultimate-guide-to-the-foundation-models-framework.html]. This Mac: M4 Pro, macOS 26.6.2 |
| Swift tests | **Swift Testing** (`import Testing`) for `Core`; XCTest only where UI testing needs it | Xcode-bundled | first-party; expressive `#expect` | `Testing.framework` present in the iOS platform of Xcode 26.6 (local `ls`) |
| Swift formatting | **swift-format** (Apple, bundled in the Xcode toolchain) | 6.3.0 (`xcrun swift-format --version`) | first-party; no SwiftLint (would be a third-party tool with no recorded need) | Local run green 2026-09-09; config `.swift-format` |
| App project | Hand-authored **`App/mathmath.xcodeproj`** (objectVersion 77) with a **file-system-synchronized** `Sources` group; **`App/mathmath.xcworkspace`** = project + `Packages/Core` | Xcode 26 format | Agents add files under `App/Sources` and `Packages/Core` **without editing the pbxproj**; no XcodeGen/Tuist | `xcodebuild -list` shows schemes `Core`, `core-cli`, `mathmath`; simulator build green 2026-09-09 |
| Pipeline language | **Python 3.14** | `.python-version` = 3.14; local 3.14.7 | D41; strict typing via pyright strict + Pydantic (preferences: "with strict types, approaches TS") | 3.14.7 released 2026-08-05, bugfix status [SOURCED: https://www.python.org/downloads/] |
| Python env / build | **uv** | 0.12.12 (Homebrew; `uv_build` backend pinned `>=0.12.12,<0.13`) | one tool for venv, lock, run | [SOURCED: https://pypi.org/pypi/uv/json] |
| Python deps | **anthropic** ≥ 1.4,<2 · **pydantic** ≥ 2.13,<3 · **sympy** ≥ 1.14,<2 (exact pins in `pipeline/uv.lock`) | resolved 2026-09-09: anthropic 1.4.0, pydantic 2.13.5, sympy 1.14.0 | Claude API for generation (D12); boundary validation; CAS answer re-derivation (I1) | [SOURCED: https://pypi.org/pypi/anthropic/json (1.4.0, Python ≥ 3.10); https://pypi.org/pypi/pydantic/json (2.13.5, 2026-08-28); https://pypi.org/pypi/sympy/json (1.14.0)] |
| Python lint/format | **ruff** (check + format) | ≥ 0.16 (0.16.6 today) | replaces flake8/black/isort | [SOURCED: https://pypi.org/pypi/ruff/json] |
| Python typecheck | **pyright** strict | ≥ 1.1 (lock pins the resolved release) | preferences: strict `mypy`/`pyright` | PyPI metadata fetch returned a stale summary (1.1.413 / 2024); the lock file records the actually resolved version — re-check at the first pipeline EPIC [ESTIMATE: current release is newer] |
| Python tests | **pytest** | ≥ 8 | — | — |
| Generation model | **`claude-opus-5`** for content generation runs; `claude-haiku-4-5` only where a spec names a mechanical extraction task | Claude API via the `anthropic` SDK; adaptive thinking; streaming for long outputs | quality > tokens (I13); model IDs per the Claude API reference in force 2026-09-09 | Claude API skill reference (cached 2026-06-24 table) |
| CI | **GitHub Actions**, `macos-26` runners (arm64) | `.github/workflows/ci.yml` | D29: simulator gate in CI; the pipeline job also runs on macOS because its seam test invokes `core-cli` | macos-26 GA since 2026-02-26, multiple Xcode 26 versions on the image [SOURCED: https://github.blog/changelog/2026-02-26-macos-26-is-now-generally-available-for-github-hosted-runners/; https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md] |
| Hooks | **pre-commit** with `conventional-pre-commit` (commit-msg), `ruff-pre-commit`, local `swift-format lint`, local I11 time-estimate grep | pre-commit 4.6.2; hook revs in `.pre-commit-config.yaml` (via `pre-commit autoupdate` 2026-09-09) | C8: commit-message and formatting checks pre-commit | [SOURCED: https://pre-commit.com/hooks.html; https://github.com/swiftlang/swift-format/blob/main/.pre-commit-hooks.yaml] |
| Branch protection | GitHub **ruleset** on `main`: PR required, CI checks `Swift (Core + App, iOS simulator)` and `Python pipeline` required, no force-push, no deletion | repo `jizhang80/mathmath` (public) | bootstrap Phase 5 step 5 | applied via `gh api` 2026-09-09 — see §5 |
| Static content host | **Cloudflare Pages** serving versioned content JSON (`data/` bundles) — set up at M3 | free tier | D36 (a); same vendor as the endpoint | HTTP request logs are not retained by default on Cloudflare [SOURCED: https://developers.cloudflare.com/logs/logpull/enabling-log-retention/] |
| Telemetry endpoint | **Cloudflare Worker** (append-only POST) writing to **R2** — set up at M3 | free tier | D36 (b), serverless, append-only | **No-IP constraint (v2.5 §2):** `[observability.logs] invocation_logs = false` in wrangler config (Workers Logs are on by default for new Workers, retained 3–7 days otherwise) [SOURCED: https://developers.cloudflare.com/workers/observability/logs/workers-logs/]; enable the **"Remove visitor IP headers"** managed transform so the Worker never receives `CF-Connecting-IP` [SOURCED: https://developers.cloudflare.com/fundamentals/reference/http-headers/]; zone HTTP logs not retained by default (Logpull off) [SOURCED: as above]. Telemetry W5 verifies all three at the wrap-gate |
| Distribution | Direct Xcode install, development signing, registered devices; TestFlight later | Apple Developer Program (exists) | D35 as amended | — |

**Not chosen, and why:** SwiftData (conflicts with D33 — v2.4 §1); SwiftLint / XcodeGen / Tuist (third-party
tooling without a recorded need; swift-format and a synchronized-folder project cover the need); TypeScript
anywhere before M5 (v2.4 §2); AWS Lambda + S3 for telemetry (equally viable; Cloudflare chosen for one vendor
and documented log-off controls — revisit at M3 if the no-IP verification fails); Chrome Prompt API / WebLLM
(D34).

## 2. Repository layout

```
/
├── App/
│   ├── mathmath.xcodeproj/         # hand-authored; synchronized `Sources` group — never edited by agents
│   ├── mathmath.xcworkspace/       # project + Packages/Core (gives xcodebuild the Core scheme)
│   └── Sources/                    # SwiftUI app: views, adapters (Foundation Models, persistence, sync)
├── Packages/Core/                  # Swift package: Core (lib), CoreCLI → core-cli (exe), CoreTests
├── Packages/Rendering/             # Swift package over SwiftMath: MathView + RenderCheck (rendering spike; LO W1 5b)
├── pipeline/                       # Python (uv): src/mathmath_pipeline, tests; calls core-cli (D42)
├── data/                           # JSON bundles: Demo hand-written; later pipeline output (+ L0 report)
├── scripts/gate.sh                 # the four gates (§3); scripts/check-no-time-estimates.sh (I11)
├── .github/workflows/ci.yml        # macos-26: Swift job + Python job
├── .pre-commit-config.yaml · .swift-format · .gitignore
└── docs/ contracts/ tasks/ modules/ (unchanged)
```

Ownership by domain (a spec's §2 file scope is authoritative): `Packages/Core` — concept-graph (types, L0,
query), map (layout, `MapViewModel`), expedition (`StudentState`, scheduler, transitions), diagnosis
(hypothesis machine), platform (state merge); `App/Sources` — all rendering, Foundation Models adapter
(runtime-tiers), persistence/sync/bundle loading (platform), telemetry client; `pipeline/` —
curriculum-spine, content-generation, learning-objects validation, telemetry aggregation (W4).

## 3. Gates (R-1) — `scripts/gate.sh`

1. **Format + lint:** `swift-format lint --strict` over `Packages` and `App/Sources`; `ruff check` and
   `ruff format --check` over `pipeline`.
2. **Typecheck:** `pyright` (strict) over `pipeline`. (Swift's typecheck is the build in gate 3.)
3. **Core:** `swift build -c release --product core-cli`; `xcodebuild test -scheme Core-Package` and
   `-scheme Rendering` on the iOS simulator (D29 — the agent gate is the simulator, never a device).
4. **App + pipeline:** `xcodebuild build -scheme mathmath` on the simulator; `pytest`.

CI runs the same steps; `scripts/pick-simulator.sh` chooses the newest available iPhone simulator
(override with `MATHMATH_SIM="platform=iOS Simulator,name=…,OS=…"`).
Physical-device verification is the owner's, at the wrap-gate, recorded in the acceptance report (D29).

## 4. Deployment model

Single deployment, no per-client instances. Student app: iOS/iPadOS via direct install (Demo, M3, M4),
TestFlight external testing before release, App Store at release. Content: static JSON on Cloudflare Pages
with an offline snapshot bundled in the app (D36). Telemetry: one Cloudflare Worker + R2 bucket, no read
API, no IP retention (§1). No application server, no containers, no Dockerfile.

## 5. Setup performed 2026-09-09

- `Packages/Core`, `App/`, `pipeline/`, `scripts/`, CI workflow, `.pre-commit-config.yaml`, `.swift-format`
  created; `uv.lock` generated; `pre-commit install --hook-type pre-commit --hook-type commit-msg`.
- Gates run green locally (`scripts/gate.sh`) — Core tests and the app build on the iOS 26.4 simulator;
  ruff, pyright strict and pytest on Python 3.14.7; the Python↔`core-cli` seam test (C1) passes.
- Branch ruleset on `main` defined in `scripts/branch-ruleset.json`, applied with `scripts/apply-branch-ruleset.sh`
  (idempotent) immediately after this commit is pushed. **Consequence for the process:** nothing lands on
  `main` without a PR whose two CI jobs are green — `wrap-epic` merges through `gh pr create` →
  `gh pr checks --watch` → `gh pr merge --merge`; owner planning sessions do the same for docs.
- `xcodebuild -downloadPlatform iOS` run once on this Mac: Xcode 26.6 ships the iOS 26.5 SDK but not the
  26.5 simulator runtime, and without it xcodebuild refuses every iOS simulator destination. CI images carry
  their matching runtime.
- Homebrew installed on this Mac for Phase 5: `uv 0.12.12`, `pre-commit 4.6.2`.

## 6. Open at lock (not blocking)

- **Apple Intelligence on this Mac** — M4′ needs it enabled (System Settings) for the simulator path;
  not verifiable from the CLI. Owner confirms before M4′.
- **Cloudflare account** — created at M3, when the endpoint and static host are first needed.
- **iCloud container / entitlement** — M3 (platform Q1).
- **Xcode on CI** — the workflow selects the newest `Xcode_26*.app` on the runner; if the image lags this
  Mac's 26.6, the package's `swift-tools-version: 6.2` keeps it buildable [ESTIMATE: image carries ≥ 26.2 per
  the runner-images changelog].

## Change log

| Date | Change |
|---|---|
| 2026-09-09 | Locked (v2 native iOS stack; D32/D33/D41/D42). |
