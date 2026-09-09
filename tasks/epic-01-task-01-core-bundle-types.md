# Epic 01 · Task 01: `Core` Codable bundle types, `CoreError`, bundle-directory I/O

---
epic: 01
task: 01
slug: core-bundle-types
kind: feat
risk: seam
depends_on: [none]
model: sonnet
---

> **Arbitrated 2026-09-09** (Q4, tester BLOCK `tasks/blocked/tester-blocked-01-01.md`, class
> testability-gap). The previous revision carried a contradiction between §4.1 (shared
> `.convertFromSnakeCase` decoder for every bundle type) and §4.10 (explicit snake_case `CodingKeys` on
> `StudentState` and its nested types); Foundation applies the key-decoding strategy to the incoming key
> **before** matching it against a `CodingKey` raw value, so the two are mutually exclusive. The settled
> convention is stated once, in §4.1 / §4.1.1: **one wire format, one key strategy, one coder pair in
> product code (`CoreCoding`)**, and no `Model/` type declares an explicit `CodingKeys`. AC6 changed
> instrument (from `CodingKeys` reflection to the re-encoded document's own key set) and AC9 is new. See
> the resolution note in the BLOCK file.

## §1 Goal & acceptance criteria

Goal: `Core` gains `Codable` Swift types for every bundle file (`manifest`, `regions`, `nodes`, `edges`,
`courses`, `landmarks`, `sources`) and for `StudentState`, plus one canonical JSON coder pair for that wire
format (`CoreCoding`), plus a `CoreError` enum mirroring the subset of `contracts/error-codes.json` that
`Core` actually raises in this EPIC's scope, plus deterministic bundle-directory read/write I/O (`BundleIO`).
This is the interface every later EPIC-01 task (L0 checker, layout, `core-cli`, the demo bundle) builds on —
it ships whole, with no placeholder types.

Invariants in play:

- **I1** — `ProbeItem` has no free-text answer field; numeric items carry `answer`/`wrong_answers`, `mc` items
  carry `choices`/`correct_choice_id`. The type shape makes a free-text answer field structurally impossible.
- **I5** — the **encoded** `StudentState` document exposes no key in the identifier blocklist. The guard is
  the wire key set of the re-encoded document, per `contracts/data-model.md` § StudentState — "**No field may
  name a person, device, account, install or session** (I5); the schema's closed key set is the guard" — not a
  Swift-side `CodingKeys` reflection; the Swift test mirrors
  `pipeline/tests/test_contracts.py::test_transmitted_shapes_reject_identifier_keys` in intent (identifier
  keys must not appear at any object nesting level).
- **I6** — no type carries a `verbatim` field; `Node.paraphrase` and `Expectation.paraphrase` are the only
  Ministry-adjacent prose fields, both bounded to the project's own words per schema (`maxLength: 140`).
- **I8** — the decode round-trip is the EPIC-time rung of the L0/decode contract; the types this task ships
  are exactly what the L0 checker (task 01.2) and layout (task 01.3) will operate on — no field is invented
  or omitted relative to the schemas.
- **I10** — `ProbeItem.type` is a closed `numeric | mc` enum; there is no OCR path and no free-text input type
  anywhere in the type set.
- **I14** — `Core` imports `Foundation` only; the existing import-boundary test is extended to walk
  `Sources/Core` recursively so the new `Model/` subdirectory is scanned; an empty scan is a FAIL.
  I14/D42's "anything the pipeline and the app must agree on is implemented **once, in `Core`**" covers the
  wire-format coder: the decode/encode recipe exists exactly once, in `Sources/Core/CoreCoding.swift`, and
  never in a test file (AC9).
- **I15** — `Landmark.sourceUrl` is a required, non-optional `String` field (https resolution is verified by
  the pipeline in task 01.7, not here).

Acceptance criteria:

- AC1: every file in `contracts/examples/` except `telemetry-batch.json` (8 files: `manifest.json`,
  `regions.json`, `nodes.json`, `edges.json`, `courses.json`, `landmarks.json`, `sources.json`,
  `student-state.json`) decodes into the `Core` types listed in §4 **through `CoreCoding.decoder`** and
  re-encodes **through `CoreCoding.encoder`** to a structurally JSON-equal document (key order excluded); all
  eight files, `student-state.json` included, go through that one pair with no per-file or per-type decoder
  override. The instrument is `DecodeRoundTripTests.decodeRoundTrip()`; it enumerates the files it read and
  fails on an empty or partial list (empty = FAIL).
- AC2: `telemetry-batch.json` is excluded by name from the round-trip test, with a comment stating there is no
  `Core` type for it (telemetry is EPICs 10–11's scope).
- AC3: every case of `CoreError` is present in `contracts/error-codes.json`, read from disk at test time; an
  empty `CoreError` case set or an empty registry read is a FAIL.
- AC4: the `Core`-imports-Foundation-only boundary test walks `Sources/Core` recursively (not just its top
  level) and passes with the new `Model/` subdirectory in place; an empty scan is a FAIL.
- AC5: round-tripping an example that omits an optional key (e.g. the first node in `nodes.json`, which has
  no `layout_hint`) never emits `null` for that key in the re-encoded document.
- AC6: encoding the `StudentState` decoded from `contracts/examples/student-state.json` through
  `CoreCoding.encoder` produces a document whose object keys, collected recursively at every nesting level,
  are disjoint from the identifier blocklist `{id, install_id, device_id, session_id, user_id, ip, timestamp,
  email, name}`. The instrument is the recursive key collector in `DecodeRoundTripTests` (§4.13); it excludes
  no nesting level and no key; empty = FAIL — the collected set must first be asserted a superset of the ten
  top-level required names of `contracts/schemas/student-state.schema.json` (`schema_version`,
  `format_version_seen`, `syllabi`, `marker`, `nodes`, `trail`, `expedition_log`, `probe_log`, `install_day`,
  `consent_on`), so a collector that silently returned nothing cannot pass.
- AC7: `BundleIO.read` throws `CoreError.platformBundleIntegrityFailed` when a file named in `manifest.files`
  is absent from the target directory, and does not return a partially constructed bundle.
- AC8: `scripts/gate.sh` gate 1 (format+lint) and gate 3 (Core build+test) are green with the new files
  included.
- AC9: no file under `Packages/Core/Sources/Core/` other than `CoreCoding.swift` contains the text
  `JSONDecoder(` or `JSONEncoder(` — the wire-format decode/encode recipe lives in product code, exactly once.
  The instrument is the recursive source scan in `CoreTests.swift` (§4.17). It scans `Sources/Core` only and
  explicitly **excludes** `Tests/CoreTests` (that tree also decodes non-wire JSON — `contracts/error-codes.json`
  in `ErrorRegistryTests` — and contains files other EPIC-01 tasks own, so scanning it would couple this task
  to theirs). Empty = FAIL: the scan must find a non-empty `.swift` file list, and must find `CoreCoding.swift`
  itself containing both texts.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Core/Sources/Core/CoreCoding.swift` — **the one** `JSONDecoder`/`JSONEncoder` configuration for
  the bundle wire format and `student-state.json` (§4.1.1).
- `Packages/Core/Sources/Core/Model/Ids.swift` — shared id/point/region-vocabulary primitives (`Point`,
  `RegionId`) used by more than one bundle file's types.
- `Packages/Core/Sources/Core/Model/Manifest.swift` — `Codable` type for `manifest.json`.
- `Packages/Core/Sources/Core/Model/Regions.swift` — `Codable` types for `regions.json`.
- `Packages/Core/Sources/Core/Model/Nodes.swift` — `Codable` types for `nodes.json`.
- `Packages/Core/Sources/Core/Model/Edges.swift` — `Codable` types for `edges.json`.
- `Packages/Core/Sources/Core/Model/Courses.swift` — `Codable` types for `courses.json`.
- `Packages/Core/Sources/Core/Model/Landmarks.swift` — `Codable` types for `landmarks.json`.
- `Packages/Core/Sources/Core/Model/Sources.swift` — `Codable` types for `sources.json`.
- `Packages/Core/Sources/Core/Model/StudentState.swift` — `Codable` type for `student-state.json`.
- `Packages/Core/Sources/Core/BundleIO.swift` — deterministic bundle-directory read/write; manifest
  file-presence completeness check.
- `Packages/Core/Sources/Core/CoreError.swift` — the `CoreError` enum.
- `Packages/Core/Sources/Core/Core.swift` — MODIFY: remove the stale "Phase 5 placeholder; the first EPIC
  replaces it" comment (this task is that replacement); `CoreInfo.dataFormatVersion` value stays `"0.0.0"`.
- `Packages/Core/Tests/CoreTests/DecodeRoundTripTests.swift` — the AC1/AC2/AC5/AC6 round-trip and I5 tests.
- `Packages/Core/Tests/CoreTests/ErrorRegistryTests.swift` — the AC3 registry test.
- `Packages/Core/Tests/CoreTests/CoreTests.swift` — MODIFY: `coreImportBoundary()` walks `Sources/Core`
  recursively; plus the AC9 single-coder scan (§4.17).

File-scope delta recorded by arbitration: `Packages/Core/Sources/Core/CoreCoding.swift` is new relative to the
previous revision of this spec and to §L of the context bundle. It is required by AC9 — the tester's BLOCK is
precisely that the only working recipe lived in `Tests/CoreTests`. It is a sibling of `BundleIO.swift` rather
than a member of it, because `student-state.json` is not part of `ContentBundle` (§4.12) yet shares the wire
format (`contracts/data-model.md`: "The shapes every bundle file, the student state and `Core`'s `Codable`
types share"). No other task's file scope touches it.

Note on §L of the context bundle: it lists `Model/Ids.swift` implicitly by omission (it did not name a file
for `Point`/`RegionId`); this spec adds `Model/Ids.swift` as the explicit home for those shared primitives so
no other `Model/*.swift` file needs to forward-declare a type another file also declares. This and
`CoreCoding.swift` are the only two places this spec's file list is more specific than the context bundle's
§L, and both stay inside the `Packages/Core/Sources/Core/` tree the bundle already scoped.

Any additional test file created under `Packages/Core/Tests/CoreTests/` while executing this task (by the
implementer or the tester) decodes and encodes wire-format types through `CoreCoding` and declares no
`JSONDecoder`/`JSONEncoder` of its own. This is a spec instruction, not a scope claim: those files are not
listed above and AC9's scan does not read `Tests/CoreTests`.

Out-of-scope (do not touch even if tempted):

- `Packages/Core/Sources/Core/Layout*.swift`, `L0*.swift`, `Validation/**`, any validation function — task
  01.2 (L0) / 01.3 (layout).
- `Packages/Core/Sources/CoreCLI/**` — task 01.4.
- `data/demo/**` — task 01.5.
- `Packages/Rendering/**` — task 01.6.
- `pipeline/**` — tasks 01.4 and 01.7.
- `contracts/**` — read-only, ground truth.
- `App/Sources/**` — no rendering or app-layer work in this EPIC (see brief §7).

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/data-model.md` — the contract's own opening statement of scope:
  > The shapes every bundle file, the student state and `Core`'s `Codable` types share. The **JSON Schemas in
  > `contracts/schemas/` are normative**; this file states the rules the schemas cannot. `Core` decodes exactly
  > these shapes (a decode test over `contracts/examples/` is owed by the Demo EPIC); Android's `core` will
  > too (D33). Retrofitting corrupts shipped bundles and synced state — locked first.

- `contracts/data-model.md` — heading `### Identifiers`:
  > Ids are **stable, opaque, lowercase kebab-case slugs** matching `^[a-z0-9]+(-[a-z0-9]+)*$`, unique within
  > their collection. Never parse meaning from an id; never renumber. A renamed concept keeps its id.
  > Fixed vocabularies: `region_id ∈ {number-operations, algebra, functions, geometry-measurement, trigonometry,
  > calculus, linear-algebra, differential-equations, probability-statistics, discrete}` plus horizon labels
  > `{analysis, topology, number-theory, abstract-algebra}` (flag `horizon: true`) and optional `shore`.
  > `course_code` is the Ministry code verbatim in upper case (`MTH1W`, `MCR3U`); `unit_id` is
  > `<course_code>.u<n>` (1-based, in unit order); `edge_id` is `<from>-->-<to>` (derived, never stored on the
  > edge); `expectation_code` is the Ministry code verbatim (e.g. `B2.3`), scoped by course.
  > Undergraduate `source_ref` is `{ source: "openstax" | "mit-ocw", edition, locator }` where `locator` is the
  > section/chapter path the source publishes; it must resolve (L0-3b).

- `contracts/data-model.md` — heading `### Versioning`:
  > Every bundle file carries `format_version` (semver) = `CoreInfo.dataFormatVersion`; a major bump means
  > `Core` needs a migration; the app refuses a bundle whose major differs from its own.
  > `manifest.json` lists every file with `asset_version` (id) and `sha256`; a partial manifest is never
  > activated (platform W2). Bundle files are **immutable**: a change is a new `asset_version`.
  > `StudentState.schema_version` (integer) is migrated forward only (platform W3); older files are kept.

- `contracts/data-model.md` — heading `### Nulls, enums, unknowns`:
  > Optional means the key is **absent**, never `null`. Enums are closed; an unknown value fails decode.
  > Every object schema sets `additionalProperties: false` — a new field is a versioned change.

- `contracts/data-model.md` — heading `### ProbeItem (inside nodes.json)`:
  > `id`, `type ∈ {numeric, mc}`, `prompt_latex`, `why`, and either `answer {value (string, normalised decimal
  > or rational), tolerance (≥ 0, default 0)}` with `wrong_answers[] {value, error_type_id}` (numeric) or
  > `choices[] {id, latex, error_type_id?}` + `correct_choice_id` (mc; every non-correct choice carries an
  > `error_type_id`). No free-text answer field exists (I1, I10).

- `contracts/data-model.md` — heading `### StudentState (student-state.schema.json)`:
  > `schema_version`, `format_version_seen`, `syllabi[]` (course codes), `marker {course_code, unit_id}`,
  > `nodes {node_id → {mastery ∈ {fog, cleared, blocked}, correct_count, last_probe?, next_due?, ladder_rung}}`,
  > `trail {segments[] {kind ∈ {course, extension}, course_code?, node_ids[]}}` (derived, cached),
  > `expedition_log[] {day, item_count, cleared, blocked, abandoned, diagnosis_events}`,
  > `probe_log[] {day, node_id, item_id, correct, retry}`, `install_day`, `consent_on`. **No field may name a
  > person, device, account, install or session** (I5); the schema's closed key set is the guard.

- `contracts/data-model.md` — heading `## Enforcement`:
  > - Demo EPIC: `CoreTests` decode every example file into the `Core` types and re-encode byte-equal (modulo
  >   key order); `core-cli validate` runs L0 (`graph-constraints.md`).

- `contracts/error-codes.md` — heading `## Rules`:
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

- `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md` §3 (MANDATORY artifact line, binding this task's
  `CoreError` case set):
  > `contracts/error-codes.md` + `error-codes.json` — `GRAPH_L0_FAILED`, `MAP_LAYOUT_MISSING`,
  > `MAP_REGION_UNKNOWN`, `MAP_LANDMARK_UNSOURCED`, `SPINE_UNIT_EMPTY`, `SPINE_SOURCE_REF_UNRESOLVED`,
  > `LO_ITEM_UNRENDERABLE`, `LO_BAD_DISTRACTOR_TAG`. `READ-ONLY`. `CoreError` mirrors these (registry ⊇ enum
  > test).

- `docs/plans/epic-01-task-plan.md` planner note 4:
  > `Core`'s `validate` stays exactly L0-1 … L0-10 — no LO-prefixed checks are bolted into the L0 report.
  > Renderability (`LO_ITEM_UNRENDERABLE`) goes to 01.6 (`Rendering`); distractor tags, SymPy re-derivation and
  > landmark resolution go to 01.7 (pipeline), per `docs/tech-stack.md` §2 ownership.

  Consequence for this task: `LO_ITEM_UNRENDERABLE` and `LO_BAD_DISTRACTOR_TAG` are NOT `CoreError` cases —
  they belong to `Packages/Rendering` and `pipeline/` respectively, never to `Core`. `CoreError`'s case set is
  therefore the epic brief §3 list minus those two `LO_*` codes, plus `PLATFORM_BUNDLE_INTEGRITY_FAILED` (see
  §6 default on `PLATFORM_BUNDLE_INTEGRITY_FAILED`).

- `docs/plans/epic-01-task-plan.md` planner note 2:
  > `core-cli validate` cannot verify SHA-256 without importing CryptoKit into `Core` (breaks D33/I14) or
  > hand-rolling it (breaks RULE 2). Default adopted: `core-cli validate` enforces manifest *completeness and
  > file presence* (`PLATFORM_BUNDLE_INTEGRITY_FAILED`, exactly what the brief's R-6 line requires); hash
  > *computation* is a Python `hashlib` helper in the pipeline; hash *verification at load* defers to EPIC 03's
  > App-side loader.

  Consequence for this task: `BundleIO` in `Core` never computes or verifies `sha256`; `Manifest.files[].sha256`
  is a stored `String` field only. `BundleIO.read` performs the file-presence half of manifest completeness
  (every name in `manifest.files` exists in the target directory) since it is the function that walks the
  directory; the *L0-report* framing of `PLATFORM_BUNDLE_INTEGRITY_FAILED` (as `core-cli validate`'s refusal)
  is task 01.2/01.4's concern — this task's `BundleIO` raises the same `CoreError` case for the same
  underlying condition (a listed file missing on disk) because that condition can only be observed while
  reading the directory.

Wire-key evidence for the settled Codable strategy (§4.1), gathered by arbitration in this run:

- `contracts/schemas/student-state.schema.json` `nodes.propertyNames.pattern` (line 42–44) is
  `"^[a-z0-9]+(-[a-z0-9]+)*$"`; `contracts/schemas/nodes.schema.json`'s `hint_tree` keys are `error_type_id`
  slugs of the same shape (`contracts/examples/nodes.json:37` `"added-exponents-on-power"`,
  `contracts/examples/nodes.json:113` `"base-exponent-swapped"`). Those are the only two dictionary-keyed
  positions in the whole wire format, and kebab-case slugs contain neither `_` nor an upper-case letter, so
  both Foundation key strategies pass them through unchanged.
- The only key containing a digit anywhere in the seven `Core`-typed bundle files is `sha256`
  (`contracts/examples/manifest.json:15,20,25,30,35`); it has no `_` and no upper-case letter, so it is also
  unchanged in both directions. The one digit-adjacent boundary key in `contracts/examples/`,
  `tier1_available` (`contracts/examples/telemetry-batch.json:55`), is in the one file that has **no** `Core`
  type (AC2).

Prior signatures (verbatim, from `Packages/Core/Sources/Core/Core.swift`, read in this run):

```swift
import Foundation

/// Core — the renderer-free heart of mathmath (D33, I14).
///
/// Graph data types, L0 validation, layout, the expedition scheduler and student-state transitions
/// live here and only here (D42). This file is the Phase 5 placeholder; the first EPIC replaces it.
public enum CoreInfo {
    /// Semantic version of the shared JSON data formats consumed by `Core` (shared with the Android port).
    public static let dataFormatVersion = "0.0.0"
}
```

Prior signature (verbatim, from `Packages/Core/Tests/CoreTests/CoreTests.swift`, read in this run):

```swift
import Foundation
import Testing

@testable import Core

@Suite("Core package")
struct CoreTests {
    @Test("data format version is a semantic version")
    func dataFormatVersion() {
        let parts = CoreInfo.dataFormatVersion.split(separator: ".")
        #expect(parts.count == 3)
        #expect(parts.allSatisfy { Int($0) != nil })
    }

    /// I14 / D33: `Core` imports Foundation only. Scans every source file of the Core target for
    /// forbidden imports; an empty scan is a FAIL (C3), so a moved directory cannot pass silently.
    @Test("Core imports Foundation only (I14)")
    func coreImportBoundary() throws {
        let forbidden = [
            "SwiftUI", "UIKit", "AppKit", "SpriteKit", "SwiftData", "FoundationModels", "CoreData", "Combine",
        ]
        let sourcesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root
            .appendingPathComponent("Sources/Core")
        let files = try FileManager.default.contentsOfDirectory(
            at: sourcesDir, includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "swift" }
        #expect(!files.isEmpty, "no Core source files found — empty scan is a FAIL")
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for line in text.split(separator: "\n") where line.hasPrefix("import ") {
                let module = line.dropFirst("import ".count).trimmingCharacters(in: .whitespaces)
                #expect(!forbidden.contains(module), "\(file.lastPathComponent) imports \(module)")
            }
        }
    }
}
```

Prior signature (verbatim, from `Packages/Core/Package.swift`, read in this run — confirms package/test target
names used by §4/§5 below):

```swift
// swift-tools-version: 6.2
// Core — graph data, L0 validation, layout, scheduler, state transitions (D33).
// Imports Foundation only. No SwiftUI / UIKit / SpriteKit / SwiftData (I14) — asserted by CoreTests.

import PackageDescription

let package = Package(
    name: "Core",
    platforms: [
        .iOS(.v18),  // D34: Doors B/C and Tier 0 diagnosis on iOS/iPadOS 18+
        .macOS(.v15),  // host platform for the CLI target and the pipeline (D42)
    ],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .executable(name: "core-cli", targets: ["CoreCLI"]),
    ],
    targets: [
        .target(
            name: "Core",
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")]
        ),
        .executableTarget(
            name: "CoreCLI",
            dependencies: ["Core"]
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
```

Identifier blocklist (verbatim, from `pipeline/tests/test_contracts.py:26-36`, read in this run — the exact
set §4/§5's I5 guard test mirrors):

```python
IDENTIFIER_BLOCKLIST = {
    "id",
    "install_id",
    "device_id",
    "session_id",
    "user_id",
    "ip",
    "timestamp",
    "email",
    "name",
}
```

Registry codes this task's `CoreError` cases must be a subset of (verbatim, from `contracts/error-codes.json`,
read in this run — showing exactly the seven entries `CoreError` mirrors):

```json
{"code": "GRAPH_L0_FAILED", "recoverable": true, "surface": "internal", "user_text": null},
{"code": "MAP_LAYOUT_MISSING", "recoverable": true, "surface": "internal", "user_text": null},
{"code": "MAP_REGION_UNKNOWN", "recoverable": true, "surface": "internal", "user_text": null},
{"code": "MAP_LANDMARK_UNSOURCED", "recoverable": true, "surface": "internal", "user_text": null},
{"code": "SPINE_UNIT_EMPTY", "recoverable": true, "surface": "owner", "user_text": null},
{"code": "SPINE_SOURCE_REF_UNRESOLVED", "recoverable": true, "surface": "owner", "user_text": null},
{"code": "PLATFORM_BUNDLE_INTEGRITY_FAILED", "recoverable": true, "surface": "student", "user_text": "Could not refresh content; still using the installed version."}
```

Gate commands (verbatim, from `scripts/gate.sh`, read in this run):

```sh
echo "== 1/4 format + lint =="
xcrun swift-format lint --strict --recursive --configuration "$ROOT/.swift-format" "$ROOT/Packages" "$ROOT/App/Sources"

echo "== 3/4 Core: build + test on the iOS simulator (D29) =="
( cd "$ROOT/Packages/Core" && swift build -c release --product core-cli )
( cd "$ROOT/Packages/Core" && xcodebuild test -quiet -scheme Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO )
```

Test framework (confirmed by the prior signature above and `docs/tech-stack.md`): **Swift Testing**
(`import Testing`, `@Suite`, `@Test`, `#expect`) — not XCTest.

## §4 Implementation outline

Layer placement: these types are layer ① (spine — `Manifest`, `Course`/`Unit`/`Expectation`), layer ②
(concept graph — `Node`, `Edge`, `Region`), layer ③ (learning objects — `ErrorType`, `HintTree`, `ProbeItem`,
`WorkedExample`, `Landmark`) shapes. `Core` is their only implementation (I14, D42).

All new `Model/*.swift` files begin `import Foundation` (matches `Core.swift`'s existing convention; `Core`
still imports Foundation only — I14). Every struct/enum is `public` (consumed by `CoreCLI`, `CoreTests`, and
later by `App/Sources`/`pipeline` through `core-cli`).

### 4.1 Codable strategy (settled — applies to EVERY type below, `StudentState` included)

**One wire format, one key strategy, one coder pair.** `contracts/data-model.md` opens by defining a single
shape set that "every bundle file, the student state and `Core`'s `Codable` types share" (§3); this spec
therefore defines exactly one decode/encode configuration for all eight documents.

- Swift property names are `camelCase`; JSON keys are `snake_case`. The conversion is done by Foundation's key
  strategies — `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` and
  `JSONEncoder.keyEncodingStrategy = .convertToSnakeCase` — configured **once**, in `CoreCoding` (§4.1.1).
- **No type in `Sources/Core/Model/` declares an explicit `CodingKeys` enum.** `.convertFromSnakeCase`
  transforms the incoming JSON key *before* Foundation matches it against a `CodingKey` raw value, so an
  explicit `CodingKeys` case whose raw value is already snake_case (`case courseCode = "course_code"`) can
  never match: the decoder has already turned `course_code` into `courseCode` and throws `keyNotFound`. An
  explicit snake_case `CodingKeys` and `.convertFromSnakeCase` are mutually exclusive; this spec chooses the
  key strategy, so the explicit `CodingKeys` go. (The encode direction hides the bug —
  `.convertToSnakeCase` is a no-op on an already-snake_case key — which is why a decoder/encoder mismatch can
  pass a round-trip test while product code is broken. Do not rely on that.)
- This is safe for the whole wire format, verified key by key in §3's "Wire-key evidence": no key in the eight
  documents needs an explicit `CodingKeys`. There is **no** acronym run and **no** digit-adjacent boundary
  that the conversion cannot express in the seven `Core`-typed bundle files or in `student-state.json`; the
  only digit-bearing key, `sha256`, is all-lower-case and passes through both strategies unchanged, and the
  only two dictionary-keyed positions (`StudentState.nodes` keyed by node id, `Node.hintTree` keyed by
  `error_type_id`) hold kebab-case slugs, which contain no `_` and no upper-case letter and are likewise
  unchanged in both directions.
- Do not name a Swift property with an internal capital-run acronym (`sourceURL`, `nodeID`) — use
  `sourceUrl`, `nodeId` etc. `.convertToSnakeCase`/`.convertFromSnakeCase` only round-trips correctly for
  single-capital word boundaries; an acronym run breaks the round trip.
- Optional fields are Swift `Optional` stored properties on structs using the **compiler-synthesized**
  `Codable` conformance (no hand-written `init(from:)`/`encode(to:)`). Swift's synthesized `Encodable` calls
  `encodeIfPresent` for `Optional`-typed stored properties, which omits the key entirely when the value is
  `nil` — this is what satisfies "optional means absent, never null" (`contracts/data-model.md` § Nulls) and
  AC5. Do not write a manual `encode(to:)` that calls `container.encode(_:forKey:)` on an `Optional` value —
  that emits `null`.
- Closed vocabularies are `enum SomeName: String, Codable` (and `CaseIterable` where a test needs to
  enumerate cases, e.g. `CoreError`). A raw-value-backed enum's synthesized `init(from:)` already throws on an
  unrecognized string — this is what satisfies "enums are closed; an unknown value fails decode" without extra
  code. (Key strategies do not touch enum raw values; only keys.)
- String fields whose JSON Schema carries a `pattern` (ids, `course_code`, `sha256`, dates, `source_url`,
  `official_url`) are plain `String` in `Core`'s types. Pattern conformance is a schema/pipeline-layer
  concern (`pipeline/tests/test_contracts.py`) and an L0 concern where graph-constraints.md names it; `Core`'s
  `Codable` layer decodes the shape, not the pattern. Do not add regex validation in `init(from:)`.
- Date-shaped fields (`built_at`, `last_probe`, `next_due`, `day`, `install_day`) are plain `String`, never
  `Foundation.Date`. `contracts/data-model.md` § Time distinguishes calendar-day strings (`YYYY-MM-DD`) from
  ISO 8601 UTC timestamps (`built_at`); converting either to `Date` and back risks losing the exact source
  text, which would break the byte-for-shape round-trip AC1 requires. Round-tripping as `String` is exact by
  construction. `CoreCoding` therefore sets no `dateDecodingStrategy`/`dateEncodingStrategy`.

### 4.1.1 `Packages/Core/Sources/Core/CoreCoding.swift`

The single decode/encode recipe, in product code. Every consumer — `BundleIO` (§4.12), `CoreTests` (§4.13),
and later EPIC 02's state transitions and EPIC 03's App loader — uses this pair; nothing else in `Core`
constructs a `JSONDecoder` or `JSONEncoder` (AC9).

```swift
import Foundation

/// The one JSON coder configuration for the bundle wire format and `student-state.json`.
///
/// `contracts/data-model.md` defines one shape set that "every bundle file, the student state and
/// `Core`'s `Codable` types share", so there is one key strategy: JSON keys are snake_case, Swift
/// properties are camelCase, and Foundation converts between them. No `Model/` type declares an
/// explicit `CodingKeys` — `.convertFromSnakeCase` rewrites the incoming key before it is matched
/// against a `CodingKey` raw value, so the two mechanisms cannot be combined.
public enum CoreCoding {
    /// A fresh decoder per access: `JSONDecoder` is a non-`Sendable` class, so a shared `static let`
    /// would not compile under Swift 6 strict concurrency.
    public static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    /// `.sortedKeys` is what makes `BundleIO.write` deterministic — byte-identical output for
    /// byte-identical input across runs. It is harmless for every other consumer because every
    /// comparison in this task's tests is structural (key order excluded).
    public static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
```

Nothing else belongs in this file: no `decode`/`encode` wrapper functions, no per-type coder, no
`StudentStateIO`. Two configured coders are the whole deliverable (RULE 2).

### 4.2 `Packages/Core/Sources/Core/Model/Ids.swift`

Shared primitives used by more than one of the files below (placed here so no other `Model/*.swift` file
needs to declare a type another file also needs):

```swift
public struct Point: Codable, Equatable {
    public let x: Double
    public let y: Double
}

public enum RegionId: String, Codable, CaseIterable {
    case numberOperations = "number-operations"
    case algebra = "algebra"
    case functions = "functions"
    case geometryMeasurement = "geometry-measurement"
    case trigonometry = "trigonometry"
    case calculus = "calculus"
    case linearAlgebra = "linear-algebra"
    case differentialEquations = "differential-equations"
    case probabilityStatistics = "probability-statistics"
    case discrete = "discrete"
    case analysis = "analysis"
    case topology = "topology"
    case numberTheory = "number-theory"
    case abstractAlgebra = "abstract-algebra"
    case shore = "shore"
}
```

`RegionId` is the 15-case superset from `contracts/schemas/regions.schema.json`'s `id`/`neighbours` enum (ten
regions + four horizon labels + `shore`). `contracts/schemas/nodes.schema.json`'s `region_id` and
`contracts/schemas/landmarks.schema.json`'s `region_ids` use a **narrower** 10-value enum (no horizon, no
`shore`) — see §6 default on why `Node`/`Landmark` reuse this same `RegionId` type rather than a second,
narrower enum.

### 4.3 `Packages/Core/Sources/Core/Model/Manifest.swift`

Fields per `contracts/schemas/manifest.schema.json` (read directly in this run; required list:
`format_version, bundle_id, spine_version, graph_version, built_at, starting_chain, files`):

```swift
public struct Manifest: Codable, Equatable {
    public let formatVersion: String
    public let bundleId: String
    public let spineVersion: String
    public let graphVersion: String
    public let builtAt: String
    public let startingChain: [String]
    public let files: [ManifestFile]
}

public struct ManifestFile: Codable, Equatable {
    public let name: String
    public let assetVersion: String
    public let sha256: String
}
```

`ManifestFile.name` stays `String` (not an enum of the six bundle filenames) — the schema's `enum` on `name`
is a pipeline/L0-layer check, not a `Core` decode concern (§4.1).

### 4.4 `Packages/Core/Sources/Core/Model/Regions.swift`

Fields per `contracts/schemas/regions.schema.json` (read directly in this run; region required list: `id,
name, about, horizon, polygon, neighbours`):

```swift
public struct RegionsFile: Codable, Equatable {
    public let formatVersion: String
    public let regions: [Region]
}

public struct Region: Codable, Equatable {
    public let id: RegionId
    public let name: String
    public let about: String
    public let horizon: Bool
    public let polygon: [Point]
    public let neighbours: [RegionId]
}
```

### 4.5 `Packages/Core/Sources/Core/Model/Nodes.swift`

Fields per `contracts/schemas/nodes.schema.json` (full file read directly in this run). Node required list:
`id, name, region_id, courses, position, paraphrase, error_types, hint_tree, probe_items`; optional:
`strand, expectation_codes, source_ref, layout_hint, explanation, worked_examples`; the schema's `anyOf`
requires at least one of `expectation_codes`/`source_ref` — **not enforced at Codable decode time**, see §6.

```swift
public struct NodesFile: Codable, Equatable {
    public let formatVersion: String
    public let nodes: [Node]
}

public struct Node: Codable, Equatable {
    public let id: String
    public let name: String
    public let regionId: RegionId
    public let strand: String?
    public let expectationCodes: [NodeExpectationCode]?
    public let sourceRef: SourceRef?
    public let courses: [NodeCourse]
    public let position: Point
    public let layoutHint: Point?
    public let paraphrase: String
    public let explanation: String?
    public let workedExamples: [WorkedExample]?
    public let errorTypes: [ErrorType]
    public let hintTree: [String: [String]]
    public let probeItems: [ProbeItem]
}

public struct NodeExpectationCode: Codable, Equatable {
    public let courseCode: String
    public let code: String
}

public struct NodeCourse: Codable, Equatable {
    public let courseCode: String
    public let depth: Int
}

public struct SourceRef: Codable, Equatable {
    public let source: UndergraduateSourceName
    public let edition: String
    public let locator: String
}

public struct WorkedExample: Codable, Equatable {
    public let id: String
    public let stepsLatex: [String]
}

public struct ErrorType: Codable, Equatable {
    public let id: String
    public let label: String
    public let impliesPrerequisite: String?
}

public struct ProbeItem: Codable, Equatable {
    public let id: String
    public let type: ProbeItemType
    public let promptLatex: String
    public let why: String
    public let renderFallback: RenderFallback?
    public let answer: ProbeAnswer?
    public let wrongAnswers: [WrongAnswer]?
    public let choices: [ProbeChoice]?
    public let correctChoiceId: String?
}

public enum ProbeItemType: String, Codable {
    case numeric
    case mc
}

public enum RenderFallback: String, Codable {
    case katex
}

public struct ProbeAnswer: Codable, Equatable {
    public let value: String
    public let tolerance: Double?
}

public struct WrongAnswer: Codable, Equatable {
    public let value: String
    public let errorTypeId: String
}

public struct ProbeChoice: Codable, Equatable {
    public let id: String
    public let latex: String
    public let errorTypeId: String?
}
```

`hintTree` is `[String: [String]]`, keyed by `error_type_id`, each value an ordered `[tier1, tier2, tier3]`.
Its dictionary keys are kebab-case slugs and therefore pass through both key strategies unchanged (§4.1). The
schema bounds each array to exactly 3 items (`minItems`/`maxItems: 3`) — not enforced at decode time
(§4.1's pattern rule: shape, not constraint, is `Core`'s job here).

`SourceRef.source` and `UndergraduateSourceName` are declared once, in `Model/Sources.swift` (§4.9), and
referenced here — both files are the same `Core` module, no import needed.

### 4.6 `Packages/Core/Sources/Core/Model/Edges.swift`

Fields per `contracts/schemas/edges.schema.json` (read directly in this run; edge required list: `from, to,
sources, generation_agreement, confidence, probe_stats`; `probe_stats` required list: `probes, confirmed`):

```swift
public struct EdgesFile: Codable, Equatable {
    public let formatVersion: String
    public let edges: [Edge]
}

public struct Edge: Codable, Equatable {
    public let from: String
    public let to: String
    public let sources: [EdgeSource]
    public let generationAgreement: Int
    public let confidence: Double
    public let probeStats: ProbeStats
}

public struct EdgeSource: Codable, Equatable {
    public let tag: EdgeSourceTag
    public let origin: String
}

public enum EdgeSourceTag: String, Codable {
    case ministryPrereq = "ministry_prereq"
    case textbookOrder = "textbook_order"
    case thirdPartyStructure = "third_party_structure"
    case modelGenerated = "model_generated"
}

public struct ProbeStats: Codable, Equatable {
    public let probes: Int
    public let confirmed: Int
    public let downstreamFailGivenUpstreamFail: Double?
}
```

### 4.7 `Packages/Core/Sources/Core/Model/Courses.swift`

Fields per `contracts/schemas/courses.schema.json` (read directly in this run; course required list:
`course_code, name, vintage, strands, expectations, units, next_courses`; `unit_source` optional):

```swift
public struct CoursesFile: Codable, Equatable {
    public let formatVersion: String
    public let courses: [Course]
}

public struct Course: Codable, Equatable {
    public let courseCode: String
    public let name: String
    public let vintage: String
    public let strands: [Strand]
    public let expectations: [Expectation]
    public let units: [Unit]
    public let unitSource: UnitSource?
    public let nextCourses: [String]
}

public struct Strand: Codable, Equatable {
    public let code: String
    public let name: String
}

public struct Expectation: Codable, Equatable {
    public let code: String
    public let kind: ExpectationKind
    public let paraphrase: String
    public let officialUrl: String
    public let unitId: String
}

public enum ExpectationKind: String, Codable {
    case overall
    case specific
}

public struct Unit: Codable, Equatable {
    public let unitId: String
    public let name: String
    public let expectationCodes: [String]
}

public struct UnitSource: Codable, Equatable {
    public let title: String
    public let edition: String
}
```

### 4.8 `Packages/Core/Sources/Core/Model/Landmarks.swift`

Fields per `contracts/schemas/landmarks.schema.json` (read directly in this run; landmark required list: `id,
name, what_it_is, source_url, node_ids, region_ids, position`):

```swift
public struct LandmarksFile: Codable, Equatable {
    public let formatVersion: String
    public let landmarks: [Landmark]
}

public struct Landmark: Codable, Equatable {
    public let id: String
    public let name: String
    public let whatItIs: String
    public let sourceUrl: String
    public let nodeIds: [String]
    public let regionIds: [RegionId]
    public let position: Point
}
```

`sourceUrl` is a required, non-optional `String` — I15's "a landmark that cannot be sourced is dropped, never
invented" is satisfied structurally: there is no code path that constructs a `Landmark` without a
`source_url`, because decode fails without one (the field is required, not optional).

### 4.9 `Packages/Core/Sources/Core/Model/Sources.swift`

Fields per `contracts/schemas/sources.schema.json` (read directly in this run; source required list: `source,
title, edition, licence, attribution, url`):

```swift
public struct SourcesFile: Codable, Equatable {
    public let formatVersion: String
    public let sources: [UndergraduateSource]
}

public struct UndergraduateSource: Codable, Equatable {
    public let source: UndergraduateSourceName
    public let title: String
    public let edition: String
    public let licence: Licence
    public let attribution: String
    public let url: String
}

public enum UndergraduateSourceName: String, Codable {
    case openstax
    case mitOcw = "mit-ocw"
}

public enum Licence: String, Codable {
    case ccBy4 = "CC BY 4.0"
    case ccByNcSa4 = "CC BY-NC-SA 4.0"
}
```

### 4.10 `Packages/Core/Sources/Core/Model/StudentState.swift`

Fields per `contracts/schemas/student-state.schema.json` (read directly in this run; top-level required list:
`schema_version, format_version_seen, syllabi, marker, nodes, trail, expedition_log, probe_log, install_day,
consent_on`; `nodes` values required list: `mastery, correct_count, ladder_rung`; `expedition_log` item
required list: `day, item_count, cleared, blocked, abandoned, diagnosis_events`; `probe_log` item required
list: `day, node_id, item_id, correct, retry`).

`StudentState` follows §4.1 exactly like the seven bundle types: **no explicit `CodingKeys` on any type
below**, camelCase properties, `CoreCoding` supplies the conversion. It is decoded and encoded with
`CoreCoding.decoder`/`CoreCoding.encoder` — the same pair as every other document — from product code and
from tests alike.

```swift
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
}

public struct NodeState: Codable, Equatable {
    public let mastery: Mastery
    public let correctCount: Int
    public let lastProbe: String?
    public let nextDue: String?
    public let ladderRung: Int
}

public enum Mastery: String, Codable {
    case fog
    case cleared
    case blocked
}

public struct Trail: Codable, Equatable {
    public let segments: [TrailSegment]
}

public struct TrailSegment: Codable, Equatable {
    public let kind: SegmentKind
    public let courseCode: String?
    public let nodeIds: [String]
}

public enum SegmentKind: String, Codable {
    case course
    case `extension`
}

public struct ExpeditionLogEntry: Codable, Equatable {
    public let day: String
    public let itemCount: Int
    public let cleared: Int
    public let blocked: Int
    public let abandoned: Bool
    public let diagnosisEvents: Int
}

public struct ProbeLogEntry: Codable, Equatable {
    public let day: String
    public let nodeId: String
    public let itemId: String
    public let correct: Bool
    public let retry: Bool
}
```

`StudentState.nodes` is `[String: NodeState]`, keyed by node id (`propertyNames` pattern
`^[a-z0-9]+(-[a-z0-9]+)*$`); the node id is a **dictionary key**, not a field name, and kebab-case slugs are
unchanged by both key strategies (§4.1).

The I5 guard is the **wire key set of the re-encoded document**, not Swift-side `CodingKeys` reflection —
`contracts/data-model.md` § StudentState: "the schema's closed key set is the guard". The guard test lives in
§4.13. This is what AC6 asserts, and it is the stronger reading: it checks the keys that are actually written
to disk and (in aggregate form) transmitted, in the same snake_case vocabulary as the blocklist, rather than
Swift-side declarations that may or may not equal them.

### 4.11 `Packages/Core/Sources/Core/CoreError.swift`

```swift
public enum CoreError: String, Error, CaseIterable {
    case graphL0Failed = "GRAPH_L0_FAILED"
    case mapLayoutMissing = "MAP_LAYOUT_MISSING"
    case mapRegionUnknown = "MAP_REGION_UNKNOWN"
    case mapLandmarkUnsourced = "MAP_LANDMARK_UNSOURCED"
    case spineUnitEmpty = "SPINE_UNIT_EMPTY"
    case spineSourceRefUnresolved = "SPINE_SOURCE_REF_UNRESOLVED"
    case platformBundleIntegrityFailed = "PLATFORM_BUNDLE_INTEGRITY_FAILED"
}
```

This is exactly the epic brief §3 code list minus `LO_ITEM_UNRENDERABLE`/`LO_BAD_DISTRACTOR_TAG` (owned by
`Rendering`/`pipeline`, not `Core` — §3 planner note 4), plus `PLATFORM_BUNDLE_INTEGRITY_FAILED` (§3 planner
note 2, the code `BundleIO`'s manifest-completeness check raises). Only `platformBundleIntegrityFailed` is
actually thrown by code shipped in this task (`BundleIO`, §4.12); the `GRAPH_L0_FAILED`/`MAP_*`/`SPINE_*`
cases exist now so tasks 01.2/01.3 do not need to reopen this file (see the file-scope note in §2 and planner
note 7 — "01.1 ... defines the interface every other task consumes").

### 4.12 `Packages/Core/Sources/Core/BundleIO.swift`

```swift
public struct ContentBundle {
    public let manifest: Manifest
    public let regions: RegionsFile
    public let nodes: NodesFile
    public let edges: EdgesFile
    public let courses: CoursesFile
    public let landmarks: LandmarksFile
    public let sources: SourcesFile
}

public enum BundleIO {
    public static func read(from directory: URL) throws -> ContentBundle { ... }
    public static func write(_ bundle: ContentBundle, to directory: URL) throws { ... }
}
```

`BundleIO` declares **no** decoder or encoder of its own: every `decode` call uses `CoreCoding.decoder` and
every `encode` call uses `CoreCoding.encoder` (§4.1.1, AC9).

`read(from:)`:
1. Decode `manifest.json` from `directory` with `CoreCoding.decoder`.
2. For every `ManifestFile` in `manifest.files`, check `FileManager.default.fileExists(atPath:)` for
   `directory.appendingPathComponent(file.name)`. If any is missing, throw
   `CoreError.platformBundleIntegrityFailed` **before** decoding any of the six content files — no partial
   `ContentBundle` is ever constructed (AC7).
3. Decode `regions.json`, `nodes.json`, `edges.json`, `courses.json`, `landmarks.json`, `sources.json` from
   `directory` into their respective types with `CoreCoding.decoder`.
4. Return the fully populated `ContentBundle`.

`write(_:to:)`: encode `manifest.json` plus the six content files into `directory`, one file per type, with
`CoreCoding.encoder`. That encoder's `outputFormatting = [.sortedKeys]` is what makes the write deterministic
(byte-identical output for byte-identical input across runs), matching the plan's "deterministic
bundle-directory read/write I/O" framing (`docs/plans/epic-01-task-plan.md` task 01.1 row).

`BundleIO` does not compute or check `sha256` (§3, planner note 2) and does not touch `student-state.json`
(`StudentState` has no bundle-directory consumer until EPIC 02 — planner note 8; it ships as a standalone
`Codable` type in this task, decodable through `CoreCoding` from any call site).

### 4.13 `Packages/Core/Tests/CoreTests/DecodeRoundTripTests.swift`

**Round trip (AC1, AC2, AC5).** For each of the 8 files below, read `contracts/examples/<file>` as `Data`,
decode into the named type with `CoreCoding.decoder`, re-encode with `CoreCoding.encoder`, then compare the
**original** and **re-encoded** `Data` structurally (parse both through `JSONSerialization.jsonObject` and
compare the resulting `NSObject` graphs for equality — this is what makes the comparison key-order-independent
while still order-sensitive on arrays, matching AC1's "JSON-equal (key order excluded)"):

| file | type |
|---|---|
| `manifest.json` | `Manifest` |
| `regions.json` | `RegionsFile` |
| `nodes.json` | `NodesFile` |
| `edges.json` | `EdgesFile` |
| `courses.json` | `CoursesFile` |
| `landmarks.json` | `LandmarksFile` |
| `sources.json` | `SourcesFile` |
| `student-state.json` | `StudentState` |

The round-trip helper takes **no** decoder or encoder parameter and no per-type override: all eight rows go
through `CoreCoding`. A `private static var decoder`/`encoder` in this test file, or a per-type variant such
as `studentStateDecoder`, is a defect — it is the exact condition AC9 and the tester's BLOCK exist to prevent.

Locate `contracts/examples/` the same way `coreImportBoundary()` locates `Sources/Core` (§3's prior
signature): from `#filePath` (`Packages/Core/Tests/CoreTests/DecodeRoundTripTests.swift`), three
`.deletingLastPathComponent()` calls reach the package root (`Packages/Core`), two more reach the repo root,
then `.appendingPathComponent("contracts/examples")`.

The test enumerates the 8 filenames it reads (a fixed array, not a directory scan — `telemetry-batch.json`
must never be picked up incidentally) and asserts the count is 8 before checking any file (`#expect(files.count
== 8, "expected 8 example files — empty or partial list is a FAIL")`) — the C3 anti-vacuity guard for AC1.
State in a comment that `telemetry-batch.json` is excluded by name because it has no `Core` type (telemetry is
EPICs 10–11's scope) — AC2.

**I5 wire-key guard (AC6).** A second `@Test` in this file:

1. Decode `contracts/examples/student-state.json` into `StudentState` with `CoreCoding.decoder` and re-encode
   it with `CoreCoding.encoder`.
2. Parse the re-encoded `Data` with `JSONSerialization` and collect, with a small recursive function, **every**
   object key at every nesting level into a `Set<String>` (descend into both dictionaries and arrays).
3. Anti-vacuity (empty = FAIL): assert the collected set is a superset of the ten top-level required names of
   `contracts/schemas/student-state.schema.json` — `schema_version`, `format_version_seen`, `syllabi`,
   `marker`, `nodes`, `trail`, `expedition_log`, `probe_log`, `install_day`, `consent_on` — so a collector
   that returned an empty or shallow set cannot pass.
4. Assert `collected.isDisjoint(with: identifierBlocklist)`, where `identifierBlocklist` is the literal Swift
   set matching §3's verbatim Python quote (mirrored, not shared code across languages — there is no
   cross-language import).

The collected set deliberately includes the `nodes` dictionary's keys (node ids). No exclusion is applied —
see the §6 default on a node id colliding with a blocklist entry.

### 4.14 `Packages/Core/Tests/CoreTests/ErrorRegistryTests.swift`

Read `contracts/error-codes.json` from disk at test time (same repo-root path derivation as §4.13), parse its
`codes[].code` array into a `Set<String>` (a private, file-local `Decodable` struct for `{code: String}` is
fine to declare inside this test file — it is not a new file). Assert:

- the registry set is non-empty (`#expect(!registryCodes.isEmpty, ...)`) — anti-vacuity on the registry side.
- `CoreError.allCases` is non-empty (`#expect(!CoreError.allCases.isEmpty, ...)`) — anti-vacuity on the enum
  side.
- every `CoreError.allCases.map(\.rawValue)` is contained in the registry set (AC3).

`contracts/error-codes.json` is **not** a bundle wire-format document — it has no `Model/` type, its keys
(`code`, `recoverable`, `surface`, `user_text`) are read into a file-local struct, and it is decoded with a
plain `JSONDecoder()`, not `CoreCoding.decoder`. This is the declared exception, and it is the reason AC9's
scan does not read `Tests/CoreTests`.

### 4.15 `Packages/Core/Tests/CoreTests/CoreTests.swift` (modify `coreImportBoundary()`)

Replace the single-level `FileManager.default.contentsOfDirectory(at:includingPropertiesForKeys:)` call with a
recursive walk of `sourcesDir` (e.g. `FileManager.default.enumerator(at:includingPropertiesForKeys:
[.isDirectoryKey])`, filtering to files with `.pathExtension == "swift"`), so `.swift` files inside
`Sources/Core/Model/` are included. Keep the `#expect(!files.isEmpty, "no Core source files found — empty
scan is a FAIL")` guard on the recursive result. Do not change the `forbidden` module list or the
`dataFormatVersion` test.

### 4.16 Smoke check

`( cd Packages/Core && swift build -c release --product core-cli )` — must be green (this also compiles
`Core`, whose new `CoreCoding.swift` and `Model/*.swift` files must build without error even though
`CoreCLI`'s `main.swift` does not yet reference them — task 01.4's job).

### 4.17 `Packages/Core/Tests/CoreTests/CoreTests.swift` (add the single-coder guard — AC9)

A third `@Test` in `CoreTests.swift`, reusing the recursive `Sources/Core` walk of §4.15:

- Collect every `.swift` file under `Packages/Core/Sources/Core/` recursively.
- Anti-vacuity (empty = FAIL): assert the file list is non-empty, and assert that `CoreCoding.swift` is in it
  and contains both the text `JSONDecoder(` and the text `JSONEncoder(` — if the detector cannot find the one
  legitimate occurrence, it cannot be trusted to find an illegitimate one.
- For every other file in the list, assert the file text contains neither `JSONDecoder(` nor `JSONEncoder(`,
  failing with the offending file name.
- Scope statement to put in the test's doc comment: this scan covers `Sources/Core` only. It deliberately
  **excludes** `Tests/CoreTests`, because that tree also decodes non-wire JSON (`contracts/error-codes.json`,
  §4.14) and contains files owned by other EPIC-01 tasks; a scan over it would couple this task to theirs.

## §5 Test plan (risk: seam — full plan)

- T1 happy path: `DecodeRoundTripTests` decodes and re-encodes all 8 named example files through
  `CoreCoding` (AC1, AC2, AC5); the file-count anti-vacuity guard (§4.13) is part of this test, not a separate
  one. This is also the **real-composition test** for the seam this task crosses: `student-state.json` — the
  document whose decoding recipe the BLOCK was about — is decoded by the same product-code coder `BundleIO`
  uses, not by a test-local one.
- T2 negative — invalid input rejected at the boundary: decode a mutated copy of an example with an
  unrecognized enum raw value substituted for a closed field (`nodes.json`'s first node's `region_id` set to
  `"made-up-region"`, and `student-state.json`'s `nodes["exponent-laws"].mastery` set to `"unknown"`) with
  `CoreCoding.decoder` and assert the decode throws (a `DecodingError`) — this is what "enums are closed; an
  unknown value fails decode" (`contracts/data-model.md` § Nulls) means at the `Core` layer, and it is
  naturally satisfied by raw-value-backed enum `Codable` conformance (§4.1) without extra code; the test
  proves it rather than asserting it by inspection.
- T3 error-taxonomy: `ErrorRegistryTests` asserts `CoreError.allCases` ⊆ the codes read from
  `contracts/error-codes.json` at test time (AC3), with both anti-vacuity guards from §4.14.
- T4 conformance per requirements §B.1 (epic brief §5 — "contracts: decode round-trip (data-model EPIC-time
  rung); `CoreError` ⊆ registry (error-codes rung)"): T1 and T3 together are this rung; no separate test is
  needed. I14's "`Core` boundary test extended to the new files" (epic brief §5) is T5's first bullet below.
- T5 negative control for every regression guard:
  - the recursive import-boundary walk (§4.15): assert the returned file list includes at least one path
    whose last two components are `Model/<name>.swift` (e.g. `Model/Manifest.swift`) — this is the negative
    control that the walk is not accidentally still flat; before the fix, this assertion is what would have
    caught the shallow `contentsOfDirectory` call silently skipping `Model/`.
  - the optional-absent guard (AC5): no separate fixture is needed — the structural equality check in T1
    already fails if a `null` leaks in for an omitted optional key (`NSNull` vs. absent key are not
    structurally equal), so a regression that swaps `encodeIfPresent` semantics for `encode` on any optional
    field is caught by T1 itself, not a new test.
  - the I5 wire-key guard (AC6): the negative control is a mutated document — take the re-encoded
    `StudentState` JSON object, inject `"device_id": "x"` into the **nested** `marker` object, re-serialize,
    run the same recursive collector over it, and assert the collected set now **intersects** the blocklist.
    This proves in one step that the collector descends past the top level and that the disjointness
    assertion is live rather than vacuous.
  - the single-coder guard (AC9): the anti-vacuity half of §4.17 is its own negative control — the scan must
    positively locate `JSONDecoder(`/`JSONEncoder(` inside `CoreCoding.swift`, so a detector that matched
    nothing (wrong path derivation, wrong extension filter, empty read) fails instead of passing silently.
  - the CoreError registry guard (AC3): covered by T3's own anti-vacuity guards (both sides asserted
    non-empty before the subset check).
- T6 idempotency / no-leak:
  - `BundleIO.write` idempotency: construct a `ContentBundle` from the decoded `contracts/examples/` files
    (excluding `student-state.json`, which `BundleIO` does not touch), write it to a temporary directory
    twice, and assert the two writes produce byte-identical files (via `.sortedKeys` on `CoreCoding.encoder`,
    §4.1.1) — this is the "deterministic ... write" requirement from the task plan's row for 01.1.
  - `BundleIO.read` no-leak (AC7): build a temporary directory whose `manifest.json` lists `nodes.json` in
    `files[]` but does not contain a `nodes.json` file on disk; assert `BundleIO.read` throws
    `CoreError.platformBundleIntegrityFailed` and that no `ContentBundle` value is ever produced (the `throws`
    signature already makes a partial return impossible in Swift — the test documents this as the
    contract-level assertion, not a runtime state check).

Verification is on the iOS simulator only (`scripts/gate.sh` gate 3). Physical-device verification is the
owner's wrap-gate delivery verification and no test in this task claims it (D29).

## §6 Decision defaults

- IF a `Model/` type appears to need an explicit `CodingKeys` to match a JSON key THEN it does not: §3's
  wire-key evidence enumerates every key of the eight documents and none needs one. The convention is one key
  strategy in `CoreCoding` (§4.1). If a *future* schema change ever introduces a key the conversion cannot
  express, the resolution is a spec change (Q4) that renames the schema key or defines the exception in
  `CoreCoding` — never a second decoder configuration, and never an explicit snake_case `CodingKeys` layered
  under `.convertFromSnakeCase`, which cannot work (`contracts/data-model.md`: one shape set shared by every
  bundle file, the student state and `Core`'s `Codable` types).
- IF any consumer — `BundleIO`, `CoreTests`, and later EPIC 02's state transitions or EPIC 03's App loader —
  needs to decode or encode `student-state.json` or any bundle file THEN it uses `CoreCoding.decoder` /
  `CoreCoding.encoder` and constructs no coder of its own (AC9, I14/D42: implemented once, in `Core`).
- IF a `contracts/examples/student-state.json` fixture ever contains a node id equal to a blocklist entry
  (`id`, `name`, …), making AC6's collector report an intersection THEN that is a FAIL and the fixture is
  fixed — the guard applies no exclusion. Rationale: `contracts/data-model.md` § StudentState makes the
  document's closed key set the guard, and an exclusion list is a hole in it (RULE 2: no configurability that
  was not requested).
- IF a node's `region_id` is decoded that is structurally valid per `RegionId`'s 15-case superset but would be
  invalid per `nodes.schema.json`'s narrower 10-value enum (a horizon label or `shore` on a node) THEN
  `Core`'s `Codable` layer accepts it (decode succeeds) and L0-6 (`GRAPH_L0_FAILED{L0-6}` /
  `MAP_REGION_UNKNOWN`) rejects it at validation time in task 01.2. Rationale: a single shared `RegionId` type
  avoids two enums with overlapping raw values in the same module (simplicity, RULE 2); the schema-level
  narrowing is exactly the kind of rule `contracts/graph-constraints.md`'s L0 table already owns (per
  `contracts/graph-constraints.md` L0-6: `"Every node has exactly one region_id, and it names a non-horizon
  region in regions.json."`).
- IF a `Node` is decoded with neither `expectation_codes` nor `source_ref` present THEN decode still succeeds
  (both are `Optional` at the Swift layer) and L0-3a/L0-3b (`GRAPH_L0_FAILED{L0-3a}` /
  `GRAPH_L0_FAILED{L0-3b}`) reject it at validation time in task 01.2, per `contracts/graph-constraints.md`:
  `"A node with neither codes nor source_ref fails."` `Core`'s `Codable` layer decodes the schema's `anyOf` as
  two independent optionals, not as a decode-time invariant — consistent with this task's scope being types,
  not L0.
- IF a `ProbeItem` of `type: "numeric"` is decoded without an `answer`, or `type: "mc"` without `choices`/
  `correct_choice_id` THEN decode still succeeds (all four fields are `Optional`) — the schema's `allOf`
  if/then requiredness is enforced by `pipeline/tests/test_contracts.py`'s JSON Schema validation, not
  replicated in `Core`. No task in EPIC 01's `Core` scope (01.1–01.3) needs to distinguish `ProbeItem`
  variants at the type level; if a later task needs an exhaustive-switch guarantee, it adds one then.
- IF the implementer's build/test cycle reports this task is overrunning THEN the only sanctioned split is
  01.1a (`CoreCoding.swift`, `Model/Ids.swift`, `Manifest.swift`, `Regions.swift`, `Nodes.swift`,
  `Edges.swift`, `Courses.swift`, `Landmarks.swift`, `Sources.swift`, `BundleIO.swift`,
  `DecodeRoundTripTests.swift` minus the `student-state.json` row) / 01.1b (`Model/StudentState.swift`,
  `CoreError.swift`, `ErrorRegistryTests.swift`, the `student-state.json` row and the I5 guard of
  `DecodeRoundTripTests.swift`, and the `CoreTests.swift` changes) — per `docs/plans/epic-01-task-plan.md`
  planner note 7. `CoreCoding.swift` goes in the first half: it is the dependency of both. Do not invent a
  different split.
- IF a Swift property name produced from a JSON key collides with a Swift reserved word (only `extension` in
  this bundle, `SegmentKind.extension`) THEN the enum case is still named `extension`, backticked
  (`` case `extension` ``) if the compiler requires it, rather than renamed — the raw value `"extension"` must
  stay exact to match `contracts/schemas/student-state.schema.json`'s `trail.segments[].kind` enum.
- Standing defaults: identifiers are stable lowercase kebab-case slugs, never parsed for meaning
  (`contracts/data-model.md` § Identifiers, quoted in §3); `format_version` on every bundle file mirrors
  `CoreInfo.dataFormatVersion` (unchanged at `"0.0.0"` by this task); `StudentState` carries no identifying
  field (I5, AC6); telemetry is out of scope entirely for this task (no telemetry type exists in `Core`).

## §7 Done definition

The task is done when ALL gates pass:

- `xcrun swift-format lint --strict --recursive --configuration .swift-format Packages App/Sources` — clean
  over the new `Packages/Core/Sources/Core/Model/*.swift`, `CoreCoding.swift`, `BundleIO.swift`,
  `CoreError.swift` files (App/Sources is untouched by this task and stays clean trivially).
- `Core` build + test green: `( cd Packages/Core && swift build -c release --product core-cli )` and
  `( cd Packages/Core && xcodebuild test -quiet -scheme Core-Package -destination "$SIM"
  CODE_SIGNING_ALLOWED=NO )` (`scripts/gate.sh` gate 3, `$SIM` from `scripts/pick-simulator.sh`).
- All cases in §5 (T1–T6) pass.
- One decoding convention only: `Packages/Core/Sources/Core/CoreCoding.swift` is the sole site in
  `Sources/Core` that configures a `JSONDecoder`/`JSONEncoder` (AC9), no `Model/` type declares an explicit
  `CodingKeys`, and no test file declares a wire-format coder of its own.
- Conforms to every contract section cited in §3 and §4 (`contracts/data-model.md` § Identifiers, §
  Versioning, § Nulls/enums/unknowns, § ProbeItem, § StudentState, § Enforcement; `contracts/error-codes.md`
  § Rules) and to every invariant listed in §1 (I1, I5, I6, I8, I10, I14, I15).
- `scripts/gate.sh` gates 1 and 3 green in full (gates 2 and 4 are pipeline/App-scoped and are unaffected by
  this task's file scope — they must already be green from Phase 5 and stay green since this task touches
  neither `pipeline/` nor `App/Sources`).
