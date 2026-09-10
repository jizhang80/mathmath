# Epic 02 · Task 02.3: L0-T trail-segment rule — versioned rewrite (Q5 ruling 02-QE, route a)

---
epic: 02
task: 03
slug: l0t-trail-rule-contract
kind: feat
risk: seam
depends_on: [none]
model: sonnet
---

> **Origin.** This task exists only to carry out the owner's Q5 ruling on the meaning of I8's trail clause,
> `tasks/blocked/Q5-RULING-02-QE.md` (ruled: option A / route (a)). It rewrites the **L0-T** row of
> `contracts/graph-constraints.md` — nothing else. `CLAUDE.md`'s I8 row has **already** been rewritten to
> match this ruling by the orchestrating session (commit `80a47a5`) and is out of scope here. `data/demo` is
> **not** changed (the ruling is explicit on this). This task unblocks 02.5, 02.6, 02.7.

## §1 Goal & acceptance criteria

Goal: rewrite the L0-T row of `contracts/graph-constraints.md` (versioned bump, v1.0.0 → v1.1.0) so that a
**course segment** is defined as that course's resident nodes ordered by unit order, then topologically
within each unit (ties broken by node id), an edge against unit order is a **warning** the trail report
lists (never a failure), and every **extension-segment** node is reachable in the graph from the segment
before it — matching the wording already landed at `CLAUDE.md:31`. No code changes; this is a normative-text
task that later tasks (02.5's `Core` implementation, 02.5/02.6's tests) build against.

Invariants in play:

- **I8** — this task IS the redefinition of I8's trail clause the ruling authorizes; the new L0-T row is the
  contract text that governs what "every generated trail is a path in the graph" now means. Satisfied by
  making the row's wording match `CLAUDE.md:31` (already rewritten) and the ruling's three bullets exactly.
- **I1** — L0-T stays a deterministic graph rule (ordering, reachability); no model is named anywhere in the
  new row, and the row continues to fail with the existing code `EXP_TRAIL_INVALID` (no ad-hoc error is
  invented).
- **I14** — the row's Note column continues to state the check is implemented once in `Core`; this task adds
  no second implementation and writes no Swift — the runtime implementation is task 02.5's, not this one.
- **I7** — the row still describes one cross-grade graph's trail generation (course segment + extension),
  never per-course authored data; the rewrite changes only how "path" is defined, not that the graph is
  singular.

Acceptance criteria (each independently verifiable):

- AC1: `contracts/graph-constraints.md`'s `Contract version` line reads `v1.1.0` and names the Q5 ruling
  (`tasks/blocked/Q5-RULING-02-QE.md`) as the reason for the L0-T change, following the same inline-changelog
  convention already used by `contracts/data-model.md:3` (append `; vX.Y.Z <what changed> (<reason>,
  <ruling path>)` to the existing version line rather than adding a new heading).
  Instrument: `rg -n "Contract version" contracts/graph-constraints.md` shows `v1.1.0` and the ruling path.
- AC2: the L0-T row states, in this order, the three ruled properties: (a) a course segment = that course's
  nodes resident in the bundle, unit order then topological-within-unit, ties by node id; (b) an
  against-unit-order edge inside one course segment is listed as a warning, never a failure; (c) every
  extension-segment node is reachable along directed edges from a node of the segment before it.
  Instrument: manual read of the row against §4 step 1's exact text; `rg -n "against unit order" -A2 -B2
  contracts/graph-constraints.md` shows the warning clause.
- AC3: the row's "Fails with" column still reads `EXP_TRAIL_INVALID` (unchanged, no new error code
  introduced, no edit to `contracts/error-codes.json`). Instrument: `rg -n "EXP_TRAIL_INVALID"
  contracts/graph-constraints.md contracts/error-codes.json` — the code appears in both, byte-identical, and
  `error-codes.json`'s entry is untouched (`git diff --stat contracts/error-codes.json` is empty).
- AC4: applying the new row's rule by hand to `data/demo` (course segments for `MTH1W` and `MCR3U`) produces
  exactly the orderings and the single warning edge pinned in §4 step 3 — the fixture values task 02.5's
  tests assert against. This AC is verified by hand-computation, not by running code (no `Core` change ships
  here); §4 step 3 documents the computation so a reviewer can re-derive it.
- AC5: no file other than `contracts/graph-constraints.md` is modified. `CLAUDE.md`, `data/demo/**`,
  `contracts/interaction-contract.md`, `contracts/error-codes.json`, and every `Packages/Core/**` file are
  byte-unchanged. Instrument: `git diff --stat` lists exactly one file.

## §2 File scope

In-scope (the implementer touches EXACTLY this file; nothing else):

- `contracts/graph-constraints.md` — MODIFY. Bump `Contract version` to `v1.1.0` with an inline changelog
  clause; replace the L0-T row (`contracts/graph-constraints.md:23`) with the text fixed in §4 step 1.

Out-of-scope (do not touch even if tempted):

- `CLAUDE.md` — the I8 row is **already rewritten** to match this ruling by the orchestrating session
  (commit `80a47a5`; verified by direct read at `CLAUDE.md:31`, which already reads "every generated trail is
  well-formed over the graph — a course segment is exactly that course's resident nodes in unit order,
  topological within a unit (an edge against unit order is reported, not failed); every extension node is
  reachable from the segment before it. | §5, v2.7 §1, Q5 02-QE"). Editing it again is out of scope and would
  create a second, possibly divergent, statement of the same rule.
- `contracts/interaction-contract.md` — §3's sentence "every segment a path (L0-T)" cites the rule by id and
  does not itself assert a literal-directed-path definition; it defers to `graph-constraints.md` for what
  "path" means. It needs no edit for this ruling to take effect, and task 02.1 (which owns
  `interaction-contract.md` this sub-epic, for §2 numeric normalisation) does not touch §3 either — so no
  collision exists and none is created by leaving §3 untouched. If a future task finds §3's wording
  misleading, that is a separate, later change to `interaction-contract.md`, not this task's.
- `contracts/error-codes.json` — no new code. Against-unit-order edges are warnings, not errors; the sole
  failure mode of L0-T remains `EXP_TRAIL_INVALID` (`contracts/error-codes.json:15`, unchanged).
- `data/demo/**` — the Q5 ruling is explicit: `data/demo` is not changed
  (`tasks/blocked/Q5-RULING-02-QE.md:14`). The new rule is written to accommodate the existing demo data, not
  the other way round.
- `Packages/Core/**` — L0-T has no implementation yet (`Packages/Core/Sources/Core/Validation/L0Checker.swift:4`:
  "L0-T is EPIC 02's"); it is written by task 02.5, which explicitly "does not edit `L0Checker.swift`"
  (`docs/plans/epic-02-plan.md` § Task scopes, 02.5). This task ships no Swift.
- `contracts/graph-constraints.md`'s "Report shape" paragraph (`contracts/graph-constraints.md:25-27`) — left
  unchanged. That paragraph documents the `core-cli validate` bundle-level JSON for L0-1…L0-10; L0-T's own
  Note column already states it "runs at generation, not on the bundle" (unchanged by this task), so L0-T's
  warnings are not part of that report and that paragraph does not need a `warnings[]` key. See §6 for the
  full reasoning.

## §3 Inputs (verbatim — do not paraphrase)

The owner ruling this task carries out — `tasks/blocked/Q5-RULING-02-QE.md:6-14` (re-read and byte-verified
in this run):

> **Ruled: option A.**
>
> - A trail's **course segment** is exactly that course's nodes resident in the bundle, ordered by **unit
>   order**, then **topologically by the graph within each unit** (ties by node id).
> - An edge that runs **against unit order** (e.g. `solving-linear-equations` u3 → `exponent-laws` u2) is
>   **reported** (a warning in the L0 report), **not a failure**.
> - Every **extension segment** node must be **reachable in the graph** from the segment before it.
> - The L0-T row of `contracts/graph-constraints.md` and the I8 wording in `CLAUDE.md` are rewritten to
>   match. The contract change is a versioned bump carried by task 02.3 (route a); **`data/demo` is not
>   changed**.

The current L0-T row this task replaces — `contracts/graph-constraints.md:23` (re-read and byte-verified in
this run):

> | L0-T | **Trail segments** (generated at runtime, expedition W8): every segment's `node_ids[]` is a
> directed path in the graph; a course segment contains only that course's nodes. | `EXP_TRAIL_INVALID` |
> same `Core` function; runs at generation, not on the bundle |

The already-landed `CLAUDE.md` I8 row this task's wording must not contradict — `CLAUDE.md:31` (re-read in
this run, current committed state, out of scope to edit):

> I8 | Every accepted graph passes the **L0 checks**: acyclic; no later→earlier course edge; code↔node
> coverage both ways **for nodes carrying `expectation_codes` and for every Ministry expectation**; a
> resolvable `source_ref` on every node without codes (a node with neither fails); in-degree outliers
> flagged; starting chain connected; **every node has exactly one region; every generated trail is
> well-formed over the graph** — a course segment is exactly that course's resident nodes in unit order,
> topological within a unit (an edge against unit order is reported, not failed); every extension node is
> reachable from the segment before it. | §5, v2.7 §1, Q5 02-QE |

The lock-first versioning rule this task follows — `contracts/README.md § Lock-first rule` (lines 42–44 at time of writing; re-read and byte-verified in
this run):

> A change to a locked contract is a **versioned** change: bump `Contract version`, ripple to every
> conforming EPIC, and flag the commit scope (`contract(<name>)`) so the ripple is auditable.

The precedent for folding a changelog into the version line rather than a separate heading —
`contracts/data-model.md:3` (re-read and byte-verified in this run; `graph-constraints.md` has no existing
"Change log" heading to extend, confirmed by direct read of the full file):

> **Contract version:** v1.2.0 · Source: brief v2 §5 as amended (D20–D22, D32, D33, D43–D48),
> `docs/domains/*.md`; v1.1.0 adds `ProbeItem.check` and `Landmark.source_title` (owner Q5 ruling
> 2026-09-09, `tasks/blocked/Q5-RULING-01-07.md`); v1.2.0 corrects § Probe answer derivation — the name
> allow-list alone does not close the parse environment, so an AST-shape allow-list is added and the true
> name list is stated (orchestrating session's authorization 2026-09-09,
> `tasks/blocked/AUTHORIZATION-01-07a-contract-write.md`, on the defect reported in
> `tasks/blocked/tester-blocked-01-07.md`; not an owner ruling)

`interaction-contract.md` §3, checked for collision and left unedited —
`contracts/interaction-contract.md § 3 Marker and trail` (lines 47–51 at time of writing; re-read and
byte-verified in this run):

> - `set_marker(course, unit)` → regenerate trail → recompute fringe. Marker default = first unit of the
>   selected course. Nodes upstream of the marker keep their mastery.
> - `generate_trail`: course segments in unit order; if the marker is past the course's last unit, an
>   `extension` segment along downstream edges preferring `next_courses[]`, then undergraduate nodes; every
>   segment a path (L0-T) else `EXP_TRAIL_INVALID` and the previous trail stands.

`error-codes.json`'s entry for the row's unchanged "Fails with" column — `contracts/error-codes.json:15`
(re-read and byte-verified in this run):

> {"code": "EXP_TRAIL_INVALID", "recoverable": true, "surface": "internal", "user_text": null}

**Quote-fidelity note (bundle defect found and corrected in this run).** The task-context bundle
(`tasks/context/epic-02-task-03-context.md` §B) cites a block labelled "Proposed L0-T contract text
(normative for this task)" as verbatim `tasks/blocked/Q5-RULING-02-QE.md:45-51`. `Q5-RULING-02-QE.md` is
**19 lines long** (re-read in full in this run) — no lines 45-51 exist, and no such longer draft text appears
anywhere in the file. That bundle quote is **fabricated** and is not used anywhere in this spec. §4 step 1's
row text below is drafted fresh in this run, directly from the ruling's actual three bullets (quoted above)
and cross-checked against the already-landed, independently-verified `CLAUDE.md:31` wording, which states
the same three properties in the same order. The bundle should be corrected to remove the fabricated
citation.

## §4 Implementation outline

### 1. Replace the L0-T row

In `contracts/graph-constraints.md`, replace the row at line 23 (quoted in §3) with:

```
| L0-T | **Trail segments** (generated at runtime, expedition W8, never over the bundle): a course segment is exactly that course's nodes resident in the bundle — a node's unit is the unit of its lowest-ordered expectation code of that course — ordered by unit order, then topologically by the edge set within each unit, ties broken by node id (ascending); an edge between two nodes of the same course segment that runs against unit order is listed as a warning in the trail generation's own report, never a failure; every node of an extension segment is reachable along directed edges from some node of the segment placed before it. | `EXP_TRAIL_INVALID` | same `Core` function family as L0-1…L0-10 conceptually, but runs at trail generation (expedition W8), never via `core-cli validate`; the warning list's concrete shape is fixed by the implementing task (02.5), not by this contract |
```

Keep the table's existing column widths/alignment style as-is (no reflow of unrelated rows).

### 2. Bump the version line

Replace `contracts/graph-constraints.md:3`:

```
**Contract version:** v1.0.0 · Source: brief v2 §5, I8 as amended (v2.7 §1), `concept-graph.md` W1, `expedition.md` W8
```

with:

```
**Contract version:** v1.1.0 · Source: brief v2 §5, I8 as amended (v2.7 §1), `concept-graph.md` W1, `expedition.md` W8; v1.1.0 rewrites L0-T's trail-segment definition — a course segment is ordered by unit then topological within unit (ties by node id), an edge against unit order is a warning not a failure, and every extension-segment node must be reachable from the segment before it (owner Q5 ruling 02-QE, 2026-09-10, `tasks/blocked/Q5-RULING-02-QE.md`)
```

### 3. Hand-computed fixture values for `data/demo` (AC4; task 02.5's expected test values)

These are derived by applying the new row's rule to `data/demo/courses.json`, `data/demo/nodes.json` and
`data/demo/edges.json` as they exist today (unchanged by this task; re-read and re-derived in this run). A
node's unit is looked up via `courses.json`'s `units[].expectation_codes` for the code in that node's
`expectation_codes[].code` matching that `course_code` (every demo node carries exactly one expectation code
per course, so "lowest-ordered" is moot here). Within-unit order is a topological sort of that unit's
induced subgraph (edges whose `from` and `to` are both in the unit), Kahn's algorithm, breaking ties by
picking the lexicographically smallest node id among the currently-available (zero-remaining-indegree)
nodes at each step.

**`MTH1W` course segment** (11 nodes, units `MTH1W.u1`…`MTH1W.u4`):

```
integer-operations (u1), order-of-operations (u1), rational-numbers (u1),
exponent-laws (u2), scientific-notation (u2),
linear-relations (u3), solving-linear-equations (u3), solving-systems-of-equations (u3),
simplifying-expressions (u4), polynomials (u4), factoring (u4)
```

**`MTH1W` against-unit-order warning** (exactly one, the case the ruling names by example):

```
solving-linear-equations (u3) --> exponent-laws (u2)
```

No other edge inside the `MTH1W` segment runs against unit order (`order-of-operations`→`linear-relations`
is u1→u3, `rational-numbers`→`solving-linear-equations` is u1→u3, `exponent-laws`→`polynomials` is u2→u4 —
all forward).

**`MCR3U` course segment** (9 nodes, units `MCR3U.u1`…`MCR3U.u3`):

```
rational-expressions (u1), solving-quadratics (u1), quadratic-functions (u1),
function-concept (u2), domain-and-range (u2), function-notation (u2), function-transformations (u2),
exponential-functions (u3), logarithms (u3)
```

**`MCR3U` against-unit-order warnings**: none. Every intra-`MCR3U` edge is same-unit or forward
(`quadratic-functions`→`function-concept` is u1→u2; `function-transformations`→`exponential-functions` is
u2→u3).

Cross-course edges (`factoring`→`solving-quadratics`, `factoring`→`rational-expressions`) are between two
different course segments, not within one, so they are never subject to the against-unit-order warning; they
bear only on extension-segment reachability, which `data/demo` cannot exercise (`MTH1W.next_courses =
["MPM2D"]` and `MCR3U.next_courses = ["MHF4U"]`, neither present in `data/demo`), matching
`docs/plans/epic-02-plan.md` § Task scopes, 02.5: "data/demo has no `next_courses` target present."

### 4. Commit

One commit, scope `contract(graph-constraints)`:

```
contract(graph-constraints): rewrite L0-T's trail-segment rule per Q5 ruling 02-QE (v1.1.0)
```

The PR description states: the ruling file, the version bump (v1.0.0 → v1.1.0), and that `CLAUDE.md`'s
matching rewrite already landed in `80a47a5` and is not repeated here.

### 5. Smoke check

`rg -n "L0-T" contracts/graph-constraints.md` shows exactly one row and it contains the string
`"against unit order"` and the string `"reachable"`. `git diff --stat` shows exactly
`contracts/graph-constraints.md | N ++--`, no other file.

## §5 Test plan (seam risk — full plan, adapted to a contract-text-only task: no code ships, so every
instrument below is a grep/manual-verification check the implementer runs and records, not a pytest/XCTest
case)

- **T1 happy path.** `rg -n "Contract version" contracts/graph-constraints.md` shows `v1.1.0` and the string
  `Q5-RULING-02-QE`. `rg -n "L0-T" -A1 contracts/graph-constraints.md` shows the new row containing all
  three ruled properties (unit-order-then-topological with tie-break, against-unit-order-is-a-warning,
  extension-reachability) — each phrase checked by eye against §4 step 1's exact text.
- **T2 negative — invalid input rejected at the boundary.** N/A in the schema-validation sense (this task
  edits prose, not a JSON Schema so no document is decoded against it here). The applicable negative check
  is textual: confirm the OLD phrase "is a directed path in the graph" (the literal-path definition the
  ruling rejects) does **not** appear anywhere in the file after the edit —
  `! rg -q "directed path in the graph" contracts/graph-constraints.md` must succeed (exit 0, meaning no
  match found).
- **T3 error-taxonomy.** `rg -n "EXP_TRAIL_INVALID" contracts/graph-constraints.md` still shows exactly one
  occurrence, in the L0-T row's "Fails with" column, unchanged from before the edit. No new code is
  registered; `git diff --stat contracts/error-codes.json` is empty (proves no code was added or renamed).
- **T4 conformance per requirements §B.1.** Conformance target: the new row must say the same thing as the
  already-landed `CLAUDE.md:31` (quoted in §3), since both state the same Q5 ruling. Check: every one of the
  three properties present in `CLAUDE.md:31`'s clause ("a course segment is exactly that course's resident
  nodes in unit order, topological within a unit"; "an edge against unit order is reported, not failed";
  "every extension node is reachable from the segment before it") has a corresponding phrase in the new
  L0-T row. A reviewer diffing the two texts side-by-side is the instrument (no automated equality check
  exists, since the two live in different files with different surrounding prose by design).
- **T5 negative control for the regression guard (T2).** Before the edit, `rg -q "directed path in the
  graph" contracts/graph-constraints.md` succeeds (the old phrase is present) — this is the guard's red
  state, confirming T2's check is not vacuously green because the phrase was already absent. Record this
  pre-edit result once, by hand, before applying step 1.
- **T6 idempotency / no-leak.** N/A — this task performs one prose edit to one file with no runtime
  behaviour and no state to leak or replay. Recorded explicitly so the omission is a decision, not a gap.

## §6 Decision defaults

- IF the "Report shape" paragraph (`contracts/graph-constraints.md:25-27`, `{ bundle_id, passed, checks[],
  indegree }`) needs a `warnings[]` key to carry the against-unit-order edges THEN it does **not**: that
  paragraph documents `core-cli validate`'s bundle-level JSON for the bundle-scope rules L0-1…L0-10; L0-T's
  own Note column already says (before and after this edit) that L0-T "runs at generation, not on the
  bundle" — it is never part of `core-cli validate`'s output. The trail generation's own report (returned by
  the function `interaction-contract.md` §3's `generate_trail` calls) is where against-unit-order warnings
  live; its Swift shape is task 02.5's to define, since 02.5 is the first task to implement L0-T at all. This
  keeps this task to prose only and avoids this contract pre-committing to a report shape a later task
  might need to adjust once it is actually implemented. (Per `contracts/graph-constraints.md:25-27`,
  re-read and byte-verified in this run, and the Note column of both the old and new L0-T row.)
- IF a new error code (e.g. a warning-level `EXP_TRAIL_UNIT_ORDER_VIOLATION`) is needed to represent the
  against-unit-order case THEN it is not: the ruling's own words are "reported ... not a failure" — a
  warning is not an error, and `contracts/error-codes.json`'s registry (`contracts/README.md`'s lock-first
  set) models failure modes, not advisories. L0-4 (in-degree outliers) is the existing precedent for an
  advisory that is "report only" with no registered code, and L0-T's warning follows the same pattern. (Per
  `contracts/graph-constraints.md:16` L0-4's "report only" Note, re-read in this run.)
- IF "ties by node id" is ambiguous between "sort the whole unit's node list by id" and "break Kahn's-
  algorithm ties by id at each step" THEN it is the latter: a full-list sort by id would not respect the
  edges inside the unit (it could place a successor before its predecessor when their ids sort that way),
  which would contradict "topologically ... within each unit" in the same sentence. Kahn's algorithm with
  id-ordered tie-break among zero-indegree candidates is the only reading that satisfies both "topological"
  and "ties by id" simultaneously, and it is the reading used to compute §4 step 3's fixture values.
- IF a node's "unit" is ambiguous because a node carries more than one `expectation_codes` entry for the
  same course THEN the rule text's own phrase governs: "a node's unit is the unit of its lowest-ordered
  expectation code of that course" (§4 step 1). This does not arise anywhere in `data/demo` today (every
  demo node has exactly one expectation code per course, confirmed by direct read of
  `data/demo/nodes.json` in this run), so no fixture value in §4 step 3 depends on this branch; it is stated
  for the benefit of future, non-demo bundles.
- IF the implementer is tempted to also touch `CLAUDE.md` "to be safe" since the two texts must agree THEN
  they must not: `CLAUDE.md:31` is confirmed already rewritten and committed (`80a47a5`), touching it again
  is scope creep this task was explicitly told is out of bounds, and a second edit risks introducing a
  divergence rather than removing one.
- IF the implementer is tempted to also touch `contracts/interaction-contract.md` §3 to spell out "path"
  more explicitly THEN they must not: that file's ownership this sub-epic is task 02.1's (§2 numeric
  normalisation only, per `docs/plans/epic-02-plan.md`), §3's existing sentence does not contradict the new
  L0-T definition (it cites the rule by id and defers to this contract), and the user-facing instruction for
  this dispatch is explicit that §3 belongs to 02.3 only if 02.1 does not already own the file and only if
  §3 needs changing — it does not need changing, so it stays out of scope here.

Standing defaults: identifiers and timestamps are untouched by this task (no schema, no data, no state
shape changes here); no model call exists in this task's scope, so no confidence threshold or Tier-0
fallback applies; telemetry is untouched; no identifying field is added anywhere (I5); no node's
`paraphrase` or Ministry text is touched (I6) — this task edits only the graph-constraints contract's own
rule prose.

## §7 Done definition

The task is done when ALL gates pass:

- `git diff --stat` shows exactly one changed file: `contracts/graph-constraints.md`.
- format/lint: N/A for Markdown (no `swift-format` or `ruff` target touches this file); confirmed by
  `scripts/gate.sh` still passing end-to-end (no gate scans `contracts/*.md` for lint).
- typecheck: N/A (no Swift or Python file is touched).
- `Core` build + test green (`swift build`; `xcodebuild test -scheme Core-Package`) — unaffected by this
  task, run once to confirm no accidental breakage.
- App build green (`xcodebuild build -scheme mathmath`) + `pytest` — unaffected by this task, run once to
  confirm no accidental breakage.
- all six checks of §5 (T1–T6) pass as described, including the pre-edit control of T5.
- `contracts/graph-constraints.md` reads `Contract version: v1.1.0`; the commit carries scope
  `contract(graph-constraints)`.
- conforms to every contract section cited in §3 and §4, and to every invariant listed in §1.
