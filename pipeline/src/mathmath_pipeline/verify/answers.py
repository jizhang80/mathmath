"""SymPy re-derivation of `numeric` ProbeItem answers from the item's `check` field alone (I1).

`contracts/data-model.md` § Probe answer derivation (v1.2.0): the pipeline derives every `numeric` answer
from `check`; `prompt_latex` is never parsed and no model participates. Parsing uses `sympy.parse_expr`
with `standard_transformations + (rationalize, restrict_ast_shape)` under **two** closed allow-lists: a
name allow-list (nine semantic names — `Eq`, `Rational`, `sqrt`, `log`, `exp`, `Abs`, `diff`, `pi`, `E` —
plus two structural constructors, `Symbol` and `Integer`, that `standard_transformations` mechanically
injects) and an AST-shape allow-list (`restrict_ast_shape`, below) validated against the exact string that
is evaluated. A name allow-list alone does not close the parse environment: `parse_expr` evaluates its
transformed source with `eval`, and attribute access, subscripting and literal construction are not name
resolution, so an expression using no allow-listed name at all can walk out of the intended sandbox.

`sympy` ships no type stubs (`reportMissingTypeStubs`) and its dynamically-built classes resolve to
`Unknown` under pyright strict; every value pyright cannot type from a `sympy` call is cast to `sympy.Basic`
immediately at the call site so nothing `Unknown` propagates into this module's own signatures.
"""

from __future__ import annotations

import ast
from dataclasses import dataclass
from fractions import Fraction
from tokenize import untokenize
from typing import Any, cast

import sympy  # pyright: ignore[reportMissingTypeStubs] -- sympy ships no type stubs (docs/tech-stack.md pin)
from sympy.parsing.sympy_parser import (  # pyright: ignore[reportMissingTypeStubs]
    rationalize,
    standard_transformations,
)

LO_PROBE_UNCHECKABLE = "LO_PROBE_UNCHECKABLE"

# The nine *semantic* names plus two *structural constructors* (`contracts/data-model.md` § Probe answer
# derivation, v1.2.0). `Symbol` and `Integer` are added below only because `sympy.parse_expr`'s own
# `standard_transformations` inject literal `Symbol(...)`/`Integer(...)` calls into the parsed code for
# bare variable names and integer literals respectively (this is a mechanical requirement of `parse_expr`
# itself, not an expansion of what an authored expression may invoke): with a custom `global_dict`, sympy's
# own default `from sympy import *` namespace is not available, so these two constructor names must be
# supplied for any legitimate `check` to parse at all. Neither adds reachable capability beyond constructing
# an inert value. A name outside this set still parses to an inert free symbol or raises on call.
# The name allow-list alone does NOT close the parse environment (`restrict_ast_shape`, below, is required
# too) — sympy's own members resolve to partially-`Unknown` signatures under pyright strict (no stubs
# shipped); each is a plain reference to a documented sympy public name, not a computed/dynamic lookup.
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


class UnsafeCheckSource(Exception):
    """Raised when a `check` source's transformed AST leaves the permitted node set (data-model v1.2.0)."""

    def __init__(self, reason: str) -> None:
        super().__init__(reason)
        self.reason = reason


# The closed AST-shape allow-list (`contracts/data-model.md` § Probe answer derivation, v1.2.0). Written as
# a literal set of permitted types, never computed by subtraction from a forbidden set — an allow-list
# derived by subtraction is a blocklist wearing a hat.
AST_ALLOWED_NODES: frozenset[type[ast.AST]] = frozenset(
    {
        ast.Expression,
        ast.BinOp,
        ast.UnaryOp,
        ast.Call,
        ast.Name,
        ast.Load,
        ast.Constant,
        ast.Add,
        ast.Sub,
        ast.Mult,
        ast.Div,
        ast.Pow,
        ast.UAdd,
        ast.USub,
    }
)
AST_ALLOWED_NODE_NAMES: frozenset[str] = frozenset(node.__name__ for node in AST_ALLOWED_NODES)
_ALLOWED_CONSTANT_TYPES: tuple[type, ...] = (int, float, str)


def restrict_ast_shape(
    tokens: list[tuple[int, str]], local_dict: dict[str, Any], global_dict: dict[str, Any]
) -> list[tuple[int, str]]:
    """A `sympy` transformation: validate the transformed token stream's AST shape before evaluation.

    Runs last in `TRANSFORMATIONS` so it sees the fully transformed stream — the exact string `eval` is
    about to run — and returns `tokens` unchanged: it is a validator, not a rewriter, so the string sympy
    goes on to evaluate is byte-identical to the string validated.
    """
    code = untokenize(list(tokens))
    tree = ast.parse(code, mode="eval")
    for node in ast.walk(tree):
        if type(node) not in AST_ALLOWED_NODES:
            raise UnsafeCheckSource(f"disallowed AST node {type(node).__name__}")
        if isinstance(node, ast.Name) and node.id not in ALLOWED_NAMES:
            raise UnsafeCheckSource(f"disallowed name {node.id!r}")
        if isinstance(node, ast.Constant) and type(node.value) not in _ALLOWED_CONSTANT_TYPES:
            raise UnsafeCheckSource(f"disallowed constant type {type(node.value).__name__}")
        if isinstance(node, ast.Call) and node.keywords:
            raise UnsafeCheckSource("disallowed keyword argument")
    return tokens


# The guard is last: it must see the fully transformed stream, because that is what is evaluated. Welding
# it into the shared tuple protects any caller that uses `TRANSFORMATIONS`/`ALLOWED_NAMES` directly with
# `sympy.parse_expr`, not only calls that go through `_parse` below.
TRANSFORMATIONS = standard_transformations + (rationalize, restrict_ast_shape)


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
    except UnsafeCheckSource as exc:
        raise UncheckableCheck(f"unsafe check source: {exc.reason}") from exc
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
