# Epic 02 · Task 04: `CoreError` R-6 set, `CalendarDay`, mastery transitions, `CoreEvent`, seeded property-test support

---
epic: 02
task: 04
slug: core-error-calendar-day-mastery
kind: feat
risk: seam
depends_on: [02.2]
model: sonnet
---

## §1 Goal & acceptance criteria

Goal: `Core` gains five interface-first building blocks that every later Door B / Door A task in this EPIC
consumes without redefining: (1) the full R-6 `CoreError` set, (2) an injected `CalendarDay` value type with no
`Date()` call anywhere, (3) the `contracts/interaction-contract.md` §1 mastery-transition state machine —
`itemCorrect`, `itemMissReview`, `diagnosisBlocked` — implementing the ladder `[1, 3, 7, 14, 30]` with the last
rung repeating, (4) `CoreEvent`, a closed enum of every exact §5 notification name, and (5) `PropertyGen`, shared
seeded property-test generators built on the existing `SeededGenerator`. This task ships no expedition, trail,
fringe, or diagnosis machinery — those are tasks 02.5–02.7 and 02.10–02.12, which import these five pieces by
name.

**Precondition (hard dependency, not advisory):** task 02.2 must be merged before this task's code compiles or
its tests run — it adds `remediated: Bool?` to `NodeState` and `past_last_unit: Bool?` to `Marker`
(`tasks/context/epic-02-task-04-context.md` §A, §D, §F). This task's `MasteryTransitions.itemCorrect` reads and
clears `NodeState.remediated`; if 02.2 has not landed, that field does not exist and this task's code does not
compile. Do not add `remediated` yourself — that is 02.2's file scope (`StudentState.swift` is out of scope
here, see §2).

Invariants in play:

- **I1 (I10)** — this task performs no item checking (that is 02.7's `ItemChecker`); it is satisfied vacuously
  here — no free-text path exists anywhere in `MasteryTransitions`, which takes only an `itemId: String` (an
  opaque identifier, never parsed as an answer) and a `Set<String>` of prior correct item ids.
- **I2** — every function in this task's scope is Tier-0 deterministic; none calls or accepts a model/adapter
  argument; `MasteryTransitions`, `CalendarDay`, and `CoreEvent` compile with zero external dependencies beyond
  `Foundation`.
- **I3** — out of scope for this task's own acceptance (answer/`why` display is 02.7's `ItemChecker` result
  shape); satisfied structurally here by not touching any answer-carrying type.
- **I4** — the ladder and clear-rule constants this task ships (`MasteryTransitions.ladder`, the distinct-items
  guard) are the constants 02.6's fringe/backtrack logic reads; this task does not implement backtracking itself.
- **I5** — no field is added to `StudentState`/`NodeState`/`Marker` by this task (that is 02.2's, already
  landed as a precondition); `CoreEvent` payloads stay out of scope (§6 default) so no identifying data is ever
  attached to an event by this task's code; `MasteryTransitionResult` carries only a `NodeState` (ids, enums,
  booleans, calendar-day strings) and an optional `CoreEvent` case.
- **I14** — every new file lives under `Packages/Core/Sources/Core/{Time,State,Events}/`, imports `Foundation`
  only, and every function is a pure value transformation: `CalendarDay` performs day arithmetic via a
  proleptic-Gregorian civil-calendar algorithm (§4.2), never `Foundation.Calendar`/`Date()`/`TimeZone.current`.
  `today` is always an injected `CalendarDay` parameter, never computed inside `Core`. A grep for `Date\(\)`
  over `Sources/Core` stays at zero hits (already zero per the context bundle's negative fact; this task must
  not introduce the first one).

Acceptance criteria (each independently verifiable):

- AC1: `CoreError.allCases` gains exactly the ten R-6 cases — `expNoFringe = "EXP_NO_FRINGE"`,
  `expTrailInvalid = "EXP_TRAIL_INVALID"`, `expItemPoolEmpty = "EXP_ITEM_POOL_EMPTY"`,
  `expStateWriteFailed = "EXP_STATE_WRITE_FAILED"`, `expNodeNotInGraph = "EXP_NODE_NOT_IN_GRAPH"`,
  `diagNoPrerequisite = "DIAG_NO_PREREQUISITE"`, `diagProbeUnavailable = "DIAG_PROBE_UNAVAILABLE"`,
  `diagStateWriteFailed = "DIAG_STATE_WRITE_FAILED"`, `graphNoPrerequisite = "GRAPH_NO_PREREQUISITE"`,
  `mapMarkerOffTrail = "MAP_MARKER_OFF_TRAIL"` — appended after the seven existing cases, with the existing
  seven byte-unchanged. `ErrorRegistryTests` (unmodified) and `ErrorRegistryNegativeControlTests` (unmodified)
  both stay green with no edit to either file.
- AC2: `CalendarDay(iso:)` accepts every syntactically and calendrically valid `"YYYY-MM-DD"` string and rejects
  every other string (malformed shape, out-of-range month/day, a non-existent date such as `"2026-02-30"` or
  `"2026-13-01"`) by returning `nil`. `CalendarDay.adding(days:)` is correct across a month boundary, a year
  boundary, and a leap-year February (`"2028-02-28"` + 1 day = `"2028-02-29"`; `"2027-02-28"` + 1 day =
  `"2027-03-01"`). No file under `Sources/Core` contains the literal `Date()`.
- AC3: `MasteryTransitions.itemCorrect` on a `fog` or `blocked` node clears it (`mastery = .cleared`,
  `ladderRung = 0`, `nextDue = today.adding(days: 1).iso`, `remediated = nil`, emits `.expeditionNodeCleared`)
  exactly when the item id, unioned with the caller-supplied set of prior correct item ids on that node, reaches
  2 distinct ids — never on the same item id answered correctly twice in a row (the guard is on distinct items,
  per `contracts/interaction-contract.md` §1's `correct_count + 1 ≥ 2` on **distinct items**). Below that
  threshold, `correctCount` increments by 1, `lastProbe` updates to `today.iso`, mastery and `remediated` are
  unchanged, and no event is emitted.
- AC4: `MasteryTransitions.itemCorrect` on a `cleared` node (review) advances `ladderRung` by 1, clamped to the
  ladder's last index (4), sets `nextDue = today.adding(days: ladder[min(ladderRung, 4)]).iso`, and stays
  `cleared` with no event — the 30-day interval (`ladder[4]`) repeats once `ladderRung` reaches 4 and stays
  there.
- AC5: `MasteryTransitions.itemMissReview` on a `cleared` node resets `ladderRung = 0`,
  `nextDue = today.adding(days: 1).iso`, updates `lastProbe`, and the node stays `cleared` — fog never returns
  (map Q1).
- AC6: `MasteryTransitions.diagnosisBlocked` on a `fog` node sets `mastery = .blocked` and emits
  `.diagnosisNodeBlocked`; called on a node whose mastery is already `.blocked` or is `.cleared`, it returns the
  input `NodeState` unchanged with no event (§6 default — the contract's transition table defines only the
  `fog → blocked` row).
- AC7: `CoreEvent` defines exactly the 41 notification names of `contracts/interaction-contract.md` § 5, one
  case per name, each case's raw value the exact dotted string from the contract (e.g. `"expedition.node_cleared"`,
  `"diagnosis.node_blocked"`) — no name added, renamed, or omitted.
- AC8: `PropertyGen`'s generator functions (§4.5) are deterministic: calling the same function with the same
  `SeededGenerator` seed and the same call sequence produces byte-identical output across two separate test
  runs.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Core/Sources/Core/CoreError.swift` — MODIFY: append the ten R-6 cases (§1 AC1) after the existing
  seven; do not reorder or edit the existing cases or the file's header doc comment.
- `Packages/Core/Sources/Core/Time/CalendarDay.swift` — CREATE: the `CalendarDay` value type (§4.2).
- `Packages/Core/Sources/Core/State/MasteryTransitions.swift` — CREATE: the §1 mastery-transition functions and
  `MasteryTransitionResult` (§4.3).
- `Packages/Core/Sources/Core/Events/CoreEvent.swift` — CREATE: the closed `CoreEvent` enum (§4.4).
- `Packages/Core/Tests/CoreTests/Support/PropertyGen.swift` — CREATE: shared seeded property-test generators
  (§4.5). **Path correction:** the context bundle's §F lists this as `Tests/CoreTests/Support/PropertyGen.swift`
  (missing the `Packages/Core/` prefix); the repo's actual test root, confirmed by `Packages/Core/Package.swift`
  and the existing `Packages/Core/Tests/CoreTests/*.swift` files, is `Packages/Core/Tests/CoreTests/`. Use the
  path in this section, not the bundle's.
- `Packages/Core/Tests/CoreTests/MasteryTransitionsTests.swift` — CREATE: the companion test suite for
  `MasteryTransitions` (§5). Same path correction as above.
- `Packages/Core/Tests/CoreTests/CalendarDayTests.swift` — CREATE: the companion test suite for `CalendarDay`
  (§5). Same path correction as above.

Out-of-scope (do not touch even if tempted):

- `Packages/Core/Sources/Core/Model/StudentState.swift` — task 02.2's; this task reads `NodeState.remediated`
  and `NodeState`'s other fields unmodified. If the field is missing, that means 02.2 has not landed — BLOCK on
  the precondition, do not add the field here.
- `Packages/Core/Tests/CoreTests/ErrorRegistryTests.swift`,
  `Packages/Core/Tests/CoreTests/ErrorRegistryNegativeControlTests.swift` — both already iterate
  `CoreError.allCases` generically (confirmed by reading both files in this run); the ten new cases are covered
  automatically with no edit. Editing either file to "add a case" is a regression, not an improvement.
- `Packages/Core/Tests/CoreTests/CoreTests.swift` — the existing `coreImportBoundary()` test already walks
  `Sources/Core` recursively and will cover the three new `Time/`, `State/`, `Events/` subdirectories with no
  change.
- `contracts/interaction-contract.md`, `contracts/error-codes.json`, `contracts/error-codes.md`,
  `contracts/data-model.md` — all read-only ground truth for this task; every code this task mirrors is already
  registered (context bundle §G), so no contract bump is needed or permitted here.
- Fringe/`compose`, `set_marker`/`generate_trail`, the expedition run machine, the diagnosis machine, `merge` —
  tasks 02.5, 02.6, 02.7, 02.10, 02.11, 02.12 respectively. This task ships the types and functions those tasks
  call; it does not call them itself and ships no scheduler, no trail logic, no query, no diagnosis flow.
- `Packages/Core/Package.swift` — no new target, no `resources:` entry; `PropertyGen.swift` is read the same
  way every existing `CoreTests` file reads repo-relative paths (via `#filePath`), not via SPM resources.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/interaction-contract.md` — heading `## 1. Mastery (per node, in StudentState)` (re-read,
  byte-compared in this run):
  > States `fog → cleared`, `fog → blocked`, `blocked → cleared`, `cleared` stays `cleared` (map Q1: fog never
  > returns). Transitions:
  >
  > | From | Event | Guard | To | Side effects |
  > |---|---|---|---|---|
  > | fog / blocked | `item_correct(node)` | `correct_count + 1 ≥ 2` on **distinct items** (expedition Q1) | cleared | `next_due = today + ladder[0]`, `ladder_rung = 0`, emit `node_cleared` |
  > | fog / blocked | `item_correct(node)` | otherwise | same | `correct_count += 1` |
  > | cleared | `item_correct(node)` (review) | — | cleared | `ladder_rung += 1`, `next_due = today + ladder[rung]` |
  > | cleared | `item_miss(node)` (review) | — | cleared | `ladder_rung = 0`, `next_due = today + ladder[0]`; tolerance per §2 |
  > | fog | `diagnosis_blocked(node)` | — | blocked | emit `node_blocked` |
  >
  > Ladder = `[1, 3, 7, 14, 30]` days [ESTIMATE: expedition Q2]; the last rung repeats.

- `contracts/interaction-contract.md` — heading `## 5. Notifications (in-process names, exact)` (re-read,
  byte-compared in this run):
  > `map.opened · map.node_opened · map.region_opened · map.landmark_opened · map.marker_moved ·
  > map.check_here_requested · map.include_requested · map.unit_expedition_requested · expedition.started ·
  > expedition.item_answered · expedition.diagnosis_requested · expedition.node_cleared · expedition.node_due ·
  > expedition.marker_changed · expedition.trail_generated · expedition.completed · diagnosis.opened ·
  > diagnosis.hypothesis_formed · diagnosis.probe_completed · diagnosis.node_blocked · diagnosis.capped ·
  > diagnosis.remediation_shown · diagnosis.returned · platform.launched · platform.content_updated ·
  > platform.state_migrated · platform.state_written · platform.sync_completed ·
  > platform.sync_conflict_merged · platform.capability_facts · platform.connectivity_changed ·
  > tier.capability_detected · tier.classification_returned · tier.fallback_decided · tier.wording_adapted ·
  > telemetry.consent_changed · telemetry.batch_sent · telemetry.batch_failed · learning_objects.bundle_loaded ·
  > learning_objects.hint_tier_served · graph.prerequisite_returned`
  >
  > Payloads are ids, enums, booleans and small integers only (I5).

- `contracts/error-codes.md` — heading `## Rules` (re-read, byte-compared in this run):
  > - Prefixes are fixed per domain: `MAP`, `EXP`, `DIAG`, `GRAPH`, `LO`, `SPINE`, `GEN`, `PLATFORM`, `TELEM`,
  >   `TIER`, `VERIFY` (M5). A code appears in exactly one domain doc and in the registry.
  > - `Core` defines `enum CoreError: String` mirroring the `GRAPH`, `EXP`, `MAP` (validation) and `DIAG`
  >   codes; the App and the pipeline each map their own. A code raised in code but absent from the registry
  >   fails the round-trip test.

- `contracts/data-model.md` — heading `## Time`-scoped bullet (re-read, byte-compared in this run):
  > Dates in state and telemetry are **calendar days** (`YYYY-MM-DD`, device-local) — never finer (I5). Bundle
  > provenance uses ISO 8601 UTC timestamps. No sub-day timestamp exists in any transmitted shape.

- `contracts/data-model.md` — § StudentState field list (re-read, byte-compared in this run):
  > `schema_version`, `format_version_seen`, `syllabi[]` (course codes), `marker {course_code, unit_id}`,
  > `nodes {node_id → {mastery ∈ {fog, cleared, blocked}, correct_count, last_probe?, next_due?, ladder_rung}}`,
  > `trail {segments[] {kind ∈ {course, extension}, course_code?, node_ids[]}}` (derived, cached),

  (task 02.2 adds `remediated?` to the `nodes` entry per the arbiter's Q-A ruling — this task treats that as a
  precondition fact, not something it re-derives.)

- `tasks/arbitration/arbiter-02-predispatch.md` — Q-A ruling, normative text for the mastery-table side effect
  (re-read, byte-compared in this run):
  > § 1 Mastery, in the row `fog / blocked | item_correct(node) | … | cleared`, append ", remove `remediated`"
  > to the side effects.

Prior signatures this task builds on (from the codebase, verbatim, re-read in this run):

```swift
// Packages/Core/Sources/Core/CoreError.swift:10-18
public enum CoreError: String, Error, CaseIterable {
    case graphL0Failed = "GRAPH_L0_FAILED"
    case mapLayoutMissing = "MAP_LAYOUT_MISSING"
    case mapRegionUnknown = "MAP_REGION_UNKNOWN"
    case mapLandmarkUnsourced = "MAP_LANDMARK_UNSOURCED"
    case spineUnitEmpty = "SPINE_UNIT_EMPTY"
    case spineSourceRefUnresolved = "SPINE_SOURCE_REF_UNRESOLVED"
    case platformBundleIntegrityFailed = "PLATFORM_BUNDLE_INTEGRITY_FAILED"
}
```

```swift
// Packages/Core/Sources/Core/Model/StudentState.swift:28-34 (NodeState, pre-02.2)
public struct NodeState: Codable, Equatable {
    public let mastery: Mastery
    public let correctCount: Int
    public let lastProbe: String?
    public let nextDue: String?
    public let ladderRung: Int
}

public enum Mastery: String, Codable {
    case fog
    case cleared
    case blocked
}
```

By this task's implementation time, task 02.2 has added `public let remediated: Bool?` to `NodeState` (absent
= false, per the Q-A ruling quoted above). This task's code references `NodeState.remediated` and constructs
`NodeState` values with all six fields including `remediated`.

```swift
// Packages/Core/Sources/Core/Layout/SeededGenerator.swift:6-20
public struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    public init(seed: UInt64) { self.state = seed }
    public mutating func next() -> UInt64 { ... }
}
```

Gate commands (verbatim, from `scripts/gate.sh`, re-read in this run):

```sh
echo "== 1/4 format + lint =="
xcrun swift-format lint --strict --recursive --configuration "$ROOT/.swift-format" "$ROOT/Packages" "$ROOT/App/Sources"

echo "== 3/4 Core: build + test on the iOS simulator (D29) =="
( cd "$ROOT/Packages/Core" && swift build -c release --product core-cli )
( cd "$ROOT/Packages/Core" && xcodebuild test -quiet -scheme Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO )
```

Test framework (confirmed by `Packages/Core/Tests/CoreTests/CoreTests.swift:1-2`, re-read in this run): Swift
Testing (`import Testing`, `@Suite`, `@Test`, `#expect`), not XCTest.

## §4 Implementation outline

Layer placement: layer ④ interaction — this task ships the mastery half of expedition W4 (`docs/domains/
expedition.md`) plus the shared value types (`CalendarDay`, `CoreEvent`) and test infrastructure the rest of
layer ④'s `Core` code depends on. It reads nothing from layers ①–③; it operates purely on `NodeState` values
the caller supplies.

### 4.1 `Packages/Core/Sources/Core/CoreError.swift`

Append, after `platformBundleIntegrityFailed`, in this exact order:

```swift
    case expNoFringe = "EXP_NO_FRINGE"
    case expTrailInvalid = "EXP_TRAIL_INVALID"
    case expItemPoolEmpty = "EXP_ITEM_POOL_EMPTY"
    case expStateWriteFailed = "EXP_STATE_WRITE_FAILED"
    case expNodeNotInGraph = "EXP_NODE_NOT_IN_GRAPH"
    case diagNoPrerequisite = "DIAG_NO_PREREQUISITE"
    case diagProbeUnavailable = "DIAG_PROBE_UNAVAILABLE"
    case diagStateWriteFailed = "DIAG_STATE_WRITE_FAILED"
    case graphNoPrerequisite = "GRAPH_NO_PREREQUISITE"
    case mapMarkerOffTrail = "MAP_MARKER_OFF_TRAIL"
```

No case is thrown by any code this task ships — `MasteryTransitions`, `CalendarDay`, and `CoreEvent` are all
non-throwing. These ten cases exist here purely as the registry mirror later tasks (02.5, 02.6, 02.7, 02.10,
02.11) throw.

### 4.2 `Packages/Core/Sources/Core/Time/CalendarDay.swift`

```swift
public struct CalendarDay: Equatable, Hashable, Comparable, Sendable {
    public let iso: String

    public init?(iso: String) { ... }
    public func adding(days: Int) -> CalendarDay { ... }
    public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool { lhs.iso < rhs.iso }
}
```

`iso` is always the canonical zero-padded `"YYYY-MM-DD"` (10 characters). `Comparable` is lexicographic string
comparison — valid because two zero-padded ISO-8601 date strings of equal length sort lexicographically in the
same order they sort chronologically; do not implement a calendar-aware comparator, it is unnecessary and adds
a second, redundant source of truth.

`init?(iso:)`: parse with a regex or manual scan for `^\d{4}-\d{2}-\d{2}$`; on a shape match, parse
`(year, month, day)` as integers and run them through `daysFromCivil` then `civilFromDays` (below); if the
round trip does not reproduce the same `(year, month, day)`, the date does not exist (e.g. `2026-02-30`) — fail
to `nil`. This makes the validity check exact rather than an approximate day-count table.

`adding(days:)`: parse `iso` to `(y, m, d)`, compute `z = daysFromCivil(y, m, d) + days`, convert back with
`civilFromDays(z)`, format the result as zero-padded `"YYYY-MM-DD"` (`String(format: "%04d-%02d-%02d", ...)`
or equivalent manual zero-padding — do not use `DateFormatter`, which reads `Locale.current`/`TimeZone.current`
by default unless explicitly pinned, and pinning it is strictly more code than the arithmetic below for no
benefit).

Day-count arithmetic — Howard Hinnant's proleptic-Gregorian civil-calendar algorithm (public domain,
<http://howardhinnant.github.io/date_algorithms.html>), pure integer math, no `Foundation.Calendar` and no
`Date` of any kind:

```swift
/// Days since 1970-01-01 (may be negative). `m` is 1...12, `d` is 1...31.
private func daysFromCivil(_ y: Int, _ m: Int, _ d: Int) -> Int {
    let y2 = y - (m <= 2 ? 1 : 0)
    let era = (y2 >= 0 ? y2 : y2 - 399) / 400
    let yoe = y2 - era * 400                                   // [0, 399]
    let doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1    // [0, 365]
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy             // [0, 146096]
    return era * 146097 + doe - 719468
}

/// Inverse of `daysFromCivil`.
private func civilFromDays(_ z: Int) -> (y: Int, m: Int, d: Int) {
    let z2 = z + 719468
    let era = (z2 >= 0 ? z2 : z2 - 146096) / 146097
    let doe = z2 - era * 146097                                             // [0, 146096]
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365         // [0, 399]
    let y = yoe + era * 400
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)                       // [0, 365]
    let mp = (5 * doy + 2) / 153                                            // [0, 11]
    let d = doy - (153 * mp + 2) / 5 + 1                                    // [1, 31]
    let m = mp + (mp < 10 ? 3 : -9)                                         // [1, 12]
    return (y: m <= 2 ? y + 1 : y, m: m, d: d)
}
```

### 4.3 `Packages/Core/Sources/Core/State/MasteryTransitions.swift`

```swift
public struct MasteryTransitionResult: Equatable {
    public let nodeState: NodeState
    public let event: CoreEvent?
}

public enum MasteryTransitions {
    public static let ladder: [Int] = [1, 3, 7, 14, 30]

    /// Dispatches on `current.mastery` per the contract's §1 table:
    /// - `.fog`/`.blocked` → the "new-learning" rows (clear-rule guard on distinct items).
    /// - `.cleared` → the "review" row (ladder advance, no clear-rule guard, `itemId`/`correctItemIds`
    ///   are ignored).
    public static func itemCorrect(
        current: NodeState,
        itemId: String,
        correctItemIds: Set<String>,
        today: CalendarDay
    ) -> MasteryTransitionResult { ... }

    /// The `cleared | item_miss(node) (review)` row only. Called on a node whose `mastery != .cleared`,
    /// this is a no-op (§6 default): returns `current` unchanged, `event: nil`.
    public static func itemMissReview(
        current: NodeState,
        today: CalendarDay
    ) -> MasteryTransitionResult { ... }

    /// The `fog | diagnosis_blocked(node) | — | blocked` row only. Called on a node whose
    /// `mastery != .fog`, this is a no-op (§6 default): returns `current` unchanged, `event: nil`.
    public static func diagnosisBlocked(current: NodeState) -> MasteryTransitionResult { ... }
}
```

`itemCorrect` behaviour, precisely:

1. `current.mastery == .fog || current.mastery == .blocked`:
   - `let distinctCorrect = correctItemIds.union([itemId])`
   - `let newCorrectCount = current.correctCount + 1` (docs/domains/expedition.md W4: "correct → increment
     `correct_count`" happens unconditionally, before the clear check).
   - `if distinctCorrect.count >= 2`: return `NodeState(mastery: .cleared, correctCount: newCorrectCount,
     lastProbe: today.iso, nextDue: today.adding(days: ladder[0]).iso, ladderRung: 0, remediated: nil)` with
     `event: .expeditionNodeCleared`. `correctCount` is NOT reset on clear — the contract's side-effect column
     for this row lists only `next_due`, `ladder_rung`, and the emit; nothing resets `correct_count` (§6
     default).
   - else: return `NodeState(mastery: current.mastery, correctCount: newCorrectCount, lastProbe: today.iso,
     nextDue: current.nextDue, ladderRung: current.ladderRung, remediated: current.remediated)` with
     `event: nil`. `remediated` is untouched — only the clearing branch ever writes it, and only to `nil`.
2. `current.mastery == .cleared` (review):
   - `let newRung = min(current.ladderRung + 1, ladder.count - 1)`
   - return `NodeState(mastery: .cleared, correctCount: current.correctCount, lastProbe: today.iso,
     nextDue: today.adding(days: ladder[newRung]).iso, ladderRung: newRung, remediated: current.remediated)`
     with `event: nil`.

`itemMissReview` behaviour: if `current.mastery == .cleared`, return `NodeState(mastery: .cleared, correctCount:
current.correctCount, lastProbe: today.iso, nextDue: today.adding(days: ladder[0]).iso, ladderRung: 0,
remediated: current.remediated)` with `event: nil`; else return `MasteryTransitionResult(nodeState: current,
event: nil)` unchanged (§6 default).

`diagnosisBlocked` behaviour: if `current.mastery == .fog`, return `NodeState(mastery: .blocked, correctCount:
current.correctCount, lastProbe: current.lastProbe, nextDue: current.nextDue, ladderRung: current.ladderRung,
remediated: current.remediated)` with `event: .diagnosisNodeBlocked`; else return
`MasteryTransitionResult(nodeState: current, event: nil)` unchanged (§6 default).

### 4.4 `Packages/Core/Sources/Core/Events/CoreEvent.swift`

```swift
public enum CoreEvent: String, CaseIterable, Equatable {
    case mapOpened = "map.opened"
    case mapNodeOpened = "map.node_opened"
    case mapRegionOpened = "map.region_opened"
    case mapLandmarkOpened = "map.landmark_opened"
    case mapMarkerMoved = "map.marker_moved"
    case mapCheckHereRequested = "map.check_here_requested"
    case mapIncludeRequested = "map.include_requested"
    case mapUnitExpeditionRequested = "map.unit_expedition_requested"
    case expeditionStarted = "expedition.started"
    case expeditionItemAnswered = "expedition.item_answered"
    case expeditionDiagnosisRequested = "expedition.diagnosis_requested"
    case expeditionNodeCleared = "expedition.node_cleared"
    case expeditionNodeDue = "expedition.node_due"
    case expeditionMarkerChanged = "expedition.marker_changed"
    case expeditionTrailGenerated = "expedition.trail_generated"
    case expeditionCompleted = "expedition.completed"
    case diagnosisOpened = "diagnosis.opened"
    case diagnosisHypothesisFormed = "diagnosis.hypothesis_formed"
    case diagnosisProbeCompleted = "diagnosis.probe_completed"
    case diagnosisNodeBlocked = "diagnosis.node_blocked"
    case diagnosisCapped = "diagnosis.capped"
    case diagnosisRemediationShown = "diagnosis.remediation_shown"
    case diagnosisReturned = "diagnosis.returned"
    case platformLaunched = "platform.launched"
    case platformContentUpdated = "platform.content_updated"
    case platformStateMigrated = "platform.state_migrated"
    case platformStateWritten = "platform.state_written"
    case platformSyncCompleted = "platform.sync_completed"
    case platformSyncConflictMerged = "platform.sync_conflict_merged"
    case platformCapabilityFacts = "platform.capability_facts"
    case platformConnectivityChanged = "platform.connectivity_changed"
    case tierCapabilityDetected = "tier.capability_detected"
    case tierClassificationReturned = "tier.classification_returned"
    case tierFallbackDecided = "tier.fallback_decided"
    case tierWordingAdapted = "tier.wording_adapted"
    case telemetryConsentChanged = "telemetry.consent_changed"
    case telemetryBatchSent = "telemetry.batch_sent"
    case telemetryBatchFailed = "telemetry.batch_failed"
    case learningObjectsBundleLoaded = "learning_objects.bundle_loaded"
    case learningObjectsHintTierServed = "learning_objects.hint_tier_served"
    case graphPrerequisiteReturned = "graph.prerequisite_returned"
}
```

41 cases, one per name in the §5 quote (§3), in the same left-to-right order the contract lists them, so a
future contract diff is trivially diffable against this file. `CoreEvent` is a bare name registry — it carries
no payload (§6 default). `MasteryTransitions` pairs a `CoreEvent` with its `NodeState` via
`MasteryTransitionResult`; later tasks that need a node id or other payload alongside an event define their own
pairing type the same way, rather than this task growing `CoreEvent` an associated value.

### 4.5 `Packages/Core/Tests/CoreTests/Support/PropertyGen.swift`

Test-target file (default `internal` access — no `public` needed; every later `CoreTests` file that wants these
functions is compiled into the same `CoreTests` target and can call them directly).

```swift
import Foundation

@testable import Core

/// Deterministic seeded generators for property-based tests across `CoreTests`, built on the existing
/// `SeededGenerator` (`Sources/Core/Layout/SeededGenerator.swift`). Every function takes
/// `inout SeededGenerator` so a whole property-test run advances one deterministic stream and is exactly
/// reproducible from its seed. No function here reads the system clock or any non-deterministic source.
/// Later tasks (02.5-02.7, 02.10-02.12) add their own generator functions to this same file/namespace
/// rather than duplicating a parallel helper (§6 default).
enum PropertyGen {
    /// A day inside `2024-01-01 ... 2029-12-31` — wide enough for any ladder/`next_due` arithmetic a
    /// property test in this EPIC exercises, narrow enough to keep string comparisons in `CalendarDay`
    /// meaningful across a small, human-inspectable range.
    static func calendarDay(_ gen: inout SeededGenerator) -> CalendarDay

    static func mastery(_ gen: inout SeededGenerator) -> Mastery

    /// A uniformly-drawn element of `pool`. `pool` must be non-empty; an empty `pool` is a test-authoring
    /// bug, not a runtime case to guard — traps via `precondition`, matching this file's test-only status.
    static func element<T>(_ gen: inout SeededGenerator, from pool: [T]) -> T

    static func bool(_ gen: inout SeededGenerator, trueWeight: Double) -> Bool

    static func int(_ gen: inout SeededGenerator, in range: ClosedRange<Int>) -> Int

    /// A syntactically valid `NodeState`: `ladderRung` drawn from `0...4`, `correctCount` from `0...3`,
    /// `lastProbe`/`nextDue` derived from `today` (both present, `nextDue` `0...30` days after `today`, so
    /// generated fixtures exercise the "due" and "not yet due" cases roughly evenly), `remediated` set only
    /// when the drawn `mastery == .blocked` (per the Q-A field contract — a generator that could produce
    /// `remediated == true` on a `.cleared`/`.fog` node would generate a StudentState the encode/decode
    /// round trip could still accept but the field's own semantics forbid, so this is a deliberate
    /// generator-level guard, not decoding validation).
    static func nodeState(_ gen: inout SeededGenerator, today: CalendarDay) -> NodeState

    /// One `nodeState(_:today:)` per id in `nodeIds`, keyed by id.
    static func nodesMap(
        _ gen: inout SeededGenerator, nodeIds: [String], today: CalendarDay
    ) -> [String: NodeState]
}
```

Implementation notes: use `Int.random(in:using:)` / `Double.random(in:using:)` / `Bool.random(using:)` with the
`inout SeededGenerator` — the standard library's `using:` overloads accept any `RandomNumberGenerator` and read
no system entropy, so this stays deterministic without hand-rolling bit-extraction arithmetic (unlike
`CalendarDay`'s day math, there is no reason to avoid the stdlib here — `SeededGenerator` itself is the
determinism boundary).

### 4.6 Smoke check

`( cd Packages/Core && swift build -c release --product core-cli )` — must be green (compiles the three new
`Sources/Core/{Time,State,Events}/*.swift` files even though `CoreCLI`'s `main.swift` calls none of them yet).

## §5 Test plan (risk: seam — full plan)

- T1 happy path:
  - `itemCorrect` on a `fog` node with `correctItemIds = ["item-a"]` and `itemId = "item-b"` clears it:
    `mastery == .cleared`, `ladderRung == 0`, `nextDue == today.adding(days: 1).iso`, `remediated == nil`,
    `event == .expeditionNodeCleared` (AC3).
  - `itemCorrect` on a `cleared` node with `ladderRung == 2` advances to `ladderRung == 3`,
    `nextDue == today.adding(days: 14).iso`, `event == nil` (AC4); repeated past `ladderRung == 4` stays at 4
    with `nextDue == today.adding(days: 30).iso` every time (the "last rung repeats" property).
  - `itemMissReview` on a `cleared` node with `ladderRung == 3` resets to `ladderRung == 0`,
    `nextDue == today.adding(days: 1).iso`, stays `cleared` (AC5).
  - `diagnosisBlocked` on a `fog` node sets `mastery == .blocked`, `event == .diagnosisNodeBlocked` (AC6).
- T2 negative — invalid input rejected at the boundary:
  - `CalendarDay(iso: "2026-02-30")`, `CalendarDay(iso: "2026-13-01")`, `CalendarDay(iso: "26-01-01")`,
    `CalendarDay(iso: "2026/01/01")` all return `nil` (AC2).
  - `itemCorrect` on a `fog` node called twice with the **same** `itemId` and `correctItemIds` reflecting only
    that one prior correct id (i.e. `correctItemIds == [itemId]`) never clears — `distinctCorrect.count == 1`,
    guard fails, `mastery` unchanged (AC3's "never on the same item id" clause).
  - `itemMissReview` called on a `fog` or `blocked` node is a no-op: returns the input unchanged, `event ==
    nil` (§6 default, AC6 sibling case).
- T3 error-taxonomy: a table-driven test asserts each of the ten new `CoreError` raw values equals its exact
  registry string from `contracts/error-codes.json` (`EXP_NO_FRINGE`, `EXP_TRAIL_INVALID`, `EXP_ITEM_POOL_EMPTY`,
  `EXP_STATE_WRITE_FAILED`, `EXP_NODE_NOT_IN_GRAPH`, `DIAG_NO_PREREQUISITE`, `DIAG_PROBE_UNAVAILABLE`,
  `DIAG_STATE_WRITE_FAILED`, `GRAPH_NO_PREREQUISITE`, `MAP_MARKER_OFF_TRAIL`); `ErrorRegistryTests` and
  `ErrorRegistryNegativeControlTests` (both unmodified) stay green (AC1).
- T4 conformance per requirements §B.1 (brief §5 "I5: `StudentState` closed field set... extended if a BUMP adds
  a field"; "I14: pure functions; import boundary"):
  - property test over `PropertyGen`-generated `(NodeState, itemId, correctItemIds, CalendarDay)` tuples:
    once a node is `.cleared`, no sequence of `itemCorrect`/`itemMissReview` calls this task's functions expose
    ever returns `mastery != .cleared` (fog never returns, map Q1).
  - property test: every `MasteryTransitionResult` whose `event == .expeditionNodeCleared` has
    `nodeState.ladderRung == 0` and `nodeState.nextDue == today.adding(days: 1).iso`.
  - property test: `nodeState.ladderRung` is always in `0...4` across any sequence of review calls, for any
    generated starting `ladderRung` in `0...4`.
  - a dedicated grep test (distinct from `CoreTests.swift`'s import-boundary scan) asserts zero occurrences of
    the literal `Date()` across every `.swift` file under `Sources/Core`, using the same recursive-enumerator
    pattern `coreImportBoundary()` already uses (an empty file scan is itself a FAIL, per that precedent).
- T5 negative control for every regression guard:
  - reconstruct (locally, in the test file — do not modify product code) a mastery-clear check that counts
    `correctItemIds.count + 1 >= 2` instead of `correctItemIds.union([itemId]).count >= 2`, and prove it wrongly
    clears when the same `itemId` is submitted twice — this is the negative control for AC3's "never on the
    same item id" property, proving the distinct-items guard is load-bearing and not accidentally satisfied by
    a count-based check that would also pass the T1 happy-path case.
  - reconstruct a 4-element ladder (`[1, 3, 7, 14]`) locally and prove that clamping `ladderRung` to
    `ladder.count - 1 == 3` yields `nextDue == today.adding(days: 14)` at the cap, differing from the real
    5-element ladder's `today.adding(days: 30)` — the negative control for AC4's "last rung repeats at 30 days,
    not 14" property.
  - `CalendarDay`'s round-trip validation: reconstruct a regex-only validator (no `daysFromCivil`/`civilFromDays`
    round trip) and prove it wrongly accepts `"2026-02-30"` — the negative control for AC2's "calendrically
    valid, not just shape-valid" property.
- T6 idempotency / no-leak: `itemCorrect`, `itemMissReview`, and `diagnosisBlocked` are pure — calling each
  twice with byte-identical arguments (constructed fresh each call, not reusing a mutated variable) returns
  `Equatable`-equal `MasteryTransitionResult` values both times. `CalendarDay.adding(days: n).adding(days: -n)`
  round-trips to the original `iso` for `n` drawn from `PropertyGen.int(_:in: -400...400)`, across year and
  leap-year boundaries.

## §6 Decision defaults

- IF `diagnosisBlocked` or `itemMissReview` is called on a node whose mastery does not match the contract row's
  origin state (not `.fog` for `diagnosisBlocked`; not `.cleared` for `itemMissReview`) THEN return the input
  `NodeState` unchanged with `event: nil` — a defensive no-op. The mastery-transition table
  (`contracts/interaction-contract.md` § 1, quoted in §3) defines no other origin for either event; the callers
  that will exist once 02.7/02.11 land already guarantee the precondition before calling, so this is a pure
  safety net, not a path any correct caller reaches.
- IF `correctCount` should be reset when a node clears THEN it is not reset — the contract's side-effect column
  for the clearing row lists only `next_due`, `ladder_rung = 0`, and `emit node_cleared`
  (`contracts/interaction-contract.md` § 1); `docs/domains/expedition.md` W4 (quoted in §3's byte-compare)
  confirms `correct_count` increments unconditionally before the clear check runs, with no reset step anywhere
  in W4.
- IF `CalendarDay`'s day arithmetic needs a calendar backend THEN it is the pure-integer proleptic-Gregorian
  civil-calendar algorithm of §4.2, not `Foundation.Calendar`/`Date` — even a `Calendar(identifier: .gregorian)`
  pinned to an explicit UTC `TimeZone` would satisfy the literal "no `Date()`" grep, but the civil-calendar
  formulas remove any Foundation-Calendar object (and its locale/timezone-adjacent surface) from `Core`
  entirely, which is the more conservative reading of I14 ("`Core` is renderer-free and single-source" —
  extended here to "no hidden device-configuration read of any kind").
- IF the ladder's last index is reached (`ladderRung == 4`) and a further review-correct event fires THEN
  `ladderRung` stays clamped at 4 and `nextDue` keeps advancing by `ladder[4] == 30` days each time — per
  `contracts/interaction-contract.md` § 1's "the last rung repeats" and brief AC1's "the rung caps at 4 with the
  last interval repeating."
- IF a non-clearing correct answer (`itemCorrect`'s "otherwise" row) or a `diagnosisBlocked` call needs to
  decide what happens to `NodeState.remediated` THEN it is left byte-unchanged — only the clearing branch of
  `itemCorrect` ever writes it, and only to `nil` (the Q-A ruling's normative text, quoted in §3, scopes the
  removal to exactly that row); writing `remediated = true` is diagnosis W4's job (task 02.11), out of this
  task's scope entirely.
- IF `CoreEvent` should carry payload data (which node cleared, which node blocked) THEN this task does not add
  it — § 5 of the contract (quoted in §3) defines `CoreEvent` as a closed set of notification **names**;
  payloads are a separate concern the contract scopes to "ids, enums, booleans and small integers," and this
  task's own need (pairing an event with the resulting `NodeState`) is already met by `MasteryTransitionResult`
  without extending `CoreEvent` itself. A later task that needs a different pairing defines its own result type
  the same way, rather than adding an associated value to every `CoreEvent` case.
- IF a downstream task (02.5-02.7, 02.10-02.12) needs a `PropertyGen` generator this task does not ship (a
  random graph, a random `StudentState`, a random `Marker`) THEN it adds that function to this same
  `PropertyGen.swift` file/namespace rather than creating a parallel `PropertyGen2`/`TestSupport`/similar file —
  per the plan's "shared seeded property-test support," this file is the one home for seeded test-data
  generation across `CoreTests` (`docs/plans/epic-02-plan.md` § 02.4 task scope).

Standing defaults: identifiers and timestamps follow `contracts/data-model.md` (calendar days only, no
sub-day timestamp — enforced structurally by `CalendarDay` never accepting anything finer than `YYYY-MM-DD`);
no model call exists anywhere in this task's code (I2); no field is added to `StudentState`/`NodeState`/`Marker`
by this task (I5) — task 02.2 owns the one field this task depends on; `CoreEvent` payloads stay out of scope
per the default above, so no identifying data is ever attached to an event by this task's code.

## §7 Done definition

The task is done when ALL gates pass:

- `xcrun swift-format lint --strict --recursive --configuration .swift-format Packages App/Sources` — clean over
  the five new files and the modified `CoreError.swift`.
- `Core` build + test green: `( cd Packages/Core && swift build -c release --product core-cli )` and
  `( cd Packages/Core && xcodebuild test -quiet -scheme Core-Package -destination "$SIM"
  CODE_SIGNING_ALLOWED=NO )` (`scripts/gate.sh` gate 3, `$SIM` from `scripts/pick-simulator.sh`).
- All cases in §5 (T1-T6) pass.
- `ErrorRegistryTests` and `ErrorRegistryNegativeControlTests` stay green with no edit to either file (AC1).
- No file under `Packages/Core/Sources/Core` contains the literal `Date()` (I14, AC2).
- Conforms to every contract section cited in §3 (`contracts/interaction-contract.md` § 1 Mastery and § 5
  Notifications; `contracts/error-codes.md` § Rules; `contracts/data-model.md` § Time and § StudentState) and to
  every invariant listed in §1 (I1/I10, I2, I3, I4, I5, I14).
- `scripts/gate.sh` gates 1 and 3 green in full (gates 2 and 4 are pipeline/App-scoped and are unaffected by
  this task's file scope).
