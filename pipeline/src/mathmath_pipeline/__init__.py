"""mathmath offline content pipeline (D41).

Owner-run, never on the device. Sub-packages are added by the EPICs that ship them: spine extraction,
generation runs (Claude API), L1/L2 intersection, SymPy answer verification, landmark sourcing, and the
build step that invokes ``core-cli`` for L0 validation and layout (D42).
"""

from __future__ import annotations

import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
CORE_PACKAGE = REPO_ROOT / "Packages" / "Core"


def core_cli(*args: str) -> str:
    """Invoke the ``core-cli`` executable from the Core Swift package and return its stdout (D42)."""
    completed = subprocess.run(
        ["swift", "run", "--package-path", str(CORE_PACKAGE), "-c", "release", "core-cli", *args],
        check=True,
        capture_output=True,
        text=True,
    )
    return completed.stdout.strip()


def main() -> None:
    print(f"mathmath-pipeline; core data format {core_cli('version')}")  # noqa: T201
