# EPIC 02a acceptance — Door B core

**Branch:** `epic-02-core-behaviour` · **Brief:** `docs/epics/epic-02-core-behaviour.md` (amendment 02.03.1) ·
**Plan:** `docs/plans/epic-02-plan.md` · **Date:** 2026-09-10

EPIC 02 was split at the brief's §8 seam because it was over the 8-task cap; scope is unchanged
(`docs/epic-plan.md` § EPIC 02 split). **02a** covers tasks 02.1–02.7 and this wrap (02.8). **02b** (02.9–02.13,
Door A core + merge) follows on `epic-02b-door-a-core-merge`.

## 1. Gate results

| Gate | Result | Instrument | Excludes |
|---|---|---|---|
| (a) typecheck | PASS: 0 errors, 0 warnings | `pyright` strict over `pipeline/` (in `scripts/gate.sh`) | Swift type checking, which is covered by (d) |
| (b) lint | PASS: ruff "All checks passed!"; swift-format strict clean | `swift-format lint --strict` over `Packages`, `App/Sources`; `ruff check pipeline` | — |
| (c) format | PASS: 17 files already formatted | `ruff format --check pipeline` | — |
| (d) tests | PASS: `scripts/gate.sh` exited 0 ("gates green") on `iPhone Air` iOS 26.5 at the pre-wrap commit `f0acc1c`; `pytest` 162 passed. The xcodebuild steps run in quiet mode, so the instrument is the exit status, not per-test counts. The SwiftPM "157 unhandled files" warning refers to test fixture JSON; it is a notice, not a failure. | `scripts/gate.sh`: `swift build -c release --product core-cli`; `xcodebuild test -scheme Core-Package` and `Rendering` on the simulator; `xcodebuild build -scheme mathmath`; `pytest` | physical device (D29, §9) |
| (e1) commit messages | PASS | `conventional-pre-commit` hook ran on every commit; no `--no-verify` | — |
| (e2) CI | PASS required before merge: the ruleset on `main` blocks the merge until both checks are green; the run is linked from the PR | PR checks `Swift (Core + App, iOS simulator)`, `Python pipeline` | — |
| (f) I14 | PASS | `grep -rh "^import " Packages/Core/Sources/Core` → 27 × `import Foundation`, nothing else. `import Core` appears only in the `CoreCLI` target. The EPIC 01 import-boundary test is green inside (d). | transitive imports |
| (f) hygiene | PASS, empty=PASS | `print(` under `Sources/Core` 0 (only `CoreCLI/main.swift`, the CLI entry point); `TODO\|FIXME\|XXX` 0; `try!\|as!` 0; force-unwrap heuristic 0; `Date()` under `Packages/Core/Sources` 0; bare `# type: ignore` 0 | hand-written `!` patterns the heuristic regex misses |
| (f) glossary | PASS, empty=PASS for identifiers | `grep -wiE "frontier\|attempt\|session"` over `Packages/Core/Sources` returns one hit: a doc comment in `State/Expedition.swift` that explains "frontier" is banned. It is not an identifier. | — |
| (f) I5 | PASS | the two new fields (`remediated`, `past_last_unit`) are booleans; `IdentifierBlocklistParityTests` and pytest `test_contracts.py` blocklist rejection are green | — |
| (f) I6 | PASS | no verbatim or Ministry-text field; 20 of 20 `data/demo` nodes carry `paraphrase` | — |
| (f) I8 | PASS | `core-cli validate data/demo` returns passed=true. L0-1, 2, 3a, 3b, 5, 6, 7, 8, 9, 10 each have 0 violations; L0-4 is advisory and reported under `indegree`. L0-T runs only at trail generation and is covered by `MarkerTrailGenerationTests` and `MarkerTrailGenerationNegativeControlTests`. | — |
| (f) I15 | PASS | `data/demo/landmarks.json`: 1 landmark, `source_url` present | — |
| (f) R-6 | PASS **by recorded judgment** (§8) | `grep -rcE "20[0-9]{2}-[0-9]{2}-[0-9]{2}"` over `Packages/Core/Tests` finds 54 literals in 9 files | — |
| (f) I11 | PASS | `no-time-estimates` pre-commit hook green on every commit | — |
| (g) cross-EPIC audit | not due | the audit runs every 3 EPICs; the next is due after EPIC 03 | — |
| (h) contract bumps | PASS | §4 | — |
| (i) DEFERRED | PASS | D-12 and D-13 added (§6) | — |
| (j) C1 seams | PASS | §5 | — |
| (k) C4 artifacts | PASS | §3 | — |

## 2. Tasks completed

| Task | Slug | Commits | Test depth |
|---|---|---|---|
| 02.1 | contract-interaction-numeric-normalisation | `2670a1b` | Tester ran every grep instrument in spec §5 and every AC. No conformance rung is owed for contract prose (the enforcement-ladder rung for `interaction-contract` is the CoreTests state-machine suite, delivered by 02.4–02.7), so the tester made no commit. |
| 02.2 | contract-data-model-remediated-flag | `397497a`, `62819bc` | comprehensive |
| 02.3 | l0t-trail-rule-contract | `5f8384a` | Prose only, in the same shape as 02.1. The orchestrator checked the diff against the Q5 ruling instead of dispatching a tester; the behaviour is tested by 02.5. |
| 02.4 | core-error-calendar-day-mastery | `80ed76e`, `e26ec83` | comprehensive; the tester added the missing `CoreEvent` (AC7) and `PropertyGen` determinism (AC8) suites |
| 02.5 | marker-trail-reconciliation | `c530f3e`, `44aeafb` | comprehensive; the tester added a negative control for the implementer's resident-node-set completeness check |
| 02.6 | fringe-compose-seam | `963985a`, `a917ea6` | comprehensive |
| 02.7 | item-checker-expedition-run | `94268d7`, `f0acc1c` | comprehensive; the tester added the T5 `diagnosisUsed` monotonicity guard that spec §5 names, plus `EXP_ITEM_POOL_EMPTY` retry-skip coverage |

Brief §4 items delivered by 02a: 1 (mastery transitions), 2 (marker/trail), 3 (fringe/compose), 4 (item
checker and run), 8 (C1 marker→trail→fringe), 10 (`CoreError` ⊆ registry). Items 5, 6, 7 and 9 (diagnosis,
Tier-0 terminals, C1 expedition↔diagnosis, merge) are 02b's.

## 3. (k) C4 artifact → gate

| Artifact | Gate that exercises it | Excludes |
|---|---|---|
| `Core` library: new `Time/CalendarDay`, `State/MasteryTransitions`, `Events/CoreEvent`, `State/MarkerTrailGeneration`, `State/Expedition`, `ItemChecker`, `State/ExpeditionRun`, extended `CoreError` | (d) `xcodebuild test -scheme Core-Package` on the simulator | device runtime (D29) |
| `core-cli` binary | (d) `swift build -c release --product core-cli`; EPIC 01 pytest seam test; (f) `core-cli validate data/demo` | nothing new in 02a |
| App build | (d) `xcodebuild build -scheme mathmath` | no App code changed in 02a |
| `student-state.schema.json` + example (v1.3.0) | pytest `test_contracts.py`; `DecodeRoundTripTests`, `OptionalAbsentTests`, `StudentStateV130ContractTests` | behaviour |
| Contract prose: `interaction-contract` v0.9.1, `graph-constraints` v1.1.0 | spec grep instruments (02.1 run by the tester, 02.3 by the orchestrator); behaviour tested by 02.5–02.7 | — |
| `data/demo` (unchanged) | (f) I8 `core-cli validate` | — |
| L0-T runtime check | `MarkerTrailGenerationTests`, `MarkerTrailGenerationNegativeControlTests` | bundle-time validation, which L0-T does not do by contract |

## 4. Contracts touched (h)

| Contract | Version | Task | Why |
|---|---|---|---|
| `data-model.md` + `student-state.schema.json` + example | v1.2.0 → v1.3.0, `schema_version` 2 | 02.2 | `nodes[].remediated` (arbiter Q-A) and `marker.past_last_unit` (arbiter Q-F); the migration from v1 is an identity |
| `interaction-contract.md` | v0.9.0 → v0.9.1 | 02.1 | exact numeric normalisation; `remediated(p)` wording; `past_last_unit`; probe item availability (Q-G) |
| `graph-constraints.md` | v1.0.0 → v1.1.0 | 02.3 | L0-T trail-segment rule rewritten per the owner's Q5 ruling 02-QE |

Each bump is committed as `contract(<name>): …` with its change log folded into the version line. `CLAUDE.md`
I8 was reworded by the orchestrator (`80a47a5`) on the owner's authority (Q5 02-QE).

## 5. (j) C1 seams

| Seam | Test | Both sides real? |
|---|---|---|
| marker → trail → fringe | `Packages/Core/Tests/CoreTests/MarkerTrailFringeSeamTests.swift` | yes: real `MarkerTrail.setMarker` + `generateTrail` + `Expedition.compose` on the real `data/demo`; no stubbed trail and no hand-built fringe |
| expedition ↔ diagnosis | owned by 02.11 (02b) | — |

## 6. Deferrals (i)

- **D-12:** the `MAP_MARKER_OFF_TRAIL` user text says the marker stays, but the load-time fallback moves it. Trigger: EPIC 03.
- **D-13:** an untracked SwiftPM directory `App/mathmath.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`
  appears after simulator builds. Trigger: the next tooling or `.gitignore` change.

## 7. Escalations during the run

- **Q5 02-QE (owner, 2026-09-10).** L0-T and I8 required each course segment of a trail to be a directed path.
  Neither demo course can satisfy that in any ordering. The owner ruled option A: unit order, then topological
  order within a unit; an edge against unit order is a warning; extension nodes must be reachable. Records:
  `tasks/blocked/Q5-RULING-02-QE.md`, `docs/blocked/run-stop-02-qe-trail-path.md` (resolved).
- **Q4 pre-dispatch arbitration:** Q-A, Q-B, Q-C, Q-D, Q-F and Q-G ruled by the spec-arbiter
  (`tasks/arbitration/arbiter-02-predispatch.md`). Brief amended (02.03.1).
- **Reviewer BLOCKs fixed at spec level before implementation:**
  - 02.3: citation form.
  - 02.6: a "Technical defaults" quote attributed to the arbiter file; the real source is brief §9.
  - 02.7: `let` properties mutated in §4, which would not compile.
  - 02.9 (02b): quote re-wrapped.
  None reached the spec-arbiter.
- **Context-bundle defects caught downstream:**
  - the 02.3 bundle contained a quote that appears in no source and a false audit line (corrected in place);
  - the 02.5 bundle had the wrong MCR3U unit-1 order;
  - the 02.6 bundle had signature sketches that do not match 02.5;
  - the 02.10 bundle conflated the `compose` fringe guard with the query's candidate filter;
  - the 02.11 bundle mis-typed `hintTree`.
  Every one was caught by the writer or the reviewer. None reached code.

## 8. R-6 judgment

The grep finds 54 ISO-date literals in 9 test files:
- `CalendarDayTests`
- `MasteryTransitionsTests`
- `PropertyGenTests`
- `Support/PropertyGen`
- `ExpeditionComposeTests` and `ExpeditionComposeBoundaryTests`
- `ExpeditionRunTests` and `ExpeditionRunBoundaryTests`
- `MarkerTrailFringeSeamTests`

Every hit is one of three things:
- the `today: CalendarDay` value a test passes into a pure function;
- a `probe_log` day, `last_probe`, `next_due` or `install_day` value in a fixture state;
- a parse or emit sample in `CalendarDayTests`, which is what those tests exist to check.

`Core` never reads a clock: `grep -rn "Date()" Packages/Core/Sources` finds 0 hits, and `today` is always
injected (data-model § Time). R-6 targets fixtures whose outcome depends on a hardcoded date instead of an
injected clock, and none of these does. This is the same judgment EPIC 01 recorded
(`docs/audits/epic-01-acceptance.md` §1).

## 9. (R-7) `fix:`-commit table and cascade check

There are no `fix:` commits on the branch (0 rework, 0 output). No tester tier-upgrades. EPIC 01 landed with
1 `fix:` commit (`8e2e313`), so the cascade trigger (> 3 rework fixes in two consecutive EPICs) does not fire.

## 10. Physical-device verification

Agents verified on the iOS simulator only. **No agent claims physical-device verification** (D29). That is
the owner's check at the Demo wrap.
