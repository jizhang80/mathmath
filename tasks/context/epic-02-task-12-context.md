# Task 02.12 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: state-merge
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- Epic: 02
- Task: 12
- Slug: state-merge
- Sub-EPIC: 02b (Door A core + merge)
- Summary: Implement pure `merge(StudentState, StudentState)` function in `Core` applying the merge rule from the Q-B arbiter ruling, landed into `contracts/data-model.md` v1.4.0 by task 02.9. Commutative, idempotent, never lowers mastery, no identifier; algebraic-law property tests.
- Invariants in play:
  - **I5** — "**No PII, no accounts.** Telemetry is anonymous and aggregate, **on by default with one-tap off, and carries no identifier of any kind** (no install, device or session id); the endpoint retains no IP. Cross-device sync uses Apple-managed identity only." (CLAUDE.md, invariants table, row I5)
  - **I14** — "**`Core` is renderer-free and single-source**: `Core` imports Foundation only; the render layer never computes state; L0 and layout exist once, in `Core`. A test asserts the import boundary." (CLAUDE.md, invariants table, row I14)

## §B. Applicable contract rules (verbatim)

### contracts/data-model.md § StudentState merge (platform Q3) — merge rule (v1.4.0, task 02.9 lands this verbatim)

The normative text this task implements. Source: `tasks/arbitration/arbiter-02-predispatch.md:83–111`, which task 02.9 lands verbatim into the contract with blockquote markers stripped.

> `merge(a, b)` is a pure `Core` function over two `StudentState`s, both already migrated to the current `schema_version` (platform W3 precedes W4 step 2); it takes no bundle and introduces no field.
> - **nodes** — key union. A key on one side keeps that entry. A key on both: `mastery` = the higher under `cleared` > `blocked` > `fog`; `correct_count` = max; `ladder_rung` = max; `last_probe` = the later day, `next_due` = the later day (absent is earlier than any day); `remediated` = logical OR, then removed unless the merged `mastery` is `blocked`.
> - **expedition_log, probe_log** — multiset union by full-value equality: every distinct entry value appears `max(count in a, count in b)` times. Output order is canonical: ascending `day`, then the remaining fields in schema property order (`expedition_log`: `item_count`, `cleared`, `blocked`, `abandoned`, `diagnosis_events`; `probe_log`: `node_id`, `item_id`, `correct`, `retry`), strings by byte order, `false` before `true`, integers ascending. Two distinct runs with identical values on the same day, one on each side, merge into one entry; this loss is accepted rather than add an identifier (I5).
> - **Winning side W** (for `marker`, `syllabi`, `trail`) — the side whose latest `day` across its `expedition_log` and `probe_log` is later (a side with both logs empty loses to a side with any entry). On a tie: the marker further along — `past_last_unit: true` ranks above any unit, else the greater unit ordinal `n` of `unit_id` = `<course_code>.u<n>` (§ Identifiers: "1-based, in unit order"); then the lexicographically greater `course_code`. Any remaining tie between fields that still differ is broken by comparing the two values' canonical JSON encodings (sorted keys) byte-wise, greater wins.
> - **marker, syllabi, trail** — all three from W (the marker stays inside its own `syllabi`; `trail` is a derived cache the caller regenerates after merge).
> - **install_day** = the earlier day. **format_version_seen** = the higher semver.
> - **consent_on** = `a.consent_on ∧ b.consent_on` — an off on either side stays off (`telemetry.md` § Consent, I5 "one-tap off").
>
> Laws (CoreTests): commutative and idempotent under equality where logs compare in canonical order — `merge(a, a) == canonicalise(a)`, `merge(a, b) == merge(b, a)`; no merged node's `mastery` is lower than either input's.

Source: `tasks/arbitration/arbiter-02-predispatch.md:83–111` (arbiter Q-B ruling normative text); task 02.9 lands this into `contracts/data-model.md` v1.4.0 § StudentState merge verbatim.
Binds this task: This is the complete normative specification of the merge function this task must implement. Every detail is binding.

### contracts/data-model.md § StudentState — data model for the merge inputs

> `schema_version`, `format_version_seen`, `syllabi[]` (course codes), `marker {course_code, unit_id, past_last_unit?}`, `nodes {node_id → {mastery ∈ {fog, cleared, blocked}, correct_count, last_probe?, next_due?, ladder_rung, remediated?}}`, `trail {segments[] {kind ∈ {course, extension}, course_code?, node_ids[]}}` (derived, cached), `expedition_log[] {day, item_count, cleared, blocked, abandoned, diagnosis_events}`, `probe_log[] {day, node_id, item_id, correct, retry}`, `install_day`, `consent_on`. **No field may name a person, device, account, install or session** (I5); the schema's closed key set is the guard.

Source: `contracts/data-model.md:131–137` (StudentState field list, v1.3.0 baseline)
Binds this task: Defines the input and output shapes; I5 constraint on the merge function binds no identifier.

### contracts/data-model.md § Time — calendar day semantics

> Dates in state and telemetry are **calendar days** (`YYYY-MM-DD`, device-local) — never finer (I5).

Source: `contracts/data-model.md:32–33`
Binds this task: All `day` fields in logs and `install_day` are calendar-day strings; the merge compares them as strings for ordering.

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/platform.md § W4 — Sync student state (step 2)

The operation this task implements the `Core` half of. W4 step 2 is the merge call that happens on iCloud conflict.

> **Pre:** signed in to iCloud; a local write happened or a remote change arrived. **Steps:** 1. Upload the document / download the remote one per the mechanism chosen in Q1. 2. On conflict merge per Q3 in `Core` (a pure function over two `StudentState`s), write the merged result, sync again. 3. Signed out, or iCloud unavailable → do nothing, silently (v2.5 §5). **Post:** `platform.sync_completed` or `platform.sync_conflict_merged`; a failure is logged locally and retried, never surfaced as an error.

Source: `docs/domains/platform.md:69–74`
Binds this task: The merge is a step in iCloud sync conflict resolution; the function is called with two already-migrated `StudentState` values and must return a merged value such that sync can proceed without further design.

### docs/domains/platform.md § Q3 — State merge on sync conflict (ratified default)

The ratified domain intent the Q-B ruling implements.

> **Q3 — State merge on sync conflict.** **Default:** per-node merge in `Core`: the higher mastery wins (`cleared` > `blocked` > `fog`), `correct_count` takes the max, `last_probe`/`next_due` take the latest; logs are unioned by entry id; the marker takes the latest write. **Trade-off:** never loses earned progress; can resurrect a `blocked` mark the other device already cleared, corrected by the next probe. **Ratified 2026-09-09:** default accepted.

Source: `docs/domains/platform.md:132–136`
Binds this task: The Q-B ruling (landed by task 02.9) is the technical realisation of this ratified intent, modified where I5 constraints prevent literal implementation ("entry id" → "full-value equality").

## §D. Prior task outputs this task depends on

Exported types and signatures already produced by EPIC 01 that this task consumes. Quote from code; cite path.

- `StudentState` — `public struct StudentState: Codable, Equatable { public let schemaVersion: Int; public let formatVersionSeen: String; public let syllabi: [String]; public let marker: Marker; public let nodes: [String: NodeState]; public let trail: Trail; public let expeditionLog: [ExpeditionLogEntry]; public let probeLog: [ProbeLogEntry]; public let installDay: String; public let consentOn: Bool; }` — Source: `Packages/Core/Sources/Core/Model/StudentState.swift:10–21` (produced by EPIC 01)

- `Marker` — `public struct Marker: Codable, Equatable { public let courseCode: String; public let unitId: String; public let pastLastUnit: Bool?; }` — Source: `Packages/Core/Sources/Core/Model/StudentState.swift:23–27`

- `NodeState` — `public struct NodeState: Codable, Equatable { public let mastery: Mastery; public let correctCount: Int; public let lastProbe: String?; public let nextDue: String?; public let ladderRung: Int; public let remediated: Bool?; }` — Source: `Packages/Core/Sources/Core/Model/StudentState.swift:29–36`

- `Mastery` — `public enum Mastery: String, Codable { case fog; case cleared; case blocked; }` — Source: `Packages/Core/Sources/Core/Model/StudentState.swift:38–42`

- `Trail` — `public struct Trail: Codable, Equatable { public let segments: [TrailSegment]; }` — Source: `Packages/Core/Sources/Core/Model/StudentState.swift:44–46`

- `ExpeditionLogEntry` — `public struct ExpeditionLogEntry: Codable, Equatable { public let day: String; public let itemCount: Int; public let cleared: Int; public let blocked: Int; public let abandoned: Bool; public let diagnosisEvents: Int; }` — Source: `Packages/Core/Sources/Core/Model/StudentState.swift:59–66`

- `ProbeLogEntry` — `public struct ProbeLogEntry: Codable, Equatable { public let day: String; public let nodeId: String; public let itemId: String; public let correct: Bool; public let retry: Bool; }` — Source: `Packages/Core/Sources/Core/Model/StudentState.swift:68–74`

- `CalendarDay` — `public struct CalendarDay: Equatable, Hashable, Comparable, Sendable { public let iso: String; public init?(iso: String) { ... }; public func adding(days: Int) -> CalendarDay { ... }; public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool { lhs.iso < rhs.iso } }` — Source: `Packages/Core/Sources/Core/Time/CalendarDay.swift:7–38` (type exists; exported via public interface)

- `CoreCoding` — `public enum CoreCoding { public static var decoder: JSONDecoder { ... }; public static var encoder: JSONEncoder { encoder.keyEncodingStrategy = .convertToSnakeCase; encoder.outputFormatting = [.sortedKeys] } }` — Source: `Packages/Core/Sources/Core/CoreCoding.swift:10–28`

- Property generators for StudentState: `PropertyGen.nodeState(_:today:)`, `PropertyGen.nodesMap(_:nodeIds:today:)` — Source: `Packages/Core/Tests/CoreTests/Support/PropertyGen.swift:50–75` (test utility produced by EPIC 01)

Task 02.9 produces the normative merge rule text (contract only, no code); task 02.12 consumes that text to implement the function.

## §E. Negative facts (confirmed ABSENT)

- **No merge function exists in `Core` yet** — Grep `Packages/Core/Sources/Core merge` (excluding comments) returns no match. The function signature and implementation are this task's deliverable.

- **No "sum-multiplicity" negative control in CoreTests** — Grep `sum.multiplicity|sumMultiplicity` across `Packages/Core/Tests/CoreTests` returns no match. Task 02.9 spec requires this test as the "cascade note" negative control; task 02.12 must land it.

- **No `canonicalise` function in Core** — Grep `canonicalise|canonicalize` across `Packages/Core/Sources/Core` returns no match. The merge rule's law test requires `merge(a, a) == canonicalise(a)` (logs in canonical order). This function must be implemented or the encoder's `.sortedKeys` must be used to canonicalise for comparison.

- **No merge rule currently in `contracts/data-model.md`** — File exists at v1.3.0; the v1.4.0 `### StudentState merge (platform Q3)` subsection does not exist until task 02.9 lands it. This task implements from the already-landed contract rule.

## §F. File scope

Files this task may create or touch:

- CREATE `Packages/Core/Sources/Core/merge.swift` (or extend an existing State file) — contains `merge(StudentState, StudentState) -> StudentState` function and helper functions for log merging, node merging, and marker tiebreak logic. Confirmed absent: `Glob Packages/Core/Sources/Core/*merge*` returns no match.

- MODIFY `Packages/Core/Tests/CoreTests/SomeTestFile.swift` (e.g., a new `MergeTests.swift` or `StudentStateMergeTests.swift`) — adds the property tests for commutativity, idempotence (via canonical log ordering), never-lowering mastery, and the sum-multiplicity negative control. Confirmed absent: `Glob Packages/Core/Tests/CoreTests/*[Mm]erge*` returns no match.

- No other files are in scope per task 02.12 spec (no schema, no example, no pipeline, no data).

## §G. Stack constraints relevant here

Concrete constraints from contracts and `docs/tech-stack.md`:

- **Language and imports:** Swift 6, strict concurrency. `Core` imports Foundation only (I14 guard). Source: `docs/tech-stack.md:1, Table row "Shared logic"`, confirmed by `CLAUDE.md I14` and `Packages/Core/Tests/CoreTests/SomeImportBoundaryTest.swift` (the existing import-boundary test).

- **Testing framework:** Swift Testing (`import Testing`). Source: `docs/tech-stack.md:1, Table row "Swift tests"`. Property tests use `SeededGenerator` (existing) and `PropertyGen` (existing utilities per §D).

- **JSON encoding:** The wire coder is `CoreCoding` which uses `.sortedKeys` for deterministic output. This is used for canonical-order log comparison in the law tests. Source: `Packages/Core/Sources/Core/CoreCoding.swift:22–26` — `.sortedKeys` is already applied to every `Core` type; the merge output must use the same coder so that `merge(a, a)` encoded equals `canonicalise(a)` encoded.

- **Calendar days, never finer:** All `day` strings are `YYYY-MM-DD`. The `CalendarDay` type exists and has string comparison semantics (`<` is lexicographic on `.iso`). Comparisons of latest `day` in the logs use string comparison. Source: `contracts/data-model.md § Time` and `Packages/Core/Sources/Core/Time/CalendarDay.swift:36–38`.

- **No error codes registered for this task.** The merge function is deterministic and never fails (both inputs are already valid `StudentState` values post-migration). No new error code is needed. Source: `tasks/epic-02-task-09-contract-state-merge-rule.md:245–247` states "nothing here is reachable at runtime (this is a contract-text change, not code)".

- **Tooling:** `swift build`, `swift test -c release`, `scripts/gate.sh` (gates 1–4 apply). Source: `docs/tech-stack.md § 3 Gates`.

- **No model calling, no Tier 1.** The merge is deterministic and Tier 0 only. Source: `tasks/epic-02-task-09-contract-state-merge-rule.md:187` — "I2 not engaged" because no model call exists.

## §H. Invariant details

**I5 — No identifier introduced:** The merge rule explicitly states "this loss is accepted rather than add an identifier (I5)" when two distinct runs merge into one entry due to identical values on the same day. The merge function must not introduce any new field that could identify a person, device, install, or session. The `IdentifierBlocklistParityTests` (EPIC 01, existing) confirms the blocklist is in sync; no new field changes this. Source: `tasks/arbitration/arbiter-02-predispatch.md:96`, `CLAUDE.md` I5, and `Packages/Core/Tests/CoreTests/IdentifierBlocklistParityTests.swift:17–19`.

**I14 — `Core` is renderer-free and single-source:** The merge function is a pure function over two `StudentState` values with no side effects, no render-layer concern, and no I/O. It exists once, in `Core`, and is the canonical implementation. The merge is not implemented anywhere else. Source: `CLAUDE.md I14`, `tasks/epic-02-task-09-contract-state-merge-rule.md:187` (I14 hold).
