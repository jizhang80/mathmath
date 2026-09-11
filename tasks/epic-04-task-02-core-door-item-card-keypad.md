# Epic 04 · Task 02: Core Door screen-content values — item card, answer card, keypad key set

---
epic: 04
task: 02
slug: core-door-item-card-keypad
kind: feat
risk: seam
depends_on: [none]
model: sonnet
---

## §1 Goal & acceptance criteria

Goal: Implement, in `Core`, the plain value types shared by both Doors B and A that carry a probe item's
screen content and its answer card, plus the numeric keypad's key-set constant. These are the input the
Door B façade (task 04.4) and the Door A façade (task 04.3) hand to the render layer: an item view that
carries a prompt, an input kind, an optional choice list and a retry flag — and never an answer value or a
`correct_choice_id` (I1, I10) — and an answer card built only from a checked `ItemResult`, carrying the
correct answer, its display kind (LaTeX or plain), the why, and an optional extra-line slot that a later
task (04.4) fills with the Q5 line. The keypad key set is a `Core` constant covering the full numeric
grammar (`contracts/interaction-contract.md` § 2 "Numeric normalisation").

Invariants in play:
- **I1** — `DoorItemContent` never stores `answer`, `answer.value`, `correctChoiceId` or any field that
  would let the render layer decide correctness; only `ItemChecker` (already landed) decides pass/fail, and
  this task calls it only from tests, never from the value types themselves. A `Mirror`-based test asserts
  the field is absent, with a planted-field negative control proving the scan is meaningful.
- **I10** — the item view's input kind is `numeric` or `multipleChoice` only (mirroring `ProbeItemType`);
  the keypad key set is a `Core` constant covering the entire numeric grammar (sign, digits, `.`, `/`), and
  a test asserts it types every `numeric` `answer.value` in `data/demo`.
- **I14** — every type in this file is a plain, `Equatable`, Foundation-only value type (no `@Observable`,
  no SwiftUI); the render layer renders these values, it never computes them. The recursive `Core`
  import-boundary test (`CoreTests.swift`) picks up the new file automatically and stays green.
- **I3** (inherited, not newly asserted here — the façade tasks assert it end to end) — the answer-card
  value this task defines is capable of carrying a non-empty `correctAnswerDisplay` and `why` on every real
  `ItemResult`; that capability is proven here over `data/demo`, so the façade tasks can build on it without
  re-deriving the shape.

Acceptance criteria (each independently verifiable):

- AC1: `DoorItemContent(nodeId:item:isRetry:)`, and the convenience `DoorItemContent(from: CurrentItem)`,
  produce, for every `ProbeItem` in every node of the real `data/demo` bundle: `promptLatex == item.promptLatex`;
  `inputKind == .numeric` for a `numeric` item and `.multipleChoice` for an `mc` item; `choices == []` for a
  `numeric` item; `choices` for an `mc` item equal to `item.choices!.map { DoorItemChoice(id: $0.id, latex:
  $0.latex) }`, in the same order; `isRetry` equal to the value passed in.
- AC2: `Mirror(reflecting:)` over a `DoorItemContent` built from an `mc` item (which carries a
  `correctChoiceId`) and from a `numeric` item (which carries an `answer`) reports no child label in
  `{"answer", "answerValue", "value", "correctChoiceId", "correctChoiceID"}`. A planted-field negative
  control — the same scan run over a synthetic fixture type that does carry a stored `answer` field — proves
  the scan actually catches such a field (`docs/lessons.md` §16 quote-fidelity discipline does not apply
  here, but the same "prove the guard is meaningful" discipline does, per `ImportBoundaryNegativeControlTests.swift`'s
  precedent shape).
- AC3: `DoorAnswerCardContent(result:itemType:extraLine:)`, built for every `data/demo` item from two real
  `ItemResult`s obtained by calling the landed `ItemChecker.check`/`correctAnswerDisplay` — one with the
  item's own correct submission, one with a submission that misses — yields: `correct` equal to the check
  outcome; `correctAnswerDisplay` and `why` both non-empty; `correctAnswerDisplayKind == .plain` when
  `itemType == .numeric` and `== .latex` when `itemType == .mc`; `extraLine == nil` when the parameter is
  omitted, and equal to the passed value otherwise.
- AC4: `DoorKeypad.numericKeypadKeys` contains every character (`"0"`–`"9"`, `"+"`, `"-"`, `"."`, `"/"`) that
  appears in any `numeric` item's `answer.value` in `data/demo`: for every such value, every one of its
  characters is a member of `DoorKeypad.numericKeypadKeys` (empty `data/demo` numeric-item set = FAIL). A
  negative control asserts that a key set with `"/"` removed does **not** cover
  `rational-numbers-1`'s value `5/6`.
- AC5: `Packages/Core/Sources/Core/Door/DoorItemContent.swift` imports `Foundation` only (grep), and the
  existing recursive `Core` import-boundary test in `CoreTests.swift` (unmodified by this task) still passes
  with the new file present.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Core/Sources/Core/Door/DoorItemContent.swift` — CREATE. Holds `DoorItemContent`,
  `DoorItemInputKind`, `DoorItemChoice`, `DoorAnswerCardContent`, `DoorAnswerDisplayKind`, `DoorKeypad`.
  Plain value types, Foundation only, no `@Observable`, no SwiftUI. Confirmed absent: no `Door/` directory
  and no file named `*ItemView*.swift`/`*AnswerCard*.swift`/`*Keypad*.swift` exists under
  `Packages/Core/Sources/Core/` on the current tree (`Glob Packages/Core/Sources/Core/**` for those
  patterns — empty).
- `Packages/Core/Tests/CoreTests/DoorItemContentTests.swift` — CREATE. This task's own companion test suite
  (AC1–AC5), over the real `data/demo` bundle plus constructed fixtures for the negative controls, following
  the `ItemCheckerTests.swift` / `ImportBoundaryNegativeControlTests.swift` shape.

Out-of-scope (do not touch even if tempted):

- `Packages/Core/Sources/Core/ItemChecker.swift`, `Packages/Core/Sources/Core/State/ExpeditionRun.swift`,
  `Packages/Core/Sources/Core/Model/Nodes.swift` — call their existing public members only; no edit.
- `Packages/Core/Sources/Core/Diagnosis/*.swift` — task 02.11's `DiagnosisRun`/`ProbeInProgress` is not
  landed on this tree yet (only `Classify.swift` exists under `Diagnosis/`; confirmed by `Glob
  Packages/Core/Sources/Core/Diagnosis/*.swift`). This task adds no dependency on that file: it derives
  probe-item screen content from a `ProbeItem` and a node/candidate id string, primitives any caller can
  supply, not from the phase type itself (§6).
- `Packages/Core/Sources/Core/CoreError.swift`, `Packages/Core/Sources/Core/Events/CoreEvent.swift` — this
  task throws no error and emits no event; no new case is needed.
- `contracts/**`, `docs/**`, `data/demo/**`, `App/**` — read-only inputs to this task.
- The Door A hypothesis card, probe orchestration, remediation selector, hint resolver and terminal-line
  constants — task 04.3, not this task.
- The Door B façade (Start expedition, answer, continue, retry, end/abandon) — task 04.4, not this task.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/interaction-contract.md` — heading `## 2. Expedition (Door B)`, the `answer(item)` bullet and
  the "Numeric normalisation" bullet (verified on disk, `contracts/interaction-contract.md:38-52`):
  > - `answer(item)`: deterministic check (expedition Q4: normalised exact match, per-item tolerance; `mc`
  >   by choice id); always show correct answer + `why` (I3); log `probe_log`; emit `item_answered`.
  > - **Numeric normalisation (expedition Q4):** a submitted numeric answer and the item's `answer.value`
  >   (`data-model.md` § ProbeItem) are each parsed under the same grammar before comparison: an optional
  >   leading sign (`+` or `-`; absent = positive), one or more digits, an optional `.` followed by one or
  >   more digits, and an optional `/` followed by one or more digits (a rational `a/b`, `b ≠ 0`); leading
  >   and trailing whitespace is stripped and has no other effect. A string that does not parse under this
  >   grammar is a **miss** — never a crash, never a retry that skips its item. Every value that parses is
  >   reduced to an **exact rational**: leading zeros in the integer part (`007`) and trailing zeros after
  >   the decimal point (`0.750`) carry no significance; a decimal parses to its exact fraction (`0.75 =
  >   3/4`). Two parsed values match iff their exact-rational values are equal, or their absolute difference
  >   is ≤ the item's `answer.tolerance` (non-negative, default `0`, per `data-model.md` § ProbeItem).
  >   Comparison is exact-rational arithmetic; no floating-point comparison is used anywhere in this rule
  >   (I1). This is the entire `numeric`-item rule; `mc` items are compared by `choices[].id` only, never by
  >   value (I10).

  Binds this task: the keypad key set is derived from this grammar (sign, digits, `.`, `/`) and must cover
  every character a student might submit.

- `contracts/interaction-contract.md` — heading `## 2. Expedition (Door B)`, "Properties (CoreTests)" bullet
  (verified on disk, `contracts/interaction-contract.md:58-60`):
  > **Properties (CoreTests):** never draws a new-learning item off the fringe or upstream of the marker
  > unless the node is `blocked`; never more than one diagnosis event per run; never more than 2 review
  > slots; every item shown ends with its answer visible.

  Binds this task: the answer-card value (holding `correctAnswerDisplay` and `why`) must be non-empty on
  every real `ItemResult`.

- `contracts/data-model.md` — heading `### ProbeItem (inside \`nodes.json\`)` (verified on disk,
  `contracts/data-model.md:58-62`):
  > `id`, `type ∈ {numeric, mc}`, `prompt_latex`, `why`, and either `answer {value (string, normalised
  > decimal or rational), tolerance (≥ 0, default 0)}` with `wrong_answers[] {value, error_type_id}`
  > (numeric) or `choices[] {id, latex, error_type_id?}` + `correct_choice_id` (mc; every non-correct choice
  > carries an `error_type_id`). No free-text answer field exists (I1, I10).

  Binds this task: `DoorItemContent` derives its fields from these, but never re-stores `answer` or
  `correct_choice_id`.

- `contracts/data-model.md` — heading `### Text` (verified on disk, `contracts/data-model.md:35-37`):
  > All student-facing strings are English (DEFERRED D-1). LaTeX appears only in fields named `latex` or
  > `prompt_latex` and must be in the SwiftMath-renderable subset or carry `render_fallback: "katex"`.

  Binds this task: the answer-card value carries a display-kind flag (LaTeX or plain) so the render layer
  does not re-derive it from `item.type` (`tasks/arbitration/arbiter-04-predispatch.md` § Q-E, item 4:
  "`MathView` is used only for `prompt_latex`, `choices[].latex`, and an `mc` answer card's
  `correctAnswerDisplay`... A `numeric` `correctAnswerDisplay`... [is] plain `Text`... The `Core` answer-card
  value carries an explicit display-kind flag (LaTeX or plain), so the App does not re-derive it from
  `item.type`.").

Prior signatures this task builds on (verbatim, verified against the current tree):

- `Packages/Core/Sources/Core/ItemChecker.swift:163-192`:
  ```swift
  public enum ItemChecker {
      public static func check(item: ProbeItem, submitted: String) -> Bool
      public static func correctAnswerDisplay(for item: ProbeItem) -> String
  }
  ```

- `Packages/Core/Sources/Core/State/ExpeditionRun.swift:4-20`:
  ```swift
  public struct ItemResult: Equatable {
      public let nodeId: String
      public let itemId: String
      public let correct: Bool
      public let correctAnswerDisplay: String
      public let why: String
      public let isRetry: Bool
  }
  public struct CurrentItem: Equatable {
      public let nodeId: String
      public let item: ProbeItem
      public let kind: SlotKind
      public let isRetry: Bool
  }
  ```

- `Packages/Core/Sources/Core/Model/Nodes.swift:54-65, 91-94, 100-113`:
  ```swift
  public struct ProbeItem: Codable, Equatable {
      public let id: String
      public let type: ProbeItemType
      public let promptLatex: String
      public let why: String
      public let renderFallback: RenderFallback?
      public let answer: ProbeAnswer?
      public let wrongAnswers: [WrongAnswer]?
      public let choices: [ProbeChoice]?
      public let correctChoiceId: String?
      public let check: ProbeCheck?
  }
  public enum ProbeItemType: String, Codable {
      case numeric
      case mc
  }
  public struct ProbeAnswer: Codable, Equatable {
      public let value: String
      public let tolerance: Double?
  }
  public struct ProbeChoice: Codable, Equatable {
      public let id: String
      public let latex: String
      public let errorTypeId: String?
  }
  ```

Facts confirmed absent (from re-running the greps this run):

- No `Door/` directory and no `*ItemView*.swift` / `*AnswerCard*.swift` / `*Keypad*.swift` file exists under
  `Packages/Core/Sources/Core/` (`Glob` this run — empty except this task's own new file).
- `Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift` is absent from the current tree; only
  `Classify.swift` exists under `Diagnosis/` (`Glob Packages/Core/Sources/Core/Diagnosis/*.swift` this run).
  Its `ProbeInProgress` type (spec `tasks/epic-02-task-11-diagnosis-machine-seam.md:671-678`) is described
  there as `public struct ProbeInProgress: Equatable { public let context: DiagnosisContext; public let
  candidateId: String; public let items: [ProbeItem]; public let levelResults: [ItemResult]; ...; public var
  currentItem: ProbeItem { items[levelResults.count] } }` with **no public initializer** on the type itself
  (AC15 of that spec: "`DiagnosisEvent.swift` declares exactly one `public init`,
  `DiagnosisLevelDecision`'s"). This task therefore does not construct or import that type; per §6, a future
  caller (task 04.3) builds `DoorItemContent` from `probeInProgress.candidateId` and
  `probeInProgress.currentItem` using this task's `init(nodeId:item:isRetry:)`.

## §4 Implementation outline

1. **Layer.** `Packages/Core/Sources/Core/Door/DoorItemContent.swift` is layer ④ interaction (screen content
   shared by Doors B and A), composing layer ③ learning-objects data already carried on `ProbeItem`. It
   performs no I/O, no rendering, no system-clock read, and calls no other `Core` function — it only reads
   the fields of the values passed to its initializers.

2. **`DoorItemContent`** — the item view's content:
   ```swift
   public struct DoorItemContent: Equatable {
       public let nodeId: String
       public let promptLatex: String
       public let inputKind: DoorItemInputKind
       public let choices: [DoorItemChoice]
       public let isRetry: Bool

       public init(nodeId: String, item: ProbeItem, isRetry: Bool) {
           self.nodeId = nodeId
           self.promptLatex = item.promptLatex
           switch item.type {
           case .numeric:
               self.inputKind = .numeric
               self.choices = []
           case .mc:
               self.inputKind = .multipleChoice
               self.choices = (item.choices ?? []).map { DoorItemChoice(id: $0.id, latex: $0.latex) }
           }
           self.isRetry = isRetry
       }

       public init(from currentItem: CurrentItem) {
           self.init(nodeId: currentItem.nodeId, item: currentItem.item, isRetry: currentItem.isRetry)
       }
   }

   public enum DoorItemInputKind: Equatable { case numeric, multipleChoice }

   public struct DoorItemChoice: Equatable {
       public let id: String
       public let latex: String
   }
   ```
   Only `id` and `latex` are carried per choice — never `errorTypeId` (a diagnosis-time distractor tag with
   no render-layer use) and never anything that identifies the correct choice. `item.answer` and
   `item.correctChoiceId` are read nowhere in this initializer.

   The Door A façade (task 04.3) builds the same value for a probe item by calling
   `DoorItemContent(nodeId: probeInProgress.candidateId, item: probeInProgress.currentItem, isRetry:
   false)` — a probe item is never a retry (§3, `ProbeInProgress` doc comment: "`isRetry` always false"
   is the corresponding `ItemResult` convention carried by 02.11 AC14). This task adds no compile-time
   dependency on `DiagnosisEvent.swift`.

3. **`DoorAnswerCardContent`** — the answer card's content, built only from a checked `ItemResult` plus the
   item's type (needed to route the display kind per Q-E; `ItemResult` itself carries no `type` field):
   ```swift
   public struct DoorAnswerCardContent: Equatable {
       public let correct: Bool
       public let correctAnswerDisplay: String
       public let correctAnswerDisplayKind: DoorAnswerDisplayKind
       public let why: String
       public let extraLine: String?

       public init(result: ItemResult, itemType: ProbeItemType, extraLine: String? = nil) {
           self.correct = result.correct
           self.correctAnswerDisplay = result.correctAnswerDisplay
           self.correctAnswerDisplayKind = itemType == .mc ? .latex : .plain
           self.why = result.why
           self.extraLine = extraLine
       }
   }

   public enum DoorAnswerDisplayKind: Equatable { case latex, plain }
   ```
   `extraLine` is `nil` by default; task 04.4 passes the Q5 line ("We'll come back to this one") through it
   on the exact second-miss-after-Door-A-spent case. This task ships the slot only, no copy.

4. **`DoorKeypad`** — the numeric keypad's key set:
   ```swift
   public enum DoorKeypad {
       public static let numericKeypadKeys: [String] = [
           "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", ".", "/", "+", "-",
       ]
   }
   ```
   The array covers every character the grammar in §3 admits (sign, digits, `.`, `/`); order is a
   phone-keypad-plus-operators layout suggestion for the render layer, not a contract requirement.

5. **Boundary schema(s).** None: this file parses no untrusted external input. Its inputs
   (`ProbeItem`, `CurrentItem`, `ItemResult`) are already-decoded, already-checked `Core` types; the schema
   validation for the raw bundle JSON happens in `BundleIO` (landed, out of scope here).

6. **Error codes.** None thrown. No `CoreError` case is added or needed (context bundle §G, confirmed: no
   throwing function exists in this file).

7. **Model-calling path.** None. No adapter, no confidence threshold, no Tier-0 fallback applies — this file
   contains no model call (I2 is structurally satisfied by the file containing no adapter import).

8. Smoke check: `swift build --package-path Packages/Core` — must be green.

## §5 Test plan (risk: seam — full plan)

- T1 happy path: `DoorItemContent(nodeId:item:isRetry:)` / `DoorItemContent(from:)` over every `data/demo`
  node's two `probeItems` produce the field mapping of AC1 (prompt, input kind, choice list, retry flag);
  `DoorAnswerCardContent(result:itemType:)` over a real correct-submission `ItemResult` and a real
  miss-submission `ItemResult` for every `data/demo` item produces the field mapping of AC3 (non-empty
  `correctAnswerDisplay`/`why`, correct `correct` flag, correct `correctAnswerDisplayKind`); `DoorKeypad.numericKeypadKeys`
  covers every character of every `data/demo` numeric `answer.value` (AC4 positive half).
- T2 negative — invalid input rejected at the boundary: this file validates no untrusted external input
  (§4 item 5), so the applicable negative case is the defensive one: an `mc` `ProbeItem` constructed with
  `choices: nil` (a state the Swift type allows even though the schema requires it in practice) yields
  `DoorItemContent.choices == []`, never a crash and never a forged choice.
- T3 error-taxonomy: N/A — this file throws no `CoreError` (§4 item 6). State this explicitly in the test
  file's header comment so a reviewer does not look for a missing case.
- T4 conformance per requirements §B.1: (a) I3/interaction-contract "every item shown ends with its answer
  visible" — asserted as AC3, over every real `data/demo` item, both a hit and a miss; (b) I10 numeric
  grammar coverage — asserted as AC4; (c) I1 no stored correctness field — asserted as AC2, via the `Mirror`
  scan.
- T5 negative control for every regression guard:
  - AC2's guard (no leaked answer/correct-choice field): a synthetic fixture type carrying a stored `answer`
    field is scanned with the same `Mirror`-based check, and the scan reports it — proving the scan is not
    vacuously passing (mirrors `ImportBoundaryNegativeControlTests.swift`'s "prove the scan catches a
    planted violation" shape).
  - AC4's guard (keypad completeness): `DoorKeypad.numericKeypadKeys` with `"/"` removed does not cover
    `rational-numbers-1`'s value `5/6` — the character-membership check fails, proving the completeness
    assertion is not vacuous.
- T6 idempotency / no-leak: constructing `DoorItemContent` (or `DoorAnswerCardContent`) twice from the same
  inputs yields `Equatable`-equal values, and neither initializer mutates its `ProbeItem`/`ItemResult`
  argument (both are `let`-only value types passed by value, so this is a structural guarantee — assert it
  once per type as a documentation-carrying test, per the `Equatable` conformance already declared).

## §6 Decision defaults

- IF the Door A façade (task 04.3) needs probe-item screen content and `ProbeInProgress` (02.11, not yet
  landed on this tree) has no public initializer THEN it calls `DoorItemContent(nodeId:
  probeInProgress.candidateId, item: probeInProgress.currentItem, isRetry: false)` using this task's public,
  primitive-typed initializer — never a new initializer keyed to the phase type — per the confirmed-absent
  fact in §3 and the arbitration record `tasks/arbitration/arbiter-02-11-stepwise-api.md` Ruling 2 ("no
  phase value has a public initializer").
- IF `ItemResult` carries no `type` field (confirmed, `ExpeditionRun.swift:4-11`) THEN
  `DoorAnswerCardContent`'s initializer takes an explicit `itemType: ProbeItemType` parameter from the
  caller (who already holds the source `ProbeItem` at the point it received the `ItemResult`) to compute
  `correctAnswerDisplayKind`, per arbiter-04 § Q-E item 4 ("the answer-card value carries a display-kind
  flag... so the App does not re-derive it from `item.type`" — the *App* does not re-derive it; `Core`
  computes it here from the type the façade already has in hand).
- IF an `mc` `ProbeItem`'s `choices` is `nil` (a state the Swift `Optional` allows even though the schema
  requires the array in practice) THEN `DoorItemContent.choices` is `[]`, never a forced-unwrap crash (T2).
- IF a future task needs a different keypad key ordering THEN it may re-derive an ordering from
  `DoorKeypad.numericKeypadKeys`'s `Set`, but the ordering shipped here is not itself a contract requirement
  — only completeness is (§4 item 4).
- IF the display-kind flag naming needs to match a sibling App-side enum name later (task 04.7, `MathView`)
  THEN this task's `DoorAnswerDisplayKind` is the canonical name; a later task adapts to it, not the reverse
  (this task lands first, per the plan's dependency table showing 04.2 depends on nothing).

Standing defaults: identifiers here are the already-validated `ProbeItem.id`/node id strings threaded
through unchanged, never re-validated or re-generated (identifier policy per `contracts/data-model.md` §
Identifiers, unchanged by this task); no model call anywhere in this file (Tier 0 only); no telemetry client
in this file; no field here identifies a student, device, install or session (I5); no Ministry text is
introduced (I6) — this file carries no `paraphrase` or expectation-code field at all.

## §7 Done definition

The task is done when ALL gates pass:

- format + lint clean (`xcrun swift-format lint --strict --recursive --configuration .swift-format
  Packages App/Sources`)
- typecheck clean — Swift's typecheck is the build; N/A for Python (this task touches no `pipeline/`)
- `Core` build + test green (`swift build --package-path Packages/Core`; `xcodebuild test -scheme
  Core-Package` on the simulator)
- App build: N/A — this task does not touch `App/Sources`
- tests green for the cases in §5
- conforms to every contract section cited in §3 and to every invariant listed in §1
