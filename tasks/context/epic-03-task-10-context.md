# Task 03.10 context bundle

> Compiler: task-context-compiler  
> Date: 2026-09-10  
> Slug: app-map-canvas  
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- Epic: 03
- Task: 10
- Slug: app-map-canvas
- Sub-EPIC: 03b
- Summary: Implement a SwiftUI `Canvas` map in `App/Sources/Map/` (`MapCanvasView.swift`, `MapCamera.swift`) that renders a `MapViewModel` value produced by task 03.6. The canvas draws regions with tint, rivers, fog/blocked/cleared nodes, due ring, trail solid/dashed segments, position indicator, and landmarks. The only view state is the ephemeral pan/zoom transform. Initial camera comes from the model's focus frame (trail-first, D44). The task asks `Core` for the zoom-dependent label set. Tap events yield the node id the model placed at that coordinate. Transitions are basic only — no animated mechanics (D24). No SpriteKit.
- Invariants in play: **I2** (Tier 0 — no model calls in rendering, pure state received); **I14** (`Core` renderer-free — `MapViewModel` imports Foundation only, `App/Sources` computes no state); **D24** (no third-party game engine, first-party SpriteKit only if `Canvas` performance demands).

## §B. Applicable contract rules (verbatim)

### contracts/interaction-contract.md — § 2. Expedition — compose formula (fringe rule, D48)

> - `compose` (D48, D45, D46, v2.7 §3): fringe = `{n : mastery(n) ≠ cleared ∧ ∀ p ∈ prereq(n): mastery(p) = cleared ∨ (mastery(p) = blocked ∧ remediated(p))}` ∩ (nodes of `marker.unit ∪ next(marker.unit)`, or the requested unit only) ∪ `{n : mastery(n) = blocked}`. Slots = up to 5: map-queued node first (map Q5, if on the fringe), then fringe nodes in trail order, then due cleared nodes (`next_due ≤ today`, oldest `last_probe` first), **≤ 2 review slots** (expedition Q3). Empty → `EXP_NO_FRINGE`.

Source: `contracts/interaction-contract.md:32-36`  
Binds this task: The fringe membership determines which fog nodes offer the `.include` action. `MapViewModel` (03.6) calls `Expedition.fringeNodeIds` directly (§B rule 2) — this task receives those computed values and renders them without re-computing.

### contracts/interaction-contract.md — § 3. Marker and trail — node upstream rule

> - `set_marker(course, unit)` → regenerate trail → recompute fringe. Marker default = first unit of the selected course. Nodes upstream of the marker keep their mastery. The marker is past the course's last unit iff `marker.past_last_unit == true`, whichever unit `unit_id` names; setting it writes the course's last unit as `unit_id`. While past the last unit, the `marker.unit ∪ next(marker.unit)` window of §2 `compose` is the nodes of the `extension` segment (empty when there is none). Nodes of the course are then upstream of the marker. A marker whose `course_code` is not in `syllabi[]`, or whose `unit_id` is not a unit of that course in the bundle, is off the trail (`MAP_MARKER_OFF_TRAIL`, default marker) regardless of `past_last_unit`.

Source: `contracts/interaction-contract.md:62-71`  
Binds this task: `MapViewModel.NodeView.upstream` is set by 03.6 and rendered by this task. Upstream nodes are reachable and can be tapped.

### contracts/domain-glossary.md — Map and graph (Door C) — glossary terms

> - **Region** — one of the ten D21 territories (`region_id` fixed enum, `data-model.md`). *Banned:* "area", "zone", "strand".
> - **Fog** — the rendering of an uncleared node. Mastery states: **fog · cleared · blocked** (`data-model.md`). *Banned:* "locked", "unknown" (as a state), "mastered".
> - **Due** — a cleared node whose `next_due` has passed; drawn with a *due ring*. Not a mastery state.
> - **Trail** — the student's one generated path over the graph (D47): **segments** that are either a **course segment** (`course_code`) or an **extension** (dashed). *Banned:* "path", "route", "track", "course trail" (a course is not a trail).
> - **Course-progress marker** ("we are here in class") — the student's chosen current unit (D45). Short form in code: `marker`. *Banned:* "start marker" (v2.1 D28 name), "position", "cursor".
> - **Position indicator** — the first uncleared trail node at or after the marker (display only).
> - **Landmark** — a real, named, sourced thing linked to nodes (D22). *Banned:* "application", "example", "story".

Source: `contracts/domain-glossary.md:9-26`  
Binds this task: Every identifier, label and doc comment uses these terms; banned synonyms never appear in identifiers or code.

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/map.md — § Core entities — MapViewModel

> **MapViewModel** — the pure derivation rendered each frame: regions with a tint from the fraction of their nodes cleared (Q2), rivers, trails with marker and position indicator, landmarks, horizon labels, and the label set for the current zoom (Q4). Derived in `Core` from bundles + `StudentState`; never persisted; the renderer holds nothing the model does not (I14).

Source: `docs/domains/map.md:54-57`

### docs/domains/map.md — § Core entities — NodeView

> **NodeView** — a node as drawn: its coordinates (from the bundle, D42), its region, its mastery state from `StudentState` (**expedition**) projected to a fog level — `fog` (full), `blocked` (fog with a marker), `cleared` (lifted), plus a `due` ring when spaced repetition has come round (Q1) — and whether it lies upstream of the current trail's marker.

Source: `docs/domains/map.md:49-52`

### docs/domains/map.md — § W1 — Open the map

> **Pre:** bundles loaded (platform); `StudentState` read. **Steps:** 1. Build `MapViewModel` (Tier 0, in `Core`). 2. Render **trail first (D44)**: the camera frames the trail's current unit — the marker's unit and the next — with the continent visible around it; zooming out reveals regions, horizon and the whole trail; node names appear at the zoom threshold (Q4). 3. The position indicator is the first uncleared trail node at or after the marker. **Post:** `map.opened` emitted.

Source: `docs/domains/map.md:64-69`

### docs/domains/map.md — § W6 — Reflect state changes

> **Pre:** expedition or diagnosis emitted a transition (`expedition.node_cleared`, `diagnosis.node_blocked`, `expedition.node_due`). **Steps:** re-derive `MapViewModel`; lift fog, place a blocked marker or a due ring, re-tint the region; a basic transition only — no animated mechanics (D24). **Post:** rendered.

Source: `docs/domains/map.md:97-100`

### docs/domains/map.md — § UI surfaces

> Native screens (iOS; names, not routes): **Map** (W1, W5, W6); **Node panel**, **Region panel**, **Landmark panel** (W2–W4) as sheets over the map. The map is the app's home screen; expedition and diagnosis are entered from it. Confirmed by the Demo (v2.2 §D: the Demo is the Phase 4 artifact for Doors B and C).

Source: `docs/domains/map.md:102-107`

### docs/domains/map.md — § Q3 — What the horizon shows

> **Q3 — What the horizon shows.** **Default:** the D21 (revised) labels only — Analysis, Topology, Number Theory, Abstract Algebra — greyed, not tappable, no content. **Ratified 2026-09-09:** default accepted.

Source: `docs/domains/map.md:160-163`

### docs/domains/map.md — § Q4 — Label zoom thresholds

> **Q4 — Label zoom thresholds.** **Default:** region names at overview; node names when a node's drawn diameter exceeds a fixed on-screen size [ESTIMATE: ~44 pt, Apple's minimum tap target]; landmark names always. **Ratified 2026-09-09:** default accepted.

Source: `docs/domains/map.md:165-168`

## §D. Prior task outputs this task depends on

Exported types from task 03.6 (`MapViewModel` public API, re-verified 2026-09-10 against the full spec):

- `MapViewModel` — `public struct MapViewModel: Equatable { public let regions: [RegionView]; public let nodes: [NodeView]; public let rivers: [River]; public let trailSegments: [TrailSegmentView]; public let positionIndicatorNodeId: String?; public let landmarks: [LandmarkView]; public let focusFrame: FocusFrame }`  
  Source: `tasks/epic-03-task-06-map-view-model.md:682-690`

- `MapViewModel.derive(bundle:state:today:)` — `public static func derive(bundle: ContentBundle, state: StudentState, today: CalendarDay) -> MapViewModel`  
  Source: `tasks/epic-03-task-06-map-view-model.md:730-733`

- `MapViewModel.labelSet(atZoom:)` — `public func labelSet(atZoom zoomScale: Double) -> LabelSet`  
  Source: `tasks/epic-03-task-06-map-view-model.md:798-801`

- `RegionView` — `public struct RegionView: Equatable { public let id: RegionId; public let horizon: Bool; public let clearedFraction: Double? }`  
  Source: `tasks/epic-03-task-06-map-view-model.md:691-695`

- `NodeView` — `public struct NodeView: Equatable { public let id: String; public let regionId: RegionId; public let position: Point; public let fogLevel: Mastery; public let due: Bool; public let upstream: Bool; public let action: NodeAction? }`  
  Source: `tasks/epic-03-task-06-map-view-model.md:697-705`

- `NodeAction` — `public enum NodeAction: Equatable { case checkHere, include }`  
  Source: `tasks/epic-03-task-06-map-view-model.md:696`

- `River` — `public struct River: Equatable { public let from: String; public let to: String }`  
  Source: `tasks/epic-03-task-06-map-view-model.md:706`

- `TrailSegmentView` — `public struct TrailSegmentView: Equatable { public let courseCode: String?; public let nodeIds: [String]; public let dashed: Bool }`  
  Source: `tasks/epic-03-task-06-map-view-model.md:707-711`

- `LandmarkView` — `public struct LandmarkView: Equatable { public let id: String; public let position: Point; public let nodeIds: [String] }`  
  Source: `tasks/epic-03-task-06-map-view-model.md:712-716`

- `FocusFrame` — `public struct FocusFrame: Equatable { public let minX: Double; public let minY: Double; public let maxX: Double; public let maxY: Double }`  
  Source: `tasks/epic-03-task-06-map-view-model.md:717-722`

- `LabelSet` — `public struct LabelSet: Equatable { public let regionNames: Bool; public let nodeNames: Bool; public let landmarkNames: Bool }`  
  Source: `tasks/epic-03-task-06-map-view-model.md:723-727`

- `Point` — `public struct Point: Codable, Equatable { public let x: Double; public let y: Double }`  
  Source: `tasks/epic-03-task-06-map-view-model.md:431` (from `Packages/Core/Sources/Core/Model/Ids.swift`)

- `RegionId` — `public enum RegionId: String, Codable, CaseIterable { case numberOperations = "number-operations"; case algebra = "algebra"; … }`  
  Source: `tasks/epic-03-task-06-map-view-model.md:432-448` (from `Packages/Core/Sources/Core/Model/Ids.swift`)

- `Mastery` — `public enum Mastery: String, Codable { case fog; case cleared; case blocked }`  
  Source: `tasks/epic-03-task-06-map-view-model.md:324` (from the spec's prior-outputs section, `Packages/Core/Sources/Core/Model/StudentState.swift`)

## §E. Negative facts (confirmed ABSENT)

- `App/Sources/Map/` directory does not exist. Glob `App/Sources/Map/**` returned no matches.
- `App/Sources/Map/MapCanvasView.swift` does not exist. Glob `App/Sources/Map/**` and `App/Sources/**/*.swift` confirm absence.
- `App/Sources/Map/MapCamera.swift` does not exist. Glob `App/Sources/Map/**` confirm absence.
- The plan § 03.9 (`app-sources-i14-scan`) spec has not been written yet, so the constraints it documents (no `StudentState(`, no direct Core transitions outside 03.7's allow-list, no `data/` reads, no `URLSession`) are noted here but not yet binding — the 03.9 spec will enforce them.
- No `MapCanvasView` or `MapCamera` types exist in the current codebase. Grep `Map` over `App/Sources` returned only the task spec path, not any implementation.

## §F. File scope

Files this task may create or touch. All files are in the synchronized `App/Sources` folder (no `pbxproj` edits per `docs/tech-stack.md` § 1):

- CREATE `App/Sources/Map/MapCanvasView.swift` — confirmed absent (§E). Holds the primary `MapCanvasView` (a SwiftUI view rendering `MapViewModel` on a `Canvas`), pan/zoom gesture handling, and the coordinate mapping from bundle space to screen space. The only state in this file is the ephemeral pan/zoom transform (e.g., `@State var pan: CGSize`, `@State var zoomScale: Double`).
- CREATE `App/Sources/Map/MapCamera.swift` — confirmed absent (§E). Holds `MapCamera` (the pan/zoom state and the initial-camera logic that frames the focus frame from the model). Extracted to a separate file for clarity; re-exported from `MapCanvasView` if needed by tests or other views.

## §G. Stack constraints relevant here

### Tech stack locked rules (verbatim from docs/tech-stack.md)

> | Slot | Choice | Version / pin |  
> |---|---|---|  
> | UI | **SwiftUI**; map on **`Canvas`**; first-party **SpriteKit** only if a few-hundred-node map demands it (D24/D32) | OS frameworks |

Source: `docs/tech-stack.md:15`

> Agents add files under `App/Sources` and `Packages/Core` **without editing the pbxproj**; no XcodeGen/Tuist

Source: `docs/tech-stack.md:24`

### Rendering layer constraints (I14, D24, D33)

- **No state computation:** `MapCanvasView` receives a `MapViewModel` value from the caller (via 03.7's façade, mediated by App-layer `@Observable` holder — see arbiter ruling Q-F); it never constructs, mutates, or re-derives state. Every model value is received immutably.
- **No model calls, no Tier 1 inference:** rendering layer invokes no Foundation Models, no `@Generable`, no async model APIs. `MapViewModel` (03.6) is pure and in `Core`; this task only renders it.
- **No data I/O:** no `URLSession`, no `FileManager`, no `data/` reads. Bundle and state are read-only inputs from the caller.
- **Coordinate space:** `MapViewModel` positions and the focus frame use bundle coordinate space (`Double` values, 0–1 or similar unit range). `MapCanvasView` maps these to screen coordinates via the pan/zoom transform, which is ephemeral and never persisted.

### Deployment target and rendering constraints

- **iOS/iPadOS 18.0** minimum (`IPHONEOS_DEPLOYMENT_TARGET = 18.0` per `docs/tech-stack.md` row "Deployment target").
- **SwiftUI Canvas only.** `Canvas` is available on iOS 17+. If Canvas performance on a few-hundred-node map becomes a bottleneck during testing, first-party `SpriteKit` may be considered at that time (D24); a spec change is required before any `SpriteKit` import.

### Linting and formatting

- Swift code must pass `swift-format lint --strict` (docs/tech-stack.md § 3, gate 1).
- Code follows the existing codebase style in `App/Sources/ContentView.swift` and `App/Sources/MathmathApp.swift`.

### Zoom threshold constant

`MapViewModel.nodeNameZoomThreshold` is defined in 03.6 as `3.0` [ESTIMATE: placeholder, tunable by rendering task]. This task receives it and uses it in the `labelSet(atZoom:)` call. No hard-coded threshold in this task unless Q-F specifies otherwise.

### Arbitration ruling Q-F precision (Core/App boundary, §B rule 2)

The Core/App boundary (arbiter `arbiter-03-predispatch.md` § Q-F) specifies:
- `Core` holds `MapViewModel` derivation (pure structs, Foundation-only, Equatable, no rendering imports).
- `App/Sources` holds views, `Canvas` drawing, and gesture handling; maps bundle coordinates to screen through ephemeral pan/zoom.
- App must not construct a `StudentState`, call `MarkerTrail`, `Expedition`, `MasteryTransitions` or L0 directly, or branch on a `CoreError` to decide visibility (rendering layer never computes state).

Source: `tasks/arbitration/arbiter-03-predispatch.md:280-316`

### Glossary compliance (contract rule §B)

Every identifier, label, and doc comment in this task's code uses glossary terms from `contracts/domain-glossary.md` (quoted in §B); banned synonyms ("start marker", "cursor", "area", "zone", "session", "save") never appear.

## Final summary

This task implements the visual rendering of `MapViewModel` — the pure state produced by task 03.6 — in SwiftUI `Canvas`. It adds two files (`MapCanvasView.swift`, `MapCamera.swift`) to the synchronized `App/Sources/Map/` folder. The canvas draws regions, nodes (fog/blocked/cleared with due rings), rivers, trail segments (solid course, dashed extension), landmarks, position indicator, and horizon labels. Pan/zoom is the only ephemeral view state; initial camera frames the focus frame (trail-first, D44). Tap events yield node ids. Transitions are basic (no animation per D24). No model calls, no state computation, no I/O.
