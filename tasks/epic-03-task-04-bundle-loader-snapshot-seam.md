# Epic 03 · Task 04: Bundle loader + embedded snapshot (C1 loader ↔ `Core` validation seam)

---
epic: 03
task: 04
slug: bundle-loader-snapshot-seam
kind: feat
risk: seam
depends_on: [03.3]
model: sonnet
---

## §1 Goal & acceptance criteria

Goal: Add `BundleLoader.load(from:)` to `Core`: it runs `BundleIO.read`, then the `format_version`-major
check, then `L0Checker.validate(bundle:)`, and returns either the loaded `(ContentBundle, L0Report)` pair or
a typed `BundleRefusal` — no `ContentBundle` value ever escapes on refusal. The format-major check is
extracted out of `L0Checker.swift` into one internal helper so `BundleLoader` reuses it rather than
reimplementing it (I14/D42: exactly one implementation). `BundleRefusal.studentCode` is always
`CoreError.platformSnapshotRefused` — the code the Demo shows, because the snapshot loaded here is the
Demo's only bundle set (arbiter-03 § Q-C, "Code shape") — and `BundleRefusal.internalCode` carries the
underlying `CoreError` (`platformBundleIntegrityFailed`, `graphL0Failed`, `mapLayoutMissing`,
`mapRegionUnknown`, `mapLandmarkUnsourced` or `spineUnitEmpty`) as internal detail, never shown to the
student. The task also embeds `data/demo` as a byte-identical copy under `App/Sources/DemoSnapshot/`, kept
in sync by a regenerating script (never a hand edit), guarded by a mandatory `CoreTests` byte-identity test
(empty set = FAIL), and ships the C1 seam test that drives `BundleLoader.load(from:)` over both the real
`data/demo` and the embedded copy, neither side stubbed.

Invariants in play:
- **I8** — a bundle that fails L0 (or the format-major check, or manifest completeness) is refused before
  any bundle value is returned to the caller; this task is the "app load" half of I8 (`docs/domains/map.md`
  § Invariants enforced here: "a violation refuses the bundle rather than rendering a broken map").
- **I14** — the format-major check exists exactly once, in `L0Checker.swift`, reused by `BundleLoader`
  rather than reimplemented; `BundleLoader.swift` imports Foundation only and performs no rendering.
- **I15** — a landmark without `source_url` cannot reach a caller of `BundleLoader.load(from:)`: it either
  fails decode (`Landmark.sourceUrl` is non-optional) or fails L0-10, and either way the load is refused
  before any bundle value escapes.
- **I2** — this path calls no model and has no adapter; it is Tier-0-only by construction, so it needs no
  confidence threshold or fallback.

Acceptance criteria:

- AC1: `BundleLoader.load(from:)` over a directory that passes every L0 rule returns `(bundle, report)`
  with `report.passed == true`, and does not throw.
- AC2: `BundleLoader.load(from: <data/demo>)` succeeds (`report.passed == true`) — the Demo snapshot is
  L0-clean today, so this is the happy path the App's launch will exercise (docs/domains/platform.md § W1
  step 1, this task's entry point).
- AC3: `BundleLoader.load(from:)` over a bundle directory with a manifest-named file removed, or with an
  edited `manifest.json` whose `format_version` major differs from `CoreInfo.dataFormatVersion`, throws a
  `BundleRefusal` with `studentCode == .platformSnapshotRefused` and `internalCode ==
  .platformBundleIntegrityFailed`.
- AC4: `BundleLoader.load(from:)` over `data/demo` with one node's `position` key deleted from `nodes.json`
  throws a `BundleRefusal` with `studentCode == .platformSnapshotRefused` and `internalCode ==
  .platformBundleIntegrityFailed` (`Node.position` is a non-optional `Point`, so this is a decode failure,
  never an L0-7 violation — verified against `Packages/Core/Sources/Core/Model/Nodes.swift:17`, `public let
  position: Point`).
- AC5: `BundleLoader.load(from:)` over `data/demo` with an edge added that creates a cycle throws a
  `BundleRefusal` with `studentCode == .platformSnapshotRefused`, `internalCode == .graphL0Failed`, and a
  non-nil `report` whose `L0-1` check has `passed == false` and a non-empty `violations` list.
- AC6: `BundleLoader.load(from:)` over `data/demo` with one node's `position` moved outside every region
  polygon in `regions.json` (the node's `region_id` unchanged) throws a `BundleRefusal` with `studentCode ==
  .platformSnapshotRefused`, `internalCode == .mapLayoutMissing`, and a non-nil `report` whose `L0-7` check
  has `passed == false` and a non-empty `violations` list.
- AC7: `L0Checker.validate(bundleDir:)`'s behaviour is unchanged by the extraction: every existing
  `L0CheckerTests` case (`manifestVersionMismatchThrows`, `validFixturePasses`, the negative-control table,
  `manifestCompletenessDelegatesToBundleIO`) stays green with no assertion edited.
- AC8: `App/Sources/DemoSnapshot/` contains exactly the 7 files `data/demo/` contains
  (`manifest.json regions.json nodes.json edges.json courses.json landmarks.json sources.json`), each
  byte-identical to its `data/demo/` counterpart. A `CoreTests` test asserts this over a non-empty file list
  (an empty comparison set is a FAIL) and fails when a one-byte diff is planted into a temp copy of the
  embedded directory compared against `data/demo`.
- AC9 (C1 seam): a `CoreTests` test calls `BundleLoader.load(from:)` on `data/demo` and, separately, on
  `App/Sources/DemoSnapshot`, neither stubbed. Both succeed, and the two `L0Report` values returned are
  `Equatable`-equal. No second loader or L0 implementation exists in `App/Sources` (I14: "L0 and layout
  exist once, in `Core`" — verified by this task's file scope: `App/Sources` gains only the 7 static
  snapshot files, no Swift source).

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Core/Sources/Core/Platform/BundleLoader.swift` — CREATE. `BundleLoader.load(from:)` and
  `BundleRefusal`. Sibling of `Packages/Core/Sources/Core/Validation/L0Checker.swift` in domain terms
  (platform, layer ④'s load-time entry, composing layer ② `L0Checker`); placed in a new `Platform/`
  subdirectory alongside `Validation/`, `State/`, `Graph/`, `Diagnosis/`, `Time/`, `Events/`, `Layout/`,
  `Model/` (the existing `Packages/Core/Sources/Core/*` layout).
- `Packages/Core/Sources/Core/Validation/L0Checker.swift` — MODIFY. Extract the two-line format-major
  comparison currently inlined in `validate(bundleDir:)` (lines 12–14) into one internal (non-`private`)
  static helper, `formatMajorMatches(_ bundle: ContentBundle) -> Bool`, and call it from both
  `validate(bundleDir:)` and `BundleLoader.load(from:)`. No other line of this file changes; no check
  function, no `errorCode(forRuleId:)` table, no public signature changes.
- `Packages/Core/Tests/CoreTests/BundleLoaderTests.swift` — CREATE. AC1–AC6.
- `Packages/Core/Tests/CoreTests/DemoSnapshotSeamTests.swift` — CREATE. AC8 (byte-identity) and AC9 (C1
  seam).
- `App/Sources/DemoSnapshot/manifest.json` — CREATE. Byte-identical copy of `data/demo/manifest.json`.
- `App/Sources/DemoSnapshot/regions.json` — CREATE. Byte-identical copy of `data/demo/regions.json`.
- `App/Sources/DemoSnapshot/nodes.json` — CREATE. Byte-identical copy of `data/demo/nodes.json`.
- `App/Sources/DemoSnapshot/edges.json` — CREATE. Byte-identical copy of `data/demo/edges.json`.
- `App/Sources/DemoSnapshot/courses.json` — CREATE. Byte-identical copy of `data/demo/courses.json`.
- `App/Sources/DemoSnapshot/landmarks.json` — CREATE. Byte-identical copy of `data/demo/landmarks.json`.
- `App/Sources/DemoSnapshot/sources.json` — CREATE. Byte-identical copy of `data/demo/sources.json`.
- `scripts/embed-demo-snapshot.sh` — CREATE. The regenerating script (§4 step 6). Not wired into
  `scripts/gate.sh` or `.github/workflows/ci.yml` by this task — only the byte-identity test (AC8) gates
  drift; the simulator smoke that exercises the built `.app`'s copy is task 03.12's (out of scope here).

Out-of-scope (do not touch even if tempted):

- `Packages/Core/Sources/Core/BundleIO.swift` — call `BundleIO.read(from:)` only; its manifest-completeness
  and decode behaviour is read-only here (already verified against `BundleIOIntegrityTests.swift`).
- `Packages/Core/Sources/Core/CoreError.swift` — task 03.3 (this task's dependency) adds
  `platformSnapshotRefused`; this task uses that case but does not define it or edit this file.
- `Packages/Core/Sources/Core/CoreErrorText.swift`, `Packages/Core/Tests/CoreTests/ErrorUserTextParityTests.swift` — task 03.3's, not this task's.
- `Packages/Core/Sources/Core/Validation/L0Report.swift`, `Packages/Core/Sources/Core/Validation/GraphIndex.swift` — read-only; call their public/internal API only.
- `Packages/Core/Sources/Core/Model/*.swift` — read-only; `Node.position` and `Landmark.sourceUrl` are
  cited, not edited.
- `data/demo/**` — read-only; the source of truth the embedded copy must match byte-for-byte.
- `App/mathmath.xcodeproj/project.pbxproj` — never edited (`App/Sources` is a file-system-synchronized
  group; adding files under it needs no pbxproj change).
- `App/Sources/ContentView.swift`, `App/Sources/MathmathApp.swift`, any other `App/Sources/*.swift` — none
  exists to touch here; the App-side launch wiring is task 03.12's.
- `Packages/Core/Sources/Core/Model/StudentState.swift`, any `StudentState` persistence — task 03.5's.
- `Packages/Core/Sources/Core/Map/MapViewModel.swift` (not yet created) — task 03.6's.
- `scripts/gate.sh`, `.github/workflows/ci.yml` — task 03.12's (the simulator smoke).
- `Packages/Core/Tests/CoreTests/Fixtures/l0/**` — the existing L0 fixture set is read-only; this task's
  corrupted-copy tests build their own temporary directories from `data/demo` (§4 step 3), they do not add
  to or read from the `l0/` fixture set.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/data-model.md` — heading `### Versioning`:
  > Every bundle file carries `format_version` (semver) = `CoreInfo.dataFormatVersion`; a major bump means
  > `Core` needs a migration; the app refuses a bundle whose major differs from its own.

- `contracts/graph-constraints.md` — heading `# Contract: Graph constraints — L0 (LOCK-FIRST)` (the L0 rule
  table and the paragraph immediately following it):
  > | L0-7 | Every node has a `position` inside its region's polygon. | `MAP_LAYOUT_MISSING` | produced by
  > `core-cli layout`; checked after it |
  >
  > **Report shape** (`core-cli validate` stdout, JSON): `{ bundle_id, passed: bool, checks: [{id, passed,
  > violations[]}], indegree: {threshold, outliers[]} }`. A bundle is accepted iff every non-advisory check
  > passed. Empty violation lists are printed, never omitted (C3).

- `contracts/error-codes.md` — heading `## Rules`:
  > Internal codes never reach a student surface; a `student` code always has a next action in its text.

- `contracts/error-codes.json` (verbatim JSON), the existing entries this task's internal codes map to:
  > `{"code": "PLATFORM_BUNDLE_INTEGRITY_FAILED", "recoverable": true, "surface": "student", "user_text": "Could not refresh content; still using the installed version."}`
  > `{"code": "MAP_LAYOUT_MISSING", "recoverable": true, "surface": "internal", "user_text": null}`
  > `{"code": "GRAPH_L0_FAILED", "recoverable": true, "surface": "internal", "user_text": null}`

  Per arbiter-03 § Q-C ("Code shape"): task 03.1 adds `PLATFORM_SNAPSHOT_REFUSED` (`recoverable: false`,
  `surface: student`, `user_text`: "The map could not be loaded from this copy of the app; reinstall the app
  to fix it.") after `PLATFORM_BUNDLE_INTEGRITY_FAILED`; task 03.3 adds `case platformSnapshotRefused =
  "PLATFORM_SNAPSHOT_REFUSED"` to `CoreError`. This task 03.4 uses that case as `BundleRefusal.studentCode`
  but does not add the registry entry or the `CoreError` case.

Domain-doc excerpts (verbatim):

- `docs/domains/platform.md` — heading `### W1 — Launch`:
  > **Pre:** app start. **Steps:** 1. Load the active `ContentBundle` (installed hosted set, else the offline
  > snapshot); verify hashes; a failure falls back to the snapshot (`PLATFORM_BUNDLE_INTEGRITY_FAILED`).
  > 2. Read `StudentState` (W3); none → a fresh default. 3. Collect `CapabilityFacts`. 4. Hand control to
  > **map** W1. Tier 0. **Post:** `platform.launched` emitted.

  In the Demo there is no installed hosted set — the snapshot loaded here is the only set — so the arbiter
  amends step 1 for the case where the snapshot itself is refused (arbiter-03 § Q-C, exact text): "If the
  snapshot itself fails, `PLATFORM_SNAPSHOT_REFUSED` and no map is rendered." This task implements the
  load-and-validate half of that step; task 03.7's launch entry point (out of scope here) is the caller that
  turns a `BundleLoader` outcome into the launch outcome and the App's course-picker / refusal screen.

- `docs/domains/map.md` — heading `## Invariants enforced here`:
  > **I7 / I8** — trails are derived from `courses[]` and validated as paths; regions are one per node; a
  > violation refuses the bundle rather than rendering a broken map.

Arbiter ruling (`tasks/arbitration/arbiter-03-predispatch.md` § Q-C, "Code shape"), verbatim:

> - `CoreError` gains `case platformSnapshotRefused = "PLATFORM_SNAPSHOT_REFUSED"`. This is additive, and the EPIC
>   01 precedent is `platformBundleIntegrityFailed`.
> - The existing `ErrorRegistryTests` ⊆-registry check covers the new case with no change.
> - The `Core` launch entry point raises this code whenever the snapshot is the only set and is refused. It carries
>   the underlying code (`PLATFORM_BUNDLE_INTEGRITY_FAILED`, `GRAPH_L0_FAILED` with rule ids, or a `MAP_*`
>   validation code) as internal detail, and the internal detail is never shown.

Arbiter ruling (`tasks/arbitration/arbiter-03-predispatch.md` § Q-F, "Embedding the snapshot"), verbatim:

> The App target is a file-system-synchronized group, and the pbxproj is never edited. So the only
> agent-available way to embed `data/demo` is a **copy under `App/Sources`** that the synchronized group
> picks up as resources. The brief's byte-identity test (a `CoreTests` test comparing that copy with
> `data/demo`, empty set = FAIL) is therefore mandatory, not optional. The spec must name the copy's path
> and state that a regenerating script, not a hand edit, keeps it in sync.

Project invariant (`CLAUDE.md`), verbatim:

> | I14 | **`Core` is renderer-free and single-source**: `Core` imports Foundation only; the render layer
> never computes state; L0 and layout exist once, in `Core`. A test asserts the import boundary. | D33, D42 |

Prior signatures this task builds on (verbatim, re-verified against the current tree):

- `Packages/Core/Sources/Core/BundleIO.swift:27`:
  ```swift
  public static func read(from directory: URL) throws -> ContentBundle {
  ```
  (`:34`: throws `CoreError.platformBundleIntegrityFailed` when a manifest-named file is absent; malformed
  JSON in any file throws the raw `DecodingError` — confirmed by
  `Packages/Core/Tests/CoreTests/BundleIOIntegrityTests.swift:78-90`,
  `malformedManifestFailsDecodeNotIntegrity` expects `DecodingError.self`, not a `CoreError`.)

- `Packages/Core/Sources/Core/Validation/L0Checker.swift:10-16` (current, to be refactored per §4 step 1):
  ```swift
  public static func validate(bundleDir: URL) throws -> L0Report {
      let bundle = try BundleIO.read(from: bundleDir)
      let bundleMajor = bundle.manifest.formatVersion.split(separator: ".").first
      let coreMajor = CoreInfo.dataFormatVersion.split(separator: ".").first
      guard bundleMajor == coreMajor else { throw CoreError.platformBundleIntegrityFailed }
      return validate(bundle: bundle)
  }
  ```

- `Packages/Core/Sources/Core/Validation/L0Checker.swift:20-40`:
  ```swift
  public static func validate(bundle: ContentBundle) -> L0Report {
  ```
  Never throws; a failing rule is a `passed: false` entry in `checks[]`.

- `Packages/Core/Sources/Core/Validation/L0Checker.swift:44-52`:
  ```swift
  public static func errorCode(forRuleId ruleId: String) -> CoreError? {
      let table: [String: CoreError] = [
          "L0-1": .graphL0Failed, "L0-2": .graphL0Failed, "L0-3a": .graphL0Failed,
          "L0-3b": .graphL0Failed, "L0-5": .graphL0Failed, "L0-6": .mapRegionUnknown,
          "L0-7": .mapLayoutMissing, "L0-8": .spineUnitEmpty, "L0-9": .graphL0Failed,
          "L0-10": .mapLandmarkUnsourced,
      ]
      return table[ruleId]
  }
  ```

- `Packages/Core/Sources/Core/Validation/L0Report.swift:6-11`:
  ```swift
  public struct L0Report: Codable, Equatable {
      public let bundleId: String
      public let passed: Bool
      public let checks: [L0Check]
      public let indegree: L0Indegree
  }
  ```

- `Packages/Core/Sources/Core/BundleIO.swift:8-16`:
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
  ```
  (Not `Equatable` — confirmed by reading the full file; `BundleRefusal` therefore does not carry a
  `ContentBundle` value, only `CoreError` codes and an optional `L0Report`, which is `Equatable`.)

- `Packages/Core/Sources/Core/Model/Nodes.swift:17`:
  ```swift
  public let position: Point
  ```
  Non-optional. A `nodes.json` entry with its `position` key deleted fails `Node`'s synthesized `Decodable`
  conformance with a `DecodingError`, before `L0Checker` ever runs (AC4).

- `Packages/Core/Sources/Core/Model/Landmarks.swift:16`:
  ```swift
  public let sourceUrl: String
  ```
  Non-optional; same decode-time refusal shape as `Node.position` (I15, structurally enforced).

- `Packages/Core/Sources/Core/CoreError.swift:10-27` (current cases; `platformSnapshotRefused` is task
  03.3's addition, a precondition of this task, not present in this list today):
  ```swift
  public enum CoreError: String, Error, CaseIterable {
      case graphL0Failed = "GRAPH_L0_FAILED"
      case mapLayoutMissing = "MAP_LAYOUT_MISSING"
      case mapRegionUnknown = "MAP_REGION_UNKNOWN"
      case mapLandmarkUnsourced = "MAP_LANDMARK_UNSOURCED"
      case spineUnitEmpty = "SPINE_UNIT_EMPTY"
      case spineSourceRefUnresolved = "SPINE_SOURCE_REF_UNRESOLVED"
      case platformBundleIntegrityFailed = "PLATFORM_BUNDLE_INTEGRITY_FAILED"
      // … (expedition/diagnosis/graph cases omitted; unaffected by this task)
  }
  ```

- `Packages/Core/Sources/Core/Core.swift:9`:
  ```swift
  public static let dataFormatVersion = "0.0.0"
  ```

- Test-location pattern (`Packages/Core/Tests/CoreTests/L0CheckerTests.swift:11-15`, re-used by this task's
  tests to locate `data/demo` and `App/Sources/DemoSnapshot` from `#filePath`):
  ```swift
  private static var l0FixturesDir: URL {
      URL(fileURLWithPath: #filePath)
          .deletingLastPathComponent()  // CoreTests
          .appendingPathComponent("Fixtures/l0")
  }
  ```
  `BundleIOIntegrityTests.swift:11-19` shows the five-`.deletingLastPathComponent()` chain from `CoreTests`
  to the repo root, used there to reach `contracts/examples`; this task's tests use the same five-call chain
  to reach `data/demo` and `App/Sources/DemoSnapshot`.

## §4 Implementation outline

1. **Extract the format-major helper (`Packages/Core/Sources/Core/Validation/L0Checker.swift`).** Replace
   the two inline `let` statements and the `guard` in `validate(bundleDir:)` (§3's current-signature quote)
   with a call to a new internal static function:
   ```swift
   static func formatMajorMatches(_ bundle: ContentBundle) -> Bool {
       let bundleMajor = bundle.manifest.formatVersion.split(separator: ".").first
       let coreMajor = CoreInfo.dataFormatVersion.split(separator: ".").first
       return bundleMajor == coreMajor
   }
   ```
   `validate(bundleDir:)` becomes:
   ```swift
   public static func validate(bundleDir: URL) throws -> L0Report {
       let bundle = try BundleIO.read(from: bundleDir)
       guard formatMajorMatches(bundle) else { throw CoreError.platformBundleIntegrityFailed }
       return validate(bundle: bundle)
   }
   ```
   No other line of the file changes. `formatMajorMatches` has no access modifier (Swift's default,
   `internal`), so `BundleLoader.swift` — same module, different file — can call it, satisfying I14/D42's
   "exactly one implementation" without making the helper part of `Core`'s public API.

2. **`Packages/Core/Sources/Core/Platform/BundleLoader.swift` — layer.** This is layer ④ interaction's
   load-time entry point (the App-launch half of `docs/domains/platform.md` § W1 step 1), composing layer ①
   (`BundleIO`) and layer ② (`L0Checker`) already implemented in `Core`. It performs file I/O through
   `BundleIO.read` only — it never opens a file itself — and does no rendering, no clock read, no model
   call.

3. **Types.**
   ```swift
   import Foundation

   /// The typed refusal `BundleLoader.load(from:)` throws. `studentCode` is always
   /// `.platformSnapshotRefused` because the directory this task loads is the Demo's only bundle set
   /// (arbiter-03 § Q-C, "Code shape"); `internalCode` is the underlying, never-shown detail.
   public struct BundleRefusal: Error, Equatable {
       public let internalCode: CoreError
       public let report: L0Report?

       public var studentCode: CoreError { .platformSnapshotRefused }
   }

   public enum BundleLoader {
       /// `BundleIO.read` → `L0Checker.formatMajorMatches` → `L0Checker.validate(bundle:)`. Returns the
       /// bundle and its report on success; throws `BundleRefusal` on any failure. No `ContentBundle`
       /// value is ever returned or attached to a thrown error.
       public static func load(from directory: URL) throws -> (bundle: ContentBundle, report: L0Report) {
           let bundle: ContentBundle
           do {
               bundle = try BundleIO.read(from: directory)
           } catch {
               throw BundleRefusal(internalCode: .platformBundleIntegrityFailed, report: nil)
           }
           guard L0Checker.formatMajorMatches(bundle) else {
               throw BundleRefusal(internalCode: .platformBundleIntegrityFailed, report: nil)
           }
           let report = L0Checker.validate(bundle: bundle)
           guard report.passed else {
               let firstFailure = report.checks.first { !$0.passed }
               let internalCode = firstFailure.flatMap { L0Checker.errorCode(forRuleId: $0.id) } ?? .graphL0Failed
               throw BundleRefusal(internalCode: internalCode, report: report)
           }
           return (bundle, report)
       }
   }
   ```
   The `catch` around `BundleIO.read` is intentionally untyped: `BundleIO.read` throws either
   `CoreError.platformBundleIntegrityFailed` (missing manifest-listed file) or a raw `DecodingError`
   (malformed JSON, or — per AC4 — a required key such as `Node.position` absent from `nodes.json`). Both
   collapse to `internalCode: .platformBundleIntegrityFailed`: this is the "map BundleIO decode failures to
   `PLATFORM_BUNDLE_INTEGRITY_FAILED`" requirement. The `firstFailure` selection walks `report.checks` in
   the fixed order `L0Checker.validate(bundle:)` builds them (`L0-1, L0-2, L0-3a, L0-3b, L0-5, L0-6, L0-7,
   L0-8, L0-9, L0-10`), so on a bundle with exactly one violated rule — every case this task tests — the
   selection is unambiguous; the `?? .graphL0Failed` fallback only matters if `report.checks` is somehow
   empty, which `L0Checker.validate(bundle:)` never produces (10 checks always).

4. **Boundary validation.** The only untrusted input is the caller-supplied `directory: URL`, already
   validated by the existing `BundleIO.read` (manifest completeness, per-file decode) and `L0Checker`
   (structural rules). `BundleLoader` adds no new validation surface of its own; it composes two already-
   validated steps and turns their failures into one typed value.

5. **Error codes thrown.** `BundleRefusal.internalCode` ∈ `{.platformBundleIntegrityFailed, .graphL0Failed,
   .mapLayoutMissing, .mapRegionUnknown, .mapLandmarkUnsourced, .spineUnitEmpty}` (drawn from
   `L0Checker.errorCode(forRuleId:)`'s existing range, §3). `BundleRefusal.studentCode` is always
   `.platformSnapshotRefused` (`contracts/error-codes.json`, arbiter-03 § Q-C). No other `CoreError` case is
   thrown by this file.

6. **`scripts/embed-demo-snapshot.sh` — the regenerating script.** A POSIX `sh` script (matching
   `scripts/pick-simulator.sh`'s and `scripts/gate.sh`'s shebang and style; no new tool — `docs/tech-stack.md`
   names no dedicated asset-embedding tool, and a plain file copy needs none):
   ```sh
   #!/bin/sh
   # Regenerates App/Sources/DemoSnapshot/ from data/demo/. Never hand-edit the copy; run this script and
   # commit its output. Guarded by Packages/Core/Tests/CoreTests/DemoSnapshotSeamTests.swift (byte-identity).
   set -eu
   ROOT="$(cd "$(dirname "$0")/.." && pwd)"
   SRC="$ROOT/data/demo"
   DEST="$ROOT/App/Sources/DemoSnapshot"
   mkdir -p "$DEST"
   for f in manifest.json regions.json nodes.json edges.json courses.json landmarks.json sources.json; do
       cp "$SRC/$f" "$DEST/$f"
   done
   ```
   Run it once during this task to produce the 7 `App/Sources/DemoSnapshot/*.json` files in §2's CREATE
   list; the byte-identity test (step 8) is what a reviewer or CI relies on afterwards, not re-running the
   script.

7. **`BundleLoaderTests.swift` — happy path and refusal (AC1–AC6).** Build a `dataDemoDir` and (for the
   corrupted cases) a fresh `FileManager.default.temporaryDirectory` copy of `data/demo`, per-case mutated
   with `JSONSerialization` (load the target file as `[String: Any]` / `[Any]`, mutate, re-serialize) rather
   than hand-written fixture JSON, since these are one-off mutations of the real bundle, not a reusable
   fixture set:
   - AC3a — delete `nodes.json` from the manifest's listed files' temp copy (or delete `edges.json` itself
     from disk while `manifest.json` still lists it).
   - AC3b — parse `manifest.json`, change `format_version` from `"0.0.0"` to `"1.0.0"`, re-write.
   - AC4 — parse `nodes.json`, remove the `"position"` key from the first node object, re-write.
   - AC5 — parse `edges.json`, append an edge whose `from`/`to` reverse an existing edge's `to`/`from` (e.g.
     data/demo's `linear-relations → solving-linear-equations` edge; add
     `solving-linear-equations → linear-relations` with the same `sources`/`confidence` shape as its
     neighbours), re-write.
   - AC6 — parse `nodes.json`, set one node's `position` to `{"x": 999, "y": 999}` (outside every polygon in
     `data/demo/regions.json`, whose coordinates are confirmed in the 0–1 range), re-write.

   Every mutated-copy test asserts, via `#expect(throws:)` or a `do/catch`, that `BundleLoader.load(from:)`
   throws a `BundleRefusal` and checks `.studentCode` and `.internalCode` (and, for AC5/AC6, `.report`'s
   relevant check).

8. **`DemoSnapshotSeamTests.swift` — byte-identity (AC8) and C1 seam (AC9).** Locate `data/demo` and
   `App/Sources/DemoSnapshot` from `#filePath` per §3's five-`.deletingLastPathComponent()` pattern. The
   byte-identity test:
   - lists the 7 file names as a fixed array (not a directory glob — an accidental empty embed directory
     must not vacuously pass);
   - asserts the list is non-empty before comparing anything (empty set = FAIL);
   - for each name, reads both files as `Data` and asserts equality;
   - a second test plants a one-byte change into a temp copy of one embedded file and asserts the same
     comparison now fails (the negative control proving the positive test is not vacuous).

   The C1 seam test calls `BundleLoader.load(from:)` on `data/demo` and on `App/Sources/DemoSnapshot`
   (neither call passes a stub or in-memory bundle), asserts both succeed, and asserts the two returned
   `L0Report` values are `==`.

9. Smoke check: `swift build -c release --product core-cli && (cd Packages/Core && swift test)` — must be
   green, including every existing `L0CheckerTests` case (AC7) and the new files.

## §5 Test plan (risk: seam — full plan)

- T1 happy path: AC1 (a passing directory) and AC2 (`data/demo` itself) both return `(bundle, report)` with
  `report.passed == true` and throw nothing.
- T2 negative — invalid input rejected at the boundary: AC3 (missing manifest-listed file; format-major
  mismatch) and AC4 (deleted `position` key) each throw `BundleRefusal` with `internalCode ==
  .platformBundleIntegrityFailed`.
- T3 error-taxonomy: AC5 (`internalCode == .graphL0Failed`, `report.checks["L0-1"].passed == false`) and AC6
  (`internalCode == .mapLayoutMissing`, `report.checks["L0-7"].passed == false`) each assert the exact
  `CoreError` case and the exact L0 rule id in `violations`.
- T4 conformance per §3 (`contracts/data-model.md` § Versioning, `contracts/graph-constraints.md`'s L0
  table, `contracts/error-codes.md` § Rules) and I8/I14/I15: AC3/AC5/AC6 conform to "the app refuses a
  bundle whose major differs from its own" and the L0-7 "Fails with" column; AC4/AC5/AC6 together conform to
  "a violation refuses the bundle rather than rendering a broken map" (`docs/domains/map.md`); every AC3–AC6
  case asserts `.studentCode == .platformSnapshotRefused`, never an internal code surfaced directly —
  conforming to "internal codes never reach a student surface" at the type level (the internal code is on a
  different, clearly-named field the App never reads for display).
- T5 negative control for every regression guard: AC7 proves the format-major extraction changed no
  observable behaviour (every pre-existing `L0CheckerTests` assertion, unedited, stays green — a regression
  here is a broken refactor, not a missing feature); AC8's planted one-byte diff is the negative control
  proving the byte-identity test is not vacuously green; the temp-directory corruption tests of AC3–AC6 are
  themselves negative controls proving `BundleLoader.load(from:)` does not silently accept a broken bundle.
- T6 idempotency / no-leak: `BundleLoader.load(from:)` is a pure function of its input directory — calling
  it twice on `data/demo` returns two `L0Report` values that are `==` (covered by AC9's C1 seam assertion,
  which additionally proves this holds identically across two distinct, byte-identical directories); no
  `ContentBundle` value is ever attached to `BundleRefusal` (AC3–AC6, asserted by `BundleRefusal`'s type
  signature itself, §3 — a `ContentBundle` field would not compile without adding `Equatable` conformance to
  `ContentBundle`, which this task does not do), so a caller cannot observe partial bundle state on a
  refused load.

## §6 Decision defaults

- IF `BundleIO.read` throws something other than `CoreError.platformBundleIntegrityFailed` or a
  `DecodingError` (e.g. a `Foundation` file-system error from `Data(contentsOf:)` on a directory that does
  not exist at all) THEN the untyped `catch` in `BundleLoader.load(from:)` still maps it to
  `internalCode: .platformBundleIntegrityFailed` — every non-`BundleRefusal` failure to read/decode the
  directory is "the bundle could not be read", which is exactly what `PLATFORM_BUNDLE_INTEGRITY_FAILED`
  means (`contracts/error-codes.json`, §3). This keeps the mapping total: `BundleLoader.load(from:)` never
  lets a non-`BundleRefusal` error escape past `BundleIO.read`'s call site.
- IF more than one L0 check fails simultaneously on a corrupted directory THEN `internalCode` is the code
  for the first-failing check in `L0Checker.validate(bundle:)`'s fixed check order (`L0-1 … L0-10`, §4 step
  3). This is a reasonable, deterministic default because every AC3–AC6 test case constructs exactly one
  violation; no test in this task depends on multi-violation tie-breaking, and the fixed order matches how
  `report.checks` is already ordered (`L0Checker.swift:22-33`), so this needs no new state.
- IF a future caller needs the L0 report on a decode/format-major refusal (currently `nil`) THEN that is out
  of this task's scope — no test in §5 asserts anything about `report` on a `.platformBundleIntegrityFailed`
  refusal beyond "may be `nil`"; a `nil` report there is correct because no `L0Report` was ever built (the
  refusal happens before `L0Checker.validate(bundle:)` runs).
- IF the reviewer reads `docs/tech-stack.md` § 2's "persistence/sync/bundle loading (platform)" ownership
  line as requiring `BundleLoader` to live in `App/Sources` THEN the same section's opening clause — "a
  spec's §2 file scope is authoritative" — and arbiter-03 § Q-F's ruling ("This is consistent with I14 and
  D33 … `Core` holds … the launch entry point") both override it; this spec's §2 placement in
  `Packages/Core/Sources/Core/Platform/` is the ruled, not the default, outcome. No further action needed.
- Standing defaults restated: identifiers and timestamps are untouched by this task (`BundleLoader` reads no
  `StudentState` and writes no file); no model call exists anywhere in this file, so no confidence threshold
  or fallback applies; no telemetry client exists in this task; no `paraphrase` or Ministry text is read or
  shown by this loader (it validates structure, not content).

## §7 Done definition

The task is done when ALL gates pass:

- format + lint clean (`swift-format lint --strict` over `Packages` and `App/Sources`)
- typecheck clean (Swift's typecheck is the build — N/A for `pipeline` here; this task touches no Python)
- `Core` build + test green (`swift build -c release --product core-cli`; `xcodebuild test -scheme
  Core-Package` on the simulator), including every case in §5 and every pre-existing `L0CheckerTests` case
  unedited and green
- App build green (`xcodebuild build -scheme mathmath` on the simulator) — the new `App/Sources/DemoSnapshot/*.json`
  files must not break the build (they are plain resource files picked up by the synchronized group)
- tests green for the cases in §5
- conforms to every contract section cited in §3 (`contracts/data-model.md` § Versioning,
  `contracts/graph-constraints.md`'s L0 table and Report shape, `contracts/error-codes.md` § Rules) and to
  every invariant listed in §1 (I2, I8, I14, I15)
