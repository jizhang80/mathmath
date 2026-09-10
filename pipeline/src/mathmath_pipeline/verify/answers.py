"""SymPy re-derivation of `numeric` ProbeItem answers from the item's `check` field alone (I1).

`contracts/data-model.md` § Probe answer derivation (v1.1.0): the pipeline derives every `numeric` answer
from `check`; `prompt_latex` is never parsed and no model participates. Parsing uses `sympy.parse_expr`
with `standard_transformations + (rationalize,)` and a closed nine-name allow-list (`Eq`, `Rational`,
`sqrt`, `log`, `exp`, `Abs`, `diff`, `pi`, `E`). Any other name parses to a free symbol; calling one raises.

`sympy` ships no type stubs (`reportMissingTypeStubs`) and its dynamically-built classes resolve to
`Unknown` under pyright strict; every value pyright cannot type from a `sympy` call is cast to `sympy.Basic`
immediately at the call site so nothing `Unknown` propagates into this module's own signatures.
"""

from __future__ import annotations

from dataclasses import dataclass
from fractions import Fraction
from typing import Any, cast

import sympy  # pyright: ignore[reportMissingTypeStubs] -- sympy ships no type stubs (docs/tech-stack.md pin)
from sympy.parsing.sympy_parser import (  # pyright: ignore[reportMissingTypeStubs]
    rationalize,
    standard_transformations,
)

LO_PROBE_UNCHECKABLE = "LO_PROBE_UNCHECKABLE"

# The closed nine-name allow-list an authored `check.expr`/`check.equations` string may reference
# (`contracts/data-model.md` § Probe answer derivation). `Symbol` and `Integer` are added below only
# because `sympy.parse_expr`'s own `standard_transformations` inject literal `Symbol(...)`/`Integer(...)`
# calls into the parsed code for bare variable names and integer literals respectively (this is a
# mechanical requirement of `parse_expr` itself, not an expansion of what an authored expression may
# invoke): with a custom `global_dict`, sympy's own default `from sympy import *` namespace is not
# available, so these two constructor names must be supplied for any legitimate `check` to parse at all.
# A name outside this set still parses to an inert free symbol or raises on call, exactly as the contract
# specifies.
# sympy's own members resolve to partially-`Unknown` signatures under pyright strict (no stubs shipped);
# each is a plain reference to a documented sympy public name, not a computed/dynamic lookup.
_ALLOWED_FUNCTIONS: dict[str, Any] = {
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
ALLOWED_NAMES: dict[str, Any] = {**_ALLOWED_FUNCTIONS, "Symbol": sympy.Symbol, "Integer": sympy.Integer}

TRANSFORMATIONS = standard_transformations + (rationalize,)


class UncheckableCheck(Exception):
    """Raised by `derive_from_check` when the contract's derivation algorithm cannot produce a value."""

    def __init__(self, reason: str) -> None:
        super().__init__(reason)
        self.reason = reason


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


def _parse(source: str) -> sympy.Basic:
    try:
        parsed = sympy.parse_expr(
            source, transformations=TRANSFORMATIONS, global_dict=ALLOWED_NAMES, local_dict={}
        )
    except Exception as exc:
        raise UncheckableCheck(f"parse failure: {exc}") from exc
    if not isinstance(parsed, sympy.Basic):
        raise UncheckableCheck(f"parse did not produce a SymPy expression: {source!r}")
    return parsed


def _parse_expr(source: str) -> sympy.Expr:
    """Like `_parse`, but additionally requires the result to be an expression, never an equation."""
    parsed = _parse(source)
    if not isinstance(parsed, sympy.Expr):
        raise UncheckableCheck(f"expected an expression, got {type(parsed).__name__}: {source!r}")
    return parsed


def _free_symbol_names(expr: sympy.Basic) -> set[str]:
    symbols = cast("set[sympy.Symbol]", expr.free_symbols)
    return {symbol.name for symbol in symbols}


def _simplify(expr: sympy.Expr) -> sympy.Expr:
    return sympy.simplify(expr)  # pyright: ignore[reportUnknownMemberType]


def _evaluate(check: dict[str, Any]) -> sympy.Expr:
    expr = _parse_expr(check["expr"])
    free_names = _free_symbol_names(expr)
    at: dict[str, str] = check.get("at", {})
    substitutions: list[tuple[sympy.Basic, sympy.Basic]] = []
    for name, value in at.items():
        if name not in free_names:
            raise UncheckableCheck(f"`at` key {name!r} is not a free symbol of `expr`")
        substitutions.append((sympy.Symbol(name), _parse_expr(value)))
    substituted = expr.subs(substitutions)
    if not isinstance(substituted, sympy.Expr):
        raise UncheckableCheck(f"substitution did not produce an expression: {substituted!r}")
    if _free_symbol_names(substituted):
        raise UncheckableCheck(f"leftover free symbols after substitution: {_free_symbol_names(substituted)}")
    return substituted


def _solve(check: dict[str, Any]) -> sympy.Expr:
    equations = [_parse(equation) for equation in check["equations"]]
    all_free: set[sympy.Symbol] = set()
    for equation in equations:
        all_free |= cast("set[sympy.Symbol]", equation.free_symbols)
    unknown_name = check["unknown"]
    unknown = sympy.Symbol(unknown_name)
    if unknown not in all_free:
        raise UncheckableCheck(f"unknown {unknown_name!r} is not a free symbol of the equations")
    unknowns = sorted(all_free, key=str)
    solutions = cast(
        "list[dict[sympy.Symbol, sympy.Expr]]",
        sympy.solve(equations, unknowns, dict=True),  # pyright: ignore[reportUnknownMemberType]
    )
    bound = [solution[unknown] for solution in solutions if unknown in solution]
    if not bound:
        raise UncheckableCheck(f"zero solutions bind unknown {unknown_name!r}")
    select = check.get("select", "only")
    distinct: list[sympy.Expr] = list({_simplify(value) for value in bound})
    if select == "only":
        if len(distinct) != 1:
            raise UncheckableCheck(
                f"select: only requires exactly one distinct bound value, got {len(distinct)}"
            )
        return distinct[0]
    if select == "max":
        return max(distinct)
    if select == "min":
        return min(distinct)
    raise UncheckableCheck(f"unknown select value {select!r}")


def derive_from_check(check: dict[str, Any]) -> Fraction:
    """Derive the answer a `numeric` ProbeItem's `check` field declares, using SymPy alone (I1)."""
    kind = check.get("kind")
    if kind == "evaluate":
        value = _evaluate(check)
    elif kind == "solve":
        value = _solve(check)
    else:
        raise UncheckableCheck(f"unknown check kind {kind!r}")
    value = _simplify(value)
    if not value.is_Rational:
        raise UncheckableCheck(f"derived value is not an exact rational: {value}")
    return Fraction(str(value))


def verify_numeric_answers(
    nodes_file: dict[str, Any],
) -> tuple[list[UncheckableItem], list[AnswerMismatch]]:
    """Re-derive every `numeric` ProbeItem's answer from its `check` field and compare to `answer.value`."""
    uncheckable: list[UncheckableItem] = []
    mismatches: list[AnswerMismatch] = []
    for node in nodes_file["nodes"]:
        node_id = node["id"]
        for item in node.get("probe_items", []):
            if item["type"] != "numeric":
                continue
            item_id = item["id"]
            try:
                check = item["check"]
                derived = derive_from_check(check)
            except UncheckableCheck as exc:
                uncheckable.append(UncheckableItem(node_id=node_id, item_id=item_id, reason=exc.reason))
                continue
            except KeyError as exc:
                uncheckable.append(
                    UncheckableItem(node_id=node_id, item_id=item_id, reason=f"missing key {exc}")
                )
                continue
            declared = Fraction(item["answer"]["value"])
            tolerance = Fraction(str(item["answer"].get("tolerance", 0)))
            if abs(derived - declared) > tolerance:
                mismatches.append(
                    AnswerMismatch(
                        node_id=node_id,
                        item_id=item_id,
                        declared_value=str(declared),
                        derived_value=str(derived),
                    )
                )
    return uncheckable, mismatches
