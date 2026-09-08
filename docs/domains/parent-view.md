# Domain — parent-view

## Purpose

A read-only, plain-language account of where the student is stuck, why, and whether they are
progressing (brief §2). It reads `SessionRecord` (owned by **tutoring-session**) and never writes it.

Milestone: **M5** (decomposition row 8; brief §8). D16 fixes the build point; release follows all
milestones, so nothing here gates M3.

The constraint that outranks every feature idea: this reads like a teacher's note, not a dashboard — no
percentages, scores or streaks. Each surface answers in sentences: what is the gap, what does it block,
what next.

## Actors and roles

| Actor | What they can do here | What they cannot |
|---|---|---|
| Parent | Open `/parent`, read status by course/strand, drill into a `Gap`, read `Trend` and `SuggestedAction` | Write, correct or delete session data; see the student's raw LaTeX input |
| Student | Open the same view (Q2 default: nothing hidden) | Edit or suppress what the parent sees |
| Owner | Product-test against the "teacher's note" criterion (brief §7) | Review or edit content (I9) |
| System | Derive `NodeStatus`, `Gap`, `Trend`, `SuggestedAction` from `SessionRecord` | Call a model — Tier 0 only here |

Every derivation is deterministic, so the domain is wholly Tier 0 and I2 holds by construction. The
**Local model** (Tier 1) and **Generation model** have no role here.

## Core entities

**NodeStatus** — one per `Node` (**concept-graph**) the student has met, in exactly one of five states:
*not seen*, *probed-pass*, *probed-fail*, *remediated*, *deeper-gap-recorded*. These follow the
interaction contract (brief §7): a passing probe means "not the issue"; a failing probe leads to minimal
remediation, which moves the node to *remediated* once the student returns to the main line.
*deeper-gap-recorded* is the D4/I4 case — the chain ran past the two-level cap, so the node was recorded,
not remediated. *not seen* is displayable: the view says "we have not got here yet" rather than implying
failure.

**Gap** — a confirmed or recorded unmastered prerequisite: a node in *probed-fail* or
*deeper-gap-recorded*, plus the downstream nodes and courses it feeds. That downstream set comes from `Edge`
(**concept-graph**) by walking outgoing edges and unioning the `courses[]` reached — the differentiator in
brief §1, "which downstream courses that node feeds". A `Gap` also carries the `ErrorType` ids
(**learning-objects**) that surfaced it, so the view can say *why*. `Confidence` (**concept-graph**) travels
with the claim: a low-confidence edge reads "may affect", a settled one "is needed for".

**Trend** — across sessions: gaps closed, gaps still open, recurring `ErrorType` ids (same id in ≥ 2
sessions [ESTIMATE: smallest count separating a pattern from a slip]). Recomputed on read; not cached.

**SuggestedAction** — one plain-language next step ("practise exponent laws with them this week", "ask the
teacher about factoring in MPM2D"). In MVP these come from a fixed template table keyed by (`NodeStatus`,
recurrence, downstream-course presence) and filled with node `paraphrase` and course names — not from a
model. That keeps the domain Tier 0, and I6 intact since `paraphrase` is the project's own text.

**ParentSummary** — the read model for one render: `NodeStatus` grouped by `Course` and `Strand`
(**curriculum-spine**), the open `Gap` list, the `Trend`, and up to three `SuggestedAction`s. Derived, never
persisted; this domain owns no store. Grouping is course-first, then strand, matching how a report card
reads.

## Workflows

### W1 — Open the parent view
**Pre:** the browser profile holds ≥ 0 `SessionRecord`s; no login exists (D19).
**Steps:** 1. Platform resolves the route and opens the `Store` (seam **platform↔all**). 2. Read all
`SessionRecord`s (seam **tutoring-session↔parent-view**, read-only). 3. If zero, render the empty state and
stop. 4. Otherwise derive `NodeStatus` per touched node, then `ParentSummary`. Tier 0.
**Post:** `ParentSummary` rendered; nothing written; `parent.summary_viewed` emitted.

### W2 — Read status by course and strand
**Pre:** W1 done. **Steps:** 1. Group `NodeStatus` by `Course` then `Strand` (**curriculum-spine**).
2. Render one sentence per strand, worst state first, suppressing strands that are entirely *not seen*.
Tier 0. **Post:** no state change.

### W3 — Drill into a gap
**Pre:** a `Gap` is displayed. **Steps:** 1. Read the node's `paraphrase` and expectation codes
(**curriculum-spine**) with the official link (I6). 2. Read outgoing `Edge`s for the downstream course
list, annotated by `Confidence`. 3. Read the evidence: the problem that surfaced it, the `ErrorType`, the
probe outcome. 4. Render the matching `SuggestedAction`. Tier 0.
**Post:** no state change; `parent.gap_opened` emitted.

### W4 — See the trend
**Pre:** ≥ 2 `SessionRecord`s. **Steps:** 1. Order records by day. 2. Compute closed gaps, open gaps and
recurring `ErrorType` ids. 3. Render as prose. With < 2 records, render "not enough sessions yet" and stop.
Tier 0. **Post:** no state change; `parent.trend_viewed` emitted.

### W5 — Clear history
**Pre:** parent view open. **Steps:** 1. Parent confirms a plain-language dialog explaining that this
permanently deletes all locally stored session history, and that `ProbeStats`/telemetry data already sent
is anonymous, aggregate and cannot be recalled or affected by this action. 2. `parent-view` emits
`parent.history_clear_requested`. 3. `tutoring-session` deletes all `SessionRecord`s and `Attempt`s and
emits `session.history_cleared`. Tier 0. **Post:** the parent view shows an empty state; `ProbeStats` and
any telemetry already sent are unaffected, as stated in the dialog.

## UI surfaces

- `/parent` — summary (W1, W2); also hosts the clear-history action and its confirmation dialog (W5)
- `/parent/gap/:nodeId` — gap detail (W3)
- `/parent/trend` — trend (W4)

No `/student/...` route is added here. Paths are placeholders, confirmed in Phase 4.

## Notifications produced

- `parent.summary_viewed` — record count, open-gap count.
- `parent.gap_opened` — node id.
- `parent.trend_viewed` — session-count bucket.
- `parent.history_clear_requested` — nothing but the request itself. Consumer: **tutoring-session**
  (deletes all `SessionRecord`s and `Attempt`s, W5).

## Errors produced

- `PARENT_NO_SESSIONS` — zero `SessionRecord`s. User sees an empty state saying a session must run first.
  Recoverable.
- `PARENT_RECORD_UNREADABLE` — a record fails schema validation (older bundle). User sees "some earlier
  sessions could not be read"; the rest render. Recoverable.
- `PARENT_NODE_NOT_IN_GRAPH` — a recorded node id is absent from the installed graph bundle. Internal;
  the node is omitted. Recoverable.
- `PARENT_STORE_UNAVAILABLE` — IndexedDB unavailable. User sees the platform limited page. Not
  recoverable here.

## Invariants enforced here

- **I4** — the destination half of "deeper gaps go to the record and parent view only". Mechanism:
  *deeper-gap-recorded* is a first-class `NodeStatus` state, and a test asserts a record containing a
  deeper gap renders in `ParentSummary` with no remediation affordance.
- **I5** — mechanism: `ParentSummary` carries no free text sourced from student input; a schema test
  rejects student-authored LaTeX reaching any parent-facing type.
- **I6** — mechanism: gap detail renders `paraphrase` + code + outbound link; a test asserts no
  expectation-text field is read.
- Secondary: **I2** holds trivially (no model calls).

## Open questions

**Q1 — Access control on a shared device.** Default: a separate `/parent` route, no PIN.
Trade-off: a PIN is a credential, D19 rules out accounts, and it fails open on a family machine anyway —
but without one a student can keep a session unseen by not mentioning the route.
**Ratified 2026-09-08:** default accepted.

**Q2 — Can the student see the parent view?** Default: yes, nothing hidden.
Trade-off: transparency avoids two contradictory accounts of one session, but rules out franker
parent-only wording.
**Ratified 2026-09-08:** default accepted.

**Q3 — `SessionRecord` retention window.** Default: unbounded, local only (D19).
Trade-off: a long history makes `Trend` better and costs few bytes, but keeps an indefinite record of a
child's mistakes, with no delete affordance yet designed.
**Ratified 2026-09-08:** unbounded local retention PLUS an explicit clear-history action.

**Q4 — Export or print for a teacher meeting?** Default: none in MVP.
Trade-off: export makes "ask the teacher about Y" actionable, but is the first artefact that could carry
data off-device — D17/D19 territory needing its own decision.
**Ratified 2026-09-08:** default accepted.

**Q5 — `SuggestedAction` from templates only?** Default: yes, no model here.
Trade-off: templates are deterministic, testable and free, but read repetitively over many sessions; Tier 1
rewording would help, at the cost of a model on a parent-facing path.
**Ratified 2026-09-08:** default accepted.

## Change log

| 2026-09-08 | Drafted (Phase 3b). |
| 2026-09-08 | Phase 3b consistency fixes (event consumers aligned with telemetry's four event kinds). |
| 2026-09-08 | Open questions ratified by owner (all defaults; see docs/plans/phase3b-open-questions.md). Q3 ratified as unbounded retention plus an explicit clear-history action; added W5 — Clear history and `parent.history_clear_requested`. |
