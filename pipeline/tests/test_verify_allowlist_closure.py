"""THE CENTRAL CHARGE: empirically test the CAS parse environment's closed allow-lists.

`contracts/data-model.md` § Probe answer derivation (v1.2.0): parsing is `sympy.parse_expr` with
`standard_transformations + (rationalize, restrict_ast_shape)` under **two** closed allow-lists — a name
allow-list (nine semantic names `Eq`, `Rational`, `sqrt`, `log`, `exp`, `Abs`, `diff`, `pi`, `E` plus two
structural constructors `Symbol`, `Integer`) and an AST-shape allow-list validated on the exact string that
is evaluated. A name allow-list alone does not close the parse environment — attribute access, subscripting
and displays are not name resolution — which is exactly what this file's central charge, below, proved
empirically on 2026-09-09 (`tasks/blocked/tester-blocked-01-07.md`) before the AST-shape guard existed.

The shipped `ALLOWED_NAMES` (`pipeline/src/mathmath_pipeline/verify/answers.py`) has **eleven** names: the
nine plus `Symbol` and `Integer`, justified because `standard_transformations` mechanically injects
`Integer(...)`/`Symbol(...)` calls for integer literals and bare names, and because neither name is claimed
to add computational capability. This file tests that claim empirically rather than accepting it (I1).
"""

from __future__ import annotations

import json
import re
from typing import Any, cast

import pytest
import sympy  # pyright: ignore[reportMissingTypeStubs]
from sympy.parsing.sympy_parser import (  # pyright: ignore[reportMissingTypeStubs]
    rationalize,
    standard_transformations,
    stringify_expr,
)

from mathmath_pipeline import REPO_ROOT
from mathmath_pipeline.verify.answers import (
    ALLOWED_NAMES,
    AST_ALLOWED_NODE_NAMES,
    LO_PROBE_UNCHECKABLE,
    TRANSFORMATIONS,
    UncheckableCheck,
    UnsafeCheckSource,
    _evaluate,  # pyright: ignore[reportPrivateUsage]
    derive_from_check,
    restrict_ast_shape,
    verify_numeric_answers,
)

# The literal nine-name allow-list the contract text specifies, reconstructed independently of the
# implementation's `ALLOWED_NAMES` so this test does not just echo the module under test.
_NINE_NAME_ALLOWLIST: dict[str, Any] = {
    "Eq": sympy.Eq,
    "Rational": sympy.Rational,
    "sqrt": sympy.sqrt,  # pyright: ignore[reportUnknownMemberType]
    "log": sympy.log,
    "exp": sympy.exp,
    "Abs": sympy.Abs,
    "diff": sympy.diff,  # pyright: ignore[reportUnknownMemberType]
    "pi": sympy.pi,  # pyright: ignore[reportUnknownMemberType]
    "E": sympy.E,  # pyright: ignore[reportUnknownMemberType]
}

# The pre-fix transformations tuple, reconstructed locally (not imported from the module under test) so a
# future edit to `TRANSFORMATIONS` cannot silently drag this negative control along with it (AC5, T5).
_UNGUARDED = standard_transformations + (rationalize,)

_NODES_JSON = REPO_ROOT / "data" / "demo" / "nodes.json"


def _load_nodes() -> dict[str, Any]:
    return cast("dict[str, Any]", json.loads(_NODES_JSON.read_text()))


def _numeric_items(nodes_file: dict[str, Any]) -> list[tuple[str, dict[str, Any]]]:
    return [
        (node["id"], item)
        for node in nodes_file["nodes"]
        for item in node.get("probe_items", [])
        if item["type"] == "numeric"
    ]


def _collect_check_sources(nodes_file: dict[str, Any]) -> list[str]:
    """Every raw source string a landed `check` hands to the parser: `expr`/`equations[]` and `at` values."""
    sources: list[str] = []
    for _node_id, item in _numeric_items(nodes_file):
        check = item["check"]
        if check["kind"] == "evaluate":
            sources.append(check["expr"])
            sources.extend(check.get("at", {}).values())
        elif check["kind"] == "solve":
            sources.extend(check["equations"])
    return sources


# ---------------------------------------------------------------------------
# 1. The literal nine-name list really does fail on ordinary content — the implementer's justification for
#    adding `Symbol`/`Integer`, reproduced rather than trusted. Unaffected by the AST-shape guard: the guard
#    checks names against the module's own fixed eleven-name `ALLOWED_NAMES`, never the caller's
#    `global_dict`, so a `NameError` raised by `eval` against a caller-supplied nine-name dict still surfaces
#    exactly as before.
# ---------------------------------------------------------------------------


def test_literal_nine_names_reject_integer_literals_with_the_claimed_nameerror() -> None:
    """`standard_transformations`' `auto_number` rewrites the literal `2` into a call `Integer(2)`; with
    only the nine allow-listed names bound, `Integer` is unresolved and parsing raises `NameError`,
    reproducing exactly the failure the implementer's justification cites."""
    with pytest.raises(NameError, match="Integer"):
        sympy.parse_expr(
            "2 + 2", transformations=TRANSFORMATIONS, global_dict=_NINE_NAME_ALLOWLIST, local_dict={}
        )


def test_literal_nine_names_reject_bare_symbols_with_the_claimed_nameerror() -> None:
    """`standard_transformations`' `auto_symbol` rewrites the bare name `x` into a call `Symbol('x')`; with
    only the nine allow-listed names bound, `Symbol` is unresolved and parsing raises `NameError`,
    reproducing exactly the failure the implementer's justification cites."""
    with pytest.raises(NameError, match="Symbol"):
        sympy.parse_expr(
            "x + 1", transformations=TRANSFORMATIONS, global_dict=_NINE_NAME_ALLOWLIST, local_dict={}
        )


def test_shipped_allowlist_parses_what_the_nine_name_list_cannot() -> None:
    """The eleven-name `ALLOWED_NAMES` this task's implementation ships parses ordinary integer-and-symbol
    content the literal nine-name list rejects — the positive half of the justification."""
    with pytest.raises(NameError):
        sympy.parse_expr(
            "2*x + 3", transformations=TRANSFORMATIONS, global_dict=_NINE_NAME_ALLOWLIST, local_dict={}
        )
    parsed = sympy.parse_expr(
        "2*x + 3", transformations=TRANSFORMATIONS, global_dict=ALLOWED_NAMES, local_dict={}
    )
    assert parsed is not None


# ---------------------------------------------------------------------------
# 2. Off-allow-list names: "parses to a free symbol; calling one raises."
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("name", ["Integral", "solve", "lambdify", "eval", "open", "os", "__import__"])
def test_off_allowlist_bare_name_parses_to_an_inert_free_symbol(name: str) -> None:
    """A bare off-allow-list name is a free symbol under `auto_symbol` — merely appearing does not raise;
    the contract's "calling one raises" clause is specifically about calling it (next test)."""
    parsed = sympy.parse_expr(name, transformations=TRANSFORMATIONS, global_dict=ALLOWED_NAMES, local_dict={})
    assert isinstance(parsed, sympy.Symbol)
    assert str(parsed) == name


@pytest.mark.parametrize(
    "expr",
    [
        "Integral(x, x)",
        "solve(x, x)",
        "lambdify(x, x)",
        '__import__("os")',
        'eval("1")',
        'open("/etc/passwd")',
        'os.system("id")',
    ],
)
def test_off_allowlist_name_raises_when_called_never_produces_a_value(expr: str) -> None:
    """Calling an off-allow-list name raises during parse — it never reaches a usable value, so
    `derive_from_check`'s exception handling (never a bare `except`, §5) converts it to `UncheckableCheck`,
    never a silently-accepted answer (I1).

    2026-09-09: `sympy`'s `auto_symbol` rewrites a called off-allow-list name to `Function('<name>')(...)`,
    and `os.system(...)` to an attribute call on `Symbol('os')`; under the AST-shape guard (data-model
    v1.2.0) both are now rejected as `UnsafeCheckSource` (a disallowed bare name `Function`, or a disallowed
    `ast.Attribute` node) before `eval` ever runs, which is a strictly earlier and stronger rejection than
    the `NameError`/`AttributeError` `eval` itself used to raise. `UnsafeCheckSource` is added to the
    accepted exception set for this reason; the property under test — never a usable value — is unchanged.
    """
    with pytest.raises((NameError, AttributeError, UnsafeCheckSource)):
        sympy.parse_expr(expr, transformations=TRANSFORMATIONS, global_dict=ALLOWED_NAMES, local_dict={})
    with pytest.raises(UncheckableCheck):
        _evaluate({"expr": expr})


# ---------------------------------------------------------------------------
# 3. THE CENTRAL CHARGE. Does the allow-list actually close the parse environment, or can an authored
#    `check.expr` string attribute-walk from any permitted value (a literal, `Symbol`, `Integer`, or any of
#    the nine) out to the live interpreter class graph and beyond?
#
#    FINDING (empirical, first reproduced against the pre-fix `ALLOWED_NAMES`/`TRANSFORMATIONS`): the
#    name-only allow-list was escapable. The expression
#
#        ().__class__.__bases__[0].__subclasses__()
#
#    used to parse and execute successfully, returning every class currently loaded in the process —
#    including `subprocess.Popen`. This uses no name outside the allow-list at all: `()` is a tuple literal
#    (no name lookup), and `.__class__` / `.__bases__` / `.__subclasses__()` are plain attribute and method
#    access on the tuple's own live object graph — a vector the name allow-list alone does not gate.
#
#    2026-09-09: the property now HOLDS. `restrict_ast_shape` (data-model v1.2.0) rejects `ast.Attribute`
#    and every other node outside the permitted shape before `eval` ever runs, so the tests below assert
#    the escape is refused, not merely that its result is inert.
# ---------------------------------------------------------------------------

_ESCAPE_EXPR = "().__class__.__bases__[0].__subclasses__()"


def _dangerous_subclass_names(subclasses: list[type]) -> list[str]:
    return [cls.__name__ for cls in subclasses if cls.__module__ in {"subprocess", "os", "builtins"}]


def test_dunder_attribute_chain_from_symbol_reaches_the_live_class_graph() -> None:
    """`Symbol('x').__class__.__mro__` walks sympy's own class hierarchy and returns live Python `type`
    objects, not sympy expressions — already wider than "construct an inert value".

    2026-09-09: retargeted (§4 step 6 / §5 T4). The pre-fix body parsed this and asserted every returned
    item was a live `type` object; under `restrict_ast_shape` the parse is refused before it evaluates
    anything, so the property is now asserted as a refusal.
    """
    with pytest.raises(UnsafeCheckSource) as excinfo:
        sympy.parse_expr(
            "Symbol('x').__class__.__mro__",
            transformations=TRANSFORMATIONS,
            global_dict=ALLOWED_NAMES,
            local_dict={},
        )
    assert "Attribute" in str(excinfo.value)


def test_allowlist_is_escapable_to_the_live_interpreter_class_graph() -> None:
    """THE CENTRAL CHARGE, empirically. This test asserts the security property the contract promises (no
    interpreter-internal class reachable) and once FAILED against the shipped `ALLOWED_NAMES`/
    `TRANSFORMATIONS`. See the BLOCK report for the exact escaping expression and a documented manual repro
    reaching real process execution.

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


def test_reaching_subprocess_popen_as_a_live_class_object_is_the_only_step_short_of_shell_execution() -> None:
    """Having reached the live class graph (previous test, pre-fix), `subprocess.Popen` was one lookup away
    — an authored `check.expr` reaching this class object is one call away from arbitrary shell execution.

    2026-09-09: retargeted (§4 step 6). The escape is refused before evaluation, so `subprocess.Popen` is
    never reached; the caller-visible path (`derive_from_check`/`_evaluate`) is also asserted, covering both
    entry paths of AC1.
    """
    with pytest.raises(UnsafeCheckSource) as excinfo:
        sympy.parse_expr(
            _ESCAPE_EXPR, transformations=TRANSFORMATIONS, global_dict=ALLOWED_NAMES, local_dict={}
        )
    assert "Attribute" in str(excinfo.value)
    with pytest.raises(UncheckableCheck) as check_excinfo:
        _evaluate({"expr": _ESCAPE_EXPR})
    assert "unsafe check source" in check_excinfo.value.reason
    assert "Attribute" in check_excinfo.value.reason


# ---------------------------------------------------------------------------
# 4. Do `Integer`/`Symbol` add reachable capability beyond constructing inert values through their own
#    attributes (as opposed to the interpreter-class-graph vector proven above, which does not depend on
#    which of the eleven names was used to obtain the starting value)?
# ---------------------------------------------------------------------------


def test_integer_dunder_class_alone_does_not_expose_a_live_module_reference() -> None:
    """`Integer.__module__` is a plain string, not a live module object — attribute access on it cannot
    itself walk back into `sympy` internals (the actual escape vector is the interpreter class graph,
    proven above, and is independent of which allowed name supplied the starting value).

    2026-09-09: retargeted (§4 step 6 / §5 T4). Attribute access is now refused structurally regardless of
    what it would have returned, which is a strictly stronger property than "this particular attribute
    happens to be harmless".
    """
    with pytest.raises(UnsafeCheckSource) as excinfo:
        sympy.parse_expr(
            "Integer.__module__", transformations=TRANSFORMATIONS, global_dict=ALLOWED_NAMES, local_dict={}
        )
    assert "Attribute" in str(excinfo.value)


def test_derive_from_check_does_not_reject_the_escaping_expression_before_it_executes() -> None:
    """Before this fix, the escape's side effect (the interpreter class-graph walk) happened during
    `sympy.parse_expr`'s own evaluation, before `_evaluate`'s later `isinstance(parsed, sympy.Expr)`
    structural check ever ran — so even though the final `derive_from_check` call was rejected as
    `UncheckableCheck`, the class-graph walk itself had already completed.

    2026-09-09: retargeted (§4 step 6). `restrict_ast_shape` runs as the last transformation, before `eval`
    is ever invoked, so the parse — and therefore the class-graph walk — never happens at all: the rejection
    is now earlier than the pre-fix vulnerability's side effect, not merely downstream of it.
    """
    with pytest.raises(UncheckableCheck) as excinfo:
        _evaluate({"expr": _ESCAPE_EXPR})
    assert "unsafe check source" in excinfo.value.reason
    assert "Attribute" in excinfo.value.reason


# ---------------------------------------------------------------------------
# 5. T1 (AC3) — every landed `check` still derives its recorded answer, unchanged, under the guard.
# ---------------------------------------------------------------------------

# Pinned independently of `data/demo/nodes.json`'s own `answer.value` (§4 step 5).
_TWENTY_EXPECTED_VALUES: dict[str, str] = {
    "integer-operations-1": "4",
    "order-of-operations-1": "14",
    "rational-numbers-1": "5/6",
    "exponent-laws-1": "6",
    "scientific-notation-1": "32000",
    "linear-relations-1": "3",
    "solving-linear-equations-1": "4",
    "solving-systems-of-equations-1": "6",
    "simplifying-expressions-1": "8",
    "polynomials-1": "4",
    "factoring-1": "6",
    "solving-quadratics-1": "3",
    "rational-expressions-1": "8",
    "quadratic-functions-1": "3",
    "function-concept-1": "7",
    "function-transformations-1": "4",
    "function-notation-1": "10",
    "domain-and-range-1": "3",
    "exponential-functions-1": "9",
    "logarithms-1": "3",
}


def test_all_twenty_landed_checks_survive_the_guard() -> None:
    """AC3: every landed `check` still derives its recorded value, unchanged, under `restrict_ast_shape`."""
    assert len(_TWENTY_EXPECTED_VALUES) == 20, "anti-vacuity: the pinned table must have exactly 20 rows"
    nodes_file = _load_nodes()
    items = _numeric_items(nodes_file)
    assert len(items) == 20, "anti-vacuity: the bundle must have exactly 20 numeric items"
    visited: set[str] = set()
    for _node_id, item in items:
        item_id = item["id"]
        derived = derive_from_check(item["check"])
        expected = _TWENTY_EXPECTED_VALUES[item_id]
        assert str(derived) == expected, f"{item_id}: expected {expected}, derived {derived}"
        visited.add(item_id)
    assert visited == set(_TWENTY_EXPECTED_VALUES), "every pinned item id must actually have been visited"


# ---------------------------------------------------------------------------
# 6. T2 (AC2) — a battery of related escapes, beyond the one reported expression.
# ---------------------------------------------------------------------------

# (source, expected exception type on the direct `sympy.parse_expr` path, a substring the rejection message
# must contain). Comprehension entries raise `SyntaxError`, not `UnsafeCheckSource`, because `auto_symbol`
# (a `standard_transformations` step that runs *before* our guard, unchanged by this task) rewrites a
# comprehension's bound loop variable into a `Symbol('<name>')` call, which is not a valid assignment
# target — so `ast.parse` itself refuses the code before `restrict_ast_shape`'s own node walk ever runs.
# This is the "a parse failure ... `_parse` already converts it" case named in §4 step 2; the escape is
# still rejected on both entry paths, just via a different, equally-terminal mechanism.
_ESCAPE_BATTERY: list[tuple[str, type[Exception], str]] = [
    ("().__class__.__bases__[0].__subclasses__()", UnsafeCheckSource, "Attribute"),
    ("().__class__", UnsafeCheckSource, "Attribute"),
    ("Symbol('x').__class__.__mro__", UnsafeCheckSource, "Attribute"),
    ("Integer.__module__", UnsafeCheckSource, "Attribute"),
    ("Integer(1).__class__.__base__.__subclasses__()", UnsafeCheckSource, "Attribute"),
    ("pi.__class__", UnsafeCheckSource, "Attribute"),
    ("[].__len__()", UnsafeCheckSource, "Attribute"),
    ("''.join", UnsafeCheckSource, "Attribute"),
    ("(1,2)[0]", UnsafeCheckSource, "Subscript"),
    ("[1,2,3][0:2]", UnsafeCheckSource, "Subscript"),
    ("[i for i in (1,2)]", SyntaxError, "assign"),
    ("(i for i in (1,2))", SyntaxError, "assign"),
    ("{k: 1 for k in (1,)}", SyntaxError, "assign"),
    ("(lambda: 1)()", UnsafeCheckSource, "Lambda"),
    ("Rational(1, 2) if 1 else 0", UnsafeCheckSource, "IfExp"),
    ("1 < 2", UnsafeCheckSource, "Compare"),
    ("Integer(1) and Integer(2)", UnsafeCheckSource, "BoolOp"),
    ('f"{Integer(1)}"', UnsafeCheckSource, "JoinedStr"),
    ("Eq(x, y, evaluate=False)", UnsafeCheckSource, "keyword"),
    ("diff(*[1])", UnsafeCheckSource, "Starred"),
]


def test_escape_battery_is_rejected() -> None:
    """AC2: every entry of the battery is rejected on both entry paths of AC1."""
    assert len(_ESCAPE_BATTERY) >= 18, "anti-vacuity [SOURCED: the battery pinned in §5 T2 has 20 entries]"
    assert len(_ESCAPE_BATTERY) == 20
    for source, exc_type, expected_substring in _ESCAPE_BATTERY:
        with pytest.raises(exc_type) as excinfo:
            sympy.parse_expr(
                source, transformations=TRANSFORMATIONS, global_dict=ALLOWED_NAMES, local_dict={}
            )
        message = str(excinfo.value)
        assert message, f"{source!r}: rejection message must not be empty"
        assert expected_substring in message, f"{source!r}: expected {expected_substring!r} in {message!r}"
        with pytest.raises(UncheckableCheck) as check_excinfo:
            _evaluate({"expr": source})
        assert check_excinfo.value.reason, f"{source!r}: UncheckableCheck.reason must not be empty"


# ---------------------------------------------------------------------------
# 7. T3 (error taxonomy) — the failure is collected and reported per-item under the registered error code,
#    never swallowed, and no new error-code constant is introduced.
# ---------------------------------------------------------------------------


def test_unsafe_source_surfaces_as_the_registered_code() -> None:
    assert LO_PROBE_UNCHECKABLE == "LO_PROBE_UNCHECKABLE"
    nodes_file: dict[str, Any] = {
        "nodes": [
            {
                "id": "some-node",
                "probe_items": [
                    {
                        "id": "some-item",
                        "type": "numeric",
                        "check": {"kind": "evaluate", "expr": _ESCAPE_EXPR},
                        "answer": {"value": "0"},
                    }
                ],
            }
        ]
    }
    uncheckable, mismatches = verify_numeric_answers(nodes_file)
    assert mismatches == []
    assert len(uncheckable) == 1
    item = uncheckable[0]
    assert item.node_id == "some-node"
    assert item.item_id == "some-item"
    assert "unsafe check source" in item.reason

    answers_source = (
        REPO_ROOT / "pipeline" / "src" / "mathmath_pipeline" / "verify" / "answers.py"
    ).read_text()
    assert answers_source, "anti-vacuity: the scan must read a non-empty file"
    lo_tokens = set(re.findall(r"LO_[A-Z_]+", answers_source))
    assert lo_tokens == {"LO_PROBE_UNCHECKABLE"}, f"no new error-code constant may be introduced: {lo_tokens}"


# ---------------------------------------------------------------------------
# 8. T4 (AC6, AC9) — the name list and the contract text agree with the implementation.
# ---------------------------------------------------------------------------

_ELEVEN_NAME_ALLOWLIST = frozenset(
    {"Eq", "Rational", "sqrt", "log", "exp", "Abs", "diff", "pi", "E", "Symbol", "Integer"}
)


def test_allowed_names_match_the_contract() -> None:
    assert len(_ELEVEN_NAME_ALLOWLIST) == 11, "anti-vacuity: the reconstructed set must have 11 members"
    assert len(ALLOWED_NAMES) > 0
    # CPython's `eval` inserts a `__builtins__` entry into any globals dict that lacks one, mutating the
    # dict object in place; `sympy.parse_expr` passes `ALLOWED_NAMES` straight through to `eval`, so this
    # key can appear here as a side effect of any earlier test in this suite calling `sympy.parse_expr`
    # with `global_dict=ALLOWED_NAMES`. It is never an author-facing name: `auto_symbol` only leaves a bare
    # name unresolved-in-place when its value is a sympy `Basic`/`type`/`AssumptionKeys` or callable, and
    # the injected `__builtins__` module is none of those, so a `check` referencing it is Symbol-wrapped
    # like any other unrecognised name; `restrict_ast_shape` independently rejects the attribute/subscript
    # access that would be needed to reach anything through it. Excluded from this equality for that reason.
    assert set(ALLOWED_NAMES) - {"__builtins__"} == _ELEVEN_NAME_ALLOWLIST
    contract_text = (REPO_ROOT / "contracts" / "data-model.md").read_text()
    assert "structural constructors" in contract_text


def test_contract_text_describes_the_shape_guard() -> None:
    contract_path = REPO_ROOT / "contracts" / "data-model.md"
    contract_text = contract_path.read_text()
    assert len(contract_text.splitlines()) >= 100, "anti-vacuity: the file read must be non-trivial"
    for token in ("restrict_ast_shape", "ast.Attribute", "structural constructors", "v1.2.0"):
        assert token in contract_text, f"contract must contain {token!r}"

    answers_path = REPO_ROOT / "pipeline" / "src" / "mathmath_pipeline" / "verify" / "answers.py"
    answers_text = answers_path.read_text()
    assert contract_text, "anti-vacuity: the contract file read must be non-empty"
    assert answers_text, "anti-vacuity: the answers.py file read must be non-empty"
    retired_phrase = "closed nine-name allow-list"
    assert retired_phrase not in answers_text
    for path in (REPO_ROOT / "contracts").rglob("*.md"):
        assert retired_phrase not in path.read_text(), f"{path} still contains the retired phrase"


def test_ast_allowed_node_names_matches_the_contract_shape_list() -> None:
    expected = {
        "Expression",
        "BinOp",
        "UnaryOp",
        "Call",
        "Name",
        "Load",
        "Constant",
        "Add",
        "Sub",
        "Mult",
        "Div",
        "Pow",
        "UAdd",
        "USub",
    }
    assert AST_ALLOWED_NODE_NAMES == expected


# ---------------------------------------------------------------------------
# 9. T5 (AC5) — negative control: the guard itself can fail, proving it is load-bearing.
# ---------------------------------------------------------------------------


def test_negative_control_without_the_guard_the_escape_still_executes() -> None:
    """Reconstruct the pre-fix `TRANSFORMATIONS` tuple locally and confirm the AC1 escape still evaluates
    and still returns live classes from `subprocess`/`os`/`builtins` under it. This proves the vulnerability
    is real and that `restrict_ast_shape` is the thing preventing it — a mutation deleting the guard from
    `TRANSFORMATIONS` would red AC1/AC2 while this test stays green.

    This test walks the class graph only; it never instantiates or calls any class it reaches, so no
    process is spawned in CI.
    """
    result = sympy.parse_expr(
        _ESCAPE_EXPR, transformations=_UNGUARDED, global_dict=ALLOWED_NAMES, local_dict={}
    )
    assert isinstance(result, list)
    classes = cast("list[type]", result)
    assert classes, "anti-vacuity: the unguarded parse must return a non-empty list"
    dangerous = _dangerous_subclass_names(classes)
    assert dangerous, "anti-vacuity: a control that finds nothing dangerous is itself a FAIL of this AC"
    assert "Popen" in dangerous


# ---------------------------------------------------------------------------
# 10. T6 (AC4) — the guard is a validator, never a rewriter: the validated string is the evaluated string,
#     and no landed derivation shifts under it.
# ---------------------------------------------------------------------------


def test_guard_is_a_validator_not_a_rewriter() -> None:
    identity_checks: list[bool] = []

    def _check_identity(
        tokens: list[tuple[int, str]], local_dict: dict[str, Any], global_dict: dict[str, Any]
    ) -> list[tuple[int, str]]:
        result = restrict_ast_shape(tokens, local_dict, global_dict)
        identity_checks.append(result is tokens)
        return result

    recording = standard_transformations + (rationalize, _check_identity)
    sources = _collect_check_sources(_load_nodes())
    assert len(sources) >= 20, "anti-vacuity: at least 20 sources must be compared"
    guarded_outputs = [stringify_expr(source, {}, ALLOWED_NAMES, recording) for source in sources]
    unguarded_outputs = [stringify_expr(source, {}, ALLOWED_NAMES, _UNGUARDED) for source in sources]
    assert len(identity_checks) >= 20
    assert all(identity_checks), "restrict_ast_shape must return the same token list object it was handed"
    assert guarded_outputs == unguarded_outputs, "the guard must never change what is computed, only accepted"
    assert any(transformed != source for source, transformed in zip(sources, guarded_outputs, strict=True)), (
        "anti-vacuity: at least one transformed string must differ from its raw source"
    )


def test_guard_validates_the_exact_string_that_is_evaluated(monkeypatch: pytest.MonkeyPatch) -> None:
    """AC4: byte-identity between the string the guard validates and the string `eval` receives, captured
    via a recording hook on the module's own `untokenize` rather than re-deriving the claim analytically."""
    import mathmath_pipeline.verify.answers as answers_module

    captured: list[str] = []
    real_untokenize = answers_module.untokenize

    def _recording_untokenize(tokens: list[tuple[int, str]]) -> str:
        code = real_untokenize(tokens)
        captured.append(code)
        return code

    monkeypatch.setattr(answers_module, "untokenize", _recording_untokenize)

    sources = _collect_check_sources(_load_nodes())
    for source in sources:
        sympy.parse_expr(source, transformations=TRANSFORMATIONS, global_dict=ALLOWED_NAMES, local_dict={})

    assert len(captured) >= 20, "anti-vacuity: at least 20 strings must have been captured"
    for source, code in zip(sources, captured, strict=True):
        independent = stringify_expr(source, {}, ALLOWED_NAMES, _UNGUARDED)
        assert code == independent, f"{source!r}: validated string must equal the evaluated string"
    assert any(code != source for source, code in zip(sources, captured, strict=True)), (
        "anti-vacuity: at least one captured string must differ from its raw authored source"
    )
