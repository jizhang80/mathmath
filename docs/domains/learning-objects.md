# Domain — learning-objects

Prefix: `LO`. Layer ③ (brief §4.1). Ground truth: `PROJECT-BRIEF-v1.md`, invariants I1–I13.

## Purpose

Owns what a node needs to be *taught*, once concept-graph has said *which* node is at issue: per Node
(concept-graph) an Explanation, WorkedExample(s), a closed ErrorType enum, a HintTree keyed by ErrorType,
and a ProbeItem pool — static assets generated offline (brief §4.1 ③), read at runtime by
tutoring-session. Nothing is computed live and no model runs here. Milestones **M2, M3, M6**; M3 is
load-bearing, as the Tier 0 prototype needs hints and probes with no model.

One asset is structure, not prose: the **implies-prerequisite mapping** (per ErrorType, whether it points
at an upstream node), which turns "error classified" into "hypothesis presented" (brief §7).

**Seam — learning-objects↔tutoring-session:** two synchronous Tier 0 lookups only,
`(node, error_type) → hint tiers` (W2) and `node → 2 ProbeItems` (W3). tutoring-session never reads the
bundle directly, nor caches hint text across versions.

## Actors and roles

| Actor | What they can do here | What they cannot |
|---|---|---|
| Student | Read explanations, examples, hints; answer ProbeItems, via tutoring-session | See enum internals, the mapping, answer keys |
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
sequence on the student-input path (D9, I10), each step checkable by verification.

**ErrorType** — a member of the node's closed catalogue (brief §5 `error_catalogue[]`): per-node, with
exactly one terminal `none_of_these`. Canonical example, the M4′ node *logarithmic equation solving*, six
members verbatim from brief §8 — missed domain restriction; log-combination rule misapplied;
exponent–log inverse relationship not internalised; quadratic solved incorrectly; arithmetic slip; none of
these. Each has a stable id, a student-facing phrasing, a `probe_target`, and `implies_prerequisite`:
`null`, or an upstream Node id — **the implies-prerequisite mapping**. Above, the exponent–log type points
at the exponential-functions node of the D14 chain, "arithmetic slip" nowhere, and `none_of_these` is
always `null`: abstention, not diagnosis.

**HintTree** — per node, ErrorType → ordered tiers: tier 1 nudges at what to look at, tier 2 targets that
ErrorType, tier 3 works the failing step through. Answers are never withheld (D5, I3), so the tree gates
nothing: it exposes the *reason* for the failure. Tier order and semantics are fixed at generation.

**ProbeItem** — a short item tagged with a node id, answer in LaTeX, required CAS-checkable by
verification, with no grader model and no free text. Two drawn per probe [SOURCED: brief §2, §7].

## Workflows

### W1 — Validate and version a bundle (offline)

**Pre:** a Graph bundle that passed L0 (I8) and candidates from content-generation — independent
GenerationRuns against the **Generation model** (offline Claude API), intersected there. Validation is
Tier 0.
**Steps:** 1. **Coverage** — one LearningObject per Node, none naming an unknown node, else
`LO_INCOMPLETE_BUNDLE`. 2. **Enum closure** — each enum non-empty, exactly one `none_of_these`.
3. **Mapping validity** — every non-null `implies_prerequisite` is an upstream neighbour (relies on I8),
else `LO_BAD_PREREQ_MAPPING`. 4. **Hint coverage** — every ErrorType but `none_of_these` has a full tier
list, else `LO_HINT_TIER_MISSING`. 5. **Probe checkability** — every ProbeItem answer and WorkedExample
step must parse and be CAS-decidable by verification, else `LO_PROBE_UNCHECKABLE`. 6. **No verbatim
text** — Explanations screened (I6).
**Post:** pass → an immutable versioned bundle; fail → a report naming every failing node; one pass, so
it terminates. **No human review step is ever inserted (I9, D12, D13);** the Owner accepts or rejects the
bundle whole.

### W2 — Serve a hint (runtime)

**Pre:** tutoring-session holds a node id and a classified ErrorType; bundle loaded.
**Steps:** 1. Resolve `(node, error_type) → tiers`; a miss raises `LO_HINT_NOT_FOUND` and the session
falls back to the node's generic tier-1 hint. 2. Tiers issue one at a time on request. 3. Tier 1 may
re-word; below threshold or on adapter failure the stored wording is used (Tier 0 fallback, I2).
**Post:** the served tier index returns for the Attempt record; the tier list is finite, so it ends.

### W3 — Draw a probe

**Pre:** tutoring-session holds a hypothesis naming a probe target node.
**Steps:** 1. Select 2 ProbeItems from that node's pool, preferring items unused in this Session.
2. Return them, answer keys withheld from the UI and passed to verification. 3. Fewer than 2 usable →
`LO_PROBE_POOL_EMPTY`; the session skips the probe, hypothesis unconfirmed.
**Post:** two items issued, or a skip. Tier 0 only — no model picks probe items.

## UI surfaces

None owned here; content appears in tutoring-session surfaces (`/student/session/...`). Phase 4 confirms.

## Notifications produced

- `learning_objects.bundle_loaded` — versions, node count. Consumers: tutoring-session, platform.
- `learning_objects.bundle_validation_failed` — version, failing node ids, codes. Consumer:
  content-generation (offline).
- `learning_objects.hint_tier_served` — node, error type, tier index, re-worded flag. Consumer:
  tutoring-session.

## Errors produced

| Code | When it fires | User sees | Recoverable |
|---|---|---|---|
| `LO_INCOMPLETE_BUNDLE` | Node without a LearningObject, or vice versa | Internal | Yes, regenerate |
| `LO_BAD_PREREQ_MAPPING` | Mapping target is not upstream | Internal | Yes |
| `LO_HINT_TIER_MISSING` | ErrorType lacks a complete tier list | Internal | Yes |
| `LO_PROBE_UNCHECKABLE` | Answer unparseable or not CAS-decidable | Internal | Yes |
| `LO_HINT_NOT_FOUND` | Runtime lookup miss | Generic node hint | Yes; degrades, never blocks |
| `LO_PROBE_POOL_EMPTY` | Fewer than 2 usable ProbeItems | Probe skipped | Yes |

## Invariants enforced here

- **I9 (zero human content review)** — primary owner. Acceptance has two states, pass and fail; no
  reviewer appears in the actor table and no workflow admits one. A spec adding a review gate is BLOCKed.
- **I6** — W1 step 6, and an Explanation schema with no field for quoted text.
- **I2** — hints are usable as stored text; Tier 1 re-wording is cosmetic, with a stored fallback.
- **I3** — negative: a spec making hint tiers a precondition for the answer is BLOCKed.
- **I1** — ProbeItems must be CAS-checkable at validation, so no probe needs a model to grade it.

## Open questions

**Q1 — Number of hint tiers.** **Default:** [ESTIMATE: three] (nudge → targeted → worked step), fixed for all nodes.
**Trade-off:** predictable generation and UI; a hard node earns no extra depth.
**Ratified 2026-09-08:** default accepted.

**Q2 — ProbeItem pool size per node.** **Default:** 6 [ESTIMATE: three non-overlapping probes, at 2 per
probe and ≤2 backtracks per session (I4)]. **Trade-off:** bigger pools cost bundle size and dilute
per-item statistics; smaller ones make repeats recognisable.
**Ratified 2026-09-08:** default accepted.

**Q3 — May a hint tier reveal the final answer?** **Default:** yes at tier 3, which works the *failing
step* through, not the whole solution; it costs nothing, as D5/I3 make the answer available anyway.
**Trade-off:** the tree cannot become a gate, but tier 3 may duplicate the answer view.
**Ratified 2026-09-08:** default accepted.

**Q4 — Downstream handling of `none_of_these`.** **Default:** abstention, not diagnosis — no hypothesis,
no probe, no backtrack; tutoring-session shows the answer and failing-step location, records the Attempt,
and per-node frequency reaches telemetry as evidence the enum is incomplete. **Trade-off:** such a session
ends with a located error and no explanation, but a fallback hypothesis would be a guess.
**Ratified 2026-09-08:** default accepted.


## Change log

| 2026-09-08 | Drafted (Phase 3b). |
| 2026-09-08 | Phase 3b consistency fixes (event consumers aligned with telemetry's four event kinds). |
| 2026-09-08 | Open questions ratified by owner (all defaults; see docs/plans/phase3b-open-questions.md). |
