# TESTER BLOCK: epic 01 task 07

**Class**: bug-found
**Implementer commit**: 35ea4447b7e631df348f49acfae85b915b9213b7
**Tester commit (red repro, unmodified)**: 46a5134 (`pipeline/tests/test_verify_allowlist_closure.py`)

## What you tried to test

The task's central charge: empirically verify that `verify/answers.py`'s `ALLOWED_NAMES` (the nine names
`contracts/data-model.md` § Probe answer derivation specifies, plus `Symbol` and `Integer` the implementer
added) is genuinely a **closed** parse environment — i.e. that an authored `ProbeItem.check.expr`/
`check.equations[]` string, drawn from untrusted (machine-generated, per I9/D10/D12/D13 "zero human
review") content, cannot reach any capability beyond constructing and evaluating an inert SymPy expression.

## Why it failed

It is not closed. The allow-list restricts which bare *names* an expression may reference, but places no
restriction on **attribute access on the object any allowed value returns**. Python attribute/dunder access
is not name resolution, so it is invisible to a `global_dict`-based allow-list entirely. Starting from a
plain tuple literal `()` — which requires no allow-listed name at all — the expression

```
().__class__.__bases__[0].__subclasses__()
```

parses and *executes* successfully under `sympy.parse_expr(source, transformations=TRANSFORMATIONS,
global_dict=ALLOWED_NAMES, local_dict={})` using the exact `ALLOWED_NAMES`/`TRANSFORMATIONS` shipped in
`pipeline/src/mathmath_pipeline/verify/answers.py`. It returns a Python `list` of every class currently
loaded in the process — including `subprocess.Popen`.

Reaching the *class object* alone is already the finding (reproduced as a committed, unmodified red test:
`pipeline/tests/test_verify_allowlist_closure.py::test_allowlist_is_escapable_to_the_live_interpreter_class_graph`
and `::test_reaching_subprocess_popen_as_a_live_class_object_is_the_only_step_short_of_shell_execution`).
One additional attribute lookup away (indexing to the `Popen` entry and calling it) is full remote code
execution. I verified this in an isolated manual session (not committed — this step spawns a real process
and is unsafe to run unconditionally in CI), against the pipeline's own installed `sympy`:

```python
import sympy
from mathmath_pipeline.verify.answers import ALLOWED_NAMES, TRANSFORMATIONS

src = "().__class__.__bases__[0].__subclasses__()"
r = sympy.parse_expr(src, transformations=TRANSFORMATIONS, global_dict=ALLOWED_NAMES, local_dict={})
idx = [c.__name__ for c in r].index("Popen")

src2 = f'().__class__.__bases__[0].__subclasses__()[{idx}](["id"], stdout=-1).communicate()'
r2 = sympy.parse_expr(src2, transformations=TRANSFORMATIONS, global_dict=ALLOWED_NAMES, local_dict={})
print(r2)
# -> (b'uid=501(jimmyz) gid=20(staff) groups=20(staff), ... \n', None)
```

This executed a real `id` shell command and returned its real stdout, entirely through
`derive_from_check`'s own parse path — before any downstream type check (`isinstance(parsed, sympy.Expr)`)
gets a chance to reject the result. The side effect (arbitrary shell execution) happens as part of
`sympy.parse_expr`'s own evaluation; the fact that `_evaluate` later raises `UncheckableCheck` because the
final value isn't a SymPy `Expr` does **not** undo the side effect — it has already completed.

**Why this is in scope, not merely a "the nine names still hold, Integer/Symbol don't add anything" finding
as the implementer's comment claims (`answers.py:27-35`)**: the comment argues the two added names supply
no capability the nine don't already have. That framing is the wrong axis. The vulnerability is
independent of which of the eleven names supplies the starting value — `()` is a bare Python tuple literal,
reachable with **zero** names from the allow-list. The literal nine-name list is exactly as exploitable as
the eleven-name list via this vector (I did not re-verify the nine-name-only case against this specific
payload, since `2+2`/`x+1` already fail to parse under it per the empirical evidence in the same test file —
but the escape technique itself requires no name resolution whatsoever, so restricting the allow-list
further would not close it). The contract's stated defense — "any other name parses to a free symbol;
calling one raises" — describes protection against calling a disallowed *name*. It says nothing about, and
does not defend against, attribute-walking from an *already-permitted* value's return object to the live
interpreter class graph and back out to any loaded class, including ones with dangerous `__init__`/`__call__`
behavior (`subprocess.Popen`, `os._wrap_close`, etc).

## Expected vs. actual

- Expected (`contracts/data-model.md` § Probe answer derivation, quoted in the task spec §3): "a **closed**
  name allow-list ... Any other name parses to a free symbol; calling one raises." — i.e. a `check.expr`/
  `check.equations[]` string can construct and evaluate SymPy expressions from the nine allowed names and
  nothing more.
- Actual: a `check.expr` string can reach and instantiate/call arbitrary live Python classes present in the
  pipeline process, including `subprocess.Popen`, achieving remote code execution during "CAS verification"
  — a build-time check whose entire purpose is to make untrusted, machine-generated content safe to trust
  (I9: "zero human content review... content is generated + machine-verified").

## Repro (committed, unmodified, red)

```
cd pipeline && uv run pytest tests/test_verify_allowlist_closure.py -q
```

Fails on exactly:
- `test_allowlist_is_escapable_to_the_live_interpreter_class_graph`
- `test_reaching_subprocess_popen_as_a_live_class_object_is_the_only_step_short_of_shell_execution`

Both assert the security property the contract promises (no interpreter-internal class reachable through
the parse environment) and both currently fail against the shipped `ALLOWED_NAMES`/`TRANSFORMATIONS`. Every
other test in the file, and every other test in the full `uv run pytest -q` run (144 passed), is green;
`swift-format lint --strict`, `ruff check`/`ruff format --check`, `pyright` strict, the Core/Rendering
simulator test suites, and the App simulator build all pass. This is an isolated, targeted finding, not a
broad regression.

## Suggested remediation (for the implementer/owner, not applied here — test files only)

`sympy.parse_expr` fundamentally evaluates the transformed source as a Python expression against
`global_dict`/`local_dict`; a name-based allow-list on that `eval` cannot close off attribute access on
whatever values are reachable from Python builtins and literals (this is the same, well-known class of
`eval()`-sandbox escape that affects any `eval`-based expression evaluator, not specific to SymPy). Options
for the owner/implementer to consider (a Q5/spec-arbiter decision, not mine to make):

- Reject any `check.expr`/`equations[]` source containing a literal `__` (dunder) substring before parsing
  — cheap, but a blocklist, not the "closed allow-list" the contract currently promises, and blocklists are
  generally bypassable in `eval`-based parsers by future SymPy/CPython internals.
- Parse with `sympy.sympify`'s `strict=True` or `sympy.parsing.sympy_parser.parse_expr`'s `evaluate=False`
  combined with an AST-level walk that permits only `Name`/`Call`/`Num`/`BinOp`/etc. nodes and rejects
  `Attribute` nodes outright — closing the vector structurally rather than by pattern-matching.
  `standard_transformations`' own `auto_symbol`/`auto_number` steps would need re-verification against
  such an AST restriction.
- Run the untrusted parse in a genuinely sandboxed subprocess/interpreter with no filesystem/network/exec
  access, so even a successful escape has nothing to reach.

This is a contract-level and implementation-level decision beyond a tester's authority; routing it back per
the BLOCK protocol.
