# Epic 03 · Task 05: `StudentStateStore` — read, migrate, write `StudentState` over a caller-supplied URL

---
epic: 03
task: 05
slug: student-state-store
kind: feat
risk: seam
depends_on: [03.3]
model: sonnet
---

> **Branch note.** This spec is written against the current tree, branch `epic-03a-map-core`, to be created
> after EPIC 02b is merged into `main` (confirmed clean `main` at spec-write time, no `epic-03a-map-core`
> branch yet). `CoreError.swift` today (re-read in this run) has 17 cases and does **not** contain
> `platformStateUnreadable` or `platformStateWriteFailed` (`Grep "platformState|PLATFORM_STATE"
> Packages/Core/Sources/Core` returns no match outside `CoreEvent.swift`'s two pre-existing event cases,
> `platformStateMigrated`/`platformStateWritten`). Task 03.3
> (`tasks/epic-03-task-03-core-error-surface-text-mirror.md`) adds those two `CoreError` cases — this task's
> `depends_on: [03.3]` means the implementer does not start until that task has landed and `CoreError.swift`
> carries `case platformStateUnreadable = "PLATFORM_STATE_UNREADABLE"` and `case platformStateWriteFailed =
> "PLATFORM_STATE_WRITE_FAILED"` (03.3 §4.1, already written and byte-compared in this run against the live
> file). If those cases are absent when implementation starts, that is the 03.3 precondition failing to
> hold — BLOCK and report it; do not add the cases here (03.3's file scope owns `CoreError.swift`; "This is
> the only task in EPIC 03 that writes `CoreError.swift`" per that spec's own goal statement).

## §1 Goal & acceptance criteria

Goal: `Core` gains `StudentStateStore`, a Foundation-only, value-typed persistence primitive over a
caller-supplied `URL` — `read(at:)` returns `.absent` for no file, `.loaded(state, migratedFrom:)` for a
readable file (identity-migrating a `schema_version` 1 document to 2 along the way), or throws
`CoreError.platformStateUnreadable` for an undecodable file or one whose `schema_version` exceeds 2; `write(_
to:)` writes the whole document atomically through `CoreCoding` or throws `CoreError.platformStateWriteFailed`.
This is the platform-domain persistence half of `docs/domains/platform.md` § W3 and the `Core` half of arbiter-03
§ Q-F item 2, fully testable in `CoreTests` against a temporary directory with no App context — the foundation
03.7's façade and 03.12's App shell build on for "no file → `courseSelectionNeeded`; a chosen course persists;
every state-changing action writes" (`docs/epics/epic-03-app-map-shell.md` § 4 AC 3, arbiter-03 § Q-E).

Invariants in play:

- **I14** — `StudentStateStore.swift` and its test file import `Foundation` only, live under
  `Packages/Core/{Sources,Tests}/Core*`, construct no `JSONDecoder`/`JSONEncoder` directly (only through
  `CoreCoding`, per `CoreTests.swift`'s existing `onlyCoreCodingConstructsCoders()` test, unmodified — this
  task's new file is covered by that scan automatically since it walks `Sources/Core` recursively), and are
  the *only* `Core` implementation of `StudentState` persistence — no second read/write/migrate path exists
  anywhere else in the repository (the App never constructs a `StudentState` or performs its own file I/O on
  it, per arbiter-03 § Q-F's boundary: "`Core` holds ... the persistence store"). The existing
  `coreImportBoundary()` test (unmodified) covers the new file with no edit.
- **I5** — `StudentStateStore` moves `StudentState` values opaquely; it adds no field, computes no identifier,
  and its test suite asserts the raw written JSON's top-level key set is exactly
  `student-state.schema.json`'s closed `required` set (§5 T4) — proving the store cannot silently smuggle an
  extra key onto disk.
- **I1, I2, I6** — not engaged: this task calls no CAS, no language model, and reads/writes no `Node`, so
  there is no step-verification path, no model-confidence threshold to define, and no Ministry text anywhere
  near this code (Tier 0 file I/O only).

Acceptance criteria (each independently verifiable):

- AC1: `StudentStateStore.read(at:)` on a `url` where `FileManager.default.fileExists(atPath:)` is `false`
  returns `.absent` and creates no file, writes nothing, and emits no `CoreEvent`.
- AC2: `read(at:)` on a `url` holding a well-formed `schema_version: 2` document (decodable by
  `CoreCoding.decoder` into `StudentState`) returns `.loaded(state, migratedFrom: nil)`; `url`'s bytes are
  byte-identical before and after the call (a plain read never writes).
- AC3: `read(at:)` on a `url` holding a well-formed `schema_version: 1` document (every `nodes[].remediated`
  key absent, per `contracts/data-model.md`'s identity-migration rule) returns `.loaded(migrated, migratedFrom:
  1)` where `migrated.schemaVersion == 2` and every other field is unchanged from the decoded input; `url`'s
  bytes after the call equal `CoreCoding.encoder.encode(migrated)` exactly (the precisely-defined
  "migrated-v2 bytes", §4); no `<url's last path component>.pre-migration` sibling file exists once `read`
  returns; the accompanying event array is `[.platformStateMigrated]`.
- AC4: `read(at:)` throws `CoreError.platformStateUnreadable` for (a) a file whose bytes are not valid JSON,
  (b) a file that is valid JSON but fails `StudentState` decode (e.g. a required key missing), and (c) a file
  that decodes successfully but carries `schema_version: 3` (or any value `> 2`) — in all three cases `url`'s
  bytes are byte-identical before and after the call, nothing is deleted, and no `.pre-migration` file is ever
  created (migration only begins once `schema_version == 1` is confirmed).
- AC5: `write(_:to:)` on a `StudentState` value writes the whole document atomically (write-to-temp-file,
  then `FileManager.replaceItemAt`) to `url`, returns `[.platformStateWritten]`, and a subsequent `read(at:
  url)` returns `.loaded(state, migratedFrom: nil)` with the returned `state` `Equatable`-equal to the
  written value; the raw bytes at `url` equal `CoreCoding.encoder.encode(state)` exactly (round-trip
  byte-equality, `docs/epics/epic-03-app-map-shell.md` § 4 AC 3: "Write → read round-trips byte-equal through
  `CoreCoding`").
- AC6: `write(_:to:)` throws `CoreError.platformStateWriteFailed` when the write cannot complete (e.g. the
  temp file's target directory does not exist), and `url`'s pre-existing content, if any, is unaffected — an
  interrupted write never leaves a truncated document at `url` (`docs/epics/epic-03-app-map-shell.md` § 4 AC
  3: "The write is atomic: an interrupted write never leaves a truncated document where the previous one
  was").
- AC7: when a migration's internal write to `url` fails (simulated), `read(at:)` throws
  `CoreError.platformStateUnreadable` (platform W3: "`PLATFORM_STATE_UNREADABLE` if migration fails — the old
  file is kept ... nothing deleted" — a migration failure is `platformStateUnreadable`, never
  `platformStateWriteFailed`), `url`'s original `schema_version: 1` bytes are unchanged, and the
  `.pre-migration` backup file is **still present** (kept until a migrated write actually succeeds, arbiter-03
  § Q-F: "Keep the pre-migration file until the migrated one is written").

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Core/Sources/Core/Platform/StudentStateStore.swift` — CREATE. `StudentStateStore.read(at:)`,
  `StudentStateStore.write(_:to:)`, and every private helper (§4). Confirmed absent: `Glob
  **/StudentStateStore.swift` returns no match at the time this spec is written; no `Platform/` directory
  exists yet under `Packages/Core/Sources/Core` (confirmed by a recursive `Glob
  Packages/Core/Sources/Core/**` in this run, which lists `BundleIO.swift`, `Core.swift`, `CoreCoding.swift`,
  `CoreError.swift`, `ItemChecker.swift`, and the `Layout/`, `Model/`, `Validation/`, `Events/`, `State/`,
  `Time/`, `Diagnosis/`, `Graph/` subdirectories — no `Platform/`).
- `Packages/Core/Tests/CoreTests/StudentStateStoreTests.swift` — CREATE. This task's own companion test suite
  (§5): AC1–AC7, the interrupted-write and migration-failure simulations, and both negative controls.

Out-of-scope (do not touch even if tempted):

- `Packages/Core/Sources/Core/CoreError.swift` — task 03.3's file; this task's precondition, not its scope
  (branch note above). Read-only here; this task throws the two cases 03.3 adds, never defines them.
- `Packages/Core/Sources/Core/CoreCoding.swift` — read-only; `StudentStateStore` uses
  `CoreCoding.decoder`/`CoreCoding.encoder` exclusively, adding no decoder/encoder configuration of its own
  (I14 — `onlyCoreCodingConstructsCoders()` must stay green with no edit to either file).
- `Packages/Core/Sources/Core/Model/StudentState.swift` — read-only; this task adds no field, no case, no
  type. `StudentState`, `Marker`, `NodeState`, `Mastery`, `Trail`, `TrailSegment`, `SegmentKind`,
  `ExpeditionLogEntry`, `ProbeLogEntry` are consumed exactly as task 02.2/02.9 left them.
- `Packages/Core/Sources/Core/Events/CoreEvent.swift` — read-only; `platformStateMigrated` and
  `platformStateWritten` already exist (confirmed, `Events/CoreEvent.swift:34-35`); this task raises them, adds
  neither case.
- `App/Sources/**` — no App code is touched; 03.7 (façade) and 03.12 (App shell, Application Support URL
  resolution) consume this task's public API in a later task. "No Application Support path logic here" — the
  caller supplies `url`; this task never resolves, constructs, or hardcodes a platform-specific path.
- `Packages/Core/Tests/CoreTests/CoreTests.swift`,
  `Packages/Core/Tests/CoreTests/IdentifierBlocklistParityTests.swift` — both already generic over
  `Sources/Core`/`StudentState`'s wire keys with no per-task edit needed; this task's new file is covered by
  the former with no change, and the latter needs no change since no field is added (§5 T4 re-runs it
  unmodified as a green-stays-green check).
- `contracts/**` — read-only ground truth.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/data-model.md:130-137` — heading `### StudentState (`student-state.schema.json`)` (re-read,
  byte-compared in this run):
  > `schema_version`, `format_version_seen`, `syllabi[]` (course codes), `marker {course_code, unit_id,
  > past_last_unit?}`, `nodes {node_id → {mastery ∈ {fog, cleared, blocked}, correct_count, last_probe?,
  > next_due?, ladder_rung, remediated?}}`, `trail {segments[] {kind ∈ {course, extension}, course_code?,
  > node_ids[]}}` (derived, cached), `expedition_log[] {day, item_count, cleared, blocked, abandoned,
  > diagnosis_events}`, `probe_log[] {day, node_id, item_id, correct, retry}`, `install_day`, `consent_on`.
  > **No field may name a person, device, account, install or session** (I5); the schema's closed key set is
  > the guard.
- `contracts/data-model.md:149-150` — same section, final paragraph (re-read, byte-compared in this run):
  > `schema_version` is **2**. Migration 1 → 2 is the identity: a version-1 document is a valid version-2
  > document with every `remediated` absent.
- `contracts/data-model.md:25` and `:29` — heading `### Versioning` (re-read, byte-compared in this run):
  > Every bundle file carries `format_version` (semver) = `CoreInfo.dataFormatVersion`; a major bump means
  > `Core` needs a migration; the app refuses a bundle whose major differs from its own.
  >
  > `StudentState.schema_version` (integer) is migrated forward only (platform W3); older files are kept.
- `contracts/data-model.md:41-43` — heading `### Nulls, enums, unknowns` (re-read, byte-compared in this run):
  > Optional means the key is **absent**, never `null`. Enums are closed; an unknown value fails decode.
  > Every object schema sets `additionalProperties: false` — a new field is a versioned change.
- `contracts/schemas/student-state.schema.json:212-224` — `required`/`additionalProperties` (re-read,
  byte-compared in this run):
  ```json
  "required": [
    "schema_version",
    "format_version_seen",
    "syllabi",
    "marker",
    "nodes",
    "trail",
    "expedition_log",
    "probe_log",
    "install_day",
    "consent_on"
  ],
  "additionalProperties": false
  ```
  Also `student-state.schema.json:7-10` (re-read in this run): `"schema_version": {"type": "integer",
  "minimum": 1}` — the schema itself sets no upper bound; the "newer than the App" refusal (AC4c) is this
  task's own logic, not a schema-level rejection.
- `docs/domains/platform.md:62-67` — heading `### W3 — Read, write and migrate student state` (re-read,
  byte-compared in this run):
  > **Pre:** a launch (read) or a domain transition (write). **Steps:** 1. Read the local JSON; if
  > `schema_version` is older, run migrations in order and keep the pre-migration file until the migrated one
  > is written (`PLATFORM_STATE_UNREADABLE` if migration fails — the old file is kept, a fresh state is used,
  > nothing deleted). 2. Writes are whole-document, atomic (write-then-rename). Tier 0. **Post:**
  > `platform.state_migrated` on a migration; `platform.state_written` otherwise.
- `docs/domains/platform.md:101-102` — heading `## Errors produced`, rows `PLATFORM_STATE_WRITE_FAILED` /
  `PLATFORM_STATE_UNREADABLE` (re-read, byte-compared in this run):
  > | `PLATFORM_STATE_WRITE_FAILED` | The JSON write failed | Banner from the calling domain | Yes — retried |
  > | `PLATFORM_STATE_UNREADABLE` | Migration failed | "Earlier progress could not be read; it has been kept" | Yes — file retained |
- `contracts/error-codes.json:50-51` (re-read, byte-compared in this run):
  ```json
  {"code": "PLATFORM_STATE_WRITE_FAILED", "recoverable": true, "surface": "internal", "user_text": null},
  {"code": "PLATFORM_STATE_UNREADABLE", "recoverable": true, "surface": "student", "user_text": "Earlier progress could not be read; it has been kept."},
  ```
- `tasks/arbitration/arbiter-03-predispatch.md:286-291` — § Q-F, "The boundary, precisely", item 2 (re-read,
  byte-compared in this run):
  > 2. **The persistence store.**
  >    - Encode and decode through `CoreCoding`; the 1 → 2 identity migration.
  >    - Atomic whole-document write to a caller-supplied URL.
  >    - Keep the pre-migration file until the migrated one is written.
  >    - Preserve an unreadable file byte-for-byte.
  >    - Errors: `PLATFORM_STATE_UNREADABLE` and `PLATFORM_STATE_WRITE_FAILED` join `CoreError` additively.
- `docs/epics/epic-03-app-map-shell.md:275-291` — § 4 AC 3 (re-read, byte-compared in this run):
  > - No file → `courseSelectionNeeded`; no file is written. Choosing a course yields a state with
  >   `schema_version` 2, `install_day` = the injected today, `syllabi` = [course], the default marker, every
  >   node absent (`fog`), and it is persisted (arbiter-03 § Q-E).
  > - Write → read round-trips byte-equal through `CoreCoding`. The write is atomic: an interrupted write
  >   never leaves a truncated document where the previous one was.
  > - Every state-changing action of the `Core` session writes the whole document to the injected URL
  >   (arbiter-03 § Q-F).
  > - A version-1 file migrates to version 2 by identity. The pre-migration file is kept until the migrated
  >   one is written.
  > - An undecodable file, or one with a `schema_version` newer than the App → `PLATFORM_STATE_UNREADABLE`.
  >   The original file is kept byte-for-byte, and launch returns `courseSelectionNeeded` with
  >   `PLATFORM_STATE_UNREADABLE` in its messages. The fresh state is created when a course is chosen
  >   (arbiter-03 § Q-E).
  >   - Every one of these passes in `Core` tests against a temporary directory. The simulator smoke (§3
  >     artifact line) shows that a fresh install writes no file, and that a seeded version-1 file migrates,
  >     validates and is byte-identical after relaunch.
- `tasks/epic-03-task-03-core-error-surface-text-mirror.md` § 1 (already-written sibling spec, re-read in this
  run — the precedent that fixes this task's throwing shape, not merely descriptive):
  > No case is thrown by any code this task ships — these three cases exist here purely as the registry
  > mirror that tasks 03.4 (`platformSnapshotRefused`, per the Q-C ruling's launch-entry-point note) and 03.5
  > (`platformStateUnreadable`, `platformStateWriteFailed`, per the Q-F boundary) throw.
- `CLAUDE.md` — Invariant table, row `I14` (re-read in this run):
  > **`Core` is renderer-free and single-source**: `Core` imports Foundation only; the render layer never
  > computes state; L0 and layout exist once, in `Core`. A test asserts the import boundary.
- `CLAUDE.md` — Invariant table, row `I5` (re-read in this run):
  > **No PII, no accounts.** Telemetry is anonymous and aggregate, **on by default with one-tap off, and
  > carries no identifier of any kind** (no install, device or session id); the endpoint retains no IP.
  > Cross-device sync uses Apple-managed identity only.

Prior signatures this task builds on (from the codebase, verbatim, re-read in this run):

```swift
// Packages/Core/Sources/Core/Model/StudentState.swift:10-27
public struct StudentState: Codable, Equatable {
    public let schemaVersion: Int
    public let formatVersionSeen: String
    public let syllabi: [String]
    public let marker: Marker
    public let nodes: [String: NodeState]
    public let trail: Trail
    public let expeditionLog: [ExpeditionLogEntry]
    public let probeLog: [ProbeLogEntry]
    public let installDay: String
    public let consentOn: Bool
}

public struct Marker: Codable, Equatable {
    public let courseCode: String
    public let unitId: String
    public let pastLastUnit: Bool?
}
```

```swift
// Packages/Core/Sources/Core/CoreCoding.swift:10-28 (full file)
public enum CoreCoding {
    public static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    public static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
```

```swift
// Packages/Core/Sources/Core/Events/CoreEvent.swift:32-35 (excerpt)
    case platformLaunched = "platform.launched"
    case platformContentUpdated = "platform.content_updated"
    case platformStateMigrated = "platform.state_migrated"
    case platformStateWritten = "platform.state_written"
```

```swift
// Packages/Core/Sources/Core/CoreError.swift:10-28 (17 cases, current state; task 03.3 appends
// platformStateUnreadable and platformStateWriteFailed after mapMarkerOffTrail — precondition, not this
// task's edit)
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

A real, schema-valid fixture this task's tests build v1/v2 variants from (`contracts/examples/student-state.json`,
full file, re-read in this run — no `remediated` mutation needed for the v2 case; the v1 fixture drops
`matrix-multiplication`'s `remediated: true` key and sets `schema_version: 1`):

```json
{
  "schema_version": 2,
  "format_version_seen": "0.0.0",
  "syllabi": ["MCR3U"],
  "marker": {"course_code": "MCR3U", "unit_id": "MCR3U.u1"},
  "nodes": {
    "exponent-laws": {"mastery": "cleared", "correct_count": 2, "last_probe": "2026-09-08", "next_due": "2026-09-09", "ladder_rung": 0},
    "exponential-functions": {"mastery": "fog", "correct_count": 1, "ladder_rung": 0},
    "matrix-multiplication": {"mastery": "blocked", "correct_count": 0, "ladder_rung": 0, "remediated": true}
  },
  "trail": {"segments": [{"kind": "course", "course_code": "MCR3U", "node_ids": ["exponential-functions"]}]},
  "expedition_log": [{"day": "2026-09-08", "item_count": 5, "cleared": 1, "blocked": 0, "abandoned": false, "diagnosis_events": 0}],
  "probe_log": [{"day": "2026-09-08", "node_id": "exponent-laws", "item_id": "exp-1", "correct": true, "retry": false}],
  "install_day": "2026-09-08",
  "consent_on": true
}
```

Precedent test idiom for a temp directory (`Packages/Core/Tests/CoreTests/BundleIOIntegrityTests.swift:48-51`,
re-read in this run):

```swift
let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: tempDir) }
```

Gate commands (`scripts/gate.sh:16-18`, re-read in this run):

```sh
( cd "$ROOT/Packages/Core" && swift build -c release --product core-cli )
( cd "$ROOT/Packages/Core" && xcodebuild test -quiet -scheme Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO )
```

Test framework (confirmed by `Packages/Core/Tests/CoreTests/ErrorRegistryTests.swift:1-4` and this task's own
precedent files, re-read in this run): Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`), not
XCTest.

## §4 Implementation outline

Layer placement: platform-domain infrastructure (`docs/domains/platform.md` § W3), not one of the four content
layers — the `Core` half of `StudentState` persistence that 03.7's façade and 03.12's App shell call; it reads
no bundle and no graph.

### 1. `Packages/Core/Sources/Core/Platform/StudentStateStore.swift` — public shape

```swift
import Foundation

/// Read/write/migrate `StudentState` at a caller-supplied `URL` (`docs/domains/platform.md` § W3, arbiter-03
/// § Q-F item 2). `Core`, Foundation only (I14) — the caller resolves the Application Support URL; this type
/// never hardcodes or resolves a platform-specific path.
public enum StudentStateStore {
    /// The highest `schema_version` this `Core` build decodes (`contracts/data-model.md:149`: "`schema_version`
    /// is **2**"). A file naming a higher version is refused (AC4c), never guessed at.
    private static let currentSchemaVersion = 2

    public enum ReadResult: Equatable {
        case absent
        case loaded(StudentState, migratedFrom: Int?)
    }

    /// Reads `StudentState` from `url`, migrating a `schema_version: 1` document to 2 (identity) if needed.
    /// Throws `CoreError.platformStateUnreadable` for an undecodable file, a `schema_version` outside `1...2`,
    /// or a migration whose write back to `url` fails — `url`'s bytes are left untouched in every throwing
    /// case (platform W3: "the old file is kept ... nothing deleted"). Returns `(result, events)`:
    /// `events == [.platformStateMigrated]` iff `result` is `.loaded` with a non-nil `migratedFrom`;
    /// otherwise `events == []` (a plain read, or a read of an absent file, writes nothing).
    public static func read(at url: URL) throws -> (result: ReadResult, events: [CoreEvent]) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return (.absent, [])
        }

        let originalData: Data
        do {
            originalData = try Data(contentsOf: url)
        } catch {
            throw CoreError.platformStateUnreadable
        }

        let decoded: StudentState
        do {
            decoded = try CoreCoding.decoder.decode(StudentState.self, from: originalData)
        } catch {
            throw CoreError.platformStateUnreadable
        }

        guard decoded.schemaVersion >= 1, decoded.schemaVersion <= currentSchemaVersion else {
            throw CoreError.platformStateUnreadable
        }

        if decoded.schemaVersion == currentSchemaVersion {
            return (.loaded(decoded, migratedFrom: nil), [])
        }

        // decoded.schemaVersion == 1: identity migration. Every field is carried through unchanged except
        // schemaVersion — a valid v1 document already has every `remediated` key absent, per the contract's
        // own migration rule (quoted §3).
        let migrated = StudentState(
            schemaVersion: currentSchemaVersion,
            formatVersionSeen: decoded.formatVersionSeen,
            syllabi: decoded.syllabi,
            marker: decoded.marker,
            nodes: decoded.nodes,
            trail: decoded.trail,
            expeditionLog: decoded.expeditionLog,
            probeLog: decoded.probeLog,
            installDay: decoded.installDay,
            consentOn: decoded.consentOn
        )

        let preMigrationURL = url.appendingPathExtension("pre-migration")
        do {
            try originalData.write(to: preMigrationURL, options: .atomic)
        } catch {
            throw CoreError.platformStateUnreadable
        }

        do {
            _ = try write(migrated, to: url)
        } catch {
            // `url` is untouched (write-then-rename never truncates the target in place);
            // `preMigrationURL` is left in place — "keep the pre-migration file until the migrated one is
            // written" (arbiter-03 § Q-F, quoted §3). AC7.
            throw CoreError.platformStateUnreadable
        }

        try? FileManager.default.removeItem(at: preMigrationURL)
        return (.loaded(migrated, migratedFrom: 1), [.platformStateMigrated])
    }

    /// Atomic whole-document write through `CoreCoding.encoder`: encode, write to a hidden temp file beside
    /// `url`, then `FileManager.replaceItemAt` — a single OS-level rename that either fully replaces `url`'s
    /// content or leaves it untouched, never a partial write (AC5, AC6). Works identically whether or not a
    /// file already exists at `url` (`replaceItemAt` moves the temp file into place when the target is
    /// absent). Throws `CoreError.platformStateWriteFailed` on any failure. Returns `[.platformStateWritten]`
    /// on success.
    public static func write(_ state: StudentState, to url: URL) throws -> [CoreEvent] {
        do {
            let data = try CoreCoding.encoder.encode(state)
            let tempURL = url.deletingLastPathComponent()
                .appendingPathComponent(".\(url.lastPathComponent).tmp-\(UUID().uuidString)")
            try data.write(to: tempURL, options: .atomic)
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
        } catch {
            throw CoreError.platformStateWriteFailed
        }
        return [.platformStateWritten]
    }
}
```

### 2. Boundary schema(s) and what is validated / rejected

`read(at:)` validates every byte it consumes: raw `Data(contentsOf:)` failure, `CoreCoding.decoder` decode
failure (missing required key, wrong type, unknown enum value, unknown `additionalProperties` — all already
enforced by `student-state.schema.json`'s shape mirrored in the Swift `Codable` types, quoted §3), and an
out-of-range `schema_version` are each rejected with `CoreError.platformStateUnreadable`, never a partial or
best-effort `StudentState`. `write(_:to:)` accepts any already-typed `StudentState` value (no untrusted-input
boundary inside `write` itself — the boundary is `read`'s decode step; a value already held in Swift as
`StudentState` is, by construction, schema-valid).

### 3. Error codes thrown

- `CoreError.platformStateUnreadable` (`PLATFORM_STATE_UNREADABLE`, `contracts/error-codes.json:51`) — an
  undecodable file, a `schema_version` outside `1...2`, or a migration whose write-back fails (§4.1, AC4, AC7).
- `CoreError.platformStateWriteFailed` (`PLATFORM_STATE_WRITE_FAILED`, `contracts/error-codes.json:50`) — any
  `write(_:to:)` I/O failure (AC6). Its registry `surface` is `internal` (`"user_text": null`); the calling
  domain (a later task) decides what, if anything, a student sees — this task never renders or maps it to a
  student-facing string.

### 4. Model-calling paths

None. Tier 0 file I/O only; I2's confidence-threshold/fallback requirement is not engaged.

### 5. Commit

```
feat(core): StudentStateStore — read, identity-migrate v1→v2, atomic write over a caller URL
```

### 6. Smoke check

```
( cd Packages/Core && swift build -c release --product core-cli )
```
must be green (compiles the new file even though `core-cli`'s `main.swift` calls none of it yet, matching
02.5's/02.6's/02.12's own smoke-check pattern).

## §5 Test plan (risk: seam — full plan)

- **T1 happy path** (`StudentStateStoreTests.swift`, each case in its own temp directory per the precedent
  idiom, §3):
  - AC1: `read(at:)` on a URL with no file returns `.absent`, `events == []`; `FileManager.default.fileExists`
    at that URL is still `false` after the call.
  - AC2: seed a `schema_version: 2` fixture (the JSON literal, §3) at `url`; `read(at:)` returns `.loaded`
    with `migratedFrom == nil`; the decoded `StudentState`'s fields match the fixture exactly; `url`'s raw
    bytes are unchanged (`Data(contentsOf:)` before/after the call are `==`).
  - AC3: seed the v1 variant (schema_version: 1, `matrix-multiplication`'s `remediated` key removed) at `url`;
    `read(at:)` returns `.loaded(migrated, migratedFrom: 1)`, `events == [.platformStateMigrated]`; assert
    `migrated.schemaVersion == 2` and every other field equals the fixture's decoded value; assert the raw
    bytes now at `url` equal `try CoreCoding.encoder.encode(migrated)` exactly (byte comparison, not just
    `Equatable`); assert `FileManager.default.fileExists(atPath: url.appendingPathExtension("pre-migration").path)
    == false`.
  - AC5: `write(state, to: url)` on a fresh `StudentState` (built from `contracts/examples/student-state.json`'s
    decoded value) returns `[.platformStateWritten]`; `read(at: url)` afterward returns `.loaded(state,
    migratedFrom: nil)` with `Equatable`-equality to the written value; raw bytes at `url` equal
    `CoreCoding.encoder.encode(state)` exactly.
  - Round-trip determinism: `write` the same `StudentState` value twice (fresh temp directory) and assert the
    two resulting files' raw bytes are identical (`.sortedKeys` determinism, `CoreCoding.swift:19-21`'s own
    documented guarantee).
- **T2 negative — invalid input rejected at the boundary:**
  - AC4a: `url` holds `"{ not valid json at all"` — `read(at:)` throws `CoreError.platformStateUnreadable`;
    raw bytes at `url` unchanged; no `.pre-migration` file created.
  - AC4b: `url` holds syntactically valid JSON missing the required `marker` key — same assertions as AC4a.
  - AC4c: `url` holds a structurally valid `schema_version: 3` document (the v2 fixture with `schema_version`
    changed to `3`) — `read(at:)` throws `CoreError.platformStateUnreadable`; raw bytes at `url` unchanged; no
    `.pre-migration` file created (proving the version check runs even when decode itself would have
    succeeded — a case AC4a/AC4b's genuinely-broken fixtures cannot distinguish).
- **T3 error-taxonomy:**
  - each of T2's three cases asserts the thrown error, cast `as? CoreError`, has `rawValue ==
    "PLATFORM_STATE_UNREADABLE"` exactly (the precedent catch-and-cast idiom,
    `BundleIOIntegrityTests.swift:64-72`).
  - AC6's write-failure case asserts the thrown error's `rawValue == "PLATFORM_STATE_WRITE_FAILED"`.
  - `ErrorRegistryTests` (unmodified, from task 03.3) stays green — both new `CoreError` cases are already
    covered by its generic `⊆`-registry scan.
- **T4 conformance per requirements §B.1 (I5, I14, and platform W3/arbiter-03 § Q-F):**
  - I5 — written key set equals the schema's closed properties: `write` a full `StudentState`, re-parse the
    raw JSON at `url` as `[String: Any]` (top-level `JSONSerialization`, used only for key inspection, never
    for decoding the value itself), and assert its `Set(keys)` equals `student-state.schema.json`'s `required`
    array read from disk via the `#filePath`-based path-navigation pattern of `ErrorRegistryTests.swift:20-26`
    / `IdentifierBlocklistParityTests.swift:22-28` (five `deletingLastPathComponent()` calls from
    `CoreTests/StudentStateStoreTests.swift` to the repo root, then `appendingPathComponent(
    "contracts/schemas/student-state.schema.json")`) — an empty read of either side is asserted as a FAIL.
  - I5 — `IdentifierBlocklistParityTests` (unmodified) stays green, re-run as part of the full suite; this
    task adds no field to `StudentState`, so its parity assertion is unaffected.
  - I14 — `coreImportBoundary()` and `onlyCoreCodingConstructsCoders()` (both unmodified,
    `CoreTests.swift:17-44` and `:51-89`) stay green with no edit; a grep-style assertion in this task's own
    suite confirms `Platform/StudentStateStore.swift`'s text contains no literal `JSONDecoder(` or
    `JSONEncoder(` (mirroring what `onlyCoreCodingConstructsCoders()` already checks generically, restated
    locally so this task's own suite fails loudly if the product file ever regresses, independent of that
    other test staying wired up).
  - platform W3 / arbiter-03 § Q-F — AC7: migration-write failure. Seed the v1 fixture at `url`; before
    calling `read`, make `url`'s containing directory read-only (`FileManager.default.setAttributes([
    .posixPermissions: 0o555], ofItemAtPath:)`) so `write`'s internal `replaceItemAt` call fails; call
    `read(at: url)`, assert it throws `CoreError.platformStateUnreadable`; restore the directory's
    permissions (`defer`, before the temp-directory cleanup runs); assert `url`'s raw bytes are still the
    original v1 fixture's bytes exactly, and assert `url.appendingPathExtension("pre-migration")` **does**
    exist and its bytes equal the original v1 fixture's bytes exactly (the backup the migration created before
    attempting the failed write).
- **T5 negative control for every regression guard:**
  - Atomic write: a locally reconstructed wrong variant (test-file-only, never product code) that writes
    directly to `url` via `try data.write(to: url)` (no temp file, no rename) is shown, under the same
    read-only-directory-interruption fixture as AC7's write-failure simulation but applied mid-way through a
    *second* write over an *existing* valid file, to risk leaving `url` either untouched or (for the wrong
    variant, under a fixture that lets the open succeed but a later flush fail) a truncated/partial file —
    while the real `write(_:to:)` (temp-then-`replaceItemAt`) leaves `url`'s prior content exactly unchanged
    in every failure fixture this suite constructs, proving the temp-then-rename step is load-bearing, not
    accidentally satisfied by a naive direct write.
  - Pre-migration backup: a locally reconstructed wrong variant that migrates by deleting/overwriting `url`
    *before* attempting the migrated write (no `.pre-migration` backup at all) is shown, under AC7's same
    read-only-directory fixture, to lose the original v1 content entirely once the write fails — data loss —
    while the real flow's `.pre-migration` backup (written before the attempt) preserves it, proving the
    backup step is load-bearing per arbiter-03 § Q-F's "keep the pre-migration file until the migrated one is
    written", not a no-op given the write's own atomicity already protects `url` itself.
- **T6 idempotency / no-leak:**
  - Byte-identical after relaunch: after AC3's migration succeeds, a **second**, independent `read(at: url)`
    call (simulating a relaunch) returns `.loaded(migrated, migratedFrom: nil)` — `migratedFrom` is `nil` the
    second time because `url` now already carries `schema_version: 2` — and `url`'s raw bytes are
    byte-identical to what they were immediately after the first `read` call returned (the exact property the
    simulator smoke, Q-G, later exercises end-to-end).
  - No leaked temp files: after both a successful and a failed `write(_:to:)` call, the containing directory's
    listing (`FileManager.default.contentsOfDirectory(at:)`) contains no file matching the `.tmp-` prefix
    pattern this task's `write` uses — `replaceItemAt` consumes the temp file on success, and Foundation's
    `.atomic` write of the temp file itself either fully succeeds (temp file then consumed by `replaceItemAt`)
    or never comes into existence (failure before the write completes) in every fixture this suite
    constructs.
  - Two independent `write(state, to: url)` calls with a freshly-constructed, value-identical `state` argument
    each time (never a reused mutated variable) produce byte-identical files, both times returning
    `[.platformStateWritten]`.

## §6 Decision defaults

- IF the file should live at `Packages/Core/Sources/Core/StateStore/StudentStateStore.swift` (a location
  named by an earlier planning artifact) THEN it does not — this spec's dispatch instruction is explicit:
  `Packages/Core/Sources/Core/Platform/StudentStateStore.swift`. `Platform/` also groups this file with the
  platform domain's other `Core`-side pieces this EPIC's other tasks may add (03.3's error-text mirror sits
  directly in `Sources/Core`, not a subdirectory, but `docs/domains/platform.md` § W3/W4 both name
  "platform" as the owning domain for this exact behaviour) — either name would have been defensible; the
  explicit dispatch instruction is followed.
- IF `read(at:)` should return an `.unreadable(keptFileURL:)` case instead of throwing
  `CoreError.platformStateUnreadable` (an earlier planning sketch phrased it that way) THEN it throws instead —
  task 03.3's own already-written spec states plainly that "03.5 (`platformStateUnreadable`,
  `platformStateWriteFailed`, per the Q-F boundary) throw" (§3, quoted verbatim); a thrown `CoreError` also
  needs no `keptFileURL` payload (`CoreError` is a plain `String`-backed enum with no associated values, so it
  could not carry one) — the caller already holds `url`, the same value it passed to `read(at:)`, so nothing
  is lost by not returning it a second time.
- IF `read`/`write`'s `[CoreEvent]` should be emitted through some in-`Core` notification mechanism instead of
  returned to the caller THEN it is returned — `CoreEvent`'s own doc comment (`Events/CoreEvent.swift:3-7`,
  re-read in this run) states it is "a bare name registry" that "carries no payload" and that "a caller that
  needs to pair an event with data defines its own pairing type" — there is no observer/notification-center
  pattern anywhere in `Core` for this enum to plug into; returning `(result, events)` / `[CoreEvent]` directly
  to the caller is the only mechanism consistent with that design and with arbiter-03 § Q-F's stated façade
  convention, "(new value, `[CoreEvent]`) or throws a `CoreError`".
- IF a migration whose write-back to `url` fails should throw `CoreError.platformStateWriteFailed` (since the
  proximate cause is a write I/O failure) THEN it throws `platformStateUnreadable` instead — `docs/domains/
  platform.md` § W3's own text is explicit: "`PLATFORM_STATE_UNREADABLE` if migration fails — the old file is
  kept, a fresh state is used, nothing deleted" (quoted §3); the distinction is about outcome, not cause — a
  failed migration always resolves to "treat this state as unreadable, start fresh at course selection"
  (arbiter-03 § Q-E), never to a retry-the-write banner, which is what `platformStateWriteFailed`'s registered
  semantics (`"Yes — retried"`, `docs/domains/platform.md:101`) would incorrectly imply for a migration
  context.
- IF the pre-migration backup file's name/location should be a fixed constant exposed publicly (so 03.12's App
  shell or the simulator smoke could reference it directly) THEN it stays a private implementation detail,
  computed as `url.appendingPathExtension("pre-migration")` — no caller needs to know this name; the contract
  this task must satisfy is observable behaviour only ("no pre-migration file remains once the migrated one is
  written", arbiter-03 § Q-G, quoted in the dispatch context), which this task's own tests (§5 AC3, AC7)
  verify directly by constructing the same URL locally in the test file (documented alongside the product
  code's own doc comment so both stay in sync by inspection, mirroring `StateMerge`'s locally-duplicated
  constant pattern for `currentSchemaVersion`, `tasks/epic-02-task-12-state-merge.md` §4 step 1).
- IF `write(_:to:)` should create `url`'s containing directory when it is absent THEN it does not — "No
  Application Support path logic here (that is 03.12's App shell, named constant)" is the dispatch
  instruction's own boundary; this task's tests always `createDirectory` on their temp directory before
  calling `write`/`read` (the precedent idiom, §3), and a missing containing directory at `url` correctly
  surfaces as `CoreError.platformStateWriteFailed` (AC6) rather than being silently repaired.
- IF a `schema_version` of `0` or a negative integer should be treated as an implicit "even older, also
  migrate" case THEN it is treated as unreadable instead — the contract names exactly one migration path, "1
  → 2, the identity" (quoted §3); no `0 → 1` or negative-version migration exists anywhere in
  `contracts/data-model.md`, so any value outside the known `1...2` range is refused the same way a too-new
  value is (AC4c's sibling case, `decoded.schemaVersion >= 1` guard in §4 step 1).

Standing defaults: identifiers and timestamps are untouched by this task (no new `StudentState`/`NodeState`
field; `install_day`/log `day` values pass through `read`/`write` as opaque strings, never parsed or
reformatted here); model calls do not exist anywhere in this task's code (I2 vacuous); telemetry is unaffected
(`consent_on` passes through opaquely, same as every other field); no node's `paraphrase`/Ministry text is read
or touched (I6 — this task never opens a bundle).

## §7 Done definition

The task is done when ALL gates pass:

- `xcrun swift-format lint --strict --recursive --configuration .swift-format Packages App/Sources` — clean
  over the new product file and the new test file.
- `Core` build + test green: `( cd Packages/Core && swift build -c release --product core-cli )` and
  `( cd Packages/Core && xcodebuild test -quiet -scheme Core-Package -destination "$SIM"
  CODE_SIGNING_ALLOWED=NO )` (`scripts/gate.sh` gate 3, `$SIM` from `scripts/pick-simulator.sh`).
- All cases in §5 (T1–T6, AC1–AC7) pass.
- `ErrorRegistryTests`, `IdentifierBlocklistParityTests`, `coreImportBoundary()`, and
  `onlyCoreCodingConstructsCoders()` (all unmodified) stay green with no edit to any of their files.
- No stray `.tmp-`-prefixed or `.pre-migration`-suffixed file remains in any test's temp directory after its
  `defer` cleanup runs — asserted implicitly by every temp directory being freshly created and fully removed
  per test (T6).
- Conforms to every contract section cited in §3 (`contracts/data-model.md` § StudentState and § Versioning;
  `contracts/schemas/student-state.schema.json`; `docs/domains/platform.md` § W3 and § Errors produced;
  `contracts/error-codes.json`; `tasks/arbitration/arbiter-03-predispatch.md` § Q-F item 2;
  `docs/epics/epic-03-app-map-shell.md` § 4 AC 3) and to every invariant listed in §1 (I5, I14; I1/I2/I6 noted
  not engaged).
- `scripts/gate.sh` gate 3 green in full (gates 1, 2, 4 are format/pipeline/App-scoped and are unaffected by
  this task's file scope beyond gate 1's Swift formatting pass, which already covers `Packages` recursively).
