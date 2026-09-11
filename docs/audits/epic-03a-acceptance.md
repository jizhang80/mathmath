# EPIC 03a acceptance — Map core

**Branch:** `epic-03a-map-core` (cut from `main` at `e2fe4a9`) · **Brief:** `docs/epics/epic-03-app-map-shell.md`
(amendment 03.00.1) · **Plan:** `docs/plans/epic-03-plan.md` · **Date:** 2026-09-10

EPIC 03 is over the 8-task cap, so it was split at the brief's §8 seam, the map-actions façade (03.7). Scope is
unchanged; the split is recorded in `docs/epic-plan.md`. **03a** covers 03.1–03.7, the `fix(pipeline)` task 03.0
carried over from EPIC 02 brief §7.10, and this wrap (03.8). **03b** (03.9–03.13, the App half) follows on
`epic-03b-map-app`.

## 1. Gate results

| Gate | Result | Instrument | Excludes |
|---|---|---|---|
| (a) typecheck | PASS (0 errors, 0 warnings) | `pyright` strict over `pipeline/` | Swift type checking, which (d) covers |
| (b) lint | PASS | `swift-format lint --strict`; `ruff check pipeline` | — |
| (c) format | PASS | `ruff format --check pipeline` | — |
| (d) tests | PASS (`scripts/gate.sh` exit 0, "gates green"; pytest 190 passed) | `scripts/gate.sh`: `core-cli` release build; `Core-Package` and `Rendering` tests on the simulator; App build; `pytest` | physical device (D29) |
| (e1) commit messages | PASS | the `conventional-pre-commit` hook ran on every commit | — |
| (e2) CI | PASS required before merge | the ruleset on `main` blocks the merge until both checks are green; the run is linked from the PR | — |
| (f) I14 | PASS | `grep -rh "^import " Packages/Core/Sources/Core` returns 36 lines, all `import Foundation` | transitive imports |
| (f) hygiene | PASS, empty=PASS | `print(`, `TODO\|FIXME\|XXX`, `try!\|as!`, `Date()` and `URLSession\|URLRequest` under `Packages/Core/Sources` each return 0 | — |
| (f) glossary | PASS | No identifier uses a banned term, and a case-sensitive `Session` scan is clean. The two word hits are doc comments explaining a ban: `MapLaunch.swift:4` and `Expedition.swift:4`. | — |
| (f) I5 | PASS | the new Core types carry no identifier; `IdentifierBlocklistParityTests` green | — |
| (f) I6 / I15 | PASS | panels carry `paraphrase`, expectation codes paired with `official_url`, and landmark `source_url` only, never Ministry prose (03.7 tests); `data/demo` unchanged | — |
| (f) I8 | PASS | `core-cli validate data/demo` returns passed=true; the loader runs L0 at launch (03.4) | — |
| (f) R-6 | PASS **by recorded judgment** (§8) | the date-literal grep over `Packages/Core/Tests` finds 146 ISO-date literals in 23 Swift test files | — |
| (f) I11 | PASS | `no-time-estimates` hook green on every commit | — |
| (g) cross-EPIC audit | due at the EPIC 03 wrap (after 03b) | every 3 EPICs | — |
| (h) contract bumps | PASS | §4 | — |
| (i) DEFERRED | PASS | D-14 (marker drag, 03.1) and D-15 (snapshot hash verification; the placeholder length) | — |
| (j) C1 seam | PASS | §5 | — |
| (k) C4 artifacts | PASS | §3 | — |

## 2. Tasks completed

| Task | Commits | Verification |
|---|---|---|
| 03.0 fix-landmark-fetch-flake (carried over) | `25a364e`, `66cb1d8` | Transport failures now get a bounded retry and then `TransportInconclusive`. A real 4xx/5xx still fails immediately, so I15 is not weakened. Live tests skip only on inconclusive. The hermetic tests fail on the pre-fix code. pytest 190. |
| 03.1 contract-interaction-marker-unit-list | `8451c0a` | Orchestrator mechanical check: all 5 ruled lines of arbiter § Q-B are present verbatim; interaction-contract is v0.9.2; D-14 added. Prose only. |
| 03.2 contract-error-codes-snapshot-refused | `2e91b16` | Orchestrator check: the registry entry and the platform.md row and W1 sentence match the ruling's fenced text. |
| 03.3 core-error-surface-text-mirror | `b0dff1e`, `cbad01a` | comprehensive: parity in both directions; negative controls for an empty registry, an empty `userText` table and a planted mismatch; string literals ⊆ registry text |
| 03.4 bundle-loader-snapshot-seam | `95e43f1`, `0c21bf1` | comprehensive: 16 conformance tests; exactly one format-major implementation; refusal mapping. Re-dispatched from a clean tree after the API-limit interruption (§7). |
| 03.5 student-state-store | `bbe09c2`, `b3b941f`, `da8dbac` (fix) | The tester found a real bug: the store accepted keys outside the closed key set. It was fixed in-task (§9). The tester also added the two missing T5 negative controls. |
| 03.6 map-view-model | `ce418a2`, `857191a` | comprehensive: 12 gap tests. Exactly one fringe formula, `Expedition`'s; the only change to it is dropping 4 `private` keywords. |
| 03.7 map-actions-facade-launch | `05a2348`, `c06688c` | comprehensive: gap suites for launch and the façade |

## 3. (k) C4 artifact → gate

| Artifact | Gate | Excludes |
|---|---|---|
| `Core` library: new `Platform/BundleLoader`, `Platform/StudentStateStore`, `Platform/MapLaunch` (`MapFacade`), `Map/MapViewModel`, `CoreErrorText`; `CoreError` +3 cases | (d) `Core-Package` tests on the simulator | device runtime (D29) |
| Embedded snapshot `App/Sources/DemoSnapshot/*.json` (7 files) | (d) byte-identity test plus the C1 seam test; the wrap `cmp` against `data/demo` shows no diff | the built `.app` contents; the sim smoke in 03.12 covers those |
| `scripts/embed-demo-snapshot.sh` | Not executed by any automated gate: `Foundation.Process` is unavailable on the iOS simulator. The wrap ran it by hand twice; both runs exited 0, left the tree unchanged, and the copies stayed byte-identical. A test checks the script's copy-only shape. | automated execution |
| `core-cli` | (d) release build; (f) `core-cli validate data/demo` | — |
| App build | (d) `xcodebuild build -scheme mathmath`, now carrying the snapshot resources | no App code changed in 03a |
| `pipeline` landmark resolver (03.0) | (d) pytest, hermetic plus live | the live path skips when the network is inconclusive |
| Contract prose (interaction-contract v0.9.2, `error-codes.json` entry, map.md / platform.md rows) | orchestrator mechanical checks; pytest `test_contracts.py` registry⇔doc round-trip | — |

## 4. Contracts touched

| Contract | Change | Task |
|---|---|---|
| `interaction-contract.md` | v0.9.1 → v0.9.2: the marker is set from the unit list only, and the drag item leaves Finalization owed | 03.1 |
| `error-codes.json` | additive `PLATFORM_SNAPSHOT_REFUSED`; no version bump per `error-codes.md` § Rules | 03.2 |

## 5. (j) C1 seam

| Seam | Test | Both sides real? |
|---|---|---|
| bundle loader ↔ Core validation | `DemoSnapshotSeamTests.swift` (03.4) | yes: the same `BundleLoader.load` entry point runs over the real `data/demo` and over `App/Sources/DemoSnapshot` |
| Core ↔ render layer | owned by 03.12 (03b) | — |

## 6. Deferrals

- **D-14** (03.1): marker drag with unit-boundary snap. Trigger: Demo observations.
- **D-15** (this wrap): snapshot `sha256` verification at load moves to EPIC 10's download path (arbiter Q-H). This
  also records the missing EPIC 01 deferral and the 66-character placeholder hashes.
- **D-12** stays open. 03.13 (03b) closes it.

## 7. Process incidents

An API session limit terminated three agents mid-work: the 03.4 implementer, the 03.0 spec revision and the 04.5
review. The rule for a derailed task is to revert it to its last task-commit. So the partial 03.4 work, an
uncommitted `L0Checker.swift` edit and a partial `Platform/BundleLoader.swift`, was discarded, and the tree was
verified at `cbad01a`. 03.4 was re-dispatched from clean. The other two were re-run. Nothing partial was
committed.

## 8. R-6 judgment

The grep finds 146 ISO-date literals in 23 Swift test files under `Packages/Core/Tests`. Each one is:
- an injected `today: CalendarDay`,
- a fixture day value, or
- a `CalendarDay` or `StudentState` parse/emit sample.

`Core` never reads a clock (`Date()` under `Packages/Core/Sources` = 0). This is the same judgment as EPIC 01, 02a and 02b.

## 9. (R-7) `fix:`-commit table and cascade check

| Commit | Cause | Corrects task | Risk tier | Rework / output |
|---|---|---|---|---|
| `25a364e` `fix(pipeline)`: classify transport-level landmark-fetch failures separately from dead sources | test-infra (the only non-hermetic test flaked three times; CI run 34528761105) | EPIC 01 task 01.07 | seam | rework |
| `da8dbac` `fix(core)`: StudentStateStore rejects keys outside the closed key set | contract-gap (the 03.5 spec claimed `Codable` enforced `additionalProperties: false`; it does not) | 03.5 | seam | rework |

03a totals: **2 rework, 0 output.** There were no tester tier-upgrades.

Cascade check (> 3 rework in each of two consecutive EPICs): EPIC 02 = 1, EPIC 03a = 2. It does not fire.

## 10. Physical-device verification

Agents verified on the iOS simulator only. **No agent claims physical-device verification** (D29).
