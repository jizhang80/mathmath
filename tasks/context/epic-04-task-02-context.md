# Task 04.2 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: core-door-item-card-keypad
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- Epic: 04
- Task: 02
- Sub-epic: 04a (Door core)
- Slug: core-door-item-card-keypad
- Summary: Implement in `Core` the screen-content values shared by both Doors B and A: the item view (no answer or `correct_choice_id` field), the answer card built only from an `ItemResult`, and the keypad key-set constant. These are plain value types carrying ids, strings, enums and booleans, with no presentation logic. They carry no `@Observable` or `SwiftUI` types; the App renders them (I14). Keypad input must cover every numeric `answer.value` in `data/demo`.

- Invariants in play: **I3** (answer card always shows correct answer + why); **I10** (no free-text answer field; numeric keypad only with defined key set); **I14** (plain value types in `Core`, no SwiftUI); **I1, I6, I15** (inherited; not newly constrained here).

## §B. Applicable contract rules (verbatim)

### contracts/interaction-contract.md — § 2 Expedition, `answer(item)` and `numeric normalisation` bullet (v0.9.1)
> - `answer(item)`: deterministic check (expedition Q4: normalised exact match, per-item tolerance; `mc` by choice id); always show correct answer + `why` (I3); log `probe_log`; emit `item_answered`.
> - **Numeric normalisation (expedition Q4):** a submitted numeric answer and the item's `answer.value` (`data-model.md` § ProbeItem) are each parsed under the same grammar before comparison: an optional leading sign (`+` or `-`; absent = positive), one or more digits, an optional `.` followed by one or more digits, and an optional `/` followed by one or more digits (a rational `a/b`, `b ≠ 0`); leading and trailing whitespace is stripped and has no other effect. A string that does not parse under this grammar is a **miss** — never a crash, never a retry that skips its item. Every value that parses is reduced to an **exact rational**: leading zeros in the integer part (`007`) and trailing zeros after the decimal point (`0.750`) carry no significance; a decimal parses to its exact fraction (`0.75 = 3/4`). Two parsed values match iff their exact-rational values are equal, or their absolute difference is ≤ the item's `answer.tolerance` (non-negative, default `0`, per `data-model.md` § ProbeItem). Comparison is exact-rational arithmetic; no floating-point comparison is used anywhere in this rule (I1). This is the entire `numeric`-item rule; `mc` items are compared by `choices[].id` only, never by value (I10).

Source: `contracts/interaction-contract.md:38-52`

Binds this task: the keypad key set is derived from this grammar and must cover every character a student might submit; the `correctAnswerDisplay` carries the verbatim `answer.value` for numeric items.

### contracts/data-model.md — § ProbeItem
> `id`, `type ∈ {numeric, mc}`, `prompt_latex`, `why`, and either `answer {value (string, normalised decimal or rational), tolerance (≥ 0, default 0)}` with `wrong_answers[] {value, error_type_id}` (numeric) or `choices[] {id, latex, error_type_id?}` + `correct_choice_id` (mc; every non-correct choice carries an `error_type_id`). No free-text answer field exists (I1, I10).

Source: `contracts/data-model.md:59-62`

Binds this task: item view and answer card values derive from these fields; no answer textarea is added anywhere.

### contracts/data-model.md — § Text
> All student-facing strings are English (DEFERRED D-1). LaTeX appears only in fields named `latex` or `prompt_latex` and must be in the SwiftMath-renderable subset or carry `render_fallback: "katex"`.

Source: `contracts/data-model.md:35-37`

Binds this task: the answer-card value carries a display-kind flag (LaTeX or plain) so the App knows which renderer to use (arbiter-04 § Q-E).

### contracts/interaction-contract.md — § 2 Properties
> **Properties (CoreTests):** never draws a new-learning item off the fringe or upstream of the marker unless the node is `blocked`; never more than one diagnosis event per run; never more than 2 review slots; **every item shown ends with its answer visible.**

Source: `contracts/interaction-contract.md:58-60`

Binds this task: the answer card (holding `correctAnswerDisplay` and `why`) must be testable as reachable from every `ItemResult`, with both fields non-empty.

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/expedition.md — § UI surfaces
> Native screens: **Expedition** (item view with numeric keypad or choices, immediate answer card — W2, W3); **Expedition summary** (W5). Entered from the **Map** "Start expedition" button. Confirmed by the Demo.

Source: `docs/domains/expedition.md:127-128`

### docs/domains/expedition.md — W2, steps 1–3
> **Steps:** 1. Student answers — numeric entry or a multiple-choice tap (I10). 2. (Tier 0) Check deterministically in code: numeric per Q4, multiple-choice by choice id. No CAS on the device, no model (I1, D34). 3. Show correct/incorrect **with the correct answer and the item's one-line why** immediately (D5, I3). 4. Record the `ItemResult`. **Post:** `expedition.item_answered` emitted (D40, per-item node and result — the L3 input).

Source: `docs/domains/expedition.md:76-80`

### docs/domains/expedition.md — § Invariants enforced here
> - **I3** — W2's answer card cannot exist without the correct answer and why; a test asserts every `ItemResult` rendering includes them.
> - **I10** — item types are `numeric | mc` only; a bundle with any other type is refused at load.

Source: `docs/domains/expedition.md:156-162`

## §D. Prior task outputs this task depends on

Exported types / signatures already produced by earlier tasks that this task consumes. Quote the signature from the code; cite the path.

- `ItemChecker.check(item:submitted:) -> Bool` — Source: `Packages/Core/Sources/Core/ItemChecker.swift:168-181`. Produced by task 02.04. Used by `ItemResult` assembly; this task reads the result, does not call the checker.

- `ItemChecker.correctAnswerDisplay(for item:) -> String` — Source: `Packages/Core/Sources/Core/ItemChecker.swift:185-192`. Produced by task 02.04. Returns the correct answer's display string for rendering: `item.answer?.value` verbatim for numeric, matching choice's `latex` for mc.

- `ItemResult` — Source: `Packages/Core/Sources/Core/State/ExpeditionRun.swift:4-11`. Produced by task 02.07. Public struct carrying `nodeId`, `itemId`, `correct`, `correctAnswerDisplay`, `why`, `isRetry`. This task builds answer-card values from this type.

- `CurrentItem` — Source: `Packages/Core/Sources/Core/State/ExpeditionRun.swift:15-20`. Produced by task 02.07. Public struct carrying the item currently awaiting an answer: `nodeId`, `item: ProbeItem`, `kind: SlotKind`, `isRetry`.

- `ProbeItem` — Source: `Packages/Core/Sources/Core/Model/Ids.swift` and `Packages/Core/Sources/Core/Model/Nodes.swift` (decoded from bundle). Carrying `id`, `type ∈ {numeric, mc}`, `prompt_latex`, `why`, and either `answer {value, tolerance}` or `choices[]` with `correct_choice_id`.

- `ItemResult` usage in `ExpeditionRun.answer(...)` — Source: `Packages/Core/Sources/Core/State/ExpeditionRun.swift:108-111`. Called by task 02.07, consumed by the façade (task 04.4); this task produces the answer-card value that wraps the `ItemResult`.

- `DiagnosisAdvance.itemResult` — Source: `tasks/epic-02-task-11-diagnosis-machine-seam.md` § 1, AC14: "every `answerProbeItem` advance carries `itemResult != nil` with non-empty `correctAnswerDisplay` and `why`". Produced by task 02.11. The diagnosis façade (task 04.3) consumes probe `ItemResult`s from the same types.

## §E. Negative facts (confirmed ABSENT)

- No `AnswerCardView`, `KeypadView` or rendering types exist in `Core`. Confirmed: `Glob Packages/Core/Sources/Core/**` for `*iew.swift`, `*Render*.swift`, `*UI*.swift` — empty. This task creates value types only; rendering lives in `App/Sources`.

- No `@Observable` types in `Core`. Confirmed: `Grep Packages/Core/Sources/Core -i observable` — 0 matches. Task 03.6 established the precedent: `MapViewModel` is a plain struct, never observable.

- No free-text answer field on `ProbeItem` or anywhere in the item model. Confirmed: `Grep data/demo/nodes.json 'text.*answer\|TextField\|input_type.*text'` — 0 matches. All items are `numeric` or `mc`, with no typed string.

- No numeric-answer value in `data/demo` requires decimals beyond two significant figures. Verified below (§G).

- No third-party UI kit beyond SwiftMath (and that only in `Rendering`). Confirmed: `contracts/data-model.md` § Text and `docs/tech-stack.md` § 1 name SwiftMath only.

## §F. File scope

Files this task may create or touch. Mark each create / modify and cite existence for modifies.

- CREATE `Packages/Core/Sources/Core/Door/ItemView.swift` — confirmed absent. Will hold: `struct ItemView` (nodeId, item, kind, isRetry) and `enum ItemInputKind { case numeric, multipleChoice }`. Plain value types, Foundation only.

- CREATE `Packages/Core/Sources/Core/Door/AnswerCardView.swift` — confirmed absent. Will hold: `struct AnswerCardView` (correct, correctAnswerDisplay, correctDisplayKind, why, isRetryOnQuestionAfterUse). Carries `enum CorrectAnswerDisplayKind { case latex, plain }` to signal which SwiftUI renderer to use (arbiter-04 § Q-E). Related to I14 boundary: the App queries `.correctDisplayKind` to decide whether to render `.correctAnswerDisplay` through `MathView` or plain `Text`.

- CREATE `Packages/Core/Sources/Core/Door/KeypadKeySet.swift` — confirmed absent. Will hold: `public static let numericKeypadKeys: [String]` = ordered array of keys (digits, sign, decimal, fraction slash) covering every character in the numeric normalisation grammar.

- No file-scope write to existing files (task 04.2 is input-only to the façade and the App).

## §G. Stack constraints relevant here

- **Boundary validation (numeric keypad):** the key set is a `Core` constant, a static array of strings. A test asserts that every `numeric` `answer.value` in `data/demo` parses under the grammar and that every character in every value is present in `numericKeypadKeys` (task 04.4 acceptance criterion 7 paraphrased here: "the keypad key set types every `numeric` `answer.value` in `data/demo`").

- **Numeric answer inventory from `data/demo` (Grep this run):** 20 numeric items in `data/demo/nodes.json`, yielding answer.value strings: `"4"`, `"14"`, `"5/6"`, `"6"`, `"32000"`, `"3"`, `"4"`, `"6"`, `"8"`, `"4"`, `"3"`, `"6"`, `"8"`, `"7"`, `"3"`, `"4"`, `"9"`, `"3"`, `"10"`, `"3"`. All parse under the grammar (digits, `/`, `.`, optional leading `+` or `-`). Keypad key set must include: digits 0–9, `+`, `-`, `.`, `/`.

- **Prompt LaTeX + choice LaTeX inventory from `data/demo`:** 20 `probe_items[].prompt_latex` (one per numeric item) + 20 `probe_items[].prompt_latex` (one per mc item) + 40 `choices[].latex` (two per mc item) = 80 LaTeX strings total. The answer-card `correctDisplayKind` flag distinguishes `numeric` (always plain) from `mc` (the choice's `latex` field, so use `MathView`) — see arbiter-04 § Q-E: "`MathView` is used only for `prompt_latex`, `choices[].latex`, and an `mc` `correctAnswerDisplay`".

- **Error codes:** none new in this task (task 04.3 adds `loHintNotFound`). No registry change needed.

- **Tier 0 only:** no model, no Foundation Models adapter, no runtime-tiers import.

- **Tech stack:** Swift 6 strict concurrency, Foundation only. Source: `docs/tech-stack.md:` 17 (Core), 14 (Swift 6).
