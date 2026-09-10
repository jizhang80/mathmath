# EPIC 02 acceptance — Core behaviour (02b wrap: Door A core + merge; EPIC 02 as a whole)

**Branch:** `epic-02b-door-a-core-merge` · **Brief:** `docs/epics/epic-02-core-behaviour.md` (amendment 02.03.1) ·
**Plan:** `docs/plans/epic-02-plan.md` · **Date:** 2026-09-10

EPIC 02 was split at the brief's §8 seam (`docs/epic-plan.md` § EPIC 02 split; scope unchanged). **02a** (Door B
core, 02.1–02.7) merged in PR #7 with its own acceptance report, `docs/audits/epic-02a-acceptance.md`. This
report covers **02b** (02.9–02.12, plus the fix task 02.5b) and traces brief §4 items 1–10 for the whole EPIC.

## 1. Gate results (02b branch)

| Gate | Result | Instrument | Excludes |
|---|---|---|---|
| (a) typecheck | PASS: 0 errors, 0 warnings | `pyright` strict over `pipeline/` (`scripts/gate.sh`) | Swift type checking, which is covered by (d) |
| (b) lint | PASS: ruff "All checks passed!"; swift-format strict clean | `swift-format lint --strict` over `Packages` and `App/Sources`; `ruff check pipeline` | — |
| (c) format | PASS: 17 files already formatted | `ruff format --check pipeline` | — |
| (d) tests | PASS: `scripts/gate.sh` exited 0 ("gates green") at `e4ffe8c`, the final code commit before this report; `pytest` 162 passed. xcodebuild runs quiet, so the instrument is the exit status. | `scripts/gate.sh`: `core-cli` release build; `Core-Package` and `Rendering` tests on the simulator; App build; `pytest` | physical device (D29, §10) |
| (e1) commit messages | PASS | the `conventional-pre-commit` hook ran on every commit | — |
| (e2) CI | PASS required before merge | the ruleset on `main` blocks the merge until both checks are green; the run is linked from the PR | — |
| (f) I14 | PASS | `grep -rh "^import " Packages/Core/Sources/Core` → 31 × `import Foundation`, nothing else | transitive imports |
| (f) hygiene | PASS, empty=PASS | `print(` / `TODO\|FIXME\|XXX` / `try!\|as!` / `Date()` under `Packages/Core/Sources/Core`: 0 hits each | — |
| (f) glossary | PASS after fix | The grep found the banned term `frontier` as BFS layer variables in `Graph/PrerequisiteQuery.swift` (02.10). Renamed `currentLayer`/`nextLayer` in a `refactor(core)` commit; the only remaining hit is `State/Expedition.swift:4`, a doc comment explaining the ban. | — |
| (f) I5 | PASS | `StateMerge` introduces no identifier (merged state passes `IdentifierBlocklistParityTests`); `DiagnosisOutcome` fields are ids, enums, booleans and ints only (Mirror scan in the 02.11 tests) | — |
| (f) I6 / I15 | PASS | `data/demo` unchanged by 02b; 20/20 nodes carry `paraphrase`; 1 landmark with `source_url` | — |
| (f) I8 | PASS | `core-cli validate data/demo` → passed=true | — |
| (f) R-6 | PASS **by recorded judgment** (§8) | the date-literal grep finds 102 ISO-date literals in 17 test files | — |
| (f) I11 | PASS | `no-time-estimates` hook green on every commit | — |
| (g) cross-EPIC audit | not due | every 3 EPICs; due after EPIC 03 | — |
| (h) contract bumps | PASS | §4 | — |
| (i) DEFERRED | no new entry in 02b | the finding in §6 is routed to task 03.8's entry, to avoid colliding with the DEFERRED ids planned by EPIC 03 | — |
| (j) C1 seams | PASS | §5 | — |
| (k) C4 artifacts | PASS | §3 | — |

## 2. Tasks completed (02b)

| Task | Commits | Test depth |
|---|---|---|
| 02.9 contract-state-merge-rule | `34ae117` | The orchestrator checked mechanically that the 27 lines of arbiter Q-B text (lines 85–111, prefix stripped) sit verbatim in `contracts/data-model.md`, and that the version reads v1.4.0 with one file changed. The task is prose only. |
| 02.10 prerequisite-query-classify | `addb1a1`, `44a9fae` | comprehensive; the tester added blocked-candidate cases with a negative control for the wrong "blocked excluded" filter |
| 02.12 state-merge | `e388060`, `6f3dfb2` | comprehensive: 38 tests, including the spec's T3/I14 greps and both branches of the winning-side rule |
| 02.11 diagnosis-machine-seam | `4b53171`, `2f4c03c` | comprehensive; the tester added the AC15 `public init` instrument, AC14 per-item shape, and the Q-G map_check_here branch |
| 02.5b fix-set-marker-past-last-unit | `c9e893d`, `f77b727` | comprehensive; the tester reconstructed the pre-fix `setMarker` as a negative control and added the relaunch and merge seams |
| glossary rename | `e4ffe8c` | no behaviour change; covered by the 02.10 suite in (d) |

**Brief §4 trace (whole EPIC):**
1. Mastery transitions: `MasteryTransitionsTests`, `CoreEventTests`, `PropertyGenTests`.
2. Marker and trail: `MarkerTrailGenerationTests`, `MarkerTrailGenerationNegativeControlTests`, `MarkerTrailSetMarkerPastLastUnitTests`, `MarkerTrailSetMarkerPastLastUnitGapTests`.
3. Fringe and compose: `ExpeditionComposeTests`, `ExpeditionComposeBoundaryTests`.
4. Item checker and run: `ItemCheckerTests`, `ItemCheckerBoundaryTests`, `ExpeditionRunTests`, `ExpeditionRunBoundaryTests`.
5. Query and diagnosis: `PrerequisiteQueryTests`, `ClassifyTests`, `DiagnosisMachineTests`, `DiagnosisMachineBoundaryTests`.
6. Tier-0 terminals: `DiagnosisTier0CompletenessTests`.
7. C1 expedition↔diagnosis: `ExpeditionDiagnosisSeamTests`.
8. C1 marker→trail→fringe: `MarkerTrailFringeSeamTests`.
9. Merge: `StateMergeTests`, `StateMergeBoundaryTests`.
10. `CoreError` ⊆ registry: `ErrorRegistryTests`.

## 3. (k) C4 artifact → gate

| Artifact | Gate | Excludes |
|---|---|---|
| `Core` library: new `Graph/PrerequisiteQuery`, `Diagnosis/Classify`, `Diagnosis/DiagnosisEvent` (step-wise `DiagnosisRun`), `State/StateMerge`; `MarkerTrail.setMarker` fix | (d) `Core-Package` tests on the simulator | device runtime (D29) |
| `core-cli` | (d) release build; (f) `core-cli validate data/demo` | — |
| App build | (d) `xcodebuild build -scheme mathmath` | no App code changed in 02b |
| `contracts/data-model.md` v1.4.0 (prose) | orchestrator's mechanical verbatim check; merge behaviour tested by 02.12 | — |

## 4. Contracts touched (whole EPIC)

| Contract | Version | Task | Why |
|---|---|---|---|
| `data-model.md` + schema + example | v1.2.0 → v1.3.0 | 02.2 | `remediated`, `past_last_unit` |
| `data-model.md` | v1.3.0 → v1.4.0 | 02.9 | StudentState merge rule (arbiter Q-B) |
| `interaction-contract.md` | v0.9.0 → v0.9.1 | 02.1 | numeric normalisation, `remediated(p)`, `past_last_unit`, probe availability |
| `graph-constraints.md` | v1.0.0 → v1.1.0 | 02.3 | L0-T rewrite (owner Q5 02-QE) |

## 5. (j) C1 seams

| Seam | Test | Both sides real? |
|---|---|---|
| marker → trail → fringe (02a) | `MarkerTrailFringeSeamTests.swift` | yes, on the real `data/demo` |
| expedition ↔ diagnosis (02b) | `ExpeditionDiagnosisSeamTests.swift` | yes: a real `ExpeditionRun` second miss, then a real step-wise `DiagnosisRun`, then a resume, on the real `data/demo`; diagnosis count = 1; the blocked candidate is visible through the threaded state; prior answers are present |

## 6. Findings and deferrals

- `data/demo/manifest.json` has placeholder sha256 values of 66 hex characters, not the 64 of a SHA-256 digest (found by the 04.1b reviewer). Routed to the embedded-snapshot hash-verification DEFERRED entry that EPIC 03 task 03.8 writes (trigger EPIC 10). No 02b entry.
- Context bundles again carried fabricated or misattributed citations. The downstream writer or reviewer caught every one, with arbitration where needed (§7), and none reached code.

### Test-suite determinism: the live-landmark flake recurred in CI

The first CI run on PR #8 (run 34528761105) failed the `Python pipeline` job on one test:
`tests/test_verify_landmarks_contract.py::test_resolve_source_ref_raises_spine_source_ref_unresolved_when_registered_url_404s`,
with `ConnectionResetError: [Errno 54] Connection reset by peer`. The other 161 passed, and the Swift job passed.
This is the only non-hermetic test in the repo (a live HTTPS fetch, deliberately so per I15). It is the second
recurrence of the flake: EPIC 01 acceptance §7 recorded the first, and 02.12's local gate hit it and passed on
retry.

Brief §7.10 says this item "enters only if CI flakes, as a separate `fix(pipeline)` task". It has now flaked in
CI, so the task is due. It is scheduled as the first task on the next branch (EPIC 03a). Its purpose is to tell a
transport blip (retry, then mark inconclusive) apart from a genuinely dead source (fail), without weakening
I15. Nothing in 02b's code touches `pipeline/`. The merge relies on a green re-run of the unchanged job, recorded
on the PR.

## 7. Escalations during 02b

- **02.9:** the reviewer blocked it because the quote had been re-wrapped. The writer retried and it passed.
- **02.11 (spec-arbiter, four rulings before implementation):**
  - The dead `.capped` branch was fixed by the writer.
  - `probe_completed` is emitted on pass/fail/declined and not on unavailable (`arbiter-02-11-probe-completed.md`).
  - The API became step-wise so EPIC 04's touch UI can drive it (`arbiter-02-11-stepwise-api.md`).
  - A capped node is never `remediated` (`arbiter-02-11-capped-remediated.md`).
  - `none_of_these` is the classify abstain value and `none-of-these` is the error-type id; `hintKey` returns nil rather than borrowing another type's hint (`arbiter-02-none-of-these.md`).
- **02.5b:** the EPIC 03 reviewer found that `MarkerTrail.setMarker` never enforced interaction-contract §3's "setting it writes the course's last unit as `unit_id`". The spec-arbiter ruled that the rule is enforced once in `setMarker` (`arbiter-03-07-past-last-unit.md`), and the fix landed before this wrap.
- No Q5 in 02b. The EPIC's one owner decision was Q5 02-QE during 02a.

## 8. R-6 judgment

The grep finds 102 ISO-date literals in 17 test files. Each one is:
- an injected `today: CalendarDay`,
- a fixture day value, or
- a `CalendarDay` parse/emit sample.

`Core` never reads a clock (`Date()` under `Packages/Core/Sources` = 0). This is the same judgment as EPIC 01 and 02a.

## 9. (R-7) `fix:`-commit table and cascade check

| Commit | Cause | Corrects task | Risk tier | Rework / output |
|---|---|---|---|---|
| `c9e893d` fix(core): setMarker writes the course's last unit when past_last_unit is true | logic (the 02.5 spec quoted the rule; its outline and tests never exercised it) | 02.5 (02a) | seam | rework |

Totals for EPIC 02 (02a + 02b): **1 rework, 0 output.** There were no tester tier-upgrades.
- Cascade check (> 3 rework in two consecutive EPICs): EPIC 01 = 1, EPIC 02 = 1. It does not fire.

## 10. Physical-device verification

Agents verified on the iOS simulator only. **No agent claims physical-device verification** (D29).
