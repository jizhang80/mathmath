# Epic 03 · Task 11: App panels, pickers and the EPIC 04 hand-off

---
epic: 03
task: 11
slug: app-panels-pickers-handoff
kind: feat
risk: seam
depends_on: [03.9]
model: sonnet
---

> **Branch note.** Written against the current tree (clean `main`; no `epic-03a-map-core` or
> `epic-03b-map-app` branch yet — confirmed by `git log`, and by direct reads in this session:
> `contracts/interaction-contract.md:3` still reads `v0.9.1`, `docs/domains/map.md:88-95` still describes the
> drag gesture, and `Packages/Core/Sources/Core/Platform/MapLaunch.swift` / `CoreErrorText.swift` are both
> confirmed absent via `Glob` in this run). The implementer runs this task on `epic-03b-map-app`, created
> after `epic-03a-map-core` (tasks 03.1–03.8) merges into `main` and this task's direct dependency, **03.9**
> (`app-sources-i14-scan`), lands. By that time:
> - `contracts/interaction-contract.md` is v0.9.2 and `docs/domains/map.md` § W5 / the `MAP_MARKER_OFF_TRAIL`
>   row read the no-drag, unit-list-only text (task 03.1, `tasks/epic-03-task-01-contract-interaction-marker-
>   unit-list.md`, exact replacement text quoted §3 below). This task's product code and prose follow that
>   post-03.1 text; nowhere does this spec or its code describe or offer a drag gesture.
> - `MapFacade` (with `MapState`, `LaunchOutcome`, `NodePanelContent`, `RegionPanelContent`,
>   `LandmarkPanelContent`, `IncludeOutcome`, and the six façade functions this task calls) exists exactly as
>   `tasks/epic-03-task-07-map-actions-facade-launch.md` §4 specifies, re-read and byte-compared in this
>   session (§3 below quotes every signature this task depends on).
> - `CoreErrorText.userText` / `CoreErrorText.text(for:)` exist exactly as
>   `tasks/epic-03-task-03-core-error-surface-text-mirror.md` §4.2 specifies, re-read and byte-compared in
>   this session (§3 below).
> - **03.9's own scan** (`docs/plans/epic-03-plan.md` § 03.9, quoted §3) enforces the allow-list this task's
>   code must already satisfy: no `StudentState(` construction, no direct `Core` transition call outside
>   03.7's façade, no `data/` read, no `URLSession`/`URLRequest`, no `FoundationModels`/third-party-engine
>   import, no free-text/OCR/item-check path. No `tasks/epic-03-task-09-*.md` file exists yet at the time this
>   spec is written (`Glob tasks/epic-03-task-09*` returned no match in this session) — this task's code is
>   written to satisfy the *class* of checks the plan doc already fixes, not a signature file that does not
>   yet exist. If, by implementation time, 03.9's landed scan enforces a materially different allow-list than
>   the plan doc's own description, that is the EPIC-order precondition changing — BLOCK and report it; do not
>   silently narrow or guess at the new allow-list.
>
> If any of the above is absent when implementation starts, that is an EPIC-order precondition failing to
> hold — BLOCK and report it; do not stub, re-derive or reimplement any of `MapFacade`, `CoreErrorText` or the
> contract text this task depends on.

## §1 Goal & acceptance criteria

Goal: ship six SwiftUI views under `App/Sources/MapUI/` that render 03.7's map-actions façade output as sheets
and full-screen pickers, and that trigger the façade's three hand-off actions ("Check me here", "Include",
"Unit expedition") through one typed hook, `HandOffHook`, carrying one placeholder enum, `HandOffDestination`,
that EPIC 04 (tasks 04.8/04.9) replaces with real screens. Every view is a pure function of the `Core`-computed
values it is handed (`NodePanelContent`, `RegionPanelContent`, `LandmarkPanelContent`, `MapState`) plus, where a
façade call can fail with a registered student-surface code, one piece of `@State` holding that resolved text —
never a hand-authored string. This task ships no screen assembly (`ContentView`/`MathmathApp`, task 03.12's
scope) and no map canvas (task 03.10's scope, already specified); it ships only the panels, the two pickers, and
the three action buttons plus their shared hand-off types.

Invariants in play:

- **I1** — not engaged: no item is checked and no correctness verdict is decided by any view in this task; the
  three action buttons pass façade output through unchanged.
- **I2** — Tier 0 only: no file in this task imports `FoundationModels` or calls any model adapter; every
  action is a direct, synchronous `MapFacade` call.
- **I3** — not engaged: no answer is shown or withheld here; these panels never render a probe or its answer.
- **I5** — every view holds only ids, enum cases, `Core` value types and `String`/`Double`/`Bool` presentation
  data already cleared by `Core`; no field named, or resembling, a device/install/session identifier is added
  anywhere in this task's code.
- **I6** — `NodePanelView` renders `content.paraphrase` and `content.expectationCodeLinks[].officialUrl`
  (03.7's `NodePanelContent`, §3); no file in this task's scope ever reads, references or displays a field
  named `verbatim`, and none exists on any type this task consumes.
- **I14** — every file in this task's scope holds only presentation state (§4.6); every state change is made
  by calling one of 03.7's public `MapFacade` functions exactly once per user action; no file constructs a
  `StudentState`, calls `MarkerTrail`, `Expedition`, `MasteryTransitions`, `DiagnosisRun` or L0 directly, and no
  file re-derives a node's offered action (`NodePanelView` reads `mapState.viewModel.nodes[...].action`, an
  id-keyed lookup over an already-derived array, never a re-derivation — §6).
- **I15** — `LandmarkPanelView` renders `content.sourceUrl` (already L0/decode-time validated as resolving,
  per `tasks/epic-03-task-07-*.md` §1's I15 note) via `Link`, never fetching it itself.

Acceptance criteria (each independently verifiable):

- AC1: `NodePanelView` renders, for a given `NodePanelContent`, its `name`, `paraphrase`, `masteryLabel`, every
  `expectationCodeLinks` entry as a `Link` to its `officialUrl`, every `courseCodesCrossingHere` entry, and
  every `landmarkIds` entry (as its raw id, non-interactively — §6); it renders exactly one action control,
  chosen by looking up `mapState.viewModel.nodes.first(where: { $0.id == content.nodeId })?.action` — `.include`
  renders `IncludeActionButton`, `.checkHere` renders `CheckHereActionButton`, `nil` renders neither.
- AC2: `CheckHereActionButton`'s action calls `MapFacade.checkHere(nodeId:mapState:)` exactly once and calls its
  `handOff: HandOffHook` exactly once with `.diagnosis(event:)` carrying the returned `DiagnosisEvent`
  unchanged; it throws nothing (03.7's `checkHere` never throws).
- AC3: `IncludeActionButton`'s action calls `MapFacade.include(nodeId:mapState:)` exactly once and calls
  `handOff` exactly once with `.included(map:)` carrying the returned `MapState` unchanged, regardless of
  whether the façade's `outcome` was `.queued` or `.ignored` (§6 default).
- AC4: `UnitExpeditionActionButton`'s action calls `MapFacade.unitExpedition(unitId:mapState:today:)` exactly
  once; on success it calls `handOff` exactly once with `.unitExpedition(result:)` carrying the returned
  `ComposeResult` unchanged and clears any prior error text; on a thrown `CoreError.expNoFringe` it sets its own
  `@State` error text to `CoreErrorText.text(for: .expNoFringe)` (verified non-nil, §3) and calls `handOff` zero
  times; on any other thrown error it calls `handOff` zero times and sets no error text (§6, matching the
  internal-surface treatment of every other façade-thrown code in this task).
- AC5: `RegionPanelView` renders, for a given `RegionPanelContent`, its `name`, `about`,
  `courseCodesCrossingHere`, and either a percentage derived only by formatting `clearedFraction` (no new
  domain computation) when non-`nil`, or the literal string `"under fog"` when `nil`; it offers no action
  control (region panels have no action, map § W3, §3).
- AC6: `LandmarkPanelView` renders, for a given `LandmarkPanelContent`, its `name`, `whatItIs`, `sourceUrl` as a
  `Link`, and one row per `nodeIds` entry that calls a caller-supplied `onNodeJump: (String) -> Void` with that
  node's id when tapped — a same-EPIC navigation callback, never a `HandOffDestination` case (§6).
- AC7: `CoursePickerView` lists every `bundle.courses.courses` entry by its `name`; tapping one calls
  `MapFacade.selectCourse(courseCode:bundle:stateURL:previousState:today:)` exactly once; on success it calls
  `onSelected: (MapState) -> Void` exactly once with the returned `MapState`; on a thrown error it calls
  `onSelected` zero times and shows no text (§6).
- AC8: `UnitListPickerView` lists `course.units` in order as one row each (`Button(unit.name)`), followed by
  exactly one final row (labelled `"Past the last unit"`) when `course.units` is non-empty; a normal row calls
  `MapFacade.setMarker(unitId: unit.unitId, pastLastUnit: false, mapState:, today:)`; the final row calls
  `MapFacade.setMarker(unitId: course.units.last!.unitId, pastLastUnit: true, mapState:, today:)`; either call
  happens exactly once per tap, and on success calls `onMarkerSet: (MapState) -> Void` exactly once with the
  returned `MapState`; on a thrown error it calls `onMarkerSet` zero times and shows no text (§6).
- AC9: `HandOffDestination` (`MapActionsView.swift`) has exactly three cases —
  `.diagnosis(event: DiagnosisEvent)`, `.unitExpedition(result: ComposeResult)`, `.included(map: MapState)` —
  and no other case; `HandOffHook` is the type alias `(HandOffDestination) -> Void`.
- AC10: No file in this task's scope contains `URLSession`, `URLRequest`, `StudentState(`, `MarkerTrail.`,
  `Expedition.`, `MasteryTransitions.`, `DiagnosisRun.`, or a force-unwrapped `URL(string:` construction
  (`URL(string: ...)!`); every `official_url`/`source_url` reaches the student only via SwiftUI `Link`.
- AC11: No file in this task's scope contains the banned glossary synonyms for a term this task uses:
  `"session"`, `"start marker"`, `"cursor"`, `"profile"`, `"progress file"`, `"save"` used as an identifier or
  in on-screen text (`contracts/domain-glossary.md`, quoted §3); `"course-progress marker"`/`"marker"` and
  `"student state"` are the only forms used.
- AC12: The App builds green (`xcodebuild build -quiet -workspace "$ROOT/App/mathmath.xcworkspace" -scheme mathmath
  -destination "$SIM" CODE_SIGNING_ALLOWED=NO`, gate 4, `scripts/gate.sh` line 22, re-read in this run) with
  all six files compiled into the target via the synchronized `Sources` group (no `pbxproj` edit);
  `swift-format lint --strict` is clean on all six files; the 03.9 source scan
  (`xcodebuild test -scheme Core-Package`) stays green with these six files present in `App/Sources`.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `App/Sources/MapUI/NodePanelView.swift` — CREATE. Confirmed absent (context bundle §E:
  `Glob **/NodePanelView.swift` returned no match). The node-panel sheet (map W2 step 1) plus its one
  action-by-state control.
- `App/Sources/MapUI/RegionPanelView.swift` — CREATE. Confirmed absent (context bundle §E). The region-panel
  sheet (map W3).
- `App/Sources/MapUI/LandmarkPanelView.swift` — CREATE. Confirmed absent (context bundle §E). The
  landmark-panel sheet (map W4) with its per-node jump rows.
- `App/Sources/MapUI/CoursePickerView.swift` — CREATE. Confirmed absent (context bundle §E). The first-launch
  / course-change picker (arbiter-03 § Q-E).
- `App/Sources/MapUI/UnitListPickerView.swift` — CREATE. Confirmed absent (context bundle §E, as
  `UnitListPickerView.swift`). The unit-list marker picker (map W5, interaction-contract v0.9.2 § 3).
- `App/Sources/MapUI/MapActionsView.swift` — CREATE. Confirmed absent (context bundle §E). `HandOffDestination`,
  `HandOffHook`, and the three action-button views (`CheckHereActionButton`, `IncludeActionButton`,
  `UnitExpeditionActionButton`).

Out-of-scope (do not touch even if tempted):

- `Packages/Core/**` — read-only; call only `MapFacade`'s and `CoreErrorText`'s public entry points, never a
  `Core` type's transition method directly.
- `App/Sources/Map/MapCanvasView.swift`, `App/Sources/Map/MapCamera.swift` — task 03.10's file scope, already
  specified (`tasks/epic-03-task-10-app-map-canvas.md`); this task supplies no tap-resolution code and no
  `Canvas` drawing.
- `App/Sources/ContentView.swift`, `App/Sources/MathmathApp.swift` — task 03.12's scope (app-shell wiring,
  Application Support/embedded-snapshot URL resolution, injecting `today`, the `@Observable` holder that
  replaces `MapState` after each façade call). This task ships no call site that instantiates any of its six
  views inside the app's live view hierarchy, and stores no `MapState` itself.
- `contracts/**`, `docs/**`, `data/**` — read-only ground truth.
- Any file under `App/mathmath.xcodeproj/` — never edited; the synchronized `Sources` group picks up new files
  automatically (`docs/tech-stack.md` § 2, quoted §3).

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/content-policy.md` — heading `## Grade 9–12 tier (Ministry authority)`:
  > A node or expectation carries codes + the project's own `paraphrase` + an `official_url`. No field
  > anywhere holds Ministry prose; the key `verbatim` is banned repo-wide (grep gate).

  Source: `contracts/content-policy.md:9-10` (re-read, byte-compared in this run — the context bundle's own
  citation named this heading "Grade 9–12 tier policy", which does not match the file; corrected here to the
  file's actual heading). Binds AC1: `NodePanelView` renders `paraphrase` and `officialUrl` only, never a
  Ministry-text field (none exists on `NodePanelContent`).

- `contracts/content-policy.md` — heading `## Landmarks (I15, D22)`:
  > Real, named, verifiable; `source_url` required and resolving at build (HTTP 2xx); `source_title` required
  > — the title of the real, named thing the landmark cites, as that title appears on the source page — and
  > the fetched page text must contain it (case-insensitive substring). The landmark's `name` is the
  > project's own descriptive claim about the mathematics and is by design not a term from the source, so it
  > is never asserted against the page; a landmark's `name` is never edited to make a check pass. ≥ 1 node
  > id. Unsourced → dropped, never invented, never "hypothetical".

  Source: `contracts/content-policy.md:39-45` (re-read, byte-compared in this run — the context bundle's own
  citation named this heading "Landmarks rule", which does not match the file; corrected here). Binds AC6:
  `LandmarkPanelView` renders `sourceUrl` as a clickable `Link`; the URL was validated at bundle load, this
  task performs no further check.

- `contracts/deployment-model.md` — the Network allowlist paragraph (this bold paragraph sits directly under
  the file's own `# Contract: Deployment model (LOCK-FIRST)` heading; the file has no subheading over it — the
  context bundle's own citation invented a `### Network allowlist` heading that does not exist in this file;
  corrected here):
  > **Network allowlist for the app (asserted by a test, App EPIC):** the content host, the telemetry
  > endpoint, iCloud. Nothing else, ever — a spec adding a host is a Q5 (D36).

  Source: `contracts/deployment-model.md:16-17` (re-read, byte-compared in this run). Binds AC10: every
  `official_url`/`source_url` this task's views render is handed to the system URL handler (SwiftUI `Link`),
  never fetched by an App-side `URLSession`/`URLRequest` call.

- `contracts/error-codes.md` — heading `## Rules`:
  > Internal codes never reach a student surface; a `student` code always has a next action in its text.

  Source: `contracts/error-codes.md:18` (re-read, byte-compared in this run). Binds AC4/AC7/AC8: every
  `CoreError` this task's façade calls can throw whose registry entry is `"surface": "internal"`
  (`EXP_TRAIL_INVALID`, `PLATFORM_STATE_WRITE_FAILED` — both confirmed `"surface": "internal", "user_text":
  null` by re-reading `contracts/error-codes.json` lines 15 and 50 in this run) is never displayed; only
  `EXP_NO_FRINGE` (`"surface": "student"`, confirmed `contracts/error-codes.json:14`, re-read in this run) has
  text shown, and only via `CoreErrorText.text(for:)`.

- `contracts/domain-glossary.md` — heading `## Map and graph (Door C)`:
  > - **Course-progress marker** ("we are here in class") — the student's chosen current unit (D45). Short
  >   form in code: `marker`. *Banned:* "start marker" (v2.1 D28 name), "position", "cursor".

  Source: `contracts/domain-glossary.md:22` (re-read, byte-compared in this run). Binds AC11 and
  `UnitListPickerView`'s naming.

- `contracts/domain-glossary.md` — heading `## Expedition (Door B)`:
  > - **Expedition** — one run of ≈ 5 items (D23). *Banned:* "quiz", "session" (a session is a telemetry
  >   day-unit), "quest", "level".
  > - **Student state** (`StudentState`) — the one persisted document (D32). *Banned:* "profile", "progress
  >   file", "save".

  Source: `contracts/domain-glossary.md:29,36` (re-read, byte-compared in this run). Binds AC11.

- `docs/tech-stack.md` — the "App project" row of § 1:
  > Agents add files under `App/Sources` and `Packages/Core` **without editing the pbxproj**; no XcodeGen/Tuist

  Source: `docs/tech-stack.md:24` (re-read, byte-compared in this run). Binds §2's out-of-scope pbxproj note.

Domain-doc excerpts (verbatim, `docs/domains/map.md`, re-read and byte-compared directly in this run against
the file's **current** pre-03.1 state; the W5 quote below is corrected to the **post-03.1** text task 03.1's
own spec lands, per this task's Branch note):

- heading `### W2 — Tap a node`:
  > **Pre:** map open. **Steps:** 1. Open the **node panel**: name, `paraphrase`, expectation codes with the
  > official link (I6), mastery state in plain words ("under fog", "cleared", "blocked — something upstream
  > is in the way"), "which courses walk through here" from trail data, linked landmarks. 2. Offer exactly one
  > action by state: fogged and reachable → "Include in my next expedition"; `blocked` or upstream of the
  > marker → "Check me here" (opens **diagnosis** W1 on this node, the D28 way in); `cleared` → nothing to do.
  > **Post:** no state change; `map.node_opened` emitted.

  Source: `docs/domains/map.md:71-77` (current text, re-read and byte-compared in this run). Binds AC1's field
  list and button labels.

- heading `### W3 — Tap a region`:
  > **Pre:** map open. **Steps:** open the **region panel**: name, the one-sentence description, fraction
  > cleared (Q2), and the trails that cross it. A `horizon` region is not tappable. **Post:** `map.region
  > _opened`.

  Source: `docs/domains/map.md:79-81` (re-read, byte-compared in this run). Binds AC5. A `horizon` region
  returns `nil` from `MapFacade.regionPanelContent` (03.7 §4.3) and is therefore never handed to
  `RegionPanelView` at all — this task adds no separate horizon check.

- heading `### W4 — Tap a landmark`:
  > **Pre:** map open. **Steps:** open the **landmark panel**: name, `what_it_is`, the source link (I15), and
  > "which parts of the map this touches" as jump links, one per linked node, each landing on W2 for that node.
  > **Post:** `map.landmark_opened` emitted (a D40 event).

  Source: `docs/domains/map.md:83-86` (re-read, byte-compared in this run). Binds AC6.

- heading `### W5 — Set the course-progress marker`, **post-03.1 text** (task 03.1's own spec,
  `tasks/epic-03-task-01-contract-interaction-marker-unit-list.md` §4 step 4, re-read and byte-compared in
  this run — the **current** tree's `docs/domains/map.md:88-95` still reads the pre-03.1 drag text at the time
  this spec is written, per this task's Branch note):
  > **Pre:** a course trail segment is selected. **Steps:** 1. Show the course's **unit list**
  > (curriculum-spine `Unit`s, D45) with the current one highlighted; the student picks "we are here in
  > class". The marker is set from this list only; there is no drag (interaction-contract v0.9.2 § 3). 2. Hand
  > the unit id to **expedition** (`map.marker_moved`), which owns the change, regenerates the trail (D47 —
  > past the last unit the trail extends, drawn dashed) and recomputes the fringe (D45/D48). 3. Re-derive fog:
  > nodes upstream of the marker are fog with an "upstream of your class" note, never cleared. **Post:**
  > marker persisted by expedition; `map.marker_moved` emitted (a D40 event).

  Binds AC8: `UnitListPickerView` offers no drag, only unit-list rows plus the final "past the last unit" row.

- `## Open questions`, `**Q5 — Can the student add a fogged node to the next expedition from the panel?**`
  (this is the file's own heading level and exact wording — the context bundle's citation named a
  non-existent `### Q5 — Include from the panel` heading; corrected here after re-reading the file directly):
  > **Default:** yes, one node, queued ahead of the scheduler's pick if it is on the fringe; ignored with a
  > plain message if it is upstream of the marker (D45 — that way in is "Check me here"). **Trade-off:** gives
  > the map a reason to be tapped; a queue longer than one is scheduling policy the student should not have to
  > manage.

  Source: `docs/domains/map.md:170-174` (re-read, byte-compared in this run). Binds AC3/§6: "ignored ... with
  no student text" — `IncludeActionButton` shows no text on either outcome.

`docs/epics/epic-03-app-map-shell.md` (the amended brief), re-read and byte-compared in this run:

- § 2, "Hand-offs to EPIC 04 (the seam)":
  > For "Check me here", "Include" and "Unit expedition", EPIC 03 ships the map action, its `Core` call and the
  > typed value that call returns: a `DiagnosisEvent`, a `ComposeResult`, or the queued node. EPIC 03 also
  > ships the navigation hook that hands that value on. **EPIC 04 owns every screen these values open**: the
  > expedition item view, the hypothesis card, probe, remediation and summary. Between the two EPICs, the hook
  > may land on a placeholder destination that EPIC 04 replaces.

  Source: `docs/epics/epic-03-app-map-shell.md:83-87`. Binds `HandOffDestination`/`HandOffHook`'s whole shape
  (§4.6, AC9).

- § 7, out-of-scope item 1:
  > Expedition, answer-card, hypothesis-card, probe, remediation and summary screens; the "Start expedition"
  > entry; the unit-expedition entry screen; the Demo acceptance record — EPIC 04 (its epic-plan row). EPIC 03
  > stops at the typed hand-off value (§2).

  Source: `docs/epics/epic-03-app-map-shell.md:398-400`. Binds §6's decision default on `UnitExpeditionAction
  Button`'s placement: this task ships the button component and its one façade call, never a dedicated
  "start unit expedition" screen.

Prior signatures this task builds on (verbatim, re-read and byte-compared against
`tasks/epic-03-task-07-map-actions-facade-launch.md` in this session):

```swift
public struct MapState {
    public let bundle: ContentBundle
    public let stateURL: URL
    public let state: StudentState
    public let viewModel: MapViewModel
    public let queuedNodeId: String?
}

public struct ExpectationCodeLink: Equatable {
    public let courseCode: String
    public let code: String
    public let officialUrl: String
}
public struct NodePanelContent: Equatable {
    public let nodeId: String
    public let name: String
    public let paraphrase: String
    public let expectationCodeLinks: [ExpectationCodeLink]
    public let masteryLabel: String
    public let courseCodesCrossingHere: [String]
    public let landmarkIds: [String]
}
public struct RegionPanelContent: Equatable {
    public let regionId: RegionId
    public let name: String
    public let about: String
    public let clearedFraction: Double?
    public let courseCodesCrossingHere: [String]
}
public struct LandmarkPanelContent: Equatable {
    public let landmarkId: String
    public let name: String
    public let whatItIs: String
    public let sourceUrl: String
    public let nodeIds: [String]
}

public enum MapFacade {
    public static func nodePanelContent(
        nodeId: String, mapState: MapState
    ) -> (content: NodePanelContent, events: [CoreEvent])?

    public static func regionPanelContent(
        regionId: RegionId, mapState: MapState
    ) -> (content: RegionPanelContent, events: [CoreEvent])?

    public static func landmarkPanelContent(
        landmarkId: String, mapState: MapState
    ) -> (content: LandmarkPanelContent, events: [CoreEvent])?

    public static func selectCourse(
        courseCode: String, bundle: ContentBundle, stateURL: URL, previousState: StudentState?,
        today: CalendarDay
    ) throws -> (map: MapState, events: [CoreEvent])

    public static func setMarker(
        unitId: String, pastLastUnit: Bool, mapState: MapState, today: CalendarDay
    ) throws -> (map: MapState, events: [CoreEvent])

    public enum IncludeOutcome: Equatable { case queued, ignored }
    public static func include(
        nodeId: String, mapState: MapState
    ) -> (map: MapState, outcome: IncludeOutcome, events: [CoreEvent])

    public static func unitExpedition(
        unitId: String, mapState: MapState, today: CalendarDay
    ) throws -> (result: ComposeResult, events: [CoreEvent])

    public static func checkHere(
        nodeId: String, mapState: MapState
    ) -> (event: DiagnosisEvent, events: [CoreEvent])
}
```

```swift
// Packages/Core/Sources/Core/CoreErrorText.swift (task 03.3's spec §4.2, re-read and byte-compared in this
// session)
public enum CoreErrorText {
    public static let userText: [String: String] = [
        "MAP_MARKER_OFF_TRAIL": "The marker stays where it was; pick a unit from the list.",
        "EXP_NO_FRINGE": "You've cleared everything up to here. Move your class marker forward, or explore the map.",
        // … (the remaining registered student-surface entries; not repeated here — see 03.3 §4.2)
    ]
    public static func text(for code: CoreError) -> String? { userText[code.rawValue] }
}
```

```swift
// Packages/Core/Sources/Core/Map/MapViewModel.swift (task 03.6's spec, quoted verbatim by
// tasks/epic-03-task-07-*.md §3 and tasks/epic-03-task-10-*.md §3, re-verified against both in this session)
public enum NodeAction: Equatable { case checkHere, include }
public struct NodeView: Equatable {
    public let id: String
    public let regionId: RegionId
    public let position: Point
    public let fogLevel: Mastery
    public let due: Bool
    public let upstream: Bool
    public let action: NodeAction?
}
public struct MapViewModel: Equatable {
    public let regions: [RegionView]
    public let nodes: [NodeView]
    // … (rivers, trailSegments, positionIndicatorNodeId, landmarks, focusFrame — unused by this task)
}
```

```swift
// Packages/Core/Sources/Core/Model/Courses.swift:9-42 (current tree, re-read and byte-compared in this run)
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
public struct Unit: Codable, Equatable {
    public let unitId: String
    public let name: String
    public let expectationCodes: [String]
}
```

```swift
// Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift (task 02.11's landed spec, quoted verbatim by
// tasks/epic-03-task-07-*.md §3)
public enum DiagnosisTrigger: String, Equatable { case expeditionSecondMiss = "expedition_second_miss"
    case mapCheckHere = "map_check_here" }
public struct DiagnosisEvent: Equatable {
    public let originNodeId: String
    public let trigger: DiagnosisTrigger
    public let levelBudget: Int
}
```

```swift
// Packages/Core/Sources/Core/State/Expedition.swift (quoted verbatim by tasks/epic-03-task-07-*.md §3)
public struct ComposeResult: Equatable {
    public let slots: [ComposeSlot]
    public let skippedNodeIds: [String]
}
```

Plan scope for the guard this task's output must pass (verbatim, `docs/plans/epic-03-plan.md` § 03.9,
re-read and byte-compared in this run):

> **03.9:** a Core test scanning `App/Sources` for violations of I14, I5, I1/I10 and D24:
> - no `StudentState(`;
> - no direct Core transitions outside 03.7's allow-list;
> - no reads of `data/` paths;
> - no `URLSession` or `URLRequest`;
> - no FoundationModels or third-party engines;
> - no free-text answer, OCR or item-check path.
>
> It has a planted-violation negative control per class. An empty scan fails.

Glossary note kept for spec writers (verbatim, `docs/plans/epic-03-plan.md`, re-read and byte-compared in
this run):
> Glossary: never use "session", "start marker", "cursor", "profile" or "save" in new identifiers or copy.

Source: `docs/plans/epic-03-plan.md:142`.

Gate commands (`scripts/gate.sh`, `docs/tech-stack.md` § 3, re-read byte-for-byte in this run):

```sh
xcrun swift-format lint --strict --recursive --configuration "$ROOT/.swift-format" "$ROOT/Packages" "$ROOT/App/Sources"
( cd "$ROOT/Packages/Core" && xcodebuild test -quiet -scheme Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO )
xcodebuild build -quiet -workspace "$ROOT/App/mathmath.xcworkspace" -scheme mathmath -destination "$SIM" CODE_SIGNING_ALLOWED=NO
```

(the third line is `scripts/gate.sh:22`, re-read byte-for-byte in this run; the App build gate always names
the workspace, never the bare scheme, because the project's package dependencies resolve only through
`App/mathmath.xcworkspace`.)

## §4 Implementation outline

Layer placement: layer ④ interaction's render layer (Door C), `App/Sources`. Every file reads only values
`Core` (03.7) already computed and produces SwiftUI views plus outgoing callbacks; nothing here derives a fog
level, an offered action, a fringe membership or a trail fact.

### 4.1 `NodePanelView.swift`

```swift
import Core
import SwiftUI

struct NodePanelView: View {
    let content: NodePanelContent
    let mapState: MapState
    let handOff: HandOffHook

    private var action: NodeAction? {
        mapState.viewModel.nodes.first(where: { $0.id == content.nodeId })?.action
    }

    var body: some View {
        List {
            Section {
                Text(content.name).font(.headline)
                Text(content.paraphrase)
                Text(content.masteryLabel)
            }
            if !content.expectationCodeLinks.isEmpty {
                Section("Expectation codes") {
                    ForEach(content.expectationCodeLinks, id: \.code) { link in
                        if let url = URL(string: link.officialUrl) {
                            Link("\(link.courseCode) \(link.code)", destination: url)
                        } else {
                            Text("\(link.courseCode) \(link.code)")
                        }
                    }
                }
            }
            if !content.courseCodesCrossingHere.isEmpty {
                Section("Courses that walk through here") {
                    ForEach(content.courseCodesCrossingHere, id: \.self) { Text($0) }
                }
            }
            if !content.landmarkIds.isEmpty {
                Section("Linked landmarks") {
                    ForEach(content.landmarkIds, id: \.self) { Text($0) }
                }
            }
            switch action {
            case .checkHere:
                CheckHereActionButton(nodeId: content.nodeId, mapState: mapState, handOff: handOff)
            case .include:
                IncludeActionButton(nodeId: content.nodeId, mapState: mapState, handOff: handOff)
            case nil:
                EmptyView()
            }
        }
    }
}
```

`action` is a presentation-only lookup by id over `mapState.viewModel.nodes`, an array `Core`'s
`MapViewModel.derive` already fully computed (03.6) — this view invents no fog/fringe/upstream logic of its
own (I14, §6).

### 4.2 `RegionPanelView.swift`

```swift
import Core
import SwiftUI

struct RegionPanelView: View {
    let content: RegionPanelContent

    var body: some View {
        List {
            Section {
                Text(content.name).font(.headline)
                Text(content.about)
                if let fraction = content.clearedFraction {
                    Text("\(Int((fraction * 100).rounded()))% cleared")
                } else {
                    Text("under fog")
                }
            }
            if !content.courseCodesCrossingHere.isEmpty {
                Section("Courses that cross this region") {
                    ForEach(content.courseCodesCrossingHere, id: \.self) { Text($0) }
                }
            }
        }
    }
}
```

No action control: map § W3 (§3) names none, and `MapFacade.regionPanelContent` already returns `nil` for a
`horizon` region, so this view never receives one.

### 4.3 `LandmarkPanelView.swift`

```swift
import Core
import SwiftUI

struct LandmarkPanelView: View {
    let content: LandmarkPanelContent
    let onNodeJump: (String) -> Void

    var body: some View {
        List {
            Section {
                Text(content.name).font(.headline)
                Text(content.whatItIs)
                if let url = URL(string: content.sourceUrl) {
                    Link("Source", destination: url)
                } else {
                    Text(content.sourceUrl)
                }
            }
            if !content.nodeIds.isEmpty {
                Section("Where this touches the map") {
                    ForEach(content.nodeIds, id: \.self) { nodeId in
                        Button(nodeId) { onNodeJump(nodeId) }
                    }
                }
            }
        }
    }
}
```

`onNodeJump` is same-EPIC navigation (landing on W2 for that node, per the W4 quote §3) — a plain callback, not
a `HandOffDestination` case; the caller (task 03.12) is expected to fetch that node's `NodePanelContent` via
`MapFacade.nodePanelContent` and present `NodePanelView` for it, outside this task's scope.

### 4.4 `CoursePickerView.swift`

```swift
import Core
import SwiftUI

struct CoursePickerView: View {
    let bundle: ContentBundle
    let stateURL: URL
    let previousState: StudentState?
    let today: CalendarDay
    let onSelected: (MapState) -> Void

    var body: some View {
        List(bundle.courses.courses, id: \.courseCode) { course in
            Button(course.name) { select(course.courseCode) }
        }
    }

    private func select(_ courseCode: String) {
        do {
            let (map, _) = try MapFacade.selectCourse(
                courseCode: courseCode, bundle: bundle, stateURL: stateURL,
                previousState: previousState, today: today)
            onSelected(map)
        } catch {
            // CoreError.expTrailInvalid / .platformStateWriteFailed: both surface: internal in
            // contracts/error-codes.json (§3) — no student-facing text exists for either. The picker stays on
            // screen; the student's next tap retries the same call (§6).
        }
    }
}
```

`previousState` is `nil` on the first-launch path (`courseSelectionNeeded`, arbiter-03 § Q-E) and the prior
`StudentState` on a later course change; this view makes no decision about which — its caller (03.12) supplies
whichever applies.

### 4.5 `UnitListPickerView.swift`

```swift
import Core
import SwiftUI

struct UnitListPickerView: View {
    let course: Course
    let mapState: MapState
    let today: CalendarDay
    let onMarkerSet: (MapState) -> Void

    var body: some View {
        List {
            ForEach(course.units, id: \.unitId) { unit in
                Button(unit.name) { setMarker(unitId: unit.unitId, pastLastUnit: false) }
            }
            if let lastUnit = course.units.last {
                Button("Past the last unit") {
                    setMarker(unitId: lastUnit.unitId, pastLastUnit: true)
                }
            }
        }
    }

    private func setMarker(unitId: String, pastLastUnit: Bool) {
        do {
            let (map, _) = try MapFacade.setMarker(
                unitId: unitId, pastLastUnit: pastLastUnit, mapState: mapState, today: today)
            onMarkerSet(map)
        } catch {
            // Same internal-surface treatment as CoursePickerView.select (§6).
        }
    }
}
```

The "past the last unit" row passes the course's own last unit id, matching interaction-contract v0.9.2 § 3's
own text ("setting it writes the course's last unit as `unit_id`") — `MarkerTrail.setMarker` (02.5b-corrected)
substitutes it regardless, so this view never computes the last unit itself; it only avoids passing an
arbitrary id. No drag gesture exists anywhere in this file (§3, post-03.1 W5 text).

### 4.6 `MapActionsView.swift`

```swift
import Core
import SwiftUI

/// EPIC 04 (tasks 04.8/04.9) replaces the destinations this enum stands in for (docs/epics/epic-03-app-map-
/// shell.md § 2, quoted §3). Each case carries exactly the value its façade call already returns — nothing
/// this task invents.
enum HandOffDestination {
    case diagnosis(event: DiagnosisEvent)
    case unitExpedition(result: ComposeResult)
    case included(map: MapState)
}

typealias HandOffHook = (HandOffDestination) -> Void

struct CheckHereActionButton: View {
    let nodeId: String
    let mapState: MapState
    let handOff: HandOffHook

    var body: some View {
        Button("Check me here") {
            let (event, _) = MapFacade.checkHere(nodeId: nodeId, mapState: mapState)
            handOff(.diagnosis(event: event))
        }
    }
}

struct IncludeActionButton: View {
    let nodeId: String
    let mapState: MapState
    let handOff: HandOffHook

    var body: some View {
        Button("Include in my next expedition") {
            let (newMap, _, _) = MapFacade.include(nodeId: nodeId, mapState: mapState)
            handOff(.included(map: newMap))
        }
    }
}

struct UnitExpeditionActionButton: View {
    let unitId: String
    let mapState: MapState
    let today: CalendarDay
    let handOff: HandOffHook

    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading) {
            Button("Unit expedition") { start() }
            if let errorText {
                Text(errorText)
            }
        }
    }

    private func start() {
        do {
            let (result, _) = try MapFacade.unitExpedition(unitId: unitId, mapState: mapState, today: today)
            errorText = nil
            handOff(.unitExpedition(result: result))
        } catch let error as CoreError {
            // The only façade-thrown code among this task's calls with a registered student-surface text
            // (contracts/error-codes.json § 3): EXP_NO_FRINGE.
            errorText = CoreErrorText.text(for: error)
        } catch {
            errorText = nil
        }
    }
}
```

`IncludeActionButton` hands off `newMap` regardless of the façade's `outcome`; per arbiter-03 § Q-D (quoted
`tasks/epic-03-task-07-*.md` §3) an "ignored" Include carries "no student text and no new code", and 03.7's
AC12 guarantees `newMap.queuedNodeId` is unchanged from the input on `.ignored`— so the hand-off value itself
already reflects whether the queue changed; no extra branch is needed (§6).

### 4.7 Presentation-state boundary (I14)

No file in this task's scope stores a `MapState`, a `StudentState` or a `ContentBundle` across calls; every
view takes its `Core`-computed input as a `let` property and, where a façade call can fail with a
student-surface code, holds exactly one `@State` field for the resolved text (`UnitExpeditionActionButton
.errorText`). No file calls `Expedition`, `MarkerTrail`, `MasteryTransitions` or `DiagnosisRun` directly; every
state-changing action goes through exactly one of `MapFacade`'s six functions this task calls
(`selectCourse`, `setMarker`, `include`, `unitExpedition`, `checkHere`, plus the three panel-content readers
called by this task's caller, not by these views themselves — §4.1's note).

### 4.8 Boundary validation

No file in this task validates untrusted input directly: `NodePanelContent`/`RegionPanelContent`/
`LandmarkPanelContent`/`MapState`/`Course` are already-valid `Core` value types handed in by the caller;
`bundle.courses.courses` and `course.units` are bundle data already passed through L0 (03.4). The one place a
string could be malformed is a URL built from `officialUrl`/`sourceUrl`: every `URL(string:)` call in this
task is guarded with `if let`, never force-unwrapped (AC10) — a malformed URL renders its raw string as `Text`
instead of crashing.

### 4.9 Error codes thrown

This task throws no `CoreError` of its own. It catches, and either discards (internal-surface) or displays
(`EXP_NO_FRINGE` only, via `CoreErrorText.text(for:)`), the codes `MapFacade.selectCourse`, `.setMarker` and
`.unitExpedition` can throw, per `tasks/epic-03-task-07-*.md` §4.7:
- `CoreError.expTrailInvalid` — internal surface, no text (`CoursePickerView`, `UnitListPickerView`).
- `CoreError.platformStateWriteFailed` — internal surface, no text (`CoursePickerView`, `UnitListPickerView`).
- `CoreError.expNoFringe` — student surface, `CoreErrorText.text(for: .expNoFringe)` shown
  (`UnitExpeditionActionButton`).

### 4.10 Model-calling paths

None. Every view in this task is Tier 0, synchronous, pure presentation plus one façade call per user action
(I2's confidence-threshold/fallback requirement is not engaged).

### 4.11 Smoke check

`xcodebuild build -quiet -workspace "$ROOT/App/mathmath.xcworkspace" -scheme mathmath -destination "$SIM"
CODE_SIGNING_ALLOWED=NO` (`scripts/gate.sh:22`, quoted §3 byte-for-byte) — must be green, with all six files
compiled into the `mathmath` target via the synchronized `Sources` group even though no call site instantiates
them yet (03.12's job; matches every prior EPIC 03b task's own precedent, e.g. `tasks/epic-03-task-10-*.md` §4
step 11).

## §5 Test plan (risk: seam — full plan)

**C3 note (owner-verified, no agent claim of pixel-level correctness).** `App/mathmath.xcodeproj` has no App
unit-test target (`tasks/arbitration/arbiter-03-predispatch.md` § Q-F, re-read and byte-compared in this run:
"CONFIRMED, consistent with I14 and D33." … "No App test target is needed."). This task's verification is
therefore the App build, the lint gate, the 03.9 structural scan, and source-level inspection against each AC —
the same C3 exclusion already established by `tasks/epic-03-task-10-*.md` §5 for `App/Sources`-only code with
no `Core` counterpart. No claim in this task's acceptance report asserts screenshot-level or runtime-rendered
correctness; that is the owner's Demo-wrap check (D29).

- **T1 happy path:** AC1–AC9 are each verified by (a) `xcodebuild build -quiet -workspace "$ROOT/App/mathmath.xcworkspace"
  -scheme mathmath -destination "$SIM" CODE_SIGNING_ALLOWED=NO` (`scripts/gate.sh:22`) succeeding with all six
  files compiled in, (b) a full read-through of each file confirming every AC's field list, call count and
  case list matches §4's code exactly, and (c) `swift-format lint --strict` clean on all six files.
- **T2 negative — invalid input rejected at the boundary:** not applicable in the throwing/validation sense for
  the three read-only panels (their one input is an already-valid `Core` value type, §4.8). For the three
  façade-calling views/buttons: `rg -n "URL\(string:.*\)!" App/Sources/MapUI` returns no match (AC10, no
  force-unwrapped URL); every `catch` block in `CoursePickerView.swift`/`UnitListPickerView.swift` is confirmed
  by inspection to assign no `String` to any `@State`/`Text` (the internal-surface codes show nothing, §6).
- **T3 error-taxonomy:** `rg -n "CoreErrorText" App/Sources/MapUI` shows exactly one call site
  (`UnitExpeditionActionButton.start()`), and `rg -n "\.expNoFringe" App/Sources/MapUI` shows exactly the one
  `catch let error as CoreError` branch that reads it — the only registry code this task ever displays. No
  `Text(` literal in any of the six files names an error condition ad hoc (verified by reading every `Text(`
  call site against §4's listing).
- **T4 conformance per requirements §B.1** (`contracts/content-policy.md` §§ Grade 9–12 tier / Landmarks,
  `contracts/deployment-model.md`'s Network allowlist paragraph, `contracts/error-codes.md` § Rules,
  `contracts/domain-glossary.md`, and I1/I2/I3/I5/I6/I14/I15 per §1):
  - I6/I15: `rg -n "verbatim" App/Sources/MapUI` returns no match; every `officialUrl`/`sourceUrl` reaches the
    student only via `Link` (`rg -n "Link\(" App/Sources/MapUI` shows every such site; `rg -n "URLSession|URL
    Request" App/Sources/MapUI` returns no match, AC10).
  - I14: the 03.9 scan (§3, `docs/plans/epic-03-plan.md` § 03.9) is re-run with these six files present and
    stays green — `rg -n "StudentState\(|MarkerTrail\.|Expedition\.|MasteryTransitions\.|DiagnosisRun\."
    App/Sources/MapUI` returns no match (AC10), a **derived** allowlist check against 03.7's own public
    `MapFacade` surface (§3's quoted signatures), never a hand-maintained list of literals — the same
    `MapFacade.` call sites named in §4 are the only `Core` entry points this task's grep is expected to find.
  - Glossary (AC11): `rg -ni "\bsession\b|start marker|\bcursor\b|\bprofile\b|progress file|\bsave\b"
    App/Sources/MapUI` returns no match.
- **T5 negative control for every regression guard:**
  - AC9's exact-three-case guard: `rg -n "case " App/Sources/MapUI/MapActionsView.swift` inside the
    `HandOffDestination` enum body shows exactly three lines; a fourth case added later without updating this
    guard is caught by re-running the count.
  - AC2/AC3/AC4's "exactly one façade call per action" guard: `rg -n "MapFacade\." App/Sources/MapUI/MapActions
    View.swift` shows exactly three call sites (`checkHere`, `include`, `unitExpedition`), one per button —
    proving no button performs two façade calls, or calls the wrong one, before this task's own review passes.
  - AC7/AC8's "one façade call per tap" guard: `rg -n "MapFacade\." App/Sources/MapUI/CoursePickerView.swift
    App/Sources/MapUI/UnitListPickerView.swift` shows exactly one call site in each file.
  - The 03.9 scan's own planted-violation classes (owned by task 03.9) must still fire correctly with these six
    files present: re-running that scan's test target after this task's files exist is the regression guard's
    own negative control, proving the allowlist actually covers this task's call sites rather than accidentally
    matching nothing (mirrors `tasks/epic-03-task-10-*.md` §5's T2 language for the same scan).
- **T6 idempotency / no-leak:** `rg -n "@State" App/Sources/MapUI` returns exactly one match
  (`UnitExpeditionActionButton.errorText`), confirming no file holds `Core` state across calls (I14); no file
  performs a second façade call as a side effect of the first (`CoursePickerView.select` and
  `UnitListPickerView.setMarker` each contain exactly one `try MapFacade.` statement, per T5's count); no view
  retains a `MapState`/`StudentState` beyond the single call it was handed for — every façade result flows
  outward through a callback (`onSelected`/`onMarkerSet`/`handOff`), never stored locally.

## §6 Decision defaults

- IF `NodePanelView` should receive a pre-computed `action: NodeAction?` parameter from its caller THEN it
  does not — it takes the full `mapState: MapState` and looks up `mapState.viewModel.nodes.first(where:
  {$0.id == content.nodeId})?.action` itself, a presentation-only id lookup over an already-derived array, not
  a new derivation — the same pattern `tasks/epic-03-task-10-*.md` §4 step 6/§6 established for its own
  `nodesById` lookup ("a presentation-only index over values `MapViewModel` already computed; it derives no
  new fog/due/trail/action fact"). This keeps the caller (03.12) from having to pre-resolve the action itself.
- IF the App should show a fallback error message when a façade call throws an internal-surface `CoreError`
  (`CoreError.expTrailInvalid` / `.platformStateWriteFailed`, both `"surface": "internal", "user_text": null`
  in `contracts/error-codes.json`, re-read in this run) THEN it must not — `contracts/error-codes.md` § Rules
  (quoted §3): "Internal codes never reach a student surface." `CoursePickerView` and `UnitListPickerView`
  show no text on such a failure and simply remain on screen; the student's next tap retries the same façade
  call (no `Result`-wrapping, no cached failure state — a plain `throws` function either returns or does not,
  consistent with `tasks/epic-03-task-07-*.md` §6's own equivalent default for its façade callers).
- IF "Unit expedition" should be wired into a specific screen or entry point by this task THEN it is not —
  `docs/epics/epic-03-app-map-shell.md` § 7 item 1 (quoted §3) names "the unit-expedition entry screen" as
  EPIC 04's own out-of-scope item ("EPIC 03 stops at the typed hand-off value"). This task ships only the
  reusable `UnitExpeditionActionButton` component (`MapActionsView.swift`) that performs the one façade call
  and the hand-off; which screen instantiates it, and with which `unitId`, is left to a later task (03.12 or
  EPIC 04) — no `App/Sources/MapUI` file in this task's scope constructs one.
- IF the Include façade's `outcome` (`.queued` vs `.ignored`) should be threaded through `HandOffDestination`
  as a fourth piece of information THEN it is not — the dispatch scope's own payload list for the three
  hand-offs is exactly "(`DiagnosisEvent`, updated state with the queued node, `ComposeResult`)`; `IncludeAction
  Button` always hands off the returned `MapState` regardless of outcome, and arbiter-03 § Q-D (quoted §3) rules
  that an "ignored" Include carries "no student text and no new code" — `newMap.queuedNodeId` (unchanged from
  the input on `.ignored`, per `tasks/epic-03-task-07-*.md` AC12) already carries the only signal that matters.
- IF `NodePanelContent`'s `landmarkIds` should be rendered with the linked landmark's name, or made tappable
  to jump to the landmark panel, THEN they must render as their raw id, non-interactively — `NodePanelContent`
  (§3) carries no landmark name field, and map § W2 (§3) describes "linked landmarks" as informational content
  only (jump links are W4's own, landmark-to-node, one-directional rule); looking up a display name here would
  mean `NodePanelView` re-deriving display data outside `Core` (I14), which this task's file scope forbids —
  the same reasoning `tasks/epic-03-task-10-*.md` §6 already applied to its own id-only labels.
- IF a picker's error handling should use `try?` (discarding the specific thrown error) instead of `do`/
  `catch` THEN `do`/`catch` with an intentionally empty `catch` body is used uniformly — `UnitExpeditionAction
  Button` needs the typed `CoreError` to look up `CoreErrorText.text(for:)`, so every façade call in this
  task's scope is written the same, explicit way for consistency, even where the catch body does nothing (the
  second decision default above).
- IF `RegionPanelView`'s pure-fog wording should reuse `NodePanelContent.masteryLabel`'s exact string ("under
  fog") for consistency, or invent a new phrase, THEN it reuses the exact string — both come from the same
  glossary entry ("Fog — the rendering of an uncleared node", `contracts/domain-glossary.md` § Map and graph,
  banned synonyms "locked"/"unknown"/"mastered" per §3's fuller quote there), and `RegionPanelContent` carries
  no separate wording field to derive from.
- IF the T4 glossary grep (§5) should also ban the bare token `position` THEN it does not — the same
  `contracts/domain-glossary.md` § Map and graph entry that bans "position" as a synonym for the
  course-progress marker (quoted §3) sits in a `Core` type this task legitimately references by name,
  `MapViewModel.positionIndicatorNodeId` (§3, listed among the fields "unused by this task"); a bare `\bposition
  \b` grep would false-positive on that legitimate identifier the moment any future task in this same
  directory reads it, or on a legitimate future UI label such as "position indicator". AC11 is therefore left
  as written — it lists the five unambiguous banned tokens the glossary bans outright ("session", "start
  marker", "cursor", "profile", "progress file", "save") — and "position" used as a marker-synonym is instead
  caught by T1's source-level read-through of each file's on-screen strings against §1's field list, not by
  grep.

Standing defaults: identifiers and timestamps are untouched by this task — every id/timestamp already on
`MapState`/`NodePanelContent`/etc. passes through opaquely, and no file constructs one. Model calls do not
exist anywhere in this task's code (I2 vacuous). Telemetry is unaffected: no telemetry client, no consent
field, no identifier is read or written by any of the six files. No node's Ministry text is read — `paraphrase`
is the only prose field this task renders, per I6.

## §7 Done definition

The task is done when ALL gates pass:

- format + lint clean (`xcrun swift-format lint --strict --recursive --configuration .swift-format Packages
  App/Sources`).
- typecheck clean (Swift's typecheck is the build).
- App build green (`xcodebuild build -quiet -workspace "$ROOT/App/mathmath.xcworkspace" -scheme mathmath -destination
  "$SIM" CODE_SIGNING_ALLOWED=NO`, `scripts/gate.sh:22`, gate 4) with all six files compiled into the target via
  the synchronized `Sources` group.
- the task 03.9 source scan (`xcodebuild test -scheme Core-Package`, its test target) stays green with these
  six files added to `App/Sources` — no planted-violation class of 03.9's scan fires against any of them.
- tests green for every case in §5 (T1–T6).
- glossary grep clean (AC11) and no force-unwrapped `URL(string:` construction anywhere in this task's scope
  (AC10).
- conforms to every contract section cited in §3 (`contracts/content-policy.md`'s Grade 9–12 tier and
  Landmarks headings, `contracts/deployment-model.md`'s Network allowlist paragraph, `contracts/error-codes.md`
  § Rules, `contracts/domain-glossary.md`) and to every invariant listed in §1 (I1, I2, I3, I5, I6, I14, I15).
- the C3 exclusion (§5) is honoured: no claim of screenshot-level or pixel-level verification appears in this
  task's acceptance report; visual correctness is the owner's Demo-wrap check (D29).
