# Contract: Error codes registry

**Contract version:** v1.0.0 · Source: every `## Errors produced` section in `docs/domains/*.md`

> The single registry of every error code. **`error-codes.json` is normative**; this file states the rules.
> Codes are stable strings `<DOMAINPREFIX>_<REASON>`; a change is a versioned change. Additive registration
> (a new code with its domain doc row) is allowed without a version bump.

## Rules
- Prefixes are fixed per domain: `MAP`, `EXP`, `DIAG`, `GRAPH`, `LO`, `SPINE`, `GEN`, `PLATFORM`, `TELEM`,
  `TIER`, `VERIFY` (M5). A code appears in exactly one domain doc and in the registry.
- Every code declares `recoverable` (bool), `surface ∈ {internal, student, owner}` and `user_text` — the
  student-facing sentence when `surface = student`, else `null`. Student text names a node or a situation,
  never the student, and never contains a score (content-policy voice).
- `Core` defines `enum CoreError: String` mirroring the `GRAPH`, `EXP`, `MAP` (validation) and `DIAG`
  codes; the App and the pipeline each map their own. A code raised in code but absent from the registry
  fails the round-trip test.
- Internal codes never reach a student surface; a `student` code always has a next action in its text.
- `GRAPH_L0_FAILED` carries the failing rule ids from `graph-constraints.md` in `details`.

## Enforcement (wired)
- `pipeline/tests/test_contracts.py`: the set of codes in `error-codes.json` equals the set of
  backticked `UPPER_SNAKE` codes across `docs/domains/*.md`; every entry has the required fields; prefixes
  match the domain. EPIC-time: `CoreError` cases ⊆ registry (Swift test).
