# Domain — learning-objects

Prefix: `LO`. Layer ③ (brief §4.1). Ground truth: `PROJECT-BRIEF-v2.md` + amendments; invariants I1–I15.

## Purpose

Owns what a node needs to be *taught*, once concept-graph has said *which* node is at issue: per Node
(concept-graph) an Explanation, WorkedExample(s), a closed ErrorType enum, a HintTree keyed by ErrorType,
and a ProbeItem pool — static assets generated offline (brief §4.1 ③), read at runtime by expedition
and diagnosis. It also owns **Landmarks** (v2 §4.1 ③ "New": real, sourced, real-world things linked to
nodes — D22, I15). Nothing is computed live and no model runs here. Milestones **Demo** (hand-written
items and one landmark), **M2, M3, M5**; M3 is load-bearing, as Tier 0 needs hints and probes with no model.

One asset is structure, not prose: the **implies-prerequisite mapping** (per ErrorType, whether it points
at an upstream node), which turns "error classified" into "hypothesis presented" (brief §7).

**Seam — learning-objects↔diagnosis / expedition:** three synchronous Tier 0 lookups only,
`(node, error_type) → hint tiers` (W2), `node → 2 ProbeItems` (W3, diagnosis) and `node → 1 ProbeItem`
(W3, expedition). Neither consumer reads the bundle directly, nor caches hint text across versions.

## Actors and roles

| Actor | What they can do here | What they cannot |
|---|---|---|
| Student | Read explanations, examples, hints, landmarks; answer ProbeItems, via expedition and diagnosis | See enum internals, the mapping, answer keys before answering |
| Owner | Accept or reject a bundle version whole, on its report | Review or edit items (I9, D12) |
| System | Load the bundle, resolve the two lookups, check version match | Modify or generate content |
| Local model (Tier 1) | Adapt hint *wording* on delivery (brief §4.2) | Change hint semantics, tier order, enum membership, a hint's target |
| Generation model (offline) | Produce candidates in content-generation | Enter a bundle unvalidated; emit ErrorTypes off-enum |

## Core entities

**LearningObject** — per-node container keyed by a Node id, one per node in the graph bundle. The
**LearningObject bundle** holds all of them, a manifest and the `graph_bundle_version` targeted; it is
immutable and versioned, and platform's AssetManifest loads it. **Explanation** — short prose in the
project's own words, no verbatim Ministry text (I6, D18); it may cite codes of the Expectations
(curriculum-spine) the node realises. **WorkedExample** — a solved item as an ordered LaTeX step
sequence, each step CAS-checked by the pipeline (D41); displayed via SwiftMath, and at M5 also on the
homework-mode input path (D9).

**ErrorType** — a member of the node's closed catalogue (brief §5 `error_catalogue[]`): per-node, with
exactly one terminal member `none-of-these` (catalogue id; `classify`'s abstention outcome is the token
`none_of_these`). Canonical example, the M4′ node *logarithmic equation solving*, six
members verbatim from brief §8 — missed domain restriction; log-combination rule misapplied;
exponent–log inverse relationship not internalised; quadratic solved incorrectly; arithmetic slip; none of
these. Each has a stable id, a student-facing phrasing, a `probe_target`, and `implies_prerequisite`:
`null`, or an upstream Node id — **the implies-prerequisite mapping**. Above, the exponent–log type points
at the exponential-functions node of the D14 chain, "arithmetic slip" nowhere, and `none-of-these` is
always `null`: abstention, not diagnosis.

**HintTree** — per node, ErrorType → ordered tiers: tier 1 nudges at what to look at, tier 2 targets that
ErrorType, tier 3 works the failing step through. Answers are never withheld (D5, I3), so the tree gates
nothing: it exposes the *reason* for the failure. Tier order and semantics are fixed at generation.

**ProbeItem** — a short item tagged with a node id, of type `numeric | mc` (I10): a `prompt` (LaTeX
subset SwiftMath renders — the rendering spike, v2.2 §B), an `answer` (numeric, with an optional declared
tolerance) or `choices[]` with the correct id, a one-line `why` shown with the answer (D5), and
`distractor_error_types` — every distractor and each anticipated numeric wrong answer tagged with an
`ErrorType` id, the Tier 0 classifier (diagnosis Q1). The answer is re-derived by SymPy in the pipeline
(D41, I1); on the device it is checked in code, with no grader model and no free text. Two drawn per
diagnosis probe [SOURCED: brief §2, §7], one per expedition slot (D23).

**Landmark** — `id`, `name`, `what_it_is` (one plain-language paragraph, the project's own words),
`source_url` (required; must resolve — D22, I15), `node_ids[]` (≥ 1, often across regions),
`region_ids[]`, `position` on the map. Generated with its source in content-generation, validated here,
placed by map. A landmark that cannot be sourced is dropped, never invented.

## Workflows

### W1 — Validate and version a bundle (offline)

**Pre:** a Graph bundle that passed L0 (I8) and candidates from content-generation — independent
GenerationRuns against the **Generation model** (offline Claude API), intersected there. Validation is
Tier 0.
**Steps:** 1. **Coverage** — one LearningObject per Node, none naming an unknown node, else
`LO_INCOMPLETE_BUNDLE`. 2. **Enum closure** — each enum non-empty, exactly one `none-of-these`.
3. **Mapping validity** — every non-null `implies_prerequisite` is an upstream neighbour (relies on I8),
else `LO_BAD_PREREQ_MAPPING`. 4. **Hint coverage** — every ErrorType but `none-of-these` has a full tier list (a `none-of-these` entry is optional; when present it is the node's generic hint), else `LO_HINT_TIER_MISSING`. 5. **Probe checkability** — every ProbeItem answer re-derived by SymPy in the pipeline and every
WorkedExample step CAS-checked there (D41), else `LO_PROBE_UNCHECKABLE`; every `mc` item has ≥ 1
distractor tag and every tag names a member of the node's enum, else `LO_BAD_DISTRACTOR_TAG`.
5b. **Renderability** — every prompt, hint and explanation renders in SwiftMath, or is flagged for the
KaTeX fallback per item, else `LO_ITEM_UNRENDERABLE`. 5c. **Landmarks** — `source_url` present and
resolving at build (HTTP 2xx), `node_ids[]` non-empty and known, else `LO_LANDMARK_UNSOURCED` (D22,
I15). 6. **No verbatim text** — Explanations and landmark text screened (I6).
**Post:** pass → an immutable versioned bundle; fail → a report naming every failing node; one pass, so
it terminates. **No human review step is ever inserted (I9, D12, D13);** the Owner accepts or rejects the
bundle whole.

### W2 — Serve a hint (runtime)

**Pre:** diagnosis holds a node id and a classified ErrorType; bundle loaded.
**Steps:** 1. Resolve `(node, error_type) → tiers`; a miss raises `LO_HINT_NOT_FOUND` (internal data) and the
diagnosis event falls back to the node's generic tier-1 hint, `hint_tree["none-of-these"][0]`, else the
node's `paraphrase`; never another ErrorType's hint (I2). 2. Tiers issue one at a time on request. 3. Tier 1 may
re-word; below threshold or on adapter failure the stored wording is used (Tier 0 fallback, I2).
**Post:** the served tier index returns to the diagnosis event; the tier list is finite, so it ends.

### W3 — Draw a probe

**Pre:** diagnosis holds a hypothesis naming a probe target node (2 items), or expedition names a
frontier node for one slot (1 item).
**Steps:** 1. Select the items from that node's pool, preferring items unused in recent runs.
2. Return them, answer keys held by `Core`'s checker, never by the view. 3. Fewer than requested →
`LO_PROBE_POOL_EMPTY`; diagnosis skips the probe (hypothesis unconfirmed); expedition skips the node.
**Post:** items issued, or a skip. Tier 0 only — no model picks probe items.

## UI surfaces

None owned here; content appears in expedition (items), diagnosis (hints, remediation) and map (node
and landmark panels). Confirmed by the Demo.

## Notifications produced

- `learning_objects.bundle_loaded` — versions, node and landmark counts. Consumers: expedition,
  diagnosis, map, platform.
- `learning_objects.bundle_validation_failed` — version, failing node ids, codes. Consumer:
  content-generation (offline).
- `learning_objects.hint_tier_served` — node, error type, tier index, re-worded flag. Consumer:
  diagnosis.

## Errors produced

| Code | When it fires | User sees | Recoverable |
|---|---|---|---|
| `LO_INCOMPLETE_BUNDLE` | Node without a LearningObject, or vice versa | Internal | Yes, regenerate |
| `LO_BAD_PREREQ_MAPPING` | Mapping target is not upstream | Internal | Yes |
| `LO_HINT_TIER_MISSING` | ErrorType lacks a complete tier list | Internal | Yes |
| `LO_PROBE_UNCHECKABLE` | Answer not re-derivable by SymPy in the pipeline | Internal | Yes |
| `LO_BAD_DISTRACTOR_TAG` | An `mc` item lacks tags, or a tag is off-enum | Internal | Yes |
| `LO_ITEM_UNRENDERABLE` | Prompt, hint or explanation fails SwiftMath and is not flagged for fallback | Internal (rendering-spike report) | Yes — rewrite notation or flag |
| `LO_LANDMARK_UNSOURCED` | `source_url` missing or not resolving; no node ids | Internal; landmark dropped (I15) | Yes — re-source, never invent |
| `LO_HINT_NOT_FOUND` | Runtime lookup miss | Generic node hint | Yes; degrades, never blocks |
| `LO_PROBE_POOL_EMPTY` | Fewer usable ProbeItems than requested | Probe or slot skipped | Yes |

## Invariants enforced here

- **I9 (zero human content review)** — primary owner. Acceptance has two states, pass and fail; no
  reviewer appears in the actor table and no workflow admits one. A spec adding a review gate is BLOCKed.
- **I6** — W1 step 6, and an Explanation schema with no field for quoted text.
- **I2** — hints are usable as stored text; Tier 1 re-wording is cosmetic, with a stored fallback.
- **I3** — negative: a spec making hint tiers a precondition for the answer is BLOCKed.
- **I1** — ProbeItem answers are re-derived by SymPy at validation and checked in code on the device, so
  no probe needs a model to grade it. **I10** — item types are `numeric | mc` only; the schema has no
  free-text answer. **I15** — W1 step 5c; the Landmark type has a non-optional `source_url`.

## Open questions

**Q1 — Number of hint tiers.** **Default:** [ESTIMATE: three] (nudge → targeted → worked step), fixed for all nodes.
**Trade-off:** predictable generation and UI; a hard node earns no extra depth.
**Ratified 2026-09-08:** default accepted.

**Q2 — ProbeItem pool size per node.** **Default:** 6 [ESTIMATE: three non-overlapping probes, at 2 per
probe and ≤2 backtracks per session (I4)]. **Trade-off:** bigger pools cost bundle size and dilute
per-item statistics; smaller ones make repeats recognisable.
**Ratified 2026-09-08:** default accepted. *v2 note:* expeditions now also draw from the pool (one per
slot), so repeat rates rise; re-measure at M5 before changing the size.

**Q3 — May a hint tier reveal the final answer?** **Default:** yes at tier 3, which works the *failing
step* through, not the whole solution; it costs nothing, as D5/I3 make the answer available anyway.
**Trade-off:** the tree cannot become a gate, but tier 3 may duplicate the answer view.
**Ratified 2026-09-08:** default accepted.

**Q4 — Downstream handling of `none_of_these`.** **Default:** abstention, not diagnosis — no hypothesis,
no probe, no backtrack; diagnosis shows the answer (in homework mode also the failing-step location), records the outcome,
and per-node frequency reaches telemetry as evidence the enum is incomplete. **Trade-off:** such a session
ends with a located error and no explanation, but a fallback hypothesis would be a guess.
**Ratified 2026-09-08:** default accepted.


## Change log

| 2026-09-08 | Drafted (Phase 3b). |
| 2026-09-08 | Phase 3b consistency fixes (event consumers aligned with telemetry's four event kinds). |
| 2026-09-08 | Open questions ratified by owner (all defaults; see docs/plans/phase3b-open-questions.md). |
| 2026-09-09 | v2 re-cut: ProbeItem typed `numeric | mc` with distractor `ErrorType` tags, `why`, SymPy verification in the pipeline (D41) and SwiftMath renderability; Landmark entity and validation (D22, I15); consumers renamed (expedition, diagnosis, map); milestone M6 → M5. Q2 carries a v2 note; no new open questions. |
| 2026-09-10 | Catalogue id spelled `none-of-these`; W2 generic hint defined (arbiter-04-hint-fallback-reconciliation). |
