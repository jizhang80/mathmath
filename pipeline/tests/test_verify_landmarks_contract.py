"""Deepened coverage for `verify/landmarks.py` beyond the implementer's smoke (AC5, AC6, AC7, L0-3b).

`contracts/content-policy.md` § Landmarks (v1.1.0): `source_url` required and resolving at build (HTTP
2xx); `source_title` required and the fetched page text must contain it (case-insensitive substring); the
landmark's `name` is never asserted against the page. `contracts/graph-constraints.md` L0-3b:
`SPINE_SOURCE_REF_UNRESOLVED` on a `source_ref` whose registered source URL does not resolve.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest

from mathmath_pipeline import REPO_ROOT
from mathmath_pipeline.verify.landmarks import (
    LO_LANDMARK_UNSOURCED,
    SPINE_SOURCE_REF_UNRESOLVED,
    ResolutionFailure,
    SourceRefEntry,
    fetch_page_text,
    page_contains,
    resolve_source_ref,
    scan_source_refs,
)

DEMO = REPO_ROOT / "data" / "demo"
PIPELINE_TESTS = REPO_ROOT / "pipeline" / "tests"
LANDMARK_URL = "https://laws-lois.justice.gc.ca/eng/acts/I-15/"


def _landmark() -> dict[str, Any]:
    return json.loads((DEMO / "landmarks.json").read_text())["landmarks"][0]


# ---------------------------------------------------------------------------
# No mock, no skip can make the live-fetch assertion vacuous (planner note [6], I15).
# ---------------------------------------------------------------------------


def test_no_mock_or_skip_disables_the_live_landmark_check_anywhere_in_pipeline_tests() -> None:
    """I15 / planner note [6]: the landmark resolution check must remain a real HTTP fetch, forever — scan
    every test file that references the landmark check for a mock/monkeypatch/skip that could make the
    live assertion vacuous. This guard covers the implementer's `test_demo_bundle.py` and every file this
    task adds, and will catch a future edit that tries to fake the response."""
    test_files = sorted(PIPELINE_TESTS.glob("test_*.py"))
    assert len(test_files) >= 4, "anti-vacuity: expected multiple pipeline test files"
    self_path = Path(__file__).resolve()
    relevant = [
        path
        for path in test_files
        if path.resolve() != self_path
        and ("fetch_page_text" in path.read_text() or "landmark" in path.read_text().lower())
    ]
    assert relevant, "anti-vacuity: expected at least one test file referencing the landmark check"
    forbidden_tokens = [
        "unittest.mock",
        "monkeypatch",
        "@pytest.mark.skip",
        "pytest.mark.skip(",
        "responses.",
        "vcr.",
        "MagicMock",
        "Mock(",
        "requests_mock",
    ]
    for path in relevant:
        text = path.read_text()
        for token in forbidden_tokens:
            assert token not in text, (
                f"{path} uses {token!r} in a file that references the landmark check — the live fetch "
                "must stay live (I15, planner note [6])"
            )


def test_fetch_page_text_is_the_stdlib_urllib_function_not_a_test_double() -> None:
    """Confirm the function under test is the real module attribute, not something a fixture replaced —
    guards against a `monkeypatch.setattr` that a future edit could slip in without touching this file."""
    import mathmath_pipeline.verify.landmarks as landmarks_module

    assert fetch_page_text is landmarks_module.fetch_page_text
    assert fetch_page_text.__module__ == "mathmath_pipeline.verify.landmarks"


# ---------------------------------------------------------------------------
# page_contains: case-insensitive substring, needle is source_title never name (pure function, no network
# required to test the matching logic itself).
# ---------------------------------------------------------------------------


def test_page_contains_is_case_insensitive_substring_match() -> None:
    page = "An Act respecting Interest ... see also the INTEREST ACT for details."
    assert page_contains(page, "Interest Act")
    assert page_contains(page, "interest act")
    assert page_contains(page, "INTEREST ACT")


def test_page_contains_false_when_title_absent() -> None:
    page = "This page discusses an entirely unrelated statute."
    assert not page_contains(page, "Interest Act")


def test_landmark_name_is_never_used_as_the_needle_anywhere_in_pipeline_tests() -> None:
    """`contracts/content-policy.md` § Landmarks: the landmark's `name` is never asserted against the page.
    Scan every test file for the specific call shape `page_contains(<text>, landmark["name"])` (or the
    dict-literal equivalent `landmark['name']`) to make sure no test — including a future edit — ever
    passes the landmark's descriptive `name` as the needle."""
    test_files = sorted(PIPELINE_TESTS.glob("test_*.py"))
    self_path = Path(__file__).resolve()
    for path in test_files:
        if path.resolve() == self_path:
            continue
        text = path.read_text()
        if "page_contains(" not in text:
            continue
        assert 'landmark["name"]' not in text
        assert "landmark['name']" not in text


# ---------------------------------------------------------------------------
# The one landmark's declared source_title is exactly what §1/AC5 requires — a blanked field cannot make
# the substring check vacuous.
# ---------------------------------------------------------------------------


def test_landmark_source_title_field_is_present_and_nonempty() -> None:
    landmark = _landmark()
    assert landmark["source_title"] == "Interest Act"
    assert landmark["source_title"].strip() != ""


@pytest.mark.network
def test_landmark_source_url_resolution_uses_source_title_not_name_as_needle() -> None:
    """Re-derive the AC5 assertion independently of the implementer's own test, using the real live fetch,
    confirming the needle used is `source_title` and that a (deliberately wrong) needle of `name` would NOT
    be expected to match reliably — `name` is the project's own descriptive claim, not sourced text."""
    landmark = _landmark()
    text = fetch_page_text(landmark["source_url"])
    assert page_contains(text, landmark["source_title"])


# ---------------------------------------------------------------------------
# AC6's negative control, reproduced independently with a different broken path than the implementer's own
# test, to prove the drop path is real under more than one failure shape.
# ---------------------------------------------------------------------------


@pytest.mark.network
def test_fetch_page_text_raises_on_a_nonexistent_host() -> None:
    """A DNS-resolution failure (a host that cannot exist) must propagate as a real network error, never be
    caught to produce a passing result (I15, §4 step 4: "lets `urllib.error.URLError` ... propagate
    unmodified")."""
    import urllib.error

    with pytest.raises(urllib.error.URLError):
        fetch_page_text("https://this-host-cannot-possibly-resolve.mathmath-test-fixture.invalid/")


# ---------------------------------------------------------------------------
# scan_source_refs: idempotency, anti-vacuity, and structural correctness on a node that DOES carry a
# source_ref (data/demo has zero such nodes, so this exercises the walking logic the demo bundle cannot).
# ---------------------------------------------------------------------------


def test_scan_source_refs_finds_a_node_that_carries_one() -> None:
    nodes_file = {
        "nodes": [
            {"id": "with-ref", "source_ref": {"source": "some-source", "locator": "p. 12"}},
            {"id": "without-ref", "expectation_codes": [{"code": "A1.1", "course_code": "MTH1W"}]},
        ]
    }
    entries = scan_source_refs(nodes_file)
    assert entries == [SourceRefEntry(node_id="with-ref", source="some-source", locator="p. 12")]


def test_scan_source_refs_is_idempotent_and_pure() -> None:
    nodes_file = json.loads((DEMO / "nodes.json").read_text())
    before = json.loads(json.dumps(nodes_file))
    first = scan_source_refs(nodes_file)
    second = scan_source_refs(nodes_file)
    assert first == second == []
    assert nodes_file == before


def test_scan_source_refs_anti_vacuity_reds_on_empty_bundle_without_the_c3_message() -> None:
    """AC7 requires the C3 message be printed explicitly rather than silently passing an empty scan. Prove
    the naive 'just assert == []' pattern alone is indistinguishable from a broken scanner that never looks
    at anything — the explicit message assertion (already exercised in `test_demo_bundle.py`) is what makes
    the difference, and its absence is what this test demonstrates by contrast."""
    empty: dict[str, Any] = {"nodes": []}
    entries = scan_source_refs(empty)
    assert entries == []
    # Without an explicit "N source_refs scanned" statement, `entries == []` is silent and vacuous —
    # indistinguishable from a scanner that never ran. C3 requires the explicit statement (AC7).


# ---------------------------------------------------------------------------
# resolve_source_ref: exercised against constructed fixtures since data/demo's scan count is 0 (§6
# decision default) — this path is otherwise completely untested, including its own error code.
# ---------------------------------------------------------------------------


def test_resolve_source_ref_raises_spine_source_ref_unresolved_when_source_not_registered() -> None:
    """The `source` a `source_ref` names must exist in `sources.json`; if it does not, the failure is
    `SPINE_SOURCE_REF_UNRESOLVED`, not a `KeyError`/`StopIteration` leaking out."""
    entry = SourceRefEntry(node_id="orphan-node", source="does-not-exist", locator="p. 3")
    sources_file: dict[str, Any] = {"sources": []}
    with pytest.raises(ResolutionFailure) as exc_info:
        resolve_source_ref(entry, sources_file)
    assert exc_info.value.code == SPINE_SOURCE_REF_UNRESOLVED


@pytest.mark.network
def test_resolve_source_ref_raises_spine_source_ref_unresolved_when_registered_url_404s() -> None:
    """The `source` is registered but its `url` does not resolve — a live fetch against a guaranteed-404
    path, proving `SPINE_SOURCE_REF_UNRESOLVED` (not `LO_LANDMARK_UNSOURCED`) is the code this path raises,
    even though the underlying fetch failure is the same shape as the landmark check's."""
    entry = SourceRefEntry(node_id="some-node", source="broken-source", locator="p. 7")
    sources_file: dict[str, Any] = {
        "sources": [{"source": "broken-source", "url": LANDMARK_URL + "this-path-cannot-exist-source-ref"}]
    }
    with pytest.raises(ResolutionFailure) as exc_info:
        resolve_source_ref(entry, sources_file)
    assert exc_info.value.code == SPINE_SOURCE_REF_UNRESOLVED
    assert exc_info.value.code != LO_LANDMARK_UNSOURCED


@pytest.mark.network
def test_resolve_source_ref_succeeds_silently_when_registered_url_resolves() -> None:
    """The positive control: a registered source whose `url` genuinely resolves raises nothing."""
    entry = SourceRefEntry(node_id="some-node", source="real-source", locator="p. 1")
    sources_file: dict[str, Any] = {"sources": [{"source": "real-source", "url": LANDMARK_URL}]}
    resolve_source_ref(entry, sources_file)  # must not raise


# ---------------------------------------------------------------------------
# Error-code sanity.
# ---------------------------------------------------------------------------


def test_landmark_and_source_ref_codes_are_distinct_and_registered() -> None:
    registry = json.loads((REPO_ROOT / "contracts" / "error-codes.json").read_text())
    codes = {entry["code"] for entry in registry["codes"]}
    assert LO_LANDMARK_UNSOURCED != SPINE_SOURCE_REF_UNRESOLVED
    assert LO_LANDMARK_UNSOURCED in codes
    assert SPINE_SOURCE_REF_UNRESOLVED in codes


def test_resolution_failure_carries_the_failing_url() -> None:
    entry = SourceRefEntry(node_id="n", source="missing", locator="l")
    with pytest.raises(ResolutionFailure) as exc_info:
        resolve_source_ref(entry, {"sources": []})
    assert exc_info.value.url == "missing"
