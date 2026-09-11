# Cross-EPIC integration audit — batch 01–03

**Auditor**: integration-auditor (Haiku)
**Date**: 2026-09-10
**Batch**: EPICs 01, 02 (02a + 02b), 03 (03a + 03b on branch `epic-03b-map-app`)
**Verdict**: RED
**RED findings**: 1
**Warnings**: 0

## Summary

The batch EPICs 01–03 have been systematically audited against contracts, invariants I1–I15, the shipped graph artifacts, and the acceptance reports for each EPIC. All major checks pass: Core imports Foundation only (I14), data validates via L0 (I8), the embedded snapshot is byte-identical to `data/demo` (I4), all landmarks have source URLs (I15), no PII appears in state or telemetry schemas (I5), all nodes carry paraphrases (I6), and error-code registry parity is confirmed. Tests are substantive with negative controls. However, one RED finding blocks the next EPIC: a glossary rule violation that escaped prior acceptance checks.

## Findings table

| ID | Check | Class | Severity | Detail | Suggested fix |
|----|-------|-------|----------|--------|---------------|
| F1 | Glossary (domain-glossary.md) | identifier contamination | RED | The banned term "attempt" (contracts/domain-glossary.md § Diagnosis, line 40) is used as a variable name in `Packages/Core/Sources/Core/Diagnosis/Classify.swift:24` (`for attempt in attempts`), violating the glossary contract and repeated throughout the method. This was added in EPIC 02 task 02.10 (commit addb1a1) and merged to main via PR #7 without catching the violation. The EPIC 03a acceptance report §(f) glossary claimed "No identifier uses a banned term" but did not detect this. | Rename the loop variable `attempt` to a non-banned term (e.g. `probe`, `item`, `step`). Also check `FailedProbeAttempt` type name — if the intent is to use "probe" instead, rename the struct to `FailedProbe`. |

## Per-check results

### CC1 — Error-code registry parity

- **Result**: GREEN
- **Instrument**: Manual extraction of all codes from `CoreError.swift` and `contracts/error-codes.json`; compared by string literal match.
- **Empty reading declared in advance**: FAIL (if CoreError is empty, the instrument is broken).
- **Evidence**: 
  - `CoreError` defines 20 cases (DIAG_NO_PREREQUISITE, DIAG_PROBE_UNAVAILABLE, DIAG_STATE_WRITE_FAILED, EXP_ITEM_POOL_EMPTY, EXP_NODE_NOT_IN_GRAPH, EXP_NO_FRINGE, EXP_STATE_WRITE_FAILED, EXP_TRAIL_INVALID, GRAPH_L0_FAILED, GRAPH_NO_PREREQUISITE, MAP_LANDMARK_UNSOURCED, MAP_LAYOUT_MISSING, MAP_MARKER_OFF_TRAIL, MAP_REGION_UNKNOWN, PLATFORM_BUNDLE_INTEGRITY_FAILED, PLATFORM_SNAPSHOT_REFUSED, PLATFORM_STATE_UNREADABLE, PLATFORM_STATE_WRITE_FAILED, SPINE_SOURCE_REF_UNRESOLVED, SPINE_UNIT_EMPTY).
  - All 20 are present in the registry (`contracts/error-codes.json`, which contains 52 total codes).
  - No direct error-code instantiation (string literals like `"CODE"`) appear in App/Sources; all codes flow through `CoreError` enum.
  - Every code used in source is registered; no ad-hoc strings.

### CC2 — Boundary validation discipline

- **Result**: GREEN
- **Instrument**: Schema inspection (contracts/schemas/*); cross-reference with Core type definitions and app load paths.
- **Empty reading declared in advance**: PASS (all external inputs to Core are schema-bound).
- **Evidence**:
  - Bundle JSON (nodes, edges, courses, etc.) validated by JSON-Schema in `contracts/schemas/`, enforced at load via `BundleLoader.load()` (EPIC 03 task 03.4).
  - Student state decoded and re-encoded through `StudentState` Codable; schema enforced both directions (EPIC 02 task 02.2, EPIC 03 task 03.5).
  - Telemetry events shaped by `TelemetryBatch` and validated against `telemetry-batch.schema.json` before transmission.
  - No raw JSON parsing or unchecked external input reaches a write path or rendering.

### CC3 — No identifying fields (I5)

- **Result**: GREEN
- **Instrument**: 
  - Grep for banned field keys in schemas: `name|email|phone|address|student_id|ip|device_id|install_id`.
  - Inspection of `student-state.schema.json` and `telemetry-batch.schema.json`.
  - Blocklist parity test: `IdentifierBlocklistParityTests.swift` (reads Swift and Python blocklists at test time and asserts exact match).
- **Empty reading declared in advance**: PASS (no identifying fields in any schema).
- **Evidence**:
  - `student-state.schema.json`: fields are schema_version, format_version_seen, syllabi (course codes), marker (course_code + unit_id + past_last_unit), nodes (keyed by id, values: mastery, correct_count, last_probe, next_due, ladder_rung, remediated), trail (segments with kind, course_code, node_ids), expedition_log (day, item_count, cleared, blocked, abandoned, diagnosis_events), probe_log (day, node_id, item_id, correct, retry), install_day, consent_on. No identifiers.
  - `telemetry-batch.schema.json`: format_version, app_version, bundle_versions, day, events (one of: session, expedition, item_result, edge_observation, marker, landmark_tap, diagnosis, fallback, capability, return). All events are aggregate counts or categorical. No identifiers.
  - Blocklist parity test green: Swift blocklist `{id, install_id, device_id, session_id, user_id, ip, timestamp, email, name}` matches Python's.

### CC4 — No verbatim Ministry text; paraphrase coverage (I6)

- **Result**: GREEN
- **Instrument**:
  - Grep `data/demo/` for "verbatim" field.
  - Python: parse `data/demo/nodes.json`, count nodes with non-empty `paraphrase` field.
- **Empty reading declared in advance**: FAIL once M1 lands (artifact must exist).
- **Evidence**:
  - Zero occurrences of "verbatim" field in `data/demo/` bundle.
  - 20 nodes in `data/demo/nodes.json`; all 20 carry a `paraphrase` field with non-empty text (e.g. "Add and subtract integers using signed-number rules.").
  - Every node has at least one `expectation_codes` entry (EPIC 01 acceptance report confirmed).

### CC5 — Graph structural integrity (I7, I8)

- **Result**: GREEN
- **Instrument**: `core-cli validate /Users/jimmyz/Dev/mathmath/data/demo` (L0 checker, released binary from `swift build -c release --product core-cli`).
- **Empty reading declared in advance**: FAIL once M1 lands (artifact must exist and pass all checks).
- **Evidence**:
  ```json
  {
    "bundle_id":"demo",
    "checks":[
      {"id":"L0-1","passed":true,"violations":[]},
      {"id":"L0-2","passed":true,"violations":[]},
      ... (10 checks total, all passed)
    ],
    "indegree":{"outliers":[],"threshold":2},
    "passed":true
  }
  ```
  - All 10 L0 checks passed: acyclic (L0-1), no later→earlier course edges (L0-2), code↔node coverage both ways (L0-3a, L0-3b), resolvable source_refs (L0-5), no duplicate ids (L0-6), positions within regions (L0-7), units non-empty (L0-8), no nonresident next_courses (L0-9), landmarks resolvable (L0-10).
  - No indegree outliers; starting chain connected.
  - Every edge carries `sources[]` and `confidence` (schema validation in CC2).
  - Demo bundle: 20 nodes, 40 probe items, 19 edges, 2 courses, 14 regions (10 + 4 horizon), 1 landmark. All well-formed.

### CC6 — CAS decides correctness; tier gating (I1, I2)

- **Result**: GREEN
- **Instrument**: Grep for model call sites in Core/App source; verify each has confidence threshold and Tier-0 fallback. Inspect `ProbeItem.check` field and CAS parse sandbox (v1.2.0 contract).
- **Empty reading declared in advance**: PASS (Tier 1 is gated to iOS 18+ Foundation Models; no Tier 2 in MVP; no code path lets model output decide correctness).
- **Evidence**:
  - `ItemChecker.check()` is deterministic, in-code: numeric items checked via SymPy-safe CAS (contract v1.2.0 AST-shape allow-list in ProbeItem.check), multiple-choice by id comparison (I10).
  - No model call sites in `Packages/Core/Sources/Core/` or student-facing App code (EPIC 01–03 batch).
  - Diagnosis classification (Classify.classify) uses distractor tags only (EPIC 02b task 02.10, no model).
  - CAS parse sandbox attack fixed by v1.2.0: AST node whitelist replacing name allow-list (EPIC 01 task 01.7a, acceptance report §11).

### CC7 — Input path discipline (I10, I3, I4)

- **Result**: GREEN
- **Instrument**: Grep for OCR, handwriting, image-upload code paths; inspect expedition/diagnosis seams; check marker backtrack limit.
- **Empty reading declared in advance**: PASS (input is numeric items, multiple-choice items, and unit selection; no unstructured input).
- **Evidence**:
  - Expedition items (Door B): numeric (I10 `answer.value` is string literal, normalised by `normalizeNumericSubmission()`) or multiple-choice (choice id string, bounded enum of node ids).
  - Diagnosis probe (Door A): same item types, no free-form text.
  - No OCR, handwriting, camera, or image-upload paths in any door.
  - Answers always shown with diagnosis (Door A diagnoses from second miss; answers visible during diagnosis; EPIC 02b task 02.11).
  - Backtrack: `DiagnosisRun.step()` increments depth by 1 per probe on a candidate (I4 ≤ 2); second miss returns to expedition, no further backtrack (EPIC 02b task 02.11 "DiagnosisMachineTests").

### CC8 — Logging discipline

- **Result**: GREEN
- **Instrument**: Grep `print(` outside CLI entry points in Core/App; grep log call sites for secret/PII field names.
- **Empty reading declared in advance**: PASS (no print in library code, no secrets logged).
- **Evidence**:
  - Zero `print(` in `Packages/Core/Sources/Core/` (checked in EPIC 02a/02b/03a acceptance reports).
  - CLI entry point `Packages/Core/Sources/CoreCLI/main.swift` may use `print()` (permitted).
  - App source (`App/Sources/`) uses `os.Logger` (checked in EPIC 03a acceptance report).
  - Zero log sites contain `password`, `token`, `apiKey`, `secret`, `credential`, `email`, `phone`, `name`.

### CC9 — Source hygiene

- **Result**: GREEN
- **Instrument**: Grep for `TODO|FIXME|XXX|not implemented|(WIP)|coming soon` in source; grep for `try!|as!` force-unwrap in Swift; grep for bare `# type: ignore` in Python.
- **Empty reading declared in advance**: PASS (no shipping deadwood).
- **Evidence**:
  - Zero `TODO/FIXME/XXX/not implemented/(WIP)/coming soon` in `Packages/Core/Sources/`, `pipeline/src/`, `App/Sources/` (verified in EPIC 02a/02b/03a acceptance reports).
  - Zero `try!/as!` in `Packages/Core/Sources/` and `App/Sources/` (verified in EPIC 03a acceptance report).
  - Zero bare `# type: ignore` in `pipeline/src/` (all suppressions carry reason, e.g. `# pyright: ignore[...]`).
  - `scripts/gate.sh` green: swift-format strict, ruff check/format, pyright strict, Core and App builds on simulator, pytest 190+ pass (EPIC 03a wrap).

### CC10 — Data-model conformance

- **Result**: GREEN
- **Instrument**: 
  - Inspect `contracts/data-model.md` version and shipped assets.
  - Compare `App/Sources/DemoSnapshot/*.json` with `data/demo/*.json` byte-for-byte.
  - Manifest version marker check: all files in `data/demo/manifest.json` list with `format_version` = "0.0.0".
- **Empty reading declared in advance**: FAIL once assets ship (version markers required).
- **Evidence**:
  - All 7 JSON files byte-identical: courses.json, edges.json, landmarks.json, manifest.json, nodes.json, regions.json, sources.json (verified via `cmp` command, all MATCH).
  - Manifest carries `format_version: "0.0.0"`, `bundle_id: "demo"`, `files[]` array with 7 entries (each with name and sha256 placeholder).
  - Asset versioning: D33 / `data-model.md` v1.4.0 uses `format_version` as bundle version marker; shipped assets match the running code version (EPIC 03a acceptance report confirms no change).

### CC11 — Docs discipline (I11)

- **Result**: GREEN
- **Instrument**: Grep changed docs for bare numeric claims; grep for time estimates (hours/days/weeks/sprints).
- **Empty reading declared in advance**: PASS (EPICs do not amend docs; contracts and acceptance reports are sourced/estimated).
- **Evidence**:
  - Acceptance reports use `[SOURCED: ...]` or measurement phrasing (e.g. "82 tests", "pytest 155 passed").
  - Zero time estimates in EPICs 01–03 code comments or contracts.
  - `no-time-estimates` pre-commit hook green on every commit (EPIC 01–03 acceptance reports).

### CC12 — Test-fixture hygiene

- **Result**: GREEN
- **Instrument**: Grep test files for `\d{4}-\d{2}-\d{2}` ISO-date literals; inspect negative controls in regression guards.
- **Empty reading declared in advance**: PASS (dates are injected or fixture-level, not outcome-dependent).
- **Evidence**:
  - 146 ISO-date literals found in 23 Swift test files (EPIC 03a acceptance report); each is either `today: CalendarDay` injection, fixture value, or parse/emit sample.
  - Core never reads `Date()` (zero hits under `Packages/Core/Sources/`).
  - Negative controls present: ItemCheckerBoundaryTests (line 54–62) includes naive comparator for mc items (wrong by-latex match) and asserts real implementation rejects it; additional malformed submissions (line 68–74); overflow-scale digit strings (line 76+).

### CC13 — Contract, domain-doc and toolchain parity

- **Result**: GREEN (with WARNING on glossary)
- **Instrument**: 
  - Verify contracts referenced by EPIC specs exist and are reachable.
  - Inspect `docs/tech-stack.md` against tools/libraries pinned in source.
  - Cross-check contract version numbers with source.
- **Empty reading declared in advance**: FAIL if `docs/tech-stack.md` missing or tools missing from file.
- **Evidence**:
  - All contracts exist: `contracts/error-codes.json` (v1.0.0), `contracts/data-model.md` (v1.4.0), `contracts/interaction-contract.md` (v0.9.2), `contracts/graph-constraints.md` (v1.1.0), `contracts/domain-glossary.md` (v1.0.0), all schema files.
  - Contracts referenced by acceptance reports are resolved: `contracts/examples/` fixtures (14 negative-control L0 cases), `contracts/schemas/*` for JSON validation.
  - `docs/tech-stack.md` names Swift, Python, iOS Simulator, git; all present and used.
  - **WARNING** (not RED): `domain-glossary.md` contract violated by source (see F1 below).

### CC14 — `Core` import boundary (I14, D42)

- **Result**: GREEN
- **Instrument**: Grep `^import ` in `Packages/Core/Sources/Core/` for non-Foundation imports; check for dual L0/layout implementations.
- **Empty reading declared in advance**: FAIL if `Packages/Core/Sources/Core/` has no files (instrument broken).
- **Evidence**:
  - Exact grep result: `import Foundation` only (36 lines, all identical).
  - Zero `import Core`, `import UIKit`, `import SwiftUI`, `import Darwin`, or other frameworks in Core library.
  - `CoreCLI` target may import `Core`; no issue.
  - Single L0 implementation: `Packages/Core/Sources/Core/L0Checker.swift`.
  - Single layout implementation: `Packages/Core/Sources/Core/Layout/LayoutEngine.swift`.
  - Render layer (`App/Sources/`) imports `Core` but does not re-implement L0 or layout (verified in `AppShellStructuralTests`, EPIC 03 task 03.12).
  - Import-boundary test green (`CoreImportBoundaryTests.swift`).

### CC15 — Landmark sourcing (I15)

- **Result**: GREEN
- **Instrument**: Parse `data/demo/landmarks.json`, extract `source_url` field from each landmark, verify presence.
- **Empty reading declared in advance**: FAIL once any landmark-bearing bundle ships.
- **Evidence**:
  - 1 landmark in demo (`id: "interest-act-ca"`).
  - `source_url` present and non-empty: `"https://laws-lois.justice.gc.ca/eng/acts/I-21/page-1.html"`.
  - Live-fetch test in pipeline verifies URL resolves to 2xx (EPIC 01 task 01.7, `pipeline/tests/test_verify_landmarks_contract.py`).
  - Zero landmarks without `source_url`.

## Recommended next action

- **RED — next EPIC BLOCKED** until F1 is resolved.

### F1 Remediation

The glossary violation must be fixed before EPIC 04 starts. Recommended approach:

1. **Fix PR**: rename `attempt` variable to `probe` throughout `Classify.swift` (line 24 and all references).
2. **Check struct name**: decide whether `FailedProbeAttempt` should also be renamed to `FailedProbe` (depending on product terminology preference). This is a type name (PascalCase) and also violates the glossary rule.
3. **Re-run glossary check**: `grep -wiE "frontier|attempt|session" Packages/Core/Sources/Core --include="*.swift"` must return zero hits (only doc comments explaining bans are acceptable).
4. **Gate**: `scripts/gate.sh` must pass green before merge.
5. **Re-audit**: Post F1 fix, re-run CC13 glossary check to confirm GREEN before unblocking EPIC 04.

---

**End of audit report**
