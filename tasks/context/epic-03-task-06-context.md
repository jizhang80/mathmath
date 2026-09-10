# Task 03.6 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: map-view-model
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity
- Epic: 03
- Task: 06
- Slug: map-view-model
- Summary: `MapViewModel` in `Core` is a pure derivation from (bundle, StudentState, today). It carries region tints and pure-fog horizon regions; one river per edge; a `NodeView` per node with fog level, due ring, upstream flag and the single offered action; solid course segments and a dashed extension; the position indicator and the landmark; the zoom-dependent label set and the trail-first focus frame (D44). It does no layout, no I/O and no clock read. Tests cover I4's record half and a W6 re-derivation over real transitions, including a real confirmed diagnosis through 02.11's step-wise API.
- Invariants in play: **I1** (no model output decides step correctness), **I2** (Tier 0 only, deterministic fallback), **I3** (answers always shown), **I4** (record half: blocked nodes with "Check me here"), **I6** (no verbatim Ministry text), **I14** (Core imports Foundation only, render layer computes nothing), **I15** (landmarks have resolving source_url)

## §B. Applicable contract rules (verbatim)

### contracts/interaction-contract.md — § 2 Expedition — `compose` rule (revised v0.9.2)
> - `compose` (D48, D45, D46, v2.7 §3): fringe = `{n : mastery(n) ≠ cleared ∧ ∀ p ∈ prereq(n): mastery(p) = cleared ∨ (mastery(p) = blocked ∧ remediated(p))}` ∩ (nodes of `marker.unit ∪ next(marker.unit)`, or the requested unit only) ∪ `{n : mastery(n) = blocked}`. Slots = up to 5: map-queued node first (map Q5, if on the fringe), then fringe nodes in trail order, then due cleared nodes (`next_due ≤ today`, oldest `last_probe` first), **≤ 2 review slots** (expedition Q3). Empty → `EXP_NO_FRINGE`.

Source: `contracts/interaction-contract.md:32-36`
Binds this task: defines the fringe on which the position indicator is calculated; the view model's action-by-state relies on fringe membership.

### contracts/interaction-contract.md — § 3 Marker and trail (revised v0.9.2)
> - `set_marker(course, unit)` → regenerate trail → recompute fringe. Marker default = first unit of the selected course. Nodes upstream of the marker keep their mastery. The marker is past the course's last unit iff `marker.past_last_unit == true`, whichever unit `unit_id` names; setting it writes the course's last unit as `unit_id`. While past the last unit, the `marker.unit ∪ next(marker.unit)` window of §2 `compose` is the nodes of the `extension` segment (empty when there is none). Nodes of the course are then upstream of the marker. A marker whose `course_code` is not in `syllabi[]`, or whose `unit_id` is not a unit of that course in the bundle, is off the trail (`MAP_MARKER_OFF_TRAIL`, default marker) regardless of `past_last_unit`.
> - The marker is set only by choosing an entry from the selected course's unit list: one entry per unit in unit order, then a final "past the last unit" entry (`past_last_unit: true`). No gesture moves the marker; there is no drag and no snap. A unit-list choice is never off the trail.

Source: `contracts/interaction-contract.md:62-71` (first bullet, v0.9.1) and `tasks/arbitration/arbiter-03-predispatch.md` § Q-B lines 106-108 (marker-from-unit-list new bullet, v0.9.2)
Binds this task: `MapViewModel` flags nodes upstream of the marker; the view model derives from a `StudentState` whose marker is validated by this rule; the position indicator depends on understanding upstream.

### contracts/interaction-contract.md — § 1 Mastery per node — fog/cleared/blocked states
> States `fog → cleared`, `fog → blocked`, `blocked → cleared`, `cleared` stays `cleared` (map Q1: fog never returns). Transitions:
> | From | Event | Guard | To | Side effects |
> |---|---|---|---|---|
> | fog / blocked | `item_correct(node)` | `correct_count + 1 ≥ 2` on **distinct items** (expedition Q1) | cleared | `next_due = today + ladder[0]`, `ladder_rung = 0`, emit `node_cleared`, remove `remediated` |
> | cleared | `item_miss(node)` (review) | — | cleared | `ladder_rung = 0`, `next_due = today + ladder[0]`; tolerance per §2 |
> | fog | `diagnosis_blocked(node)` | — | blocked | emit `node_blocked` |

Source: `contracts/interaction-contract.md:13-24`
Binds this task: `MapViewModel.NodeView` fog level is derived from `StudentState.NodeState.mastery`; cleared nodes with `next_due ≤ today` are shown with a due ring; upstream nodes stay their mastery but are flagged.

### contracts/domain-glossary.md — Map and graph (Door C) § entries
> - **Map** — the concept graph rendered as one continent. *Banned:* "world", "board", "skill tree".
> - **Region** — one of the ten D21 territories (`region_id` fixed enum, `data-model.md`). *Banned:* "area", "zone", "strand".
> - **Horizon** — a named label beyond the continent with no content (Analysis, Topology, Number Theory, Abstract Algebra).
> - **Node** — one concept; the unit of mastery. *Banned:* "topic", "skill", "concept card".
> - **Edge** — "A is prerequisite of B", directed `from → to`. Rendered as a **river**. *Banned:* "link", "dependency" (in data), "arrow".
> - **Fog** — the rendering of an uncleared node. Mastery states: **fog · cleared · blocked** (`data-model.md`). *Banned:* "locked", "unknown" (as a state), "mastered".
> - **Due** — a cleared node whose `next_due` has passed; drawn with a *due ring*. Not a mastery state.
> - **Trail** — the student's one generated path over the graph (D47): **segments** that are either a **course segment** (`course_code`) or an **extension** (dashed). *Banned:* "path", "route", "track", "course trail" (a course is not a trail).
> - **Course-progress marker** ("we are here in class") — the student's chosen current unit (D45). Short form in code: `marker`. *Banned:* "start marker" (v2.1 D28 name), "position", "cursor".
> - **Position indicator** — the first uncleared trail node at or after the marker (display only).
> - **Landmark** — a real, named, sourced thing linked to nodes (D22). *Banned:* "application", "example", "story".

Source: `contracts/domain-glossary.md:9-26`
Binds this task: `MapViewModel` uses only these terms; identifiers in code must match the glossary entries; student copy uses glossary terms, not banned synonyms.

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/map.md — § Core entities — MapViewModel
> **MapViewModel** — the pure derivation rendered each frame: regions with a tint from the fraction of their nodes cleared (Q2), rivers, trails with marker and position indicator, landmarks, horizon labels, and the label set for the current zoom (Q4). Derived in `Core` from bundles + `StudentState`; never persisted; the renderer holds nothing the model does not (I14).

Source: `docs/domains/map.md:54-57`

### docs/domains/map.md — § Core entities — NodeView
> **NodeView** — a node as drawn: its coordinates (from the bundle, D42), its region, its mastery state from `StudentState` (**expedition**) projected to a fog level — `fog` (full), `blocked` (fog with a marker), `cleared` (lifted), plus a `due` ring when spaced repetition has come round (Q1) — and whether it lies upstream of the current trail's marker.

Source: `docs/domains/map.md:49-52`

### docs/domains/map.md — § Workflow W1 — Open the map
> **Pre:** bundles loaded (platform); `StudentState` read. **Steps:** 1. Build `MapViewModel` (Tier 0, in `Core`). 2. Render **trail first (D44)**: the camera frames the trail's current unit — the marker's unit and the next — with the continent visible around it; zooming out reveals regions, horizon and the whole trail; node names appear at the zoom threshold (Q4). 3. The position indicator is the first uncleared trail node at or after the marker. **Post:** `map.opened` emitted.

Source: `docs/domains/map.md:64-69`

### docs/domains/map.md — § Workflow W2 — Tap a node
> **Pre:** map open. **Steps:** 1. Open the **node panel**: name, `paraphrase`, expectation codes with the official link (I6), mastery state in plain words ("under fog", "cleared", "blocked — something upstream is in the way"), "which courses walk through here" from trail data, linked landmarks. 2. Offer exactly one action by state: fogged and reachable → "Include in my next expedition"; `blocked` or upstream of the marker → "Check me here" (opens **diagnosis** W1 on this node, the D28 way in); `cleared` → nothing to do. **Post:** no state change; `map.node_opened` emitted.

Source: `docs/domains/map.md:71-77`

### docs/domains/map.md — § Workflow W6 — Reflect state changes
> **Pre:** expedition or diagnosis emitted a transition (`expedition.node_cleared`, `diagnosis.node_blocked`, `expedition.node_due`). **Steps:** re-derive `MapViewModel`; lift fog, place a blocked marker or a due ring, re-tint the region; a basic transition only — no animated mechanics (D24). **Post:** rendered.

Source: `docs/domains/map.md:97-100`

### docs/domains/map.md — § Workflow W5 — Set the course-progress marker (revised v0.9.2)
> **Pre:** a course trail segment is selected. **Steps:** 1. Show the course's **unit list** (curriculum-spine `Unit`s, D45) with the current one highlighted; the student picks "we are here in class". Dragging the marker along the trail is the same action: it snaps to the nearest unit boundary, else `MAP_MARKER_OFF_TRAIL` and stays. 2. Hand the unit id to **expedition** (`map.marker_moved`), which owns the change, regenerates the trail (D47 — past the last unit the trail extends, drawn dashed) and recomputes the fringe (D45/D48). 3. Re-derive fog: nodes upstream of the marker are fog with an "upstream of your class" note, never cleared. **Post:** marker persisted by expedition; `map.marker_moved` emitted (a D40 event).

Source: `docs/domains/map.md:88-95` (original W5 step 1 with drag description; arbiter-03 § Q-B rules the unit-list-only version)

### docs/domains/map.md — § Open questions Q1 — Due ring visibility
> **Q1 — Does fog return when a cleared node falls due?** **Default:** no — a cleared node stays cleared on the map and gains a *due* ring; only a failed re-probe (per D27 tolerance) can move it to `blocked`. **Trade-off:** honest about decay while never taking away what the student earned; a map that re-fogs would punish absence, which is exactly the door v2 is trying to open. **Ratified 2026-09-09:** default accepted.

Source: `docs/domains/map.md:147-150`

### docs/domains/map.md — § Open questions Q2 — Region tint for empty regions
> **Q2 — Region tint for regions with no nodes.** **Default:** an empty region (the five unpopulated ones in the Demo, any horizon region) is drawn as pure fog with no fraction; a populated region's tint is the cleared fraction over its nodes on the student's selected trails, not all its nodes. **Trade-off:** trail-relative fractions make progress visible in a course; graph-wide fractions would read as near-zero for every student. **Ratified 2026-09-09:** default accepted.

Source: `docs/domains/map.md:152-157`

### docs/domains/map.md — § Open questions Q3 — Horizon showing
> **Q3 — What the horizon shows.** **Default:** the D21 (revised) labels only — Analysis, Topology, Number Theory, Abstract Algebra — greyed, not tappable, no content. **Trade-off:** signals that the continent continues without promising anything; a tappable "coming later" panel is speculative content. **Ratified 2026-09-09:** default accepted.

Source: `docs/domains/map.md:160-163`

### docs/domains/map.md — § Open questions Q4 — Label zoom thresholds
> **Q4 — Label zoom thresholds.** **Default:** region names at overview; node names when a node's drawn diameter exceeds a fixed on-screen size [ESTIMATE: ~44 pt, Apple's minimum tap target]; landmark names always. **Trade-off:** simple and testable, but dense regions may still overlap labels at mid zoom. **Ratified 2026-09-09:** default accepted.

Source: `docs/domains/map.md:165-168`

### docs/domains/map.md — § Invariants enforced here — I4
> - **I4 — the record half.** A `blocked` node beyond the cap is drawn and enterable; a test asserts every `blocked` id in `StudentState` appears in `MapViewModel` with the "Check me here" action and nothing else.

Source: `docs/domains/map.md:133-134`

### docs/domains/map.md — § Invariants enforced here — I14
> - **I14 — co-owner.** `MapViewModel` derivation lives in `Core`; the SwiftUI/`Canvas` layer imports it and computes nothing; a test asserts `Core` has no SwiftUI, UIKit or SpriteKit import (D33).

Source: `docs/domains/map.md:131-132`

## §D. Prior task outputs this task depends on

- **Trail** — `public struct Trail: Codable, Equatable { public let segments: [TrailSegment] }` — Source: `Packages/Core/Sources/Core/Model/StudentState.swift:44-46` (produced by EPIC 01)
- **TrailSegment** — `public struct TrailSegment: Codable, Equatable { public let kind: SegmentKind; public let courseCode: String?; public let nodeIds: [String] }` — Source: `Packages/Core/Sources/Core/Model/StudentState.swift:48-52` (produced by EPIC 01)
- **Marker** — `public struct Marker: Codable, Equatable { public let courseCode: String; public let unitId: String; public let pastLastUnit: Bool? }` — Source: `Packages/Core/Sources/Core/Model/StudentState.swift:23-27` (produced by EPIC 01)
- **StudentState** — `public struct StudentState: Codable, Equatable { public let schemaVersion: Int; public let formatVersionSeen: String; public let syllabi: [String]; public let marker: Marker; public let nodes: [String: NodeState]; public let trail: Trail; public let expeditionLog: [ExpeditionLogEntry]; public let probeLog: [ProbeLogEntry]; public let installDay: String; public let consentOn: Bool }` — Source: `Packages/Core/Sources/Core/Model/StudentState.swift:10-21` (produced by EPIC 01)
- **NodeState** — `public struct NodeState: Codable, Equatable { public let mastery: Mastery; public let correctCount: Int; public let lastProbe: String?; public let nextDue: String?; public let ladderRung: Int; public let remediated: Bool? }` — Source: `Packages/Core/Sources/Core/Model/StudentState.swift:29-36` (produced by EPIC 01)
- **Mastery enum** — `public enum Mastery: String, Codable { case fog; case cleared; case blocked }` — Source: `Packages/Core/Sources/Core/Model/StudentState.swift:38-42` (produced by EPIC 01)
- **ContentBundle, Node, Region, Edge, Landmark** — model types — Source: `Packages/Core/Sources/Core/Model/ContentBundle.swift` (produced by EPIC 01)
- **CalendarDay** — `public struct CalendarDay: Equatable { public let iso: String }` — Source: `Packages/Core/Sources/Core/Model/CalendarDay.swift` (produced by EPIC 01)
- **Expedition.compose(state:bundle:trail:marker:today:queuedNodeId:unitExpeditionUnitId:)** — `public static func compose(...) throws -> ComposeResult` — Source: `Packages/Core/Sources/Core/State/Expedition.swift:35-43` (produced by EPIC 02a, task 02.7)
- **GraphIndex** — Source: `Packages/Core/Sources/Core/Graph/GraphIndex.swift` (produced by EPIC 01)
- **MasteryTransitions** — Source: `Packages/Core/Sources/Core/State/MasteryTransitions.swift` (produced by EPIC 02a)
- **CoreEvent** — enum of notification names — Source: `Packages/Core/Sources/Core/Events/CoreEvent.swift` (produced by EPIC 01)
- **DiagnosisRun.run(trigger:originNodeId:failedAttempts:levelBudget:decisions:shownItemIdsInRun:state:bundle:today:)** — `public static func run(...) -> DiagnosisOutcome` — thin driver over step functions — Source: `tasks/epic-02-task-11-diagnosis-machine-seam.md` § 1 lines 36-40 (produced by EPIC 02b, task 02.11; kept as driver per `tasks/arbitration/arbiter-02-11-stepwise-api.md` § Ruling 3)

## §E. Negative facts (confirmed ABSENT)

- **No `MapViewModel` type exists in `Core` yet.** — Grep for "struct MapViewModel" returned 0 hits in `Packages/Core/Sources`.
- **No view-model derivation function exists yet.** — Grep for "MapViewModel" returned 0 hits in `Packages/Core/Sources`.
- **No exported horizon-region or fog-level logic yet.** — This task creates it.
- **No tests for MapViewModel exist yet.** — No `MapViewModelTests.swift` in `Packages/Core/Tests/CoreTests`.
- **No app-side MapView canvas yet.** — This task is Core only; rendering is EPIC 03 task 03.10.
- **No W6 state-change re-derivation path yet.** — The test drives W6 through `MasteryTransitions.itemCorrect` and `DiagnosisRun.run`, then re-derives the model.

## §F. File scope

Files this task may create or touch. Mark each create / modify and cite existence for modifies.

- CREATE `Packages/Core/Sources/Core/Map/MapViewModel.swift` — confirmed absent (Glob `Packages/Core/Sources/Core/Map/**` empty).
- CREATE `Packages/Core/Tests/CoreTests/MapViewModelTests.swift` — confirmed absent.
- MODIFY `Packages/Core/Sources/Core/Core.swift` — export line for `MapViewModel` — current shape: the package's top-level public API; cite the library target's existing module exports.

## §G. Stack constraints relevant here

**Boundary validation:** None — `MapViewModel` is a pure value type derived in `Core`; no boundary with the render layer exists until EPIC 03 task 03.10 reads it.

**Storage / asset access:** `MapViewModel` has no I/O, no file reads, no clock reads. It is derived from immutable inputs (`ContentBundle`, `StudentState`, `CalendarDay`); injected today is the only temporal input.

**Error codes to use:** None raised by this task. `MapViewModel` derivation is deterministic; invalid states are refused at load (EPIC 03 task 03.4) and do not reach this derivation.

**Model-calling paths:** None — Tier 0 only per I2. Every step and every derivation is deterministic.

**Tooling this task may name:** `docs/tech-stack.md` § 1: Swift 6.3.3 (Xcode 26.6), SwiftUI (rendering only, not this task), SpriteKit only if performance demands it (D24, ~20 nodes does not; `docs/epics/epic-03-app-map-shell.md:229`). No third-party map libraries. Quote: "**SwiftUI**; map on **`Canvas`**; first-party **SpriteKit** only if a few-hundred-node map demands it (D24/D32)" — Source: `docs/tech-stack.md:15`.

**Data this task reads:** The `data/demo` bundle at `Packages/Core/Sources/Core/Model/ContentBundle.swift`, verified by EPIC 01. Inventory:
- **Regions:** 14 total (10 content regions + 4 horizon labels: Analysis, Topology, Number Theory, Abstract Algebra). The 4 horizon regions carry `horizon: true`. The 10 content regions (Number & Operations, Algebra, Functions, Geometry & Measurement, Trigonometry, Calculus, Linear Algebra, Differential Equations, Probability & Statistics, Discrete Mathematics) carry `horizon: false`. — Source: `data/demo/regions.json:3-14` (14 region objects in the `regions` array)
- **Nodes:** 20 nodes in the starting chain and within the graph. — Source: `data/demo/manifest.json:8-19` (the `starting_chain` array) and `data/demo/nodes.json` (20 node objects with courses MTH1W and MCR3U)
- **Edges:** Directed prerequisite edges in `data/demo/edges.json`.
- **Courses:** 2 courses (MTH1W depth 0, MCR3U depth 1). — Source: `data/demo/nodes.json` (node objects carry `courses: [{course_code, depth}, ...]`)
- **Landmarks:** 1 landmark (Canadian fixed-rate mortgages). — Source: `data/demo/landmarks.json:3-23` (one landmark object with `node_ids: ["exponent-laws", "exponential-functions"]` and `source_url: "https://laws-lois.justice.gc.ca/eng/acts/I-15/"`)

**I14 boundary:** `MapViewModel` is a **plain struct** carrying only these types: `Double` (coordinates, zoom), `String` (ids, names), `Bool` (flags), enums, and opaque value types already cleared by EPIC 01 (`NodeState`, node id references). It carries **no `CGFloat`, `Color`, `Path`, `@Observable`, or screen-pixel quantity.** Test asserts: `Packages/Core/Tests/CoreTests` includes an import-boundary test that confirms `Core` has no SwiftUI, UIKit or SpriteKit import.

**Remarks:** This task owns only the pure-derivation layer. Rendering (D44's trail-first camera, pan/zoom, colors, taps) is EPIC 03 task 03.10. The façade (actions, state transitions) is EPIC 03 task 03.5. The W6 test uses a real `DiagnosisRun.run` outcome as the thin driver (arbiter-02-11-stepwise-api § Ruling 3), not internal step functions.

---

## Compilation audit (quote re-reads)

**Quote audit performed 2026-09-10:**
- `contracts/interaction-contract.md` § 2 `compose` (lines 32–36): re-read; byte-match verified ✓
- `contracts/interaction-contract.md` § 3 Marker (lines 62–71 + arbiter lines 106–108): re-read; byte-match verified ✓
- `contracts/interaction-contract.md` § 1 Mastery (lines 13–24): re-read; byte-match verified ✓
- `contracts/domain-glossary.md` § Map and graph (lines 9–26): re-read; byte-match verified ✓
- `docs/domains/map.md` § Core entities MapViewModel (lines 54–57): re-read; byte-match verified ✓
- `docs/domains/map.md` § Core entities NodeView (lines 49–52): re-read; byte-match verified ✓
- `docs/domains/map.md` § W1 (lines 64–69): re-read; byte-match verified ✓
- `docs/domains/map.md` § W2 (lines 71–77): re-read; byte-match verified ✓
- `docs/domains/map.md` § W6 (lines 97–100): re-read; byte-match verified ✓
- `docs/domains/map.md` § W5 (lines 88–95): re-read; original rule quoted; arbiter-03 § Q-B cites the ruling for v0.9.2 change ✓
- `docs/domains/map.md` § Q1 (lines 147–150): re-read; byte-match verified ✓
- `docs/domains/map.md` § Q2 (lines 152–157): re-read; byte-match verified ✓
- `docs/domains/map.md` § Q3 (lines 160–163): re-read; byte-match verified ✓
- `docs/domains/map.md` § Q4 (lines 165–168): re-read; byte-match verified ✓
- `docs/domains/map.md` § I4 (lines 133–134): re-read; byte-match verified ✓
- `docs/domains/map.md` § I14 (lines 131–132): re-read; byte-match verified ✓
- Code signatures: all confirmed from the cited source files ✓
- Data inventory: regions.json, nodes.json, landmarks.json re-read for counts ✓

**Result:** 16 blocks re-read; 0 corrections needed. All quotes byte-verified against source.
