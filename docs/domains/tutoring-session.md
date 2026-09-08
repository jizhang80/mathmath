# Domain — tutoring-session

## Purpose

The brief's §7 interaction contract — the one flow every milestone must preserve — as a state machine over
one sitting: entry → mapping → verification → localisation → classification → hint → hypothesis → probe →
remediation → return → record. It owns no mathematics and no content, deferring to `verification`,
`concept-graph`, `learning-objects`, `runtime-tiers`. Milestones **M3**, **M4** [SOURCED: brief §8].

## Actors and roles

| Actor | Can do here | Cannot |
|---|---|---|
| Student | Enter problem and steps; pick or confirm an error type; take or decline a probe; ask for the next hint | Edit a `StepVerdict` or `Diagnosis` |
| Parent | Read `SessionRecord` via `parent-view` | Act in a live session |
| Owner | Product-test the flow against §7 (M3) | Review content (I9) |
| System | Run the machine; call `verification`; query `concept-graph`; fetch `HintTree`/`ProbeItem`; enforce the cap | Decide correctness (I1); use an off-catalogue `ErrorType` |
| Local model (Tier 1) | Supply `ClassificationResult`, node mapping, rewording | Touch correctness (I1); alone justify a diagnosis (I2) |

## Core entities

- **Session** — one sitting in one browser profile, state local (D19): ordered `Attempt`s, the backtrack
  budget (I4: ≤ 2 levels), the consent snapshot.
- **Attempt** — one problem: mapped `Node`, the `Problem` with its `Step`s, `StepVerdict`s and `FirstFailure`
  (verification), hint tier, `Diagnosis` objects, outcome `resolved` | `answered` | `abandoned`; it always
  terminates, the answer shown at close (D5).
- **Diagnosis** — a hypothesis: a candidate upstream `Node` (concept-graph) plus the `ErrorType`
  (learning-objects) implying it; Tier 0 offers candidates the student picks, Tier 1 proposes one with a
  `ClassificationResult` confidence, never `confirmed` without a `ProbeRun`.
- **ProbeRun** — 2 `ProbeItem`s, ~60 s [SOURCED: brief §2, §7], pass/fail, plus an outcome.
- **Remediation** — the minimal piece for a confirmed gap: one `Explanation` or `WorkedExample`.
- **SessionRecord** — nodes, error types, hypotheses and fates, probe outcomes, backtrack depth, and deeper
  gaps **recorded but not remediated** (D4); read by `parent-view`. Deletion of `SessionRecord`s (and their
  `Attempt`s) is triggered only by `parent.history_clear_requested` (**parent-view**); nothing else in this
  domain removes them.

## Workflows

### W1 — Enter a problem and map it to a node
**Pre:** Session open, bundles loaded. **Steps:** MathLive → LaTeX only (I10, D9); *Tier 0:* menu Course →
Strand → Node [SOURCED: brief §4.2]; *Tier 1:* free text → `{node_id, confidence}`, above `Threshold`
pre-selecting that entry, below it a logged `FallbackDecision` and the menu (I2). **Post:** a mapped
`Attempt`; `session.attempt_started`.

### W2 — Verify steps and locate the first failure
**Pre:** Attempt with ≥ 1 `Step`. **No tier branch (I1).** **Steps:** `verification` returns a `StepVerdict`
per step and `FirstFailure` or none, no model participating; no failure closes via W7. **Post:**
`session.first_failure_located`.

### W3 — Classify the error
**Pre:** a `FirstFailure` on a node with a loaded `ErrorType` catalogue. **Steps:** *Tier 0:* offer the
catalogue as candidates, "none of these" included, the student's pick authoritative; *Tier 1:*
`{error_type ∈ enum, confidence}`, confirmed above `Threshold`, else a logged `FallbackDecision` and that
Tier 0 pick (I2). **Post:** `session.error_classified`.

### W4 — Deliver a tiered hint
**Pre:** a `FirstFailure`, an `ErrorType` or none. **Steps:** fetch the `HintTree` branch for
`(node, error_type)` else the generic one; show the lowest untried tier, next on request, the tree being
finite; *Tier 1:* rewording only, semantics fixed by `learning-objects`. **Post:** `session.hint_shown`.

### W5 — Form a hypothesis and run the probe
**Pre:** an `ErrorType` implying an upstream node, budget per W8. **Steps:** query `concept-graph` along that
`Edge` for the nearest unmastered prerequisite; create a `Diagnosis`, a hypothesis never a verdict (D11);
offer the `ProbeRun`, declinable (Q1); pass → `refuted`, "not the issue — back to the problem", W4; fail →
`confirmed`, W6; declined → `unconfirmed`. **Post:** `session.probe_completed`, feeding `ProbeStats`.

### W6 — Remediate minimally and return
**Pre:** a `confirmed` Diagnosis. **Steps:** show exactly one `Remediation` piece, then return to the Attempt
at its failing step — the main line is always the current problem (D4). **Post:** remediation logged.

### W7 — Close the attempt and persist
**Pre:** Attempt `resolved`, answer requested, or abandoned. **Steps:** render answer **and** diagnosis
together, never withheld and never bare (D5 / I3); update and persist `SessionRecord`, emitting to
`telemetry` only under consent (I5). **Post:** `session.attempt_closed`.

### W8 — Enforce the backtrack cap
**Pre:** any W5 entry. **Steps:** level ≤ 2 from the origin with budget left proceeds; otherwise no probe
and no remediation — the candidate goes to `SessionRecord` as a recorded-not-remediated gap, said plainly to
be for later, and W4 resumes (D4 / I4). **Post:** `session.backtrack_capped`.

### §7 acceptance stance (M3)
*Teacher not chatbot*: one thing at a time, no persona or filler. *Confirmation not interrogation*: 2 items,
the ~60 s cost stated up front, declinable, unscored. *A wrong hypothesis costs a minute and no trust*: the
system owns the refutation and returns at once.

## UI surfaces

`/student/session`, `/student/session/hint`, `/student/session/probe`, `/student/session/answer` (answer and
diagnosis together, D5), `/student/history`. Parent routes live in `parent-view`.

## Notifications produced

- `session.attempt_started`, `session.first_failure_located`, `session.hint_shown`,
  `session.remediation_shown`, `session.attempt_closed` (ids, node, tier, outcome)
- `session.error_classified` (error type, tier, fallback) → telemetry
- `session.probe_completed` (node, pass/fail/declined) → concept-graph, telemetry (consented)
- `session.backtrack_capped` (origin, candidate, depth), `session.record_updated` → parent-view
- `session.history_cleared` (triggered only by `parent.history_clear_requested`) → parent-view, platform

## Errors produced

All are recoverable; none blocks the answer.

- `SESSION_NODE_UNMAPPED` — W1 ends with no node; the menu is re-shown.
- `SESSION_VERIFICATION_UNAVAILABLE` — Pyodide worker not ready; retry offered, no diagnosis meanwhile.
- `SESSION_PROBE_UNAVAILABLE` — fewer than 2 `ProbeItem`s; the Diagnosis stays `unconfirmed` (I2).
- `SESSION_RECORD_WRITE_FAILED` — `Store` write failed; a banner only, the answer still shown (I3).

## Invariants enforced here

- **I3**, primary owner — W7's view model cannot exist with the answer absent; a test asserts every terminal
  state yields answer and diagnosis together.
- **I4**, primary owner — W8 checks the budget before any `ProbeRun` or `Remediation` exists; a property test
  asserts none beyond depth 2 and that blocked candidates reach `SessionRecord`.
- **I2**, co-owner with `runtime-tiers` — each tier branch (W1, W3, W4) has a Tier-0 path tested with
  adapters disabled; M3 is model-free.
- **I1**/**I5** negatively — no `ModelAdapter` touches a `StepVerdict`; state is local, emissions ids only.

**Seams:** verification↔ (`StepVerdict`/`FirstFailure`, W2); concept-graph↔ (prerequisite query, W5);
learning-objects↔ (`HintTree`/`ProbeItem`, W4/W5); runtime-tiers↔ (`ClassificationResult`/`FallbackDecision`,
W1/W3/W4); ↔telemetry (W7); ↔parent-view (W7); platform↔all.

## Open questions

**Q1 — May the student decline the probe?** **Default:** yes, Diagnosis `unconfirmed`, no remediation.
**Trade-off:** keeps the probe a confirmation; thins `ProbeStats`.
**Ratified 2026-09-08:** default accepted.

**Q2 — What happens on "none of these"?** **Default:** generic hint, no hypothesis, no probe.
**Trade-off:** no guessed diagnosis (I2), least help where the catalogue is weak.
**Ratified 2026-09-08:** default accepted.

**Q3 — Attempts before suggesting a stop?** **Default:** none, no nagging.
**Trade-off:** keeps teacher-not-chatbot; no fatigue signal.
**Ratified 2026-09-08:** default accepted.

**Q4 — Does a session survive a reload?** **Default:** yes, resume the last Attempt.
**Trade-off:** costs persisted intermediate state; losing work on refresh costs trust.
**Ratified 2026-09-08:** default accepted.

## Change log

| 2026-09-08 | Drafted (Phase 3b). |
| 2026-09-08 | Phase 3b consistency fixes (event consumers aligned with telemetry's four event kinds). |
| 2026-09-08 | Open questions ratified by owner (all defaults; see docs/plans/phase3b-open-questions.md). Added `session.history_cleared`, triggered only by parent-view's `parent.history_clear_requested` (W5 there). |
