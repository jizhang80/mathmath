# Task 01.7 context bundle (REFRESHED 2026-09-09)

> Compiler: task-context-compiler  
> Date: 2026-09-09  
> Slug: pipeline-content-verification  
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- Epic: 01
- Task: 07
- Slug: pipeline-content-verification
- Summary: Implement three pipeline verification checks: (a) every `numeric` ProbeItem's declared answer is re-derived by SymPy from its `check` field alone, (b) every `mc` distractor and every `wrong_answers[]` entry names an `error_type_id` from its node's own `error_types[]` and is never `"none-of-these"`, (c) the landmark's `source_url` resolves (HTTP 2xx) and its page contains the landmark's `source_title` (not its `name`).
- Invariants in play: I1 (correctness decided by CAS, never model, never prompt parsing), I9 (zero human review; machine-verified), I10 (only `numeric`/`mc` ProbeItems), I15 (landmarks real, verifiable; unresolvable dropped, never edited).

## §B. Applicable contract rules (verbatim)

### contracts/data-model.md — ProbeItem's `check` field (v1.1.0, added by task 01.6.1)

> Every `numeric` item additionally carries **`check`** — the machine-readable declaration the CAS re-derives the answer from (I1). An `mc` item never carries `check`: its correctness is `correct_choice_id` plus the on-enum distractor rule (`content-policy.md` § Generated content). Extending `check` to `mc` items is a further versioned change.
>
> `check` is `{ kind ∈ {evaluate, solve} }` plus, by kind:
> - **`evaluate`** — `expr` (required): one SymPy-source expression; `at` (optional): a map from symbol name to a numeric string, substituted before evaluation. `equations`, `unknown`, `select` are absent.
> - **`solve`** — `equations[]` (required): one or more `Eq(lhs, rhs)` in SymPy source; `unknown` (required): the symbol whose value is the answer; `select ∈ {only, max, min}` (optional, default `only`): which solution is the answer when a well-posed problem has more than one. `expr` and `at` are absent.
>
> `expr` and `equations[]` hold **SymPy source, never LaTeX** (§ Text is unaffected); they are never rendered and never shown to a student. `expr` may not be a bare numeric literal — a check that restates `answer.value` proves nothing, and the schema rejects it. `answer.value` is the claim, `check` is the derivation, and the two are compared, never merged: a disagreement is a build failure, never a correction of one from the other.

Source: `contracts/data-model.md:318-335` (v1.1.0, added by task 01.6.1)  
Binds this task: AC2 derives the answer from the item's `check` field exactly as specified; derives it from `check` alone, never from `prompt_latex`.

### contracts/data-model.md — Probe answer derivation (normative, v1.1.0, added by task 01.6.1)

> The pipeline derives every `numeric` answer from `check` alone. **`prompt_latex` is never parsed** — it is a presentation string that may embed an English question, and a parser that mis-reads it does not fail, it silently confirms whatever answer was authored. No model participates at any point (I1).
>
> Parsing is `sympy.parse_expr` with `standard_transformations + (rationalize,)` — so decimal literals become exact `Rational`s — and a **closed name allow-list**: `Eq`, `Rational`, `sqrt`, `log`, `exp`, `Abs`, `diff`, `pi`, `E`. Any other name parses to a free symbol; calling one raises, and the item fails. Extending the allow-list is a versioned change.
>
> - `evaluate`: parse `expr`; every key of `at` must be a free symbol of `expr`; substitute; the result must have no free symbols left.
> - `solve`: parse each equation; `unknown` must be a free symbol of the set; call `sympy.solve(equations, sorted(free_symbols), dict=True)`; keep the solutions that bind `unknown`; `select: only` requires exactly one distinct bound value, `max`/`min` take the extreme of them.
>
> The derived value must be an exact rational after `sympy.simplify` (`.is_Rational` true). A parse failure, an unknown name, a leftover free symbol, an unbound `unknown`, zero solutions, more than one solution under `select: only`, or a non-rational result is `LO_PROBE_UNCHECKABLE` and **fails the build**. Nothing is rounded, nothing is approximated, nothing is inferred. The derived value is then compared to `answer.value` within `answer.tolerance` (default `0`); a mismatch fails the build.

Source: `contracts/data-model.md:340-360` (v1.1.0, added by task 01.6.1)  
Binds this task: this is the normative algorithm AC2 must implement exactly; no shortcuts, no second paths, no numeric fallback.

### contracts/content-policy.md — Generated content answer re-derivation (v1.1.0, amended by task 01.6.1)

> Probe answers are re-derived by SymPy before persistence (I1): every `numeric` ProbeItem carries `check` and the CAS derives the answer from `check` alone — never by parsing `prompt_latex`, never by a model (`data-model.md` § ProbeItem, § Probe answer derivation). An item the CAS cannot derive exactly, or whose derived value differs from `answer.value` beyond `tolerance`, is `LO_PROBE_UNCHECKABLE` and fails the build; nothing ships unchecked. `mc` correctness is `correct_choice_id` plus the distractor rule below; extending `check` to `mc` is a further versioned change. Prompts and hints must render in SwiftMath or carry `render_fallback: "katex"` (learning-objects W1 5b).

Source: `contracts/content-policy.md:376-383` (v1.1.0, amended by task 01.6.1)  
Binds this task: AC2 (answers re-derived from `check`), AC3 (mismatch fails).

### contracts/content-policy.md — Distractor tags (v1.1.0)

> Distractor tags: every `mc` distractor and every anticipated numeric wrong answer names an `ErrorType` of its node (diagnosis Q1); `none-of-these` is never a tag.

Source: `contracts/content-policy.md:381` (v1.1.0, General content section)  
Binds this task: AC4 validates every distractor `error_type_id` is on-enum.

### contracts/content-policy.md — Landmarks (v1.1.0, amended by task 01.6.1)

> Real, named, verifiable; `source_url` required and resolving at build (HTTP 2xx); `source_title` required — the title of the real, named thing the landmark cites, as that title appears on the source page — and the fetched page text must contain it (case-insensitive substring). The landmark's `name` is the project's own descriptive claim about the mathematics and is by design not a term from the source, so it is never asserted against the page; a landmark's `name` is never edited to make a check pass. ≥ 1 node id. Unsourced → dropped, never invented, never "hypothetical".

Source: `contracts/content-policy.md:389-394` (v1.1.0, amended by task 01.6.1)  
Binds this task: AC5 fetches the `source_url`, asserts the page contains the landmark's `source_title` (case-insensitive substring, never its `name`); on failure, raises `LO_LANDMARK_UNSOURCED` and the landmark is dropped (I15).

### contracts/graph-constraints.md — L0-3b source_ref resolver

> Every node without `expectation_codes` carries a `source_ref` whose `source` exists in `sources.json` and whose `locator` is non-empty; the pipeline additionally checks that the locator resolves (HTTP 2xx) at build. A node with neither codes nor `source_ref` fails. | `GRAPH_L0_FAILED{L0-3b, node}` / `SPINE_SOURCE_REF_UNRESOLVED` | resolution is a build-time check; the app checks presence only

Source: `contracts/graph-constraints.md:15` (quoted in task spec 01.7 §3)  
Binds this task: AC7 scans for `source_ref` entries; for `data/demo`, zero found (all nodes carry `expectation_codes`); test asserts and prints "0 source_refs scanned — vacuous by bundle scope".

### contracts/error-codes.md — Rules on code registration

> A code appears in exactly one domain doc and in the registry.

Source: `contracts/error-codes.md:11`  
Binds this task: the three error codes this task uses must be registered in both domain docs and registry; `LO_LANDMARK_UNSOURCED` is in `docs/domains/learning-objects.md` (not `MAP_LANDMARK_UNSOURCED` from `docs/domains/map.md`, which is Core's L0-10).

### contracts/error-codes.json — Error codes this task uses

```json
{"code": "LO_PROBE_UNCHECKABLE", "recoverable": true, "surface": "internal", "user_text": null},
{"code": "LO_BAD_DISTRACTOR_TAG", "recoverable": true, "surface": "internal", "user_text": null},
{"code": "LO_LANDMARK_UNSOURCED", "recoverable": true, "surface": "internal", "user_text": null},
```

Source: `contracts/error-codes.json` (verified present)  
Binds this task: these three codes are raised by this task's checks. Note: `MAP_LANDMARK_UNSOURCED` (Core's presence check) is NOT used here; `LO_LANDMARK_UNSOURCED` (pipeline's resolution check) is.

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/learning-objects.md — Probe checkability and landmarks (W1, step 5/5c)

> 5. **Probe checkability** — every ProbeItem answer re-derived by SymPy in the pipeline and every WorkedExample step CAS-checked there (D41), else `LO_PROBE_UNCHECKABLE`; every `mc` item has ≥ 1 distractor tag and every tag names a member of the node's enum, else `LO_BAD_DISTRACTOR_TAG`. 5c. **Landmarks** — `source_url` present and resolving at build (HTTP 2xx), `node_ids[]` non-empty and known, else `LO_LANDMARK_UNSOURCED` (D22, I15).

Source: `docs/domains/learning-objects.md:240-245`  
Binds this task: this is what this task implements — the three machine checks and the error codes.

### docs/domains/learning-objects.md — Landmark error code (Errors produced)

> | `LO_LANDMARK_UNSOURCED` | `source_url` missing or not resolving; no node ids | Internal; landmark dropped (I15) | Yes — re-source, never invent |

Source: `docs/domains/learning-objects.md:233` (the resolution-check code, not the presence-check code)  
Binds this task: this task raises `LO_LANDMARK_UNSOURCED` for resolution failures; it is the pipeline's code (live HTTP fetch), not Core's `MAP_LANDMARK_UNSOURCED` (presence check).

## §D. Prior task outputs this task depends on

- `ProbeCheck` type with `kind: ProbeCheckKind`, `expr`, `at`, `equations`, `unknown`, `select` fields — source: `Packages/Core/Sources/Core/Model/Nodes.swift` (added by task 01.6.1)
- `ProbeCheckKind` enum with cases `evaluate`, `solve` — source: `Packages/Core/Sources/Core/Model/Nodes.swift` (added by task 01.6.1)
- `ProbeCheckSelect` enum with cases `only`, `max`, `min` — source: `Packages/Core/Sources/Core/Model/Nodes.swift` (added by task 01.6.1)
- `ProbeItem.check: ProbeCheck?` field — source: `Packages/Core/Sources/Core/Model/Nodes.swift:54-64` (added by task 01.6.1)
- `Landmark.sourceTitle: String` field — source: `Packages/Core/Sources/Core/Model/Landmarks.swift:11-19` (added by task 01.6.1)
- Contracts v1.1.0 (data-model, content-policy, nodes.schema.json, landmarks.schema.json) — all amended by task 01.6.1
- `data/demo/nodes.json` with `check` objects on all 20 `numeric` probe items — source: the file (populated by task 01.6.1)
- `data/demo/landmarks.json` with `source_title: "Interest Act"` on the landmark — source: the file (populated by task 01.6.1)

## §E. Negative facts (confirmed ABSENT)

- No `pipeline/src/mathmath_pipeline/verify/` subpackage exists. Glob `pipeline/src/mathmath_pipeline/verify/**` returns empty.
- No `pipeline/tests/test_demo_bundle.py` exists. Glob `pipeline/tests/test_demo_bundle.py` returns empty (file created by this task).
- The `network` pytest marker is not registered in `pipeline/pyproject.toml`. Grep `markers` in the file returns empty (if task adds network tests, must register the marker).
- No L1/L2 (model-based) verification code in the pipeline yet (later EPICs only).

## §F. File scope

Files this task may create or touch.

- CREATE `pipeline/src/mathmath_pipeline/verify/__init__.py` — module re-exports; confirmed absent.
- CREATE `pipeline/src/mathmath_pipeline/verify/answers.py` — SymPy re-derivation from `check` field; confirmed absent.
- CREATE `pipeline/src/mathmath_pipeline/verify/distractors.py` — on-enum tag validation; confirmed absent.
- CREATE `pipeline/src/mathmath_pipeline/verify/landmarks.py` — HTTP resolution + L0-3b scan; confirmed absent.
- CREATE `pipeline/tests/test_demo_bundle.py` — companion test over `data/demo`; confirmed absent (per spec §2: "reserved for this task").
- MODIFY `pipeline/pyproject.toml` — add `markers` stanza to `[tool.pytest.ini_options]` if network tests marked; confirmed present.
- MODIFY `data/demo/nodes.json` — answer/distractor corrections only (where this task's checks find violations); confirmed present.
- (OUT-OF-SCOPE) `data/demo/landmarks.json` — this task may NOT touch this file; out-of-scope per spec §2.

## §G. Stack constraints relevant here

- **Boundary validation**: `pipeline/tests/test_contracts.py` validates all Python code against schemas (Source: `contracts/data-model.md:75-79`). Every check must raise one of the three registered error codes.
- **Storage / asset access**: This task writes no new bundle files; it corrects only `answer.value` and `error_type_id` fields in `data/demo/nodes.json` where its checks find violations (Source: spec 01.7 §4 step 8).
- **Error codes to use**: `LO_PROBE_UNCHECKABLE`, `LO_BAD_DISTRACTOR_TAG`, `LO_LANDMARK_UNSOURCED` (registered). NOT `MAP_LANDMARK_UNSOURCED` (Core's presence check, not pipeline's).
- **Model-calling paths**: ZERO. No `anthropic` import anywhere. Correctness by SymPy (CAS), set membership (tags), HTTP status (landmarks). No threshold, no fallback.
- **Tooling**: Python 3.14, uv, pytest, pyright strict, sympy ≥ 1.14, standard library `urllib` for HTTP (Source: `docs/tech-stack.md:25-27`).
- **HTTP in tests**: Tests making live HTTPS requests are marked `@pytest.mark.network` (register in `pyproject.toml`). Gate 4 runs `uv run pytest -q` with no `-m` flag; network tests execute unfiltered (Source: spec 01.7 §3 planner note [6]).

---

# Normative algorithm: Probe answer derivation (verbatim from contracts/data-model.md v1.1.0)

This is the exact algorithm AC2 must implement. Do not deviate. Source: `contracts/data-model.md:340-360` (added by task 01.6.1, v1.1.0).

> The pipeline derives every `numeric` answer from `check` alone. **`prompt_latex` is never parsed** — it is a presentation string that may embed an English question, and a parser that mis-reads it does not fail, it silently confirms whatever answer was authored. No model participates at any point (I1).
>
> Parsing is `sympy.parse_expr` with `standard_transformations + (rationalize,)` — so decimal literals become exact `Rational`s — and a **closed name allow-list**: `Eq`, `Rational`, `sqrt`, `log`, `exp`, `Abs`, `diff`, `pi`, `E`. Any other name parses to a free symbol; calling one raises, and the item fails. Extending the allow-list is a versioned change.
>
> - `evaluate`: parse `expr`; every key of `at` must be a free symbol of `expr`; substitute; the result must have no free symbols left.
> - `solve`: parse each equation; `unknown` must be a free symbol of the set; call `sympy.solve(equations, sorted(free_symbols), dict=True)`; keep the solutions that bind `unknown`; `select: only` requires exactly one distinct bound value, `max`/`min` take the extreme of them.
>
> The derived value must be an exact rational after `sympy.simplify` (`.is_Rational` true). A parse failure, an unknown name, a leftover free symbol, an unbound `unknown`, zero solutions, more than one solution under `select: only`, or a non-rational result is `LO_PROBE_UNCHECKABLE` and **fails the build**. Nothing is rounded, nothing is approximated, nothing is inferred. The derived value is then compared to `answer.value` within `answer.tolerance` (default `0`); a mismatch fails the build.

## Repo state facts at 2026-09-09

- Current contracts versions: `data-model.md` v1.1.0 (set by task 01.6.1), `content-policy.md` v1.1.0 (set by task 01.6.1)
- `data/demo/nodes.json` contains exactly 20 `numeric` ProbeItems, each carrying a `check` field (populated by task 01.6.1)
- `data/demo/landmarks.json` contains one landmark with `source_title: "Interest Act"` (populated by task 01.6.1)
- `sympy` version pinned in `pipeline/uv.lock`: 1.14.0 (Source: `docs/tech-stack.md:27`, resolved 2026-09-09)
- HTTP library: Python standard library `urllib.request` (no third-party client pinned)
- Test runner: pytest ≥ 8 via `uv run pytest -q`
- Swift 6 / iOS 18 simulator for gate 4 (Core tests alongside pipeline tests)
