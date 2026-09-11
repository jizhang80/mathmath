# Domain — diagnosis

Prefix: `DIAG` (session codes `SESSION_*` from the v1 `tutoring-session` domain are retired). Layer ④
(brief §4.1). Ground truth: `PROJECT-BRIEF-v2.md` + amendments; invariants I1–I15 in `CLAUDE.md`.
Supersedes `tutoring-session` (v1): same hypothesis → probe → remediation → return machine, now an
**in-map event** rather than the main flow (D4 as amended).

## Purpose

Door A. When movement is blocked — a second miss on a node in an expedition (D27), or the student taps
"Check me here" on a fogged or blocked node (D28's way in) — this domain forms a hypothesis ("this may be
blocked by **X** upstream"), confirms it with a ~60-second probe on X [SOURCED: brief §7], remediates the
minimum piece, and returns to where the student was. A hypothesis is never a verdict (D11); the system never
guesses (I2); backtrack is ≤ 2 levels per session (I4) and anything deeper is marked `blocked` on the map
only. It owns no mathematics and no content, deferring to **concept-graph** (the query), **learning-objects**
(items, hints, remediation), **runtime-tiers** (Tier 1 wording), **expedition** (state). Milestones **Demo**
(cap = 1 level, hand-specified upstream hint), **M3**, **M4**; the **homework-mode variant** (§ below) is
desktop web at **M5**.

## Actors and roles

| Actor | Can do here | Cannot |
|---|---|---|
| Student | Take or decline the probe; ask for the next hint; return | Edit a `Diagnosis`; skip the answer (I3) |
| Owner | Product-test "a wrong hypothesis costs one minute and no trust" (§7) | Review content (I9) |
| System | Run the machine; query concept-graph; draw items; enforce the cap; report outcomes to expedition | Decide correctness by model (I1); use an off-catalogue `ErrorType` |
| Local model (Tier 1, iOS 26+) | Re-word a hint; classify an optional free-text "what I did" line (Q1) | Touch correctness (I1); alone justify a diagnosis (I2) |
| Generation model | No role at runtime | Anything |

## Core entities

- **DiagnosisEvent** — one Door A occurrence: the origin node, the trigger (`expedition_second_miss` |
  `map_check_here` | `homework_first_failure` at M5), the failed `ItemResult`s, the backtrack budget
  (I4: ≤ 2 levels; the Demo caps at 1), and an outcome `refuted` | `confirmed` | `unconfirmed` | `capped`.
  It always terminates and always returns the student to the origin.
- **Diagnosis** — the hypothesis: a candidate upstream `Node` (concept-graph W3) plus the `ErrorType`
  implying it, where one exists (Q1). Tier 0 forms it deterministically; Tier 1 may only add wording or a
  classification of volunteered text, never `confirmed` without a `ProbeRun`.
- **ProbeRun** — 2 `ProbeItem`s on the candidate, ~60 s [SOURCED: brief §2, §7], numeric or
  multiple-choice (I10), checked in code (I1); pass/fail; declinable (Q2).
- **Remediation** — the minimal piece for a confirmed gap: one `Explanation` or `WorkedExample` from
  **learning-objects** — or, when the node carries neither, its `paraphrase` plus, when one resolves, one tier-1 hint (DEMO-BRIEF §3.6) — then return.
- **Outcome record** — written into `StudentState` (**expedition**): the event, hypotheses and fates, probe
  results, nodes marked `blocked`. There is no separate record page (v2.5 §3).

Referenced elsewhere: **Node**, **Edge**, **Confidence** (concept-graph); **ProbeItem**, **HintTree**,
**ErrorType**, **Explanation**, **WorkedExample** (learning-objects); **StudentState**, **ItemResult**
(expedition); **ClassificationResult**, **FallbackDecision** (runtime-tiers); **MapViewModel** (map).

## Workflows

### W1 — Open a diagnosis event
**Pre:** `expedition.diagnosis_requested` (D27) or `map.check_here_requested` (D28). **Steps:** 1. Create
the `DiagnosisEvent` with the origin node and budget. 2. (Tier 0) Classify the miss deterministically:
the failed items' `distractor_error_types` (learning-objects) name an `ErrorType` when the wrong answer
matches a tagged distractor; otherwise `none_of_these` (abstention). 3. Show the **hypothesis card**:
"This may be blocked by **X**" (W2) — or, on `none_of_these` with no candidate, a tier-1 hint on the origin
and return (W5). **Post:** `diagnosis.opened` emitted.

### W2 — Form the hypothesis
**Pre:** an event with budget left. **Steps:** 1. (Tier 0) Query **concept-graph** W3 for the deepest
unmastered prerequisite within the remaining levels, biased by the `ErrorType`'s `implies_prerequisite`
when present; unknown counts as a candidate (graph Q2). 2. In the Demo, the candidate is the node's
hand-specified `upstream_hint` — no inference (DEMO-BRIEF §3.6). 3. No candidate → `DIAG_NO_PREREQUISITE`;
show the origin's hint and return (W5). **Post:** a `Diagnosis`, never a verdict (D11);
`diagnosis.hypothesis_formed`.

### W3 — Probe the candidate
**Pre:** a `Diagnosis`; two items available. **Steps:** 1. State the cost up front ("two quick checks, about a
minute") and let the student decline (Q2). 2. Draw 2 `ProbeItem`s (learning-objects W3); fewer →
`DIAG_PROBE_UNAVAILABLE`, outcome `unconfirmed`, hint and return. 3. Check in code (I1); show each answer
with its why (D5). 4. Pass → `refuted`: "Not the issue — back to where you were", W5 with a tier-1 hint on
the origin. Fail → `confirmed`, W4. **Post:** `diagnosis.probe_completed` → expedition (state), telemetry
(L3: the edge, the upstream state, the downstream result — v2.5 §1).

### W4 — Remediate minimally and mark
**Pre:** a `confirmed` Diagnosis. **Steps:** 1. Mark the candidate `blocked` (`diagnosis.node_blocked` →
expedition W4; the map shows it). 2. Show exactly one `Remediation` piece for the candidate. 3. If budget
remains and the candidate itself has unmastered prerequisites, offer — not force — one more level (W2 on
the candidate); beyond the cap, W6. 4. Return (W5). **Post:** `diagnosis.remediation_shown`.

### W5 — Return
**Pre:** any terminal outcome. **Steps:** 1. Write the outcome record into `StudentState`. 2. Hand control
back: to the suspended expedition (its W3 step 2 continues) or to the map node panel. 3. Tier 1 (M4+) may
re-word the hint shown; below threshold or unavailable the stored wording stands (I2). **Post:**
`diagnosis.returned`; the event is closed.

### W6 — Enforce the backtrack cap
**Pre:** W2 or W4 would exceed 2 levels from the origin in this session (Demo: 1). **Steps:** no probe, no
remediation; the deeper candidate is marked `blocked` in `StudentState` and said plainly to be "further
upstream — it's on your map"; return. **Post:** `diagnosis.capped` (D4, I4).

### Homework-mode variant (M5, desktop web)
The same W2–W6 machine with a different W1: the student enters a problem and steps in a structured editor
(D9, I10); **verification** returns `StepVerdict`s and the `FirstFailure` by CAS (I1); the error is
classified against the node's catalogue (Tier 0 candidates the student picks; Tier 1 enum with threshold);
the answer is always shown with the diagnosis (D5, I3). Its screens are the v1 prototype's
`student-session-*` pages, kept as reference. Not part of the iOS app (D34).

### §7 acceptance stance
*Help, not accusation* (DEMO-BRIEF §7 item 5): the card names a node, not the student. *Confirmation, not
interrogation*: 2 items, the cost stated, declinable, unscored. *A wrong hypothesis costs a minute and no
trust*: the system owns the refutation and returns at once.

## UI surfaces

Native: **Hypothesis card** (W1–W2, a sheet over the expedition or map); **Probe** (W3, two items in the
expedition item view); **Remediation** (W4, one explanation or worked example, else the paraphrase and, when one resolves, one tier-1 hint); return is implicit (W5).
Confirmed by the Demo.

## Notifications produced

- `diagnosis.opened` — `{ origin_node, trigger }`; `diagnosis.hypothesis_formed` — `{ origin_node,
  candidate_id, level, error_type|null }`; `diagnosis.remediation_shown` — `{ node_id }`;
  `diagnosis.returned` — `{ origin_node, outcome }`. Consumers: **expedition**, **telemetry** (D40).
- `diagnosis.probe_completed` — `{ candidate_id, edge_id, pass|fail|declined }`. Consumers: **expedition**
  (state), **concept-graph** (local `ProbeStats`), **telemetry** (L3).
- `diagnosis.node_blocked` — `{ node_id, level }`. Consumers: **expedition** (W4), **map** (W6).
- `diagnosis.capped` — `{ origin_node, candidate_id, depth }`. Consumers: **expedition**, **map**.

## Errors produced

All recoverable; none blocks an answer (I3).

| Code | When | User sees | Recoverable |
|---|---|---|---|
| `DIAG_NO_PREREQUISITE` | No unmastered candidate within reach | "Nothing upstream to check — here's a hint." | Yes |
| `DIAG_PROBE_UNAVAILABLE` | Fewer than 2 items on the candidate | Probe skipped; outcome `unconfirmed` | Yes |
| `DIAG_STATE_WRITE_FAILED` | Outcome record could not persist | Banner; the event still returns | Yes |

## Invariants enforced here

- **I2 — co-owner with runtime-tiers.** The hypothesis path is model-free; W1's classifier is a lookup over
  tagged distractors; M3 is entirely Tier 0. A test runs every workflow with the adapter absent.
- **I4 — primary owner.** W6 checks the budget before any `ProbeRun` or `Remediation` exists; a property
  test asserts none beyond depth 2 and that every capped candidate reaches `StudentState` as `blocked`.
- **I3** — every terminal path shows the item answers already given (W3) and never gates them.
- **I1 / I10** — probe items are checked in code; no free-text answer field exists on the device path.
- **D27** — this domain is entered at most once per expedition; the guard is expedition's, asserted there.
- **I5** — outcome records carry ids, enums and booleans only.

Seams: expedition ↔ diagnosis (request in; `node_blocked`, `returned` out); map ↔ diagnosis ("check me
here" in; blocked markers out); concept-graph → diagnosis (W3 query); learning-objects → diagnosis (items,
hints, remediation, distractor tags); runtime-tiers → diagnosis (wording, optional classification);
diagnosis → telemetry (L3, D40); verification → diagnosis (M5 only).

## Open questions

**Q1 — Where does the `ErrorType` come from on a phone?** **Default:** from **distractor tagging** — at
generation each multiple-choice distractor and each anticipated numeric wrong answer carries an
`ErrorType` id (learning-objects), so a miss classifies by lookup (Tier 0). Tier 1 classification is
offered only over an optional, single-line "what did you do?" the student may type on the hypothesis card,
off by default until M4. **Trade-off:** deterministic and free, but only as good as the generated
distractors; the free-text path is the one place a phone diagnosis could use the model, and the one the
student can ignore.
**Ratified 2026-09-09:** default accepted.

**Q2 — May the student decline the probe?** **Default:** yes — outcome `unconfirmed`, a hint on the origin,
return; the run continues. **Trade-off:** keeps the probe a confirmation, not an interrogation; thins L3.
**Ratified 2026-09-09:** default accepted.

**Q3 — Is the second level offered or automatic?** **Default:** offered ("want to look one step further
upstream?"), never automatic, so a Door A event costs about a minute unless the student chooses more.
**Trade-off:** respects the 3-minute rhythm; a student who always declines never reaches a level-2 gap
except via the map's `blocked` marker.
**Ratified 2026-09-09:** default accepted.

**Q4 — Does "Check me here" on a node upstream of the marker count against the backtrack budget?**
**Default:** the tapped node is the origin; the budget counts from it. **Trade-off:** simple; a student can
walk arbitrarily far upstream one tap at a time, which is the D28 intent.
**Ratified 2026-09-09:** default accepted.

## Change log

| 2026-09-08 | Drafted as `tutoring-session` (Phase 3b). Open questions ratified (see docs/plans/phase3b-open-questions.md). |
| 2026-09-09 | Rewritten as `diagnosis` for v2: in-map event, D27/D28 entries, Tier 0 distractor classification, map as record; homework mode moved to an M5 variant. New open questions Q1–Q4 pending owner ratification; v1's Q1 (decline) carried as Q2, Q2 (none of these) folded into W1, Q3 (nagging) dropped with the session concept, Q4 (reload) moved to expedition Q6. |
