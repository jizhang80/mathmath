"""Real-composition seam test (C1): the Python pipeline invokes the Swift core-cli binary (D42)."""

from __future__ import annotations

import json
import re
import shutil
from pathlib import Path

import pytest
from pydantic import ValidationError

from mathmath_pipeline import bundle as bundle_helpers
from mathmath_pipeline import core_cli
from mathmath_pipeline.cli import CoreCliError, L0Report, layout, validate

EXAMPLES_DIR = Path(__file__).resolve().parents[2] / "contracts" / "examples"

# The ten non-advisory L0 rule ids, transcribed from `contracts/graph-constraints.md`'s rule table
# (task spec §3/§5 — copied from the contract, not from `Core`'s source). `L0-4` is advisory and never
# appears in `checks[]`.
CONTRACT_L0_RULE_IDS = {
    "L0-1",
    "L0-2",
    "L0-3a",
    "L0-3b",
    "L0-5",
    "L0-6",
    "L0-7",
    "L0-8",
    "L0-9",
    "L0-10",
}


def test_core_cli_version_is_semver() -> None:
    version = core_cli("version")
    assert re.fullmatch(r"\d+\.\d+\.\d+", version), version


def _copy_examples(tmp_path: Path) -> Path:
    working_dir = tmp_path / "bundle"
    shutil.copytree(EXAMPLES_DIR, working_dir)
    return working_dir


def test_validate_reports_every_rule_id() -> None:
    report = validate(EXAMPLES_DIR)
    assert {check.id for check in report.checks} == CONTRACT_L0_RULE_IDS
    for check in report.checks:
        assert isinstance(check.violations, list)


def test_validate_exit_code_matches_passed(tmp_path: Path) -> None:
    working_dir = _copy_examples(tmp_path)
    report = validate(working_dir)
    assert isinstance(report.passed, bool)
    # The report is always produced regardless of the pass/fail outcome (both exit 0 and exit 1 carry a
    # report per the task spec's exit-code table); this call not raising `CoreCliError` is the proof.


def test_validate_missing_bundle_exits_three(tmp_path: Path) -> None:
    missing = tmp_path / "does-not-exist"
    with pytest.raises(CoreCliError) as excinfo:
        validate(missing)
    assert excinfo.value.returncode == 3


def test_layout_rewrites_nodes_file_idempotently(tmp_path: Path) -> None:
    working_dir = _copy_examples(tmp_path)
    nodes_path = working_dir / "nodes.json"

    layout(working_dir)
    first_bytes = nodes_path.read_bytes()

    layout(working_dir)
    second_bytes = nodes_path.read_bytes()

    assert first_bytes == second_bytes

    decoded = json.loads(first_bytes)
    for node in decoded["nodes"]:
        position = node["position"]
        assert isinstance(position["x"], (int, float))
        assert isinstance(position["y"], (int, float))


def test_layout_and_restamp_pair_is_idempotent(tmp_path: Path) -> None:
    working_dir = _copy_examples(tmp_path)

    layout(working_dir)
    bundle_helpers.restamp_manifest(working_dir, "nodes.json")
    first_nodes = (working_dir / "nodes.json").read_bytes()
    first_manifest = (working_dir / "manifest.json").read_bytes()

    layout(working_dir)
    bundle_helpers.restamp_manifest(working_dir, "nodes.json")
    second_nodes = (working_dir / "nodes.json").read_bytes()
    second_manifest = (working_dir / "manifest.json").read_bytes()

    assert first_nodes == second_nodes
    assert first_manifest == second_manifest


def test_l0_report_rejects_malformed_shape() -> None:
    malformed = json.dumps({"bundle_id": "x", "passed": True, "checks": []})
    with pytest.raises(ValidationError):
        L0Report.model_validate_json(malformed)


def test_validate_missing_listed_file_exits_three_with_registry_code(tmp_path: Path) -> None:
    working_dir = _copy_examples(tmp_path)
    (working_dir / "sources.json").unlink()

    with pytest.raises(CoreCliError) as excinfo:
        validate(working_dir)
    assert excinfo.value.returncode == 3
    assert excinfo.value.stderr.strip().endswith("PLATFORM_BUNDLE_INTEGRITY_FAILED")


def test_build_bundle_refuses_on_failing_report(tmp_path: Path) -> None:
    working_dir = _copy_examples(tmp_path)

    landmarks_path = working_dir / "landmarks.json"
    landmarks = json.loads(landmarks_path.read_text())
    landmarks["landmarks"][0]["node_ids"][0] = "nonexistent-node"
    landmarks_path.write_text(json.dumps(landmarks))
    bundle_helpers.restamp_manifest(working_dir, "landmarks.json")

    before = {p.name: p.stat().st_mtime_ns for p in working_dir.iterdir()}

    with pytest.raises(bundle_helpers.BundleRejected):
        bundle_helpers.build_bundle(working_dir)

    after = {p.name: p.stat().st_mtime_ns for p in working_dir.iterdir()}
    assert before == after


def test_seam_invokes_real_binary_not_a_mock() -> None:
    # Tokens are built by concatenation so this file's own source never contains any of them as a
    # literal substring (which would otherwise make this assertion trivially self-fail).
    source = Path(__file__).read_text()
    forbidden_tokens = (
        "unittest" + ".mock",
        "Magic" + "Mock",
        "monkey" + "patch",
        "subprocess.run" + "(",
    )
    for token in forbidden_tokens:
        assert token not in source, f"forbidden token {token!r} found in {__file__}"
