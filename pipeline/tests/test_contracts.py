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
