# Epic 01 · Task 07a: CAS parse sandbox — close the `check` parse environment with an AST-shape allow-list

---
epic: 01
task: 07a
slug: cas-parse-sandbox
kind: fix
risk: seam
depends_on: [01.7]
model: sonnet
---

> **Origin.** The 01.7 tester filed `tasks/blocked/tester-blocked-01-07.md` (class `bug-found`), and the
> owner reproduced the finding directly on 2026-09-09 against the shipped `ALLOWED_NAMES`/`TRANSFORMATIONS`.
> The CAS parse environment that `contracts/data-model.md` § Probe answer derivation calls a "closed name
> allow-list" is not closed: it admits arbitrary code execution. This task is the fix. It lands **on task
> 01.7's branch**, ahead of 01.7's merge — 01.7 cannot be merged with two red security tests, and the fix
> touches 01.7's own source file, so the two ship as one green PR with 01.7's tester re-running afterwards.
> This task takes sole write ownership of `pipeline/src/mathmath_pipeline/verify/answers.py` and
> `pipeline/tests/test_verify_allowlist_closure.py` for its duration; no other in-flight task writes either.

## §1 Goal & acceptance criteria

Goal: make the parse environment used to derive `numeric` probe answers **structurally closed** — an
authored or generated `check.expr` / `check.equations[]` / `at` value can construct and evaluate an inert
SymPy expression and can do nothing else — by validating the exact source that `sympy.parse_expr` is about
to `eval` against a **closed allow-list of AST node types**, inside the shared `TRANSFORMATIONS` tuple so no
caller can bypass it; and correct `contracts/data-model.md` § Probe answer derivation (v1.1.0 → **v1.2.0**)
to describe the algorithm that is actually required, both the shape restriction and the true name list.

### The defect, stated exactly

`contracts/data-model.md:88-89` promises: "a **closed name allow-list**: `Eq`, `Rational`, `sqrt`, `log`,
`exp`, `Abs`, `diff`, `pi`, `E`. Any other name parses to a free symbol; calling one raises." That sentence
describes protection against resolving a disallowed **name**. Python attribute access is not name
resolution, and `sympy.parse_expr` evaluates its transformed source with `eval`
(`.venv/.../sympy/parsing/sympy_parser.py:905-907`, `eval(code, global_dict, local_dict)`). `sympy`'s
`auto_symbol` explicitly declines to rewrite attribute access (`sympy_parser.py:547-548`, comment "Don't
convert attribute access"), so a dotted chain reaches `eval` untouched. Therefore

```
().__class__.__bases__[0].__subclasses__()
```

parses and **executes**, using zero allow-listed names (`()` is a bare tuple literal), and returns every
class loaded in the process — including `subprocess.Popen`, one call away from a shell. The tester's manual
transcript (`tasks/blocked/tester-blocked-01-07.md:38-50`) executed a real `id` command and returned its
real stdout through `derive_from_check`'s own parse path. `_evaluate`'s downstream
`isinstance(parsed, sympy.Expr)` check cannot help: the side effect completes inside `parse_expr`, before
the check runs. `check` strings are hand-authored in `data/demo` today, but EPICs 05–09 generate them with a
model — a model-generated `check` flowing into an escapable parser lets model output execute arbitrary code,
which is a worse breach of I1 than the problem `check` was introduced to solve.

Invariants in play:

- **I1** — the CAS decides correctness. A parse environment in which an input can execute arbitrary code is
  a parse environment in which the input, not the CAS, decides the outcome. Closing it is I1 work, and the
  fix must not relax any existing derivation rule to make a value pass.
- **I2** — not engaged: this task has zero model-calling paths, therefore no confidence threshold and no
  Tier-0 fallback applies. `verify/` imports no model client and calls no model (recorded, not omitted).
- **I9** — zero human content review. The defence against bad generated content is machine verification; a
  verifier that can be subverted by the content it verifies is the load-bearing failure this task repairs.
  No "someone eyeballs the `check` strings" step may be introduced as mitigation.
- **I14** — `Core` is untouched. The derivation and its sandbox are pipeline-owned
  (`docs/tech-stack.md:67`), and exist once (C1) in `verify/answers.py`.

Acceptance criteria (each independently verifiable; each names its instrument and its anti-vacuity guard):

- **AC1 — the documented escape is rejected.** The exact string `().__class__.__bases__[0].__subclasses__()`
  is rejected by `UnsafeCheckSource` before any evaluation occurs, on **both** entry paths: (a) directly
  through `sympy.parse_expr(src, transformations=TRANSFORMATIONS, global_dict=ALLOWED_NAMES, local_dict={})`
  — proving the guard rides on the shared module constants and cannot be bypassed by a caller who uses them
  — and (b) through `derive_from_check({"kind": "evaluate", "expr": src})`, which raises `UncheckableCheck`
  whose `.reason` names the rejected node type.
  Instrument: the two named tests of AC7 in `pipeline/tests/test_verify_allowlist_closure.py`.
  Anti-vacuity: the same tests assert the raised exception's message contains the literal token `Attribute`
  — an exception raised for an unrelated reason (a typo, a `SyntaxError`, an `ImportError`) does not satisfy
  this AC.
- **AC2 — a battery of related escapes is rejected.** Every entry of the parametrized battery in §5 T2
  raises `UnsafeCheckSource` through both entry paths of AC1: attribute chains, dunder access from an
  allow-listed value, subscript walks, slices, comprehensions and generator expressions, `lambda`, string and
  bytes literals used as payload carriers, keyword arguments, starred arguments, tuple/list/dict/set
  displays, comparison and boolean operators, conditional expressions, f-strings, and the walrus operator.
  Instrument: `test_escape_battery_is_rejected` (parametrized).
  Anti-vacuity: the test asserts `len(_ESCAPE_BATTERY) >= 18` [SOURCED: the battery enumerated in §5 T2 has
  20 entries] so that a battery silently emptied by a bad edit fails rather than passes, and asserts each
  entry's rejection message names a node type from `AST_ALLOWED_NODE_NAMES`' complement, never a generic
  message.
- **AC3 — all 20 landed `check` objects still derive their recorded answers, unchanged.** Over the real
  committed `data/demo/nodes.json`, `verify_numeric_answers` returns `([], [])` and the number of `numeric`
  items derived is exactly **20** [SOURCED: `tasks/epic-01-task-06.1-contract-v1-1-probe-check.md` §4 step 6
  pins 20 `check` objects; 01.7 AC2 asserts the same count]. No `check` string, no `answer.value`, and no
  `tolerance` in `data/demo/nodes.json` is edited by this task — the file is out of scope (§2), so a
  derivation that changes is a blocking gap, not a data edit.
  Instrument: `cd pipeline && uv run pytest tests/test_demo_bundle.py -q` (01.7's committed companion test,
  unmodified) plus `test_all_twenty_landed_checks_survive_the_guard` in this task's own test file, which
  loads `data/demo/nodes.json`, derives every `numeric` item, and compares against a **table of the 20
  expected values pinned in this spec (§4 step 5)**, not against the file's own `answer.value`.
  Anti-vacuity: that test asserts it compared exactly 20 items and that its pinned table has exactly 20 rows;
  a bundle that shrank, a walk that visited nothing, and a table that was trimmed all fail.
- **AC4 — the validated string is the evaluated string.** For every one of the 20 landed checks (and every
  `at` value), the source the guard validates is **byte-identical** to the string
  `sympy.parsing.sympy_parser.stringify_expr` produces for the same input with the same transformations —
  i.e. there is no window in which one string is checked and another is evaluated.
  Instrument: `test_guard_validates_the_exact_string_that_is_evaluated`, which captures the guard's input via
  a recording hook and compares byte-for-byte against an independent `stringify_expr` call.
  Anti-vacuity: the test asserts it captured ≥ 20 strings and that at least one captured string differs from
  the raw authored source (proving it is the *transformed* code being compared, not the input echoed back).
- **AC5 — negative control: the guard itself can fail.** A test reconstructs the pre-fix transformations
  tuple locally (`standard_transformations + (rationalize,)`, i.e. the guard removed) and asserts that under
  it the AC1 escape **does** evaluate and **does** return live classes from `subprocess`, `os` or `builtins`.
  This proves the vulnerability is real, that the guard is the thing preventing it, and that a future edit
  deleting the guard would red rather than pass.
  Instrument: `test_negative_control_without_the_guard_the_escape_still_executes`.
  Anti-vacuity: the test asserts the returned list is non-empty and that the dangerous-name list it computes
  is non-empty — a control that finds nothing dangerous is itself a FAIL of this AC. This test walks the
  class graph only; it never instantiates or calls any class it reaches, so no process is spawned in CI.
- **AC6 — the name list is corrected, in the contract and in the code, and they agree.**
  `contracts/data-model.md` § Probe answer derivation names **eleven** names, distinguishing the nine
  semantic names from the two structural constructors (`Symbol`, `Integer`) and stating why the latter are
  mechanically required; `ALLOWED_NAMES` contains exactly those eleven keys.
  Instrument: `test_allowed_names_match_the_contract`, which asserts `set(ALLOWED_NAMES) == frozenset` of the
  eleven literal strings written out in the test itself (reconstructed independently of the module, as the
  existing file already does at `_NINE_NAME_ALLOWLIST`), and a text assertion that
  `contracts/data-model.md` contains the literal phrase `structural constructors`.
  Anti-vacuity: the test asserts the reconstructed set has exactly 11 members and that `ALLOWED_NAMES` is
  non-empty.
- **AC7 — the tester's two currently-RED evidence tests are GREEN, by the escape being blocked.** The two
  functions `test_allowlist_is_escapable_to_the_live_interpreter_class_graph` and
  `test_reaching_subprocess_popen_as_a_live_class_object_is_the_only_step_short_of_shell_execution` in
  `pipeline/tests/test_verify_allowlist_closure.py` keep their names, keep `_ESCAPE_EXPR` as the exact string
  above, and keep the security property they assert. They are **never** deleted, never skipped, never
  `xfail`ed, never marked, and their property is never softened. Their bodies change in exactly one way,
  mandated by §4 step 6: from "parse, then inspect the returned value for dangerous classes" to "assert the
  parse is **rejected** before it returns anything". See §6 for why this instrument change is the only way
  the property can hold, and why it is strictly stronger, not weaker.
  Instrument: `cd pipeline && uv run pytest tests/test_verify_allowlist_closure.py -q` green, with a
  collected count ≥ the pre-fix count [SOURCED: the pre-fix file collects 21 test cases after parametrized
  expansion; the post-fix file must collect strictly more, since this task only adds].
  Anti-vacuity: AC5 is this AC's negative control.
- **AC8 — no existing guard is weakened.** The three build-failing conditions of
  `contracts/data-model.md` § Probe answer derivation — (i) a parse or derivation failure
  (`LO_PROBE_UNCHECKABLE`), (ii) a derived value that is not an exact rational after `sympy.simplify`, and
  (iii) a derived value differing from `answer.value` beyond `tolerance` — all still fail the build, and no
  test anywhere in the repository is deleted, skipped, `xfail`ed, mocked out, or has an assertion removed by
  this task. The AST guard is an **additional** failure clause appended to that list, never a replacement.
  Instrument: `cd pipeline && uv run pytest -q` green with a collected-test count strictly greater than the
  pre-fix run [SOURCED: `tasks/blocked/tester-blocked-01-07.md:95` records 144 passing before the two red
  tests], plus 01.7's own T5 negative controls (`factorial(3)`, leftover free symbol, unsolvable equation)
  unchanged and still green.
  Anti-vacuity: the implementer records both collected counts in the PR description; a count that fell is a
  FAIL of this AC.
- **AC9 — the contract change is versioned and auditable.** `contracts/data-model.md`'s `Contract version`
  reads `v1.2.0`, its § Probe answer derivation carries the replacement text pinned in §4 step 1 verbatim,
  and the commit that carries it uses the scope `contract(data-model)`.
  Instrument: `rg -n "Contract version" contracts/data-model.md` shows `v1.2.0`; `git log --oneline` shows
  the scope.
  Anti-vacuity: a test in this task's file asserts `contracts/data-model.md` contains the literal strings
  `restrict_ast_shape`, `ast.Attribute`, and `v1.2.0`, so a contract left un-edited reds the suite rather
  than passing silently.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `contracts/data-model.md` — MODIFY. The `Contract version` line (`:3`) and § Probe answer derivation
  (`:82-102`) only. **No other section, and no other file under `contracts/`.** No JSON Schema changes: the
  data *shape* of `check` is unchanged by this task; only the normative rule for how `check` is parsed
  changes. `contracts/schemas/**`, `contracts/examples/**`, `contracts/content-policy.md`,
  `contracts/error-codes.*` are untouched — no new error code is registered (`LO_PROBE_UNCHECKABLE` already
  covers "a parse failure … fails the build", `contracts/error-codes.json`, quoted in §3).
- `pipeline/src/mathmath_pipeline/verify/answers.py` — MODIFY. Add the AST guard, wire it into
  `TRANSFORMATIONS`, correct the module docstring and the `ALLOWED_NAMES` comment to the corrected contract
  text. `derive_from_check`, `verify_numeric_answers`, `_evaluate`, `_solve`, `UncheckableCheck`,
  `UncheckableItem`, `AnswerMismatch`, `LO_PROBE_UNCHECKABLE` keep their existing names and signatures
  exactly — 01.7's spec §4 step 2 pins them and `pipeline/tests/test_demo_bundle.py` imports them.
- `pipeline/tests/test_verify_allowlist_closure.py` — MODIFY. Retarget the two RED evidence tests per §4
  step 6 (names and property preserved, AC7), and add this task's new tests (§5).

**Write authority over `contracts/data-model.md` for this task only.** `contracts/` is read-only to every
agent by standing rule (`CLAUDE.md` RULE 5), and a change to a LOCK-FIRST contract is a versioned owner
decision. The authorizing act is the owner's direct reproduction and ruling of 2026-09-09 recorded in this
spec's Origin block and in `tasks/blocked/tester-blocked-01-07.md`; the auditable form is the version bump
plus the `contract(data-model)` commit scope required by `contracts/README.md:42-44` (quoted in §3). This is
a **correction of contract text that is factually wrong about its own algorithm** — a contract that promises
a closed environment which is not closed, and that names nine names when the algorithm mechanically requires
eleven. It changes **no locked decision D1–D49**, no data shape, and no error code. Nothing in `contracts/`
outside the two passages of `contracts/data-model.md` named above may be touched; if the implementer
believes another contract must change, that is a Q5 stop, not an edit.

Out-of-scope (do not touch even if tempted):

- `data/demo/nodes.json` — the 20 `check` objects are the **compatibility constraint**, not a variable. If
  any of the 20 stops deriving its recorded value under the guard, the guard is wrong and must be corrected;
  the data is never edited to fit the guard (§6). Editing this file is also 01.7's narrow authority
  (`answer.value` / `error_type_id` corrections only), never this task's.
- `pipeline/tests/test_demo_bundle.py` — 01.7's committed companion test. It must stay green **unmodified**;
  that is AC3's primary instrument, and modifying it would destroy the instrument.
- `pipeline/src/mathmath_pipeline/verify/distractors.py`, `verify/landmarks.py`, `verify/__init__.py` —
  01.7's files, unrelated to the parse environment. `__init__.py` re-exports public functions; the new guard
  symbols are consumed only by `answers.py` and its test, so no re-export is needed and none is added.
- `Packages/Core/**`, `App/**`, `Packages/Rendering/**` — `Core` never parses a `check`
  (`tasks/epic-01-task-06.1-contract-v1-1-probe-check.md` §4 step 7: "`Core` carries it so a bundle
  re-encode preserves it; `Core` never parses or evaluates it"). I14: no L0 rule, no `Core` code.
- `pipeline/pyproject.toml`, `pipeline/uv.lock`, `docs/tech-stack.md` — **no new dependency.** `ast` and
  `tokenize` are Python standard library and need no pin (the same reasoning
  `tasks/epic-01-task-07-pipeline-content-verification.md` §4 step 4 applied to `urllib`). A spec that pins
  a tool `docs/tech-stack.md` does not name is drifted; this task pins none.
- `docs/epics/epic-01-*.md` — the EPIC brief is `brief-amender`'s file. Its §3 I1 clause
  (`docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:51-54`) stays true word-for-word under this change
  — the pipeline still re-derives every answer from `check` alone with SymPy and never with a model — so no
  amendment is owed.
- `docs/domains/*.md` — domain docs sit below contracts in the ground-truth order
  (`contracts/README.md:4-6`); `learning-objects.md` W1 step 5 is unaffected word-for-word.
- Any subprocess, container, `seccomp`, `resource`-limit or separate-interpreter machinery. Rejected on
  RULE 2 grounds in §6.

## §3 Inputs (verbatim — do not paraphrase)

The reproduced defect:

- `tasks/blocked/tester-blocked-01-07.md:17-29`:
  > It is not closed. The allow-list restricts which bare *names* an expression may reference, but places no
  > restriction on **attribute access on the object any allowed value returns**. Python attribute/dunder
  > access is not name resolution, so it is invisible to a `global_dict`-based allow-list entirely. Starting
  > from a plain tuple literal `()` — which requires no allow-listed name at all — the expression
  >
  > ```
  > ().__class__.__bases__[0].__subclasses__()
  > ```
  >
  > parses and *executes* successfully under `sympy.parse_expr(source, transformations=TRANSFORMATIONS,
  > global_dict=ALLOWED_NAMES, local_dict={})` using the exact `ALLOWED_NAMES`/`TRANSFORMATIONS` shipped in
  > `pipeline/src/mathmath_pipeline/verify/answers.py`. It returns a Python `list` of every class currently
  > loaded in the process — including `subprocess.Popen`.
- `tasks/blocked/tester-blocked-01-07.md:52-56`:
  > This executed a real `id` shell command and returned its real stdout, entirely through
  > `derive_from_check`'s own parse path — before any downstream type check (`isinstance(parsed,
  > sympy.Expr)`) gets a chance to reject the result. The side effect (arbitrary shell execution) happens as
  > part of `sympy.parse_expr`'s own evaluation; the fact that `_evaluate` later raises `UncheckableCheck`
  > because the final value isn't a SymPy `Expr` does **not** undo the side effect — it has already
  > completed.

The contract text being replaced:

- `contracts/data-model.md:87-90` (§ Probe answer derivation):
  > Parsing is `sympy.parse_expr` with `standard_transformations + (rationalize,)` — so decimal literals
  > become exact `Rational`s — and a **closed name allow-list**: `Eq`, `Rational`, `sqrt`, `log`, `exp`,
  > `Abs`, `diff`, `pi`, `E`. Any other name parses to a free symbol; calling one raises, and the item
  > fails. Extending the allow-list is a versioned change.
- `contracts/data-model.md:98-102` (the failure list, **kept**; one clause is appended to it by §4 step 1):
  > The derived value must be an exact rational after `sympy.simplify` (`.is_Rational` true). A parse
  > failure, an unknown name, a leftover free symbol, an unbound `unknown`, zero solutions, more than one
  > solution under `select: only`, or a non-rational result is `LO_PROBE_UNCHECKABLE` and **fails the
  > build**. Nothing is rounded, nothing is approximated, nothing is inferred. The derived value is then
  > compared to `answer.value` within `answer.tolerance` (default `0`); a mismatch fails the build.

The procedure a locked-contract change must follow:

- `contracts/README.md:42-44` (§ Lock-first rule):
  > A change to a locked contract is a **versioned** change: bump `Contract version`, ripple to every
  > conforming EPIC, and flag the commit scope (`contract(<name>)`) so the ripple is auditable.

The upstream facts that make the escape work (verified by direct read of the pinned `sympy` 1.14
[SOURCED: `docs/tech-stack.md:27`, "sympy ≥ 1.14,<2 … resolved 2026-09-09: sympy 1.14.0"]):

- `pipeline/.venv/lib/python3.14/site-packages/sympy/parsing/sympy_parser.py:899-907`:
  > ```python
  > def eval_expr(code, local_dict: DICT, global_dict: DICT):
  >     """
  >     Evaluate Python code generated by ``stringify_expr``.
  >
  >     Generally, ``parse_expr`` should be used.
  >     """
  >     expr = eval(
  >         code, global_dict, local_dict)  # take local objects in preference
  >     return expr
  > ```
- `sympy_parser.py:545-548` (inside `auto_symbol`) — why a dotted chain survives the transformations:
  > ```python
  >                 if (name in ['True', 'False', 'None']
  >                         or iskeyword(name)
  >                         # Don't convert attribute access
  >                         or (prevTok[0] == OP and prevTok[1] == '.')
  > ```
- `sympy_parser.py:880-896` — the transformation pipeline and the exact string that is evaluated:
  > ```python
  > def stringify_expr(s: str, local_dict: DICT, global_dict: DICT,
  >         transformations: tuple[TRANS, ...]) -> str:
  >     tokens = []
  >     input_code = StringIO(s.strip())
  >     for toknum, tokval, _, _, _ in generate_tokens(input_code.readline):
  >         tokens.append((toknum, tokval))
  >
  >     for transform in transformations:
  >         tokens = transform(tokens, local_dict, global_dict)
  >
  >     return untokenize(tokens)
  > ```
- `sympy_parser.py:875-877` — the tuple this task extends:
  > ```python
  > standard_transformations: tuple[TRANS, ...] \
  >     = (lambda_notation, auto_symbol, repeated_decimals, auto_number,
  >        factorial_notation)
  > ```
- `sympy_parser.py:1075` — `stringify_expr` (and therefore every transformation, including this task's) runs
  **outside** `parse_expr`'s `try`/`except`, so a guard exception propagates to the caller unwrapped:
  > ```python
  >     code = stringify_expr(s, local_dict, global_dict, _transformations)
  > ```
- `sympy_parser.py:916-918` — `sympy`'s own warning, which is precisely the property the contract wrongly
  claimed to have neutralised with a name list:
  > ```
  >     .. warning::
  >         Note that this function uses ``eval``, and thus shouldn't be used on
  >         unsanitized input.
  > ```

The evidence file this task must turn green without weakening (its two red functions, verbatim as committed
at tester commit `46a5134`):

- `pipeline/tests/test_verify_allowlist_closure.py:161-178`:
  > ```python
  > def test_allowlist_is_escapable_to_the_live_interpreter_class_graph() -> None:
  >     """THE CENTRAL CHARGE, empirically, RED: the closed nine-name allow-list does not hold. This test
  >     asserts the security property the contract promises (no interpreter-internal class reachable) and
  >     currently FAILS against the shipped `ALLOWED_NAMES`/`TRANSFORMATIONS` ...
  >     """
  >     parsed = sympy.parse_expr(
  >         _ESCAPE_EXPR, transformations=TRANSFORMATIONS, global_dict=ALLOWED_NAMES, local_dict={}
  >     )
  >     assert isinstance(parsed, list)
  > ```
- `pipeline/tests/test_verify_allowlist_closure.py:181-196` — the second red function, same shape,
  asserting `subprocess.Popen` is not reachable.

The mechanical justification for the two extra names, reproduced by the tester and therefore a fact the
corrected contract must state rather than contradict:

- `pipeline/tests/test_verify_allowlist_closure.py:48-55` (green, unmodified by this task):
  > `standard_transformations`' `auto_number` rewrites the literal `2` into a call `Integer(2)`; with only
  > the nine allow-listed names bound, `Integer` is unresolved and parsing raises `NameError`, reproducing
  > exactly the failure the implementer's justification cites.

The error code this task raises under (already registered; no new code):

- `contracts/error-codes.json`:
  > `{"code": "LO_PROBE_UNCHECKABLE", "recoverable": true, "surface": "internal", "user_text": null},`

Ownership and generation-scale stakes:

- `docs/tech-stack.md:67`:
  > `pipeline/` — curriculum-spine, content-generation, learning-objects validation, telemetry aggregation
  > (W4).
- `CLAUDE.md` (Hard invariants, I9):
  > **Zero human content review** — content is generated + machine-verified; disputed edges ship at low
  > confidence, settled by probe data. Never add an "owner reviews content" step.

## §4 Implementation outline

### 1. `contracts/data-model.md` — the versioned correction (do this first; it is the specification)

Replace the version line at `contracts/data-model.md:3` with:

```
**Contract version:** v1.2.0 · Source: brief v2 §5 as amended (D20–D22, D32, D33, D43–D48), `docs/domains/*.md`; v1.1.0 adds `ProbeItem.check` and `Landmark.source_title` (owner Q5 ruling 2026-09-09, `tasks/blocked/Q5-RULING-01-07.md`); v1.2.0 corrects § Probe answer derivation — the name allow-list alone does not close the parse environment, so an AST-shape allow-list is added and the true name list is stated (owner ruling 2026-09-09 on `tasks/blocked/tester-blocked-01-07.md`)
```

Replace the paragraph at `contracts/data-model.md:87-90` (quoted in §3) with exactly this text:

```
Parsing is `sympy.parse_expr` with `standard_transformations + (rationalize, restrict_ast_shape)` — so
decimal literals become exact `Rational`s — under **two** closed allow-lists, a name allow-list and an
AST-shape allow-list. Both are required. A name allow-list alone does **not** close the parse environment:
`parse_expr` evaluates its transformed source with `eval`, and Python attribute access, subscripting and
literal construction are not name resolution, so an expression using no allow-listed name at all can walk
out of the intended sandbox. Enumerating forbidden spellings does not close it either; only enumerating the
permitted shape does.

**Names (eleven).** The nine *semantic* names an author may write are `Eq`, `Rational`, `sqrt`, `log`,
`exp`, `Abs`, `diff`, `pi`, `E`. Two *structural constructors*, `Symbol` and `Integer`, must additionally be
bound: `standard_transformations` mechanically rewrites every bare name into `Symbol('<name>')` and every
integer literal into `Integer(<n>)` before evaluation, and supplying a custom `global_dict` removes SymPy's
default namespace, so without these two no legitimate check parses at all. They construct inert values and
add no reachable capability. Any name outside the eleven parses to a free symbol; calling one is rejected.
Extending the eleven is a versioned change.

**Shape.** The transformed source — the exact string that would be evaluated — is parsed with
`ast.parse(source, mode="eval")` and validated **before** evaluation against a closed allow-list of AST node
types. Permitted, exhaustively: `Expression`, `BinOp`, `UnaryOp`, `Call`, `Name`, `Load`, `Constant`, and
the operator nodes `Add`, `Sub`, `Mult`, `Div`, `Pow`, `UAdd`, `USub`. In addition every `Name.id` must be
one of the eleven allowed names; every `Constant.value` must be of exact type `int`, `float` or `str`; and
every `Call` must carry no keyword arguments. Every other node Python's grammar admits is rejected —
`ast.Attribute`, `ast.Subscript`, `ast.Slice`, `ast.Lambda`, every comprehension and `ast.GeneratorExp`,
`ast.Tuple`, `ast.List`, `ast.Dict`, `ast.Set`, `ast.Starred`, `ast.keyword`, `ast.Compare`, `ast.BoolOp`,
`ast.IfExp`, `ast.JoinedStr`, `ast.NamedExpr`, and the remaining operators including `Mod`, `FloorDiv`,
`MatMult` and every bitwise operator. Extending the permitted node set is a versioned change. The string
validated must be byte-identical to the string evaluated: validating one string and evaluating another is
not a guard, so the check runs as the final transformation, inside the parse pipeline, where no caller can
step around it.
```

Append one clause to the failure list at `contracts/data-model.md:98-102`, so that its second sentence reads
(the rest of the paragraph is unchanged):

```
A parse failure, an unknown name, a source whose transformed AST leaves the permitted node set or carries a
keyword argument, a leftover free symbol, an unbound `unknown`, zero solutions, more than one solution under
`select: only`, or a non-rational result is `LO_PROBE_UNCHECKABLE` and **fails the build**.
```

Nothing else in `contracts/data-model.md` changes.

### 2. `verify/answers.py` — the guard

Add, at module level, after `TRANSFORMATIONS`' current definition site and before it is rebuilt:

```python
class UnsafeCheckSource(Exception):
    """Raised when a `check` source's transformed AST leaves the permitted node set (data-model v1.2.0)."""

    def __init__(self, reason: str) -> None:
        super().__init__(reason)
        self.reason = reason
```

- `AST_ALLOWED_NODES: frozenset[type[ast.AST]]` — exactly the fourteen types the contract names:
  `ast.Expression`, `ast.BinOp`, `ast.UnaryOp`, `ast.Call`, `ast.Name`, `ast.Load`, `ast.Constant`,
  `ast.Add`, `ast.Sub`, `ast.Mult`, `ast.Div`, `ast.Pow`, `ast.UAdd`, `ast.USub`. Write it as a literal
  `frozenset({...})`, never computed from `dir(ast)` or by subtraction from a forbidden set — an allow-list
  derived by subtraction is a blocklist wearing a hat.
- `AST_ALLOWED_NODE_NAMES: frozenset[str]` — `frozenset(node.__name__ for node in AST_ALLOWED_NODES)`,
  exported for the tests' messages.
- `_ALLOWED_CONSTANT_TYPES: tuple[type, ...] = (int, float, str)` — matched by `type(value) in ...`, never
  `isinstance`, so `bool` (a subclass of `int`) is rejected along with `bytes`, `complex`, `None` and
  `Ellipsis`.
- `restrict_ast_shape(tokens, local_dict, global_dict)` — a `sympy` transformation with that exact
  three-argument signature. It:
  1. renders the *current* token stream with `tokenize.untokenize(list(tokens))` — a copy, so the list it
     was handed is not mutated;
  2. `ast.parse(code, mode="eval")` (a `SyntaxError` propagates unmodified — that is a parse failure, not a
     shape violation, and `_parse` already converts it);
  3. walks the tree with `ast.walk`; for each node, if `type(node) not in AST_ALLOWED_NODES` raises
     `UnsafeCheckSource` naming the node type (`f"disallowed AST node {type(node).__name__}"`);
  4. for each `ast.Name`, if `node.id not in ALLOWED_NAMES` raises `UnsafeCheckSource` naming the name;
  5. for each `ast.Constant`, if `type(node.value) not in _ALLOWED_CONSTANT_TYPES` raises, naming the type;
  6. for each `ast.Call`, if `node.keywords` is non-empty raises, naming `keyword`;
  7. returns `tokens` **unchanged and unwrapped** — it is a validator, not a rewriter, so the string sympy
     goes on to `untokenize` is byte-identical to the string validated (AC4).
- Rebuild the shared constant as `TRANSFORMATIONS = standard_transformations + (rationalize, restrict_ast_shape)`.
  The guard is **last**: it must see the fully transformed stream, because that is what is evaluated.
  `ALLOWED_NAMES` keeps its name, its eleven keys and its module-level position — the test file imports both
  constants and passes them to `sympy.parse_expr` directly (AC1(a)); welding the guard into the tuple is
  what makes that path safe too, and is the reason a wrapper around `_parse` would not have been enough.
- `_parse` gains one `except UnsafeCheckSource as exc:` clause **before** its existing `except Exception`,
  re-raising `UncheckableCheck(f"unsafe check source: {exc.reason}")`. The broad clause stays; the narrow
  one only makes the reason legible.
- Update the module docstring and the `ALLOWED_NAMES` comment block (`answers.py:1-11`, `:27-35`) to the
  corrected contract text: nine semantic names plus two structural constructors, name allow-list plus AST
  shape allow-list, contract v1.2.0. The current docstring's claim "a closed nine-name allow-list … calling
  one raises" is the false claim this task exists to retire; it must not survive anywhere in the file.

### 3. Ordering and typing notes

- Import `ast` and `from tokenize import untokenize` at module top. Both are standard library.
- `pyright` strict: `ast` is fully typed. `untokenize` accepts an iterable of 2-tuples and returns `str`; if
  the stub's parameter type requires it, annotate the local as `list[tuple[int, str]]` and pass that. Do not
  add a `pyright: ignore` for anything except the pre-existing `sympy` no-stub cases already in the file.
- Do not touch the existing `# pyright: ignore[...]` comments on the `sympy` member references.

### 4. What this fix does NOT do

- It does not change `ALLOWED_NAMES`' membership. The escape uses zero allow-listed names, so narrowing the
  list would not have closed it and widening it would not be needed
  (`tasks/blocked/tester-blocked-01-07.md:58-70`).
- It does not add a substring, regex or "reject any source containing `__`" test anywhere. That is a
  blocklist; §6 records why it is refused.
- It does not spawn a subprocess, drop privileges, or set resource limits.
- It does not alter `sympy.solve`, `sympy.simplify`, the rational-exactness rule, the `at`-substitution
  rule, or the comparison against `answer.value`.

### 5. The compatibility table — the 20 landed checks, pinned (AC3)

The guard is correct only if every one of these still derives its recorded value. Pin this table in the
test, not in a comment [SOURCED: the 20 rows are read from `data/demo/nodes.json` and match
`tasks/epic-01-task-06.1-contract-v1-1-probe-check.md` §4 step 6 row for row]:

| # | item id | `check` source strings the guard sees | derives |
|---|---|---|---|
| 1 | `integer-operations-1` | `-3 - (-7)` | `4` |
| 2 | `order-of-operations-1` | `2 + 3*4` | `14` |
| 3 | `rational-numbers-1` | `1/2 + 1/3` | `5/6` |
| 4 | `exponent-laws-1` | `Eq((2**3)**2, 2**k)` | `6` |
| 5 | `scientific-notation-1` | `3.2*10**4` | `32000` |
| 6 | `linear-relations-1` | `diff(3*x + 5, x)` | `3` |
| 7 | `solving-linear-equations-1` | `Eq(2*x + 3, 11)` | `4` |
| 8 | `solving-systems-of-equations-1` | `Eq(x + y, 10)`, `Eq(x - y, 2)` | `6` |
| 9 | `simplifying-expressions-1` | `diff(3*x + 5*x, x)` | `8` |
| 10 | `polynomials-1` | `diff((3*x**2 + 2*x) + (x**2 + 5*x), x, 2)/2` | `4` |
| 11 | `factoring-1` | `x**2 + 5*x + 6`, `at x = 0` | `6` |
| 12 | `solving-quadratics-1` | `Eq(x**2 - 5*x + 6, 0)`, `select: max` | `3` |
| 13 | `rational-expressions-1` | `(x**2 - 9)/(x - 3)`, `at x = 5` | `8` |
| 14 | `quadratic-functions-1` | `Eq(diff((x - 3)**2 + 4, x), 0)` | `3` |
| 15 | `function-concept-1` | `2*x + 1`, `at x = 3` | `7` |
| 16 | `function-transformations-1` | `x - (x - 4)` | `4` |
| 17 | `function-notation-1` | `3*x - 2`, `at x = 4` | `10` |
| 18 | `domain-and-range-1` | `Eq(x - 3, 0)` | `3` |
| 19 | `exponential-functions-1` | `3**x`, `at x = 2` | `9` |
| 20 | `logarithms-1` | `log(8, 2)` | `3` |

Why the permitted node set is sufficient for all 20 (check this reasoning against the real
`stringify_expr` output during implementation; if any row needs a node outside the set, **stop and report**,
per §6 — do not widen the set silently): after `standard_transformations + (rationalize,)`, every bare name
becomes `Symbol('…')` (`Call`/`Name`/`Constant[str]`), every integer literal becomes `Integer(…)`
(`Call`/`Name`/`Constant[int]`), and every float becomes `Rational('…')` (`Call`/`Name`/`Constant[str]` —
`auto_number` emits `Float(repr(str(n)))` and `rationalize` renames `Float`→`Rational` and retypes the
argument token to a `STRING`, `sympy_parser.py:773-780`, `:788-804`), which is why `str` constants are
permitted. `Eq`, `diff` and `log` survive as bare `Name`s because they are present in `global_dict` and
callable (`auto_symbol`, `sympy_parser.py:551-560`), and all three are among the eleven. The only operators
used across the 20 are `+`, `-` (binary and unary), `*`, `/` and `**`. No row uses a tuple, a subscript, an
attribute, a keyword argument or a comparison.

### 6. Retargeting the two RED evidence tests (AC7)

The two functions keep their names, their docstrings' security property, and `_ESCAPE_EXPR`. Change only
the instrument, and add one sentence to each docstring recording the change and the date. Shape:

```python
def test_allowlist_is_escapable_to_the_live_interpreter_class_graph() -> None:
    """... (existing docstring, kept) ...

    2026-09-09: the property now HOLDS. The instrument changed with it: the pre-fix body parsed the escape
    and inspected the returned list, which presumes the parse succeeds. Under `restrict_ast_shape` the parse
    is refused before it evaluates anything, so the property is asserted as a refusal. Asserting "rejected
    before evaluation" is strictly stronger than asserting "evaluated, but returned nothing dangerous".
    """
    with pytest.raises(UnsafeCheckSource) as excinfo:
        sympy.parse_expr(
            _ESCAPE_EXPR, transformations=TRANSFORMATIONS, global_dict=ALLOWED_NAMES, local_dict={}
        )
    assert "Attribute" in str(excinfo.value)
```

The second function is the same, additionally asserting that `derive_from_check`/`_evaluate` on the same
string raises `UncheckableCheck` whose `.reason` contains `unsafe check source`, so the caller-visible path
is covered too. `_dangerous_subclass_names` is **kept**, not deleted — AC5's negative control uses it.

Nothing else in that file's sections 1, 2 and 4 changes, except as §5 T4 requires for the two tests that
call `sympy.parse_expr` with `TRANSFORMATIONS` on dotted sources
(`test_dunder_attribute_chain_from_symbol_reaches_the_live_class_graph`,
`test_integer_dunder_class_alone_does_not_expose_a_live_module_reference`).

### 7. Commit (the auditable ripple)

Two commits in the 01.7 PR, ahead of 01.7's own tester re-run:

1. `contract(data-model): the check parse environment is a name AND AST-shape allow-list (v1.2.0)` —
   `contracts/data-model.md`.
2. `fix(pipeline): reject unsafe check sources before evaluation (CVE-class eval escape)` —
   `pipeline/src/mathmath_pipeline/verify/answers.py`,
   `pipeline/tests/test_verify_allowlist_closure.py`.

The PR description states: the escape string, the two collected-test counts of AC8, the 20-row derivation
output of AC3, and the version bump.

## §5 Test plan (seam risk — full plan)

All tests live in `pipeline/tests/test_verify_allowlist_closure.py`.

- **T1 happy path.** `test_all_twenty_landed_checks_survive_the_guard` — load the real
  `data/demo/nodes.json`; for every `numeric` item derive via `derive_from_check`; assert the derived
  `Fraction` equals the value pinned for that item id in the §4 step 5 table (a module-level dict in the
  test, independent of the bundle's own `answer.value`). Anti-vacuity: assert the pinned table has exactly
  20 rows, assert exactly 20 items were derived, and assert every pinned item id was actually visited.
  (AC3.)
- **T2 negative — invalid input rejected at the boundary.** `test_escape_battery_is_rejected`, parametrized
  over `_ESCAPE_BATTERY`, each entry rejected on both entry paths of AC1. The battery, exactly
  [SOURCED: 20 entries]:
  1. `().__class__.__bases__[0].__subclasses__()` — the reported escape (attribute chain + subscript).
  2. `().__class__` — the minimal attribute step.
  3. `Symbol('x').__class__.__mro__` — attribute chain from an allow-listed value.
  4. `Integer.__module__` — dunder on a bare allow-listed name.
  5. `Integer(1).__class__.__base__.__subclasses__()` — the escape re-rooted on an allowed constructor.
  6. `pi.__class__` — attribute on an allow-listed constant.
  7. `[].__len__()` — attribute from a list display.
  8. `''.join` — attribute from a string literal.
  9. `(1,2)[0]` — subscript on a tuple display.
  10. `[1,2,3][0:2]` — slice.
  11. `[i for i in (1,2)]` — list comprehension.
  12. `(i for i in (1,2))` — generator expression.
  13. `{k: 1 for k in (1,)}` — dict comprehension.
  14. `(lambda: 1)()` — lambda.
  15. `Rational(1, 2) if 1 else 0` — conditional expression.
  16. `1 < 2` — comparison.
  17. `Integer(1) and Integer(2)` — boolean operator.
  18. `f"{Integer(1)}"` — f-string.
  19. `Eq(x, y, evaluate=False)` — keyword argument.
  20. `diff(*[1])` — starred argument.
  Anti-vacuity: `assert len(_ESCAPE_BATTERY) >= 18`; each case additionally asserts the rejection message
  names a concrete node type or name, never an empty or generic string. Entries 3 and 4 are the same
  expressions two currently-green tests in section 4 of the file parse successfully; those two tests are
  **retargeted, not deleted** (T4) — their point was that dunder access reaches live objects, and the point
  now is that it is refused. (AC2.)
- **T3 error taxonomy.** `test_unsafe_source_surfaces_as_the_registered_code` — assert
  `LO_PROBE_UNCHECKABLE == "LO_PROBE_UNCHECKABLE"` (the registered string, `contracts/error-codes.json`,
  quoted in §3); assert `verify_numeric_answers` on an in-memory `nodes_file` carrying one `numeric` item
  whose `check.expr` is `_ESCAPE_EXPR` returns exactly one `UncheckableItem`, with the right `node_id` and
  `item_id` and a `reason` containing `unsafe check source` — i.e. the failure is collected and reported
  per-item and reds the build, never swallowed. Assert no new error-code constant was introduced by scanning
  `verify/answers.py` for `LO_` tokens and asserting the set is exactly `{"LO_PROBE_UNCHECKABLE"}`
  (anti-vacuity: assert the scan read a non-empty file).
- **T4 conformance.** `test_allowed_names_match_the_contract` (AC6) and
  `test_contract_text_describes_the_shape_guard` — the latter reads `contracts/data-model.md` and asserts it
  contains the literal strings `restrict_ast_shape`, `ast.Attribute`, `structural constructors` and
  `v1.2.0`, and that it no longer contains the retired phrase `closed nine-name allow-list` anywhere in the
  repository's `contracts/` tree or in `verify/answers.py` (anti-vacuity: assert the file read was
  non-empty and ≥ 100 lines). Additionally, the two section-4 tests named in §4 step 6 are retargeted to
  `pytest.raises(UnsafeCheckSource)` with their names and docstring properties preserved and a dated note
  added, for the same reason as AC7's two: their bodies presume the parse succeeds.
- **T5 negative control for the guard** (AC5).
  `test_negative_control_without_the_guard_the_escape_still_executes` — build
  `_UNGUARDED = standard_transformations + (rationalize,)` locally in the test (reconstructed, not imported,
  so it cannot drift with the module), parse `_ESCAPE_EXPR` under it with `ALLOWED_NAMES`, assert the result
  is a non-empty `list`, and assert `_dangerous_subclass_names(result)` is **non-empty** and contains
  `"Popen"`. Comment in the test that this is the mutation control: delete `restrict_ast_shape` from
  `TRANSFORMATIONS` and AC1/AC2 red, while this test stays green — the pair pins the guard as the cause.
  This test reaches class objects only and never instantiates or calls one; it spawns no process, matching
  the tester's own reason for not committing the shell step.
- **T6 idempotency / no-leak.** `test_guard_is_a_validator_not_a_rewriter` — assert that for each of the 20
  landed sources, `restrict_ast_shape(tokens, {}, ALLOWED_NAMES) is tokens` (the same list object, returned
  unchanged) and that `stringify_expr(src, {}, ALLOWED_NAMES, TRANSFORMATIONS)` equals
  `stringify_expr(src, {}, ALLOWED_NAMES, _UNGUARDED)` byte-for-byte — the guard changes what is *accepted*
  and never what is *computed*, so no landed answer can shift under it. This is also AC4's byte-identity
  assertion. Anti-vacuity: assert ≥ 20 sources compared and that at least one transformed string differs
  from its raw source.

01.7's `pipeline/tests/test_demo_bundle.py` is not modified and must stay green; it is AC3's primary
instrument and AC8's regression instrument.

## §6 Decision defaults

- **IF** the question is which sandbox shape to build **THEN** it is an **allow-list of AST node types
  validated on the transformed source, as the final entry of `TRANSFORMATIONS`.** The three candidates the
  tester named (`tasks/blocked/tester-blocked-01-07.md:107-117`) resolve as follows, and this reasoning is
  not to be re-opened by the implementer:
  - *Dunder-substring rejection* — **refused.** It is a blocklist, and the lesson of this defect is that
    enumerating what is forbidden loses. It matches on spelling, not structure, so it is evaded by
    `getattr`-free but equally live paths (`[].__len__` is caught, `(1,2)[0]` is not; a future CPython or
    SymPy exposing a non-dunder route defeats it entirely), and it would have to reject `__` inside string
    literals to be even nominally sound.
  - *Subprocess or sandboxed-interpreter isolation* — **refused as disproportionate (RULE 2, "minimum code
    that solves the problem").** It adds a process boundary, a serialisation format, a timeout policy and a
    failure taxonomy to a build-time function whose entire job is to evaluate arithmetic; it does not by
    itself stop the escape, only contain it; and containment that still lets attacker-chosen code run inside
    the build is a weaker property than never running it. It is the right tool only if legitimate checks
    needed general Python, and they do not.
  - *AST node-type allow-list* — **chosen.** Attribute access, subscripting, comprehensions, lambdas,
    keyword arguments and displays are needed by **none** of the 20 landed checks (§4 step 5) and by no
    conceivable `check`, whose grammar is fixed by `contracts/data-model.md` § ProbeItem as arithmetic over
    a handful of SymPy constructors. Rejecting `ast.Attribute` outright therefore costs nothing and closes
    the vector *structurally*: there is no spelling of attribute access, present or future, that is not an
    `ast.Attribute` node. It is enumerating what is permitted, which is the property the contract claimed to
    have and did not.
  - *Placement inside `TRANSFORMATIONS` rather than wrapping `_parse`* — **chosen**, and load-bearing. The
    guard must validate the string that is evaluated, and `stringify_expr` produces that string inside
    `parse_expr` (`sympy_parser.py:1075`, quoted in §3). Running as the last transformation means (a) there
    is no window between validation and evaluation, and (b) the guard is welded to the exported constants,
    so the tester's own tests — which call `sympy.parse_expr(..., transformations=TRANSFORMATIONS,
    global_dict=ALLOWED_NAMES)` directly, bypassing `_parse` entirely — are protected by it. A wrapper
    around `_parse` would leave that path open and could not turn AC7's tests green.
- **IF** one of the 20 landed `check` objects fails to derive its pinned value under the guard **THEN**
  **stop and report it as a blocking gap on this spec**, naming the item id, the source string, the
  transformed string and the node type that was rejected. Do **not** edit `data/demo/nodes.json` (out of
  scope, §2), do not add the node type to `AST_ALLOWED_NODES` to make the row pass, and do not special-case
  the item. Widening the permitted node set is a versioned contract change and is never made to accommodate
  a datum; if the set is genuinely too narrow, that is a correction to §4 step 1's contract text, decided
  before it is coded.
- **IF** a legitimate future `check` would need a node outside the permitted set (`%`, a comparison, a
  tuple) **THEN** that is a versioned change to `contracts/data-model.md` § Probe answer derivation, exactly
  as extending the name list is, and it is not this task's to make. Nothing in `data/demo` needs one.
- **IF** the guard's exception seems better expressed by reusing `UncheckableCheck` **THEN** it is not: a
  distinct `UnsafeCheckSource` is required, because the two red evidence tests assert on the type raised
  from `sympy.parse_expr`, which knows nothing of `UncheckableCheck`, and because "this content tried to
  escape the sandbox" and "this content is not derivable" are different findings that must remain
  distinguishable when EPICs 05–09 aggregate generation results. Both still surface to the build as
  `LO_PROBE_UNCHECKABLE` (`_parse` converts), so the registered code set does not grow.
- **IF** `pyright` strict objects to `tokenize.untokenize`'s argument type **THEN** annotate the local
  token list; do not add a blanket `# type: ignore`, and do not widen a signature to `Any`.
- **IF** making a test green appears to require deleting an assertion, adding `xfail`, adding a skip marker,
  or shrinking `_ESCAPE_BATTERY` **THEN** the change is refused and the situation is reported as a blocking
  gap. "Weakened" means, exactly: the test no longer fails when the escape succeeds. The two AC7 tests may
  change instrument (§4 step 6) precisely because the retargeted body **does** fail when the escape
  succeeds, and fails earlier.
- **IF** the implementer is tempted to add a human review step over generated `check` strings as a
  mitigation **THEN** it is forbidden (I9). The machine check is the review.
- **IF** anything outside the two `contracts/data-model.md` passages of §2 appears to need a contract edit
  **THEN** stop: that is a Q5 owner decision, not an implementer's edit.

Standing defaults: no identifying field is added anywhere (I5) — this task adds no field to any schema or
bundle; telemetry is untouched; this task has zero model-calling paths, so no confidence threshold and no
Tier-0 fallback applies (I2 not engaged); no `paraphrase`, `why`, `what_it_is` or `name` string is touched
(I6, I15); no `Core` code, no L0 rule, no renderer (I14); no new dependency and no tool outside
`docs/tech-stack.md`.

## §7 Done definition

The task is done when ALL gates pass:

- `cd pipeline && uv run ruff check . && uv run ruff format --check .` clean
- `cd pipeline && uv run pyright` clean (strict) over `verify/answers.py` and
  `tests/test_verify_allowlist_closure.py`
- `cd pipeline && uv run pytest tests/test_verify_allowlist_closure.py -q` green — every test in the file,
  including the two formerly-RED evidence tests (AC7), the battery (AC2) and the negative control (AC5)
- `cd pipeline && uv run pytest tests/test_demo_bundle.py -q` green, **unmodified** (AC3, AC8)
- `cd pipeline && uv run pytest -q` green, with a collected-test count strictly greater than the pre-fix run
  and no test skipped or `xfail`ed that was not skipped before (AC8); both counts recorded in the PR
- `scripts/gate.sh` green end-to-end (all four gates of `docs/tech-stack.md` §3)
- `data/demo/nodes.json` is byte-unchanged by this task (`git diff --stat` shows it absent)
- `contracts/data-model.md` reads `Contract version: v1.2.0`, carries §4 step 1's text verbatim, and its
  commit uses the scope `contract(data-model)` (AC9)
- the phrase `closed nine-name allow-list` appears nowhere in `contracts/` or `pipeline/src/`
- the 20-row derivation output of AC3 and the escape-rejection evidence are in the PR description
- conforms to every contract section cited in §3 and §4, and to every invariant listed in §1
