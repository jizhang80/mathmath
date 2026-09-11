# Epic 04 · Task 05: Core Door entries — persistence seam over EPIC 03's map façade

---
epic: 04
task: 05
slug: core-door-entries-persistence-seam
kind: feat
risk: seam
depends_on: [04.4]
model: opus
---

> **Branch note.** Written against the current tree (clean `main`; no `epic-04a-door-core` branch yet). The
> implementer runs this task on `epic-04a-door-core`, created after EPIC 03 merges into `main`
> (`docs/plans/epic-04-plan.md`: "EPIC 04 starts only after EPIC 03 is merged"), and after tasks 04.1, 04.1b,
> 04.2, 04.3 and 04.4 have landed on that branch (`depends_on: [04.4]`, which transitively requires 04.1–04.3).
> `Packages/Core/Sources/Core/Platform/MapLaunch.swift` (task 03.7), `Packages/Core/Sources/Core/Door/
> ExpeditionFlow.swift` / `ExpeditionContent.swift` (task 04.4) and `Packages/Core/Sources/Core/Door/
> DiagnosisFlow.swift` / `DiagnosisContent.swift` (task 04.3) are assumed landed and byte-verified against their
> own already-written specs (`tasks/epic-03-task-07-map-actions-facade-launch.md`,
> `tasks/epic-04-task-03-core-door-a-diagnosis-flow.md`, `tasks/epic-04-task-04-core-door-b-expedition-flow.md`
> — the last is marked **PASS** in the dispatch instructions). If any of these files is absent, or its public
> surface differs from the signatures quoted in §3 below, that is an EPIC-order precondition failing to
> hold — BLOCK and report it; do not stub, re-derive or reimplement any of 03.7's, 04.3's or 04.4's logic here.
> This task is **the only EPIC 04 task that modifies 03.7's façade file**,
> `Packages/Core/Sources/Core/Platform/MapLaunch.swift` (`docs/plans/epic-04-plan.md`: "the Door entry points on
> EPIC 03's Core map-actions/session type (04.5)"; brief §8 file-ownership notes: "The 'Start expedition' entry
> touches EPIC 03's façade file (03.7). Exactly one 04a task writes it.").

## §1 Goal & acceptance criteria

Goal: `Core` gains a `DoorFacade` enum, added to `Packages/Core/Sources/Core/Platform/MapLaunch.swift`, that is
the **only** surface 04b's screens are allowed to call for Door B and Door A actions (`docs/plans/epic-04-plan.md`:
"04b calls only those entry points; 04.10's extended `App/Sources` scan enforces it"). `DoorFacade` wraps 04.4's
`DoorBExpeditionFlow` and 04.3's `DoorADiagnosisFlow` step APIs with (a) the Start-expedition/Unit-expedition/
Check-me-here entry points that open a run or a diagnosis event from EPIC 03's map façade, (b) pass-through
entry points for `answer`/`continue`/`decideProbe`/`answerProbeItem`/`continueAfterProbeAnswer`/
`decideFurtherLevel`/`resumeAfterDiagnosis`, and (c) `Start another` / `Back to the map`, and sequences a
whole-document `StudentStateStore.write` after **every** state-changing call among these (never after a
`continue` call, which changes no `StudentState` — arbiter-04 § Q-A). During an expedition run, that write
persists the Q-G in-progress ("write-ahead") value computed by 04.4's `DoorBWriteAhead.provisionalAbandonedState`;
outside a run (`Check me here`, and the run's own natural end / `Back to the map`) it persists the plain
threaded `StudentState` or the run's final log entry, respectively. A write failure never discards the value the
call already produced: it surfaces as a `writeFailureCode` field carrying the registered code string
(`"EXP_STATE_WRITE_FAILED"` or `"DIAG_STATE_WRITE_FAILED"`, both already-registered `CoreError` cases — no new
case, no registry change), alongside the advance/screen/summary value the caller still receives. `Expedition
.compose` throwing `CoreError.expNoFringe` starts no run and writes nothing; the caller resolves its registered
text via 03.3's `CoreErrorText.text(for: .expNoFringe)`. This task owns the C1 real-composition test exercising
the same entry points the Door buttons will call in 04b, over real `data/demo` and a temp-directory store, with
no stub on either side.

**C3 exclusion (Core half only).** Per `tasks/arbitration/arbiter-04-predispatch.md` § Q-C, this task's tests
evidence "logic, composition and static wiring only". They cannot and do not claim: (1) that any tap on a
simulator actually fires its action; (2) that a Door screen is laid out so its controls are visible and
reachable; (3) that no runtime trap occurs along the Door screens after launch; (4) that the sequence of screens
a student sees at runtime matches the façade's screen values, rather than only in `CoreTests`. This task ships
no `App/Sources` code, so all four points are, trivially and entirely, out of its reach; the literal tap-through
is the owner's device verification (D29). 04b's specs (04.7–04.13) restate this exclusion for their own scope.

Invariants in play:

- **I1** — not applicable: this task decides no correctness itself. Every checked answer already came from
  `ItemChecker` inside `ExpeditionRun.answer` / `DiagnosisRun.answerProbeItem` (04.4's / 04.3's concern); this
  task only sequences persistence around their already-computed results.
- **I2** — Tier 0 only: no adapter parameter, no model import anywhere in the `DoorFacade` additions to
  `MapLaunch.swift`, verified by a grep with a planted-violation negative control (mirrors 04.3 AC8 / 04.4
  AC11's shape).
- **I3** — inherited, never re-opened: `DoorFacade.answer` returns 04.4's `DoorBAnswerAdvance` unchanged (its
  `pendingHandoffMisses`/`pendingEnd` fields already carry no `public` modifier — 04.4 AC2); `DoorFacade
  .answerProbeItem` returns 04.3's `DoorAProbeAnswerAdvance` unchanged (04.3 AC3). This task adds no field or
  wrapper that would re-expose a hidden screen; a source-scan negative control proves this (§5 T5).
- **I4** — not re-derived: the Demo `levelBudget` of 1 and the at-most-one-diagnosis-per-run property are
  04.3's/04.4's own guarantees (04.3 AC4, 04.4 AC6); this task calls `DoorADiagnosisFlow.open` at most once per
  run only because it calls it **only** inside 04.4's own `continueAfterAnswer` (D27 hand-off, already inside
  04.4's file) or inside this task's own `checkHere` (a distinct, non-run-nested trigger) — never both for the
  same event.
- **I5** — `DoorRunState`, `writeFailureCode` and every other new value here carry only node/item ids, enums,
  `StudentState` (already I5-clean), registry code strings and plain strings resolved from the bundle; no
  identifier of any kind is added.
- **I14** — the `DoorFacade` additions import Foundation only, perform I/O exclusively through
  `StudentStateStore.write` (never a second write path — arbiter-03 § Q-F: "the persistence store" is 03.5's
  file, called here, never reimplemented), and compute no screen content of their own beyond what 04.3/04.4
  already produced. The App's later allow-list (04.10) is widened by exactly this task's public entry points;
  `ExpeditionRun`, `DiagnosisRun`, `Expedition`, `DoorBExpeditionFlow` and `DoorADiagnosisFlow` stay off that
  list — 04b calls only `DoorFacade`.

Acceptance criteria (each independently verifiable; brief item numbers noted where they map to
`docs/epics/epic-04-app-expedition-diagnosis-acceptance.md` § 4, after Amendments 04.00.1/04.00.2):

- AC1 (Start expedition consumes the queue, brief item 5): `DoorFacade.startExpedition(mapState:, today:)` on a
  `mapState` whose `queuedNodeId` names a node on the fringe calls `Expedition.compose(state:, bundle:, trail:,
  marker:, today:, queuedNodeId: mapState.queuedNodeId, unitExpeditionUnitId: nil)` then
  `DoorBExpeditionFlow.start(compose:)`; the returned `runState.map.queuedNodeId == nil` (emptied); the queued
  node is the run's first (`.newLearning`) slot (delegated to `Expedition.compose`'s own placement rule, not
  re-derived — matches 03.7 AC12's own assertion of the same rule). On success, `StudentStateStore.write` is
  called with `DoorBWriteAhead.provisionalAbandonedState(runState: advance.runState, state: mapState.state,
  today:)` (the Q-G run-start write-ahead); `writeFailureCode == nil`; `events` contains `.platformStateWritten`.
- AC2 (Unit expedition scope, brief item 5): `DoorFacade.startUnitExpedition(unitId:, mapState:, today:)` calls
  `MapFacade.unitExpedition(unitId:, mapState:, today:)` (03.7's already-landed function, delegated verbatim —
  its own fringe-restricted-to-the-unit-plus-blocked-nodes rule is not re-derived here) then
  `DoorBExpeditionFlow.start(compose:)`; `mapState.queuedNodeId` is **unchanged** in the returned `runState.map`
  (Unit expedition never touches the Include queue — `MapFacade.unitExpedition` itself always passes
  `queuedNodeId: nil` to `compose`, per 03.7 §4.5, so nothing queued is consumed or cleared); the write-ahead
  persistence matches AC1's shape.
- AC3 (`EXP_NO_FRINGE`, brief item 5): on a `mapState`/unit combination whose fringe and due set are both empty,
  both `startExpedition` and `startUnitExpedition` throw `CoreError.expNoFringe`; no `StudentStateStore.write`
  call occurs (assert via an unwritable `stateURL` directory that would otherwise force a thrown write error —
  none is thrown, because none is attempted); the caller's `mapState` value is returned unchanged by Swift's own
  throw semantics (no new value constructed); `CoreErrorText.text(for: .expNoFringe) ==
  "You've cleared everything up to here. Move your class marker forward, or explore the map."` (registered text,
  resolved by the caller, not duplicated here).
- AC4 (answer / continue sequencing, Q-G write-ahead, brief item 1): `DoorFacade.answer(_:submitted:today:)`
  calls `DoorBExpeditionFlow.answer` then persists **either** (a) — when the internal `pendingEnd` is non-nil —
  `pendingEnd!.state` directly (the run's final, `abandoned: false` entry, computed and written in the **same**
  call that produces the run's last result, never deferred to `continueAfterAnswer` — arbiter-04 § Q-G: "In the
  same façade call that produces the run's last result"), **or** (b) — otherwise —
  `DoorBWriteAhead.provisionalAbandonedState(runState: advance.runState, state: advance.state, today:)` (the
  in-run write-ahead). `DoorFacade.continueAfterAnswer` calls `DoorBExpeditionFlow.continueAfterAnswer` and
  performs **no** `StudentStateStore.write` call (arbiter-04 § Q-A: "continue... triggers no write") — asserted
  by a file-byte-identity check across the `continueAfterAnswer` call, over real `data/demo`.
- AC5 (D27 hand-off, no extra write on the hand-off continue): when `continueAfterAnswer` reveals
  `.diagnosis(...)` (the D27 hand-off, computed inside 04.4's own `continueAfterAnswer` via
  `DoorADiagnosisFlow.open` + `.start`), the state file at `stateURL` is byte-identical before and after that
  specific `continueAfterAnswer` call (hypothesis formation mutates no `StudentState`, per 04.4 §3's own citation
  of this fact — the general "continue writes nothing" rule of AC4 already covers this branch with no special
  case in this task's code).
- AC6 (Door A pass-throughs, brief items 2 and 8): `DoorFacade.decideProbe`, `.answerProbeItem` and
  `.decideFurtherLevel` each call the matching `DoorADiagnosisFlow` function then persist the resulting
  `StudentState` — write-ahead-wrapped (`DoorBWriteAhead.provisionalAbandonedState`) when `runState.expedition
  != nil` (an in-run D27 hand-off leg), or written plainly (`StudentStateStore.write(advance.state, to:)`, no
  wrapping — Q-G: "`map_check_here` outside a run: no in-run entry exists") when `runState.expedition == nil`
  (a standalone `Check me here` event). A write failure surfaces `writeFailureCode ==
  CoreError.diagStateWriteFailed.rawValue` while the full `advance`/`answerCard` value is still returned.
  `DoorFacade.continueAfterProbeAnswer` calls `DoorADiagnosisFlow.continueAfterProbeAnswer` and performs no
  write (mirrors AC4(b); 04.3 AC3: "changes no `StudentState` and emits no new `CoreEvent`").
- AC7 (resume, brief item 2a): `DoorFacade.resumeAfterDiagnosis(_:outcome:today:)` requires `runState.expedition
  != nil` (a programmer-error `preconditionFailure` otherwise — `map_check_here` events never call this, §6);
  it calls `DoorBExpeditionFlow.resumeAfterDiagnosis(expedition, outcome:, bundle:, today:)`; when the resumed
  run's `screen` is `.item(...)`, the write-ahead value is persisted (as AC4(b)); when it is `.summary(...)`
  (the resumed run reached an empty queue), the already-final `advance.state` (computed inside
  `DoorBExpeditionFlow.resumeAfterDiagnosis` with `abandoned: false`) is persisted directly, not re-wrapped.
- AC8 (standalone `Check me here`, brief items 2b and 8): `DoorFacade.checkHere(nodeId:, mapState:, today:)`
  calls `MapFacade.checkHere(nodeId:, mapState:)` (03.7, unchanged, pure construction) then
  `DoorADiagnosisFlow.start(event:, misses: [], shownItemIdsInRun: [], state: mapState.state, bundle:
  mapState.bundle)`; the returned `runState.expedition == nil` throughout this event's whole life (it is never
  nested inside an expedition run); every subsequent state-changing call on this `runState` (through AC6's
  `decideProbe`/`answerProbeItem`/`decideFurtherLevel`) writes plainly, never write-ahead-wrapped; no
  `DoorFacade.resumeAfterDiagnosis` call is made or needed for this event — the terminal screen's own
  `outcome.state` is already the last state written (diagnosis W5 step 2: "hand control back to... the map node
  panel"). `today` is threaded only into `DoorFacade`'s own persistence helper (`persistDoorA`, §4.2) — 03.7's
  `MapFacade.checkHere` itself takes no `today` parameter and is unaffected.
- AC9 (Start another, brief item 5): `DoorFacade.startAnother(mapState:, today:)` composes a fresh run from
  `mapState` (the post-run state, already reflecting the completed run's cleared/blocked nodes) by delegating to
  `startExpedition(mapState:, today:)` unchanged — identical queue-consuming, write-ahead-persisting behaviour
  (§6). Over real `data/demo`, a run that clears one node followed by `startAnother` produces a second run whose
  fringe no longer offers the just-cleared node.
- AC10 (Back to the map, mid-run abandon, brief item 5): `DoorFacade.backToMap(_:today:)` computes `end =
  ExpeditionRun.end(run: runState.expedition!.run, state: runState.map.state, today:, abandoned: true)` and
  persists `end.state` directly (the final abandoned entry, replacing whatever write-ahead entry preceded it —
  never a second entry); the returned `mapState` carries no active `DoorRunState.expedition` (the caller's next
  action is a plain map action, e.g. `MapFacade.setMarker`, not another Door B call). A **simulated kill**
  (dropping the in-memory `runState` after any state-changing call and independently re-reading `stateURL`)
  yields exactly one `expedition_log` entry with `abandoned == true` and that call's own item counts — this is
  the same file every intermediate write-ahead call already produced; `backToMap` merely stops the sequence,
  it does not need to run for the guarantee to hold (negative control in §5 T5 proves a session that skips the
  write-ahead fails this exact case).
- AC11 (write-failure banner, brief item 5): over an unwritable `stateURL` directory (the containing directory
  made read-only before the call, mirroring 03.7 AC13's fixture), (a) `DoorFacade.answer` returns a fully
  populated `advance` (non-`nil` `answerCard`) with `writeFailureCode == CoreError.expStateWriteFailed.rawValue
  == "EXP_STATE_WRITE_FAILED"`; (b) `DoorFacade.answerProbeItem` (or `.checkHere`) returns a fully populated
  value with `writeFailureCode == CoreError.diagStateWriteFailed.rawValue == "DIAG_STATE_WRITE_FAILED"`. Neither
  case throws; neither case discards the computed value (expedition W5 step 2: "`EXP_STATE_WRITE_FAILED` shows a
  banner, the summary still shows"; diagnosis W5: "A failed write surfaces `DIAG_STATE_WRITE_FAILED` as a
  banner, and the event still returns" — epic brief §2).
- AC12 (no new registry surface): `Packages/Core/Sources/Core/CoreError.swift` and
  `Packages/Core/Sources/Core/Events/CoreEvent.swift` are byte-unchanged by this task (file-scope check, §2); a
  test confirms `CoreError.expStateWriteFailed` and `CoreError.diagStateWriteFailed` were already present before
  this task's diff (both are among 03.5's/03.3's pre-existing 17-case set, quoted §3) — no case is added by this
  task anywhere.
- AC13 (C1 seam — full expedition, brief §4 item 1's Core half): `DoorFacadeSeamTests.swift` drives, through
  `DoorFacade` only, on real `data/demo` and a temp-directory `stateURL`, with no stub on either side: **Start
  expedition** → answer every item (one deliberate first miss on a node, then its retry answered correctly, then
  every remaining item correctly) → **Continue** through to **summary**. After **every** state-changing call
  the decoded state file (re-read from disk, not the in-memory value) equals the threaded state plus exactly one
  trailing `abandoned: true` `expedition_log` entry matching `ExpeditionRun.end(..., abandoned: true)` computed
  from the current run at that moment; a missing write (a call whose file-hash does not change when it should)
  is a FAIL, not a skip. After the natural end, the file holds exactly one entry for the run, `abandoned ==
  false`. The summary's `clearedNodeNames`/`blockedNodeNames` equal the run's own; re-deriving `MapViewModel
  .derive(bundle:, state: <final file contents>, today:)` afterward shows the fog lifted (`fogLevel == .cleared`)
  on every node the summary names as cleared.
- AC14 (C1 seam — full diagnosis, both triggers, brief §4 item 2's Core half): the same file drives, through
  `DoorFacade` only:
  - (a) `expedition_second_miss`: two misses on one node inside a run → **Continue** reveals `.diagnosis
    (.hypothesis(...))` → `decideProbe(accept: true)` → two `answerProbeItem`/`continueAfterProbeAnswer` pairs
    (both wrong) → `.terminal` with `terminal == .capped`, a non-nil remediation → `resumeAfterDiagnosis` →
    the run resumes at its next item, with the candidate `blocked` in the threaded state.
  - (b) `map_check_here`, decline: `checkHere` → `decideProbe(accept: false)` → `.terminal` with `terminal ==
    .unconfirmed`, a non-nil hint, return to the (simulated) node panel with no `DoorFacade.resumeAfterDiagnosis`
    call.
  - (c) `map_check_here`, refuted: `checkHere` → `decideProbe(accept: true)` → two correct `answerProbeItem`/
    `continueAfterProbeAnswer` pairs → `.terminal` with `terminal == .refuted`.
  - Every one of (a)–(c) ends with `.diagnosisReturned` last in its accumulated `events` list (the underlying
    `DiagnosisRun` machinery's own guarantee, unmodified, asserted here as a seam-level property).
- AC15 (`DoorEntriesTests.swift`, brief item 5): AC1–AC3, AC9, AC10 and AC11's write-failure banner (both the
  Door B and the Door A case) each get their own dedicated test in this file, independent of the longer C1
  sequences in `DoorFacadeSeamTests.swift`.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Core/Sources/Core/Platform/MapLaunch.swift` — MODIFY. Appends `DoorRunState` and the `DoorFacade`
  enum (§4) after the existing `MapFacade` enum's closing brace; no existing line in the file is edited,
  reordered or removed. Confirmed present, with the shape quoted §3, per task 03.7's own already-written spec
  (`tasks/epic-03-task-07-map-actions-facade-launch.md` §4). This task is the only EPIC 04 writer of this file.
- `Packages/Core/Tests/CoreTests/DoorFacadeSeamTests.swift` — CREATE. AC13, AC14 (the C1 full-expedition and
  full-diagnosis sequences, both triggers, over real `data/demo`, no stubs).
- `Packages/Core/Tests/CoreTests/DoorEntriesTests.swift` — CREATE. AC1–AC3, AC9, AC10, AC11, AC12, AC15 (queue
  behaviour, unit-expedition delegation, `EXP_NO_FRINGE`, Start another, Back to the map, the write-failure
  banner for both doors, the no-new-registry-surface check).

Out-of-scope (do not touch even if tempted):

- `Packages/Core/Sources/Core/Door/ExpeditionFlow.swift`, `Packages/Core/Sources/Core/Door/
  ExpeditionContent.swift` — 04.4's files; call `DoorBExpeditionFlow`'s and `DoorBWriteAhead`'s public entry
  points only, never edit, never call `ExpeditionRun` directly (04.4 already delegates to it; a second call site
  here would duplicate 04.4's own sequencing).
- `Packages/Core/Sources/Core/Door/DiagnosisFlow.swift`, `Packages/Core/Sources/Core/Door/
  DiagnosisContent.swift` — 04.3's files; call `DoorADiagnosisFlow`'s public entry points only, never edit,
  never call `DiagnosisRun` directly.
- `Packages/Core/Sources/Core/Platform/StudentStateStore.swift` — 03.5's file; call `StudentStateStore.write`
  only, never edit, never construct a second read/write/atomic-rename path (I14).
- `Packages/Core/Sources/Core/CoreError.swift` — read-only; this task throws/surfaces only
  `.expStateWriteFailed`, `.diagStateWriteFailed` and `.expNoFringe`, all three already present (AC12); no case
  is added.
- `Packages/Core/Sources/Core/Events/CoreEvent.swift` — read-only; this task emits only event cases the
  underlying `MapFacade`/`DoorBExpeditionFlow`/`DoorADiagnosisFlow`/`StudentStateStore` calls already produce;
  no case is added.
- `Packages/Core/Sources/Core/CoreErrorText.swift` — 03.3's file; this task never resolves `writeFailureCode`
  or `EXP_NO_FRINGE` to display text itself — it returns the registry code string only (arbiter-03 § Q-F: "The
  list of student messages to display... is computed here, as registry codes"); the App (04.8/04.9, out of this
  task's scope) resolves text via `CoreErrorText.text(for:)`.
- `Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift`, `Packages/Core/Sources/Core/State/
  ExpeditionRun.swift`, `Packages/Core/Sources/Core/State/Expedition.swift` — landed files; called only through
  04.3's/04.4's/03.7's own public wrappers, except the one direct `Expedition.compose` call inside
  `startExpedition`, and the one direct `ExpeditionRun.end` call inside `backToMap` (03.7 already makes an
  equivalent direct `Expedition.compose` call inside `MapFacade.unitExpedition`; this task matches that shape,
  never touching either file itself).
- `App/Sources/**` — no App code; 04.7–04.10 consume this task's public surface in 04b, on a later branch.
- `contracts/**`, `data/demo/**`, `docs/**` — read-only ground truth.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/interaction-contract.md` — heading `## 2. Expedition`, the `end`/summary/in-run-log-entry bullets
  (re-read, byte-compared this run):
  > - `end`: summary; log entry; a run left mid-way is `abandoned` (expedition Q6), never resumed item-by-item.
  >
  > - **Answer card (timing):** after every checked item — expedition item, retry or probe item — the answer
  >   card (correct/incorrect, the correct answer, `why`) stays on screen until the student taps an explicit
  >   continue control. There is no timer and no auto-advance. No next item, probe item, hypothesis card,
  >   remediation, terminal line or summary is reachable before that tap (I3).
  > - **Summary content:** the summary lists the nodes cleared this run, the fog lifted, the nodes marked
  >   `blocked`, and offers "Start another" and "Back to the map". It shows no region tint delta and no
  >   fraction; the re-derived map shows the tint on return (map W6).
  > - **In-run log entry (expedition Q6):** while a run is in progress, the persisted `StudentState` carries
  >   that run's `expedition_log` entry exactly as `end` with `abandoned = true` would write it at that moment;
  >   `end` replaces it with the final entry. A run the OS terminates is therefore logged as abandoned and never
  >   resumed. No field is added.

  Source: `contracts/interaction-contract.md:56, 77-92` (v0.9.3, per task 04.1, a `depends_on`-transitive
  precondition). Binds AC4, AC7, AC10, AC13: the write-ahead/final-entry split this task's persistence sequencing
  implements.

- `contracts/interaction-contract.md` — heading `## 4. Diagnosis`, `open` (re-read, byte-compared this run):
  > `open(origin, trigger ∈ {expedition_second_miss, map_check_here})`; `level = 0`; budget 2 (Demo: 1).

  Source: `contracts/interaction-contract.md:81`. Binds AC8: `checkHere`'s `DoorADiagnosisFlow.start` call opens
  with `trigger: .mapCheckHere`, `levelBudget: 1`, both already threaded by `MapFacade.checkHere` (03.7).

- `contracts/error-codes.json` — the three codes this task raises/surfaces (re-read, byte-compared this run):
  > `{"code": "EXP_NO_FRINGE", "recoverable": true, "surface": "student", "user_text": "You've cleared
  > everything up to here. Move your class marker forward, or explore the map."}`
  > `{"code": "EXP_STATE_WRITE_FAILED", "recoverable": true, "surface": "student", "user_text": "Your progress
  > could not be saved just now; it will be retried."}`
  > `{"code": "DIAG_STATE_WRITE_FAILED", "recoverable": true, "surface": "student", "user_text": "Your progress
  > could not be saved just now; it will be retried."}`

  Source: `contracts/error-codes.json:14, 17, 22` (re-verified against `CoreErrorText.userText`, quoted below).
  Binds AC3, AC11: this task surfaces these registry codes as strings; it never authors new copy.

- `contracts/data-model.md` — heading `### StudentState (student-state.schema.json)` (re-read, byte-compared
  this run):
  > `schema_version`, `format_version_seen`, `syllabi[]` (course codes), `marker {course_code, unit_id,
  > past_last_unit?}`, `nodes {node_id → {mastery ∈ {fog, cleared, blocked}, correct_count, last_probe?,
  > next_due?, ladder_rung, remediated?}}`, `trail {segments[] {kind ∈ {course, extension}, course_code?,
  > node_ids[]}}` (derived, cached), `expedition_log[] {day, item_count, cleared, blocked, abandoned,
  > diagnosis_events}`, `probe_log[] {day, node_id, item_id, correct, retry}`, `install_day`, `consent_on`.
  > **No field may name a person, device, account, install or session** (I5); the schema's closed key set is
  > the guard.

  Source: `contracts/data-model.md:131-137`. Binds every `StudentStateStore.write` call in this task: the whole
  document, never a partial update; no queue field exists or is added (`DoorRunState`/`MapState.queuedNodeId`
  stays in-memory only, per arbiter-03 § Q-D, quoted below).

Domain-doc excerpts (verbatim):

- `docs/domains/expedition.md` — heading `### W5 — End the run` (re-read, byte-compared this run):
  > **Pre:** the last item is answered, or the student leaves. **Steps:** 1. Build the `ExpeditionSummary`.
  > 2. Append the ExpeditionLog entry; write `StudentState` via **platform** (`EXP_STATE_WRITE_FAILED` shows a
  > banner, the summary still shows — I3's spirit). 3. Offer "Start another" (W1) and "Back to the map".
  > **Post:** `expedition.completed` emitted (D40) with the count of items and cleared nodes; a run left
  > mid-way is logged as abandoned, never resumed item-by-item (Q6).

  Source: `docs/domains/expedition.md:98-103`. Binds AC10, AC11(a).

- `docs/domains/diagnosis.md` — heading `### W5 — Return` (re-read, byte-compared this run):
  > **Pre:** any terminal outcome. **Steps:** 1. Write the outcome record into `StudentState`. 2. Hand control
  > back: to the suspended expedition (its W3 step 2 continues) or to the map node panel. 3. Tier 1 (M4+) may
  > re-word the hint shown; below threshold or unavailable the stored wording stands (I2). **Post:**
  > `diagnosis.returned`; the event is closed.

  Source: `docs/domains/diagnosis.md:82-86`. Binds AC7, AC8, AC14: step 2's fork is exactly `resumeAfterDiagnosis`
  (in-run) vs. the standalone `checkHere` event's own terminal (out-of-run).

Arbiter rulings (verbatim, re-read and byte-compared this run):

- `tasks/arbitration/arbiter-03-predispatch.md` § Q-D:
  > CONFIRMED. The queue is one in-memory node id held by the `Core` façade value (Q-F), passed to the next
  > `Expedition.compose(queuedNodeId:)` and not persisted. `StudentState` has a closed key set with no queue
  > field, so persisting it would be a data-model BUMP.
  >
  > Precisions for task 5:
  > - A later Include **replaces** the queued id; map Q5 allows "one node".
  > - The id is consumed by the next `compose` call whether or not it was still on the fringe; `compose` already
  >   ignores an off-fringe queued id.

  Binds AC1: "Precisions for task 5" is EPIC 03's own brief-task numbering (03.7, the façade task), the rule
  this task's `startExpedition` consumes by passing `mapState.queuedNodeId` into `Expedition.compose`, exactly
  as 03.7's own `MapFacade.include`/AC12 already establishes the mechanism for.

- `tasks/arbitration/arbiter-03-predispatch.md` § Q-F, "The boundary, precisely", item 4:
  > **The façade.** Each entry point takes values and returns (new value, `[CoreEvent]`) or throws a
  > `CoreError`. — The persist-after-every-state-changing-action sequencing lives here too: a `Core` session
  > type whose actions write to the injected URL. That way a missed write is caught by a `CoreTests` test, not
  > left in untestable App code. — The list of student messages to display... is computed here, as registry
  > codes.

  Binds the whole shape of `DoorFacade`: registry-code strings, never resolved text; a missed write is
  `CoreTests`-catchable (AC13's file-hash assertions).

- `tasks/arbitration/arbiter-04-predispatch.md` § Q-A (re-read, byte-compared this run):
  > "Continue" is a façade entry point, not an App-only presentation flag. After an answer, the façade's current
  > screen value is the answer card. Only the continue call moves it on... The continue call changes no
  > `StudentState`, so it triggers no write.

  Binds AC4, AC5, AC6: no `StudentStateStore.write` call inside `continueAfterAnswer` or
  `continueAfterProbeAnswer`.

- `tasks/arbitration/arbiter-04-predispatch.md` § Q-G (re-read, byte-compared this run):
  > - **In-run write-ahead.** After every state-changing Door B or Door A call during a run, including the
  >   run-start call, the session persists `ExpeditionRun.end(run: <current run>, state: <threaded state>,
  >   today:, abandoned: true).state`. The in-memory threaded state never contains that entry. At a natural end
  >   the session persists `end(…, abandoned: false).state`. On "Back to the map" mid-run it persists `end(…,
  >   abandoned: true).state`. Either way, the provisional entry is replaced, because it was never in memory.
  > - **Where the natural end is called.** In the same façade call that produces the run's last result: the
  >   final answer, or the `returned` that resumes into an empty queue. The summary value is held behind that
  >   call's answer card and shown on continue (Q-A). So a completed run is never logged abandoned by an OS
  >   kill while its last card is on screen.
  > - **`map_check_here` outside a run.** No in-run entry exists, which is the EPIC 02 § 9 default: "logs no
  >   `expedition_log` entry".

  Binds AC1, AC4, AC6, AC7, AC8, AC10, AC13: this task's entire write-ahead-vs-plain-vs-final persistence
  branching is exactly this ruling, realised as code.

- `tasks/arbitration/arbiter-04-predispatch.md` § Q-C (re-read, byte-compared this run — the exact exclusion
  text this spec's Goal section restates):
  > **What it cannot claim** (the exclusion that must be stated verbatim in the 04b task specs and the
  > acceptance report): 1. that any tap on a simulator actually fires its action... 2. that each Door screen is
  > laid out so its controls are visible and reachable... 3. that no runtime trap occurs along the Door screens
  > after launch... 4. that the sequence of screens a student sees matches the façade's screen values at
  > runtime, rather than only in `CoreTests`.

  Binds this spec's §1 C3 paragraph (Core-half framing: this task ships no App code, so it evidences none of the
  four points and claims none of them).

Prior signatures this task builds on (verbatim, re-read against the current tree — and, where the target file is
not yet on the tree used to write this spec, against the sibling task's own already-written, PASS-marked spec —
in this session):

```swift
// Packages/Core/Sources/Core/Platform/MapLaunch.swift (task 03.7's spec §4.1, §4.5)
public struct MapState {
    public let bundle: ContentBundle
    public let stateURL: URL
    public let state: StudentState
    public let viewModel: MapViewModel
    public let queuedNodeId: String?
}
public enum MapFacade {
    public static func unitExpedition(
        unitId: String, mapState: MapState, today: CalendarDay
    ) throws -> (result: ComposeResult, events: [CoreEvent])
    public static func checkHere(
        nodeId: String, mapState: MapState
    ) -> (event: DiagnosisEvent, events: [CoreEvent])
}
```

```swift
// Packages/Core/Sources/Core/State/Expedition.swift:35-43 (landed, EPIC 01/02)
public static func compose(
    state: StudentState, bundle: ContentBundle, trail: Trail, marker: Marker, today: CalendarDay,
    queuedNodeId: String? = nil, unitExpeditionUnitId: String? = nil
) throws -> ComposeResult
```

```swift
// Packages/Core/Sources/Core/Platform/StudentStateStore.swift (task 03.5's spec §4)
public static func write(_ state: StudentState, to url: URL) throws -> [CoreEvent]
```

```swift
// Packages/Core/Sources/Core/Door/ExpeditionFlow.swift (task 04.4's spec §4, PASS)
public struct DoorBRunState: Equatable {
    public let run: ExpeditionRunState
    let pendingFirstMiss: ItemMiss?
}
public struct DoorBStartAdvance: Equatable {
    public let runState: DoorBRunState
    public let screen: DoorBScreen
    public let event: CoreEvent
}
public struct DoorBAnswerAdvance: Equatable {
    public let answerCard: DoorAnswerCardContent
    public let result: ItemResult
    public let runState: DoorBRunState
    public let state: StudentState
    public let events: [CoreEvent]
    let pendingHandoffMisses: [ItemMiss]?
    let pendingEnd: EndOutcome?
}
public struct DoorBContinueAdvance: Equatable {
    public let screen: DoorBScreen
    public let runState: DoorBRunState
    public let state: StudentState
    public let events: [CoreEvent]
}
public struct DoorBResumeAdvance: Equatable {
    public let screen: DoorBScreen
    public let runState: DoorBRunState
    public let state: StudentState
    public let events: [CoreEvent]
}
public enum DoorBExpeditionFlow {
    public static func start(compose: ComposeResult) -> DoorBStartAdvance
    public static func answer(
        _ runState: DoorBRunState, submitted: String, state: StudentState, bundle: ContentBundle,
        today: CalendarDay
    ) -> DoorBAnswerAdvance
    public static func continueAfterAnswer(_ pending: DoorBAnswerAdvance, bundle: ContentBundle)
        -> DoorBContinueAdvance
    public static func resumeAfterDiagnosis(
        _ runState: DoorBRunState, outcome: DiagnosisOutcome, bundle: ContentBundle, today: CalendarDay
    ) -> DoorBResumeAdvance
}
public enum DoorBWriteAhead {
    public static func provisionalAbandonedState(
        runState: DoorBRunState, state: StudentState, today: CalendarDay
    ) -> StudentState
}
public enum DoorBScreen: Equatable {
    case item(DoorItemContent)
    case diagnosis(DoorADiagnosisScreen)
    case summary(DoorBSummaryScreen)
}
```

```swift
// Packages/Core/Sources/Core/Door/DiagnosisFlow.swift (task 04.3's spec §4)
public struct DoorADiagnosisAdvance: Equatable {
    public let screen: DoorADiagnosisScreen
    public let state: StudentState
    public let events: [CoreEvent]
}
public struct DoorAProbeAnswerAdvance: Equatable {
    public let answerCard: DoorAnswerCardContent
    public let itemResult: ItemResult
    public let state: StudentState
    public let events: [CoreEvent]
    let pendingAdvance: DiagnosisAdvance
    let classifiedToken: String
}
public enum DoorADiagnosisFlow {
    public static func open(originNodeId: String, trigger: DiagnosisTrigger, levelBudget: Int) -> DiagnosisEvent
    public static func start(
        event: DiagnosisEvent, misses: [ItemMiss], shownItemIdsInRun: Set<String>,
        state: StudentState, bundle: ContentBundle
    ) -> DoorADiagnosisAdvance
    public static func decideProbe(
        _ offer: ProbeOffer, accept: Bool, state: StudentState, bundle: ContentBundle
    ) -> DoorADiagnosisAdvance
    public static func answerProbeItem(
        _ probe: ProbeInProgress, submitted: String, state: StudentState, bundle: ContentBundle,
        today: CalendarDay
    ) -> DoorAProbeAnswerAdvance
    public static func continueAfterProbeAnswer(_ pending: DoorAProbeAnswerAdvance, bundle: ContentBundle)
        -> DoorADiagnosisScreen
    public static func decideFurtherLevel(
        _ offer: FurtherLevelOffer, accept: Bool, state: StudentState, bundle: ContentBundle
    ) -> DoorADiagnosisAdvance
}
public enum DoorADiagnosisScreen: Equatable {
    case hypothesis(content: DoorAHypothesisContent, offer: ProbeOffer)
    case probeItem(content: DoorItemContent, probe: ProbeInProgress)
    case furtherLevelOffer(
        remediation: DoorARemediationContent, offer: DoorAFurtherLevelOfferContent, decision: FurtherLevelOffer)
    case terminal(DoorATerminalContent)
}
public struct DoorATerminalContent: Equatable {
    public let terminal: DiagnosisTerminal
    public let line: String?
    public let hint: DoorAHintContent?
    public let remediation: DoorARemediationContent?
    public let outcome: DiagnosisOutcome
}
```

```swift
// Packages/Core/Sources/Core/State/ExpeditionRun.swift:1-192 (landed, EPIC 01/02; called here only via
// ExpeditionRun.end, for Back to the map's mid-run abandon — every other call goes through 04.4's wrapper)
public static func end(
    run: ExpeditionRunState, state: StudentState, today: CalendarDay, abandoned: Bool
) -> EndOutcome   // non-throwing
public struct EndOutcome: Equatable { public let state: StudentState; public let summary: ExpeditionSummary
    public let event: CoreEvent }
```

```swift
// Packages/Core/Sources/Core/CoreError.swift:10-28 (17 pre-existing cases; re-verified this run against the
// tree used to write this spec — neither case below is added by this task)
case expNoFringe = "EXP_NO_FRINGE"
case expStateWriteFailed = "EXP_STATE_WRITE_FAILED"
case diagStateWriteFailed = "DIAG_STATE_WRITE_FAILED"
```

```swift
// Packages/Core/Sources/Core/CoreErrorText.swift (task 03.3's spec §4; re-verified against its own byte-quoted
// table)
public enum CoreErrorText {
    public static let userText: [String: String]   // includes "EXP_NO_FRINGE", "EXP_STATE_WRITE_FAILED",
                                                     // "DIAG_STATE_WRITE_FAILED" verbatim (§3 above)
    public static func text(for code: CoreError) -> String?
}
```

Gate commands (`scripts/gate.sh:16-18`, re-read this run):

```sh
( cd "$ROOT/Packages/Core" && swift build -c release --product core-cli )
( cd "$ROOT/Packages/Core" && xcodebuild test -quiet -scheme Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO )
```

Test framework (confirmed by every sibling task file re-read in this run): Swift Testing (`import Testing`,
`@Suite`, `@Test`, `#expect`), not XCTest.

## §4 Implementation outline

Layer placement: layer ④ interaction (Doors B/C — the seam between EPIC 03's map façade and EPIC 04's Door
façades). `MapLaunch.swift`'s new `DoorFacade` composes 03.7's `MapFacade`/`MapState`, 03.5's
`StudentStateStore`, 04.4's `DoorBExpeditionFlow`/`DoorBWriteAhead`, and 04.3's `DoorADiagnosisFlow`, strictly
through their public entry points — it adds no expedition, diagnosis, fringe or checking logic of its own.

### 4.1 `DoorRunState` — the App's one handle onto an in-progress Door run

```swift
/// The App's one handle onto a live Door B expedition or Door A diagnosis, layered over `MapState`. Replaced
/// wholesale by the App's `@Observable` holder after every `DoorFacade` call (same discipline as `MapState`,
/// arbiter-03 § Q-F). `expedition` carries no `public` modifier: only `Core` code (this file, and this task's
/// own tests) inspects or constructs it directly — the App holds it opaquely and passes it back unmodified,
/// mirroring 04.3's/04.4's own "no field yields a screen" discipline applied here at the run-state level.
public struct DoorRunState {
    public let map: MapState
    let expedition: DoorBRunState?
}
```

`DoorRunState` declares no `Equatable`: its `map: MapState` field is not `Equatable`, because
`ContentBundle` is not (`BundleIO.swift:8`), a deliberate EPIC 03 choice
(`tasks/epic-03-task-07-map-actions-facade-launch.md` §4.1: "every test asserts on individual fields").
Tests compare a `DoorRunState` field-wise (`map.state`, `map.viewModel`, `map.queuedNodeId`, `map.stateURL`,
and `expedition` via `@testable import Core`) — `tasks/arbitration/arbiter-04-doorrunstate-equatable.md`.

### 4.2 Persistence helpers (private)

```swift
private static func persistExpeditionWrite(_ state: StudentState, to url: URL) -> String? {
    do {
        _ = try StudentStateStore.write(state, to: url)
        return nil
    } catch {
        return CoreError.expStateWriteFailed.rawValue
    }
}

private static func persistDiagnosisWrite(_ state: StudentState, to url: URL) -> String? {
    do {
        _ = try StudentStateStore.write(state, to: url)
        return nil
    } catch {
        return CoreError.diagStateWriteFailed.rawValue
    }
}

/// Q-G branch: write-ahead when a `DoorBRunState` is active, plain otherwise (`map_check_here` outside a run).
private static func persistDoorA(
    _ state: StudentState, expedition: DoorBRunState?, url: URL, today: CalendarDay
) -> String? {
    let toWrite = expedition.map {
        DoorBWriteAhead.provisionalAbandonedState(runState: $0, state: state, today: today)
    } ?? state
    return persistDiagnosisWrite(toWrite, to: url)
}

private static func rebuiltMap(_ map: MapState, state: StudentState, today: CalendarDay) -> MapState {
    MapState(
        bundle: map.bundle, stateURL: map.stateURL, state: state,
        viewModel: MapViewModel.derive(bundle: map.bundle, state: state, today: today),
        queuedNodeId: map.queuedNodeId)
}
```

### 4.3 `DoorFacade` — Door B (expedition) entries

```swift
public enum DoorFacade {
    /// AC1. Consumes and empties the Include queue.
    public static func startExpedition(mapState: MapState, today: CalendarDay) throws
        -> (runState: DoorRunState, screen: DoorBScreen, writeFailureCode: String?, events: [CoreEvent])
    {
        let compose = try Expedition.compose(
            state: mapState.state, bundle: mapState.bundle, trail: mapState.state.trail,
            marker: mapState.state.marker, today: today, queuedNodeId: mapState.queuedNodeId,
            unitExpeditionUnitId: nil)
        let advance = DoorBExpeditionFlow.start(compose: compose)
        let ahead = DoorBWriteAhead.provisionalAbandonedState(
            runState: advance.runState, state: mapState.state, today: today)
        let failure = persistExpeditionWrite(ahead, to: mapState.stateURL)
        let newMap = MapState(
            bundle: mapState.bundle, stateURL: mapState.stateURL, state: mapState.state,
            viewModel: mapState.viewModel, queuedNodeId: nil)
        let events = failure == nil ? [advance.event, .platformStateWritten] : [advance.event]
        return (
            DoorRunState(map: newMap, expedition: advance.runState), advance.screen, failure, events)
    }

    /// AC2. Delegates fringe scoping verbatim to `MapFacade.unitExpedition`; never touches `queuedNodeId`.
    public static func startUnitExpedition(unitId: String, mapState: MapState, today: CalendarDay) throws
        -> (runState: DoorRunState, screen: DoorBScreen, writeFailureCode: String?, events: [CoreEvent])
    {
        let (compose, composeEvents) = try MapFacade.unitExpedition(
            unitId: unitId, mapState: mapState, today: today)
        let advance = DoorBExpeditionFlow.start(compose: compose)
        let ahead = DoorBWriteAhead.provisionalAbandonedState(
            runState: advance.runState, state: mapState.state, today: today)
        let failure = persistExpeditionWrite(ahead, to: mapState.stateURL)
        let events = composeEvents + (failure == nil ? [advance.event, .platformStateWritten] : [advance.event])
        return (DoorRunState(map: mapState, expedition: advance.runState), advance.screen, failure, events)
    }

    /// AC4. Persists the final entry when the run naturally ends in this call, else the write-ahead value.
    public static func answer(_ runState: DoorRunState, submitted: String, today: CalendarDay)
        -> (advance: DoorBAnswerAdvance, runState: DoorRunState, writeFailureCode: String?)
    {
        guard let expedition = runState.expedition else {
            preconditionFailure("DoorFacade.answer called with no active expedition")
        }
        let advance = DoorBExpeditionFlow.answer(
            expedition, submitted: submitted, state: runState.map.state, bundle: runState.map.bundle, today: today)
        let toWrite =
            advance.pendingEnd?.state
            ?? DoorBWriteAhead.provisionalAbandonedState(
                runState: advance.runState, state: advance.state, today: today)
        let failure = persistExpeditionWrite(toWrite, to: runState.map.stateURL)
        let newMap = rebuiltMap(runState.map, state: advance.state, today: today)
        return (advance, DoorRunState(map: newMap, expedition: advance.runState), failure)
    }

    /// AC4/AC5. No write — arbiter-04 § Q-A.
    public static func continueAfterAnswer(_ pending: DoorBAnswerAdvance, runState: DoorRunState)
        -> (screen: DoorBScreen, runState: DoorRunState)
    {
        let advance = DoorBExpeditionFlow.continueAfterAnswer(pending, bundle: runState.map.bundle)
        let newMap = MapState(
            bundle: runState.map.bundle, stateURL: runState.map.stateURL, state: advance.state,
            viewModel: runState.map.viewModel, queuedNodeId: runState.map.queuedNodeId)
        return (advance.screen, DoorRunState(map: newMap, expedition: advance.runState))
    }

    /// AC7. `resumeAfterDiagnosis` requires an in-run `DoorRunState` — never called for `map_check_here`.
    public static func resumeAfterDiagnosis(
        _ runState: DoorRunState, outcome: DiagnosisOutcome, today: CalendarDay
    ) -> (advance: DoorBResumeAdvance, runState: DoorRunState, writeFailureCode: String?) {
        guard let expedition = runState.expedition else {
            preconditionFailure("DoorFacade.resumeAfterDiagnosis called with no active expedition")
        }
        let advance = DoorBExpeditionFlow.resumeAfterDiagnosis(
            expedition, outcome: outcome, bundle: runState.map.bundle, today: today)
        let toWrite: StudentState
        if case .summary = advance.screen {
            toWrite = advance.state  // already final (abandoned: false), computed inside resumeAfterDiagnosis
        } else {
            toWrite = DoorBWriteAhead.provisionalAbandonedState(
                runState: advance.runState, state: advance.state, today: today)
        }
        let failure = persistExpeditionWrite(toWrite, to: runState.map.stateURL)
        let newMap = rebuiltMap(runState.map, state: advance.state, today: today)
        return (advance, DoorRunState(map: newMap, expedition: advance.runState), failure)
    }

    /// AC9. Identical to `startExpedition`, applied to the post-run `mapState` (§6).
    public static func startAnother(mapState: MapState, today: CalendarDay) throws
        -> (runState: DoorRunState, screen: DoorBScreen, writeFailureCode: String?, events: [CoreEvent])
    {
        try startExpedition(mapState: mapState, today: today)
    }

    /// AC10. Persists the final `abandoned: true` entry; ends the Door B run.
    public static func backToMap(_ runState: DoorRunState, today: CalendarDay)
        -> (mapState: MapState, writeFailureCode: String?)
    {
        guard let expedition = runState.expedition else { return (runState.map, nil) }
        let end = ExpeditionRun.end(
            run: expedition.run, state: runState.map.state, today: today, abandoned: true)
        let failure = persistExpeditionWrite(end.state, to: runState.map.stateURL)
        return (rebuiltMap(runState.map, state: end.state, today: today), failure)
    }
}
```

### 4.4 `DoorFacade` — Door A (diagnosis) entries

```swift
extension DoorFacade {
    /// AC8. Opens a standalone diagnosis event (no expedition run). `runState.expedition` stays `nil` for this
    /// event's whole life. `today` is used only by `persistDoorA` (§4.2) — `MapFacade.checkHere` itself takes
    /// no `today` parameter.
    public static func checkHere(nodeId: String, mapState: MapState, today: CalendarDay)
        -> (runState: DoorRunState, screen: DoorADiagnosisScreen, writeFailureCode: String?, events: [CoreEvent])
    {
        let (event, mapEvents) = MapFacade.checkHere(nodeId: nodeId, mapState: mapState)
        let advance = DoorADiagnosisFlow.start(
            event: event, misses: [], shownItemIdsInRun: [], state: mapState.state, bundle: mapState.bundle)
        let failure = persistDoorA(advance.state, expedition: nil, url: mapState.stateURL, today: today)
        let newMap = MapState(
            bundle: mapState.bundle, stateURL: mapState.stateURL, state: advance.state,
            viewModel: mapState.viewModel, queuedNodeId: mapState.queuedNodeId)
        return (
            DoorRunState(map: newMap, expedition: nil), advance.screen, failure, mapEvents + advance.events)
    }

    /// AC6. Write-ahead-wrapped when in-run, plain otherwise.
    public static func decideProbe(_ offer: ProbeOffer, accept: Bool, runState: DoorRunState, today: CalendarDay)
        -> (advance: DoorADiagnosisAdvance, runState: DoorRunState, writeFailureCode: String?)
    {
        let advance = DoorADiagnosisFlow.decideProbe(
            offer, accept: accept, state: runState.map.state, bundle: runState.map.bundle)
        let failure = persistDoorA(
            advance.state, expedition: runState.expedition, url: runState.map.stateURL, today: today)
        let newMap = rebuiltMap(runState.map, state: advance.state, today: today)
        return (advance, DoorRunState(map: newMap, expedition: runState.expedition), failure)
    }

    public static func answerProbeItem(
        _ probe: ProbeInProgress, submitted: String, runState: DoorRunState, today: CalendarDay
    ) -> (advance: DoorAProbeAnswerAdvance, runState: DoorRunState, writeFailureCode: String?) {
        let advance = DoorADiagnosisFlow.answerProbeItem(
            probe, submitted: submitted, state: runState.map.state, bundle: runState.map.bundle, today: today)
        let failure = persistDoorA(
            advance.state, expedition: runState.expedition, url: runState.map.stateURL, today: today)
        let newMap = rebuiltMap(runState.map, state: advance.state, today: today)
        return (advance, DoorRunState(map: newMap, expedition: runState.expedition), failure)
    }

    /// No write — mirrors `continueAfterAnswer` (04.3 AC3: "changes no `StudentState`").
    public static func continueAfterProbeAnswer(_ pending: DoorAProbeAnswerAdvance, runState: DoorRunState)
        -> DoorADiagnosisScreen
    {
        DoorADiagnosisFlow.continueAfterProbeAnswer(pending, bundle: runState.map.bundle)
    }

    public static func decideFurtherLevel(
        _ offer: FurtherLevelOffer, accept: Bool, runState: DoorRunState, today: CalendarDay
    ) -> (advance: DoorADiagnosisAdvance, runState: DoorRunState, writeFailureCode: String?) {
        let advance = DoorADiagnosisFlow.decideFurtherLevel(
            offer, accept: accept, state: runState.map.state, bundle: runState.map.bundle)
        let failure = persistDoorA(
            advance.state, expedition: runState.expedition, url: runState.map.stateURL, today: today)
        let newMap = rebuiltMap(runState.map, state: advance.state, today: today)
        return (advance, DoorRunState(map: newMap, expedition: runState.expedition), failure)
    }
}
```

### 4.5 Boundary validation

The only untrusted input any `DoorFacade` function reads is `stateURL` (already validated by
`StudentStateStore`, 03.5) and caller-supplied ids (`nodeId`, `unitId`) and free-text (`submitted`) — all three
are already handled by the underlying `MapFacade`/`DoorBExpeditionFlow`/`DoorADiagnosisFlow` calls this task
wraps; this file adds no new validation and no new untrusted-input boundary.

### 4.6 Error codes thrown / surfaced

- `CoreError.expNoFringe` — thrown by `startExpedition`/`startUnitExpedition`/`startAnother` via
  `Expedition.compose`/`MapFacade.unitExpedition` (already-registered, propagated, never newly thrown here).
- `CoreError.expStateWriteFailed.rawValue` (`"EXP_STATE_WRITE_FAILED"`) — returned as `writeFailureCode` by every
  Door B state-changing entry on a `StudentStateStore.write` failure.
- `CoreError.diagStateWriteFailed.rawValue` (`"DIAG_STATE_WRITE_FAILED"`) — returned as `writeFailureCode` by
  every Door A state-changing entry on a `StudentStateStore.write` failure.

No new `CoreError` case; no `error-codes.json` entry.

### 4.7 Model-calling paths

None. Every `DoorFacade` function is a pure sequencing wrapper over already-Tier-0 calls plus one
`StudentStateStore.write` I/O call (I2's confidence-threshold/fallback requirement is not engaged).

### 4.8 Smoke check

`( cd Packages/Core && swift build -c release --product core-cli )` — must be green.

## §5 Test plan (risk: seam — full plan)

- **T1 happy path:** AC1, AC2, AC4, AC6, AC7, AC8, AC9 — each runs over real `data/demo` in
  `DoorEntriesTests.swift` (the short, focused cases) and inside the AC13/AC14 sequences of
  `DoorFacadeSeamTests.swift` (the long, C1 real-composition runs).
- **T2 negative — invalid input rejected at the boundary:** this file parses no new untrusted external input
  (§4.5); the applicable case is a `submitted` string that fails `ItemChecker`'s numeric grammar (e.g. `"abc"`)
  passed through `DoorFacade.answer`/`.answerProbeItem` — both still return a fully populated advance with
  `correct == false`, never a crash (mirrors 04.2/04.3/04.4's T2 shape).
- **T3 error-taxonomy:** AC3's `CoreError.expNoFringe`, AC11's `.expStateWriteFailed`/`.diagStateWriteFailed`
  each assert the exact `rawValue`; `ErrorRegistryTests` (unmodified, from 03.3) stays green — this task throws
  no new `CoreError` case.
- **T4 conformance per requirements §B.1 and the invariants of §1:**
  - interaction-contract § 2/§ 4 (Q-A, Q-G): AC4–AC8, AC10, AC13, AC14 assert the write-ahead/final/plain
    persistence branching directly against re-read file bytes, never against the in-memory value alone.
  - I3: AC4/AC5's "no write on continue" and 04.3's/04.4's own screen-hiding guarantees, re-asserted here only
    at the persistence layer (this task adds no new screen-exposing field — T5's source scan is the load-bearing
    proof).
  - I5: a `Mirror`-based scan over `DoorRunState` and every `writeFailureCode`-carrying return tuple finds no
    field name matching a student/device/install/session identifier pattern (empty pool = FAIL), mirroring
    04.2/04.3/04.4's shape.
  - I14: a grep over the `DoorFacade`/`DoorRunState` additions in `MapLaunch.swift` finds zero matches for
    `FoundationModels`/`Adapter`/`import CoreML`/`URLSession`, and finds exactly the one `StudentStateStore
    .write` call site per persistence helper (§4.2) — no second write path.
- **T5 negative control for every regression guard:**
  - AC10's simulated-kill guard: a locally reconstructed variant of `answer` that returns `advance` without
    calling `persistExpeditionWrite` at all (test-file-only, never product code) is run through the same
    simulated-kill fixture (drop the in-memory `runState` after a call, independently re-read `stateURL`) and
    is shown to leave `stateURL` either stale (the prior call's entry) or absent — proving the write-ahead call
    is load-bearing, not accidentally satisfied.
  - AC4/AC7's final-vs-write-ahead branch: a locally reconstructed variant that always persists
    `DoorBWriteAhead.provisionalAbandonedState(...)`, even when `pendingEnd`/the `.summary` screen is present,
    is shown to leave the file's final `expedition_log` entry with `abandoned == true` where the real
    implementation's is `false` — proving the branch is load-bearing.
  - AC6/AC8's write-ahead-vs-plain branch (`persistDoorA`): a locally reconstructed variant that always wraps
    with `DoorBWriteAhead.provisionalAbandonedState` (even when `runState.expedition == nil`) is shown to
    `preconditionFailure` or produce a nonsensical `expedition_log` entry for a standalone `map_check_here`
    event with no run — proving the `expedition == nil` branch is load-bearing.
  - AC12's no-new-case check: a diff-based assertion that `CoreError.swift`'s and `CoreEvent.swift`'s line
    counts (captured before this task's implementation begins, and re-checked in the test suite by counting
    `CoreError.allCases.count`/`CoreEvent.allCases.count` against a value hard-coded from the pre-task tree)
    proves the byte-unchanged claim is checkable, not merely asserted in prose; the real diff has zero lines
    changed in `CoreError.swift`/`CoreEvent.swift`.
- **T6 idempotency / no-leak:**
  - `continueAfterAnswer` called twice on the same `Equatable`-equal pending value and the same input
    `DoorRunState` returns results whose `screen` values are `==` and whose `runState` values agree field by
    field: `runState.map.state`, `runState.map.viewModel`, `runState.map.queuedNodeId`, `runState.map.stateURL`
    and `runState.expedition` (reachable via `@testable import Core`) are each `==`. `DoorRunState` and `MapState`
    are not `Equatable` (§4.1), so there is no whole-value `==`. `continueAfterProbeAnswer` called twice returns
    `==` `DoorADiagnosisScreen` values. Neither function changes the file bytes at `stateURL` from before either
    call (no write, called twice).
    - Instrument: Swift Testing `#expect` in `DoorEntriesTests.swift` or `DoorFacadeSeamTests.swift`. It
      excludes a physical device (D29).
    - Negative control: the same five-field comparison, applied to one `continueAfterAnswer` result and the
      `DoorRunState` returned by the *preceding* `answer` call, finds at least one differing field
      (`runState.map.state` or `runState.expedition`). This proves the comparison can go red.
  - `DoorFacade.startAnother` called twice in immediate succession (each over the prior call's own resulting
    `mapState`) produces two independent, non-overlapping runs with byte-identical persistence behaviour to two
    separate `startExpedition` calls.
  - Two independent `DoorFacade.answer` calls with freshly-constructed, value-identical arguments each time
    (never a reused mutated variable) produce byte-identical written files (mirrors 03.5 T6's shape).

## §6 Decision defaults

- IF `DoorFacade`/`DoorRunState` should live in a new file (e.g. `Packages/Core/Sources/Core/Door/
  DoorFacade.swift`) rather than appended to `MapLaunch.swift` THEN they live in `MapLaunch.swift` — the
  dispatch instruction is explicit ("this task is the ONLY EPIC 04 task that modifies 03.7's façade file; name
  that file exactly"), and `docs/plans/epic-04-plan.md`'s own seam note names this task as the one that adds
  "the Door entry points on EPIC 03's Core map-actions/session type" — i.e., onto the existing façade type's
  file, not a sibling file.
- IF "Start another" should have its own composition logic (distinct from `startExpedition`) THEN it delegates
  to `startExpedition` unchanged (§4.3) — the brief's own wording is "Start another composes from post-run
  state" (identical composition, different input state only), and 03.7's Q-D precedent already establishes that
  `compose`'s queue-consumption rule applies uniformly to every `compose` call, not specially to the first one
  of a session.
- IF a write failure on a Door B call should surface `DIAG_STATE_WRITE_FAILED` (or vice versa for Door A) THEN
  it does not — the split follows the domain each entry point belongs to (expedition W5 step 2 names
  `EXP_STATE_WRITE_FAILED`; diagnosis W5 names `DIAG_STATE_WRITE_FAILED`, both quoted §3), independent of
  whether a Door A call happens to be nested inside an expedition run (a D27 hand-off's `decideProbe`/
  `answerProbeItem`/`decideFurtherLevel` calls still surface `DIAG_STATE_WRITE_FAILED` on failure, because they
  are Door A actions, even though their write is write-ahead-wrapped for Door B's own Q-G bookkeeping).
- IF `checkHere`'s hypothesis-formation write (which mutates no `StudentState`, per 04.4 §3's citation of the
  same fact for the D27 hand-off) should be skipped entirely (since it is a no-op write) THEN it still writes —
  the conservative default is to persist after every state-changing-shaped call uniformly (§4.2's `persistDoorA`
  helper has no special case for "this particular call happens not to mutate anything"), because a future
  content/data change could make hypothesis formation state-mutating (e.g., a telemetry-adjacent field, out of
  this EPIC's scope) and a uniform rule is simpler to audit than a per-call exception list.
- IF `resumeAfterDiagnosis` should be callable with `runState.expedition == nil` (returning some no-op value)
  THEN it does not — a `preconditionFailure` is correct, because diagnosis W5 step 2's own fork ("hand control
  back... to the suspended expedition... or to the map node panel") means a `map_check_here` event's `returned`
  step never has a suspended expedition to resume into; calling this function in that context is a caller
  (04b) programming error, not a runtime condition this façade should tolerate silently.
- IF the Q-G "run-start call" write-ahead in `startExpedition`/`startUnitExpedition` should be computed from
  `advance.runState`'s **post-start** `ExpeditionRunState` but the **pre-start** `state` (i.e. `mapState.state`,
  since `DoorBExpeditionFlow.start` itself never threads or returns a `StudentState`) THEN that is exactly what
  §4.3 does — `DoorBExpeditionFlow.start(compose:)` returns no `state` field (its `DoorBStartAdvance` carries
  only `runState`/`screen`/`event`, quoted §3), because composing and starting a run changes no mastery; the
  write-ahead value is therefore built from the caller's own already-current `mapState.state`, which is correct
  by construction (the run has not yet answered anything).
- IF `checkHere` should take no `today: CalendarDay` parameter (mirroring 03.7's own `MapFacade.checkHere`,
  which needs none) THEN it does anyway — this task's own `persistDoorA` helper needs `today` to compute the
  write-ahead value on the (structurally possible, though never actually taken on `data/demo`, since `checkHere`
  always has `expedition == nil`) branch where a future caller nests a `checkHere`-opened event inside a run;
  threading `today` uniformly through every `DoorFacade` entry keeps the persistence helper's signature single
  and total, rather than partial over which entry points happen to need it today.
- IF a test needs to compare two `DoorRunState` (or `MapState`) values THEN it compares them field-wise per
  §4.1 — never by adding `Equatable` to `DoorRunState`, `MapState` or `ContentBundle`, in product code or via a
  retroactive `extension … : Equatable` in a test file (per 03.7 §4.1's recorded choice;
  `tasks/arbitration/arbiter-04-doorrunstate-equatable.md`).
- Standing defaults: identifiers and timestamps are untouched beyond what `StudentStateStore`/`ExpeditionRun`/
  `DiagnosisRun` already produce; model calls do not exist anywhere in this task's code (I2 vacuous); telemetry
  is unaffected (`consentOn` passes through opaquely); no node's Ministry text is read or written by this task
  (I6 — this task reads no `paraphrase`/`hint_tree`/`explanation` field itself; those are 04.3's/04.4's content
  builders, already-computed by the time this task's code sees them).

## §7 Done definition

The task is done when ALL gates pass:

- format + lint clean (`xcrun swift-format lint --strict --recursive --configuration .swift-format Packages
  App/Sources`).
- typecheck clean — Swift's typecheck is the build.
- `Core` build + test green (`swift build -c release --product core-cli`; `xcodebuild test -scheme
  Core-Package` on the simulator), including every case in §5.
- App build: N/A — this task does not touch `App/Sources`.
- tests green for every case in §5 (T1–T6).
- `ErrorRegistryTests`, `ErrorRegistryNegativeControlTests`, `coreImportBoundary()` and every sibling task's own
  unmodified test suite (03.3–03.7, 04.1–04.4) stay green with no edit to any of their files.
- conforms to every contract section cited in §3 (`contracts/interaction-contract.md` §§ 2, 4;
  `contracts/error-codes.json`'s `EXP_NO_FRINGE`/`EXP_STATE_WRITE_FAILED`/`DIAG_STATE_WRITE_FAILED` entries;
  `contracts/data-model.md` § StudentState) and to every invariant listed in §1 (I1 n/a, I2, I3, I4, I5, I14).
- `scripts/gate.sh` gate 3 green in full (gates 1, 2, 4 are format/pipeline/App-scoped and unaffected by this
  task's file scope beyond gate 1's Swift formatting pass).
