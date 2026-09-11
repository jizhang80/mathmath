# EPIC 04a acceptance — Door core

**Branch:** `epic-04a-door-core`, cut from `main` at `1ca3752`, the merge of PR #10 (EPIC 03b). `main`'s CI run
34559464840 on that merge was green, which closed EPIC 03. **Brief:**
`docs/epics/epic-04-app-expedition-diagnosis-acceptance.md` · **Plan:** `docs/plans/epic-04-plan.md` · **Date:**
2026-09-11

EPIC 04 exceeded the 8-task cap, so the planner split it at the brief's Door-façade seam without changing scope.
**04a** is the `Core` half: tasks 04.1, 04.1b, 04.2–04.5, and this wrap (04.6). **04b** (04.7–04.13, the App half)
follows on `epic-04b-door-app`, and calls only the `DoorFacade` entry points this half ships.

## 1. Gate results

| Gate | Result | Instrument | Excludes |
|---|---|---|---|
| (a) typecheck | PASS (0 errors) | `pyright` strict over `pipeline/` | Swift type checking, which (d) covers |
| (b) lint | PASS | `swift-format lint --strict`; `ruff check pipeline` | — |
| (c) format | PASS | `ruff format --check pipeline` | — |
| (d) tests | PASS | `scripts/gate.sh` green at the final product tree `07ef532` (run by the 04.5 T6 tester): `Core-Package` 687 tests in 68 suites; `Rendering` green; App build green; `sim-smoke` scenarios 1 and 2 PASS, embedded snapshot byte-identical; `pytest` 190 passed. The commit after it is docs only. | `scripts/gate.sh`: `core-cli` release build; `Core-Package` and `Rendering` tests on the simulator; App build; `scripts/sim-smoke.sh`; `pytest` | physical device (D29) |
| (e1) commit messages | PASS | the `conventional-pre-commit` hook ran on every commit | — |
| (e2) CI | must pass before merge | the ruleset on `main` blocks the merge until both checks are green | — |
| (f) I14 | PASS | `grep -rh "^import " Packages/Core/Sources/Core` gives 41 × `import Foundation` (the 5 new `Door/*` files included) | transitive imports |
| (f) hygiene | PASS, empty = PASS | Under `Packages/Core/Sources/Core`, each of these returns 0: `print(`, `TODO\|FIXME\|XXX`, `try!\|as!`, `Date()`, `URLSession\|URLRequest`, force-unwrap. Under `App/Sources`, the same list returns 0. | the invariant traps (§7) |
| (f) glossary | PASS **for the scanned terms** | The case-sensitive `Session` scan returns 0. `attempts?` returns 0 in `Core` and `App` sources, and `CoreGlossaryAttemptGuardTests` is green. The two "session" word hits are known prose: `MapLaunch.swift:4` explains the ban, and `AppShell.swift:4–5` quotes arbiter-03 Q-F. The generic hints pass the AC9 I2 token check (§6). | the full 57-term glossary. The sense-aware gate is a standing follow-up (03b report §7). |
| (f) I1 / I2 | PASS | Door A and Door B check answers in code only (`ItemChecker` via `ExpeditionRun` and `DiagnosisRun`). No model call and no adapter pattern: 04.3, 04.4 and 04.5 each have an I2 source guard with a negative control. The none-of-these hint is served only when `classify` abstains, and names or describes no sibling misconception (AC9). | — |
| (f) I3 | PASS | The answer card is its own phase in both doors (04.2 no-leak Mirror scan; 04.3 and 04.4 phase gates, with negative controls). `continueAfter*` never writes (04.5). | runtime screen order (04b, Q-C) |
| (f) I4 | PASS | Backtrack is capped at the Demo budget of 1; the 04.3 and 04.4 tests assert it on real and synthetic graphs | — |
| (f) I5 | PASS | Mirror scans over the Door screen content and `DoorRunState` / `MapState` / `DoorBRunState` find no identifier-shaped field (04.3, 04.4, 04.5 tests) | — |
| (f) I6 / I15 | PASS | The new hint strings are the project's own prose, with no `verbatim` key. `data/demo` changed only in `hint_tree["none-of-these"]`. | — |
| (f) I8 | PASS | `core-cli validate data/demo` returns `passed: true` (10 checks); the embedded snapshot's 7 files are byte-identical | — |
| (f) R-6 | PASS **by recorded judgment** (§9) | the date-literal grep over `Packages/Core/Tests` finds 173 ISO-date literals in 30 Swift test files (146/23 at the 03b wrap; +27 in the 7 new 04a test files) | — |
| (f) I11 | PASS | `no-time-estimates` hook green on every commit | — |
| (g) cross-EPIC audit | not due | The audit runs every 3 EPICs; 01–03 ran at the EPIC 03 wrap (`docs/audits/cross-epic-01-03.md`), and the next covers 04–06 | — |
| (h) contract bumps | PASS | §4 | — |
| (i) DEFERRED | PASS | D-17 and D-18 added (04.1); D-15 corrected (`5e2b833`); D-13 re-measured and still unstaged | — |
| (j) C1 seam | PASS | §5 | — |
| (k) C4 artifacts | PASS | §3 | — |

## 2. Tasks completed

| Task | Commits | Verification |
|---|---|---|
| 04.1 contract-interaction-card-timing-summary-tint | `641478d` | Five files, all in scope:<br>- interaction-contract v0.9.2 → **v0.9.3** (answer-card timing, summary content, in-run log entry);<br>- domain-glossary v1.0.0 → **v1.0.1** (Remediation clarification, and the two none-of-these tokens);<br>- `diagnosis.md` and `learning-objects.md`;<br>- DEFERRED **D-17** and **D-18**.<br>The DEFERRED ids moved from the spec's D-15/D-16, because EPIC 03 had already used those. Checked by the orchestrator's mechanical check and `test_contracts.py`. |
| 04.1b data-demo-none-of-these-hints | `1474a74`, `e5cc3b5`, **`8f066b7` (fix, single retry)** | Adds three generic tiers to all 20 `data/demo` nodes, re-embedded byte-identical, with the Rendering count table at 123/203.<br>The first-pass strings described sibling misconceptions (§6), so the task was retried under the arbiter's replacement set with the **AC9** I2 token check: 0 violations on all 20 nodes, and exact results for the committed controls NC1–NC4 and NC3b.<br>The re-test confirmed the implementation matches the ruling, and that NC3b depends on the allowlist (a throwaway mutation turned red). |
| 04.2 core-door-item-card-keypad | `05ce416`, `31411b5` | Item view with no answer field (Mirror scan with a planted-leak control); answer card built from `ItemResult`, showing the answer on a hit and on a miss (I3); keypad covers every numeric answer (control: remove `/`). |
| 04.3 core-door-a-diagnosis-flow | `47f61ff`, `86e20a6` | Door A façade (`DoorADiagnosisFlow`, six entry points); `CoreError.loHintNotFound` appended (21 cases, registry parity unchanged).<br>39 tests cover: both triggers; resolver rows 1–3; remediation order; the further-level offer; terminal lines from `CoreErrorText` only; `LO_HINT_NOT_FOUND` never shown to a student. |
| 04.4 core-door-b-expedition-flow | `0e52d48`, `cf1b8ac` | Door B façade (`DoorBExpeditionFlow`) and summary copy.<br>Covers the I3 phase gate and the D27 retry. The hand-off carries the exact submitted bytes and is cross-checked against 04.3. Also covers the Q5 line, I4, resume, the natural end (Q-G), a write-ahead that is pure and equal to `end`, and a summary with no tint or fraction. |
| 04.5 core-door-entries-persistence-seam | `24e10bd`, `bf2108e`, `07ef532` | `DoorRunState` plus 12 `DoorFacade` entry points, appended to `Platform/MapLaunch.swift`; the 46 pre-existing public declarations are unchanged. Covers:<br>- write-after-every-state-changing-call, with write-failure banners on both doors;<br>- the Include queue;<br>- `backToMap` abandon;<br>- the **C1 seam** (§5).<br>`DoorRunState` is not `Equatable` (§6): T6 compares it field by field, with a negative control. |

Before each dispatch the orchestrator checked every spec against the code that had actually shipped. It
checked the file-scope targets, each quoted `Core` API (03.3 `CoreErrorText`, 03.7 `MapState` / `MapFacade`,
and 04.2 / 04.3 / 04.4 as they landed), and the renamed identifiers. The only drift found was in §6.

## 3. (k) C4 artifact → gate

| Artifact | Gate | Excludes |
|---|---|---|
| `Door/DoorItemContent.swift` (04.2) | (d) `Core-Package` tests; `DoorItemContentComprehensiveTests` | device runtime (D29) |
| `Door/DiagnosisContent.swift`, `Door/DiagnosisFlow.swift`, `CoreError.loHintNotFound` (04.3) | (d) `DiagnosisFlowComprehensiveTests`; `ErrorRegistryTests` | the `preconditionFailure` traps (§7) |
| `Door/ExpeditionFlow.swift`, `Door/ExpeditionContent.swift` (04.4) | (d) `ExpeditionFlowComprehensiveTests` | the traps (§7) |
| `Platform/MapLaunch.swift` `DoorRunState` / `DoorFacade` (04.5) | (d) `DoorEntriesTests`, `DoorFacadeSeamTests` (C1), `DoorFacadeConformanceTests` | the traps (§7); the render side of the seam (04b, Q-C) |
| `data/demo/nodes.json` none-of-these hints, and the embedded `App/Sources/DemoSnapshot/nodes.json` (04.1b) | `core-cli validate`; `RenderCheck`; AC9 `i2Violations` with committed controls; the 03.4 byte-identity seam test; `sim-smoke` `cmp` against the built `.app` | the semantic residue of R3 that tokens cannot see, discharged by the arbiter's pre-checked strings |
| interaction-contract v0.9.3, domain-glossary v1.0.1, `diagnosis.md`, `learning-objects.md`, DEFERRED D-17 / D-18 (04.1) | orchestrator mechanical check; `test_contracts.py`; `no-time-estimates` hook | — |
| `docs/epics/epic-01-rendering-spike-outcome.md` 123/203, plus the Rendering test literal and comment (04.1b) | (d) `Rendering` tests: `outcomeRecordCountsMatchFreshScan` and the staleness guard | — |

## 4. Contracts touched

| Contract | Change | Task |
|---|---|---|
| `interaction-contract.md` | v0.9.2 → **v0.9.3**: answer-card timing, summary content, in-run log entry | 04.1 |
| `domain-glossary.md` | v1.0.0 → **v1.0.1**: Remediation for nodes without an Explanation; catalogue id `none-of-these` vs outcome token `none_of_these` | 04.1 |
| `error-codes.json` | unchanged. `LO_HINT_NOT_FOUND` was already registered as internal; 04.3 added only the `CoreError` case. | — |

## 5. (j) C1 seam

| Seam | Test | Both sides real? |
|---|---|---|
| Door façade ↔ `Core` state and persistence: a full expedition (brief §4 item 1) | `DoorFacadeSeamTests` AC13 (04.5). Every step is one `DoorFacade` call, including one first miss and a retry. It asserts:<br>- the event order `expedition.started` → `item_answered`* → `completed`;<br>- after every state-changing call, the decoded file equals the threaded state plus exactly one trailing `abandoned: true` entry equal to `end(abandoned: true)`;<br>- after the natural end, exactly one `abandoned: false` entry;<br>- the summary lists equal the run's;<br>- a re-derived `MapViewModel` shows the fog lifted. | yes: real `data/demo` and real `StudentStateStore` file I/O in a temp directory; nothing stubbed |
| Door façade ↔ `DiagnosisRun`, both triggers (brief §4 item 2) | `DoorFacadeSeamTests` AC14 (a) capped then resumed, (b) declined → unconfirmed, (c) refuted. The tester added per-call write-ahead checks inside the Door A steps. | yes |
| App ↔ `Core` state transitions (brief item 8), **Core half** | A source scan proves the seam tests reach `Core` only through `DoorFacade.*`, the entry points the 04b buttons will call; it has a negative control. | Core side is real. The render side belongs to 04b: the 04.10 button scan, and the 04.13 record of the verbatim arbiter-04 § Q-C cannot-claim list. |

## 6. Rulings and spec corrections during 04a

1. **The 04.1b generic hints described sibling misconceptions.** After the implementer committed, the
   orchestrator spot-checked the 20 nodes side by side. About 14 nodes had a tier pointing at the sibling
   error type's locus. Examples: "checking the sign at each step" next to `sign-error`, and "every occurrence of
   x was replaced" next to `function-evaluation-error`'s own hint.
   - This breaks `arbiter-04-hint-fallback-reconciliation.md:83` ("No string names or describes a sibling …
     misconception (I2)"). It also breaks I2, because the hint is served only when `classify` abstains.
   - The tester's check compared only names and literal text, so it passed the defect.
   - Q4 ruling `arbiter-04-01b-generic-hint-i2.md` defines the rules R1–R4 and a **mechanical token check**
     (AC9: tokenizer, 28-word stoplist, 4-letter stem, `name`-derived allowlist, S1 substring rule, S2
     qualifier list). All 20 nodes were rewritten.
   - Before dispatch, the orchestrator re-implemented the check in Python: 0 violations, and all five
     controls exact. The spec was re-anchored by E1–E7 (`62ab4c4`).
   - The fix landed as a single retry (`8f066b7`).
   - The re-test found one latent literal divergence and accepted it. A token that is both an S2 and an S1 hit
     is reported once, not twice. Pass or fail is unaffected, and no fixture contains such a token.
2. **`DoorRunState` is not `Equatable`.** The 04.5 literal does not compile: `MapState` holds `ContentBundle`,
   which EPIC 03 left non-`Equatable` on purpose (03.7 §4.1; 03.4 T6).
   - The orchestrator found that 04b declared four App types as `Equatable` while holding
     `runState: DoorRunState`, which would not compile.
   - Q4 ruling `arbiter-04-doorrunstate-equatable.md` chose **option B: no product change**. No 04b consumer
     compares those values, and a hand-written `==` over `Core` state would put equality in the render layer
     (I14).
   - E1–E16 re-anchored 04.5, 04.8 and 04.9 (`c9989a9`), verified by the ruling's own greps before and after.
     04.5's T6 now compares field by field (`07ef532`).
3. **Placeholder hash length.** The EPIC 02 acceptance claimed 66 characters, and D-15 and the 03a acceptance
   repeated it. At the start of 04a the orchestrator re-measured before dispatching 04.1b: all six placeholders
   are **64** zeros.
   - The likely source is a 62-zero literal mis-quoted in the 04.1b spec. Under a string comparison, that
     literal would have triggered a forbidden restamp.
   - Fixed in `5e2b833`: D-15 corrected, errata added to the 02 and 03a reports, and the literal corrected.
   - 04.1b was dispatched with a predicate check (6 × 64 `0`s).
4. **03.13b rename carried into the EPIC 04 packet.** The packet uses `ItemMiss` / `misses` /
   `pendingHandoffMisses`. The EPIC 04 plan's grandfather clause was withdrawn (`c306f18`).

## 7. Notes

- **Invariant traps (C3 exclusion).** 04a adds 10 `preconditionFailure` sites under `Sources/Core`, on top of
  the 4 that already existed (`ExpeditionRun`, `CalendarDay`, `DiagnosisEvent`).
  - The new sites are:
    - `DoorFacade.answer` / `resumeAfterDiagnosis` with no active expedition (`MapLaunch.swift:384, 414`);
    - `DoorBExpeditionFlow` (3), `DoorBContent` (1) and `DoorADiagnosisFlow` (2);
    - `DoorADiagnosisContentBuilder.resolveHint` (2), which the 04.3 tester showed unreachable on a valid
      bundle.
  - Each one guards a caller contract or a validated-bundle invariant; this is the project's existing idiom.
  - A trap cannot be exercised in-process. For 04b, the App calls `answer` / `resumeAfterDiagnosis` only while
    a Door B run is active.
- **Process incidents.**
  - **Untracked packet file overwritten.** A task-writer applying the 03.13b rename list overwrote the
    untracked `tasks/context/epic-04-task-09-context.md` with an 11-byte placeholder. It stopped and reported
    the damage instead of inventing content.
    - The orchestrator restored the file verbatim from the task-context-compiler's own `Write` call in its
      session transcript. Nothing else had written to the file between those two points.
    - Lesson candidate (owner-triggered Phase 8): untracked packet files have no git safety net, so commit a
      packet as soon as it is final.
  - **Rename list undercounted.** The arbiter's §8 list for 03.13b undercounted the 04-04 and 04-05 references
    (17 listed against 23 actual; 5 against 6). All were renamed, and the stale identifiers in the brief and
    plan were fixed too.
  - **Hash-length claim propagated.** A false measurement travelled through three merged documents (item 3
    above). C6's "consuming work re-measures" is what caught it.
  - **Name-keyed diff false positive.** A name-keyed diff of the 04.4 and 04.5 specs reported three
    mismatches. They were 04.5's own `DoorFacade` wrappers, which share names with 04.4's functions; the
    orchestrator checked by type and withdrew them.
  - **Incomplete gate by one implementer.** The 04.4 implementer ran the Core tests and the App build but not
    the full `gate.sh`. The tester ran the full gate: Rendering, sim-smoke and pytest were all green.
- No Q5 was raised in 04a.

## 8. Deferrals

- **D-17**: region tint deltas on the expedition summary. **D-18**: hint tiers 2–3 on Door A screens. Both are
  from 04.1, and both are revisited at Demo observations.
- **D-15 corrected**: the placeholder hashes are 64 hex characters, not 66.
- **D-13**: re-measured. It is still untracked and unstaged.

## 9. R-6 judgment

The grep finds 173 ISO-date literals in 30 Swift test files. The 27 new ones are in the seven 04a test files. Each literal is:
- an injected `today: CalendarDay` (`CalendarDay(iso: "2026-09-10")`),
- a `StudentState` fixture field (`installDay`, `lastProbe`, `nextDue`),
- or a probe-log `day` value.

`Core` never reads a clock (`Date()` under `Packages/Core/Sources/Core` = 0). This is the same judgment as EPIC 01, 02, 03a and 03b.

## 10. (R-7) `fix:`-commit table and cascade check

| Commit | Cause | Corrects task | Risk tier | Rework / output |
|---|---|---|---|---|
| `8f066b7` `fix(demo-data)`: replace the none-of-these hints with non-diagnosing nudges; add the AC9 I2 token check | spec-gap: the 04.1b §4 table described sibling misconceptions, which the governing ruling forbids; its I2 claim was "by construction" | 04.1b | seam | rework |

The orchestrator commits `5e2b833`, `62ab4c4` and `c9989a9` are `docs:` / `chore:` spec and ledger
corrections. The T6 top-up (`07ef532`) is a `test:` commit, and no product code changed. None of these count.

EPIC 04a totals: **1 rework, 0 output.** The cascade check fires only when rework exceeds 3 in each of two
consecutive EPICs. EPIC 03 had 3, which does not exceed 3, so the EPIC 03–04 pair cannot fire.

## 11. Physical-device verification

Agents verified on the iOS simulator only: builds, `sim-smoke.sh`, and tests. **No agent claims
physical-device verification** (D29). 04a ships no new App surface, so the owner's device check of the Door
screens belongs to the 04b wrap.
