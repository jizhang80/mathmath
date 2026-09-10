"""THE CENTRAL CHARGE: empirically test the CAS parse environment's closed nine-name allow-list.

`contracts/data-model.md` § Probe answer derivation (v1.1.0): parsing is `sympy.parse_expr` with
`standard_transformations + (rationalize,)` and a **closed name allow-list**: `Eq`, `Rational`, `sqrt`,
`log`, `exp`, `Abs`, `diff`, `pi`, `E` — "any other name parses to a free symbol; calling one raises."

The shipped `ALLOWED_NAMES` (`pipeline/src/mathmath_pipeline/verify/answers.py`) has **eleven** names: the
nine plus `Symbol` and `Integer`, justified because `standard_transformations` mechanically injects
`Integer(...)`/`Symbol(...)` calls for integer literals and bare names, and because neither name is claimed
to add computational capability. This file tests that claim empirically rather than accepting it (I1).
"""

from __future__ import annotations

from typing import Any, cast

import pytest
import sympy  # pyright: ignore[reportMissingTypeStubs]

from mathmath_pipeline.verify.answers import (
    ALLOWED_NAMES,
    TRANSFORMATIONS,
    UncheckableCheck,
    _evaluate,  # pyright: ignore[reportPrivateUsage]
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


# ---------------------------------------------------------------------------
# 1. The literal nine-name list really does fail on ordinary content — the implementer's justification for
#    adding `Symbol`/`Integer`, reproduced rather than trusted.
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
    never a silently-accepted answer (I1)."""
    with pytest.raises((NameError, AttributeError)):
        sympy.parse_expr(expr, transformations=TRANSFORMATIONS, global_dict=ALLOWED_NAMES, local_dict={})
    with pytest.raises(UncheckableCheck):
        _evaluate({"expr": expr})


# ---------------------------------------------------------------------------
# 3. THE CENTRAL CHARGE. Does the allow-list actually close the parse environment, or can an authored
#    `check.expr` string attribute-walk from any permitted value (a literal, `Symbol`, `Integer`, or any of
#    the nine) out to the live interpreter class graph and beyond?
#
#    FINDING (empirical, reproduced below against the exact shipped `ALLOWED_NAMES`/`TRANSFORMATIONS`):
#    the allow-list is escapable. The expression
#
#        ().__class__.__bases__[0].__subclasses__()
#
#    parses and executes successfully, returning every class currently loaded in the process — including
#    `subprocess.Popen`. This uses no name outside the allow-list at all: `()` is a tuple literal (no name
#    lookup), and `.__class__` / `.__bases__` / `.__subclasses__()` are plain attribute and method access on
#    the tuple's own live object graph — a vector the name allow-list does not gate, because the contract's
#    promise ("any other name parses to a free symbol; calling one raises") describes protection against
#    calling a disallowed *name*, not against attribute-walking from an *allowed* value's return object.
#
#    A one-time manual repro (not re-run here — see the BLOCK report for the full transcript) confirmed
#    that reaching `subprocess.Popen` this way and calling it (`...__subclasses__()[<Popen index>](["id"],
#    stdout=-1).communicate()`) executes a real shell command and returns its real stdout. This test proves
#    reachability of the dangerous class object without spawning a process during the test suite itself.
# ---------------------------------------------------------------------------

_ESCAPE_EXPR = "().__class__.__bases__[0].__subclasses__()"


def _dangerous_subclass_names(subclasses: list[type]) -> list[str]:
    return [cls.__name__ for cls in subclasses if cls.__module__ in {"subprocess", "os", "builtins"}]


def test_dunder_attribute_chain_from_symbol_reaches_the_live_class_graph() -> None:
    """`Symbol('x').__class__.__mro__` walks sympy's own class hierarchy and returns live Python `type`
    objects, not sympy expressions — already wider than "construct an inert value"."""
    parsed = sympy.parse_expr(
        "Symbol('x').__class__.__mro__",
        transformations=TRANSFORMATIONS,
        global_dict=ALLOWED_NAMES,
        local_dict={},
    )
    assert isinstance(parsed, tuple)
    items = cast("tuple[object, ...]", parsed)
    assert all(isinstance(item, type) for item in items)


def test_allowlist_is_escapable_to_the_live_interpreter_class_graph() -> None:
    """THE CENTRAL CHARGE, empirically, RED: the closed nine-name allow-list does not hold. This test
    asserts the security property the contract promises (no interpreter-internal class reachable) and
    currently FAILS against the shipped `ALLOWED_NAMES`/`TRANSFORMATIONS` — a guard never shown failing is
    not a guard, and here the underlying property genuinely does not hold. See the BLOCK report for the
    exact escaping expression and a documented manual repro reaching real process execution.
    """
    parsed = sympy.parse_expr(
        _ESCAPE_EXPR, transformations=TRANSFORMATIONS, global_dict=ALLOWED_NAMES, local_dict={}
    )
    assert isinstance(parsed, list)
    dangerous = _dangerous_subclass_names(cast("list[type]", parsed))
    assert dangerous == [], (
        "the CAS parse environment is not a closed nine-name allow-list: attribute-chaining from a tuple "
        f"literal reaches live interpreter classes including {dangerous!r} — reachable via "
        f"{_ESCAPE_EXPR!r} using the exact ALLOWED_NAMES/TRANSFORMATIONS shipped in "
        "pipeline/src/mathmath_pipeline/verify/answers.py"
    )


def test_reaching_subprocess_popen_as_a_live_class_object_is_the_only_step_short_of_shell_execution() -> None:
    """Having reached the live class graph (previous test), `subprocess.Popen` is one lookup away — an
    authored `check.expr` reaching this class object is one call away from arbitrary shell execution. This
    test stops short of actually spawning a process (unsafe to do unconditionally on every CI run) and
    instead asserts the class object itself is never reachable; it currently FAILS."""
    parsed = sympy.parse_expr(
        _ESCAPE_EXPR, transformations=TRANSFORMATIONS, global_dict=ALLOWED_NAMES, local_dict={}
    )
    classes = cast("list[type]", parsed)
    popen_classes = [cls for cls in classes if cls.__module__ == "subprocess" and cls.__name__ == "Popen"]
    assert popen_classes == [], (
        "subprocess.Popen is reachable as a live class object through the shipped CAS parse environment "
        f"via {_ESCAPE_EXPR!r}; instantiating and calling it (not exercised here) executes arbitrary shell "
        "commands as a side effect of what is supposed to be inert 'CAS derivation' — see the BLOCK report "
        "for a documented one-time manual repro that actually executed a shell command"
    )


# ---------------------------------------------------------------------------
# 4. Do `Integer`/`Symbol` add reachable capability beyond constructing inert values through their own
#    attributes (as opposed to the interpreter-class-graph vector proven above, which does not depend on
#    which of the eleven names was used to obtain the starting value)?
# ---------------------------------------------------------------------------


def test_integer_dunder_class_alone_does_not_expose_a_live_module_reference() -> None:
    """`Integer.__module__` is a plain string, not a live module object — attribute access on it cannot
    itself walk back into `sympy` internals (the actual escape vector is the interpreter class graph,
    proven above, and is independent of which allowed name supplied the starting value)."""
    parsed = sympy.parse_expr(
        "Integer.__module__", transformations=TRANSFORMATIONS, global_dict=ALLOWED_NAMES, local_dict={}
    )
    assert isinstance(parsed, str)


def test_derive_from_check_does_not_reject_the_escaping_expression_before_it_executes() -> None:
    """The escape's side effect (the interpreter class-graph walk) happens during `sympy.parse_expr`'s own
    evaluation, before `_evaluate`'s later `isinstance(parsed, sympy.Expr)` structural check ever runs — so
    even though the final `derive_from_check` call is rejected as `UncheckableCheck` (the returned value is
    a Python `list`, not a SymPy `Expr`), the class-graph walk itself has already completed by the time the
    rejection happens. This demonstrates the vulnerability is not mitigated by `_evaluate`'s downstream type
    checks: arbitrary attribute-chain evaluation happens as a side effect of parsing, regardless of what a
    later type check does with the result.
    """
    with pytest.raises(UncheckableCheck, match="did not produce a SymPy expression"):
        _evaluate({"expr": _ESCAPE_EXPR})
    # ...yet the parse itself, one line above where `_evaluate` calls it, already walked the live class
    # graph — proven directly and independently in the previous tests.
