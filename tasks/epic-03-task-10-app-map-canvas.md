# Epic 03 · Task 10: App map canvas (SwiftUI `Canvas` rendering of `MapViewModel`)

---
epic: 03
task: 10
slug: app-map-canvas
kind: feat
risk: mechanical
depends_on: [03.09]
model: sonnet
---

## §1 Goal & acceptance criteria

Goal: Add a SwiftUI `Canvas`-based map view, `MapCanvasView`, and its camera helper, `MapCamera`, under
`App/Sources/Map/`. `MapCanvasView` renders a `MapViewModel` value (produced elsewhere, by `Core`'s task 03.6
derivation and handed in by the caller) — regions, rivers, nodes (fog/blocked/cleared, due ring), trail
segments (solid course / dashed extension), the position indicator, landmarks and the greyed horizon labels.
The view's only state is the ephemeral pan/zoom camera transform; the initial camera frames the model's
`focusFrame` (trail-first, D44). A tap resolves to the id of the `NodeView` the model placed at that screen
location and is handed to a caller-supplied callback; task 03.11/03.12 wire that callback to the node panel and
the diagnosis/expedition hand-offs. The view computes no domain state of its own: no fog, fringe, due,
mastery or trail logic — every one of those is already decided in the `MapViewModel` it receives.

Invariants in play:
- **I2** — Tier 0 only. `MapCanvasView.swift` and `MapCamera.swift` import no model/adapter framework
  (`FoundationModels` or otherwise); rendering runs with no model call on the path.
- **I10** — the only student input this view accepts is taps, drag and pinch gestures over the canvas; no
  free-text field, no OCR path, nothing that reads or writes an answer.
- **I14 (primary)** — `MapCanvasView` is renderer-free of domain logic: it stores nothing beyond the
  `MapViewModel` value it was handed and its own ephemeral `MapCamera` (pan + zoom); it constructs no
  `StudentState`, calls no `Core` transition or derivation function, and never independently thresholds a
  label — every visibility decision it draws (`nodeNames`/`regionNames`/`landmarkNames`) comes from calling
  `mapViewModel.labelSet(atZoom:)`, never from a value this view invents. `Core`'s `MapViewModel` is the single
  source of every fog level, due flag, upstream flag, offered action and label-set decision (`tasks/epic-03-
  task-06-map-view-model.md` §1/§2/§4, cited verbatim in §3 below); this task never restates any of it.
- **D24** — SwiftUI `Canvas` only; no `SpriteKit`, no third-party game engine; state transitions between
  `MapViewModel` values use a basic SwiftUI transition/animation only, never a game-style animated mechanic.

Acceptance criteria (every AC is verifiable by source inspection and/or the build/lint gates — see the C3 note
in §5 on why no runtime-rendered assertion is possible here):

- AC1: `MapCanvasView`'s only stored properties are the `MapViewModel` value it was initialized with, an
  `onNodeTap: (String) -> Void` callback, and `@State` properties that together hold only the pan/zoom
  transform (`MapCamera`, plus at most one `Bool` flag recording whether the initial camera has been framed).
  No `StudentState`, `ContentBundle`, or any other `Core` type beyond `MapViewModel`'s own value types
  (`NodeView`, `RegionView`, `River`, `TrailSegmentView`, `LandmarkView`, `FocusFrame`, `LabelSet`,
  `NodeAction`, `RegionId`, `Point`, `Mastery`) appears as a stored property or a parameter to either file.
- AC2: neither file references `Expedition`, `MarkerTrail`, `MasteryTransitions`, `DiagnosisRun`, `BundleIO`,
  `StudentStateStore`, or any map-actions façade entry point — grep over both files for these identifiers
  returns zero hits.
- AC3: every place the view decides whether to draw a region name, node name or landmark name calls
  `mapViewModel.labelSet(atZoom:)` with the current `MapCamera.zoomScale` and reads the returned
  `LabelSet.regionNames` / `.nodeNames` / `.landmarkNames` — no independent zoom-threshold constant is
  declared in `MapCanvasView.swift` or `MapCamera.swift`.
- AC4: `MapCamera`'s initial value is produced once, by `MapCamera.initial(focusFrame:canvasSize:)`, from
  `mapViewModel.focusFrame` (trail-first, D44) and the canvas's measured size; a later change to the
  `mapViewModel` the view was re-initialized with (a W6 re-derivation handed in by the caller) does not reset
  an already-framed camera — panning and zooming already performed by the student persist across state
  updates.
- AC5: a tap inside the canvas is converted to bundle coordinate space through `MapCamera`'s inverse transform,
  resolves to the nearest `NodeView` within the tap-hit radius (§4 step 7), and invokes `onNodeTap(nodeId)`
  exactly once for that node id; a tap that resolves to no node within the radius invokes the callback zero
  times.
- AC6: `App/Sources/Map/MapCanvasView.swift` and `App/Sources/Map/MapCamera.swift` import only `Foundation`
  and `SwiftUI` — no `SpriteKit`, no `FoundationModels`, no `UIKit` symbol beyond what `SwiftUI`/`Canvas`
  already re-exports, no `URLSession`/`URLRequest`, and no `StudentState(` construction — matching the guard
  classes the 03.9 source scan checks (`docs/plans/epic-03-plan.md` § 03.9, quoted in §3).
- AC7: the App builds green (`xcodebuild build -scheme mathmath` on the simulator, gate 4) with both files
  compiled into the target, and `swift-format lint --strict` is clean on both files.
- AC8: a transition between two `MapViewModel` values applied to an already-displayed `MapCanvasView` (fog
  lifted, a blocked marker placed, a region re-tinted — W6) uses at most one basic SwiftUI `.animation`/
  `.transition` modifier; no custom animation loop, timer-driven mechanic or `SpriteKit` scene exists in either
  file (D24).

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `App/Sources/Map/MapCanvasView.swift` — CREATE. Confirmed absent: context bundle §E, glob
  `App/Sources/Map/**` returned no matches. The `MapCanvasView` SwiftUI view: `Canvas` drawing of regions,
  rivers, nodes, trail segments, the position indicator, landmarks and horizon labels; pan/zoom gesture
  handling; tap-to-node-id resolution; the `onNodeTap` callback.
- `App/Sources/Map/MapCamera.swift` — CREATE. Confirmed absent: context bundle §E, same glob. The `MapCamera`
  value type: pan + zoom state, the bundle-coordinate ↔ screen-coordinate transform (both directions) and the
  `MapCamera.initial(focusFrame:canvasSize:)` trail-first framing function.

Out-of-scope (do not touch even if tempted):

- `App/Sources/ContentView.swift`, `App/Sources/MathmathApp.swift` — owned by task 03.12 (App shell wiring);
  this task ships no call site that constructs `MapCanvasView` inside the app's live view hierarchy.
- Node/region/landmark sheet panels, the course picker, the unit-list marker picker, the three action buttons
  — task 03.11's file scope. This task supplies only the raw tap-to-node-id callback; 03.11 decides what a tap
  opens.
- `Packages/Core/Sources/Core/Map/MapViewModel.swift`, the map-actions façade, `MapLaunch` — already specified
  and owned by tasks 03.6/03.7 (03a); read-only inputs to this task.
- Region or landmark tap resolution. The context bundle's own scope statement for this task (§A, §F) names
  only the node-id tap; see §6 decision default for the reasoning and the hand-off note for a later task.
- `App/mathmath.xcodeproj/project.pbxproj` — never edited; the synchronized `Sources` group picks up new files
  automatically (`docs/tech-stack.md` § 1, quoted in §3).
- `contracts/**`, `docs/**`, `data/**`, `scripts/**`, `.github/**` — this task adds no contract, registry,
  content or CI change.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/domain-glossary.md` — heading `## Map and graph (Door C)`:
  > - **Region** — one of the ten D21 territories (`region_id` fixed enum, `data-model.md`). *Banned:* "area", "zone", "strand" (a strand is a Ministry division, see below).
  > - **Fog** — the rendering of an uncleared node. Mastery states: **fog · cleared · blocked** (`data-model.md`). *Banned:* "locked", "unknown" (as a state), "mastered".
  > - **Due** — a cleared node whose `next_due` has passed; drawn with a *due ring*. Not a mastery state.
  > - **Trail** — the student's one generated path over the graph (D47): **segments** that are either a **course segment** (`course_code`) or an **extension** (dashed). *Banned:* "path", "route", "track", "course trail" (a course is not a trail).
  > - **Course-progress marker** ("we are here in class") — the student's chosen current unit (D45). Short form in code: `marker`. *Banned:* "start marker" (v2.1 D28 name), "position", "cursor".
  > - **Position indicator** — the first uncleared trail node at or after the marker (display only).
  > - **Landmark** — a real, named, sourced thing linked to nodes (D22). *Banned:* "application", "example", "story".

  Source: `contracts/domain-glossary.md:12,17-19,22-24` (byte-verified in this session; the context bundle's
  own copy of the Region bullet silently dropped the trailing clause "(a strand is a Ministry division, see
  below)" — corrected here; flagged to the compiler). Every identifier, doc comment and any on-screen text this
  task draws uses these terms; the banned synonyms never appear.

Domain-doc excerpts (verbatim, re-read and byte-verified this session, `docs/domains/map.md`):

- § Core entities — `NodeView` (`:49-52`):
  > **NodeView** — a node as drawn: its coordinates (from the bundle, D42), its region, its mastery state from
  > `StudentState` (**expedition**) projected to a fog level — `fog` (full), `blocked` (fog with a marker),
  > `cleared` (lifted), plus a `due` ring when spaced repetition has come round (Q1) — and whether it lies
  > upstream of the current trail's marker.

- § Core entities — `MapViewModel` (`:54-57`):
  > **MapViewModel** — the pure derivation rendered each frame: regions with a tint from the fraction of their
  > nodes cleared (Q2), rivers, trails with marker and position indicator, landmarks, horizon labels, and the
  > label set for the current zoom (Q4). Derived in `Core` from bundles + `StudentState`; never persisted; the
  > renderer holds nothing the model does not (I14).

- § W1 — Open the map (`:64-69`):
  > **Pre:** bundles loaded (platform); `StudentState` read. **Steps:** 1. Build `MapViewModel` (Tier 0, in
  > `Core`). 2. Render **trail first (D44)**: the camera frames the trail's current unit — the marker's unit
  > and the next — with the continent visible around it; zooming out reveals regions, horizon and the whole
  > trail; node names appear at the zoom threshold (Q4). 3. The position indicator is the first uncleared trail
  > node at or after the marker. **Post:** `map.opened` emitted.

- § W3 — Tap a region (`:79-81`):
  > **Pre:** map open. **Steps:** open the **region panel**: name, the one-sentence description, fraction
  > cleared (Q2), and the trails that cross it. A `horizon` region is not tappable. **Post:** `map.region_opened`.

  Binds this task's region rendering (§4 step 5): a horizon region is drawn greyed and never registers a tap.

- § W6 — Reflect state changes (`:97-100`):
  > **Pre:** expedition or diagnosis emitted a transition (`expedition.node_cleared`, `diagnosis.node_blocked`,
  > `expedition.node_due`). **Steps:** re-derive `MapViewModel`; lift fog, place a blocked marker or a due
  > ring, re-tint the region; a basic transition only — no animated mechanics (D24). **Post:** rendered.

Tech-stack rules (verbatim, `docs/tech-stack.md`, byte-verified this session):

- § 1, row "UI":
  > **SwiftUI**; map on **`Canvas`**; first-party **SpriteKit** only if a few-hundred-node map demands it (D24/D32)

- § 1, row "App project":
  > Agents add files under `App/Sources` and `Packages/Core` **without editing the pbxproj**; no XcodeGen/Tuist

Arbitration ruling (verbatim, `tasks/arbitration/arbiter-03-predispatch.md` § Q-F, "The boundary, precisely",
byte-verified this session):

> `App/Sources` holds only what needs SwiftUI/UIKit or the OS environment:
> - views, `Canvas` drawing, and mapping bundle coordinates to screen through the ephemeral pan/zoom transform;
> - gesture handling and sheet-presentation flags;
> - one `@Observable` holder that stores the current `Core` session value and **replaces** it with each façade
>   result, never deriving from it;
> - resolving the Application Support URL and the embedded-snapshot URL, and reading the device calendar into a
>   `CalendarDay` (via its public `init?(iso:)`);
> - handing a `source_url` / `official_url` to the system, and showing a `student` code's registered `user_text`.
>
> The App must not construct a `StudentState`, call `MarkerTrail`, `Expedition`, `MasteryTransitions` or L0
> directly, branch on a `CoreError` to decide visibility, or read `data/`. The brief's new `App/Sources` source
> scan (§ 3 I14 line) enforces this, with a planted negative control.

Plan scope for the guard this task's output must pass (verbatim, `docs/plans/epic-03-plan.md` § 03.9 task
scope, byte-verified this session):

> **03.9:** a Core test scanning `App/Sources` for violations of I14, I5, I1/I10 and D24:
> - no `StudentState(`;
> - no direct Core transitions outside 03.7's allow-list;
> - no reads of `data/` paths;
> - no `URLSession` or `URLRequest`;
> - no FoundationModels or third-party engines;
> - no free-text answer, OCR or item-check path.
>
> It has a planted-violation negative control per class. An empty scan fails.

`MapViewModel`'s public API this task renders (verbatim, `tasks/epic-03-task-06-map-view-model.md` §2/§4,
re-verified against that spec's file text in this session — task 03.6 has not yet landed in the current tree;
these are the signatures 03.6 is specified to ship, and this task builds against them):

```swift
public struct MapViewModel: Equatable {
    public let regions: [RegionView]
    public let nodes: [NodeView]
    public let rivers: [River]
    public let trailSegments: [TrailSegmentView]
    public let positionIndicatorNodeId: String?
    public let landmarks: [LandmarkView]
    public let focusFrame: FocusFrame
    public func labelSet(atZoom zoomScale: Double) -> LabelSet
    public static let nodeNameZoomThreshold: Double = 3.0
}
public struct RegionView: Equatable {
    public let id: RegionId
    public let horizon: Bool
    public let clearedFraction: Double?   // nil = pure fog (map Q2/Q3)
}
public enum NodeAction: Equatable { case checkHere, include }
public struct NodeView: Equatable {
    public let id: String
    public let regionId: RegionId
    public let position: Point
    public let fogLevel: Mastery          // fog / cleared / blocked
    public let due: Bool
    public let upstream: Bool
    public let action: NodeAction?        // nil = no action offered
}
public struct River: Equatable { public let from: String; public let to: String }
public struct TrailSegmentView: Equatable {
    public let courseCode: String?
    public let nodeIds: [String]
    public let dashed: Bool
}
public struct LandmarkView: Equatable {
    public let id: String
    public let position: Point
    public let nodeIds: [String]
}
public struct FocusFrame: Equatable {
    public let minX: Double
    public let minY: Double
    public let maxX: Double
    public let maxY: Double
}
public struct LabelSet: Equatable {
    public let regionNames: Bool
    public let nodeNames: Bool
    public let landmarkNames: Bool
}
```
Note (carried forward from the 03.6 spec, `[ESTIMATE]`-tagged there): `nodeNameZoomThreshold = 3.0` is "the
zoom multiple, relative to a whole-continent overview of 1.0" — i.e. `MapCamera.zoomScale == 1.0` must mean
"the whole `[0,1]×[0,1]` bundle coordinate space exactly fills the canvas" for this task's `zoomScale` to be
the same unit `labelSet(atZoom:)` expects (§4 step 3).

Supporting types this task's code reads but does not redeclare (verbatim, `Packages/Core/Sources/Core/Model/
Ids.swift:4`, quoted by the 03.6 spec and re-verified there this session):
```swift
public struct Point: Codable, Equatable { public let x: Double; public let y: Double }
```
`Ids.swift`'s own doc comment (quoted by the 03.6 spec, `tasks/epic-03-task-06-map-view-model.md:946`): "A
normalised map coordinate in `[0, 1]` on each axis" — the bundle coordinate space every `Point` and
`FocusFrame` value lives in.

## §4 Implementation outline

1. **Layer.** Both files are layer ④ interaction's render layer (Door C), `App/Sources`. They read one input —
   a `MapViewModel` value, already fully derived in `Core` — and produce pixels plus one outgoing tap-to-id
   callback; they write nothing, call nothing in `Core` beyond the `MapViewModel` value's own read-only methods
   (`labelSet(atZoom:)`), and hold no state beyond the ephemeral camera.

2. **`MapCamera` (`MapCamera.swift`).** A value type holding the ephemeral pan/zoom transform and the
   coordinate mapping between bundle space (`[0,1]×[0,1]`, per `Point`'s doc comment, §3) and screen space:
   ```swift
   struct MapCamera: Equatable {
       var pan: CGSize
       var zoomScale: Double

       // [ESTIMATE: bounds on how far the student can zoom in/out; tunable during simulator review, D29/C3]
       static let minZoomScale: Double = 0.5
       static let maxZoomScale: Double = 8.0

       static func initial(focusFrame: FocusFrame, canvasSize: CGSize) -> MapCamera { /* step 4 below */ }
       func screenPoint(for bundlePoint: Point, canvasSize: CGSize) -> CGPoint { /* forward transform */ }
       func bundlePoint(for screenPoint: CGPoint, canvasSize: CGSize) -> Point { /* inverse transform */ }
   }
   ```
   The forward transform: `scale = zoomScale * min(canvasSize.width, canvasSize.height)`; the `[0,1]×[0,1]`
   square is centred in `canvasSize` at `zoomScale == 1.0` (`origin = ((canvasSize.width - scale)/2,
   (canvasSize.height - scale)/2)`); `screenPoint = origin + (bundlePoint.x, bundlePoint.y) * scale + pan`. The
   inverse transform undoes exactly that arithmetic. No other file in the module defines a second bundle-to-
   screen transform (I14 single-source within this task's own two files).

3. **`zoomScale` unit.** `MapCamera.zoomScale` is the same "relative to a whole-continent overview of 1.0" unit
   `MapViewModel.nodeNameZoomThreshold` uses (§3). Every call this task makes to `mapViewModel.labelSet
   (atZoom:)` passes `camera.zoomScale` directly — never a converted, inverted or independently-scaled value.

4. **Initial camera — trail-first framing (D44, AC4).**
   ```swift
   extension MapCamera {
       static func initial(focusFrame: FocusFrame, canvasSize: CGSize) -> MapCamera {
           let frameWidth = max(focusFrame.maxX - focusFrame.minX, 0.0001)
           let frameHeight = max(focusFrame.maxY - focusFrame.minY, 0.0001)
           // [ESTIMATE: the margin that keeps "the continent visible around it" (map W1 step 2); tunable]
           let paddingMultiplier = 3.0
           let targetSpan = min(1.0, max(frameWidth, frameHeight) * paddingMultiplier)
           let zoomScale = min(maxZoomScale, max(minZoomScale, 1.0 / targetSpan))
           let centerX = (focusFrame.minX + focusFrame.maxX) / 2
           let centerY = (focusFrame.minY + focusFrame.maxY) / 2
           // pan is chosen so (centerX, centerY) maps to the canvas's own centre at this zoomScale
       }
   }
   ```
   `MapCanvasView` calls this exactly once per appearance of a *newly opened* map (§4 step 8), from
   `mapViewModel.focusFrame` and the canvas's measured `GeometryReader` size, and never again resets the
   camera on a later `mapViewModel` value the view is re-initialized with (AC4) — panning/zooming already done
   by the student is the view's only persistent state, and W6 re-derivations must not fight it.

5. **`MapCanvasView` (`MapCanvasView.swift`) — shape.**
   ```swift
   struct MapCanvasView: View {
       let mapViewModel: MapViewModel
       let onNodeTap: (String) -> Void

       @State private var camera = MapCamera(pan: .zero, zoomScale: 1.0)
       @State private var hasFramedInitialCamera = false

       var body: some View {
           GeometryReader { geometry in
               Canvas { context, size in
                   draw(mapViewModel: mapViewModel, camera: camera, canvasSize: size, into: &context)
               }
               .gesture(panGesture(canvasSize: geometry.size))
               .gesture(zoomGesture)
               .onTapGesture { location in handleTap(at: location, canvasSize: geometry.size) }
               .onAppear {
                   guard !hasFramedInitialCamera else { return }
                   camera = MapCamera.initial(focusFrame: mapViewModel.focusFrame, canvasSize: geometry.size)
                   hasFramedInitialCamera = true
               }
           }
       }
   }
   ```
   `draw`, `panGesture`, `zoomGesture` and `handleTap` are private helpers on `MapCanvasView`; none of them
   introduces a stored property beyond `camera`/`hasFramedInitialCamera` (AC1).

6. **Drawing — the presentation index.** Because `NodeView`/`River`/`TrailSegmentView`/`RegionView` carry only
   ids, not the display names or the polygon geometry the bundle's own `Node`/`Region`/`Landmark` types carry
   (§6 decision default), `draw` builds one local, non-persisted lookup —
   `let nodesById = Dictionary(uniqueKeysWithValues: mapViewModel.nodes.map { ($0.id, $0) })` — purely to
   resolve a `River.from`/`River.to`, a `TrailSegmentView.nodeIds` entry, or a region's member-node set to a
   screen position via `NodeView.position`. Building this dictionary is a presentation-only index over values
   `MapViewModel` already computed; it derives no new fog/due/trail/action fact (I14).

7. **Drawing — per element (order back-to-front: regions, rivers, trail segments, nodes, position indicator,
   landmarks, horizon labels):**
   - **Regions.** For each `RegionView` with `horizon == false`: compute the bounding box of every `NodeView`
     in `mapViewModel.nodes` whose `regionId == region.id` (via `nodesById`, step 6); draw that box (or a
     shape derived from it) filled at an opacity/tint from `region.clearedFraction` (`nil` → pure fog grey, per
     map Q2/Q3); draw the region name only when `labelSet(atZoom: camera.zoomScale).regionNames == true`, using
     `region.id.rawValue` as the label text (§6 decision default — `RegionView` carries no `name` field). A
     region with no member `NodeView`s (its bounding box is empty) is drawn as pure fog with no shape, per the
     same rule `MapViewModel` already applied to give it `clearedFraction == nil`.
   - **Horizon regions.** `RegionView`s with `horizon == true` are drawn as a greyed label list at a fixed
     position along one screen edge (they carry no coordinate — §6 decision default), non-tappable (§3, map §
     W3: "A `horizon` region is not tappable"), shown whenever `labelSet(...).regionNames == true`.
   - **Rivers.** For each `River`, a line from `nodesById[river.from]?.position` to `nodesById[river.to]?
     .position` (via `camera.screenPoint(for:canvasSize:)`); a river whose endpoint id is missing from
     `nodesById` draws nothing for that entry (defensive; §6 decision default).
   - **Trail segments.** For each `TrailSegmentView`, a polyline through `nodeIds`' resolved positions;
     `dashed == true` uses a dashed `StrokeStyle` (`[ESTIMATE]`-tagged dash pattern, e.g. `dash: [6, 4]`),
     `dashed == false` a solid stroke.
   - **Nodes.** For each `NodeView`, a circle at its screen position; fill/stroke varies by `fogLevel`
     (`.fog`/`.blocked`/`.cleared`, per the glossary's Fog entry, §3) and `due` (a ring drawn only when `due ==
     true`, and only ever on a `.cleared` node, per `MapViewModel`'s own AC3 — this view draws the ring exactly
     when `due == true`, never re-deriving that condition); the node name is drawn only when `labelSet
     (...).nodeNames == true`, using `node.id` as the label text (§6 decision default).
   - **Position indicator.** When `mapViewModel.positionIndicatorNodeId` is non-`nil` and resolves via
     `nodesById`, draw a distinct marker at that node's position (never the word "cursor" or "start marker" —
     glossary, §3).
   - **Landmarks.** For each `LandmarkView`, a marker at `landmark.position`; the name is drawn only when
     `labelSet(...).landmarkNames == true` — which `MapViewModel.labelSet` always returns `true` for (per the
     03.6 spec's AC7) — using `landmark.id` as the label text (§6 decision default).

8. **Tap resolution (AC5).** `handleTap(at: CGPoint, canvasSize: CGSize)` converts the tap location to bundle
   space via `camera.bundlePoint(for:canvasSize:)`, then finds the `NodeView` in `mapViewModel.nodes` whose
   `position` is closest to that bundle point, computing distance in *screen* space (convert both points back
   through `camera.screenPoint(for:canvasSize:)` and compare) so the hit radius is a fixed screen size
   regardless of zoom:
   ```swift
   // [ESTIMATE: half of Apple's ~44 pt minimum tap target (map Q4's own estimate), tunable]
   private static let nodeTapRadius: CGFloat = 22
   ```
   If the nearest node's screen distance is `<= nodeTapRadius`, call `onNodeTap(nearestNode.id)`; otherwise
   call nothing (AC5). This task resolves node taps only — no region or landmark tap callback ships here (§6
   decision default).

9. **Basic transitions only (D24, AC8).** Where the view distinguishes a changed `mapViewModel` value from the
   previous one (e.g. via `.animation(.easeInOut, value: mapViewModel)` on the `Canvas`, or an equivalent
   single modifier), the effect is a basic cross-fade/interpolation SwiftUI already provides — never a custom
   `SpriteKit` scene, timer-driven mechanic, particle effect or game-style animation loop. No `import
   SpriteKit` appears in either file.

10. **No boundary schema, no error codes, no storage.** Neither file validates external input (its one input,
    `MapViewModel`, is an already-valid `Equatable` value from `Core`), throws or catches a `CoreError`, or
    performs any file/network I/O. This step exists to record the absence explicitly, per the outline template.

11. **Smoke check**: `xcodebuild build -scheme mathmath -destination "$(scripts/pick-simulator.sh)"` — must be
    green, with both new files compiled into the `mathmath` target via the synchronized `Sources` group (no
    `pbxproj` edit, §3).

## §5 Test plan

This is a `mechanical` spec (renders a value type defined and fully specified elsewhere — `MapViewModel`,
03.6 — through a `Canvas`; it touches no contract, no registry, no persisted data, and computes no
time-sensitive or domain state of its own; every visibility/fog/due/action/label decision is read, never
computed, from the `MapViewModel` value it is handed). Per §5's risk-tier rule, only T1–T3 are listed.

**C3 note (owner-verified, no agent claim of pixel-level correctness).** `App/mathmath.xcodeproj` has no App
unit-test target (arbiter-03 § Q-F: "CONFIRMED, consistent with I14 and D33." … "No App test target is needed.");
SwiftUI `Canvas` drawing and gesture behaviour cannot be asserted by a `Core` test. Per
`docs/epics/epic-03-app-map-shell.md` § 9 Q-F and `docs/plans/epic-03-plan.md` § "Planner notes kept for spec
writers" ("With no App test target, the render side of the C1 seam is evidenced only by the App build, the 03.9
scan and the simulator smoke" — citation corrected by the orchestrator after review), this
task's test plan is the App build, the lint gate, and the 03.9 structural scan. **Visual correctness — pixel
placement, camera feel, drawing fidelity — is the owner's Demo-wrap check (D29); no test in this task, and no
claim in its acceptance report, asserts screenshot-level correctness.**

- T1 smoke fidelity: `xcodebuild build -scheme mathmath` on the simulator (gate 4) succeeds with
  `App/Sources/Map/MapCanvasView.swift` and `App/Sources/Map/MapCamera.swift` compiled into the target;
  `swift-format lint --strict` over both files is clean. This is the happy-path smoke the implementer ships,
  standing in for a unit test given the C3 exclusion above.
- T2 negative — invalid input rejected at the boundary: not applicable in the throwing/validation sense —
  `MapCanvasView` receives an already-valid `MapViewModel` `Equatable` value with no failure mode of its own
  and performs no boundary validation (§4 step 10). The negative check this task's new code must survive is
  the 03.9 source scan's own planted-violation classes (owned by task 03.9): running that scan (already green
  before this task, per its own spec) over the tree with this task's two files added must **stay** green — no
  `StudentState(` construction, no direct `Core` transition call outside 03.7's façade allow-list, no `data/`
  read, no `URLSession`/`URLRequest`, no `FoundationModels`/third-party-engine import appears in either new
  file. This is verified by re-running the 03.9 scan (`xcodebuild test -scheme Core-Package`, its test target)
  after this task's files exist.
- T3 error-taxonomy: not applicable — this task raises no `CoreError` and shows no registry `user_text`
  (registry-code display is task 03.11/03.12's concern, over the façade's message list). Documented here per
  the risk-tier template rather than omitted silently.

## §6 Decision defaults

- IF `MapViewModel`'s `RegionView`/`NodeView`/`LandmarkView` carry no display-name field (verified: their
  fields, quoted in §3, are `id`/`regionId`/`horizon`/`clearedFraction`/`position`/`fogLevel`/`due`/`upstream`/
  `action`/`nodeIds` only — no `name` anywhere) THEN the label text this task draws for a region, node or
  landmark is the raw id (`region.id.rawValue`, `node.id`, `landmark.id`) — never a name looked up in the
  bundle or elsewhere, because `MapCanvasView` receives no `ContentBundle` and must not re-derive display data
  outside `Core` (I14, arbiter-03 § Q-F's boundary, §3). A later task may extend `MapViewModel` with a display
  name if the owner's Demo review finds raw ids unacceptable; that is a 03.6-spec change, out of this task's
  scope.
- IF `RegionView` carries no polygon/position (verified against its fields, §3) THEN a content region's drawn
  shape is the bounding box of its member `NodeView`s' `position`s (resolved via the `regionId` field every
  `NodeView` already carries, §4 step 6) — a presentation-only computation over already-derived values, not a
  domain derivation; an empty member set (no bundle nodes in that region, or a horizon region) draws no shape,
  consistent with `MapViewModel` having already given it `clearedFraction == nil`.
- IF the context bundle's own scope statement for this task (§A: "Tap events yield the node id the model
  placed at that coordinate"; §F: no mention of a region- or landmark-tap callback) is read against map §
  W3/W4's region/landmark panels (§3) THEN this task ships exactly one tap callback, `onNodeTap: (String) ->
  Void`, and region/landmark tap resolution is out of this task's scope — a later task (03.11, which owns the
  region/landmark panels) adds that callback surface to `MapCanvasView` if it needs it, since this task's file
  scope is fixed to the two files named in §2 and the compiled context bundle scoped this task to node taps
  only.
- IF a `River`'s `from`/`to` id, or a `TrailSegmentView`'s `nodeIds` entry, is absent from
  `mapViewModel.nodes` (a defensive case `MapViewModel`'s own ACs do not claim can occur, since every id in
  those arrays is drawn from the same bundle `derive` walks) THEN that entry draws nothing rather than
  crashing — a `Canvas` draw closure has no throwing path, and `MapCanvasView` must never force-unwrap a
  dictionary lookup.
- IF the map Q4 tap-target/zoom-bound constants (`nodeTapRadius`, `minZoomScale`/`maxZoomScale`, the initial-
  camera padding multiplier, the dash pattern) have no first-principles derivation available at this layer
  THEN each is a single `[ESTIMATE]`-tagged constant (§4 steps 2, 4, 8), left for the implementer/owner to tune
  during simulator review (D29) — consistent with the precedent set by `MapViewModel.nodeNameZoomThreshold`
  (`tasks/epic-03-task-06-map-view-model.md` §4 step 7, quoted in §3).
- IF `MapCanvasView` needs to distinguish "the map was just opened" (frame the camera) from "the map's state
  was re-derived while already open" (do not reset the camera) THEN use a single `Bool` `@State` flag
  (`hasFramedInitialCamera`, §4 step 5/AC4) rather than comparing `focusFrame` values — comparing values would
  re-frame the camera on every legitimate W6 re-derivation whose `focusFrame` happens to differ (e.g. after a
  marker move on a different unit), which is not this task's job to decide (that is a full map-reopen versus
  a live update, a distinction 03.12's shell owns, not this canvas view).
- Standing defaults: identifiers and timestamps are untouched by this task (`MapCanvasView`/`MapCamera`
  persist nothing); no model call anywhere (Tier 0 only, I2); no telemetry client in this task; no identifying
  field is introduced (the view holds only node/region/landmark ids already cleared by `MapViewModel`, plus
  `Double`/`Bool`/`CGFloat`/`CGSize` presentation data); glossary terms only, banned synonyms never appear in
  new identifiers or on-screen text (§3).

## §7 Done definition

The task is done when ALL gates pass:

- format + lint clean (`swift-format lint --strict` over `App/Sources/Map/MapCanvasView.swift` and
  `App/Sources/Map/MapCamera.swift`).
- typecheck clean (Swift's typecheck is the build).
- App build green (`xcodebuild build -scheme mathmath` on the simulator, gate 4) with both files compiled into
  the target via the synchronized `Sources` group.
- the task 03.9 source scan (`xcodebuild test -scheme Core-Package`, its test target) stays green with this
  task's two files added to `App/Sources` — no planted-violation class of 03.9's scan fires against either new
  file.
- tests green for the cases in §5 (T1–T3, with T2/T3 documented as not applicable per the mechanical
  risk-tier template).
- conforms to every contract section cited in §3 and to every invariant listed in §1.
- the C3 exclusion (§5) is honoured: no claim of screenshot-level or pixel-level verification appears in this
  task's acceptance report; visual correctness is the owner's Demo-wrap check (D29).
