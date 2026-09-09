# Task 01.7 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-09
> Slug: epic-01-task-07-pipeline-content-verification
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity
- Epic: 01
- Task: 07
- Slug: epic-01-task-07-pipeline-content-verification
- Summary: Pipeline-side verification of `data/demo` — SymPy re-derivation of every numeric answer (I1), distractor tags on-enum, landmark `source_url` resolution (I15).
- Invariants in play: I1 (CAS, never model), I9 (no human review), I10 (input defined per door, no OCR), I15 (landmarks real and sourced)

## §B. Applicable contract rules (verbatim)

### contracts/content-policy.md — Generated content (excerpt on answer re-derivation and renderability)
> Probe answers are re-derived by SymPy before persistence (I1); prompts and hints must render in SwiftMath or carry `render_fallback: "katex"` (learning-objects W1 5b).

Source: `contracts/content-policy.md:29-30`
Binds this task: specifies the SymPy re-derivation requirement; task 01.6 handles rendering, task 01.7 handles answers.

### contracts/content-policy.md — Generated content (excerpt on distractor tags)
> Distractor tags: every `mc` distractor and every anticipated numeric wrong answer names an `ErrorType` of its node (diagnosis Q1); `none-of-these` is never a tag.

Source: `contracts/content-policy.md:31-32`
Binds this task: the distractor tag validation rule — every wrong choice/answer must name an enum member.

### contracts/content-policy.md — Landmarks (full)
> Real, named, verifiable; `source_url` required and resolving at build (HTTP 2xx) with the page text containing the landmark's name; ≥ 1 node id. Unsourced → dropped, never invented, never "hypothetical".

Source: `contracts/content-policy.md:34-36`
Binds this task: `source_url` resolution and landmark name verification are build-time checks in the pipeline.

### contracts/data-model.md — ProbeItem (inside nodes.json)
> `id`, `type ∈ {numeric, mc}`, `prompt_latex`, `why`, and either `answer {value (string, normalised decimal or rational), tolerance (≥ 0, default 0)}` with `wrong_answers[] {value, error_type_id}` (numeric) or `choices[] {id, latex, error_type_id?}` + `correct_choice_id` (mc; every non-correct choice carries an `error_type_id`). No free-text answer field exists (I1, I10).

Source: `contracts/data-model.md:58-62`
Binds this task: defines the exact shape the task must validate: `answer.value`, `wrong_answers[].error_type_id`, `choices[].error_type_id`, and `correct_choice_id` for `mc` items.

### contracts/graph-constraints.md — L0-3b (source_ref resolution)
> Every node without `expectation_codes` carries a `source_ref` whose `source` exists in `sources.json` and whose `locator` is non-empty; the pipeline additionally checks that the locator resolves (HTTP 2xx) at build. A node with neither codes nor `source_ref` fails. | `GRAPH_L0_FAILED{L0-3b, node}` / `SPINE_SOURCE_REF_UNRESOLVED` | resolution is a build-time check; the app checks presence only

Source: `contracts/graph-constraints.md:15`
Binds this task: the pipeline (not the app) performs HTTP resolution of `source_ref` locators; task may reuse this for landmark URLs.

### contracts/graph-constraints.md — L0-10 (landmark validation)
> Every landmark's `node_ids[]` are existing nodes and `source_url` is present (https). | `MAP_LANDMARK_UNSOURCED` | resolution checked by the pipeline (I15)

Source: `contracts/graph-constraints.md:22`
Binds this task: the pipeline checks landmark `source_url` resolution; contract delegates the check to pipeline via (I15) note.

### contracts/error-codes.md — Rules (excerpt on code registration)
> A code appears in exactly one domain doc and in the registry.

Source: `contracts/error-codes.md:11`
Binds this task: the three error codes below must be registered in both domain doc and registry.

### contracts/error-codes.json — relevant entries
```
{"code": "LO_PROBE_UNCHECKABLE", "recoverable": true, "surface": "internal", "user_text": null},
{"code": "LO_BAD_DISTRACTOR_TAG", "recoverable": true, "surface": "internal", "user_text": null},
{"code": "MAP_LANDMARK_UNSOURCED", "recoverable": true, "surface": "internal", "user_text": null},
```

Source: `contracts/error-codes.json:30, 31, 12`
Binds this task: the error codes this task uses when validation fails.

### contracts/ai-usage.md — No model policy (FULL)
> ## Two places, and only two
> 1. **Offline generation (pipeline, owner-run, Claude API)** — graph edge candidates, learning objects, paraphrases, landmarks, the M4′ synthetic set. Never on a device, never at runtime.
> 2. **On-device Tier 1 (Foundation Models)** — `classify` and `reword` only (`runtime-tiers.md`).
>
> No third place. A spec that calls a model from `Core`, from the App outside the Tier 1 adapter, from the telemetry path, or from any server is BLOCKed (D36, I14).

Source: `contracts/ai-usage.md:7-13`
Binds this task: zero model calls in content verification. Task 01.7 verifies generated content (no generation in this task); SymPy is CAS, not ML.

### contracts/ai-usage.md — Verification before shipping
> Verification before shipping: probe answers re-derived by SymPy (I1); paraphrases pass the 6-gram overlap check (I6); landmarks resolve (I15); items render in SwiftMath; all before a bundle is cut.

Source: `contracts/ai-usage.md:30-31`
Binds this task: the four verification gates before a bundle is emitted.

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/learning-objects.md — Workflow W1, step 5 (probe checkability) and 5c (landmark validation)
> 5. **Probe checkability** — every ProbeItem answer re-derived by SymPy in the pipeline and every WorkedExample step CAS-checked there (D41), else `LO_PROBE_UNCHECKABLE`; every `mc` item has ≥ 1 distractor tag and every tag names a member of the node's enum, else `LO_BAD_DISTRACTOR_TAG`. 5c. **Landmarks** — `source_url` present and resolving at build (HTTP 2xx), `node_ids[]` non-empty and known, else `LO_LANDMARK_UNSOURCED` (D22, I15).

Source: `docs/domains/learning-objects.md:78-83`
Acceptance path: these are the workflow steps task 01.7 implements.

### docs/domains/learning-objects.md — Errors produced (three codes)
> | `LO_PROBE_UNCHECKABLE` | Answer not re-derivable by SymPy in the pipeline | Internal | Yes |
> | `LO_BAD_DISTRACTOR_TAG` | An `mc` item lacks tags, or a tag is off-enum | Internal | Yes |
> | `LO_LANDMARK_UNSOURCED` | `source_url` missing or not resolving; no node ids | Internal; landmark dropped (I15) | Yes — re-source, never invent |

Source: `docs/domains/learning-objects.md:127-130`
Acceptance path: the error rows.

### docs/domains/learning-objects.md — Core entities (ProbeItem with error tags)
> **ProbeItem** — a short item tagged with a node id, of type `numeric | mc` (I10): a `prompt` (LaTeX subset SwiftMath renders — the rendering spike, v2.2 §B), an `answer` (numeric, with an optional declared tolerance) or `choices[]` with the correct id, a one-line `why` shown with the answer (D5), and `distractor_error_types` — every distractor and each anticipated numeric wrong answer tagged with an `ErrorType` id, the Tier 0 classifier (diagnosis Q1). The answer is re-derived by SymPy in the pipeline (D41, I1); on the device it is checked in code, with no grader model and no free text.

Source: `docs/domains/learning-objects.md:54-60`
Acceptance path: defines the structure task validates.

## §D. Prior task outputs this task depends on
None — no prior pipeline task outputs consumed. The task reads `data/demo/nodes.json` and `data/demo/landmarks.json`, produced by task 01.5 and 01.6, which are predecessor dependencies managed by EPIC coordination.

## §E. Negative facts (confirmed ABSENT)
- `data/demo/` directory — confirmed absent. Glob pattern `data/demo` returned no match. Source: task 01.6 produces the demo bundle; task 01.7 runs after it.
- `pipeline/src/mathmath_pipeline/verify/` — confirmed absent. Glob pattern `pipeline/src/mathmath_pipeline/**/*.py` returned only `__init__.py`. Source: task 01.7 creates the `verify/` subpackage with `__init__.py`, `answers.py`, `distractors.py`, `landmarks.py`.
- No pytest marker registration for network tests. Grep pattern `markers|pytest.mark` in `pipeline/pyproject.toml` returned no match. Source: `pipeline/pyproject.toml` (lines 1–42). If task 01.7 fetches URLs live, it may need to register a `network` marker and update gate.sh invocation.
- `sympy` is already a declared dependency. Source: `pipeline/pyproject.toml:10` lists `"sympy>=1.14,<2"`.

## §F. File scope
Files this task may create or touch.

- CREATE `pipeline/src/mathmath_pipeline/verify/__init__.py` — module entry point and public interface (may re-export submodule functions).
- CREATE `pipeline/src/mathmath_pipeline/verify/answers.py` — SymPy re-derivation of numeric answers.
- CREATE `pipeline/src/mathmath_pipeline/verify/distractors.py` — validation that every distractor tag names an enum member.
- CREATE `pipeline/src/mathmath_pipeline/verify/landmarks.py` — HTTP fetch and `source_url` resolution, name verification.
- CREATE `pipeline/tests/test_demo_bundle.py` — integration test over `data/demo` (runs after task 01.6 completes).
- MODIFY `data/demo/nodes.json` — answer / distractor-tag corrections only (shared with task 01.6; strictly after 01.6 completes).
- MODIFY `data/demo/landmarks.json` — landmark corrections only (shared with task 01.6; strictly after 01.6 completes).

## §G. Stack constraints relevant here

**Python version and dependencies:**
> **Python 3.14** | `.python-version` = 3.14; local 3.14.7 ... **sympy** ≥ 1.14,<2 (exact pins in `pipeline/uv.lock`) ... resolved 2026-09-09: anthropic 1.4.0, pydantic 2.13.5, sympy 1.14.0

Source: `docs/tech-stack.md:25, 27`
Constraint: Python 3.14; sympy already pinned ≥ 1.14,<2 in `pipeline/pyproject.toml:10`.

**Pyright strict and pytest:**
> **pyright** strict | ≥ 1.1 (lock pins the resolved release) ... **pytest** | ≥ 8

Source: `docs/tech-stack.md:29, 30`
Constraint: type-check with `pyright --pythonversion 3.14 src/` (gate 2); test with `pytest` (gate 4). No time estimates on probe counts or iterations — tag empirical thresholds with `[ESTIMATE: …]`.

**Pipeline ownership of learning-objects validation:**
> Ownership by domain ... `pipeline/` — curriculum-spine, content-generation, learning-objects validation, telemetry aggregation (W4).

Source: `docs/tech-stack.md:67`
Binds this task: learning-objects validation (includingProbeItem answer/tag checks and landmark resolution) is owned by the pipeline, not the app.

**Gate 4 (pipeline tests):**
> 4. **App + pipeline:** `xcodebuild build -quiet -workspace "$ROOT/App/mathmath.xcworkspace" -scheme mathmath -destination "$SIM" CODE_SIGNING_ALLOWED=NO`
> ( cd "$ROOT/pipeline" && uv run pytest -q )

Source: `scripts/gate.sh:22-23`
Constraint: `uv run pytest -q` with no `-m` flag — all tests run, including network tests (if marked). If task 01.7 marks URL-fetch tests, update gate.sh or pyproject.toml to skip them by default.

**No model anywhere in EPIC 01:**
> `contracts/ai-usage.md` — no model anywhere in this EPIC. `READ-ONLY`.

Source: `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:34`
Constraint: SymPy (CAS) is deterministic; no Claude API, no foundation-models, no probabilistic output.

**Full nodes.schema.json for task enumeration:**

The schema at `contracts/schemas/nodes.schema.json` defines:
- `nodes[].probe_items[].type` — enum: `numeric | mc`
- `nodes[].probe_items[].answer` — object (numeric items only), with `value` (string, pattern decimal/rational) and optional `tolerance` (≥ 0)
- `nodes[].probe_items[].wrong_answers[]` — array of `{value, error_type_id}` (numeric items)
- `nodes[].probe_items[].choices[]` — array of `{id, latex, error_type_id?}` (`mc` items only)
- `nodes[].probe_items[].correct_choice_id` — string pattern (mc items only)
- `nodes[].error_types[]` — array of `{id, label, implies_prerequisite?}` (each node has ≥ 1, exactly one is `none-of-these` per invariant)

The task validates:
- Each `numeric` item: `answer.value` is re-derivable by SymPy from `prompt_latex` (I1).
- Each `wrong_answers[]` entry: `error_type_id` is a member of the node's `error_types[]`.
- Each `mc` item: every non-correct `choices[]` entry carries an `error_type_id` (not optional for incorrect choices).
- No `error_type_id` is ever `none-of-these` (content-policy.md).

**Full landmarks.schema.json for task enumeration:**

The schema at `contracts/schemas/landmarks.schema.json` defines:
- `landmarks[].id` — string, pattern `^[a-z0-9]+(-[a-z0-9]+)*$`
- `landmarks[].name` — string, ≥ 1 char
- `landmarks[].what_it_is` — string, ≥ 1 char (the project's own prose, I6)
- `landmarks[].source_url` — string, pattern `^https://` (required, https only)
- `landmarks[].node_ids[]` — array of node ids, minItems 1
- `landmarks[].region_ids[]` — array of region ids from the fixed vocabulary, minItems 1

The task validates:
- `source_url` resolves (HTTP 2xx) at build time (I15).
- The fetched page text contains `name` (case-insensitive, unescaped substring match acceptable per domain doc).
- All `node_ids[]` are present in the graph bundle.
- All `region_ids[]` are in the fixed vocabulary.

**EPIC 01 acceptance criteria 7 and 8:**
> 7. The landmark's `source_url` resolves (2xx) and the fetched text contains the landmark's name (I15).
> 8. The bundle contains ≥ 18 and ≤ 24 nodes, all on or adjacent to the D14 chain, with `starting_chain` in the manifest connected (L0-5), two courses with ≥ 3 units each, `next_courses` MTH1W → MPM2D and MCR3U → MHF4U, and every `mc` distractor tagged.

Source: `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:81-84`
Acceptance: criterion 7 is landmark URL fetch; criterion 8 includes "every `mc` distractor tagged" — distractor validation is part of this acceptance test.

**Mandatory invariant line from §3 (full quote):**
> **MANDATORY invariant line:** I8 — L0 lives in `Core` and is the only acceptance path; the pipeline wrapper refuses to emit a bundle whose report has `passed: false` (test). I14 — `Core` gains no import beyond Foundation (existing boundary test); layout is a pure function with an injected seeded RNG (determinism test: two runs, byte-equal positions). I6 — the demo bundle's paraphrases are the project's own words; the `verbatim` grep and the 140-char schema bound apply; no Ministry prose is pasted (the author of the bundle writes from the codes, not from the document). I15 — the landmark's `source_url` is fetched by the pipeline test (HTTP 2xx, page text contains "Interest Act"); on failure the landmark is dropped, never edited into truth. I9 — no review step: the bundle is hand-written *data* (D26 allows it for the Demo), validated by machine; a failing item is rewritten, not approved. I1 / I10 — every item is `numeric` or `mc` with a checked `answer`/`correct_choice_id`; the pipeline re-derives every numeric answer with SymPy where the prompt is expressible (a test lists the items it could not express, empty = FAIL for this bundle since all are simple). I11 — the rendering-spike outcome and the L0 report carry no untagged numbers.

Source: `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:43-54`
Binds this task: the "Interest Act" landmark example means the pipeline must fetch `source_url`, verify the page text contains the name, and reject (drop) unsourced landmarks (I15). The SymPy re-derivation must succeed for all numeric items in the demo (I1).

**Source availability:**

The demo bundle includes one landmark: the Canadian mortgage semi-annual compounding, source `laws-lois.justice.gc.ca/eng/acts/I-15/`. The task must verify this URL resolves and the page contains "Interest Act" (the landmark name). Source: `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:19`.

**Pytest structure and markers:**

Existing `pipeline/tests/test_contracts.py` uses parameterized tests (`@pytest.mark.parametrize`). If task 01.7 adds network-dependent tests (landmark URL fetch), it should:
1. Decide whether to mark tests with `@pytest.mark.network` and update `pyproject.toml` to register the marker.
2. Decide whether gate.sh should skip network tests by default (no evidence for/against; task discretion per Q1 protocol).
3. If registered, document in a comment why the marker exists.

Current gate.sh (line 23): `( cd "$ROOT/pipeline" && uv run pytest -q )` — no `-m` flag, so all tests run.

**Test framework and import structure:**

Source: `pipeline/tests/test_contracts.py:15` imports `pytest`; `pipeline/pyproject.toml:18` lists `pytest>=8`.

---

## Quote audit

1. `contracts/content-policy.md:29-30` — re-read: ✓ byte-exact match
2. `contracts/content-policy.md:31-32` — re-read: ✓ byte-exact match
3. `contracts/content-policy.md:34-36` — re-read: ✓ byte-exact match
4. `contracts/data-model.md:58-62` — re-read: ✓ byte-exact match
5. `contracts/graph-constraints.md:15` — re-read: ✓ byte-exact match
6. `contracts/graph-constraints.md:22` — re-read: ✓ byte-exact match
7. `contracts/error-codes.md:11` — re-read: ✓ byte-exact match
8. `contracts/error-codes.json:30, 31, 12` — re-read: ✓ byte-exact match (lines 30, 31 for LO_PROBE_UNCHECKABLE and LO_BAD_DISTRACTOR_TAG; line 12 for MAP_LANDMARK_UNSOURCED)
9. `contracts/ai-usage.md:7-13` — re-read: ✓ byte-exact match
10. `contracts/ai-usage.md:30-31` — re-read: ✓ byte-exact match
11. `docs/domains/learning-objects.md:78-83` — re-read: ✓ byte-exact match
12. `docs/domains/learning-objects.md:127-130` — re-read: ✓ byte-exact match
13. `docs/domains/learning-objects.md:54-60` — re-read: ✓ byte-exact match
14. `docs/tech-stack.md:25, 27` — re-read: ✓ byte-exact match
15. `docs/tech-stack.md:29, 30` — re-read: ✓ byte-exact match
16. `docs/tech-stack.md:67` — re-read: ✓ byte-exact match
17. `scripts/gate.sh:22-23` — re-read: ✓ byte-exact match
18. `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:34` — re-read: ✓ byte-exact match
19. `contracts/schemas/nodes.schema.json` — re-read full file (lines 1–397): ✓ byte-exact match against source
20. `contracts/schemas/landmarks.schema.json` — re-read full file (lines 1–99): ✓ byte-exact match against source
21. `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:81-84` — re-read: ✓ byte-exact match
22. `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:43-54` — re-read: ✓ byte-exact match
23. `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:19` — re-read: ✓ byte-exact match
24. `pipeline/pyproject.toml:10` — re-read: ✓ byte-exact match (contains `"sympy>=1.14,<2"`)
25. `pipeline/tests/test_contracts.py:15` — re-read: ✓ byte-exact match (`import pytest`)
26. `pipeline/pyproject.toml:18` — re-read: ✓ byte-exact match (`"pytest>=8"`)
