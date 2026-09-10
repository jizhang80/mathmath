# Epic 02 · Task 12: `StateMerge.merge` — commutative, idempotent, mastery-preserving StudentState merge

---
epic: 02
task: 12
slug: state-merge
kind: feat
risk: seam
depends_on: [02.9]
model: sonnet
---

> **Branch note.** This spec is written against the current tree (branch `epic-02b-door-a-core-merge`, after
> 02a is merged into `main`). At the time this spec is written, `contracts/data-model.md` is still v1.3.0
> (confirmed by reading `contracts/data-model.md:1-3` in this run: `**Contract version:** v1.3.0 ...`, no
> `### StudentState merge (platform Q3)` subsection present — `rg -n "StudentState merge"
> contracts/data-model.md` returns no match). Task 02.9 (`tasks/epic-02-task-09-contract-state-merge-rule.md`,
> currently being revised for line-wrapping only — its rule content is fixed) lands the v1.4.0 subsection
> verbatim before this task runs. §3 below quotes the rule text from its normative source,
> `tasks/arbitration/arbiter-02-predispatch.md:83-111` (byte-compared against 02.9's own already-landed §3/§4
> quote of the same text in this run — identical, modulo 02.9's own Markdown line-wrapping, which changes no
> character of content). This task implements from that text; it is cited here as "`contracts/data-model.md`
> v1.4.0 § StudentState merge", per the dispatch instruction, on the understanding that 02.9 has landed it by
> the time this task executes.

## §1 Goal & acceptance criteria

Goal: give `Core` the pure function `StateMerge.merge(_ a: StudentState, _ b: StudentState) -> StudentState`
that realises the normative merge rule landed by task 02.9 (`contracts/data-model.md` v1.4.0 § StudentState
merge, platform Q3) — the `Core` half of iCloud sync conflict resolution (`docs/domains/platform.md` W4 step
2), never lowering any node's mastery, never introducing an identifier, and provable by algebraic-law property
tests (commutative, idempotent under a `canonicalise` step) over `PropertyGen`-generated pairs.

Invariants in play:

- **I5** — the merge rule's own text states twice that it "introduces no field" and that a same-day
  duplicate-value log collision "is accepted rather than add an identifier (I5)". This task's implementation
  adds no field to `StudentState`/`NodeState`/`Marker`/`ExpeditionLogEntry`/`ProbeLogEntry`, computes no new
  identifier of any kind, and the merged output's re-encoded wire-key set is proven disjoint from the
  identifier blocklist mirrored from `pipeline/tests/test_contracts.py::IDENTIFIER_BLOCKLIST` (AC11).
- **I14** — `StateMerge.merge` and `StateMerge.canonicalise` are pure value functions over `StudentState`:
  `Foundation` only, no `Date()`, no file I/O, no bundle argument, no global mutable state. They are the one
  and only `Core` implementation of the merge rule — no second implementation exists anywhere else in the
  repository. `Core`'s existing `coreImportBoundary()` test (unmodified) covers the new file with no edit.

Acceptance criteria (each independently verifiable):

- AC1: `Packages/Core/Sources/Core/State/StateMerge.swift` exports `public enum StateMerge` with `public
  static func merge(_ a: StudentState, _ b: StudentState) -> StudentState` and `public static func
  canonicalise(_ state: StudentState) -> StudentState`.
  Instrument: `swift build -c release --product core-cli` compiles; `rg -n "public static func (merge|canonicalise)"
  Packages/Core/Sources/Core/State/StateMerge.swift` shows both signatures.
- AC2 (commutativity): a property test over 200 `SeededGenerator`-driven `(a, b)` pairs asserts
  `StateMerge.merge(a, b) == StateMerge.merge(b, a)`.
- AC3 (idempotency): a property test over 200 `SeededGenerator`-driven `a` values asserts `StateMerge.merge(a,
  a) == StateMerge.canonicalise(a)`.
- AC4 (never-lowering mastery): a property test asserts, for every node key present in `a.nodes` (resp.
  `b.nodes`), the merged result's `nodes[key].mastery` rank (`fog` < `blocked` < `cleared`) is `≥` that key's
  rank in `a` (resp. `b`) whenever the key survives into the merged result — which it always does, since
  `nodes` is a key union.
- AC5 (`correct_count`/`ladder_rung` max, `last_probe`/`next_due` latest): an explicit two-`NodeState`
  scenario plus a property test assert `merged.correctCount == max(a.correctCount, b.correctCount)`,
  `merged.ladderRung == max(a.ladderRung, b.ladderRung)`, and `merged.lastProbe`/`merged.nextDue` equal
  whichever of the two inputs' values is present and later, or the sole present value, or absent iff both are
  absent.
- AC6 (`remediated` — OR, then dropped unless merged mastery is `blocked`): three scenarios — (a) both sides
  `blocked`, one `remediated: true` one `remediated: false` → merged `blocked`, `remediated == true`; (b) both
  sides `blocked`, both `remediated: false`/absent → merged `blocked`, `remediated == false` (present, not
  `nil`); (c) either side's mastery merges to `cleared` (e.g. one side `cleared`, the other `blocked`) →
  merged `remediated == nil` regardless of either input's `remediated` value.
- AC7 (logs — multiset union, max multiplicity, canonical order): a scenario where `a.probeLog` holds one
  entry `X` twice and `b.probeLog` holds `X` once and a distinct entry `Y` once asserts the merged
  `probeLog` holds `X` exactly twice and `Y` exactly once, in canonical order (ascending `day`, then
  `node_id`, `item_id`, `correct`, `retry`, strings byte order, `false` before `true`); a property test
  asserts, for every generated `(a, b)` pair and both log kinds, `merged.count == Σ over distinct values of
  max(countInA, countInB)`.
- AC8 (Winning side W → `marker`, `syllabi`, `trail`): four explicit scenarios — (a) `a`'s latest `day` across
  its logs is later than `b`'s → `a`'s marker/syllabi/trail win; (b) both sides' latest `day` tie (or both
  empty), `a.marker.pastLastUnit == true` and `b.marker.pastLastUnit != true` → `a` wins regardless of unit
  ordinal; (c) both sides tie on `day` and neither is past-last-unit, `a`'s unit ordinal is strictly greater
  → `a` wins; (d) both sides tie on `day`, marker rank, and unit ordinal, but `a.marker.courseCode` is
  lexicographically greater → `a` wins.
- AC9 (`install_day` earlier, `format_version_seen` higher, `consent_on` AND): a scenario plus a property
  test assert `merged.installDay == min(a.installDay, b.installDay)` (string/lexicographic, matching calendar-
  day ordering), `merged.formatVersionSeen` is the semver-greater of the two inputs' values, and
  `merged.consentOn == (a.consentOn && b.consentOn)` — false whenever either side is `false`.
- AC10 (`schema_version` pinned to current): every scenario and property test asserts `merged.schemaVersion ==
  2` (`contracts/data-model.md:149`: "`schema_version` is **2**"), regardless of either input's own
  `schemaVersion` value (both inputs are assumed already migrated to 2 per the merge rule's own preamble;
  `merge` re-pins the output rather than propagate either input's value — §6 default 1).
- AC11 (CoreCoding round trip + I5 identifier-blocklist parity): for a merged `StudentState` produced by a
  non-trivial scenario, `CoreCoding.decoder.decode(StudentState.self, from: CoreCoding.encoder.encode(merged))
  == merged`; the re-encoded document's collected wire-key set (collected the same way
  `DecodeRoundTripTests.swift`'s `studentStateWireKeysRejectIdentifierBlocklist()` does) is disjoint from the
  nine-entry identifier blocklist mirrored from `pipeline/tests/test_contracts.py::IDENTIFIER_BLOCKLIST`.
- AC12 (negative control per guard): for each of the merge rule's distinguishing choices — max vs
  sum-multiplicity (logs), max vs min (mastery, `correctCount`, `ladderRung`), latest vs earliest
  (`lastProbe`/`nextDue`), OR vs AND (`remediated`), the marker tie-break's stated priority order vs a
  swapped order, min vs max (`installDay`), higher vs lower semver (`formatVersionSeen`), AND vs OR
  (`consentOn`) — a locally reconstructed wrong variant (in the test file only, never in product code)
  produces an observably different result from `StateMerge.merge` on a concrete scenario, proving the real
  rule's choice is load-bearing, not accidentally satisfied by its opposite.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Core/Sources/Core/State/StateMerge.swift` — CREATE. `StateMerge.merge`, `StateMerge.canonicalise`,
  and every private helper (§4). Confirmed absent: `Glob Packages/Core/Sources/Core/**/*erge*` returns no
  match at the time this spec is written.
- `Packages/Core/Tests/CoreTests/StateMergeTests.swift` — CREATE. This task's own companion test suite (§5):
  AC1–AC12, the algebraic-law property tests, and every negative control.
- `Packages/Core/Tests/CoreTests/Support/PropertyGen.swift` — MODIFY. Append new generator functions —
  `marker`, `trail`, `expeditionLogEntry`, `probeLogEntry`, `studentState` — to the existing `enum
  PropertyGen` body, per that file's own documented extension point: "Later tasks (02.5-02.7, 02.10-02.12)
  add their own generator functions to this same file/namespace rather than duplicating a parallel helper
  (§6 default)" (`Packages/Core/Tests/CoreTests/Support/PropertyGen.swift:9-10`). No existing function in
  that file is edited or removed.

Out-of-scope (do not touch even if tempted):

- `Packages/Core/Sources/Core/Model/StudentState.swift` — task 02.2's file, already landed. This task reads
  `StudentState`, `Marker`, `NodeState`, `Mastery`, `Trail`, `TrailSegment`, `SegmentKind`,
  `ExpeditionLogEntry`, `ProbeLogEntry` unmodified; it adds no field, no case, no type.
- `Packages/Core/Sources/Core/CoreCoding.swift`, `Packages/Core/Sources/Core/Time/CalendarDay.swift` — read
  unmodified; `merge`/`canonicalise` use `CoreCoding.encoder` for the winning-side final tie-break (§4) and
  compare calendar-day strings the same way `CalendarDay.Comparable` does, but this task adds nothing to
  either file.
- `Packages/Core/Sources/Core/CoreError.swift` — no error code is added or raised by this task; `merge` is
  deterministic and total over any two well-typed `StudentState` values (§4 step 6, `docs/tech-stack.md` §
  boundary-validation note does not apply here — there is no untrusted-input boundary inside a pure `Core`
  function over already-typed Swift values).
- `Packages/Core/Tests/CoreTests/DecodeRoundTripTests.swift`,
  `Packages/Core/Tests/CoreTests/IdentifierBlocklistParityTests.swift` — read-only precedent for AC11's
  key-collection instrument; this task's own test file declares its own local copy of the blocklist Set and
  the key-collector function (mirroring both files' own pattern of a private, file-local copy — neither file
  exports a public one), rather than editing either file.
- `contracts/data-model.md` — task 02.9's file, already landed by the time this task runs (see branch note
  above). This task implements the already-landed rule; it does not touch the contract.
- `data/demo/**`, `pipeline/**` — no bundle is read by `merge` (the rule's own first sentence: "it takes no
  bundle and introduces no field"); no pipeline surface is touched.
- `Packages/Core/Sources/Core/State/Expedition.swift`, `MasteryTransitions.swift`,
  `MarkerTrailGeneration.swift`, `Diagnosis*.swift` — other tasks' files in the same directory; this task adds
  one new, independent file (`StateMerge.swift`) and touches none of these.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rule — the normative merge text (`contracts/data-model.md` v1.4.0 § StudentState merge
(platform Q3), landed verbatim by task 02.9 from its source, `tasks/arbitration/arbiter-02-predispatch.md:83-111`,
re-read and byte-compared in this run against 02.9's own already-written §3/§4 quote of the same passage —
identical in content, differing only in Markdown line-wrapping):

> `merge(a, b)` is a pure `Core` function over two `StudentState`s, both already migrated to the current
> `schema_version` (platform W3 precedes W4 step 2); it takes no bundle and introduces no field.
> - **nodes** — key union. A key on one side keeps that entry. A key on both: `mastery` = the higher under
>   `cleared` > `blocked` > `fog`; `correct_count` = max; `ladder_rung` = max; `last_probe` = the later day,
>   `next_due` = the later day (absent is earlier than any day); `remediated` = logical OR, then removed
>   unless the merged `mastery` is `blocked`.
> - **expedition_log, probe_log** — multiset union by full-value equality: every distinct entry value
>   appears `max(count in a, count in b)` times. Output order is canonical: ascending `day`, then the
>   remaining fields in schema property order (`expedition_log`: `item_count`, `cleared`, `blocked`,
>   `abandoned`, `diagnosis_events`; `probe_log`: `node_id`, `item_id`, `correct`, `retry`), strings by byte
>   order, `false` before `true`, integers ascending. Two distinct runs with identical values on the same
>   day, one on each side, merge into one entry; this loss is accepted rather than add an identifier (I5).
> - **Winning side W** (for `marker`, `syllabi`, `trail`) — the side whose latest `day` across its
>   `expedition_log` and `probe_log` is later (a side with both logs empty loses to a side with any entry).
>   On a tie: the marker further along — `past_last_unit: true` ranks above any unit, else the greater unit
>   ordinal `n` of `unit_id` = `<course_code>.u<n>` (§ Identifiers: "1-based, in unit order"); then the
>   lexicographically greater `course_code`. Any remaining tie between fields that still differ is broken by
>   comparing the two values' canonical JSON encodings (sorted keys) byte-wise, greater wins.
> - **marker, syllabi, trail** — all three from W (the marker stays inside its own `syllabi`; `trail` is a
>   derived cache the caller regenerates after merge).
> - **install_day** = the earlier day. **format_version_seen** = the higher semver.
> - **consent_on** = `a.consent_on ∧ b.consent_on` — an off on either side stays off (`telemetry.md` §
>   Consent, I5 "one-tap off").
>
> Laws (CoreTests): commutative and idempotent under equality where logs compare in canonical order —
> `merge(a, a) == canonicalise(a)`, `merge(a, b) == merge(b, a)`; no merged node's `mastery` is lower than
> either input's.

Cascade note (same arbiter section, immediately following, re-read in this run):

> **Cascade for 02.12.** The AC9 law tests must compare through `canonicalise`, because a raw append-ordered
> log would make `merge(a, a) == a` fail spuriously. The spec must include a **negative control**: a merge
> that keeps sum-multiplicity instead of max must fail idempotence.

Supporting contract clause (`contracts/data-model.md:149`, § StudentState final paragraph, re-read in this
run):

> `schema_version` is **2**. Migration 1 → 2 is the identity: a version-1 document is a valid version-2
> document with every `remediated` absent.

Supporting contract clause (`contracts/data-model.md:18-19`, § Identifiers, re-read in this run):

> `unit_id` is `<course_code>.u<n>` (1-based, in unit order)

CLAUDE.md invariants this task's code is bound by:

- `CLAUDE.md` — Invariant table, row `I5`:
  > **No PII, no accounts.** Telemetry is anonymous and aggregate, **on by default with one-tap off, and
  > carries no identifier of any kind** (no install, device or session id); the endpoint retains no IP.
  > Cross-device sync uses Apple-managed identity only.
- `CLAUDE.md` — Invariant table, row `I14`:
  > **`Core` is renderer-free and single-source**: `Core` imports Foundation only; the render layer never
  > computes state; L0 and layout exist once, in `Core`. A test asserts the import boundary.

Ratified domain intent this rule realises (`docs/domains/platform.md:132-136`, § Q3, re-read in this run):

> **Q3 — State merge on sync conflict.** **Default:** per-node merge in `Core`: the higher mastery wins
> (`cleared` > `blocked` > `fog`), `correct_count` takes the max, `last_probe`/`next_due` take the latest;
> logs are unioned by entry id; the marker takes the latest write. **Trade-off:** never loses earned
> progress; can resurrect a `blocked` mark the other device already cleared, corrected by the next probe.
> **Ratified 2026-09-09:** default accepted.

Prior signatures this task builds on (`Packages/Core/Sources/Core/Model/StudentState.swift:10-74`, re-read in
this run):

```swift
public struct StudentState: Codable, Equatable {
    public let schemaVersion: Int
    public let formatVersionSeen: String
    public let syllabi: [String]
    public let marker: Marker
    public let nodes: [String: NodeState]
    public let trail: Trail
    public let expeditionLog: [ExpeditionLogEntry]
    public let probeLog: [ProbeLogEntry]
    public let installDay: String
    public let consentOn: Bool
}

public struct Marker: Codable, Equatable {
    public let courseCode: String
    public let unitId: String
    public let pastLastUnit: Bool?
}

public struct NodeState: Codable, Equatable {
    public let mastery: Mastery
    public let correctCount: Int
    public let lastProbe: String?
    public let nextDue: String?
    public let ladderRung: Int
    public let remediated: Bool?
}

public enum Mastery: String, Codable {
    case fog
    case cleared
    case blocked
}

public struct Trail: Codable, Equatable {
    public let segments: [TrailSegment]
}

public struct TrailSegment: Codable, Equatable {
    public let kind: SegmentKind
    public let courseCode: String?
    public let nodeIds: [String]
}

public enum SegmentKind: String, Codable {
    case course
    case `extension`
}

public struct ExpeditionLogEntry: Codable, Equatable {
    public let day: String
    public let itemCount: Int
    public let cleared: Int
    public let blocked: Int
    public let abandoned: Bool
    public let diagnosisEvents: Int
}

public struct ProbeLogEntry: Codable, Equatable {
    public let day: String
    public let nodeId: String
    public let itemId: String
    public let correct: Bool
    public let retry: Bool
}
```

`CalendarDay` (`Packages/Core/Sources/Core/Time/CalendarDay.swift:7-38`, re-read in this run):

```swift
public struct CalendarDay: Equatable, Hashable, Comparable, Sendable {
    public let iso: String
    public init?(iso: String) { ... }
    public func adding(days: Int) -> CalendarDay { ... }
    public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool { lhs.iso < rhs.iso }
}
```

`CoreCoding` (`Packages/Core/Sources/Core/CoreCoding.swift:10-28`, re-read in this run):

```swift
public enum CoreCoding {
    public static var decoder: JSONDecoder { ... }  // .convertFromSnakeCase
    public static var encoder: JSONEncoder { ... }  // .convertToSnakeCase, .sortedKeys
}
```

`PropertyGen` (`Packages/Core/Tests/CoreTests/Support/PropertyGen.swift:11-76`, re-read in this run — the
existing functions this task's new generators call):

```swift
enum PropertyGen {
    static func calendarDay(_ gen: inout SeededGenerator) -> CalendarDay
    static func mastery(_ gen: inout SeededGenerator) -> Mastery
    static func element<T>(_ gen: inout SeededGenerator, from pool: [T]) -> T
    static func bool(_ gen: inout SeededGenerator, trueWeight: Double) -> Bool
    static func int(_ gen: inout SeededGenerator, in range: ClosedRange<Int>) -> Int
    static func nodeState(_ gen: inout SeededGenerator, today: CalendarDay) -> NodeState
    static func nodesMap(_ gen: inout SeededGenerator, nodeIds: [String], today: CalendarDay) -> [String: NodeState]
}
```

`SeededGenerator` (`Packages/Core/Sources/Core/Layout/SeededGenerator.swift:6-20`, re-read in this run):

```swift
public struct SeededGenerator: RandomNumberGenerator {
    public init(seed: UInt64)
    public mutating func next() -> UInt64
}
```

I5 identifier blocklist this task's AC11 test mirrors (`Packages/Core/Tests/CoreTests/DecodeRoundTripTests.swift:246-248`,
re-read in this run):

```swift
private static let identifierBlocklist: Set<String> = [
    "id", "install_id", "device_id", "session_id", "user_id", "ip", "timestamp", "email", "name",
]
```

Gate commands (`scripts/gate.sh:16-18`, re-read in this run):

```sh
( cd "$ROOT/Packages/Core" && swift build -c release --product core-cli )
( cd "$ROOT/Packages/Core" && xcodebuild test -quiet -scheme Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO )
```

## §4 Implementation outline

Layer placement: this task is not part of any of the four content layers (① spine, ② concept graph, ③
learning objects, ④ interaction) — it is the `Core` half of platform infrastructure (`docs/domains/
platform.md` W4 step 2, iCloud sync conflict resolution), a pure function over the `StudentState` artifact
layer ④'s own machinery (`Expedition`, `Diagnosis`) writes. It reads no bundle and no graph.

### 1. `StateMerge.swift` — types and top-level functions

```swift
import Foundation

/// State merge on iCloud sync conflict (`contracts/data-model.md` v1.4.0 § StudentState merge (platform
/// Q3), landed by task 02.9 from the arbiter's Q-B ruling,
/// `tasks/arbitration/arbiter-02-predispatch.md:83-111`). A pure `Core` function over two already-migrated
/// `StudentState` values (I14) — no bundle, no I/O, no clock read, no new field (I5).
public enum StateMerge {
    /// `merge(a, b)` per the contract's normative rule (quoted in full, §3). Commutative and idempotent
    /// under `canonicalise` (below); no merged node's `mastery` is lower than either input's.
    public static func merge(_ a: StudentState, _ b: StudentState) -> StudentState {
        let aWins = winningSideIsA(a, b)
        let winner = aWins ? a : b
        return StudentState(
            schemaVersion: currentSchemaVersion,
            formatVersionSeen: higherSemver(a.formatVersionSeen, b.formatVersionSeen),
            syllabi: winner.syllabi,
            marker: winner.marker,
            nodes: mergeNodes(a.nodes, b.nodes),
            trail: winner.trail,
            expeditionLog: mergeLogs(a.expeditionLog, b.expeditionLog, precedes: expeditionLogPrecedes),
            probeLog: mergeLogs(a.probeLog, b.probeLog, precedes: probeLogPrecedes),
            installDay: min(a.installDay, b.installDay),
            consentOn: a.consentOn && b.consentOn
        )
    }

    /// `merge(a, a)`'s expected value: `a` with `expeditionLog`/`probeLog` reordered into the merge rule's
    /// canonical order. Every other field degenerates to `a`'s own value when both merge sides are `a`
    /// (max/min/OR/AND of a value with itself is itself; `nodes` merging `a.nodes` with itself keeps every
    /// entry unchanged; the winning-side computation, given two structurally identical inputs, picks a
    /// side whose fields equal `a`'s own regardless of which one it names). `schemaVersion` is re-pinned to
    /// `currentSchemaVersion`, matching `merge`'s own behaviour, so this is not simply "`a` unchanged."
    public static func canonicalise(_ state: StudentState) -> StudentState {
        StudentState(
            schemaVersion: currentSchemaVersion,
            formatVersionSeen: state.formatVersionSeen,
            syllabi: state.syllabi,
            marker: state.marker,
            nodes: state.nodes,
            trail: state.trail,
            expeditionLog: state.expeditionLog.sorted(by: expeditionLogPrecedes),
            probeLog: state.probeLog.sorted(by: probeLogPrecedes),
            installDay: state.installDay,
            consentOn: state.consentOn
        )
    }

    /// `contracts/data-model.md:149`: "`schema_version` is **2**." Re-pinned rather than propagated from
    /// either input so the function's output does not silently depend on both inputs already being 2 (§6
    /// default 1).
    private static let currentSchemaVersion = 2
}
```

### 2. `nodes` — key union, per-key merge

```swift
extension StateMerge {
    private static func mergeNodes(_ a: [String: NodeState], _ b: [String: NodeState]) -> [String: NodeState] {
        var result: [String: NodeState] = [:]
        for key in Set(a.keys).union(b.keys) {
            switch (a[key], b[key]) {
            case let (.some(onlyA), nil): result[key] = onlyA
            case let (nil, .some(onlyB)): result[key] = onlyB
            case let (.some(left), .some(right)): result[key] = mergeNode(left, right)
            case (nil, nil): break  // unreachable — key drawn from the union of both key sets
            }
        }
        return result
    }

    private static func mergeNode(_ a: NodeState, _ b: NodeState) -> NodeState {
        let mastery = higherMastery(a.mastery, b.mastery)
        let orRemediated = (a.remediated ?? false) || (b.remediated ?? false)
        return NodeState(
            mastery: mastery,
            correctCount: max(a.correctCount, b.correctCount),
            lastProbe: laterDay(a.lastProbe, b.lastProbe),
            nextDue: laterDay(a.nextDue, b.nextDue),
            ladderRung: max(a.ladderRung, b.ladderRung),
            remediated: mastery == .blocked ? orRemediated : nil
        )
    }

    /// `cleared` > `blocked` > `fog` (contract, quoted §3).
    private static func masteryRank(_ mastery: Mastery) -> Int {
        switch mastery {
        case .fog: return 0
        case .blocked: return 1
        case .cleared: return 2
        }
    }

    private static func higherMastery(_ a: Mastery, _ b: Mastery) -> Mastery {
        masteryRank(a) >= masteryRank(b) ? a : b
    }

    /// "absent is earlier than any day" (contract, quoted §3). String comparison of `YYYY-MM-DD` values is
    /// chronological order — the same fact `CalendarDay.Comparable` relies on
    /// (`Time/CalendarDay.swift:36-38`).
    private static func laterDay(_ a: String?, _ b: String?) -> String? {
        switch (a, b) {
        case (nil, nil): return nil
        case let (.some(onlyA), nil): return onlyA
        case let (nil, .some(onlyB)): return onlyB
        case let (.some(dayA), .some(dayB)): return dayA >= dayB ? dayA : dayB
        }
    }
}
```

### 3. `expedition_log`, `probe_log` — multiset union, max multiplicity, canonical order

Log arrays are small (a handful of entries per sync); an `O(n²)` dedup-and-count is the simplest correct
implementation and is not a performance concern here (RULE 2, Simplicity First — §6 default 2).

```swift
extension StateMerge {
    private static func mergeLogs<T: Equatable>(_ a: [T], _ b: [T], precedes: (T, T) -> Bool) -> [T] {
        var distinctValues: [T] = []
        for value in a + b where !distinctValues.contains(value) {
            distinctValues.append(value)
        }
        var result: [T] = []
        for value in distinctValues {
            let countA = a.filter { $0 == value }.count
            let countB = b.filter { $0 == value }.count
            result.append(contentsOf: Array(repeating: value, count: max(countA, countB)))
        }
        return result.sorted(by: precedes)
    }

    /// Canonical order for `expedition_log`: ascending `day`, then `item_count`, `cleared`, `blocked`,
    /// `abandoned` (`false` before `true`), `diagnosis_events` — the contract's stated field order, which
    /// matches `ExpeditionLogEntry`'s own declared field order (`Model/StudentState.swift:59-66`, re-read
    /// in this run).
    private static func expeditionLogPrecedes(_ lhs: ExpeditionLogEntry, _ rhs: ExpeditionLogEntry) -> Bool {
        if lhs.day != rhs.day { return lhs.day < rhs.day }
        if lhs.itemCount != rhs.itemCount { return lhs.itemCount < rhs.itemCount }
        if lhs.cleared != rhs.cleared { return lhs.cleared < rhs.cleared }
        if lhs.blocked != rhs.blocked { return lhs.blocked < rhs.blocked }
        if lhs.abandoned != rhs.abandoned { return !lhs.abandoned }
        return lhs.diagnosisEvents < rhs.diagnosisEvents
    }

    /// Canonical order for `probe_log`: ascending `day`, then `node_id`, `item_id`, `correct` (`false`
    /// before `true`), `retry` — matching `ProbeLogEntry`'s own declared field order
    /// (`Model/StudentState.swift:68-74`, re-read in this run).
    private static func probeLogPrecedes(_ lhs: ProbeLogEntry, _ rhs: ProbeLogEntry) -> Bool {
        if lhs.day != rhs.day { return lhs.day < rhs.day }
        if lhs.nodeId != rhs.nodeId { return lhs.nodeId < rhs.nodeId }
        if lhs.itemId != rhs.itemId { return lhs.itemId < rhs.itemId }
        if lhs.correct != rhs.correct { return !lhs.correct }
        return !lhs.retry && rhs.retry
    }
}
```

### 4. Winning side W — marker tie-break, final canonical-JSON tie-break

```swift
extension StateMerge {
    /// `true` selects `a` as the winning side, `false` selects `b` (contract's "Winning side W", quoted
    /// §3).
    private static func winningSideIsA(_ a: StudentState, _ b: StudentState) -> Bool {
        switch (latestDay(a), latestDay(b)) {
        case (nil, nil): break
        case (nil, .some): return false
        case (.some, nil): return true
        case let (.some(dayA), .some(dayB)):
            if dayA != dayB { return dayA > dayB }
        }
        let rankA = markerRank(a.marker)
        let rankB = markerRank(b.marker)
        if rankA.0 != rankB.0 { return rankA.0 > rankB.0 }
        if rankA.1 != rankB.1 { return rankA.1 > rankB.1 }
        if a.marker.courseCode != b.marker.courseCode { return a.marker.courseCode > b.marker.courseCode }
        // Final tie-break: canonical JSON encodings (CoreCoding — the one JSON coder configuration,
        // `.sortedKeys`), byte-wise, greater wins (§6 default 3).
        let encodedA = (try? CoreCoding.encoder.encode(a)) ?? Data()
        let encodedB = (try? CoreCoding.encoder.encode(b)) ?? Data()
        if encodedA == encodedB { return true }  // structurally identical for ranking purposes
        return encodedB.lexicographicallyPrecedes(encodedA)
    }

    private static func latestDay(_ state: StudentState) -> String? {
        (state.expeditionLog.map(\.day) + state.probeLog.map(\.day)).max()
    }

    /// `(pastLastUnitFlag, unitOrdinal)`, compared lexicographically: `past_last_unit: true` ranks above
    /// any unit (flag 1 > flag 0); `nil`/`false` both rank as "not past last unit" (§6 default 4).
    private static func markerRank(_ marker: Marker) -> (Int, Int) {
        (marker.pastLastUnit == true ? 1 : 0, unitOrdinal(marker.unitId))
    }

    /// `unit_id` = `<course_code>.u<n>` (§ Identifiers, quoted §3); `n` is the substring after the last
    /// `.u`.
    private static func unitOrdinal(_ unitId: String) -> Int {
        guard let range = unitId.range(of: ".u", options: .backwards) else { return 0 }
        return Int(unitId[range.upperBound...]) ?? 0
    }
}
```

### 5. `install_day`, `format_version_seen`, `consent_on`

```swift
extension StateMerge {
    private static func higherSemver(_ a: String, _ b: String) -> String {
        semverComponents(a).lexicographicallyPrecedes(semverComponents(b)) ? b : a
    }

    private static func semverComponents(_ semver: String) -> [Int] {
        semver.split(separator: ".").map { Int($0) ?? 0 }
    }
}
```

`installDay: min(a.installDay, b.installDay)` and `consentOn: a.consentOn && b.consentOn` are inline in
`merge` itself (step 1) — no helper needed for either.

### 6. Error codes and model-calling paths

No error code is added or raised by this task. `merge`/`canonicalise` are total over any two well-typed
`StudentState` values — there is no untrusted-input boundary inside a pure function over already-decoded
Swift values (the boundary that validates a `StudentState` document is `CoreCoding`'s decode path, task
02.2's and earlier tasks' concern, unmodified here). No model-calling path exists in this task; I2's
confidence-threshold/Tier-0-fallback requirement is not engaged (Tier 0 only, per the bundle's own note:
"I2 not engaged" — `tasks/epic-02-task-09-contract-state-merge-rule.md:187` states the same for the
contract-text task, and no code in this task calls an adapter).

### 7. `PropertyGen` additions (`Packages/Core/Tests/CoreTests/Support/PropertyGen.swift`, appended inside
the existing `enum PropertyGen { ... }` body, before its closing brace; no existing function is edited)

```swift
/// Small closed pools for this task's fixtures — no bundle is loaded (`merge` never reads one, per the
/// rule's own first sentence, quoted §3); the pools exist so generated pairs exercise real string
/// comparison in the marker tie-break (`mergeCourseCodePool`) and real overlap/disjointness in the log
/// multiset (`mergeItemIdPool`).
static let mergeCourseCodePool = ["MTH1W", "MCR3U"]
static let mergeItemIdPool = ["item-a", "item-b"]

static func marker(_ gen: inout SeededGenerator) -> Marker {
    let courseCode = element(&gen, from: mergeCourseCodePool)
    let unitOrdinal = int(&gen, in: 1...5)
    let pastLastUnit = element(&gen, from: [true, false, nil] as [Bool?])
    return Marker(
        courseCode: courseCode, unitId: "\(courseCode).u\(unitOrdinal)", pastLastUnit: pastLastUnit)
}

static func trail(_ gen: inout SeededGenerator, courseCode: String, nodeIds: [String]) -> Trail {
    Trail(segments: [TrailSegment(kind: .course, courseCode: courseCode, nodeIds: nodeIds)])
}

static func expeditionLogEntry(_ gen: inout SeededGenerator, today: CalendarDay) -> ExpeditionLogEntry {
    ExpeditionLogEntry(
        day: today.adding(days: -int(&gen, in: 0...10)).iso,
        itemCount: int(&gen, in: 1...5),
        cleared: int(&gen, in: 0...5),
        blocked: int(&gen, in: 0...5),
        abandoned: bool(&gen, trueWeight: 0.2),
        diagnosisEvents: int(&gen, in: 0...1)
    )
}

static func probeLogEntry(
    _ gen: inout SeededGenerator, today: CalendarDay, nodeIds: [String]
) -> ProbeLogEntry {
    ProbeLogEntry(
        day: today.adding(days: -int(&gen, in: 0...10)).iso,
        nodeId: element(&gen, from: nodeIds),
        itemId: element(&gen, from: mergeItemIdPool),
        correct: bool(&gen, trueWeight: 0.6),
        retry: bool(&gen, trueWeight: 0.2)
    )
}

/// A syntactically valid, fully-populated `StudentState` for merge property tests. `nodeIds` is the
/// caller's fixed small pool; each id is independently included with probability 0.6, so generated pairs
/// exercise the merge rule's "key on one side" and "key on both sides" cases with non-trivial probability
/// every run.
static func studentState(_ gen: inout SeededGenerator, nodeIds: [String], today: CalendarDay) -> StudentState {
    let generatedMarker = marker(&gen)
    let presentNodeIds = nodeIds.filter { _ in bool(&gen, trueWeight: 0.6) }
    let logCount = int(&gen, in: 0...3)
    return StudentState(
        schemaVersion: 2,
        formatVersionSeen: "\(int(&gen, in: 0...2)).\(int(&gen, in: 0...9)).\(int(&gen, in: 0...9))",
        syllabi: [generatedMarker.courseCode],
        marker: generatedMarker,
        nodes: nodesMap(&gen, nodeIds: presentNodeIds, today: today),
        trail: trail(&gen, courseCode: generatedMarker.courseCode, nodeIds: nodeIds),
        expeditionLog: (0..<logCount).map { _ in expeditionLogEntry(&gen, today: today) },
        probeLog: (0..<logCount).map { _ in probeLogEntry(&gen, today: today, nodeIds: nodeIds) },
        installDay: today.adding(days: -int(&gen, in: 0...60)).iso,
        consentOn: bool(&gen, trueWeight: 0.8)
    )
}
```

`StateMergeTests.swift` calls `PropertyGen.studentState(&gen, nodeIds: ["alpha-node", "beta-node",
"gamma-node"], today: someDay)` (a fixed, valid-kebab-case id pool, per `contracts/data-model.md` §
Identifiers) — no `data/demo` bundle is loaded anywhere in this task, matching §6 default 5.

### 8. Commit

```
feat(core): merge(StudentState, StudentState) — commutative, idempotent, mastery-preserving state merge
```

### 9. Smoke check

```
( cd Packages/Core && swift build -c release --product core-cli )
```
must be green (compiles the new file even though `core-cli`'s `main.swift` calls none of it yet, matching
02.4's/02.5's/02.6's own smoke-check pattern).

## §5 Test plan (risk: seam — full plan)

- **T1 happy path** (`StateMergeTests.swift`):
  - AC1: `swift build -c release --product core-cli` compiles; both signatures present.
  - AC5, AC6, AC7, AC8, AC9, AC10: the explicit hand-built scenarios listed under each AC, asserting exact
    field values on `StateMerge.merge`'s result.
  - AC11: the round-trip and identifier-blocklist assertions on a non-trivial merged scenario's output.
- **T2 negative — asymmetric key sets are not mistaken for both-side keys:** a scenario where `a.nodes`
  contains key `"solo-a"` (absent from `b.nodes`) and `b.nodes` contains key `"solo-b"` (absent from
  `a.nodes`) asserts the merged result carries `"solo-a"`'s value **byte-identical to `a`'s own entry** (not
  run through `mergeNode`'s max/OR logic) and likewise for `"solo-b"` from `b` — proving the single-side
  branch of `mergeNodes`'s `switch` is exercised and correct, distinct from the both-side branch AC5/AC6
  exercise.
- **T3 error-taxonomy:** not applicable — no error code is registered or thrown by this task (§4 step 6).
  Recorded explicitly, matching 02.9's own T3 disposition, so the omission is a decision, not a gap. A grep
  assertion (`rg -n "throw|CoreError" Packages/Core/Sources/Core/State/StateMerge.swift`) confirms zero
  matches, as a mechanical check that this stays true.
- **T4 conformance per requirements §B.1 / cited contract and invariants:**
  - AC2, AC3, AC4: the three algebraic-law property tests, `SeededGenerator`-driven, 200 iterations each,
    using the new `PropertyGen.studentState(_:nodeIds:today:)` generator over the fixed small
    `["alpha-node", "beta-node", "gamma-node"]` id pool (so generated pairs exercise the "key on one side",
    "key on both sides", and "distinct log values on each side" cases with non-trivial probability every
    run).
  - I5: AC11's blocklist-disjointness assertion, plus a property-test variant run once over 20 generated
    merges (not the full 200, to keep the suite fast — key-set collection is the expensive part) confirming
    no generated merge ever produces a wire key in the blocklist.
  - I14: `xcrun swift-format lint --strict` passes over the new file (mechanical); a grep assertion confirms
    zero occurrences of `Date()` in `StateMerge.swift`; `Core`'s existing `coreImportBoundary()` test is
    re-run unmodified and stays green.
- **T5 negative control for every regression guard** (AC12) — each reconstructed locally in the test file,
  never in product code, and proven to diverge from `StateMerge.merge`'s real output on a concrete scenario:
  - Logs: a variant that appends `a + b` without deduplication (sum-multiplicity, not max) fails idempotence
    on a scenario where `a` itself already holds a duplicate entry (the arbiter's own named negative
    control, quoted §3 cascade note) — `merge(a, a)` under the wrong variant has twice the true canonical
    count.
  - Mastery: a variant that takes the **lower** mastery under `cleared > blocked > fog` produces `fog` on a
    `(cleared, fog)` pair, where the real rule produces `cleared` — proving "higher wins" is load-bearing.
  - `correct_count`/`ladder_rung`: a variant that takes `min` instead of `max` produces a strictly lower
    value than the real rule on a pair with unequal inputs.
  - `last_probe`/`next_due`: a variant that takes the **earlier** day (and treats absent as *later* than any
    day, the literal opposite of the contract) produces a different day than the real rule on a pair with
    unequal, both-present values.
  - `remediated`: a variant using AND instead of OR produces `false` on the AC6(a) scenario (one side `true`,
    one side `false`), where the real rule produces `true`.
  - Marker tie-break: a variant that checks `course_code` **before** the unit-ordinal/past-last-unit
    priority produces a different winning side than the real rule on AC8(c)'s scenario, reconstructed with a
    `course_code` ordering that contradicts the unit-ordinal ordering (e.g. `a`'s course code is
    lexicographically smaller but its unit ordinal is strictly greater) — the wrong variant picks `b`, the
    real rule picks `a`.
  - `install_day`: a variant that takes the **later** day produces a different result than the real rule
    (`min`) whenever the two inputs' `installDay` values differ.
  - `format_version_seen`: a variant that takes the **lower** semver produces a different result than the
    real rule whenever the two inputs' values differ.
  - `consent_on`: a variant using OR instead of AND produces `true` on a pair where exactly one side is
    `false` — the real rule (AND) produces `false`.
- **T6 idempotency / no-leak:** `StateMerge.merge` and `StateMerge.canonicalise`, called twice with
  byte-identical, freshly-constructed argument values (never a reused mutated variable — both are `let`-bound
  value types, so no in-place mutation is structurally possible), return `Equatable`-equal results both
  times. Neither input value's fields differ before and after the call (trivially true for `let`-bound
  structs; asserted explicitly for documentation, mirroring 02.5's/02.6's own T6 disposition for
  non-persistence tasks). This task ships no writer of any kind.

## §6 Decision defaults

- IF `merge`'s output `schemaVersion` should propagate one of the two inputs' own `schemaVersion` values (say,
  `max(a.schemaVersion, b.schemaVersion)`) THEN it should not — the rule's own preamble states both inputs
  are "already migrated to the current `schema_version`" as a **precondition**, not something `merge` itself
  verifies or negotiates; re-pinning to the known current value (`2`, per `contracts/data-model.md:149`,
  quoted §3) keeps the function's output correct even in the degenerate case where a caller violates the
  precondition, without adding any validation logic that would turn this pure function into one with a
  boundary-rejection path it does not otherwise need (§4 step 6 — no error code exists here).
- IF the multiset-union merge (`mergeLogs`) should use an efficient `Dictionary`-keyed count (requiring
  `Hashable`, not just `Equatable`, on `ExpeditionLogEntry`/`ProbeLogEntry`) THEN it should not — neither
  type currently conforms to `Hashable` (confirmed by reading `Model/StudentState.swift` in this run: both
  are `Codable, Equatable` only), and adding `Hashable` conformance to either is out of this task's file
  scope (§2 — that file is task 02.2's). The `O(n²)` `Equatable`-only implementation (§4 step 3) is correct
  and simple; expedition/probe logs are small per sync event (RULE 2, Simplicity First).
- IF the "Winning side W" final tie-break's "the two values' canonical JSON encodings" should be read as
  comparing only the two `Marker` values' encodings (not the full `StudentState`) THEN the full-`StudentState`
  reading is used instead — the rule text's antecedent for "the two values" is ambiguous between "the two
  markers" (the immediately preceding subject) and "the two `StudentState`s" (`merge`'s own two arguments,
  named at the very start of the rule: "`merge(a, b)` is a pure `Core` function over two `StudentState`s").
  The full-`StudentState` reading is the more conservative, more deterministic choice — it resolves ties
  that a marker-only comparison could leave unresolved (e.g. identical markers, differing `syllabi`) — and
  `CoreCoding` is the contract-mandated "one JSON coder configuration" (`CoreCoding.swift:3-9`) for exactly
  this purpose.
- IF `Marker.pastLastUnit == nil` should rank differently from `Marker.pastLastUnit == false` in the marker
  tie-break THEN it should not — the rule text only distinguishes "`past_last_unit: true`" from "any unit";
  it names no separate treatment for `false` vs absent, so both are treated identically as "not past last
  unit" (`markerRank`'s `marker.pastLastUnit == true ? 1 : 0`, §4 step 4).
- IF `installDay`/log `day` string comparison should use `CalendarDay(iso:)` parsing (constructing a value,
  then comparing via `Comparable`) rather than raw `String` comparison THEN raw `String` comparison is used
  — `CalendarDay.Comparable`'s own implementation is `lhs.iso < rhs.iso` (`Time/CalendarDay.swift:36-38`,
  quoted §3), i.e. it is defined as string comparison; parsing first would add a fallible `init?` step (every
  `day` value is already a validated `YYYY-MM-DD` string by construction, decoded through `CoreCoding`) with
  no behavioural difference and an unhandled-`nil` risk this task's pure, non-throwing function should not
  carry.
- IF `PropertyGen`'s new `studentState` generator should also validate its generated `trail` against a real
  graph (e.g. `data/demo`) THEN it should not — the merge rule treats `trail` as opaque ("a derived cache the
  caller regenerates after merge", quoted §3); `merge`/`canonicalise` never inspect `Trail`'s contents beyond
  carrying the winning side's value through unchanged, so a graph-valid trail is not required for these
  property tests to be meaningful, and loading `data/demo` here would be an unnecessary dependency this
  task's out-of-scope list (§2) already excludes.
- IF the new `PropertyGen` generator functions should live in a new file (e.g. `PropertyGenStateMerge.swift`)
  rather than the existing `PropertyGen.swift` THEN they should not — the file's own header comment states
  the pattern explicitly: "Later tasks (02.5-02.7, 02.10-02.12) add their own generator functions to this
  same file/namespace rather than duplicating a parallel helper" (`Support/PropertyGen.swift:9-10`, quoted
  §3).

Standing defaults: identifiers and timestamps follow `contracts/data-model.md` (calendar days only, string
comparison, no sub-day timestamp anywhere in this task's code or tests); no model call exists anywhere in
this task's code (I2 not engaged); no field is added to `StudentState`/`NodeState`/`Marker`/
`ExpeditionLogEntry`/`ProbeLogEntry` by this task (I5) — `merge`/`canonicalise` return values built entirely
from the two inputs' own existing fields. Telemetry is unaffected — `consentOn`'s AND rule is already the
complete telemetry-consent behaviour this task implements (`telemetry.md` § Consent cross-reference, quoted
§3). No node's `paraphrase`/Ministry text is read or touched by this task (I6) — `merge` never reads a
`Node`, only `StudentState`.

## §7 Done definition

The task is done when ALL gates pass:

- `xcrun swift-format lint --strict --recursive --configuration .swift-format Packages App/Sources` — clean
  over the new file and the modified/new test files.
- `Core` build + test green: `( cd Packages/Core && swift build -c release --product core-cli )` and
  `( cd Packages/Core && xcodebuild test -quiet -scheme Core-Package -destination "$SIM"
  CODE_SIGNING_ALLOWED=NO )` (`scripts/gate.sh` gate 3, `$SIM` from `scripts/pick-simulator.sh`).
- All cases in §5 (T1–T6, AC1–AC12) pass.
- `PropertyGenTests.swift` (unmodified, 02.4's file) stays green — the new generator functions do not alter
  any existing generator's behaviour.
- No file under `Packages/Core/Sources/Core` contains the literal `Date()` (I14); `coreImportBoundary()`
  stays green.
- Conforms to every contract section cited in §3 (`contracts/data-model.md` v1.4.0 § StudentState merge,
  quoted from its normative source `tasks/arbitration/arbiter-02-predispatch.md:83-111`; `contracts/
  data-model.md:149`, § StudentState; `contracts/data-model.md:18-19`, § Identifiers; `docs/domains/
  platform.md:132-136`, § Q3) and to every invariant listed in §1 (I5, I14).
- `scripts/gate.sh` gate 1 and gate 3 green in full (gates 2 and 4 are pipeline/App-scoped and are
  unaffected by this task's file scope).
