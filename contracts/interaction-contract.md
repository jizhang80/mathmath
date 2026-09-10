# Contract: Interaction contract — three doors over one base

**Contract version:** v0.9.2 (discovery zone — finalized just-in-time by the Demo EPIC) · Source: brief v2
§7, D23, D27, D44–D48, v2.7 §3; `map.md`, `expedition.md`, `diagnosis.md`; v0.9.1 adds the numeric
normalisation rule (expedition Q4), the `remediated(p)` predicate and its two ripples (arbiter Q-A,
`tasks/arbitration/arbiter-02-predispatch.md`), the `past_last_unit` marker text (arbiter Q-F), and the
probe "available" definition (arbiter Q-G); v0.9.2 resolves the marker-drag finalization item (arbiter Q-B,
`tasks/arbitration/arbiter-03-predispatch.md`)

> The three doors as state machines with named states, events and guards, so `Core` implements them as
> pure transition functions and `CoreTests` proves the properties. Screens are in the domain docs; this
> file fixes the behaviour. Ratified open-question defaults are folded in as rules.

## 1. Mastery (per node, in `StudentState`)

States `fog → cleared`, `fog → blocked`, `blocked → cleared`, `cleared` stays `cleared` (map Q1: fog never
returns). Transitions:

| From | Event | Guard | To | Side effects |
|---|---|---|---|---|
| fog / blocked | `item_correct(node)` | `correct_count + 1 ≥ 2` on **distinct items** (expedition Q1) | cleared | `next_due = today + ladder[0]`, `ladder_rung = 0`, emit `node_cleared`, remove `remediated` |
| fog / blocked | `item_correct(node)` | otherwise | same | `correct_count += 1` |
| cleared | `item_correct(node)` (review) | — | cleared | `ladder_rung += 1`, `next_due = today + ladder[rung]` |
| cleared | `item_miss(node)` (review) | — | cleared | `ladder_rung = 0`, `next_due = today + ladder[0]`; tolerance per §2 |
| fog | `diagnosis_blocked(node)` | — | blocked | emit `node_blocked` |

Ladder = `[1, 3, 7, 14, 30]` days [ESTIMATE: expedition Q2]; the last rung repeats.

## 2. Expedition (Door B)

States: `idle → composing → item → (retry | diagnosing | item) → summary → idle`.

- `compose` (D48, D45, D46, v2.7 §3): fringe = `{n : mastery(n) ≠ cleared ∧ ∀ p ∈ prereq(n): mastery(p) =
  cleared ∨ (mastery(p) = blocked ∧ remediated(p))}` ∩ (nodes of `marker.unit ∪ next(marker.unit)`, or the
  requested unit only) ∪ `{n : mastery(n) = blocked}`. Slots = up to 5: map-queued node first (map Q5, if on
  the fringe), then fringe nodes in trail order, then due cleared nodes (`next_due ≤ today`, oldest
  `last_probe` first), **≤ 2 review slots** (expedition Q3). Empty → `EXP_NO_FRINGE`.
  `remediated(p)` ≡ `nodes[p].remediated == true` (`data-model.md` § StudentState; absent = false).
- `answer(item)`: deterministic check (expedition Q4: normalised exact match, per-item tolerance; `mc` by
  choice id); always show correct answer + `why` (I3); log `probe_log`; emit `item_answered`.
- **Numeric normalisation (expedition Q4):** a submitted numeric answer and the item's `answer.value`
  (`data-model.md` § ProbeItem) are each parsed under the same grammar before comparison: an optional
  leading sign (`+` or `-`; absent = positive), one or more digits, an optional `.` followed by one or
  more digits, and an optional `/` followed by one or more digits (a rational `a/b`, `b ≠ 0`); leading and
  trailing whitespace is stripped and has no other effect. A string that does not parse under this
  grammar is a **miss** — never a crash, never a retry that skips its item. Every value that parses is
  reduced to an **exact rational**: leading zeros in the integer part (`007`) and trailing zeros after
  the decimal point (`0.750`) carry no significance; a decimal parses to its exact fraction (`0.75 =
  3/4`). Two parsed values match iff their exact-rational values are equal, or their absolute difference
  is ≤ the item's `answer.tolerance` (non-negative, default `0`, per `data-model.md` § ProbeItem).
  Comparison is exact-rational arithmetic; no floating-point comparison is used anywhere in this rule
  (I1). This is the entire `numeric`-item rule; `mc` items are compared by `choices[].id` only, never by
  value (I10).
- **Tolerance (D27):** first miss on a node in this run → `retry` with a second item of the same node; second
  miss → if `diagnosis_used == false` → `diagnosing` (set `diagnosis_used = true`), else mark the node
  `blocked` (expedition Q5: "We'll come back to this one") and continue. **At most one diagnosis per run.**
- `end`: summary; log entry; a run left mid-way is `abandoned` (expedition Q6), never resumed item-by-item.

**Properties (CoreTests):** never draws a new-learning item off the fringe or upstream of the marker unless
the node is `blocked`; never more than one diagnosis event per run; never more than 2 review slots; every
item shown ends with its answer visible.

## 3. Marker and trail (D45, D47)

- `set_marker(course, unit)` → regenerate trail → recompute fringe. Marker default = first unit of the
  selected course. Nodes upstream of the marker keep their mastery.
  The marker is past the course's last unit iff `marker.past_last_unit == true`, whichever unit `unit_id`
  names; setting it writes the course's last unit as `unit_id`. While past the last unit, the
  `marker.unit ∪ next(marker.unit)` window of §2 `compose` is the nodes of the `extension` segment (empty
  when there is none). Nodes of the course are then upstream of the marker. A marker whose `course_code` is
  not in `syllabi[]`, or whose `unit_id` is not a unit of that course in the bundle, is off the trail
  (`MAP_MARKER_OFF_TRAIL`, default marker) regardless of `past_last_unit`.
- `generate_trail`: course segments in unit order; if the marker is past the course's last unit, an
  `extension` segment along downstream edges preferring `next_courses[]`, then undergraduate nodes; every
  segment a path (L0-T) else `EXP_TRAIL_INVALID` and the previous trail stands.
- The marker is set only by choosing an entry from the selected course's unit list: one entry per unit in
  unit order, then a final "past the last unit" entry (`past_last_unit: true`). No gesture moves the marker;
  there is no drag and no snap. A unit-list choice is never off the trail.

## 4. Diagnosis (Door A)

States: `opened → hypothesis → (probe | hint) → (remediation | hint) → returned`, with `capped` as a
terminal branch.

- `open(origin, trigger ∈ {expedition_second_miss, map_check_here})`; `level = 0`; budget 2 (Demo: 1).
- `classify`: distractor-tag lookup over the failed items → `error_type` or `none_of_these` (diagnosis Q1);
  Tier 1 may *suggest* from the optional typed line (runtime-tiers), never decides.
- `hypothesise`: candidate = deepest unmastered prerequisite within remaining levels (graph query), biased by
  `implies_prerequisite`; none → `DIAG_NO_PREREQUISITE` → hint → returned.
- `probe` (declinable, diagnosis Q2): 2 items on the candidate; `pass` → `refuted` → hint on origin →
  returned; `fail` → `confirmed` → candidate `blocked`, one remediation piece, candidate `remediated =
  true` once that piece is shown; `declined` → `unconfirmed` → hint → returned. Fewer than 2 items →
  `DIAG_PROBE_UNAVAILABLE` → `unconfirmed`. An item is *available* for the probe iff it belongs to the
  candidate and its answer has not been shown in the current expedition run (trigger
  `expedition_second_miss`); under `map_check_here` every item of the candidate is available. Among
  available items the draw order of learning-objects W3 applies.
- After `confirmed`, a further level is **offered, never automatic** (diagnosis Q3); beyond the budget →
  `capped`: candidate `blocked`, "further upstream — it's on your map", returned (I4).
- `returned` always hands control back to the suspended expedition (its next item) or the map node panel.

**Properties (CoreTests):** depth ≤ 2 from origin; every capped or failed candidate is `blocked` in state;
no path reaches `remediation` without a `fail` probe outcome; no path withholds an already-answered item's
answer (I3); Tier 0 completes every path with the adapter absent (I2).

## 5. Notifications (in-process names, exact)

`map.opened · map.node_opened · map.region_opened · map.landmark_opened · map.marker_moved ·
map.check_here_requested · map.include_requested · map.unit_expedition_requested · expedition.started ·
expedition.item_answered · expedition.diagnosis_requested · expedition.node_cleared · expedition.node_due ·
expedition.marker_changed · expedition.trail_generated · expedition.completed · diagnosis.opened ·
diagnosis.hypothesis_formed · diagnosis.probe_completed · diagnosis.node_blocked · diagnosis.capped ·
diagnosis.remediation_shown · diagnosis.returned · platform.launched · platform.content_updated ·
platform.state_migrated · platform.state_written · platform.sync_completed ·
platform.sync_conflict_merged · platform.capability_facts · platform.connectivity_changed ·
tier.capability_detected · tier.classification_returned · tier.fallback_decided · tier.wording_adapted ·
telemetry.consent_changed · telemetry.batch_sent · telemetry.batch_failed · learning_objects.bundle_loaded ·
learning_objects.hint_tier_served · graph.prerequisite_returned`

Payloads are ids, enums, booleans and small integers only (I5).

## Finalization owed by the Demo EPIC
The timing of the answer card; whether the summary shows region tint deltas. Bump to v1.0.0 on wrap.
(Resolved in v0.9.2: the marker is set from the unit list only — § 3; no drag.)
