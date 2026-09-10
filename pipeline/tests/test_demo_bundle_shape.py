"""Shape assertions over `data/demo/` (epic-01-task-05, amendment 01.05.2).

Scoped to `data/demo/`'s own files only, never a whole-repo scan, so a later task's `data/<other-bundle>/`
cannot falsify these assertions. This is the companion test for task 01.5's hand-authored bundle; the
integration test (SymPy re-derivation, tag enum, live landmark resolution) is `test_demo_bundle.py`,
reserved for task 01.7.
"""

from __future__ import annotations

import json
from typing import Any

from mathmath_pipeline import REPO_ROOT

DEMO = REPO_ROOT / "data" / "demo"


def _load(name: str) -> dict[str, Any]:
    return json.loads((DEMO / f"{name}.json").read_text())


def test_node_count_in_range() -> None:
    nodes = _load("nodes")["nodes"]
    assert 18 <= len(nodes) <= 24


def test_starting_chain_nodes_exist() -> None:
    manifest = _load("manifest")
    nodes = _load("nodes")["nodes"]
    node_ids = {n["id"] for n in nodes}
    chain = manifest["starting_chain"]
    assert chain
    for node_id in chain:
        assert node_id in node_ids


def test_exactly_two_courses_with_enough_units() -> None:
    courses = _load("courses")["courses"]
    codes = {c["course_code"] for c in courses}
    assert codes == {"MTH1W", "MCR3U"}
    for course in courses:
        assert len(course["units"]) >= 3


def test_next_courses_literal_values() -> None:
    courses = {c["course_code"]: c for c in _load("courses")["courses"]}
    assert courses["MTH1W"]["next_courses"] == ["MPM2D"]
    assert courses["MCR3U"]["next_courses"] == ["MHF4U"]


def test_every_node_region_confined_to_three_populated_regions() -> None:
    nodes = _load("nodes")["nodes"]
    allowed = {"number-operations", "algebra", "functions"}
    for node in nodes:
        assert node["region_id"] in allowed


def test_mc_distractors_tagged_from_owning_nodes_own_error_types() -> None:
    nodes = _load("nodes")["nodes"]
    for node in nodes:
        allowlist = {et["id"] for et in node["error_types"]}
        for item in node["probe_items"]:
            if item["type"] != "mc":
                continue
            correct_id = item["correct_choice_id"]
            for choice in item["choices"]:
                if choice["id"] == correct_id:
                    continue
                error_type_id = choice.get("error_type_id")
                assert error_type_id is not None
                assert error_type_id != "none-of-these"
                assert error_type_id in allowlist


def test_exactly_one_landmark_sourced_and_cross_region() -> None:
    landmarks = _load("landmarks")["landmarks"]
    assert len(landmarks) == 1
    landmark = landmarks[0]
    assert landmark["source_url"] == "https://laws-lois.justice.gc.ca/eng/acts/I-15/"
    assert len(landmark["node_ids"]) >= 2
    nodes_by_id = {n["id"]: n for n in _load("nodes")["nodes"]}
    region_ids = {nodes_by_id[node_id]["region_id"] for node_id in landmark["node_ids"]}
    assert len(region_ids) >= 2
