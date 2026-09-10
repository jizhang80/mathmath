# Epic 03 · Task 12: App shell — launch wiring, refusal/unreadable surfaces, simulator smoke

---
epic: 03
task: 12
slug: app-shell-launch-smoke
kind: feat
risk: seam
depends_on: [03.10, 03.11]
model: sonnet
---

> **Branch note.** Written against the current tree (clean `main`; confirmed by direct reads in this session:
> `contracts/interaction-contract.md:3` still reads `v0.9.1`, `contracts/error-codes.json` has no
> `PLATFORM_SNAPSHOT_REFUSED` entry, `App/Sources/ContentView.swift`/`MathmathApp.swift` are still the Phase-5
> placeholders, and `Packages/Core/Sources/Core/Platform/MapLaunch.swift` is absent). The implementer runs this
> task on `epic-03b-map-app`, after `epic-03a-map-core` (03.1–03.8) has merged and this task's direct
> dependencies, **03.10** (`app-map-canvas`) and **03.11** (`app-panels-pickers-handoff`), have landed. By that
> time `MapLaunch.open`, `MapFacade`, `CoreErrorText`, `MapCanvasView`/`MapCamera`, the six `App/Sources/MapUI`
> views, `HandOffDestination`/`HandOffHook`, and 03.9's `AppSourcesBoundary` scan (with its time-boxed SwiftMath
> exception still in place) all exist exactly as their own specs describe, quoted verbatim in §3. If any of
> these — or `interaction-contract.md` v0.9.2, or the `PLATFORM_SNAPSHOT_REFUSED` registry entry — is absent
> when implementation starts, that is an EPIC-order precondition failing to hold: BLOCK and report it; do not
> stub, re-derive or reimplement any of them.
>
> **Quote-fidelity correction to the compiled context bundle.** The bundle's §B quote for
> `contracts/deployment-model.md` ("local JSON in Application Support; iCloud at M3") is a paraphrase, not the
> file's text. The actual table row, re-read in this run, is quoted verbatim in §3 below and used throughout
> this spec instead.

## §1 Goal & acceptance criteria

Goal: ship the App's launch shell. `AppShell` (a new SwiftUI view) resolves the embedded snapshot URL and the
Application Support state-file URL, reads today from the device calendar into a `CalendarDay`, calls
`MapLaunch.open`, and renders one of three surfaces: the refusal screen (`RefusalView`, `PLATFORM_SNAPSHOT_REFUSED`
text) on `.refused`, the course picker (03.11's `CoursePickerView`, with an `PLATFORM_STATE_UNREADABLE` banner
when Core's message list carries it) on `.courseSelectionNeeded`, or the map screen (03.10's `MapCanvasView` plus
03.11's panels/pickers/action buttons) on `.ready`. A single `@Observable` holder stores the current `MapState`
and is **replaced wholesale** by every façade call's result — it never derives from the old value. `ContentView`
is replaced to show `AppShell()` (the Phase-5 `MathLabel`/SwiftMath placeholder is removed); `MathmathApp.swift`
is adjusted to drop its now-unused `import Core`. `scripts/sim-smoke.sh` (`xcrun simctl`) proves this shell works
on the simulator in two scenarios — a fresh install writes no state file, and a seeded `schema_version: 1` file
migrates to 2, validates against `student-state.schema.json` via `jsonschema` (`uv run --project pipeline
python …`), and survives a terminate + relaunch byte-identical — and separately `cmp`s the built `.app`'s
`DemoSnapshot` copy against `data/demo`. The script is wired into both `scripts/gate.sh` gate 4 and the `swift`
job of `.github/workflows/ci.yml` (which gains a pinned `setup-uv` step). Finally, this task deletes 03.9's
time-boxed SwiftMath import exception now that `ContentView.swift` no longer imports `SwiftMath`, and reverses
its now-false-premised test into a guard that the carve-out is actually gone.

Invariants in play:

- **I14 (primary)** — `AppShell` holds only the ephemeral `MapStateHolder` (a plain value replaced wholesale)
  and presentation `@State`; every state-changing action still runs through exactly one of 03.7's `MapLaunch`/
  `MapFacade` entry points (already enforced by 03.11's views this task instantiates); `AppShell.swift` never
  constructs a `StudentState` or calls `MarkerTrail`/`Expedition`/`MasteryTransitions`/`DiagnosisRun`/L0 directly.
  Satisfied observably by: the App build + the 03.9 scan staying green over the complete `App/Sources` (now with
  no carve-out anywhere) + the simulator smoke — the C1 seam evidence line this task owns (§5).
- **I5** — the state file's location (Application Support) and its bytes never leave the device; no identifier
  is introduced by the URL-resolution or calendar-reading code this task adds.
- **I4** — not newly engaged: this task adds no record surface; the map (already the sole record, per 02a/03.6)
  is rendered unchanged.
- **I1 / I3 / I10** — not engaged: this task checks no item; the only student input `AppShell` wires is taps and
  the pickers 03.11 already built, none of them free-text or OCR.
- **I2** — Tier 0 only; no file this task adds imports `FoundationModels` or calls a model adapter.
- **I6 / I15** — not newly engaged: `AppShell` renders `NodePanelContent`/`LandmarkPanelContent` (03.7/03.11's
  already-cleared values) unchanged; it invents no new content field.
- **D29** — the simulator is the only surface this task verifies against; the smoke script runs `xcrun simctl`
  only, never a physical device.

Acceptance criteria (each independently verifiable):

- AC1: `AppShell.resolveSnapshotDir()` returns `Bundle.main.resourcePath` (a signed, read-only app-bundle path)
  with `DemoSnapshot` appended, never a `data/`-relative literal; `AppShell.resolveStateURL()` returns a URL
  inside `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]` with the fixed
  last path component `AppShell.stateFileName = "student-state.json"`, creating the containing directory first
  if it does not exist (`StudentStateStore.write` does not create it — 03.5 §6 — so the App must).
- AC2: `AppShell.resolveToday()` formats the device-local calendar day as `"yyyy-MM-dd"` (POSIX locale, current
  time zone) and constructs a `CalendarDay` via its public `init?(iso:)`; the constructed value is never `nil`
  in practice (a well-formed `yyyy-MM-dd` string from `DateFormatter` always round-trips `CalendarDay`'s
  civil-calendar check).
- AC3: on `AppShell.onAppear`, `MapLaunch.open(snapshotDir:stateURL:today:)` is called exactly once; its
  `.ready` case replaces `MapStateHolder.mapState` and renders the map screen; its `.courseSelectionNeeded` case
  renders 03.11's `CoursePickerView`, preceded by `CoreErrorText.text(for: .platformStateUnreadable)` **iff**
  `messages.contains("PLATFORM_STATE_UNREADABLE")` — no other code is checked by name anywhere in this task's
  code (the silent load-path marker reset, arbiter-03 § Q-A: `AppShell` renders whatever `messages` Core hands
  it, generically, never branching on `MAP_MARKER_OFF_TRAIL` or any other specific code); its `.refused` case
  renders `RefusalView`.
- AC4: `RefusalView` renders `CoreErrorText.text(for: refusal.studentCode)` — never `refusal.internalCode`,
  which this view never reads for display (only `BundleRefusal.studentCode` is always `.platformSnapshotRefused`
  per 03.4).
- AC5: choosing a course in `CoursePickerView` (`onSelected: (MapState) -> Void`) replaces
  `MapStateHolder.mapState` and switches `AppShell` to the map screen; the map screen offers a "change course"
  affordance that returns to `CoursePickerView` with `previousState: mapState.state` (arbiter-03 § Q-E, the
  later-course-change path); every façade call either 03.11's views or this task's own callbacks make already
  persists internally (03.7 §4.4 — `selectCourse`/`setMarker` call `StudentStateStore.write` before returning) —
  `AppShell` performs no separate persistence step of its own.
- AC6: the map screen renders 03.10's `MapCanvasView(mapViewModel:onNodeTap:)` over `holder.mapState!.viewModel`;
  a node tap resolves the tapped id to `MapFacade.nodePanelContent(nodeId:mapState:)` and presents 03.11's
  `NodePanelView` with that content, `mapState`, and this task's `handOff` hook; a `nil` panel-content result (an
  id absent from the bundle — defensive, never reached against real `data/demo`) presents nothing.
- AC7: `AppShell`'s `handOff: HandOffHook` handles exactly three cases: `.included(let map)` replaces
  `MapStateHolder.mapState` with `map`; `.diagnosis` and `.unitExpedition` are acknowledged with a placeholder
  surface only (EPIC 04, tasks 04.8/04.9, replaces both — `docs/epics/epic-03-app-map-shell.md` § 2, quoted §3)
  — neither case calls any further `Core` function.
- AC8: `App/Sources/ContentView.swift`'s body is exactly `AppShell()`; it imports `Core` and `SwiftUI` and no
  longer imports `SwiftMath`; `App/Sources/MathmathApp.swift` drops its now-unused `import Core` (its body is
  otherwise unchanged — `WindowGroup { ContentView() }`).
- AC9: `AppSourcesBoundary.contentViewSwiftMathExceptionFile`, `AppSourcesBoundary
  .contentViewSwiftMathExceptionImport`, and the `if rule.name == "non-allow-listed import", <path comparison>,
  <import-line match> { continue }` statement inside `violations(in:rules:)` are deleted from
  `AppSourcesBoundaryTests.swift` in the same change that removes `ContentView.swift`'s `import SwiftMath` line;
  `exemptsSwiftMathInsideTopLevelContentView()` in `AppSourcesBoundaryNegativeControlTests.swift` is reversed
  into a test asserting that `import SwiftMath` in the top-level `ContentView.swift` of a fixture tree **is now
  reported** (empty = FAIL) — its two sibling AC7 tests (`catchesSwiftMathImportOutsideException`,
  `catchesSwiftMathImportInNestedContentView`) are unchanged and stay valid (per
  `tasks/arbitration/arbiter-03-09-exception-path.md`, quoted §3).
- AC10: after AC9's deletion, `AppSourcesBoundary.violations(in:)` run against the real, complete `App/Sources`
  (`AppShell.swift`, `RefusalView.swift`, `ContentView.swift`, `MathmathApp.swift`, `Map/*`, `MapUI/*`,
  `DemoSnapshot/*`) returns `[]` — the C1 seam evidence, with no carve-out of any kind remaining anywhere in the
  tree.
- AC11: `scripts/sim-smoke.sh` exits 0 and asserts, in order: (a) a fresh install + launch leaves the process
  alive and writes **no** file at the App container's `Library/Application Support/student-state.json`; (b) a
  seeded `schema_version: 1` file (a copy of `contracts/examples/student-state.json` with `schema_version` set
  to `1` and every `remediated` key removed) migrates on the next launch to `schema_version: 2`, validates
  against `contracts/schemas/student-state.schema.json` via `Draft202012Validator` (`uv run --project pipeline
  python`), and leaves no `.pre-migration` sibling file; (c) a subsequent terminate + relaunch leaves the file
  byte-identical to what it was immediately after (b) — load never writes (arbiter-03 § Q-A precision 3); and
  (d) every file under the built `.app`'s `DemoSnapshot/` directory is byte-identical to its `data/demo/`
  counterpart. Every assertion names its instrument (`simctl get_app_container`, `launchctl list` via `simctl
  spawn`, the jsonschema validator, `cmp`); an empty/missing container or file is FAIL, never a silent skip.
- AC12: `scripts/sim-smoke.sh` is invoked from `scripts/gate.sh` gate 4, after the App build and before the
  pipeline `pytest` step; `.github/workflows/ci.yml`'s `swift` job gains an `astral-sh/setup-uv@v6` step pinned
  `version: "0.12.12"` (the same pin as the `python` job) followed by a step running `scripts/sim-smoke.sh`,
  both placed after the existing "App build on the simulator" step; both the `gate.sh` and `ci.yml` App-build
  invocations gain `-configuration Debug -derivedDataPath "$ROOT/.build/DerivedData"` (a fixed path both the
  build step and the smoke script agree on, so the smoke script can locate the built `.app` deterministically).
- AC13: before staging anything, the implementer re-measures
  `App/mathmath.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/` (`git status --porcelain` over that path)
  and confirms it is not staged by this task's changes (D-13's own rule: "never stages it" — the wrap, 03.13,
  records the measurement in `docs/DEFERRED.md`; this task does not edit that file).
- AC14 (C1 seam — Core ↔ render layer, I14, owned by this task): the App build (`xcodebuild build -workspace
  App/mathmath.xcworkspace -scheme mathmath`) is green, the 03.9 scan (`xcodebuild test -scheme Core-Package`)
  is green over the complete `App/Sources` tree with the carve-out removed (AC9/AC10), and the simulator smoke
  (AC11) is green — together, per the C3 note below, this is the full evidence this task offers for the render
  side of the seam; no pixel-level or tap-behavior claim is made.
- **C3 exclusion (explicit, per this task's own dispatch scope).** `App/mathmath.xcodeproj` has no App unit-test
  target (arbiter-03 § Q-F: "No App test target is needed"). This task's own new code (`AppShell.swift`,
  `RefusalView.swift`, the `ContentView`/`MathmathApp` edits) is therefore verified only by the App build, the
  03.9 scan, and the simulator smoke — never by a `Core`/App unit test asserting SwiftUI rendering or tap
  behavior. Visual correctness and tap fidelity are the owner's Demo-wrap check (D29); no claim in this task's
  acceptance report asserts screenshot-level or interaction-level correctness. This mirrors the C3 note already
  established by `tasks/epic-03-task-10-*.md` §5 and `tasks/epic-03-task-11-*.md` §5.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `App/Sources/ContentView.swift` — MODIFY. Replace the Phase-5 body (`MathLabel`/`import SwiftMath`) with
  `AppShell()`; drop `import SwiftMath`.
- `App/Sources/MathmathApp.swift` — MODIFY. Drop the now-unused `import Core`; body unchanged.
- `App/Sources/Shell/AppShell.swift` — CREATE. `AppShell` (the launch/refusal/course-selection/map state
  machine), `MapStateHolder`, `AppShell.resolveSnapshotDir()` / `.resolveStateURL()` / `.resolveToday()`, and
  the private `MapScreen` subview assembling 03.10's `MapCanvasView` with 03.11's panels/pickers/action buttons.
- `App/Sources/Shell/RefusalView.swift` — CREATE. The `PLATFORM_SNAPSHOT_REFUSED` screen.
- `scripts/sim-smoke.sh` — CREATE. The two-scenario simulator smoke (§4).
- `scripts/gate.sh` — MODIFY. Add `-configuration Debug -derivedDataPath` to the existing App-build line; add
  the `scripts/sim-smoke.sh` call after it, before the pipeline `pytest` line.
- `.github/workflows/ci.yml` — MODIFY. Add `-configuration Debug -derivedDataPath` to the existing "App build on
  the simulator" step; add a pinned `setup-uv` step and a smoke step after it, in the `swift` job.
- `Packages/Core/Tests/CoreTests/AppSourcesBoundaryTests.swift` — MODIFY. Delete the two
  `contentViewSwiftMathException*` constants, their doc comment, and the `continue`-skip block inside
  `violations(in:rules:)` (§1 AC9).
- `Packages/Core/Tests/CoreTests/AppSourcesBoundaryNegativeControlTests.swift` — MODIFY. Reverse
  `exemptsSwiftMathInsideTopLevelContentView()` into a positive-detection test (§1 AC9); the two sibling AC7
  tests are unchanged.

Out-of-scope (do not touch even if tempted):

- `App/Sources/Map/MapCanvasView.swift`, `App/Sources/Map/MapCamera.swift` — task 03.10's; consumed by their
  public `MapCanvasView(mapViewModel:onNodeTap:)` init only.
- `App/Sources/MapUI/*.swift` (all six files) — task 03.11's; consumed by their public inits only.
- `App/Sources/DemoSnapshot/*.json` — task 03.4's; read-only, never hand-edited.
- `Packages/Core/**` — read-only; call only `MapLaunch.open` and `MapFacade`'s public entry points.
- `App/mathmath.xcodeproj/**` — never edited by an agent; the synchronized `Sources` group covers new files.
- `contracts/**`, `docs/**`, `data/**` — read-only ground truth; this task adds no contract or registry change.
- `docs/DEFERRED.md` — the D-13 re-measurement (AC13) is recorded at the 03.13 wrap, not by this task.
- `scripts/pick-simulator.sh` — read-only; `sim-smoke.sh` calls it for the destination string and independently
  resolves the matching simulator UDID (§4) without modifying this file.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/data-model.md` — heading `### Versioning` (re-read, byte-compared in this run):
  > `StudentState.schema_version` (integer) is migrated forward only (platform W3); older files are kept.

- `contracts/data-model.md` — heading `### Time` (re-read, byte-compared in this run):
  > Dates in state and telemetry are **calendar days** (`YYYY-MM-DD`, device-local) — never finer (I5). Bundle
  > provenance uses ISO 8601 UTC timestamps. No sub-day timestamp exists in any transmitted shape.

- `contracts/data-model.md` § StudentState — the migration-identity sentence (line 149 at time of writing;
  re-read, byte-compared in this run):
  > `schema_version` is **2**. Migration 1 → 2 is the identity: a version-1 document is a valid version-2
  > document with every `remediated` absent.

- `contracts/deployment-model.md`, the Student state row (re-read, byte-compared in this run — **this
  corrects the context bundle's paraphrase of the same row**):
  > | Student state | local JSON (Application Support) + iCloud (Drive container or CloudKit, chosen at M3)
  > under Apple's identity, only when signed in (v2.5 §5) | Apple-managed |

- `contracts/error-codes.json:51` — `PLATFORM_STATE_UNREADABLE` (re-read, byte-compared in this run):
  > {"code": "PLATFORM_STATE_UNREADABLE", "recoverable": true, "surface": "student", "user_text": "Earlier
  > progress could not be read; it has been kept."},

- `tasks/arbitration/arbiter-03-predispatch.md:146` — `PLATFORM_SNAPSHOT_REFUSED`'s exact registry entry, landed
  by task 03.2 (re-read, byte-compared in this run; not yet present in the current `main` tree per the branch
  note):
  > {"code": "PLATFORM_SNAPSHOT_REFUSED", "recoverable": false, "surface": "student", "user_text": "The map
  > could not be loaded from this copy of the app; reinstall the app to fix it."},

- `contracts/interaction-contract.md` § 3 Marker and trail, the v0.9.2 bullet task 03.1 lands (re-read from
  `tasks/arbitration/arbiter-03-predispatch.md:106-108`, byte-compared in this run; not yet present in the
  current `main` tree, which still reads v0.9.1):
  > - The marker is set only by choosing an entry from the selected course's unit list: one entry per unit in
  >   unit order, then a final "past the last unit" entry (`past_last_unit: true`). No gesture moves the marker;
  >   there is no drag and no snap. A unit-list choice is never off the trail.

- `CLAUDE.md` — Hard invariants table, row I14 (verified against this run's system context):
  > **`Core` is renderer-free and single-source**: `Core` imports Foundation only; the render layer never
  > computes state; L0 and layout exist once, in `Core`. A test asserts the import boundary.

Domain-doc excerpts (verbatim, re-read and byte-compared in this run):

- `docs/domains/platform.md` § W1 — Launch:
  > **Pre:** app start. **Steps:** 1. Load the active `ContentBundle` (installed hosted set, else the offline
  > snapshot); verify hashes; a failure falls back to the snapshot (`PLATFORM_BUNDLE_INTEGRITY_FAILED`).
  > 2. Read `StudentState` (W3); none → a fresh default. 3. Collect `CapabilityFacts`. 4. Hand control to
  > **map** W1. Tier 0. **Post:** `platform.launched` emitted.

  Amended by task 03.2 (not yet on `main`; arbiter-03 § Q-C exact text, cited by the epic-03 brief §3): appends
  "If the snapshot itself fails, `PLATFORM_SNAPSHOT_REFUSED` and no map is rendered." to step 1.

- `docs/domains/platform.md` § W3 — Read, write and migrate student state:
  > **Pre:** a launch (read) or a domain transition (write). **Steps:** 1. Read the local JSON; if
  > `schema_version` is older, run migrations in order and keep the pre-migration file until the migrated one
  > is written (`PLATFORM_STATE_UNREADABLE` if migration fails — the old file is kept, a fresh state is used,
  > nothing deleted). 2. Writes are whole-document, atomic (write-then-rename). Tier 0. **Post:**
  > `platform.state_migrated` on a migration; `platform.state_written` otherwise.

- `docs/domains/platform.md` § Errors produced, the two rows this task displays or reads (re-read,
  byte-compared in this run):
  > | `PLATFORM_STATE_WRITE_FAILED` | The JSON write failed | Banner from the calling domain | Yes — retried |
  > | `PLATFORM_STATE_UNREADABLE` | Migration failed | "Earlier progress could not be read; it has been kept" | Yes — file retained |

Arbiter rulings (verbatim, re-read and byte-compared in this run, `tasks/arbitration/arbiter-03-predispatch.md`):

- § Q-A, ruling paragraph 1 and 3:
  > 1. **No student text on the W7 load path.** … `Core`'s launch outcome carries the reconciliation code as
  >    internal diagnostics. The list of messages the App must display is computed **in `Core`** and is empty
  >    for this code on this path. The App shows what `Core` hands it and never branches on a code itself.
  > 3. **No write on load.** Reconciliation changes the in-memory state only. The file keeps its stored marker
  >    until the next state-changing action writes the whole document.

- § Q-F, "The boundary, precisely" (the App-side bullet list):
  > `App/Sources` holds only what needs SwiftUI/UIKit or the OS environment:
  > - views, `Canvas` drawing, and mapping bundle coordinates to screen through the ephemeral pan/zoom transform;
  > - gesture handling and sheet-presentation flags;
  > - one `@Observable` holder that stores the current `Core` session value and **replaces** it with each façade
  >   result, never deriving from it;
  > - resolving the Application Support URL and the embedded-snapshot URL, and reading the device calendar into a
  >   `CalendarDay` (via its public `init?(iso:)`);
  > - handing a `source_url` / `official_url` to the system, and showing a `student` code's registered `user_text`.

- § Q-G, ruling, corrections 1 and 2, and the "Where to write the seed" paragraph (full text, already re-read
  and quoted at length in the planner's own bundle §G and re-verified here against the source file):
  > **Correction 1: CI does not run `gate.sh`.** … Task 6 must: add the smoke to `scripts/gate.sh` gate 4, after
  > the App build; add an `astral-sh/setup-uv@v6` step (`version: "0.12.12"`, the same pin as the `python` job)
  > plus a smoke step after "App build on the simulator" in the `swift` job of `ci.yml`.
  > **Correction 2: the smoke's assertions.** … The smoke instead runs two scenarios: 1. **Fresh install.**
  > Install, launch, and assert the process is alive after a settle interval. Assert **no** state file exists in
  > the container's Application Support … 2. **Seeded relaunch.** … Launch and assert: the process is alive; the
  > file now has `schema_version` 2 and validates against `student-state.schema.json`; and no pre-migration file
  > remains once the migrated one is written. Terminate and relaunch, then assert the process is alive and the
  > file is byte-identical to the one before relaunch.
  > **Where to write the seed.** … The App's state-file location (a fixed file name under Application Support)
  > is therefore a named constant in the task 6 spec, shared by the App and the smoke.
  > **D-13.** … Task 6 first **re-measures** … records the measurement in DEFERRED D-13 at wrap, and **never
  > stages** that directory.

- § Q-H's `data/demo` fact and the `ca.mathmath.app` bundle-id citation (re-verified directly in this run,
  `App/mathmath.xcodeproj/project.pbxproj:217,245`, `PRODUCT_BUNDLE_IDENTIFIER = ca.mathmath.app;`).

`tasks/arbitration/arbiter-03-09-exception-path.md` (full file, re-read in this run) — the 03.12 deletion
obligation:

> - `AppSourcesBoundary.contentViewSwiftMathExceptionFile` (`"ContentView.swift"`, root-relative path)
> - `AppSourcesBoundary.contentViewSwiftMathExceptionImport` (`"SwiftMath"`)
> - The whole `if rule.name == "non-allow-listed import", <exact-path comparison>, <import line match> { continue }`
>   statement in `violations(in:rules:)`
> - Plus: invert or delete `exemptsSwiftMathInsideTopLevelContentView()`. Its premise no longer holds once the
>   exception is gone. The other two AC7 tests stay valid.

`docs/epics/epic-03-app-map-shell.md` § 2, "Hand-offs to EPIC 04 (the seam)" (re-read, byte-compared in this
run):

> For "Check me here", "Include" and "Unit expedition", EPIC 03 ships the map action, its `Core` call and the
> typed value that call returns: a `DiagnosisEvent`, a `ComposeResult`, or the queued node. EPIC 03 also ships
> the navigation hook that hands that value on. **EPIC 04 owns every screen these values open**: the expedition
> item view, the hypothesis card, probe, remediation and summary. Between the two EPICs, the hook may land on a
> placeholder destination that EPIC 04 replaces.

Prior signatures this task builds on (verbatim, re-read against their own already-written specs and, where
present, the current tree, in this session):

```swift
// Packages/Core/Sources/Core/Platform/MapLaunch.swift (task 03.7's spec §4.1/§4.2)
public struct MapState {
    public let bundle: ContentBundle
    public let stateURL: URL
    public let state: StudentState
    public let viewModel: MapViewModel
    public let queuedNodeId: String?
}
public enum LaunchOutcome {
    case ready(map: MapState, messages: [String], events: [CoreEvent])
    case courseSelectionNeeded(bundle: ContentBundle, messages: [String], events: [CoreEvent])
    case refused(BundleRefusal)
}
public enum MapLaunch {
    public static func open(snapshotDir: URL, stateURL: URL, today: CalendarDay) -> LaunchOutcome
}
```

```swift
// Packages/Core/Sources/Core/Platform/BundleLoader.swift (task 03.4's spec §3)
public struct BundleRefusal: Error, Equatable {
    public let internalCode: CoreError
    public let report: L0Report?
    public var studentCode: CoreError { .platformSnapshotRefused }
}
```

```swift
// Packages/Core/Sources/Core/CoreErrorText.swift (task 03.3's spec §4.2)
public enum CoreErrorText {
    public static let userText: [String: String]
    public static func text(for code: CoreError) -> String?
}
```

```swift
// Packages/Core/Sources/Core/Time/CalendarDay.swift:7-10 (current tree, re-read, byte-compared in this run)
public struct CalendarDay: Equatable, Hashable, Comparable, Sendable {
    public let iso: String
    public init?(iso: String) { … }
}
```

```swift
// App/Sources/MapUI/*.swift (task 03.11's spec §4, the exact call-site signatures this task uses)
struct CoursePickerView: View {
    let bundle: ContentBundle
    let stateURL: URL
    let previousState: StudentState?
    let today: CalendarDay
    let onSelected: (MapState) -> Void
}
struct UnitListPickerView: View {
    let course: Course
    let mapState: MapState
    let today: CalendarDay
    let onMarkerSet: (MapState) -> Void
}
struct NodePanelView: View {
    let content: NodePanelContent
    let mapState: MapState
    let handOff: HandOffHook
}
enum HandOffDestination {
    case diagnosis(event: DiagnosisEvent)
    case unitExpedition(result: ComposeResult)
    case included(map: MapState)
}
typealias HandOffHook = (HandOffDestination) -> Void
```

```swift
// App/Sources/Map/MapCanvasView.swift (task 03.10's spec §4.5, the exact init this task calls)
struct MapCanvasView: View {
    let mapViewModel: MapViewModel
    let onNodeTap: (String) -> Void
}
```

```swift
// Packages/Core/Sources/Core/Platform/MapLaunch.swift (task 03.7's spec §4.3, the panel-content signature)
public enum MapFacade {
    public static func nodePanelContent(
        nodeId: String, mapState: MapState
    ) -> (content: NodePanelContent, events: [CoreEvent])?
}
```

`AppSourcesBoundary`'s exact carve-out this task deletes (`tasks/epic-03-task-09-*.md` §4.2, re-read and
byte-compared in this run — the two constants, their doc comment, and the skip block):

```swift
    /// TIME-BOXED EXCEPTION (03.9 → deleted by 03.12). The Phase-5 placeholder `App/Sources/ContentView.swift`
    /// imports `SwiftMath` directly (confirmed by reading the file this session, line 2). Until 03.12 replaces
    /// that file … the "non-allow-listed import" rule below skips exactly this one line in exactly this one
    /// file. … 03.12 MUST delete `contentViewSwiftMathExceptionFile`, `contentViewSwiftMathExceptionImport` and
    /// the `continue`-skip block in `violations(in:rules:)` that reads them, in the same change that removes
    /// `ContentView.swift`'s `import SwiftMath` line. After that deletion this scan enforces the tech-stack
    /// rule with no carve-out anywhere in `App/Sources`.
    static let contentViewSwiftMathExceptionFile = "ContentView.swift"
    static let contentViewSwiftMathExceptionImport = "SwiftMath"
```
```swift
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
```

`AppSourcesBoundary.allowedImportModules` (`tasks/epic-03-task-09-*.md` §4.2, re-read in this run — governs
what `AppShell.swift`/`RefusalView.swift` may import):

```swift
static let allowedImportModules: [String] = ["SwiftUI", "Foundation", "Core", "Rendering"]
```

Note: `"Observation"` is **not** in this list. `@Observable` is used in this task's `MapStateHolder` without a
separate `import Observation` statement — SwiftUI's own module re-exports `Observation`, so `import SwiftUI`
alone is sufficient; adding `import Observation` would trip the 03.9 scan's "non-allow-listed import" rule.

Current tree, re-read and byte-compared in this run (the files this task replaces/edits):

```swift
// App/Sources/ContentView.swift (current, full file)
import Core
import SwiftMath
import SwiftUI

/// Phase 5 placeholder. The Demo EPIC replaces this with the Map (Door C).
struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("mathmath").font(.largeTitle)
            Text("core data format \(CoreInfo.dataFormatVersion)").font(.footnote)
            MathLabel(latex: #"x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}"#).frame(height: 60)
        }
        .padding()
    }
}
struct MathLabel: UIViewRepresentable { … }
```

```swift
// App/Sources/MathmathApp.swift (current, full file)
import Core
import SwiftUI

@main
struct MathmathApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

```sh
# scripts/gate.sh (current, lines 21-23, re-read in this run)
echo "== 4/4 App build on the simulator + pipeline tests =="
xcodebuild build -quiet -workspace "$ROOT/App/mathmath.xcworkspace" -scheme mathmath -destination "$SIM" CODE_SIGNING_ALLOWED=NO
( cd "$ROOT/pipeline" && uv run pytest -q )
```

```yaml
# .github/workflows/ci.yml (current, swift job, lines 36-37, re-read in this run)
      - name: App build on the simulator
        run: xcodebuild build -quiet -workspace App/mathmath.xcworkspace -scheme mathmath -destination "${{ steps.sim.outputs.dest }}" CODE_SIGNING_ALLOWED=NO
```

```yaml
# .github/workflows/ci.yml (current, python job, lines 46-49, re-read in this run — the setup-uv pin this
# task's new swift-job step matches exactly)
      - uses: astral-sh/setup-uv@v6
        with:
          version: "0.12.12"
```

```sh
# scripts/pick-simulator.sh (current, full file, re-read in this run) — this task's smoke script calls it
# unmodified and independently resolves the matching device UDID (§4); it does not edit this file.
```

`pipeline/pyproject.toml:21` (re-read in this run): `"jsonschema>=4.23",` — already a locked pipeline dev
dependency, used by `pipeline/tests/test_contracts.py` (`Draft202012Validator`, re-read in this run).

`contracts/examples/student-state.json` (full file, re-read in this run — the seed fixture's base; the
`matrix-multiplication` node's `remediated: true` key is present in this file and confirmed absent from
`data/demo`'s node set, so seeding it exercises expedition W7's "kept in the file but ignored" path incidentally,
though this task does not assert on it).

## §4 Implementation outline

### 4.1 Layer placement

`AppShell.swift`/`RefusalView.swift` are layer ④ interaction's render layer (Door C shell), `App/Sources`. They
compose 03.7's `MapLaunch`/`MapFacade` (state), 03.10's `MapCanvasView` (canvas) and 03.11's six `MapUI` views
(panels/pickers/actions) — this task adds no new domain logic, only wiring. `scripts/sim-smoke.sh` and the
`gate.sh`/`ci.yml` edits are pipeline/CI infrastructure, not layer code.

### 4.2 `App/Sources/Shell/AppShell.swift`

```swift
import Core
import SwiftUI

@Observable
final class MapStateHolder {
    private(set) var mapState: MapState?
    func replace(with newValue: MapState) { mapState = newValue }
}

struct AppShell: View {
    static let stateFileName = "student-state.json"

    private enum Phase {
        case launching
        case courseSelection(bundle: ContentBundle, previousState: StudentState?, unreadable: Bool)
        case ready
        case refused(BundleRefusal)
    }

    @State private var holder = MapStateHolder()
    @State private var phase: Phase = .launching
    private let today = AppShell.resolveToday()

    var body: some View {
        Group {
            switch phase {
            case .launching:
                ProgressView()
            case .refused(let refusal):
                RefusalView(refusal: refusal)
            case .courseSelection(let bundle, let previousState, let unreadable):
                VStack {
                    if unreadable, let text = CoreErrorText.text(for: .platformStateUnreadable) {
                        Text(text)
                    }
                    CoursePickerView(
                        bundle: bundle, stateURL: Self.resolveStateURL(), previousState: previousState,
                        today: today,
                        onSelected: { map in
                            holder.replace(with: map)
                            phase = .ready
                        })
                }
            case .ready:
                MapScreen(
                    holder: holder, today: today, handOff: handOff,
                    onChangeCourse: { bundle, state in
                        phase = .courseSelection(bundle: bundle, previousState: state, unreadable: false)
                    })
            }
        }
        .onAppear(perform: launch)
    }

    private func launch() {
        let outcome = MapLaunch.open(
            snapshotDir: Self.resolveSnapshotDir(), stateURL: Self.resolveStateURL(), today: today)
        switch outcome {
        case .ready(let map, _, _):
            holder.replace(with: map)
            phase = .ready
        case .courseSelectionNeeded(let bundle, let messages, _):
            // Silent load-path marker reset (arbiter-03 § Q-A): `messages` is rendered generically — this
            // is the only code this task ever names, and only because it has registered student-surface text.
            // MAP_MARKER_OFF_TRAIL / EXP_NODE_NOT_IN_GRAPH are never in `messages` on the load path (03.7's
            // own guarantee); this task does not special-case them.
            phase = .courseSelection(
                bundle: bundle, previousState: nil,
                unreadable: messages.contains("PLATFORM_STATE_UNREADABLE"))
        case .refused(let refusal):
            phase = .refused(refusal)
        }
    }

    private func handOff(_ destination: HandOffDestination) {
        switch destination {
        case .included(let map):
            holder.replace(with: map)
        case .diagnosis, .unitExpedition:
            break  // EPIC 04 (tasks 04.8/04.9) replaces this with a real screen.
        }
    }

    static func resolveSnapshotDir() -> URL {
        guard let resourcePath = Bundle.main.resourcePath else {
            fatalError("Bundle.main.resourcePath is nil — the app bundle is malformed")
        }
        return URL(fileURLWithPath: resourcePath).appendingPathComponent("DemoSnapshot")
    }

    static func resolveStateURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport.appendingPathComponent(stateFileName)
    }

    static func resolveToday() -> CalendarDay {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        let iso = formatter.string(from: Date())
        guard let day = CalendarDay(iso: iso) else {
            fatalError("device calendar produced an unparsable date: \(iso)")
        }
        return day
    }
}
```

`MapScreen` (private, same file) assembles the "ready" surface:

```swift
private struct MapScreen: View {
    let holder: MapStateHolder
    let today: CalendarDay
    let handOff: HandOffHook
    let onChangeCourse: (ContentBundle, StudentState) -> Void

    @State private var openNodeId: String?
    @State private var showingUnitPicker = false

    var body: some View {
        if let mapState = holder.mapState {
            MapCanvasView(mapViewModel: mapState.viewModel) { nodeId in openNodeId = nodeId }
                .toolbar {
                    ToolbarItem { Button("Set marker") { showingUnitPicker = true } }
                    ToolbarItem {
                        Button("Change course") { onChangeCourse(mapState.bundle, mapState.state) }
                    }
                }
                .sheet(isPresented: Binding(
                    get: { openNodeId != nil }, set: { if !$0 { openNodeId = nil } })
                ) {
                    if let nodeId = openNodeId,
                        let (content, _) = MapFacade.nodePanelContent(nodeId: nodeId, mapState: mapState)
                    {
                        NodePanelView(content: content, mapState: mapState, handOff: handOff)
                    }
                }
                .sheet(isPresented: $showingUnitPicker) {
                    if let course = mapState.bundle.courses.courses.first(where: {
                        $0.courseCode == mapState.state.marker.courseCode
                    }) {
                        UnitListPickerView(
                            course: course, mapState: mapState, today: today,
                            onMarkerSet: { newMap in
                                holder.replace(with: newMap)
                                showingUnitPicker = false
                            })
                    }
                }
        } else {
            EmptyView()
        }
    }
}
```

Region/landmark panel presentation (03.11's `RegionPanelView`/`LandmarkPanelView`) has no trigger surface in
this task: 03.10's `MapCanvasView` ships a node-tap callback only ("this task ships exactly one tap callback,
`onNodeTap`" — 03.10 §6 decision default), and 03.10/03.11's file scopes are both out of this task's reach
(§2). This is a known, intentionally deferred gap, not a Q5 — a later task extends `MapCanvasView` with a
region/landmark tap surface if the owner's Demo review calls for it.

### 4.3 `App/Sources/Shell/RefusalView.swift`

```swift
import Core
import SwiftUI

struct RefusalView: View {
    let refusal: BundleRefusal

    var body: some View {
        VStack(spacing: 12) {
            Text(CoreErrorText.text(for: refusal.studentCode) ?? "")
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
```

`refusal.studentCode` is always `.platformSnapshotRefused` (03.4's `BundleRefusal.studentCode` computed
property); `CoreErrorText.text(for:)` is guaranteed non-nil for it by 03.3's own parity test suite
(`ErrorUserTextParityTests`). `refusal.internalCode`/`refusal.report` are never read by this view — the
internal code is never shown (`contracts/error-codes.md` § Rules: "Internal codes never reach a student
surface").

### 4.4 `App/Sources/ContentView.swift` and `App/Sources/MathmathApp.swift`

```swift
// App/Sources/ContentView.swift
import Core
import SwiftUI

/// The Demo shell entry point (EPIC 03 task 03.12). Replaces the Phase-5 SwiftMath placeholder.
struct ContentView: View {
    var body: some View {
        AppShell()
    }
}
```

```swift
// App/Sources/MathmathApp.swift
import SwiftUI

@main
struct MathmathApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

`MathLabel`/`import SwiftMath` are deleted entirely — no App surface renders LaTeX in this EPIC (`docs/epics/
epic-03-app-map-shell.md` § 7 item 3: `MathView` moves to EPIC 04, its first consumer). `MathmathApp.swift`'s
`import Core` is dropped because nothing in that file references a `Core` symbol once `ContentView` no longer
shows `CoreInfo.dataFormatVersion` directly (RULE 3: remove imports your own change made unused).

### 4.5 Boundary validation

The only untrusted input this task's `App/Sources` code reads is the OS's own Calendar/FileManager/Bundle APIs
(`Date()`, `FileManager.default.urls(for:in:)`, `Bundle.main.resourcePath`) — none of these can be "invalid" in
a schema sense; `AppShell.resolveToday()` is the one place a malformed value is even conceivable (a `DateFormat`
whose output somehow fails `CalendarDay.init?(iso:)`'s round-trip check), and that is guarded defensively with
`fatalError` rather than silently guessed at (a well-formed `yyyy-MM-dd` string always round-trips). No JSON,
network payload or user-typed string is parsed anywhere in this task's `App/Sources` code.

### 4.6 Error codes shown

- `CoreError.platformSnapshotRefused` (`PLATFORM_SNAPSHOT_REFUSED`) — `RefusalView`, via `CoreErrorText.text(for:
  refusal.studentCode)`.
- `CoreError.platformStateUnreadable` (`PLATFORM_STATE_UNREADABLE`) — the course-selection banner, via
  `CoreErrorText.text(for: .platformStateUnreadable)`, shown **iff** `messages.contains
  ("PLATFORM_STATE_UNREADABLE")` — the only code this task's `AppShell.launch()` ever names by string; every
  other message in `messages` (there are none others reachable per 03.7's own AC4/T4 guarantee) would be shown
  the same generic way if `messages` ever carried one, never suppressed by a hardcoded check.
- No `CoreError` is thrown by any file in this task's scope; `MapLaunch.open` never throws (it returns a
  `LaunchOutcome`), and every façade call this task's own code makes is delegated to 03.11's views, which
  already catch and either display or discard per their own §4.9.

### 4.7 Model-calling paths

None. Every file in this task's `App/Sources` scope is Tier 0, synchronous, no `FoundationModels` import (I2's
confidence-threshold/fallback requirement is not engaged).

### 4.8 `scripts/sim-smoke.sh`

```sh
#!/bin/sh
# EPIC 03 task 03.12 (arbiter-03 § Q-G). Two scenarios: (1) a fresh install writes no state file; (2) a seeded
# v1 state file migrates to v2, validates, and survives terminate+relaunch byte-identical. Also cmp's the built
# .app's embedded DemoSnapshot against data/demo. xcrun simctl only (D29); no launch-argument test hook exists
# in shipping code. Wired into scripts/gate.sh gate 4 and the swift job of .github/workflows/ci.yml.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_ID="ca.mathmath.app"
DERIVED_DATA="$ROOT/.build/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/mathmath.app"
STATE_FILE_NAME="student-state.json"

if [ ! -d "$APP_PATH" ]; then
    echo "sim-smoke: $APP_PATH not found — build the App with -configuration Debug -derivedDataPath \"$DERIVED_DATA\" first" >&2
    exit 1
fi

SIM_DEST="$("$ROOT/scripts/pick-simulator.sh")"
SIM_NAME="$(printf '%s' "$SIM_DEST" | sed -n 's/.*name=\([^,]*\).*/\1/p')"
SIM_OS="$(printf '%s' "$SIM_DEST" | sed -n 's/.*OS=\([^,]*\).*/\1/p')"
SIM_UDID="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
data = json.load(sys.stdin)["devices"]
name, os_version = sys.argv[1], sys.argv[2]
for runtime, devices in data.items():
    if os_version.replace(".", "-") not in runtime:
        continue
    for d in devices:
        if d.get("isAvailable") and d["name"] == name:
            print(d["udid"]); sys.exit(0)
sys.exit("sim-smoke: no simulator device matching " + name + " / " + os_version)
' "$SIM_NAME" "$SIM_OS")"

xcrun simctl boot "$SIM_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIM_UDID" -b

is_running() { xcrun simctl spawn "$SIM_UDID" launchctl list | grep -q "$BUNDLE_ID"; }

# --- Scenario 1: fresh install writes no state file ---
xcrun simctl uninstall "$SIM_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$SIM_UDID" "$APP_PATH"
xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID"
sleep 3  # [ESTIMATE: settle interval before the process check]
if ! is_running; then
    echo "sim-smoke: $BUNDLE_ID is not running after a fresh-install launch" >&2
    exit 1
fi
DATA_CONTAINER="$(xcrun simctl get_app_container "$SIM_UDID" "$BUNDLE_ID" data)"
STATE_PATH="$DATA_CONTAINER/Library/Application Support/$STATE_FILE_NAME"
if [ -e "$STATE_PATH" ]; then
    echo "sim-smoke: fresh install unexpectedly wrote $STATE_PATH" >&2
    exit 1
fi
echo "sim-smoke: scenario 1 (fresh install, no state file) PASS"

# --- Scenario 2: seeded v1 -> v2 migration, then byte-identical relaunch ---
xcrun simctl terminate "$SIM_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
SEED_PATH="$ROOT/.build/sim-smoke-seed.json"
mkdir -p "$ROOT/.build"
uv run --project "$ROOT/pipeline" python -c "
import json
with open('$ROOT/contracts/examples/student-state.json') as f:
    state = json.load(f)
state['schema_version'] = 1
for node in state['nodes'].values():
    node.pop('remediated', None)
with open('$SEED_PATH', 'w') as f:
    json.dump(state, f)
"
mkdir -p "$DATA_CONTAINER/Library/Application Support"
cp "$SEED_PATH" "$STATE_PATH"

xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID"
sleep 3
if ! is_running; then
    echo "sim-smoke: $BUNDLE_ID is not running after the seeded launch" >&2
    exit 1
fi
if [ ! -e "$STATE_PATH" ]; then
    echo "sim-smoke: seeded state file is missing after launch" >&2
    exit 1
fi
if [ -e "${STATE_PATH}.pre-migration" ]; then
    echo "sim-smoke: a .pre-migration file remains after a successful migration" >&2
    exit 1
fi
uv run --project "$ROOT/pipeline" python -c "
import json
from jsonschema import Draft202012Validator
with open('$ROOT/contracts/schemas/student-state.schema.json') as f:
    schema = json.load(f)
Draft202012Validator.check_schema(schema)
validator = Draft202012Validator(schema)
with open('$STATE_PATH') as f:
    instance = json.load(f)
assert instance['schema_version'] == 2, instance['schema_version']
validator.validate(instance)
print('sim-smoke: migrated state file validates against student-state.schema.json')
"
cp "$STATE_PATH" "$ROOT/.build/sim-smoke-migrated.json"

xcrun simctl terminate "$SIM_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID"
sleep 3
if ! is_running; then
    echo "sim-smoke: $BUNDLE_ID is not running after relaunch" >&2
    exit 1
fi
if ! cmp -s "$ROOT/.build/sim-smoke-migrated.json" "$STATE_PATH"; then
    echo "sim-smoke: the state file changed across a relaunch (load must never write)" >&2
    exit 1
fi
echo "sim-smoke: scenario 2 (v1 -> v2 migration, byte-identical relaunch) PASS"

# --- Embedded snapshot cmp against data/demo ---
for f in manifest.json regions.json nodes.json edges.json courses.json landmarks.json sources.json; do
    if ! cmp -s "$APP_PATH/DemoSnapshot/$f" "$ROOT/data/demo/$f"; then
        echo "sim-smoke: $APP_PATH/DemoSnapshot/$f differs from data/demo/$f" >&2
        exit 1
    fi
done
echo "sim-smoke: embedded DemoSnapshot byte-identical to data/demo"
```

`STATE_FILE_NAME` here must equal `AppShell.stateFileName` (`"student-state.json"`) — the two are kept in sync
by inspection, mirroring `StudentStateStore`'s own locally-duplicated-constant precedent (03.5 §6). `$DATA_CONTAINER`
is resolved once, after the fresh-install launch, and reused for scenario 2 (the container path does not change
across terminate/launch on the same install).

### 4.9 `scripts/gate.sh` — the App-build line and the new smoke call

```sh
echo "== 4/4 App build on the simulator + pipeline tests =="
xcodebuild build -quiet -workspace "$ROOT/App/mathmath.xcworkspace" -scheme mathmath -destination "$SIM" -configuration Debug -derivedDataPath "$ROOT/.build/DerivedData" CODE_SIGNING_ALLOWED=NO
"$ROOT/scripts/sim-smoke.sh"
( cd "$ROOT/pipeline" && uv run pytest -q )
```

### 4.10 `.github/workflows/ci.yml` — the `swift` job

Modify the existing "App build on the simulator" step to add `-configuration Debug -derivedDataPath
.build/DerivedData`, then add two steps after it:

```yaml
      - name: App build on the simulator
        run: xcodebuild build -quiet -workspace App/mathmath.xcworkspace -scheme mathmath -destination "${{ steps.sim.outputs.dest }}" -configuration Debug -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO
      - uses: astral-sh/setup-uv@v6
        with:
          version: "0.12.12"
      - name: Simulator smoke (fresh install + v1→v2 migration, arbiter-03 § Q-G)
        run: scripts/sim-smoke.sh
```

The pin `"0.12.12"` matches the `python` job's own `setup-uv` step exactly (§3), per the ruling's "the same pin
as the `python` job".

### 4.11 The 03.9 scan deletion (`AppSourcesBoundaryTests.swift`, `AppSourcesBoundaryNegativeControlTests.swift`)

In `AppSourcesBoundaryTests.swift`, delete the doc comment and the two constants quoted in §3 in full:
`contentViewSwiftMathExceptionFile`, `contentViewSwiftMathExceptionImport`. Inside `violations(in:rules:)`,
replace the `for rule in rules where rule.violates(lineText) { if rule.name == … { continue } violations.append
(…) }` block with the plain, unconditional form:

```swift
                for rule in rules where rule.violates(lineText) {
                    violations.append("\(file.lastPathComponent): \(rule.name)")
                }
```

In `AppSourcesBoundaryNegativeControlTests.swift`, reverse `exemptsSwiftMathInsideTopLevelContentView()` (rename
to e.g. `catchesSwiftMathImportInTopLevelContentView()`) so it asserts the opposite of its current premise —
`import SwiftMath` in a top-level `ContentView.swift` of a fixture tree is now **reported**:

```swift
    // 03.12 removed the time-boxed exception once ContentView.swift no longer imports SwiftMath. This test
    // proves the removal actually re-enables detection at the exact path the exception used to cover.
    @Test("catches import SwiftMath now that the top-level ContentView.swift exception is gone")
    func catchesSwiftMathImportInTopLevelContentView() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try "import SwiftMath\nimport SwiftUI\nstruct ContentView: View { var body: some View { Text(\"\") } }\n"
            .write(to: tempRoot.appendingPathComponent("ContentView.swift"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(
            violations.contains { $0 == "ContentView.swift: non-allow-listed import" },
            "the top-level ContentView.swift exception should be gone after 03.12 — got: \(violations)")
    }
```

The two sibling AC7 tests (`catchesSwiftMathImportOutsideException`, `catchesSwiftMathImportInNestedContentView`)
are untouched — their premises (a violation in a non-`ContentView.swift` file, or a nested `ContentView.swift`)
never depended on the exception applying, so their assertions hold unchanged before and after this deletion.

### 4.12 D-13 re-measurement

Before staging any change, run `git status --porcelain
App/mathmath.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/` and confirm the directory is not staged by
this task's own `git add`. Record nothing in `docs/DEFERRED.md` here — the 03.13 wrap records the measurement
(arbiter-03 § Q-G, "D-13").

### 4.13 Commit

```
feat(app): shell — launch wiring, refusal/unreadable surfaces, simulator smoke
```

### 4.14 Smoke check

`scripts/gate.sh` in full — must be green (all four gates, including the new sim-smoke step in gate 4).

## §5 Test plan (risk: seam — full plan)

**C3 note.** As established by `tasks/epic-03-task-10-*.md` §5 and `tasks/epic-03-task-11-*.md` §5, `App/
mathmath.xcodeproj` has no App unit-test target. This task's own new `App/Sources` code (`AppShell.swift`,
`RefusalView.swift`, the `ContentView`/`MathmathApp` edits) is verified by the App build, the 03.9 scan, and the
simulator smoke script — not by a `Core`/App unit test. No claim in this task's acceptance report asserts
screenshot-level or interaction-level correctness; that is the owner's Demo-wrap check (D29). The two modified
`Core` test files (§4.11), by contrast, ARE verified by `xcodebuild test -scheme Core-Package` in the normal way.

- T1 happy path:
  - the App build (`xcodebuild build -workspace App/mathmath.xcworkspace -scheme mathmath -configuration Debug
    -derivedDataPath .build/DerivedData`) succeeds with all four new/modified `App/Sources` files compiled in
    (AC1–AC8, AC14).
  - the 03.9 scan (`xcodebuild test -scheme Core-Package`) is green over the complete `App/Sources` tree with no
    carve-out (AC9, AC10).
  - `scripts/sim-smoke.sh` exits 0, printing both scenario-PASS lines and the embedded-snapshot cmp line (AC11).
  - `AppSourcesBoundaryNegativeControlTests.catchesSwiftMathImportInTopLevelContentView()` (the reversed test)
    passes as a normal `Core` test (AC9).
- T2 negative — invalid input rejected at the boundary: not applicable in the schema-validation sense (this
  task's own `App/Sources` code parses no untrusted external payload, §4.5). The closest analogue: sim-smoke's
  scenario 1 assertion that **no** file exists is itself a negative assertion (rejecting the false claim that
  the App wrote prematurely); its `if [ -e "$STATE_PATH" ]; then … exit 1; fi` branch is the negative-control
  shape for that claim.
- T3 error-taxonomy: `rg -n "CoreErrorText" App/Sources/Shell` shows exactly two call sites
  (`RefusalView`'s `.platformSnapshotRefused` lookup, `AppShell`'s `.platformStateUnreadable` lookup); `rg -n
  '"PLATFORM_' App/Sources/Shell` shows exactly one string literal (`"PLATFORM_STATE_UNREADABLE"`, the
  `messages.contains` check) — no other registry code is named by string anywhere in this task's `App/Sources`
  scope, and no ad-hoc error text is authored.
- T4 conformance per requirements §B.1 (`contracts/data-model.md` § Versioning/§ Time, `contracts/
  deployment-model.md`'s Student state row, arbiter-03 § Q-A/§ Q-F/§ Q-G, and I5/I14 per §1):
  - I14: the App-build + 03.9-scan + sim-smoke triad (AC14) is the C1 seam evidence this task owns; `rg -n
    "StudentState\(|MarkerTrail\.|Expedition\.|MasteryTransitions\.|DiagnosisRun\." App/Sources/Shell` returns
    no match.
  - I5: `rg -n "URLSession|URLRequest" App/Sources/Shell` returns no match (also covered generically by the
    03.9 scan's own network rule); the state file's path is resolved only from
    `.applicationSupportDirectory`, never a hardcoded absolute path or a value derived from a device/install
    identifier.
  - arbiter-03 § Q-A ("no write on load"): sim-smoke's scenario 2 final `cmp` (§4.8) is the end-to-end proof —
    a relaunch that silently wrote anything (even a re-serialization with identical content but different
    byte layout) would fail this check, since `CoreCoding.encoder`'s `.sortedKeys` determinism (03.5's own
    T1 note) means "wrote nothing" and "wrote the identical bytes" are the only two ways this assertion passes,
    and only the former is true on a load-only relaunch.
- T5 negative control for every regression guard:
  - the reversed `catchesSwiftMathImportInTopLevelContentView()` (§4.11) is the negative control for the
    carve-out deletion itself: if any trace of the exception survived (the constants, the skip block, or a
    stray re-add), this test fails to catch the planted `import SwiftMath` and reds — proving the deletion is
    complete, not merely renamed.
  - sim-smoke's scenario 1 no-file check is the negative control against a premature-write bug in `AppShell`
    or the façade (a bug that called `selectCourse`/wrote a default state before the student picked a course
    would fail this check).
  - sim-smoke's scenario 2 `.pre-migration`-absence check and the final byte-identity `cmp` are, together, the
    negative control against a migration bug that either leaves the backup file behind (arbiter-03 § Q-F: "keep
    the pre-migration file until the migrated one is written" — 03.5's own responsibility, re-exercised
    end-to-end here) or silently re-writes on a load-only relaunch (Q-A precision 3).
- T6 idempotency / no-leak:
  - `MapStateHolder.replace(with:)` never merges or accumulates — a second `replace` call fully supersedes the
    first (verified by inspection: the property is `private(set) var mapState: MapState?` with a single
    assignment, no array or dictionary accumulation).
  - sim-smoke's own uninstall-then-install at the start of scenario 1 makes the whole script idempotent across
    repeated runs (no state from a prior run of the script leaks into the next).
  - the embedded-snapshot `cmp` loop (§4.8, final section) is read-only and side-effect-free; running it twice
    in a row produces the same PASS/FAIL outcome both times.

## §6 Decision defaults

- IF the state-file's exact on-disk name is left to the implementer's choice THEN it is
  `AppShell.stateFileName = "student-state.json"`, directly inside Application Support (no subdirectory) — no
  ruling names an exact filename beyond "a fixed file name under Application Support" (arbiter-03 § Q-G,
  quoted §3); this default is shared verbatim, by inspection, between `AppShell.swift` and
  `scripts/sim-smoke.sh`'s `STATE_FILE_NAME` (§4.8, §4.9).
- IF `Bundle.main.resourcePath` should instead resolve directly to the snapshot's files (a flat layout, no
  `DemoSnapshot` subdirectory) THEN it does not — the context bundle's own §G fact ("resolved from `Bundle.main
  .resourcePath`") is read together with 03.4's own embedding location, `App/Sources/DemoSnapshot/` (§3); Xcode's
  file-system-synchronized group preserves that subdirectory in the built product, and `sim-smoke.sh`'s final
  cmp loop (§4.8) is this task's own end-to-end verification that the assumption holds against the real built
  `.app` — if it does not, the smoke script's cmp step fails loudly rather than the App silently refusing at
  launch with no diagnostic.
- IF the App should create a fresh default `StudentState` itself on `courseSelectionNeeded` (rather than waiting
  for `CoursePickerView.onSelected`) THEN it does not — arbiter-03 § Q-E (quoted in 03.7's own spec, §3 there)
  is explicit that no valid `StudentState` can exist before a course is chosen; `AppShell` only ever presents the
  picker and replaces the holder with whatever `MapFacade.selectCourse` returns.
- IF `AppShell` should branch on the specific code inside `messages` (e.g. a `switch` over known strings) THEN
  it does not — arbiter-03 § Q-A's own principle ("the App never branches on a code itself", quoted §3) is
  applied generically: the one `messages.contains("PLATFORM_STATE_UNREADABLE")` check exists only because that
  is the single code 03.7's own AC4/T4 guarantees can ever appear in `messages` on this build's reachable paths,
  and it looks up text through `CoreErrorText`, never hardcoding a sentence.
- IF the region/landmark panels 03.11 shipped should be wired into the map screen by this task THEN they are
  not — 03.10's `MapCanvasView` ships a node-tap callback only (03.10 §6 decision default, quoted §4.2), and
  extending it is out of this task's file scope (§2); this is recorded as an intentional gap, not a silent
  omission.
- IF `-derivedDataPath`/`-configuration Debug` should be added only to `sim-smoke.sh`'s own invocation of
  `xcodebuild` (building the App itself inside the smoke script) rather than to the shared gate/CI build step
  THEN it is not — the dispatch scope's own wording ("fixed `-derivedDataPath`") is read as: the *existing*
  App-build step (already run once per gate/CI invocation) gains the fixed path, and `sim-smoke.sh` locates the
  already-built product there — building the App a second time inside the smoke script would double the build
  cost with no compensating benefit (RULE 2: no speculative work).
- IF a bare `xcrun simctl launch` failing to find the app running should retry automatically THEN it does not —
  the smoke script fails loudly and immediately (`exit 1`) on the first `is_running` check that fails, per
  arbiter-03 § Q-G's "Empty checks are FAIL: a missing container or a missing file fails the smoke", read as
  extending to "the process is not running" as well; a retry loop would risk masking a real launch regression
  behind transient simulator flakiness, which the ruling's own "Revisit trigger: CI simulator-boot flakes"
  clause already anticipates as a *future* fallback (the wrap's runbook command), not this task's default.
- IF `MapmathApp.swift`'s `import Core` should be kept "just in case a future file in the same target needs it"
  THEN it is dropped — RULE 3 ("remove imports/variables/functions that YOUR changes made unused") applies
  directly: nothing in `MathmathApp.swift`'s post-edit body references a `Core` symbol.

Standing defaults: identifiers and timestamps are untouched beyond what `AppShell.resolveToday()`/
`resolveStateURL()` already produce (a `CalendarDay` value and a device-local file URL, neither leaving the
device, I5); no model call exists anywhere in this task's code (I2 vacuous); telemetry is unaffected — no
telemetry client, no consent field read or written by any file in this task's scope; no node's Ministry text is
read or shown (this task renders only values 03.7/03.11 already cleared, I6).

## §7 Done definition

The task is done when ALL gates pass:

- format + lint clean (`xcrun swift-format lint --strict --recursive --configuration .swift-format Packages
  App/Sources`).
- typecheck clean (Swift's typecheck is the build).
- `Core` build + test green (`swift build -c release --product core-cli`; `xcodebuild test -scheme
  Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO`), including the two modified 03.9 test files
  (§4.11) and every other existing `CoreTests` suite unmodified and green.
- App build green (`xcodebuild build -workspace App/mathmath.xcworkspace -scheme mathmath -configuration Debug
  -derivedDataPath .build/DerivedData -destination "$SIM" CODE_SIGNING_ALLOWED=NO`).
- `scripts/gate.sh` green in full, including the new `scripts/sim-smoke.sh` step in gate 4.
- `.github/workflows/ci.yml`'s `swift` job green with its new `setup-uv` and smoke steps.
- tests green for every case in §5 (T1–T6).
- the D-13 re-measurement (§4.12, AC13) performed and confirmed not staged; no edit to `docs/DEFERRED.md` by
  this task.
- conforms to every contract section cited in §3 (`contracts/data-model.md` § Versioning/§ Time,
  `contracts/deployment-model.md`'s Student state row, `contracts/error-codes.json`'s two cited entries,
  `contracts/interaction-contract.md`'s v0.9.2 § 3 bullet) and to every invariant listed in §1 (I14, I5, I2;
  I1/I3/I4/I6/I10/I15 noted not newly engaged); D29 honoured (simulator only).
- the C3 exclusion (§1, §5) is honoured: no claim of screenshot-level or pixel-level verification appears in
  this task's acceptance report; visual and tap-behavior correctness is the owner's Demo-wrap check.
