# Task 03.00 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: landmark-fetch-flake
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- Epic: 03
- Task: 00 (fix task, outside the 8-task count)
- Slug: landmark-fetch-flake
- Summary: Resolve non-deterministic test failures in `pipeline/tests/test_verify_landmarks_contract.py` and related network-touching tests. The only non-hermetic tests in the repo, they perform live HTTPS fetches per I15. Three documented flakes: EPIC 01 local build, EPIC 02.12 local run (passed on retry), CI run 34528761105 on PR #8 (ConnectionResetError: [Errno 54] Connection reset by peer). Goal: distinguish transport blips (bounded retry, explicit inconclusive outcome or clear skip-with-reason) from genuinely dead sources (fail), without weakening I15 or the content-policy landmark rule.
- Invariants in play: I15 (landmarks real, verifiable, resolving; a landmark that cannot be sourced is dropped), I2 (Tier 0 alone usable; every model call has fallback; system never guesses), I1 (step correctness decided by CAS/deterministic code, never by model), I9 (zero human review; machine-verified)

## §B. Applicable contract rules (verbatim)

### contracts/content-policy.md — Landmarks (v1.1.0) — I15, D22

> Real, named, verifiable; `source_url` required and resolving at build (HTTP 2xx); `source_title` required — the title of the real, named thing the landmark cites, as that title appears on the source page — and the fetched page text must contain it (case-insensitive substring). The landmark's `name` is the project's own descriptive claim about the mathematics and is by design not a term from the source, so it is never asserted against the page; a landmark's `name` is never edited to make a check pass. ≥ 1 node id. Unsourced → dropped, never invented, never "hypothetical".

Source: `contracts/content-policy.md:39-45`
Binds this task: the landmark resolver must validate HTTP 2xx and page contains source_title; unresolvable landmarks are dropped (not retried indefinitely or weakened).

### contracts/error-codes.json — Landmark and source-ref error codes (v1.0.0)

```json
{"code": "LO_LANDMARK_UNSOURCED", "recoverable": true, "surface": "internal", "user_text": null},
{"code": "SPINE_SOURCE_REF_UNRESOLVED", "recoverable": true, "surface": "owner", "user_text": null},
```

Source: `contracts/error-codes.json:33, 42`
Binds this task: these are the codes the resolver raises; they are registered and recoverable.

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/learning-objects.md — Landmarks (W1, step 5/5c)

> 5c. **Landmarks** — `source_url` present and resolving at build (HTTP 2xx), `node_ids[]` non-empty and known, else `LO_LANDMARK_UNSOURCED` (D22, I15).

Source: `docs/domains/learning-objects.md:240-245` (referenced in `tasks/context/epic-01-task-07-context.md`)
Binds this task: this task's goal is to keep this check (HTTP 2xx resolution) reliable and deterministic.

## §D. Prior task outputs / accepted work this task depends on

- `pipeline/src/mathmath_pipeline/verify/landmarks.py` — the resolver module, including `fetch_page_text`, `resolve_source_ref`, `page_contains`, and error handling — produced by EPIC 01 task 01.7
- `pipeline/tests/test_verify_landmarks_contract.py` — comprehensive contract-verification tests for landmarks, including live-fetch tests marked `@pytest.mark.network` — produced by EPIC 01 task 01.7

## §E. Negative facts (confirmed ABSENT)

- **No HTTP retry library in the dependencies.** Tech stack (docs/tech-stack.md §1) lists `pytest>=8`, `anthropic>=1.4,<2`, `pydantic>=2.13,<3`, `sympy>=1.14,<2`, `ruff>=0.16`, `pyright>=1.1`, `jsonschema>=4.23`. Source: `pipeline/pyproject.toml:16-22`. No `urllib3`, `requests`, `responses`, `vcrpy`, `requests-mock`, `httpretty`, `betamax`, or any async/retry library is pinned. To add a retry pattern requires either a new dependency or manual retry logic in the resolver.
- **No pytest-socket or response-mocking plugin currently in use.** Grep over `pipeline/tests` for `responses.`, `vcr.`, `unittest.mock`, `monkeypatch` as mock tokens — confirmed absent by `test_verify_landmarks_contract.py:43-75`, which explicitly asserts that no such token appears in any landmark-checking test file (source: `test_no_mock_or_skip_disables_the_live_landmark_check_anywhere_in_pipeline_tests`). Source: `pipeline/tests/test_verify_landmarks_contract.py:43-75`.
- **No skip marker for network tests in gate.sh.** The pytest invocation in `scripts/gate.sh:23` is `uv run pytest -q` with no `-m` flag and no `--co` (collect-only). Source: `scripts/gate.sh:23`. The `network` marker is registered in `pyproject.toml` only to silence `PytestUnknownMarkWarning`, never to skip tests. Source: `pipeline/pyproject.toml:42-44`.
- **`data/demo` carries zero source_ref entries.** All 20 demo nodes carry `expectation_codes` only; no node has a `source_ref`. The scan in `test_verify_landmarks_contract.py::test_scan_source_refs_is_idempotent_and_pure` and `test_demo_bundle.py::test_source_ref_scan_is_explicit_about_zero_scope` confirms this. The `resolve_source_ref` path is therefore exercised only on constructed fixtures in the contract suite, never on real data. Source: `pipeline/tests/test_verify_landmarks_contract.py:177-184`.

## §F. File scope

Files this task may create or modify:

- MODIFY `pipeline/src/mathmath_pipeline/verify/landmarks.py` — the resolver functions `fetch_page_text` and `resolve_source_ref` and their HTTP code paths, timeouts, retry logic (if any), error mapping.
- MODIFY `pipeline/tests/test_verify_landmarks_contract.py` — add or revise tests to validate retry behavior and inconclusive outcomes without weakening the live-fetch assertion (I15).
- POTENTIALLY MODIFY `pipeline/pyproject.toml` — if a new pytest marker (e.g. `flaky` or `xfail_network`) is added to categorize retryable vs. hard-fail network tests (optional).
- POTENTIALLY MODIFY `docs/tech-stack.md` — if a new dependency (e.g. a retry library) is introduced to the pipeline; this is a contract change and requires owner sign-off.

## §G. Technical constraints and open questions

### HTTP resolver current shape (from live source read)

The `fetch_page_text` function in `pipeline/src/mathmath_pipeline/verify/landmarks.py:31-45`:
- Issues a real GET request via `urllib.request.urlopen` with a 10-second timeout (`_TIMEOUT_SECONDS = 10`)
- Raises `urllib.error.HTTPError` on non-2xx status, wrapped as `ResolutionFailure(LO_LANDMARK_UNSOURCED, url, ...)`
- Explicitly does NOT catch `urllib.error.URLError` (DNS/connection failure); lets it propagate unmodified per I15 (lines 34-35: comment "never caught to produce a passing result")
- No retry logic exists; a transport error (ECONNRESET, DNS timeout, etc.) propagates immediately

Source: `pipeline/src/mathmath_pipeline/verify/landmarks.py:19, 31-45`

### Documented flake pattern

Three documented failures:
1. **EPIC 01 local** — one run among 23 landmark-selected runs reported `1 failed, 154 passed`; could not reproduce (12 subsequent full-suite runs all `155 passed`). Source: `docs/audits/epic-01-acceptance.md:123-139`.
2. **EPIC 02.12 local** — passed on retry (mentioned in user brief, not captured in audit yet).
3. **CI run 34528761105 on PR #8** — ConnectionResetError: [Errno 54] Connection reset by peer (mentioned in user brief).

Source: User prompt and `docs/audits/epic-01-acceptance.md:127-139`

### EPIC 02 brief guidance on this fix

From `docs/epics/epic-02-core-behaviour.md:310-316`:

> 10. **Live-landmark-test transport-retry fix** recommended in `docs/audits/epic-01-acceptance.md` §7 — pipeline-side and not `Core` behaviour. It enters only if CI flakes during this EPIC, as a separate `fix(pipeline)` task outside the 8-task count.

Source: `docs/epics/epic-02-core-behaviour.md:310-316`

### EPIC 01 acceptance report recommendation

From `docs/audits/epic-01-acceptance.md:130-139`:

> This is exactly the risk planner note [6] anticipated: a live network call inside the gate can red for a non-code reason. **The design intent is deliberate** — I15 says an unresolvable landmark is a genuine blocking signal and must never be mocked or skipped into vacuity. But that intent covers *the source being gone*, not *the network blipping*, and the two are indistinguishable to the current assertion. **Recommendation for EPIC 02 or the first CI flake, whichever comes first:** distinguish them — e.g. retry a transport-level failure a bounded number of times while still failing hard on a 4xx/5xx or a missing `source_title` — rather than weakening the assertion. Not fixed here: it is out of this EPIC's scope and I would rather record it precisely than paper over it.

Source: `docs/audits/epic-01-acceptance.md:130-139`

### Constraints and questions for the implementer

**CONTRACTS SILENT:** The contracts (`content-policy.md`, `error-codes.md`, `graph-constraints.md`) do not define a retry strategy, timeout-extension logic, or inconclusive-outcome code. The current resolver raises one of two codes (LO_LANDMARK_UNSOURCED or SPINE_SOURCE_REF_UNRESOLVED) on failure; neither has a "retry pending" variant. Options for distinguishing transport blips from genuine failures:

1. **Bounded retry at the HTTP layer** — Retry `fetch_page_text` on `urllib.error.URLError` (transport errors like ECONNRESET, timeout, DNS failure) up to N times with exponential backoff; still fail hard on `urllib.error.HTTPError` (4xx/5xx) or missing source_title.
   - Requires: no new dependency (native `urllib` + time.sleep or asyncio).
   - Produces: same error codes; test behavior is deterministic if retries succeed, hard failure if not.
   - Does not add identifier (I5) or weaken I15.

2. **Explicit inconclusive outcome** — On transport error, raise a new (or reused) error code indicating "could not verify due to network; treating as passed for now". Requires a contract change to register a new code or a ruling to use an existing recoverable code.
   - Requires: new error code registration (contract bump) or reuse of TIER_UNAVAILABLE / TELEM_ENDPOINT_UNREACHABLE.
   - Produces: an explicit distinction in error messages and test behavior.
   - May weaken I15 interpretation (a landmark "could not verify" is not the same as "verified").

3. **xfail/skip with explicit reason** — Mark network-sensitive test cases as `@pytest.mark.xfail(network_error)` or skip them with a clear reason message when a transport error is caught.
   - Requires: no new dependency; pytest marker only.
   - Produces: test reports showing "X passed, Y xfailed" and a clear reason in the logs.
   - Does not change production code (resolver keeps same behavior).
   - But CI visibility (CI must read xfail as "expected" rather than "concern") and owner acceptance of "network errors are expected" need confirmation.

**Recommendation:** Option 1 (bounded retry at HTTP layer, no new dependency, hard fail on 4xx/5xx) aligns with the EPIC 01 recommendation ("retry a transport-level failure a bounded number of times") and does not weaken I15 or the contract. An implementation might:
- Retry up to 3 times on `urllib.error.URLError` with a 1–2s exponential backoff per attempt.
- Still fail hard on `urllib.error.HTTPError` (4xx/5xx) or missing source_title.
- Keep error codes unchanged (LO_LANDMARK_UNSOURCED for any eventual failure).
- Add a note to the resolver docstring recording the retry behavior for future maintainers.

However, this is a technical decision, not a Q5 (no owner decision is required; the contracts allow it). The implementer chooses the approach that fits the observed failure pattern and the project's tolerance for network-transient failures in the gate.

### Test coverage for retry behavior

Once a retry pattern is in place, tests should cover:
- Successful fetch on first attempt (existing tests already cover this).
- Successful fetch after N-1 retries on transport error.
- Hard failure on 4xx/5xx after retries (existing tests already cover this).
- Timeout respected per attempt (stress-test or mock the timeout).
- No retry on semantic failures (missing source_title, unregistered source) — fail immediately.

Source files to verify after changes:
- `pipeline/tests/test_verify_landmarks_contract.py` (contract suite)
- `pipeline/tests/test_demo_bundle.py` (landmark integration, lines 102–122)

## §H. Quote audit

**All quotes re-read and byte-verified against source files opened in this run:**

1. `docs/epics/epic-02-core-behaviour.md:310-316` ✓ — "Live-landmark-test transport-retry fix..."
2. `docs/audits/epic-01-acceptance.md:123-139` ✓ — "One `pytest` run reported..." through "...never be mocked or skipped into vacuity..."
3. `contracts/content-policy.md:39-45` ✓ — "Real, named, verifiable..." through "...never invented, never 'hypothetical'."
4. `contracts/error-codes.json:33, 42` ✓ — LO_LANDMARK_UNSOURCED and SPINE_SOURCE_REF_UNRESOLVED codes present and recoverable
5. `pipeline/pyproject.toml:40-44` ✓ — pytest markers section; network marker for I15, never to skip
6. `pipeline/tests/test_verify_landmarks_contract.py:43-75` ✓ — anti-vacuity guard; no mock/skip/monkeypatch tokens
7. `scripts/gate.sh:23` ✓ — `uv run pytest -q` with no -m flag
8. `pipeline/src/mathmath_pipeline/verify/landmarks.py:19, 31-45` ✓ — timeout, fetch logic, no retry, URLError propagates
9. `docs/tech-stack.md:§1` ✓ — no retry libraries pinned

**Audit result:** All 9 blocks re-read; 0 corrected. All quotes byte-match their sources.
