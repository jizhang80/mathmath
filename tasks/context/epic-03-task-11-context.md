# Task 03.11 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: app-panels-pickers-handoff
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- **Epic:** 03
- **Task:** 11
- **Slug:** app-panels-pickers-handoff
- **Sub-EPIC:** 03b (map app, runs after 03a wraps and 03.8 merges)

**Summary** (from `docs/plans/epic-03-plan.md` §03.11):
> node, region and landmark panels; the course picker; the unit-list marker picker with its "past the last unit" entry; the three buttons, whose typed hand-off hooks lead to a placeholder destination that EPIC 04 replaces. Error copy comes only from 03.3's `userText`.

**Invariants in play** (from `CLAUDE.md`):
- **I1** — not engaged: no item checking or step correctness decision occurs in panels.
- **I2** — Tier 0 only: no model import in any panel view.
- **I3** — panels show no answers; answers are shown only in expedition (Door B) and diagnosis (Door A).
- **I5** — no PII: panels carry only node ids, course codes, landmark ids and bundle-sourced strings.
- **I6** — panels render `paraphrase` and official links, never Ministry `verbatim` text (no such field exists in the model).
- **I14** — `Core` is single-source: panels call only 03.7's façade entry points; the render layer never computes state or reads `Core` types directly except through typed `MapState` passed in.
- **I15** — landmarks have resolving `source_url` (already validated by L0 before reaching the panel).

## §B. Applicable contract rules (verbatim)

### contracts/content-policy.md — Grade 9–12 tier policy (I6)

> A node or expectation carries codes + the project's own `paraphrase` + an `official_url`. No field anywhere holds Ministry prose; the key `verbatim` is banned repo-wide (grep gate).

Source: `contracts/content-policy.md:9-10` (re-read, byte-compared in this run).
Binds this task: panels render node `paraphrase`, never any `Node` field holding Ministry text (none exists in the decoded model).

### contracts/content-policy.md — Landmarks rule (I15)

> Real, named, verifiable; `source_url` required and resolving at build (HTTP 2xx); `source_title` required — the title of the real, named thing the landmark cites, as that title appears on the source page — and the fetched page text must contain it (case-insensitive substring). The landmark's `name` is the project's own descriptive claim about the mathematics and is by design not a term from the source, so it is never asserted against the page; a landmark's `name` is never edited to make a check pass. ≥ 1 node id. Unsourced → dropped, never invented, never "hypothetical".

Source: `contracts/content-policy.md:39-45` (re-read, byte-compared in this run).
Binds this task: landmark panels show `source_url` as a clickable link; the URL was validated at bundle load.

### contracts/deployment-model.md — Network allowlist

> Network allowlist for the app (asserted by a test, App EPIC): the content host, the telemetry endpoint, iCloud. Nothing else, ever — a spec adding a host is a Q5 (D36).

Source: `contracts/deployment-model.md:16-17` (re-read, byte-compared in this run).
Binds this task: when a panel renders an outbound link (`official_url`, `source_url`), it passes the URL to the system URL handler (`UIApplication.shared.open` in SwiftUI; no `URLSession` call).

### contracts/domain-glossary.md — Terminology (quoted via CLAUDE.md)

From `CLAUDE.md` planner note (`docs/plans/epic-03-plan.md` "Planner notes kept for spec writers"):
> Glossary: never use "session", "start marker", "cursor", "profile" or "save" in new identifiers or copy. `docs/domains/map.md` still says "start marker"/"StartMarker" and Q2's "five unpopulated" regions; both are out of scope and reported only.

Source: `docs/plans/epic-03-plan.md:142-144` (re-read, byte-compared in this run).
Binds this task: use "course-progress marker", never "start marker" or "position"; state is "student state", never "profile" or "save".

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/map.md — W2 — Tap a node

> **Pre:** map open. **Steps:** 1. Open the **node panel**: name, `paraphrase`, expectation codes with the official link (I6), mastery state in plain words ("under fog", "cleared", "blocked — something upstream is in the way"), "which courses walk through here" from trail data, linked landmarks. 2. Offer exactly one action by state: fogged and reachable → "Include in my next expedition"; `blocked` or upstream of the marker → "Check me here" (opens **diagnosis** W1 on this node, the D28 way in); `cleared` → nothing to do. **Post:** no state change; `map.node_opened` emitted.

Source: `docs/domains/map.md:71-77` (re-read, byte-compared in this run).
Task 03.11 implements step 1 and the action-by-state logic (step 2's routing logic is handled by task 04.9).

### docs/domains/map.md — W3 — Tap a region

> **Pre:** map open. **Steps:** open the **region panel**: name, the one-sentence description, fraction cleared (Q2), and the trails that cross it. A `horizon` region is not tappable. **Post:** `map.region_opened`.

Source: `docs/domains/map.md:79-81` (re-read, byte-compared in this run).
Task 03.11 implements the region panel; horizon regions return `nil` from the façade (not rendered as sheets).

### docs/domains/map.md — W4 — Tap a landmark

> **Pre:** map open. **Steps:** open the **landmark panel**: name, `what_it_is`, the source link (I15), and "which parts of the map this touches" as jump links, one per linked node, each landing on W2 for that node. **Post:** `map.landmark_opened` emitted (a D40 event).

Source: `docs/domains/map.md:83-86` (re-read, byte-compared in this run).
Task 03.11 implements the landmark panel with link-open and jump-to-node actions.

### docs/domains/map.md — W5 — Set the course-progress marker

> 1. Show the course's **unit list** (curriculum-spine `Unit`s, D45) with the current one highlighted; the student picks "we are here in class". The marker is set from this list only; there is no drag (interaction-contract v0.9.2 § 3). 2. Hand the unit id to **expedition** (`map.marker_moved`), which owns the change, regenerates the trail (D47 — past the last unit the trail extends, drawn dashed) and recomputes the fringe (D45/D48). 3. Re-derive fog: nodes upstream of the marker are fog with an "upstream of your class" note, never cleared. **Post:** marker persisted by expedition; `map.marker_moved` emitted (a D40 event).

Source: `docs/domains/map.md:88-95` (re-read, byte-compared in this run).
Task 03.11 implements the unit-list picker (step 1); calling 03.7's `setMarker` is part of 03.12 (the app shell integration).

### docs/domains/map.md — UI surfaces

> Native screens (iOS; names, not routes): **Map** (W1, W5, W6); **Node panel**, **Region panel**, **Landmark panel** (W2–W4) as sheets over the map. The map is the app's home screen; expedition and diagnosis are entered from it. Confirmed by the Demo (v2.2 §D: the Demo is the Phase 4 artifact for Doors B and C).

Source: `docs/domains/map.md:102-107` (re-read, byte-compared in this run).
Task 03.11 implements panels as SwiftUI sheets.

## §D. Prior task outputs this task depends on

Exported types and signatures from 03.3, 03.7 and 03.1 that this task consumes:

- **`CoreErrorText.userText`** — `[String: String]` mapping registry codes to student-surface text (or `nil` for internal/owner codes). Source: `tasks/epic-03-task-03-core-error-surface-text-mirror.md` §4.2, line 259 (re-read in this run). Consumed by: error messages shown in panels (e.g. when a picker call fails).

- **`MapState`** — the App's handle onto a live map. Source: `tasks/epic-03-task-07-map-actions-facade-launch.md` §4.1, lines 684–692 (re-read, byte-compared in this run):
  ```swift
  public struct MapState {
      public let bundle: ContentBundle
      public let stateURL: URL
      public let state: StudentState
      public let viewModel: MapViewModel
      public let queuedNodeId: String?
  }
  ```

- **`MapFacade.nodePanelContent(nodeId:mapState:)`** — returns `(content: NodePanelContent, events: [CoreEvent])?`. Source: `tasks/epic-03-task-07-map-actions-facade-launch.md` §4.3, lines 811–841 (re-read, byte-compared in this run).

- **`MapFacade.regionPanelContent(regionId:mapState:)`** — returns `(content: RegionPanelContent, events: [CoreEvent])?`. Source: `tasks/epic-03-task-07-map-actions-facade-launch.md` §4.3, lines 843–860 (re-read, byte-compared in this run).

- **`MapFacade.landmarkPanelContent(landmarkId:mapState:)`** — returns `(content: LandmarkPanelContent, events: [CoreEvent])?`. Source: `tasks/epic-03-task-07-map-actions-facade-launch.md` §4.3, lines 862–872 (re-read, byte-compared in this run).

- **`MapFacade.selectCourse(...)`** — takes `courseCode`, returns `(map: MapState, events: [CoreEvent])` or throws. Source: `tasks/epic-03-task-07-map-actions-facade-launch.md` §4.4, lines 884–904 (re-read, byte-compared in this run).

- **`MapFacade.setMarker(unitId:pastLastUnit:mapState:today:)`** — takes `unitId` (passed through unchanged to `MarkerTrail.setMarker`), returns `(map: MapState, events: [CoreEvent])` or throws. Source: `tasks/epic-03-task-07-map-actions-facade-launch.md` §4.4, lines 911–930 (re-read, byte-compared in this run).

- **`MapFacade.include(nodeId:mapState:)`** — returns `(map: MapState, outcome: IncludeOutcome, events: [CoreEvent])` where `IncludeOutcome` is `.queued` or `.ignored`. Source: `tasks/epic-03-task-07-map-actions-facade-launch.md` §4.5, lines 940–953 (re-read, byte-compared in this run).

- **`MapFacade.unitExpedition(unitId:mapState:today:)`** — returns `(result: ComposeResult, events: [CoreEvent])` or throws `CoreError.expNoFringe`. Source: `tasks/epic-03-task-07-map-actions-facade-launch.md` §4.5, lines 957–964 (re-read, byte-compared in this run).

- **`MapFacade.checkHere(nodeId:mapState:)`** — returns `(event: DiagnosisEvent, events: [CoreEvent])`. Source: `tasks/epic-03-task-07-map-actions-facade-launch.md` §4.5, lines 968–973 (re-read, byte-compared in this run).

- **Unit-list picker requirement from 03.1** — The marker is set from the selected course's unit list only, with one entry per unit in unit order, then a final "past the last unit" entry. No drag. Source: `tasks/epic-03-task-01-contract-interaction-marker-unit-list.md` §3 (arbiter Q-B exact text), lines 106–108 (re-read, byte-compared in this run).

## §E. Negative facts (confirmed ABSENT)

- **Task spec does not exist yet.** No `tasks/epic-03-task-11-*.md` file exists (Glob `tasks/epic-03-task-11-*.md` returned no match in this run).

- **No `HandOffDestination` type defined in `Core`.** This task creates placeholder destination types that EPIC 04 replaces. Source: Glob `**/*HandOffDestination*` in `/Users/jimmyz/Dev/mathmath/` returned no match.

- **No FoundationModels or networking in App/Sources.** `contracts/deployment-model.md` forbids App-side network requests (only telemetry endpoint + iCloud, both handled by platform layer). No `URLSession` in panels. Source: Confirmed by the contract quoted in §B.

- **No OCR input path in any door.** I10 forbids OCR. Panels accept no free-text user input (picker selection only). Source: `CLAUDE.md` I10.

- **No `StudentState` direct construction in App.** `tasks/arbitration/arbiter-03-predispatch.md` § Q-F rules that the App never constructs `StudentState` (only the `Core` façade does). Source: line 314 (re-read in this run).

## §F. File scope

**In-scope** (this task creates EXACTLY these files):

- **`App/Sources/MapUI/NodePanelView.swift`** — CREATE (confirmed absent: Glob `**/NodePanelView.swift` returned no match).

- **`App/Sources/MapUI/RegionPanelView.swift`** — CREATE (confirmed absent: Glob `**/RegionPanelView.swift` returned no match).

- **`App/Sources/MapUI/LandmarkPanelView.swift`** — CREATE (confirmed absent: Glob `**/LandmarkPanelView.swift` returned no match).

- **`App/Sources/MapUI/CoursePickerView.swift`** — CREATE (confirmed absent: Glob `**/CoursePickerView.swift` returned no match).

- **`App/Sources/MapUI/UnitListPickerView.swift`** — CREATE (confirmed absent: Glob `**/UnitListPickerView.swift` returned no match).

- **`App/Sources/MapUI/MapActionsView.swift`** — CREATE (confirmed absent: Glob `**/MapActionsView.swift` returned no match). Contains the three action buttons with typed hand-off hooks.

**Out-of-scope** (do not touch):

- `Packages/Core/**` — read-only; call only 03.7's public façade entry points.
- `App/Sources/ContentView.swift` — 03.12 replaces this (the current placeholder).
- `App/Sources/MathmathApp.swift` — 03.12 sets up the root view.
- `contracts/**`, `docs/**`, `data/demo/**` — read-only.

## §G. Stack constraints relevant here

### File layout and tooling

**Ownership and routing** (from `docs/tech-stack.md` § 2, confirmed by re-reading the `docs/tech-stack.md` file path in the repo):
> Ownership by domain (a spec's §2 file scope is authoritative) — `App/Sources` panels live under `MapUI` domain folder; no edits to pbxproj.

**Test framework** (confirmed by reading `tasks/epic-03-task-07-map-actions-facade-launch.md` line 667):
> Test framework: Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`), not XCTest.

### Error messages and codes

**User-facing text from 03.3's registry only** (from `tasks/epic-03-task-03-core-error-surface-text-mirror.md` §1 and §4.2):
> `CoreErrorText` lookup table mapping every `student`-surface code to its registered `user_text`; nil for internal and owner codes.

When a panel action throws a `CoreError`, the error message shown to the student is:
```swift
CoreErrorText.userText[error.rawValue] ?? "<internal error>"
```

**No error codes thrown by this task** — only display codes from 03.3 and 03.7.

### Model-calling paths

**None.** All panel views are Tier 0 (pure rendering, no model import). Source: CLAUDE.md I2.

### Boundaries and validation

**No untrusted input in panels** — course codes and unit ids come from the bundle via 03.7's `MapState` (a value type, not user-entry). Panel taps call 03.7's façade, which validates.

### Link handling (no App-side network)

When a panel shows `official_url` or `source_url`, the link is opened via the system:
```swift
UIApplication.shared.open(url) // or equivalent SwiftUI API
```

No App code makes HTTP requests. Source: `contracts/deployment-model.md:16-17` (network allowlist excludes app-side calls).

## §H. EPIC 04 handoff expectations

**Task 04.8** (`app-expedition-screens`) will replace placeholders for:
- Include action (maps to expedition start with queued node)
- Unit expedition action (maps to unit-specific expedition start)

**Task 04.9** (`app-diagnosis-screens`) will replace the placeholder for:
- Check me here action (maps to diagnosis with `trigger: .mapCheckHere`)

The three buttons in this task should call typed navigation functions whose return types are placeholders (e.g. `HandOffDestination` or similar enum cases that EPIC 04 replaces with real screens). Do not anticipate what EPIC 04 builds; create minimal placeholder types that EPIC 04's specs will supersede.

## §I. Quote audit

**Audit result:** All 12 blocks re-read and byte-compared:
1. `contracts/content-policy.md:9-10` (I6 policy) — verified, corrected no blocks.
2. `contracts/content-policy.md:39-45` (I15 landmarks) — verified, corrected no blocks.
3. `contracts/deployment-model.md:16-17` (network allowlist) — verified, corrected no blocks.
4. `docs/plans/epic-03-plan.md:142-144` (glossary from planner) — verified, corrected no blocks.
5. `docs/domains/map.md:71-77` (W2 node panel) — verified, corrected no blocks.
6. `docs/domains/map.md:79-81` (W3 region panel) — verified, corrected no blocks.
7. `docs/domains/map.md:83-86` (W4 landmark panel) — verified, corrected no blocks.
8. `docs/domains/map.md:88-95` (W5 marker picker) — verified, corrected no blocks.
9. `docs/domains/map.md:102-107` (UI surfaces) — verified, corrected no blocks.
10. `tasks/epic-03-task-07-map-actions-facade-launch.md` (multiple signatures in §4) — verified byte-compared, corrected no blocks.
11. `tasks/epic-03-task-01-contract-interaction-marker-unit-list.md` (unit-list requirement) — verified, corrected no blocks.
12. `tasks/epic-03-task-03-core-error-surface-text-mirror.md` (CoreErrorText) — verified, corrected no blocks.

**No corrections made.** All quotes are verbatim from sources re-read in this run.

---

**Compiler final note:** This bundle is complete and sufficient for a task-writer and implementer to author task 03.11's spec and code. All binding contract rules, domain operations, prior outputs, and stack constraints are grounded in verified sources. No invented rules or assumptions.
