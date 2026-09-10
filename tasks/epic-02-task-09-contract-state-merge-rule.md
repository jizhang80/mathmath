# Epic 02 · Task 09: Contract v1.4.0 — StudentState merge rule (platform Q3)

---
epic: 02
task: 09
slug: contract-state-merge-rule
kind: feat
risk: seam
depends_on: [02.8]
model: sonnet
---

## §1 Goal & acceptance criteria

Goal: bump `contracts/data-model.md` from v1.3.0 to v1.4.0, landing the arbiter's Q-B ruling
(`tasks/arbitration/arbiter-02-predispatch.md` § Q-B) as a new, normative `### StudentState merge (platform
Q3)` subsection, verbatim. This is a documentation-only, code-free change: no schema, no `Core` type, no
pipeline module and no `data/demo` file is touched. The rule defines `merge(a, b)` — a pure function over two
`StudentState` values — completely enough that task 02.12 can implement `merge(StudentState, StudentState)`
in `Core` and property-test commutativity, idempotence (via a `canonicalise` step), never-lowering mastery,
and I5 (no identifier introduced) with no further design decision left open.

Invariants in play:

- **I5** — the merge rule this task lands introduces no field and no identifier of any kind. The arbiter's
  own verification confirms this is the load-bearing reason the "union by entry id" domain default (platform
  Q3) could not be realised literally: "A per-run id names a run, which is the thing I5's 'no … session id'
  guards against" (`tasks/arbitration/arbiter-02-predispatch.md` § Q-B). The normative text this task lands
  states explicitly, twice, that the loss of distinguishing two identical-value same-day log entries "is
  accepted rather than add an identifier (I5)", and that `merge` "takes no bundle and introduces no field".
- **I14** — `merge` is specified as, and task 02.12 must implement, "a pure `Core` function over two
  `StudentState`s" — a value-level function with no render-layer concern and no second implementation
  outside `Core`. This task supplies the single normative text that implementation conforms to; it writes no
  implementation itself.

Acceptance criteria (each independently verifiable):

- AC1: `contracts/data-model.md`'s `Contract version` line reads `v1.4.0`; every clause of the current line
  (through the v1.3.0 clause) is byte-unchanged, and one new clause is appended naming this bump, the arbiter
  ruling and its source file.
  Instrument: `rg -n "Contract version" contracts/data-model.md` shows `v1.4.0`; a full read of the line
  confirms the v1.1.0/v1.2.0/v1.3.0 clauses are untouched and a v1.4.0 clause is appended.
- AC2: a new subsection headed exactly `### StudentState merge (platform Q3)` appears immediately after §
  StudentState and immediately before `## Enforcement`, holding the six-bullet body and the closing "Laws
  (CoreTests)" paragraph, byte-identical to `tasks/arbitration/arbiter-02-predispatch.md:85-111` (with the
  arbiter's own blockquote `> ` markers stripped, per the bundle's compilation discipline — content
  unchanged, only the blockquote prefix removed).
  Instrument: `rg -n "### StudentState merge \(platform Q3\)" contracts/data-model.md` shows exactly one
  match; `rg -n "takes no bundle and introduces no field" contracts/data-model.md` shows exactly one match,
  inside that subsection; a full manual read confirms every one of the six bullets (`nodes`,
  `expedition_log, probe_log`, `Winning side W`, `marker, syllabi, trail`, `install_day` /
  `format_version_seen`, `consent_on`) and the `Laws (CoreTests)` paragraph are present verbatim in the order
  given.
- AC3: no field is added anywhere by this task — `contracts/schemas/student-state.schema.json`,
  `contracts/examples/student-state.json` and every `Packages/Core/**` file are untouched (confirmed by the
  normative text's own first sentence: "it takes no bundle and introduces no field").
  Instrument: `git diff --stat` after the commit shows exactly one file, `contracts/data-model.md`.
- AC4: the existing § StudentState section — the field-list paragraph and both explanatory paragraphs
  (`past_last_unit`, `remediated`, `schema_version`) landed by task 02.2 — is byte-unchanged; this task adds
  a new subsection after it and edits nothing inside it.
  Instrument: `git diff contracts/data-model.md` shows no changed line inside § StudentState itself (the
  diff's only additions are the version-line clause of AC1 and the new subsection of AC2, both located
  strictly outside § StudentState's existing text).
- AC5: no other section of `contracts/data-model.md` changes — § Identifiers, § Versioning, § Time, § Text, §
  Nulls/enums/unknowns, § Collections, § ProbeItem, § Probe answer derivation and § Enforcement are all
  byte-unchanged.
  Instrument: `git diff contracts/data-model.md` touches only the version line and the insertion point
  between § StudentState and `## Enforcement`; no other hunk appears.

## §2 File scope

In-scope (the implementer touches EXACTLY this file; nothing else):

- `contracts/data-model.md` — MODIFY. `Contract version` line (v1.3.0 → v1.4.0); insert the new §
  StudentState merge subsection per §4 below. This is the only file this task may create or touch, per the
  task's own scoping ("File scope: `contracts/data-model.md` only").

Out-of-scope (do not touch even if tempted):

- `contracts/schemas/student-state.schema.json` — the ruling's own text says the merge "introduces no
  field"; there is nothing for the schema to gain.
- `contracts/examples/student-state.json` — no field, so no example fixture change.
- `Packages/Core/Sources/Core/**` — `merge(StudentState, StudentState)`'s implementation is task 02.12's
  file, not this task's. This task supplies only the normative text task 02.12 conforms to.
- `Packages/Core/Tests/CoreTests/**` — the property tests for commutativity, idempotence (via
  `canonicalise`), never-lowering-mastery and the sum-multiplicity negative control are task 02.12's, per the
  plan ("02.9 (text), 02.12 (code)") and the arbiter's cascade note ("The spec must include a **negative
  control**: a merge that keeps sum-multiplicity instead of max must fail idempotence" — owed by 02.12, not
  this task).
- `contracts/interaction-contract.md` — task 02.1's file (already landed); no interaction-contract text is
  touched by the Q-B ruling.
- `contracts/graph-constraints.md`, `CLAUDE.md` — untouched by Q-B; those belong to task 02.3's Q-E ruling.
- `docs/domains/platform.md` — the ratified Q3 default this task's text completes is read-only source
  material; the domain doc itself is not amended by this task.
- `pipeline/**`, `data/demo/**` — no executable surface and no bundle data is affected by a merge rule that
  operates only on `StudentState`, which is not a bundle asset (`contracts/data-model.md` § Collections
  lists it as the separate `(state)` row).

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rule (the versioning procedure this task follows):

- `contracts/README.md` — heading `## Lock-first rule`:
  > `data-model`, `graph-constraints`, `content-policy`, `telemetry`, `domain-glossary`, `runtime-tiers` and
  > `deployment-model` **lock before any dependent EPIC starts** — retrofitting them corrupts shipped data,
  > the graph, or the compliance position. Discovery-zone contracts stay open and are finalized
  > just-in-time. A change to a locked contract is a **versioned** change: bump `Contract version`, ripple
  > to every conforming EPIC, and flag the commit scope (`contract(<name>)`) so the ripple is auditable.

CLAUDE.md invariant this task's text is bound by:

- `CLAUDE.md` — Invariant table, row `I5`:
  > **No PII, no accounts.** Telemetry is anonymous and aggregate, **on by default with one-tap off, and
  > carries no identifier of any kind** (no install, device or session id); the endpoint retains no IP.
  > Cross-device sync uses Apple-managed identity only.

Arbiter ruling — the normative text this task lands verbatim
(`tasks/arbitration/arbiter-02-predispatch.md`, § `## Q-B — merge "by entry id" / "latest write" with no id
and no write time`, lines 83–111; the lead-in sentence "Normative text for 02.9: …" is compilation
scaffolding, not text to land):

> **Ruling.** Adopt the planner default and complete it, so that `merge` is total, commutative and
> idempotent. The rule text goes into the contract. **Normative text for 02.9: `contracts/data-model.md`,
> new subsection `### StudentState merge (platform Q3)` (v1.4.0):**
>
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

Cascade note this task's out-of-scope list relies on (same section, immediately following):

> **Cascade for 02.12.** The AC9 law tests must compare through `canonicalise`, because a raw append-ordered
> log would make `merge(a, a) == a` fail spuriously. The spec must include a **negative control**: a merge
> that keeps sum-multiplicity instead of max must fail idempotence.

Prior contract text this task edits in place (from `contracts/data-model.md`, current v1.3.0, read directly
so the diff below is unambiguous):

- `Contract version` line:
  > **Contract version:** v1.3.0 · Source: brief v2 §5 as amended (D20–D22, D32, D33, D43–D48),
  > `docs/domains/*.md`; v1.1.0 adds `ProbeItem.check` and `Landmark.source_title` (owner Q5 ruling
  > 2026-09-09, `tasks/blocked/Q5-RULING-01-07.md`); v1.2.0 corrects § Probe answer derivation — the name
  > allow-list alone does not close the parse environment, so an AST-shape allow-list is added and the true
  > name list is stated (orchestrating session's authorization 2026-09-09,
  > `tasks/blocked/AUTHORIZATION-01-07a-contract-write.md`, on the defect reported in
  > `tasks/blocked/tester-blocked-01-07.md`; not an owner ruling); v1.3.0 adds
  > `StudentState.nodes[].remediated` and `StudentState.marker.past_last_unit`, `schema_version` 2 (arbiter
  > rulings Q-A, Q-F, `tasks/arbitration/arbiter-02-predispatch.md`)

- § StudentState, final paragraph, immediately followed by `## Enforcement` (the insertion point):
  > `schema_version` is **2**. Migration 1 → 2 is the identity: a version-1 document is a valid version-2
  > document with every `remediated` absent.
  >
  > ## Enforcement

- § Identifiers, the clause the "Winning side W" bullet cross-references:
  > `unit_id` is `<course_code>.u<n>` (1-based, in unit order)

## §4 Implementation outline

This is a documentation-only contract edit. There is no boundary schema, no error code, no storage/asset
access and no model-calling path in this task (§1 records I5 and I14 as the only invariants engaged; I1–I4,
I6–I13, I15 are not touched by a merge-rule contract text).

1. **Version line.** Replace the `Contract version` line quoted in §3 with the same line, every existing
   clause byte-unchanged, plus one new clause appended at the end:
   ```
   **Contract version:** v1.4.0 · Source: brief v2 §5 as amended (D20–D22, D32, D33, D43–D48),
   `docs/domains/*.md`; v1.1.0 adds `ProbeItem.check` and `Landmark.source_title` (owner Q5 ruling
   2026-09-09, `tasks/blocked/Q5-RULING-01-07.md`); v1.2.0 corrects § Probe answer derivation — the name
   allow-list alone does not close the parse environment, so an AST-shape allow-list is added and the true
   name list is stated (orchestrating session's authorization 2026-09-09,
   `tasks/blocked/AUTHORIZATION-01-07a-contract-write.md`, on the defect reported in
   `tasks/blocked/tester-blocked-01-07.md`; not an owner ruling); v1.3.0 adds
   `StudentState.nodes[].remediated` and `StudentState.marker.past_last_unit`, `schema_version` 2 (arbiter
   rulings Q-A, Q-F, `tasks/arbitration/arbiter-02-predispatch.md`); v1.4.0 adds a normative `StudentState`
   merge rule, `### StudentState merge (platform Q3)` (arbiter ruling Q-B,
   `tasks/arbitration/arbiter-02-predispatch.md`)
   ```
   This new clause is composed for this task (it does not exist verbatim in any source file); it follows
   the exact style of the v1.1.0/v1.2.0/v1.3.0 clauses it is appended after (one `;`-joined clause, section
   name, ruling name, source file), per §6 default 2.

2. **New § StudentState merge subsection.** Insert the following, verbatim from the arbiter's blockquote
   text in §3 with only the leading `> ` blockquote markers stripped (content, punctuation, backticks and
   line breaks otherwise unchanged), immediately after the § StudentState final paragraph quoted in §3 and
   immediately before `## Enforcement`:
   ```
   ### StudentState merge (platform Q3)
   `merge(a, b)` is a pure `Core` function over two `StudentState`s, both already migrated to the current
   `schema_version` (platform W3 precedes W4 step 2); it takes no bundle and introduces no field.
   - **nodes** — key union. A key on one side keeps that entry. A key on both: `mastery` = the higher under
     `cleared` > `blocked` > `fog`; `correct_count` = max; `ladder_rung` = max; `last_probe` = the later day,
     `next_due` = the later day (absent is earlier than any day); `remediated` = logical OR, then removed unless
     the merged `mastery` is `blocked`.
   - **expedition_log, probe_log** — multiset union by full-value equality: every distinct entry value appears
     `max(count in a, count in b)` times. Output order is canonical: ascending `day`, then the remaining fields in
     schema property order (`expedition_log`: `item_count`, `cleared`, `blocked`, `abandoned`, `diagnosis_events`;
     `probe_log`: `node_id`, `item_id`, `correct`, `retry`), strings by byte order, `false` before `true`, integers
     ascending. Two distinct runs with identical values on the same day, one on each side, merge into one entry;
     this loss is accepted rather than add an identifier (I5).
   - **Winning side W** (for `marker`, `syllabi`, `trail`) — the side whose latest `day` across its
     `expedition_log` and `probe_log` is later (a side with both logs empty loses to a side with any entry). On a
     tie: the marker further along — `past_last_unit: true` ranks above any unit, else the greater unit ordinal
     `n` of `unit_id` = `<course_code>.u<n>` (§ Identifiers: "1-based, in unit order"); then the lexicographically
     greater `course_code`. Any remaining tie between fields that still differ is broken by comparing the two
     values' canonical JSON encodings (sorted keys) byte-wise, greater wins.
   - **marker, syllabi, trail** — all three from W (the marker stays inside its own `syllabi`; `trail` is a
     derived cache the caller regenerates after merge).
   - **install_day** = the earlier day. **format_version_seen** = the higher semver.
   - **consent_on** = `a.consent_on ∧ b.consent_on` — an off on either side stays off (`telemetry.md` § Consent,
     I5 "one-tap off").

   Laws (CoreTests): commutative and idempotent under equality where logs compare in canonical order —
   `merge(a, a) == canonicalise(a)`, `merge(a, b) == merge(b, a)`; no merged node's `mastery` is lower than
   either input's.
   ```
   `## Enforcement` (and everything after it) follows this subsection, byte-unchanged.

3. **Error codes and model-calling paths.** No error code is added or raised by this task; nothing here is
   reachable at runtime (this is a contract-text change, not code). No model-calling path exists in this
   task — I2's confidence-threshold/Tier-0-fallback requirement is not engaged.

4. **Commit.** One commit, touching only `contracts/data-model.md`:
   ```
   contract(data-model): normative StudentState merge rule (platform Q3, v1.4.0)
   ```
   The PR description names the ruling this task carries out (Q-B,
   `tasks/arbitration/arbiter-02-predispatch.md`) and states that no schema, example or `Core` type changes,
   because the rule introduces no field (task 02.12 lands the implementation and property tests separately).

5. **Smoke check.**
   ```
   rg -n "Contract version|### StudentState merge \(platform Q3\)|takes no bundle and introduces no field|Laws \(CoreTests\)" contracts/data-model.md
   ```
   must show the version line at `v1.4.0`, the new heading exactly once, the "introduces no field" sentence
   exactly once, and the "Laws (CoreTests)" paragraph exactly once. `git diff --stat contracts/data-model.md`
   shows exactly one file changed.

## §5 Test plan (seam risk — full plan)

This task ships no code, so its "tests" are the verifiable textual assertions below — the cheapest rung that
actually holds prose contract text (`contracts/README.md` § Enforcement ladder: "type system → static
analysis / lint → schema / config check → runtime contract test"; a grep-based content assertion is the lint
rung). The rule's *behavioural* conformance (commutativity, idempotence, never-lowering mastery, the
sum-multiplicity negative control) is proven at the runtime-contract-test rung by task 02.12's `CoreTests`
property tests, which this task's text is normative input to, not the instrument for.

- **T1 happy path.** Run the smoke check of §4 step 5. All four grepped strings are present exactly where §4
  places them (verified by a full read of the file after the edit, not just the grep match count); the new
  subsection's six bullets and closing paragraph are present verbatim, in order, byte-identical to §3's
  quoted arbiter text (blockquote markers stripped only).
- **T2 negative — invalid input rejected at the boundary.** Not applicable in the schema/code sense (this
  task validates no runtime input). The equivalent negative check for a prose contract: confirm the *old*
  version line (ending at the v1.3.0 clause, with no v1.4.0 clause) no longer appears unmodified —
  `rg -n "Contract version.*v1\.3\.0 adds \`StudentState\.nodes\[\]\.remediated\`.*$" contracts/data-model.md`
  matches only as a substring of the new, longer line (i.e. the line does not terminate at the v1.3.0
  clause); and confirm `## Enforcement` is not duplicated and does not appear before the new subsection. A
  diff that leaves the old version line duplicated alongside the new one, or that inserts the subsection
  inside § StudentState rather than after it, is a FAIL.
- **T3 error-taxonomy.** Nothing to assert: this task registers no error code in `contracts/error-codes.md` /
  `error-codes.json`. Recorded explicitly so the omission is a decision, not a gap.
- **T4 conformance per §B.1 / cited contract and invariants.** Re-read the full edited file top to bottom and
  confirm: (a) the version line names the ruling and its source file (AC1); (b) the new subsection sits
  strictly between § StudentState's closing paragraph and `## Enforcement`, with no other section reordered
  (AC2, AC4); (c) I5 holds — the "introduces no field" sentence and both explicit "(I5)" parentheticals from
  the arbiter text are present verbatim; (d) I14 holds — the opening sentence states `merge` is "a pure
  `Core` function over two `StudentState`s"; (e) the subsection reads grammatically as continuous prose with
  no orphaned bullet or dangling cross-reference (the "§ Identifiers" cross-reference inside the "Winning
  side W" bullet resolves to the existing § Identifiers clause quoted in §3).
- **T5 negative control for every regression guard.** The regression guard this task installs is the grep
  set of §4 step 5. Its negative control: temporarily revert the edit (restore the pre-edit version line and
  remove the new subsection) and confirm the smoke check of §4 step 5 fails (the
  `### StudentState merge \(platform Q3\)` grep now returns zero matches, and the version-line grep shows
  `v1.3.0`). Perform this once during review, not as a committed test file (there is no test harness for
  `contracts/*.md` prose in this repository today — confirmed absent by task 02.1's own audit: "there is no
  test harness for `contracts/*.md` prose in this repository", `Glob scripts/*.sh` lists no markdown-content
  check).
- **T6 idempotency / no-leak.** Re-applying the same two edits (version-line replace, subsection insert) to
  the post-edit file is a no-op: the version-line replace targets the exact pre-edit string quoted in §3,
  which no longer exists post-edit, and the subsection-insert targets the exact insertion point (immediately
  before `## Enforcement`), which the post-edit file no longer offers without also matching inside the
  already-inserted subsection's own content — so a second application is rejected by inspection, not
  silently duplicated. No side file is touched; `git diff --stat` after the commit shows exactly one file.

## §6 Decision defaults

- IF the merge rule's six bullets and closing "Laws" paragraph should be reformatted to match
  `contracts/data-model.md`'s existing prose style (comma-joined field lists, no bullet lists) THEN they
  should not — the arbiter's normative text is itself already in the target contract's Markdown dialect
  (headings, bold-lead bullets, inline code spans) and AC2 requires byte-identical content; reformatting
  would be an uninstructed edit to normative ruling text, which only the spec-arbiter or the owner may
  change.
- IF the new v1.4.0 version-line clause's wording should quote the ruling's bullets in full (mirroring the
  subsection body) THEN it should not — every prior clause (v1.1.0, v1.2.0, v1.3.0) is a one-sentence
  pointer to the ruling and its section, not a restatement of the ruling's content; the full content lives
  once, in the new subsection, matching the existing pattern in `contracts/data-model.md` § Identifiers:
  "Never parse meaning from an id" holding the detail while the version line only points to where a change
  landed.
- IF `## Enforcement` should gain a bullet describing the merge law tests (`merge(a,a) == canonicalise(a)`,
  the sum-multiplicity negative control) THEN it should not — those tests are task 02.12's `CoreTests`
  deliverable per the plan ("02.9 (text), 02.12 (code)") and the arbiter's own cascade note ("The spec must
  include a **negative control** … owed by 02.12"); this task is contract text only, and `## Enforcement`'s
  existing bullets describe wiring that already exists (`pipeline/tests/test_contracts.py`,
  `CoreTests` decode round-trips), not wiring this task ships.
- IF `contracts/schemas/student-state.schema.json` or `contracts/examples/student-state.json` should gain
  any change to exercise the merge rule in a schema/example test THEN neither should — the normative text's
  first sentence is explicit: `merge` "takes no bundle and introduces no field", so there is no new key, no
  new example value and no new validation surface for a schema-level test to exercise; task 02.12's
  `CoreTests` property tests are the correct and sufficient instrument.
- IF the "§ Identifiers" cross-reference inside the "Winning side W" bullet ("`unit_id` = `<course_code>.u<n>`
  (§ Identifiers: '1-based, in unit order')") should be rewritten to quote § Identifiers' current wording in
  full THEN it should not — the arbiter's text already quotes the exact clause verified present in §3 above
  (`unit_id` is `<course_code>.u<n>` (1-based, in unit order)`), and the cross-reference is landed verbatim,
  unedited, per AC2's byte-identical requirement.
- IF `StudentState.schema_version` appears to have no explicit merge bullet among the six THEN this is not a
  gap: the arbiter preamble's own precondition governs it directly — `merge` is defined only over "two
  `StudentState`s, both already migrated to the current `schema_version`" (platform W3 precedes W4 step 2)
  (`tasks/arbitration/arbiter-02-predispatch.md:85-86`). The consequence, stated explicitly for the
  implementer: `merge`'s output always carries the current `schema_version` (both inputs already share it,
  by precondition), and an input at a different `schema_version` is migrated to the current `schema_version`
  before `merge` is ever invoked — that migration is outside `merge`'s own responsibility and outside this
  task's scope (§ StudentState's existing "Migration 1 → 2 is the identity" text, quoted in §3, is the
  migration this precondition relies on). `merge` itself therefore never resolves a `schema_version`
  conflict, because none can exist at its call boundary; this task adds no seventh bullet for
  `schema_version`, since the precondition sentence already normatively covers it and a bullet would
  duplicate, not add, rule content.

Standing defaults: identifiers and timestamps are unaffected by this task (no schema, no field, no
migration). No model call exists in this task, so no confidence threshold or Tier-0 fallback applies (I2 not
engaged). Telemetry is unaffected beyond the existing `telemetry.md` § Consent cross-reference already
present in the landed text. No field anywhere is added that could identify a person, device, install or
session — the landed text states this twice, explicitly, as the load-bearing reason for its own design.
Ministry text is not touched; no `paraphrase` field exists in this section.

## §7 Done definition

The task is done when ALL gates pass:

- `scripts/gate.sh` green end-to-end (unaffected by a docs-only change, but run in full per standing
  practice — no gate in `scripts/gate.sh` reads `contracts/data-model.md` at the prose level beyond the
  pipeline's schema/example tests, which this task does not touch, so this is a regression check that the
  change introduced no stray edit elsewhere)
- `git diff --stat` shows exactly one file changed: `contracts/data-model.md`
- the smoke check and both grep-based T1/T2/T5 checks of §5 pass
- `Contract version` reads `v1.4.0` and the commit is scoped `contract(data-model)`
- conforms to every contract section cited in §3 and §4, and to every invariant listed in §1
