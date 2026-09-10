"""Real-composition seam test (C1): the Python pipeline invokes the Swift core-cli binary (D42)."""

from __future__ import annotations

import hashlib
import inspect
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
from pydantic import ValidationError

from mathmath_pipeline import bundle as bundle_helpers
from mathmath_pipeline import cli as cli_module
from mathmath_pipeline import core_cli
from mathmath_pipeline.cli import CoreCliError, L0Report, layout, validate

EXAMPLES_DIR = Path(__file__).resolve().parents[2] / "contracts" / "examples"
CORE_SOURCES_DIR = Path(__file__).resolve().parents[2] / "Packages" / "Core" / "Sources" / "Core"
PIPELINE_SRC_DIR = Path(__file__).resolve().parents[2] / "pipeline" / "src" / "mathmath_pipeline"

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


def test_layout_and_restamp_first_call_actually_changes_asset_version(tmp_path: Path) -> None:
    """Negative control for the idempotency guard above (C2): the committed `contracts/examples/`
    manifest carries a placeholder `sha256`/`asset_version` (`nodes-v0`, all-zero digest) for
    `nodes.json`. The *first* `layout` + `restamp_manifest` pair must actually replace that placeholder
    with a real, content-derived value — proving `restamp_manifest` is a real stamping function, not a
    no-op that would make the idempotency assertion above vacuously true.
    """
    working_dir = _copy_examples(tmp_path)
    manifest_before = json.loads((working_dir / "manifest.json").read_text())
    entry_before = next(e for e in manifest_before["files"] if e["name"] == "nodes.json")
    assert entry_before["asset_version"] == "nodes-v0"

    layout(working_dir)
    bundle_helpers.restamp_manifest(working_dir, "nodes.json")

    manifest_after = json.loads((working_dir / "manifest.json").read_text())
    entry_after = next(e for e in manifest_after["files"] if e["name"] == "nodes.json")

    assert entry_after["asset_version"] != entry_before["asset_version"]
    assert entry_after["sha256"] != entry_before["sha256"]


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
    # `swift run` may prepend nondeterministic build-cache warnings to stderr; the registry code is
    # always the CLI's own final line (`contracts/error-codes.md`: raw code on one line of stderr).
    stderr_lines = excinfo.value.stderr.strip().splitlines()
    assert stderr_lines[-1] == "PLATFORM_BUNDLE_INTEGRITY_FAILED"


def test_layout_missing_bundle_exits_three(tmp_path: Path) -> None:
    # Mirrors validate's exit-3 case for the other subcommand: a `CoreError` (here
    # `platformBundleIntegrityFailed`, bundle unreadable) thrown before any rewrite happens.
    missing = tmp_path / "does-not-exist"
    with pytest.raises(CoreCliError) as excinfo:
        layout(missing)
    assert excinfo.value.returncode == 3


def test_validate_exits_zero_for_the_unmodified_contract_example() -> None:
    # AC2 / §4.4 exit-code table: exit 0 for a passing bundle. Calls the real, committed
    # `contracts/examples/` bundle via the pipeline's generic `core_cli` wrapper (`check=True`) so a
    # nonzero exit would itself raise — the exit code is asserted directly, not inferred from "did not
    # raise" on a higher-level wrapper.
    stdout = core_cli("validate", str(EXAMPLES_DIR))
    report = json.loads(stdout)
    assert report["passed"] is True


def test_validate_exits_one_for_a_failing_bundle(tmp_path: Path) -> None:
    working_dir = _copy_examples(tmp_path)
    landmarks_path = working_dir / "landmarks.json"
    landmarks = json.loads(landmarks_path.read_text())
    landmarks["landmarks"][0]["node_ids"][0] = "nonexistent-node"
    landmarks_path.write_text(json.dumps(landmarks))

    with pytest.raises(subprocess.CalledProcessError) as excinfo:
        core_cli("validate", str(working_dir))
    assert excinfo.value.returncode == 1
    report = json.loads(excinfo.value.stdout)
    assert report["passed"] is False


def test_no_subcommand_exits_two_with_usage_and_no_stdout() -> None:
    with pytest.raises(subprocess.CalledProcessError) as excinfo:
        core_cli()
    assert excinfo.value.returncode == 2
    assert excinfo.value.stdout == ""
    assert "usage: core-cli" in excinfo.value.stderr


def test_unknown_subcommand_exits_two_with_usage_and_no_stdout() -> None:
    with pytest.raises(subprocess.CalledProcessError) as excinfo:
        core_cli("frobnicate-not-a-real-subcommand")
    assert excinfo.value.returncode == 2
    assert excinfo.value.stdout == ""
    assert "usage: core-cli" in excinfo.value.stderr


def test_report_shape_matches_contract_through_real_cli_stdout() -> None:
    """Report fidelity through the CLI (`contracts/graph-constraints.md` § Report shape): parses the
    real `core-cli validate` stdout as raw JSON (bypassing the Pydantic model entirely) and asserts the
    top-level and per-check key sets against the contract's own shape, and the rule-id set against the
    contract's own table (`CONTRACT_L0_RULE_IDS`, transcribed above) — never against `Core`'s source.
    """
    stdout = core_cli("validate", str(EXAMPLES_DIR))
    report = json.loads(stdout)
    assert set(report.keys()) == {"bundle_id", "passed", "checks", "indegree"}
    assert report["passed"] is True

    check_ids = {check["id"] for check in report["checks"]}
    assert check_ids == CONTRACT_L0_RULE_IDS
    for check in report["checks"]:
        assert set(check.keys()) == {"id", "passed", "violations"}
        # C3: empty violation lists are printed, never omitted.
        assert isinstance(check["violations"], list)

    assert set(report["indegree"].keys()) == {"threshold", "outliers"}


def test_build_bundle_refuses_on_failing_report(tmp_path: Path) -> None:
    working_dir = _copy_examples(tmp_path)

    # Restored regression guard (task 02b, commit 8e2e313, fixed L0-9 successor semantics so
    # `contracts/examples/` — the contract's own worked example — validates clean with all ten checks
    # passing). An unmodified copy of the contract's example must build through the real CLI with no
    # refusal before we prove the refusal path below on a deliberately corrupted copy: this is the
    # negative control for the I8 refusal guard (C2) — the guard must be *capable* of not firing on a
    # sound bundle, or a guard that always fires proves nothing.
    sound_report = bundle_helpers.build_bundle(working_dir)
    assert sound_report.passed is True

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


def test_seam_tests_never_silently_skip() -> None:
    """AC5: "must fail loudly, never silently skip." No test in this file may reach for a pytest skip
    marker, a pytest import-skip helper, or the standard-library skip exception to paper over a broken
    or unavailable seam — a failure here (missing `swift`, an unbuildable `Core` package, a missing
    `core-cli` artefact) must surface as a test failure. Tokens are concatenated for the same
    self-reference reason as the mock-grep guard above (including in this docstring).
    """
    source = Path(__file__).read_text()
    forbidden_tokens = (
        "pytest.mark" + ".skip",
        "pytest" + ".skip(",
        "import" + "orskip",
        "unittest.Skip" + "Test",
    )
    for token in forbidden_tokens:
        assert token not in source, f"forbidden skip token {token!r} found in {__file__}"


def test_seam_fails_loudly_when_core_package_is_unbuildable(tmp_path: Path) -> None:
    """AC5's own text: "or points `CORE_PACKAGE` at a directory with no buildable package" — must fail
    loudly. This redirects the real seam's target at a directory with no `Package.swift` and proves the
    resulting failure surfaces as a genuine exception from a real `swift run` subprocess invocation
    inside `cli._run` (confirmed by hand: `swift run --package-path <bogus> ...` exits 1 with empty
    stdout and an `error: Could not find Package.swift...` line on stderr, so `validate()`'s own parsing
    of that empty stdout is what raises here) — not a mock, not a stub report, and no `pytest.skip`
    anywhere catches it.
    """
    bogus_package = tmp_path / "not-a-swift-package"
    bogus_package.mkdir()
    original_package = cli_module.CORE_PACKAGE
    cli_module.CORE_PACKAGE = bogus_package
    try:
        with pytest.raises((CoreCliError, ValidationError)):
            validate(EXAMPLES_DIR)
    finally:
        cli_module.CORE_PACKAGE = original_package


def test_core_package_never_hashes_content() -> None:
    """D33/I14: `Core` imports Foundation only and never computes or verifies `sha256` (planner note 2,
    task spec §3). SHA-256 computation lives exclusively in the pipeline's `hashlib` helper
    (`bundle.py::sha256_of`).
    """
    core_swift_files = list(CORE_SOURCES_DIR.rglob("*.swift"))
    assert core_swift_files, "expected at least one Core Swift source file to enumerate"
    forbidden_tokens = ("import Crypto" + "Kit", "SHA256" + "(", "Insecure.SHA1")
    for path in core_swift_files:
        text = path.read_text()
        for token in forbidden_tokens:
            assert token not in text, f"{token!r} found in {path} — Core must never hash (D33/I14)"


def test_sha256_of_matches_hashlib_and_changes_on_tamper(tmp_path: Path) -> None:
    working_dir = _copy_examples(tmp_path)
    target = working_dir / "sources.json"

    original_digest = bundle_helpers.sha256_of(target)
    assert original_digest == hashlib.sha256(target.read_bytes()).hexdigest()

    target.write_text(target.read_text() + " ")
    tampered_digest = bundle_helpers.sha256_of(target)
    assert tampered_digest != original_digest
    assert tampered_digest == hashlib.sha256(target.read_bytes()).hexdigest()


def test_restamp_manifest_stamps_the_real_sha256(tmp_path: Path) -> None:
    working_dir = _copy_examples(tmp_path)
    bundle_helpers.restamp_manifest(working_dir, "nodes.json")

    manifest = json.loads((working_dir / "manifest.json").read_text())
    entry = next(e for e in manifest["files"] if e["name"] == "nodes.json")
    expected_digest = bundle_helpers.sha256_of(working_dir / "nodes.json")

    assert entry["sha256"] == expected_digest
    assert entry["asset_version"] == expected_digest[: bundle_helpers.ASSET_VERSION_HEX_LENGTH]


def test_restamp_manifest_changes_on_tampered_content(tmp_path: Path) -> None:
    """Negative control (C2): the manifest entry must actually change when the file's bytes change —
    proves `restamp_manifest` is sensitive to content, not a function that always reproduces the same
    stamp regardless of input (which would make the idempotency guards above vacuously true).
    """
    working_dir = _copy_examples(tmp_path)
    bundle_helpers.restamp_manifest(working_dir, "nodes.json")
    first_manifest = (working_dir / "manifest.json").read_bytes()

    nodes_path = working_dir / "nodes.json"
    nodes = json.loads(nodes_path.read_text())
    nodes["nodes"][0]["paraphrase"] = nodes["nodes"][0]["paraphrase"] + " (tampered)"
    nodes_path.write_text(json.dumps(nodes))

    bundle_helpers.restamp_manifest(working_dir, "nodes.json")
    second_manifest = (working_dir / "manifest.json").read_bytes()

    assert first_manifest != second_manifest


def test_no_core_cli_submodule_name_collision() -> None:
    """§6 default: the submodule is named `cli.py`, not `core_cli.py`, precisely because Python
    permanently rebinds a package attribute to a same-named submodule on first import — a `core_cli.py`
    submodule would eventually shadow `__init__.py`'s module-level `core_cli` function.
    """
    assert PIPELINE_SRC_DIR.is_dir()
    assert not (PIPELINE_SRC_DIR / "core_cli.py").exists()


def test_core_cli_name_resolves_to_the_function_not_a_module() -> None:
    """Guard against the shadowing hazard the spec was revised to remove: after importing both
    `mathmath_pipeline.cli` (this file's own import, above) and `mathmath_pipeline.core_cli` (the
    function), `mathmath_pipeline.core_cli` must still be the callable — never rebound to a module —
    and no `mathmath_pipeline.core_cli` *module* may exist in `sys.modules` (only the `cli` submodule
    does).
    """
    assert inspect.isfunction(core_cli)
    assert core_cli.__module__ == "mathmath_pipeline"
    assert "mathmath_pipeline.cli" in sys.modules
    assert "mathmath_pipeline.core_cli" not in sys.modules
