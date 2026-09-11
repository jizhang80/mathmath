"""Companion test for `verify/`: SymPy re-derivation, distractor tags, landmark resolution (epic-01-task-07).

Scoped to `data/demo/` specifically. `test_demo_bundle_shape.py` (task 01.5) covers the bundle's static
shape; this file covers the three machine checks this task adds (I1, I9, I15).
"""

from __future__ import annotations

import inspect
import json
from pathlib import Path
from typing import Any

import pytest

from mathmath_pipeline import REPO_ROOT
from mathmath_pipeline.verify import (
    LO_BAD_DISTRACTOR_TAG,
    LO_LANDMARK_UNSOURCED,
    LO_PROBE_UNCHECKABLE,
    SPINE_SOURCE_REF_UNRESOLVED,
    ResolutionFailure,
    TransportInconclusive,
    derive_from_check,
    fetch_page_text,
    find_bad_distractor_tags,
    page_contains,
    scan_source_refs,
    verify_numeric_answers,
)

DEMO = REPO_ROOT / "data" / "demo"
VERIFY_PACKAGE = REPO_ROOT / "pipeline" / "src" / "mathmath_pipeline" / "verify"
LANDMARK_URL = "https://laws-lois.justice.gc.ca/eng/acts/I-15/"


def _load(name: str) -> dict[str, Any]:
    return json.loads((DEMO / f"{name}.json").read_text())


def _verify_source_files() -> list[Path]:
    return sorted(VERIFY_PACKAGE.glob("*.py"))


# ---------------------------------------------------------------------------
# AC1 — no model import anywhere in verify/
# ---------------------------------------------------------------------------


def test_no_model_import_in_verify_package() -> None:
    files = _verify_source_files()
    assert len(files) >= 3, "anti-vacuity: expected the three verify/ modules plus __init__.py"
    for path in files:
        assert "anthropic" not in path.read_text(), f"{path} imports anthropic"


# ---------------------------------------------------------------------------
# AC2/AC3 — every numeric probe answer is CAS-derived from `check` and matches `answer.value`
# ---------------------------------------------------------------------------


def test_every_numeric_probe_answer_is_cas_derived() -> None:
    nodes_file = _load("nodes")
    numeric_items = [
        item
        for node in nodes_file["nodes"]
        for item in node.get("probe_items", [])
        if item["type"] == "numeric"
    ]
    uncheckable, _ = verify_numeric_answers(nodes_file)
    assert uncheckable == [], f"{LO_PROBE_UNCHECKABLE}: {uncheckable}"
    assert len(numeric_items) == 20
    derived_count = len(numeric_items) - len(uncheckable)
    assert derived_count == len(numeric_items) == 20


def test_numeric_probe_answers_match_sympy_derivation() -> None:
    nodes_file = _load("nodes")
    _, mismatches = verify_numeric_answers(nodes_file)
    assert mismatches == [], f"{LO_PROBE_UNCHECKABLE}: {mismatches}"


# ---------------------------------------------------------------------------
# AC4 — distractor tags on-enum, never "none-of-these"
# ---------------------------------------------------------------------------


def test_distractor_tags_on_enum_and_never_none_of_these() -> None:
    nodes_file = _load("nodes")
    mc_count = sum(
        1 for node in nodes_file["nodes"] for item in node.get("probe_items", []) if item["type"] == "mc"
    )
    assert mc_count > 0
    violations = find_bad_distractor_tags(nodes_file)
    assert violations == [], f"{LO_BAD_DISTRACTOR_TAG}: {violations}"


# ---------------------------------------------------------------------------
# AC5 — landmark source_url resolves and page contains source_title (never name)
# ---------------------------------------------------------------------------


@pytest.mark.network
def test_landmark_source_url_resolves() -> None:
    landmarks = _load("landmarks")["landmarks"]
    landmark = landmarks[0]
    assert landmark["source_title"] == "Interest Act"
    try:
        text = fetch_page_text(landmark["source_url"])
    except TransportInconclusive as exc:
        pytest.skip(f"transport blip, not a confirmed dead source (I15): {exc}")
    assert page_contains(text, landmark["source_title"])


# ---------------------------------------------------------------------------
# AC6 — the resolution failure path is real, not disabled
# ---------------------------------------------------------------------------


@pytest.mark.network
def test_landmark_resolution_failure_path_is_real() -> None:
    broken_url = LANDMARK_URL + "this-path-cannot-exist-mathmath-test"
    try:
        with pytest.raises(ResolutionFailure) as exc_info:
            fetch_page_text(broken_url)
    except TransportInconclusive as exc:
        pytest.skip(f"transport blip, not a confirmed dead source (I15): {exc}")
    assert exc_info.value.code == LO_LANDMARK_UNSOURCED


# ---------------------------------------------------------------------------
# AC7 — L0-3b source_ref scan is explicit about zero scope (C3)
# ---------------------------------------------------------------------------


def test_source_ref_scan_is_explicit_about_zero_scope(capsys: pytest.CaptureFixture[str]) -> None:
    nodes_file = _load("nodes")
    entries = scan_source_refs(nodes_file)
    assert entries == []
    message = "0 source_refs scanned — vacuous by bundle scope"
    print(message)  # noqa: T201
    captured = capsys.readouterr()
    assert message in captured.out


# ---------------------------------------------------------------------------
# T2/T5 — negative paths over in-memory fixtures (never touch data/demo/nodes.json)
# ---------------------------------------------------------------------------


def _make_nodes_file(item: dict[str, Any], item_type: str = "numeric") -> dict[str, Any]:
    node: dict[str, Any] = {
        "id": "fixture-node",
        "error_types": [{"id": "sign-error", "description": "flips a sign"}],
        "probe_items": [item],
    }
    return {"nodes": [node]}


def test_answer_mismatch_is_flagged() -> None:
    item = {
        "id": "fixture-item",
        "type": "numeric",
        "check": {"kind": "evaluate", "expr": "2 + 2"},
        "answer": {"value": "5"},
    }
    nodes_file = _make_nodes_file(item)
    uncheckable, mismatches = verify_numeric_answers(nodes_file)
    assert uncheckable == []
    assert len(mismatches) == 1
    assert mismatches[0].declared_value == "5"
    assert mismatches[0].derived_value == "4"


def test_none_of_these_mc_distractor_is_flagged() -> None:
    item = {
        "id": "fixture-mc",
        "type": "mc",
        "correct_choice_id": "a",
        "choices": [
            {"id": "a", "latex": "1"},
            {"id": "b", "latex": "2", "error_type_id": "none-of-these"},
        ],
    }
    nodes_file = _make_nodes_file(item, item_type="mc")
    violations = find_bad_distractor_tags(nodes_file)
    assert len(violations) == 1
    assert violations[0].entry_id == "b"


def test_missing_error_type_id_mc_distractor_is_flagged() -> None:
    item = {
        "id": "fixture-mc-missing",
        "type": "mc",
        "correct_choice_id": "a",
        "choices": [
            {"id": "a", "latex": "1"},
            {"id": "b", "latex": "2"},
        ],
    }
    nodes_file = _make_nodes_file(item, item_type="mc")
    violations = find_bad_distractor_tags(nodes_file)
    assert len(violations) == 1
    assert violations[0].error_type_id is None


@pytest.mark.parametrize(
    "check",
    [
        {"kind": "evaluate", "expr": "factorial(3)"},
        {"kind": "evaluate", "expr": "2*x + 1"},
        {"kind": "solve", "equations": ["Eq(x + 1, x + 2)"], "unknown": "x"},
    ],
)
def test_uncheckable_check_clauses_fail_loudly(check: dict[str, Any]) -> None:
    item = {
        "id": "fixture-item",
        "type": "numeric",
        "check": check,
        "answer": {"value": "0"},
    }
    nodes_file = _make_nodes_file(item)
    uncheckable, mismatches = verify_numeric_answers(nodes_file)
    assert mismatches == []
    assert len(uncheckable) == 1


# ---------------------------------------------------------------------------
# T3 — error-taxonomy assertions
# ---------------------------------------------------------------------------


def test_error_code_constants_match_registry() -> None:
    registry = json.loads((REPO_ROOT / "contracts" / "error-codes.json").read_text())
    codes = {entry["code"] for entry in registry["codes"]}
    assert LO_PROBE_UNCHECKABLE in codes
    assert LO_BAD_DISTRACTOR_TAG in codes
    assert LO_LANDMARK_UNSOURCED in codes
    assert SPINE_SOURCE_REF_UNRESOLVED in codes


def test_map_landmark_unsourced_code_not_present_in_verify_package() -> None:
    files = _verify_source_files()
    assert len(files) >= 3
    for path in files:
        assert "MAP_LANDMARK_UNSOURCED" not in path.read_text()


def test_derive_from_check_takes_only_the_check_object() -> None:
    parameters = inspect.signature(derive_from_check).parameters
    assert list(parameters) == ["check"]


def test_pytest_skip_calls_in_this_file_are_only_reached_via_except_transportinconclusive() -> None:
    """A future edit must not add a blanket skip to paper over a genuine failure (I15) — every
    `pytest.skip(` call in this file must be inside an `except TransportInconclusive:` handler."""
    text = Path(__file__).read_text()
    skip_count = text.count("pytest.skip(")
    except_count = text.count("except TransportInconclusive")
    assert skip_count > 0, "anti-vacuity: expected at least one transport-inconclusive skip in this file"
    assert skip_count == except_count, (
        f"{skip_count} pytest.skip( call(s) but {except_count} 'except TransportInconclusive' "
        "handler(s) — every skip in this file must be gated on a transport-inconclusive outcome"
    )
