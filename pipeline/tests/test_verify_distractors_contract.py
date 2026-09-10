"""Deepened coverage for `verify/distractors.py` beyond the implementer's smoke (AC4).

`contracts/content-policy.md` § Generated content, distractor tags: every `mc` distractor and every
`numeric` `wrong_answers[]` entry names an `ErrorType` of its own node; `none-of-these` is never a tag.
"""

from __future__ import annotations

import json
from typing import Any

import pytest

from mathmath_pipeline import REPO_ROOT
from mathmath_pipeline.verify.distractors import BANNED_TAG, BadDistractorTag, find_bad_distractor_tags

DEMO = REPO_ROOT / "data" / "demo"


def _node(error_types: list[dict[str, str]], probe_items: list[dict[str, Any]]) -> dict[str, Any]:
    return {"id": "fixture-node", "error_types": error_types, "probe_items": probe_items}


def _mc_item(item_id: str, choices: list[dict[str, Any]], correct_choice_id: str = "a") -> dict[str, Any]:
    return {"id": item_id, "type": "mc", "correct_choice_id": correct_choice_id, "choices": choices}


def _numeric_item_with_wrong_answers(item_id: str, wrong_answers: list[dict[str, Any]]) -> dict[str, Any]:
    return {"id": item_id, "type": "numeric", "wrong_answers": wrong_answers}


# ---------------------------------------------------------------------------
# The fixture required by the task charge: an error_type_id not in its node's own error_types[].
# ---------------------------------------------------------------------------


def test_mc_distractor_off_node_own_enum_is_flagged_with_item_id() -> None:
    node = _node(
        [{"id": "sign-error", "label": "flips a sign"}],
        [
            _mc_item(
                "item-off-enum",
                [
                    {"id": "a", "latex": "1"},
                    {"id": "b", "latex": "2", "error_type_id": "not-a-member-of-this-nodes-enum"},
                ],
            )
        ],
    )
    nodes_file = {"nodes": [node]}
    violations = find_bad_distractor_tags(nodes_file)
    assert violations == [
        BadDistractorTag(
            node_id="fixture-node",
            item_id="item-off-enum",
            entry_id="b",
            error_type_id="not-a-member-of-this-nodes-enum",
        )
    ]


def test_numeric_wrong_answer_off_node_own_enum_is_flagged_with_item_id() -> None:
    node = _node(
        [{"id": "sign-error", "label": "flips a sign"}],
        [
            _numeric_item_with_wrong_answers(
                "item-numeric-off-enum",
                [{"value": "-10", "error_type_id": "borrowed-from-another-node"}],
            )
        ],
    )
    nodes_file = {"nodes": [node]}
    violations = find_bad_distractor_tags(nodes_file)
    assert len(violations) == 1
    assert violations[0].item_id == "item-numeric-off-enum"
    assert violations[0].error_type_id == "borrowed-from-another-node"


# ---------------------------------------------------------------------------
# The fixture required by the task charge: "none-of-these" as a tag — including the trap case where the
# node's OWN error_types[] legitimately contains "none-of-these" as a member (mirroring real demo data
# shape, e.g. data/demo/nodes.json's "integer-operations" node), proving the banned-tag rule is checked
# independently of enum membership.
# ---------------------------------------------------------------------------


def test_none_of_these_tag_is_flagged_even_when_the_nodes_own_enum_contains_it_as_a_member() -> None:
    node = _node(
        [{"id": "sign-error", "label": "flips a sign"}, {"id": BANNED_TAG, "label": "None of these"}],
        [
            _mc_item(
                "item-none-of-these",
                [
                    {"id": "a", "latex": "1"},
                    {"id": "b", "latex": "2", "error_type_id": BANNED_TAG},
                ],
            )
        ],
    )
    nodes_file = {"nodes": [node]}
    violations = find_bad_distractor_tags(nodes_file)
    assert len(violations) == 1
    assert violations[0].entry_id == "b"
    assert violations[0].error_type_id == BANNED_TAG


def test_none_of_these_tag_on_numeric_wrong_answer_is_flagged() -> None:
    node = _node(
        [{"id": BANNED_TAG, "label": "None of these"}],
        [
            _numeric_item_with_wrong_answers(
                "item-numeric-none", [{"value": "0", "error_type_id": BANNED_TAG}]
            )
        ],
    )
    nodes_file = {"nodes": [node]}
    violations = find_bad_distractor_tags(nodes_file)
    assert len(violations) == 1


# ---------------------------------------------------------------------------
# Negative controls / boundary cases the implementer's smoke does not cover.
# ---------------------------------------------------------------------------


def test_correct_choice_is_never_checked_even_without_an_error_type_id() -> None:
    """Only non-correct choices carry a tag requirement — the correct choice must never be flagged even if
    it has no `error_type_id` (it needs none)."""
    node = _node(
        [{"id": "sign-error", "label": "flips a sign"}],
        [
            _mc_item(
                "item-correct-untagged",
                [{"id": "a", "latex": "1"}, {"id": "b", "latex": "2", "error_type_id": "sign-error"}],
            )
        ],
    )
    nodes_file = {"nodes": [node]}
    violations = find_bad_distractor_tags(nodes_file)
    assert violations == []


def test_on_enum_valid_tag_is_never_flagged() -> None:
    """The positive control: a distractor tag that IS a member of the node's own error_types[] and is not
    the banned tag must never be flagged."""
    node = _node(
        [{"id": "sign-error", "label": "flips a sign"}],
        [
            _mc_item(
                "item-valid",
                [{"id": "a", "latex": "1"}, {"id": "b", "latex": "2", "error_type_id": "sign-error"}],
            )
        ],
    )
    nodes_file = {"nodes": [node]}
    assert find_bad_distractor_tags(nodes_file) == []


def test_numeric_item_with_no_wrong_answers_key_is_not_flagged() -> None:
    """`wrong_answers[]` is optional on a `numeric` item — its absence is not itself a violation."""
    node = _node(
        [{"id": "sign-error", "label": "flips a sign"}], [{"id": "item-no-wrong", "type": "numeric"}]
    )
    nodes_file = {"nodes": [node]}
    assert find_bad_distractor_tags(nodes_file) == []


def test_multiple_violations_in_one_item_are_all_reported() -> None:
    node = _node(
        [{"id": "sign-error", "label": "flips a sign"}],
        [
            _mc_item(
                "item-multi",
                [
                    {"id": "a", "latex": "1"},
                    {"id": "b", "latex": "2"},  # missing error_type_id
                    {"id": "c", "latex": "3", "error_type_id": BANNED_TAG},  # banned
                    {"id": "d", "latex": "4", "error_type_id": "off-enum"},  # off-enum
                ],
            )
        ],
    )
    nodes_file = {"nodes": [node]}
    violations = find_bad_distractor_tags(nodes_file)
    assert {v.entry_id for v in violations} == {"b", "c", "d"}


# ---------------------------------------------------------------------------
# Anti-vacuity and idempotency.
# ---------------------------------------------------------------------------


def test_anti_vacuity_reds_on_an_empty_bundle() -> None:
    empty: dict[str, Any] = {"nodes": []}
    violations = find_bad_distractor_tags(empty)
    assert violations == []
    mc_count = sum(
        1 for node in empty["nodes"] for item in node.get("probe_items", []) if item["type"] == "mc"
    )
    with pytest.raises(AssertionError):
        assert mc_count > 0, "vacuous: zero mc items scanned"


def test_find_bad_distractor_tags_is_idempotent_and_does_not_mutate_input() -> None:
    nodes_file = json.loads((DEMO / "nodes.json").read_text())
    before = json.loads(json.dumps(nodes_file))
    first = find_bad_distractor_tags(nodes_file)
    second = find_bad_distractor_tags(nodes_file)
    assert first == second
    assert nodes_file == before
