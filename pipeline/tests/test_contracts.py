"""Contract enforcement (contracts/README.md, "wired" column).

Instrument per C3: every check states what it scanned; an empty scan is reported explicitly and, where the
contract says so, treated as PASS with a printed note rather than silently.
"""

from __future__ import annotations

import json
import re
from collections.abc import Iterator
from pathlib import Path
from typing import Any, cast

import pytest
from jsonschema import Draft202012Validator

from mathmath_pipeline import REPO_ROOT

CONTRACTS = REPO_ROOT / "contracts"
SCHEMAS = CONTRACTS / "schemas"
EXAMPLES = CONTRACTS / "examples"
DATA = REPO_ROOT / "data"
DOMAINS = REPO_ROOT / "docs" / "domains"

IDENTIFIER_BLOCKLIST = {
    "id",
    "install_id",
    "device_id",
    "session_id",
    "user_id",
    "ip",
    "timestamp",
    "email",
    "name",
}


def _schema(name: str) -> dict[str, Any]:
    return json.loads((SCHEMAS / f"{name}.schema.json").read_text())


def _validator(name: str) -> Draft202012Validator:
    schema = _schema(name)
    Draft202012Validator.check_schema(schema)
    return Draft202012Validator(schema)


JsonValue = dict[str, Any] | list[Any] | str | int | float | bool | None


def _errors(name: str, instance: JsonValue) -> list[str]:
    """Validation error messages for `instance` against schema `name` (jsonschema ships partial stubs)."""
    validator = _validator(name)
    found = validator.iter_errors(instance)  # pyright: ignore[reportUnknownMemberType]
    return sorted(e.message for e in found)


def _schema_name_for(path: Path) -> str:
    return path.stem  # regions.json -> regions; student-state.json -> student-state


@pytest.mark.parametrize("schema_path", sorted(SCHEMAS.glob("*.schema.json")), ids=lambda p: p.name)
def test_schema_is_valid_2020_12(schema_path: Path) -> None:
    schema = json.loads(schema_path.read_text())
    Draft202012Validator.check_schema(schema)
    assert schema["$schema"].endswith("2020-12/schema")


@pytest.mark.parametrize("example", sorted(EXAMPLES.glob("*.json")), ids=lambda p: p.name)
def test_example_validates(example: Path) -> None:
    errors = _errors(_schema_name_for(example), json.loads(example.read_text()))
    assert not errors, "\n".join(errors)


def test_every_schema_has_an_example() -> None:
    schemas = {p.name.removesuffix(".schema.json") for p in SCHEMAS.glob("*.schema.json")}
    examples = {p.stem for p in EXAMPLES.glob("*.json")}
    assert schemas == examples, (
        f"missing examples: {schemas - examples}; stray examples: {examples - schemas}"
    )


def test_data_bundles_validate() -> None:
    files = sorted(p for p in DATA.rglob("*.json"))
    if not files:
        print("data/: no JSON files yet — empty scan = PASS by contract (data-model.md § Enforcement)")  # noqa: T201
        return
    for path in files:
        errors = _errors(_schema_name_for(path), json.loads(path.read_text()))
        assert not errors, f"{path.relative_to(REPO_ROOT)}: " + "; ".join(errors)


def _walk_objects(value: object) -> Iterator[dict[str, Any]]:
    if isinstance(value, dict):
        typed = cast(dict[str, Any], value)
        yield typed
        for child in typed.values():
            yield from _walk_objects(child)
    elif isinstance(value, list):
        for child in cast(list[Any], value):
            yield from _walk_objects(child)


@pytest.mark.parametrize("name", ["telemetry-batch", "student-state"])
def test_transmitted_shapes_reject_identifier_keys(name: str) -> None:
    """I5: inject each blocklisted key at every object nesting level of the example; each must be rejected."""
    validator = _validator(name)
    example = json.loads((EXAMPLES / f"{name}.json").read_text())
    objects = list(_walk_objects(example))
    assert objects, "empty example — scan would be vacuous"
    rejected = 0
    for key in IDENTIFIER_BLOCKLIST:
        for index in range(len(objects)):
            mutated = json.loads(json.dumps(example))
            target = list(_walk_objects(mutated))[index]
            target[key] = "x"
            accepted = validator.is_valid(mutated)  # pyright: ignore[reportUnknownMemberType]  # jsonschema stubs
            assert not accepted, f"{name}: key {key!r} accepted at object #{index}"
            rejected += 1
    assert rejected == len(IDENTIFIER_BLOCKLIST) * len(objects)


def test_telemetry_strings_are_constrained() -> None:
    """telemetry.md: every string field carries a pattern or enum (no free text can be represented)."""
    unconstrained: list[str] = []

    def visit(node: object, path: str) -> None:
        if isinstance(node, dict):
            typed = cast(dict[str, Any], node)
            if typed.get("type") == "string" and not ("pattern" in typed or "enum" in typed):
                unconstrained.append(path)
            for key, child in typed.items():
                visit(child, f"{path}/{key}")
        elif isinstance(node, list):
            for index, child in enumerate(cast(list[Any], node)):
                visit(child, f"{path}[{index}]")

    visit(_schema("telemetry-batch"), "")
    assert not unconstrained, unconstrained


def test_error_registry_matches_domain_docs() -> None:
    registry = json.loads((CONTRACTS / "error-codes.json").read_text())
    codes = {entry["code"] for entry in registry["codes"]}
    prefixes = set(registry["prefixes"])
    for entry in registry["codes"]:
        assert set(entry) == {"code", "recoverable", "surface", "user_text"}, entry
        assert entry["surface"] in {"internal", "student", "owner"}
        assert entry["code"].split("_", 1)[0] in prefixes, entry["code"]
        assert (entry["surface"] == "student") == (entry["user_text"] is not None), entry
    docs = sorted(DOMAINS.glob("*.md"))
    assert docs, "no domain docs found — scan would be vacuous"
    in_docs: set[str] = set()
    for doc in docs:
        in_docs |= set(re.findall(r"`([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)`", doc.read_text()))
    in_docs = {c for c in in_docs if c.split("_", 1)[0] in prefixes}
    missing, stray = sorted(in_docs - codes), sorted(codes - in_docs)
    assert in_docs == codes, f"in docs not registry: {missing}; in registry not docs: {stray}"


def test_no_verbatim_key_in_examples_or_data() -> None:
    """content-policy.md: the key `verbatim` is banned in any bundle or fixture."""
    files = sorted(EXAMPLES.glob("*.json")) + sorted(DATA.rglob("*.json"))
    assert files, "no files scanned"
    for path in files:
        for obj in _walk_objects(json.loads(path.read_text())):
            assert "verbatim" not in obj, path


def test_numeric_probe_item_requires_check() -> None:
    """v1.1.0: schema requires `check` on every `numeric` ProbeItem (owner Q5 ruling)."""
    example = json.loads((EXAMPLES / "nodes.json").read_text())
    target: dict[str, Any] | None = None
    for node in example["nodes"]:
        for item in node.get("probe_items", []):
            if item.get("type") == "numeric":
                target = item
                break
        if target is not None:
            break
    assert target is not None, "no numeric probe item found in contracts/examples/nodes.json"
    del target["check"]
    errors = _errors("nodes", example)
    assert errors, "deleting check from a numeric item did not fail validation"
    assert any("check" in message for message in errors), errors


def test_mc_probe_item_rejects_check() -> None:
    """v1.1.0: schema forbids `check` on every `mc` ProbeItem."""
    example = json.loads((EXAMPLES / "nodes.json").read_text())
    target: dict[str, Any] | None = None
    for node in example["nodes"]:
        for item in node.get("probe_items", []):
            if item.get("id") == "exp-2":
                target = item
                break
        if target is not None:
            break
    assert target is not None, "exp-2 not found in contracts/examples/nodes.json"
    assert target["type"] == "mc"
    target["check"] = {"kind": "evaluate", "expr": "x + 1"}
    errors = _errors("nodes", example)
    assert errors, "adding check to an mc item did not fail validation"


def test_check_expr_rejects_a_bare_numeric_literal() -> None:
    """v1.1.0: `check.expr` may not be a bare numeric literal (anti-vacuity guard)."""
    example = json.loads((EXAMPLES / "nodes.json").read_text())
    target: dict[str, Any] | None = None
    for node in example["nodes"]:
        for item in node.get("probe_items", []):
            check = item.get("check")
            if check is not None and check.get("kind") == "evaluate":
                target = check
                break
        if target is not None:
            break
    assert target is not None, "no evaluate-kind check found in contracts/examples/nodes.json"
    target["expr"] = "6"
    errors = _errors("nodes", example)
    assert errors, "a bare numeric literal expr did not fail validation"


def test_landmark_requires_source_title() -> None:
    """v1.1.0: schema requires `source_title` on every landmark (owner Q5 ruling)."""
    example = json.loads((EXAMPLES / "landmarks.json").read_text())
    del example["landmarks"][0]["source_title"]
    errors = _errors("landmarks", example)
    assert errors, "deleting source_title did not fail validation"
    assert any("source_title" in message for message in errors), errors


def test_node_state_remediated_must_be_boolean() -> None:
    """v1.3.0: schema types StudentState.nodes[].remediated as boolean (arbiter Q-A)."""
    example = json.loads((EXAMPLES / "student-state.json").read_text())
    example["nodes"]["matrix-multiplication"]["remediated"] = "true"
    errors = _errors("student-state", example)
    assert errors, "a string remediated value did not fail validation"


def test_marker_past_last_unit_must_be_boolean() -> None:
    """v1.3.0: schema types StudentState.marker.past_last_unit as boolean (arbiter Q-F)."""
    example = json.loads((EXAMPLES / "student-state.json").read_text())
    example["marker"]["past_last_unit"] = 1
    errors = _errors("student-state", example)
    assert errors, "an integer past_last_unit value did not fail validation"


def test_schema_version_1_document_without_new_fields_still_validates() -> None:
    """v1.3.0 migration identity (arbiter Q-A): "a version-1 document is a valid version-2 document
    with every `remediated` absent" (contracts/data-model.md § StudentState). A v1-shaped document —
    `schema_version: 1`, no `remediated` on any node, no `past_last_unit` on `marker` — must still
    validate against the amended (v1.3.0) schema, because both new properties are optional and
    `schema_version`'s own fragment is `{"type": "integer", "minimum": 1}` with no upper bound."""
    example = json.loads((EXAMPLES / "student-state.json").read_text())
    example["schema_version"] = 1
    del example["nodes"]["matrix-multiplication"]["remediated"]
    assert "past_last_unit" not in example["marker"], "fixture precondition: marker already carries it"
    errors = _errors("student-state", example)
    assert not errors, f"a v1-shaped document failed against the v1.3.0 schema: {errors}"


def test_remediated_required_guard_is_real() -> None:
    """C2 negative control for T5 guard 2: reconstructs the defect an implementer could introduce
    (adding `remediated` to the node-entry `required` array, contrary to arbiter Q-A: "It is not in
    `required`") and proves the pre-existing `exponent-laws` entry — which carries no `remediated` key —
    would fail validation under that defect, then confirms the real (un-mutated) schema accepts it."""
    schema = _schema("student-state")
    node_schema = schema["properties"]["nodes"]["additionalProperties"]
    assert "remediated" not in node_schema["required"], "fixture precondition: already required"

    broken_schema = json.loads(json.dumps(schema))
    broken_schema["properties"]["nodes"]["additionalProperties"]["required"].append("remediated")
    Draft202012Validator.check_schema(broken_schema)
    broken_validator = Draft202012Validator(broken_schema)

    example = json.loads((EXAMPLES / "student-state.json").read_text())
    assert "remediated" not in example["nodes"]["exponent-laws"], "fixture precondition failed"

    broken_errors = sorted(
        e.message
        for e in broken_validator.iter_errors(example)  # pyright: ignore[reportUnknownMemberType]
    )
    assert broken_errors, "guard failed to fail: a required remediated did not reject exponent-laws"

    real_errors = _errors("student-state", example)
    assert not real_errors, f"the real schema wrongly rejects exponent-laws: {real_errors}"


def test_past_last_unit_required_guard_is_real() -> None:
    """C2 negative control for T5 guard 2: same reconstruction for `marker.past_last_unit` (arbiter
    Q-F: "It is not required") — the pre-existing `marker` object carries no `past_last_unit` key."""
    schema = _schema("student-state")
    marker_schema = schema["properties"]["marker"]
    assert "past_last_unit" not in marker_schema["required"], "fixture precondition: already required"

    broken_schema = json.loads(json.dumps(schema))
    broken_schema["properties"]["marker"]["required"].append("past_last_unit")
    Draft202012Validator.check_schema(broken_schema)
    broken_validator = Draft202012Validator(broken_schema)

    example = json.loads((EXAMPLES / "student-state.json").read_text())
    assert "past_last_unit" not in example["marker"], "fixture precondition failed"

    broken_errors = sorted(
        e.message
        for e in broken_validator.iter_errors(example)  # pyright: ignore[reportUnknownMemberType]
    )
    assert broken_errors, "guard failed to fail: a required past_last_unit did not reject marker"

    real_errors = _errors("student-state", example)
    assert not real_errors, f"the real schema wrongly rejects marker: {real_errors}"


def test_remediated_type_guard_is_real() -> None:
    """C2 negative control for T5 guard 1: reconstructs the defect of an open (untyped) `remediated`
    property (`{}` instead of `{"type": "boolean"}`) and proves that, under that defect,
    `test_node_state_remediated_must_be_boolean`'s mutated instance (a string `remediated`) would
    wrongly validate — showing the type constraint in the real schema is load-bearing, not vacuous."""
    schema = _schema("student-state")
    node_props = schema["properties"]["nodes"]["additionalProperties"]["properties"]
    assert node_props["remediated"] == {"type": "boolean"}, "fixture precondition failed"

    broken_schema = json.loads(json.dumps(schema))
    broken_schema["properties"]["nodes"]["additionalProperties"]["properties"]["remediated"] = {}
    Draft202012Validator.check_schema(broken_schema)
    broken_validator = Draft202012Validator(broken_schema)

    example = json.loads((EXAMPLES / "student-state.json").read_text())
    example["nodes"]["matrix-multiplication"]["remediated"] = "true"

    assert broken_validator.is_valid(example), (  # pyright: ignore[reportUnknownMemberType]
        "guard reconstruction is wrong: the open schema still rejects a string remediated"
    )
    real_errors = _errors("student-state", example)
    assert real_errors, "the real schema failed to reject the same string remediated value"


def test_past_last_unit_type_guard_is_real() -> None:
    """C2 negative control for T5 guard 1: same reconstruction for `marker.past_last_unit` — an open
    (untyped) property would let `test_marker_past_last_unit_must_be_boolean`'s mutated instance (an
    integer `past_last_unit`) wrongly validate."""
    schema = _schema("student-state")
    marker_props = schema["properties"]["marker"]["properties"]
    assert marker_props["past_last_unit"] == {"type": "boolean"}, "fixture precondition failed"

    broken_schema = json.loads(json.dumps(schema))
    broken_schema["properties"]["marker"]["properties"]["past_last_unit"] = {}
    Draft202012Validator.check_schema(broken_schema)
    broken_validator = Draft202012Validator(broken_schema)

    example = json.loads((EXAMPLES / "student-state.json").read_text())
    example["marker"]["past_last_unit"] = 1

    assert broken_validator.is_valid(example), (  # pyright: ignore[reportUnknownMemberType]
        "guard reconstruction is wrong: the open schema still rejects an integer past_last_unit"
    )
    real_errors = _errors("student-state", example)
    assert real_errors, "the real schema failed to reject the same integer past_last_unit value"
