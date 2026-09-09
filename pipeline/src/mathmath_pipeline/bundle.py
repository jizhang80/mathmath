"""Bundle-directory build-time helpers (D42): SHA-256 stamping and the I8 build-refusal gate.

`Core` never computes or verifies SHA-256 (Foundation only, D33/I14; `core-cli validate` enforces manifest
*completeness and file presence* only — planner note 2). SHA-256 *computation* is this module's `hashlib`
helper.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from mathmath_pipeline.cli import L0Report, validate

ASSET_VERSION_HEX_LENGTH = 12


def sha256_of(path: Path) -> str:
    """The SHA-256 hex digest of a file's bytes."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def restamp_manifest(bundle_dir: Path, file_name: str) -> None:
    """Recompute `file_name`'s SHA-256 and rewrite its `manifest.json` entry (`sha256`, `asset_version`).

    `asset_version` is the first `ASSET_VERSION_HEX_LENGTH` hex characters of the new digest: content-
    derived, so byte-identical input yields a byte-identical `asset_version` with no comparison against
    the manifest's previous value required (`contracts/data-model.md` § Versioning: "Bundle files are
    **immutable**: a change is a new `asset_version`").
    """
    manifest_path = bundle_dir / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    digest = sha256_of(bundle_dir / file_name)
    asset_version = digest[:ASSET_VERSION_HEX_LENGTH]
    for entry in manifest["files"]:
        if entry["name"] == file_name:
            entry["sha256"] = digest
            entry["asset_version"] = asset_version
            break
    else:
        raise ValueError(f"{file_name!r} not listed in {manifest_path}'s files[]")
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")


class BundleRejected(RuntimeError):
    """I8: raised by `build_bundle` when the L0 report says `passed: false`. No write happens."""

    def __init__(self, report: L0Report) -> None:
        self.report = report
        failing = [check.id for check in report.checks if not check.passed]
        super().__init__(f"bundle {report.bundle_id!r} failed L0 checks: {failing}")


def build_bundle(bundle_dir: Path) -> L0Report:
    """The I8 build gate: validate `bundle_dir`; raise `BundleRejected` and write nothing if the report's
    `passed` is `False`. Returns the report on success. The only side effect on any path is the
    `core-cli validate` subprocess call inside `validate()` — this function itself never writes."""
    report = validate(bundle_dir)
    if not report.passed:
        raise BundleRejected(report)
    return report
