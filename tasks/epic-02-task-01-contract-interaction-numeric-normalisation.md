# Epic 02 · Task 01: Contract v0.9.1 — numeric normalisation, `remediated`, `past_last_unit`, probe availability

---
epic: 02
task: 01
slug: contract-interaction-numeric-normalisation
kind: feat
risk: seam
depends_on: [none]
model: sonnet
---

## §1 Goal & acceptance criteria

Goal: bump `contracts/interaction-contract.md` from v0.9.0 to v0.9.1, landing six normative text edits in one
commit: (1) the numeric-answer normalisation rule this task itself owns (expedition Q4, ratified), which
must accept every numeric-answer form authored in `data/demo` and define tolerance application exactly; (2)
the `remediated(p)` predicate text and its two ripple edits, carrying out the arbiter's Q-A ruling; (3) the
`past_last_unit` marker text, carrying out the arbiter's Q-F ruling, itself carrying out the owner's Q5
ruling on I8's trail-path meaning only insofar as Q-F's own text references §2 `compose`'s window (no I8
text is edited by this task — that is task 02.3); (4) the probe "available" definition, carrying out the
arbiter's Q-G ruling; and (5) removal of the now-obsolete numeric-normalisation line from § Finalization
owed. This is a documentation-only, code-free change: no schema, no `Core` type, no pipeline module, no
`data/demo` file is touched.

Invariants in play:

- **I1** — the numeric normalisation rule this task writes is the exact, deterministic comparison
  `ItemChecker` (task 02.7) implements; it is exact-rational arithmetic, never floating-point, and no model
  is consulted anywhere in the rule.
- **I2** — not engaged: this task adds no model-calling path. Recorded so its absence is a decision, not a
  gap.
- **I3** — untouched by this task's edits; the existing `answer(item)` bullet's "always show correct answer
  + `why`" stands unedited.
- **I6** — not engaged: no Ministry text, no `paraphrase` field is touched.
- **I10** — the normalisation rule this task writes governs numeric input only; it adds no new input
  surface and no OCR path. `mc` items remain compared by `choices[].id` only, never by value (stated
  explicitly in the new text, §4 step 2 below).
- **I14** — the rule this task writes is implemented once, in `Core` (`ItemChecker`, task 02.7); this task
  supplies the contract text the implementation conforms to, not a second implementation.

Acceptance criteria (each independently verifiable):

- AC1: `contracts/interaction-contract.md`'s `Contract version` line reads `v0.9.1` and states, inline, what
  changed and why (the six edits below, each with its ruling reference), per the pattern §4 step 1 fixes.
  Instrument: `rg -n "Contract version" contracts/interaction-contract.md`.
- AC2: §2 Expedition carries a new, self-contained numeric-normalisation rule (own bullet, immediately after
  `answer(item)`) that normatively defines: optional leading sign; integer, decimal and rational `a/b`
  forms; whitespace insignificance; leading- and trailing-zero insignificance; exact-rational comparison
  (`3/4 = 0.75`); and tolerance application (`answer.tolerance`, non-negative, default `0`, per
  `data-model.md` § ProbeItem). Instrument: `rg -n "Numeric normalisation" contracts/interaction-contract.md`
  plus a manual read confirming every clause of §4 step 2's text is present verbatim.
- AC3: the rule of AC2 accepts, without ambiguity or special-casing, all three demo answer forms verified
  present in `data/demo/nodes.json` — rational `5/6` (`rational-numbers-1`), integer `32000`
  (`scientific-notation-1`), and the negative-integer form exemplified by `-6` in `factoring-1`'s
  `wrong_answers[]` (no demo item currently authors exactly `-10`, but the grammar must not special-case it
  out; §6 records this as a conditional). Instrument: manual trace — each of the three forms parses under
  the grammar of AC2 with no clause left unsatisfied.
- AC4: §2 `compose` bullet ends with the `remediated(p)` predicate sentence, verbatim per the Q-A ruling
  (§3 below). Instrument: `rg -n "remediated\(p\)" contracts/interaction-contract.md`.
- AC5: §1 Mastery's `fog / blocked | item_correct(node) | correct_count + 1 ≥ 2 … | cleared` row's side
  effects end with `, remove \`remediated\`` and no other row is touched. Instrument: `rg -n "remove
  \`remediated\`" contracts/interaction-contract.md` shows exactly one match, on that row.
- AC6: §3 `set_marker` bullet ends with the Q-F ruling's `past_last_unit` paragraph, byte-identical to
  `tasks/arbitration/arbiter-02-predispatch.md:191-196`. Instrument: `rg -n "past_last_unit == true"
  contracts/interaction-contract.md`.
- AC7: §4 `probe` bullet's `fail` clause reads `` `fail` → `confirmed` → candidate `blocked`, one
  remediation piece, candidate `remediated = true` once that piece is shown; `` (Q-A), and the bullet ends
  with the Q-G "available" paragraph, byte-identical to `tasks/arbitration/arbiter-02-predispatch.md:209-211`.
  Instrument: `rg -n "remediated = true|is \*available\*" contracts/interaction-contract.md`.
- AC8: § Finalization owed no longer contains the phrase "Exact item-normalisation rules for numeric
  answers"; the other three items in that sentence (unit-boundary snap, answer-card timing, summary region
  tint deltas) and the "Bump to v1.0.0 on wrap" sentence are otherwise untouched. Instrument: `rg -n
  "item-normalisation" contracts/interaction-contract.md` returns no match; `git diff` on that line shows
  only the one phrase removed.
- AC9: `git diff contracts/interaction-contract.md` touches only §0 (version line), §1 (one row), §2 (one
  appended sentence in `compose`, one new bullet), §3 (one appended paragraph), §4 (one clause edit, one
  appended paragraph), and § Finalization owed (one phrase removed) — no other line changes.

## §2 File scope

In-scope (the implementer touches EXACTLY this file; nothing else):

- `contracts/interaction-contract.md` — MODIFY. The six edits of §4 below. This is the only file this task
  may create or touch, per the task's own scoping ("File scope: `contracts/interaction-contract.md` only").

Out-of-scope (do not touch even if tempted):

- `contracts/data-model.md` — the `remediated` field's schema/type/data-model text belongs to task 02.2
  (Q-A ruling: "02.2 (schema/type)"), and its own `past_last_unit` schema text also belongs to 02.2 (Q-F
  ruling). This task writes no field, only the behavioural predicate that consumes it.
- `contracts/graph-constraints.md` — the L0-T trail-path rewrite from the owner's Q5 ruling
  (`tasks/blocked/Q5-RULING-02-QE.md`) belongs to task 02.3, dispatched concurrently. This task's §3 edit
  cites `compose`'s window but does not touch I8 or L0-T wording.
- `contracts/schemas/student-state.schema.json` — task 02.2's file (the `remediated` and `past_last_unit`
  schema properties).
- `Packages/Core/**` — no `Core` code exists yet for this rule; `ItemChecker` is task 02.7's file.
- `data/demo/**` — no data edit. The three demo answer forms cited in AC3 are read-only evidence that the
  rule already covers what is shipped; none of them needs to change to conform.
- `CLAUDE.md` — its I8 row is task 02.3's edit (per the Q5 ruling), not this task's.
- `pipeline/**` — this task has no executable surface; nothing under `pipeline/` changes or is tested by it.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/README.md` — heading `## Lock-first rule`:
  > `data-model`, `graph-constraints`, `content-policy`, `telemetry`, `domain-glossary`, `runtime-tiers` and
  > `deployment-model` **lock before any dependent EPIC starts** — retrofitting them corrupts shipped data,
  > the graph, or the compliance position. Discovery-zone contracts stay open and are finalized
  > just-in-time. A change to a locked contract is a **versioned** change: bump `Contract version`, ripple
  > to every conforming EPIC, and flag the commit scope (`contract(<name>)`) so the ripple is auditable.

  Note: `contracts/interaction-contract.md` is listed in `contracts/README.md`'s table (`## The set`) as
  "discovery — finalize just-in-time (Demo EPIC)", not among the seven contracts the Lock-first rule names
  as locking before any dependent EPIC starts. This task nonetheless follows the same versioning discipline
  (bump `Contract version`, scope the commit `contract(interaction-contract)`) because the contract carries
  its own `Contract version` line and `docs/plans/epic-02-plan.md:83` fixes the ceiling ("interaction-contract
  stays below v1.0.0 (EPIC 04 bumps it)") — i.e. it is versioned even while open.

- `contracts/README.md` — heading `## Enforcement ladder`:
  > Wire each contract at the **cheapest rung that actually holds it**:
  >
  > **type system → static analysis / lint → schema / config check → runtime contract test**
  >
  > Higher rungs are preferred: they surface failures as build or lint errors at the owner's review layer,
  > rather than needing a runtime test to expose them. The "(wired)" column above names what exists today; a
  > rung marked *EPIC-time* is owed by the first EPIC that ships the corresponding code and is a wrap-gate
  > item.

- `contracts/data-model.md` — heading `### ProbeItem (inside nodes.json)`:
  > `id`, `type ∈ {numeric, mc}`, `prompt_latex`, `why`, and either `answer {value (string, normalised
  > decimal or rational), tolerance (≥ 0, default 0)}` with `wrong_answers[] {value, error_type_id}`
  > (numeric) or `choices[] {id, latex, error_type_id?}` + `correct_choice_id` (mc; every non-correct choice
  > carries an `error_type_id`). No free-text answer field exists (I1, I10).

- `docs/domains/expedition.md` — Q4 (ratified 2026-09-09):
  > **Q4 — Numeric answer matching.** **Default:** exact match after normalisation (whitespace, leading
  > zeros, `3/4` = `0.75`); decimals within a per-item absolute tolerance the item declares, default 0
  > [ESTIMATE: items are authored to have exact answers]; no CAS on the device (D34). **Trade-off:** honest
  > and cheap; an item whose answer genuinely needs symbolic comparison must be authored as multiple-choice
  > instead.
  > **Ratified 2026-09-09:** default accepted.

Arbiter rulings, verbatim, authorizing this task's remaining five edits (`tasks/arbitration/arbiter-02-predispatch.md`):

- Q-A, normative text for 02.1 (`arbiter-02-predispatch.md:63-65`):
  > - § 2 Expedition, at the end of the `compose` bullet, add: "`remediated(p)` ≡ `nodes[p].remediated ==
  >   true` (`data-model.md` § StudentState; absent = false)."
  > - § 1 Mastery, in the row `fog / blocked | item_correct(node) | … | cleared`, append ", remove
  >   `remediated`" to the side effects.
  > - § 4 Diagnosis, `probe` bullet: change "`fail` → `confirmed` → candidate `blocked`, one remediation
  >   piece" to "`fail` → `confirmed` → candidate `blocked`, one remediation piece, candidate `remediated =
  >   true` once that piece is shown".

- Q-F, normative text for 02.1 (`arbiter-02-predispatch.md:191-196`), appended to the `set_marker` bullet of
  §3:
  > The marker is past the course's last unit iff `marker.past_last_unit == true`, whichever unit `unit_id`
  > names; setting it writes the course's last unit as `unit_id`. While past the last unit, the
  > `marker.unit ∪ next(marker.unit)` window of §2 `compose` is the nodes of the `extension` segment (empty
  > when there is none). Nodes of the course are then upstream of the marker. A marker whose `course_code`
  > is not in `syllabi[]`, or whose `unit_id` is not a unit of that course in the bundle, is off the trail
  > (`MAP_MARKER_OFF_TRAIL`, default marker) regardless of `past_last_unit`.

- Q-G, normative text for 02.1 (`arbiter-02-predispatch.md:209-211`), appended to the `probe` bullet of §4:
  > An item is *available* for the probe iff it belongs to the candidate and its answer has not been shown
  > in the current expedition run (trigger `expedition_second_miss`); under `map_check_here` every item of
  > the candidate is available. Among available items the draw order of learning-objects W3 applies.

Prior contract text this task edits in place (from `contracts/interaction-contract.md`, current v0.9.0, read
directly and quoted verbatim so every diff below is unambiguous):

- Version line:
  ```
  **Contract version:** v0.9.0 (discovery zone — finalized just-in-time by the Demo EPIC) · Source: brief v2
  §7, D23, D27, D44–D48, v2.7 §3; `map.md`, `expedition.md`, `diagnosis.md`
  ```

- §1 Mastery table, the row this task edits:
  ```
  | fog / blocked | `item_correct(node)` | `correct_count + 1 ≥ 2` on **distinct items** (expedition Q1) | cleared | `next_due = today + ladder[0]`, `ladder_rung = 0`, emit `node_cleared` |
  ```

- §2 Expedition, `compose` bullet (full text, ending with `EXP_NO_FRINGE`):
  ```
  - `compose` (D48, D45, D46, v2.7 §3): fringe = `{n : mastery(n) ≠ cleared ∧ ∀ p ∈ prereq(n): mastery(p) =
    cleared ∨ (mastery(p) = blocked ∧ remediated(p))}` ∩ (nodes of `marker.unit ∪ next(marker.unit)`, or the
    requested unit only) ∪ `{n : mastery(n) = blocked}`. Slots = up to 5: map-queued node first (map Q5, if on
    the fringe), then fringe nodes in trail order, then due cleared nodes (`next_due ≤ today`, oldest
    `last_probe` first), **≤ 2 review slots** (expedition Q3). Empty → `EXP_NO_FRINGE`.
  ```

- §2 Expedition, `answer(item)` bullet (this task inserts its new bullet immediately after this one):
  ```
  - `answer(item)`: deterministic check (expedition Q4: normalised exact match, per-item tolerance; `mc` by
    choice id); always show correct answer + `why` (I3); log `probe_log`; emit `item_answered`.
  ```

- §3 Marker and trail, `set_marker` bullet (full text this task appends to):
  ```
  - `set_marker(course, unit)` → regenerate trail → recompute fringe. Marker default = first unit of the
    selected course. Nodes upstream of the marker keep their mastery.
  ```

- §4 Diagnosis, `probe` bullet (full text this task edits):
  ```
  - `probe` (declinable, diagnosis Q2): 2 items on the candidate; `pass` → `refuted` → hint on origin →
    returned; `fail` → `confirmed` → candidate `blocked`, one remediation piece; `declined` → `unconfirmed` →
    hint → returned. Fewer than 2 items → `DIAG_PROBE_UNAVAILABLE` → `unconfirmed`.
  ```

- § Finalization owed (full text this task edits):
  ```
  ## Finalization owed by the Demo EPIC
  Exact item-normalisation rules for numeric answers; the unit-boundary snap for dragging the marker; the
  timing of the answer card; whether the summary shows region tint deltas. Bump to v1.0.0 on wrap.
  ```

## §4 Implementation outline

This is a documentation-only contract edit. There is no boundary schema, no error code, no storage/asset
access and no model-calling path in this task (§1 records I2/I6/I10 as not engaged or unchanged). The six
ordered edits below are applied to `contracts/interaction-contract.md` in place.

1. **Version line.** Replace the version line quoted in §3 with:
   ```
   **Contract version:** v0.9.1 (discovery zone — finalized just-in-time by the Demo EPIC) · Source: brief v2
   §7, D23, D27, D44–D48, v2.7 §3; `map.md`, `expedition.md`, `diagnosis.md`; v0.9.1 adds the numeric
   normalisation rule (expedition Q4), the `remediated(p)` predicate and its two ripples (arbiter Q-A,
   `tasks/arbitration/arbiter-02-predispatch.md`), the `past_last_unit` marker text (arbiter Q-F), and the
   probe "available" definition (arbiter Q-G)
   ```

2. **§2 Expedition — new numeric-normalisation bullet.** Insert this bullet immediately after the
   `answer(item)` bullet quoted in §3 (before the `**Tolerance (D27):**` bullet):
   ```
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
   ```

3. **§2 Expedition — `compose` bullet.** Append this sentence to the end of the bullet quoted in §3 (after
   "Empty → `EXP_NO_FRINGE`."):
   ```
    `remediated(p)` ≡ `nodes[p].remediated == true` (`data-model.md` § StudentState; absent = false).
   ```

4. **§1 Mastery — the `fog / blocked → cleared` row.** Replace the row quoted in §3 with:
   ```
   | fog / blocked | `item_correct(node)` | `correct_count + 1 ≥ 2` on **distinct items** (expedition Q1) | cleared | `next_due = today + ladder[0]`, `ladder_rung = 0`, emit `node_cleared`, remove `remediated` |
   ```
   The other `fog / blocked | item_correct(node)` row (guard "otherwise", `To` = "same") is untouched — the
   ruling's row identifier names the row whose `To` column is `cleared`.

5. **§3 Marker and trail — `set_marker` bullet.** Append this paragraph to the end of the bullet quoted in
   §3 (its own line, immediately following "Nodes upstream of the marker keep their mastery."):
   ```
   The marker is past the course's last unit iff `marker.past_last_unit == true`, whichever unit `unit_id`
   names; setting it writes the course's last unit as `unit_id`. While past the last unit, the
   `marker.unit ∪ next(marker.unit)` window of §2 `compose` is the nodes of the `extension` segment (empty
   when there is none). Nodes of the course are then upstream of the marker. A marker whose `course_code` is
   not in `syllabi[]`, or whose `unit_id` is not a unit of that course in the bundle, is off the trail
   (`MAP_MARKER_OFF_TRAIL`, default marker) regardless of `past_last_unit`.
   ```

6. **§4 Diagnosis — `probe` bullet.** Replace the bullet quoted in §3 with:
   ```
   - `probe` (declinable, diagnosis Q2): 2 items on the candidate; `pass` → `refuted` → hint on origin →
     returned; `fail` → `confirmed` → candidate `blocked`, one remediation piece, candidate `remediated =
     true` once that piece is shown; `declined` → `unconfirmed` → hint → returned. Fewer than 2 items →
     `DIAG_PROBE_UNAVAILABLE` → `unconfirmed`. An item is *available* for the probe iff it belongs to the
     candidate and its answer has not been shown in the current expedition run (trigger
     `expedition_second_miss`); under `map_check_here` every item of the candidate is available. Among
     available items the draw order of learning-objects W3 applies.
   ```

7. **§ Finalization owed.** Replace the section quoted in §3 with:
   ```
   ## Finalization owed by the Demo EPIC
   The unit-boundary snap for dragging the marker; the timing of the answer card; whether the summary shows
   region tint deltas. Bump to v1.0.0 on wrap.
   ```

8. **Commit.** One commit, `contract(interaction-contract): numeric normalisation, remediated(p),
   past_last_unit, probe availability (v0.9.1)`, touching only `contracts/interaction-contract.md`. The PR
   description names the three rulings this task carries out (Q-A, Q-F, Q-G,
   `tasks/arbitration/arbiter-02-predispatch.md`) and the domain-doc ratification it carries out (expedition
   Q4, `docs/domains/expedition.md`).

9. **Smoke check.** `rg -n "Contract version|Numeric normalisation|remediated\(p\)|remove \`remediated\`|past_last_unit ==
   true|remediated = true|is \*available\*|item-normalisation" contracts/interaction-contract.md` — must
   show every new/changed string present and `item-normalisation` absent. `git diff --stat
   contracts/interaction-contract.md` shows exactly one file changed.

## §5 Test plan (seam risk — full plan)

This task ships no code, so its "tests" are the verifiable textual assertions below — the cheapest rung
that actually holds prose contract text (`contracts/README.md` § Enforcement ladder: "type system → static
analysis / lint → schema / config check → runtime contract test"; a grep-based content assertion is the
lint rung). The rule's *behavioural* conformance is proven at the runtime-contract-test rung by task 02.7's
`ItemChecker` property tests, which this task's text is normative input to, not the instrument for.

- **T1 happy path.** Run the smoke check of §4 step 9. Every one of the eight grepped strings is present
  exactly where §4 places it (verified by a full read of the file after edit, not just the grep match count);
  `item-normalisation` has zero matches.
- **T2 negative — invalid input rejected at the boundary.** Not applicable in the schema/code sense (this
  task validates no runtime input). The equivalent negative check for a prose contract: confirm the *old*
  text each edit replaces no longer appears unmodified — e.g. `rg -n "\\bcleared\\b.*\\bnode_cleared\\b\\s*\\|"
  contracts/interaction-contract.md` (the pre-edit §1 row) is absent, and the pre-edit `probe` bullet
  (`"one remediation piece; \`declined\`"` — note the semicolon immediately after "piece", with no
  `remediated = true` clause) is absent. A diff that leaves the old row/bullet duplicated alongside the new
  one is a FAIL.
- **T3 error-taxonomy.** Nothing to assert: this task registers no error code in `contracts/error-codes.md`
  / `error-codes.json` and references only the already-registered `DIAG_PROBE_UNAVAILABLE` and
  `MAP_MARKER_OFF_TRAIL` (both pre-existing in the bullets this task edits). Recorded explicitly so the
  omission is a decision, not a gap.
- **T4 conformance per §B.1 / cited contract and invariants.** Re-read the full edited file top to bottom
  and confirm: (a) every one of the six edits in §4 appears verbatim as specified, with no adjacent text
  altered; (b) the version line names all three rulings and the Q4 ratification (AC1); (c) I1 holds —
  the numeric rule's comparison is stated as exact-rational, never floating-point; (d) I10 holds — the new
  bullet states `mc` items are never compared by value; (e) the `set_marker` and `probe` bullets read
  grammatically as continuous prose after the append (no orphaned clause, no dangling reference).
- **T5 negative control for every regression guard.** The regression guard this task installs is the grep
  set of §4 step 9. Its negative control: temporarily revert one edit (e.g. re-insert "Exact
  item-normalisation rules for numeric answers" into § Finalization owed) and confirm the smoke check of §4
  step 9 fails (the `item-normalisation` grep now matches). Perform this once per edit during review, not as
  a committed test file (there is no test harness for `contracts/*.md` prose in this repository today —
  confirmed absent, `Glob scripts/*.sh` lists no markdown-content check and `Grep interaction-contract
  pipeline/` returns no match).
- **T6 idempotency / no-leak.** Re-applying the same six edits to the post-edit file is a no-op (each
  target string, once present, is not matched again by its own insertion instruction — every insertion in
  §4 targets a string from the *pre*-edit file, quoted in §3, which no longer exists post-edit). No side
  file is touched; `git diff --stat` after the commit shows exactly one file.

## §6 Decision defaults

- IF the two `fog / blocked | item_correct(node)` rows in §1 both look like candidates for the Q-A append
  THEN the append lands only on the row whose `To` column is `cleared` (data-model.md's `remediated` field
  is defined only for a node whose `mastery` is `blocked`, and only *clearing* removes it — Q-A's own
  normative text for 02.2, `arbiter-02-predispatch.md:49-53`: "It is written `true` only by that step and
  only on a node whose `mastery` is `blocked`; it is removed whenever the node becomes `cleared`."); the
  "otherwise" row (`To` = "same") never changes `mastery` and so never removes `remediated`.
- IF the new numeric-normalisation bullet's grammar should special-case `-10` (or any other value absent
  from `data/demo` today) as a distinct rule THEN it must not: the grammar in §4 step 2 is general (optional
  sign + digits, optional decimal, optional rational) and already accepts any negative integer, positive
  integer, decimal or rational without enumeration; `data/demo`'s current forms (`5/6`, `32000`, and `-6` as
  a `wrong_answers[]` value in `factoring-1`) are cited in AC3 as evidence the grammar already covers what
  ships, not as an exhaustive list the grammar is scoped to.
- IF a future numeric item is authored with a leading `+` sign in `answer.value` THEN the grammar in §4
  step 2 already accepts it (an absent sign, per the grammar, is positive; an explicit `+` is not forbidden
  by the prose, and `contracts/schemas/nodes.schema.json`'s `answer.value` pattern
  `^-?[0-9]+(\.[0-9]+)?(/[1-9][0-9]*)?$`, read directly, does not permit a leading `+` on the *stored* form —
  so an authored `answer.value` never carries one; only a *submitted* student answer might, and the contract
  text's grammar accepts it there).
- IF § Finalization owed's remaining three items (unit-boundary snap, answer-card timing, summary region
  tint deltas) look related enough to fold into this task's scope THEN they are not: this task closes only
  the one item the plan names ("Remove 'Exact item-normalisation rules for numeric answers' from §
  Finalization owed"); the other three stay open, owed by whichever future EPIC finalizes them.
- IF the commit should also bump `contracts/interaction-contract.md`'s Source line's D-numbers or add a
  fourth ruling reference (Q-B, Q-C, Q-D, Q-E) THEN it must not: those rulings land in other contracts or
  other tasks entirely (Q-B → `data-model.md` via 02.9; Q-C, Q-D → no contract text at all, confirmed from
  existing text; Q-E → `graph-constraints.md` via 02.3, held separately under the owner's Q5 ruling). Naming
  them here would misattribute a ruling to a file it never touches.

Standing defaults: identifiers and timestamps are unaffected by this task (no schema, no field). No model
call exists in this task, so no confidence threshold or Tier-0 fallback applies (I2 not engaged). Telemetry
is unaffected. No field anywhere is added that could identify a person, device or session — this task adds
prose only, no field. Ministry text is not touched; no `paraphrase` field exists in this file.

## §7 Done definition

The task is done when ALL gates pass:

- `scripts/gate.sh` green end-to-end (unaffected by a docs-only change, but run in full per standing
  practice — no gate in `scripts/gate.sh` reads `contracts/interaction-contract.md`, so this is a
  regression check that the change introduced no stray edit elsewhere)
- `git diff --stat` shows exactly one file changed: `contracts/interaction-contract.md`
- the smoke check and both grep-based T1/T2/T5 checks of §5 pass
- `Contract version` reads `v0.9.1` and the commit is scoped `contract(interaction-contract)`
- conforms to every contract section cited in §3 and §4, and to every invariant listed in §1
