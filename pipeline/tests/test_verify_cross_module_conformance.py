"""T4 conformance: the pipeline-owned LO checks never leak into `Core`'s L0 report.

`docs/plans/epic-01-task-plan.md` planner note [4]: "`Core`'s `validate` stays exactly L0-1 … L0-10 — no
LO-prefixed checks are bolted into the L0 report. … distractor tags, SymPy re-derivation and landmark
resolution go to 01.7 (pipeline)." `docs/domains/learning-objects.md` W1 step 5/5c names the three codes
this task's checks map to.
"""

from __future__ import annotations

import json

from mathmath_pipeline import REPO_ROOT
from mathmath_pipeline.verify import (
    LO_BAD_DISTRACTOR_TAG,
    LO_LANDMARK_UNSOURCED,
    LO_PROBE_UNCHECKABLE,
)

CORE_SOURCES = REPO_ROOT / "Packages" / "Core" / "Sources"


def test_lo_prefixed_verification_codes_appear_nowhere_under_packages_core() -> None:
    """Distractor tags, SymPy re-derivation and landmark resolution are pipeline-owned (§2 out-of-scope);
    `Core`'s L0 report never grows an LO-prefixed check."""
    assert CORE_SOURCES.exists()
    swift_files = list(CORE_SOURCES.rglob("*.swift"))
    assert swift_files, "anti-vacuity: expected Core Swift sources to exist"
    banned = [LO_PROBE_UNCHECKABLE, LO_BAD_DISTRACTOR_TAG, LO_LANDMARK_UNSOURCED]
    for path in swift_files:
        text = path.read_text()
        for code in banned:
            assert code not in text, (
                f"{path} references {code!r} — LO-prefixed checks belong to pipeline/verify, never Core "
                "(planner note [4])"
            )


def test_each_ac_named_code_maps_to_the_domain_doc_workflow_step() -> None:
    """`docs/domains/learning-objects.md` W1 step 5/5c names exactly these three codes for this task's
    checks; confirm they are registered and distinct from one another and from the L0-10 presence code this
    task does NOT implement."""
    registry = json.loads((REPO_ROOT / "contracts" / "error-codes.json").read_text())
    codes = {entry["code"] for entry in registry["codes"]}
    task_codes = {LO_PROBE_UNCHECKABLE, LO_BAD_DISTRACTOR_TAG, LO_LANDMARK_UNSOURCED}
    assert task_codes <= codes
    assert len(task_codes) == 3, "the three codes must be pairwise distinct"
    assert "MAP_LANDMARK_UNSOURCED" not in task_codes, (
        "MAP_LANDMARK_UNSOURCED is Core's L0-10 presence code, never this task's resolution code"
    )
