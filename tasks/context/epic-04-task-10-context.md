# Task 04.10 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: app-sources-door-scan
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- **Epic:** 04
- **Task:** 10 (sub-EPIC 04b)
- **Slug:** app-sources-door-scan
- **Summary:** extends 03.9's App/Sources boundary scan with new Door rule classes (a–g per spec scope), widens the call allow-list by exactly the 04.5 entry points, and ships negative-control tests for each new rule class. The scan enforces I1, I2, I10, I14 at the App ↔ Core boundary, preventing Door views from calling Core-internal Door types or re-implementing any Door logic. Never widens import exceptions; the 03.9 SwiftMath carve-out is deleted by 03.12, not this task.
- **Invariants in play:** I1 (step correctness via CAS only), I2 (Tier 0 only, no model imports), I10 (numeric keypad or choice taps only, no OCR), I14 (Core is renderer-free, render layer never computes state, test asserts boundary).

## §B. Applicable contract rules (verbatim)

Only the rules this task must conform to. For each, a verb phrase naming how this task binds it.

### CLAUDE.md — Hard invariants table, I1

> **Wherever step verification exists, step correctness is decided by CAS, never by a language model.** No code path lets a model output decide whether a step or a probe answer is right; expedition items are checked deterministically in code.

Source: `CLAUDE.md:24` (read and byte-compared this run)
Binds this task: the scan must fail on any `ItemChecker` call or comparison against answer/correct_choice_id in `App/Sources`, preventing the render layer from re-implementing check logic (negative control planted).

### CLAUDE.md — Hard invariants table, I2

> **Tier 0 alone must be a usable product**: every model call has a confidence threshold and a deterministic fallback; the system never guesses a diagnosis.

Source: `CLAUDE.md:25` (read and byte-compared this run)
Binds this task: the scan must fail on any `FoundationModels` import in `App/Sources` (negative control planted), ensuring no model-calling path enters the render layer.

### CLAUDE.md — Hard invariants table, I10

> **Input is defined per door**: expedition items are numeric or multiple-choice; homework mode uses a structured math editor; **no OCR in any door.**

Source: `CLAUDE.md:33` (read and byte-compared this run)
Binds this task: the scan must fail on any `TextField`/`TextEditor` bound to an "answer"-named value, and on any `Vision`/`VisionKit`/`PencilKit` import, preventing free-text entry and camera/handwriting input in `App/Sources` (negative controls planted).

### CLAUDE.md — Hard invariants table, I14

> **`Core` is renderer-free and single-source**: `Core` imports Foundation only; the render layer never computes state; L0 and layout exist once, in `Core`. A test asserts the import boundary.

Source: `CLAUDE.md:37` (read and byte-compared this run)
Binds this task: the scan is exactly this test. It must fail on: direct `ExpeditionRun`/`DiagnosisRun`/`Expedition` calls in `App/Sources` (I14's co-owner clause from 03.9 § 1: "the App must not call... `Expedition`, `ExpeditionRun`, `DiagnosisRun`... directly"), and on any Door view button action that is not exactly one allow-listed façade call from 04.5 (negative control: empty match over Door buttons = FAIL).

### docs/tech-stack.md — §1 Choices table, Math display row

Per task 03.9 spec §3 (read and byte-compared there):
> **SwiftMath**, imported only by the `Packages/Rendering` package

Source: `docs/tech-stack.md:1` (quoted via 03.9 spec, not re-read this session)
Binds this task: the scan's import allow-list never admits `SwiftMath` to `App/Sources`. The 03.9 SwiftMath carve-out (path-scoped to top-level `ContentView.swift`) is deleted by 03.12, so this task works against a tree with no exception active.

## §C. Relevant domain-doc excerpts (verbatim)

The operations and constraints this task enforces, from the domain docs and the brief.

### docs/domains/map.md § Invariants enforced here

From task 03.9 spec §3 (read and byte-compared there):
> - **I14 — co-owner.** `MapViewModel` derivation lives in `Core`; the SwiftUI/`Canvas` layer imports it and computes nothing; a test asserts `Core` has no SwiftUI, UIKit or SpriteKit import (D33).

Source: `docs/domains/map.md:131-132` (cited via 03.9 spec)
This task extends that test to the Door render layer (App/Sources Door views).

### docs/epics/epic-04-app-expedition-diagnosis-acceptance.md § 4 items 7 and 8

Item 7 — **Input (I10)**: the keypad key set (a `Core` constant) types every `numeric` `answer.value` in `data/demo`. An `mc` answer is submitted as the choice id. **The extended `App/Sources` scan is green, and its planted violations fail it:** a free-text answer field, a direct `ItemChecker`/`ExpeditionRun`/`DiagnosisRun` call, a Vision/PencilKit import, and a model-framework import.

Item 8 — **C1 seam — App ↔ `Core` state transitions**: the App build is green; **every Door button's action is exactly one façade call (source scan over the Door view files, with a negative control)**; the `Core` tests of items 1 and 2 drive the same façade entry points the buttons call; the render side of the seam is evidenced by logic, composition and static wiring only. The 04b task specs and the acceptance report state verbatim what it cannot claim (arbiter-04 § Q-C): (1) that any tap on a simulator actually fires its action; (2) that each Door screen is laid out so its controls are visible and reachable; (3) that no runtime trap occurs along the Door screens after launch; (4) that the sequence of screens a student sees matches the façade's screen values at runtime, rather than only in `CoreTests` (C3; §9 Q-C).

Source: `docs/epics/epic-04-app-expedition-diagnosis-acceptance.md:388-402` (read and byte-compared this run)
This task delivers the "extended App/Sources scan" and the "source scan over the Door view files" parts of both items, with planted negative controls for the new violation classes.

### docs/plans/epic-04-plan.md § 04.10

> **04.10:** extends 03.9's App/Sources scan with the Door rules and widens the allow-list by exactly the 04.5 entries. Each new rule class has a negative control.

Source: `docs/plans/epic-04-plan.md:78` (read and byte-compared this run)
This task's entire scope: extend 03.9's logic with new rules (Door-specific violation classes), extend the allow-list with 04.5's public entry points only, and ship negative controls for each new rule class.

### docs/plans/epic-04-plan.md § Planner notes — 04.10 runs after 04.8/04.9

> **04.10 runs after 04.8/04.9**, because its one-call-per-button rule needs real Door views. The spec writer must make sure 04.8 and 04.9 do not need allow-list entries before 04.10 adds them. Either land the allow-list widening first or merge the two steps.

Source: `docs/plans/epic-04-plan.md:91-93` (read and byte-compared this run)
Constrains implementation order: 04.8 and 04.9 must land before this task, so Door view files exist for the scan to traverse.

## §D. Prior task outputs this task depends on

Exported types, rule structures, and entry points already produced by earlier tasks that this task widens or consumes.

### From task 03.9 (tasks/epic-03-task-09-app-sources-i14-scan.md)

The scan helper and rule infrastructure (read and byte-compared):

**Rule structure:**
```swift
struct Rule {
    let name: String
    let violates: (String) -> Bool
}
```

**Rule infrastructure:**
- `AppSourcesBoundary.defaultRules: [Rule]` — the base rule set this task extends
- `AppSourcesBoundary.violations(in:rules:) -> [String]` — the scan entry point, parameterized to accept caller-supplied rules
- `AppSourcesBoundary.allowedImportModules: [String]` — the import allow-list

**File-scoped Swift Math exception (time-boxed):**
- `AppSourcesBoundary.contentViewSwiftMathExceptionFile = "ContentView.swift"` (path relative to scanned root)
- `AppSourcesBoundary.contentViewSwiftMathExceptionImport = "SwiftMath"`
- A `continue`-skip block inside `violations(in:rules:)` that matches both constants

(These are deleted by task 03.12, so this task assumes the exception is already gone and the scan is clean over the full `App/Sources` tree with no carve-out anywhere.)

**Negative-control fixture pattern:**
- Each violation class tested by a dedicated `@Test` that builds a fresh temp directory, plants exactly one violation, asserts `violations(in:)` reports it, and cleans up via `defer`. Clean-fixture and JSON-skip tests prove the filter and exclusions work.

Source: `tasks/epic-03-task-09-app-sources-i14-scan.md:§3`, `§4.2`, `§4.3`, `§4.4` (read and byte-compared this run)
Binds this task: 03.9's rule-driven walk and empty-scan=FAIL discipline must be reused; this task calls `violations(in: rules: defaultRules + doorRules)` (per plan line 78) or constructs a wider `allowedImportModules`, never editing 03.9's walk or the core-test boundary logic.

### From task 04.5 (tasks/epic-04-task-05-core-door-entries-persistence-seam.md)

**Entry points to widen the call allow-list by:**
- `DoorFacade.startExpedition(mapState:today:) -> (runState, screen, writeFailureCode, events)`
- `DoorFacade.startUnitExpedition(unitId:mapState:today:) -> (runState, screen, writeFailureCode, events)`
- `DoorFacade.answer(_:submitted:today:) -> (advance, runState, writeFailureCode)`
- `DoorFacade.continueAfterAnswer(_:runState:) -> (screen, runState)`
- `DoorFacade.resumeAfterDiagnosis(_:outcome:today:) -> (advance, runState, writeFailureCode)`
- `DoorFacade.startAnother(mapState:today:) -> (runState, screen, writeFailureCode, events)`
- `DoorFacade.backToMap(_:today:) -> (mapState, writeFailureCode)`
- `DoorFacade.checkHere(nodeId:mapState:today:) -> (runState, screen, writeFailureCode, events)`
- `DoorFacade.decideProbe(_:accept:runState:today:) -> (advance, runState, writeFailureCode)`
- `DoorFacade.answerProbeItem(_:submitted:runState:today:) -> (advance, runState, writeFailureCode)`
- `DoorFacade.continueAfterProbeAnswer(_:runState:) -> (screen, runState)`
- `DoorFacade.decideFurtherLevel(_:accept:runState:today:) -> (advance, runState, writeFailureCode)`

These are the ONLY `Core` calls 04b's Door view layer is allowed to make. Every Door button action must map exactly to one of these calls.

Source: `tasks/epic-04-task-05-core-door-entries-persistence-seam.md:§4.3`, `§4.4` (read and byte-compared this run)
Binds this task: the allow-list must be widened by exactly these 12 entry points, by no others (especially not `ExpeditionRun`, `DiagnosisRun`, `DoorBExpeditionFlow`, `DoorADiagnosisFlow` — those stay off-limits). A test (`DoorFacadeSeamTests.swift`) confirms the Door buttons call only these entry points, mirroring 03.9's AC6 (rule set is data-driven) and AC8 (façade calls don't false-positive).

### From task 03.12 (tasks/epic-03-task-12-app-shell-launch-smoke.md)

AC9 (deletion obligation):
```swift
AppSourcesBoundary.contentViewSwiftMathExceptionFile
AppSourcesBoundary.contentViewSwiftMathExceptionImport
// plus the continue-skip block in violations(in:rules:)
```

These are deleted in 03.12, so by the time 04.10 runs (after 04.8/04.9, which run after 03.12 is merged), the exception is already gone and the scan is clean over the real `App/Sources` (Door files + the original 03.10/03.11/03.12 files) with no carve-out anywhere.

Source: `tasks/epic-03-task-12-app-shell-launch-smoke.md:109-116` (read and byte-compared this run)
Binds this task: assumes the exception is deleted; this task never re-adds it or adds any other import exception.

## §E. Negative facts (confirmed ABSENT)

Things a downstream agent might assume exist but DON'T. Each verified by Grep/Glob this run.

- No 04.10 task spec exists yet. Source: Glob `tasks/epic-04-task-10-*.md` returned no match.
- The 03.9 SwiftMath import exception is assumed DELETED by 03.12 before 04.10 runs (per task 03.12 AC9). The exception constants and skip block are verified present in 03.9's spec text (read this run). This task does not re-add them.
- No `DoorFacadeSeamTests.swift` or `DoorEntriesTests.swift` exists in `Packages/Core/Tests/CoreTests` yet. Source: Glob `Packages/Core/Tests/CoreTests/Door*.swift` returned no match. These are the 04.5 test files that define what the allow-list must cover. This task's scan must match those tests' exact entry point calls.
- No Door view files (expedition/diagnosis screens) exist in `App/Sources` yet. Source: Glob `App/Sources/Door*.swift`, `App/Sources/*[Ee]xpedition*.swift`, `App/Sources/*[Dd]iagnosis*.swift` all returned no matches. Task 04.8 and 04.9 produce these files; this task runs after they land.
- No `appSources.*Scan*.md` rule documentation or prose guide exists. Source: Grep `(docs|contracts)` for `appSources.*[Ss]can|door.*scan|door.*rule` returned no contract or domain binding beyond the epic brief's AC items 7 and 8. This task invents no rule; it extends 03.9's existing rule-driven infrastructure.

## §F. File scope

Files this task may create or touch. Mark each create / modify and cite existence for modifies.

In-scope (the implementer touches EXACTLY these; nothing else):

- CREATE `Packages/Core/Tests/CoreTests/DoorAppSourcesBoundaryTests.swift` — defines `doorRules: [AppSourcesBoundary.Rule]` array with the six new violation classes (a–f), plants negative controls for each, and exercises the data-driven rule composition (extending 03.9's `defaultRules` with `doorRules`). Confirmed absent (Glob `**/DoorAppSourcesBoundaryTests.swift` returned no match).
- MODIFY `Packages/Core/Tests/CoreTests/AppSourcesBoundaryTests.swift` — widens `AppSourcesBoundary.allowedImportModules` to include `"DoorFacade"` (or constructs a new allowed-names list for the Door entry points), and adds or updates one test that asserts the real `App/Sources` (after 04.8/04.9 land) scans clean with the extended rules. Source: `tasks/epic-03-task-09-app-sources-i14-scan.md:§2` confirms this file exists (created by 03.9). The SwiftMath exception constants and skip block have been deleted by 03.12 (§D above).
- MODIFY `Packages/Core/Tests/CoreTests/AppSourcesBoundaryNegativeControlTests.swift` — adds negative-control tests for each new violation class (a–f). Source: file exists (created by 03.9).

Out-of-scope (do not touch even if tempted):

- `App/Sources/**` — read-only (read to run the scan, but never edit). Door view files are written by 04.8/04.9; this task consumes them.
- `Packages/Core/Sources/Core/Platform/MapLaunch.swift` — read-only. 04.5 writes the `DoorFacade` definitions; this task reads them to build the allow-list.
- `Packages/Core/Tests/CoreTests/DoorFacadeSeamTests.swift`, `DoorEntriesTests.swift` — 04.5's files; read-only. This task ensures its own scan matches what those tests call, but never edits them.
- `scripts/gate.sh`, `.github/workflows/ci.yml` — unchanged; this task's tests run under the existing gate 3 (`xcodebuild test -scheme Core-Package`).
- `contracts/**`, `docs/**`, `data/**` — read-only ground truth.

## §G. Stack constraints relevant here

Concrete, task-specific constraints pulled from contracts, RULES, `docs/tech-stack.md`, and prior specs:

- **Scan rules (borrowed from 03.9, extended by this task):** per 03.9 spec §4.2, one rule per violation class (`name: String`, `violates: (String) -> Bool`), applied to every line of every `.swift` file, with empty-scan = FAIL. This task adds new rules in a separate `doorRules` array; the existing `violations(in: rules:)` walk is not edited (03.9 AC6: rule set is data-driven).
- **Violation classes in scope (a–g per user request):**
  - (a) comparison against `answer` / `correct_choice_id` or any `ItemChecker` call (I1) — plant `ItemChecker.check(...)` in a test fixture
  - (b) `TextField`/`TextEditor` bound to an "answer"-named value (I10) — plant `TextField("Answer", text: $answerText)` in a test fixture
  - (c) `Vision`/`VisionKit`/`PencilKit` import (I10) — plant `import Vision` in a test fixture
  - (d) `FoundationModels` import (I2) — plant `import FoundationModels` in a test fixture
  - (e) direct `ExpeditionRun`/`DiagnosisRun`/`Expedition` calls — plant `ExpeditionRun.start(...)` in a test fixture; `ItemChecker`, `Expedition` covered under (a)/(c)
  - (f) any Door view button action that is not exactly one allow-listed façade call — this is a meta-rule applied across Door view files only, checking that every `Button(...) { ... }` or similar action closure contains exactly one `DoorFacade.someEntry(...)` call and no other state-changing calls; empty match over Door buttons = FAIL
  - (g) Door student-facing copy as string literals — this is a prose/scan rule, not a violation code (I6, I12); string literals in Door views that are user-facing (not comments, not debug) should reference `CoreErrorText` or a Core constant, never hard-coded. Plant a string like `Text("Hard-coded error")` in a Door view and the scan should flag it.

- **Allow-list widening (rule constraint):** the import allow-list gains exactly the `DoorFacade` name (or a specific allow-list for the 12 entry-point calls); no other Core type, no other import. Every `DoorFacade.*` call is allowed; direct calls to `ExpeditionRun`, `DiagnosisRun`, `DoorBExpeditionFlow`, `DoorADiagnosisFlow` are still forbidden. The scan must prove rule (f) — every Door button action is exactly one `DoorFacade.*` call.
- **Test framework:** Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`), not XCTest (confirmed by 03.9 spec §3, re-read this run).
- **Gate:** tests run under gate 3 (`Packages/Core && xcodebuild test -scheme Core-Package`). No new gate step.
- **Negative-control fixture pattern (from 03.9):** one `@Test` per violation class, each building a fresh `UUID()`-named temp directory, planting exactly that violation, asserting `violations(in:)` reports it, cleaning up via `defer`. AC4/AC5 (clean fixture, JSON skip) already exist from 03.9; this task adds parallel tests for Door rules only.
- **No model framework anywhere:** Tier 0 only (I2). Verified by a grep in the scan itself (rule d) and a negative control.
- **No re-implementation of Core logic:** I14. The scan forbids direct calls to state-transition types; the App calls only `DoorFacade`, which is the single façade wrapping `Core`'s Door logic.
- **One-call-per-button rule (brief item 8, C1 seam):** this is verified by a source-scan rule (f) that runs over real Door view files (after 04.8/04.9 land) and asserts every button action is exactly one `DoorFacade` call, never zero (FAIL) or multiple or mixing other calls.
- **Tech stack:** No new tool named in this task beyond what `docs/tech-stack.md` already specifies (Swift 6, Foundation only in `Core`). The task is a pure source-scan test in Swift.
