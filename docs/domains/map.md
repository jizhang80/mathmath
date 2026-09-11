# Domain — map

Prefix: `MAP`. Layer ④ (brief §4.1, "Interaction — three doors"). Ground truth: `PROJECT-BRIEF-v2.md` +
amendments; invariants I1–I15 in `CLAUDE.md`.

## Purpose

Door C: the concept graph rendered as one continent the student can see and move across. Regions are
territories organised by math's own taxonomy (D20, D21); edges are rivers flowing in dependency direction;
unmastered nodes sit under fog; the student's one trail is drawn over the map (D47; course segments solid,
extension segments dashed); beyond the continent lies a greyed horizon of labels only; landmarks — real, sourced things (D22, I15) — sit on the map and link into nodes.
The map is also **the record** (D4, v2.5 §3): nodes beyond the backtrack cap are marked `blocked` and stay
visible in fog, enterable by choice, never pushed. **Trail first (D44):** the default view is the student's trail, the continent is background reachable by
zooming out. This domain owns orientation and presentation only: mastery, the course-progress marker,
trail generation and scheduling belong to **expedition**; the hypothesis machine to **diagnosis**; node
coordinates arrive precomputed from the pipeline (D33, D42) and are never computed here. Milestones
**Demo** (hand-written data), **M3** (real M2 data), **M5** (all regions populated, landmarks everywhere).

## Actors and roles

| Actor | Can do here | Cannot |
|---|---|---|
| Student | Pan and zoom; tap a region, node or landmark; move the start marker along a trail; enter a fogged or blocked node by choice | Lift fog by tapping; edit trails, regions or landmarks |
| Owner | Product-test the five §7 criteria at Demo and M3 | Author or review content (I9) |
| System | Derive the `MapViewModel` from the bundles plus `StudentState`; render; emit taps and marker moves | Compute layout or mastery; call a model (Tier 0 only, I2) |
| Local model (Tier 1), Generation model | No role here | Anything |

## Core entities

**Region** — one of the ten D21 (revised) territories — Number & Operations · Algebra · Functions · Geometry &
Measurement · Trigonometry · Calculus · Linear Algebra · Differential Equations · Probability & Statistics ·
Discrete Mathematics — or a horizon label (Analysis, Topology, Number Theory, Abstract Algebra), or the
optional "shore" (grade 7–8; drawn, no content, no fog; not in the Demo — decided at M5): `id`, `name`, `polygon` (normalised coordinates, hand-authored
for the Demo, pipeline-authored later), `horizon: bool`, `neighbours[]`, and one sentence on what the
territory is about (project's own words, I6). A `horizon` region is a label with no nodes and is not
tappable. Every `Node` (**concept-graph**) has exactly one region (I8).

**Trail** — the student's one trail (D47), generated in `Core` by **expedition** W8 from the selected
syllabi, the course-progress marker and mastery state: ordered `segments[]`, each a `course_code`
(**curriculum-spine**) or `extension`, with `node_ids[]`; every segment is a path in the graph (I8). A
trail is presentation of `courses[]` membership plus the D47 extension, never a second graph (I7). The
**course-progress marker** ("we are here in class", a unit of the course — D45) is owned by **expedition**
and set from here.

**Landmark** — `id`, `name`, `what_it_is` (one plain-language paragraph), `source_url` (required, must
resolve — D22, I15), `node_ids[]` (≥ 1), `region_ids[]`, `position`. Validated by **learning-objects** W1;
this domain only places and presents it.

**NodeView** — a node as drawn: its coordinates (from the bundle, D42), its region, its mastery state from
`StudentState` (**expedition**) projected to a fog level — `fog` (full), `blocked` (fog with a marker),
`cleared` (lifted), plus a `due` ring when spaced repetition has come round (Q1) — and whether it lies
upstream of the current trail's marker.

**MapViewModel** — the pure derivation rendered each frame: regions with a tint from the fraction of their
nodes cleared (Q2), rivers, trails with marker and position indicator, landmarks, horizon labels, and the
label set for the current zoom (Q4). Derived in `Core` from bundles + `StudentState`; never persisted; the
renderer holds nothing the model does not (I14).

Referenced elsewhere: **Node**, **Edge**, **Graph bundle** (concept-graph); **Course** (curriculum-spine);
**StudentState**, **StartMarker** (expedition); **Diagnosis** (diagnosis); **ContentBundle** (platform).

## Workflows

### W1 — Open the map
**Pre:** bundles loaded (platform); `StudentState` read. **Steps:** 1. Build `MapViewModel` (Tier 0, in
`Core`). 2. Render **trail first (D44)**: the camera frames the trail's current unit — the marker's unit
and the next — with the continent visible around it; zooming out reveals regions, horizon and the whole
trail; node names appear at the zoom threshold (Q4). 3. The position indicator is the first uncleared
trail node at or after the marker. **Post:** `map.opened` emitted.

### W2 — Tap a node
**Pre:** map open. **Steps:** 1. Open the **node panel**: name, `paraphrase`, expectation codes with the
official link (I6), mastery state in plain words ("under fog", "cleared", "blocked — something upstream
is in the way"), "which courses walk through here" from trail data, linked landmarks. 2. Offer exactly one
action by state: fogged and reachable → "Include in my next expedition"; `blocked` or upstream of the
marker → "Check me here" (opens **diagnosis** W1 on this node, the D28 way in); `cleared` → nothing to do.
**Post:** no state change; `map.node_opened` emitted.

### W3 — Tap a region
**Pre:** map open. **Steps:** open the **region panel**: name, the one-sentence description, fraction
cleared (Q2), and the trails that cross it. A `horizon` region is not tappable. **Post:** `map.region_opened`.

### W4 — Tap a landmark
**Pre:** map open. **Steps:** open the **landmark panel**: name, `what_it_is`, the source link (I15), and
"which parts of the map this touches" as jump links, one per linked node, each landing on W2 for that node.
**Post:** `map.landmark_opened` emitted (a D40 event).

### W5 — Set the course-progress marker
**Pre:** a course trail segment is selected. **Steps:** 1. Show the course's **unit list** (curriculum-spine
`Unit`s, D45) with the current one highlighted; the student picks "we are here in class". The marker is set
from this list only; there is no drag (interaction-contract v0.9.2 § 3). 2. Hand the unit id to **expedition** (`map.marker_moved`), which owns the
change, regenerates the trail (D47 — past the last unit the trail extends, drawn dashed) and recomputes the
fringe (D45/D48). 3. Re-derive fog: nodes upstream of the marker are fog with an "upstream of your class"
note, never cleared. **Post:** marker persisted by expedition; `map.marker_moved` emitted (a D40 event).

### W6 — Reflect state changes
**Pre:** expedition or diagnosis emitted a transition (`expedition.node_cleared`, `diagnosis.node_blocked`,
`expedition.node_due`). **Steps:** re-derive `MapViewModel`; lift fog, place a blocked marker or a due ring,
re-tint the region; a basic transition only — no animated mechanics (D24). **Post:** rendered.

## UI surfaces

Native screens (iOS; names, not routes): **Map** (W1, W5, W6); **Node panel**, **Region panel**,
**Landmark panel** (W2–W4) as sheets over the map. The map is the app's home screen; expedition and
diagnosis are entered from it. Confirmed by the Demo (v2.2 §D: the Demo is the Phase 4 artifact for Doors
B and C).

## Notifications produced

- `map.opened` — `{ trail_code }`. Consumer: **telemetry** (session start, D40).
- `map.node_opened` — `{ node_id, state }`; `map.region_opened` — `{ region_id }`. Consumer: none in MVP.
- `map.landmark_opened` — `{ landmark_id }`. Consumer: **telemetry** (D40 landmark taps).
- `map.marker_moved` — `{ course_code, unit_id }`. Consumers: **expedition** (owns the change), **telemetry**
  (D40 marker placement and moves).
- `map.unit_expedition_requested` — `{ course_code, unit_id }`. Consumer: **expedition** (D46).
- `map.check_here_requested` — `{ node_id }`. Consumer: **diagnosis** (W1 entry from the map).
- `map.include_requested` — `{ node_id }`. Consumer: **expedition** (Q5).

## Errors produced

| Code | When | User sees | Recoverable |
|---|---|---|---|
| `MAP_LAYOUT_MISSING` | A node in the bundle has no coordinates | Internal; bundle refused at load (platform) | Yes — re-run the pipeline build step (D33) |
| `MAP_REGION_UNKNOWN` | A node names a region absent from the bundle | Internal; bundle refused (I8) | Yes — pipeline |
| `MAP_MARKER_OFF_TRAIL` | A stored marker names a course not in `syllabi[]` or a unit absent from the bundle (load, expedition W7) | Nothing on the load path — the map opens at the default marker (arbiter-03 Q-A) | Yes |
| `MAP_LANDMARK_UNSOURCED` | A landmark lacks `source_url` | Internal; bundle refused (I15) | Yes — pipeline |

## Invariants enforced here

- **I14 — co-owner.** `MapViewModel` derivation lives in `Core`; the SwiftUI/`Canvas` layer imports it and
  computes nothing; a test asserts `Core` has no SwiftUI, UIKit or SpriteKit import (D33).
- **I4 — the record half.** A `blocked` node beyond the cap is drawn and enterable; a test asserts every
  `blocked` id in `StudentState` appears in `MapViewModel` with the "Check me here" action and nothing else.
- **I7 / I8** — trails are derived from `courses[]` and validated as paths; regions are one per node; a
  violation refuses the bundle rather than rendering a broken map.
- **I15** — a landmark without a resolving `source_url` never reaches the model.
- **I2 / I6** — Tier 0 throughout; panels show `paraphrase`, codes and outbound links, never Ministry text.
- **D24** — no third-party engine; the renderer is replaceable without touching `Core`.

Seams: expedition → map (`StudentState` in, marker moves out); diagnosis ↔ map (blocked markers in,
"check me here" out); concept-graph, curriculum-spine, learning-objects → map (bundles, read-only);
platform → map (bundle loading); map → telemetry (D40 events).

## Open questions

**Q1 — Does fog return when a cleared node falls due?** **Default:** no — a cleared node stays cleared on
the map and gains a *due* ring; only a failed re-probe (per D27 tolerance) can move it to `blocked`.
**Trade-off:** honest about decay while never taking away what the student earned; a map that re-fogs
would punish absence, which is exactly the door v2 is trying to open.
**Ratified 2026-09-09:** default accepted.

**Q2 — Region tint for regions with no nodes.** **Default:** an empty region (the five unpopulated ones in
the Demo, any horizon region) is drawn as pure fog with no fraction; a populated region's tint is the
cleared fraction over its nodes on the student's selected trails, not all its nodes. **Trade-off:**
trail-relative fractions make progress visible in a course; graph-wide fractions would read as near-zero
for every student.
**Ratified 2026-09-09:** default accepted.

**Q3 — What the horizon shows.** **Default:** the D21 (revised) labels only — Analysis, Topology, Number
Theory, Abstract Algebra — greyed, not tappable, no content. **Trade-off:** signals that the continent continues without promising
anything; a tappable "coming later" panel is speculative content.
**Ratified 2026-09-09:** default accepted.

**Q4 — Label zoom thresholds.** **Default:** region names at overview; node names when a node's drawn
diameter exceeds a fixed on-screen size [ESTIMATE: ~44 pt, Apple's minimum tap target]; landmark names
always. **Trade-off:** simple and testable, but dense regions may still overlap labels at mid zoom.
**Ratified 2026-09-09:** default accepted.

**Q5 — Can the student add a fogged node to the next expedition from the panel?** **Default:** yes, one
node, queued ahead of the scheduler's pick if it is on the fringe; ignored with a plain message if it is
upstream of the marker (D45 — that way in is "Check me here"). **Trade-off:** gives the map a reason to be
tapped; a queue longer than one is scheduling policy the student should not have to manage.
**Ratified 2026-09-09:** default accepted.

## Change log

| 2026-09-09 | Drafted (Phase 3b, v2 re-cut). Open questions pending owner ratification. |
| 2026-09-09 | v2.6/v2.7: ten regions + four horizon labels + optional shore (D21 revised); trail first (D44); per-student generated trail with dashed extension (D47); course-progress marker set from the unit list (D45); unit expedition request (D46); fringe wording (D48). |
