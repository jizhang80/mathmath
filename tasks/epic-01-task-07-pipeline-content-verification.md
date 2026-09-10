# Epic 01 · Task 07: Pipeline content verification (SymPy re-derivation, distractor tags, landmark sourcing)

---
epic: 01
task: 07
slug: pipeline-content-verification
kind: test
risk: seam
depends_on: [01.5, 01.6]
model: sonnet
---

## §1 Goal & acceptance criteria

Goal: give the pipeline a `verify/` subpackage that machine-checks three properties of `data/demo` at
build time — (a) every `numeric` ProbeItem's declared answer is re-derived by SymPy (never a model) from
its prompt, (b) every `mc` distractor and every `wrong_answers[]` entry names an `error_type_id` that is a
member of its own node's `error_types[]` and is never `"none-of-these"`, and (c) the one landmark's
`source_url` actually resolves (HTTP 2xx) and its page contains both the landmark's own `name` and the
literal string `"Interest Act"` — and ship the companion test that proves all three over the real
`data/demo` bundle, plus the deferred L0-3b `source_ref` resolver scan.

Invariants in play:

- **I1** — correctness of every numeric probe answer is decided by re-deriving it with SymPy (a CAS), never
  by asking a model or trusting the hand-authored value; a mismatch is a build-time failure, not a warning.
- **I9** — zero human review step: a failing item's answer or tag is corrected in `nodes.json` and
  re-verified by the same machine check, never "approved as-is".
- **I10** — this task only ever inspects `numeric`/`mc` ProbeItems; it asserts no other item shape exists.
- **I15** — the landmark is dropped (in principle; this task proves the check, task authorship of the drop
  is out of this task's file scope) rather than trusted unresolved: `source_url` resolution is a live HTTP
  fetch, and the failure path is proven to exist against a real broken URL, never mocked or skipped.

Acceptance criteria (each independently verifiable):

- AC1: no `anthropic` import token appears anywhere in `pipeline/src/mathmath_pipeline/verify/*.py` —
  asserted by a test that scans the three new source files (`contracts/ai-usage.md` heading `## Two
  places, and only two`: "No third place. A spec that calls a model from `Core`, from the App outside the
  Tier 1 adapter, from the telemetry path, or from any server is BLOCKed").
- AC2: every `numeric` ProbeItem in `data/demo/nodes.json` is re-derived by `answers.py`'s SymPy
  translator; the list of items it could not express is printed and asserted **empty** — a non-empty list
  FAILS the test (EPIC brief mandatory invariant line, quoted in §3).
- AC3: every re-derived value equals the item's declared `answer.value` within its `tolerance` (default
  `0`); any mismatch is printed by node id and item id and FAILS the test.
- AC4: every `mc` item's non-correct `choices[]` entries and every `wrong_answers[]` entry carries an
  `error_type_id` drawn from its **own node's** `error_types[].id` list (never a hardcoded enum) and is
  never the literal `"none-of-these"`; a violation FAILS with the item id named in the assertion message.
- AC5: the landmark's `source_url` (`https://laws-lois.justice.gc.ca/eng/acts/I-15/`) resolves with HTTP
  2xx and the fetched page text contains, case-insensitively, both the landmark's own `name` field value
  and the literal substring `"Interest Act"`.
- AC6: the landmark-resolution failure path is proven live — a deliberately broken fixture URL derived
  from the real `source_url` (same host, a path guaranteed to 404) is fetched for real and asserted to
  raise the resolution-failure exception; no mock stands in for this assertion.
- AC7: the L0-3b `source_ref` resolver scans `data/demo/nodes.json` and explicitly asserts/prints
  `"0 source_refs scanned — vacuous by bundle scope"` (C3) rather than silently passing an empty scan.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `pipeline/src/mathmath_pipeline/verify/__init__.py` — CREATE. Re-exports the public functions of the
  three submodules below; no logic of its own beyond re-export.
- `pipeline/src/mathmath_pipeline/verify/answers.py` — CREATE. SymPy re-derivation of `numeric` ProbeItem
  answers from `prompt_latex` (§4 step 2).
- `pipeline/src/mathmath_pipeline/verify/distractors.py` — CREATE. On-enum distractor-tag validation
  (§4 step 3).
- `pipeline/src/mathmath_pipeline/verify/landmarks.py` — CREATE. Live `source_url`/`source_ref` HTTP
  resolution (§4 step 4).
- `pipeline/tests/test_demo_bundle.py` — CREATE. The companion test over `data/demo` (§5). This exact path
  is reserved for this task (`tasks/epic-01-task-05-demo-bundle.md` out-of-scope list: "`pipeline/tests/
  test_demo_bundle.py` — reserved for task 01.7"; task 01.5 ships `test_demo_bundle_shape.py` instead,
  confirmed present at `pipeline/tests/test_demo_bundle_shape.py`).
- `data/demo/nodes.json` — MODIFY. **Answer or distractor-tag corrections only** — this file is shared:
  01.5 authored it, 01.6 amended notation/`render_fallback`, this task amends only `answer.value` values
  and `error_type_id` tags that this task's own checks find wrong. Never touch `id`, `paraphrase`,
  `region_id`, `courses`, `position`, `prompt_latex`, `hint_tree`, `expectation_codes`, or the node set
  itself — those belong to 01.5/01.6.
- `pipeline/pyproject.toml` — MODIFY. Register the `network` pytest marker (§4 step 6 gives the exact
  stanza) so the live-HTTP tests this task adds do not raise `PytestUnknownMarkWarning`.

Out-of-scope (do not touch even if tempted):

- `pipeline/tests/test_demo_bundle_shape.py` — task 01.5's file; do not extend it with this task's checks.
- `data/demo/landmarks.json`, `data/demo/manifest.json`, `data/demo/sources.json`, `data/demo/edges.json`,
  `data/demo/courses.json`, `data/demo/regions.json` — none of these are in this task's write scope. If the
  landmark itself needs correcting (a broken `source_url`, a name mismatch), that is a scope gap to report,
  not a file this task edits.
- `Packages/Core/**` — no L0-prefixed check is added to `Core`'s L0 report; distractor tags, SymPy
  re-derivation and landmark resolution are pipeline-owned, never `Core`-owned
  (`docs/tech-stack.md:67`: "`pipeline/` — curriculum-spine, content-generation, learning-objects
  validation, telemetry aggregation").
- `contracts/**` — read-only ground truth.
- Any file under `pipeline/src/mathmath_pipeline/` other than the four `verify/` files listed above
  (`cli.py`, `bundle.py`, `__init__.py` at the package root are untouched).

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/content-policy.md` (Generated content, answer re-derivation and renderability):
  > Probe answers are re-derived by SymPy before persistence (I1); prompts and hints must render in
  > SwiftMath or carry `render_fallback: "katex"` (learning-objects W1 5b).

- `contracts/content-policy.md` (Generated content, distractor tags):
  > Distractor tags: every `mc` distractor and every anticipated numeric wrong answer names an `ErrorType`
  > of its node (diagnosis Q1); `none-of-these` is never a tag.

- `contracts/content-policy.md` (Landmarks, I15/D22):
  > Real, named, verifiable; `source_url` required and resolving at build (HTTP 2xx) with the page text
  > containing the landmark's name; ≥ 1 node id. Unsourced → dropped, never invented, never
  > "hypothetical".

- `contracts/data-model.md` (ProbeItem):
  > `id`, `type ∈ {numeric, mc}`, `prompt_latex`, `why`, and either `answer {value (string, normalised
  > decimal or rational), tolerance (≥ 0, default 0)}` with `wrong_answers[] {value, error_type_id}`
  > (numeric) or `choices[] {id, latex, error_type_id?}` + `correct_choice_id` (mc; every non-correct
  > choice carries an `error_type_id`). No free-text answer field exists (I1, I10).

- `contracts/graph-constraints.md` (L0-3b row):
  > Every node without `expectation_codes` carries a `source_ref` whose `source` exists in `sources.json`
  > and whose `locator` is non-empty; the pipeline additionally checks that the locator resolves (HTTP
  > 2xx) at build. A node with neither codes nor `source_ref` fails. | `GRAPH_L0_FAILED{L0-3b, node}` /
  > `SPINE_SOURCE_REF_UNRESOLVED` | resolution is a build-time check; the app checks presence only

- `contracts/graph-constraints.md` (L0-10 row):
  > Every landmark's `node_ids[]` are existing nodes and `source_url` is present (https). |
  > `MAP_LANDMARK_UNSOURCED` | resolution checked by the pipeline (I15)

- `contracts/error-codes.md` (Rules, code registration):
  > A code appears in exactly one domain doc and in the registry.

- `contracts/error-codes.json` (entries this task uses, verified against the live file):
  ```
  {"code": "LO_PROBE_UNCHECKABLE", "recoverable": true, "surface": "internal", "user_text": null},
  {"code": "LO_BAD_DISTRACTOR_TAG", "recoverable": true, "surface": "internal", "user_text": null},
  {"code": "MAP_LANDMARK_UNSOURCED", "recoverable": true, "surface": "internal", "user_text": null},
  ```
  (`SPINE_SOURCE_REF_UNRESOLVED` is the L0-3b code named above; it is registered alongside these three per
  the same `error-codes.md` rule.)

- `contracts/ai-usage.md` (Two places, and only two, full):
  > ## Two places, and only two
  > 1. **Offline generation (pipeline, owner-run, Claude API)** — graph edge candidates, learning objects,
  > paraphrases, landmarks, the M4′ synthetic set. Never on a device, never at runtime.
  > 2. **On-device Tier 1 (Foundation Models)** — `classify` and `reword` only (`runtime-tiers.md`).
  >
  > No third place. A spec that calls a model from `Core`, from the App outside the Tier 1 adapter, from
  > the telemetry path, or from any server is BLOCKed (D36, I14).

- `contracts/ai-usage.md` (Verification before shipping):
  > Verification before shipping: probe answers re-derived by SymPy (I1); paraphrases pass the 6-gram
  > overlap check (I6); landmarks resolve (I15); items render in SwiftMath; all before a bundle is cut.

- `docs/domains/learning-objects.md` (Workflow W1, step 5/5c):
  > 5. **Probe checkability** — every ProbeItem answer re-derived by SymPy in the pipeline and every
  > WorkedExample step CAS-checked there (D41), else `LO_PROBE_UNCHECKABLE`; every `mc` item has ≥ 1
  > distractor tag and every tag names a member of the node's enum, else `LO_BAD_DISTRACTOR_TAG`. 5c.
  > **Landmarks** — `source_url` present and resolving at build (HTTP 2xx), `node_ids[]` non-empty and
  > known, else `LO_LANDMARK_UNSOURCED` (D22, I15).

- `docs/tech-stack.md:67` (pipeline ownership):
  > `pipeline/` — curriculum-spine, content-generation, learning-objects validation, telemetry aggregation
  > (W4).

- `docs/tech-stack.md:27` (Python deps, exact pins):
  > **anthropic** ≥ 1.4,<2 · **pydantic** ≥ 2.13,<3 · **sympy** ≥ 1.14,<2 (exact pins in
  > `pipeline/uv.lock`) | resolved 2026-09-09: anthropic 1.4.0, pydantic 2.13.5, sympy 1.14.0 | Claude API
  > for generation (D12); boundary validation; CAS answer re-derivation (I1)

- `scripts/gate.sh:22-23` (gate 4, verified against the live file):
  ```
  xcodebuild build -quiet -workspace "$ROOT/App/mathmath.xcworkspace" -scheme mathmath -destination "$SIM" CODE_SIGNING_ALLOWED=NO
  ( cd "$ROOT/pipeline" && uv run pytest -q )
  ```
  There is no `-m` flag: `uv run pytest -q` runs every collected test, including any `@pytest.mark.network`
  test this task adds. Registering the marker (§4 step 6) silences the unknown-mark warning; it does **not**
  cause the network test to be filtered out of the gate.

- `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md` §3, mandatory invariant line (I15 and I1/I10
  clauses, verified against the live file):
  > I15 — the landmark's `source_url` is fetched by the pipeline test (HTTP 2xx, page text contains
  > "Interest Act"); on failure the landmark is dropped, never edited into truth. I9 — no review step: the
  > bundle is hand-written *data* (D26 allows it for the Demo), validated by machine; a failing item is
  > rewritten, not approved. I1 / I10 — every item is `numeric` or `mc` with a checked
  > `answer`/`correct_choice_id`; the pipeline re-derives every numeric answer with SymPy where the prompt
  > is expressible (a test lists the items it could not express, empty = FAIL for this bundle since all
  > are simple).

- `docs/plans/epic-01-task-plan.md` planner note [4], verbatim:
  > **Scope redistribution vs §8.** `Core`'s `validate` stays exactly L0-1 … L0-10 — no LO-prefixed checks
  > are bolted into the L0 report. Renderability (`LO_ITEM_UNRENDERABLE`) goes to 01.6 (`Rendering`);
  > distractor tags, SymPy re-derivation and landmark resolution go to 01.7 (pipeline), per
  > `docs/tech-stack.md` §2 ownership.

- `docs/plans/epic-01-task-plan.md` planner note [6], verbatim:
  > **Network in CI.** 01.7's landmark fetch makes a live HTTPS request inside `pytest`, which gate 4 and
  > CI both run. The spec marks it `@pytest.mark.network`, runs it in the gate, and treats a network
  > failure as a genuine blocking signal (I15). No mock may make the assertion vacuous.

Prior signatures this task's own modules must fit alongside (verified by direct read):

- `pipeline/src/mathmath_pipeline/__init__.py`:
  ```python
  REPO_ROOT = Path(__file__).resolve().parents[3]
  CORE_PACKAGE = REPO_ROOT / "Packages" / "Core"

  def core_cli(*args: str) -> str: ...
  ```
- `pipeline/src/mathmath_pipeline/cli.py` exposes `L0Report`, `validate(bundle_dir: Path) -> L0Report`,
  `layout(bundle_dir: Path) -> None`, `CoreCliError`; this task does not call any of these — L0 is not
  this task's concern (planner note [4]).
- `pipeline/pyproject.toml` (`[tool.pytest.ini_options]`, verified against the live file — no `markers`
  key present today):
  ```toml
  [tool.pytest.ini_options]
  testpaths = ["tests"]
  ```

**The machine-readable-field gap (named plainly, not worked around).** `contracts/schemas/nodes.schema.json`
(verified by direct read, `probe_items[].items.properties`) defines exactly these ProbeItem fields:
`id`, `type`, `prompt_latex`, `why`, `render_fallback`, `answer {value, tolerance}`,
`wrong_answers[] {value, error_type_id}`, `choices[] {id, latex, error_type_id}`, `correct_choice_id`.
**There is no separate machine-readable expression field** (no `expr`, `sympy_expr`, `formula`, or
equivalent) distinct from the presentation string `prompt_latex`. The re-derivation this task ships
therefore cannot be "parse a structured field"; it must be "translate a restricted LaTeX-arithmetic subset
out of `prompt_latex` itself." §4 step 2 fixes the exact subset supported and the exact failure mode
(collected as unexpressible, never guessed at). This is a real, load-bearing gap in the schema, not an
implementer oversight — it is named here so the acceptance path (an *empty* unexpressible list) is
understood as depending on 01.5/01.6 having written prompts inside this subset, which this task cannot
itself widen by editing `prompt_latex` (§2 out-of-scope).

## §4 Implementation outline

1. **Layer placement.** This task is layer ③ (learning objects) static-content *validation*, pipeline-side
   (`docs/tech-stack.md:67`). It adds no layer ④ (interaction/runtime) code and no `Core` code.

2. **`verify/answers.py` — SymPy re-derivation.**
   - Extract the first `$...$`-delimited math span from `prompt_latex` with a regex
     (`re.compile(r"\$(.+?)\$")`); if none is found, the item is unexpressible.
   - Translate that span into a `sympy.sympify`-parsable string using a **fixed, small substitution
     table** covering exactly: `\left`, `\right` (dropped), `\times`, `\cdot` (→ `*`), `\div` (→ `/`),
     `\frac{a}{b}` (→ `((a)/(b))`), `^{e}` / `^d` (→ `**(e)` / `**d`). If, after substitution, the string
     still contains a `\` (an untranslated LaTeX command), the item is unexpressible — return `None`, never
     guess at an unknown command.
   - If the translated string contains no top-level `=`, evaluate it as an expression:
     `sympy.nsimplify(sympy.sympify(source), rational=True)`.
   - If it contains exactly one top-level `=`, treat it as a linear equation in exactly one distinct
     single-letter symbol other than the digits/operators already consumed; solve with
     `sympy.solve(sympy.Eq(lhs, rhs), symbol)`. If zero or more than one solution results, the item is
     unexpressible.
   - Public functions (exact signatures, `pipeline/src/mathmath_pipeline/verify/answers.py`):
     ```python
     from __future__ import annotations

     from dataclasses import dataclass
     from fractions import Fraction
     from typing import Any

     LO_PROBE_UNCHECKABLE: str

     @dataclass(frozen=True)
     class UnexpressibleItem:
         node_id: str
         item_id: str
         prompt_latex: str

     @dataclass(frozen=True)
     class AnswerMismatch:
         node_id: str
         item_id: str
         declared_value: str
         derived_value: str

     def extract_math_span(prompt_latex: str) -> str | None: ...
     def translate_to_sympy_source(latex_math: str) -> str | None: ...
     def derive_numeric_value(prompt_latex: str) -> Fraction | None: ...
     def verify_numeric_answers(
         nodes_file: dict[str, Any],
     ) -> tuple[list[UnexpressibleItem], list[AnswerMismatch]]: ...
     ```
   - `verify_numeric_answers` walks every node's `probe_items[]` where `type == "numeric"`; for each,
     calls `derive_numeric_value(item["prompt_latex"])`. `None` → appended to the `UnexpressibleItem` list.
     Otherwise, compare the derived `Fraction` against `Fraction(item["answer"]["value"])` (parsing the
     schema's `p/q` or decimal string form); if the absolute difference exceeds
     `item["answer"].get("tolerance", 0)`, append an `AnswerMismatch`. Both lists are returned so the
     caller can assert each independently (AC2, AC3).
   - Errors thrown: this module raises nothing itself (it returns lists for the caller to assert on); the
     registry code the caller cites on failure is `LO_PROBE_UNCHECKABLE` (`contracts/error-codes.json`)
     for either list being non-empty.
   - CAS assertion: `sympy` alone decides the derived value; no model is called anywhere in this function
     (I1).

3. **`verify/distractors.py` — on-enum distractor tags.**
   - Exact signatures (`pipeline/src/mathmath_pipeline/verify/distractors.py`):
     ```python
     from __future__ import annotations

     from dataclasses import dataclass
     from typing import Any

     LO_BAD_DISTRACTOR_TAG: str
     BANNED_TAG: str  # "none-of-these"

     @dataclass(frozen=True)
     class BadDistractorTag:
         node_id: str
         item_id: str
         entry_id: str
         error_type_id: str | None

     def find_bad_distractor_tags(nodes_file: dict[str, Any]) -> list[BadDistractorTag]: ...
     ```
   - For every node, build `allowed = {e["id"] for e in node["error_types"]}` **from that node's own
     `error_types[]`** — never a module-level or hand-maintained literal list.
   - For every `mc` item: for every `choices[]` entry whose `id` != `correct_choice_id`, the entry MUST
     have a non-null `error_type_id` in `allowed`, and it must never equal `"none-of-these"`; a violation
     of either rule appends a `BadDistractorTag`.
   - For every `numeric` item's `wrong_answers[]` (if present): the same two rules apply to each entry's
     `error_type_id`.
   - Errors: the caller cites `LO_BAD_DISTRACTOR_TAG` for any non-empty result (AC4).

4. **`verify/landmarks.py` — live HTTP resolution (I15) + L0-3b `source_ref` scan.**
   - Uses only Python's standard library `urllib.request`/`urllib.error` for the HTTP fetch — no HTTP
     client library is pinned in `docs/tech-stack.md` §1, and the stdlib needs no pin.
   - Exact signatures (`pipeline/src/mathmath_pipeline/verify/landmarks.py`):
     ```python
     from __future__ import annotations

     from dataclasses import dataclass
     from typing import Any

     MAP_LANDMARK_UNSOURCED: str
     SPINE_SOURCE_REF_UNRESOLVED: str

     class ResolutionFailure(Exception):
         code: str
         url: str
         def __init__(self, code: str, url: str, detail: str) -> None: ...

     def fetch_page_text(url: str) -> str: ...
     def page_contains(page_text: str, needle: str) -> bool: ...

     @dataclass(frozen=True)
     class SourceRefEntry:
         node_id: str
         source: str
         locator: str

     def scan_source_refs(nodes_file: dict[str, Any]) -> list[SourceRefEntry]: ...
     def resolve_source_ref(entry: SourceRefEntry, sources_file: dict[str, Any]) -> None: ...
     ```
   - `fetch_page_text(url)`: issues a real `urllib.request.urlopen` GET with a `User-Agent` header (some
     government hosts reject the default urllib agent string), 10-second timeout. Raises
     `ResolutionFailure(MAP_LANDMARK_UNSOURCED, url, "HTTP <status>, expected 2xx")` on a non-2xx status;
     lets `urllib.error.URLError` (DNS/connection failure) propagate unmodified — both are genuine I15
     failures, never caught to produce a passing result.
   - `page_contains(page_text, needle)`: case-insensitive substring match (`needle.lower() in
     page_text.lower()`) — matches the domain doc's "unescaped substring match acceptable" reading (task
     01.5 §7 decision note, same acceptance shape reused here).
   - `scan_source_refs(nodes_file)`: returns one `SourceRefEntry` per node carrying a `source_ref` key.
     For `data/demo`, this returns `[]` (every Demo node carries `expectation_codes` instead — D14/
     DEMO-BRIEF §3.1–3.2, confirmed by task 01.5 §4 step 3: "every Demo node should carry
     `expectation_codes` since Demo content is grade 9–12 only"). The caller (the test, §5) MUST assert
     and print the scan count explicitly, with the literal message
     `"0 source_refs scanned — vacuous by bundle scope"` when the count is `0` (C3; AC7) — silently
     passing an empty list with no message is not acceptable.
   - `resolve_source_ref(entry, sources_file)`: looks up `entry.source` in `sources_file["sources"]` by
     matching the `source` field; if found, resolves that source's registered `url` field via
     `fetch_page_text`, requiring 2xx (raises `ResolutionFailure(SPINE_SOURCE_REF_UNRESOLVED, ...)`
     otherwise). `entry.locator` is carried in the failure detail for diagnosis only — no contract defines
     how a source's `url` and a `source_ref.locator` join into one fetchable address, so this function
     resolves the source's own `url`, not a locator-appended URL (§6 decision-default makes this explicit;
     the path is untested by `data/demo` since its scan count is `0`).

5. **Model-calling path: none.** No function in `verify/` imports `anthropic`, calls a model, or reads
   Tier 1/Tier 2 infrastructure. Correctness in this task is decided entirely by `sympy` (a CAS) for
   answers, by set membership for distractor tags, and by a real HTTP status code for landmark sourcing —
   never a model (I1, `contracts/ai-usage.md`). There is therefore no confidence threshold and no Tier-0
   fallback to specify: this task has zero model-calling paths.

6. **Register the `network` pytest marker.** Add exactly this stanza to `pipeline/pyproject.toml`'s
   existing `[tool.pytest.ini_options]` table (the live file has `testpaths = ["tests"]` and no `markers`
   key today):
   ```toml
   [tool.pytest.ini_options]
   testpaths = ["tests"]
   markers = [
       "network: exercises a live HTTPS request (I15 landmark source_url resolution). Runs unfiltered in gate 4 (`uv run pytest -q`, no -m flag); registered only to silence PytestUnknownMarkWarning, never to enable skipping a network test.",
   ]
   ```
   Mark every test in `test_demo_bundle.py` that performs a live fetch with `@pytest.mark.network`. Do
   **not** add a `-m "not network"` anywhere in `scripts/gate.sh`, CI, or this task's own tests — planner
   note [6] requires the network test to run in the gate and to fail loudly on a network failure.

7. **Author `pipeline/tests/test_demo_bundle.py`** per §5.

8. **Correct `data/demo/nodes.json` only where this task's own checks find a violation.** If
   `verify_numeric_answers` reports a mismatch, fix that item's `answer.value` to the SymPy-derived value
   (never adjust the translator to match a wrong hand-authored value). If `find_bad_distractor_tags`
   reports a violation, fix that entry's `error_type_id` to a valid member of the node's own
   `error_types[]`. If `verify_numeric_answers` reports an **unexpressible** item, this task does not
   rewrite `prompt_latex` (out of scope, §2) — report it as a blocking gap against 01.5/01.6 instead.

9. Smoke check: `cd pipeline && uv run pytest tests/test_demo_bundle.py -q` — must be green, including the
   `network`-marked tests actually executed (not skipped).

## §5 Test plan (seam risk — full plan)

- T1 happy path: over the real, committed `data/demo/nodes.json` and `data/demo/landmarks.json` —
  `verify_numeric_answers` returns `([], [])` (both lists empty — AC2, AC3); `find_bad_distractor_tags`
  returns `[]` (AC4); `fetch_page_text` on the landmark's real `source_url` returns 2xx text containing
  both the landmark's `name` and the literal `"Interest Act"` (AC5); `scan_source_refs` returns `[]` and
  the test explicitly asserts/prints the C3 message (AC7).
- T2 negative — invalid input rejected at the boundary: construct an in-memory `nodes_file` dict (not a
  file on disk — this test does not touch `data/demo/nodes.json`) with one `numeric` item whose
  `answer.value` is deliberately wrong relative to its `prompt_latex`; assert `verify_numeric_answers`
  returns it in the `AnswerMismatch` list. Likewise construct one `mc` item with a distractor
  `error_type_id` of `"none-of-these"`; assert `find_bad_distractor_tags` flags it.
- T3 error-taxonomy: assert `fetch_page_text` on a URL that returns non-2xx raises `ResolutionFailure`
  whose `.code == MAP_LANDMARK_UNSOURCED` (this is AC6 below, using a live fixture URL, not a mock);
  assert the module-level constants `LO_PROBE_UNCHECKABLE`, `LO_BAD_DISTRACTOR_TAG`,
  `MAP_LANDMARK_UNSOURCED`, `SPINE_SOURCE_REF_UNRESOLVED` equal the exact strings registered in
  `contracts/error-codes.json` (quoted in §3).
- T4 conformance per requirements §B.1: `docs/domains/learning-objects.md` W1 step 5/5c (quoted in §3) —
  assert every check this task ships maps to the named error code (`LO_PROBE_UNCHECKABLE`,
  `LO_BAD_DISTRACTOR_TAG`) and that the landmark check is the pipeline's, not `Core`'s (no new file under
  `Packages/Core/**` in this task's diff — asserted by the PR diff, not a runtime test).
- T5 negative control for every regression guard:
  - For the SymPy re-derivation guard: T2's mismatch case already proves it reds on a wrong answer.
    Additionally, plant an item whose `prompt_latex` uses a LaTeX command outside the supported subset
    (e.g. `\sqrt{4}`) and assert it lands in the `UnexpressibleItem` list, proving the guard does not
    silently accept an untranslatable prompt as passing.
  - For the distractor-tag guard: T2's `"none-of-these"` case already proves it reds; additionally plant
    a `choices[]` entry with a missing `error_type_id` (`None`) and assert it is flagged too.
  - For the landmark guard: AC6 below is this guard's negative control, run live.
- T6 idempotency / no-leak: `verify_numeric_answers`, `find_bad_distractor_tags`, `scan_source_refs` are
  pure functions over their input dict — call each twice on the same in-memory `nodes_file` and assert
  identical return values; none of the three functions writes to disk (only step 8 of §4, run manually by
  the implementer during authoring, ever writes `data/demo/nodes.json`).

**Companion test this task ships**, exactly at `pipeline/tests/test_demo_bundle.py` (§2), asserting over
`data/demo/` specifically:

- `test_no_model_import_in_verify_package` — scans the three `verify/*.py` source files (not the whole
  repo) for the literal token `"anthropic"`; asserts none found; asserts the scan actually covered ≥ 3
  files (anti-vacuity).
- `test_numeric_probe_answers_all_sympy_expressible` — loads `data/demo/nodes.json`, calls
  `verify_numeric_answers`, asserts the unexpressible list is `[]`, printing every entry's `node_id`/
  `item_id`/`prompt_latex` in the assertion message on failure; asserts the number of `numeric` items
  scanned is `> 0` (anti-vacuity — an empty bundle must not pass this check vacuously).
- `test_numeric_probe_answers_match_sympy_derivation` — same call, asserts the mismatch list is `[]`,
  printing every entry's declared vs. derived value on failure.
- `test_distractor_tags_on_enum_and_never_none_of_these` — loads `data/demo/nodes.json`, calls
  `find_bad_distractor_tags`, asserts `[]`; asserts the number of `mc` items scanned is `> 0`.
- `test_landmark_source_url_resolves` (`@pytest.mark.network`) — loads `data/demo/landmarks.json`, fetches
  the one landmark's real `source_url`, asserts `page_contains(text, landmark["name"])` and
  `page_contains(text, "Interest Act")` are both `True`.
- `test_landmark_resolution_failure_path_is_real` (`@pytest.mark.network`) — fetches
  `<real source_url> + "this-path-cannot-exist-mathmath-test"` (same host as the real landmark, a path
  guaranteed 404) and asserts `ResolutionFailure` is raised with `.code == MAP_LANDMARK_UNSOURCED` — this
  is AC6, proving the drop path is real, not disabled.
- `test_source_ref_scan_is_explicit_about_zero_scope` — loads `data/demo/nodes.json`, calls
  `scan_source_refs`, asserts the result is `[]`, and asserts a captured print/log line equals exactly
  `"0 source_refs scanned — vacuous by bundle scope"` (via `capsys` or an explicit string return the test
  checks) — never a bare `pass`/no-op on the empty case.

## §6 Decision defaults

- IF a `numeric` item's `prompt_latex` uses LaTeX outside `answers.py`'s supported arithmetic subset (not
  translatable) THEN it is collected in the `UnexpressibleItem` list and the acceptance test FAILS; since
  this task cannot edit `prompt_latex` (§2 out-of-scope), a non-empty unexpressible list is a **blocking
  dependency gap on 01.5/01.6's authoring** to report, never a reason to widen the translator with guesses
  or to hand-code a per-item exception (`docs/epics/epic-01-core-data-l0-layout-demo-bundle.md` §3
  mandatory invariant line, quoted in §3: "empty = FAIL for this bundle since all are simple").
- IF `verify_numeric_answers` reports an `AnswerMismatch` THEN correct `data/demo/nodes.json`'s
  `answer.value` to the SymPy-derived value (in-scope per §2's "answer … corrections") and re-run; never
  adjust `answers.py`'s translation logic to make a wrong hand-authored value pass (I1: SymPy decides
  correctness, not the other way around).
- IF `find_bad_distractor_tags` reports a `BadDistractorTag` THEN correct that entry's `error_type_id` in
  `data/demo/nodes.json` to a valid member of the owning node's own `error_types[]` (in-scope per §2's
  "tag corrections"); never delete the node's `error_types[]` entry to make the reference resolve
  backwards.
- IF the join convention between a `sources.json` entry's `url` and a node's `source_ref.locator` is
  needed (it is not, for `data/demo`, since `scan_source_refs` returns `[]`) THEN `resolve_source_ref`
  resolves the source's registered `url` field directly and records `locator` only as diagnostic detail —
  no contract (`contracts/data-model.md`, `contracts/graph-constraints.md` L0-3b, quoted in §3) defines a
  URL-join convention, so this is the conservative default and it is untested by this bundle's data (scan
  count `0`, AC7).
- IF the `network` pytest marker is unregistered (confirmed: `pipeline/pyproject.toml`'s
  `[tool.pytest.ini_options]` has no `markers` key today) THEN add exactly the stanza in §4 step 6; do not
  add a `-m` filter anywhere that would cause the network test to be skipped in the gate (planner note
  [6], quoted in §3).
- IF the fetched landmark page's character case differs from the landmark's stored `name` field THEN use a
  case-insensitive substring match (`page_contains`, §4 step 4) — matching the domain doc's "unescaped
  substring match acceptable" reading already used by task 01.5 for the same landmark.

Standing defaults: identifiers and timestamps are not touched by this task (it writes no new bundle file,
only corrects existing `answer.value`/`error_type_id` fields inside `data/demo/nodes.json`); this task has
zero model-calling paths, so no confidence threshold or Tier-0 fallback applies (§4 step 5); telemetry is
untouched; no identifying field is added anywhere; `data/demo/nodes.json`'s `paraphrase` fields are never
touched by this task (I6 — this task corrects answers/tags only, never prose).

## §7 Done definition

The task is done when ALL gates pass:

- format + lint clean (`cd pipeline && uv run ruff check . && uv run ruff format --check .`, covering the
  four new/modified Python files)
- typecheck clean (`cd pipeline && uv run pyright`, strict, covering `verify/*.py` and
  `tests/test_demo_bundle.py`)
- `cd pipeline && uv run pytest tests/test_demo_bundle.py -q` green, including the `network`-marked tests
  actually executed against live URLs (not skipped, not mocked)
- `cd pipeline && uv run pytest -q` (the full gate-4 pipeline suite, per `scripts/gate.sh:23`) green
- `scripts/gate.sh` green end-to-end
- every bullet in §5's companion-test list passes
- `data/demo/nodes.json` still validates against `contracts/schemas/nodes.schema.json`
  (`pytest pipeline/tests/test_contracts.py::test_data_bundles_validate` green) after any correction this
  task makes
- conforms to every contract section cited in §3 and §4, and to every invariant listed in §1
