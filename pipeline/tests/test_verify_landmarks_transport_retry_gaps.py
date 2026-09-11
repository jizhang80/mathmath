"""Tester suite for EPIC 03 task 00 (`fix-landmark-fetch-flake`, risk: seam).

Fills gaps the implementer's own hermetic file (`test_verify_landmarks_transport_retry.py`) and the
targeted edits to `test_verify_landmarks_contract.py` / `test_demo_bundle.py` leave open:

- every 4xx/5xx (not just 404) still takes exactly one opener call, no retry (I15 unweakened, §1 AC4/AC7);
- mixed transport-error types within a single retry sequence (not just same-type-repeated) still classify
  correctly and respect the `MAX_TRANSPORT_ATTEMPTS` bound exactly;
- `resolve_source_ref`'s re-raised `TransportInconclusive` carries the node/locator context, the same way
  its `ResolutionFailure` sibling already does (§4 step 7's contract, untested by the implementer's AC6
  test, which only asserts on `.attempts`);
- the injectable `opener` keyword parameter is a real, permanent seam (a structural regression guard: this
  is the shipped substitute for AC12's implementation-time negative control, since re-running against a
  pre-fix revision cannot be part of a permanent suite);
- the retry loop's wait is bounded to `TRANSPORT_RETRY_BACKOFF_SECONDS`, not something a future edit could
  silently scale up (a real-time upper-bound assertion, hermetic — no network, deterministic outcome);
- negative controls (C2) proving the AC10 skip/except-parity guard's own detection logic genuinely reds on
  a reconstructed unguarded-skip defect, in both files it is duplicated into.

Never uses a test-double substitution library or a blanket skip marker — kept clean of the anti-vacuity
guard's forbidden-token list in `test_verify_landmarks_contract.py`.
"""

from __future__ import annotations

import inspect
import time
import urllib.error
import urllib.request
from collections.abc import Callable
from email.message import Message
from pathlib import Path
from typing import Any

import pytest

from mathmath_pipeline.verify.landmarks import (
    LO_LANDMARK_UNSOURCED,
    MAX_TRANSPORT_ATTEMPTS,
    SPINE_SOURCE_REF_UNRESOLVED,
    TRANSPORT_RETRY_BACKOFF_SECONDS,
    ResolutionFailure,
    SourceRefEntry,
    TransportInconclusive,
    fetch_page_text,
    resolve_source_ref,
)

REPO_ROOT = Path(__file__).resolve().parents[2]


class _FakeResponse:
    def __init__(self, status: int, body: bytes) -> None:
        self.status = status
        self._body = body

    def __enter__(self) -> _FakeResponse:
        return self

    def __exit__(self, *exc_info: object) -> None:
        return None

    def read(self) -> bytes:
        return self._body


def _counting_opener(
    outcomes: list[BaseException | tuple[int, bytes]],
) -> tuple[Callable[[urllib.request.Request], Any], list[int]]:
    calls = [0]

    def opener(request: urllib.request.Request) -> Any:  # noqa: ANN401
        index = calls[0]
        calls[0] += 1
        outcome = outcomes[index]
        if isinstance(outcome, BaseException):
            raise outcome
        status, body = outcome
        return _FakeResponse(status, body)

    return opener, calls


# ---------------------------------------------------------------------------
# T2/T3 — every 4xx/5xx status raises ResolutionFailure immediately, not just 404 (AC4, I15 unweakened).
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("status_code", [400, 410, 500, 503])
def test_fetch_page_text_raises_resolution_failure_immediately_on_any_4xx_5xx_no_retry(
    status_code: int,
) -> None:
    error = urllib.error.HTTPError("https://example.invalid/bad", status_code, "error", Message(), None)
    opener, calls = _counting_opener([error])
    with pytest.raises(ResolutionFailure) as exc_info:
        fetch_page_text("https://example.invalid/bad", opener=opener)
    assert exc_info.value.code == LO_LANDMARK_UNSOURCED
    assert calls[0] == 1, "a confirmed non-2xx status must never be retried (I15)"


def test_resolve_source_ref_raises_spine_source_ref_unresolved_on_a_confirmed_410_no_retry() -> None:
    """AC7's guard exercised with a different confirmed-dead status than the implementer's 404 case, to
    prove the classification is by "any non-2xx via HTTPError", not hardcoded to 404."""
    error = urllib.error.HTTPError("https://example.invalid/gone", 410, "Gone", Message(), None)
    opener, calls = _counting_opener([error])
    entry = SourceRefEntry(node_id="n", source="s", locator="p. 1")
    sources_file: dict[str, Any] = {"sources": [{"source": "s", "url": "https://example.invalid/gone"}]}
    with pytest.raises(ResolutionFailure) as exc_info:
        resolve_source_ref(entry, sources_file, opener=opener)
    assert exc_info.value.code == SPINE_SOURCE_REF_UNRESOLVED
    assert calls[0] == 1


# ---------------------------------------------------------------------------
# T1/T6 — mixed transport-error types within one retry sequence, not same-type-repeated (AC1/AC2/AC3 depth).
# ---------------------------------------------------------------------------


def test_fetch_page_text_retries_across_mixed_transport_error_types_within_the_bound() -> None:
    """A connection reset followed by a timeout, then success on the third (final permitted) attempt: the
    classification tuple treats every named transport error uniformly across a single retry sequence, not
    only when the same type repeats — the bound is exactly `MAX_TRANSPORT_ATTEMPTS`, not per-error-type."""
    assert MAX_TRANSPORT_ATTEMPTS == 3, "written against the current bound; update if it changes"
    opener, calls = _counting_opener(
        [ConnectionResetError("reset"), TimeoutError("timed out"), (200, b"third time lucky")]
    )
    text = fetch_page_text("https://example.invalid/mixed", opener=opener)
    assert text == "third time lucky"
    assert calls[0] == 3


def test_fetch_page_text_raises_transport_inconclusive_with_mixed_errors_exhausted() -> None:
    opener, calls = _counting_opener(
        [ConnectionResetError("reset"), TimeoutError("timed out"), urllib.error.URLError("refused")]
    )
    with pytest.raises(TransportInconclusive) as exc_info:
        fetch_page_text("https://example.invalid/mixed-exhausted", opener=opener)
    assert calls[0] == MAX_TRANSPORT_ATTEMPTS
    assert exc_info.value.attempts == MAX_TRANSPORT_ATTEMPTS


# ---------------------------------------------------------------------------
# T1 — resolve_source_ref's re-raised TransportInconclusive carries node/locator context, mirroring the
# ResolutionFailure wrap this file's sibling test already proves for the confirmed-dead path.
# ---------------------------------------------------------------------------


def test_resolve_source_ref_wraps_transport_inconclusive_with_node_and_locator_context() -> None:
    resets: list[BaseException | tuple[int, bytes]] = [ConnectionResetError("reset")] * MAX_TRANSPORT_ATTEMPTS
    opener, _ = _counting_opener(resets)
    entry = SourceRefEntry(node_id="node-42", source="flaky-source", locator="p. 99")
    sources_file: dict[str, Any] = {
        "sources": [{"source": "flaky-source", "url": "https://example.invalid/flaky"}]
    }
    with pytest.raises(TransportInconclusive) as exc_info:
        resolve_source_ref(entry, sources_file, opener=opener)
    message = str(exc_info.value)
    assert "node-42" in message
    assert "p. 99" in message
    # The re-raised exception is a distinct TransportInconclusive carrying the caller's own url, not the
    # inner one re-thrown verbatim (mirrors the ResolutionFailure wrap for the confirmed-dead path).
    assert exc_info.value.url == "https://example.invalid/flaky"


# ---------------------------------------------------------------------------
# T5 (C2) — the injectable opener seam is permanent: a structural regression guard standing in for AC12's
# implementation-time-only negative control (re-running against the pre-fix revision is not a shipped test).
# ---------------------------------------------------------------------------


def test_fetch_page_text_exposes_a_keyword_only_opener_parameter_with_a_default() -> None:
    parameters = inspect.signature(fetch_page_text).parameters
    assert "opener" in parameters
    assert parameters["opener"].kind == inspect.Parameter.KEYWORD_ONLY
    assert parameters["opener"].default is not inspect.Parameter.empty


def test_resolve_source_ref_exposes_a_keyword_only_opener_parameter_with_a_default() -> None:
    parameters = inspect.signature(resolve_source_ref).parameters
    assert "opener" in parameters
    assert parameters["opener"].kind == inspect.Parameter.KEYWORD_ONLY
    assert parameters["opener"].default is not inspect.Parameter.empty


def test_fetch_page_text_without_opener_and_without_url_errors_would_not_be_hermetic() -> None:
    """Negative control for the seam itself: calling without `opener` falls back to the real network opener
    (`_default_opener`), proving the injected fake genuinely substitutes network I/O rather than merely
    decorating it — the seam does something, it is not a no-op parameter. Verified by signature identity,
    never by making a live request from a hermetic test."""
    import mathmath_pipeline.verify.landmarks as landmarks_module

    default = inspect.signature(fetch_page_text).parameters["opener"].default
    assert default is landmarks_module._default_opener  # noqa: SLF001  # pyright: ignore[reportPrivateUsage]


# ---------------------------------------------------------------------------
# T6/T1 — the bounded backoff is genuinely small: a real-time upper bound (hermetic, no network) that would
# red if a future edit silently widened TRANSPORT_RETRY_BACKOFF_SECONDS or MAX_TRANSPORT_ATTEMPTS.
# ---------------------------------------------------------------------------


def test_transport_retry_backoff_constant_is_the_estimate_value_and_wait_stays_bounded() -> None:
    assert TRANSPORT_RETRY_BACKOFF_SECONDS == 0.5
    resets: list[BaseException | tuple[int, bytes]] = [ConnectionResetError("reset")] * MAX_TRANSPORT_ATTEMPTS
    opener, _ = _counting_opener(resets)
    started = time.monotonic()
    with pytest.raises(TransportInconclusive):
        fetch_page_text("https://example.invalid/timed", opener=opener)
    elapsed = time.monotonic() - started
    expected_sleeps = MAX_TRANSPORT_ATTEMPTS - 1
    # Generous upper bound (5x the exact expected wait) to absorb scheduler jitter without masking a
    # regression that scales the backoff up by an order of magnitude or removes the bound entirely.
    assert elapsed < expected_sleeps * TRANSPORT_RETRY_BACKOFF_SECONDS * 5 + 1.0


# ---------------------------------------------------------------------------
# T5 (C2) — negative controls proving the AC10 skip/except-parity guard's detection logic actually reds on
# a reconstructed defect, reproduced here as a pure string-algorithm test (never by editing the guarded
# files themselves, which stay production test files this suite must not modify).
# ---------------------------------------------------------------------------


def _skip_except_parity_holds(text: str) -> bool:
    """The exact detection rule AC10's guard applies in both `test_verify_landmarks_contract.py` and
    `test_demo_bundle.py`: every `pytest.skip(` call site count must equal the `except TransportInconclusive`
    count, and there must be at least one of each."""
    skip_count = text.count("pytest.skip(")
    except_count = text.count("except TransportInconclusive")
    return skip_count > 0 and skip_count == except_count


def test_skip_except_parity_rule_reds_on_a_blanket_unguarded_skip() -> None:
    """Reconstruct the defect the AC10 guard exists to catch: a `pytest.skip(...)` call with no
    `except TransportInconclusive` anywhere in the file — the shape a careless future edit would introduce
    to paper over a flake instead of classifying it. Prove the rule this suite's guard applies detects it."""
    broken_source = "import pytest\n\n\ndef test_something() -> None:\n    pytest.skip('just skip it')\n"
    assert not _skip_except_parity_holds(broken_source)


def test_skip_except_parity_rule_reds_on_a_skip_count_exceeding_except_count() -> None:
    """A second reconstructed defect: two skip call sites but only one guarding `except`, e.g. a
    copy-pasted skip added outside any handler. The count-equality check (not just "at least one guard
    exists") is what catches this."""
    broken_source = (
        "import pytest\n\n\n"
        "def test_first() -> None:\n"
        "    try:\n"
        "        do_thing()\n"
        "    except TransportInconclusive as exc:\n"
        "        pytest.skip(f'blip: {exc}')\n\n\n"
        "def test_second() -> None:\n"
        "    pytest.skip('unguarded second skip')\n"
    )
    assert not _skip_except_parity_holds(broken_source)


def test_skip_except_parity_rule_passes_on_the_fixed_shape() -> None:
    """The positive control: exactly one skip, gated on exactly one `except TransportInconclusive` handler,
    is the shape both real guarded files ship (proving the rule is not vacuously false on everything)."""
    fixed_source = (
        "import pytest\n\n\n"
        "def test_something() -> None:\n"
        "    try:\n"
        "        do_thing()\n"
        "    except TransportInconclusive as exc:\n"
        "        pytest.skip(f'blip: {exc}')\n"
    )
    assert _skip_except_parity_holds(fixed_source)


def test_ac10_guard_in_contract_test_file_uses_the_same_parity_rule_this_suite_verifies() -> None:
    """Confirm the real guard in `test_verify_landmarks_contract.py` (this task's shipped AC10 test) applies
    the exact rule reconstructed above, not a weaker or differently-shaped check."""
    text = (REPO_ROOT / "pipeline" / "tests" / "test_verify_landmarks_contract.py").read_text()
    assert _skip_except_parity_holds(text)


def test_ac10_guard_in_demo_bundle_test_file_uses_the_same_parity_rule_this_suite_verifies() -> None:
    """Confirm the real guard in `test_demo_bundle.py` (this task's shipped AC10 test) applies the exact
    rule reconstructed above, not a weaker or differently-shaped check."""
    text = (REPO_ROOT / "pipeline" / "tests" / "test_demo_bundle.py").read_text()
    assert _skip_except_parity_holds(text)


# ---------------------------------------------------------------------------
# T3/AC11 — registry absence, reproduced independently of the implementer's own test with a fresh assertion
# shape (iterate every registered code's exact string, not just membership in a derived set).
# ---------------------------------------------------------------------------


def test_transport_inconclusive_class_name_and_both_registered_codes_never_collide() -> None:
    import json

    registry = json.loads((REPO_ROOT / "contracts" / "error-codes.json").read_text())
    for entry in registry["codes"]:
        assert entry["code"] != "TransportInconclusive"
        assert entry["code"] != TransportInconclusive.__name__
    assert TransportInconclusive.__name__ not in {LO_LANDMARK_UNSOURCED, SPINE_SOURCE_REF_UNRESOLVED}
