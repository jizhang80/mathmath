# Task 03.3 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: core-error-surface-text-mirror
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- **Epic:** 03 (map core)
- **Task:** 03.3
- **Slug:** core-error-surface-text-mirror
- **Summary:** `CoreError` gains three new cases: `PLATFORM_STATE_UNREADABLE`, `PLATFORM_STATE_WRITE_FAILED`, and `PLATFORM_SNAPSHOT_REFUSED`. A Core `userText` table mirrors every student-surface code's registered text (nil for internal and owner codes). Implement a parity test against `contracts/error-codes.json` with a planted-mismatch negative control.
- **Invariants in play:** I14 (Core imports Foundation only; L0 and layout exist once in Core)

## §B. Applicable contract rules (verbatim)

### contracts/error-codes.md — § Rules

> - Prefixes are fixed per domain: `MAP`, `EXP`, `DIAG`, `GRAPH`, `LO`, `SPINE`, `GEN`, `PLATFORM`, `TELEM`,
>   `TIER`, `VERIFY` (M5). A code appears in exactly one domain doc and in the registry.
> - Every code declares `recoverable` (bool), `surface ∈ {internal, student, owner}` and `user_text` — the
>   student-facing sentence when `surface = student`, else `null`. Student text names a node or a situation,
>   never the student, and never contains a score (content-policy voice).
> - `Core` defines `enum CoreError: String` mirroring the `GRAPH`, `EXP`, `MAP` (validation) and `DIAG`
>   codes; the App and the pipeline each map their own. A code raised in code but absent from the registry
>   fails the round-trip test.
> - Internal codes never reach a student surface; a `student` code always has a next action in its text.
> - `GRAPH_L0_FAILED` carries the failing rule ids from `graph-constraints.md` in `details`.

Source: `contracts/error-codes.md:9–19`
Binds this task: Defines the registry structure, surface-level categories, and the principle that `CoreError` mirrors the registry.

### contracts/README.md — error-codes enforcement row

> | [`error-codes.md`](error-codes.md) + [`error-codes.json`](error-codes.json) | locked (additive) | test: registry ⇔ domain docs round-trip (`test_contracts.py`); type system: `Core` error enum mirrors the registry (EPIC-time) | every code, its domain, recoverability, user-facing text policy |

Source: `contracts/README.md:18`
Binds this task: The error-codes contract is locked and additive; `CoreError` enum must mirror the registry; a round-trip test (Swift, EPIC-time) must verify the mirror.

### CLAUDE.md — I14 (Core imports Foundation only; L0 and layout exist once)

> I14 | **`Core` is renderer-free and single-source**: `Core` imports Foundation only; the render layer never computes state; L0 and layout exist once, in `Core`. A test asserts the import boundary. | D33, D42

Source: `CLAUDE.md` (system rules table)
Binds this task: `CoreErrorText.swift` must be implemented in `Core` (Foundation only, value-typed, testable); no SwiftUI/UIKit imports. The parity test runs in `CoreTests`.

## §C. Relevant domain-doc excerpts

Not applicable. This task implements a data table in `Core`; domain-specific content (platform, expedition, diagnosis operations) are defined elsewhere and reflected in the registry.

## §D. Prior task outputs this task depends on

- **Task 03.2** produces one registry entry: `PLATFORM_SNAPSHOT_REFUSED`. 
  - Exact entry (per `tasks/arbitration/arbiter-03-predispatch.md` § Q-C, lines 145–147):
  ```json
  {"code": "PLATFORM_SNAPSHOT_REFUSED", "recoverable": false, "surface": "student", "user_text": "The map could not be loaded from this copy of the app; reinstall the app to fix it."}
  ```
  - Source: `tasks/arbitration/arbiter-03-predispatch.md:143–147`
  - This entry is not yet in `contracts/error-codes.json`; task 03.2 adds it before task 03.3 runs.

## §E. Negative facts (confirmed ABSENT)

- **CoreErrorText.swift** — confirmed absent. Glob `Packages/Core/Sources/Core/CoreErrorText.swift` empty.
- **ErrorUserTextParityTests.swift** — confirmed absent. Glob `Packages/Core/Tests/CoreTests/ErrorUserTextParityTests.swift` empty.
- **PLATFORM_SNAPSHOT_REFUSED in contracts/error-codes.json** — confirmed absent (as of the current state). It appears only in the arbiter ruling text and will be added by task 03.2.
- **The three new CoreError cases** — confirmed absent in current `Packages/Core/Sources/Core/CoreError.swift` (lines 1–28): no `platformStateUnreadable`, `platformStateWriteFailed`, or `platformSnapshotRefused` case.

## §F. File scope

- **MODIFY** `Packages/Core/Sources/Core/CoreError.swift` — Add three cases: `case platformStateUnreadable = "PLATFORM_STATE_UNREADABLE"`, `case platformStateWriteFailed = "PLATFORM_STATE_WRITE_FAILED"`, `case platformSnapshotRefused = "PLATFORM_SNAPSHOT_REFUSED"`. Current state: 17 cases (lines 10–28). Only this task writes this file in EPIC 03a (per `docs/plans/epic-03-plan.md` planner note, line 130).
- **CREATE** `Packages/Core/Sources/Core/CoreErrorText.swift` — A struct (or enum) holding a static `userText` dictionary that maps student-surface error codes to their `user_text` values from the registry, and `nil` for internal and owner codes. Must be Foundation-only and testable.
- **CREATE** `Packages/Core/Tests/CoreTests/ErrorUserTextParityTests.swift` — Test suite using Swift Testing (`import Testing`), reading `contracts/error-codes.json` at test time via `#filePath` (the pattern established in `ErrorRegistryTests`), asserting:
  1. Every code with `surface: "student"` in the registry has a corresponding non-nil entry in the `userText` table.
  2. Every entry in `userText` table has `surface: "student"` in the registry (no orphans).
  3. All `user_text` values match the registry exactly.
  4. A planted mismatch (e.g., a hardcoded typo in one entry) fails the test (negative control).
  5. Empty registry read or empty `userText` dictionary is a FAIL.

## §G. Stack constraints relevant here

### Language and imports
- **Swift 6, strict concurrency (`complete`)**: `Packages/Core/Sources/Core/CoreErrorText.swift` must run on iOS/iPadOS 18.0+.
- **Foundation only**: I14 binds; no SwiftUI, UIKit, Combine, or third-party imports in `Core`.

### Test framework
- **Swift Testing** (`import Testing`) for the parity test in `CoreTests`, matching the pattern in `ErrorRegistryTests.swift` (lines 1–41 of the current file).

### Registry location and schema
- **Normative source**: `contracts/error-codes.json` (locked, additive changes only). The test reads this file at runtime using `#filePath`-based path navigation (same pattern as `ErrorRegistryTests`, lines 20–26).
- **Student-surface codes to mirror** (from `contracts/error-codes.json`):
  - `MAP_MARKER_OFF_TRAIL` (line 11): "The marker stays where it was; pick a unit from the list."
  - `EXP_NO_FRINGE` (line 14): "You've cleared everything up to here. Move your class marker forward, or explore the map."
  - `EXP_STATE_WRITE_FAILED` (line 17): "Your progress could not be saved just now; it will be retried."
  - `DIAG_NO_PREREQUISITE` (line 20): "Nothing upstream to check — here's a hint."
  - `DIAG_PROBE_UNAVAILABLE` (line 21): "No quick check is available for this one yet; here's a hint instead."
  - `DIAG_STATE_WRITE_FAILED` (line 22): "Your progress could not be saved just now; it will be retried."
  - `PLATFORM_BUNDLE_FETCH_FAILED` (line 48): "Could not refresh content; still using the installed version."
  - `PLATFORM_BUNDLE_INTEGRITY_FAILED` (line 49): "Could not refresh content; still using the installed version."
  - `PLATFORM_STATE_UNREADABLE` (line 51): "Earlier progress could not be read; it has been kept."
  - `PLATFORM_STATE_WRITE_FAILED` (line 50): internal — no `user_text` entry
  - `VERIFY_CAS_UNAVAILABLE` (line 65): "The checker could not start."
  - `VERIFY_PARSE_FAILED` (line 66): "This step could not be read; please re-enter it."
  - `VERIFY_TIMEOUT` (line 67): "This step could not be decided in time; the rest of the check stands."
  - `VERIFY_UNSUPPORTED` (line 68): "Step checking is not available for this kind of problem; the answer is shown."
  - `PLATFORM_SNAPSHOT_REFUSED` (to be added by task 03.2, exact text: "The map could not be loaded from this copy of the app; reinstall the app to fix it.")

Source: `contracts/error-codes.json:8–70` (all student-surface entries extracted)

### Current CoreError state
- **Current cases** (17 total, from `Packages/Core/Sources/Core/CoreError.swift:10–28`):
  - `graphL0Failed = "GRAPH_L0_FAILED"`
  - `mapLayoutMissing = "MAP_LAYOUT_MISSING"`
  - `mapRegionUnknown = "MAP_REGION_UNKNOWN"`
  - `mapLandmarkUnsourced = "MAP_LANDMARK_UNSOURCED"`
  - `spineUnitEmpty = "SPINE_UNIT_EMPTY"`
  - `spineSourceRefUnresolved = "SPINE_SOURCE_REF_UNRESOLVED"`
  - `platformBundleIntegrityFailed = "PLATFORM_BUNDLE_INTEGRITY_FAILED"`
  - `expNoFringe = "EXP_NO_FRINGE"`
  - `expTrailInvalid = "EXP_TRAIL_INVALID"`
  - `expItemPoolEmpty = "EXP_ITEM_POOL_EMPTY"`
  - `expStateWriteFailed = "EXP_STATE_WRITE_FAILED"`
  - `expNodeNotInGraph = "EXP_NODE_NOT_IN_GRAPH"`
  - `diagNoPrerequisite = "DIAG_NO_PREREQUISITE"`
  - `diagProbeUnavailable = "DIAG_PROBE_UNAVAILABLE"`
  - `diagStateWriteFailed = "DIAG_STATE_WRITE_FAILED"`
  - `graphNoPrerequisite = "GRAPH_NO_PREREQUISITE"`
  - `mapMarkerOffTrail = "MAP_MARKER_OFF_TRAIL"`
- **Cases to add by this task**: `platformStateUnreadable`, `platformStateWriteFailed`, `platformSnapshotRefused`.
- **Registry codes NOT yet mirrored in CoreError but present in registry**: (owner/internal only, not required for this task) `PLATFORM_BUNDLE_FETCH_FAILED`, `PLATFORM_SYNC_UNAVAILABLE`, `VERIFY_*` codes, `SPINE_PARSE_INCOMPLETE`, `SPINE_PARAPHRASE_REJECTED`, `SPINE_VERBATIM_TEXT_DETECTED`, `LO_*` codes, `GEN_*` codes, `TELEM_*` codes, `TIER_*` codes, `GRAPH_NO_PREREQUISITE` is in CoreError.

### Test pattern and framework
- **Registry read pattern**: Use the `#filePath`-based path navigation from `ErrorRegistryTests.swift` (lines 20–26). The pattern navigates from the test file location up to the repo root, then to `contracts/error-codes.json`.
- **Test obligations**:
  1. Assert `!registryCodes.isEmpty` (empty registry read is a FAIL).
  2. Assert `!CoreErrorText.userText.isEmpty` (empty userText dictionary is a FAIL).
  3. For each `(code, entry)` in the registry with `surface: "student"`, verify `userText[code] != nil` and the text matches exactly.
  4. For each `(code, text)` in `userText`, verify the registry contains a matching `student`-surface entry.
  5. Plant a negative control: include a hardcoded mismatch in the test (e.g., `userText["FAKE_TEST_MISMATCH"] = "This is a planted failure"`) and verify the test catches it.
  6. No entry in `userText` for `internal` or `owner` codes (must be `nil` or absent from the dictionary).

### Architectural notes
- **CoreErrorText location**: `Packages/Core/Sources/Core/CoreErrorText.swift`, alongside `CoreError.swift`. It is Foundation-only, value-typed, and testable against the temp JSON read in the test.
- **Error registry completeness**: The test inherits the obligation from `ErrorRegistryTests` that `CoreError.allCases ⊆ registry codes`; this new test adds the obligation that every `student`-surface code ⊆ `CoreErrorText.userText`.

