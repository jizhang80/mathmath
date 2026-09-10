# Epic 01 · Task 07: Pipeline content verification (SymPy re-derivation, distractor tags, landmark sourcing)

---
epic: 01
task: 07
slug: pipeline-content-verification
kind: test
risk: seam
depends_on: [01.5, 01.6, 01.6.1]
model: sonnet
---

> **Status: dispatchable once 01.6.1 has landed.** Arbitration 2026-09-09 applied Finding A (the landmark
> error code) below in full and escalated two findings to the owner. Both were ruled on — see
> `tasks/blocked/Q5-RULING-01-07.md`. AC2 and AC5 are unfrozen and rewritten to that ruling: AC2 now derives
> from the ProbeItem `check` field added by `tasks/epic-01-task-06.1-contract-v1-1-probe-check.md`, and AC5
> now asserts the landmark's `source_title`. The `extract_math_span` / substitution-table algorithm the
> reviewer measured unworkable against the real bundle (zero `$` characters in `data/demo/nodes.json`) is
> deleted. **Dispatch precondition:** task 01.6.1 is merged, and the EPIC brief amendment filed in
> `tasks/blocked/brief-amendment-01-07-probe-check-and-landmark.md` has landed. Every other section of this
> spec is arbitrated and final and is unchanged.

## §1 Goal & acceptance criteria

Goal: give the pipeline a `verify/` subpackage that machine-checks three properties of `data/demo` at
build time — (a) every `numeric` ProbeItem's declared answer is re-derived by SymPy (never a model) from
that item's `check` field, (b) every `mc` distractor and every `wrong_answers[]` entry names an
`error_type_id` that is a member of its own node's `error_types[]` and is never `"none-of-these"`, and
(c) the one landmark's `source_url` actually resolves (HTTP 2xx) and its page contains the landmark's
declared `source_title` — and ship the companion test that proves all three over the real `data/demo`
bundle, plus the deferred L0-3b `source_ref` resolver scan.

Invariants in play:

- **I1** — correctness of every numeric probe answer is decided by re-deriving it with SymPy (a CAS) from
  the item's `check` declaration, never by asking a model, never by parsing the presentation string
  `prompt_latex`, and never by trusting the hand-authored value; a mismatch is a build-time failure, not a
  warning.
- **I9** — zero human review step: a failing item's answer or tag is corrected in `nodes.json` and
  re-verified by the same machine check, never "approved as-is".
- **I10** — this task only ever inspects `numeric`/`mc` ProbeItems; it asserts no other item shape exists.
- **I15** — a landmark whose `source_url` does not resolve is never trusted. The resolution check is a live
  HTTP fetch. **Failure behaviour in this task is unambiguous and single-valued: the resolution failure
  raises `ResolutionFailure(LO_LANDMARK_UNSOURCED, …)`, the companion test goes red, and gate 4 blocks.**
  This task never silently drops, skips, retries-until-green, or mocks the landmark. Editing or removing
  the landmark entry itself is an edit to `data/demo/landmarks.json`, which is **out of this task's file
  scope** (§2) — a real resolution failure against the committed landmark is reported as a blocking gap
  against the owner of that file, never worked around here.

Acceptance criteria (each independently verifiable):

- AC1: no `anthropic` import token appears anywhere in `pipeline/src/mathmath_pipeline/verify/*.py` —
  asserted by a test that scans the three new source files (`contracts/ai-usage.md` heading `## Two
  places, and only two`: "No third place. A spec that calls a model from `Core`, from the App outside the
  Tier 1 adapter, from the telemetry path, or from any server is BLOCKed").
- AC2: every `numeric` ProbeItem in `data/demo/nodes.json` is re-derived by `answers.py` from its **`check`
  field alone**, exactly as `contracts/data-model.md` § Probe answer derivation (v1.1.0) specifies; the
  number of items derived equals the number of `numeric` items in the bundle (**20**, anti-vacuity: a scan
  that covers fewer FAILS) and the list of items the CAS could not derive is printed and asserted **empty**
  — a non-empty list FAILS the test. `answers.py` never reads `prompt_latex` to derive a value: the
  derivation function takes the `check` object and nothing else, asserted structurally in §5 T3.
- AC3: every re-derived value equals the item's declared `answer.value` within its `tolerance` (default
  `0`); any mismatch is printed by node id and item id and FAILS the test.
- AC4: every `mc` item's non-correct `choices[]` entries and every `wrong_answers[]` entry carries an
  `error_type_id` drawn from its **own node's** `error_types[].id` list (never a hardcoded enum) and is
  never the literal `"none-of-these"`; a violation FAILS with the item id named in the assertion message.
- AC5: the landmark's `source_url` (`https://laws-lois.justice.gc.ca/eng/acts/I-15/`) resolves with HTTP
  2xx and the fetched page text contains, case-insensitively, the landmark's declared `source_title` field
  value — `"Interest Act"` for this bundle. The needle is read from the landmark record, never hardcoded in
  the test, and the test additionally asserts the record's `source_title` equals `"Interest Act"` so that a
  blanked-out field cannot make the substring check vacuous. The landmark's `name` is **not** asserted
  against the page: it is the project's own descriptive claim, not a term from the source
  (`contracts/content-policy.md` § Landmarks v1.1.0; owner ruling Q5-2, quoted in §3).
- AC6: the landmark-resolution failure path is proven live — a deliberately broken fixture URL derived
  from the real `source_url` (same host, a path guaranteed to 404) is fetched for real and asserted to
  raise `ResolutionFailure` with `.code == LO_LANDMARK_UNSOURCED`; no mock stands in for this assertion.
- AC7: the L0-3b `source_ref` resolver scans `data/demo/nodes.json` and explicitly asserts/prints
  `"0 source_refs scanned — vacuous by bundle scope"` (C3) rather than silently passing an empty scan.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `pipeline/src/mathmath_pipeline/verify/__init__.py` — CREATE. Re-exports the public functions of the
  three submodules below; no logic of its own beyond re-export.
- `pipeline/src/mathmath_pipeline/verify/answers.py` — CREATE. SymPy re-derivation of `numeric` ProbeItem
  answers from the item's `check` field (§4 step 2).
- `pipeline/src/mathmath_pipeline/verify/distractors.py` — CREATE. On-enum distractor-tag validation
  (§4 step 3).
- `pipeline/src/mathmath_pipeline/verify/landmarks.py` — CREATE. Live `source_url`/`source_ref` HTTP
  resolution (§4 step 4).
- `pipeline/tests/test_demo_bundle.py` — CREATE. The companion test over `data/demo` (§5). This exact path
  is reserved for this task (`tasks/epic-01-task-05-demo-bundle.md` out-of-scope list: "`pipeline/tests/
  test_demo_bundle.py` — reserved for task 01.7"; task 01.5 ships `test_demo_bundle_shape.py` instead,
  confirmed present at `pipeline/tests/test_demo_bundle_shape.py`).
- `data/demo/nodes.json` — MODIFY. **Answer or distractor-tag corrections only** — this file is shared:
  01.5 authored it, 01.6 amended notation/`render_fallback`, 01.6.1 added the `check` field to every
  `numeric` item, this task amends only `answer.value` values and `error_type_id` tags that this task's own
  checks find wrong. Never touch `id`, `paraphrase`, `region_id`, `courses`, `position`, `prompt_latex`,
  `check`, `hint_tree`, `expectation_codes`, or the node set itself — those belong to 01.5/01.6/01.6.1.
- `pipeline/pyproject.toml` — MODIFY. Register the `network` pytest marker (§4 step 6 gives the exact
  stanza) so the live-HTTP tests this task adds do not raise `PytestUnknownMarkWarning`.

Out-of-scope (do not touch even if tempted):

- `pipeline/tests/test_demo_bundle_shape.py` — task 01.5's file; do not extend it with this task's checks.
- `data/demo/landmarks.json`, `data/demo/manifest.json`, `data/demo/sources.json`, `data/demo/edges.json`,
  `data/demo/courses.json`, `data/demo/regions.json` — none of these are in this task's write scope. This
  exclusion is deliberate and was re-confirmed at arbitration: this task's job is to *prove the resolution
  check exists and reds on a real failure*, so a failure against the committed landmark must **block the
  gate**, not be quietly repaired here. If the landmark itself needs correcting (a non-resolving
  `source_url`, a `source_title` the page does not contain), that is a scope gap to report against the
  owner of `landmarks.json`, not a file this task edits.
- `Packages/Core/**` — no L0-prefixed check is added to `Core`'s L0 report; distractor tags, SymPy
  re-derivation and landmark resolution are pipeline-owned, never `Core`-owned
  (`docs/tech-stack.md:67`: "`pipeline/` — curriculum-spine, content-generation, learning-objects
  validation, telemetry aggregation").
- `contracts/**` — read-only ground truth. (The v1.1.0 change this task consumes was applied by task
  01.6.1 under the owner's Q5 ruling; this task adds nothing to it.)
- Any file under `pipeline/src/mathmath_pipeline/` other than the four `verify/` files listed above
  (`cli.py`, `bundle.py`, `__init__.py` at the package root are untouched).

## §3 Inputs (verbatim — do not paraphrase)

The owner ruling this task's AC2 and AC5 implement:

- `tasks/blocked/Q5-RULING-01-07.md:22-25`:
  > **OWNER RULING: extend the schema.** ProbeItem gains a machine-readable expression field; SymPy derives
  > the answer from that field and compares against `answer`. Chosen over re-authoring the demo data and
  > over qualifying the contract, because the problem is not Demo-local: the generated-content EPICs (05–09)
  > need machine-checkable answers for I1 to hold at product scale, and both other options leave that
  > unsolved.
- `tasks/blocked/Q5-RULING-01-07.md:39-42`:
  > **OWNER RULING: assert `"Interest Act"`.** The general rule — "the fetched page contains the landmark's
  > name" — is amended, because a landmark `name` is by design the project's own descriptive claim and not a
  > term from the source document, so the rule is unsatisfiable for essentially every landmark, not just
  > this one. The landmark's `name` is NOT edited to suit the test.

Binding contract rules (`contracts/data-model.md` and `contracts/content-policy.md` at **v1.1.0**, as
amended by task 01.6.1 under that ruling):

- `contracts/content-policy.md` (Generated content, answer re-derivation and renderability):
  > Probe answers are re-derived by SymPy before persistence (I1): every `numeric` ProbeItem carries `check`
  > and the CAS derives the answer from `check` alone — never by parsing `prompt_latex`, never by a model
  > (`data-model.md` § ProbeItem, § Probe answer derivation). An item the CAS cannot derive exactly, or whose
  > derived value differs from `answer.value` beyond `tolerance`, is `LO_PROBE_UNCHECKABLE` and fails the
  > build; nothing ships unchecked. `mc` correctness is `correct_choice_id` plus the distractor rule below;
  > extending `check` to `mc` is a further versioned change. Prompts and hints must render in SwiftMath or
  > carry `render_fallback: "katex"` (learning-objects W1 5b).

- `contracts/content-policy.md` (Generated content, distractor tags):
  > Distractor tags: every `mc` distractor and every anticipated numeric wrong answer names an `ErrorType`
  > of its node (diagnosis Q1); `none-of-these` is never a tag.

- `contracts/content-policy.md` (Landmarks, I15/D22):
  > Real, named, verifiable; `source_url` required and resolving at build (HTTP 2xx); `source_title` required
  > — the title of the real, named thing the landmark cites, as that title appears on the source page — and
  > the fetched page text must contain it (case-insensitive substring). The landmark's `name` is the
  > project's own descriptive claim about the mathematics and is by design not a term from the source, so it
  > is never asserted against the page; a landmark's `name` is never edited to make a check pass. ≥ 1 node
  > id. Unsourced → dropped, never invented, never "hypothetical".

- `contracts/data-model.md` (ProbeItem):
  > `id`, `type ∈ {numeric, mc}`, `prompt_latex`, `why`, and either `answer {value (string, normalised
  > decimal or rational), tolerance (≥ 0, default 0)}` with `wrong_answers[] {value, error_type_id}`
  > (numeric) or `choices[] {id, latex, error_type_id?}` + `correct_choice_id` (mc; every non-correct
  > choice carries an `error_type_id`). No free-text answer field exists (I1, I10).
  >
  > Every `numeric` item additionally carries **`check`** — the machine-readable declaration the CAS
  > re-derives the answer from (I1). An `mc` item never carries `check` … `check` is
  > `{ kind ∈ {evaluate, solve} }` plus, by kind: **`evaluate`** — `expr` (required): one SymPy-source
  > expression; `at` (optional): a map from symbol name to a numeric string, substituted before evaluation
  > … **`solve`** — `equations[]` (required): one or more `Eq(lhs, rhs)` in SymPy source; `unknown`
  > (required): the symbol whose value is the answer; `select ∈ {only, max, min}` (optional, default
  > `only`) …

- `contracts/data-model.md` (Probe answer derivation, normative) — **this task's AC2 algorithm; implement
  it, do not re-invent it**:
  > The pipeline derives every `numeric` answer from `check` alone. **`prompt_latex` is never parsed** — it
  > is a presentation string that may embed an English question, and a parser that mis-reads it does not
  > fail, it silently confirms whatever answer was authored. No model participates at any point (I1).
  >
  > Parsing is `sympy.parse_expr` with `standard_transformations + (rationalize,)` — so decimal literals
  > become exact `Rational`s — and a **closed name allow-list**: `Eq`, `Rational`, `sqrt`, `log`, `exp`,
  > `Abs`, `diff`, `pi`, `E`. Any other name parses to a free symbol; calling one raises, and the item
  > fails. Extending the allow-list is a versioned change.
  >
  > - `evaluate`: parse `expr`; every key of `at` must be a free symbol of `expr`; substitute; the result
  >   must have no free symbols left.
  > - `solve`: parse each equation; `unknown` must be a free symbol of the set; call
  >   `sympy.solve(equations, sorted(free_symbols), dict=True)`; keep the solutions that bind `unknown`;
  >   `select: only` requires exactly one distinct bound value, `max`/`min` take the extreme of them.
  >
  > The derived value must be an exact rational after `sympy.simplify` (`.is_Rational` true). A parse
  > failure, an unknown name, a leftover free symbol, an unbound `unknown`, zero solutions, more than one
  > solution under `select: only`, or a non-rational result is `LO_PROBE_UNCHECKABLE` and **fails the
  > build**. Nothing is rounded, nothing is approximated, nothing is inferred. The derived value is then
  > compared to `answer.value` within `answer.tolerance` (default `0`); a mismatch fails the build.

- `contracts/graph-constraints.md` (L0-3b row):
  > Every node without `expectation_codes` carries a `source_ref` whose `source` exists in `sources.json`
  > and whose `locator` is non-empty; the pipeline additionally checks that the locator resolves (HTTP
  > 2xx) at build. A node with neither codes nor `source_ref` fails. | `GRAPH_L0_FAILED{L0-3b, node}` /
  > `SPINE_SOURCE_REF_UNRESOLVED` | resolution is a build-time check; the app checks presence only

- `contracts/graph-constraints.md` (L0-10 row) — **cited for contrast only; this task does not implement
  L0-10**, which is `Core`'s structural presence check:
  > Every landmark's `node_ids[]` are existing nodes and `source_url` is present (https). |
  > `MAP_LANDMARK_UNSOURCED` | resolution checked by the pipeline (I15)

- `contracts/error-codes.md` (Rules, code registration):
  > A code appears in exactly one domain doc and in the registry.

- `contracts/error-codes.json` (entries this task uses, verified against the live file):
  ```
  {"code": "LO_PROBE_UNCHECKABLE", "recoverable": true, "surface": "internal", "user_text": null},
  {"code": "LO_BAD_DISTRACTOR_TAG", "recoverable": true, "surface": "internal", "user_text": null},
  {"code": "LO_LANDMARK_UNSOURCED", "recoverable": true, "surface": "internal", "user_text": null},
  ```
  (`SPINE_SOURCE_REF_UNRESOLVED` is the L0-3b code named above; it is registered alongside these three per
  the same `error-codes.md` rule. `MAP_LANDMARK_UNSOURCED` is also registered but belongs to `Core`'s
  L0-10 presence check — see the code-split note below.)

**Which landmark code, and why (arbitrated 2026-09-09).** `contracts/error-codes.md` (Rules) states "A code
appears in exactly one domain doc and in the registry." The two landmark codes therefore denote two
different checks in two different domain docs, and this task implements exactly one of them:

- `docs/domains/map.md` (Errors produced) registers the **presence** check, which lives in `Core` as L0-10
  and is **not** this task's:
  > | `MAP_LANDMARK_UNSOURCED` | A landmark lacks `source_url` | Internal; bundle refused (I15) | Yes — pipeline |
- `docs/domains/learning-objects.md` (Errors produced) registers the **resolution** check, which is this
  task's whole job:
  > | `LO_LANDMARK_UNSOURCED` | `source_url` missing or not resolving; no node ids | Internal; landmark dropped (I15) | Yes — re-source, never invent |

This task performs a live HTTP fetch and decides on the response — that is "not resolving", so the code is
`LO_LANDMARK_UNSOURCED` everywhere in §4 step 4, AC6, T3 and the companion tests. `MAP_LANDMARK_UNSOURCED`
appears in this spec only inside the two quotations above, as the code of a check this task does not
implement.

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

- `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md` §3, mandatory invariant line, **as amended** per
  `tasks/blocked/brief-amendment-01-07-probe-check-and-landmark.md` (that amendment is a dispatch
  precondition for this task; if the brief still carries the pre-amendment wording, stop and report it):
  > I15 — the landmark's `source_url` is fetched by the pipeline test (HTTP 2xx, page text contains the
  > landmark's `source_title`, `"Interest Act"`); on failure the landmark is dropped, never edited into
  > truth. I9 — no review step: the bundle is hand-written *data* (D26 allows it for the Demo), validated by
  > machine; a failing item is rewritten, not approved. I1 / I10 — every item is `numeric` or `mc` with a
  > checked `answer`/`correct_choice_id`; every `numeric` item carries a `check` and the pipeline re-derives
  > its answer from that field with SymPy, never from `prompt_latex` and never with a model. Every numeric
  > item is derived — a scan covering fewer than all of them, or any item the CAS cannot derive exactly,
  > FAILS.

  Note (arbitration): this EPIC-brief §3 code list names `MAP_LANDMARK_UNSOURCED` but not
  `LO_LANDMARK_UNSOURCED`, and also omits `LO_PROBE_UNCHECKABLE`, which this task certainly uses; the list
  is a non-exhaustive citation of codes the EPIC touches (L0-10 is implemented elsewhere in this EPIC), not
  a code assignment that overrides `contracts/error-codes.md` or the two domain docs.

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

**The machine-readable-field gap is closed (history, so the rewrite is understood).** Arbitration measured
the landed bundle and found the schema had no machine-readable expression field: `prompt_latex` was the
only candidate, two thirds of the 20 numeric prompts encode their question as English inside `\text{…}`,
and the file contains zero `$` characters (`tasks/blocked/blocked-arbiter-01-07.md`, finding B). The owner
ruled the schema be extended rather than the translator widened, and task 01.6.1 added `check` at contract
v1.1.0 and populated all 20 items. This task therefore reads a declared field and never interprets a
prompt. Widening any parser to "understand" `prompt_latex` is out of bounds here for the reason the arbiter
gave: such a parser does not fail when it mis-reads — it silently confirms the hand-authored answer, which
is the laundered guess I1 exists to forbid.

## §4 Implementation outline

1. **Layer placement.** This task is layer ③ (learning objects) static-content *validation*, pipeline-side
   (`docs/tech-stack.md:67`). It adds no layer ④ (interaction/runtime) code and no `Core` code.

2. **`verify/answers.py` — SymPy re-derivation from `check`.**
   - Implement exactly the algorithm quoted in §3 from `contracts/data-model.md` § Probe answer derivation.
     Do not add to it, do not relax it, and do not implement any second path.
   - Build the parse environment once, at module level: `ALLOWED_NAMES: dict[str, Any]` containing exactly
     the nine allow-listed names (`Eq`, `Rational`, `sqrt`, `log`, `exp`, `Abs`, `diff`, `pi`, `E`) bound to
     their `sympy` objects, and `TRANSFORMATIONS = standard_transformations + (rationalize,)`. Every
     `parse_expr` call passes `global_dict=ALLOWED_NAMES` and `local_dict={}`. Nothing else is reachable
     from an authored string.
   - `derive_from_check` takes the `check` mapping and nothing else — no `prompt_latex`, no `answer`, no
     item. This is the structural guarantee behind AC2's "never reads the prompt" and is asserted in §5 T3.
   - Every failure listed in the contract paragraph raises `UncheckableItem` (below) with a `reason`
     string naming which one; nothing is caught and turned into a value, and no branch returns a default.
   - Public functions (exact signatures, `pipeline/src/mathmath_pipeline/verify/answers.py`):
     ```python
     from __future__ import annotations

     from dataclasses import dataclass
     from fractions import Fraction
     from typing import Any

     LO_PROBE_UNCHECKABLE: str

     class UncheckableCheck(Exception):
         reason: str
         def __init__(self, reason: str) -> None: ...

     @dataclass(frozen=True)
     class UncheckableItem:
         node_id: str
         item_id: str
         reason: str

     @dataclass(frozen=True)
     class AnswerMismatch:
         node_id: str
         item_id: str
         declared_value: str
         derived_value: str

     def derive_from_check(check: dict[str, Any]) -> Fraction: ...
     def verify_numeric_answers(
         nodes_file: dict[str, Any],
     ) -> tuple[list[UncheckableItem], list[AnswerMismatch]]: ...
     ```
   - `verify_numeric_answers` walks every node's `probe_items[]` where `type == "numeric"`; for each, calls
     `derive_from_check(item["check"])`. An `UncheckableCheck` (or a `KeyError` on a missing `check`) is
     recorded as an `UncheckableItem` carrying its `reason` — never re-raised as a pass and never skipped.
     Otherwise the derived `Fraction` is compared against `Fraction(item["answer"]["value"])` (the schema's
     `p/q` or decimal string form); if the absolute difference exceeds
     `item["answer"].get("tolerance", 0)`, an `AnswerMismatch` is appended. Both lists are returned so the
     caller can assert each independently (AC2, AC3).
   - Errors thrown: the registry code the caller cites on either list being non-empty is
     `LO_PROBE_UNCHECKABLE` (`contracts/error-codes.json`).
   - CAS assertion: `sympy` alone decides the derived value; no model is called anywhere in this module
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

     LO_LANDMARK_UNSOURCED: str
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
     `MAP_LANDMARK_UNSOURCED` is deliberately **not** a constant of this module: it is `Core`'s L0-10
     presence code (§3 code-split note), and this module implements the resolution check only.
   - `fetch_page_text(url)`: issues a real `urllib.request.urlopen` GET with a `User-Agent` header (some
     government hosts reject the default urllib agent string), 10-second timeout. Raises
     `ResolutionFailure(LO_LANDMARK_UNSOURCED, url, "HTTP <status>, expected 2xx")` on a non-2xx status;
     lets `urllib.error.URLError` (DNS/connection failure) propagate unmodified — both are genuine I15
     failures, never caught to produce a passing result.
   - `page_contains(page_text, needle)`: case-insensitive substring match (`needle.lower() in
     page_text.lower()`) — matches the domain doc's "unescaped substring match acceptable" reading (task
     01.5 §7 decision note, same acceptance shape reused here). Its needle at the call site is the
     landmark's `source_title` (AC5), never its `name`.
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
   - **Failure behaviour, single-valued (§1 I15).** Neither `fetch_page_text` nor any caller in this task
     catches `ResolutionFailure` to produce a green result, and no caller edits or removes the landmark.
     A live failure against the committed landmark propagates out of the companion test, reds gate 4, and
     is reported as a blocking gap against the owner of `data/demo/landmarks.json` (§2 out-of-scope).

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
   `find_bad_distractor_tags` reports a violation, fix that entry's `error_type_id` to a valid member of
   the node's own `error_types[]`. If `verify_numeric_answers` reports a mismatch or an uncheckable item,
   see the two decision-defaults in §6 first — the correction is not automatic, because a disagreement
   between `check` and `answer.value` can mean either one is wrong.

9. Smoke check: `cd pipeline && uv run pytest tests/test_demo_bundle.py -q` — must be green, including the
   `network`-marked tests actually executed (not skipped).

## §5 Test plan (seam risk — full plan)

- T1 happy path: over the real, committed `data/demo/nodes.json` and `data/demo/landmarks.json` —
  `verify_numeric_answers` returns `([], [])` (both lists empty — AC2, AC3); `find_bad_distractor_tags`
  returns `[]` (AC4); `fetch_page_text` on the landmark's real `source_url` returns 2xx text containing the
  landmark's `source_title` (AC5); `scan_source_refs` returns `[]` and the test explicitly asserts/prints
  the C3 message (AC7).
- T2 negative — invalid input rejected at the boundary: construct an in-memory `nodes_file` dict (not a
  file on disk — this test does not touch `data/demo/nodes.json`) with one `numeric` item whose
  `answer.value` is deliberately wrong relative to its `check`; assert `verify_numeric_answers` returns it
  in the `AnswerMismatch` list. Likewise construct one `mc` item with a distractor `error_type_id` of
  `"none-of-these"`; assert `find_bad_distractor_tags` flags it.
- T3 error-taxonomy: assert `fetch_page_text` on a URL that returns non-2xx raises `ResolutionFailure`
  whose `.code == LO_LANDMARK_UNSOURCED` (this is AC6, using a live fixture URL, not a mock);
  assert the module-level constants `LO_PROBE_UNCHECKABLE`, `LO_BAD_DISTRACTOR_TAG`,
  `LO_LANDMARK_UNSOURCED`, `SPINE_SOURCE_REF_UNRESOLVED` equal the exact strings registered in
  `contracts/error-codes.json` (quoted in §3); assert that the literal token `MAP_LANDMARK_UNSOURCED`
  appears nowhere in `pipeline/src/mathmath_pipeline/verify/*.py` (it is `Core`'s L0-10 code, §3
  code-split note), with the scan asserting it covered ≥ 3 files (anti-vacuity); and assert structurally
  that the derivation never sees the prompt — `inspect.signature(derive_from_check).parameters` has exactly
  one parameter named `check` (AC2).
- T4 conformance per requirements §B.1: `docs/domains/learning-objects.md` W1 step 5/5c (quoted in §3) —
  assert every check this task ships maps to the named error code (`LO_PROBE_UNCHECKABLE`,
  `LO_BAD_DISTRACTOR_TAG`, `LO_LANDMARK_UNSOURCED`) and that the landmark check is the pipeline's, not
  `Core`'s (no new file under `Packages/Core/**` in this task's diff — asserted by the PR diff, not a
  runtime test).
- T5 negative control for every regression guard:
  - For the SymPy re-derivation guard: T2's mismatch case already proves it reds on a wrong answer.
    Additionally, plant three in-memory items that each trip a different clause of the contract's failure
    list and assert each lands in the `UncheckableItem` list rather than passing: (i) an `evaluate` check
    whose `expr` calls a name outside the allow-list (e.g. `"factorial(3)"`), (ii) an `evaluate` check with
    a leftover free symbol (`expr: "2*x + 1"` with no `at`), (iii) a `solve` check whose equation has no
    solution for `unknown` (e.g. `Eq(x + 1, x + 2)` for `x`). This proves the guard fails loudly instead of
    guessing — the property the whole task exists for.
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
- `test_every_numeric_probe_answer_is_cas_derived` — loads `data/demo/nodes.json`, calls
  `verify_numeric_answers`, asserts the uncheckable list is `[]`, printing every entry's `node_id`/
  `item_id`/`reason` in the assertion message on failure; asserts the number of `numeric` items scanned is
  exactly `20` and equals the number of items derived (anti-vacuity — neither an empty bundle nor a partial
  scan may pass this check).
- `test_numeric_probe_answers_match_sympy_derivation` — same call, asserts the mismatch list is `[]`,
  printing every entry's declared vs. derived value on failure.
- `test_distractor_tags_on_enum_and_never_none_of_these` — loads `data/demo/nodes.json`, calls
  `find_bad_distractor_tags`, asserts `[]`; asserts the number of `mc` items scanned is `> 0`.
- `test_landmark_source_url_resolves` (`@pytest.mark.network`) — loads `data/demo/landmarks.json`, asserts
  the record's `source_title == "Interest Act"` (so a blanked field cannot make the next assertion
  vacuous), fetches the one landmark's real `source_url`, and asserts
  `page_contains(text, landmark["source_title"])` is `True`. The landmark's `name` is not used as a needle.
- `test_landmark_resolution_failure_path_is_real` (`@pytest.mark.network`) — fetches
  `<real source_url> + "this-path-cannot-exist-mathmath-test"` (same host as the real landmark, a path
  guaranteed 404) and asserts `ResolutionFailure` is raised with `.code == LO_LANDMARK_UNSOURCED` — this
  is AC6, proving the drop path is real, not disabled.
- `test_source_ref_scan_is_explicit_about_zero_scope` — loads `data/demo/nodes.json`, calls
  `scan_source_refs`, asserts the result is `[]`, and asserts a captured print/log line equals exactly
  `"0 source_refs scanned — vacuous by bundle scope"` (via `capsys` or an explicit string return the test
  checks) — never a bare `pass`/no-op on the empty case.

## §6 Decision defaults

- IF a landmark check is about `source_url` **presence/shape** THEN the code is `MAP_LANDMARK_UNSOURCED`
  and the check belongs to `Core`'s L0-10, which this task does not implement; IF the check is about the
  URL **resolving over the network** THEN the code is `LO_LANDMARK_UNSOURCED` and the check is this task's
  (`contracts/error-codes.md` Rules: "A code appears in exactly one domain doc and in the registry";
  `docs/domains/map.md:127` vs `docs/domains/learning-objects.md:130`).
- IF the landmark's `source_url` fails to resolve at test time, or the page does not contain its
  `source_title`, THEN `ResolutionFailure` propagates / the assertion reds, the companion test fails and
  gate 4 blocks; this task never edits `data/demo/landmarks.json`, never catches the failure, never
  substitutes a mock, and never swaps the needle for a shorter string that happens to match (§1 I15, §2
  out-of-scope, planner note [6]). A page that no longer contains the declared title is a re-sourcing
  decision for the owner of `landmarks.json`, and under I15 the landmark is dropped rather than edited into
  truth.
- IF a `numeric` item's `check` cannot be derived exactly THEN it is collected as an `UncheckableItem` with
  its reason and the acceptance test FAILS. Since this task cannot edit `check` or `prompt_latex` (§2
  out-of-scope), a non-empty uncheckable list is a **blocking dependency gap on 01.6.1's `check`
  authoring** to report, never a reason to widen the allow-list, add a numeric fallback, round a result, or
  hand-code a per-item exception. The allow-list and the failure list are contract text
  (`contracts/data-model.md` § Probe answer derivation, quoted in §3); extending them is a versioned
  contract change, which is never this task's to make.
- IF `verify_numeric_answers` reports an `AnswerMismatch` THEN **do not immediately edit anything.** First
  read that item's `check` against its `prompt_latex` by hand and decide which of the two is wrong. If the
  `check` mis-declares the prompt, it is a blocking gap on 01.6.1 — report it with the item id, the
  derived value and the declared value; correcting `answer.value` in that case would launder a wrong
  derivation into the bundle, which is precisely what I1 forbids. Only if the `check` faithfully declares
  the prompt is the hand-authored `answer.value` the wrong one, and then it is corrected to the
  SymPy-derived value (in-scope per §2's "answer … corrections") and re-run. Never adjust `answers.py`'s
  derivation to make a value pass (I1: the CAS decides correctness, not the other way around).
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
  add a `-m` filter anywhere that would cause the network test to be skipped in the gate (planner
  note [6], quoted in §3).
- IF the fetched landmark page's character case differs from the landmark's stored `source_title` THEN use
  a case-insensitive substring match (`page_contains`, §4 step 4) — matching the domain doc's "unescaped
  substring match acceptable" reading already used by task 01.5 for the same landmark, and fixed by
  `contracts/content-policy.md` § Landmarks v1.1.0 ("case-insensitive substring").

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
