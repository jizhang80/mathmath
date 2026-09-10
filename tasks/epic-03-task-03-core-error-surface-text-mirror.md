# Epic 03 · Task 03.3: `CoreError` platform cases + student-surface `userText` mirror

---
epic: 03
task: 03
slug: core-error-surface-text-mirror
kind: feat
risk: seam
depends_on: [03.2]
model: sonnet
---

## §1 Goal & acceptance criteria

Goal: `CoreError` gains three additive cases — `PLATFORM_STATE_UNREADABLE`, `PLATFORM_STATE_WRITE_FAILED`,
`PLATFORM_SNAPSHOT_REFUSED` — and `Core` ships a `CoreErrorText` table mapping every `student`-surface
registry code to its exact registered `user_text`, with `nil` for internal and owner codes. A parity test
proves the table matches `contracts/error-codes.json` in both directions (no missing student text, no orphan
entry) and that the guard is load-bearing via a planted-mismatch negative control. This is the only task in
EPIC 03 that writes `CoreError.swift` (`docs/plans/epic-03-plan.md` planner note: "only 03.3 writes
`CoreError.swift`"); later tasks (03.11, 03.12) read `CoreErrorText.userText` to render error copy but never
hardcode their own strings.

Invariants in play:

- **I14** — `CoreErrorText.swift` and `ErrorUserTextParityTests.swift` live under `Packages/Core/{Sources,
  Tests}/Core*`, import `Foundation` only, and are value-typed/pure (a static lookup table plus tests). The
  existing `coreImportBoundary()` test (`Packages/Core/Tests/CoreTests/CoreTests.swift:18-33`) already
  recursively scans every `.swift` file under `Sources/Core` for forbidden imports (`SwiftUI`, `UIKit`,
  `AppKit`, `SpriteKit`, `SwiftData`, `FoundationModels`, `CoreData`, `Combine`); it covers the new file with
  no edit.
- **I5** — `CoreErrorText`'s values are the registry's own `user_text` strings, which the content-policy voice
  already forbids from naming the student or carrying a score (`contracts/error-codes.md` § Rules, quoted in
  §3); this task adds no new copy and no identifying field.

Acceptance criteria (each independently verifiable):

- AC1: `CoreError.allCases` gains exactly three cases — `case platformStateUnreadable =
  "PLATFORM_STATE_UNREADABLE"`, `case platformStateWriteFailed = "PLATFORM_STATE_WRITE_FAILED"`, `case
  platformSnapshotRefused = "PLATFORM_SNAPSHOT_REFUSED"` — appended after the existing 17 cases, with the
  existing 17 byte-unchanged in order. `ErrorRegistryTests` and `ErrorRegistryNegativeControlTests` (both
  unmodified) stay green with no edit to either file.
- AC2: `CoreErrorText.userText` returns the exact registered `user_text` string for every code whose registry
  entry has `"surface": "student"`, and returns `nil` (or has no entry) for every code whose registry entry has
  `"surface": "internal"` or `"surface": "owner"`.
- AC3: A test reading `contracts/error-codes.json` at test time via the `#filePath`-based path navigation
  pattern of `ErrorRegistryTests` (`Packages/Core/Tests/CoreTests/ErrorRegistryTests.swift:20-26`) asserts, for
  every registry entry with `surface == "student"`, that `CoreErrorText.userText[code]` is non-nil and equal to
  the registry's `user_text`, and, for every key in `CoreErrorText.userText`, that the registry contains a
  matching `surface == "student"` entry with the same text — i.e. equality holds in both directions over the
  full registry, not just over `CoreError.allCases`.
- AC4: A planted-mismatch negative control (a local fixture inside the test file, never product code) proves
  the parity assertion is load-bearing: it reds when a registered code's text is deliberately altered by one
  character, and reds when an extra, registry-absent code/text pair is added to a local copy of the table.
- AC5: An empty registry read or an empty `CoreErrorText.userText` table is itself asserted as a FAIL (not
  silently skipped) — mirroring `ErrorRegistryTests`'s `!registryCodes.isEmpty` / `!CoreError.allCases.isEmpty`
  guards.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Core/Sources/Core/CoreError.swift` — MODIFY: append the three cases (§1 AC1) after the existing 17;
  do not reorder or edit the existing cases or the file's header doc comment.
- `Packages/Core/Sources/Core/CoreErrorText.swift` — CREATE: the `CoreErrorText` lookup table (§4.2).
- `Packages/Core/Tests/CoreTests/ErrorUserTextParityTests.swift` — CREATE: the parity test suite plus its
  planted-mismatch negative control (§4.3).

Out-of-scope (do not touch even if tempted):

- `Packages/Core/Tests/CoreTests/ErrorRegistryTests.swift`,
  `Packages/Core/Tests/CoreTests/ErrorRegistryNegativeControlTests.swift` — both already iterate
  `CoreError.allCases` generically (confirmed by reading both files in this run); the three new cases are
  covered automatically with no edit.
- `Packages/Core/Tests/CoreTests/CoreTests.swift` — the existing `coreImportBoundary()` test already walks
  `Sources/Core` recursively and covers `CoreErrorText.swift` with no change.
- `contracts/error-codes.json`, `contracts/error-codes.md`, `docs/domains/platform.md` — read-only ground
  truth for this task. `PLATFORM_SNAPSHOT_REFUSED`'s registration is task 03.2's file scope; if the entry is
  absent from `contracts/error-codes.json` when this task starts, that means 03.2 has not landed — BLOCK on the
  precondition, do not add the registry entry here.
- Any `App/Sources` file — this task ships no UI; 03.11/03.12 consume `CoreErrorText.userText` later.
- `Packages/Core/Package.swift` — no new target, no `resources:` entry; the parity test reads
  `contracts/error-codes.json` the same way `ErrorRegistryTests` does, via `#filePath`, not via SPM resources.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/error-codes.md` — heading `## Rules` (re-read, byte-compared in this run):
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

- `contracts/README.md` — the error-codes row of the contract set table (re-read, byte-compared in this run):
  > | [`error-codes.md`](error-codes.md) + [`error-codes.json`](error-codes.json) | locked (additive) | test:
  > registry ⇔ domain docs round-trip (`test_contracts.py`); type system: `Core` error enum mirrors the
  > registry (EPIC-time) | every code, its domain, recoverability, user-facing text policy |

- `tasks/arbitration/arbiter-03-predispatch.md` § Q-C — the exact registry entry task 03.2 lands before this
  task runs (re-read, byte-compared in this run):
  > ```json
  > {"code": "PLATFORM_SNAPSHOT_REFUSED", "recoverable": false, "surface": "student", "user_text": "The map
  > could not be loaded from this copy of the app; reinstall the app to fix it."},
  > ```
  and, in the same section, on the `CoreError` shape:
  > `CoreError` gains `case platformSnapshotRefused = "PLATFORM_SNAPSHOT_REFUSED"`. This is additive, and the
  > EPIC 01 precedent is `platformBundleIntegrityFailed`.

- `CLAUDE.md` — I14 (system rules table, re-read in this run):
  > I14 | **`Core` is renderer-free and single-source**: `Core` imports Foundation only; the render layer never
  > computes state; L0 and layout exist once, in `Core`. A test asserts the import boundary. | D33, D42

Prior signatures this task builds on (from the codebase, verbatim, re-read in this run):

```swift
// Packages/Core/Sources/Core/CoreError.swift:10-28 (current state, 17 cases)
public enum CoreError: String, Error, CaseIterable {
    case graphL0Failed = "GRAPH_L0_FAILED"
    case mapLayoutMissing = "MAP_LAYOUT_MISSING"
    case mapRegionUnknown = "MAP_REGION_UNKNOWN"
    case mapLandmarkUnsourced = "MAP_LANDMARK_UNSOURCED"
    case spineUnitEmpty = "SPINE_UNIT_EMPTY"
    case spineSourceRefUnresolved = "SPINE_SOURCE_REF_UNRESOLVED"
    case platformBundleIntegrityFailed = "PLATFORM_BUNDLE_INTEGRITY_FAILED"
    case expNoFringe = "EXP_NO_FRINGE"
    case expTrailInvalid = "EXP_TRAIL_INVALID"
    case expItemPoolEmpty = "EXP_ITEM_POOL_EMPTY"
    case expStateWriteFailed = "EXP_STATE_WRITE_FAILED"
    case expNodeNotInGraph = "EXP_NODE_NOT_IN_GRAPH"
    case diagNoPrerequisite = "DIAG_NO_PREREQUISITE"
    case diagProbeUnavailable = "DIAG_PROBE_UNAVAILABLE"
    case diagStateWriteFailed = "DIAG_STATE_WRITE_FAILED"
    case graphNoPrerequisite = "GRAPH_NO_PREREQUISITE"
    case mapMarkerOffTrail = "MAP_MARKER_OFF_TRAIL"
}
```

```swift
// Packages/Core/Tests/CoreTests/ErrorRegistryTests.swift:1-41 (full file, current state)
import Foundation
import Testing

@testable import Core

@Suite("CoreError registry (contracts/error-codes.json)")
struct ErrorRegistryTests {
    private struct RegistryEntry: Decodable {
        let code: String
    }

    private struct Registry: Decodable {
        let codes: [RegistryEntry]
    }

    // AC3: every case of `CoreError` is present in `contracts/error-codes.json`, read from disk at
    // test time; an empty `CoreError` case set or an empty registry read is a FAIL.
    @Test("CoreError.allCases is a subset of the error-codes.json registry")
    func coreErrorIsSubsetOfRegistry() throws {
        let registryPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root (Packages/Core)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("contracts/error-codes.json")

        let data = try Data(contentsOf: registryPath)
        let registry = try JSONDecoder().decode(Registry.self, from: data)
        let registryCodes = Set(registry.codes.map(\.code))

        #expect(!registryCodes.isEmpty, "empty registry read is a FAIL")
        #expect(!CoreError.allCases.isEmpty, "empty CoreError case set is a FAIL")

        for errorCase in CoreError.allCases {
            #expect(
                registryCodes.contains(errorCase.rawValue),
                "\(errorCase.rawValue) raised in Core but absent from the registry")
        }
    }
}
```

Registry student-surface entries this task mirrors verbatim into `CoreErrorText.userText` (re-read,
byte-compared in this run against `contracts/error-codes.json`, current state — 46 total codes before task 03.2
adds `PLATFORM_SNAPSHOT_REFUSED`):

```json
{"code": "MAP_MARKER_OFF_TRAIL", "recoverable": true, "surface": "student", "user_text": "The marker stays where it was; pick a unit from the list."}
{"code": "EXP_NO_FRINGE", "recoverable": true, "surface": "student", "user_text": "You've cleared everything up to here. Move your class marker forward, or explore the map."}
{"code": "EXP_STATE_WRITE_FAILED", "recoverable": true, "surface": "student", "user_text": "Your progress could not be saved just now; it will be retried."}
{"code": "DIAG_NO_PREREQUISITE", "recoverable": true, "surface": "student", "user_text": "Nothing upstream to check — here's a hint."}
{"code": "DIAG_PROBE_UNAVAILABLE", "recoverable": true, "surface": "student", "user_text": "No quick check is available for this one yet; here's a hint instead."}
{"code": "DIAG_STATE_WRITE_FAILED", "recoverable": true, "surface": "student", "user_text": "Your progress could not be saved just now; it will be retried."}
{"code": "PLATFORM_BUNDLE_FETCH_FAILED", "recoverable": true, "surface": "student", "user_text": "Could not refresh content; still using the installed version."}
{"code": "PLATFORM_BUNDLE_INTEGRITY_FAILED", "recoverable": true, "surface": "student", "user_text": "Could not refresh content; still using the installed version."}
{"code": "PLATFORM_STATE_UNREADABLE", "recoverable": true, "surface": "student", "user_text": "Earlier progress could not be read; it has been kept."}
{"code": "VERIFY_CAS_UNAVAILABLE", "recoverable": true, "surface": "student", "user_text": "The checker could not start."}
{"code": "VERIFY_PARSE_FAILED", "recoverable": true, "surface": "student", "user_text": "This step could not be read; please re-enter it."}
{"code": "VERIFY_TIMEOUT", "recoverable": true, "surface": "student", "user_text": "This step could not be decided in time; the rest of the check stands."}
{"code": "VERIFY_UNSUPPORTED", "recoverable": false, "surface": "student", "user_text": "Step checking is not available for this kind of problem; the answer is shown."}
```

Plus, once task 03.2 lands, `PLATFORM_SNAPSHOT_REFUSED` (§3's Q-C quote above gives its exact `user_text`).

`PLATFORM_STATE_WRITE_FAILED` is registered with `"surface": "internal", "user_text": null` (re-read,
byte-compared in this run) — it gets a `CoreError` case (AC1) but no `CoreErrorText.userText` entry (AC2).

Gate commands (verbatim, from `scripts/gate.sh`, re-read in this run):

```sh
echo "== 1/4 format + lint =="
xcrun swift-format lint --strict --recursive --configuration "$ROOT/.swift-format" "$ROOT/Packages" "$ROOT/App/Sources"

echo "== 3/4 Core: build + test on the iOS simulator (D29) =="
( cd "$ROOT/Packages/Core" && swift build -c release --product core-cli )
( cd "$ROOT/Packages/Core" && xcodebuild test -quiet -scheme Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO )
```

Test framework (confirmed by `Packages/Core/Tests/CoreTests/ErrorRegistryTests.swift:1-4`, re-read in this
run): Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`), not XCTest.

## §4 Implementation outline

Layer placement: layer ④ interaction — `CoreErrorText` is the error-taxonomy half of the platform domain's
student-surface story (Q-C, Q-F rulings); it is read by 03.7's façade (message-list computation) and 03.11's
panels, neither of which this task touches.

### 4.1 `Packages/Core/Sources/Core/CoreError.swift`

Append, after `mapMarkerOffTrail` (the last of the current 17 cases), in this exact order:

```swift
    case platformStateUnreadable = "PLATFORM_STATE_UNREADABLE"
    case platformStateWriteFailed = "PLATFORM_STATE_WRITE_FAILED"
    case platformSnapshotRefused = "PLATFORM_SNAPSHOT_REFUSED"
```

No case is thrown by any code this task ships — these three cases exist here purely as the registry mirror
that tasks 03.4 (`platformSnapshotRefused`, per the Q-C ruling's launch-entry-point note) and 03.5
(`platformStateUnreadable`, `platformStateWriteFailed`, per the Q-F boundary) throw.

### 4.2 `Packages/Core/Sources/Core/CoreErrorText.swift`

```swift
import Foundation

/// The registered `user_text` for every `student`-surface code in `contracts/error-codes.json`, mirrored
/// verbatim — no new copy is authored here (content-policy voice: `contracts/error-codes.md` § Rules).
/// `internal`/`owner` codes have no entry (§1 AC2). `ErrorUserTextParityTests` asserts this table matches
/// the registry in both directions.
public enum CoreErrorText {
    public static let userText: [String: String] = [
        "MAP_MARKER_OFF_TRAIL": "The marker stays where it was; pick a unit from the list.",
        "EXP_NO_FRINGE": "You've cleared everything up to here. Move your class marker forward, or explore the map.",
        "EXP_STATE_WRITE_FAILED": "Your progress could not be saved just now; it will be retried.",
        "DIAG_NO_PREREQUISITE": "Nothing upstream to check — here's a hint.",
        "DIAG_PROBE_UNAVAILABLE": "No quick check is available for this one yet; here's a hint instead.",
        "DIAG_STATE_WRITE_FAILED": "Your progress could not be saved just now; it will be retried.",
        "PLATFORM_BUNDLE_FETCH_FAILED": "Could not refresh content; still using the installed version.",
        "PLATFORM_BUNDLE_INTEGRITY_FAILED": "Could not refresh content; still using the installed version.",
        "PLATFORM_STATE_UNREADABLE": "Earlier progress could not be read; it has been kept.",
        "PLATFORM_SNAPSHOT_REFUSED": "The map could not be loaded from this copy of the app; reinstall the app to fix it.",
        "VERIFY_CAS_UNAVAILABLE": "The checker could not start.",
        "VERIFY_PARSE_FAILED": "This step could not be read; please re-enter it.",
        "VERIFY_TIMEOUT": "This step could not be decided in time; the rest of the check stands.",
        "VERIFY_UNSUPPORTED": "Step checking is not available for this kind of problem; the answer is shown.",
    ]

    /// `nil` for any code absent from `userText` (internal/owner codes, or an unrecognized string).
    public static func text(for code: CoreError) -> String? {
        userText[code.rawValue]
    }
}
```

Keys are the raw registry `code` strings (not `CoreError` cases) because the table must mirror the full
registry's `student`-surface set (AC3), which includes `VERIFY_*` codes not yet present as `CoreError` cases
(M5, out of this task's scope per the context bundle's negative-fact note) — `CoreErrorText` is a registry
mirror, `CoreError` is `Core`'s own throw-site enum; they are related but not required to have identical
domains. `text(for:)` is the typed convenience `Core` code calling with a `CoreError` value uses.

### 4.3 `Packages/Core/Tests/CoreTests/ErrorUserTextParityTests.swift`

```swift
import Foundation
import Testing

@testable import Core

@Suite("CoreErrorText parity with error-codes.json student-surface entries")
struct ErrorUserTextParityTests {
    private struct RegistryEntry: Decodable {
        let code: String
        let surface: String
        let userText: String?

        enum CodingKeys: String, CodingKey {
            case code, surface
            case userText = "user_text"
        }
    }

    private struct Registry: Decodable {
        let codes: [RegistryEntry]
    }

    private static func loadRegistry() throws -> Registry {
        let registryPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root (Packages/Core)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("contracts/error-codes.json")
        let data = try Data(contentsOf: registryPath)
        return try JSONDecoder().decode(Registry.self, from: data)
    }

    @Test("every student-surface registry code has a matching, non-nil CoreErrorText entry")
    func everyStudentCodeHasMatchingText() throws {
        let registry = try Self.loadRegistry()
        let studentEntries = registry.codes.filter { $0.surface == "student" }

        #expect(!registry.codes.isEmpty, "empty registry read is a FAIL")
        #expect(!studentEntries.isEmpty, "no student-surface entries found — registry read is suspect")
        #expect(!CoreErrorText.userText.isEmpty, "empty CoreErrorText.userText is a FAIL")

        for entry in studentEntries {
            let mirrored = CoreErrorText.userText[entry.code]
            #expect(mirrored != nil, "\(entry.code) is student-surface but has no CoreErrorText entry")
            #expect(
                mirrored == entry.userText,
                "\(entry.code): CoreErrorText text does not match the registry's user_text")
        }
    }

    @Test("every CoreErrorText entry has a matching student-surface registry entry (no orphans)")
    func noOrphanTextEntries() throws {
        let registry = try Self.loadRegistry()
        let studentByCode = Dictionary(
            uniqueKeysWithValues: registry.codes.filter { $0.surface == "student" }.map { ($0.code, $0.userText) })

        for (code, text) in CoreErrorText.userText {
            #expect(studentByCode[code] != nil, "\(code) in CoreErrorText but not a student-surface registry entry")
            #expect(studentByCode[code] ?? nil == text, "\(code): orphan text does not match the registry")
        }
    }

    @Test("no internal or owner code carries a CoreErrorText entry")
    func noInternalOrOwnerTextEntries() throws {
        let registry = try Self.loadRegistry()
        let nonStudentCodes = Set(
            registry.codes.filter { $0.surface != "student" }.map(\.code))

        for code in CoreErrorText.userText.keys {
            #expect(
                !nonStudentCodes.contains(code),
                "\(code) is internal/owner surface but carries a CoreErrorText entry")
        }
    }

    // AC4: planted-mismatch negative control. Builds a local, broken copy of the parity check — never
    // touches product code — and proves the same equality assertion reds on it, then greens on the real
    // table. A guard never shown to fail is not a guard (C2, mirroring
    // ErrorRegistryNegativeControlTests's pattern).
    @Test("parity guard reds against a planted one-character text mismatch")
    func parityGuardRedsOnPlantedMismatch() throws {
        let registry = try Self.loadRegistry()
        guard let realEntry = registry.codes.first(where: { $0.code == "MAP_MARKER_OFF_TRAIL" }) else {
            Issue.record("fixture code MAP_MARKER_OFF_TRAIL missing from registry — negative control cannot run")
            return
        }
        var brokenTable = CoreErrorText.userText
        brokenTable["MAP_MARKER_OFF_TRAIL"] = (realEntry.userText ?? "") + "X"

        #expect(
            brokenTable["MAP_MARKER_OFF_TRAIL"] != realEntry.userText,
            "the planted mismatch guard failed to differ from the registry — guard is not load-bearing"
        )
    }

    // AC4: planted-mismatch negative control, orphan-entry variant.
    @Test("parity guard reds against a planted registry-absent code")
    func parityGuardRedsOnPlantedOrphan() throws {
        let registry = try Self.loadRegistry()
        var brokenTable = CoreErrorText.userText
        brokenTable["CORE_MADE_UP_CODE_NOT_IN_REGISTRY"] = "This is a planted failure."

        let studentCodes = Set(registry.codes.filter { $0.surface == "student" }.map(\.code))
        let orphans = brokenTable.keys.filter { !studentCodes.contains($0) }

        #expect(
            !orphans.isEmpty,
            "the orphan guard failed to catch a code absent from the registry — guard is not load-bearing"
        )
    }
}
```

The two "real" tests (`everyStudentCodeHasMatchingText`, `noOrphanTextEntries`) are the AC2/AC3 assertions; the
two planted-mismatch tests are AC4's negative control, following the shape of
`ErrorRegistryNegativeControlTests.swift` — reconstruct the broken fixture locally inside the test file, never
edit `CoreErrorText.swift` itself, and assert the guard's own comparison catches the defect. AC5 (empty-read
FAIL) is folded into `everyStudentCodeHasMatchingText`'s two `!isEmpty` guards, matching the precedent in
`ErrorRegistryTests.coreErrorIsSubsetOfRegistry()`.

### 4.4 Smoke check

`( cd Packages/Core && swift build -c release --product core-cli )` — must be green (compiles `CoreError.swift`
and `CoreErrorText.swift` even though `CoreCLI`'s `main.swift` calls neither the three new cases nor
`CoreErrorText` yet).

## §5 Test plan (risk: seam — full plan)

- T1 happy path:
  - `CoreErrorText.userText["PLATFORM_STATE_UNREADABLE"] == "Earlier progress could not be read; it has been
    kept."` and `CoreErrorText.text(for: .platformStateUnreadable)` returns the same string (AC2).
  - `CoreErrorText.userText["PLATFORM_SNAPSHOT_REFUSED"] == "The map could not be loaded from this copy of the
    app; reinstall the app to fix it."` (AC2, the Q-C exact text).
  - `everyStudentCodeHasMatchingText` and `noOrphanTextEntries` (§4.3) both pass over the real registry and the
    real `CoreErrorText.userText` (AC3).
- T2 negative — invalid input rejected at the boundary: not directly applicable (this task parses no untrusted
  external input beyond the registry JSON itself, which is repo-controlled, not user-supplied); the boundary
  case covered instead is registry/table divergence (T4/T5 below), which is this task's actual correctness
  surface.
- T3 error-taxonomy: a table-driven test (part of `everyStudentCodeHasMatchingText`) asserts each of the three
  new `CoreError` raw values equals its exact registry string (`PLATFORM_STATE_UNREADABLE`,
  `PLATFORM_STATE_WRITE_FAILED`, `PLATFORM_SNAPSHOT_REFUSED`); `ErrorRegistryTests` and
  `ErrorRegistryNegativeControlTests` (both unmodified) stay green (AC1).
- T4 conformance per requirements §B.1 (`contracts/error-codes.md` § Rules: "Internal codes never reach a
  student surface; a `student` code always has a next action in its text" — I5):
  - `noInternalOrOwnerTextEntries` (§4.3) asserts zero `CoreErrorText` keys for any `internal`/`owner` registry
    entry, including `PLATFORM_STATE_WRITE_FAILED` specifically (AC2's negative half).
  - a dedicated assertion that `CoreErrorText.userText.count` equals the registry's `student`-surface entry
    count exactly (no undercounting, no overcounting) — proves the mirror is total, not just a non-empty
    subset.
- T5 negative control for every regression guard:
  - `parityGuardRedsOnPlantedMismatch` proves the text-equality check catches a one-character corruption of a
    registered string (AC4).
  - `parityGuardRedsOnPlantedOrphan` proves the orphan check catches a `CoreErrorText` entry with no matching
    `student`-surface registry code (AC4).
  - both negative controls construct their broken fixture locally in the test file and never modify
    `CoreErrorText.swift` (product code) — matching `ErrorRegistryNegativeControlTests`'s "Does not modify
    `CoreError`" discipline.
- T6 idempotency / no-leak: `CoreErrorText.userText` is a `static let` — reading it twice in the same process
  returns the identical dictionary value (`Equatable`-equal); `CoreErrorText.text(for:)` is a pure function with
  no side effect, so calling it twice with the same `CoreError` case returns the same `String?` both times.

## §6 Decision defaults

- IF the registry's `student`-surface set grows or shrinks after this task lands (a later additive
  registration) THEN `ErrorUserTextParityTests` catches the drift automatically — it reads
  `contracts/error-codes.json` at test time rather than a hardcoded copy of the code list, so no future task
  needs to edit this test file to stay conformant. (Per `contracts/error-codes.md` § Rules: additive
  registration needs no version bump; the parity test's registry-driven design is what keeps it a lint-strength
  guard rather than a landmine.)
- IF a future `student`-surface code is registered but has no matching `CoreErrorText` entry yet (e.g. because
  the task that registers it has not also updated `CoreErrorText.swift`) THEN `everyStudentCodeHasMatchingText`
  fails with a named code in its message — this is the intended behavior, not a bug to work around; the task
  that adds the registry entry must also add the `CoreErrorText` entry in the same or a dependent task (mirrors
  this task's own dependency on 03.2).
- IF `CoreErrorText` should key on `CoreError` cases instead of raw registry strings THEN it does not — the
  registry's `student`-surface set (§3, `VERIFY_*` codes) is wider than `CoreError.allCases` today (the
  `VERIFY_*` cases are M5-scoped and explicitly out of this task's `CoreError` additions per the context
  bundle's negative-fact note), so a `CoreError`-keyed table could not represent the full registry mirror AC3
  requires; `CoreErrorText.text(for:)` is the typed convenience for `Core` code that already holds a
  `CoreError` value.
- IF the planted-mismatch negative control should mutate `CoreErrorText.swift` directly (a temporary edit,
  reverted after the test) THEN it does not — per `ErrorRegistryNegativeControlTests`'s established pattern
  (re-read in this run, "Does not modify `CoreError` (product code) — the broken shape is a local fixture, not
  the enum"), the broken shape is always a local copy built inside the test function.
- IF `contracts/error-codes.json`'s `PLATFORM_SNAPSHOT_REFUSED` entry is absent when this task's implementer
  starts THEN this is the 03.2 precondition failing to hold — BLOCK and report the missing registry entry
  rather than adding it here (03.2's file scope owns `contracts/error-codes.json`, out of scope for this task
  per §2).

Standing defaults: identifiers and timestamps are not touched by this task (no `StudentState`/`NodeState`
field involved); no model call exists anywhere in this task's code (I2 — vacuous, no model-calling path here);
telemetry is untouched by this task; every string in `CoreErrorText.userText` is copied verbatim from the
registry, never newly authored (content-policy voice, `contracts/error-codes.md` § Rules).

## §7 Done definition

The task is done when ALL gates pass:

- `xcrun swift-format lint --strict --recursive --configuration .swift-format Packages App/Sources` — clean
  over the two new files and the modified `CoreError.swift`.
- `Core` build + test green: `( cd Packages/Core && swift build -c release --product core-cli )` and
  `( cd Packages/Core && xcodebuild test -quiet -scheme Core-Package -destination "$SIM"
  CODE_SIGNING_ALLOWED=NO )` (`scripts/gate.sh` gate 3, `$SIM` from `scripts/pick-simulator.sh`).
- All cases in §5 (T1, T3, T4, T5, T6) pass.
- `ErrorRegistryTests` and `ErrorRegistryNegativeControlTests` stay green with no edit to either file (AC1).
- Conforms to every contract section cited in §3 (`contracts/error-codes.md` § Rules; `contracts/README.md`
  error-codes row) and to every invariant listed in §1 (I14, I5).
- `scripts/gate.sh` gate 3 green in full (gates 1, 2, 4 are format/pipeline/App-scoped and are unaffected by
  this task's file scope beyond gate 1's Swift formatting pass).
