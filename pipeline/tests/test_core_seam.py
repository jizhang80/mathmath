"""Real-composition seam test (C1): the Python pipeline invokes the Swift core-cli binary (D42)."""

from __future__ import annotations

import re

from mathmath_pipeline import core_cli


def test_core_cli_version_is_semver() -> None:
    version = core_cli("version")
    assert re.fullmatch(r"\d+\.\d+\.\d+", version), version
