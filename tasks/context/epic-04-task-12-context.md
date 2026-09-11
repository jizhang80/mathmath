# Task 04.12 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: contract-interaction-v1-0-0
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity
- Epic: 04
- Task: 12
- Slug: contract-interaction-v1-0-0
- Summary: Bump `contracts/interaction-contract.md` from v0.9.3 to v1.0.0, replacing the "Bump to v1.0.0 on wrap." sentence in § Finalization owed with "Finalized at v1.0.0." and adjusting the header and Source sentence per arbiter-04 § Q-A ruling text. No normative changes to the contract; all § 2 substantive bullets (answer-card timing, summary content, in-run log entry) were landed in task 04.1. This is a documentation-only, code-free change.
- Invariants in play: I11 (quantitative claims tagged), I12 (English), no time estimates.

## §B. Applicable contract rules (verbatim)

### contracts/README.md — § Lock-first rule
> `data-model`, `graph-constraints`, `content-policy`, `telemetry`, `domain-glossary`, `runtime-tiers` and `deployment-model` **lock before any dependent EPIC starts** — retrofitting them corrupts shipped data, the graph, or the compliance position. Discovery-zone contracts stay open and are finalized just-in-time. A change to a locked contract is a **versioned** change: bump `Contract version`, ripple to every conforming EPIC, and flag the commit scope (`contract(<name>)`) so the ripple is auditable.

Source: `contracts/README.md:40-44`
Binds this task: `interaction-contract.md` is discovery-zone and is finalized just-in-time at the Demo wrap; the v1.0.0 version flip follows the discipline of a versioned change (commit scope `contract(interaction-contract)`).

### contracts/README.md — § The set, interaction-contract row
> | [`interaction-contract.md`](interaction-contract.md) | discovery — finalize just-in-time (Demo EPIC) | runtime contract test: state-machine property tests in `CoreTests` (EPIC-time) | the three doors as state machines: expedition, diagnosis, marker/trail |

Source: `contracts/README.md:19` (row quoted from table)
Binds this task: this task lands the contract text only; the v1.0.0 finalization is stated in the version line.

## §C. Relevant domain-doc excerpts (verbatim)
None. This task touches only the contract header, source sentence, and § Finalization owed paragraph. No domain doc is edited in this task.

## §D. Prior task outputs this task depends on
- **task 04.1** (`contract-interaction-card-timing-summary-tint`): `contracts/interaction-contract.md` v0.9.3 pre-state. Quoted below in §E.
- **EPIC 03 task 03.1** (`contract-interaction-marker-unit-list`): `contracts/interaction-contract.md` v0.9.2 pre-state. Quoted in §E for reference.

Source task specs: `tasks/epic-03-task-01-contract-interaction-marker-unit-list.md` (v0.9.2 text, §3 and §4), `tasks/epic-04-task-01-contract-interaction-card-timing-summary-tint.md` (v0.9.3 text, §3).

## §E. Negative facts (confirmed ABSENT)
- No new error code is registered in this task. `contracts/error-codes.json` is untouched. Source: confirmed by the task spec and arbiter ruling; `error-codes.json` gains no entry for v0.9.x or v1.0.0 bumps (error codes are only added for new error types, not for contract finalization).
- No `docs/domains/` file is edited in this task. The domain docs were edited in task 04.1. Source: `contracts/README.md` enforcement ladder shows "runtime contract test" for interaction-contract; prose edits are out of scope for this wrap task.
- No `docs/DEFERRED.md` entry is added in this task. Both DEFERRED entries (region tint deltas, hint tiers 2–3) were added in task 04.1. Source: task 04.1 spec §2 names task 04.1 as "the single EPIC 04 writer of `docs/DEFERRED.md`".
- No new code (Core, App, or pipeline) is written in this task. Source: brief §8 task 8 names this as the wrap-task contract-version flip only.

## §F. File scope
Files this task may create or touch. Mark each create / modify and cite existence for modifies.

- MODIFY `contracts/interaction-contract.md:1-7` — **Contract version** line (header and Source sentence append). Current shape: lines 3–7 hold v0.9.1 header and source history through the probe "available" definition (arbiter Q-G).
- MODIFY `contracts/interaction-contract.md:117-119` — **§ Finalization owed by the Demo EPIC** paragraph. Current shape: three-item list (marker drag, answer-card timing, summary tint deltas) plus "Bump to v1.0.0 on wrap."

## §G. Stack constraints relevant here
- **Commitment convention:** One commit, subject `contract(interaction-contract): finalize v1.0.0 (Demo wrap)`, scoped per `contracts/README.md` § Lock-first rule. Precedent: task 03.1 commit `contract(interaction-contract): marker set only from the unit list, no drag (v0.9.2)`.
- **Verbatim authority:** All contract text is sourced from `tasks/arbitration/arbiter-04-predispatch.md` § Q-A Wrap section (lines 100–103, exact instruction on header, source-sentence append, and Finalization owed replacement). No paraphrase.
- **Byte-verification:** Every quoted edit block below must be character-exact to the arbiter ruling; this task records no deviations.

## §H. Pre-state (v0.9.3, from task 04.1)

### contracts/interaction-contract.md — version line (v0.9.3, pre-state this task receives)
Source: `tasks/epic-04-task-01-contract-interaction-card-timing-summary-tint.md:382-391`
```
**Contract version:** v0.9.3 (discovery zone — finalized just-in-time by the Demo EPIC) · Source: brief v2
§7, D23, D27, D44–D48, v2.7 §3; `map.md`, `expedition.md`, `diagnosis.md`; v0.9.1 adds the numeric
normalisation rule (expedition Q4), the `remediated(p)` predicate and its two ripples (arbiter Q-A,
`tasks/arbitration/arbiter-02-predispatch.md`), the `past_last_unit` marker text (arbiter Q-F), and the
probe "available" definition (arbiter Q-G); v0.9.2 resolves the marker-drag finalization item (arbiter Q-B,
`tasks/arbitration/arbiter-03-predispatch.md`); v0.9.3 resolves the answer-card timing and summary-tint
finalization items and records the in-run abandoned log entry (arbiter Q-A, Q-G,
`tasks/arbitration/arbiter-04-predispatch.md`)
```

### contracts/interaction-contract.md — § Finalization owed (v0.9.3, pre-state this task receives)
Source: `tasks/epic-04-task-01-contract-interaction-card-timing-summary-tint.md:407-411`
```
## Finalization owed by the Demo EPIC
Nothing remains owed. Resolved in v0.9.2: the marker is set from the unit list only — § 3; no drag. Resolved
in v0.9.3: the answer card stays until the student continues, and the summary shows no region tint deltas —
§ 2. Bump to v1.0.0 on wrap.
```

## §I. Normative text to land (exact — arbiter-04 § Q-A Wrap section)

### Header and Source sentence append (lines 100–102)
Source: `tasks/arbitration/arbiter-04-predispatch.md:100-103`
```
The header becomes `**Contract version:** v1.0.0 (finalized by the Demo EPIC)`. Append to the Source sentence: 
`; v1.0.0 closes the discovery zone at the Demo wrap`.
```

### § Finalization owed replacement (line 102–103)
Source: `tasks/arbitration/arbiter-04-predispatch.md:102-103`
```
In § Finalization owed by the Demo EPIC, replace the last sentence ("Bump to v1.0.0 on wrap.") with
`Finalized at v1.0.0.` No normative text changes at the flip.
```

## §J. Conformance notes
- **I11 (no time estimates):** This task adds no quantitative claims.
- **I12 (English):** All text is in English; no translation touches are in this task.
- **Discovery-zone finalization:** `interaction-contract.md` is the only discovery-zone contract touched by EPIC 04; it transitions from v0.9.1 → v0.9.3 (task 04.1) → v1.0.0 (this task, wrap). The three § 2 bullets (answer-card timing, summary content, in-run log entry) that resolve the "Finalization owed" section are already landed in task 04.1; this task only flips the version and records completion.
- **Commit scope:** One commit, subject to be formatted as `contract(interaction-contract): <brief message>` per `contracts/README.md` § Lock-first rule line 43 (`flag the commit scope`).
- **One task writes only.** No other EPIC 04 task touches `contracts/interaction-contract.md` in this wrap; task 04.1 is the sole prior writer (v0.9.3).
