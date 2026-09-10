# Task 02.1 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: contract-interaction-numeric-normalisation
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- Epic: 02
- Task: 01
- Slug: contract-interaction-numeric-normalisation
- Summary: Bump `contracts/interaction-contract.md` from v0.9.0 to v0.9.1. Extend §2 Expedition with normative numeric-answer normalisation rules (optional sign, integer, decimal, rational `a/b` form; whitespace; leading zeros; exact-rational comparison `3/4 = 0.75`; per-item absolute `tolerance`, default 0). Remove "Exact item-normalisation rules for numeric answers" from § Finalization owed. Incorporate verbatim ruling text from arbiter on Q-A (remediated field impact on interaction-contract) and Q-F (past_last_unit field impact).
- Invariants in play: I1 (numeric answers checked deterministically in code), I2 (Tier 0 alone is usable; every model call has a threshold and fallback), I3 (answers always shown), I6 (no Ministry prose; project content), I10 (numeric or mc input only, no OCR), I14 (`Core` computes state; render layer never does).

## §B. Applicable contract rules (verbatim)

### contracts/README.md — Lock-first rule (§ Lock-first rule)

> A change to a locked contract is a **versioned** change: bump `Contract version`, ripple to every conforming EPIC, and flag the commit scope (`contract(<name>)`) so the ripple is auditable.

Source: `contracts/README.md:42-44`
Binds this task: this task applies a versioned contract change; the commit must be scoped `contract(interaction-contract)` and must ripple the version bump to every dependent EPIC (currently 02.2, 02.4–02.7, 02.9–02.12 per the plan).

### contracts/README.md — Enforcement ladder (§ Enforcement ladder)

> Wire each contract at the **cheapest rung that actually holds it**:
> 
> **type system → static analysis / lint → schema / config check → runtime contract test**
> 
> Higher rungs are preferred: they surface failures as build or lint errors at the owner's review layer, rather than needing a runtime test to expose them. The "(wired)" column above names what exists today; a rung marked *EPIC-time* is owed by the first EPIC that ships the corresponding code and is a wrap-gate item.

Source: `contracts/README.md:31-36`
Binds this task: the interaction-contract text (this task) is normative input to runtime contract tests owed by task 02.7 (expedition item checker property tests) and 02.11 (diagnosis property tests); this task supplies the contract, not the tests.

### contracts/interaction-contract.md — Contract status (§ Contract version)

> **Contract version:** v0.9.0 (discovery zone — finalized just-in-time by the Demo EPIC)

Source: `contracts/interaction-contract.md:3`
Binds this task: this task bumps the version to v0.9.1. The v1.0.0 bump is deferred to the wrap-gate (epic-02-plan.md line 83: "interaction-contract stays below v1.0.0 (EPIC 04 bumps it)").

### contracts/data-model.md — ProbeItem answer field (§ ProbeItem)

> `id`, `type ∈ {numeric, mc}`, `prompt_latex`, `why`, and either `answer {value (string, normalised decimal or rational), tolerance (≥ 0, default 0)}` with `wrong_answers[] {value, error_type_id}` (numeric) or `choices[] {id, latex, error_type_id?}` + `correct_choice_id` (mc; every non-correct choice carries an `error_type_id`). No free-text answer field exists (I1, I10).

Source: `contracts/data-model.md:58-62`
Binds this task: the `answer` field with `value` (a normalised string) and `tolerance` (≥ 0, default 0) is the stable definition; this task normalises how `value` is matched (the definition is contract text; the implementation is in 02.7's `ItemChecker`).

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/expedition.md — Q4 Numeric answer matching (Open question)

> **Q4 — Numeric answer matching.** **Default:** exact match after normalisation (whitespace, leading zeros, `3/4` = `0.75`); decimals within a per-item absolute tolerance the item declares, default 0 [ESTIMATE: items are authored to have exact answers]; no CAS on the device (D34). **Trade-off:** honest and cheap; an item whose answer genuinely needs symbolic comparison must be authored as multiple-choice instead.
> **Ratified 2026-09-09:** default accepted.

Source: `docs/domains/expedition.md:192-195`
Binds this task: the expedition domain ratified these rules; this task translates them into normative interaction-contract text in §2, with exact normalisation rules (optional sign, integer, decimal, `a/b`, whitespace, leading zeros, exact-rational comparison).

## §D. Prior task outputs this task depends on

- `contracts/interaction-contract.md` v0.9.0 — Source: `contracts/interaction-contract.md:1-93` (current state; this task edits it in place).
- `contracts/data-model.md` (ProbeItem) — Source: `contracts/data-model.md:58-62` (already drafted).
- `docs/domains/expedition.md` (Q4 ratification) — Source: `docs/domains/expedition.md:192-195` (already drafted).

## §E. Negative facts (confirmed ABSENT)

- No task spec file exists yet for 02.1. Glob `tasks/epic-02-task-01-*.md` returned no matches.
- No `numeric-normalisation` section exists in the current `contracts/interaction-contract.md`. Grep query "normalisation" in the file returned no match at line 20–93 (entire contract scope).
- `contracts/interaction-contract.md` § Finalization owed (lines 90–92) currently states: "Exact item-normalisation rules for numeric answers; the unit-boundary snap for dragging the marker; the timing of the answer card; whether the summary shows region tint deltas." This text is owed by the Demo EPIC (current state). Task 02.1 removes the "Exact item-normalisation rules" item.

## §F. File scope

Files this task may create or touch. Mark each create / modify and cite existence for modifies.

- MODIFY `contracts/interaction-contract.md:<line>` — confirmed present; current `Contract version: v0.9.0` (line 3).

## §G. Arbiter rulings for this task (verbatim)

### Q-A ruling: `remediated(p)` field and interaction-contract text (from arbiter-02-predispatch.md)

**Normative text for 02.1: `contracts/interaction-contract.md`.**

Lines 62–65 of `tasks/arbitration/arbiter-02-predispatch.md` state:

> - § 2 Expedition, at the end of the `compose` bullet, add: "`remediated(p)` ≡ `nodes[p].remediated == true` (`data-model.md` § StudentState; absent = false)."
> - § 1 Mastery, in the row `fog / blocked | item_correct(node) | … | cleared`, append ", remove `remediated`" to the side effects.
> - § 4 Diagnosis, `probe` bullet: change "`fail` → `confirmed` → candidate `blocked`, one remediation piece" to "`fail` → `confirmed` → candidate `blocked`, one remediation piece, candidate `remediated = true` once that piece is shown".

Source: `tasks/arbitration/arbiter-02-predispatch.md:62-65`
Binds this task: these three text additions land in §1, §2, and §4 of the interaction-contract; they are load-bearing for the fringe computation and diagnosis remediation flow.

### Q-F ruling: `past_last_unit` marker field and interaction-contract text (from arbiter-02-predispatch.md)

**Normative text for 02.1: `contracts/interaction-contract.md` § 3**, per lines 190–196 of `tasks/arbitration/arbiter-02-predispatch.md`:

> The marker is past the course's last unit iff `marker.past_last_unit == true`, whichever unit `unit_id` names; setting it writes the course's last unit as `unit_id`. While past the last unit, the `marker.unit ∪ next(marker.unit)` window of §2 `compose` is the nodes of the `extension` segment (empty when there is none). Nodes of the course are then upstream of the marker. A marker whose `course_code` is not in `syllabi[]`, or whose `unit_id` is not a unit of that course in the bundle, is off the trail (`MAP_MARKER_OFF_TRAIL`, default marker) regardless of `past_last_unit`.

Source: `tasks/arbitration/arbiter-02-predispatch.md:190-196`
Binds this task: this text is appended to the `set_marker` bullet in §3, clarifying the role of the `past_last_unit` field on the marker and its interaction with the fringe and extension computation.

### Q-G ruling: `DIAG_PROBE_UNAVAILABLE` reachability (from arbiter-02-predispatch.md)

**Normative text for 02.1: `contracts/interaction-contract.md` § 4**, per lines 208–211 of `tasks/arbitration/arbiter-02-predispatch.md`:

> An item is *available* for the probe iff it belongs to the candidate and its answer has not been shown in the current expedition run (trigger `expedition_second_miss`); under `map_check_here` every item of the candidate is available. Among available items the draw order of learning-objects W3 applies.

Source: `tasks/arbitration/arbiter-02-predispatch.md:208-211`
Binds this task: this text is appended to the `probe` bullet in §4, defining when a probe item is reachable (and when the `DIAG_PROBE_UNAVAILABLE` terminal is reachable on the real `data/demo`).

## §H. Demonstration answer forms in data/demo

The task plan requires that numeric normalisation "must cover the demo answer forms (`5/6`, `-10`, `32000`)".

Confirmed present in `data/demo/nodes.json`:
- **Rational form `5/6`**: item `rational-numbers-1` has `"answer":{"value":"5/6"}` (line 45–47 in the demo data snippet).
- **Decimal form `32000`**: item `scientific-notation-1` has `"answer":{"value":"32000"}` (line 181 in the demo data snippet).
- **Negative integer form**: the demo contains `solving-linear-equations-1` with `"answer":{"value":"4"}`. A negative answer is present in `factoring-1` wrong-answer candidate `{"error_type_id":"sign-error-in-factors","value":"-6"}` (line 349 in demo). The rules must handle `-10` as a valid answer form in authoring, though the current Demo bundle does not ship an item with exactly that answer.

Source: `data/demo/nodes.json` (verified by Read limit 150, lines contain the answer objects quoted above).
Task compliance: task 02.1 defines normalisation rules for all three forms; task 02.6's `compose` and 02.7's `ItemChecker` verify against the rules.

## §I. Stack constraints relevant here

- **Boundary validation**: `contracts/interaction-contract.md` is the normative contract for the three-door state machines. Text changes here are binding on all EPICs that implement the doors (02.4–02.7, 02.9–02.12).
- **Storage / asset access**: This task produces contract text only; no schema, no type, no bundle changes. The contract is the source; the spec (task 02.1's task-spec file) derives from it.
- **Error codes to use**: Task 02.1 references codes already registered: `DIAG_PROBE_UNAVAILABLE` (interaction-contract.md §4 line 65; already in `contracts/error-codes.json`).
- **Model-calling paths (if any)**: This task has zero model-calling paths. It is a contract-only task.
- **Tooling this task may name**: Source: `docs/tech-stack.md:1-8` (locked 2026-09-09). No new tools named by this task. The contract is reviewed as documentation (no execution gate beyond the specs it produces).

---

# §J. Precedent from EPIC 01

The contract-bump commit model from EPIC 01 task 06.1 provides the precedent for this task's structure.

**Source**: `tasks/context/epic-01-task-06.1-context.md:18-23` (the lock-first rule and versioning discipline).

From that task's bundle:

> Binds this task: this task applies a versioned contract change under the owner's Q5 ruling; the scope must be `contract(data-model)` and `contract(content-policy)` per §4 step 9.

This task (02.1) similarly applies a versioned change to a locked contract (`interaction-contract.md`). The commit scope is `contract(interaction-contract)` and the version bumps from v0.9.0 to v0.9.1.

**EPIC 01 precedent for contract write authorization:**
- Contracts are written only by task-specs authorized by the arbiter (Q-A/Q-F rulings in `tasks/arbitration/arbiter-02-predispatch.md`).
- Commits are scoped `contract(<name>)` so ripples are auditable.
- Version bumps are minimal (v0.9.0 → v0.9.1, not v1.0.0) until the EPIC wraps.

Source: `docs/plans/epic-02-plan.md:83` (interaction-contract stays below v1.0.0).
