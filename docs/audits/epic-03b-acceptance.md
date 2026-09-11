# EPIC 03b acceptance — Map app

**Branch:** `epic-03b-map-app`, cut from `main` at `dcc42d6`. That commit is the merge of PR #9 (03a); `main`'s CI
run 34553565078 on it was green. **Brief:** `docs/epics/epic-03-app-map-shell.md` · **Plan:**
`docs/plans/epic-03-plan.md` · **Date:** 2026-09-10

EPIC 03 was split at the brief's §8 seam, the map-actions façade (recorded in `docs/epic-plan.md`). **03b** is the
App half. It covers tasks 03.9–03.12, task 03.13b, and this wrap (03.13). Task 03.13b is a `Core` rename that came
out of the cross-EPIC audit (§7). **03a** (03.0–03.8, the `Core` half) merged earlier; see
`docs/audits/epic-03a-acceptance.md`. This wrap closes EPIC 03, so the every-3-EPICs cross-EPIC audit (g) runs
here, over EPICs 01–03.

## 1. Gate results

| Gate | Result | Instrument | Excludes |
|---|---|---|---|
| (a) typecheck | PASS (0 errors, 0 warnings) | `pyright` strict over `pipeline/` | Swift type checking, which (d) covers |
| (b) lint | PASS | `swift-format lint --strict`; `ruff check pipeline` | — |
| (c) format | PASS | `ruff format --check pipeline` | — |
| (d) tests | PASS | `scripts/gate.sh` exit 0, "gates green". It covers: the `core-cli` release build; `Core-Package` tests on the simulator (568 tests in 57 suites at `ecf0bbf`, the final tree, run by both the 13b implementer and the 13b tester); `Rendering` tests; the App build (Debug, fixed `-derivedDataPath`); **`scripts/sim-smoke.sh`** (scenario 1 PASS, scenario 2 PASS, embedded snapshot byte-identical); `pytest` (190 passed) | physical device (D29) |
| (e1) commit messages | PASS | the `conventional-pre-commit` hook ran on every commit | — |
| (e2) CI | the PR must pass before merge | the ruleset on `main` blocks the merge until both checks are green. This PR is the first CI run of 03.12's `ci.yml` change (pinned `setup-uv` and the smoke step). | — |
| (f) I14, Core | PASS | `grep -rh "^import " Packages/Core/Sources/Core` returns 36 lines, all `import Foundation` | transitive imports |
| (f) I14, App | PASS | the 03.9 `AppSourcesBoundary` scan runs over the real `App/Sources` tree, now with the SwiftMath exception deleted (03.12). The 03.10, 03.11 and 03.12 structural suites (§2) back it. | runtime SwiftUI behaviour (§3) |
| (f) hygiene | PASS, empty=PASS | Under `Packages/Core/Sources/Core`, `print(`, `TODO\|FIXME\|XXX`, `try!\|as!`, `Date()` and `URLSession\|URLRequest` each return 0. Under `App/Sources`, `print(\|try!\|as!\|TODO\|FIXME` returns 0. The one `print(` elsewhere in `Packages/Core/Sources` is `CoreCLI/main.swift:10`, which is the CLI's stdout contract. | — |
| (f) clock | PASS | `Core` never reads a clock: `Date()` under `Sources/Core` returns 0. The App reads it exactly once, at `AppShell.swift:113` (`resolveToday`), and injects `today`. | — |
| (f) glossary | PASS **for the scanned terms only**, after 03.13b (§7) | The case-sensitive `Session` scan returns 0. The single-term guards return 0: session, profile, cursor, save, start marker, and now "attempt" (`CoreGlossaryAttemptGuardTests`). `grep -rniw "attempts\?"` over `Packages/Core/Sources` and `App/Sources` returns 0. The cross-EPIC audit found the "attempt" violation that the EPIC 02 and 03a glossary rows missed, so this row no longer claims coverage beyond the terms listed here. `AppShell.swift:4–5` uses the word "session" in a doc comment quoting arbiter-03 § Q-F; this is prose, not an identifier or copy. | **the full 57-term banned list in `contracts/domain-glossary.md`.** No sense-aware gate over it exists yet, so it is routed as a follow-up (§7). |
| (f) I5 | PASS | the new App files carry no identifier. `IdentifierBlocklistParityTests` and the 03.9 identifier rules are green. | — |
| (f) I6 / I15 | PASS | panels show `paraphrase`, expectation codes paired with `official_url`, and landmark `source_url` via `Link` only, never fetched. Checked structurally by the 03.11 tests. `data/demo` is unchanged. | — |
| (f) I8 | PASS | `core-cli validate data/demo` returns passed=true; the embedded snapshot's 7 files are byte-identical to `data/demo` (`cmp`). | — |
| (f) R-6 | PASS **by recorded judgment** (§8) | the date-literal grep over `Packages/Core/Tests` finds 146 ISO-date literals in 23 Swift test files | — |
| (f) I11 | PASS | `no-time-estimates` hook green on every commit | — |
| (g) cross-EPIC audit | **RED → resolved by rename** (§7) | `integration-auditor` over EPICs 01–03, `docs/audits/cross-epic-01-03.md`. CC1–CC15 are GREEN. F1 is RED: "attempt" appears in `Core` identifiers. Spec-arbiter ruling `arbiter-03-audit-f1-attempt.md` upholds F1. Task 03.13b renames the identifiers (`ecf0bbf`) and adds a mechanical guard. | the auditor did not run the gate or the simulator, by instruction; the orchestrator's full gate run covers them |
| (h) contract bumps | PASS: none in 03b | interaction-contract stays at v0.9.2; EPIC 04 bumps it to v1.0.0 (task 04.12) | — |
| (i) DEFERRED | PASS | D-12 closed. D-13 re-measured and still unstaged. D-16 added. | — |
| (j) C1 seam | PASS | §5 | — |
| (k) C4 artifacts | PASS | §3 | — |

## 2. Tasks completed

| Task | Commits | Verification |
|---|---|---|
| 03.9 app-sources-i14-scan | `489e0e9`, `35e770b` | The implementer made `Rule` `Sendable` with a `@Sendable` closure, for Swift 6; this was a compile-only deviation. The tester closed six gaps: all 10 forbidden `Core` type names are now planted, not just 4; the `URLRequest` branch; the exact-line SwiftMath scope; `.plist` skipped as well as `.json`; the real-tree walk is shown to be non-vacuous; the violation set is deterministic. |
| 03.10 app-map-canvas | `ed00479`, `7ec1c03` | The orchestrator **rejected** one deviation: pan and zoom committed only `.onEnded`. It was reworked inside the task, and the commit was amended before push. The gesture baseline now lives in the `MapCamera` value (`applyDrag`, `applyMagnification`, `endGesture`), with no new stored property in the view. Two deviations were accepted: the inverse transform returns `CGPoint` (`Core.Point`'s memberwise init is internal), and taps use `SpatialTapGesture`. Tests: `MapCanvasViewStructuralTests` (AC1, AC2, AC3 and AC8, each with a negative control). |
| 03.11 app-panels-pickers-handoff | `feaa267`, `c4aa9fe` | No deviations. Tests: `MapPanelsPickersHandOffStructuralTests`, 36 tests covering AC1–AC11, I6, I15, I14 (exactly one `@State`) and a cross-check against `error-codes.json`. |
| 03.12 app-shell-launch-smoke | `8c25724`, `fca1513` | The SwiftMath exception is deleted. `scripts/sim-smoke.sh` was added and wired into `gate.sh` and CI. Two deviations were accepted (§6). Tests: `AppShellStructuralTests`, plus the stale exception naming in `AppSourcesBoundaryAuditTests` renamed. |
| 03.13b rename-failed-probe-attempt (from audit F1) | `ecf0bbf` (tester: no commit, no gap) | The spec-arbiter wrote this spec (`arbiter-03-audit-f1-attempt.md`). It is a pure rename to the glossary's **Miss** term, with no behaviour change. It adds the guard `CoreGlossaryAttemptGuardTests`, with a negative control. The §8 edits to the EPIC 04 specs and context bundles are applied before EPIC 04 dispatch. The EPIC 04 packet is untracked here and is committed on the 04a branch. The tester reconstructed the edited test files byte for byte and found only renames, with the same `@Test` counts per file (31/10/7/4). The guard asserts `scanned > 0`, matches case-insensitively, and its negative control is shown red on the old declaration and green on the new one. It scans `Sources/Core` only, per AC5; `CoreCLI` has 0 hits, and `App/Sources` is scanned by 04.10. All 8 ACs pass. |

The orchestrator also cross-checked the EPIC 03 interfaces before each dispatch:
- the 03.11 signatures that 03.12 calls, against `feaa267`;
- `MapCanvasView(mapViewModel:onNodeTap:)`, against `ed00479`;
- the 03.9 test files that 03.12 edits.

None had drifted.

## 3. (k) C4 artifact → gate

| Artifact | Gate | Excludes |
|---|---|---|
| `App/Sources/Map/{MapCamera,MapCanvasView}.swift` | (d) App build; source-level structural tests | **the `MapCamera` math (round trip, zoom clamp, gesture baseline, initial framing) and the runtime tap and gesture behaviour.** No App unit-test target exists, and the project file is never edited, so no automated test covers them. Only the owner's Demo check exercises them (D29). |
| `App/Sources/MapUI/*.swift` (6 files) | (d) App build; structural tests | sheet presentation and tap-driven navigation at runtime |
| `App/Sources/Shell/{AppShell,RefusalView}.swift`, `ContentView.swift`, `MathmathApp.swift` | (d) App build; `sim-smoke.sh`; structural tests | SwiftUI phase transitions beyond what `sim-smoke.sh` observes on the file system |
| `scripts/sim-smoke.sh` | (d) run by `gate.sh` on the iOS simulator: fresh install writes no state; v1→v2 migration validates against `student-state.schema.json`; terminate and relaunch is byte-identical; the built snapshot is byte-identical to `data/demo` | device runtime (D29) |
| `scripts/gate.sh`, `.github/workflows/ci.yml` | the local gate run; the step order is checked as text by `AppShellStructuralTests` | CI execution itself is verified only by this PR's run |
| Embedded snapshot inside the built `.app` | `sim-smoke.sh` `cmp`. This discharges the 03a §3 exclusion ("the built `.app` contents"). | — |
| `AppSourcesBoundary` scan (test-side) | (d) `Core-Package` tests over the real `App/Sources` | named-func calls; EPIC 04 task 04.10 extends the scan |

## 4. Contracts touched

None. interaction-contract stays at v0.9.2 and `error-codes.json` is unchanged (plan note on 03.13).

## 5. (j) C1 seam

| Seam | Test | Both sides real? |
|---|---|---|
| bundle loader ↔ Core validation | `DemoSnapshotSeamTests` (03.4, 03a) | yes |
| Core ↔ render layer | `sim-smoke.sh`, where the App launches through `MapLaunch.open` over the real built snapshot and state file. `AppShellStructuralTests` asserts that `AppShell` calls `MapLaunch.open` exactly once and never calls `BundleLoader`, and that `MapLaunch.open` calls `BundleLoader.load` exactly once, so the path is the same load path the 03.4 seam test covers. | yes, on the simulator |

## 6. Deviations accepted at the wrap (03.12)

1. **`AppShell.resolveSnapshotDir()` returns `Bundle.main.resourcePath` directly.** Xcode's synchronized group copies
   `App/Sources/DemoSnapshot/*.json` flat into the `.app` resource root. With the spec's literal
   `DemoSnapshot` subpath, `MapLaunch.open` refused the bundle on every launch. The first smoke run caught this:
   the migration scenario never wrote a state file. Spec §6's decision default named the smoke `cmp` as the
   arbiter. The EPIC 04 specs were checked: none quotes the subpath.
2. **`catchesSwiftMathImportInNestedContentView` now expects 2 reports, not 1.** Violations are keyed on
   `lastPathComponent`. With the carve-out gone, a nested `ContentView.swift` and a top-level one report
   identically. The arbiter's claim that the sibling test "stays valid unchanged" was wrong, as running the test
   showed.

## 7. Notes

- **Glossary prose.** `AppShell.swift:4–5` calls the map state "the current map session" in a doc comment
  quoting arbiter-03 § Q-F. The rule (`docs/plans/epic-03-plan.md`: never "session" in new identifiers or copy;
  `contracts/domain-glossary.md`: a session is a telemetry day-unit) covers identifiers and student copy, so
  this comment does not violate it. It was left unchanged.
- **Audit F1: "attempt" in `Core` identifiers.**
  - **Finding:** the cross-EPIC audit flagged `FailedProbeAttempt`, `incorrectAttempts` and `failedAttempts:`
    (EPIC 02 task 02.10, commit `addb1a1`).
  - **First reading:** the orchestrator read the line-40 ban as scoped to its sense, "attempt" as a synonym for
    *diagnosis event*, which this type is not. The glossary's other bans are sense-scoped the same way: "strand",
    "session", "unknown (as a state)", "dependency (in data)".
  - **Arbitration:** the orchestrator routed that reading to the spec-arbiter (Q4). The arbiter upheld F1 on
    grounds that do not depend on line 40:
    - the glossary already names the concept: **Miss** is "an incorrect answer" (line 34);
    - the header requires one term per concept;
    - line 34 bans "fail" for an item;
    - `docs/domains/diagnosis.md:54` says "Classify the miss";
    - `docs/plans/epic-02-plan.md:90–91` banned "attempt" in new identifiers at the wrap grep, which the EPIC 02
      wrap missed.
  - **Rename (task 03.13b):** `FailedProbeAttempt` → `ItemMiss`; `incorrectAttempts` / `failedAttempts:` →
    `misses`. The EPIC 04 specs name `pendingHandoffMisses`.
  - **Mechanical guard:** `CoreGlossaryAttemptGuardTests`, with a negative control.
  - **Same-commit fixes:** the EPIC 04 plan's grandfather clause was withdrawn. It also listed
    `FurtherLevelOffer` and `levelBudget`, which need no exemption because they name the defined term
    **backtrack level**. The v1 leftovers "session" and "Attempt record" in `docs/domains/learning-objects.md` W2
    were replaced with "diagnosis event".
- **Process gap (standing).** The glossary rows of the EPIC 01, 02 and 03a acceptance reports grepped a partial
  term list ("session", "frontier", "start marker" and so on), not the full banned list in
  `contracts/domain-glossary.md` (57 terms). The new guard covers "attempt" only. A sense-aware gate over the
  full glossary is routed as a follow-up. A plain word grep would false-positive on the glossary's own
  vocabulary: `fail` as a probe outcome, **backtrack level**, SwiftUI `Link`, Foundation `resourcePath`.
- **Erratum, 03a.** The 03a hygiene row said the greps ran "under `Packages/Core/Sources`". The zero result
  holds for `Packages/Core/Sources/Core`; `CoreCLI/main.swift:10` has always had its stdout `print(`. The row
  is corrected in this PR.
- No Q5 was raised in 03b.

## 8. R-6 judgment

The grep finds 146 ISO-date literals in 23 Swift test files. 03b added none: its new tests are structural
source scans. Each literal is:
- an injected `today: CalendarDay`,
- a fixture day value, or
- a `CalendarDay` / `StudentState` parse and emit sample.

`Core` never reads a clock. The same judgment was made for EPIC 01, 02 and 03a.

## 9. (R-7) `fix:`-commit table and cascade check

| Commit | Cause | Corrects task | Risk tier | Rework / output |
|---|---|---|---|---|
| `ecf0bbf` `refactor(core)`: rename `FailedProbeAttempt` → `ItemMiss` | contract-gap: glossary nonconformance that the EPIC 02 wrap grep missed, found by the cross-EPIC audit (F1) | EPIC 02 task 02.10 | seam | rework |

13b is a `refactor`, not a `fix:`. It is still counted as rework here because it corrects an earlier task's
nonconformance with a contract. The 03.10 pan and zoom rework was done inside the task, before push, by amending
the task-commit, so it corrected no earlier task. The 03.12 test adjustment (§6.2) was also done inside the task.

EPIC 03 totals: 03a 2 rework plus 03b 1, so **3 rework, 0 output.** The cascade check fires only when rework is
above 3 in each of two consecutive EPICs. EPIC 02 had 1 and EPIC 03 has 3, so it does not fire. EPIC 03 is at 3,
not above it, so the EPIC 03–04 pair cannot fire the cascade whatever EPIC 04's count is.

## 10. Deferrals

- **D-12 closed** by arbiter Q-A. It is revisited at EPIC 10.
- **D-13** re-measured. It is still untracked and unstaged, and it differs from the tracked `Package.resolved`
  files only in `originHash`.
- **D-16 added**: the region and landmark panels have no tap trigger in the Demo.
- **Standing gap** routed to the owner as an optional Q5 in the run report: an App unit-test target. Without
  one, `MapCamera`'s math and the runtime UI behaviour have no automated test (§3).

## 11. Physical-device verification

Agents verified on the iOS simulator only: builds, `sim-smoke.sh`, and tests. **No agent claims
physical-device verification** (D29). The owner's device check of the Demo map is the delivery verification.
