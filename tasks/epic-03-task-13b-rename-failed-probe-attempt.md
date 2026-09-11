# Epic 03 · Task 13b: rename `FailedProbeAttempt` → `ItemMiss` per the domain glossary

---
epic: 03
task: 13b
slug: rename-failed-probe-attempt
kind: refactor
risk: seam
depends_on: [02.10, 02.11]
model: sonnet
---

> **Origin.** `docs/audits/cross-epic-01-03.md` F1 (RED, blocks EPIC 04) as ruled in
> `tasks/arbitration/arbiter-03-audit-f1-attempt.md` (verdict B). Task 02.10 (commit `addb1a1`) coined the
> public `Core` type `FailedProbeAttempt`, and task 02.11 added the members `incorrectAttempts` and
> `failedAttempts`. Both names break `contracts/domain-glossary.md`: the concept already has a glossary
> term, **Miss**; "fail" for an item is banned; and "attempt" is banned.
>
> **Branch.** `epic-03b-map-app`, as the last EPIC 03 task, before any EPIC 04 task is dispatched. Commit
> subject: `refactor(core): rename FailedProbeAttempt to ItemMiss per the domain glossary`.
>
> **R-7 classification:** cause `spec-gap`. The task corrects 02.10 and 02.11 (`Classify.swift`,
> `DiagnosisEvent.swift`) and is rework with **no behaviour change**.

## §1 Goal & acceptance criteria

Goal: rename these identifiers throughout `Packages/Core`, changing no behaviour, and add a guard test so
the word cannot return to `Core` sources.

| Old | New |
|---|---|
| type `FailedProbeAttempt` | `ItemMiss` |
| `Classify.classify(_ attempts:)` and its loop variable `attempt` | `classify(_ misses:)`, loop variable `miss` |
| `DiagnosisProbeResult.incorrectAttempts` (public) | `misses` |
| `ProbeInProgress.incorrectAttempts` and `FurtherLevelOffer.incorrectAttempts` (internal) | `misses` |
| the `DiagnosisRun.start`/`run` argument label `failedAttempts:` | `misses:` |
| internal `DiagnosisRun.classify(_ attempts:)` | `classify(_ misses:)` |

Invariants in play:

- **I1**: `Classify` stays a lookup over already-known-wrong answers and never decides correctness.
  `ItemChecker.check` is untouched.
- **I2**: no model call is added. The Tier-0 classifier and its `"none_of_these"` abstention token are
  byte-identical in behaviour.
- **I4**: `DiagnosisRun`'s budget logic (`offered`, W6) is untouched, and the existing budget tests pass
  unchanged apart from the renamed labels.
- **I5**: `ItemMiss` carries the same two fields (`item: ProbeItem`, `submittedValue: String`) and no
  identifier.
- **I14**: `Core` still imports Foundation only. No file outside `Packages/Core` changes.

Acceptance criteria:

- **AC1 (renamed, source).** After the change, the grep `grep -rniE "attempt|FailedProbe"
  Packages/Core/Sources/Core` returns **0 lines**.
  - Instrument: that grep. It excludes `Packages/Core/Tests`, which is covered by AC2.
  - Empty = PASS.
  - The instrument is confirmed live because the same grep returns 34 lines before the change: 11 in
    `Classify.swift` and 23 in `DiagnosisEvent.swift`.
- **AC2 (renamed, tests).** The grep `grep -nE
  "FailedProbeAttempt|incorrectAttempts|failedAttempts|missedAttempts|emptyAttempts|\battempts?\b"` over
  the six test files in §2 returns **0 lines**.
  - Instrument: that grep over those six files only.
  - Empty = PASS.
  - Excluded: `L0CheckerContractTests.swift:275` and `StudentStateStoreConformanceTests.swift:171,179`. They
    use the English verb "attempted"/"attempting" and name no glossary concept
    (`tasks/arbitration/arbiter-03-audit-f1-attempt.md` § Ruling 2). They are not in §2.
- **AC3 (new API compiles).**
  - `ItemMiss(item:submittedValue:)` is `public`, as is `Classify.classify(_ misses: [ItemMiss]) -> String`.
  - `DiagnosisProbeResult.misses` is `public let misses: [ItemMiss]`.
  - `DiagnosisRun.start(event:misses:shownItemIdsInRun:state:bundle:)` and
    `DiagnosisRun.run(trigger:originNodeId:misses:levelBudget:decisions:shownItemIdsInRun:state:bundle:today:)`
    are public.
  - Instrument: `xcodebuild test -scheme Core-Package` (gate 3) compiles the whole test target against
    these exact signatures.
- **AC4 (no behaviour change).** Every pre-existing test in the six §2 test files passes, with only the
  identifier edits of §4.4 applied: the assertions, fixtures, expected values and test count stay the same
  (test functions are renamed, never removed).
  - Instrument: gate 3. It excludes a physical device (D29).
- **AC5 (guard).** The new `CoreGlossaryAttemptGuardTests.swift` passes, and here empty = FAIL: it scans at
  least one `.swift` file under `Packages/Core/Sources/Core`, recursively, and finds no case-insensitive
  `attempt` and no `FailedProbe` in any file's full text (identifiers, comments and string literals).
- **AC6 (guard negative control).** In the same file, a test runs the guard's own `violations(in:)`
  function over the pre-rename declaration `public struct FailedProbeAttempt: Equatable {` and expects both
  `"attempt"` and `"FailedProbe"`. Over `for miss in misses {` it expects an empty result.
- **AC7 (scope).** `git diff --stat` for the task commit lists exactly the 9 paths in §2 and no others.
  - Instrument: `git diff --stat HEAD~1`.
  - This excludes `tasks/**`: the EPIC 04 spec edits of §8 are the orchestrator's, not this task's.
- **AC8 (gates).** `scripts/gate.sh` exits 0.

## §2 File scope

In scope (the implementer touches exactly these):

- `Packages/Core/Sources/Core/Diagnosis/Classify.swift` — MODIFY: the whole file is replaced by §4.1.
- `Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift` — MODIFY: the line edits in §4.2 only.
- `Packages/Core/Tests/CoreTests/ClassifyTests.swift` — MODIFY: §4.4.
- `Packages/Core/Tests/CoreTests/DiagnosisMachineTests.swift` — MODIFY: §4.4.
- `Packages/Core/Tests/CoreTests/DiagnosisMachineBoundaryTests.swift` — MODIFY: §4.4.
- `Packages/Core/Tests/CoreTests/DiagnosisTier0CompletenessTests.swift` — MODIFY: §4.4.
- `Packages/Core/Tests/CoreTests/ExpeditionDiagnosisSeamTests.swift` — MODIFY: §4.4.
- `Packages/Core/Tests/CoreTests/MapViewModelTests.swift` — MODIFY: §4.4.
- `Packages/Core/Tests/CoreTests/CoreGlossaryAttemptGuardTests.swift` — CREATE: §4.5. This is the companion
  test that guards the rename.

Out of scope (do not touch, even if tempted):

- `contracts/**`. No contract names these identifiers: a case-insensitive grep of `contracts/` for
  `attempt` hits only `domain-glossary.md:40`, the ban itself.
- `docs/**`, including the audit report, `docs/plans/epic-04-plan.md:96-97` and
  `docs/domains/learning-objects.md:95` (arbiter ruling § Resolution record).
- `tasks/**`. The EPIC 04 edits in §8 are applied by the orchestrator before EPIC 04 is dispatched.
- `App/**`. A grep of `App/**/*.swift` for `attempt` returns 0 today.
- `pipeline/**`. `landmarks.py`'s `attempts` is an HTTP-retry count, not a glossary concept (arbiter
  ruling § Ruling 2).
- `L0CheckerContractTests.swift` and `StudentStateStoreConformanceTests.swift`, which contain English-verb
  prose only (AC2 note).
- `Support/PropertyGen.swift`, which contains no `FailedProbeAttempt` (grep of `Packages/**/*.swift`).
- The Xcode project file, which is never edited: `Packages/Core` is a package and needs no project change.

## §3 Inputs (verbatim)

The binding contract is `contracts/domain-glossary.md` (v1.0.0). Its header block reads:

> One agreed term per concept. Every EPIC, type, JSON key, screen label and doc uses the same word. Code
> identifiers are the term in `PascalCase` (types) / `camelCase` (Swift members) / `snake_case` (JSON,
> Python). **Banned synonyms** are listed so the grep gate can catch drift.

§ Expedition (Door B):

> - **Item** (`ProbeItem`) — one numeric or multiple-choice question with a `why` (I10). *Banned:* "question", "exercise", "task".

> - **Retry** — the second item on the same node after a miss (D27). **Miss** — an incorrect answer. **Clear** — reaching the clear rule (two correct on distinct items). *Banned:* "fail" for an item (fail is a probe outcome), "pass a node".

§ Diagnosis (Door A):

> - **Diagnosis event** — one Door A occurrence, from an expedition second miss or "Check me here". *Banned:* "tutoring session", "attempt".

> - **Probe** — two items on the candidate, ~60 s; outcome **pass / fail / declined** → diagnosis outcome **refuted / confirmed / unconfirmed / capped**.

From the domain doc `docs/domains/diagnosis.md`, § W1 — Open a diagnosis event:

> 2. (Tier 0) Classify the miss deterministically: the failed items' `distractor_error_types`
> (learning-objects) name an `ErrorType` when the wrong answer matches a tagged distractor; otherwise
> `none_of_these` (abstention).

And § Invariants enforced here:

> - **I2 — co-owner with runtime-tiers.** The hypothesis path is model-free; W1's classifier is a lookup over
>   tagged distractors; M3 is entirely Tier 0. A test runs every workflow with the adapter absent.

The arbitration `tasks/arbitration/arbiter-03-audit-f1-attempt.md` § Ruling 4 sets the name table in §1.

The current code, verbatim, is `Packages/Core/Sources/Core/Diagnosis/Classify.swift:1-43`:

```swift
import Foundation

/// One failed probe attempt: the `ProbeItem` the student got wrong, and the value they submitted for it
/// (a normalised numeric string for `.numeric` items, a choice id for `.mc` items — never free text,
/// I10). Normalisation of a numeric submission is the caller's responsibility (task 02.7's expedition run
/// machine); `Classify.classify` performs exact string equality only.
public struct FailedProbeAttempt: Equatable {
    public let item: ProbeItem
    public let submittedValue: String

    public init(item: ProbeItem, submittedValue: String) {
        self.item = item
        self.submittedValue = submittedValue
    }
}

/// Diagnosis W1 step 2: the Tier-0 distractor-tag classifier. A pure lookup over already-known-wrong
/// answers — it never decides correctness (I1) and never calls a model (I2).
public enum Classify {
    /// Returns the `errorTypeId` of the first attempt (in `attempts` order) whose submitted value matches
    /// a tagged `wrongAnswers[].value` (`.numeric` items) or a tagged `choices[].id` (`.mc` items) on that
    /// attempt's own item. `"none_of_these"` if no attempt matches.
    public static func classify(_ attempts: [FailedProbeAttempt]) -> String {
        for attempt in attempts {
            switch attempt.item.type {
            case .numeric:
                if let match = (attempt.item.wrongAnswers ?? []).first(where: {
                    $0.value == attempt.submittedValue
                }) {
                    return match.errorTypeId
                }
            case .mc:
                for choice in attempt.item.choices ?? [] {
                    guard choice.id == attempt.submittedValue, let errorTypeId = choice.errorTypeId else {
                        continue
                    }
                    return errorTypeId
                }
            }
        }
        return "none_of_these"
    }
}
```

`Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift` has every `attempt`-bearing line listed with
its replacement in §4.2. That list is exhaustive per a case-insensitive grep, which returns 23 lines.

## §4 Implementation outline

Layer: ④ interaction. This is the Door A Tier-0 classifier and the diagnosis machine, in `Core` only.

### 4.1 `Classify.swift`: replace the whole file

```swift
import Foundation

/// One miss (`contracts/domain-glossary.md`: "**Miss** — an incorrect answer"): the `ProbeItem` the
/// student answered incorrectly, and the value they submitted for it (a normalised numeric string for
/// `.numeric` items, a choice id for `.mc` items — never free text, I10). Normalisation of a numeric
/// submission is the caller's responsibility (task 02.7's expedition run machine); `Classify.classify`
/// performs exact string equality only.
public struct ItemMiss: Equatable {
    public let item: ProbeItem
    public let submittedValue: String

    public init(item: ProbeItem, submittedValue: String) {
        self.item = item
        self.submittedValue = submittedValue
    }
}

/// Diagnosis W1 step 2: the Tier-0 distractor-tag classifier. A pure lookup over already-known-wrong
/// answers — it never decides correctness (I1) and never calls a model (I2).
public enum Classify {
    /// Returns the `errorTypeId` of the first miss (in `misses` order) whose submitted value matches a
    /// tagged `wrongAnswers[].value` (`.numeric` items) or a tagged `choices[].id` (`.mc` items) on that
    /// miss's own item. `"none_of_these"` if no miss matches.
    public static func classify(_ misses: [ItemMiss]) -> String {
        for miss in misses {
            switch miss.item.type {
            case .numeric:
                if let match = (miss.item.wrongAnswers ?? []).first(where: {
                    $0.value == miss.submittedValue
                }) {
                    return match.errorTypeId
                }
            case .mc:
                for choice in miss.item.choices ?? [] {
                    guard choice.id == miss.submittedValue, let errorTypeId = choice.errorTypeId else {
                        continue
                    }
                    return errorTypeId
                }
            }
        }
        return "none_of_these"
    }
}
```

### 4.2 `DiagnosisEvent.swift`: line edits only (nothing else in the file changes)

| Line | Before (verbatim fragment) | After |
|---|---|---|
| 33 | `public let incorrectAttempts: [FailedProbeAttempt]` | `public let misses: [ItemMiss]` |
| 75 | `let incorrectAttempts: [FailedProbeAttempt]` | `let misses: [ItemMiss]` |
| 83 | `let incorrectAttempts: [FailedProbeAttempt]` | `let misses: [ItemMiss]` |
| 134 | ``/// W1 + W2 at the first level. `originErrorTypeId = classify(failedAttempts)`; for `map_check_here` `` | ``/// W1 + W2 at the first level. `originErrorTypeId = classify(misses)`; for `map_check_here` `` |
| 135 | ``/// the caller passes `failedAttempts: []` (so `originErrorTypeId == "none_of_these"`) and`` | ``/// the caller passes `misses: []` (so `originErrorTypeId == "none_of_these"`) and`` |
| 138 | `event: DiagnosisEvent, failedAttempts: [FailedProbeAttempt], shownItemIdsInRun: Set<String>,` | `event: DiagnosisEvent, misses: [ItemMiss], shownItemIdsInRun: Set<String>,` |
| 141 | `let originErrorTypeId = classify(failedAttempts)` | `let originErrorTypeId = classify(misses)` |
| 160 | `outcome: .declined, results: [], incorrectAttempts: [], code: nil)` | `outcome: .declined, results: [], misses: [], code: nil)` |
| 180 | `outcome: .unavailable, results: [], incorrectAttempts: [], code: .diagProbeUnavailable)` | `outcome: .unavailable, results: [], misses: [], code: .diagProbeUnavailable)` |
| 191 | `incorrectAttempts: [])` | `misses: [])` |
| 207 | `var incorrectAttempts = probe.incorrectAttempts` | `var misses = probe.misses` |
| 209 | `incorrectAttempts.append(FailedProbeAttempt(item: item, submittedValue: submitted))` | `misses.append(ItemMiss(item: item, submittedValue: submitted))` |
| 216 | `levelResults: levelResults, incorrectAttempts: incorrectAttempts)` | `levelResults: levelResults, misses: misses)` |
| 222 | `guard !incorrectAttempts.isEmpty else {` | `guard !misses.isEmpty else {` |
| 224 | `outcome: .refuted, results: levelResults, incorrectAttempts: [], code: nil)` | `outcome: .refuted, results: levelResults, misses: [], code: nil)` |
| 239 | `outcome: .confirmed, results: levelResults, incorrectAttempts: incorrectAttempts, code: nil)` | `outcome: .confirmed, results: levelResults, misses: misses, code: nil)` |
| 267 | `incorrectAttempts: incorrectAttempts)` | `misses: misses)` |
| 276 | `originId: probe.candidateId, biasErrorTypeId: classify(incorrectAttempts),` | `originId: probe.candidateId, biasErrorTypeId: classify(misses),` |
| 330 | `queryOriginId: offer.candidateId, biasErrorTypeId: classify(offer.incorrectAttempts),` | `queryOriginId: offer.candidateId, biasErrorTypeId: classify(offer.misses),` |
| 338 | `trigger: DiagnosisTrigger, originNodeId: String, failedAttempts: [FailedProbeAttempt],` | `trigger: DiagnosisTrigger, originNodeId: String, misses: [ItemMiss],` |
| 344 | `event: event, failedAttempts: failedAttempts, shownItemIdsInRun: shownItemIdsInRun,` | `event: event, misses: misses, shownItemIdsInRun: shownItemIdsInRun,` |
| 377 | `static func classify(_ attempts: [FailedProbeAttempt]) -> String {` | `static func classify(_ misses: [ItemMiss]) -> String {` |
| 378 | `Classify.classify(attempts)` | `Classify.classify(misses)` |

Keep the property order of `DiagnosisProbeResult` (`outcome`, `results`, `misses`, `code`), because its
memberwise initializer is positional by label. Keep `ProbeInProgress` and `FurtherLevelOffer` in their
current order as well.

### 4.3 Error codes, events and model paths

- No registry code is added, removed or re-mapped. `.diagProbeUnavailable` and `.diagNoPrerequisite` are
  emitted exactly as before.
- No `CoreEvent` changes.
- There is no model call, so no threshold and no fallback applies. The task is deterministic Tier 0 only.

### 4.4 Test-file edits: identifier replacements only

Every edit below is a textual rename. No assertion, fixture or expected value changes.

- **`ClassifyTests.swift`**
  - Lines 41, 49, 65 and 84: `let attempt = FailedProbeAttempt(` becomes `let miss = ItemMiss(`.
  - Lines 42, 50, 66 and 85: `[attempt]` becomes `[miss]`. Line 85 has two occurrences.
  - Line 72: `func emptyAttemptsReturnsUnderscoreSentinel()` becomes
    `func emptyMissesReturnsUnderscoreSentinel()`.
- **`DiagnosisMachineTests.swift`**
  - Every `failedAttempts:` label becomes `misses:`. There are 29 occurrences, at lines 157, 182, 222, 255,
    302, 346, 365, 417, 473, 547, 584, 629, 653, 667, 690, 706, 722, 743, 762, 765, 787, 810, 832, 835,
    847, 883, 896, 1005 and 1028.
  - Line 206: `incorrectAttempts: []` becomes `misses: []`.
- **`DiagnosisMachineBoundaryTests.swift`**
  - Lines 167, 221, 263, 300, 372 and 389: `failedAttempts:` becomes `misses:`.
- **`DiagnosisTier0CompletenessTests.swift`**
  - Lines 61, 72, 87, 100, 114 and 169: `failedAttempts:` becomes `misses:`.
- **`MapViewModelTests.swift`**
  - Line 346: `failedAttempts:` becomes `misses:`.
- **`ExpeditionDiagnosisSeamTests.swift`**
  - Line 85: the comment `the missed items become FailedProbeAttempts` becomes
    `the missed items become ItemMisses`.
  - Line 87: `let missedAttempts = [` becomes `let misses = [`.
  - Lines 88 and 91: `FailedProbeAttempt(` becomes `ItemMiss(`.
  - Line 98: `failedAttempts: missedAttempts,` becomes `misses: misses,`.

If swift-format re-wraps a line after a label shortens, accept its output (gate 1).

### 4.5 `CoreGlossaryAttemptGuardTests.swift`: create

```swift
import Foundation
import Testing

@testable import Core

/// Glossary guard (`contracts/domain-glossary.md`; `tasks/arbitration/arbiter-03-audit-f1-attempt.md`):
/// no `.swift` file under `Packages/Core/Sources/Core` carries the banned word "attempt" (any case, any
/// position — identifiers, comments and string literals alike) or the retired type-name stem
/// "FailedProbe". The concept is named **Miss** ("an incorrect answer"), e.g. `ItemMiss`.
@Suite("Core glossary guard — no \"attempt\" in Core sources")
struct CoreGlossaryAttemptGuardTests {
    private static var coreSourcesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root (Packages/Core)
            .appendingPathComponent("Sources/Core")
    }

    /// The guard's rule, isolated so the negative control exercises the exact function the real scan uses.
    static func violations(in text: String) -> [String] {
        var found: [String] = []
        if text.lowercased().contains("attempt") { found.append("attempt") }
        if text.contains("FailedProbe") { found.append("FailedProbe") }
        return found
    }

    @Test("no .swift file under Packages/Core/Sources/Core contains \"attempt\" or \"FailedProbe\"")
    func coreSourcesCarryNoAttempt() throws {
        let enumerator = try #require(
            FileManager.default.enumerator(at: Self.coreSourcesDir, includingPropertiesForKeys: nil))
        var scanned = 0
        var offenders: [String] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            scanned += 1
            let text = try String(contentsOf: url, encoding: .utf8)
            for word in Self.violations(in: text) {
                offenders.append("\(url.lastPathComponent): \(word)")
            }
        }
        #expect(scanned > 0, "instrument broken: no .swift file under \(Self.coreSourcesDir.path)")
        #expect(offenders.isEmpty, "banned glossary word in Core sources: \(offenders)")
    }

    @Test("guard is load-bearing: the pre-rename declaration fails it (negative control)")
    func guardNegativeControl() {
        let preRename = "public struct FailedProbeAttempt: Equatable {"
        let found = Self.violations(in: preRename)
        #expect(found.contains("attempt"))
        #expect(found.contains("FailedProbe"))
        #expect(Self.violations(in: "for miss in misses {").isEmpty)
    }
}
```

The path resolution mirrors the landed pattern at `MapLaunchGapTests.swift:12-19` (`#filePath`, climbing
from `CoreTests`). Swift Testing is the runner that `docs/tech-stack.md` names for gate 3.

### 4.6 Smoke

Run `scripts/gate.sh`. It runs gates 1 to 4 of `docs/tech-stack.md` § 3: swift-format and ruff; pyright;
the `core-cli` build and the `Core-Package`/`Rendering` tests on the iOS simulator; the App build and
pytest.

## §5 Test plan (risk: seam)

- **T1, happy path.** `ClassifyTests` AC4 round-trips every tagged wrong answer and distractor in
  `data/demo` through `classify([ItemMiss])`. `ExpeditionDiagnosisSeamTests` shows two real expedition
  misses becoming `ItemMiss` values and opening a real `DiagnosisRun.start(event:misses:…)`.
- **T2, negatives.**
  - (a) `ClassifyTests` AC5: an unmatched submission returns `"none_of_these"`.
  - (b) `emptyMissesReturnsUnderscoreSentinel`: `classify([])` returns `"none_of_these"`, never
    `"none-of-these"`.
  - (c) The `DiagnosisMachineTests` declined and unavailable branches construct
    `DiagnosisProbeResult(…, misses: [], …)` and assert the terminal and code unchanged.
- **T3, error taxonomy.** The existing assertions still pass under the renamed labels:
  `DIAG_PROBE_UNAVAILABLE` → `.diagProbeUnavailable` (`DiagnosisEvent.swift:180`, asserted in
  `DiagnosisMachineTests` and `DiagnosisMachineBoundaryTests`), and `DIAG_NO_PREREQUISITE` →
  `.diagNoPrerequisite`. No new code is added.
- **T4, B.1 conformance.** `docs/domains/diagnosis.md` has no header named "Conformance tests". Its
  § Invariants enforced here is the conformance surface, and the existing suites (listed below) keep
  covering every item on it under the new names.
  - **I2** ("A test runs every workflow with the adapter absent") is covered by
    `DiagnosisTier0CompletenessTests`.
  - **I4** (property test "none beyond depth 2") is covered by the `DiagnosisMachineTests` budget
    property test at lines 883–1028.
  - **I1/I10**, **I3** and **I5** are covered by `DiagnosisMachineTests` and
    `DiagnosisMachineBoundaryTests`.
- **T5, negative control for every regression guard.** AC6 (`guardNegativeControl`) shows the new guard
  goes red on the pre-rename declaration and stays quiet on the new shape.
- **T6, real composition across a seam.** `ExpeditionDiagnosisSeamTests` exercises the expedition ↔
  diagnosis seam with real `ExpeditionRun.answer` and `DiagnosisRun` calls, none stubbed.
- **T7, idempotency.** The idempotency test in `ClassifyTests` (`[miss]` passed twice) is unchanged in
  substance. The task has no state mutation and adds no persisted field.
- **Device.** Physical-device verification is the owner's at the wrap gate (D29). Agents verify on the
  simulator only.

## §6 Decision defaults

- IF a shorter or longer type name is considered (`Miss`, `ProbeItemMiss`, `FailedProbe`), THEN use
  `ItemMiss`.
  - It composes two glossary terms, **Item** and **Miss**, per the header rule "Code identifiers are the
    term in `PascalCase`".
  - `FailedProbe` is rejected because "Probe" is two items on a candidate and "fail" for an item is
    banned (arbiter ruling § Ruling 3).
- IF a member name is unclear, THEN use `misses` for every `[ItemMiss]` member, argument label and local,
  and `miss` for a single element.
  - The same names apply in the public field, the internal fields, both argument labels and the locals.
  - This follows `docs/domains/diagnosis.md` W1: "Classify the miss deterministically".
- IF a word "attempt" appears in a `Core` doc comment as plain English, THEN reword it anyway. AC1 and the
  guard scan full text, because a comment in Door A code that says "attempt" is the drift the grep gate
  exists to catch.
- IF swift-format changes wrapping, THEN accept it. Never hand-format against the formatter.

## §7 Done definition

- AC1–AC8 are verified.
- `scripts/gate.sh` exits 0.
- There is one commit with the subject `refactor(core): rename FailedProbeAttempt to ItemMiss per the
  domain glossary`, touching exactly the 9 §2 paths.
- The result conforms to `contracts/domain-glossary.md` (header, § Expedition "Miss", § Diagnosis ban
  list). No contract is changed.

## §8 EPIC 04 references to update before EPIC 04 dispatch (orchestrator, not the implementer)

After this task lands, the new guard (§4.5) fails on any `Core` source that contains "attempt". EPIC 04's
Door façades live under `Packages/Core/Sources/Core/`, so these spec and context edits are **mandatory**
before any EPIC 04 task is dispatched.

Use the same mapping everywhere:

| Old | New |
|---|---|
| `FailedProbeAttempt` | `ItemMiss` |
| `incorrectAttempts` | `misses` |
| `failedAttempts` (label and variable) | `misses` |
| `pendingHandoffAttempts` | `pendingHandoffMisses` |
| `thisAttempt` | `thisMiss` |
| local `attempts` | `misses` |
| `classify(_ attempts:` | `classify(_ misses:` |
| `selectRemediation(candidate:incorrectAttempts:)` | `selectRemediation(candidate:misses:)` |

The line numbers are from a grep of each file in this run.

**Task specs:**

- **`tasks/epic-04-task-03-core-door-a-diagnosis-flow.md`**
  - Lines 58, 95, 99, 167, 168, 261, 291, 297, 315, 340, 346, 520, 521, 530, 568, 572, 574, 642 and 667.
  - At 340, `public struct FailedProbeAttempt` becomes `public struct ItemMiss`. At 346, the quoted
    `classify` signature becomes `classify(_ misses: [ItemMiss])`.
  - At 58, "two real `FailedProbeAttempt`s" becomes "two real `ItemMiss`es".
- **`tasks/epic-04-task-04-core-door-b-expedition-flow.md`**
  - Lines 19, 66, 68, 70, 131, 309, 339, 458, 463, 481, 531, 532, 534, 568, 574, 695 and 696.
  - At 568, `if let attempts = pending.pendingHandoffAttempts,` becomes
    `if let misses = pending.pendingHandoffMisses,`.
  - At 574, `failedAttempts: attempts,` becomes `misses: misses,`.
  - At 695, "`failedAttempts` is built from the single available attempt only (`[thisAttempt]`)" becomes
    "`misses` is built from the single available miss only (`[thisMiss]`)".
  - Also re-quote the `Classify.swift` doc and struct text from §4.1 wherever the spec quotes it verbatim.
- **`tasks/epic-04-task-05-core-door-entries-persistence-seam.md`**
  - Lines 144, 428, 441, 498 and 748.
  - At 428, `let pendingFirstMiss: FailedProbeAttempt?` becomes `let pendingFirstMiss: ItemMiss?`.
- **`tasks/epic-04-task-08-app-expedition-screens.md`**
  - Line 367: `let pendingHandoffAttempts: [FailedProbeAttempt]?` becomes
    `let pendingHandoffMisses: [ItemMiss]?`.

**Context bundles:**

- **`tasks/context/epic-04-task-03-context.md`**
  - Lines 143, 148, 152 and 157.
  - At 157, the quoted source becomes `Classify.swift:7–15`, and the type name changes.
- **`tasks/context/epic-04-task-04-context.md`**
  - Lines 57, 157, 161, 182 and 232.
  - At 57, "the two failed attempts" becomes "the two misses".
  - At 157, re-quote `public struct ItemMiss: Equatable { … }`.
  - At 182, the recorded grep pattern becomes `misses|suspendedForDiagnosis`.
  - At 232, the check becomes "**ItemMiss** (`Classify.swift:7–15`)".
- **`tasks/context/epic-04-task-09-context.md`**
  - Line 108: `start(event: DiagnosisEvent, misses: [ItemMiss], …)`.

**Not to update:**

- `tasks/epic-04-task-09-app-diagnosis-screens.md:639,644` and `tasks/context/epic-04-task-11-context.md:31`
  quote the glossary ban itself, and quoting it is correct.
- `tasks/epic-04-task-10-app-sources-door-scan.md:709` is the English verb "does not attempt" in spec
  prose about an App-side scan. It names no glossary concept and lies outside this guard's scope.

After the edits, a re-grep of `FailedProbeAttempt|incorrectAttempts|failedAttempts|pendingHandoffAttempts|thisAttempt`
over `tasks/epic-04-*` and `tasks/context/epic-04-*` must return 0 (empty = PASS). Because these are
mechanical identifier substitutions with no behavioural change, re-review of the affected specs is at
the orchestrator's discretion.
