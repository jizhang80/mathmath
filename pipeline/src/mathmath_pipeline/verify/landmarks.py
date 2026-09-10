"""Live HTTP resolution of landmark `source_url`s (I15) and the L0-3b `source_ref` resolver scan.

`contracts/content-policy.md` § Landmarks (v1.1.0): `source_url` must resolve (HTTP 2xx) and the fetched
page text must contain the landmark's `source_title`. `contracts/graph-constraints.md` L0-3b: every node
without `expectation_codes` carries a `source_ref` whose locator resolves at build.
"""

from __future__ import annotations

import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any

LO_LANDMARK_UNSOURCED = "LO_LANDMARK_UNSOURCED"
SPINE_SOURCE_REF_UNRESOLVED = "SPINE_SOURCE_REF_UNRESOLVED"

_USER_AGENT = "mathmath-pipeline/1.0 (+content verification)"
_TIMEOUT_SECONDS = 10


class ResolutionFailure(Exception):
    """A landmark or source-ref URL did not resolve with HTTP 2xx (I15)."""

    def __init__(self, code: str, url: str, detail: str) -> None:
        super().__init__(f"{code}: {url}: {detail}")
        self.code = code
        self.url = url


def fetch_page_text(url: str) -> str:
    """Issue a real GET request and return the decoded page text; raise on a non-2xx status.

    `urllib.error.URLError` (DNS/connection failure) propagates unmodified — never caught to produce a
    passing result (I15).
    """
    request = urllib.request.Request(url, headers={"User-Agent": _USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=_TIMEOUT_SECONDS) as response:  # noqa: S310
            status = response.status
            if not 200 <= status < 300:
                raise ResolutionFailure(LO_LANDMARK_UNSOURCED, url, f"HTTP {status}, expected 2xx")
            return response.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as exc:
        raise ResolutionFailure(LO_LANDMARK_UNSOURCED, url, f"HTTP {exc.code}, expected 2xx") from exc


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


def resolve_source_ref(entry: SourceRefEntry, sources_file: dict[str, Any]) -> None:
    """Resolve `entry`'s registered source `url` (HTTP 2xx); raise `SPINE_SOURCE_REF_UNRESOLVED` otherwise.

    No contract defines a URL-join convention between a source's `url` and a `source_ref.locator`, so this
    resolves the source's own `url` directly and carries `locator` in the failure detail for diagnosis only
    (untested by `data/demo`, whose scan count is `0`).
    """
    for source in sources_file["sources"]:
        if source["source"] == entry.source:
            try:
                fetch_page_text(source["url"])
            except ResolutionFailure as exc:
                raise ResolutionFailure(
                    SPINE_SOURCE_REF_UNRESOLVED,
                    source["url"],
                    f"locator {entry.locator!r} on node {entry.node_id!r}: {exc}",
                ) from exc
            return
    raise ResolutionFailure(
        SPINE_SOURCE_REF_UNRESOLVED,
        entry.source,
        f"source {entry.source!r} not found in sources.json (node {entry.node_id!r})",
    )
