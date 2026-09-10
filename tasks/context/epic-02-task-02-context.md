# Task 02.2 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: contract-data-model-remediated-flag
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- Epic: 02
- Task: 02.2
- Slug: contract-data-model-remediated-flag
- **Status:** Conditional on arbiter ruling Q-A; Q-F is included in the same task per the ruling's summary table.
- **Summary:** Apply arbiter rulings Q-A and Q-F: add optional boolean `remediated` to `NodeState` and optional boolean `past_last_unit` to `Marker`, update `data-model.md` to v1.3.0, update schema `student-state.schema.json` to `schema_version: 2`, implement identity migration (v1 → v2 is no-op), and ripple changes through `Core` types and all relevant examples and tests.
- **Invariants in play:**
  - I5 (CLAUDE.md): "No field may name a person, device, account, install or session"; these fields are booleans about nodes and markers, naming nothing but state facts.
  - I14 (CLAUDE.md): "`Core` is renderer-free and single-source"; the types are `Codable` only, no logic.

## §B. Applicable contract rules (verbatim)

### contracts/README.md — Lock-first rule

> A change to a locked contract is a **versioned** change: bump `Contract version`, ripple to every conforming EPIC, and flag the commit scope (`contract(<name>)`) so the ripple is auditable.

Source: `contracts/README.md:38-44`
Binds this task: This task is the data-model contract bump landing the arbiter rulings; the commit scope is `contract(data-model)` and the version bumps from v1.2.0 to v1.3.0.

### arbiter-02-predispatch.md — Q-A ruling (remediated flag)

> **Normative text for 02.2: `contracts/data-model.md` § StudentState (v1.3.0).** Replace the `nodes` clause with:
> > `nodes {node_id → {mastery ∈ {fog, cleared, blocked}, correct_count, last_probe?, next_due?, ladder_rung, remediated?}}`
>
> Then add this paragraph after the field list:
> > `remediated` (boolean, optional; absent = false) records that a diagnosis event confirmed this node (probe outcome `fail`) and showed its one remediation piece (diagnosis W4). It is written `true` only by that step and only on a node whose `mastery` is `blocked`; it is removed whenever the node becomes `cleared`. A node blocked by `capped` or by a second miss after the run's Door A event was spent does not carry it. It is a fact about a node, never about a person, device, install or session (I5).
> >
> > `schema_version` is **2**. Migration 1 → 2 is the identity: a version-1 document is a valid version-2 document with every `remediated` absent.
>
> - **Schema.** Add `"remediated": {"type": "boolean"}` to the node-entry `properties`. It is not in `required`, and `additionalProperties: false` stays.
> - **Example.** In `contracts/examples/student-state.json`, set `schema_version` to 2 and add one entry `{"mastery": "blocked", "correct_count": 0, "ladder_rung": 0, "remediated": true}` so the round-trip test exercises the key.
> - **Type.** Add `remediated: Bool?` to `NodeState`. It encodes as absent, never `null` (§ Nulls, enums, unknowns).

Source: `tasks/arbitration/arbiter-02-predispatch.md:45-60`
Binds this task: The normative text specifies exactly what the contract amendment must state, how the schema must be amended, what the example must carry, and the Swift type signature.

### arbiter-02-predispatch.md — Q-F ruling (past_last_unit flag)

> **Ruling.** Add an optional boolean `past_last_unit` on `marker`. It lands with Q-A in **02.2** (data-model v1.3.0, schema, example, `Marker` type) and in **02.1** (interaction-contract text).
>
> **Normative text for 02.2: `contracts/data-model.md` § StudentState.** Replace the `marker` clause with `marker {course_code, unit_id, past_last_unit?}`, then add:
> > `past_last_unit` (boolean, optional; absent = false): `true` means the marker has been moved past the course's last unit (v2.7 §4). `unit_id` then names the course's last unit at the time it was set and must still name a unit of the course.
>
> Schema: add `"past_last_unit": {"type": "boolean"}` to `marker.properties`. It is not required.

Source: `tasks/arbitration/arbiter-02-predispatch.md:181-196`
Binds this task: Q-F lands in 02.2 alongside Q-A; both are in the same data-model version and schema version.

### contracts/data-model.md § Nulls, enums, unknowns

> Optional means the key is **absent**, never `null`. Enums are closed; an unknown value fails decode.

Source: `contracts/data-model.md:42`
Binds this task: Both new optional fields must encode/decode as absent keys, never `null` values; the `Codable` implementation must use `encodeIfPresent` on the new fields.

### contracts/data-model.md § StudentState (current version 1.2.0)

> `schema_version`, `format_version_seen`, `syllabi[]` (course codes), `marker {course_code, unit_id}`,
> `nodes {node_id → {mastery ∈ {fog, cleared, blocked}, correct_count, last_probe?, next_due?, ladder_rung}}`,
> `trail {segments[] {kind ∈ {course, extension}, course_code?, node_ids[]}}` (derived, cached),
> `expedition_log[] {day, item_count, cleared, blocked, abandoned, diagnosis_events}`,
> `probe_log[] {day, node_id, item_id, correct, retry}`, `install_day`, `consent_on`. **No field may name a
> person, device, account, install or session** (I5); the schema's closed key set is the guard.

Source: `contracts/data-model.md:131-136`
Binds this task: The current structure is the baseline; both new optional fields extend it without adding identifiers.

## §C. Relevant domain-doc excerpts (verbatim)

### contracts/interaction-contract.md § 2 Expedition, `compose` (fringe definition)

> fringe = `{n : mastery(n) ≠ cleared ∧ ∀ p ∈ prereq(n): mastery(p) = cleared ∨ (mastery(p) = blocked ∧ remediated(p))}`

Source: `tasks/arbitration/arbiter-02-predispatch.md:32` (quoted from `contracts/interaction-contract.md`)
Binds this task: The `remediated` field exists to represent this guard condition; the type must capture it for EPIC 02's fringe logic.

## §D. Prior task outputs this task depends on

- `StudentState`, `Marker`, `NodeState`, `Mastery`, `Trail`, `TrailSegment`, `SegmentKind`, `ExpeditionLogEntry`, `ProbeLogEntry` — exported by EPIC 01, source: `Packages/Core/Sources/Core/Model/StudentState.swift:1-73` (produced by task 01.x)
- `IdentifierBlocklistParityTests`, `OptionalAbsentTests`, `DecodeRoundTripTests` — exported by EPIC 01, source: `Packages/Core/Tests/CoreTests/{IdentifierBlocklistParityTests,OptionalAbsentTests,DecodeRoundTripTests}.swift` (produced by task 01.x)
- `student-state.schema.json` (JSON Schema 2020-12) — source: `contracts/schemas/student-state.schema.json:1-219` (produced by task 01.x)
- `student-state.json` example — source: `contracts/examples/student-state.json:1-57` (produced by task 01.x)

## §E. Negative facts (confirmed ABSENT)

- No task spec `tasks/epic-02-task-02-contract-data-model-remediated-flag.md` exists yet — this is pre-dispatch; the spec will be written by the task-writer after this bundle is compiled. Source: `Glob **/epic-02-task-02* returned no match.`
- No `remediated` field in `NodeState` type. Source: `Packages/Core/Sources/Core/Model/StudentState.swift:28-34` line-by-line read shows only `mastery`, `correctCount`, `lastProbe`, `nextDue`, `ladderRung`.
- No `past_last_unit` field in `Marker` type. Source: `Packages/Core/Sources/Core/Model/StudentState.swift:23-26` shows only `courseCode`, `unitId`.
- `student-state.schema.json:schema_version` is integer, minimum 1; no version 2 reference yet. Source: `contracts/schemas/student-state.schema.json:7-10`.
- `contracts/examples/student-state.json:schema_version` is `1`. Source: `contracts/examples/student-state.json:2`.
- `contracts/data-model.md` version line reads `v1.2.0`. Source: `contracts/data-model.md:3` (no v1.3.0 text yet).
- No `IDENTIFIER_BLOCKLIST` entry for `remediated` or `past_last_unit`. Source: `Packages/Core/Tests/CoreTests/IdentifierBlocklistParityTests.swift:17-19` and `pipeline/tests/test_contracts.py:26-36` both read `["id", "install_id", "device_id", "session_id", "user_id", "ip", "timestamp", "email", "name"]` — these new field names are not on the blocklist, and neither is a field name that requires blocking.

## §F. File scope

Files this task may create or touch. Mark each create / modify and cite existence for modifies.

- MODIFY `contracts/data-model.md:1-145` — version line at line 3; § StudentState at lines 130-136 replaced with new text including v1.3.0 and the two new fields' descriptions.
- MODIFY `contracts/schemas/student-state.schema.json:1-219` — `schema_version` still integer (no min change); `marker.properties` at lines 24-39 extended; node-entry `properties` at lines 47-79 extended; `schema_version` example updated in `required` section if affected.
- MODIFY `contracts/examples/student-state.json:1-57` — `schema_version` line 2 changed from `1` to `2`; one node entry mutated or added to carry `remediated: true`; marker object extended with `past_last_unit` if present or added.
- MODIFY `Packages/Core/Sources/Core/Model/StudentState.swift:1-73` — `Marker` struct at lines 23-26 extended with `pastLastUnit: Bool?`; `NodeState` struct at lines 28-34 extended with `remediated: Bool?`.
- MODIFY `Packages/Core/Tests/CoreTests/IdentifierBlocklistParityTests.swift:1-67` — no new entries needed (no new identifier-like fields added); parity test re-run to confirm blocklist drift detection works.
- MODIFY `Packages/Core/Tests/CoreTests/OptionalAbsentTests.swift:1-77` — add a test asserting `past_last_unit` and `remediated` are omitted (not `null`) on re-encode. Cite: the test already has `nodeStateOmitsAbsentOptionalKeys` at lines 53-76 checking `last_probe` and `next_due`; a new or extended test covers the marker and node fields added by this task.
- MODIFY `Packages/Core/Tests/CoreTests/DecodeRoundTripTests.swift:1-328` — the existing `decodeRoundTrip` test at lines 35-67 already covers `student-state.json` round-trip; no new test needed if the example is updated to carry the new fields and the assertion passes.

## §G. Stack constraints relevant here

**Boundary validation:** StudentState decode/encode over JSON; schema is JSON Schema 2020-12 (`contracts/schemas/student-state.schema.json`). Optional fields must be absent on wire, never `null`. Source: `contracts/data-model.md:42` and `docs/tech-stack.md:19`.

**Codable wire format:** `Swift 6` strict concurrency; `CoreCoding.decoder` and `CoreCoding.encoder` use `.convertFromSnakeCase`, so Swift field names are snake_case on wire. `Codable` implementation must not use explicit `CodingKeys` (that layers on top of `.convertFromSnakeCase` and breaks). Source: `Packages/Core/Sources/Core/Model/StudentState.swift:8-9` (comment explaining why no `CodingKeys`).

**Migration rule:** `schema_version` migration 1 → 2 is the identity function — every valid v1 document is a valid v2 document with both new fields absent. This is a data-model contract, not a runtime-code contract; the pipeline enforces it at the W3 step (platform domain, not this task). Source: `tasks/arbitration/arbiter-02-predispatch.md:55-56`.

**Error codes to use:** This task adds no error code; `DIAG_NO_PREREQUISITE`, `EXP_*`, etc. are EPIC 02's responsibility. Source: `contracts/error-codes.json` (no new entry needed).

**Model-calling paths:** None. This task is a pure data-model contract bump; no Tier-0, Tier-1, or Tier-2 path is involved. Source: CLAUDE.md I2 and contracts/runtime-tiers.md.

**Tooling:** Swift 6.3.3, Python 3.14, pyright strict, pytest. Source: `docs/tech-stack.md:14, 25, 29, 30`.

**Lock-first rule:** This is a LOCK-FIRST contract change (data-model in the set at `contracts/README.md:6-7`). It must land as a versioned commit with scope `contract(data-model)` before any EPIC 02 task that reads the new fields proceeds. Source: `contracts/README.md:38-44` and `docs/plans/epic-02-plan.md:87-88` ("sequentially").

---

## Quote audit (mandatory, re-verification)

1. **arbiter-02-predispatch.md § Q-A normative text (lines 45-60):** Re-read the source file; the block quotes exactly the contract text to be landed in data-model.md, the schema changes, the example changes, and the Swift type signature. ✓ Byte-match verified.

2. **arbiter-02-predispatch.md § Q-F normative text (lines 181-196):** Re-read the source file; the block quotes the exact marker amendments, schema changes, and the new `pastLastUnit` field description. ✓ Byte-match verified.

3. **contracts/data-model.md § Nulls line 42 / line 43:** Re-read; the rule is "Optional means the key is **absent**, never `null`. Enums are closed; an unknown value fails decode." ✓ Byte-match verified.

4. **contracts/data-model.md § StudentState lines 131-136:** Re-read; current version lists the node entry fields and I5 guard. The text will be replaced by the arbiter's normative text. ✓ Source verified for current state.

5. **contracts/interaction-contract.md § compose fringe (per arbiter quote):** The arbiter cites this in predispatch.md line 32; fringe definition references `remediated(p)` predicate. ✓ Rationale verified through arbiter document.

6. **contracts/README.md § Lock-first rule lines 38-44:** Re-read; the rule is "A change to a locked contract is a **versioned** change: bump `Contract version`, ripple to every conforming EPIC, and flag the commit scope (`contract(<name>)`) so the ripple is auditable." ✓ Byte-match verified.

7. **StudentState.swift current fields (lines 23-34):** Re-read; `Marker` has `courseCode`, `unitId`; `NodeState` has `mastery`, `correctCount`, `lastProbe?`, `nextDue?`, `ladderRung`. No `remediated`, no `pastLastUnit` yet. ✓ Verified.

8. **student-state.schema.json schema_version property (lines 7-10):** Re-read; type is `integer`, minimum 1. The example in the file (line 2 of the example JSON) is `1`. ✓ Verified.

9. **IdentifierBlocklistParityTests.swift blocklist (lines 17-19):** Re-read; the set is `["id", "install_id", "device_id", "session_id", "user_id", "ip", "timestamp", "email", "name"]`. Neither `remediated` nor `past_last_unit` are identifiers, so they should not be added to this list. ✓ Verified.

10. **Docs/tech-stack.md Swift version (line 14):** Re-read; "Swift 6 (language mode 6, strict concurrency `complete`)", toolchain 6.3.3. ✓ Verified.

All blocks re-read and byte-matched against source files in this run. No corrections needed.
