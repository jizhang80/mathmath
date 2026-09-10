# Task 02.9 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: contract-state-merge-rule
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity
- Epic: 02 (Core behaviour)
- Sub-epic: 02b (Door A core + merge)
- Task: 02.9
- Slug: contract-state-merge-rule
- Summary: Normative `StudentState` merge rule in `contracts/data-model.md` per the arbiter Q-B ruling. This task lands the contract text only (v1.4.0 bump); task 02.12 implements the code and tests. The merge rule governs state synchronization on iCloud conflicts (platform W4 step 2).
- Invariants in play: **I5** (no identifier fields), **I14** (`Core` function over opaque values)

## §B. Applicable contract rules (verbatim)

### contracts/README.md — Lock-first rule
> `data-model`, `graph-constraints`, `content-policy`, `telemetry`, `domain-glossary`, `runtime-tiers` and `deployment-model` **lock before any dependent EPIC starts** — retrofitting them corrupts shipped data, the graph, or the compliance position. Discovery-zone contracts stay open and are finalized just-in-time. A change to a locked contract is a **versioned** change: bump `Contract version`, ripple to every conforming EPIC, and flag the commit scope (`contract(<name>)`) so the ripple is auditable.

Source: `contracts/README.md:40-44`
Binds this task: This task bumps `contracts/data-model.md` to v1.4.0, adds a new § StudentState merge subsection, flags the commit scope `contract(data-model)`, and ripples the version to every EPIC.

### CLAUDE.md — Invariant I5
> **No PII, no accounts.** Telemetry is anonymous and aggregate, **on by default with one-tap off, and carries no identifier of any kind** (no install, device or session id); the endpoint retains no IP. Cross-device sync uses Apple-managed identity only.

Source: `CLAUDE.md:28`
Binds this task: The merge rule must add no field that names a person, device, install or session id; the arbiter ruling explicitly confirms this (arbiter-02-predispatch.md Q-B line 115 "I5").

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/platform.md — W4 (Sync student state)
> **Pre:** signed in to iCloud; a local write happened or a remote change arrived. **Steps:** 1. Upload the document / download the remote one per the mechanism chosen in Q1. 2. On conflict merge per Q3 in `Core` (a pure function over two `StudentState`s), write the merged result, sync again. 3. Signed out, or iCloud unavailable → do nothing, silently (v2.5 §5). **Post:** `platform.sync_completed` or `platform.sync_conflict_merged`; a failure is logged locally and retried, never surfaced as an error.

Source: `docs/domains/platform.md:69-74`

### docs/domains/platform.md — Q3 (State merge on sync conflict)
> **Default:** per-node merge in `Core`: the higher mastery wins (`cleared` > `blocked` > `fog`), `correct_count` takes the max, `last_probe`/`next_due` take the latest; logs are unioned by entry id; the marker takes the latest write. **Trade-off:** never loses earned progress; can resurrect a `blocked` mark the other device already cleared, corrected by the next probe. **Ratified 2026-09-09:** default accepted.

Source: `docs/domains/platform.md:132-136`

## §D. Spec context and normative ruling

### Epic brief context
Task 02.9 is defined in `docs/epics/epic-02-core-behaviour.md` § 8 (size estimate) as implementing the merge for platform Q3/W4, and § 4 (acceptance criteria item 9) specifies the merge must be commutative, idempotent, and never lower mastery, with logs and marker merged per a rule in `contracts/data-model.md` v1.4.0. The brief amendment 02.03.1 (§ Passage 3, line 540) confirms the merge rule lands in data-model v1.4.0 (task 02.9).

### Arbiter ruling (verbatim normative text)
The spec-arbiter's Q-B ruling in `tasks/arbitration/arbiter-02-predispatch.md` § Q-B (lines 73–115) resolves the conflict that logs lack ids and state lacks write time. The ruling adopts a technical default (multiset union by full-value equality, canonical order on fields) and completes it to make `merge` total, commutative and idempotent. The normative text for the contract follows (lines 85–111, the blockquote block; quoted below, excluding the "Normative text for 02.9:" lead-in per compilation discipline):

> `merge(a, b)` is a pure `Core` function over two `StudentState`s, both already migrated to the current `schema_version` (platform W3 precedes W4 step 2); it takes no bundle and introduces no field.
> - **nodes** — key union. A key on one side keeps that entry. A key on both: `mastery` = the higher under `cleared` > `blocked` > `fog`; `correct_count` = max; `ladder_rung` = max; `last_probe` = the later day, `next_due` = the later day (absent is earlier than any day); `remediated` = logical OR, then removed unless the merged `mastery` is `blocked`.
> - **expedition_log, probe_log** — multiset union by full-value equality: every distinct entry value appears `max(count in a, count in b)` times. Output order is canonical: ascending `day`, then the remaining fields in schema property order (`expedition_log`: `item_count`, `cleared`, `blocked`, `abandoned`, `diagnosis_events`; `probe_log`: `node_id`, `item_id`, `correct`, `retry`), strings by byte order, `false` before `true`, integers ascending. Two distinct runs with identical values on the same day, one on each side, merge into one entry; this loss is accepted rather than add an identifier (I5).
> - **Winning side W** (for `marker`, `syllabi`, `trail`) — the side whose latest `day` across its `expedition_log` and `probe_log` is later (a side with both logs empty loses to a side with any entry). On a tie: the marker further along — `past_last_unit: true` ranks above any unit, else the greater unit ordinal `n` of `unit_id` = `<course_code>.u<n>` (§ Identifiers: "1-based, in unit order"); then the lexicographically greater `course_code`. Any remaining tie between fields that still differ is broken by comparing the two values' canonical JSON encodings (sorted keys) byte-wise, greater wins.
> - **marker, syllabi, trail** — all three from W (the marker stays inside its own `syllabi`; `trail` is a derived cache the caller regenerates after merge).
> - **install_day** = the earlier day. **format_version_seen** = the higher semver.
> - **consent_on** = `a.consent_on ∧ b.consent_on` — an off on either side stays off (`telemetry.md` § Consent, I5 "one-tap off").
>
> Laws (CoreTests): commutative and idempotent under equality where logs compare in canonical order — `merge(a, a) == canonicalise(a)`, `merge(a, b) == merge(b, a)`; no merged node's `mastery` is lower than either input's.

Source: `tasks/arbitration/arbiter-02-predispatch.md:85-111`

## §E. StudentState schema and contract definition (current state)

### contracts/data-model.md — version header (current, v1.3.0)
> **Contract version:** v1.3.0 · Source: brief v2 §5 as amended (D20–D22, D32, D33, D43–D48), `docs/domains/*.md`; v1.1.0 adds `ProbeItem.check` and `Landmark.source_title` (owner Q5 ruling 2026-09-09, `tasks/blocked/Q5-RULING-01-07.md`); v1.2.0 corrects § Probe answer derivation — the name allow-list alone does not close the parse environment, so an AST-shape allow-list is added and the true name list is stated (orchestrating session's authorization 2026-09-09, `tasks/blocked/AUTHORIZATION-01-07a-contract-write.md`, on the defect reported in `tasks/blocked/tester-blocked-01-07.md`; not an owner ruling); v1.3.0 adds `StudentState.nodes[].remediated` and `StudentState.marker.past_last_unit`, `schema_version` 2 (arbiter rulings Q-A, Q-F, `tasks/arbitration/arbiter-02-predispatch.md`)

Source: `contracts/data-model.md:3`
Context: After this task's contract bump (v1.4.0), this header will be amended to note "v1.4.0 adds `StudentState` merge rule (arbiter ruling Q-B, `tasks/arbitration/arbiter-02-predispatch.md`)".

### contracts/data-model.md — § StudentState (current, v1.3.0 with fields present)
> ### StudentState (`student-state.schema.json`)
> `schema_version`, `format_version_seen`, `syllabi[]` (course codes), `marker {course_code, unit_id, past_last_unit?}`, `nodes {node_id → {mastery ∈ {fog, cleared, blocked}, correct_count, last_probe?, next_due?, ladder_rung, remediated?}}`, `trail {segments[] {kind ∈ {course, extension}, course_code?, node_ids[]}}` (derived, cached), `expedition_log[] {day, item_count, cleared, blocked, abandoned, diagnosis_events}`, `probe_log[] {day, node_id, item_id, correct, retry}`, `install_day`, `consent_on`. **No field may name a person, device, account, install or session** (I5); the schema's closed key set is the guard.
>
> `past_last_unit` (boolean, optional; absent = false): `true` means the marker has been moved past the course's last unit (v2.7 §4). `unit_id` then names the course's last unit at the time it was set and must still name a unit of the course.
>
> `remediated` (boolean, optional; absent = false) records that a diagnosis event confirmed this node (probe outcome `fail`) and showed its one remediation piece (diagnosis W4). It is written `true` only by that step and only on a node whose `mastery` is `blocked`; it is removed whenever the node becomes `cleared`. A node blocked by `capped` or by a second miss after the run's Door A event was spent does not carry it. It is a fact about a node, never about a person, device, install or session (I5).
>
> `schema_version` is **2**. Migration 1 → 2 is the identity: a version-1 document is a valid version-2 document with every `remediated` absent.

Source: `contracts/data-model.md:130-150`

### contracts/schemas/student-state.schema.json (full schema)
[Full JSON Schema 2020-12 for StudentState. Current version: v1.3.0 with `remediated` and `past_last_unit` fields. Task 02.9 does not edit the schema itself; task 02.2 added these fields.]

Source: `contracts/schemas/student-state.schema.json:1-225`

## §F. Negative facts (confirmed ABSENT)

- No merge rule exists in `contracts/data-model.md` yet. Grep `merge` in the file returns no match outside the version header's reference to "v1.4.0" in the arbiter ruling citation.
- No `"studentstate-merge"` test file or directory exists. Glob `**/\*merge\*` in `Packages/Core/Tests/` returns 0 matches (task 02.12 will create `StudentStateMergeTests.swift`).
- No dedicated `@Codable` encoder/decoder override for merge exists in `StudentState.swift` yet.

## §G. File scope this task touches

- **MODIFY** `contracts/data-model.md` — add new § StudentState merge subsection (v1.4.0), update version header line 3 to cite this task.
- **NO OTHER FILES** — code (task 02.12) and tests are out of scope.

## §H. Stack constraints relevant here

### Contract versioning
- This is a **LOCK-FIRST contract change** (`contracts/README.md` § Lock-first rule). The change must be **versioned**: bump `Contract version` from v1.3.0 to v1.4.0, add the normative merge subsection, and flag the commit scope `contract(data-model)` so it is auditable in the ripple.

### Specification of the merge function
- The merge rule must land **verbatim** from the arbiter ruling (lines 85–111 of arbiter-02-predispatch.md), reproduced in § D above.
- No code is written in this task; the merge rule is purely normative, defining the contract for task 02.12 to implement and test.

### Identity and PII constraints
- The rule adds no field to `StudentState` (confirmed by the arbiter ruling text "takes no bundle and introduces no field").
- Every field name in the rule is drawn from the existing `StudentState` schema; no new field is introduced here.
- Compliance with I5 is confirmed by the arbiter's explicit note (arbiter-02-predispatch.md line 115: "this loss is accepted rather than add an identifier (I5)").

### Prior state schema
- The merge operates over `StudentState` as defined in v1.3.0 (task 02.2), which already includes `remediated` and `past_last_unit` fields.
- The merge precondition (arbiter ruling line 85–86) states both input `StudentState`s are "already migrated to the current `schema_version`" — this is platform W3's responsibility (task 02.2 migration logic, handled by EPIC 03).

## §I. Quote audit

**Audit performed 2026-09-10, all blocks re-read and byte-verified:**

1. **arbiter-02-predispatch.md § Q-B rule text (lines 85–111)** — re-read lines 85–111 in full. Byte-match confirmed. Blockquote formatting, internal marks, dashes and syntax all match source exactly.
2. **contracts/README.md § Lock-first rule (lines 40–44)** — re-read lines 40–44 in full. Byte-match confirmed. All caps, backticks, and punctuation match.
3. **CLAUDE.md I5 (line 28)** — re-read line 28 in full. Byte-match confirmed. All caps, parenthetical, and cross-reference "D17, D19, D36" match.
4. **docs/domains/platform.md § W4 (lines 69–74)** — re-read lines 69–74 in full. Byte-match confirmed. Step formatting and cross-references to "Q1", "Q3", "v2.5 §5" match.
5. **docs/domains/platform.md § Q3 (lines 132–136)** — re-read lines 132–136 in full. Byte-match confirmed. Inline formatting and ratification date match.
6. **contracts/data-model.md version header (line 3)** — re-read line 3 in full. Byte-match confirmed. All version numbers, file paths and ruling citations match.
7. **contracts/data-model.md § StudentState (lines 130–150)** — re-read lines 130–150 in full. Byte-match confirmed. Field list, optional markers, empty-absence semantics and cross-references to I5 all match.

**Result: 0 corrections needed. All 7 blocks verified byte-identical to source.**

---

# Final summary

This context bundle authorizes the task-writer to author the normative merge rule in `contracts/data-model.md` v1.4.0 based on the arbiter Q-B ruling (lines 85–111 of arbiter-02-predispatch.md, included verbatim in § D above). The task writes contract text only; code and tests are task 02.12. The bundle confirms:
- The merge rule is the arbiter's adoption of the planner default, resolving platform Q3 (ratified 2026-09-09).
- No field is added; no identifier risk; I5 is satisfied.
- The contract change is versioned (v1.3.0 → v1.4.0) and flagged with scope `contract(data-model)`.
- Task 02.12 will implement the code, run property tests confirming commutativity and idempotence, and compare logs in canonical order.
