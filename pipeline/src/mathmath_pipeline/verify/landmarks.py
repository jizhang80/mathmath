"""Live HTTP resolution of landmark `source_url`s (I15) and the L0-3b `source_ref` resolver scan.

`contracts/content-policy.md` § Landmarks (v1.1.0): `source_url` must resolve (HTTP 2xx) and the fetched
page text must contain the landmark's `source_title`. `contracts/graph-constraints.md` L0-3b: every node
without `expectation_codes` carries a `source_ref` whose locator resolves at build.
"""

from __future__ import annotations

import http.client
import ssl
import time
import urllib.error
import urllib.request
from collections.abc import Callable
from dataclasses import dataclass
from typing import Any

LO_LANDMARK_UNSOURCED = "LO_LANDMARK_UNSOURCED"
SPINE_SOURCE_REF_UNRESOLVED = "SPINE_SOURCE_REF_UNRESOLVED"

_USER_AGENT = "mathmath-pipeline/1.0 (+content verification)"
_TIMEOUT_SECONDS = 10

MAX_TRANSPORT_ATTEMPTS = 3  # [ESTIMATE: bounded retry count for a transport blip, not a measured flake rate]
TRANSPORT_RETRY_BACKOFF_SECONDS = 0.5  # [ESTIMATE: fixed backoff between attempts, kept short]


class ResolutionFailure(Exception):
    """A landmark or source-ref URL did not resolve with HTTP 2xx (I15)."""

    def __init__(self, code: str, url: str, detail: str) -> None:
        super().__init__(f"{code}: {url}: {detail}")
        self.code = code
        self.url = url


class TransportInconclusive(Exception):
    """A transport-level failure (connection reset, timeout, DNS/TLS error) persisted across every retry.

    The source's liveness is unknown, not confirmed dead. Never carries `LO_LANDMARK_UNSOURCED` or
    `SPINE_SOURCE_REF_UNRESOLVED` — those codes mean a confirmed non-2xx response, which this is not.
    """

    def __init__(self, url: str, attempts: int, detail: str) -> None:
        super().__init__(f"transport inconclusive after {attempts} attempt(s): {url}: {detail}")
        self.url = url
        self.attempts = attempts


_TRANSPORT_ERRORS: tuple[type[BaseException], ...] = (
    urllib.error.URLError,
    ConnectionResetError,
    TimeoutError,
    ssl.SSLError,
    http.client.IncompleteRead,
)


def _default_opener(request: urllib.request.Request) -> Any:  # noqa: ANN401
    return urllib.request.urlopen(request, timeout=_TIMEOUT_SECONDS)  # noqa: S310


def _fetch_once(url: str, opener: Callable[[urllib.request.Request], Any]) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": _USER_AGENT})
    with opener(request) as response:
        status = response.status
        if not 200 <= status < 300:
            raise ResolutionFailure(LO_LANDMARK_UNSOURCED, url, f"HTTP {status}, expected 2xx")
        return response.read().decode("utf-8", errors="replace")


def fetch_page_text(url: str, *, opener: Callable[[urllib.request.Request], Any] = _default_opener) -> str:
    """Issue a real GET request and return the decoded page text.

    A confirmed non-2xx status (`urllib.error.HTTPError`, a subclass of `urllib.error.URLError`) raises
    `ResolutionFailure(LO_LANDMARK_UNSOURCED, ...)` immediately, with no retry (I15: a confirmed non-2xx
    status is a genuine dead source). A transport-level failure — `urllib.error.URLError` (DNS/connect
    failure), `ConnectionResetError`, `TimeoutError`, `ssl.SSLError`, or `http.client.IncompleteRead` — is
    retried up to `MAX_TRANSPORT_ATTEMPTS` times with a `TRANSPORT_RETRY_BACKOFF_SECONDS` pause between
    attempts; if it persists across every attempt, raises `TransportInconclusive` — never caught to
    produce a passing result and never mapped to `LO_LANDMARK_UNSOURCED` (I15).
    """
    last_exc: BaseException = RuntimeError("unreachable")
    for attempt in range(1, MAX_TRANSPORT_ATTEMPTS + 1):
        try:
            return _fetch_once(url, opener)
        except urllib.error.HTTPError as exc:
            raise ResolutionFailure(LO_LANDMARK_UNSOURCED, url, f"HTTP {exc.code}, expected 2xx") from exc
        except _TRANSPORT_ERRORS as exc:
            last_exc = exc
            if attempt < MAX_TRANSPORT_ATTEMPTS:
                time.sleep(TRANSPORT_RETRY_BACKOFF_SECONDS)
    raise TransportInconclusive(url, MAX_TRANSPORT_ATTEMPTS, str(last_exc)) from last_exc


def page_contains(page_text: str, needle: str) -> bool:
    """Case-insensitive substring match (`contracts/content-policy.md` § Landmarks)."""
    return needle.lower() in page_text.lower()


@dataclass(frozen=True)
class SourceRefEntry:
    node_id: str
    source: str
    locator: str


def scan_source_refs(nodes_file: dict[str, Any]) -> list[SourceRefEntry]:
    """Every node carrying a `source_ref` key (L0-3b). `data/demo` carries none (all nodes have codes)."""
    entries: list[SourceRefEntry] = []
    for node in nodes_file["nodes"]:
        source_ref = node.get("source_ref")
        if source_ref is None:
            continue
        entries.append(
            SourceRefEntry(node_id=node["id"], source=source_ref["source"], locator=source_ref["locator"])
        )
    return entries


def resolve_source_ref(
    entry: SourceRefEntry,
    sources_file: dict[str, Any],
    *,
    opener: Callable[[urllib.request.Request], Any] = _default_opener,
) -> None:
    """Resolve `entry`'s registered source `url` (HTTP 2xx); raise `SPINE_SOURCE_REF_UNRESOLVED` on a
    confirmed non-2xx status, or propagate `TransportInconclusive` (carrying `entry`'s node/locator
    context) on a persisted transport-level failure — never mapped to `SPINE_SOURCE_REF_UNRESOLVED`, since
    a transport blip is not a confirmed dead source (I15).

    No contract defines a URL-join convention between a source's `url` and a `source_ref.locator`, so this
    resolves the source's own `url` directly and carries `locator` in the failure detail for diagnosis
    only (untested by `data/demo`, whose scan count is `0`).
    """
    for source in sources_file["sources"]:
        if source["source"] == entry.source:
            try:
                fetch_page_text(source["url"], opener=opener)
            except ResolutionFailure as exc:
                raise ResolutionFailure(
                    SPINE_SOURCE_REF_UNRESOLVED,
                    source["url"],
                    f"locator {entry.locator!r} on node {entry.node_id!r}: {exc}",
                ) from exc
            except TransportInconclusive as exc:
                raise TransportInconclusive(
                    source["url"],
                    exc.attempts,
                    f"locator {entry.locator!r} on node {entry.node_id!r}: {exc}",
                ) from exc
            return
    raise ResolutionFailure(
        SPINE_SOURCE_REF_UNRESOLVED,
        entry.source,
        f"source {entry.source!r} not found in sources.json (node {entry.node_id!r})",
    )
