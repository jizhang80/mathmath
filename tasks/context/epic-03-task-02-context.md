# Task 3.2 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: contract-error-codes-snapshot-refused
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- Epic: 03
- Task: 02 (sub-EPIC 03a)
- Slug: `contract-error-codes-snapshot-refused`
- Summary: Registry and domain-doc registration of `PLATFORM_SNAPSHOT_REFUSED`, a new recoverable=false student error code raised when the offline snapshot fails load-time validation (manifest, format major, L0) with no other bundle available. Additive registration, no version bump. This task lands contracts only; the `CoreError` case is added by task 03.3.
- Invariants in play: I1 (CAS decides step correctness, not models), I5 (no PII; all telemetry fields constrained), I6 (nodes carry paraphrase + codes, no Ministry text), I14 (Core imports Foundation only; L0 and layout in Core once), I15 (landmarks real with resolving `source_url`)

## §B. Applicable contract rules (verbatim)

### contracts/error-codes.md — § Rules (header note + rules)

> **Contract version:** v1.0.0 · Source: every `## Errors produced` section in `docs/domains/*.md`
>
> The single registry of every error code. **`error-codes.json` is normative**; this file states the rules.
> Codes are stable strings `<DOMAINPREFIX>_<REASON>`; a change is a versioned change. Additive registration
> (a new code with its domain doc row) is allowed without a version bump.

Source: `contracts/error-codes.md:1-7`

Binds this task: The task must register the code additively with no version bump; `error-codes.json` is the registry of record.

### contracts/error-codes.md — § Rules (operative rules)

> - Prefixes are fixed per domain: `MAP`, `EXP`, `DIAG`, `GRAPH`, `LO`, `SPINE`, `GEN`, `PLATFORM`, `TELEM`,
>   `TIER`, `VERIFY` (M5). A code appears in exactly one domain doc and in the registry.
> - Every code declares `recoverable` (bool), `surface ∈ {internal, student, owner}` and `user_text` — the
>   student-facing sentence when `surface = student`, else `null`. Student text names a node or a situation,
>   never the student, and never contains a score (content-policy voice).
> - `Core` defines `enum CoreError: String` mirroring the `GRAPH`, `EXP`, `MAP` (validation) and `DIAG`
>   codes; the App and the pipeline each map their own. A code raised in code but absent from the registry
>   fails the round-trip test.
> - Internal codes never reach a student surface; a `student` code always has a next action in its text.
> - `GRAPH_L0_FAILED` carries the failing rule ids from `graph-constraints.md` in `details`.

Source: `contracts/error-codes.md:9-19`

Binds this task: Every new code must declare all four fields and conform to surface/user_text invariants; the field set assertion in the round-trip test line 148 will catch omissions.

### contracts/error-codes.md — § Enforcement (wired)

> - `pipeline/tests/test_contracts.py`: the set of codes in `error-codes.json` equals the set of
>   backticked `UPPER_SNAKE` codes across `docs/domains/*.md`; every entry has the required fields; prefixes
>   match the domain. EPIC-time: `CoreError` cases ⊆ registry (Swift test).

Source: `contracts/error-codes.md:21-24`

Binds this task: The test at line 143–159 must pass after this task lands; it verifies registry ↔ domain-doc round-trip equivalence and the field assertion at line 151 verifies the surface/user_text constraint.

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/platform.md — § W1 — Launch (current and ruling amendment)

Current (before amendment):
> **Pre:** app start. **Steps:** 1. Load the active `ContentBundle` (installed hosted set, else the offline
> snapshot); verify hashes; a failure falls back to the snapshot (`PLATFORM_BUNDLE_INTEGRITY_FAILED`).
> 2. Read `StudentState` (W3); none → a fresh default. 3. Collect `CapabilityFacts`. 4. Hand control to
> **map** W1. Tier 0. **Post:** `platform.launched` emitted.

Source: `docs/domains/platform.md:50-54`

Amendment (Q-C ruling):
> Also amend platform § W1 step 1 by appending: "If the snapshot itself fails, `PLATFORM_SNAPSHOT_REFUSED` and no
> map is rendered."

Source: `tasks/arbitration/arbiter-03-predispatch.md:164-165`

Binds this task: Step 1 must be amended to add the sentence about snapshot failure; the W1 section is also the place where the new error is first mentioned to the reader before the Errors produced table.

### docs/domains/platform.md — § Errors produced (full table with new entry to add)

Current (excerpt):
> | Code | When | User sees | Recoverable |
> |---|---|---|---|
> | `PLATFORM_BUNDLE_FETCH_FAILED` | A hosted bundle could not be fetched | "Could not refresh content; still using the installed version" | Yes |
> | `PLATFORM_BUNDLE_INTEGRITY_FAILED` | Hash mismatch or a bundle failing load-time validation (`MAP_LAYOUT_MISSING`, I8) | Same message; the snapshot or installed set stays | Yes, never tolerated |
> | `PLATFORM_STATE_WRITE_FAILED` | The JSON write failed | Banner from the calling domain | Yes — retried |
> | `PLATFORM_STATE_UNREADABLE` | Migration failed | "Earlier progress could not be read; it has been kept" | Yes — file retained |
> | `PLATFORM_SYNC_UNAVAILABLE` | Not signed in, or iCloud errored | Nothing (silent); status in Settings | Yes |

Source: `docs/domains/platform.md:95-103`

New row to add (Q-C ruling):
> | `PLATFORM_SNAPSHOT_REFUSED` | The offline snapshot shipped in the build fails a load-time check (manifest completeness, format major, L0) and no other set is installed | "The map could not be loaded from this copy of the app; reinstall the app to fix it." No map is rendered | No — needs a new build |

Source: `tasks/arbitration/arbiter-03-predispatch.md:160-162`

Binds this task: The new row must be inserted immediately after the `PLATFORM_BUNDLE_INTEGRITY_FAILED` row; the "User sees" column text matches exactly the `user_text` in the registry entry.

## §D. Prior task outputs this task depends on

None — no prior outputs consumed. Task 03.2 is a contract-registration task with no external dependencies; task 03.3 consumes the registry entry this task produces.

## §E. Negative facts (confirmed ABSENT)

- No `PLATFORM_SNAPSHOT_REFUSED` entry currently in `contracts/error-codes.json`. Grep query: `grep -i "PLATFORM_SNAPSHOT_REFUSED" /Users/jimmyz/Dev/mathmath/contracts/error-codes.json` returned no match.
- No `CoreError` case for `platformSnapshotRefused` in the codebase. Grep query: `grep -r "platformSnapshotRefused" /Users/jimmyz/Dev/mathmath/Packages/` returned no match (the case is added by task 03.3).
- No test function asserting the new entry exists. The existing `test_error_registry_matches_domain_docs` at line 143–159 will validate round-trip equality; no additional test is required for this task.
- No task spec file exists yet for epic-03-task-02. Glob query: `tasks/epic-03-task-02-*.md` empty.

## §F. File scope

- MODIFY `contracts/error-codes.json` (current: lines 48–49, the end of PLATFORM entries) — add one new entry after `PLATFORM_BUNDLE_INTEGRITY_FAILED` at line 49, before `PLATFORM_STATE_WRITE_FAILED` at line 50.
- MODIFY `docs/domains/platform.md` (current: lines 50–54 for W1; lines 95–103 for Errors produced) — append W1 amendment sentence; insert new error row.

## §G. Stack constraints relevant here

- Boundary validation: `contracts/error-codes.json` structure. The new entry must follow the key order: `"code"`, `"recoverable"`, `"surface"`, `"user_text"` (order verified by inspection of existing entries at lines 9–52).
- Error codes to use: `PLATFORM_SNAPSHOT_REFUSED` — the exact code string per the ruling. Source: `tasks/arbitration/arbiter-03-predispatch.md:146`.
- Registry entry field values (exact):
  - `"code"`: `"PLATFORM_SNAPSHOT_REFUSED"`
  - `"recoverable"`: `false` (not `"false"`; boolean)
  - `"surface"`: `"student"` (string)
  - `"user_text"`: `"The map could not be loaded from this copy of the app; reinstall the app to fix it."` (exact string, no edits)
  
  Source: `tasks/arbitration/arbiter-03-predispatch.md:145-147`

- No version bump to `contracts/error-codes.md` header (it stays v1.0.0). Source: `tasks/arbitration/arbiter-03-predispatch.md:155-156` citing `contracts/error-codes.md:6-7`.
- Test coverage: `pipeline/tests/test_contracts.py::test_error_registry_matches_domain_docs` (lines 143–159) must pass. No new test is needed; this task's changes exercise the round-trip check at line 159.
- Tooling: None beyond what is named in `docs/tech-stack.md`. JSON editing is manual; no JSON linting tool is pinned.
