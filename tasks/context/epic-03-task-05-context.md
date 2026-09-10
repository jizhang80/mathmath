# Task 03.5 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: student-state-store
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- Epic: 03
- Task: 05 (sub-EPIC 03a)
- Slug: student-state-store
- Summary: `StudentStateStore` in Core, reading/writing/migrating `StudentState` to a caller-supplied URL, with atomic persistence and migration from schema v1 to v2 (identity transformation).
- Invariants in play: I1, I2, I5, I6, I14 (Foundation-only in Core); I4 (record half implicit here via state transition tests from 02.11); I8 (state coherence in graph); I12 (English, no time estimates); I13 (quality first).

## §B. Applicable contract rules (verbatim)

### contracts/data-model.md § StudentState (v1.4.0)

> `schema_version`, `format_version_seen`, `syllabi[]` (course codes), `marker {course_code, unit_id,
> past_last_unit?}`, `nodes {node_id → {mastery ∈ {fog, cleared, blocked}, correct_count, last_probe?,
> next_due?, ladder_rung, remediated?}}`, `trail {segments[] {kind ∈ {course, extension}, course_code?,
> node_ids[]}}` (derived, cached), `expedition_log[] {day, item_count, cleared, blocked, abandoned,
> diagnosis_events}`, `probe_log[] {day, node_id, item_id, correct, retry}`, `install_day`, `consent_on`.
> **No field may name a person, device, account, install or session** (I5); the schema's closed key set is the
> guard.
>
> `past_last_unit` (boolean, optional; absent = false): `true` means the marker has been moved past the
> course's last unit (v2.7 §4). `unit_id` then names the course's last unit at the time it was set and must
> still name a unit of the course.
>
> `remediated` (boolean, optional; absent = false) records that a diagnosis event confirmed this node (probe
> outcome `fail`) and showed its one remediation piece (diagnosis W4). It is written `true` only by that step
> and only on a node whose `mastery` is `blocked`; it is removed whenever the node becomes `cleared`. A node
> blocked by `capped` or by a second miss after the run's Door A event was spent does not carry it. It is a
> fact about a node, never about a person, device, install or session (I5).
>
> `schema_version` is **2**. Migration 1 → 2 is the identity: a version-1 document is a valid version-2
> document with every `remediated` absent.

Source: `contracts/data-model.md:130–151`
Binds this task: defines the `StudentState` shape the store reads, migrates, and writes; identity migration path; closed key set enforcement.

### contracts/data-model.md § Versioning

> Every bundle file carries `format_version` (semver) = `CoreInfo.dataFormatVersion`; a major bump means
> `Core` needs a migration; the app refuses a bundle whose major differs from its own.
> ...
> `StudentState.schema_version` (integer) is migrated forward only (platform W3); older files are kept.

Source: `contracts/data-model.md:24–29`
Binds this task: `schema_version` migrates forward only; older files are kept byte-for-byte; no new versions are written backward.

### contracts/data-model.md § Nulls, enums, unknowns

> Optional means the key is **absent**, never `null`. Enums are closed; an unknown value fails decode.
> Every object schema sets `additionalProperties: false` — a new field is a versioned change.

Source: `contracts/data-model.md:41–43`
Binds this task: `StudentState` decodes must reject additional properties; optional fields are absent, not null.

### contracts/schemas/student-state.schema.json — required keys and marker pattern

> ```json
> "required": [
>   "schema_version",
>   "format_version_seen",
>   "syllabi",
>   "marker",
>   "nodes",
>   "trail",
>   "expedition_log",
>   "probe_log",
>   "install_day",
>   "consent_on"
> ],
> "additionalProperties": false
> ```
>
> (marker:)
> ```json
> "marker": {
>   "type": "object",
>   "properties": {
>     "course_code": {"type": "string", "pattern": "^[A-Z]{3}[1-4][A-Z]$"},
>     "unit_id": {"type": "string", "pattern": "^[A-Z]{3}[1-4][A-Z]\\.u[1-9][0-9]*$"},
>     "past_last_unit": {"type": "boolean"}
>   },
>   "required": ["course_code", "unit_id"],
>   "additionalProperties": false
> }
> ```

Source: `contracts/schemas/student-state.schema.json:212–224` (required) and `22–42` (marker)
Binds this task: defines the schema the store enforces at decode time; `marker` is required and non-optional in Swift.

### contracts/deployment-model.md — Student state row

> | Student state | local JSON (Application Support) + iCloud (Drive container or CloudKit, chosen at M3) under Apple's identity, only when signed in (v2.5 §5) | Apple-managed |

Source: `contracts/deployment-model.md:13`
Binds this task: the store reads/writes to Application Support in the Demo; iCloud is out of scope (EPIC 10).

### docs/domains/platform.md § W3 — Read, write and migrate student state

> **Pre:** a launch (read) or a domain transition (write). **Steps:** 1. Read the local JSON; if
> `schema_version` is older, run migrations in order and keep the pre-migration file until the migrated one
> is written (`PLATFORM_STATE_UNREADABLE` if migration fails — the old file is kept, a fresh state is used,
> nothing deleted). 2. Writes are whole-document, atomic (write-then-rename). Tier 0. **Post:**
> `platform.state_migrated` on a migration; `platform.state_written` otherwise.

Source: `docs/domains/platform.md:62–67`
Binds this task: the store's read/migrate/write flow; pre-migration file retention; atomic write; event emission.

### docs/domains/platform.md § Errors produced — PLATFORM_STATE_UNREADABLE and PLATFORM_STATE_WRITE_FAILED

> | `PLATFORM_STATE_UNREADABLE` | Migration failed | "Earlier progress could not be read; it has been kept" | Yes — file retained |
> | `PLATFORM_STATE_WRITE_FAILED` | The JSON write failed | Banner from the calling domain | Yes — retried |

Source: `docs/domains/platform.md:102–103`
Binds this task: the store raises these codes; `PLATFORM_STATE_UNREADABLE` surfaces to student after Q-E precondition (no state → courseSelectionNeeded); `PLATFORM_STATE_WRITE_FAILED` is internal (surfaces through `EXP_STATE_WRITE_FAILED` or `DIAG_STATE_WRITE_FAILED` per arbiter-03 § Q-C).

### contracts/error-codes.json — PLATFORM_STATE_* and EXP_/DIAG_STATE_WRITE_FAILED

> ```json
> {"code": "PLATFORM_STATE_WRITE_FAILED", "recoverable": true, "surface": "internal", "user_text": null},
> {"code": "PLATFORM_STATE_UNREADABLE", "recoverable": true, "surface": "student", "user_text": "Earlier progress could not be read; it has been kept."},
> {"code": "EXP_STATE_WRITE_FAILED", "recoverable": true, "surface": "student", "user_text": "Your progress could not be saved just now; it will be retried."},
> {"code": "DIAG_STATE_WRITE_FAILED", "recoverable": true, "surface": "student", "user_text": "Your progress could not be saved just now; it will be retried."},
> ```

Source: `contracts/error-codes.json:50–52` (PLATFORM codes), `17` (EXP), `22` (DIAG)
Binds this task: the store throws `PLATFORM_STATE_UNREADABLE` and `PLATFORM_STATE_WRITE_FAILED`; these codes are already registered and must not be changed.

### tasks/arbitration/arbiter-03-predispatch.md § Q-E — Course selection on a fresh install

> - **Launch outcome.** The `Core` launch entry returns one of three outcomes:
>   - `ready(bundle, state, viewModel, messages)`;
>   - `courseSelectionNeeded(bundle, messages)`, when there is no state file, the file is unreadable
>     (`PLATFORM_STATE_UNREADABLE` in `messages`, file kept byte-for-byte), or no stored course resolves (Q-A
>     precision 2);
>   - `refused(code)`, the Q-C path.
> - **First state.** The course picker is the first screen for `courseSelectionNeeded`. Choosing a course calls
>   a `Core` façade function that builds the first state and persists it, then derives the view model:
>   - `schema_version` 2 and `format_version_seen` = the bundle's `format_version`;
>   - `syllabi = [course]` and `marker = defaultMarker(syllabi:bundle:)`;
>   - `trail` from `generateTrail`, `nodes` empty (every node `fog`), both logs empty;
>   - `install_day` = injected today, and `consent_on = true` (I5: telemetry "on by default").

Source: `tasks/arbitration/arbiter-03-predispatch.md:230–241`
Binds this task: no `StudentState` can exist before a course is chosen (marker is required); the store returns appropriate signals to the façade and persists only after course selection.

### tasks/arbitration/arbiter-03-predispatch.md § Q-F — The boundary, precisely

> `Core` holds (all Foundation-only, value-typed, and testable in `CoreTests` against temp directories):
> 2. **The persistence store.**
>    - Encode and decode through `CoreCoding`; the 1 → 2 identity migration.
>    - Atomic whole-document write to a caller-supplied URL.
>    - Keep the pre-migration file until the migrated one is written.
>    - Preserve an unreadable file byte-for-byte.
>    - Errors: `PLATFORM_STATE_UNREADABLE` and `PLATFORM_STATE_WRITE_FAILED` join `CoreError` additively.

Source: `tasks/arbitration/arbiter-03-predispatch.md:286–291`
Binds this task: the store lives in Core, uses `CoreCoding`, implements atomic writes and migration, handles errors, and is fully testable against temporary directories without app context.

### docs/epics/epic-03-app-map-shell.md § 3 § 3 artifact line — save-after-every-action session (Q-F)

> The persist-after-every-state-changing-action sequencing lives here too: a `Core` session type whose
> actions write to the injected URL. That way a missed write is caught by a `CoreTests` test, not left in
> untestable App code.

Source: `docs/epics/epic-03-app-map-shell.md § Q-F, "The boundary, precisely"` (line 300–302)
Binds this task: the store/session implement save-after-every-action, testable in Core; the test must catch a missed write.

### docs/epics/epic-03-app-map-shell.md § 4 AC 3 — Persistence (platform W3, Demo slice)

> - No file → `courseSelectionNeeded`; no file is written. Choosing a course yields a state with
>   `schema_version` 2, `install_day` = the injected today, `syllabi` = [course], the default marker, every
>   node absent (`fog`), and it is persisted (arbiter-03 § Q-E).
> - Write → read round-trips byte-equal through `CoreCoding`. The write is atomic: an interrupted write never
>   leaves a truncated document where the previous one was.
> - Every state-changing action of the `Core` session writes the whole document to the injected URL
>   (arbiter-03 § Q-F).
> - A version-1 file migrates to version 2 by identity. The pre-migration file is kept until the migrated
>   one is written.
> - An undecodable file, or one with a `schema_version` newer than the App → `PLATFORM_STATE_UNREADABLE`. The
>   original file is kept byte-for-byte, and launch returns `courseSelectionNeeded` with
>   `PLATFORM_STATE_UNREADABLE` in its messages. The fresh state is created when a course is chosen
>   (arbiter-03 § Q-E).
> - Every one of these passes in `Core` tests against a temporary directory. The simulator smoke (§3 artifact
>   line) shows that a fresh install writes no file, and that a seeded version-1 file migrates, validates and
>   is byte-identical after relaunch.

Source: `docs/epics/epic-03-app-map-shell.md:275–291`
Binds this task: comprehensive acceptance criteria for the store: no-file case, write/read round-trip byte-equality, atomic writes, identity migration with file retention, unreadable/newer-version handling, and testing in Core against temp directories.

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/platform.md § W3 — Read, write and migrate student state

> **Pre:** a launch (read) or a domain transition (write). **Steps:** 1. Read the local JSON; if
> `schema_version` is older, run migrations in order and keep the pre-migration file until the migrated one
> is written (`PLATFORM_STATE_UNREADABLE` if migration fails — the old file is kept, a fresh state is used,
> nothing deleted). 2. Writes are whole-document, atomic (write-then-rename). Tier 0. **Post:**
> `platform.state_migrated` on a migration; `platform.state_written` otherwise.

Source: `docs/domains/platform.md:62–67`

### docs/domains/platform.md § Errors produced

> | Code | When | User sees | Recoverable |
> |---|---|---|---|
> | `PLATFORM_STATE_WRITE_FAILED` | The JSON write failed | Banner from the calling domain | Yes — retried |
> | `PLATFORM_STATE_UNREADABLE` | Migration failed | "Earlier progress could not be read; it has been kept" | Yes — file retained |

Source: `docs/domains/platform.md:101–102`

## §D. Prior task outputs this task depends on

- `StudentState` (struct) — `public struct StudentState: Codable, Equatable { public let schemaVersion: Int; public let formatVersionSeen: String; public let syllabi: [String]; public let marker: Marker; public let nodes: [String: NodeState]; public let trail: Trail; public let expeditionLog: [ExpeditionLogEntry]; public let probeLog: [ProbeLogEntry]; public let installDay: String; public let consentOn: Bool; }` — Source: `Packages/Core/Sources/Core/Model/StudentState.swift:10–21` (produced by EPIC 02a)
- `Marker` (struct) — `public struct Marker: Codable, Equatable { public let courseCode: String; public let unitId: String; public let pastLastUnit: Bool?; }` — Source: `Packages/Core/Sources/Core/Model/StudentState.swift:23–27` (produced by EPIC 02a)
- `CoreEvent` cases `platformStateMigrated` and `platformStateWritten` — Source: `Packages/Core/Sources/Core/Events/CoreEvent.swift:34–35` (produced by EPIC 02a; these cases already exist)
- `CoreCoding` — encoder/decoder with `.convertFromSnakeCase` / `.convertToSnakeCase` and `.sortedKeys` — Source: `Packages/Core/Sources/Core/CoreCoding.swift` (produced by EPIC 01)
- `MarkerTrail.defaultMarker`, `MarkerTrail.generateTrail`, `MarkerTrail.setMarker`, `MarkerTrail.reconcileMarker`, `MarkerTrail.reconcileNodeIds` — Source: `Packages/Core/Sources/Core/State/` (produced by EPIC 02a)
- `CalendarDay` — Source: `Packages/Core/Sources/Core/Model/CalendarDay.swift` (produced by EPIC 02a)

Note: `CoreError` lacks `PLATFORM_STATE_UNREADABLE` and `PLATFORM_STATE_WRITE_FAILED` cases until task 03.3 adds them (precondition).

## §E. Negative facts (confirmed ABSENT)

- `StudentStateStore` does not exist. Source: Glob `**/StudentStateStore.swift` returned no match.
- `PLATFORM_STATE_UNREADABLE` and `PLATFORM_STATE_WRITE_FAILED` are not in `CoreError.swift` (they are already in the contracts but not yet in the Swift enum). Source: Grep `platformState|PLATFORM_STATE` in `/Users/jimmyz/Dev/mathmath/Packages/Core/Sources/Core` type swift returned no match in CoreError.swift; only the event cases exist.
- No migration code path for StudentState schema v1→v2 exists. Source: Glob `**/migration*` and Grep `schema_version` in Core sources shows references in model but no migration implementation.
- No atomic write helper exists. Source: Glob `**/atomic*` returned no match.

## §F. File scope

- CREATE `Packages/Core/Sources/Core/StateStore/StudentStateStore.swift` — Core type implementing read/migrate/write, confirmed absent (Glob `**/StudentStateStore.swift` empty).
- MODIFY `Packages/Core/Sources/Core/CoreError.swift:<line>` — add `PLATFORM_STATE_UNREADABLE` and `PLATFORM_STATE_WRITE_FAILED` cases (this is task 03.3, a precondition; note this as a dependency, not a scope item for 03.5).
- MODIFY `Packages/Core/Sources/Core/CoreCoding.swift` — no changes expected; already has the correct decoder/encoder configuration.
- MODIFY `Packages/Core/Tests/CoreTests/` — add test suite for StudentStateStore (read absent, read + migrate v1→v2, read unreadable, write atomic, write on state change, round-trip byte-equality).

## §G. Stack constraints relevant here

- **Boundary validation:** JSON decode via `CoreCoding` enforces schema; any decode failure → `PLATFORM_STATE_UNREADABLE`. Decode must use `CoreCoding.decoder` with `.convertFromSnakeCase` strategy (no explicit `CodingKeys` per `StudentState.swift` comments).
- **Storage / asset access:** reads and writes from/to caller-supplied `URL` only (no hardcoded paths). No network I/O, no iCloud in this EPIC (Demo only). File I/O via Foundation: `Data.write(to:options: .atomic)`, `FileManager.replaceItemAt`, `try? Data(contentsOf:)`.
- **Error codes to use:**
  - `PLATFORM_STATE_UNREADABLE` — raised by the store when a file is undecodable or has `schema_version` newer than the current App version (2). Source: `contracts/error-codes.json:51`.
  - `PLATFORM_STATE_WRITE_FAILED` — raised by the store when the JSON write fails. Source: `contracts/error-codes.json:50`.
  - These codes join `CoreError` additively (no version bump to the error registry). Precedent: `PLATFORM_BUNDLE_INTEGRITY_FAILED` in EPIC 01.
- **Model-calling paths:** none. Tier 0 only. No Foundation Models framework in this task.
- **Tooling this task may name:** per `docs/tech-stack.md` — Swift 6 with strict concurrency; Swift Testing for tests; `Foundation` imports only.
- **Test pattern for contract files:** existing tests read contracts via `#filePath` and relative path traversal. Example: `IdentifierBlocklistParityTests.swift` uses `let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent()...appendingPathComponent("pipeline/tests/test_contracts.py")`. Test obligations for this task include byte-identity round-trip through `CoreCoding` and validation of the written file against `contracts/schemas/student-state.schema.json`.
- **Concurrency:** Swift 6 strict concurrency; the store returns synchronously (no async paths in Tier 0); caller is responsible for dispatching to the appropriate queue if needed.
- **Imports:** Foundation only; no imports of App/platform-specific types.

## Preconditions and ordering

- Task 03.3 (core-error-surface-text-mirror) must add `PLATFORM_STATE_UNREADABLE` and `PLATFORM_STATE_WRITE_FAILED` cases to `CoreError` before this task's code compiles.
- EPIC 02b (includes task 02.11 with `DiagnosisRun.open`, `MarkerTrail` functions, and data-model v1.4.0) must be wrapped and merged first.
- The brief specifies that the task 03.7 façade (map-actions) depends on this task's store; the façade calls `selectCourse` and every action that changes state (e.g., `setMarker`) must trigger a persistent write.

## Post-write checklist

- Quote audit: re-read every verbatim block against the cited source file and line range before writing.
- Verify no fabricated quotes (byte-comparison required).
- Ensure every citation has a path and line range or an exact Grep query.
- Confirm the precondition note about task 03.3 is accurate.
