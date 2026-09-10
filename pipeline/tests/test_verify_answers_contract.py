"""Deepened coverage for `verify/answers.py` beyond the implementer's smoke (I1, AC2, AC3).

`contracts/data-model.md` § Probe answer derivation (v1.1.0): a parse failure, an unknown name, a leftover
free symbol, an unbound `unknown`, zero solutions, more than one solution under `select: only`, or a
non-rational result is `LO_PROBE_UNCHECKABLE` and fails the build; a mismatch beyond `tolerance` fails the
build; nothing is rounded, nothing is approximated, nothing is inferred, and no model participates.
"""

from __future__ import annotations

import json
import re
from fractions import Fraction
from pathlib import Path
from typing import Any

import pytest

from mathmath_pipeline import REPO_ROOT
from mathmath_pipeline.verify.answers import (
    LO_PROBE_UNCHECKABLE,
    AnswerMismatch,
    UncheckableCheck,
    UncheckableItem,
    derive_from_check,
    verify_numeric_answers,
)

DEMO = REPO_ROOT / "data" / "demo"
VERIFY_PACKAGE = REPO_ROOT / "pipeline" / "src" / "mathmath_pipeline" / "verify"


def _nodes_file(items: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "nodes": [
            {
                "id": "fixture-node",
                "error_types": [{"id": "sign-error", "description": "flips a sign"}],
                "probe_items": items,
            }
        ]
    }


def _numeric_item(
    item_id: str, check: dict[str, Any], value: str, tolerance: str | None = None
) -> dict[str, Any]:
    answer: dict[str, Any] = {"value": value}
    if tolerance is not None:
        answer["tolerance"] = tolerance
    return {"id": item_id, "type": "numeric", "check": check, "answer": answer}


# ---------------------------------------------------------------------------
# I1's three build-failing conditions — each with its own test and negative control.
# ---------------------------------------------------------------------------


def test_condition_1_incomplete_coverage_is_never_silently_accepted() -> None:
    """Reconstruct the defect I1's coverage clause exists to forbid: a scanner that only inspects the first
    numeric item per node would silently miss a mismatch buried in the second item. Prove the real
    `verify_numeric_answers` (which walks every item) catches what a partial scan would miss — the guard's
    negative control (C2)."""
    ok_item = _numeric_item("item-1", {"kind": "evaluate", "expr": "1 + 1"}, "2")
    broken_item = _numeric_item("item-2", {"kind": "evaluate", "expr": "3 + 3"}, "999")
    nodes_file = _nodes_file([ok_item, broken_item])

    def _partial_scan_defect(nf: dict[str, Any]) -> list[dict[str, Any]]:
        """A defective scanner in the shape I1's coverage clause forbids: only the first numeric item."""
        found: list[dict[str, Any]] = []
        for node in nf["nodes"]:
            numeric = [i for i in node.get("probe_items", []) if i["type"] == "numeric"]
            if numeric:
                found.append(numeric[0])
        return found

    partial = _partial_scan_defect(nodes_file)
    assert len(partial) == 1, "the defect: a partial scan silently drops item-2 entirely"

    uncheckable, mismatches = verify_numeric_answers(nodes_file)
    assert uncheckable == []
    assert [m.item_id for m in mismatches] == ["item-2"], "the real, full scan catches what the defect misses"


def test_condition_1_anti_vacuity_reds_on_an_empty_bundle() -> None:
    """An empty `nodes_file` trivially returns `([], [])` from `verify_numeric_answers` — indistinguishable
    from 'everything passed' without an independent item-count assertion (AC2's anti-vacuity clause). Prove
    the count-assertion pattern the companion test relies on genuinely REDS on this empty shape."""
    empty: dict[str, Any] = {"nodes": []}
    uncheckable, mismatches = verify_numeric_answers(empty)
    assert uncheckable == []
    assert mismatches == []
    numeric_items = [
        item for node in empty["nodes"] for item in node.get("probe_items", []) if item["type"] == "numeric"
    ]
    with pytest.raises(AssertionError):
        assert len(numeric_items) > 0, "vacuous: zero numeric items scanned"


def test_condition_2_uncheckable_item_reported_not_silently_skipped() -> None:
    """A `check` the CAS cannot derive exactly (`Eq(x + 1, x + 2)`, no solution) is collected as an
    `UncheckableItem` with a `reason`, never silently omitted from the result and never turned into a
    passing value (I1)."""
    item = _numeric_item(
        "unsolvable", {"kind": "solve", "equations": ["Eq(x + 1, x + 2)"], "unknown": "x"}, "0"
    )
    nodes_file = _nodes_file([item])
    uncheckable, mismatches = verify_numeric_answers(nodes_file)
    assert mismatches == []
    assert len(uncheckable) == 1
    assert uncheckable[0] == UncheckableItem(
        node_id="fixture-node", item_id="unsolvable", reason=uncheckable[0].reason
    )
    assert uncheckable[0].reason  # a reason string is always attached, never blank


def test_condition_2_negative_control_a_derivable_check_is_not_flagged_uncheckable() -> None:
    """The negative control for condition 2: a genuinely derivable `check` must NOT land in the uncheckable
    list — proves the guard doesn't over-fire on ordinary content."""
    item = _numeric_item("solvable", {"kind": "solve", "equations": ["Eq(2*x, 6)"], "unknown": "x"}, "3")
    nodes_file = _nodes_file([item])
    uncheckable, mismatches = verify_numeric_answers(nodes_file)
    assert uncheckable == []
    assert mismatches == []


def test_condition_3_mismatch_beyond_tolerance_fails() -> None:
    """A derived value differing from `answer.value` beyond `tolerance` is an `AnswerMismatch`, printed by
    node/item id (AC3) — proven with the implementer's `2+2` vs `5` shape, kept alive here as its own test
    so this file does not depend on the implementer's own fixture surviving unmodified."""
    item = _numeric_item("mismatch", {"kind": "evaluate", "expr": "2 + 2"}, "5")
    nodes_file = _nodes_file([item])
    uncheckable, mismatches = verify_numeric_answers(nodes_file)
    assert uncheckable == []
    assert mismatches == [
        AnswerMismatch(node_id="fixture-node", item_id="mismatch", declared_value="5", derived_value="4")
    ]


def test_condition_3_tolerance_boundary_inclusive_pass_exclusive_fail() -> None:
    """`contracts/data-model.md`: "compared ... within `answer.tolerance`" — the comparison in
    `verify_numeric_answers` is `abs(derived - declared) > tolerance`, i.e. exactly-at-tolerance PASSES and
    anything beyond FAILS. Prove the exact boundary with exact `Fraction` arithmetic, not floats."""
    derived = Fraction(1, 3)
    declared = Fraction("0.34")
    exact_diff = abs(derived - declared)
    assert exact_diff == Fraction(1, 150)

    at_boundary = _numeric_item(
        "boundary-pass", {"kind": "evaluate", "expr": "Rational(1, 3)"}, "0.34", tolerance=str(exact_diff)
    )
    just_inside = _numeric_item(
        "boundary-fail",
        {"kind": "evaluate", "expr": "Rational(1, 3)"},
        "0.34",
        tolerance=str(exact_diff - Fraction(1, 100000)),
    )
    nodes_file = _nodes_file([at_boundary, just_inside])
    uncheckable, mismatches = verify_numeric_answers(nodes_file)
    assert uncheckable == []
    assert [m.item_id for m in mismatches] == ["boundary-fail"], (
        "exactly-at-tolerance must PASS (boundary inclusive); anything beyond it must FAIL"
    )


# ---------------------------------------------------------------------------
# No silent confirmation — the failure mode I1 exists to prevent (a mis-parse that "confirms" a
# hand-authored answer).
# ---------------------------------------------------------------------------


def test_no_silent_confirmation_subtly_wrong_expression_still_mismatches() -> None:
    """A `check.expr` that is subtly wrong relative to the intended prompt (sign flipped) must not be
    silently accepted just because *some* value was derived — the derived value still has to match
    `answer.value`, and a subtle authoring error surfaces as a mismatch, not a pass."""
    # Intended prompt: "-3 - (-7)" = 4. Subtly wrong check: "-3 - 7" = -10 (dropped the double negative).
    item = _numeric_item("subtle", {"kind": "evaluate", "expr": "-3 - 7"}, "4")
    nodes_file = _nodes_file([item])
    uncheckable, mismatches = verify_numeric_answers(nodes_file)
    assert uncheckable == []
    assert len(mismatches) == 1
    assert mismatches[0].derived_value == "-10"


def test_no_silent_confirmation_multiple_solutions_under_select_only_is_uncheckable() -> None:
    """`Eq(x**2, 4)` has two solutions (2 and -2); `select: only` requires exactly one distinct bound value.
    A sloppy implementation might pick the first one found and silently "confirm" a hand-authored answer of
    either sign — this must instead be `UncheckableItem`, never a guessed value."""
    item = _numeric_item(
        "two-solutions",
        {"kind": "solve", "equations": ["Eq(x**2, 4)"], "unknown": "x", "select": "only"},
        "2",
    )
    nodes_file = _nodes_file([item])
    uncheckable, mismatches = verify_numeric_answers(nodes_file)
    assert mismatches == []
    assert len(uncheckable) == 1
    assert "one distinct" in uncheckable[0].reason


def test_no_silent_confirmation_leftover_free_symbol_after_substitution_is_uncheckable() -> None:
    """`expr: "x + y"` with only `x` substituted via `at` leaves `y` free — a sloppy implementation might
    silently treat the unsubstituted symbol as zero or drop it; this must be `UncheckableItem`."""
    item = _numeric_item("leftover-symbol", {"kind": "evaluate", "expr": "x + y", "at": {"x": "1"}}, "1")
    nodes_file = _nodes_file([item])
    uncheckable, mismatches = verify_numeric_answers(nodes_file)
    assert mismatches == []
    assert len(uncheckable) == 1
    assert "leftover" in uncheckable[0].reason.lower()


def test_no_silent_confirmation_unbound_unknown_is_uncheckable() -> None:
    """`unknown` must be a free symbol of the equation set; asking for the value of a symbol the equations
    never mention must never silently resolve to a default (e.g. zero)."""
    item = _numeric_item(
        "unbound-unknown", {"kind": "solve", "equations": ["Eq(x + 1, 3)"], "unknown": "y"}, "0"
    )
    nodes_file = _nodes_file([item])
    uncheckable, mismatches = verify_numeric_answers(nodes_file)
    assert mismatches == []
    assert len(uncheckable) == 1


def test_no_silent_confirmation_name_outside_allowlist_is_uncheckable() -> None:
    """A `check.expr` calling a name outside the nine-plus-two allow-list must not silently evaluate to
    some numeric-looking coincidence; it must be `UncheckableItem`."""
    item = _numeric_item("off-allowlist", {"kind": "evaluate", "expr": "factorial(3)"}, "6")
    nodes_file = _nodes_file([item])
    uncheckable, mismatches = verify_numeric_answers(nodes_file)
    assert mismatches == []
    assert len(uncheckable) == 1


def test_missing_check_field_is_uncheckable_not_a_crash() -> None:
    """A `numeric` item missing its `check` field entirely (schema violation / untrusted input) is recorded
    as `UncheckableItem` with a `missing key` reason — never an unhandled `KeyError` propagating out, and
    never silently skipped."""
    item = {"id": "no-check", "type": "numeric", "answer": {"value": "1"}}
    nodes_file = _nodes_file([item])
    uncheckable, mismatches = verify_numeric_answers(nodes_file)
    assert mismatches == []
    assert len(uncheckable) == 1
    assert "check" in uncheckable[0].reason


def test_derive_from_check_raises_typed_exception_never_a_default_value() -> None:
    """`derive_from_check` itself (not the walking wrapper) raises `UncheckableCheck` — never returns a
    sentinel/default `Fraction` for an unresolvable check."""
    with pytest.raises(UncheckableCheck):
        derive_from_check({"kind": "evaluate", "expr": "undeclared_name_xyz(1)"})
    with pytest.raises(UncheckableCheck):
        derive_from_check({"kind": "bogus"})


# ---------------------------------------------------------------------------
# No rounding, no `evalf`, no bare `except` anywhere in verify/ (structural scan).
# ---------------------------------------------------------------------------


def _verify_source_files() -> list[Path]:
    files = sorted(VERIFY_PACKAGE.glob("*.py"))
    assert len(files) >= 3, "anti-vacuity: expected at least the three verify/ modules"
    return files


def test_no_evalf_anywhere_in_verify_package() -> None:
    for path in _verify_source_files():
        assert "evalf" not in path.read_text(), f"{path} calls evalf — approximation is forbidden (I1)"


def test_no_round_call_anywhere_in_verify_package() -> None:
    for path in _verify_source_files():
        assert re.search(r"\bround\s*\(", path.read_text()) is None, (
            f"{path} calls round() — rounding is forbidden (I1)"
        )


def test_no_bare_except_anywhere_in_verify_package() -> None:
    for path in _verify_source_files():
        text = path.read_text()
        assert re.search(r"except\s*:", text) is None, f"{path} has a bare `except:` clause"


# ---------------------------------------------------------------------------
# Idempotency / purity — pure function over its input dict, no mutation, no disk write.
# ---------------------------------------------------------------------------


def test_verify_numeric_answers_is_idempotent_and_does_not_mutate_input() -> None:
    nodes_file = json.loads((DEMO / "nodes.json").read_text())
    before = json.loads(json.dumps(nodes_file))
    first = verify_numeric_answers(nodes_file)
    second = verify_numeric_answers(nodes_file)
    assert first == second
    assert nodes_file == before, "verify_numeric_answers must never mutate its input"


def test_verify_numeric_answers_writes_nothing_to_disk(tmp_path: Path) -> None:
    """Run against an isolated in-memory fixture and confirm no file appears under a scratch directory the
    function has no reason to touch — a stand-in for 'this function is pure'."""
    before = set(tmp_path.iterdir())
    item = _numeric_item("pure-check", {"kind": "evaluate", "expr": "1 + 1"}, "2")
    verify_numeric_answers(_nodes_file([item]))
    after = set(tmp_path.iterdir())
    assert before == after


# ---------------------------------------------------------------------------
# LO_PROBE_UNCHECKABLE constant sanity (used by every uncheckable-list assertion above).
# ---------------------------------------------------------------------------


def test_lo_probe_uncheckable_constant_is_the_registered_code() -> None:
    registry = json.loads((REPO_ROOT / "contracts" / "error-codes.json").read_text())
    codes = {entry["code"] for entry in registry["codes"]}
    assert LO_PROBE_UNCHECKABLE == "LO_PROBE_UNCHECKABLE"
    assert LO_PROBE_UNCHECKABLE in codes
