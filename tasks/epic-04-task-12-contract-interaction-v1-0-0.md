# Epic 04 · Task 12: Contract v1.0.0 — finalize interaction-contract at the Demo wrap

---
epic: 04
task: 12
slug: contract-interaction-v1-0-0
kind: feat
risk: seam
depends_on: [04.8, 04.9, 04.10]
model: sonnet
---

## §1 Goal & acceptance criteria

Goal: bump `contracts/interaction-contract.md` from v0.9.3 to v1.0.0, closing the discovery zone at the Demo
wrap per arbiter-04 § Q-A's "Wrap" instruction. Two edits only: (1) the header line becomes
`**Contract version:** v1.0.0 (finalized by the Demo EPIC)` and the Source sentence gains an appended clause;
(2) § Finalization owed by the Demo EPIC keeps its heading and has its last sentence ("Bump to v1.0.0 on
wrap.") replaced with "Finalized at v1.0.0." No other line in the file changes — no normative text changes at
the flip. This task runs on branch `epic-04b-door-app`, after `epic-04a-door-core` (which lands task 04.1's
v0.9.3 bump) has merged and after tasks 04.8–04.10 land. This is a documentation-only, code-free change: no
schema, no `Core` type, no pipeline module, no `data/demo` file, no `contracts/error-codes.json` entry, no
`docs/DEFERRED.md` entry is touched.

**Pre-state gate.** This spec is written before `contracts/interaction-contract.md` reaches v0.9.3 on any
branch (it is v0.9.1 on `main` today; v0.9.2 lands via EPIC 03 task 03.1, v0.9.3 via EPIC 04 task 04.1 — both
pre-state texts are quoted verbatim in §3 for the implementer's own verification, not because either has
landed at spec-writing time). Before touching the file, the implementer MUST confirm the on-disk state matches
§3's v0.9.3 pre-state quotes exactly. If the header does not read `v0.9.3`, or § Finalization owed by the Demo
EPIC does not read exactly the single sentence "Bump to v1.0.0 on wrap." as its closing item (with the rest of
the paragraph matching §3's quote), the implementer BLOCKs and does not proceed — this is a genuine
prerequisite-not-landed condition, not an ambiguity to default around.

Invariants in play:

- **I11** — no time estimates: this task adds no quantitative claim; the two edits carry no numeric or
  duration text.
- **I12** — English: all text landed is English; no translation touches occur.
- Not engaged (recorded so the absence is a decision, not a gap): I1 (no item-checking rule touched), I2 (no
  model-calling path), I3 (no answer-visibility text touched), I5 (no identifier field touched), I6 (no
  Ministry text or `paraphrase` field touched), I8 (no L0 rule touched), I14 (no `Core` shape touched — this
  task writes contract text only), I15 (no landmark field touched).

Acceptance criteria (each independently verifiable):

- AC1: `contracts/interaction-contract.md`'s `Contract version` line reads `v1.0.0 (finalized by the Demo
  EPIC)`, and the Source sentence is appended (not replaced) with the exact v1.0.0 closing clause, per §4 step
  1. Instrument: `rg -n "Contract version" contracts/interaction-contract.md`.
- AC2: § Finalization owed by the Demo EPIC keeps its heading and its two "Resolved in v0.9.2 …" / "Resolved
  in v0.9.3 …" sentences unchanged; only the final sentence "Bump to v1.0.0 on wrap." is replaced by "Finalized
  at v1.0.0." Instrument: `rg -n "Finalized at v1.0.0\." contracts/interaction-contract.md` returns one match;
  `rg -n "Bump to v1.0.0 on wrap\." contracts/interaction-contract.md` returns no match.
- AC3: no other line in `contracts/interaction-contract.md` changes. Instrument: `git diff --stat` shows
  exactly one file, `contracts/interaction-contract.md`; `git diff contracts/interaction-contract.md` shows
  changed lines restricted to the version-line block (§4 step 1's block) and the § Finalization owed paragraph
  (§4 step 2's block) — no other hunk.
- AC4: `pipeline/tests/test_contracts.py` and `scripts/check-no-time-estimates.sh` are both green after the
  edit (regression checks; this task touches no field either test inspects).

## §2 File scope

In-scope (the implementer touches EXACTLY this one file; nothing else):

- `contracts/interaction-contract.md` — MODIFY. Version line append; § Finalization owed by the Demo EPIC,
  last-sentence replacement (§4 steps 1–2 below).

Out-of-scope (do not touch even if tempted):

- `contracts/error-codes.json`, `contracts/error-codes.md` — no error code is registered or changed by a
  contract-version flip.
- `contracts/domain-glossary.md` — its own v1.0.1 bump is EPIC 04 task 04.1's file scope, already landed by
  the time this task runs; this task does not touch it.
- `docs/domains/*.md` — no domain doc is edited in this task; the three § 2 substantive bullets (answer-card
  timing, summary content, in-run log entry) were landed in task 04.1, not here.
- `docs/DEFERRED.md` — no new entry; both EPIC 04 entries (region tint deltas, hint tiers 2–3) were added in
  task 04.1, which is "the single EPIC 04 writer of `docs/DEFERRED.md`" per that task's own §1.
- `Packages/Core/**`, `App/Sources/**`, `pipeline/**` (other than running its existing tests as a regression
  check) — no code, no schema, no pipeline module is touched by this task.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/README.md` — heading `## Lock-first rule`:
  > `data-model`, `graph-constraints`, `content-policy`, `telemetry`, `domain-glossary`, `runtime-tiers` and
  > `deployment-model` **lock before any dependent EPIC starts** — retrofitting them corrupts shipped data, the
  > graph, or the compliance position. Discovery-zone contracts stay open and are finalized just-in-time. A
  > change to a locked contract is a **versioned** change: bump `Contract version`, ripple to every conforming
  > EPIC, and flag the commit scope (`contract(<name>)`) so the ripple is auditable.

  Note: `interaction-contract.md` is listed in `contracts/README.md`'s `## The set` table as "discovery —
  finalize just-in-time (Demo EPIC)", not among the seven LOCK-FIRST contracts. This task follows the same
  versioning discipline (bump `Contract version`, scope the commit `contract(interaction-contract)`) because
  the file carries its own `Contract version` line, and this edit is the file's terminal, wrap-time flip out
  of the discovery zone.

- `contracts/README.md` — heading `## The set`, the `interaction-contract.md` row:
  > | [`interaction-contract.md`](interaction-contract.md) | discovery — finalize just-in-time (Demo EPIC) |
  > runtime contract test: state-machine property tests in `CoreTests` (EPIC-time) | the three doors as state
  > machines: expedition, diagnosis, marker/trail |

  Binds this task: the contract change is enforced by runtime property tests in `CoreTests`, authored in prior
  EPIC 03/04 tasks. This task lands the version-line and § Finalization owed text only; it changes no
  behaviour those tests assert.

Arbiter ruling, verbatim, authorizing this task's two edits
(`tasks/arbitration/arbiter-04-predispatch.md:100-103`):

> *Wrap (brief task 8): a `contract(interaction-contract)` commit.* The header becomes `**Contract version:**
> v1.0.0 (finalized by the Demo EPIC)`. Append to the Source sentence: `; v1.0.0 closes the discovery zone at
> the Demo wrap`. In § Finalization owed by the Demo EPIC, replace the last sentence ("Bump to v1.0.0 on
> wrap.") with `Finalized at v1.0.0.` No normative text changes at the flip.

Amended-brief acceptance criterion, verbatim, this task's own AC target
(`docs/epics/epic-04-app-expedition-diagnosis-acceptance.md:403-405`, §4 item 9):

> 9. **Contract**: `interaction-contract.md` reads v1.0.0 and carries the three § 2 bullets landed at v0.9.3
>    (answer-card timing, summary content, in-run log entry). § Finalization owed by the Demo EPIC keeps its
>    heading and reads the ruled paragraph, ending "Finalized at v1.0.0." `domain-glossary.md` reads v1.0.1.

Prior contract text this task edits in place — **v0.9.3 pre-state**, quoted verbatim from the task spec that
lands it (`tasks/epic-04-task-01-contract-interaction-card-timing-summary-tint.md:382-391`). The implementer
MUST confirm the on-disk text matches this block exactly before editing (§1 Pre-state gate):

- Version line:
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

- § Finalization owed by the Demo EPIC, full section
  (`tasks/epic-04-task-01-contract-interaction-card-timing-summary-tint.md:407-411`):
  ```
  ## Finalization owed by the Demo EPIC
  Nothing remains owed. Resolved in v0.9.2: the marker is set from the unit list only — § 3; no drag. Resolved
  in v0.9.3: the answer card stays until the student continues, and the summary shows no region tint deltas —
  § 2. Bump to v1.0.0 on wrap.
  ```

## §4 Implementation outline

This is a documentation-only contract edit. There is no boundary schema, no error code, no storage/asset
access and no model-calling path in this task (§1 records I1–I3, I5, I6, I8, I14, I15 as not engaged). The two
ordered edits below are applied in place, in one commit, after the §1 Pre-state gate passes.

1. **`contracts/interaction-contract.md` — version line.** Change `v0.9.3 (discovery zone — finalized
   just-in-time by the Demo EPIC)` to `v1.0.0 (finalized by the Demo EPIC)` in the header. Append to the end
   of the existing Source sentence (after `` `tasks/arbitration/arbiter-04-predispatch.md`) `` from the v0.9.3
   pre-state quoted in §3, with no period before the append — match the existing sentence's punctuation style,
   which has none at its current end):
   ```
   ; v1.0.0 closes the discovery zone at the Demo wrap
   ```
   Resulting full version-line block:
   ```
   **Contract version:** v1.0.0 (finalized by the Demo EPIC) · Source: brief v2
   §7, D23, D27, D44–D48, v2.7 §3; `map.md`, `expedition.md`, `diagnosis.md`; v0.9.1 adds the numeric
   normalisation rule (expedition Q4), the `remediated(p)` predicate and its two ripples (arbiter Q-A,
   `tasks/arbitration/arbiter-02-predispatch.md`), the `past_last_unit` marker text (arbiter Q-F), and the
   probe "available" definition (arbiter Q-G); v0.9.2 resolves the marker-drag finalization item (arbiter Q-B,
   `tasks/arbitration/arbiter-03-predispatch.md`); v0.9.3 resolves the answer-card timing and summary-tint
   finalization items and records the in-run abandoned log entry (arbiter Q-A, Q-G,
   `tasks/arbitration/arbiter-04-predispatch.md`); v1.0.0 closes the discovery zone at the Demo wrap
   ```
   The `v0.9.1 adds …`, `v0.9.2 resolves …` and `v0.9.3 resolves …` clauses are history and stay untouched —
   only the header's version parenthetical and the sentence's tail change. The `(discovery zone — finalized
   just-in-time by the Demo EPIC)` parenthetical is removed entirely, replaced by `(finalized by the Demo
   EPIC)`, per the ruling's exact header text.

2. **`contracts/interaction-contract.md` § Finalization owed by the Demo EPIC.** Replace only the last sentence
   of the paragraph quoted in §3 ("Bump to v1.0.0 on wrap.") with "Finalized at v1.0.0." The heading and the
   two "Resolved in v0.9.2 …" / "Resolved in v0.9.3 …" sentences are unchanged. Resulting full section:
   ```
   ## Finalization owed by the Demo EPIC
   Nothing remains owed. Resolved in v0.9.2: the marker is set from the unit list only — § 3; no drag. Resolved
   in v0.9.3: the answer card stays until the student continues, and the summary shows no region tint deltas —
   § 2. Finalized at v1.0.0.
   ```

3. **Commit.** One commit, subject `contract(interaction-contract): finalize v1.0.0 (Demo wrap)`, touching
   exactly the one file of §2. The PR description names the ruling this task carries out (arbiter-04 § Q-A
   "Wrap", `tasks/arbitration/arbiter-04-predispatch.md`) and states explicitly that no normative text changed.

4. **Negative control record.** Before editing, run and record the pre-edit grep results (they are the T2/T5
   negative baseline in §5):
   - `rg -n "Contract version" contracts/interaction-contract.md` — expected pre-edit match: the v0.9.3 header
     line quoted in §3.
   - `rg -n "Bump to v1.0.0 on wrap\." contracts/interaction-contract.md` — expected pre-edit match: one, inside
     § Finalization owed.
   - `rg -n "Finalized at v1.0.0\." contracts/interaction-contract.md` — expected pre-edit match: none.

5. **Smoke check.** `rg -n "Contract version|finalized by the Demo EPIC|closes the discovery zone at the Demo
   wrap|Finalized at v1\.0\.0\." contracts/interaction-contract.md` — must show every new string present.
   `rg -n "Bump to v1\.0\.0 on wrap\.|discovery zone — finalized just-in-time by the Demo EPIC"
   contracts/interaction-contract.md` — must return no match (both superseded strings gone). `git diff --stat`
   shows exactly one file changed, `contracts/interaction-contract.md`. `pipeline/tests/test_contracts.py` and
   `scripts/check-no-time-estimates.sh` both green.

## §5 Test plan (seam risk — full plan)

This task ships no code, so its "tests" are the verifiable textual assertions below — the cheapest rung that
actually holds prose contract text (`contracts/README.md` § Enforcement ladder: "type system → static
analysis / lint → schema / config check → runtime contract test"; a grep-based content assertion is the lint
rung). The file's behavioural conformance (the three doors as state machines) is proven at the
runtime-contract-test rung by `CoreTests` property tests authored in prior EPIC 03/04 tasks; this task changes
no behaviour those tests assert, only the version marker and the wrap-completion sentence.

- **T1 happy path.** Confirm the §1 Pre-state gate passes (on-disk text matches the v0.9.3 quotes of §3
  exactly). Apply the two edits of §4. Run the smoke check of §4 step 5; every grepped string is present
  exactly where §4 places it (verified by a full read of the file after edit, not just the grep match count).
  `pipeline/tests/test_contracts.py` and `scripts/check-no-time-estimates.sh` are run and stay green — this
  task touches no error-registry row and adds no quantitative claim.
- **T2 negative — invalid input rejected at the boundary.** Not applicable in the schema/code sense (this task
  validates no runtime input). The prose equivalent: confirm the *old* text each edit replaces no longer
  appears unmodified, against the §4 step 4 negative-control baseline —
  - `rg -n "Bump to v1\.0\.0 on wrap\." contracts/interaction-contract.md` returns no match post-edit (had one
    match pre-edit);
  - `rg -n "v0\.9\.3 \(discovery zone — finalized just-in-time by the Demo EPIC\)"
    contracts/interaction-contract.md` returns no match post-edit (had one match pre-edit, as the header line).

  A diff that leaves the old text duplicated alongside the new one is a FAIL.
- **T3 error-taxonomy.** Nothing to assert: this task registers no error code in `contracts/error-codes.md` /
  `error-codes.json` and touches no registry row. `git diff -- contracts/error-codes.json` is empty. Recorded
  explicitly so the omission is a decision, not a gap.
- **T4 conformance per §3 / cited contract and invariants.** Re-read the edited file top to bottom and confirm:
  (a) both edits of §4 appear verbatim as specified, with no adjacent text altered; (b) the version line names
  `v1.0.0 (finalized by the Demo EPIC)` and the appended clause (AC1); (c) § Finalization owed keeps its
  heading and both "Resolved in …" sentences, with only the closing sentence replaced (AC2); (d) I11 holds — no
  new quantitative claim, tagged or otherwise, is introduced; (e) I12 holds — all landed text is English.
- **T5 negative control for every regression guard.** The regression guard this task installs is the grep set
  of §4 step 5. Its negative control: temporarily revert one edit (e.g. re-insert "Bump to v1.0.0 on wrap." in
  place of "Finalized at v1.0.0.") and confirm the smoke check of §4 step 5 fails (the "Finalized at v1.0.0."
  grep no longer matches, and the T2 negative check's "Bump to v1.0.0 on wrap." grep now matches again).
  Perform this once per edit during review, not as a committed test file — there is no test harness for
  `contracts/*.md` prose in this repository today (confirmed absent by the precedent tasks
  `tasks/epic-03-task-01-contract-interaction-marker-unit-list.md` § T5 and
  `tasks/epic-04-task-01-contract-interaction-card-timing-summary-tint.md` § T5, both of which record the same
  finding for `contracts/interaction-contract.md`).
- **T6 idempotency / no-leak.** Re-applying the same two edits to the post-edit file is a no-op: each target
  string, once present, is not matched again by its own insertion instruction (both insertions in §4 target
  strings from the *pre*-edit v0.9.3 text quoted in §3, which no longer exists post-edit). No side file is
  touched; `git diff --stat` after the commit shows exactly one file.

## §6 Decision defaults

- IF the on-disk `contracts/interaction-contract.md` does not read v0.9.3 at implementation time (header or §
  Finalization owed text differs from the §3 pre-state quotes) THEN BLOCK and do not edit the file — per §1's
  Pre-state gate, this is a genuine prerequisite-not-landed condition (branch sequencing: 03.1, then 04.1, then
  04.8–04.10, then this task), not an ambiguity with a safe default.
- IF the version-line append should replace the entire Source sentence (as the pre-v0.9.1 EPIC 02 precedent
  did for its own earlier bump) rather than append to it THEN it must append: the arbiter ruling's own
  instruction is "Append to the Source sentence" (`arbiter-04-predispatch.md:100-101`), and the `v0.9.1 adds
  …` / `v0.9.2 resolves …` / `v0.9.3 resolves …` clauses are still-true historical records, not stale values to
  overwrite — this mirrors the append convention both 03.1 and 04.1 already used for this same file.
- IF § Finalization owed's two "Resolved in v0.9.2 …" / "Resolved in v0.9.3 …" sentences should also be
  removed or reworded now that the paragraph is fully closed THEN they must not be: the ruling's own
  instruction targets only "the last sentence ('Bump to v1.0.0 on wrap.')" for replacement
  (`arbiter-04-predispatch.md:102-103`) and states explicitly "No normative text changes at the flip" — the
  resolution history stays as a record of what each prior bump closed.
- IF this task should also add a `docs/DEFERRED.md` entry or touch `docs/domains/*.md` because the Demo wrap
  is a natural place to consolidate outstanding items THEN it must not: task 04.1 is "the single EPIC 04 writer
  of `docs/DEFERRED.md`" (its own §1) and already landed both EPIC 04 entries; no domain doc edit is named by
  the arbiter ruling for this wrap step.
- IF the commit should bundle this bump with any other contract's version change (as task 04.1 bundled
  `interaction-contract` and `domain-glossary` in one commit) THEN it must not: `domain-glossary.md`'s v1.0.1
  bump already landed in task 04.1; this wrap task touches only `interaction-contract.md`, so the commit scope
  is the single-contract form `contract(interaction-contract): …`, matching the precedent commit subject
  `contract(interaction-contract): marker set only from the unit list, no drag (v0.9.2)` (task 03.1).

Standing defaults: identifiers and timestamps are unaffected by this task (no schema, no field touched). No
model call exists in this task, so no confidence threshold or Tier-0 fallback applies (I2 not engaged).
Telemetry is unaffected — no event, no payload field is added or changed. No field anywhere is added that
could identify a person, device or session — this task adds prose only, no field. No node's `paraphrase`
field is touched; no Ministry text is added anywhere.

## §7 Done definition

The task is done when ALL gates pass:

- `scripts/gate.sh` green end-to-end (a docs/contract-only change; no gate reads code this task touches, so
  this is a regression check that the change introduced no stray edit elsewhere)
- `pipeline/tests/test_contracts.py` green
- `scripts/check-no-time-estimates.sh` green
- `git diff --stat` shows exactly one file changed: `contracts/interaction-contract.md`; `git diff -- .` shows
  hunks restricted to the version-line block and the § Finalization owed paragraph
- the smoke check and T1/T2/T5 checks of §5 pass
- `Contract version` reads `v1.0.0 (finalized by the Demo EPIC)`; § Finalization owed ends "Finalized at
  v1.0.0."; the commit is scoped `contract(interaction-contract)` with subject `contract(interaction-contract):
  finalize v1.0.0 (Demo wrap)` (instrument: `git log -1 --format=%s`)
- conforms to every contract section cited in §3 and §4, and to every invariant listed in §1
