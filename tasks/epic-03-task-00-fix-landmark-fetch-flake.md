# Epic 03 · Task 00: classify transport-level landmark-fetch failures separately from dead sources

---
epic: 03
task: 00
slug: fix-landmark-fetch-flake
kind: fix
risk: seam
depends_on: [01.7]
model: sonnet
---

> **Origin.** `pipeline/tests/test_verify_landmarks_contract.py` is the only non-hermetic test suite in the
> repo (it does live HTTPS fetches, deliberately, per I15). It has flaked three times: an unreproducible
> local run during EPIC 01 (`docs/audits/epic-01-acceptance.md:123-139`), a local run during EPIC 02.12 that
> passed on retry, and CI run 34528761105 on PR #8
> (`ConnectionResetError: [Errno 54] Connection reset by peer` in
> `test_resolve_source_ref_raises_spine_source_ref_unresolved_when_registered_url_404s`). EPIC 02's brief
> named this a deferred `fix(pipeline)` task the moment CI flaked
> (`docs/epics/epic-02-core-behaviour.md:310-316`), and the EPIC 01 acceptance report recommended the exact
> shape of the fix without landing it (`docs/audits/epic-01-acceptance.md:130-139`). This task lands it.
>
> **Branch.** Runs first on `epic-03a-map-core`, immediately after EPIC 02b merges to `main`, before any
> other EPIC 03 task. Its file scope is the pipeline-side resolver and its tests only — no `Core`, no `App`,
> no graph/data changes. Commit subject:
> `fix(pipeline): classify transport-level landmark-fetch failures separately from dead sources`.
>
> **R-7 classification (for the next acceptance report's `fix:`-commit table):** cause `test-infra`; corrects
> task 01.7 (`pipeline/src/mathmath_pipeline/verify/landmarks.py`, landed in EPIC 01); risk tier `seam`.
> Rework, not new output. The resolver's original design was deliberate and I15-correct — the gap is that it
> could not tell a transport blip from a genuinely dead source, which is exactly the risk the EPIC 01
> planner and acceptance report both flagged in advance and left for the first flake to trigger.

## §1 Goal & acceptance criteria

Goal: `pipeline/src/mathmath_pipeline/verify/landmarks.py`'s `fetch_page_text` and `resolve_source_ref`
distinguish a transport-level failure (connection reset, timeout, DNS/TLS error) — retried a bounded number
of times, then raised as a new, distinct `TransportInconclusive` exception — from a confirmed HTTP
4xx/5xx, which still raises the existing `ResolutionFailure` (`LO_LANDMARK_UNSOURCED` /
`SPINE_SOURCE_REF_UNRESOLVED`) immediately, with no retry. The five live `@pytest.mark.network` tests that
exercise real URLs — three in `pipeline/tests/test_verify_landmarks_contract.py` and two in
`pipeline/tests/test_demo_bundle.py` (`test_landmark_source_url_resolves`,
`test_landmark_resolution_failure_path_is_real`) — treat a `TransportInconclusive` outcome as
`pytest.skip(reason=...)` — never a pass, never a silent no-op, and never something a genuine dead-source
failure can hide behind — while a hermetic test file proves the classification logic deterministically, with
no network access.

Invariants in play:

- **I15**: a landmark that cannot be sourced is still dropped/failed on a confirmed non-2xx response,
  unconditionally. This task narrows only which failures count as "confirmed" — a transport blip is no
  longer a candidate for accidentally producing either a pass (never was) or an unhandled crash (was, per the
  CI flake); a confirmed 4xx/5xx is untouched and still fails the build path this check protects.
  `contracts/content-policy.md` § Landmarks: "Unsourced → dropped, never invented, never 'hypothetical'."
- **I2**: the classification is fully deterministic Tier-0 code (bounded retry count, fixed backoff, no
  model call anywhere in this path); "inconclusive" is never silently treated as "resolved" or as "dead" —
  a caller must handle it explicitly.
- **I9**: zero human review. The retry/backoff/classification thresholds are fixed constants in code; no
  step in this task asks anyone to eyeball a result.

Acceptance criteria (each independently verifiable by `pytest`; hermetic ACs run with no network):

- AC1 (retry-then-succeed, hermetic): `fetch_page_text(url, opener=<fake that raises ConnectionResetError
  once, then returns 200>)` returns the decoded body, and the fake opener was called exactly twice.
- AC2 (exhausted retries → inconclusive, hermetic): `fetch_page_text(url, opener=<fake that always raises
  ConnectionResetError>)` raises `TransportInconclusive` after exactly `MAX_TRANSPORT_ATTEMPTS` calls to the
  opener; `exc.attempts == MAX_TRANSPORT_ATTEMPTS`.
- AC3 (every named transport-error type retries, hermetic): `TimeoutError`, `urllib.error.URLError`,
  `ssl.SSLError`, and `http.client.IncompleteRead`, each raised once then followed by a 200, each resolve
  successfully with exactly 2 opener calls.
- AC4 (confirmed 404 → immediate `ResolutionFailure`, no retry, hermetic): `fetch_page_text(url,
  opener=<fake that raises urllib.error.HTTPError(..., 404, ...)>)` raises `ResolutionFailure` with `.code ==
  LO_LANDMARK_UNSOURCED` after exactly one opener call.
- AC5 (confirmed 200 → resolved on the first attempt, hermetic, regression guard): unchanged happy path,
  exactly one opener call.
- AC6 (`resolve_source_ref` propagates `TransportInconclusive` unmodified, hermetic): with an opener that
  always raises `ConnectionResetError`, `resolve_source_ref(entry, sources_file, opener=...)` raises
  `TransportInconclusive` (never `ResolutionFailure`, never `SPINE_SOURCE_REF_UNRESOLVED`).
- AC7 (`resolve_source_ref` still raises `SPINE_SOURCE_REF_UNRESOLVED` on a confirmed 404, hermetic): with an
  opener that raises a 404 `HTTPError`, `resolve_source_ref` raises `ResolutionFailure` with `.code ==
  SPINE_SOURCE_REF_UNRESOLVED`, in exactly one opener call — I15 is not weakened.
- AC8 (live tests skip only on inconclusive, never on confirmed failure): the three
  `@pytest.mark.network` tests in `test_verify_landmarks_contract.py` and the two `@pytest.mark.network`
  tests in `test_demo_bundle.py` (`test_landmark_source_url_resolves`,
  `test_landmark_resolution_failure_path_is_real`) that call `fetch_page_text` or `resolve_source_ref`
  against a real URL catch `TransportInconclusive` and call `pytest.skip(reason=...)`; every other
  exception, and every explicit assertion after a successful/confirmed-failed call, still runs and can still
  fail the test.
- AC9 (DNS failure is genuinely expected and deterministic, not skipped): the live test against a host that
  cannot resolve asserts `TransportInconclusive` is raised with `.attempts == MAX_TRANSPORT_ATTEMPTS` — this
  is the expected outcome, so it is asserted, not skipped.
- AC10 (skip is structurally tied to the transport classification): a new test in
  `test_verify_landmarks_contract.py` scans that file's own source and asserts every `pytest.skip(` call in
  the file has a matching `except TransportInconclusive`; a new, equivalent test in `test_demo_bundle.py`
  scans that file's own source and asserts the same — a blanket or unguarded skip added later to either file
  fails the corresponding test.
- AC11 (registry unchanged): `TransportInconclusive` is confirmed absent from `contracts/error-codes.json`'s
  code set; `LO_LANDMARK_UNSOURCED` and `SPINE_SOURCE_REF_UNRESOLVED` remain the only two registered codes
  this module raises.
- AC12 (negative control on pre-fix code): AC1 and AC2's hermetic tests fail on the code as it stood before
  this task (no retry loop, no `TransportInconclusive` type, no `opener` parameter) — confirmed by re-running
  them against `git show 01.7-landed-revision:pipeline/src/mathmath_pipeline/verify/landmarks.py`-equivalent
  code during implementation (the guard is load-bearing, not vacuous).
- AC13 (anti-vacuity guard unaffected): `test_no_mock_or_skip_disables_the_live_landmark_check_anywhere_in_pipeline_tests`
  still passes over every file this task touches or adds — no `unittest.mock`, `monkeypatch`,
  `@pytest.mark.skip`, `pytest.mark.skip(`, `Mock(`, `MagicMock`, `responses.`, `vcr.`, or `requests_mock`
  token appears anywhere in this task's new or modified test files.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `pipeline/src/mathmath_pipeline/verify/landmarks.py` — MODIFY: add `TransportInconclusive`, the
  `MAX_TRANSPORT_ATTEMPTS` / `TRANSPORT_RETRY_BACKOFF_SECONDS` constants, the `_TRANSPORT_ERRORS`
  classification tuple, an injectable `opener` parameter on `fetch_page_text` and `resolve_source_ref`, and
  the retry loop. `page_contains`, `SourceRefEntry` and `scan_source_refs` are untouched.
- `pipeline/src/mathmath_pipeline/verify/__init__.py` — MODIFY: re-export `TransportInconclusive` from
  `mathmath_pipeline.verify.landmarks`, added to both the import block and `__all__`, matching the file's
  existing alphabetical-by-case grouping.
- `pipeline/tests/test_verify_landmarks_contract.py` — MODIFY: update the import list; rewrite
  `test_fetch_page_text_raises_on_a_nonexistent_host` to assert `TransportInconclusive` (AC9); wrap the three
  live tests that touch a real URL with the skip-on-inconclusive pattern (AC8); add the registry-absence test
  (AC11) and the skip/except-parity guard test (AC10).
- `pipeline/tests/test_verify_landmarks_transport_retry.py` — CREATE: the hermetic test suite (AC1–AC7,
  AC12), using an injected fake opener function — never `unittest.mock`/`monkeypatch`/`Mock`.
- `pipeline/tests/test_demo_bundle.py` — MODIFY: add `TransportInconclusive` to the package-root
  `from mathmath_pipeline.verify import (...)` block; wrap `test_landmark_source_url_resolves` and
  `test_landmark_resolution_failure_path_is_real` with the same skip-on-inconclusive pattern §4 step 11
  applies to `test_verify_landmarks_contract.py`'s live tests (AC8); add the equivalent skip/except-parity
  structural guard test scoped to this file's own source (AC10).

Out-of-scope (do not touch even if tempted):

- `pipeline/tests/test_verify_cross_module_conformance.py` — unaffected; it does not call `fetch_page_text`
  or `resolve_source_ref`, and neither function's positional signature changes (only a new keyword-only
  `opener` parameter is added).
- `contracts/error-codes.json`, `contracts/content-policy.md`, `contracts/graph-constraints.md` — no
  contract change. `TransportInconclusive` is an internal pipeline exception type, never a registry code
  (§6).
- `docs/tech-stack.md`, `pipeline/pyproject.toml` — no new dependency. The retry uses only
  `urllib`/`ssl`/`http.client`/`time` (stdlib).
- `Packages/Core/**`, `App/Sources/**`, `data/**` — this is a pipeline-only fix; nothing here touches graph
  data, `Core`, or the app.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rule:

- `contracts/content-policy.md` — heading `## Landmarks (I15, D22)`:
  > Real, named, verifiable; `source_url` required and resolving at build (HTTP 2xx); `source_title`
  > required — the title of the real, named thing the landmark cites, as that title appears on the source
  > page — and the fetched page text must contain it (case-insensitive substring). The landmark's `name` is
  > the project's own descriptive claim about the mathematics and is by design not a term from the source, so
  > it is never asserted against the page; a landmark's `name` is never edited to make a check pass. ≥ 1 node
  > id. Unsourced → dropped, never invented, never "hypothetical".

  Source: `contracts/content-policy.md:39-45`. This task must not weaken this rule: a confirmed non-2xx
  status still raises `LO_LANDMARK_UNSOURCED`/`SPINE_SOURCE_REF_UNRESOLVED`, unconditionally and without
  retry.

- `contracts/error-codes.json` (registered codes this module raises):
  ```json
  {"code": "LO_LANDMARK_UNSOURCED", "recoverable": true, "surface": "internal", "user_text": null},
  {"code": "SPINE_SOURCE_REF_UNRESOLVED", "recoverable": true, "surface": "owner", "user_text": null},
  ```
  Source: `contracts/error-codes.json:33, 42`.

- `docs/epics/epic-02-core-behaviour.md`:
  > 10. **Live-landmark-test transport-retry fix** recommended in `docs/audits/epic-01-acceptance.md` §7 —
  >     pipeline-side and not `Core` behaviour. It enters only if CI flakes during this EPIC, as a separate
  >     `fix(pipeline)` task outside the 8-task count.

  Source: `docs/epics/epic-02-core-behaviour.md:314-316`.

- `docs/audits/epic-01-acceptance.md`:
  > This is exactly the risk planner note [6] anticipated: a live network call inside the gate can red for a
  > non-code reason. **The design intent is deliberate** — I15 says an unresolvable landmark is a genuine
  > blocking signal and must never be mocked or skipped into vacuity. But that intent covers *the source
  > being gone*, not *the network blipping*, and the two are indistinguishable to the current assertion.
  > **Recommendation for EPIC 02 or the first CI flake, whichever comes first:** distinguish them — e.g.
  > retry a transport-level failure a bounded number of times while still failing hard on a 4xx/5xx or a
  > missing `source_title` — rather than weakening the assertion. Not fixed here: it is out of this EPIC's
  > scope and I would rather record it precisely than paper over it.

  Source: `docs/audits/epic-01-acceptance.md:132-139`.

Prior code this task modifies (verbatim, as it stands today):

- `pipeline/src/mathmath_pipeline/verify/landmarks.py:31-45` (`fetch_page_text`, to be replaced per §4):
  ```python
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
  ```

- `pipeline/src/mathmath_pipeline/verify/landmarks.py:73-95` (`resolve_source_ref`, to be replaced per §4):
  ```python
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
  ```

- `pipeline/tests/test_verify_landmarks_contract.py:43-75`
  (`test_no_mock_or_skip_disables_the_live_landmark_check_anywhere_in_pipeline_tests`) — the anti-vacuity
  guard this task's new/modified files must keep passing, verbatim forbidden-token list:
  ```python
  forbidden_tokens = [
      "unittest.mock",
      "monkeypatch",
      "@pytest.mark.skip",
      "pytest.mark.skip(",
      "responses.",
      "vcr.",
      "MagicMock",
      "Mock(",
      "requests_mock",
  ]
  ```
  Note: this list does not forbid a runtime `pytest.skip(...)` call (distinct token from
  `pytest.mark.skip(` / `@pytest.mark.skip`), which is why the design in §4/§6 uses `pytest.skip(reason=...)`
  gated on `except TransportInconclusive` rather than the skip *marker*.

- `pipeline/pyproject.toml:7-11, 40-44` — dependency and pytest-marker facts (no retry library present, and
  the `network` marker runs unfiltered):
  ```toml
  dependencies = [
      "anthropic>=1.4,<2",
      "pydantic>=2.13,<3",
      "sympy>=1.14,<2",
  ]
  ```
  ```toml
  [tool.pytest.ini_options]
  testpaths = ["tests"]
  markers = [
      "network: exercises a live HTTPS request (I15 landmark source_url resolution). Runs unfiltered in gate 4 (`uv run pytest -q`, no -m flag); registered only to silence PytestUnknownMarkWarning, never to enable skipping a network test.",
  ]
  ```

- `pipeline/src/mathmath_pipeline/verify/__init__.py:1-53` (full file, to be modified per §4):
  ```python
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
  ```

- `pipeline/tests/test_demo_bundle.py:17-29` (import block, to be modified per §4):
  ```python
  from mathmath_pipeline.verify import (
      LO_BAD_DISTRACTOR_TAG,
      LO_LANDMARK_UNSOURCED,
      LO_PROBE_UNCHECKABLE,
      SPINE_SOURCE_REF_UNRESOLVED,
      ResolutionFailure,
      derive_from_check,
      fetch_page_text,
      find_bad_distractor_tags,
      page_contains,
      scan_source_refs,
      verify_numeric_answers,
  )
  ```

- `pipeline/tests/test_demo_bundle.py:102-121` (the two live tests, to be modified per §4):
  ```python
  @pytest.mark.network
  def test_landmark_source_url_resolves() -> None:
      landmarks = _load("landmarks")["landmarks"]
      landmark = landmarks[0]
      assert landmark["source_title"] == "Interest Act"
      text = fetch_page_text(landmark["source_url"])
      assert page_contains(text, landmark["source_title"])


  # ---------------------------------------------------------------------------
  # AC6 — the resolution failure path is real, not disabled
  # ---------------------------------------------------------------------------


  @pytest.mark.network
  def test_landmark_resolution_failure_path_is_real() -> None:
      broken_url = LANDMARK_URL + "this-path-cannot-exist-mathmath-test"
      with pytest.raises(ResolutionFailure) as exc_info:
          fetch_page_text(broken_url)
      assert exc_info.value.code == LO_LANDMARK_UNSOURCED
  ```

- `scripts/gate.sh:23` (unmodified by this task; the pytest invocation this fix must stay green under):
  ```sh
  ( cd "$ROOT/pipeline" && uv run pytest -q )
  ```

## §4 Implementation outline

Layer: ③ learning objects (pipeline-side build verification of a landmark's `source_url` and a node's
`source_ref`, per `docs/domains/learning-objects.md` W1 step 5c) — offline pipeline code, not `Core`, not the
app.

1. **`pipeline/src/mathmath_pipeline/verify/landmarks.py` — imports.** Add to the existing import block:
   ```python
   import http.client
   import ssl
   import time
   from collections.abc import Callable
   ```
   (`urllib.error`, `urllib.request`, `dataclass`, `Any` stay as they are.)

2. **New constants**, placed after `_TIMEOUT_SECONDS`:
   ```python
   MAX_TRANSPORT_ATTEMPTS = 3  # [ESTIMATE: bounded retry count for a transport blip, not a measured flake rate]
   TRANSPORT_RETRY_BACKOFF_SECONDS = 0.5  # [ESTIMATE: fixed backoff between attempts, kept short]
   ```
   These are public (no leading underscore) so tests can import and assert against them directly, matching
   `LO_LANDMARK_UNSOURCED`/`SPINE_SOURCE_REF_UNRESOLVED`'s existing public-constant convention in this file.

3. **New exception type**, placed immediately after `ResolutionFailure`:
   ```python
   class TransportInconclusive(Exception):
       """A transport-level failure (connection reset, timeout, DNS/TLS error) persisted across every retry.

       The source's liveness is unknown, not confirmed dead. Never carries `LO_LANDMARK_UNSOURCED` or
       `SPINE_SOURCE_REF_UNRESOLVED` — those codes mean a confirmed non-2xx response, which this is not.
       """

       def __init__(self, url: str, attempts: int, detail: str) -> None:
           super().__init__(f"transport inconclusive after {attempts} attempt(s): {url}: {detail}")
           self.url = url
           self.attempts = attempts
   ```

4. **Classification tuple**, placed after `TransportInconclusive`:
   ```python
   _TRANSPORT_ERRORS: tuple[type[BaseException], ...] = (
       urllib.error.URLError,
       ConnectionResetError,
       TimeoutError,
       ssl.SSLError,
       http.client.IncompleteRead,
   )
   ```
   `urllib.error.HTTPError` is a subclass of `urllib.error.URLError` but is caught by an earlier, more
   specific `except` clause (step 6), so it never falls into this tuple's classification.

5. **Default opener and the single-attempt fetch**, replacing the top of the old `fetch_page_text`:
   ```python
   def _default_opener(request: urllib.request.Request) -> Any:
       return urllib.request.urlopen(request, timeout=_TIMEOUT_SECONDS)  # noqa: S310


   def _fetch_once(url: str, opener: Callable[[urllib.request.Request], Any]) -> str:
       request = urllib.request.Request(url, headers={"User-Agent": _USER_AGENT})
       with opener(request) as response:
           status = response.status
           if not 200 <= status < 300:
               raise ResolutionFailure(LO_LANDMARK_UNSOURCED, url, f"HTTP {status}, expected 2xx")
           return response.read().decode("utf-8", errors="replace")
   ```

6. **`fetch_page_text` rewritten** (replaces lines 31-45 quoted in §3), with an injectable `opener`
   defaulting to the real one:
   ```python
   def fetch_page_text(
       url: str, *, opener: Callable[[urllib.request.Request], Any] = _default_opener
   ) -> str:
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
   ```

7. **`resolve_source_ref` rewritten** (replaces lines 73-95 quoted in §3), passing the `opener` through and
   propagating `TransportInconclusive` distinctly from `ResolutionFailure`:
   ```python
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
   ```

8. **Error codes thrown**: unchanged — `LO_LANDMARK_UNSOURCED` and `SPINE_SOURCE_REF_UNRESOLVED`
   (`contracts/error-codes.json:33, 42`), both still raised only from a confirmed non-2xx response.
   `TransportInconclusive` is a new internal exception TYPE, never a registry error code (§6).

9. **Model-calling paths**: none. This entire path is deterministic Tier-0 code — no confidence threshold or
   Tier-0 fallback applies because there is no model call to gate.

10. **`pipeline/tests/test_verify_landmarks_transport_retry.py` — new hermetic file.** Create a fake opener
    helper and the hermetic tests for AC1–AC7 and AC12:
    ```python
    """Hermetic coverage for the transport-blip vs. dead-source classification in `verify/landmarks.py`
    (EPIC 03 task 00, fixing the flake in `test_verify_landmarks_contract.py`'s live network tests).

    Injects a plain opener function (never `unittest.mock`/`monkeypatch`/`Mock` — the anti-vacuity guard in
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

        def __enter__(self) -> "_FakeResponse":
            return self

        def __exit__(self, *exc_info: object) -> None:
            return None

        def read(self) -> bytes:
            return self._body


    def _counting_opener(
        outcomes: list[BaseException | tuple[int, bytes]],
    ) -> tuple[Callable[[urllib.request.Request], Any], list[int]]:
        calls = [0]

        def opener(request: urllib.request.Request) -> Any:
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
    ```

11. **`pipeline/tests/test_verify_landmarks_contract.py` — targeted edits.**
    - Import list (`landmarks.py:15-27` region in the current file): add `MAX_TRANSPORT_ATTEMPTS` and
      `TransportInconclusive` to the `from mathmath_pipeline.verify.landmarks import (...)` block.
    - Rewrite `test_fetch_page_text_raises_on_a_nonexistent_host` (current lines 150-158) to:
      ```python
      @pytest.mark.network
      def test_fetch_page_text_raises_transport_inconclusive_on_a_nonexistent_host() -> None:
          """A DNS-resolution failure (a host that cannot exist) is a transport-level failure: retried up to
          MAX_TRANSPORT_ATTEMPTS times, then raised as TransportInconclusive — never silently caught to
          produce a passing result (I15), and never mapped to LO_LANDMARK_UNSOURCED, since it is the host's
          reachability, not the landmark's, that is unknown here. This host can never resolve, so this
          outcome is genuinely expected and deterministic: asserted, not skipped."""
          with pytest.raises(TransportInconclusive) as exc_info:
              fetch_page_text("https://this-host-cannot-possibly-resolve.mathmath-test-fixture.invalid/")
          assert exc_info.value.attempts == MAX_TRANSPORT_ATTEMPTS
      ```
      Remove the now-unused local `import urllib.error` line this test previously contained.
    - Wrap `test_landmark_source_url_resolution_uses_source_title_not_name_as_needle` (current lines 134-141):
      ```python
      @pytest.mark.network
      def test_landmark_source_url_resolution_uses_source_title_not_name_as_needle() -> None:
          """... (existing docstring, unchanged) ... A transport-inconclusive outcome is skipped, not
          failed, so a network blip does not red the gate; a confirmed non-2xx still fails (I15 is not
          weakened — see the 404 tests below and the hermetic suite)."""
          landmark = _landmark()
          try:
              text = fetch_page_text(landmark["source_url"])
          except TransportInconclusive as exc:
              pytest.skip(f"transport blip, not a confirmed dead source (I15): {exc}")
          assert page_contains(text, landmark["source_title"])
      ```
    - Wrap `test_resolve_source_ref_raises_spine_source_ref_unresolved_when_registered_url_404s` (current
      lines 215-227):
      ```python
      @pytest.mark.network
      def test_resolve_source_ref_raises_spine_source_ref_unresolved_when_registered_url_404s() -> None:
          """... (existing docstring, unchanged) ... The ConnectionResetError this test flaked on in CI run
          34528761105 is now a transport-inconclusive outcome: skipped, not failed. The assertion below
          still runs, and still fails, on a confirmed 404."""
          entry = SourceRefEntry(node_id="some-node", source="broken-source", locator="p. 7")
          sources_file: dict[str, Any] = {
              "sources": [{"source": "broken-source", "url": LANDMARK_URL + "this-path-cannot-exist-source-ref"}]
          }
          try:
              with pytest.raises(ResolutionFailure) as exc_info:
                  resolve_source_ref(entry, sources_file)
          except TransportInconclusive as exc:
              pytest.skip(f"transport blip, not a confirmed dead source (I15): {exc}")
          assert exc_info.value.code == SPINE_SOURCE_REF_UNRESOLVED
          assert exc_info.value.code != LO_LANDMARK_UNSOURCED
      ```
    - Wrap `test_resolve_source_ref_succeeds_silently_when_registered_url_resolves` (current lines 230-235):
      ```python
      @pytest.mark.network
      def test_resolve_source_ref_succeeds_silently_when_registered_url_resolves() -> None:
          """The positive control: a registered source whose `url` genuinely resolves raises nothing. A
          transport-inconclusive outcome is skipped, not failed."""
          entry = SourceRefEntry(node_id="some-node", source="real-source", locator="p. 1")
          sources_file: dict[str, Any] = {"sources": [{"source": "real-source", "url": LANDMARK_URL}]}
          try:
              resolve_source_ref(entry, sources_file)  # must not raise
          except TransportInconclusive as exc:
              pytest.skip(f"transport blip, not a confirmed dead source (I15): {exc}")
      ```
    - Add, after `test_landmark_and_source_ref_codes_are_distinct_and_registered` (current lines 243-248):
      ```python
      def test_transport_inconclusive_is_never_a_registered_error_code() -> None:
          """TransportInconclusive is an internal pipeline exception, not a registry error code (§6 decision
          default): it must never appear in contracts/error-codes.json."""
          registry = json.loads((REPO_ROOT / "contracts" / "error-codes.json").read_text())
          codes = {entry["code"] for entry in registry["codes"]}
          assert "TransportInconclusive" not in codes
          assert "TRANSPORT_INCONCLUSIVE" not in codes


      def test_pytest_skip_calls_in_this_file_are_only_reached_via_except_transportinconclusive() -> None:
          """A future edit must not add a blanket `pytest.skip(...)` to paper over a genuine failure (I15) —
          every `pytest.skip(` call in this file must be inside an `except TransportInconclusive:` handler."""
          text = Path(__file__).read_text()
          skip_count = text.count("pytest.skip(")
          except_count = text.count("except TransportInconclusive")
          assert skip_count > 0, "anti-vacuity: expected at least one transport-inconclusive skip in this file"
          assert skip_count == except_count, (
              f"{skip_count} pytest.skip( call(s) but {except_count} 'except TransportInconclusive' "
              "handler(s) — every skip in this file must be gated on a transport-inconclusive outcome"
          )
      ```

12. **`pipeline/src/mathmath_pipeline/verify/__init__.py` — re-export edit.** Add `TransportInconclusive` to
    the `from mathmath_pipeline.verify.landmarks import (...)` block, inserted alphabetically among the
    existing PascalCase entries (after `SourceRefEntry`), and to `__all__`, inserted alphabetically among the
    existing PascalCase entries there (after `"SourceRefEntry"`, before `"UncheckableCheck"`). The full
    resulting file (replaces the content quoted in §3):
    ```python
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
    ```

13. **`pipeline/tests/test_demo_bundle.py` — targeted edits.** This file already imports from the package
    root (`from mathmath_pipeline.verify import (...)`, quoted in §3), which is why step 12 re-exports
    `TransportInconclusive` rather than leaving `__init__.py` untouched.
    - Import list (current lines 17-29): add `TransportInconclusive`, inserted alphabetically among the
      existing PascalCase entries (after `ResolutionFailure`):
      ```python
      from mathmath_pipeline.verify import (
          LO_BAD_DISTRACTOR_TAG,
          LO_LANDMARK_UNSOURCED,
          LO_PROBE_UNCHECKABLE,
          SPINE_SOURCE_REF_UNRESOLVED,
          ResolutionFailure,
          TransportInconclusive,
          derive_from_check,
          fetch_page_text,
          find_bad_distractor_tags,
          page_contains,
          scan_source_refs,
          verify_numeric_answers,
      )
      ```
    - Wrap `test_landmark_source_url_resolves` (current lines 102-108):
      ```python
      @pytest.mark.network
      def test_landmark_source_url_resolves() -> None:
          landmarks = _load("landmarks")["landmarks"]
          landmark = landmarks[0]
          assert landmark["source_title"] == "Interest Act"
          try:
              text = fetch_page_text(landmark["source_url"])
          except TransportInconclusive as exc:
              pytest.skip(f"transport blip, not a confirmed dead source (I15): {exc}")
          assert page_contains(text, landmark["source_title"])
      ```
    - Wrap `test_landmark_resolution_failure_path_is_real` (current lines 116-121):
      ```python
      @pytest.mark.network
      def test_landmark_resolution_failure_path_is_real() -> None:
          broken_url = LANDMARK_URL + "this-path-cannot-exist-mathmath-test"
          try:
              with pytest.raises(ResolutionFailure) as exc_info:
                  fetch_page_text(broken_url)
          except TransportInconclusive as exc:
              pytest.skip(f"transport blip, not a confirmed dead source (I15): {exc}")
          assert exc_info.value.code == LO_LANDMARK_UNSOURCED
      ```
    - Add, after `test_derive_from_check_takes_only_the_check_object` (current lines 242-244; end of file):
      ```python
      def test_pytest_skip_calls_in_this_file_are_only_reached_via_except_transportinconclusive() -> None:
          """A future edit must not add a blanket `pytest.skip(...)` to paper over a genuine failure (I15) —
          every `pytest.skip(` call in this file must be inside an `except TransportInconclusive:` handler."""
          text = Path(__file__).read_text()
          skip_count = text.count("pytest.skip(")
          except_count = text.count("except TransportInconclusive")
          assert skip_count > 0, "anti-vacuity: expected at least one transport-inconclusive skip in this file"
          assert skip_count == except_count, (
              f"{skip_count} pytest.skip( call(s) but {except_count} 'except TransportInconclusive' "
              "handler(s) — every skip in this file must be gated on a transport-inconclusive outcome"
          )
      ```
      `Path` is already imported in this file (`from pathlib import Path`); no new import needed for it.

14. Smoke check: `( cd pipeline && uv run pytest -q -k "landmarks or transport_retry or demo_bundle" )` is
    green with no network available disabled (hermetic tests only need to pass without network; live tests
    are allowed to skip in that environment, never fail).

## §5 Test plan (risk: seam — full plan)

- **T1 happy path:** AC1, AC3 (every named transport error retries and then succeeds), AC5 (200 resolves
  immediately, unchanged), AC7 (confirmed 404 through `resolve_source_ref`, unchanged code path).
- **T2 negative — invalid input rejected at the boundary:** AC4 (a confirmed 404 raises `ResolutionFailure`
  immediately, no retry — a malformed/dead URL is rejected exactly as before).
- **T3 error taxonomy:** AC4, AC7, AC11 — `LO_LANDMARK_UNSOURCED` and `SPINE_SOURCE_REF_UNRESOLVED` are the
  only two registered codes this module raises; `TransportInconclusive` is confirmed absent from the
  registry.
- **T4 conformance per `contracts/content-policy.md` § Landmarks and I15:** AC4, AC7, AC9 together prove a
  confirmed non-2xx (whether from a real host or an injected fake) still fails exactly as it did before this
  task — the unsourced/unresolved path is not weakened by the addition of a retry.
- **T5 negative control for every regression guard:**
  - AC12: AC1 and AC2's hermetic tests fail against the pre-fix `fetch_page_text` (no `opener` parameter, no
    retry loop, no `TransportInconclusive` type) — confirms the guard is load-bearing, not vacuous.
  - AC10: `test_pytest_skip_calls_in_this_file_are_only_reached_via_except_transportinconclusive` in each of
    `test_verify_landmarks_contract.py` and `test_demo_bundle.py` fails red against a version of its own file
    with an unguarded `pytest.skip(...)` call, proving the parity guard actually constrains future edits in
    both files.
  - AC13: the existing anti-vacuity guard
    (`test_no_mock_or_skip_disables_the_live_landmark_check_anywhere_in_pipeline_tests`) fails red if the new
    hermetic file used `unittest.mock`/`monkeypatch`/`Mock(` — implementer must confirm it stays green with
    the real (non-mock) fake-opener design in this spec.
- **T6 idempotency / no-leak:** AC2 and AC6 assert the exact call count (`calls[0] == MAX_TRANSPORT_ATTEMPTS`)
  — the retry loop makes exactly the bounded number of attempts, never more (no leak into an unbounded retry)
  and never fewer (no silent short-circuit that would make the "bounded" guarantee vacuous).

## §6 Decision defaults

- IF a transport-level failure persists across `MAX_TRANSPORT_ATTEMPTS` THEN raise `TransportInconclusive`,
  an internal pipeline exception, never a registry code — per this task's instruction to prefer an internal
  exception type over a contract change; no `contracts/error-codes.json` edit in this task.
- IF classifying "transport-level" vs. "confirmed dead" THEN `urllib.error.HTTPError` (any non-2xx) is
  confirmed-dead (existing `LO_LANDMARK_UNSOURCED`/`SPINE_SOURCE_REF_UNRESOLVED` mapping, unchanged, no
  retry); `urllib.error.URLError`, `ConnectionResetError`, `TimeoutError`, `ssl.SSLError`, and
  `http.client.IncompleteRead` are transport-level (retried) — grounded in the observed CI failure
  (`ConnectionResetError: [Errno 54]`) and `docs/audits/epic-01-acceptance.md:132-139`'s recommendation.
- IF retry count/backoff values are chosen THEN use `MAX_TRANSPORT_ATTEMPTS = 3` and
  `TRANSPORT_RETRY_BACKOFF_SECONDS = 0.5`, both `[ESTIMATE]`-tagged in code per this task's explicit
  instruction — `contracts/content-policy.md` § Documentation claims (I11) scopes the SOURCED/ESTIMATE
  requirement to `docs/`, `contracts/`, briefs and amendments, not source code, so this tag is applied here
  as a courtesy, not a contract obligation.
- IF a live `@pytest.mark.network` test's assertion path raises `TransportInconclusive` THEN
  `pytest.skip(reason=...)`, but ONLY inside an `except TransportInconclusive:` handler around the specific
  call, never a blanket/marker skip — enforced by AC10's structural guard (in both
  `test_verify_landmarks_contract.py` and `test_demo_bundle.py`) so a future edit cannot broaden the skip in
  either file without the corresponding guard failing red.
- IF `test_demo_bundle.py` needs `TransportInconclusive` to wrap its two live tests THEN re-export it from
  `pipeline/src/mathmath_pipeline/verify/__init__.py` — added to both the
  `from mathmath_pipeline.verify.landmarks import (...)` block and `__all__`, inserted alphabetically among
  the file's existing PascalCase entries (after `SourceRefEntry`) — so `test_demo_bundle.py` keeps its
  existing package-root import style (`from mathmath_pipeline.verify import (...)`,
  `pipeline/tests/test_demo_bundle.py:17-29`) rather than switching to importing from the `landmarks`
  submodule directly.
- IF a retry library would simplify the loop THEN do not add one — `docs/tech-stack.md` §1 names no retry
  library for the pipeline, and `pipeline/pyproject.toml:7-11` lists only `anthropic`, `pydantic`, `sympy` as
  dependencies. The retry uses only stdlib `urllib`/`ssl`/`http.client`/`time`.
- IF `resolve_source_ref`'s `TransportInconclusive` re-raise needs node/locator context THEN wrap it the same
  way `ResolutionFailure` is already wrapped (append `locator {entry.locator!r} on node {entry.node_id!r}` to
  the detail), keeping the exception TYPE unchanged so any future caller can `except TransportInconclusive`
  uniformly regardless of which function raised it.

## §7 Done definition

The task is done when ALL gates pass:

- format + lint clean: `( cd pipeline && uv run ruff check . && uv run ruff format --check . )`.
- typecheck clean: `( cd pipeline && uv run pyright )` — strict mode over `src` and `tests`
  (`pipeline/pyproject.toml:35-38`).
- `pytest` green: `( cd pipeline && uv run pytest -q )` (`scripts/gate.sh:23`) — all hermetic tests pass with
  no network; live `@pytest.mark.network` tests either pass or skip with an explicit
  transport-inconclusive reason, never fail from a transport blip, and still fail on a confirmed dead source.
- AC1–AC13 in §1 all verified, including the two negative controls (AC10, AC12).
- one commit, subject
  `fix(pipeline): classify transport-level landmark-fetch failures separately from dead sources`.
- conforms to `contracts/content-policy.md` § Landmarks (I15 not weakened: a confirmed non-2xx still fails
  unconditionally) and to `contracts/error-codes.json`'s registered codes (unchanged, no new registry entry).
