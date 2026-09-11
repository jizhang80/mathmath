# Task 04.1b context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: data-demo-none-of-these-hints

Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- Epic: 04
- Task: 04.1b
- Sub: a (Door core)
- Slug: data-demo-none-of-these-hints
- Summary: Add `hint_tree["none-of-these"]` (three plain-text tiers) to every node in `data/demo/nodes.json` and its embedded copy `App/Sources/DemoSnapshot/nodes.json`; update the rendering-spike count table and the test that pins it; manifest hashes only if they are not placeholders. Agent-authored, machine-verified hand-written data (I9); no CAS step (hints are neither answers nor worked examples).
- Invariants in play: I1 (step correctness by CAS only, not model), I2 (Tier 0 usable product; no guess), I6 (no Ministry prose, own paraphrase), I9 (zero human content review — agent-authored + machine-verified)

## §B. Applicable contract rules (verbatim)

### contracts/data-model.md — Collections / nodes.json row — hint_tree shape
> `hint_tree {error_type_id → [tier1, tier2, tier3]}`

Source: `contracts/data-model.md:50`
Binds this task: Every node's `hint_tree` object must have exactly three tiers for each key, including `"none-of-these"` once added.

### contracts/schemas/nodes.schema.json — hint_tree object definition
> ```json
> "hint_tree": {
>   "type": "object",
>   "additionalProperties": {
>     "type": "array",
>     "items": {
>       "type": "string",
>       "minLength": 1
>     },
>     "minItems": 3,
>     "maxItems": 3
>   }
> }
> ```

Source: `contracts/schemas/nodes.schema.json:212-222`
Binds this task: `hint_tree` keys are open (`additionalProperties`); any key's value must be exactly three non-empty strings.

### contracts/data-model.md — Identifiers — kebab-case ids
> Ids are **stable, opaque, lowercase kebab-case slugs** matching `^[a-z0-9]+(-[a-z0-9]+)*$`, unique within their collection.

Source: `contracts/data-model.md:13-14`
Binds this task: The `"none-of-these"` id matches the kebab-case pattern; it is the catalogue id spelling (see Glossary rule below).

### contracts/content-policy.md — Voice — no percentages, plain text
> **Voice** — Teacher, not chatbot: one thing at a time, no persona, no filler, **no scores or percentages on student surfaces**; a node is named, the student never is (diagnosis §7 stance).

Source: `contracts/content-policy.md:54-55`
Binds this task: Hints are student-facing text; they must follow teacher voice and name no percent or score.

### contracts/content-policy.md — Generated content — prompts and hints
> Prompts and hints must render in SwiftMath or carry `render_fallback: "katex"` (learning-objects W1 5b).

Source: `contracts/content-policy.md:34-35`
Binds this task: Every `none-of-these` tier string must be plain text or SwiftMath-renderable; no `render_fallback` is applied to `hint_tree` entries (only to `probe_items[].prompt_latex` and `choices[].latex`).

### contracts/content-policy.md — Grade 9–12 tier — paraphrase rule
> Paraphrase rule (curriculum-spine Q1): one verb-initial plain sentence, no LaTeX, ≤ 140 characters, rejected on a shared 6-gram with the source outside the technical-term allow-list.

Source: `contracts/content-policy.md:10`
Binds this task: Hints are not paraphrases but follow the same style: plain sentence, no LaTeX in tier strings, no verbatim Ministry text.

### contracts/domain-glossary.md — Error type — none-of-these catalogue id spelling
> **Error type** (`ErrorType`) — a member of a node's closed catalogue, incl. the none-of-these member, whose catalogue id is `none-of-these`; `classify` reports abstention as the outcome token `none_of_these`, which is never a catalogue id or a `hint_tree` key.

Source: `contracts/domain-glossary.md:45` (via arbiter-04-hint-fallback-reconciliation, Ruling 5 edit)
Binds this task: The `hint_tree` key is spelled `"none-of-these"` (kebab-case), not `none_of_these` (snake_case).

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/learning-objects.md — W2 — Serve a hint — generic tier-1 hint definition
> **Pre:** diagnosis holds a node id and a classified ErrorType; bundle loaded.
> **Steps:** 1. Resolve `(node, error_type) → tiers`; a miss raises `LO_HINT_NOT_FOUND` and the session falls back to the node's generic tier-1 hint, `hint_tree["none-of-these"][0]`, else the node's `paraphrase`; never another ErrorType's hint (I2).

Source: `docs/domains/learning-objects.md:92-93` (as amended by arbiter-04-hint-fallback-reconciliation, Ruling 5 Q-D edit)
Binds this task: The none-of-these entry's tier 1 is the "generic tier-1 hint"; it is the fallback when no error type resolves.

### docs/domains/learning-objects.md — HintTree — structure and voice
> **HintTree** — per node, ErrorType → ordered tiers: tier 1 nudges at what to look at, tier 2 targets that ErrorType, tier 3 works the failing step through. Answers are never withheld (D5, I3), so the tree gates nothing: it exposes the *reason* for the failure. Tier order and semantics are fixed at generation.

Source: `docs/domains/learning-objects.md:50-52`
Binds this task: Tier 1 nudges (what to look at); tier 2 targets (the specific error); tier 3 works through (the step). For `none-of-these`, tier 2 and 3 follow the same semantics but without naming a specific misconception.

### docs/domains/learning-objects.md — W1 — Hint coverage rule
> **Hint coverage** — every ErrorType but `none_of_these` has a full tier list, else `LO_HINT_TIER_MISSING`.

Source: `docs/domains/learning-objects.md:77` (as amended by arbiter-04-hint-fallback-reconciliation, Ruling 5 Q-D edit stating the `none-of-these` entry is optional in the coverage rule but present on `data/demo`)
Binds this task: After this task, every node carries `hint_tree["none-of-these"]` with a full (3-tier) list.

### docs/domains/diagnosis.md — (from arbiter-04-hint-fallback-reconciliation, Rule 3 and Ruling 5 Q-D edit)
From the arbiter ruling, the remediation and W3 definitions are amended to include "plus, when one resolves, one tier-1 hint". This defines that `hint_tree["none-of-these"][0]` is shown when the key is nil or when the outcome token is `none_of_these` (the abstention case).

Source: `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md:114-123` (cross-reference: `docs/domains/diagnosis.md` W1, W3, W4 amendments)
Binds this task: The none-of-these tier 1 is shown on diagnosis W1 step 3 and W3 step 4, and on expedition retry after a second miss (the `map_check_here` case).

## §D. Prior task outputs this task depends on

- `data/demo/nodes.json` — existed at task EPIC 01.5 (Demo bundle creation), 20 nodes, each with `error_types[]` (including a `none-of-these` member) and `hint_tree` object keyed only by real error types (not `none-of-these`). The Rendering-spike outcome counted 63 hint_tree tier strings pre-task.
- `App/Sources/DemoSnapshot/nodes.json` — byte-identical copy of `data/demo/nodes.json`, created by EPIC 03 task 03.4 (bundle-loader-snapshot-seam), guarded by a mandatory byte-identity test. Source: `tasks/epic-03-task-04-bundle-loader-snapshot-seam.md:68-71` (AC8: "each byte-identical to its `data/demo/` counterpart").
- `docs/epics/epic-01-rendering-spike-outcome.md` — count table with row "| `hint_tree` tier strings | 63 | 0 |" and total "| **Total** | **143** | **0** |". Source: `docs/epics/epic-01-rendering-spike-outcome.md:18, :20`.
- Test `Packages/Rendering/Tests/RenderingTests/OutcomeRecordAndImportBoundaryTests.swift:72-89` pinning the counts at 63/143. Source: `Packages/Rendering/Tests/RenderingTests/OutcomeRecordAndImportBoundaryTests.swift:102-104` (fabricated test data with 63/143).
- Test comment at `Packages/Rendering/Tests/RenderingTests/FieldKindPolicyMutationTests.swift:180` referencing "63/143". Source: `Packages/Rendering/Tests/RenderingTests/FieldKindPolicyMutationTests.swift:180`.

## §E. Negative facts (confirmed ABSENT)

- No `hint_tree["none-of-these"]` entry exists in any `data/demo/nodes.json` node today. Verified: Grep over entire file in this run found only real error-type ids as keys (e.g., `"sign-error"`, `"wrong-order"`; no `"none-of-these"` key). Source: raw file read of `data/demo/nodes.json` (lines 1–>end).
- No `EPIC 04 task 04.1b` spec has been written yet. The task is defined only in `docs/plans/epic-04-plan.md:24` (table row) and `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md:72-102` (Rule 4, the decomposition).
- No `App/Sources/DemoSnapshot/` directory exists yet at this run; it is created by EPIC 03 task 03.4 (not yet merged to main; current branch is epic-02b-door-a-core-merge). Verified: branch name recorded in system context.
- `data/demo/manifest.json` carries all-zero `sha256` placeholders (`"0000000000000000000000000000000000000000000000000000000000000000"`) on all six files. Verified by read of `data/demo/manifest.json:24, :29, :34, :39, :44, :49`.

## §F. File scope

Files this task may create or touch:

- MODIFY `data/demo/nodes.json:<line varies>` — add `"none-of-these": ["tier1", "tier2", "tier3"]` to the `hint_tree` object of each of the 20 nodes. Current shape: each node's `hint_tree` is an object with 1–2 real error-type keys (e.g., `{"sign-error":[…]}` or `{"base-exponent-swapped":[…], "multiplied-instead-of-power":[…]}`). Source: file read.
- MODIFY `App/Sources/DemoSnapshot/nodes.json:<line varies>` — (once 03.4 lands) apply byte-identical update to the embedded copy. Current shape: will exist as byte copy; guarded by AC8 test in 03.4.
- MODIFY `docs/epics/epic-01-rendering-spike-outcome.md:18, :20` — update row "| `hint_tree` tier strings | 63 | 0 |" to "| `hint_tree` tier strings | 123 | 0 |" and total "| **Total** | **143** | **0** |" to "| **Total** | **203** | **0** |" (arithmetic: 63 + 3×20 = 123; 143 + 60 = 203). Source: `arbiter-04-hint-fallback-reconciliation.md:99` ("recomputed by the task's scan, not typed from this line").
- MODIFY `Packages/Rendering/Tests/RenderingTests/OutcomeRecordAndImportBoundaryTests.swift:102, :104` — update the fabricated table in the negative-control test from `| `hint_tree` tier strings | 63 | 0 |` and `| **Total** | **143** | **0** |` to the new counts (123 and 203). Source: test structure and purpose in `OutcomeRecordAndImportBoundaryTests.swift:94-113`.
- MODIFY `Packages/Rendering/Tests/RenderingTests/FieldKindPolicyMutationTests.swift:180` — update comment from "63/143" to "123/203". Source: `FieldKindPolicyMutationTests.swift:180`.
- (CONDITIONAL) MODIFY `data/demo/manifest.json:24, :29, :34, :39, :44, :49` — if hashes are no longer placeholders (all zeros), run `pipeline/src/mathmath_pipeline/bundle.py` restamp helper (lines 24–38, per arbiter ruling). Current state: all are zero placeholders. Action: leave unchanged per arbiter ruling line 101 ("while they are placeholders, leave them").

## §G. Stack constraints relevant here

### Boundary validation — `nodes.schema.json` §hint_tree
- Input: node objects parsed from `data/demo/nodes.json`.
- Validation: `hint_tree` is an optional object; each key maps to an array of exactly 3 non-empty strings. The schema permits any key (additionalProperties open).
- Source: `contracts/schemas/nodes.schema.json:212-222`.

### Error codes (not applicable)
- No error code is raised by this task. Hints are not probe answers or step verifications (I1); no CAS check is needed. Validation failures are caught by schema decode and L0 checks run by later test instruments.
- Source: `contracts/content-policy.md:29-35` (hints not subject to CAS; only `numeric` ProbeItem.check re-derivation requires CAS).

### Instruments (verification)
1. **Schema decode and L0** — `core-cli validate data/demo` (called by pipeline tests; must pass after hints are added). Source: `tasks/epic-03-task-04-bundle-loader-snapshot-seam.md:92` (AC7 and §5's instrument list).
2. **`BundleRenderCheckTests` over `data/demo`** — zero unresolved entries. Hints are plain text, no LaTeX by design; no `render_fallback` flag exists on `hint_tree` entries (only on `probe_items`). Source: `arbiter-04-hint-fallback-reconciliation.md:88` (instrument list, 4th item: "BundleRenderCheckTests over data/demo, 0 unresolved").
3. **CoreTests data assertion 1** — for every node (count > 0, empty = FAIL):
   - `hint_tree["none-of-these"]` has 3 non-empty strings. Source: `arbiter-04-hint-fallback-reconciliation.md:89-90` (instrument detail).
   - Tier-1 string differs from every other key's tier-1 string on that node (negative control: planting a copy of a sibling's tier-1 fails). Source: `arbiter-04-hint-fallback-reconciliation.md:91`.
4. **CoreTests data assertion 2** — for every node, `hintKey(node, "none_of_these") == "none-of-these"` (2.11's T10, already covered by existing tests; no edit needed). Source: `arbiter-04-hint-fallback-reconciliation.md:92`.

### Tooling named in `docs/tech-stack.md`
- `core-cli` — exists (locked in Phase 5). Used for validation via pipeline test.
- `RenderCheck` — exists (Rendering package, locked in Phase 5).
- Swift test framework (locked). Source: `CLAUDE.md` (foundation language is Swift 6 / SwiftUI).
- No new tool is named or required by this task.

### No contract is silent
All sub-questions raised by this task are answered in contracts or arbiter ruling. No CONTRACTS SILENT entries.

## §H. Data inventory — the 20 nodes

Each node from `data/demo/nodes.json`, with id, name, existing error_types ids (in catalogue order), and existing `hint_tree` keys (in order as they appear):

| Node id | Name | Existing error_types ids (excl. none-of-these) | Existing hint_tree keys |
|---|---|---|---|
| integer-operations | Integer operations | `sign-error` | `sign-error` |
| order-of-operations | Order of operations | `wrong-order` | `wrong-order` |
| rational-numbers | Operations with rational numbers | `common-denominator-error` | `common-denominator-error` |
| exponent-laws | Exponent laws | `added-exponents-on-power` | `added-exponents-on-power` |
| scientific-notation | Scientific notation | `decimal-point-error` | `decimal-point-error` |
| linear-relations | Linear relations | `slope-intercept-swap` | `slope-intercept-swap` |
| solving-linear-equations | Solving linear equations | `sign-flip-error` | `sign-flip-error` |
| solving-systems-of-equations | Solving systems of linear equations | `substitution-error` | `substitution-error` |
| simplifying-expressions | Simplifying algebraic expressions | `unlike-terms-combined` | `unlike-terms-combined` |
| polynomials | Adding and subtracting polynomials | `like-terms-miscombined` | `like-terms-miscombined` |
| factoring | Factoring quadratic trinomials | `sign-error-in-factors` | `sign-error-in-factors` |
| solving-quadratics | Solving quadratic equations | `quadratic-formula-sign-error` | `quadratic-formula-sign-error` |
| rational-expressions | Simplifying rational expressions | `cancelled-terms-not-factors` | `cancelled-terms-not-factors` |
| quadratic-functions | Quadratic functions in vertex form | `vertex-sign-error` | `vertex-sign-error` |
| function-concept | Function concept and evaluation | `function-evaluation-error` | `function-evaluation-error` |
| function-transformations | Transformations of functions | `shift-direction-error` | `shift-direction-error` |
| function-notation | Function notation | `notation-misread` | `notation-misread` |
| domain-and-range | Domain of a function | `domain-range-swap` | `domain-range-swap` |
| exponential-functions | Exponential functions | `base-exponent-swapped`, `multiplied-instead-of-power` | `base-exponent-swapped`, `multiplied-instead-of-power` |
| logarithms | Logarithms | `log-exponent-confusion` | `log-exponent-confusion` |

Note: Every node carries exactly one `none-of-these` member in its `error_types[]` array (confirmed by schema and L0 rule W1 step 2). The task adds a `hint_tree["none-of-these"]` entry to each node's `hint_tree` object.

**Tier-1 distinctness requirement:** When the task's tier-1 strings are authored, each node's none-of-these tier 1 must not match any other error type's tier 1 on that same node. For nodes with multiple error types (only `exponential-functions` and `logarithms` have >1), this is a required check; for the rest, it is vacuously true.

Source: inventory from `data/demo/nodes.json` file read; entry count verified by node id enumeration (20 nodes as specified in DEMO-BRIEF §3.2 and arbiter ruling line 99).
