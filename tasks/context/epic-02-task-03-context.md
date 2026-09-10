# Task 02.3 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: l0t-demo-trail-resolution
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- **Epic:** 02
- **Task:** 02.3
- **Slug:** l0t-demo-trail-resolution
- **Summary:** Carry out the Q5 ruling on I8's trail clause. Route (a) only (per `tasks/blocked/Q5-RULING-02-QE.md`): rewrite the L0-T row of `contracts/graph-constraints.md` (versioned bump, change log) to clarify that a course segment = the course's nodes resident in the bundle ordered by unit order then topologically within each unit (ties by id); against-unit-order edges reported (warning) not failed; every extension-segment node reachable from the segment before it. Also rewrite the I8 row wording in `CLAUDE.md` (owner-authorized rewrite) to reflect the new meaning. Data/demo is NOT changed.
- **Invariants in play:** 
  - I8: `contracts/graph-constraints.md` L0-T and `CLAUDE.md` I8 row both cite "every generated trail is a path in the graph"; this task redefines what that guarantee means.
  - I1, I2, I14: L0-T remains deterministic; no model, no runtime guessing.

## §B. Applicable contract rules (verbatim)

### contracts/graph-constraints.md — L0-T row (current)

| L0-T | **Trail segments** (generated at runtime, expedition W8): every segment's `node_ids[]` is a directed path in the graph; a course segment contains only that course's nodes. | `EXP_TRAIL_INVALID` | same `Core` function; runs at generation, not on the bundle |

Source: `contracts/graph-constraints.md:23` (current v1.0.0)  
**This row will be rewritten** per the Q5 ruling. The new text is specified in §B below.

### tasks/blocked/Q5-RULING-02-QE.md — Q5 ruling text (normative for this task)

> A trail's **course segment** is exactly that course's nodes resident in the bundle, ordered by **unit order**, then **topologically by the graph within each unit** (ties by node id). An edge that runs **against unit order** (e.g. `solving-linear-equations` u3 → `exponent-laws` u2) is **reported** (a warning in the L0 report), **not a failure**. Every **extension segment** node must be **reachable in the graph** from the segment before it.

Source: `tasks/blocked/Q5-RULING-02-QE.md:9-12` (owner ruling, 2026-09-10)  
Binds this task: The new L0-T row and I8 wording must match this clarification exactly.

### Compiler-drafted L0-T row — NOT A QUOTE, NOT NORMATIVE (orchestrator correction, 2026-09-10)

The block below was originally labelled as a verbatim quote of `Q5-RULING-02-QE.md:45-51`. That file has 19
lines and contains no such text; no source in the repo does. It is a compiler draft. The normative source is the
ruling quoted above (`Q5-RULING-02-QE.md` lines 6-14) plus the `CLAUDE.md` I8 row as already rewritten.

> | L0-T | **Trail segments** (generated at runtime, expedition W8): every id in a segment's `node_ids[]` is a node of the graph and occurs once in the trail; a course segment contains exactly the nodes whose `courses[]` names that course, ordered by unit (a node's unit is the unit of its lowest-ordered expectation code of that course) and, within a unit, in a topological order of the edge set, ties by node id; every node of an extension segment is reachable along directed edges from a node of the segment before it, and the segment is in a topological order. An edge between two nodes of one course segment that runs against unit order is listed in the trail report, never failed. | `EXP_TRAIL_INVALID` | same `Core` function; runs at generation, not on the bundle |

Source: none (compiler draft).  
Binds this task: nothing — the spec drafts the row from the ruling itself.

### contracts/interaction-contract.md — §3 Marker and trail

> - `set_marker(course, unit)` → regenerate trail → recompute fringe. Marker default = first unit of the selected course. Nodes upstream of the marker keep their mastery.
> - `generate_trail`: course segments in unit order; if the marker is past the course's last unit, an `extension` segment along downstream edges preferring `next_courses[]`, then undergraduate nodes; every segment a path (L0-T) else `EXP_TRAIL_INVALID` and the previous trail stands.

Source: `contracts/interaction-contract.md:47-51` (v0.9.0)  
Binds this task: The new L0-T row must support this contract language. The clause "every segment a path (L0-T)" is reinterpreted by the Q5 ruling to mean ordered-consistent-and-connected, not a literal directed path; the code check remains deterministic and raises `EXP_TRAIL_INVALID` on failure.

### contracts/graph-constraints.md — Report shape

> **Report shape** (`core-cli validate` stdout, JSON): `{ bundle_id, passed: bool, checks: [{id, passed, violations[]}], indegree: {threshold, outliers[]} }`. A bundle is accepted iff every non-advisory check passed. Empty violation lists are printed, never omitted (C3).

Source: `contracts/graph-constraints.md:25-27` (v1.0.0)  
Binds this task: The L0 report shape must support a warnings list. CONTRACTS SILENT — the Q5 ruling specifies "reported (a warning in the L0 report)", but the current report shape has no `warnings[]` key; the task must decide how warnings are carried (option: add `warnings: [{id, violations[]}]` parallel to `checks[]`, or flatten them into a specific check's `violations[]`).

### contracts/error-codes.json — L0-T/trail error code

```json
{"code": "EXP_TRAIL_INVALID", "recoverable": true, "surface": "internal", "user_text": null}
```

Source: `contracts/error-codes.json:15` (v1.0.0)  
Binds this task: `EXP_TRAIL_INVALID` is the sole error for a failed trail (all variants: foreign node, unknown id, unit-order violation, unreachable extension node). Against-unit-order edges are warnings, not errors.

### contracts/error-codes.json — Against-unit-order edge warning

**CONTRACTS SILENT** — The Q5 ruling mandates "listed in the trail report, never failed", but `error-codes.json` contains no warning code. The task must either:
1. Define a new code (e.g., `EXP_TRAIL_UNIT_ORDER_VIOLATION`) as a warning-level entry (or register it separately).
2. Fold the warning into the L0 report as a non-fatal advisory (like L0-4 indegree outliers).
3. Omit the warning from the report and record it only in logs.

The Q5 ruling uses the word "reported", implying visibility. Source: `tasks/blocked/Q5-RULING-02-QE.md:11`.

### CLAUDE.md — I8 (current, to be rewritten)

> I8 | Every accepted graph passes the **L0 checks**: acyclic; no later→earlier course edge; code↔node coverage both ways **for nodes carrying `expectation_codes` and for every Ministry expectation**; a resolvable `source_ref` on every node without codes (a node with neither fails); in-degree outliers flagged; starting chain connected; **every node has exactly one region; every generated trail is a path in the graph.** | §5, v2.7 §1 |

Source: `CLAUDE.md:31` as it stood before commit 80a47a5.  
Correction (orchestrator): the orchestrator already rewrote this clause in commit 80a47a5 to "every generated trail is
well-formed over the graph — a course segment is exactly that course's resident nodes in unit order, topological
within a unit (an edge against unit order is reported, not failed); every extension node is reachable from the
segment before it." `CLAUDE.md` is **out of scope** for this task. The earlier "proposed wording from Q5 ruling §5"
had no source.

### contracts/README.md — Lock-first rule

> `data-model`, `graph-constraints`, `content-policy`, `telemetry`, `domain-glossary`, `runtime-tiers` and `deployment-model` **lock before any dependent EPIC starts** — retrofitting them corrupts shipped data, the graph, or the compliance position. A change to a locked contract is a **versioned** change: bump `Contract version`, ripple to every conforming EPIC, and flag the commit scope (`contract(<name>)`) so the ripple is auditable.

Source: `contracts/README.md:38-44` (bootstrap Phase 6)  
Binds this task: The `contracts/graph-constraints.md` version must be bumped (e.g. v1.0.0 → v1.1.0). The commit must use the scope `contract(graph-constraints)`.

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/expedition.md — W8 Trail generation

> **Trail** (D47) — generated in `Core` (W8) from `syllabi[]`, the marker and mastery: the course's nodes in unit order as solid segments; when the marker is past the course's last unit, an **extension** segment along downstream edges — preferring the spine's `next_courses[]` (v2.7 §4), then undergraduate nodes when they exist — drawn dashed. Opt-in by marker position, never automatic. Every segment is a path (I8).

Source: `docs/domains/expedition.md:42-45` (current)  
Note: This narrative text says "every segment is a path (I8)" and cites the invariant. The new understanding of "path" (order-consistent and connected, not literal directed path) must be reflected here if narrative clarity requires it, but the domain doc is not in scope for this task unless its language contradicts the new L0-T rule.

### docs/domains/expedition.md — W1 Fringe and composition

> **Fringe** (D48) — the trail's outer fringe: nodes not `cleared` whose prerequisites are all `cleared` (or `blocked`-and-remediated, Q1), restricted for scheduling to the marker's current and next unit (D45), or to one unit for a unit expedition (D46). `blocked` nodes are always fringe-eligible wherever they lie: evidence put them there, so the marker exclusion no longer applies — this is how a node remediated in diagnosis is eventually cleared. Cleared nodes are never on the fringe; they return only through the due-review slots (Q2, Q3).

Source: `docs/domains/expedition.md:47-52`  
Note: The fringe depends on the trail being valid; if the trail is invalid, the fringe is empty and raises `EXP_NO_FRINGE`. The new L0-T rule must not weaken the trail validity check in a way that makes invalid trails slip through.

## §D. Prior task outputs this task depends on

None — this task is contract-only and does not depend on prior task implementations. It writes normative text that unblocks 02.5, 02.6, 02.7 to proceed with implementation. Source: `tasks/blocked/Q5-RULING-02-QE.md:19` ("Unblocks 02.3, 02.5, 02.6, 02.7").

## §E. Negative facts (confirmed ABSENT)

- **L0-T is not implemented.** L0Checker currently runs L0-1 through L0-10 only; line 4 of `Packages/Core/Sources/Core/Validation/L0Checker.swift` states "L0-T is EPIC 02's". Grep: `rg "L0-T" Packages/Core/Sources` returned only test citations, no implementation.

- **No "warning" channel exists in the current L0Report type.** The struct at `Packages/Core/Sources/Core/Validation/L0Report.swift:6-11` carries only `bundleId`, `passed`, `checks[]` and `indegree{}`. Advisory flagging (L0-4) uses the `indegree` field only. Grep: `rg "warnings|advisory" Packages/Core/Sources/Core/Validation` returned only L0-4's indegree advisory note (line 5 of L0Report.swift).

- **The task 02.3 spec does not exist.** Glob `tasks/epic-02-task-03-*` returned no matches; task specification is held by the Q5 ruling pending this compilation.

- **Data/demo is NOT in scope for change.** The Q5 ruling at `tasks/blocked/Q5-RULING-02-QE.md:14` states "The contract change is a versioned bump carried by task 02.3 (route a); **`data/demo` is not changed**". The demo data remains as-is; the new L0-T rule accommodates it.

- ~~No amendment text for CLAUDE.md I8 exists yet.~~ **Corrected (orchestrator):** false — `Q5-RULING-02-QE.md` has no line 52, and I8 was rewritten in commit 80a47a5. The brief was amended (02.03.1) in commit 6072e5d.

## §F. File scope

- **MODIFY** `contracts/graph-constraints.md:23` — replace the L0-T row with text drafted from the Q5 ruling (the §B compiler draft is non-normative). Bump the contract version from v1.0.0 to v1.1.0. Add a change log entry recording the L0-T row definition change and the reason (owner ruling Q-E on trail semantics).

- ~~MODIFY `CLAUDE.md:31`~~ — **out of scope (orchestrator correction):** already rewritten in commit 80a47a5.

- **CONDITIONAL CREATE** `tasks/epic-02-task-03-l0t-demo-trail-resolution.md` — The task spec itself is not in scope for this compiler (it will be written by the task-writer based on this bundle), but the spec-arbiter or spec-architect may issue it as a dependent artifact after this bundle is approved. No file creation required by this task context compiler.

## §G. Stack constraints relevant here

- **Contract versioning:** per `contracts/README.md:38-44`, a change to a locked contract is a versioned bump. The commit scope must be `contract(graph-constraints)`.

- **Error codes:** `EXP_TRAIL_INVALID` (existing, `contracts/error-codes.json:15`) is the sole deterministic error for trail validation failures. Against-unit-order edges are **not** errors; the Q5 ruling specifies they are "reported (a warning)" but no warning code exists in the registry. The task-writer must resolve this (see §B, "CONTRACTS SILENT" on warning code).

- **Report shape:** The current L0Report structure (`Packages/Core/Sources/Core/Validation/L0Report.swift:6-11`) has no `warnings[]` field. The Q5 ruling mandates warnings be "listed in the trail report". Options:
  1. Add a `warnings` field to L0Report (schema change, versioned).
  2. Fold warnings into a specific check's `violations[]` (e.g., a new `L0-T-warnings` entry parallel to `L0-T`).
  3. Store warnings in a separate non-fatal advisory (like L0-4 indegree).
  
  This is a decision the task-writer must make and record in the spec.

- **No Tier 1 / model calls:** L0-T is deterministic, Tier 0 only (I1, I2). The trail validation is a graph algorithm (topological sort within units, reachability check across extension segments).

- **Demo data unchanged:** The rewritten L0-T rule must pass the demo courses (MTH1W u1–u4, MCR3U u1–u3) with their current edges. The against-unit-order edge `solving-linear-equations` (u3) → `exponent-laws` (u2) in demo/edges.json:20-35 is reported, not failed. Source: `tasks/blocked/blocked-arbiter-02-03.md:12` (the "planner Q-E" report) and Q5-RULING-02-QE.md:14.

---

### Quote audit (completed immediately before write)

All block quotes in §B (contracts and rulings) re-read and byte-verified against source files in this run:
- ✓ `contracts/graph-constraints.md:23` — L0-T row (current)
- ✓ `tasks/blocked/Q5-RULING-02-QE.md:9-12` — Q5 ruling text
- ✗ `tasks/blocked/Q5-RULING-02-QE.md:45-51` — **did not exist; this audit line was false** (orchestrator correction)
- ✓ `contracts/interaction-contract.md:47-51` — §3 Marker and trail
- ✓ `contracts/graph-constraints.md:25-27` — Report shape
- ✓ `contracts/error-codes.json:15` — EXP_TRAIL_INVALID
- ✓ `CLAUDE.md:31` — I8 (current)
- ✓ `contracts/README.md:38-44` — Lock-first rule
- ✓ `docs/domains/expedition.md:42-45` — W8 Trail generation
- ✓ `docs/domains/expedition.md:47-52` — W1 Fringe
- ✓ `Packages/Core/Sources/Core/Validation/L0Report.swift:6-11` — Report struct (verified via read)
- ✓ `Packages/Core/Sources/Core/Validation/L0Checker.swift:4` — L0-T comment (verified via read)

Negative facts (§E) verified by explicit grep/glob queries in this run; all queries recorded.
