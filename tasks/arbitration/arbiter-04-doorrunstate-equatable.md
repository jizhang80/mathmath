# Arbiter ruling: `DoorRunState: Equatable` (04.5 ↔ 04.8/04.9)

**Date**: 2026-09-11
**Trigger**: an implementer deviation. Task 04.5 shipped `DoorRunState` without `Equatable` because the
spec literal did not compile. That exposed a spec-to-spec contradiction with the already-reviewed 04b specs
04.8 and 04.9.
**Verdict**: **Option B.** The 04b App-side types drop `Equatable`. 04.5's spec is re-anchored to the
shipped code, and 04.5's T6 compares the non-`Equatable` result field-wise. **There is no product-code change
and no 05b task.**

## 1 Verified facts (re-verified in this run)

| # | Fact | Evidence |
|---|---|---|
| F1 | The shipped `DoorRunState` has no `Equatable`. | `Packages/Core/Sources/Core/Platform/MapLaunch.swift:296-299`: `public struct DoorRunState { public let map: MapState; let expedition: DoorBRunState? }` |
| F2 | 04.5's spec literal declares `Equatable`. | `tasks/epic-04-task-05-core-door-entries-persistence-seam.md:583`: `public struct DoorRunState: Equatable {` |
| F3 | `MapState` has no `Equatable`. | `MapLaunch.swift:6`: `public struct MapState {`. Its fields (`:7-13`) are `bundle: ContentBundle`, `stateURL: URL`, `state: StudentState`, `viewModel: MapViewModel` and `queuedNodeId: String?`. |
| F4 | `ContentBundle` has no `Equatable`. | `Packages/Core/Sources/Core/BundleIO.swift:8`: `public struct ContentBundle {` |
| F5 | Every component of `ContentBundle` is already `Equatable`. | `Manifest` (`Model/Manifest.swift:4`), `RegionsFile` (`Model/Regions.swift:4`), `NodesFile` (`Model/Nodes.swift:4`), `EdgesFile` (`Model/Edges.swift:4`), `CoursesFile` (`Model/Courses.swift:4`), `LandmarksFile` (`Model/Landmarks.swift:4`) and `SourcesFile` (`Model/Sources.swift:4`) are all `Codable, Equatable`. |
| F6 | The other component types are `Equatable`. | `StudentState` (`Model/StudentState.swift:10`), `MapViewModel` (`Map/MapViewModel.swift:9`) and `DoorBRunState` (`Door/ExpeditionFlow.swift:7`). |
| F7 | Leaving `MapState` non-`Equatable` was a **deliberate, recorded design choice** in EPIC 03. | `tasks/epic-03-task-07-map-actions-facade-launch.md` §4.1: "`ContentBundle` is not `Equatable` (03.4 §3, …), so neither `MapState` nor `LaunchOutcome` conforms to `Equatable`; every test asserts on individual fields (`.state`, `.viewModel`, `.marker`, …), all of which are themselves `Equatable`." |
| F8 | 03.4 relies on `ContentBundle`'s non-conformance as a soft compile-time guard. | `tasks/epic-03-task-04-bundle-loader-snapshot-seam.md` §5 T6: "a `ContentBundle` field would not compile without adding `Equatable` conformance to `ContentBundle`, which this task does not do". |
| F9 | The 04b specs quote the non-compiling literal. | `tasks/epic-04-task-08-app-expedition-screens.md:338` and `tasks/epic-04-task-09-app-diagnosis-screens.md:409`: `public struct DoorRunState: Equatable {` |
| F10 | Four App-side declaration sites need `DoorRunState: Equatable`. | 04.8:698 `struct DoorBStartOutcome: Equatable {`; 04.8:791 `struct DoorBRunSnapshot: Equatable {`; 04.9:804 `struct DoorAStartOutcome: Equatable {`; 04.9:479 and 04.9:844 `struct DoorBRunSnapshot: Equatable {` (the second is 04.9's quote of 04.8, the third is 04.9's extension of it). Each holds `let runState: DoorRunState`. |
| F11 | **No App consumer uses the conformance.** | See the list below this table. |
| F12 | The App has no unit-test target, so App-side `Equatable` cannot be test-motivated. | Dispatcher fact. It is consistent with `docs/plans/epic-04-plan.md:102` ("If the owner adds a `mathmathUITests` target … optional owner Q5"). |
| F13 | **04.5's own T6 uses the conformance, in Core tests.** | 04.5 spec §5 T6: "`continueAfterAnswer`/`continueAfterProbeAnswer` called twice on the same `Equatable`-equal pending value return `Equatable`-equal results". `continueAfterAnswer` returns `(screen: DoorBScreen, runState: DoorRunState)` (`MapLaunch.swift:399-400`), so T6 as literally worded needs `DoorRunState ==`. `continueAfterProbeAnswer` returns only `DoorADiagnosisScreen` (`MapLaunch.swift:499-500`), which is already `Equatable`. |
| F14 | The 04.5 tests on disk make no whole-value comparison of `DoorRunState`. | `DoorEntriesTests.swift:79,103` compare `.runState.map.queuedNodeId`, and `DoorFacadeSeamTests.swift:319` compares `.runState.expedition`. Both are field-wise. |
| F15 | No retroactive conformance exists anywhere. | A grep for `extension (ContentBundle\|MapState\|DoorRunState)\b` over `**/*.swift` returns 0 matches. |
| F16 | No contract names the conformance. | A grep of `contracts/` for `ContentBundle\|MapState\|Equatable` returns one hit, `contracts/domain-glossary.md:53` (the **Bundle** term), which says nothing about equality. |
| F17 | 04a is 04.1–04.6, and 04.6 is the wrap. | `docs/plans/epic-04-plan.md:6`: "**04a — Door core:** 04.1–04.6 (wrap 04.6), branch `epic-04a-door-core`." |

The evidence for F11:

- `HandOffDestination` is a plain `enum` with no `Equatable` (`App/Sources/MapUI/MapActionsView.swift:7`; 04.8
  §4.8 and 04.9 §4.5 keep it plain). So `DoorBStartOutcome`/`DoorAStartOutcome` as associated values need no
  conformance.
- `DoorRunHolder` is an `@Observable final class` (04.8 §4.9). The `@Observable` macro places no `Equatable`
  requirement on stored properties.
- The `fullScreenCover` binds `isPresented: Binding(get: { doorHolder.current != nil } …)` (04.8:816-818,
  04.9:501-503). That is an optional-nil test, which needs no `Equatable` on the wrapped type.
- A grep of 04.8 and 04.9 for `fullScreenCover|\.animation|onChange\(|\.task\(id|Identifiable|isPresented|current ==|removeDuplicates`
  finds only the `isPresented`/`!= nil` sites above.
- The App's one `.animation(value:)` (`App/Sources/Map/MapCanvasView.swift:40`) keys on `mapViewModel`, which
  is `Equatable` (F6). It is not a run-state value.
- 04.10 declares no App struct holding `DoorRunState`. A grep for `DoorRunState: Equatable` over 04.10 returns
  0 matches.

## 2 Option analysis

### (A) Restore the literal: make `ContentBundle`, `MapState` and `DoorRunState` `Equatable`

- **Feasibility.** It is purely additive and synthesized: F5 and F6 show every component is already
  `Equatable`. Three one-token edits would compile.
- **Ownership.**
  - `BundleIO.swift` is EPIC 01's file.
  - `MapState` (`MapLaunch.swift:6`) is 03.7's declaration. 04.5 §2 limits 04.5 to appending, with "no existing
    line in the file is edited".
  - A new 04a task (05b) would be needed. It would be classed as rework.
- **Semantics.**
  - It reverses the recorded EPIC 03 design choice (F7).
  - It removes 03.4's soft compile-time guard (F8). A `ContentBundle` field could then be added to
    `BundleRefusal` without a compile error.
  - Whole-bundle value equality has no consumer. Within one App run the bundle never changes (every
    `DoorFacade` entry passes `map.bundle` through unchanged: `MapLaunch.swift:335-338, 355-357, 403-405`).
- **Cost.** Near-zero at runtime [ESTIMATE: Swift `Array ==` short-circuits on shared buffer identity, and
  `DoorFacade` forwards the same `bundle` storage, so the realistic comparisons are pointer checks]. But there
  is no caller to pay it or benefit from it.
- **Contract.** No contract is affected (F16).
- **I14.** No I14 issue: equality would live in `Core`.
- **Blast radius.** 2 product files in 2 foreign-owned scopes, 1 new task, 1 rework commit that gates the 04a
  wrap, plus the 04.8/04.9 quote stays as it is.
- **Rejected.** It pays a design reversal and rework to satisfy a conformance nobody consumes.

### (B) Drop `Equatable` from the 04b App types; re-anchor the 04.5 spec to the shipped code

- **Why were the App types `Equatable`?**
  - **Not tests.** There is no App test target (F12).
  - **Not SwiftUI diffing.** There is no `onChange`/`animation(value:)`/`task(id:)`/`removeDuplicates` on
    them, and `fullScreenCover` uses `isPresented` (F11).
  - **Not `@Observable`.** The macro has no `Equatable` requirement.
  - **Not the phase machine.** `DoorBPhase` stays `Equatable` on its own: its payloads `DoorBScreen`,
    `DoorBAnswerAdvance` and `DoorAProbeAnswerAdvance` are `Equatable` Core types. Nothing compares
    `DoorBRunSnapshot` or the start outcomes.
  - The conformance is house-style habit copied from the `Core` value types, and it has no consumer.
- **Blast radius.**
  - Code: none.
  - Specs: five one-token edits to App declaration lines, two quote corrections, and three prose touch-ups
    across 04.8/04.9, all before 04b dispatch.
  - 04.5: a spec-alignment edit, plus one T6 wording re-anchor that the in-flight tester follows. That is test
    code the tester is already writing, not rework.
- **The 04.5 T6 fallout (F13)** is resolved field-wise. This is exactly 03.7's established precedent (F7:
  "every test asserts on individual fields"), and it is a strictly stronger check than `==`, because each
  field's inequality is reported separately.
- **I14.** Clean. The render layer gains no equality semantics. It simply stops declaring a conformance.
- **Chosen.**

### (C) A narrower manual `==` on `DoorRunState` or `MapState`

- It invents an equality definition ("bundle fixed for a session") in `Core` that no contract or domain doc
  states. The comparison would silently lie if a future call ever carried a different bundle.
- It is still a product edit to 04.5's file, so it is rework.
- The App-side variant (a manual `==` excluding `runState`) would put equality semantics over `Core` state in
  the render layer, which is an I14 smell.
- **Rejected.**

## 3 Ruling

**Option B.** `DoorRunState` stays exactly as shipped (`MapLaunch.swift:296-299`, non-`Equatable`).

- 04.5's spec is corrected to match it.
- 04.5's T6 compares `continueAfterAnswer`'s result field-wise.
- 04.8 and 04.9 drop `: Equatable` from `DoorBStartOutcome`, `DoorAStartOutcome` and `DoorBRunSnapshot`.
- 04.8 and 04.9 correct their quote of `DoorRunState`.

No contract changes. No D-number is touched, so this is not a Q5.

## 4 Owning tasks and landing plan

| Where | What | Kind |
|---|---|---|
| 04.5 spec (`tasks/epic-04-task-05-…md`) | §4.1 literal re-anchored to the shipped code; §5 T6 re-worded field-wise; one §6 default added | Spec alignment by the orchestrator. **No `fix:` commit, no product rework.** |
| 04.5 tester (in flight) | Implements T6 per the re-anchored wording (§5.1 E2 below). No product file is touched. | Part of 04.5's own test commit. |
| 04.8 and 04.9 specs | Edits §5.2 and §5.3 below | Spec edits by the orchestrator, **before 04b dispatch**. The substitutions are mechanical and change no behaviour, so re-review is at the orchestrator's discretion (same rule as 03.13b §8). |

**04a's wrap (04.6) does not wait for a fix commit**: there is none. It waits only for 04.5's tester
commit, as normal. The orchestrator must relay E2 to the tester **before** the tester commits T6. If the
tester has already written `#expect(a == b)` over a `DoorRunState`, that line does not compile and must be
replaced per E2. A retroactive `extension DoorRunState: Equatable` in a test file is **forbidden**, because it
would reintroduce the reversed design choice through the back door (E3).

## 5 Exact edits (old → new)

### 5.1 `tasks/epic-04-task-05-core-door-entries-persistence-seam.md`

**E1 — §4.1 literal (line 583).**

- Old: `public struct DoorRunState: Equatable {`
- New: `public struct DoorRunState {`

Then append this paragraph directly after the closing code fence of §4.1 (after line 587):

> `DoorRunState` declares no `Equatable`: its `map: MapState` field is not `Equatable`, because
> `ContentBundle` is not (`BundleIO.swift:8`), a deliberate EPIC 03 choice
> (`tasks/epic-03-task-07-map-actions-facade-launch.md` §4.1: "every test asserts on individual fields").
> Tests compare a `DoorRunState` field-wise (`map.state`, `map.viewModel`, `map.queuedNodeId`, `map.stateURL`,
> and `expedition` via `@testable import Core`) — `tasks/arbitration/arbiter-04-doorrunstate-equatable.md`.

**E2 — §5 T6, first bullet (lines 871–873).**

Old:

> - `continueAfterAnswer`/`continueAfterProbeAnswer` called twice on the same `Equatable`-equal pending value
>   return `Equatable`-equal results, and neither call's file bytes at `stateURL` differ from before either call
>   (no write, called twice).

New:

> - `continueAfterAnswer` called twice on the same `Equatable`-equal pending value and the same input
>   `DoorRunState` returns results whose `screen` values are `==` and whose `runState` values agree field by
>   field: `runState.map.state`, `runState.map.viewModel`, `runState.map.queuedNodeId`, `runState.map.stateURL`
>   and `runState.expedition` (reachable via `@testable import Core`) are each `==`. `DoorRunState` and `MapState`
>   are not `Equatable` (§4.1), so there is no whole-value `==`. `continueAfterProbeAnswer` called twice returns
>   `==` `DoorADiagnosisScreen` values. Neither function changes the file bytes at `stateURL` from before either
>   call (no write, called twice).
>   - Instrument: Swift Testing `#expect` in `DoorEntriesTests.swift` or `DoorFacadeSeamTests.swift`. It
>     excludes a physical device (D29).
>   - Negative control: the same five-field comparison, applied to one `continueAfterAnswer` result and the
>     `DoorRunState` returned by the *preceding* `answer` call, finds at least one differing field
>     (`runState.map.state` or `runState.expedition`). This proves the comparison can go red.

**E3 — §6, append one decision default.**

> - IF a test needs to compare two `DoorRunState` (or `MapState`) values THEN it compares them field-wise per
>   §4.1 — never by adding `Equatable` to `DoorRunState`, `MapState` or `ContentBundle`, in product code or via a
>   retroactive `extension … : Equatable` in a test file (per 03.7 §4.1's recorded choice;
>   `tasks/arbitration/arbiter-04-doorrunstate-equatable.md`).

### 5.2 `tasks/epic-04-task-08-app-expedition-screens.md`

**E4 — §3 quote (line 338).**

- Old: `public struct DoorRunState: Equatable {`
- New: `public struct DoorRunState {`

**E5 — §4.8 (line 698).**

- Old: `struct DoorBStartOutcome: Equatable {`
- New: `struct DoorBStartOutcome {`

**E6 — §4.9 (line 791).**

- Old: `struct DoorBRunSnapshot: Equatable {`
- New: `struct DoorBRunSnapshot {`

Leave `enum DoorBPhase: Equatable {` (line 786) unchanged. Its payloads are `Equatable` Core types.

**E7 — §2 file-scope bullet for `MapActionsView.swift` (line 155).**

- Old: `(a new \`Equatable\` struct added to this same file)`
- New: `(a new plain struct added to this same file — not \`Equatable\`: it holds a \`DoorRunState\`, which is not \`Equatable\`, 04.5 §4.1)`

**E8 — §5 T6 (lines 1031–1033).**

- Old: ``returns `Equatable`-equal results, so this task's rendering re-derives the identical screen either way;``
- New: ``returns `==` `DoorBScreen` values (04.5 T6 compares the accompanying `DoorRunState` field-wise, since it is not `Equatable`), so this task's rendering re-derives the identical screen either way;``

**E9 — §6, append one decision default.**

> - IF an App-side struct or enum holding a `DoorRunState` or `MapState` (`DoorBStartOutcome`,
>   `DoorBRunSnapshot`) seems to want `Equatable` THEN it does not declare it. `DoorRunState` is not `Equatable`
>   (04.5 §4.1), nothing in this task compares these values (`fullScreenCover` binds on
>   `doorHolder.current != nil`; `@Observable` needs no conformance), and a hand-written `==` over `Core` state
>   would put equality semantics in the render layer (I14). Per
>   `tasks/arbitration/arbiter-04-doorrunstate-equatable.md`.

### 5.3 `tasks/epic-04-task-09-app-diagnosis-screens.md`

**E10 — §3 quote (line 409).**

- Old: `public struct DoorRunState: Equatable {`
- New: `public struct DoorRunState {`

**E11 — §3 quote of 04.8's code (line 479).**

- Old: `struct DoorBRunSnapshot: Equatable {`
- New: `struct DoorBRunSnapshot {`

**E12 — §4.5 (line 804).**

- Old: `struct DoorAStartOutcome: Equatable {`
- New: `struct DoorAStartOutcome {`

**E13 — §4.6 (line 844).**

- Old: `struct DoorBRunSnapshot: Equatable {`
- New: `struct DoorBRunSnapshot {`

Leave `enum DoorBPhase: Equatable {` (lines 474 and 856) unchanged.

**E14 — §2 file-scope bullet (line 190).**

- Old: `(a new \`Equatable\` struct added to this`
- New: `(a new plain struct — not \`Equatable\`, it holds a \`DoorRunState\` (04.5 §4.1) — added to this`

**E15 — §5 T5 guard prose (line 1117).**

- Old: ``The declaration `struct DoorBRunSnapshot:`, the parameter``
- New: ``The declaration `struct DoorBRunSnapshot {`, the parameter``

Guard (a)'s pattern `DoorBRunSnapshot\(` still never matches the declaration, so the count of 10 is
unchanged.

**E16 — §6, append the same decision default as E9, with `DoorAStartOutcome` added to its type list.**

### 5.4 Not to edit

- The `DoorBSession: Equatable` text at 04.8:1009 and 04.9:1089-1090 quotes a prior draft as the
  negative-control fixture of the Session-identifier scan. It is never compiled, and quoting it is correct.
- `tasks/epic-04-task-10-app-sources-door-scan.md` quotes `DoorFacade` signatures only, with no `DoorRunState`
  declaration (a grep for `DoorRunState: Equatable` returns 0), so it needs no edit.
- The context bundles under `tasks/context/` contain no `DoorRunState: Equatable` and no `Equatable`
  declaration of the three App types (a grep over all of `tasks/` returns only the spec hits in F2/F9/F10).
- No product code. No contract.

### 5.5 Post-edit verification (orchestrator)

1. `rg -n "DoorRunState: Equatable|struct (DoorBStartOutcome|DoorAStartOutcome|DoorBRunSnapshot): Equatable" tasks/epic-04-task-0*.md`
   returns **0 lines**.
   - Empty = PASS.
   - The instrument is live: before the edits it returns exactly **8 lines**: 04.5:583, 04.8:338, 698 and 791,
     and 04.9:409, 479, 804 and 844.
2. `rg -n "enum DoorBPhase: Equatable" tasks/epic-04-task-0{8,9}-*.md` still returns **3 lines** (04.8:786,
   04.9:474 and 856). This is the negative control that the edit was surgical.
3. After 04.5's tester commit: `rg -n "extension (DoorRunState|MapState|ContentBundle)" Packages/` returns
   **0 lines** (E3). Empty = PASS.

## 6 Resolution record

| # | Claim | Classification |
|---|---|---|
| 1 | 04.5 §4.1's `DoorRunState: Equatable` does not compile. | VALID. The spec is re-anchored to the shipped code (E1). |
| 2 | 04b's App types need `DoorRunState: Equatable`. | VALID as a compile fact, INVALID as a need. No consumer exists (F11/F12), so the conformance is removed (E4–E16). |
| 3 | 04.5 T6 depends on `DoorRunState ==` (found in this run). | VALID. Re-anchored field-wise with a negative control (E2). |
| 4 | The fix requires a product change (Option A). | INVALID. No consumer needs it, and it reverses 03.7 §4.1 and 03.4 T6 (F7/F8). |
