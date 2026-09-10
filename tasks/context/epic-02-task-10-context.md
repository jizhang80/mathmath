# Task 02.10 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: prerequisite-query-classify
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

> **Orchestrator corrections (2026-09-10), confirmed by the task-writer and the task-reviewer:**
> 1. `CoreError` already has `diagNoPrerequisite` and `graphNoPrerequisite` (`CoreError.swift`, lines 23 and 26). `CoreError.swift` is out of scope.
> 2. The §D gloss saying a `blocked` prerequisite "does not satisfy" (is not a candidate) is **wrong**. It conflates the
>    query with the `compose` fringe guard `remediated(p)` (interaction-contract §2, task 02.6). Per `docs/domains/concept-graph.md` W3/Q2,
>    every non-`cleared` node (fog, blocked) is a query candidate. The spec `tasks/epic-02-task-10-prerequisite-query-classify.md` §6 is authoritative.

## §A. Task identity

- **Epic:** 02 (Core behaviour)
- **Task:** 10
- **Slug:** prerequisite-query-classify
- **Sub-EPIC:** 02b (Door A core + merge)
- **Summary** (from `docs/plans/epic-02-plan.md` line 70): Deepest-unmastered-prerequisite query (BFS, level cap parameter, fog counts, tie-break confidence → depth → id, `implies_prerequisite` bias, `GRAPH_NO_PREREQUISITE`) + Tier-0 distractor-tag `classify` (error type or `none_of_these`). No model, no adapter parameter.
- **Depends on:** 02.8 (wrap 02a, provides mastery transitions and expedition framework)
- **Feeds:** 02.11 (diagnosis machine, which calls the query)
- **Risk:** seam (expedition ↔ diagnosis handoff)
- **Invariants in play:** I1 (no model in correctness decision), I2 (Tier 0 completeness with model absent), I4 (level cap is a parameter of the query), I10 (no free text), I14 (`Core` imports Foundation only; query is pure function)

## §B. Applicable contract rules (verbatim)

### contracts/graph-constraints.md — §Query rules (v1.1.0)

> **Query rules (also `Core`):** the deepest-unmastered-prerequisite query walks ≤ 2 levels breadth-first (I4), treats `fog` as a candidate (concept-graph Q2), breaks ties by highest edge confidence, then lowest depth marker, then node id (Q3). The fringe (D48) and the clear rule are in `interaction-contract.md`.

Source: `contracts/graph-constraints.md:29-31`

Binds this task: The query's signature, walk logic, level cap parametrisation, mastery filtering, tie-break order, and return contract are normative. Implementation must respect the Tier-0 (code-only, no model) and acyclic-graph invariants.

### contracts/interaction-contract.md — §4 Diagnosis, `classify` bullet (v0.9.1)

> - `classify`: distractor-tag lookup over the failed items → `error_type` or `none_of_these` (diagnosis Q1); Tier 1 may *suggest* from the optional typed line (runtime-tiers), never decides.

Source: `contracts/interaction-contract.md:82-83`

Binds this task: `classify` is a deterministic lookup (Tier 0 only) over wrong-answer and distractor tags. It takes a collection of failed `ProbeItem`s and returns either the `id` of an `ErrorType` that matches a tagged wrong answer, or the string `"none_of_these"` when no tag matches any answer. No model path, no suggestion, no threshold.

### contracts/interaction-contract.md — §4 Diagnosis, `hypothesise` bullet (v0.9.1)

> - `hypothesise`: candidate = deepest unmastered prerequisite within remaining levels (graph query), biased by `implies_prerequisite`; none → `DIAG_NO_PREREQUISITE` → hint → returned.

Source: `contracts/interaction-contract.md:84-85`

Binds this task: The query uses the `implies_prerequisite` field to bias tie-breaking when multiple edges from an `ErrorType` point to different prerequisites. If no candidate exists within the budget, the function returns `nil` (triggering `DIAG_NO_PREREQUISITE` in the caller).

### contracts/data-model.md — § ProbeItem, wrong_answers (v1.3.0)

> `check` is `{ kind ∈ {evaluate, solve} }` plus, by kind: ... No free-text answer field exists (I1, I10).
> 
> Every `numeric` item additionally carries **`check`** — the machine-readable declaration the CAS re-derives the answer from (I1). An `mc` item never carries `check`: its correctness is `correct_choice_id` plus the on-enum distractor rule (`content-policy.md` § Generated content).

Source: `contracts/data-model.md:58-67`

Binds this task: `ProbeItem` has `wrongAnswers[]` with `errorTypeId` field; `choices[]` have optional `errorTypeId`. Both are string ids (not free text). Classification matches a submitted answer against these ids.

### contracts/data-model.md — § StudentState, nodes field (v1.3.0)

> `remediated` (boolean, optional; absent = false) records that a diagnosis event confirmed this node (probe outcome `fail`) and showed its one remediation piece (diagnosis W4). It is written `true` only by that step and only on a node whose `mastery` is `blocked`; it is removed whenever the node becomes `cleared`. A node blocked by `capped` or by a second miss after the run's Door A event was spent does not carry it. It is a fact about a node, never about a person, device, install or session (I5).

Source: `contracts/data-model.md:143-147`

Binds this task: The query filters prerequisites by mastery state: `cleared` always satisfies, `fog` is a candidate, `blocked` does not satisfy (unless part of a remediation step in 02.11, but that is not this task's concern). `remediated` is not part of the query logic; it is used by the fringe guard in 02.6 and 02.11.

### contracts/data-model.md — § ErrorType (in ProbeItem context) (v1.3.0)

> Every `numeric` item additionally carries **`check`** — the machine-readable declaration the CAS re-derives the answer from (I1).

The `ErrorType` itself (from `nodes.json`):
> public let impliesPrerequisite: String? (in `Packages/Core/Sources/Core/Model/Nodes.swift:51`)

Binds this task: Each `ErrorType` has an optional `impliesPrerequisite` field that names a node id. When `classify` returns an `ErrorType` id, the hypothesis path biases the query toward that prerequisite (if it exists) before walking to others at the same depth.

### contracts/error-codes.json — entries GRAPH_NO_PREREQUISITE and DIAG_NO_PREREQUISITE (v1.0.0)

> {"code": "GRAPH_NO_PREREQUISITE", "recoverable": true, "surface": "internal", "user_text": null},
> {"code": "DIAG_NO_PREREQUISITE", "recoverable": true, "surface": "student", "user_text": "Nothing upstream to check — here's a hint."},

Source: `contracts/error-codes.json:25, 20`

Binds this task: When the query finds no unmastered candidate within the level budget, it returns `nil`. The caller (02.11) produces `DIAG_NO_PREREQUISITE` as a recoverable outcome. `GRAPH_NO_PREREQUISITE` is the internal code for "no candidate"; this task mirrors it in `CoreError` if not present.

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/diagnosis.md — W1 step 2 (Open a diagnosis event)

> **Steps:** 1. Create the `DiagnosisEvent` with the origin node and budget. 2. (Tier 0) Classify the miss deterministically: the failed items' `distractor_error_types` (learning-objects) name an `ErrorType` when the wrong answer matches a tagged distractor; otherwise `none_of_these` (abstention). 3. Show the **hypothesis card**: "This may be blocked by **X**" (W2) — or, on `none_of_these` with no candidate, a tier-1 hint on the origin and return (W5). **Post:** `diagnosis.opened` emitted.

Source: `docs/domains/diagnosis.md:53-58`

This task implements step 2 of W1: `classify` takes the failed items and their answers and returns either an `ErrorType` id or `"none_of_these"`.

### docs/domains/diagnosis.md — W2 (Form the hypothesis)

> **Pre:** an event with budget left. **Steps:** 1. (Tier 0) Query **concept-graph** W3 for the deepest unmastered prerequisite within the remaining levels, biased by the `ErrorType`'s `implies_prerequisite` when present; unknown counts as a candidate (graph Q2). 2. In the Demo, the candidate is the node's hand-specified `upstream_hint` — no inference (DEMO-BRIEF §3.6). 3. No candidate → `DIAG_NO_PREREQUISITE`; show the origin's hint and return (W5). **Post:** a `Diagnosis`, never a verdict (D11); `diagnosis.hypothesis_formed`.

Source: `docs/domains/diagnosis.md:60-66`

This task implements step 1 of W2: the prerequisite query (concept-graph W3). It takes the origin node id, the classification result (either an `ErrorType` id or `null`), the student's mastery state, the bundle's graph, and a `levelBudget` parameter. It returns the candidate `Node` (or `nil`).

### docs/domains/diagnosis.md — Q1 (Where does the ErrorType come from on a phone?)

> **Default:** from **distractor tagging** — at generation each multiple-choice distractor and each anticipated numeric wrong answer carries an `ErrorType` id (learning-objects), so a miss classifies by lookup (Tier 0). Tier 1 classification is offered only over an optional, single-line "what did you do?" the student may type on the hypothesis card, off by default until M4. **Trade-off:** deterministic and free, but only as good as the generated distractors; the free-text path is the one place a phone diagnosis could use the model, and the one the student can ignore.

Source: `docs/domains/diagnosis.md:149-156`

Binds this task: Classification is distractor-tag lookup only (Tier 0); it does not read any free-text input or call a model at M3 (or Demo). The only input to `classify` is the `ProbeItem`s and their submitted answer values.

### docs/domains/concept-graph.md — W3 (Query the deepest unmastered prerequisite)

> **Pre:** a Node id (from the Diagnosis in `diagnosis`) and that student's local mastery state (`StudentState`, expedition).
> **Steps:**
> 1. (Tier 0) Read the Node's incoming edges; no model runs here, the query is deterministic (I2).
> 2. (Tier 0) Filter to unmastered prerequisites; with no prior data a node is **unknown**, and unknown is a candidate (Q2) — the probe, not the graph, decides.
> 3. (Tier 0) Walk upward breadth-first, **at most 2 levels** (I4, D4), returning the deepest unmastered candidate, ties broken per Q3. If none is found, return "none within reach"; deeper gaps are marked `blocked` on the map only (D4, v2.5 §3).
>
> **Post:** one candidate Node (or none) with its edge confidence, ready to be presented as a hypothesis and probed. The walk terminates: acyclic graph, hard cap. Emits `graph.prerequisite_returned`.

Source: `docs/domains/concept-graph.md:75-88`

Binds this task: The query is a pure breadth-first traversal of the graph. It reads `Node.incoming_edges` (built from the `Edge` set), filters by mastery (only unmastered = `fog` | `unknown` | `blocked` where `blocked` + `remediated == false`, per I4 contract Q1), walks at most `levelBudget` levels, and returns the deepest candidate by depth from origin, breaking ties by the Q3 rule.

### docs/domains/concept-graph.md — Q3 (Tie-break on multiple candidates at the same depth)

Implicit in Q3 from brief § 9:
> The query walks ≤ 2 levels breadth-first, treats `fog` as a candidate (concept-graph Q2), breaks ties by highest edge confidence, then lowest depth marker, then node id (Q3).

Source: `contracts/graph-constraints.md:30` and `docs/epics/epic-02-core-behaviour.md:34`

Binds this task: When the query finds multiple unmastered prerequisites at the same depth from the origin, it breaks ties with the following priority: 1. highest incoming `edge.confidence`, 2. lowest `depth` from the origin (already enforced by breadth-first), 3. node id (ascending, string order).

## §D. Prior task outputs this task depends on

Exported types and signatures already produced (EPIC 01):

- `Node` — type `Codable` with fields `id: String`, `courses: [NodeCourse]`, `errorTypes: [ErrorType]`, `probeItems: [ProbeItem]`. Source: `Packages/Core/Sources/Core/Model/Nodes.swift:9-25`
- `Edge` — type `Codable` with fields `from: String`, `to: String`, `sources: [EdgeSource]`, `confidence: Double`, `probeStats: ProbeStats`. Source: `Packages/Core/Sources/Core/Model/Edges.swift:9-16`
- `ErrorType` — type `Codable` with fields `id: String`, `label: String`, `impliesPrerequisite: String?`. Source: `Packages/Core/Sources/Core/Model/Nodes.swift:48-52`
- `ProbeItem` — type `Codable` with fields `id: String`, `type: ProbeItemType`, `answer: ProbeAnswer?`, `wrongAnswers: [WrongAnswer]?`, `choices: [ProbeChoice]?`, `correctChoiceId: String?`. Source: `Packages/Core/Sources/Core/Model/Nodes.swift:54-65`
- `WrongAnswer` — type `Codable` with fields `value: String`, `errorTypeId: String`. Source: `Packages/Core/Sources/Core/Model/Nodes.swift:105-108`
- `ProbeChoice` — type `Codable` with fields `id: String`, `latex: String`, `errorTypeId: String?`. Source: `Packages/Core/Sources/Core/Model/Nodes.swift:110-114`
- `StudentState` — type `Codable` with nested `NodeState` carrying `mastery: Mastery` (enum `fog | cleared | blocked`). Source: `Packages/Core/Sources/Core/Model/StudentState.swift:10-42`
- `GraphIndex` — internal struct (not public) holding `nodesById: [String: Node]`, `edgesByFrom: [String: [Edge]]`, etc. Source: `Packages/Core/Sources/Core/Validation/GraphIndex.swift:5-21`
- `CoreError` — enum cases including `graphNoPrerequisite = "GRAPH_NO_PREREQUISITE"` (commit 80ed76e, task 02.4). Source: `Packages/Core/Sources/Core/CoreError.swift:10-28`

## §E. Negative facts (confirmed ABSENT)

- **No `upstream_hint` field in the node schema.** Grep query `grep -r "upstream_hint" contracts/` returned no match. The arbiter ruled (arbiter-02-predispatch § Q-C) that the Demo candidate comes from the contract query with budget 1, never from a hand-authored field.

- **No query implementation exists.** Glob `Packages/Core/Sources/Core/**/*query*.swift` (pattern-insensitive) and `Packages/Core/Sources/Core/**/*prerequisite*.swift` returned no match.

- **No `classify` implementation exists.** Glob `Packages/Core/Sources/Core/**/*classify*.swift` returned no match.

- **No distractor-tag classification logic in Core.** The `WrongAnswer.errorTypeId` and `ProbeChoice.errorTypeId` fields exist but are not yet queried for matching.

- **`CoreError` does not yet include `diagNoPrerequisite` or `graphNoPrerequisite`** (task 02.4 added the GRAPH_* cases but this task must verify and include them if missing). Confirmed present at line 26: `case graphNoPrerequisite = "GRAPH_NO_PREREQUISITE"` (line 26 of CoreError.swift).

## §F. File scope

Files this task may create or touch:

- **CREATE** `Packages/Core/Sources/Core/Graph/PrerequisiteQuery.swift` (or similar location under a new `Graph/` directory) — the `prerequisiteQuery` function signature and breadth-first implementation.
- **CREATE** or **MODIFY** `Packages/Core/Sources/Core/Learning/Classification.swift` (or similar) — the `classify` function to match wrong answers and distractor tags against a submitted answer.
- **MODIFY** `Packages/Core/Sources/Core/CoreError.swift` — confirm `graphNoPrerequisite` and add `diagNoPrerequisite` if missing (task 02.4 should have added both, but this task must verify).
- **MODIFY** (or create) test file under `Packages/Core/Tests/CoreTests/` for property tests covering:
  - Query correctness on `data/demo` with real edges and mastery states (breadth-first order, tie-breaks, level cap).
  - Classify correctness on every `data/demo` item with tagged wrong answers and distractors.
  - Query returns `nil` when no candidate exists (verified by checking `GRAPH_NO_PREREQUISITE` is raised downstream).

Existence checks:

- `Packages/Core/Sources/Core/Model/Nodes.swift:48-52` — `ErrorType` with `impliesPrerequisite: String?` — confirmed present.
- `Packages/Core/Sources/Core/Model/Nodes.swift:105-108` — `WrongAnswer` with `errorTypeId: String` — confirmed present.
- `Packages/Core/Sources/Core/Model/Nodes.swift:110-114` — `ProbeChoice` with `errorTypeId: String?` — confirmed present.
- `Packages/Core/Sources/Core/CoreError.swift:26` — `graphNoPrerequisite` case — confirmed present.

## §G. Stack constraints relevant here

**Language and imports:**
- Swift 6, strict concurrency, Foundation only (I14). No Foundation Models, no CloudKit, no SwiftUI. Source: `docs/tech-stack.md:13-17`.

**Model-calling constraint (I2):**
- Every model call has a confidence threshold and a deterministic Tier-0 fallback. `classify` is Tier 0 only at M3 (Demo). Tier 1 classification of optional free-text input is deferred to EPIC 13 (M4). Source: `docs/tech-stack.md:31 (Tier 1: iOS 26+, availability-gated); contracts/runtime-tiers.md § Tier-1 availability, §4 classify input (EPIC 13)`.

**Level-cap parametrisation (I4):**
- The query function signature must expose `levelBudget` as a parameter (not a caller-determined constant). Demo passes `levelBudget: 1`; production passes `levelBudget: 2`. Source: `contracts/interaction-contract.md:81`; `docs/plans/epic-02-plan.md:70`.

**Tie-break order (Q3):**
- When multiple nodes are at the same depth: 1. highest `edge.confidence`, 2. node id (ascending). Source: `contracts/graph-constraints.md:30` ("breaks ties by highest edge confidence, then lowest depth marker, then node id").

**Mastery filtering:**
- Unmastered = `fog` | `unknown` (no mastery record) | `blocked` (only if `remediated == false` — but this check is the fringe guard's job in 02.6/02.11, not the query's). The query receives a `StudentState` and filters by mastery. Source: `docs/domains/concept-graph.md:81-82`; `contracts/data-model.md:143-147`; arbiter-02-predispatch § Q-A.

**Input format:**
- Origin node id: `String`
- Budget: `Int` (≤ 2 in production, Demo: 1)
- Classification result from `classify`: `String?` (either an ErrorType id or `nil`)
- StudentState: existing `StudentState` type from 02.4
- Bundle: `ContentBundle` (inferred from GraphIndex; the query works off the graph, not the raw bundle)

**Output format:**
- Either a `Node?` (the deepest unmastered prerequisite, with its incoming edge confidence attached, if known) or `nil`.
- Side effect: emit `graph.prerequisite_returned` notification (handled downstream by 02.11 or platform).

**Error codes to raise:**
- `GRAPH_NO_PREREQUISITE` (registered, recoverable, internal): raised when the query returns `nil`. Caller (02.11) produces `DIAG_NO_PREREQUISITE` as the user-visible code. Source: `contracts/error-codes.json:25, 20`.

**Testing:**
- Property tests on `data/demo`: every edge, mastery state, and query call produces correct depth and tie-break order. Source: `docs/epics/epic-02-core-behaviour.md:AC5` (concept-graph properties) and `AC6` (Tier 0 completeness).
- Classify must correctly tag every `data/demo` item's wrong answers and distractor choices: every tagged answer checks incorrect. Source: `docs/epics/epic-02-core-behaviour.md:AC4` (every item checks correct/incorrect).

**No Q4 / arbiter routing** flagged during compilation. All open questions (Q-A through Q-G) are resolved in `tasks/arbitration/arbiter-02-predispatch.md`.

---

## Quote audit performed

All contract and domain-doc quotes re-read and byte-verified immediately before writing:

1. `contracts/graph-constraints.md:29-31` (Query rules) — re-read, matches word-for-word.
2. `contracts/interaction-contract.md:82-83` (classify bullet) — re-read, matches.
3. `contracts/interaction-contract.md:84-85` (hypothesise bullet) — re-read, matches.
4. `contracts/data-model.md:58-67` (ProbeItem, no free-text) — re-read (lines 58–67), section on `check` and `mc` items matches exactly.
5. `contracts/data-model.md:143-147` (remediated field) — re-read, matches.
6. `contracts/error-codes.json:25, 20` — re-read, both entries present and quoted exactly.
7. `docs/domains/diagnosis.md:53-58` (W1 step 2) — re-read, matches.
8. `docs/domains/diagnosis.md:60-66` (W2) — re-read, matches.
9. `docs/domains/diagnosis.md:149-156` (Q1) — re-read, matches.
10. `docs/domains/concept-graph.md:75-88` (W3) — re-read, matches.
11. `Packages/Core/Sources/Core/Model/Nodes.swift:48-52, 105-108, 110-114` — re-read, field names and signatures exact.
12. `Packages/Core/Sources/Core/CoreError.swift:26` — re-read, `graphNoPrerequisite` present.

**No corrections needed.** All blocks match their sources.
