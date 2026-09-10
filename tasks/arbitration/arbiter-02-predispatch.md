# ARBITER RULINGS: EPIC 02 pre-dispatch (Q-A … Q-G)

**Date**: 2026-09-10
**Brief**: `docs/epics/epic-02-core-behaviour.md` § 9 Open questions
**Plan**: `docs/plans/epic-02-plan.md` (task ids 02.1–02.13 below are the plan's)
**Trigger**: pre-dispatch Q4 from the planner. No task spec exists yet. These rulings bind specs 02.1, 02.2, 02.3,
02.5, 02.6, 02.9, 02.11 and 02.12.
**Authority used**: `tasks/*` write only. No contract, doc or source file was edited. Contract text below is
normative wording for the named contract task to land verbatim (its own `contract(<name>)` commit, versioned
per `contracts/README.md` § Lock-first rule).

## Summary

| Q | Ruling | Lands in |
|---|---|---|
| Q-A | **Planner default adopted**: optional boolean `remediated` on the node entry; data-model v1.3.0; `schema_version` 2 | 02.2 (schema/type), 02.1 (§1/§2/§4 text), 02.11 (sets it), 02.12 (merge) |
| Q-B | **Planner default adopted, completed**: multiset union by full value, canonical order; marker+syllabi+trail from the "winning side" by latest log day, then a stated total order; every other field ruled | 02.9 (text), 02.12 (code) |
| Q-C | **CONFIRMED** from contracts: no `upstream_hint`; the Demo candidate is the graph query with budget 1 | 02.10, 02.11 |
| Q-D | **CONFIRMED with one caveat**: `MAP_MARKER_OFF_TRAIL` + default marker, returned by `Core` as data; the registry `user_text` does not fit this path and is owed to EPIC 03 | 02.5 |
| Q-E | **ESCALATE-Q5**: no reading of "path" that has any content is satisfiable on `data/demo` or on real course subsets. Any passing rule changes I8's meaning | 02.3, 02.5, 02.6, 02.7 **held**; see `tasks/blocked/blocked-arbiter-02-03.md` |
| Q-F | Optional boolean `past_last_unit` on `marker`; there is no sentinel `unit_id` | 02.2 (schema/type), 02.1 (§3/§2 text) |
| Q-G | "Available" = the candidate's items whose answer has not been shown in the current run. `DIAG_PROBE_UNAVAILABLE` is reachable on real `data/demo` with a constructed state | 02.1 (§4 text), 02.11 (tests) |

One data-model bump carries Q-A and Q-F together: **v1.3.0, one task (02.2)**. Q-B follows as **v1.4.0 (02.9)**.
The file is written sequentially, per the plan's note "`contracts/data-model.md` by 02.2 then 02.9".

---

## Q-A — `remediated(p)` has no field

**Verification.**
- `contracts/interaction-contract.md` § 2 Expedition (Door B), `compose`: "fringe = `{n : mastery(n) ≠ cleared ∧ ∀ p ∈ prereq(n): mastery(p) = cleared ∨ (mastery(p) = blocked ∧ remediated(p))}`".
- `contracts/schemas/student-state.schema.json:45-80`: the node entry is closed. It holds `mastery`, `correct_count`, `last_probe`, `next_due` and `ladder_rung`, with `additionalProperties: false`. There is no remediation field.
- The ratified domain intent is explicit. `docs/domains/expedition.md:47-48` says: "nodes not `cleared` whose prerequisites are all `cleared` (or `blocked`-and-remediated, Q1)".
- Blocked has three sources:
  - diagnosis W4 (confirmed, then remediated): `docs/domains/diagnosis.md:76-80`;
  - W6 capped, with no remediation: `diagnosis.md:88-91`;
  - expedition Q5, spent Door A, with no remediation: `expedition.md:197-199`.
- Nothing in the state separates these three cases. A derivation from `probe_log` fails because a capped node can carry `probe_log` rows from earlier runs.
- The claim is **VALID**. Contracts outrank domain docs, and the contract names the predicate, so the predicate must become representable.
- Rewriting the guard so that no blocked prerequisite satisfies it would reverse a ratified default (`expedition.md` Fringe). Adding the field does not.

**Ruling.** Adopt the planner default. This is a technical realisation of a ratified rule. It is not a D change and it does not change an invariant's meaning. I5 allows it: the field is a boolean about a node and names no person, device, install or session (`contracts/data-model.md` § StudentState). The field name is not on the identifier blocklist (`Packages/Core/Tests/CoreTests/DecodeRoundTripTests.swift:246-248`).

**Normative text for 02.2: `contracts/data-model.md` § StudentState (v1.3.0).** Replace the `nodes` clause with:
> `nodes {node_id → {mastery ∈ {fog, cleared, blocked}, correct_count, last_probe?, next_due?, ladder_rung, remediated?}}`

Then add this paragraph after the field list:
> `remediated` (boolean, optional; absent = false) records that a diagnosis event confirmed this node (probe
> outcome `fail`) and showed its one remediation piece (diagnosis W4). It is written `true` only by that step and
> only on a node whose `mastery` is `blocked`; it is removed whenever the node becomes `cleared`. A node blocked
> by `capped` or by a second miss after the run's Door A event was spent does not carry it. It is a fact about a
> node, never about a person, device, install or session (I5).
>
> `schema_version` is **2**. Migration 1 → 2 is the identity: a version-1 document is a valid version-2
> document with every `remediated` absent.

- **Schema.** Add `"remediated": {"type": "boolean"}` to the node-entry `properties`. It is not in `required`, and `additionalProperties: false` stays.
- **Example.** In `contracts/examples/student-state.json`, set `schema_version` to 2 and add one entry `{"mastery": "blocked", "correct_count": 0, "ladder_rung": 0, "remediated": true}` so the round-trip test exercises the key.
- **Type.** Add `remediated: Bool?` to `NodeState`. It encodes as absent, never `null` (§ Nulls, enums, unknowns).

**Normative text for 02.1: `contracts/interaction-contract.md`.**
- § 2 Expedition, at the end of the `compose` bullet, add: "`remediated(p)` ≡ `nodes[p].remediated == true` (`data-model.md` § StudentState; absent = false)."
- § 1 Mastery, in the row `fog / blocked | item_correct(node) | … | cleared`, append ", remove `remediated`" to the side effects.
- § 4 Diagnosis, `probe` bullet: change "`fail` → `confirmed` → candidate `blocked`, one remediation piece" to "`fail` → `confirmed` → candidate `blocked`, one remediation piece, candidate `remediated = true` once that piece is shown".

**Merge (for Q-B).** The merged value is the logical OR of both sides. It is then removed unless the merged `mastery` is `blocked`.

**Cascade note for 02.6.** A prerequisite that is `capped` or blocked on a spent Door A event keeps its downstream nodes off the fringe until it is cleared. It is always fringe-eligible itself as `blocked`. This is intended, per I4 ("deeper gaps are marked on the map only").

---

## Q-B — merge "by entry id" / "latest write" with no id and no write time

**Verification.**
- `docs/domains/platform.md:132-136` (Q3, ratified): "logs are unioned by entry id; the marker takes the latest write."
- `student-state.schema.json:123-197`: `expedition_log` and `probe_log` entries have no id field. The state has no write timestamp.
- `contracts/data-model.md` § Time: "calendar days … never finer (I5)". § StudentState: "**No field may name a person, device, account, install or session**".
- A per-run id names a run, which is the thing I5's "no … session id" guards against (CLAUDE.md I5).
- The claim is **VALID**. The domain default cannot be realised literally without an I5 risk. Its intent can be: never lose progress, and the newer side wins the marker.
- This is a technical choice and no D-number is touched.

**Ruling.** Adopt the planner default and complete it, so that `merge` is total, commutative and idempotent. The rule text goes into the contract. **Normative text for 02.9: `contracts/data-model.md`, new subsection `### StudentState merge (platform Q3)` (v1.4.0):**

> `merge(a, b)` is a pure `Core` function over two `StudentState`s, both already migrated to the current
> `schema_version` (platform W3 precedes W4 step 2); it takes no bundle and introduces no field.
> - **nodes** — key union. A key on one side keeps that entry. A key on both: `mastery` = the higher under
>   `cleared` > `blocked` > `fog`; `correct_count` = max; `ladder_rung` = max; `last_probe` = the later day,
>   `next_due` = the later day (absent is earlier than any day); `remediated` = logical OR, then removed unless
>   the merged `mastery` is `blocked`.
> - **expedition_log, probe_log** — multiset union by full-value equality: every distinct entry value appears
>   `max(count in a, count in b)` times. Output order is canonical: ascending `day`, then the remaining fields in
>   schema property order (`expedition_log`: `item_count`, `cleared`, `blocked`, `abandoned`, `diagnosis_events`;
>   `probe_log`: `node_id`, `item_id`, `correct`, `retry`), strings by byte order, `false` before `true`, integers
>   ascending. Two distinct runs with identical values on the same day, one on each side, merge into one entry;
>   this loss is accepted rather than add an identifier (I5).
> - **Winning side W** (for `marker`, `syllabi`, `trail`) — the side whose latest `day` across its
>   `expedition_log` and `probe_log` is later (a side with both logs empty loses to a side with any entry). On a
>   tie: the marker further along — `past_last_unit: true` ranks above any unit, else the greater unit ordinal
>   `n` of `unit_id` = `<course_code>.u<n>` (§ Identifiers: "1-based, in unit order"); then the lexicographically
>   greater `course_code`. Any remaining tie between fields that still differ is broken by comparing the two
>   values' canonical JSON encodings (sorted keys) byte-wise, greater wins.
> - **marker, syllabi, trail** — all three from W (the marker stays inside its own `syllabi`; `trail` is a
>   derived cache the caller regenerates after merge).
> - **install_day** = the earlier day. **format_version_seen** = the higher semver.
> - **consent_on** = `a.consent_on ∧ b.consent_on` — an off on either side stays off (`telemetry.md` § Consent,
>   I5 "one-tap off").
>
> Laws (CoreTests): commutative and idempotent under equality where logs compare in canonical order —
> `merge(a, a) == canonicalise(a)`, `merge(a, b) == merge(b, a)`; no merged node's `mastery` is lower than
> either input's.

**Cascade for 02.12.** The AC9 law tests must compare through `canonicalise`, because a raw append-ordered log would make `merge(a, a) == a` fail spuriously. The spec must include a **negative control**: a merge that keeps sum-multiplicity instead of max must fail idempotence.

**Out-of-scope note.** If EPIC 10 observes lost runs, the revisit trigger in brief § 9 stands. An id is never the fix, because that is I5.

---

## Q-C — `upstream_hint` (confirmation)

**Verification.**
- `Grep upstream_hint contracts/` → **no match**, so `nodes.schema.json` has no such field.
- `contracts/interaction-contract.md` § 4 Diagnosis: "`hypothesise`: candidate = deepest unmastered prerequisite within remaining levels (graph query), biased by `implies_prerequisite`; none → `DIAG_NO_PREREQUISITE` → hint → returned." Budget: "`budget 2 (Demo: 1)`".
- `contracts/graph-constraints.md` § Query rules: "walks ≤ 2 levels breadth-first (I4), treats `fog` as a candidate …, breaks ties by highest edge confidence, then lowest depth marker, then node id".
- Contracts outrank `docs/domains/diagnosis.md:63-64` and DEMO-BRIEF § 3.6.

**Ruling.** CONFIRMED as answerable from contracts. The Demo candidate is the graph query with budget 1, and no field is added. It lands in 02.10 (query) and 02.11 (budget 1 in the Demo configuration).

---

## Q-D — unknown persisted marker (confirmation, with caveat)

**Verification.**
- `contracts/interaction-contract.md` § 3: "Marker default = first unit of the selected course."
- `error-codes.json:11` registers `MAP_MARKER_OFF_TRAIL` (recoverable, surface `student`), with `user_text` "The marker stays where it was; pick a unit from the list."
- `docs/domains/map.md:126` scopes it to "Marker dropped outside a unit boundary … Marker snaps back".
- No contract clause covers a *persisted* marker that no longer resolves. `expedition.md` W7 (`:119-123`) covers node ids only.
- The code family fits: it is a MAP code for a marker off the trail, and it is registered. Its `user_text` is wrong for this path, because at load the marker moves; it does not stay.

**Ruling.** CONFIRMED for `Core`. The W7 reconciliation in 02.5 returns `MAP_MARKER_OFF_TRAIL` as data in its result, together with the default marker. `Core` surfaces no text (I14), and mastery is untouched.
- **Default marker.** Use the first unit of the first course in `syllabi[]` that exists in the bundle.
- **No resolvable course.** If no course in `syllabi[]` exists in the bundle, keep the stored marker, generate a trail with no segments, and let `compose` raise `EXP_NO_FRINGE` unless `blocked` or due nodes exist.
- **Off-trail definition.** A marker is off the trail when `course_code ∉ syllabi[]`, or when the course is absent from the bundle, or when `unit_id` is not one of that course's `units[]`.
- **Caveat owed to EPIC 03 (App persistence and UI owner), not to EPIC 02.** On this load path, EPIC 03 must either not show the registry `user_text` or register a dedicated code with its domain-doc row (`contracts/error-codes.md`: "Additive registration … allowed without a version bump"). The planner's note in `docs/plans/epic-02-plan.md` already flags this. EPIC 02 adds no code.

---

## Q-E — L0-T "directed path" vs unit-ordered course segments → **ESCALATE-Q5**

Full analysis, options and recommendation: `tasks/blocked/blocked-arbiter-02-03.md`.

In short, the **conflict is confirmed and is structural**.
- **MTH1W.** Its unit-ordered node set:
  - has sources `integer-operations`, `rational-numbers` and `simplifying-expressions`;
  - has sinks `factoring`, `scientific-notation` and `solving-systems-of-equations`;
  - carries the edge `solving-linear-equations` (u3) → `exponent-laws` (u2), which runs against unit order. That edge is the D14 step "linear relations/equations → exponent laws" (`PROJECT-BRIEF-v2.md:68`), and v2.7 § 2 says "The Demo's hand-written unit lists stand".
- **MCR3U.** `rational-expressions` has no in-course neighbour in either direction. Its only edge is `factoring` → it, from MTH1W (`data/demo/edges.json:260-275`).
- **Readings tested.** Each of the following fails on `data/demo`:
  - directed path;
  - undirected simple path;
  - consecutive pairs comparable in the transitive closure;
  - topological consistency with unit order.
- **The only reading that passes** is "every segment id is a graph node". That empties "path" of meaning, so it is a change to I8, not a reading of it.
- **Data fix.** A demo-data fix would need to break D14 or v2.7 § 2, or invent prerequisite edges that the Door A query would then use as hypotheses. The same obstruction returns for every generated course at M1.

**Holds.**
- Held: 02.3, 02.5, 02.6, and 02.7 (which depends on 02.6).
- May proceed now: 02.1, 02.2 and 02.4. 02.10 may proceed too, although the plan sequences it after 02.8.

---

## Q-F — representing "marker past the course's last unit"

**Verification.**
- `interaction-contract.md` § 3: "if the marker is past the course's last unit, an `extension` segment …".
- AMENDMENT-v2.7 § 4: "When the course-progress marker is moved past the course's last unit … The extension is opt-in by marker position".
- `student-state.schema.json:22-39`: `marker` is `{course_code, unit_id}` with `additionalProperties: false`, and `unit_id` matches `^[A-Z]{3}[1-4][A-Z]\.u[1-9][0-9]*$`.
- A sentinel `u<N+1>` would name a unit that does not exist. That collides with the Q-D off-trail rule, and it silently changes meaning when a content refresh adds a unit N+1.
- The claim is **VALID**. This is a representation choice, not a D change.

**Ruling.** Add an optional boolean `past_last_unit` on `marker`. It lands with Q-A in **02.2** (data-model v1.3.0, schema, example, `Marker` type) and in **02.1** (interaction-contract text).

**Normative text for 02.2: `contracts/data-model.md` § StudentState.** Replace the `marker` clause with `marker {course_code, unit_id, past_last_unit?}`, then add:
> `past_last_unit` (boolean, optional; absent = false): `true` means the marker has been moved past the course's
> last unit (v2.7 §4). `unit_id` then names the course's last unit at the time it was set and must still name a
> unit of the course.

Schema: add `"past_last_unit": {"type": "boolean"}` to `marker.properties`. It is not required.

**Normative text for 02.1: `contracts/interaction-contract.md` § 3**, appended to the `set_marker` bullet:
> The marker is past the course's last unit iff `marker.past_last_unit == true`, whichever unit `unit_id` names;
> setting it writes the course's last unit as `unit_id`. While past the last unit, the `marker.unit ∪
> next(marker.unit)` window of §2 `compose` is the nodes of the `extension` segment (empty when there is none).
> Nodes of the course are then upstream of the marker. A marker whose `course_code` is not in `syllabi[]`, or
> whose `unit_id` is not a unit of that course in the bundle, is off the trail (`MAP_MARKER_OFF_TRAIL`, default
> marker) regardless of `past_last_unit`.

---

## Q-G — when is `DIAG_PROBE_UNAVAILABLE` reachable?

**Verification.**
- `data/demo/nodes.json` holds 20 `"type":"numeric"` and 20 `"type":"mc"` items across 20 nodes, alternating (Grep `-o`, 40 matches). Every node has exactly 2 items, consistent with `docs/epics/epic-02-core-behaviour.md:245`.
- `interaction-contract.md` § 4: "`probe` …: 2 items on the candidate … Fewer than 2 items → `DIAG_PROBE_UNAVAILABLE` → `unconfirmed`."
- `docs/domains/learning-objects.md:101`: "preferring items unused in recent runs". That is a draw preference, not an exclusion.
- Under a pool-size reading the terminal is unreachable over `data/demo`. That would contradict brief AC6 (each terminal reached "over `data/demo` with the Demo budget of 1"), including the `unconfirmed` terminal by `DIAG_PROBE_UNAVAILABLE` (brief § 3 I2 line).

**Ruling.** "Available" excludes items whose answer was already shown in the current run. I3 guarantees the answer is on screen after every item (`interaction-contract.md` § 2 `answer`: "always show correct answer + `why`"). A probe on an item answered minutes earlier in the same run tests recall of a displayed key, not the prerequisite. This is a technical definition. **Normative text for 02.1: `contracts/interaction-contract.md` § 4**, appended to the `probe` bullet:
> An item is *available* for the probe iff it belongs to the candidate and its answer has not been shown in the
> current expedition run (trigger `expedition_second_miss`); under `map_check_here` every item of the candidate
> is available. Among available items the draw order of learning-objects W3 applies.

**Reachability on the real `data/demo`.** This is for the 02.11 Tier-0 completeness suite, which needs no bundle edit. Use a constructed `StudentState` and trail: `syllabi = [MTH1W]`, `exponent-laws` = `blocked`, `polynomials` = `blocked`, `simplifying-expressions` = `cleared`. Then run the following sequence:
1. The run shows `exponent-laws` (u2) before `polynomials` (u4) in trail order. `exponent-laws` item 1 is missed and its retry (item 2) is answered correctly, so both of its answers have been shown.
2. `polynomials` is missed on its first item and again on the retry. That is the second miss, so a diagnosis opens at `polynomials` with budget 1.
3. The candidate is `exponent-laws`. The edge confidence is 0.95 (`edges.json:36-51`), against 0.7 for `simplifying-expressions` (`:228-243`), and `simplifying-expressions` is cleared in any case.
4. The candidate has 0 available items, so the result is `DIAG_PROBE_UNAVAILABLE` → `unconfirmed` → hint → `returned`.

**Test-data rule** (02.5, 02.6, 02.11):
- In-memory bundles derived from `data/demo` are allowed for property tests over generated graphs (brief AC5) and for the extension positive case (02.5, where `data/demo` has no `next_courses` target).
- The C1 seams (AC7, AC8) and the AC6 terminal suite run on the real `data/demo` bundle. Only the `StudentState` is constructed.
- A test that substitutes a bundle there fails review.
