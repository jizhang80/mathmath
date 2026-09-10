"""On-enum distractor-tag validation (`contracts/content-policy.md` § Generated content).

Every `mc` distractor and every `numeric` item's `wrong_answers[]` entry must name an `error_type_id` drawn
from its own node's `error_types[]`, and never the literal `"none-of-these"`.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

LO_BAD_DISTRACTOR_TAG = "LO_BAD_DISTRACTOR_TAG"
BANNED_TAG = "none-of-these"


@dataclass(frozen=True)
class BadDistractorTag:
    node_id: str
    item_id: str
    entry_id: str
    error_type_id: str | None


def find_bad_distractor_tags(nodes_file: dict[str, Any]) -> list[BadDistractorTag]:
    """Flag every `mc` distractor and `numeric` `wrong_answers[]` entry whose tag is off-enum or banned."""
    violations: list[BadDistractorTag] = []
    for node in nodes_file["nodes"]:
        node_id = node["id"]
        allowed = {error_type["id"] for error_type in node["error_types"]}
        for item in node.get("probe_items", []):
            item_id = item["id"]
            if item["type"] == "mc":
                correct_id = item["correct_choice_id"]
                for choice in item["choices"]:
                    if choice["id"] == correct_id:
                        continue
                    error_type_id = choice.get("error_type_id")
                    if error_type_id is None or error_type_id == BANNED_TAG or error_type_id not in allowed:
                        violations.append(
                            BadDistractorTag(
                                node_id=node_id,
                                item_id=item_id,
                                entry_id=choice["id"],
                                error_type_id=error_type_id,
                            )
                        )
            elif item["type"] == "numeric":
                for wrong_answer in item.get("wrong_answers", []):
                    error_type_id = wrong_answer.get("error_type_id")
                    if error_type_id is None or error_type_id == BANNED_TAG or error_type_id not in allowed:
                        violations.append(
                            BadDistractorTag(
                                node_id=node_id,
                                item_id=item_id,
                                entry_id=wrong_answer.get("value", "<unknown>"),
                                error_type_id=error_type_id,
                            )
                        )
    return violations
