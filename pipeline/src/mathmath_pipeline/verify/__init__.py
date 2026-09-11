"""Pipeline content verification (I1, I15): SymPy answer re-derivation, distractor tags, landmark sourcing.

Re-exports the public functions of `answers.py`, `distractors.py` and `landmarks.py`; no logic of its own.
"""

from __future__ import annotations

from mathmath_pipeline.verify.answers import (
    LO_PROBE_UNCHECKABLE,
    AnswerMismatch,
    UncheckableCheck,
    UncheckableItem,
    derive_from_check,
    verify_numeric_answers,
)
from mathmath_pipeline.verify.distractors import (
    BANNED_TAG,
    LO_BAD_DISTRACTOR_TAG,
    BadDistractorTag,
    find_bad_distractor_tags,
)
from mathmath_pipeline.verify.landmarks import (
    LO_LANDMARK_UNSOURCED,
    SPINE_SOURCE_REF_UNRESOLVED,
    ResolutionFailure,
    SourceRefEntry,
    TransportInconclusive,
    fetch_page_text,
    page_contains,
    resolve_source_ref,
    scan_source_refs,
)

__all__ = [
    "BANNED_TAG",
    "LO_BAD_DISTRACTOR_TAG",
    "LO_LANDMARK_UNSOURCED",
    "LO_PROBE_UNCHECKABLE",
    "SPINE_SOURCE_REF_UNRESOLVED",
    "AnswerMismatch",
    "BadDistractorTag",
    "ResolutionFailure",
    "SourceRefEntry",
    "TransportInconclusive",
    "UncheckableCheck",
    "UncheckableItem",
    "derive_from_check",
    "find_bad_distractor_tags",
    "fetch_page_text",
    "page_contains",
    "resolve_source_ref",
    "scan_source_refs",
    "verify_numeric_answers",
]
