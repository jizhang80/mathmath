"""Hermetic coverage for the transport-blip vs. dead-source classification in the landmark resolver
(EPIC 03 task 00, fixing the flake in `test_verify_landmarks_contract.py`'s live network tests).

Injects a plain opener function (never a test-double substitution library — the anti-vacuity guard in
`test_verify_landmarks_contract.py` forbids those tokens repo-wide) so the retry/backoff/classification
logic is exercised deterministically, with no network access.
"""

from __future__ import annotations

import http.client
import ssl
import urllib.error
import urllib.request
from collections.abc import Callable
from email.message import Message
from typing import Any

import pytest

from mathmath_pipeline.verify.landmarks import (
    LO_LANDMARK_UNSOURCED,
    MAX_TRANSPORT_ATTEMPTS,
    SPINE_SOURCE_REF_UNRESOLVED,
    ResolutionFailure,
    SourceRefEntry,
    TransportInconclusive,
    fetch_page_text,
    resolve_source_ref,
)


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


def test_fetch_page_text_retries_a_connection_reset_then_succeeds() -> None:
    opener, calls = _counting_opener([ConnectionResetError("reset"), (200, b"hello world")])
    text = fetch_page_text("https://example.invalid/reset-once", opener=opener)
    assert text == "hello world"
    assert calls[0] == 2


def test_fetch_page_text_raises_transport_inconclusive_after_max_attempts_of_resets() -> None:
    outcomes: list[BaseException | tuple[int, bytes]] = [
        ConnectionResetError("reset")
    ] * MAX_TRANSPORT_ATTEMPTS
    opener, calls = _counting_opener(outcomes)
    with pytest.raises(TransportInconclusive) as exc_info:
        fetch_page_text("https://example.invalid/always-reset", opener=opener)
    assert calls[0] == MAX_TRANSPORT_ATTEMPTS
    assert exc_info.value.attempts == MAX_TRANSPORT_ATTEMPTS


def test_fetch_page_text_retries_every_named_transport_error_type() -> None:
    transport_errors: list[BaseException] = [
        TimeoutError("timed out"),
        urllib.error.URLError("connection refused"),
        ssl.SSLError("bad handshake"),
        http.client.IncompleteRead(partial=b""),
    ]
    for transport_error in transport_errors:
        opener, calls = _counting_opener([transport_error, (200, b"ok")])
        text = fetch_page_text("https://example.invalid/transient", opener=opener)
        assert text == "ok"
        assert calls[0] == 2


def test_fetch_page_text_raises_resolution_failure_immediately_on_http_404_no_retry() -> None:
    error = urllib.error.HTTPError("https://example.invalid/missing", 404, "Not Found", Message(), None)
    opener, calls = _counting_opener([error])
    with pytest.raises(ResolutionFailure) as exc_info:
        fetch_page_text("https://example.invalid/missing", opener=opener)
    assert exc_info.value.code == LO_LANDMARK_UNSOURCED
    assert calls[0] == 1


def test_fetch_page_text_resolves_on_http_200_first_attempt() -> None:
    opener, calls = _counting_opener([(200, b"page text")])
    text = fetch_page_text("https://example.invalid/ok", opener=opener)
    assert text == "page text"
    assert calls[0] == 1


def test_resolve_source_ref_propagates_transport_inconclusive_unmodified() -> None:
    outcomes: list[BaseException | tuple[int, bytes]] = [
        ConnectionResetError("reset")
    ] * MAX_TRANSPORT_ATTEMPTS
    opener, _ = _counting_opener(outcomes)
    entry = SourceRefEntry(node_id="n", source="s", locator="p. 1")
    sources_file: dict[str, Any] = {"sources": [{"source": "s", "url": "https://example.invalid/flaky"}]}
    with pytest.raises(TransportInconclusive) as exc_info:
        resolve_source_ref(entry, sources_file, opener=opener)
    assert exc_info.value.attempts == MAX_TRANSPORT_ATTEMPTS


def test_resolve_source_ref_raises_spine_source_ref_unresolved_on_a_confirmed_404() -> None:
    error = urllib.error.HTTPError("https://example.invalid/dead", 404, "Not Found", Message(), None)
    opener, calls = _counting_opener([error])
    entry = SourceRefEntry(node_id="n", source="s", locator="p. 1")
    sources_file: dict[str, Any] = {"sources": [{"source": "s", "url": "https://example.invalid/dead"}]}
    with pytest.raises(ResolutionFailure) as exc_info:
        resolve_source_ref(entry, sources_file, opener=opener)
    assert exc_info.value.code == SPINE_SOURCE_REF_UNRESOLVED
    assert calls[0] == 1
