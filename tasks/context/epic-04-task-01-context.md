# Task 04.1 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: contract-interaction-card-timing-summary-tint
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity
- Epic: 04
- Task: 01
- Slug: contract-interaction-card-timing-summary-tint
- Sub-epic: 04a (Door core)
- Kind: contract
- Summary: bump `contracts/interaction-contract.md` from v0.9.2 (landing from EPIC 03.1) to v0.9.3, landing the ruling texts from arbiter-04 for answer-card timing (Q-A), summary content (Q-A), in-run log entry (Q-G), and the hypothesis-card cost line (Q-D). Also bumps `contracts/domain-glossary.md` to v1.0.1 with a remediation clarification (Q-B), cascades three edits to `docs/domains/diagnosis.md` (Q-D once, Q-B twice) and `docs/domains/learning-objects.md` per the hint-fallback reconciliation, and lands two DEFERRED entries (Q-A region-tint deltas; Q-F hint tiers 2–3). This task is the single writer of `docs/DEFERRED.md` in EPIC 04.
- Invariants in play: **I2** (Tier 0 only, never guesses), **I3** (answers shown, never withheld), **I5** (no PII), **I6** (no Ministry text), **I14** (`Core` renders nothing, logic only), **I15** (landmarks sourced).

## §B. Applicable contract rules (verbatim)

### contracts/README.md — §Lock-first rule — contract versioning discipline

> `data-model`, `graph-constraints`, `content-policy`, `telemetry`, `domain-glossary`, `runtime-tiers` and `deployment-model` **lock before any dependent EPIC starts** — retrofitting them corrupts shipped data, the graph, or the compliance position. Discovery-zone contracts stay open and are finalized just-in-time. A change to a locked contract is a **versioned** change: bump `Contract version`, ripple to every conforming EPIC, and flag the commit scope (`contract(<name>)`) so the ripple is auditable.

Source: `contracts/README.md:40-44`
Binds this task: `domain-glossary.md` is LOCK-FIRST; `interaction-contract.md` is discovery-zone finalized just-in-time by the Demo EPIC. Both require versioned bumps with `Contract version` line edits and commit scopes `contract(domain-glossary)` and `contract(interaction-contract)`.

### contracts/content-policy.md — §Voice — no scores on student surfaces

> Teacher, not chatbot: one thing at a time, no persona, no filler, no scores or percentages on student surfaces; a node is named, the student never is (diagnosis §7 stance).

Source: `contracts/content-policy.md:53-55`
Binds this task: the summary shows no region tint delta (arbiter-04 § Q-A) and no fraction; the map re-tints on return instead.

## §C. Relevant domain-doc excerpts (verbatim from normative sources)

### docs/domains/expedition.md — expedtion Q6 (ratified text enabling the in-run log entry ruling)

The brief §2 of `docs/epics/epic-04-app-expedition-diagnosis-acceptance.md` references this as "a terminated run is logged as abandoned and the next launch starts fresh" (line 266 of arbiter-04). The exact ratified text from expedition Q6 (lines 203–207 of arbiter-04 § Q-G citations) is the source for the Q-G ruling and the contract bullet "In-run log entry (expedition Q6)".

Source: `tasks/arbitration/arbiter-04-predispatch.md:313-314` (citation, not quoted in full here; arbiter § Q-G line 266-291 reconstructs the rule)
Binds this task: the Q-G ruling confirms Q6 is met without a schema change, using in-run write-ahead.

## §D. Normative ruling texts (exact, from arbiter-04-predispatch.md and arbiter-04-hint-fallback-reconciliation.md)

### Task 1 contract text — arbiter-04 § Q-A (answer-card timing, summary content, in-run log entry)

**Exact text for § 2 Expedition, after `answer(item)` bullet:**

> - **Answer card (timing):** after every checked item — expedition item, retry or probe item — the answer card
>   (correct/incorrect, the correct answer, `why`) stays on screen until the student taps an explicit continue
>   control. There is no timer and no auto-advance. No next item, probe item, hypothesis card, remediation,
>   terminal line or summary is reachable before that tap (I3).

Source: `tasks/arbitration/arbiter-04-predispatch.md:79-82`

**Exact text for § 2 Expedition, after `end` bullet:**

> - **Summary content:** the summary lists the nodes cleared this run, the fog lifted, the nodes marked
>   `blocked`, and offers "Start another" and "Back to the map". It shows no region tint delta and no fraction;
>   the re-derived map shows the tint on return (map W6).
> - **In-run log entry (expedition Q6):** while a run is in progress, the persisted `StudentState` carries that
>   run's `expedition_log` entry exactly as `end` with `abandoned = true` would write it at that moment; `end`
>   replaces it with the final entry. A run the OS terminates is therefore logged as abandoned and never
>   resumed. No field is added.

Source: `tasks/arbitration/arbiter-04-predispatch.md:86-92`

**Exact text for § Finalization owed by the Demo EPIC:**

> Nothing remains owed. Resolved in v0.9.2: the marker is set from the unit list only — § 3; no drag. Resolved
> in v0.9.3: the answer card stays until the student continues, and the summary shows no region tint deltas —
> § 2. Bump to v1.0.0 on wrap.

Source: `tasks/arbitration/arbiter-04-predispatch.md:96-98`

**Version line patch (append to Source sentence):**

> ; v0.9.3 resolves the answer-card timing and summary-tint finalization items and records the in-run
> abandoned log entry (arbiter Q-A, Q-G, `tasks/arbitration/arbiter-04-predispatch.md`)

Source: `tasks/arbitration/arbiter-04-predispatch.md:74-75`

### Task 1 DEFERRED entry — arbiter-04 § Q-A (region-tint deltas)

**Exact text:**

```
### D-n — Region tint deltas on the expedition summary
**Observed:** interaction-contract v0.9.3 § 2 resolves the summary to nodes cleared, fog lifted, blocked marked,
"Start another" / "Back to the map", with no region tint delta (arbiter-04 Q-A). A per-region fraction on a
student surface would conflict with content-policy § Voice ("no scores or percentages on student surfaces").
**Configuration:** Demo (`data/demo`); the map re-tints on return (map W6).
**Revisit trigger:** Demo observations (DEMO-BRIEF §7 items 2 and 3).
**Hypothesis (unverified):** none.
```

Source: `tasks/arbitration/arbiter-04-predispatch.md:108-115`
Binds this task: append this entry after the current last entry in `docs/DEFERRED.md`; take the next free `D-n` id at implementation time.

### Task 1 DEFERRED entry — arbiter-04 § Q-F (hint tiers 2–3)

**Exact text:**

```
### D-n — Hint tiers 2–3 ("ask for the next hint") on Door A screens
**Observed:** EPIC 04 shows only tier 1 of the resolved hint (arbiter-04 Q-F, per DEMO-BRIEF §3.6 "one
level"); `data/demo` carries three tiers per `hint_tree` entry (schema minItems/maxItems 3).
**Configuration:** Demo, Tier 0, iOS app.
**Revisit trigger:** Demo observations, or EPIC 12 (M3 screens on real data).
**Hypothesis (unverified):** none.
```

Source: `tasks/arbitration/arbiter-04-predispatch.md:360-367`
Binds this task: append this entry after the region-tint entry; this task is the single writer of `docs/DEFERRED.md` in EPIC 04.

### Task 1 contract text — arbiter-04 § Q-D (cost line and diagnosis.md edit)

**Exact text for diagnosis.md § W3 step 1:**

From arbiter-04 § Q-D cascade (line 251-252):
> `docs/domains/diagnosis.md` W3 step 1: replace `("two quick questions, about a minute")` with `("two quick checks, about a minute")`.

Source: `tasks/arbitration/arbiter-04-predispatch.md:251-252`
Binds this task: the diagnosis.md W3 step 1 edit uses exactly this wording (note "checks" not "questions").

### Task 1 contract text — arbiter-04 § Q-B (glossary v1.0.1, diagnosis.md edits, learning-objects.md edits)

**Exact text for `contracts/domain-glossary.md` header v1.0.1:**

> **Contract version:** v1.0.1 · Source: `docs/domains/*.md`, `docs/idea.md` (D1–D49); v1.0.1 clarifies Remediation for nodes without an Explanation (arbiter-04 Q-B)

Source: `tasks/arbitration/arbiter-04-predispatch.md:197-198`

**Exact text for Remediation in glossary § Diagnosis (Door A):**

> **Remediation** — one Explanation or WorkedExample for a confirmed candidate; when the node carries neither, its `paraphrase` plus one tier-1 hint (DEMO-BRIEF §3.6).

Source: `tasks/arbitration/arbiter-04-predispatch.md:200-201`

**Exact text for diagnosis.md § Core entities, Remediation:**

> one `Explanation` or `WorkedExample` from **learning-objects** — or, when the node carries neither, its `paraphrase` plus one tier-1 hint (DEMO-BRIEF §3.6) — then return.

Source: `tasks/arbitration/arbiter-04-predispatch.md:205-206`

**Exact text for diagnosis.md § UI surfaces, remediation:** 

> (W4, one explanation or worked example, else the paraphrase and one tier-1 hint)

Source: `tasks/arbitration/arbiter-04-predispatch.md:207-208`

### Task 1 contract text — arbiter-04-hint-fallback-reconciliation.md Rule 5 amendments

**Glossary header (v1.0.1) — amended by reconciliation:**

> **Contract version:** v1.0.1 · Source: `docs/domains/*.md`, `docs/idea.md` (D1–D49); v1.0.1 clarifies Remediation for nodes without an Explanation and the two none-of-these tokens (arbiter-04 Q-B; arbiter-04-hint-fallback-reconciliation)

Source: `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md:111`
Binds this task: the glossary header amendment adds the reconciliation reference.

**Glossary § Diagnosis (Door A), Remediation — amended by reconciliation:**

> **Remediation** — one Explanation or WorkedExample for a confirmed candidate; when the node carries neither, its `paraphrase` plus, when one resolves, one tier-1 hint (DEMO-BRIEF §3.6).

Source: `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md:115`
Binds this task: this replaces the arbiter-04 § Q-B text above, to reflect that the hint part is omitted when the key is nil.

**Glossary :45, Error type (new entry):**

> **Error type** (`ErrorType`) — a member of a node's closed catalogue, incl. the none-of-these member, whose catalogue id is `none-of-these`; `classify` reports abstention as the outcome token `none_of_these`, which is never a catalogue id or a `hint_tree` key.

Source: `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md:118`
Binds this task: add this Error type definition to the glossary.

**docs/domains/diagnosis.md edits — amended by reconciliation:**

- **§ Core entities, Remediation:** Replace the arbiter-04 text above with:
  > one `Explanation` or `WorkedExample` from **learning-objects** — or, when the node carries neither, its `paraphrase` plus, when one resolves, one tier-1 hint (DEMO-BRIEF §3.6) — then return.

  Source: `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md:121`

- **§ UI surfaces:** Replace the arbiter-04 text above with:
  > (W4, one explanation or worked example, else the paraphrase and, when one resolves, one tier-1 hint)

  Source: `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md:122`

**docs/domains/learning-objects.md edits — amended by reconciliation (spelling and W2 definition):**

Source: `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md:125-132`

The task lands these edits per the reconciliation Rule 5:
- Line 41-42: "with exactly one terminal `none_of_these`" → "with exactly one terminal member `none-of-these` (catalogue id; `classify`'s abstention outcome is the token `none_of_these`)"
- Line 47-48: "and `none_of_these` is always `null`: abstention, not diagnosis." → "and `none-of-these` is always `null`: abstention, not diagnosis."
- Line 75: "exactly one `none_of_these`" → "exactly one `none-of-these`"
- Line 77: "every ErrorType but `none_of_these` has a full tier list" → "every ErrorType but `none-of-these` has a full tier list (a `none-of-these` entry is optional; when present it is the node's generic hint)"
- W2 step 1 (lines 92-93): "a miss raises `LO_HINT_NOT_FOUND` and the session falls back to the node's generic tier-1 hint" → "a miss raises `LO_HINT_NOT_FOUND` (internal data) and the session falls back to the node's generic tier-1 hint, `hint_tree["none-of-these"][0]`, else the node's `paraphrase`; never another ErrorType's hint (I2)"
- Add changelog row (line 2026-09-10): `| 2026-09-10 | Catalogue id spelled \`none-of-these\`; W2 generic hint defined (arbiter-04-hint-fallback-reconciliation). |`

## §E. Pre-state: v0.9.2 text from EPIC 03.1 (the immediate predecessor task)

EPIC 03 task 03.1 (`tasks/epic-03-task-01-contract-interaction-marker-unit-list.md`) lands v0.9.2 **before** this task runs. The v0.9.2 pre-state for this task is:

**Version line after EPIC 03.1 (v0.9.2):**

```
**Contract version:** v0.9.2 (discovery zone — finalized just-in-time by the Demo EPIC) · Source: brief v2
§7, D23, D27, D44–D48, v2.7 §3; `map.md`, `expedition.md`, `diagnosis.md`; v0.9.1 adds the numeric
normalisation rule (expedition Q4), the `remediated(p)` predicate and its two ripples (arbiter Q-A,
`tasks/arbitration/arbiter-02-predispatch.md`), the `past_last_unit` marker text (arbiter Q-F), and the
probe "available" definition (arbiter Q-G); v0.9.2 resolves the marker-drag finalization item (arbiter Q-B,
`tasks/arbitration/arbiter-03-predispatch.md`)
```

Source: `tasks/epic-03-task-01-contract-interaction-marker-unit-list.md:244-249`

**§ Finalization owed by the Demo EPIC (v0.9.2):**

```
## Finalization owed by the Demo EPIC
The timing of the answer card; whether the summary shows region tint deltas. Bump to v1.0.0 on wrap.
(Resolved in v0.9.2: the marker is set from the unit list only — § 3; no drag.)
```

Source: `tasks/epic-03-task-01-contract-interaction-marker-unit-list.md:265-268`

This task bumps only the version line and the Finalization section.

## §F. Dependent on EPIC 03.1 status

This task is blocked until EPIC 03 task 03.1 merges and v0.9.2 lands in `contracts/interaction-contract.md`. The pre-state quoted in §E above must be present before this task's writer can begin.

Source: `docs/plans/epic-04-plan.md:11` (confirmed: "EPIC 04 starts only after EPIC 03 is merged")

## §G. File scope

In-scope (the implementer touches EXACTLY these files):

- `contracts/interaction-contract.md` — MODIFY. Version line append with v0.9.3 text; insert three new bullets in § 2 Expedition (`answer card (timing)`, `summary content`, `in-run log entry`); replace § Finalization owed paragraph. (Four edits total.)
- `contracts/domain-glossary.md` — MODIFY. Version line to v1.0.1; add Error type definition (line ≈ 45); replace Remediation text in § Diagnosis (Door A) (line ≈ 43).
- `docs/domains/diagnosis.md` — MODIFY. Three edits: W3 step 1 (replace "questions" with "checks"); § Core entities Remediation (replace to add "paraphrase plus hint" branch); § UI surfaces (replace to add "when one resolves" wording).
- `docs/domains/learning-objects.md` — MODIFY. Five spelling/definition edits per reconciliation: lines ≈ 41–42, 47–48, 75, 77, 92–93. Add changelog row.
- `docs/DEFERRED.md` — MODIFY. Append two new entries: region-tint deltas (D-n) and hint tiers 2–3 (D-m). This task is the single EPIC 04 writer of this file. Take next free id at implementation time.

Out-of-scope (do not touch):

- `contracts/error-codes.json`, `contracts/error-codes.md`, `CoreError.swift` — arbiter-04 § Q-B notes "`error-codes.json` gains no entry"; LO_HINT_NOT_FOUND is already registered as internal. Task 04.3 adds the `CoreError` case.
- `data/demo/**` — no data edit in task 04.1. A separate data task 04.1b (planned in the planner) may land `hint_tree["none-of-these"]` per the reconciliation Rule 4.
- `Packages/Core/**`, `App/Sources/**` — contract/docs only.
- `pipeline/**` — no executable surface.

## §H. Negative facts (confirmed ABSENT)

- **No existing D-15, D-16, D-17 DEFERRED entries yet.** `docs/DEFERRED.md:135-147` shows last entry is D-13 (line 135). Next free id is D-15 (D-14 was used by EPIC 03.1). Source: `docs/DEFERRED.md:135` read directly.
- **No `CoreError.loHintNotFound` case yet.** `Packages/Core/Sources/Core/CoreError.swift:11-27` contains no loHintNotFound case (Grep query: `grep -n "loHintNotFound" Packages/Core/Sources/Core/CoreError.swift` returned no match — verified 2026-09-10). This case lands in task 04.3, not here.
- **No `render_fallback: "katex"` entries in `data/demo`.** Arbiter-04 § Q-E line 329 and `docs/epics/epic-01-rendering-spike-outcome.md` confirm 0 unresolved of 143. Source: arbiter-04 predispatch (citations page 330).

## §I. Stack constraints and binding rules

### Version targets and commit scope

- `interaction-contract.md` → v0.9.3 (this task), then v1.0.0 at wrap (task 04.13).
- `domain-glossary.md` → v1.0.1 (this task). No further bumps in EPIC 04.

Commit scopes:
- `contract(interaction-contract)` for the three v0.9.3 bullets and Finalization edit.
- `contract(domain-glossary)` for the glossary v1.0.1 bump and the Remediation edit.

These are separate commits, per `contracts/README.md` § Lock-first rule (line 43: "versioned change: bump `Contract version`, ripple to every conforming EPIC, and flag the commit scope").

### DEFERRED.md template and writer rule

Source: `docs/DEFERRED.md:6-20` (entry template C6)
Binds this task: entries must use the four-field template exactly (Observed, Configuration, Revisit trigger, Hypothesis).

Source: `docs/plans/epic-04-plan.md:45` ("docs/DEFERRED.md has exactly one writer in EPIC 04: this task.")
Binds this task: this task is the only EPIC 04 writer of `docs/DEFERRED.md`. No concurrent task lands a DEFERRED entry.

### Invariant enforcement in text

Source: `CLAUDE.md` I2 (line 239): "Tier 0 alone must be a usable product: every model call has a confidence threshold and a deterministic fallback; the system never guesses a diagnosis."

The reconciliation (arbiter-04-hint-fallback-reconciliation.md) resolves a conflict between arbiter-04 § Q-B and arbiter-02-none-of-these over what "never guesses" means when no hint key resolves. The Task 1 landing carries arbiter-04's text; the reconciliation's Rule 5 amends it. Both are binding. Source: arbiter-04-hint-fallback-reconciliation.md:152-160.

### No `Core` or pipeline changes

This task ships documentation only. No Codable schema, no `Core` type, no pipeline module, no executable.

Source: `docs/epics/epic-04-app-expedition-diagnosis-acceptance.md:149` ("Layer ④ interaction"; task 04.1 is Layer ④ only for the contract/docs).

## §J. Quote audit (all blocks re-read and byte-verified)

All quoted sections above were re-read from their cited sources immediately before writing:

- arbiter-04-predispatch.md: Q-A answer-card bullets (lines 79–92 reread ✓), Q-A summary and finalization text (lines 96–98 reread ✓), Q-D cost-line replacement (lines 251–252 reread ✓), Q-B glossary header and Remediation (lines 197–201 reread ✓), Q-B diagnosis.md cascade (lines 205–208 reread ✓), Q-A DEFERRED region-tint (lines 108–115 reread ✓), Q-F DEFERRED hint-tiers (lines 360–367 reread ✓).
- arbiter-04-hint-fallback-reconciliation.md: Rule 5 glossary header (line 111 reread ✓), Remediation (line 115 reread ✓), Error-type definition (line 118 reread ✓), learning-objects.md edits (lines 125–132 reread ✓).
- EPIC 03 task 01 spec: v0.9.2 version line and Finalization (lines 244–249, 265–268 reread ✓).
- contracts/domain-glossary.md current state: version line v1.0.0 (line 3 reread ✓), Remediation (line 43 reread ✓).
- docs/DEFERRED.md: last entry D-13 (line 135 reread ✓), template (lines 6–20 reread ✓).
- contracts/README.md: Lock-first rule (lines 40–44 reread ✓).
- contracts/content-policy.md: Voice section (lines 53–55 reread ✓).

**Audit result:** All blocks verified to source. No discrepancies found. No RECONSTRUCTED entries (all quoted verbatim from source files).
