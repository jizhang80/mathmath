"""Real, per-subcommand wrappers around the core-cli binary (D42): validate, layout.

Every function here invokes a real `core-cli` subprocess against a real bundle directory — no
reimplementation of L0 or layout (`contracts/graph-constraints.md` Preamble: "Python never reimplements
these (D42)"), no subprocess mock (C1, task plan note 9).
"""

from __future__ import annotations

import subprocess
from pathlib import Path

from pydantic import BaseModel, ConfigDict

from mathmath_pipeline import CORE_PACKAGE


class L0Check(BaseModel):
    model_config = ConfigDict(extra="forbid")
    id: str
    passed: bool
    violations: list[str]


class L0Indegree(BaseModel):
    model_config = ConfigDict(extra="forbid")
    threshold: int
    outliers: list[str]


class L0Report(BaseModel):
    """Boundary-validated shape of `core-cli validate` stdout (`contracts/graph-constraints.md` § Report
    shape). Pydantic is the boundary-validation tool `docs/tech-stack.md` names for the pipeline."""

    model_config = ConfigDict(extra="forbid")
    bundle_id: str
    passed: bool
    checks: list[L0Check]
    indegree: L0Indegree


class CoreCliError(RuntimeError):
    """Raised for any core-cli exit that is not a report-bearing exit (exit 2 usage, exit 3 CoreError)."""

    def __init__(self, subcommand: str, returncode: int, stderr: str) -> None:
        self.subcommand = subcommand
        self.returncode = returncode
        self.stderr = stderr
        super().__init__(f"core-cli {subcommand} exited {returncode}: {stderr.strip()}")


def _run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["swift", "run", "--package-path", str(CORE_PACKAGE), "-c", "release", "core-cli", *args],
        capture_output=True,
        text=True,
        check=False,
    )


def validate(bundle_dir: Path) -> L0Report:
    """Run `core-cli validate <bundle_dir>` and parse its stdout into a boundary-validated `L0Report`.

    Exit 0 or 1 both carry a report (0 = passed, 1 = passed: false — task spec §4.4's table); any other
    exit code means no report was printed, so it raises `CoreCliError` instead of attempting to parse
    stdout.
    """
    completed = _run("validate", str(bundle_dir))
    if completed.returncode not in (0, 1):
        raise CoreCliError("validate", completed.returncode, completed.stderr)
    return L0Report.model_validate_json(completed.stdout)


def layout(bundle_dir: Path) -> None:
    """Run `core-cli layout <bundle_dir>`, which rewrites `nodes.json` in place. Raises `CoreCliError` on
    any non-zero exit — layout has no partial-success report (task spec §4.4's table)."""
    completed = _run("layout", str(bundle_dir))
    if completed.returncode != 0:
        raise CoreCliError("layout", completed.returncode, completed.stderr)
