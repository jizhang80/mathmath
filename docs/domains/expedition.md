# Domain — expedition

Prefix: `EXP`. Layer ④ (brief §4.1, "Interaction — three doors"). Ground truth: `PROJECT-BRIEF-v2.md` +
amendments; invariants I1–I15 in `CLAUDE.md`.

## Purpose

Door B: fragmented-time progression. One expedition is ≈ 5 probe items, ≈ 3 minutes [SOURCED: brief §2,
D23], drawn from the fog frontier with spaced repetition over the graph; a cleared item lifts fog. It is
built from the existing probe mechanism — no separate game content is authored (D23). This domain owns the
**student state** (per-node mastery, the start marker per trail, expedition and probe logs), the
**scheduler**, deterministic item checking (I1, I10) and the D27 tolerance rule that hands a second miss to
**diagnosis**. Streaks, region completion and trail progress emerge from the state without extra design.
Milestones **Demo**, **M3**, **M4** (Tier 1 touches only hint wording via diagnosis), **M5**.

## Actors and roles

| Actor | Can do here | Cannot |
|---|---|---|
| Student | Start an expedition; answer items; see the answer and one-line why after each; move the start marker (via map); read the end summary | Skip checking; mark a node cleared; see answer keys before answering |
| Owner | Product-test "finishes one and starts a second" (§7 criteria) | Review items (I9) |
| System | Select items; check answers in code; apply transitions; persist state; hand off to diagnosis | Use a model for anything (Tier 0 only, I2); schedule a node beyond the cap (I4) or upstream of the marker (D28) |
| Local model (Tier 1), Generation model | No role here | Anything |

## Core entities

**StudentState** — the one persisted student document, a `Codable` struct in `Core` (D32, D33), written as
JSON by **platform** and synced via iCloud when signed in (D36). Per node: `mastery ∈ {fog, cleared,
blocked}` (v2 §5's `unknown` collapses into `fog`; the distinction is carried by `last_probe = nil`),
`correct_count`, `last_probe` (day granularity), `next_due` (Q2). Per trail: `start_marker` (a node id on
the trail, default the trail's first node — D28), selected-trail flag. Plus the **ExpeditionLog** (one entry
per run: items, results, Door A events, marker at the time) and the **ProbeLog** that **telemetry** derives
its events from. Serialisable from day one (v2.2 A5 resolution; Android port). No field identifies a
person (I5).

**StartMarker** — per trail, the student's self-placed start (D28). Nodes upstream of it are excluded from
the frontier and entered only through diagnosis; diagnosis is the safety net for a marker placed too far
ahead. Owned here; moved from **map** W5.

**Frontier** — the set of nodes eligible for new items: not `cleared`, not upstream of the current trail's
marker, and either a trail-relative root (no prerequisite that is itself on the frontier side of the
marker) or having every prerequisite `cleared` or `blocked`-and-remediated (Q1). `blocked` nodes are always
frontier-eligible wherever they lie: evidence put them there, so the marker exclusion no longer applies —
this is how a node remediated in diagnosis is eventually cleared.

**Expedition** — one run: ≈ 5 `ProbeItem`s (**learning-objects**) chosen per W1, answered in order, with
at most one Door A event (D27). **ItemResult** — item id, node, correct/incorrect, retry flag, the answer
shown (D5). **ExpeditionSummary** — nodes cleared this run, fog lifted, blocked nodes marked, "Start
another".

Referenced elsewhere: **Node**, **Edge**, **Graph bundle** (concept-graph); **ProbeItem**, **HintTree**
(learning-objects); **Trail**, **MapViewModel** (map); **Diagnosis** (diagnosis); **ContentBundle**,
**StatePersistence** (platform).

## Workflows

### W1 — Start an expedition
**Pre:** bundles loaded; `StudentState` read; a trail selected. **Steps:** 1. (Tier 0, `Core`) Compute the
Frontier. 2. Fill up to ≈ 5 slots (Q3): first any node queued from the map (map Q5), then frontier nodes
ordered by trail position, then `cleared` nodes whose `next_due` has passed, oldest `last_probe` first.
3. Draw one `ProbeItem` per slot from **learning-objects** W3 (single-item variant), preferring items unused
in the last N runs. 4. If the frontier and due sets are both empty, raise `EXP_NO_FRONTIER` and stop.
**Post:** an Expedition in progress; `expedition.started` emitted (D40).

### W2 — Answer an item
**Pre:** an item is shown. **Steps:** 1. Student answers — numeric entry or a multiple-choice tap (I10).
2. (Tier 0) Check deterministically in code: numeric per Q4, multiple-choice by choice id. No CAS on the
device, no model (I1, D34). 3. Show correct/incorrect **with the correct answer and the item's one-line
why** immediately (D5, I3). 4. Record the `ItemResult`. **Post:** `expedition.item_answered` emitted (D40,
per-item node and result — the L3 input).

### W3 — Apply the tolerance rule (D27)
**Pre:** an incorrect `ItemResult`. **Steps:** 1. First miss on this node in this run → draw one retry
item on the same node and return to W2. 2. Second miss on the node, and no Door A event yet this run →
emit `expedition.diagnosis_requested` and suspend the run while **diagnosis** runs (W1 there); on return,
continue with the remaining items. 3. Second miss after the run's Door A event was used → mark the node
`blocked` (W4) and continue without interruption. **Post:** at most one Door A event per run; a test
asserts it.

### W4 — Apply a mastery transition
**Pre:** an `ItemResult`, or a diagnosis outcome. **Steps (all in `Core`, pure):** correct → increment
`correct_count`; at the clear rule (Q1) set `cleared`, set `next_due` per Q2, emit `expedition.node_cleared`.
Incorrect on a `cleared` node that was due → keep `cleared`, reset `next_due` to the shortest interval,
and apply W3 as for any miss. `diagnosis.node_blocked` → set `blocked` on the named upstream node
(frontier-eligible thereafter). `blocked` → `cleared` only through the clear rule. **Post:** state
transitioned; **map** re-derives (W6 there).

### W5 — End the run
**Pre:** the last item is answered, or the student leaves. **Steps:** 1. Build the `ExpeditionSummary`.
2. Append the ExpeditionLog entry; write `StudentState` via **platform** (`EXP_STATE_WRITE_FAILED` shows
a banner, the summary still shows — I3's spirit). 3. Offer "Start another" (W1) and "Back to the map".
**Post:** `expedition.completed` emitted (D40) with the count of items and cleared nodes; a run left
mid-way is logged as abandoned, never resumed item-by-item (Q6).

### W6 — Move the start marker
**Pre:** `map.marker_moved` with a node on the trail. **Steps:** set `start_marker`; recompute the
Frontier; nodes newly upstream keep whatever mastery they had (a cleared node stays cleared). **Post:**
persisted; `expedition.marker_changed` emitted → map, telemetry (D40).

### W7 — Resume after relaunch
**Pre:** app launch; a `StudentState` file exists (or an iCloud copy). **Steps:** platform reads and
migrates (its W4); this domain validates node ids against the installed bundle — ids no longer in the graph
are kept in the file but ignored (`EXP_NODE_NOT_IN_GRAPH`), never deleted. **Post:** state loaded; the map
opens (map W1).

## UI surfaces

Native screens: **Expedition** (item view with numeric keypad or choices, immediate answer card — W2, W3);
**Expedition summary** (W5). Entered from the **Map** "Start expedition" button. Confirmed by the Demo.

## Notifications produced

- `expedition.started` — `{ trail_code, item_count, marker_node }`; `expedition.completed` — `{ items,
  cleared_count, blocked_count, abandoned }`. Consumers: **telemetry** (D40), **map**.
- `expedition.item_answered` — `{ node_id, correct, retry }`. Consumer: **telemetry** (L3 per-item event and
  the per-edge derived event, v2.5 §1).
- `expedition.diagnosis_requested` — `{ node_id, failed_item_ids[] }`. Consumer: **diagnosis** (W1 entry).
- `expedition.node_cleared` — `{ node_id }`; `expedition.node_due` — `{ node_id }`. Consumers: **map**,
  **telemetry**.
- `expedition.marker_changed` — `{ trail_code, node_id }`. Consumers: **map**, **telemetry** (D40).

## Errors produced

| Code | When | User sees | Recoverable |
|---|---|---|---|
| `EXP_NO_FRONTIER` | Nothing reachable and nothing due | "You've cleared everything reachable from your start. Move your marker, or explore the map." | Yes |
| `EXP_ITEM_POOL_EMPTY` | A frontier node has no unused item | Node skipped this run; internal count | Yes — pool grows at M5 |
| `EXP_STATE_WRITE_FAILED` | Platform could not persist | Banner; summary still shown | Yes — retried next write |
| `EXP_NODE_NOT_IN_GRAPH` | State names a node absent from the bundle | Internal; entry ignored, kept | Yes |

## Invariants enforced here

- **I2 / I1** — every workflow is Tier 0; checking is code over `answer`/`choice` fields, and the
  `ProbeItem` type carries no free-text answer for the device to grade (co-owner with learning-objects).
- **I3** — W2's answer card cannot exist without the correct answer and why; a test asserts every
  `ItemResult` rendering includes them.
- **I4 — co-owner with diagnosis.** The scheduler never selects a node that diagnosis marked beyond the cap
  unless it is `blocked` (evidence-based); a property test asserts no item is ever drawn from a node
  upstream of the marker that is not `blocked` (D28).
- **I5** — `StudentState` has no identifying field; a schema test asserts the closed field set.
- **I10** — item types are `numeric | mc` only; a bundle with any other type is refused at load.
- **I14** — Frontier, scheduler and transitions are pure functions in `Core`; the view calls them.
- **D27** — one retry, one Door A event per run: both are tested as properties of W3.

Seams: expedition ↔ diagnosis (`expedition.diagnosis_requested` out; `diagnosis.node_blocked` /
`diagnosis.returned` in); expedition → map (`StudentState`, transitions); map → expedition (marker,
include request); learning-objects → expedition (`ProbeItem` draw); platform ↔ expedition (persistence,
sync); expedition → telemetry (D40, L3).

## Open questions

**Q1 — The clear rule.** **Default:** two correct answers on **distinct items** of the node, in any runs
(the Demo's "2 correct probes clears it"); a retry item counts. **Trade-off:** one correct would clear on a
guess (25 % on four-choice items); three would make a five-item run clear at most one node and feel slow.
**Ratified 2026-09-09:** default accepted.

**Q2 — Spaced-repetition schedule.** **Default:** a fixed Leitner-style ladder over `next_due` — 1, 3, 7,
14, 30 days [ESTIMATE: common spacing ladder; not tuned on this population] — advancing a rung on a correct
due item, resetting to the first rung on a miss; due items fill at most two slots per run (Q3). **Trade-off:**
transparent and testable; an adaptive scheduler would need per-student data D17 forbids sending and the
device alone has too little of.
**Ratified 2026-09-09:** default accepted.

**Q3 — Slot mix per run.** **Default:** 5 slots — up to 3 frontier (map-queued first), up to 2 due; if one
pool is short the other fills. **Trade-off:** keeps every run moving forward; a due-heavy run feels like
revision, a frontier-only run lets cleared nodes rot silently.
**Ratified 2026-09-09:** default accepted.

**Q4 — Numeric answer matching.** **Default:** exact match after normalisation (whitespace, leading zeros,
`3/4` = `0.75`); decimals within a per-item absolute tolerance the item declares, default 0 [ESTIMATE:
items are authored to have exact answers]; no CAS on the device (D34). **Trade-off:** honest and cheap; an
item whose answer genuinely needs symbolic comparison must be authored as multiple-choice instead.
**Ratified 2026-09-09:** default accepted.

**Q5 — What the student sees on the second miss when the run's Door A event is spent.** **Default:** the
answer card as usual plus one line — "We'll come back to this one" — and the node is marked `blocked` on
the map; no hint, no probe. **Trade-off:** keeps the 3-minute rhythm (D27's purpose); the student gets no
help on that node until the next run or a "Check me here" tap.
**Ratified 2026-09-09:** default accepted.

**Q6 — Resuming a run interrupted by the app going to background.** **Default:** the current item is kept
for a short grace window [ESTIMATE: until the app is terminated by the OS]; a terminated run is logged as
abandoned and the next launch starts fresh. **Trade-off:** no half-finished runs to reason about; a student
interrupted by a call loses at most one item's context.
**Ratified 2026-09-09:** default accepted.

## Change log

| 2026-09-09 | Drafted (Phase 3b, v2 re-cut). Open questions pending owner ratification. |
