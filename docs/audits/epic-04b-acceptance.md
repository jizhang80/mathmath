# EPIC 04b acceptance — Door app

**Branch:** `epic-04b-door-app`, cut from `main` at `cd7c914` (the merge of PR #11, EPIC 04a). `main` CI run 34566864497
on that merge was green on both jobs. **Brief:** `docs/epics/epic-04-app-expedition-diagnosis-acceptance.md` · **Plan:**
`docs/plans/epic-04-plan.md` · **Date:** 2026-09-11

**04b** is the App half of EPIC 04. It covers tasks 04.7–04.12 and this wrap (04.13), which **closes EPIC 04**. It
calls `Core` only through the `DoorFacade` entry points that 04a shipped. The wrap fills the *simulator — agent*
cells of `docs/epics/demo-acceptance-record.md`. The *device — owner* cells stay blank for the owner (D29).

## 1. Gate results

| Gate | Result | Instrument | Excludes |
|---|---|---|---|
| (a) typecheck | PASS (0 errors) | `pyright` strict over `pipeline/` | Swift type checking, which (d) covers |
| (b) lint | PASS | `swift-format lint --strict`; `ruff check pipeline` | — |
| (c) format | PASS | `ruff format --check pipeline` | — |
| (d) tests | PASS | `scripts/gate.sh` exit 0, "gates green", at the final product tree `9a92440`: `core-cli` release build; `Core-Package` tests on the simulator (787 tests in 72 suites plus 1 intended known issue, per the 04.10 tester's full run; only contract text changed after it); `Rendering` green; App build green; `sim-smoke` scenario 1 and scenario 2 PASS, embedded snapshot byte-identical; `pytest` 190 passed, 0 skipped, so the live landmark resolution test passed | physical device (D29) |
| (e1) commit messages | PASS | the `conventional-pre-commit` hook ran on every commit | — |
| (e2) CI | must pass before merge | the ruleset on `main` blocks merge until both checks are green | — |
| (f) I14, Core | PASS | `grep -rh "^import " Packages/Core/Sources/Core` returns 41 × `import Foundation`; 04b adds no `Core` source | transitive imports |
| (f) I14, App | PASS | The 03.9 scan plus 04.10's Door rules pass over the real `App/Sources`. 04.10 checks one permitted `DoorFacade` entry per action/composition function. No `Core` transition type appears in App code, and there is no hand-rolled `==` over `Core` state (04.8, 04.9, 04.10 suites). | the render side is excluded (§5, Q-C) |
| (f) hygiene | PASS, empty = PASS | In `Packages/Core/Sources/Core`, `print(`, `TODO\|FIXME\|XXX`, `try!\|as!`, `Date()` and `URLSession\|URLRequest` each return 0. In `App/Sources`, `print(\|try!\|as!\|TODO\|FIXME` returns 0. The only `Date()` in the App is `AppShell.resolveToday` (03.12), and it is injected as `today`. | — |
| (f) I3 / I10 / I2 | PASS | I3: each answer card is its own phase (`DoorBPhase.answerCard` / `.diagnosisAnswerCard`) and only continue advances. I10: no `TextField` or `TextEditor` anywhere in `App/Sources/Doors`, checked directory-exhaustively. I2: `LO_HINT_NOT_FOUND` never appears in `App/Sources`, and hint and remediation prose comes only from 04.3 content. Each is a structural test with a negative control. | runtime screen order (Q-C 4) |
| (f) glossary | PASS **for the scanned terms** | The case-sensitive `Session` whole-word scan has one hit, `AppShell.swift:22`: a `///` doc comment that explains the ban ("never named `*Session*`"), the same category as `MapLaunch.swift:4`. It is not an identifier or copy. `attempts?` returns 0. The glossary guards in the Doors suites are green. | the full 57-term sense-aware gate is a standing follow-up (03b report §7) |
| (f) I8 | PASS | `core-cli validate data/demo` returns `passed: true` (10 checks). The embedded snapshot's 7 files are byte-identical. | — |
| (f) R-6 | PASS **by recorded judgment** (§8) | 173 ISO-date literals in 30 Swift test files, unchanged from the 04a wrap; 04b added none | — |
| (f) I11 | PASS | `no-time-estimates` hook green on every commit | — |
| (g) cross-EPIC audit | not due | runs every 3 EPICs; the next covers 04–06 | — |
| (h) contract bumps | PASS | interaction-contract v0.9.3 → **v1.0.0** (04.12); domain-glossary stays v1.0.1 | — |
| (i) DEFERRED | PASS: no new entries in 04b | the ledger ends at D-18 (04a); D-13 re-measured, still untracked and unstaged | — |
| (j) C1 seam | PASS | §5 | — |
| (k) C4 artifacts | PASS | §3 | — |

## 2. Tasks completed

| Task | Commits | Verification |
|---|---|---|
| 04.7 rendering-mathview | `2248f06`, `ffcdb0f` | `MathView` with a plain-text fallback on parse failure (Q-E), and `MathViewContent`. The tester added: AC4 view dispatch; agreement with `RenderCheck` over the whole 203-entry bundle, with a parity negative control; and empty/whitespace boundary cases. The `nonisolated` + `Sendable` additions (Swift 6) were accepted. |
| 04.8 app-expedition-screens | `166f3de` (re-dispatch after BLOCK), `fc7ffa1` | Six `Doors` views; `DoorRunHolder` / `DoorBRunSnapshot` / `DoorBPhase`; the Door B run screen. Lockstep updates to the two EPIC 03 structural suites follow §4.14. The orchestrator re-ran ruling §8 checks 5–7 (1 line; 44 / 38; only the two files) and the trap analysis: `answer` is reachable only mid-run, and `backToMap` clears the holder. The tester added 47 structural tests. |
| 04.9 app-diagnosis-screens | `5fb69fc` (re-dispatch after BLOCK), `787f23b` | Three `Doors` views; `DoorBPhase.diagnosisAnswerCard`; `isStandaloneDiagnosis`; the Door A actions. Lockstep updates to three structural suites follow §4.11.1–§4.11.3. The orchestrator re-ran checks 4–11 (44 / 38 / 48; 0 pinned literals; 9 = 9 Doors files) and confirmed that `resumeAfterDiagnosis` is reachable only in the non-standalone arm. The tester added 31 structural tests. |
| 04.10 app-sources-door-scan | `688b421`, `1401890` | `doorRules`, `doorCopyRule` (Doors only) and the per-function-body one-entry check, each with negative controls. The tester added: a helper-routed negative control that documents the C3 limitation verbatim; a drift guard for the duplicated forbidden-type list; and computed-`var` body coverage. Core: 787 tests in 72 suites, plus 1 intended known issue (AC9). |
| 04.11 demo-acceptance-record-template | `ededd7b` | Orchestrator mechanical check: DEMO-BRIEF §7 (7 items) and §8 (6 sections) are present, the Q-C list is verbatim, and every line is tagged. |
| 04.12 contract-interaction-v1-0-0 | `9a92440` | Orchestrator mechanical check: the header reads v1.0.0 (finalized by the Demo EPIC) with the Source clause appended; the last sentence is now "Finalized at v1.0.0."; the diff is limited to those two spots; `test_contracts.py` passes (36). |

## 3. (k) C4 artifact → gate

| Artifact | Gate | Excludes |
|---|---|---|
| `Packages/Rendering` `MathView` (04.7) | (d) `Rendering` tests: `MathViewTests` and `MathViewConformanceAndBoundaryTests` | on-device rendering fidelity (D29) |
| `App/Sources/Doors/*` (9 files), plus the `AppShell` and `MapActionsView` rewires (04.8, 04.9) | (d) App build; structural suites: `DoorExpeditionScreensStructuralTests`, `DoorDiagnosisScreensStructuralTests`, and the two EPIC 03 suites as updated | taps, layout, runtime traps, runtime screen order (Q-C 1–4) |
| The extended `AppSourcesBoundary` scan (04.10) | (d) `DoorAppSourcesBoundaryTests`, `DoorAppSourcesBoundaryGapTests`, negative controls | cross-function call tracing (C3, recorded with a control) |
| `docs/epics/demo-acceptance-record.md` (04.11; agent half filled at this wrap) | orchestrator mechanical check | the owner half (device) |
| `contracts/interaction-contract.md` v1.0.0 (04.12) | orchestrator mechanical check; `test_contracts.py` | — |

## 4. Contracts touched

| Contract | Change | Task |
|---|---|---|
| `interaction-contract.md` | v0.9.3 → **v1.0.0**: the discovery zone is closed at the Demo wrap, with no normative change | 04.12 |

## 5. (j) C1 seam: the render half (brief item 8)

- **App build green:** gate 4.
- **Every Door button's action is exactly one façade call:** 04.10's per-function-body scan over `App/Sources` (11 named action methods, plus `CheckHereActionButton.body`), with negative controls.
- **The `Core` tests of items 1 and 2 drive the same `DoorFacade` entry points:** 04a 04.5 AC13 and AC14, with 04a's source-scan proof that the seam tests reach `Core` only through `DoorFacade.*`.
- **What the agents cannot claim** (arbiter-04 § Q-C, verbatim from `tasks/arbitration/arbiter-04-predispatch.md:387-395`):

> **What it cannot claim** (the exclusion that must be stated verbatim in the 04b task specs and the acceptance
> report):
> 1. that any tap on a simulator actually fires its action: hit-testing, sheet and navigation presentation, and
>    keypad key → string binding at runtime;
> 2. that each Door screen is laid out so its controls are visible and reachable (e.g. continue and decline are
>    on screen);
> 3. that no runtime trap occurs along the Door screens after launch. The smoke only covers launch and relaunch;
> 4. that the sequence of screens a student sees matches the façade's screen values at runtime, rather than only
>    in `CoreTests`.

## 6. Rulings and process incidents in 04b

1. **04.8 BLOCK: EPIC 03 structural suites pinned pre-EPIC-04 shapes.** `AppShellStructuralTests` and `MapPanelsPickersHandOffStructuralTests` hard-coded the two-clause `handOff`, the old `unitExpedition` shape and a single `@State`. 04.8's ACs had to change all three (11 failures in 7 tests).
   - The implementer reverted cleanly.
   - Ruling `arbiter-04-08-structural-suite-ownership.md` chose option (a): the task that changes the App files updates those suites in the same commit, guard by guard, keeping each intent and negative control. It also fixed a pre-existing 04.10 defect: its 4+-word copy rule would have failed on three EPIC 03 lines, so it was scoped to `Doors`.
   - Spec edits `ceb9289`. The orchestrator's dispatch note ("the 03.10–03.12 suites must stay green") was wrong and was corrected.
2. **04.9 BLOCK: 04.8's own tester suite pinned 04.8's shapes.** The orchestrator predicted this before 04.9 returned and ran an addendum ruling in parallel (`arbiter-04-09-doors-structural-suite-addendum.md`).
   - The addendum found that the suite's Doors-wide scans read a hard-coded six-file list. New files would have silently escaped the I10, glossary, `@State` and copy checks.
   - The guards became list-driven, and the inventory is now exact against the directory. Spec edits `04722c9`.
   - The addendum's own "live" baseline had been taken on a transient tree that still held 04.9's uncommitted edits. The orchestrator re-measured on the clean tree.
3. **Prevention, adopted from the 04.9 tester onward.** Tester prompts now require shape pins as named lists with list-relative negative controls, and directory scans that are exhaustive against the directory listing.
4. **An orchestrator note was corrected.** The "inline `DoorFacade` call inside the closure" requirement contradicted the specs: 04.8 T3/T6 name the action methods, and 04.10 counts per function body. 04.8 was correct.
5. **Whole-file rewrites by task-writers.** Task-writers applying ruling edits had no Edit tool and rewrote whole files. Each result was verified by diff, with every removed line mapped to cited old text, and by the ruling's own greps before and after.
6. **Implementer misreports caught.** The 04.4-style incomplete-gate pattern did not recur. The 04.10 implementer reported the pytest count (190) as the Core count; the tester's full run gives 787. The 04.10 helper-routed negative control that the dispatch asked for was missing and was added by the tester.
7. **Acceptance-record template inaccuracy.** The item-6 instrument line claimed that a gate 3 static test asserts a *resolvable* `source_url`. `Core` checks presence and https well-formedness only, and live resolution is the gate 4 pytest. The wrap corrected the line and recorded both facts. The live fetch passed.
- No Q5 was raised in 04b.

## 7. Notes

- **`doorCopyRule` scope.** It matches `Text("…")` / `Button("…")` literal forms and does not special-case `//` comments. No real comment has that shape, and with comments stripped `Doors` has 0 literals of 4+ words. The 04.10 tester recorded this as weak but not a defect.
- **Standing gaps, routed to the owner report:**
  - There is no App unit-test or UI-test target (optional Q5), so the runtime UI behaviour has no automated test.
  - The full-glossary gate is not built.
  - `astral-sh/setup-uv@v6` still targets Node 20 (a CI warning).

## 8. R-6 judgment

The date-literal grep finds 173 ISO-date literals in 30 Swift test files, the same as at the 04a wrap: the 04b test
suites are structural source scans and add none. Each literal is an injected `today: CalendarDay`, a `StudentState`
fixture field, or a probe-log `day` value. `Core` never reads a clock. The App reads it once, in `resolveToday`, and
injects it. This is the same judgment as EPIC 01, 02, 03a, 03b and 04a.

## 9. (R-7) `fix:`-commit table and cascade check

04b has **no** `fix:` commits. Both BLOCKs were resolved before any commit, by spec edits (`ceb9289`, `04722c9`), and
both re-dispatches landed as `feat`. The orchestrator commits are `chore:`, and the tester commits are `test:`.

**EPIC 04 totals:** 04a had 1 rework (`8f066b7`) and 04b has 0, so **1 rework, 0 output.** The cascade check needs
more than 3 rework in each of two consecutive EPICs. EPIC 03 had 3 and EPIC 04 has 1, so it does not fire.

## 10. Physical-device verification

Agents verified on the iOS simulator only, through builds, `sim-smoke.sh` and tests. **No agent claims
physical-device verification** (D29). The owner's device check is the delivery verification. The *device — owner*
cells of `docs/epics/demo-acceptance-record.md` (§8 items 2 and 3b) and the §7 Tester A/B lines are blank for the
owner. The record decides whether the map form proceeds to M3 or is revised; this is a Q5 checkpoint by design.
