# Epic 03 · Task 09: `App/Sources` boundary scan (I14 / I5 / I1 / I10 / D24)

---
epic: 03
task: 09
slug: app-sources-i14-scan
kind: test
risk: seam
depends_on: [03.8]
model: sonnet
---

> **Branch note.** This task runs first on `epic-03b-map-app`, created after `epic-03a-map-core` (03.1–03.8)
> merges into `main`. Written against the current tree (clean `main`, no `epic-03b-map-app` branch yet). By
> the time this task's implementer starts, `App/Sources` holds exactly `MathmathApp.swift`, `ContentView.swift`
> (the Phase-5 placeholder — confirmed present, read in this run) and `App/Sources/DemoSnapshot/` (a copy of
> `data/demo`, landed by task 03.4 per `docs/plans/epic-03-plan.md`: "The snapshot is embedded as a copy under
> `App/Sources/DemoSnapshot/`", line 54). `Packages/Core/Sources/Core/Platform/MapLaunch.swift` (03.7's
> `MapLaunch`/`MapFacade`) is also landed. If any of these are absent when implementation starts, that is the
> EPIC-order precondition (03a merged before 03b starts) failing to hold — BLOCK and report it; do not stub
> the missing pieces here.

## §1 Goal & acceptance criteria

Goal: a `Core` test suite that recursively scans `App/Sources` (and, for the network-code rule only, also
`Packages/Core/Sources/Core`) for violations of the `Core` ↔ App boundary the map domain requires, and fails
the build the moment a future task's code crosses it. The scan is the *test* half of I14's co-owner clause in
`docs/domains/map.md`: "the SwiftUI/`Canvas` layer imports it and computes nothing". It ships before any
render code lands (03.10–03.12 all `depends_on` this task), so every later App task is written against an
already-red guard rather than one bolted on afterward. The scan logic is a single, rule-driven helper so
EPIC 04 task 04.10 ("extends 03.9's App/Sources scan with the Door rules and widens the allow-list by exactly
the 04.5 entries", `docs/plans/epic-04-plan.md` line 78) can add new violation classes and widen the import
allow-list without rewriting the walk or the empty-scan guard.

The module-wide import allow-list carries **no** third-party math-rendering module: `SwiftMath` is not in
`allowedImportModules` (`docs/tech-stack.md` §1, "Choices" table, Math display row, Choice column: "**SwiftMath**,
imported only by the `Packages/Rendering` package" — `App/Sources` is not `Packages/Rendering`). Because the
Phase-5 placeholder `App/Sources/ContentView.swift` imports `SwiftMath` directly today, this task instead ships
one **named, file-scoped, time-boxed exception**: the "non-allow-listed import" rule's `import SwiftMath`
match is skipped only when the file is `App/Sources/ContentView.swift` — i.e. only when the scanned file's
absolute path, standardized and symlink-resolved, equals `<scanned root>/ContentView.swift` standardized and
symlink-resolved the same way. It is **not** matched by file name: a `ContentView.swift` in any subdirectory
(e.g. `App/Sources/Views/ContentView.swift`) gets no exception, and the rule fires normally there and in every
other `.swift` file, as any other non-allow-listed import does. Task 03.12 — which replaces `ContentView.swift`
and removes its `import SwiftMath` line (`docs/plans/epic-03-plan.md` § 03.12: "replaces the placeholder
`ContentView`") — **must delete this exception in the same change**: it removes the two constants
`AppSourcesBoundary.contentViewSwiftMathExceptionFile` and `AppSourcesBoundary.contentViewSwiftMathExceptionImport`,
and the `continue`-skip block inside `violations(in:rules:)` that reads them (§4.2). After that deletion the
scan enforces the tech-stack rule — `SwiftMath` imported only by `Packages/Rendering` — with no carve-out
anywhere in `App/Sources`, and 03.12's own spec must reference these two symbol names and the skip block when
it schedules the deletion.

Invariants in play:

- **I14** (primary). `CLAUDE.md:37`: "**`Core` is renderer-free and single-source**: `Core` imports Foundation
  only; the render layer never computes state; L0 and layout exist once, in `Core`. A test asserts the import
  boundary." This task IS that test, for the render layer's half of the boundary (the existing
  `coreImportBoundary()` in `CoreTests.swift` already covers `Core`'s own import side). It fails if `App/Sources`
  constructs a `StudentState`, calls any of `MarkerTrail`, `Expedition`, `ExpeditionRun`, `MasteryTransitions`,
  `DiagnosisRun`, `L0Checker`, `BundleIO`, `BundleLoader`, `StudentStateStore`, `LayoutEngine` or
  `MapViewModel.derive` directly instead of going through `MapLaunch.open` / `MapFacade`'s public entry points
  (arbiter-03 § Q-F, "The boundary, precisely", item 4).
- **I5**. `CLAUDE.md:28`: "**No PII, no accounts.** … the endpoint retains no IP." Binds two rules here: no
  read of `data/` paths (which are pipeline/bundle-internal, not the App's concern once `MapLaunch` owns
  loading), and no `URLSession` / `URLRequest` anywhere in `App/Sources` or `Packages/Core/Sources/Core` —
  `docs/epics/epic-03-app-map-shell.md:219`: "There is no network code in `App/Sources` or `Core`; a grep for
  `URLSession` and `URLRequest` must return 0 hits."
- **I1**. `CLAUDE.md:24`: "**Wherever step verification exists, step correctness is decided by CAS, never by a
  language model.**" No item exists on the map (Door C only, 03b); this scan forbids any `ItemChecker`-shaped
  call from appearing in `App/Sources` pre-emptively, so a later task cannot introduce a model-decided
  correctness path without also editing this scan's rule set.
- **I10**. `CLAUDE.md:33`: "**Input is defined per door**: expedition items are numeric or multiple-choice; …
  **no OCR in any door.**" The scan forbids any `TextField` bound to an "answer"-named value, and any
  `Vision`/`VisionKit`/`PencilKit` import (caught by the same import-allow-list rule as every other
  non-allow-listed module).
- **D24** (binding decision, not I-numbered). `CLAUDE.md:12`: "No third-party game engine (D24); Apple's
  first-party SpriteKit is permitted only if `Canvas` performance demands it." The scan forbids
  `FoundationModels` (Tier 1 is out of scope for the map app entirely in this EPIC — context bundle §B binds
  this: "no model imports in `App/Sources` except the designated adaptation layer … out of scope for this
  Core test") via the same non-allow-listed-import rule; it does not forbid `SpriteKit`, since D24 permits it
  conditionally and no task in this EPIC decides that question (03.10 decides "no SpriteKit" for itself, not
  this scan).
- **I4** (supporting). `CLAUDE.md:27`: "backtrack ≤ 2 levels per session; deeper gaps are marked on the map
  only." Forbidding direct `MasteryTransitions` / `DiagnosisRun` calls from `App/Sources` keeps the backtrack
  rule single-sourced in `Core`; the App can never compute its own remediation depth.

Acceptance criteria (each independently verifiable):

- AC1: `AppSourcesBoundary.violations(in:)` run against the real `App/Sources` (resolved via `#filePath`, not
  a hardcoded absolute path) returns `[]`.
- AC2: the same helper, restricted to the URLSession/URLRequest rule alone (`rules: [AppSourcesBoundary
  .networkRule]`), run against the real `Packages/Core/Sources/Core`, returns `[]`.
- AC3: for each of the six violation classes — (1) `StudentState(` construction, (2) a direct call into one
  of the ten named Core-internal types/`MapViewModel.derive`, (3) a `"data/` path literal, (4) `URLSession` /
  `URLRequest`, (5) a non-allow-listed `import`, (6) an `ItemChecker` call or a `TextField` bound to an
  "answer"-named value — a dedicated negative-control test plants exactly that violation in a synthetic
  fixture tree and asserts `AppSourcesBoundary.violations(in:)` reports it.
- AC4: a clean fixture tree, shaped like the real `App/Sources` (a top-level file plus a nested subdirectory,
  mirroring `DemoSnapshot/`'s depth), reports zero violations.
- AC5: a fixture containing a `.json` file whose text contains a planted violation string (e.g. `StudentState(`)
  is scanned and the violation is **not** reported — the scan's file-enumeration filters on `.pathExtension ==
  "swift"` before any rule runs, so `App/Sources/DemoSnapshot`'s JSON payload never enters the rule scan.
- AC6: `AppSourcesBoundary.violations(in:rules:)` accepts a caller-supplied `[AppSourcesBoundary.Rule]` array
  distinct from `AppSourcesBoundary.defaultRules`; a test passes a synthetic extra rule against a fixture
  planted only with that rule's trigger string and asserts it is caught — proving the rule set is
  data-driven and a later task (04.10) can extend it by passing `defaultRules + [newRule]` without touching
  this file's walk or empty-scan logic.
- AC7: the SwiftMath exception is scoped to exactly one path, `<scanned root>/ContentView.swift`. Instrument:
  three Swift Testing tests in `AppSourcesBoundaryNegativeControlTests.swift` (§4.4), each over its own
  `UUID()`-named temp fixture tree, each asserting on the "non-allow-listed import" violation string only:
  (a) `import SwiftMath` in a top-level fixture file **not** named `ContentView.swift` (`MathView.swift`) is
  reported; (b) `import SwiftMath` in a nested `Views/ContentView.swift` is reported — both when it is the only
  `ContentView.swift` in the tree and when a top-level `ContentView.swift` carrying the same line sits beside it
  (in that tree exactly one `ContentView.swift: non-allow-listed import` violation is reported, the nested one);
  (c) the identical `import SwiftMath` line in the top-level `ContentView.swift` alone produces zero violations.
  (a) and (b) are empty=FAIL (the violation must be present); (c) is empty=PASS. Together they prove the
  exception is path-scoped — not file-name-scoped and not a module-wide re-admission of `SwiftMath`.
- AC8: `MapFacade.unitExpedition(`, `MapFacade.checkHere(`, and constructing/reading panel-content values
  returned by the façade (e.g. `facade.nodePanelContent(for:)` and reading a field off its result) produce
  zero violations against a synthetic fixture; `Expedition.compose(` and `ExpeditionRun.` (a member access,
  e.g. `ExpeditionRun.resume()`) each independently trigger the "direct Core transition/derivation call
  outside the façade" rule in the same fixture tree.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Core/Tests/CoreTests/AppSourcesBoundaryTests.swift` — CREATE. Defines `AppSourcesBoundary` (the
  `Rule` type, `defaultRules`, `allowedImportModules`, `networkRule`, the two `contentViewSwiftMathException*`
  constants, and the `violations(in:rules:)` scan helper) plus the real-tree tests (AC1, AC2, AC5's real-
  `DemoSnapshot` companion check if useful, the extensibility test AC6, and the façade false-positive test
  AC8). Confirmed absent this session (Glob `**/AppSourcesI14ScanTests.swift` and
  `**/AppSourcesBoundaryTests.swift` both returned no match).
- `Packages/Core/Tests/CoreTests/AppSourcesBoundaryNegativeControlTests.swift` — CREATE. The six planted-
  violation tests (AC3), the clean-fixture test (AC4), the JSON-skip fixture test (AC5) and the three
  SwiftMath-exception scope tests (AC7), mirroring the shape of `ImportBoundaryNegativeControlTests.swift` (one
  helper call per test, a fresh temp directory per test, `defer` cleanup).

Out-of-scope (do not touch even if tempted):

- `App/Sources/**` — no App code exists yet beyond the Phase-5 placeholder and 03.4's `DemoSnapshot` copy;
  this task never edits either. 03.10/03.11/03.12 write App code later, against this scan already green.
  03.12 also owns deleting this task's `contentViewSwiftMathException*` carve-out (§1) — not this task.
- `Packages/Core/Sources/Core/**` — read-only; this task adds no product code, only tests. AC2 scans this
  tree but does not modify it.
- `Packages/Core/Tests/CoreTests/CoreTests.swift`, `ImportBoundaryNegativeControlTests.swift` — precedent,
  read-only. Their `coreImportBoundary()` / `forbiddenImportViolations(in:)` logic is cited for shape, not
  copied verbatim or edited (per the house rule against "mirror exactly" — this task's helper is a distinct,
  rule-driven generalization, not a duplicate of the Core-only import scan).
- `scripts/gate.sh`, `.github/workflows/ci.yml` — unchanged; this task's tests run under the existing gate 3
  Core-test step (`xcodebuild test -scheme Core-Package`), no new gate step.
- `contracts/**`, `docs/**`, `data/**` — read-only ground truth.

## §3 Inputs (verbatim — do not paraphrase)

Binding invariant rules (`CLAUDE.md`, Hard invariants table, re-read and byte-compared in this run):

- I1 (`CLAUDE.md:24`):
  > **Wherever step verification exists, step correctness is decided by CAS, never by a language model.** No
  > code path lets a model output decide whether a step or a probe answer is right; expedition items are
  > checked deterministically in code.

- I5 (`CLAUDE.md:28`):
  > **No PII, no accounts.** Telemetry is anonymous and aggregate, **on by default with one-tap off, and
  > carries no identifier of any kind** (no install, device or session id); the endpoint retains no IP.
  > Cross-device sync uses Apple-managed identity only.

- I10 (`CLAUDE.md:33`):
  > **Input is defined per door**: expedition items are numeric or multiple-choice; homework mode uses a
  > structured math editor; **no OCR in any door.**

- I14 (`CLAUDE.md:37`):
  > **`Core` is renderer-free and single-source**: `Core` imports Foundation only; the render layer never
  > computes state; L0 and layout exist once, in `Core`. A test asserts the import boundary.

- D24 reference (`CLAUDE.md:12`, Principal languages & conventions section):
  > No third-party game engine (D24); Apple's first-party SpriteKit is permitted only if `Canvas` performance
  > demands it.

Stack-lock quote (verbatim, re-read and byte-compared in this run — `docs/tech-stack.md` §1 "Choices" table,
Math display row, Choice column):

> **SwiftMath**, imported only by the `Packages/Rendering` package

This is the rule this task's import-allow-list enforces module-wide; `App/Sources` is not `Packages/Rendering`,
so `SwiftMath` is not in `allowedImportModules` (§4.2) and the one place it is currently imported
(`App/Sources/ContentView.swift`, the Phase-5 placeholder) is carved out by exact path, not by file name and
not by widening the list.

Domain-doc excerpts (verbatim, re-read and byte-compared in this run):

- `docs/domains/map.md:131-132`, heading `## Invariants enforced here`:
  > - **I14 — co-owner.** `MapViewModel` derivation lives in `Core`; the SwiftUI/`Canvas` layer imports it and
  >   computes nothing; a test asserts `Core` has no SwiftUI, UIKit or SpriteKit import (D33).

- `docs/domains/platform.md:112-113`, heading `## Invariants enforced here`:
  > - **I14** — this domain reads and writes `StudentState` as an opaque `Codable` value from `Core` and
  >   merges via a `Core` function; it defines no state shape and no transition.

- `docs/epics/epic-03-app-map-shell.md:219` (I5 bullet):
  > There is no network code in `App/Sources` or `Core`; a grep for `URLSession` and `URLRequest` must return
  > 0 hits.

Arbiter ruling (verbatim, re-read and byte-compared in this run — `tasks/arbitration/arbiter-03-predispatch.md`
§ Q-F, "The boundary, precisely", item 4):

> **The façade.** Each entry point takes values and returns (new value, `[CoreEvent]`) or throws a
> `CoreError`.
> — The persist-after-every-state-changing-action sequencing lives here too: a `Core` session type whose
> actions write to the injected URL. That way a missed write is caught by a `CoreTests` test, not left in
> untestable App code.
> — The list of student messages to display (Q-A, Q-C, Q-E) is computed here, as registry codes.

Same document, the boundary paragraph naming the scan (re-read, byte-compared):

> The App must not construct a `StudentState`, call `MarkerTrail`, `Expedition`, `MasteryTransitions` or L0
> directly, branch on a `CoreError` to decide visibility, or read `data/`. The brief's new `App/Sources` source
> scan (§ 3 I14 line) enforces this, with a planted negative control.

Allow-listed public façade entry points this task's rule set treats as the App's only legitimate route into
`Core` map state (from `tasks/epic-03-task-07-map-actions-facade-launch.md`, re-read and byte-compared in this
run against §1, §2 and the `MapLaunch`/`MapFacade` code blocks of §4):

```swift
// §4.1 — the App's one handle onto a live map; §4.2 — the launch entry point.
public struct MapState { … }
public enum LaunchOutcome {
    case ready(map: MapState, messages: [String], events: [CoreEvent])
    case courseSelectionNeeded(bundle: ContentBundle, messages: [String], events: [CoreEvent])
    case refused(BundleRefusal)
}
public enum MapLaunch {
    public static func open(snapshotDir: URL, stateURL: URL, today: CalendarDay) -> LaunchOutcome
}
```

§2 File scope (task 03.7), the `MapFacade` methods (re-read and byte-compared against the file-scope line
listing `MapLaunch.swift` as the single CREATE target holding `MapLaunch.open`, `LaunchOutcome`, `MapState`
and `MapFacade`):

> `MapFacade` (panel content, `selectCourse`, `setMarker`, `include`, `unitExpedition`, `checkHere`), and
> every panel-content / outcome value type (§4).

The task's own §1 Goal sentence naming the exact method surface (re-read, byte-compared):

> It also gains the map-actions façade covering panel content (node/region/landmark), `selectCourse`,
> `setMarker`, `include` (an in-memory one-node queue), `unitExpedition` and `checkHere`.

So the App-legitimate surface is: `MapLaunch.open`, `LaunchOutcome`, `MapState`, and `MapFacade
.nodePanelContent`, `.regionPanelContent`, `.landmarkPanelContent`, `.selectCourse`, `.setMarker`, `.include`,
`.unitExpedition`, `.checkHere`. This task's rules never need to name these directly (the rule set is a
forbidden-list, not an allow-complement, for Core-internal calls — see §4.2); they are recorded here only so
the implementer can confirm no rule accidentally flags them (AC8 makes this an executable assertion, not just
a documentation note).

Precedent test shape (verbatim, re-read in this run — `Packages/Core/Tests/CoreTests/CoreTests.swift:15-44`
and `Packages/Core/Tests/CoreTests/ImportBoundaryNegativeControlTests.swift:1-84`, full files already quoted
by `tasks/context/epic-03-task-09-context.md` §G and re-verified here against the actual files):

```swift
// CoreTests.swift:22-36 — the #filePath resolution pattern and the empty-scan=FAIL rule
let sourcesDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // CoreTests
    .deletingLastPathComponent()  // Tests
    .deletingLastPathComponent()  // package root
    .appendingPathComponent("Sources/Core")
let enumerator = FileManager.default.enumerator(
    at: sourcesDir, includingPropertiesForKeys: [.isDirectoryKey]
)
var files: [URL] = []
while let url = enumerator?.nextObject() as? URL {
    if url.pathExtension == "swift" {
        files.append(url)
    }
}
#expect(!files.isEmpty, "no Core source files found — empty scan is a FAIL")
```

```swift
// ImportBoundaryNegativeControlTests.swift:22-43 — a rule helper parameterised over a root directory
private static func forbiddenImportViolations(in root: URL) throws -> [String] {
    let enumerator = FileManager.default.enumerator(
        at: root, includingPropertiesForKeys: [.isDirectoryKey])
    var files: [URL] = []
    while let url = enumerator?.nextObject() as? URL {
        if url.pathExtension == "swift" {
            files.append(url)
        }
    }
    #expect(!files.isEmpty, "no source files found — empty scan is a FAIL")
    var violations: [String] = []
    for file in files {
        let text = try String(contentsOf: file, encoding: .utf8)
        for line in text.split(separator: "\n") where line.hasPrefix("import ") {
            let module = line.dropFirst("import ".count).trimmingCharacters(in: .whitespaces)
            if forbidden.contains(module) {
                violations.append("\(file.lastPathComponent) imports \(module)")
            }
        }
    }
    return violations
}
```

Prior task-plan text this task's design must satisfy (`docs/plans/epic-04-plan.md:78`, re-read in this run):

> **04.10:** extends 03.9's App/Sources scan with the Door rules and widens the allow-list by exactly the 04.5
> entries. Each new rule class has a negative control.

Task-plan text governing the SwiftMath exception's lifetime (`docs/plans/epic-03-plan.md:112-115`, § 03.12,
re-read in this run):

> **03.12:** the app shell:
> - resolves the snapshot and Application Support URLs, and gets today from the device calendar;
> - calls `MapLaunch`, persists after each action, and shows the refusal and unreadable surfaces;
> - replaces the placeholder `ContentView`.

Gate command this task's tests run under (`scripts/gate.sh:16-18`, re-read in this run):

```sh
( cd "$ROOT/Packages/Core" && swift build -c release --product core-cli )
( cd "$ROOT/Packages/Core" && xcodebuild test -quiet -scheme Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO )
```

Test framework (confirmed by every sibling `CoreTests` file re-read in this run): Swift Testing (`import
Testing`, `@Suite`, `@Test`, `#expect`), not XCTest.

Fact re-confirmed by direct read this session: `App/Sources/ContentView.swift` (current placeholder, at the top
level of `App/Sources`) contains `import SwiftMath` (line 2) alongside `import Core` and `import SwiftUI`; the
only other `.swift` file under `App/Sources` today is `App/Sources/MathmathApp.swift`. This is the sole basis
for the path-scoped exception in §4.2 — it is not a basis for widening `allowedImportModules`, nor for
exempting any other file that happens to be named `ContentView.swift`.

## §4 Implementation outline

### 4.1 Layer placement

This is a `Core` test-target file (`Packages/Core/Tests/CoreTests/`), not product code. It sits at the seam
between layer ④ interaction (Door C, the map) and the App's render layer: it asserts, from the `Core` side,
that the render layer never re-implements ② graph queries, ③ learning-object access or ④ state transitions
that `Core` already owns. No new `Core`, `App` or pipeline product code is added by this task.

### 4.2 `AppSourcesBoundary` — the rule-driven scan helper

In `AppSourcesBoundaryTests.swift`:

```swift
import Foundation
import Testing

@testable import Core

/// I14 / I5 / I1 / I10 / D24: a rule-driven scan over App/Sources (and, for the network rule, over
/// Packages/Core/Sources/Core) that fails the build the moment the render layer crosses the Core ↔ App
/// boundary arbiter-03 § Q-F draws. `defaultRules` is a forbidden-pattern list, mirroring
/// `ImportBoundaryNegativeControlTests.forbiddenImportViolations`'s shape — not an allow-list complement —
/// so a legitimate future identifier never becomes a false positive by omission. `violations(in:rules:)`
/// takes its rule set as a parameter so EPIC 04 task 04.10 can call it with `defaultRules + doorRules`
/// without editing this file. 04.10 widens only the call allow-list (new `Rule` values / a wider
/// `forbiddenCoreTypeNames`-shaped list it constructs); it never re-adds an import exception — the one
/// exception this file defines (below) is 03.9-owned and time-boxed to before 03.12 runs.
enum AppSourcesBoundary {
    /// One boundary rule: a name for the violation message, and a predicate over a single source line.
    struct Rule {
        let name: String
        let violates: (String) -> Bool
    }

    /// Modules App/Sources may import. Deliberately excludes `SwiftMath`: `docs/tech-stack.md` §1 Math
    /// display row states `SwiftMath` is "imported only by the `Packages/Rendering` package", and
    /// `App/Sources` is not `Packages/Rendering`. `Rendering` is listed for the package 04.7 lands.
    static let allowedImportModules: [String] = ["SwiftUI", "Foundation", "Core", "Rendering"]

    /// TIME-BOXED EXCEPTION (03.9 → deleted by 03.12). The Phase-5 placeholder `App/Sources/ContentView.swift`
    /// imports `SwiftMath` directly (confirmed by reading the file this session, line 2). Until 03.12 replaces
    /// that file (`docs/plans/epic-03-plan.md` § 03.12: "replaces the placeholder `ContentView`"), the
    /// "non-allow-listed import" rule below skips exactly this one line in exactly this one file.
    /// `contentViewSwiftMathExceptionFile` is a path RELATIVE TO THE SCANNED ROOT, not a file name: the skip
    /// applies only when the scanned file's standardized, symlink-resolved absolute path equals
    /// `root.appendingPathComponent(contentViewSwiftMathExceptionFile)` standardized and symlink-resolved the
    /// same way — i.e. the top-level `ContentView.swift` only. A `ContentView.swift` in any subdirectory
    /// (e.g. `Views/ContentView.swift`) gets no exception. It does not widen `allowedImportModules`, so every
    /// other file's `import SwiftMath` is still caught (AC7). 03.12 MUST delete
    /// `contentViewSwiftMathExceptionFile`, `contentViewSwiftMathExceptionImport` and the `continue`-skip
    /// block in `violations(in:rules:)` that reads them, in the same change that removes
    /// `ContentView.swift`'s `import SwiftMath` line. After that deletion this scan enforces the tech-stack
    /// rule with no carve-out anywhere in `App/Sources`.
    static let contentViewSwiftMathExceptionFile = "ContentView.swift"
    static let contentViewSwiftMathExceptionImport = "SwiftMath"

    /// Names of Core-internal types the App must never call directly — every state-changing or state-
    /// deriving path other than `MapLaunch.open` and `MapFacade`'s eight entry points (§3). Matched as whole
    /// words, so `unitExpedition`/`ExpeditionRun` do not false-positive against a bare `Expedition` rule.
    private static let forbiddenCoreTypeNames = [
        "MasteryTransitions", "MarkerTrail", "Expedition", "ExpeditionRun", "DiagnosisRun",
        "L0Checker", "BundleIO", "BundleLoader", "StudentStateStore", "LayoutEngine",
    ]

    static let defaultRules: [Rule] = [
        Rule(name: "StudentState construction") { line in
            line.range(of: #"\bStudentState\s*\("#, options: .regularExpression) != nil
        },
        Rule(name: "direct Core transition/derivation call outside the façade") { line in
            for name in forbiddenCoreTypeNames {
                if line.range(of: "\\b\(name)\\b", options: .regularExpression) != nil { return true }
            }
            return line.range(of: #"MapViewModel\.derive\("#, options: .regularExpression) != nil
        },
        Rule(name: "read of a data/ path") { line in
            line.range(of: #""data/"#, options: .regularExpression) != nil
        },
        networkRule,
        Rule(name: "non-allow-listed import") { line in
            guard line.hasPrefix("import ") else { return false }
            let module = line.dropFirst("import ".count).trimmingCharacters(in: .whitespaces)
            return !allowedImportModules.contains(String(module))
        },
        Rule(name: "free-text answer / OCR / item-check path") { line in
            if line.range(of: #"\bItemChecker\b"#, options: .regularExpression) != nil { return true }
            return line.range(of: #"TextField\s*\([^)]*[Aa]nswer"#, options: .regularExpression) != nil
        },
    ]

    /// Isolated as its own named rule (not just a `defaultRules` entry) because AC2 runs it alone against
    /// `Packages/Core/Sources/Core` — a tree the other rules (StudentState construction, façade calls, the
    /// import allow-list) do not apply to, since Core legitimately contains all of those symbols.
    static let networkRule = Rule(name: "URLSession or URLRequest") { line in
        line.range(of: #"\bURLSession\b|\bURLRequest\b"#, options: .regularExpression) != nil
    }

    /// Recursively scans `root` for `.swift` files only — `.json` payloads (e.g. `App/Sources/DemoSnapshot`'s
    /// copy of `data/demo`) are excluded by the `pathExtension == "swift"` filter before any rule runs
    /// (AC5). Empty scan (zero `.swift` files found) is a FAIL, matching `CoreTests.swift`'s and
    /// `ImportBoundaryNegativeControlTests.swift`'s existing rule for this scan shape.
    static func violations(in root: URL, rules: [Rule] = defaultRules) throws -> [String] {
        let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: [.isDirectoryKey])
        var files: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension == "swift" {
                files.append(url)
            }
        }
        #expect(!files.isEmpty, "no .swift source files found under \(root.path) — empty scan is a FAIL")
        var violations: [String] = []
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let lineText = String(line)
                for rule in rules where rule.violates(lineText) {
                    if rule.name == "non-allow-listed import",
                        file.resolvingSymlinksInPath().standardizedFileURL.path
                            == root.appendingPathComponent(contentViewSwiftMathExceptionFile)
                            .resolvingSymlinksInPath().standardizedFileURL.path,
                        lineText.trimmingCharacters(in: .whitespaces)
                            == "import \(contentViewSwiftMathExceptionImport)"
                    {
                        continue  // TIME-BOXED EXCEPTION — deleted by 03.12, see the doc comment above.
                    }
                    violations.append("\(file.lastPathComponent): \(rule.name)")
                }
            }
        }
        return violations
    }
}
```

The exception's path match compares full absolute paths, never `file.lastPathComponent`. Both sides go
through `resolvingSymlinksInPath().standardizedFileURL` so that a root under a symlinked temp directory
(`/var/…` vs `/private/var/…` on Darwin) cannot defeat the positive case. A mismatch between the two sides can
only withhold the exception (the line is then reported), never extend it to another file.

### 4.3 Real-tree tests (`AppSourcesBoundaryTests.swift`, AC1/AC2/AC6/AC8)

```swift
@Suite("App/Sources boundary (I14 / I5 / I1 / I10 / D24, 03.9)")
struct AppSourcesBoundaryTests {
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // Core (package root)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
    }

    @Test("App/Sources has no I14/I5/I1/I10/D24 boundary violations")
    func appSourcesIsClean() throws {
        let appSources = Self.repoRoot.appendingPathComponent("App/Sources")
        let violations = try AppSourcesBoundary.violations(in: appSources)
        #expect(violations.isEmpty, "App/Sources boundary violations: \(violations)")
    }

    @Test("Packages/Core/Sources has no URLSession or URLRequest (I5)")
    func coreSourcesHasNoNetworkCode() throws {
        let coreSources = Self.repoRoot.appendingPathComponent("Packages/Core/Sources/Core")
        let violations = try AppSourcesBoundary.violations(
            in: coreSources, rules: [AppSourcesBoundary.networkRule])
        #expect(violations.isEmpty, "Core network-code violations: \(violations)")
    }

    // AC6: the rule set is data-driven — a caller-supplied rule array is honored without editing the walk.
    @Test("violations(in:rules:) honors a caller-supplied rule set distinct from defaultRules")
    func customRuleSetIsHonored() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        try "import Foundation\nlet x = ExpeditionRunViewFutureDoorThing()\n"
            .write(to: tempRoot.appendingPathComponent("Planted.swift"), atomically: true, encoding: .utf8)

        let customRule = AppSourcesBoundary.Rule(name: "planted future-door marker") { line in
            line.contains("ExpeditionRunViewFutureDoorThing")
        }
        let violations = try AppSourcesBoundary.violations(in: tempRoot, rules: [customRule])
        #expect(violations.contains { $0.contains("planted future-door marker") })
    }

    // AC8: the façade's own call surface must never false-positive against the forbidden-call rule, and
    // genuine Core-internal calls in the same tree must still be caught.
    @Test("façade calls and panel-content access are not false positives; Expedition-internal calls still are")
    func facadeCallsAreNotFalsePositives() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try """
            import Foundation
            import Core
            struct Clean {
                func go(facade: MapFacade, id: NodeID) {
                    let outcome = facade.unitExpedition(node: id)
                    _ = facade.checkHere(node: id)
                    let content = facade.nodePanelContent(for: id)
                    let title = content.title
                }
            }
            """
            .write(to: tempRoot.appendingPathComponent("Clean.swift"), atomically: true, encoding: .utf8)

        let cleanViolations = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(cleanViolations.isEmpty, "façade-only calls falsely flagged: \(cleanViolations)")

        try """
            import Foundation
            import Core
            struct Planted {
                func bad() {
                    Expedition.compose(items: [])
                    ExpeditionRun.resume()
                }
            }
            """
            .write(to: tempRoot.appendingPathComponent("Planted.swift"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(
            violations.contains {
                $0.contains("Planted.swift")
                    && $0.contains("direct Core transition/derivation call outside the façade")
            })
    }
}
```

### 4.4 Negative controls (`AppSourcesBoundaryNegativeControlTests.swift`, AC3/AC4/AC5/AC7)

One `@Test` per violation class, each: builds a fresh temp directory (`UUID()`-named, `defer`-removed), plants
exactly one violation matching that class two directories deep (mirroring `App/Sources/DemoSnapshot/`'s
depth), asserts `AppSourcesBoundary.violations(in:)` reports it, and does not assert on any other class.
Plus one clean-fixture test (AC4), one JSON-skip test (AC5), and the three SwiftMath-exception scope tests
(AC7). Skeleton for one class (the other five follow the identical shape with a different planted line and
assertion):

```swift
@Suite("App/Sources boundary: negative control (I14 / I5 / I1 / I10 / D24)")
struct AppSourcesBoundaryNegativeControlTests {
    @Test("catches StudentState( construction planted inside a nested subdirectory")
    func catchesStudentStateConstruction() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let nested = tempRoot.appendingPathComponent("Views")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try "import Foundation\nimport Core\nstruct Clean {}\n"
            .write(to: tempRoot.appendingPathComponent("Clean.swift"), atomically: true, encoding: .utf8)
        try "import Foundation\nimport Core\nlet s = StudentState(schemaVersion: 2)\n"
            .write(to: nested.appendingPathComponent("Planted.swift"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(violations.contains { $0.contains("Planted.swift") && $0.contains("StudentState construction") })
    }

    // … five more @Test functions, one per remaining class:
    //   - a direct call: "MarkerTrail.setMarker(courseCode: ...)" and, separately, "MapViewModel.derive(...)"
    //   - a data/ read: `Bundle.main.url(forResource: "data/demo/courses", ...)`
    //   - URLSession: `let s = URLSession.shared`
    //   - a non-allow-listed import: `import Vision`
    //   - free-text/OCR: `TextField("Your answer", text: $answerText)` and, separately, `ItemChecker.check(...)`

    @Test("reports no violations on a clean fixture tree shaped like App/Sources")
    func cleanFixtureTreeIsClean() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let nested = tempRoot.appendingPathComponent("Views")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try "import Foundation\nimport Core\nimport SwiftUI\nstruct App1 {}\n"
            .write(to: tempRoot.appendingPathComponent("MathmathApp.swift"), atomically: true, encoding: .utf8)
        try "import SwiftUI\nimport Core\nstruct ContentView: View { var body: some View { Text(\"\") } }\n"
            .write(to: nested.appendingPathComponent("ContentView.swift"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(violations.isEmpty, "clean fixture tree unexpectedly reported violations: \(violations)")
    }

    @Test("a planted violation inside a .json file is not reported — the scan is Swift-source only")
    func jsonFilesAreSkipped() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let snapshot = tempRoot.appendingPathComponent("DemoSnapshot")
        try FileManager.default.createDirectory(at: snapshot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try "import Foundation\nstruct Clean {}\n"
            .write(to: tempRoot.appendingPathComponent("Clean.swift"), atomically: true, encoding: .utf8)
        try "{\"note\": \"StudentState(schemaVersion: 2) URLSession data/demo\"}"
            .write(to: snapshot.appendingPathComponent("courses.json"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(violations.isEmpty, "JSON payload text leaked into the Swift-source scan: \(violations)")
    }

    // AC7 (a): the SwiftMath exception is not a module-wide re-admission. Empty=FAIL.
    @Test("catches import SwiftMath planted in a top-level file other than ContentView.swift")
    func catchesSwiftMathImportOutsideException() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try "import SwiftMath\nimport SwiftUI\nstruct MathView: View { var body: some View { Text(\"\") } }\n"
            .write(to: tempRoot.appendingPathComponent("MathView.swift"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(
            violations.contains { $0.contains("MathView.swift") && $0.contains("non-allow-listed import") })
    }

    // AC7 (b): the exception is path-scoped, not file-name-scoped — a nested ContentView.swift is NOT exempt.
    // Empty=FAIL for both assertions.
    @Test("catches import SwiftMath planted in a nested Views/ContentView.swift")
    func catchesSwiftMathImportInNestedContentView() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let nested = tempRoot.appendingPathComponent("Views")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let body = "import SwiftMath\nimport SwiftUI\nstruct ContentView: View { var body: some View { Text(\"\") } }\n"
        try body.write(to: nested.appendingPathComponent("ContentView.swift"), atomically: true, encoding: .utf8)

        // Nested file alone: its import SwiftMath is reported.
        let nestedOnly = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(
            nestedOnly.filter { $0 == "ContentView.swift: non-allow-listed import" }.count == 1,
            "nested Views/ContentView.swift was wrongly exempted: \(nestedOnly)")

        // Add the exempt top-level ContentView.swift beside it: still exactly one report — the nested one.
        try body.write(to: tempRoot.appendingPathComponent("ContentView.swift"), atomically: true, encoding: .utf8)
        let both = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(
            both.filter { $0 == "ContentView.swift: non-allow-listed import" }.count == 1,
            "expected exactly one SwiftMath report (the nested file), got: \(both)")
    }

    // AC7 (c): positive case — the exact top-level path is exempt. Empty=PASS.
    @Test("does not flag import SwiftMath inside the top-level ContentView.swift of the scanned root")
    func exemptsSwiftMathInsideTopLevelContentView() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try "import SwiftMath\nimport SwiftUI\nstruct ContentView: View { var body: some View { Text(\"\") } }\n"
            .write(to: tempRoot.appendingPathComponent("ContentView.swift"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(violations.isEmpty, "the top-level ContentView.swift SwiftMath exception did not apply: \(violations)")
    }
}
```

The implementer writes the five remaining planted-violation tests following the skeleton's shape exactly (one
plant, one assertion on that class's name substring, no assertion on any other class), covering: (2) a direct
Core-internal call — plant both a `MarkerTrail.setMarker(` line and a `MapViewModel.derive(` line in the same
or separate tests, either is acceptable as long as both trigger patterns in §4.2 are exercised by at least one
negative-control test each; (3) a `"data/` path literal; (4) `URLSession`; (5) a non-allow-listed import
(`import Vision`); (6) both an `ItemChecker` call and a `TextField` bound to `answerText` (two assertions, one
test or two — implementer's choice, both trigger patterns must be exercised). Lines longer than the
swift-format line limit in the skeletons above may be wrapped by the implementer; wrapping must not change the
planted strings or the asserted substrings.

### 4.5 Error codes

None. This task raises and catches no `CoreError`; it is a pure text scan over the file system, and its own
failure mode is a Swift Testing `#expect` failure, not a thrown/caught registry error.

### 4.6 Model-calling paths

None. No model is called by this task's code; it exists precisely to keep model-calling paths (Tier 1 /
FoundationModels) out of `App/Sources` until a later, explicitly-scoped task adds the adapter with its own
confidence threshold and Tier-0 fallback (I2).

### 4.7 Smoke check

`( cd Packages/Core && xcodebuild test -quiet -scheme Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO )`
(`scripts/gate.sh:18`, re-read in this run) — must be green, with both new test files' suites passing.

## §5 Test plan

`risk: seam` — full plan.

- T1 happy path: `AppSourcesBoundaryTests.appSourcesIsClean()` (AC1) over the real `App/Sources` as it exists
  at the start of `epic-03b-map-app` (`MathmathApp.swift`, `ContentView.swift`, `DemoSnapshot/`); zero
  violations — including the time-boxed top-level `ContentView.swift` `import SwiftMath` line, which the
  exact-path exception (§4.2) skips.
- T2 negative — invalid input rejected at the boundary: not applicable in the schema-validation sense (this
  task validates no external payload); the closest analogue is T5's negative controls, which assert the
  scan *rejects* (reports) forbidden source shapes.
- T3 error-taxonomy: not applicable — no `CoreError` is raised by this task (§4.5).
- T4 conformance per requirements §B.1 / the cited invariants: `coreSourcesHasNoNetworkCode()` (AC2) proves the
  I5 network-code clause of `docs/epics/epic-03-app-map-shell.md:219` holds for `Core` as well as for `App
  /Sources`; `customRuleSetIsHonored()` (AC6) proves the rule set is data-driven, the specific property
  `docs/plans/epic-04-plan.md:78` needs 04.10 to be able to rely on; `facadeCallsAreNotFalsePositives()` (AC8)
  proves the façade's own legitimate call surface (§3, the "App-legitimate surface" list) never trips the
  forbidden-call rule, and that `Expedition`/`ExpeditionRun` calls outside the façade still do.
- T5 negative control for every regression guard — one per violation class (AC3), plus the two SwiftMath-
  exception scope guards (AC7 a/b), each proving the guard bites on the specific broken shape it exists to
  catch:
  1. `StudentState(` construction inside a nested subdirectory.
  2. a direct `MarkerTrail`/`Expedition`/`MasteryTransitions`/`ExpeditionRun`/`DiagnosisRun`/`L0Checker`
     /`BundleIO`/`BundleLoader`/`StudentStateStore`/`LayoutEngine` call, and separately `MapViewModel.derive(`.
  3. a `"data/…"` path literal.
  4. `URLSession` (and, by the same rule, `URLRequest`).
  5. `import Vision` (a non-allow-listed module — stands in for the FoundationModels/OCR/third-party-engine
     class; `import FoundationModels` is an equally valid planted string for the same rule).
  6. an `ItemChecker` call, and separately a `TextField` bound to an "answer"-named value.
  7. `import SwiftMath` planted in a top-level file named anything other than `ContentView.swift` is still
     caught by the "non-allow-listed import" rule (`catchesSwiftMathImportOutsideException()`), proving the
     exception does not widen `allowedImportModules`.
  8. `import SwiftMath` planted in a nested `Views/ContentView.swift` is still caught, both alone and beside an
     exempt top-level `ContentView.swift` (exactly one report in the latter tree)
     (`catchesSwiftMathImportInNestedContentView()`), proving the exception is scoped to the exact path
     `<scanned root>/ContentView.swift`, not to the file name. This is the negative control for the skip
     block's path comparison: a `lastPathComponent` match would make both assertions fail.
- T6 idempotency / no-leak: each negative-control test creates its own `UUID()`-named temp directory and
  removes it in a `defer`, so no test's fixture leaks into another's scan; `cleanFixtureTreeIsClean()` (AC4),
  `jsonFilesAreSkipped()` (AC5) and `exemptsSwiftMathInsideTopLevelContentView()` (AC7 c) all assert zero
  cross-contamination from the shared `defaultRules` set against an otherwise-clean or exempted tree.

## §6 Decision defaults

- IF the App/Sources allow-list for imports would need to admit `SwiftMath` for the Phase-5 placeholder THEN
  do NOT widen `allowedImportModules` to include it — `docs/tech-stack.md` §1 Math display row states
  `SwiftMath` is "imported only by the `Packages/Rendering` package" (verbatim, §3), and `App/Sources` is not
  `Packages/Rendering`. Instead add the single, named, path-scoped exception in §4.2
  (`AppSourcesBoundary.contentViewSwiftMathExceptionFile = "ContentView.swift"`, a path relative to the
  scanned root, and `.contentViewSwiftMathExceptionImport = "SwiftMath"`), which skips exactly one line
  (`import SwiftMath`) in exactly one file (`<scanned root>/ContentView.swift`). Every other file containing
  `import SwiftMath` — including any nested file also named `ContentView.swift` — is still caught by the
  "non-allow-listed import" rule (AC7, T5.7, T5.8).
- IF the exception's file match could be written as a file-name comparison (`file.lastPathComponent ==
  contentViewSwiftMathExceptionFile`) THEN do not: compare
  `file.resolvingSymlinksInPath().standardizedFileURL.path` with
  `root.appendingPathComponent(contentViewSwiftMathExceptionFile).resolvingSymlinksInPath().standardizedFileURL.path`
  (§4.2), because §1 scopes the exception to the one file `App/Sources/ContentView.swift`
  (`App/Sources/ContentView.swift:2` is the only `import SwiftMath` in `App/Sources`, read this run). Both sides
  are symlink-resolved so a Darwin temp root (`/var` → `/private/var`) cannot defeat the AC7 (c) positive case.
- IF task 03.12 lands THEN it MUST delete `AppSourcesBoundary.contentViewSwiftMathExceptionFile`,
  `.contentViewSwiftMathExceptionImport`, and the `continue`-skip block inside `violations(in:rules:)` that
  reads them (the whole `if rule.name == "non-allow-listed import", … { continue }` statement, including its
  path comparison), in the same change that replaces `ContentView.swift` and removes its `import SwiftMath`
  line (`docs/plans/epic-03-plan.md` § 03.12, quoted verbatim in §3: "replaces the placeholder
  `ContentView`"). With the exception gone, 03.12 also inverts or deletes
  `exemptsSwiftMathInsideTopLevelContentView()` (its premise no longer holds); the other two AC7 tests stay
  valid unchanged. The 03.12 spec must name these two symbols so its own file scope and acceptance criteria
  can reference the deletion directly; 03.9 records only the obligation, since 03.9 does not itself touch
  `ContentView.swift`.
- IF a later task (04.10) needs to widen the forbidden-Core-type list or the import allow-list THEN it calls
  `AppSourcesBoundary.violations(in:rules: AppSourcesBoundary.defaultRules + doorRules)` with its own
  additional `Rule` values, or extends `allowedImportModules` via a new array it constructs — never by editing
  this file's `violations(in:rules:)` walk or empty-scan logic (per `docs/plans/epic-04-plan.md:78`,
  "extends 03.9's App/Sources scan with the Door rules … Each new rule class has a negative control"). 04.10
  never re-adds an import exception: by EPIC ordering, 03.12 (epic 03b) runs before any EPIC 04 task, so the
  `contentViewSwiftMathException*` carve-out is already deleted by the time 04.10 dispatches, and 04.10's own
  scope is the call allow-list only, never an import exception.
- IF a forbidden Core-internal type name (e.g. `Expedition`) would also match as a substring inside a
  legitimate façade call (e.g. `unitExpedition`) THEN the rule uses a `\b…\b` word-boundary regex, which does
  not match across a lowercase→uppercase transition with no non-word character between (`unitExpedition` has
  no boundary before `Expedition`, so it is not flagged; `ExpeditionRun` has no boundary after `Expedition`
  either, so the standalone `Expedition` rule does not double-fire on it — `ExpeditionRun` is caught by its own
  separate forbidden-name entry). AC8 makes this an executable assertion covering both the false-positive
  (`unitExpedition`, `checkHere`, panel-content access) and true-positive (`Expedition.compose(`,
  `ExpeditionRun.resume()`) directions.
- IF the `TextField`-bound-to-answer heuristic (rule 6) cannot statically distinguish every possible free-text
  entry point THEN accept the documented heuristic (`TextField(...answer...)`, case-insensitive) as the
  Core-test-tier guard; it is intentionally conservative (matches on the word "answer" appearing near
  `TextField(`) rather than a full SwiftUI AST analysis, consistent with the precedent's own per-line textual
  scan (not a Swift parser) for the import-boundary test.
- IF the URLSession/URLRequest rule is applied to `Packages/Core/Sources/Core` in addition to `App/Sources`
  THEN it is invoked as its own isolated `[AppSourcesBoundary.networkRule]` array (AC2), not folded into a
  single "scan everything with `defaultRules`" call, because `defaultRules`' other rules (import allow-list,
  `StudentState(` construction, façade-bypass calls) do not apply to `Core`'s own source tree, which
  legitimately contains all of those symbols.
- Standing defaults: no identifier or timestamp is introduced by this task (it is test-only); no model call
  exists in this task's code, so the confidence-threshold/Tier-0-fallback rule is satisfied vacuously; no
  telemetry path is touched; no node gains a `paraphrase` or verbatim-text field, since this task adds no
  content.

## §7 Done definition

The task is done when ALL gates pass:

- format + lint clean (`swift-format lint --strict` over `Packages` — this task's two new files only; no
  `pipeline/` or `App/Sources` change to lint).
- typecheck clean — Swift's typecheck is the build (`pyright` not applicable, no Python file touched).
- `Core` build + test green: `swift build -c release --product core-cli`; `xcodebuild test -scheme
  Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO` on the simulator, with both new test suites
  passing (AC1–AC8, all six §4.4 negative controls, the clean-fixture and JSON-skip tests, and the three AC7
  SwiftMath-exception scope tests — top-level other-name reported, nested `Views/ContentView.swift` reported,
  top-level `ContentView.swift` exempt).
- App build unaffected (no `App/Sources` file touched by this task) — not re-verified here, since 03.10–03.12
  are the tasks that add App code against this scan.
- tests green for every case in §5.
- conforms to every invariant listed in §1 (I1, I2 vacuously, I4, I5, I10, I14) and to D24; conforms to the
  arbiter-03 § Q-F boundary quoted in §3; the `SwiftMath` carve-out conforms to `docs/tech-stack.md` §1 Math
  display row by being scoped to the single path `<scanned root>/ContentView.swift` and by carrying an explicit
  deletion obligation for 03.12 (§1, §6).
