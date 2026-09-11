# EPIC 04: App — Expedition (Door B) + Diagnosis (Door A) + acceptance instrument

> Status: brief authored 2026-09-10 by epic-scoper; amended 2026-09-10 by brief-amender with the pre-dispatch
> arbiter rulings (Amendment 04.00.1) and the hint-fallback reconciliation (Amendment 04.00.2). No cross-ruling
> conflict is open (§9 cross-reference). Owner decides dispatch; planner decomposes.

## 1. EPIC id, title, category
EPIC 04 — App: Expedition (Door B) + Diagnosis (Door A) + acceptance instrument. Category: Feature.

## 2. Goal & scope
After EPIC 03 the App opens on the map, and its "Check me here", "Include" and "Unit expedition" actions each
return a typed value (`DiagnosisEvent`, `ComposeResult`, or a queued node) to a placeholder destination
(EPIC 03 task 03.11). **After this EPIC a student can run a whole expedition and a whole diagnosis event by
touch.** An expedition covers items, the answer card, a retry, the D27 hand-off, and the summary. A diagnosis
event covers the hypothesis card, the probe, remediation, and the return. Every screen action is one `Core`
call. The EPIC also ships the owner's Demo acceptance record template.

**Dominant domains:** expedition (W1, W2, W3, W5; UI surfaces "Expedition" and "Expedition summary") and
diagnosis (W1–W6 as screens; UI surfaces "Hypothesis card", "Probe", "Remediation"). The rows are
`docs/domains/expedition.md` § UI surfaces ("**Expedition** (item view with numeric keypad or choices,
immediate answer card — W2, W3); **Expedition summary** (W5). Entered from the **Map** "Start expedition"
button") and `docs/domains/diagnosis.md` § UI surfaces. In scope, cut at the domain docs' seams:

- **Door B flow in `Core`.** This is a door façade over the landed machines. It follows the same boundary as
  EPIC 03's map façade and `Core` session (`tasks/arbitration/arbiter-03-predispatch.md` § "The boundary,
  precisely", item 4: "Each entry point takes values and returns (new value, `[CoreEvent]`) or throws a
  `CoreError`", with persist-after-every-state-changing-action in a `Core` session type). It covers:
  - **Start expedition** from the map: `Expedition.compose` with the façade's in-memory queued node (EPIC 03
    § Q-D). EPIC 03 brief §7 item 1 hands the "Start expedition" entry to this EPIC.
  - **Unit expedition entry**: starts a run from the `ComposeResult` that EPIC 03's "Unit expedition" action
    returns (D46).
  - **Answer**: `ExpeditionRun.answer` with the raw submitted string, followed by the D27 retry.
  - **Continue**: after every checked item (expedition item, retry or probe item) the façade's screen value is
    the answer card. Only an explicit continue call, itself a façade entry point, moves it on: to the next item,
    the retry, the second probe item, the hypothesis card (D27 hand-off), remediation, a terminal line, or the
    summary. Continue changes no `StudentState`, so it triggers no write (arbiter-04 § Q-A).
  - **D27 hand-off**: when the run is suspended, the façade opens the diagnosis
    (`DiagnosisRun.open(... expedition_second_miss ...)`). It builds `misses` from the two missed items
    and the exact submitted strings, as `tasks/epic-02-task-11-diagnosis-machine-seam.md` §6 requires ("it
    builds `misses` from the two missed `CurrentItem.item` values and the exact strings it submitted
    to `ExpeditionRun.answer`"). `shownItemIdsInRun` is `run.shownItemIds`. On `returned`, the façade calls
    `ExpeditionRun.resume(run:)`.
  - **Second miss after the Door A event is spent**: the answer card shows the extra line "We'll come back to
    this one" (expedition Q5).
  - **End**: `ExpeditionRun.end`, both on natural completion and on "Back to the map" mid-run (abandoned,
    expedition W5, Q6). The natural end is called in the same façade call that produces the run's last result
    (the final answer, or the `returned` that resumes into an empty queue); the summary value is held behind
    that call's answer card and shown on continue (arbiter-04 § Q-G).
  - **Persistence**: the whole `StudentState` is written after every state-changing call, through EPIC 03's
    store. **During a run** (from the run-start call on, Door B and Door A calls alike), every write persists
    what `ExpeditionRun.end(run: <current run>, state: <threaded state>, today:, abandoned: true).state` would
    produce at that moment; the in-memory threaded state never carries that entry. The natural end
    (`abandoned: false`) or "Back to the map" (`abandoned: true`) replaces it. A run the OS terminates is
    therefore logged as abandoned and never resumed; nothing is written on backgrounding; no field is added
    (arbiter-04 § Q-G; expedition Q6). A failed write surfaces `EXP_STATE_WRITE_FAILED` as a banner, and the
    summary still shows (expedition W5 step 2).
- **Door A flow in `Core`.** The diagnosis is driven only through the public step API that 02b's task 02.11
  lands (`tasks/arbitration/arbiter-02-11-stepwise-api.md` § Ruling 1): `DiagnosisRun.start` → `decideProbe` →
  `answerProbeItem` → `decideFurtherLevel`, threading `DiagnosisAdvance.state`, one call per screen action.
  The flow opens from either trigger:
  - `expedition_second_miss`, from the Door B flow;
  - `map_check_here`, from the `DiagnosisEvent` that EPIC 03's "Check me here" returns.

  `returned` hands control back to the suspended expedition's next item, or to the map node panel (diagnosis
  W5 step 2). A failed write surfaces `DIAG_STATE_WRITE_FAILED` as a banner, and the event still returns. A
  Door A event ends only by its own decisions (decline, the two probe answers, the further-level choice);
  "Back to the map" is offered on the Door B item view and answer card, not mid-event (arbiter-04 § Q-G).
- **Screen content derived in `Core` (I14).** These are plain value types, in the same shape discipline as
  `MapViewModel` (arbiter-03 § "The boundary, precisely", item 3):
  - the **item view**: prompt, input kind (numeric or choices), the choice list, and the retry flag;
  - the **answer card**: correct or incorrect, `correctAnswerDisplay` with an explicit display-kind flag (LaTeX
    or plain, arbiter-04 § Q-E), `why`, and the Q5 extra line when it applies;
  - the **hypothesis card**: "This may be blocked by **X**", with the cost stated up front and a decline
    option (diagnosis W3 step 1, Q2). The cost line reads exactly "Two quick checks, about a minute." It is a
    `public static let` constant in `Core`'s Door A screen-content file, carried on the hypothesis-card value
    and rendered verbatim (arbiter-04 § Q-D);
  - the **probe**: two items in the item view, with an answer card after each (diagnosis W3 step 3, I3);
  - **remediation**: the one piece for the confirmed candidate X, chosen by one `Core` function: `X.explanation`,
    else `X.worked_examples[0]`, else `X.paraphrase` plus the hint resolved for
    `(X, Classify.classify(probeResult.misses))`, where `probeResult` is the one on the advance whose
    `probeResult.outcome == .confirmed`. The hint part is omitted when no key resolves, so the piece is then the
    paraphrase alone and the paraphrase is never shown twice. It is never empty (`paraphrase` is
    schema-required). At the Demo budget the `capped` screen shows it before the capped line (arbiter-04 § Q-B;
    arbiter-04-hint-fallback-reconciliation Rule 3; see §9 Q-B);
  - the **further-level offer** (diagnosis Q3, "offered, never automatic");
  - the **hint**, resolved from the key `DiagnosisOutcome` carries (`hintNodeId`, `hintErrorTypeId`) to its
    prose. The step API "Returns keys, never hint prose" (02.11 spec §4 step 5), so the key→prose lookup is a
    `Core` function, not App code. The key is `hintErrorTypeId` as returned by 02.11's `hintKey`: the
    classified error type when its `hint_tree` entry exists, else the catalogue id `"none-of-these"` when that
    entry exists, else `nil`, never the outcome token `"none_of_these"` and never another error type's key
    (arbiter-02-none-of-these Ruling 3). The resolver takes `(node, classifiedToken)`: `originErrorTypeId` for a
    terminal hint, `Classify.classify(probeResult.misses)` for remediation. It calls `hintKey`
    in-module (`hintKey` is `internal`), so nothing is reimplemented. With `expected` = `"none-of-these"` for the
    outcome token `"none_of_these"`, else the token itself:
    - key == `expected` → tier 1 of `hint_tree[key]`, `internalCode` nil;
    - key non-nil and ≠ `expected` (a classified type had no entry, so the none-of-these branch served) → tier 1
      of `hint_tree[key]`, `internalCode: .loHintNotFound`;
    - key `nil` → the node's `paraphrase`, `internalCode: .loHintNotFound`.

    "The node's generic tier-1 hint" (learning-objects W2) is `hint_tree["none-of-these"][0]`, a node-level
    hint naming no specific mistake, and nothing else; the resolver never returns another error type's hint
    (I2). `LO_HINT_NOT_FOUND` is internal data, never thrown and never shown. When the key is `nil`, every hint
    slot (refuted, `DIAG_NO_PREREQUISITE`, `DIAG_PROBE_UNAVAILABLE`, declined-`unconfirmed`, the W1 abstention
    path) shows the origin node's `paraphrase` with no label naming a mistake: never blank, never a sibling
    type's hint, and the code never on screen; the prototype's "No hint written for that exact mistake yet"
    banner is not built (arbiter-04-hint-fallback-reconciliation Rules 1–3). Tier 1 only (§9 Q-F);
  - the **terminal lines**: refuted "Not the issue — back to where you were", `DIAG_NO_PREREQUISITE` and
    `DIAG_PROBE_UNAVAILABLE` registered text, and capped "further upstream — it's on your map". The fixed Door
    strings are `Core` constants in the same file as the cost line; registry codes come from 03.3's
    `CoreErrorText.userText` (arbiter-04 § Q-D);
  - the **summary**: nodes cleared this run, fog lifted, blocked nodes marked, "Start another" and "Back to the
    map" (expedition W5). It shows no region tint delta and no fraction (arbiter-04 § Q-A; content-policy
    § Voice).
- **Demo data: the none-of-these hint.** Every `data/demo` node gains `hint_tree["none-of-these"]`: three
  non-empty plain-text tiers in the learning-objects HintTree voice (tier 1 nudges at what to look at, tier 3
  works the step through), naming or describing no other `error_types[]` member's misconception (I2), with no
  Ministry prose (I6). This delivers diagnosis W1 step 3 and W3 step 4 ("a tier-1 hint on the origin") and
  DEMO-BRIEF §3.6 ("Show the original node's hint") on the Demo's commonest path, `map_check_here`. The data is
  agent-authored and machine-verified with no human review step (I9), exactly as the hand-written Demo bundle
  was in EPIC 01 (D26). No field is added: the schema already accepts the key (arbiter-04-hint-fallback-reconciliation
  Rule 4; §8 task 1b).
- **`MathView` in `Packages/Rendering`.** The EPIC 03 brief §7 item 3 moved it here: "`MathView` therefore
  moves to EPIC 04, its first consumer". It is a SwiftUI view over SwiftMath for the only LaTeX-bearing fields,
  `prompt_latex` and `choices[].latex` (`contracts/data-model.md` § Text: "LaTeX appears only in fields named
  `latex` or `prompt_latex`"). It is also used for an `mc` `correctAnswerDisplay`, which is the correct choice's
  `latex` (`ItemChecker.swift:183-191`). A `numeric` `correctAnswerDisplay`, `why`, hint strings and
  `paraphrase` are plain text. When `RenderCheck.parseError(latex:)` is non-nil, or the item carries
  `render_fallback: "katex"`, `MathView` shows the unmodified source string as plain `Text`: never blank, never
  an error string, no student code (arbiter-04 § Q-E). `Rendering` already builds and is linked into the App
  target (pbxproj product `Rendering`), so no pbxproj edit is needed. `RenderCheck.canRender` exists;
  `MathView` does not.
- **Render layer in `App/Sources`:**
  - the item view: a numeric keypad covering the full numeric grammar (sign, digits, `.`, `/`), or choice
    buttons;
  - the answer card with an explicit continue control;
  - the hypothesis card as a sheet over the expedition or the map;
  - probe, remediation and summary screens;
  - the map's "Start expedition" button;
  - replacing EPIC 03's placeholder hand-off destination with these screens.

  The layer computes nothing (I14).
- **Acceptance instrument:** the template `docs/epics/demo-acceptance-record.md`. It holds per-tester rows for
  DEMO-BRIEF §7 items 1–7 as amended, and the §8 verification checklist as amended by v2.2 §B. Each checklist
  line is marked *simulator — agent* or *device — owner* (D29). The owner fills it at the Demo wrap.
- **Contract finalization:** `interaction-contract.md` goes to v0.9.3 in task 1 (answer-card timing, summary
  content, in-run log entry; arbiter-04 § Q-A, § Q-G) and flips to **v1.0.0** at the wrap with no normative
  change. `domain-glossary.md` goes to v1.0.1 (Remediation and the two none-of-these tokens; arbiter-04 § Q-B;
  arbiter-04-hint-fallback-reconciliation Rule 5). See §3.

**This EPIC builds on 01, 02a, 02b and 03 and re-creates nothing.** Landed in `Packages/Core/Sources/Core/`:
`ItemChecker.swift` (`check`, `correctAnswerDisplay`), `State/ExpeditionRun.swift` (`start`, `answer`,
`resume`, `end`; `ItemResult`, `ExpeditionSummary`), `State/Expedition.swift` (`compose`, `selectItem`),
`State/MasteryTransitions.swift`, `Events/CoreEvent.swift` (every § 5 name), `CoreError.swift`. **Named as
dependencies, not existing code:**
- 02b's task 02.11, the step-wise `DiagnosisRun` (`tasks/epic-02-task-11-diagnosis-machine-seam.md` with
  `tasks/arbitration/arbiter-02-11-stepwise-api.md`), being implemented on `epic-02b-door-a-core-merge`;
- EPIC 03's store, session, façade and userText table (03.3, 03.5, 03.7), its App shell and I14 source scan
  (03.9, 03.12), and its placeholder hand-off (03.11).

**Correction carried from the EPIC 03 brief.** That brief's §9 "Note for EPIC 04" named `hypothesise`, `probe`,
`offered`, `remediate` and `returned` as step-wise entry points. That note is already marked superseded there.
Under arbiter-02-11-stepwise-api § Ruling 2 those helpers are `internal`: "`classify`, `hypothesise`,
`drawProbeItems` (the old `probe`), `offered`, `remediate`, `capped` and `hintKey` (the old `returned`)". This
EPIC uses only `open`, `start`, `decideProbe`, `answerProbeItem` and `decideFurtherLevel`. The App cannot call
the internal helpers because the call does not compile. The phase types (`ProbeOffer`, `ProbeInProgress`,
`FurtherLevelOffer`, `DiagnosisContext`, `DiagnosisOutcome`, `DiagnosisEvent`) have "no public initializer",
so the App cannot construct a phase.

**MANDATORY placement line:** milestone **Demo** (D26; `data/demo` is the snapshot). M3 repeats the same
screens on real data (EPIC 12). Layer **④ interaction**: Doors B and A, plus the Demo acceptance instrument.
Layers ② (nodes, edges) and ③ (probe items, hint trees, `why`) are read-only inputs, except that one data task
(§8 task 1b) adds `hint_tree["none-of-these"]` to every `data/demo` node.

## 3. Contracts it must conform to
- `contracts/interaction-contract.md` (v0.9.1 today; **v0.9.2 after EPIC 03 task 03.1**):
  - § 2 Expedition: `READ-ONLY`. The states `idle → composing → item → (retry | diagnosing | item) → summary →
    idle`. "always show correct answer + `why` (I3)". The numeric normalisation rule: the App passes the raw
    string and never normalises. "**At most one diagnosis per run.**"
  - § 4 Diagnosis: `READ-ONLY`. States, probe outcomes, "a further level is **offered, never automatic**",
    "`returned` always hands control back to the suspended expedition (its next item) or the map node panel".
  - § 5 Notifications: `READ-ONLY`. Every name used already exists as a `CoreEvent` case. Events are
    in-process only.
  - § *Finalization owed by the Demo EPIC* ("the timing of the answer card; whether the summary shows region
    tint deltas. Bump to v1.0.0 on wrap"): **BUMP**, in two `contract(interaction-contract)` commits with the
    exact text of arbiter-04 § Q-A. **Task 1:** v0.9.2 → **v0.9.3** — the header and Source sentence; in § 2,
    the "Answer card (timing)" bullet after `answer(item)` and the "Summary content" and "In-run log entry
    (expedition Q6)" bullets after `end` (Q-A, Q-G); and the § Finalization paragraph replaced, heading kept.
    **Wrap:** → **v1.0.0** — the header, the Source sentence, and "Bump to v1.0.0 on wrap." replaced by
    "Finalized at v1.0.0."; no normative change. The v0.9.2 marker item belongs to EPIC 03 and must have landed
    first.
- `contracts/data-model.md` (v1.4.0): `READ-ONLY`.
  - § ProbeItem: `type ∈ {numeric, mc}`, `prompt_latex`, `why`, "No free-text answer field exists (I1, I10)".
  - § Text.
  - § StudentState: the closed key set; `remediated` is written only by the confirmed step (02.11).
  - `nodes.json` fields: `paraphrase`, `explanation?`, `worked_examples[]?`, `hint_tree`. No field is added.
- `contracts/error-codes.md` + `error-codes.json` (v1.0.0), § Rules: `READ-ONLY`.
  - "Student text names a node or a situation, never the student, and never contains a score".
  - "Internal codes never reach a student surface; a `student` code always has a next action in its text."
  - Student text comes only from EPIC 03's `Core` userText table (03.3), which mirrors the registry.
    `error-codes.json` gains no entry. `CoreError` gains one additive case for an already-registered internal
    code, `loHintNotFound = "LO_HINT_NOT_FOUND"` (arbiter-04 § Q-B); it is internal, so it has no userText
    entry and the 03.3 parity test stays green (see the R-6 line).
- `contracts/domain-glossary.md` (v1.0.0): **BUMP to v1.0.1** in task 1 (a `contract(domain-glossary)` commit;
  the exact header, Remediation and Error-type texts are in `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md`
  Rule 5, which amends arbiter-04 § Q-B). § Diagnosis (Door A) Remediation becomes: "**Remediation** — one
  Explanation or WorkedExample for a confirmed candidate; when the node carries neither, its `paraphrase` plus,
  when one resolves, one tier-1 hint (DEMO-BRIEF §3.6)." The Error type line (:45) becomes: "**Error type**
  (`ErrorType`) — a member of a node's closed catalogue, incl. the none-of-these member, whose catalogue id is
  `none-of-these`; `classify` reports abstention as the outcome token `none_of_these`, which is never a
  catalogue id or a `hint_tree` key." Cascade in the same task, exact text in the rulings:
  `docs/domains/diagnosis.md` § Core entities and § UI surfaces (reconciliation Rule 5), and W3 step 1 (Q-D);
  `docs/domains/learning-objects.md` catalogue-id spelling (:41-42, :47-48, :75, :77), the W2 step 1
  generic-hint definition and a change-log row, with the Q4 heading keeping `none_of_these` (reconciliation
  Rule 5). Otherwise `READ-ONLY`. Expedition ("*Banned:*
  "quiz", "session" … "quest", "level""); Item ("*Banned:* "question", "exercise", "task""); Slot; Retry / Miss /
  Clear ("*Banned:* "fail" for an item"); Diagnosis event; Hypothesis / Candidate; Probe; Remediation; Blocked.
  The wrap-epic (f) banned-synonym grep covers new identifiers **and student-facing copy** in `App/Sources` and
  `Core`. New EPIC 04 identifiers and copy use no "Session", "Quiz" or "Question"; EPIC 03's landed session type
  name is reused as-is, never duplicated (arbiter-04 § Other claims verified). §9 Q-D records one copy conflict
  (resolved).
- `contracts/graph-constraints.md` (v1.1.0): `READ-ONLY`. No new rule. The bundle is validated at launch by
  EPIC 03.
- `contracts/content-policy.md`: `READ-ONLY`. No Ministry text on any Door screen (I6). Remediation shows the
  project's own `paraphrase`, explanation or hint.
- `contracts/runtime-tiers.md`, `contracts/ai-usage.md`: `READ-ONLY`. No model or adapter. The optional "what
  did you do?" line is EPIC 13.
- `contracts/telemetry.md`: `READ-ONLY`. No client. D40 events stay in-process (DEMO-BRIEF §2: no telemetry in
  the Demo).
- `contracts/deployment-model.md`: `READ-ONLY`. No network code. EPIC 03's `URLSession` / `URLRequest` zero-hit
  grep stays green.

**MANDATORY (R-6) brief-checklist line — startup-failure guard set.** These are the config- and
registry-bearing inputs in scope, each checked against `contracts/error-codes.json` v1.0.0:
- **Content bundle (items, hint trees)**, read through EPIC 03's launch entry. A malformed bundle is refused
  there with `PLATFORM_SNAPSHOT_REFUSED` (registered by 03.2) and internal detail `PLATFORM_BUNDLE_INTEGRITY_FAILED`
  / `GRAPH_L0_FAILED`. An item `type` outside `{numeric, mc}` fails decode (closed enum; expedition §
  Invariants I10: "a bundle with any other type is refused at load"). All registered → `READ-ONLY`. This EPIC
  adds no loader.
- **Error registry**: `CoreError` ⊆ registry (`ErrorRegistryTests` with its negative control), and the 03.3
  userText parity test. `EXP_NO_FRINGE`, `EXP_ITEM_POOL_EMPTY`, `EXP_STATE_WRITE_FAILED`, `DIAG_NO_PREREQUISITE`,
  `DIAG_PROBE_UNAVAILABLE` and `DIAG_STATE_WRITE_FAILED` are registered and are already `CoreError` cases
  (`CoreError.swift:18-25`). `PLATFORM_STATE_WRITE_FAILED` is registered (internal) and joins `CoreError` in
  03.3. `LO_HINT_NOT_FOUND` is registered (internal) and joins `CoreError` as `loHintNotFound` in task 3, the
  only EPIC 04 writer of `CoreError.swift`; `ErrorRegistryTests` covers it unchanged (arbiter-04 § Q-B). →
  `READ-ONLY`.
- **Rendering**: a LaTeX string that SwiftMath cannot parse is `LO_ITEM_UNRENDERABLE` (registered, internal). It
  is gated before shipping by `Rendering`'s `BundleRenderCheckTests` over `data/demo`, and the spike outcome
  records 0 unresolved of 143 [SOURCED: docs/epics/epic-01-rendering-spike-outcome.md]. Task 1b adds 60 hint
  tier strings; the outcome's hint row becomes 123 and its total 203 [SOURCED:
  tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md Rule 4, arithmetic 63 + 3×20 and 143 + 60],
  recomputed by the task's scan, not typed from this line, still with 0 unresolved. → `READ-ONLY`. The
  runtime fallback is in §9 Q-E.
- **Constants** (the Demo diagnosis budget 1, 5 slots and ≤ 2 review, the hint tier shown, the cost line and
  the fixed Door strings): code constants from ratified defaults. No config file, so no config-invalid code to
  register.

**`error-codes.json` gains no entry in this EPIC.** Re-checked against §9 Q-B (arbiter-04 § Q-B, "Registry"):
no remediation path without content is reachable, because `paraphrase` is schema-required, so no code is
needed.

**MANDATORY invariant line:**
- **I1** — correctness comes only from `ItemChecker.check`, inside `ExpeditionRun.answer` /
  `DiagnosisRun.answerProbeItem`. The App passes the raw typed string or the tapped choice id and receives an
  `ItemResult`. The EPIC 03 source scan (03.9) is extended to fail on any comparison against
  `answer`/`correct_choice_id` or any `ItemChecker` call in `App/Sources`, with a planted negative control.
  There is no model framework anywhere (I2 scan).
- **I2** — Tier 0 only. Every Door A path completes with no adapter parameter in the call chain (02.11 AC11).
  The façade adds none. The hint fallback is `hint_tree["none-of-these"]`, else the paraphrase; it never borrows
  another ErrorType's hint (arbiter-04-hint-fallback-reconciliation).
- **I3** — the answer-card value is built from `ItemResult.correctAnswerDisplay` and `why`. A `Core` test
  asserts that no façade transition reaches the next item, the next probe item, a terminal or the summary
  without first returning an answer-card value with both fields non-empty. This covers every item of the run
  and both probe items. The contract's timing resolution (§9 Q-A) keeps the card until the student continues,
  and continue is a `Core` façade call, so the guard is assertable in `CoreTests` (arbiter-04 § Q-A).
  Remediation appears only after both probe answer cards. A declined probe shows no item, so it has nothing to
  withhold.
- **I4** — the Demo `levelBudget` is 1 for both triggers. The façade passes only `DiagnosisAdvance` values
  back, so it cannot construct a deeper `FurtherLevelOffer` (no public init). A test drives a confirmed probe at
  budget 1 through the façade and asserts `capped`, the candidate `blocked`, no further offer, and no screen
  listing deeper gaps. The map is the record.
- **I10** — input is the numeric keypad or choice taps only. There is no free-text field, no OCR, no camera and
  no handwriting. The source scan fails on `TextField`/`TextEditor` bound to an answer, and on any
  Vision/VisionKit/PencilKit import, each with a negative control. The keypad's key set is a `Core` constant,
  and a test asserts that every `numeric` `answer.value` in `data/demo` can be typed with it.
- **I14** — the flow logic, screen content, hint-key resolution, remediation selection, the Door copy
  constants, miss assembly, D27 hand-off and persistence sequencing (including the in-run
  write-ahead) are all in `Core`. The App holds one replacing `@Observable` holder plus presentation flags and
  the in-progress keypad string (arbiter-03 § "The boundary, precisely"). The 03.9 scan's allow-list gains
  exactly the Door façade entry points. `ExpeditionRun`, `DiagnosisRun`, `Expedition` and `ItemChecker` stay
  off the App's allow-list. The recursive `Core` import-boundary test stays green, and `Rendering` is not
  imported by `Core`; the `MathView` plain-text fallback is presentation and lives in `Rendering`.
- **I5** — no new persisted field. Payloads are ids, enums and booleans. The acceptance record template
  identifies testers as "Tester A" and "Tester B" with no names.
- **I6 / I15** — no Ministry text on Door screens. The landmark is untouched here.
- **I9** — task 1b's hint strings are agent-authored and machine-verified (schema, L0, render check, the
  distinctness test); no human content-review step is added, as for the EPIC 01 Demo bundle (D26).
- **D27** — at most one Door A event per run. Reached through the façade, it is asserted as a property over
  generated answer scripts (the machine-level property is 02a/02b's).
- **D29** — agents verify on the simulator only. Every device line in the acceptance record is the owner's.

**MANDATORY artifact line (P4/C4):**
- **App build** (`xcodebuild build -scheme mathmath`, gate 4) with the Door B and Door A screens.
- **`Core` library**: the Door B / Door A façade, the screen-content values and the keypad key set, exercised
  by `xcodebuild test -scheme Core-Package` (gate 3).
- **`Rendering` library**: `MathView`, exercised by `xcodebuild test -scheme Rendering` (gate 3).
- **EPIC 03's simulator smoke** (`scripts/sim-smoke.sh`, planned in 03.12) stays green in both `gate.sh` and
  `ci.yml`.
- **`core-cli`** still builds; no subcommand is added.
- **`docs/epics/demo-acceptance-record.md`** (template), checked by a grep instrument at wrap: every §7 item
  1–7 and every §8 line present, each §8 line tagged agent or owner.
- **Contract artefacts**: `interaction-contract.md` v0.9.3 (task 1), then v1.0.0 (wrap); `domain-glossary.md`
  v1.0.1 (task 1).
- **Doc artefacts (task 1)**: the three `docs/domains/diagnosis.md` edits (Q-B ×2, Q-D ×1), the
  `docs/domains/learning-objects.md` edits (reconciliation Rule 5), and two `docs/DEFERRED.md` entries (Q-A
  tint deltas, Q-F hint tiers), exact text in arbiter-04 and the reconciliation.
- **Data artefacts (task 1b)**: `data/demo/nodes.json` with `hint_tree["none-of-these"]` on all 20 nodes, and
  its cascade (§8 task 1b).

## 4. Acceptance criteria
1. **One full expedition through the façade on real `data/demo`** (`Core` test, the C1 seam): with a state
   whose marker opens a non-empty fringe, the test runs **Start expedition** → answer every item (one
   deliberate first miss, then a retry) → summary. Each step is one façade call. It asserts:
   - the event order includes `expedition.started`, `expedition.item_answered` per item and
     `expedition.completed`;
   - during the run, after every state-changing call, the decoded state file equals the threaded state plus
     exactly one trailing `abandoned: true` `expedition_log` entry matching `end(abandoned: true)` computed from
     the current run; after the natural end it holds exactly one entry for the run, with `abandoned: false`
     (arbiter-04 § Q-G);
   - the summary's cleared and blocked node lists equal the run's;
   - re-deriving `MapViewModel` from the final state shows the fog lifted on each cleared node.

   Nothing is stubbed.
2. **One full diagnosis event on each trigger** (`Core` test, C1):
   - **(a) `expedition_second_miss`:** two misses on a node open the hypothesis card, and `misses`
     carries the exact submitted strings. Accept → two probe items, an answer card after each → confirmed →
     remediation → capped at budget 1 → the run resumes at its next item with the candidate `blocked` in the
     threaded state (diagnosis W5, 02.11 C1 shape).
   - **(b) `map_check_here`:** starts from the `DiagnosisEvent` that EPIC 03's action returns. A decline →
     `unconfirmed`, the origin hint as prose, return to the node panel. A refuted run → "Not the issue — back
     to where you were" and the hint.
   - Every terminal emits `diagnosis.returned` last.
3. **I3 answer card**: every `ItemResult` produced through the façade (expedition items, retries, probe items)
   yields an answer-card value with a non-empty `correctAnswerDisplay` and `why`. No next-item, probe-item,
   hypothesis-card, remediation, terminal or summary value is reachable without one, and only the façade's
   continue call moves past the card; continue changes no `StudentState` (arbiter-04 § Q-A). The Q5 line
   appears exactly on a second miss after the Door A event was spent. A planted façade variant that skips the
   card fails the test (negative control).
4. **Door A content**:
   - the hypothesis card names the candidate node, never the student;
   - the cost line reads exactly "Two quick checks, about a minute." (a `Core` constant), and decline is
     available (Q2; arbiter-04 § Q-D);
   - remediation for a confirmed candidate is non-empty on every `data/demo` node, per §9 Q-B (on `data/demo`
     every node takes the `paraphrase` + tier-1 hint branch);
   - the hint prose follows the Rule 2 table of `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md`
     over 02.11's `hintKey`. On `data/demo` after the Rule 4 task (task 1b), every `map_check_here` hint
     terminal shows `hint_tree["none-of-these"][0]` with `internalCode == nil`. A constructed node without that
     entry shows its `paraphrase` with `.loHintNotFound`. Negative controls:
     - a resolver returning empty prose fails;
     - a resolver returning a sibling type's tier 1 for the outcome token fails;
   - `data/demo` carries `hint_tree["none-of-these"]` on every node (task 1b; reconciliation Rule 4), each
     instrument with empty = FAIL: schema decode and L0 (`core-cli validate` / `BundleIO.read`);
     `BundleRenderCheckTests` over `data/demo` with 0 unresolved; a `CoreTests` assertion over every node
     (count > 0) that the entry holds 3 non-empty strings and that its tier-1 string differs from every other
     key's tier-1 string on that node (a planted copy of a sibling's tier fails it); and
     `hintKey(node, "none_of_these") == "none-of-these"` on every node (02.11's derived T10, unedited). The
     spike outcome's count table and its pinning test agree with the re-scan, and 03.4's embedded snapshot
     copy stays byte-identical;
   - `DIAG_NO_PREREQUISITE` and `DIAG_PROBE_UNAVAILABLE` show their registered `user_text` (via 03.3).

   All of these are `Core` tests over real data plus constructed states, except the render check, which is a
   `RenderingTests` test.
5. **Entries**:
   - "Start expedition" consumes the in-memory Include queue: the queued node is slot 1, and the queue is
     emptied.
   - "Unit expedition" runs only that unit's nodes plus `blocked` nodes (D46).
   - `EXP_NO_FRINGE` on an empty fringe returns its registered text and starts no run.
   - "Start another" composes a fresh run from the post-run state.
   - "Back to the map" mid-run yields exactly one `abandoned: true` entry for the run. A simulated kill
     (dropping the session after any call and re-reading the file) yields exactly one `abandoned: true` entry
     with that call's counts. A session that skips the write-ahead fails the simulated-kill case (negative
     control) (expedition W5, Q6; arbiter-04 § Q-G).
6. **MathView**: `RenderingTests` render every `prompt_latex` and `choices[].latex` in `data/demo` (80 strings:
   40 + 40 [SOURCED: tasks/arbitration/arbiter-04-predispatch.md § Q-B, count over `data/demo/nodes.json`])
   through `MathView`'s own entry point without a parse error. Empty set = FAIL. `MathView` is used only for
   those fields and an `mc` `correctAnswerDisplay`. The failure path shows the unmodified source as plain text
   (§9 Q-E) and is covered by one planted unparsable string.
7. **Input (I10)**: the keypad key set (a `Core` constant) types every `numeric` `answer.value` in `data/demo`.
   An `mc` answer is submitted as the choice id. The extended `App/Sources` scan is green, and its planted
   violations fail it: a free-text answer field, a direct `ItemChecker`/`ExpeditionRun`/`DiagnosisRun` call, a
   Vision/PencilKit import, and a model-framework import.
8. **C1 seam — App ↔ `Core` state transitions**:
   - the App build is green;
   - every Door button's action is exactly one façade call (source scan over the Door view files, with a
     negative control);
   - the `Core` tests of items 1 and 2 drive the **same** façade entry points the buttons call;
   - the render side of the seam is evidenced by logic, composition and static wiring only. The 04b task specs
     and the acceptance report state verbatim what it cannot claim (arbiter-04 § Q-C): (1) that any tap on a
     simulator actually fires its action — hit-testing, sheet and navigation presentation, and keypad key →
     string binding at runtime; (2) that each Door screen is laid out so its controls are visible and reachable
     (e.g. continue and decline are on screen); (3) that no runtime trap occurs along the Door screens after
     launch (the smoke covers launch and relaunch only); (4) that the sequence of screens a student sees matches
     the façade's screen values at runtime, rather than only in `CoreTests` (C3; §9 Q-C).
9. **Contract**: `interaction-contract.md` reads v1.0.0 and carries the three § 2 bullets landed at v0.9.3
   (answer-card timing, summary content, in-run log entry). § Finalization owed by the Demo EPIC keeps its
   heading and reads the ruled paragraph, ending "Finalized at v1.0.0." `domain-glossary.md` reads v1.0.1.
   `docs/DEFERRED.md` holds the two ruled entries in the C6 template: region tint deltas on the expedition
   summary (Q-A) and hint tiers 2–3 (Q-F) (arbiter-04 § Q-A, § Q-B, § Q-F).
10. **Acceptance record template**: `docs/epics/demo-acceptance-record.md` holds:
    - per-tester (A, B) blanks for DEMO-BRIEF §7 items 1–5, v2.1 §D item 6 and v2.6 §D item 7, quoted from
      their sources, with "No numeric pass threshold" carried over;
    - the §8 checklist as amended: the surviving DEMO-BRIEF §8 lines (L0 passes, deterministic layout,
      landmark `source_url` resolves) plus v2.2 §B ("builds and runs on a physical iPhone; one expedition and
      one diagnosis event completable by touch; state survives app relaunch; layout deterministic across
      launches; landmark source URL resolves");
    - the v2.2 §B clause "one expedition and one diagnosis event completable by touch" split into two lines:
      *simulator — agent* (logic, composition and wiring, naming the instruments — the `Core` C1 façade tests,
      the one-call-per-button source scan, the App build and EPIC 03's launch smoke — and exclusions 1–4 of §4
      item 8), and *device — owner* (the literal tap-through, D29) (arbiter-04 § Q-C);
    - on each line, its owner (*simulator — agent*, with the gate or instrument that evidences it, or *device —
      owner*) and a blank result;
    - the wrap's agent half filled in with instruments; the owner half left blank.

## 5. Conformance tests it must ship (B.1)
- **expedition** (§ Invariants enforced here):
  - I3: "a test asserts every `ItemResult` rendering includes them". Delivered at the `Core` screen-content
    level (§4 item 3), because there is no App test target.
  - I1 / I10: checking only in `Core`; the App passes raw input; the scan asserts no App-side check and no
    free-text field.
  - I14: the view calls `Core`; the flow is a `Core` façade.
  - D27: one retry and one Door A event per run, as a façade-level property.
- **diagnosis** (§ Invariants enforced here):
  - I4: the budget is checked before any probe or remediation exists; at the Demo budget, a confirmed probe
    caps and blocks.
  - I3: "every terminal path shows the item answers already given (W3) and never gates them".
  - I2: every path completes with no adapter.
  - I1 / I10: probe items are checked in code.
  - I5: façade values carry ids, enums and strings resolved from the bundle only.
- **Contract rungs marked EPIC-time** (`contracts/README.md`):
  - interaction-contract "state-machine property tests in `CoreTests`", extended to the façade (D27 once per
    run, I3 per item, I4 cap);
  - error-codes "`Core` error enum mirrors the registry", which stays green;
  - the userText parity (03.3), which stays green.
- **C1:** App ↔ `Core` state transitions (§4 items 1, 2, 8).

## 6. Dependencies on prior EPICs
- **EPIC 02b** (merged): the step-wise `DiagnosisRun` (02.11, per `tasks/arbitration/arbiter-02-11-stepwise-api.md`
  and, for `hintKey`, `tasks/arbitration/arbiter-02-none-of-these.md` Ruling 3), the prerequisite query and
  classify (02.10), and data-model v1.4.0 (02.9). At arbitration,
  `Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift` was absent on `main` at 590f40c; "merged" must be
  true before dispatch (arbiter-04 § Other claims verified).
- **EPIC 03**, both halves merged (03a map core, 03b map app, per `docs/plans/epic-03-plan.md`). This EPIC uses:
  - `interaction-contract.md` v0.9.2 (03.1) and `PLATFORM_SNAPSHOT_REFUSED` (03.2);
  - the `CoreError` userText table (03.3);
  - the `StudentState` store (03.5);
  - the façade, session and launch (03.7), including `checkHere` → `DiagnosisEvent`, `unitExpedition` →
    `ComposeResult` and the in-memory Include queue;
  - the App shell and simulator smoke (03.12), the I14 source scan (03.9), and the placeholder hand-off
    destination (03.11) that this EPIC replaces.
- **EPIC 01**: `Rendering` package (`RenderCheck`, `BundleRenderCheckTests`) and `data/demo` (20 nodes, 40
  items) [SOURCED: docs/epics/epic-03-app-map-shell.md §6, citing docs/audits/epic-01-acceptance.md §2].
- Domain order: the map is the record (v2.5 §3), so the Door screens return to a map that re-derives from the
  new state (map W6, EPIC 03). The Tier-0 flow is complete before any Tier-1 adapter (EPIC 13).
- No dependency on EPICs 05–13.

## 7. Out of scope
1. **Tier 1 anything**: the "what did you do?" line on the hypothesis card, `classify` suggestion, and `reword`.
   EPIC 13 (diagnosis Q1 Tier-1 half; runtime-tiers).
2. **Hint tiers 2–3 ("ask for the next hint")**: the Demo shows one hint tier (DEMO-BRIEF §3.6: "Show the
   original node's hint (hand-written, one level)"). A DEFERRED entry is written in task 1 (the only EPIC 04
   writer of `docs/DEFERRED.md`), trigger Demo observations or EPIC 12 (§9 Q-F).
3. **Summary region-tint deltas** (§9 Q-A, confirmed). A DEFERRED entry is written in task 1, trigger Demo
   observations (DEMO-BRIEF §7 items 2 and 3).
4. **WKWebView/KaTeX fallback rendering** (`render_fallback: "katex"`): no `data/demo` string needs it [SOURCED:
   docs/epics/epic-01-rendering-spike-outcome.md, 0 unresolved]. Trigger: EPIC 09's generated learning
   objects carrying the flag.
5. **Door A homework mode** (D-4, trigger M5) and **OCR/handwriting** (D-8, trigger post-release; I10).
6. **Telemetry client and consent switch**: EPICs 10–11. Events stay in-process.
7. **Persisting the Include queue or an in-progress run across relaunch**: no `StudentState` field exists, and
   adding one is a data-model BUMP. Expedition Q6 is met without a field: the in-run write-ahead logs an
   OS-terminated run as abandoned, and the next launch starts fresh (§9 Q-G).
8. **Streaks, badges, Game Center** (D-7) and **animation beyond a basic transition** (D24; DEMO-BRIEF §4).
9. **UI localisation** (D-1) and **accessibility polish** (DEMO-BRIEF §4).
10. **Physical-device verification** (D29): the owner fills the device half of the acceptance record. No
    agent claims it.
11. **Running the tester sessions and deciding M3 go/revise**: an owner Q5 checkpoint by design
    (`docs/epic-plan.md`: "a Q5 checkpoint by design, not a stop"). This EPIC ships only the template.
12. **Hosted content, sync, merge**: EPIC 10. The EPIC 10 sync spec must handle the in-run provisional
    `expedition_log` entry (§9 Q-G note).

## 8. Size estimate
**8 work tasks + wrap(s)** [ESTIMATE: EPIC 03's planner found 11 work tasks against a similar-looking brief;
this one is expected to exceed the 8-task cap once wraps are counted; task 1b was added by the hint-fallback
reconciliation]. The recommended split is at the **Door-façade seam**, the same way EPIC 03 split at its map
façade:

- **04a — Door core** (all `Core` + the contract; gate `Core-Package`):
  1. Contract: interaction-contract v0.9.3 (§9 Q-A, Q-G), domain-glossary v1.0.1 (§9 Q-B, with the
     reconciliation Rule 5 texts: header, Remediation, Error type), the three `docs/domains/diagnosis.md` edits
     (Q-B ×2 in the Rule 5 wording, Q-D ×1), the `docs/domains/learning-objects.md` Rule 5 edits, and both
     DEFERRED entries (Q-A tint deltas, Q-F hint tiers).
  1b. Demo data (ordered after task 1 and before task 3; it must not run concurrently with EPIC 03's 03.4,
     which §6's "EPIC 03 merged" already ensures): `hint_tree["none-of-these"]` on every `data/demo` node, per
     the §2 "Demo data" bullet and reconciliation Rule 4. File scope, the cascade included:
     - `data/demo/nodes.json`;
     - 03.4's embedded snapshot copy of `data/demo`, kept byte-identical (its byte-identity test);
     - `docs/epics/epic-01-rendering-spike-outcome.md`, the hint-tree and total rows, recomputed by the task's
       scan (§3 R-6 Rendering line);
     - the pinned table in `Packages/Rendering/Tests/RenderingTests/OutcomeRecordAndImportBoundaryTests.swift`,
       and the "63/143" comment in `FieldKindPolicyMutationTests.swift`;
     - `data/demo/manifest.json`, only if a landed task has replaced its placeholder `asset_version`/`sha256`
       values, restamped with `pipeline/src/mathmath_pipeline/bundle.py`; while they are placeholders it is
       left alone (arbiter-03 § Q-H);
     - the `CoreTests` data assertions of §4 item 4.

     Instruments are those of §4 item 4's data bullet. No SymPy/CAS step applies: hints are neither ProbeItem
     answers nor WorkedExample steps. Agent-authored, machine-verified, no human review step (I9).
  2. Door B façade and screen-content values: Start expedition / unit expedition entry / answer / continue /
     retry / Q5 line / end / abandon, persistence after every call with the in-run write-ahead (Q-G), the
     keypad key-set constant, I3 card guard (§4 items 1, 3, 5, 7-Core half).
  3. Door A façade: both triggers, `misses` assembly, the step API threading, hypothesis / probe /
     remediation / further-offer / terminal content, hint key→prose per reconciliation Rule 2 (in-module
     `hintKey`; the none-of-these tier 1, else the paraphrase, never another type's hint), the remediation
     selector with the hint part omitted on a `nil` key, the `CoreError.loHintNotFound` case (the only EPIC 04
     writer of `CoreError.swift`), the Door copy constants (Q-D), resume, and the **C1** façade-level full
     expedition + diagnosis test (§4 items 2, 4). Depends on task 1b, so its real-data tests exercise the
     resolving path.
  4. 04a wrap.
- **04b — Door app** (`App/Sources` + `Packages/Rendering` + the record):
  5. `MathView` in `Rendering` with its `RenderingTests`, the plain-text fallback and field routing (§4 item 6;
     §9 Q-E).
  6. App item view, keypad or choices, answer card, retry, and summary; the "Start expedition" button; the
     placeholder hand-off replaced for "Unit expedition" and "Include".
  7. App hypothesis card sheet, probe, remediation, further-level offer, and return (to the run or the node
     panel), for both triggers; the extended `App/Sources` scan with its negative controls; the Q-C exclusion
     text verbatim in the task specs (§4 items 7, 8).
  8. `docs/epics/demo-acceptance-record.md` template with the split v2.2 §B line, and the wrap with the v1.0.0
     flip (§4 items 9, 10). The planner may fold the template into the wrap.

**Mapping to the planner's split** (`docs/plans/epic-04-plan.md`: 04a = 04.1–04.6, 04b =
04.7–04.13, plus task 1b). The arbiter-04 rulings use the task numbers above; they map as 1 → 04.1; 1b → a new
04a plan id between 04.1 and 04.3, assigned by the planner without renumbering existing ids, on which 04.3 then
depends (04a becomes 7 tasks including its wrap); 2 → 04.2, 04.4, 04.5
(the write-ahead sequencing lands in 04.5, the only writer of EPIC 03's session file); 3 → 04.3; 5 → 04.7;
6 → 04.8; 7 → 04.9, 04.10; 8 → 04.11, 04.12 (the v1.0.0 flip), 04.13. Two plan lines predate the rulings:
04.1's "the expedition.md Q6 narrowing (Q-G)" is superseded — Q-G lands as the interaction-contract "In-run log
entry" bullet, with no `expedition.md` edit — and 04.1 also carries the glossary v1.0.1 commit, the two
diagnosis.md Q-B edits and the learning-objects.md edits. The plan's "Q-H" is `tasks/arbitration/arbiter-02-none-of-these.md` (§9
cross-reference); the plan already gates 04.3 on it. Its conflict with arbiter-04 § Q-B is reconciled by
`tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md`, which also fixes 04.1's glossary, diagnosis.md
and learning-objects.md texts and adds task 1b.

**File-ownership notes for the planner:**
- The "Start expedition" entry touches EPIC 03's façade file (03.7). Exactly one 04a task writes it.
- The 03.9 scan's allow-list is widened by exactly one 04b task.
- `ContentView.swift` / `MathmathApp.swift` are written by at most one task.
- `CoreError.swift` is written by exactly one task (task 3 / 04.3); `docs/DEFERRED.md` by exactly one (task 1 /
  04.1).
- `data/demo/**`, 03.4's embedded snapshot copy, the spike outcome record and its pinning test are written by
  exactly one task (task 1b).
- The D-13 directory is never staged.

**Seams (C1) added:** App ↔ `Core` state transitions (façade-level test in 04a; scan and build in 04b).

## 9. Open questions
All of Q-A … Q-G are **resolved** (2026-09-10). The pre-dispatch arbiter rulings are in
`tasks/arbitration/arbiter-04-predispatch.md` (no ESCALATE-Q5; no locked decision D1–D49 or invariant
changed). The entries below keep their original analysis. The one conflict between two arbiter rulings (the
cross-reference entry after Q-B), which touched the Q-B hint fallback, is **reconciled** by
`tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md` (Q4; no ESCALATE-Q5).
- **Q-A — The two remaining § Finalization items** (contract discovery zone, delegated to "the Demo EPIC"; not a
  D-number, so **not Q5**). They are routed to the spec-arbiter pre-dispatch (Q4) for confirmation of the
  normative text, as EPIC 03's Q-B was.
  - **RESOLVED — CONFIRMED** (arbiter-04 § Q-A). The card stays until an explicit continue, and continue is a
    `Core` façade entry point (not an App-only flag), so the §4 item 3 guard is assertable in `CoreTests`;
    continue triggers no write. The summary shows no region tint delta; the per-region fraction alternative is
    rejected under content-policy § Voice ("no scores or percentages on student surfaces"). Exact contract
    text: v0.9.3 patch in task 1, v1.0.0 flip at the wrap; DEFERRED entry "Region tint deltas on the
    expedition summary" in task 1 (§3, §4 item 9).
  - *Answer-card timing.* **Default:** the card stays until the student taps an explicit continue control. There
    is no auto-advance and no timer, so the answer is never withheld (I3, D5). Rationale: any timeout could hide
    the answer before it is read.
  - *Summary region tint deltas.* **Default:** not shown. The summary lists what expedition W5 names (nodes
    cleared, fog lifted, blocked marked, "Start another"), and the re-derived map shows the tint on return (map
    W6). A DEFERRED entry is added, trigger Demo observations (DEMO-BRIEF §7 items 2, 3). **Alternative:** a
    `Core`-derived per-region before/after fraction on the summary. That adds no task.
  - **Revisit trigger:** the arbiter's pre-dispatch ruling.
- **Q-B — Remediation content in the Demo.** The glossary defines "**Remediation** — one Explanation or
  WorkedExample for a confirmed candidate", but `data/demo` carries no `explanation` and no `worked_examples`
  (0 entries of each [SOURCED: docs/epics/epic-01-rendering-spike-outcome.md, per-field-kind table]).
  DEMO-BRIEF §3.6 says "Fail → mark X `blocked`, show X's paraphrase and one hint, then return". **Default:** a
  `Core` function picks the piece: `explanation` if present, else the first worked example, else the
  candidate's `paraphrase` plus its tier-1 hint keyed by `Classify` over the probe's misses (with
  the `none_of_these` fallback). It is never empty, and no new code is needed. Because this reads a glossary
  definition against shipped data, it is **Q4 → spec-arbiter** pre-dispatch. **Revisit trigger:** EPIC 09
  generates explanations.
  - **RESOLVED — CONFIRMED with a correction** (arbiter-04 § Q-B). The "`none_of_these` fallback" matches no
    hint in `data/demo`: no node has a `none-of-these` / `none_of_these` `hint_tree` key, and on `data/demo`
    every `map_check_here` event classifies as the abstention outcome. `CoreError` gains
    `loHintNotFound = "LO_HINT_NOT_FOUND"` (already registered, internal; no `error-codes.json` entry).
    Remediation order is confirmed; every `data/demo` node takes the `paraphrase` + tier-1 hint branch.
    Glossary v1.0.1 and the two `docs/domains/diagnosis.md` edits land in task 1. arbiter-04's own generic-hint
    definition (the first `error_types[]` member with a `hint_tree` entry) and its empty-`hint_tree` branch are
    **superseded** by the reconciliation below.
  - **RECONCILED** (`tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md`, Rules 1–5):
    - "the node's generic tier-1 hint" is `hint_tree["none-of-these"][0]`, a node-level hint naming no specific
      mistake, and never another error type's hint (I2); 02.11's `hintKey` is unchanged;
    - `LO_HINT_NOT_FOUND` is raised as internal data by task 3's `Core` hint resolver (Rule 2 table), never in
      02.11, never thrown and never shown;
    - when the key is `nil`, every hint slot shows the origin node's `paraphrase`, never blank and with the code
      never on screen, and remediation drops the hint part;
    - a new data task (task 1b) adds `hint_tree["none-of-these"]` to every `data/demo` node, so the `nil` branch
      is unreachable on `data/demo` but stays live for any bundle without the entry;
    - task 1 carries the Rule 5 glossary v1.0.1, diagnosis.md and learning-objects.md texts, which spell the
      catalogue id `none-of-these` and the classify outcome `none_of_these`. `Classify.swift` and 02.11 are not
      edited.
- **Cross-reference — the none-of-these spelling** (`tasks/arbitration/arbiter-02-none-of-these.md`,
  2026-09-10; the planner's "Q-H"; it gates 04.3).
  - **Agreements with arbiter-04 § Q-B:**
    - there are two distinct tokens: `none_of_these` is the classify outcome and `none-of-these` is the
      catalogue id;
    - neither `Classify.swift` nor its tests change (Ruling 1, F1);
    - today, in `data/demo`, no node has a `hint_tree` entry for the none-of-these member in either spelling
      (finding 4). Task 1b adds the `none-of-these` entry.
  - **Wording aligned here:** 02.11's `hintKey(originNode:errorTypeId:) -> String?` returns the classified error
    type when its entry exists, else `"none-of-these"` when that entry exists, else `nil`, and never
    `"none_of_these"` (Ruling 3). This brief's resolver consumes that key, so `hintErrorTypeId` may be `nil`.
    On `data/demo` it is `nil` on every abstaining hint terminal until task 1b lands, and `"none-of-these"`
    after it.
  - **Conflict — RECONCILED** (`tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md`). arbiter-04 § Q-B
    rule 1 showed the first `error_types[]` member's tier 1 and called it no guessed diagnosis;
    arbiter-02-none-of-these Ruling 3 forbade that substitution under I2. The reconciliation upholds Ruling 3
    and defines the generic hint as the none-of-these branch (§9 Q-B, RECONCILED). It replaces
    arbiter-02-none-of-these F2's "renders no hint prose" with the paraphrase, and corrects that ruling's
    premise that `LO_HINT_NOT_FOUND` is unregistered (`contracts/error-codes.json` registers it, internal). The
    earlier sentence "no lookup of either spelling is required to succeed" (arbiter-04's naming note, carried
    here as "nor the data change" and "the naming split is not fixed") is **withdrawn**: `"none-of-these"` is a
    lookup that succeeds on `data/demo` after task 1b.
  - **What it reached, now settled:** the §2 hint and remediation bullets, the §3 I2 line and the §4 item 4 hint
    bullet (task 3 / 04.3); the trigger of `CoreError.loHintNotFound` (task 3); the domain-glossary v1.0.1
    texts, the two diagnosis.md Q-B edits and the learning-objects.md edits (task 1 / 04.1); and the new data
    task 1b. Parts of 04.1 that the conflict did not touch (interaction-contract v0.9.3, the Q-D edit,
    DEFERRED) and 04.2 are unaffected.
- **Q-C — Proving "completable by touch on the simulator" without an App test target.** The pbxproj has one
  native target, and "Agents add files under `App/Sources` and `Packages/Core` **without editing the
  pbxproj**" (`docs/tech-stack.md` §1). The options:
  1. **Façade-script evidence (default, no owner action).** The `Core` C1 tests (§4 items 1, 2) drive the exact
     façade entry points the buttons call through a full expedition and a full diagnosis on real data. The
     source scan proves each button is one façade call. The App build and EPIC 03's launch smoke prove the
     screens compile and launch. The literal tap-through is an explicit **exclusion** on the agent side (C3),
     recorded in the acceptance report. The owner performs it on the simulator or device and records it in the
     acceptance record's owner half.
  2. **XCUITest.** The tool is allowed ("XCTest only where UI testing needs it", `docs/tech-stack.md` §1), but it
     needs a UI-test target and a scheme test action, which is an **owner-only pbxproj edit**. With it, a gate-4
     XCUITest would tap one expedition and one diagnosis on the simulator, and the agent half would cover touch.
  3. **Rejected:**
     - a launch-argument autopilot inside the App (arbiter-03 § Q-G: "launch-argument hook is **not**
       permitted");
     - third-party simulator drivers (not named in `docs/tech-stack.md`, so BLOCK);
     - an agent clicking the simulator by hand (not a reproducible gate instrument).

  **Default: option 1.** The epic-plan row's "completable by touch on the simulator (§8)" is then evidenced by
  logic and composition, not by taps. **Q5 candidate, non-blocking:** the owner may choose option 2 before
  dispatch by adding `mathmathUITests` to the pbxproj. The EPIC proceeds on option 1 if the owner does not.
  **Revisit trigger:** the owner adds a UI-test target (then 04b gains one XCUITest task, and it may exceed
  the cap).
  - **RESOLVED — proceed on option 1** (arbiter-04 § Q-C; the option-2 choice stays the owner's, non-blocking).
    The epic-plan row criterion is **not claimed literally**. The exclusions 1–4 are stated verbatim in the 04b
    task specs and the acceptance report (§4 item 8), and the v2.2 §B "completable by touch" line is split into
    a *simulator — agent* half and a *device — owner* half (§4 item 10). If the owner adds `mathmathUITests`
    before dispatch, exclusions 1, 3 and 4 move to the agent side for the scripted path.
- **Q-D — Glossary vs domain copy.** Diagnosis W3 step 1 gives the copy "two quick questions, about a minute",
  and the glossary bans "question" for an Item. **Default:** the student-facing string reads "two quick checks,
  about a minute". It is rendered from `Core`, and the wrap (f) copy grep stays green. This is Q4 → spec-arbiter
  (a domain-doc text fix, owned by the arbiter's cascade). The same grep applies to v2.1 §D item 6's "start
  marker" wording: the template quotes it as source text and labels it "course-progress marker". **Revisit
  trigger:** the arbiter's ruling.
  - **RESOLVED — CONFIRMED** (arbiter-04 § Q-D). The line is exactly "Two quick checks, about a minute.", a
    `public static let` constant in `Core`'s Door A screen-content file, rendered verbatim. `docs/domains/diagnosis.md`
    W3 step 1 is edited to "two quick checks, about a minute" in task 1. The "start marker" handling is
    confirmed. Accept/decline labels are left to the task-3 spec and must pass the glossary grep.
- **Q-E — `MathView` parse failure at runtime.** **Default:** show the LaTeX source as plain text (never blank,
  I3). It is unreachable for a gated bundle (§4 item 6). No student code is registered, and the internal
  `LO_ITEM_UNRENDERABLE` stays pipeline/test-side. Technical default. **Revisit trigger:** EPIC 09's generated
  items.
  - **RESOLVED — CONFIRMED** (arbiter-04 § Q-E). The fallback lives in `Rendering` (I14) and also covers
    `render_fallback: "katex"` items. `MathView` is used only for `prompt_latex`, `choices[].latex` and an `mc`
    `correctAnswerDisplay`; the answer-card value carries a display-kind flag. The §4 item 6 population is the
    80 strings; empty = FAIL.
- **Q-F — Hint tiers.** **Default:** tier 1 only, per DEMO-BRIEF §3.6. The diagnosis actor row "ask for the
  next hint" is deferred with a DEFERRED entry at wrap. Technical default grounded in the Demo brief. **Revisit
  trigger:** Demo observations or EPIC 12.
  - **RESOLVED — CONFIRMED** (arbiter-04 § Q-F). Tier 1 only; DEFERRED entry "Hint tiers 2–3 ("ask for the next
    hint") on Door A screens" lands in task 1 (plan 04.1, the single `docs/DEFERRED.md` writer).
- **Q-G — An abandoned run vs OS termination** (expedition Q6: "a terminated run is logged as abandoned and the
  next launch starts fresh"). `ExpeditionRun.end(abandoned: true)` needs a live call, and `StudentState` has no
  in-progress-run field. **Default:**
  - "Back to the map" mid-run → `end(abandoned: true)`, persisted;
  - OS termination → the probe-log rows are already persisted per answer, and no `expedition_log` entry is
    written; the next launch starts fresh.

  This reads Q6's "logged as abandoned" narrowly, so it is **Q4 → spec-arbiter**. **Alternative:** a
  data-model BUMP for an in-progress flag (out of scope, §7 item 7). **Revisit trigger:** the ruling, or EPIC
  11's day-N telemetry needing abandoned counts.
  - **RESOLVED — CORRECTED** (arbiter-04 § Q-G). The narrow reading contradicts ratified expedition Q6. During a
    run every write persists what `ExpeditionRun.end(abandoned: true)` would produce at that moment; the
    natural end or "Back to the map" replaces it. No schema change and no `ExpeditionRun` edit. One contract
    bullet ("In-run log entry (expedition Q6)") lands in the v0.9.3 commit. §2 persistence and end, and §4
    items 1 and 5, are re-worded to the ruling's test obligations.
  - **Risk recorded for EPIC 10 (not built here).** `expedition_log` merges as a "multiset union by full-value
    equality" (`data-model.md` § StudentState merge). A sync snapshot taken mid-run would carry the provisional
    entry alongside the final one, and the merge would keep both. EPIC 10's sync spec must sync only at run
    boundaries or treat this explicitly. EPIC 04 has no sync.
- **Q5 candidates:** only Q-C option 2, which is optional and non-blocking. Q-A, Q-B, Q-D and Q-G are contract
  or doc realisations for the spec-arbiter. Q-E and Q-F are technical defaults. No locked decision D1–D49 is
  changed. *Post-arbitration:* the arbiter raised no ESCALATE-Q5; Q-C option 2 remains the only (optional,
  non-blocking) owner choice. The Q-B / none-of-these conflict was an arbiter-to-arbiter reconciliation (Q4), not
  a D-number change, and it is reconciled with no ESCALATE-Q5.

## 10. Change log
| Date | Author | Change |
|------|--------|--------|
| 2026-09-10 | epic-scoper | Initial brief synthesized. |
| 2026-09-10 | brief-amender (arbiter pre-dispatch rulings `tasks/arbitration/arbiter-04-predispatch.md`; cross-reference `tasks/arbitration/arbiter-02-none-of-these.md`) | Status line; §2 (continue entry, end, in-run write-ahead persistence, Door A exits, answer-card display kind, cost line, remediation selector, hint resolver keyed on 02.11 `hintKey`, Door copy constants, summary, MathView fallback and routing, contract finalization); §3 (interaction-contract v0.9.3 + v1.0.0, domain-glossary v1.0.1 + diagnosis.md cascade, error-codes `loHintNotFound`, glossary identifier precision, R-6 registry and constants, no-entry re-check, I2/I3/I14 lines, artifact line); §4 criteria 1, 3, 4, 5, 6, 8, 9, 10; §6 02b pre-dispatch check; §7 items 2, 3, 7, 12; §8 task contents, plan mapping, file ownership; §9 Q-A…Q-G marked resolved, none-of-these cross-reference with the open Q-B conflict, EPIC 10 risk. Scope unchanged. See Amendment 04.00.1. |
| 2026-09-10 | brief-amender (reconciliation `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md`) | Status line; §2 remediation bullet (hint part omitted on a `nil` key), hint bullet (Rule 2 table, generic hint = `hint_tree["none-of-these"][0]`, `nil`-key paraphrase), new "Demo data" bullet, contract-finalization line, placement line; §3 glossary bullet (Rule 5 texts, learning-objects cascade), R-6 Rendering line (123/203), I2 line, new I9 line, artifact lines; §4 item 4 (hint bullet with two negative controls, new data bullet); §8 size, new task 1b, task 1 and 3 contents, plan mapping, file ownership; §9 preamble, Q-B reconciled, cross-reference conflict reconciled and the "no lookup required to succeed" sentence withdrawn, Q5 line. Every "contested" marker removed. One data task added; scope otherwise unchanged. See Amendment 04.00.2. |

## Amendment log

### Amendment 04.00.1 — 2026-09-10

**Trigger**: tier-6 brief-amender, invoked by the orchestrating session with the spec-arbiter's pre-dispatch rulings on Q-A … Q-G, before any EPIC 04 task is dispatched. The sequence number `00` marks the pre-dispatch amendment, which is tied to no task.
**Architect escalation**: none on disk. The brief itself routed Q-A, Q-B, Q-D and Q-G to the spec-arbiter (Q4) and submitted Q-E, Q-F and the Q-C default path for confirmation. The rulings are in `tasks/arbitration/arbiter-04-predispatch.md`. Cross-referenced: `tasks/arbitration/arbiter-02-none-of-these.md` (appeared during this amendment).

**Passage 1 — §4 acceptance criterion 1, persistence bullet (arbiter-04 § Q-G, "Test obligations", item 1).**

**Original brief text**:
> - the state file is written after every state-changing call;

**Amended brief text**:
> - during the run, after every state-changing call, the decoded state file equals the threaded state plus
>   exactly one trailing `abandoned: true` `expedition_log` entry matching `end(abandoned: true)` computed from
>   the current run; after the natural end it holds exactly one entry for the run, with `abandoned: false`
>   (arbiter-04 § Q-G);

**Passage 2 — §4 acceptance criterion 5, abandon bullet (arbiter-04 § Q-G, "Test obligations", item 5 and negative control).**

**Original brief text**:
> - "Back to the map" mid-run logs the run as `abandoned: true` (expedition W5, Q6).

**Amended brief text**:
> - "Back to the map" mid-run yields exactly one `abandoned: true` entry for the run. A simulated kill
>   (dropping the session after any call and re-reading the file) yields exactly one `abandoned: true` entry
>   with that call's counts. A session that skips the write-ahead fails the simulated-kill case (negative
>   control) (expedition W5, Q6; arbiter-04 § Q-G).

**Passage 3 — §2 Door B persistence bullet (arbiter-04 § Q-G, "In-run write-ahead", "Backgrounding").**

**Original brief text**:
> - **Persistence**: the whole `StudentState` is written after every state-changing call, through EPIC 03's
>   store. A failed write surfaces `EXP_STATE_WRITE_FAILED` as a banner, and the summary still shows
>   (expedition W5 step 2).

**Amended brief text**:
> - **Persistence**: the whole `StudentState` is written after every state-changing call, through EPIC 03's
>   store. **During a run** (from the run-start call on, Door B and Door A calls alike), every write persists
>   what `ExpeditionRun.end(run: <current run>, state: <threaded state>, today:, abandoned: true).state` would
>   produce at that moment; the in-memory threaded state never carries that entry. The natural end
>   (`abandoned: false`) or "Back to the map" (`abandoned: true`) replaces it. A run the OS terminates is
>   therefore logged as abandoned and never resumed; nothing is written on backgrounding; no field is added
>   (arbiter-04 § Q-G; expedition Q6). A failed write surfaces `EXP_STATE_WRITE_FAILED` as a banner, and the
>   summary still shows (expedition W5 step 2).

**Passage 4 — §4 acceptance criterion 3, reachability sentence (arbiter-04 § Q-A, "Precision").**

**Original brief text**:
> No next-item, terminal or summary value is reachable without one.

**Amended brief text**:
> No next-item, probe-item, hypothesis-card, remediation, terminal or summary value is reachable without one,
> and only the façade's continue call moves past the card; continue changes no `StudentState` (arbiter-04
> § Q-A).

**Passage 5 — §4 acceptance criterion 4, cost-line and hint bullets (arbiter-04 § Q-D; § Q-B, "Brief § 4 item 4, re-worded bullet"; contested flag per arbiter-02-none-of-these F2).**

**Original brief text**:
> - the cost line is present, and decline is available (Q2);

> - the hint prose equals the `hint_tree` tier resolved from `hintErrorTypeId`, with the `none_of_these`
>   fallback;

**Amended brief text**:
> - the cost line reads exactly "Two quick checks, about a minute." (a `Core` constant), and decline is
>   available (Q2; arbiter-04 § Q-D);

> - the hint prose equals tier 1 of `hint_tree[hintErrorTypeId]` when that key exists, else the node's generic
>   tier-1 hint (first `error_types[]` member with a `hint_tree` entry), with `LO_HINT_NOT_FOUND` as internal
>   data when the fallback fires; a `map_check_here` event on `data/demo` exercises the fallback on every node
>   (arbiter-04 § Q-B). A resolver that returns empty prose on a missing key fails the test (negative
>   control). **Contested** by arbiter-02-none-of-these F2, which asks that a `nil` key with non-nil
>   `hintNodeId` render no hint prose (§9 cross-reference);

**Passage 6 — §4 acceptance criterion 6 (arbiter-04 § Q-E, precision 4 and population).**

**Original brief text**:
> **MathView**: `RenderingTests` render every `prompt_latex` and `choices[].latex` in `data/demo` through
> `MathView`'s own entry point without a parse error. Empty set = FAIL. The failure path follows §9 Q-E and is
> covered by one planted unparsable string.

**Amended brief text**:
> **MathView**: `RenderingTests` render every `prompt_latex` and `choices[].latex` in `data/demo` (80 strings:
> 40 + 40 [SOURCED: tasks/arbitration/arbiter-04-predispatch.md § Q-B, count over `data/demo/nodes.json`])
> through `MathView`'s own entry point without a parse error. Empty set = FAIL. `MathView` is used only for
> those fields and an `mc` `correctAnswerDisplay`. The failure path shows the unmodified source as plain text
> (§9 Q-E) and is covered by one planted unparsable string.

**Passage 7 — §4 acceptance criterion 8, render-side bullet (arbiter-04 § Q-C, "What it cannot claim").**

**Original brief text**:
> - the render side of the seam excludes tap execution. That exclusion is stated in the task spec and in the
>   acceptance report (C3; §9 Q-C).

**Amended brief text**:
> - the render side of the seam is evidenced by logic, composition and static wiring only. The 04b task specs
>   and the acceptance report state verbatim what it cannot claim (arbiter-04 § Q-C): (1) that any tap on a
>   simulator actually fires its action — hit-testing, sheet and navigation presentation, and keypad key →
>   string binding at runtime; (2) that each Door screen is laid out so its controls are visible and reachable
>   (e.g. continue and decline are on screen); (3) that no runtime trap occurs along the Door screens after
>   launch (the smoke covers launch and relaunch only); (4) that the sequence of screens a student sees matches
>   the façade's screen values at runtime, rather than only in `CoreTests` (C3; §9 Q-C).

**Passage 8 — §4 acceptance criterion 10, new bullet splitting the v2.2 §B touch line (arbiter-04 § Q-C, "The acceptance record must split").**

**Original brief text**: (no such bullet; the v2.2 §B line was quoted whole)

**Amended brief text**:
> - the v2.2 §B clause "one expedition and one diagnosis event completable by touch" split into two lines:
>   *simulator — agent* (logic, composition and wiring, naming the instruments — the `Core` C1 façade tests,
>   the one-call-per-button source scan, the App build and EPIC 03's launch smoke — and exclusions 1–4 of §4
>   item 8), and *device — owner* (the literal tap-through, D29) (arbiter-04 § Q-C);

**Passage 9 — §4 acceptance criterion 9 (arbiter-04 § Q-A exact text, § Q-B glossary, § Q-F DEFERRED).**

**Original brief text**:
> **Contract**: `interaction-contract.md` reads v1.0.0. § Finalization owed is replaced by the two
> resolutions (§9 Q-A) and the already-landed v0.9.2 marker resolution. A DEFERRED entry exists for any
> resolution that defers a behaviour.

**Amended brief text**:
> **Contract**: `interaction-contract.md` reads v1.0.0 and carries the three § 2 bullets landed at v0.9.3
> (answer-card timing, summary content, in-run log entry). § Finalization owed by the Demo EPIC keeps its
> heading and reads the ruled paragraph, ending "Finalized at v1.0.0." `domain-glossary.md` reads v1.0.1.
> `docs/DEFERRED.md` holds the two ruled entries in the C6 template: region tint deltas on the expedition
> summary (Q-A) and hint tiers 2–3 (Q-F) (arbiter-04 § Q-A, § Q-B, § Q-F).

**Passage 10 — §3 interaction-contract Finalization bullet (arbiter-04 § Q-A, "Exact normative text").**

**Original brief text**:
> **BUMP**. The remaining two items are resolved in a
> `contract(interaction-contract)` commit with the defaults in §9 Q-A, and the header goes to **v1.0.0** at
> this EPIC's wrap. The v0.9.2 marker item belongs to EPIC 03 and must have landed first. If the planner
> lands the two resolutions before the wrap, they go in as a v0.9.x patch and the wrap only flips the version
> to v1.0.0.

**Amended brief text**:
> **BUMP**, in two `contract(interaction-contract)` commits with the
> exact text of arbiter-04 § Q-A. **Task 1:** v0.9.2 → **v0.9.3** — the header and Source sentence; in § 2,
> the "Answer card (timing)" bullet after `answer(item)` and the "Summary content" and "In-run log entry
> (expedition Q6)" bullets after `end` (Q-A, Q-G); and the § Finalization paragraph replaced, heading kept.
> **Wrap:** → **v1.0.0** — the header, the Source sentence, and "Bump to v1.0.0 on wrap." replaced by
> "Finalized at v1.0.0."; no normative change. The v0.9.2 marker item belongs to EPIC 03 and must have landed
> first.

**Passage 11 — §3 domain-glossary line (arbiter-04 § Q-B, "Exact normative text" and "Cascade"; § Q-D cascade; § Other claims verified).**

**Original brief text**:
> - `contracts/domain-glossary.md` (v1.0.0): `READ-ONLY`. Expedition ("*Banned:* "quiz", "session" … "quest",

**Amended brief text**:
> - `contracts/domain-glossary.md` (v1.0.0): **BUMP to v1.0.1** in task 1 (a `contract(domain-glossary)` commit,
>   header text per arbiter-04 § Q-B). § Diagnosis (Door A) Remediation becomes: "**Remediation** — one
>   Explanation or WorkedExample for a confirmed candidate; when the node carries neither, its `paraphrase` plus
>   one tier-1 hint (DEMO-BRIEF §3.6)." Cascade in the same task, exact text in the ruling: `docs/domains/diagnosis.md`
>   § Core entities and § UI surfaces (Q-B), and W3 step 1 (Q-D). The "plus one tier-1 hint" wording is touched
>   by the open conflict (§9 cross-reference). Otherwise `READ-ONLY`. Expedition ("*Banned:*
>   "quiz", "session" … "quest",

The same bullet also gains two additions. The first: "New EPIC 04 identifiers and copy use no "Session", "Quiz" or "Question"; EPIC 03's landed session type name is reused as-is, never duplicated (arbiter-04 § Other claims verified)". The second: "(resolved)", placed after "§9 Q-D records one copy conflict".

**Passage 12 — §2 hint and remediation bullets (arbiter-04 § Q-B, Rulings 1 and 2; key source per arbiter-02-none-of-these Ruling 3).**

**Original brief text**:
> - **remediation**: the one piece for the confirmed candidate (see §9 Q-B for Demo content);

> - the **hint**, resolved from the key `DiagnosisOutcome` carries (`hintNodeId`, `hintErrorTypeId`) to its
>   prose. The step API "Returns keys, never hint prose" (02.11 spec §4 step 5), so the key→prose lookup is a
>   `Core` function, not App code;

**Amended brief text**: see §2. The two bullets now say:
- **Remediation** takes the first of these that exists: `explanation`, then `worked_examples[0]`, then `paraphrase` plus the hint resolved for `(X, Classify.classify(probeResult.misses))`. It is never empty.
- **Hint:**
  - the key is 02.11 `hintKey`'s result: the classified error type, then `"none-of-these"`, then `nil`, and never `"none_of_these"`;
  - the prose is tier 1 of `hint_tree[key]`, else the node's generic tier-1 hint, else the `paraphrase` when `hint_tree` is empty;
  - `internalCode: .loHintNotFound` is returned when the fallback fires.
- Both bullets carry a **Contested** pointer to §9.

**Passage 13 — §3 I2 line (arbiter-04 § Q-B vs arbiter-02-none-of-these Ruling 3).**

**Original brief text**:
> - **I2** — Tier 0 only. Every Door A path completes with no adapter parameter in the call chain (02.11 AC11).
>   The façade adds none.

**Amended brief text**:
> - **I2** — Tier 0 only. Every Door A path completes with no adapter parameter in the call chain (02.11 AC11).
>   The façade adds none. arbiter-04 § Q-B holds that the generic tier-1 hint fallback asserts no `ErrorType`
>   and is not a guessed diagnosis; arbiter-02-none-of-these Ruling 3 holds that substituting another error
>   type's hint is guessing a diagnosis. This reading of I2 is **unresolved** (§9 cross-reference).

**Passage 14 — specificity from the rulings, with no deliverable added or removed.**
- §2:
  - the continue entry point (Q-A);
  - the natural end in the last-result call (Q-G);
  - Door A exits only by its own decisions (Q-G);
  - the answer-card display-kind flag (Q-E);
  - the cost-line constant and the fixed Door strings as `Core` constants (Q-D);
  - the summary shows no tint delta or fraction (Q-A);
  - `MathView`: the fallback, `render_fallback: "katex"` handling and field routing, with the line range corrected to `ItemChecker.swift:183-191` (Q-E; arbiter-04 § Other claims verified);
  - contract finalization in two steps, plus glossary v1.0.1.
- §3:
  - error-codes: the additive `loHintNotFound` case, with no registry entry;
  - the R-6 registry line gains `LO_HINT_NOT_FOUND`, and the constants line gains the Door copy;
  - the "planner re-checks … Q-B" sentence is replaced by the ruling's registry answer;
  - I3: continue is a façade call; I14: remediation selection, copy constants and write-ahead, with the fallback in `Rendering`;
  - the artifact line gains the glossary, diagnosis.md and DEFERRED artefacts.
- §6:
  - the 02b "merged" dependency must be true before dispatch; per the ruling, `DiagnosisEvent.swift` was absent on `main` at 590f40c;
  - `hintKey` is cited to arbiter-02-none-of-these Ruling 3.
- §7:
  - items 2 and 3: the DEFERRED entries are written in task 1. The ruling allows task 1 or the wrap; task 1 keeps the plan's single `docs/DEFERRED.md` writer, 04.1;
  - item 7: Q6 is met by the write-ahead;
  - item 12: the EPIC 10 sync note.
- §8:
  - task contents per arbiter-04 § Consequences for the planner;
  - the mapping of the ruling's task numbers to `docs/plans/epic-04-plan.md` ids;
  - file-ownership lines for `CoreError.swift` and `docs/DEFERRED.md`.
- §9: every Q-A … Q-G entry is marked RESOLVED with a pointer, the original analysis is kept, and a cross-reference entry is added for the second ruling.

**Plan consistency (`docs/plans/epic-04-plan.md`; not edited, because it is outside brief-amender write authority).**
- The 04a/04b split is unchanged (04.1–04.6 / 04.7–04.13), and the brief now maps onto it (§8).
- The plan's 04.1 line "the expedition.md Q6 narrowing (Q-G)" predates the ruling and is superseded. Q-G lands as the interaction-contract "In-run log entry" bullet, and no `expedition.md` edit is owed.
- 04.1 also carries the glossary v1.0.1 commit and the two diagnosis.md Q-B edits.
- 04.3 is the only writer of `CoreError.swift`, and 04.5 carries the write-ahead sequencing.
- The plan already gates 04.3 on arbiter-02-none-of-these. The conflict below also reaches 04.1's glossary and diagnosis.md Q-B text.
- Where the plan's summary lines differ from the brief, spec writers follow the brief.

**Cross-reference and conflict — `tasks/arbitration/arbiter-02-none-of-these.md`.** This file appeared while the amendment was in progress. It was read in full and aligned where it agrees with arbiter-04 § Q-B:
- two distinct tokens;
- no change to `Classify.swift` or the data;
- 02.11 `hintKey` returns the classified error type, then `"none-of-these"`, then `nil`, and never `"none_of_these"`;
- `hintErrorTypeId` may therefore be `nil`, and on `data/demo` it is `nil` on every abstaining terminal.

**The two rulings conflict, and this amendment does not choose between them.** The conflict is on the missing/`nil`-key branch:
- arbiter-04 § Q-B rule 1 shows the node's generic tier-1 hint, meaning another error type's tier 1. It states this "is not a guessed diagnosis (I2)".
- arbiter-02-none-of-these Ruling 3 forbids exactly that substitution as "guessing a diagnosis (`CLAUDE.md` I2)".
- Its F2 asks EPIC 04 to render no hint prose for a `nil` key, and to define that presentation. It names DEMO-BRIEF §3.6 and the origin's `paraphrase` as candidates.

What the brief records:
- It carries arbiter-04's text, as the invoking session instructed.
- It marks that text **contested** at every site the conflict reaches: §2 hint and remediation, the §3 glossary line and I2 line, and the §4 item 4 hint bullet.
- It routes reconciliation to the spec-arbiter (Q4). That must happen before 04.1's glossary/diagnosis.md Q-B commits and before 04.3 is dispatched.
- No D-number is involved. Whatever the reconciliation decides, the resulting reading of I2 must hold before either task runs.

**Source**: `tasks/arbitration/arbiter-04-predispatch.md` § Q-A, § Q-B, § Q-D, § Q-G, § Q-E, § Q-F, § Q-C, § Other claims verified in this run, and § Consequences for the planner. Those sections cite:
- `contracts/interaction-contract.md` § 2 Expedition and § Finalization owed by the Demo EPIC;
- `contracts/domain-glossary.md` § Diagnosis (Door A);
- `contracts/content-policy.md` § Voice;
- `contracts/error-codes.json`;
- `contracts/data-model.md` § Text and § StudentState merge;
- `docs/domains/expedition.md` Q6, `docs/domains/learning-objects.md` W2 and `docs/domains/diagnosis.md` W3;
- `DEMO-BRIEF.md` §3.5 and §3.6, and `AMENDMENT-v2.2.md` §B.

Also `tasks/arbitration/arbiter-02-none-of-these.md` Rulings 1, 3 and 4, and follow-ups F1 and F2.

**Effect on deliverables**: NONE (specificity added).
- The contract bumps, glossary patch, domain-doc edits and DEFERRED entries were already owed by the brief's §3 / §7 / §9 defaults. The rulings fix their exact text and the task each lands in.
- `error-codes.json` gains no entry. `CoreError` gains one additive case for an already-registered code.
- The open conflict could change the hint prose shown on abstaining terminals, but no deliverable is added or dropped.

**Effect on owner-facing acceptance**: NONE.
- The epic-plan row's "completable by touch" was already evidenced by logic and composition under the Q-C default. Splitting the acceptance-record line makes that explicit.
- The literal tap-through stays the owner's (D29).

### Amendment 04.00.2 — 2026-09-10

**Trigger**: tier-6 brief-amender, invoked by the orchestrating session with the spec-arbiter's reconciliation of the conflict Amendment 04.00.1 recorded as contested (arbiter-04-predispatch § Q-B vs arbiter-02-none-of-these). The sequence number `00` again marks a pre-dispatch amendment tied to no task.
**Architect escalation**: none on disk. The ruling is `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md` (Q4, no ESCALATE-Q5); its § "What the EPIC 04 brief and specs must reflect", items 1–7, lists the passages changed below. Amendment 04.00.1's log above is kept as history; its "contested" wording describes the brief as it stood then.

**Passage 1 — Status line (04.00.2 note).**

**Original brief text**:
> > Status: brief authored 2026-09-10 by epic-scoper; amended 2026-09-10 by brief-amender with the pre-dispatch
> > arbiter rulings (Amendment 04.00.1). One cross-ruling conflict on the hint fallback is open (§9
> > cross-reference). Owner decides dispatch; planner decomposes.

**Amended brief text**:
> > Status: brief authored 2026-09-10 by epic-scoper; amended 2026-09-10 by brief-amender with the pre-dispatch
> > arbiter rulings (Amendment 04.00.1) and the hint-fallback reconciliation (Amendment 04.00.2). No cross-ruling
> > conflict is open (§9 cross-reference). Owner decides dispatch; planner decomposes.

**Passage 2 — §2 remediation bullet, tail (reconciliation item 2; Rule 3 "Remediation").**

**Original brief text**:
> `probeResult.outcome == .confirmed`. It is never empty (`paraphrase` is schema-required). At the Demo
> budget the `capped` screen shows it before the capped line (arbiter-04 § Q-B; see §9 Q-B). **Contested:**
> whether the hint part may use the generic fallback when classify abstains (§9 cross-reference);

**Amended brief text**:
> `probeResult.outcome == .confirmed`. The hint part is omitted when no key resolves, so the piece is then the
> paraphrase alone and the paraphrase is never shown twice. It is never empty (`paraphrase` is
> schema-required). At the Demo budget the `capped` screen shows it before the capped line (arbiter-04 § Q-B;
> arbiter-04-hint-fallback-reconciliation Rule 3; see §9 Q-B);

**Passage 3 — §2 hint bullet, from "(arbiter-02-none-of-these Ruling 3)." onward (reconciliation item 1; Rules 1–3).**

**Original brief text**:
> entry exists, else `nil`, never the outcome token `"none_of_these"` (arbiter-02-none-of-these Ruling 3).
> Given `(node, key)`: tier 1 of `hint_tree[key]` when that entry exists and is non-empty; else the node's
> generic tier-1 hint (tier 1 of the first `error_types[]` member, in catalogue order, with a `hint_tree`
> entry); else, when `hint_tree` is empty, the node's `paraphrase`. It returns the prose, the resolved key,
> and `internalCode: .loHintNotFound` whenever the fallback fired (arbiter-04 § Q-B; learning-objects W2).
> **Contested:** the generic-fallback branch for a missing or `nil` key conflicts with
> arbiter-02-none-of-these Ruling 3 and F2 (§9 cross-reference). Tier 1 only (§9 Q-F);

**Amended brief text**:
> entry exists, else `nil`, never the outcome token `"none_of_these"` and never another error type's key
> (arbiter-02-none-of-these Ruling 3). The resolver takes `(node, classifiedToken)`: `originErrorTypeId` for a
> terminal hint, `Classify.classify(probeResult.incorrectAttempts)` for remediation. It calls `hintKey`
> in-module (`hintKey` is `internal`), so nothing is reimplemented. With `expected` = `"none-of-these"` for the
> outcome token `"none_of_these"`, else the token itself:
> - key == `expected` → tier 1 of `hint_tree[key]`, `internalCode` nil;
> - key non-nil and ≠ `expected` (a classified type had no entry, so the none-of-these branch served) → tier 1
>   of `hint_tree[key]`, `internalCode: .loHintNotFound`;
> - key `nil` → the node's `paraphrase`, `internalCode: .loHintNotFound`.
>
> "The node's generic tier-1 hint" (learning-objects W2) is `hint_tree["none-of-these"][0]`, a node-level
> hint naming no specific mistake, and nothing else; the resolver never returns another error type's hint
> (I2). `LO_HINT_NOT_FOUND` is internal data, never thrown and never shown. When the key is `nil`, every hint
> slot (refuted, `DIAG_NO_PREREQUISITE`, `DIAG_PROBE_UNAVAILABLE`, declined-`unconfirmed`, the W1 abstention
> path) shows the origin node's `paraphrase` with no label naming a mistake: never blank, never a sibling
> type's hint, and the code never on screen; the prototype's "No hint written for that exact mistake yet"
> banner is not built (arbiter-04-hint-fallback-reconciliation Rules 1–3). Tier 1 only (§9 Q-F);

**Passage 4 — §2 new scope bullet, before `MathView` (reconciliation item 6; Rule 4).**

**Original brief text**: (no such bullet)

**Amended brief text**:
> - **Demo data: the none-of-these hint.** Every `data/demo` node gains `hint_tree["none-of-these"]`: three
>   non-empty plain-text tiers in the learning-objects HintTree voice (tier 1 nudges at what to look at, tier 3
>   works the step through), naming or describing no other `error_types[]` member's misconception (I2), with no
>   Ministry prose (I6). This delivers diagnosis W1 step 3 and W3 step 4 ("a tier-1 hint on the origin") and
>   DEMO-BRIEF §3.6 ("Show the original node's hint") on the Demo's commonest path, `map_check_here`. The data is
>   agent-authored and machine-verified with no human review step (I9), exactly as the hand-written Demo bundle
>   was in EPIC 01 (D26). No field is added: the schema already accepts the key (arbiter-04-hint-fallback-reconciliation
>   Rule 4; §8 task 1b).

**Passage 5 — §2 contract-finalization sentence and placement line (consequential on Passages 4 and 7).**

**Original brief text**:
> `domain-glossary.md` goes to v1.0.1 (Remediation; arbiter-04 § Q-B). See §3.

> Layers ② (nodes, edges) and ③ (probe items, hint trees, `why`) are read-only inputs.

**Amended brief text**:
> `domain-glossary.md` goes to v1.0.1 (Remediation and the two none-of-these tokens; arbiter-04 § Q-B;
> arbiter-04-hint-fallback-reconciliation Rule 5). See §3.

> Layers ② (nodes, edges) and ③ (probe items, hint trees, `why`) are read-only inputs, except that one data task
> (§8 task 1b) adds `hint_tree["none-of-these"]` to every `data/demo` node.

**Passage 6 — §3 domain-glossary bullet, head (reconciliation item 4; Rule 5).**

**Original brief text**:
> - `contracts/domain-glossary.md` (v1.0.0): **BUMP to v1.0.1** in task 1 (a `contract(domain-glossary)` commit,
>   header text per arbiter-04 § Q-B). § Diagnosis (Door A) Remediation becomes: "**Remediation** — one
>   Explanation or WorkedExample for a confirmed candidate; when the node carries neither, its `paraphrase` plus
>   one tier-1 hint (DEMO-BRIEF §3.6)." Cascade in the same task, exact text in the ruling: `docs/domains/diagnosis.md`
>   § Core entities and § UI surfaces (Q-B), and W3 step 1 (Q-D). The "plus one tier-1 hint" wording is touched
>   by the open conflict (§9 cross-reference). Otherwise `READ-ONLY`. Expedition ("*Banned:*

**Amended brief text**:
> - `contracts/domain-glossary.md` (v1.0.0): **BUMP to v1.0.1** in task 1 (a `contract(domain-glossary)` commit;
>   the exact header, Remediation and Error-type texts are in `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md`
>   Rule 5, which amends arbiter-04 § Q-B). § Diagnosis (Door A) Remediation becomes: "**Remediation** — one
>   Explanation or WorkedExample for a confirmed candidate; when the node carries neither, its `paraphrase` plus,
>   when one resolves, one tier-1 hint (DEMO-BRIEF §3.6)." The Error type line (:45) becomes: "**Error type**
>   (`ErrorType`) — a member of a node's closed catalogue, incl. the none-of-these member, whose catalogue id is
>   `none-of-these`; `classify` reports abstention as the outcome token `none_of_these`, which is never a
>   catalogue id or a `hint_tree` key." Cascade in the same task, exact text in the rulings:
>   `docs/domains/diagnosis.md` § Core entities and § UI surfaces (reconciliation Rule 5), and W3 step 1 (Q-D);
>   `docs/domains/learning-objects.md` catalogue-id spelling (:41-42, :47-48, :75, :77), the W2 step 1
>   generic-hint definition and a change-log row, with the Q4 heading keeping `none_of_these` (reconciliation
>   Rule 5). Otherwise `READ-ONLY`. Expedition ("*Banned:*

**Passage 7 — §3 R-6 Rendering line (Rule 4 cascade; count table 63→123, 143→203).**

**Original brief text**:
> records 0 unresolved of 143 [SOURCED: docs/epics/epic-01-rendering-spike-outcome.md]. → `READ-ONLY`. The
> runtime fallback is in §9 Q-E.

**Amended brief text**:
> records 0 unresolved of 143 [SOURCED: docs/epics/epic-01-rendering-spike-outcome.md]. Task 1b adds 60 hint
> tier strings; the outcome's hint row becomes 123 and its total 203 [SOURCED:
> tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md Rule 4, arithmetic 63 + 3×20 and 143 + 60],
> recomputed by the task's scan, not typed from this line, still with 0 unresolved. → `READ-ONLY`. The
> runtime fallback is in §9 Q-E.

**Passage 8 — §3 I2 line (reconciliation item 3, verbatim) and new I9 line (Rule 4 "I9").**

**Original brief text**:
> - **I2** — Tier 0 only. Every Door A path completes with no adapter parameter in the call chain (02.11 AC11).
>   The façade adds none. arbiter-04 § Q-B holds that the generic tier-1 hint fallback asserts no `ErrorType`
>   and is not a guessed diagnosis; arbiter-02-none-of-these Ruling 3 holds that substituting another error
>   type's hint is guessing a diagnosis. This reading of I2 is **unresolved** (§9 cross-reference).

**Amended brief text**:
> - **I2** — Tier 0 only. Every Door A path completes with no adapter parameter in the call chain (02.11 AC11).
>   The façade adds none. The hint fallback is `hint_tree["none-of-these"]`, else the paraphrase; it never borrows
>   another ErrorType's hint (arbiter-04-hint-fallback-reconciliation).

> - **I9** — task 1b's hint strings are agent-authored and machine-verified (schema, L0, render check, the
>   distinctness test); no human content-review step is added, as for the EPIC 01 Demo bundle (D26).

**Passage 9 — §3 artifact line, doc artefacts and new data artefacts (Rule 4, Rule 5).**

**Original brief text**:
> - **Doc artefacts (task 1)**: the three `docs/domains/diagnosis.md` edits (Q-B ×2, Q-D ×1) and two
>   `docs/DEFERRED.md` entries (Q-A tint deltas, Q-F hint tiers), exact text in arbiter-04.

**Amended brief text**:
> - **Doc artefacts (task 1)**: the three `docs/domains/diagnosis.md` edits (Q-B ×2, Q-D ×1), the
>   `docs/domains/learning-objects.md` edits (reconciliation Rule 5), and two `docs/DEFERRED.md` entries (Q-A
>   tint deltas, Q-F hint tiers), exact text in arbiter-04 and the reconciliation.
> - **Data artefacts (task 1b)**: `data/demo/nodes.json` with `hint_tree["none-of-these"]` on all 20 nodes, and
>   its cascade (§8 task 1b).

**Passage 10 — §4 item 4, hint bullet (reconciliation item 5, verbatim), new data bullet (Rule 4 instruments), closing line.**

**Original brief text**:
> - the hint prose equals tier 1 of `hint_tree[hintErrorTypeId]` when that key exists, else the node's generic
>   tier-1 hint (first `error_types[]` member with a `hint_tree` entry), with `LO_HINT_NOT_FOUND` as internal
>   data when the fallback fires; a `map_check_here` event on `data/demo` exercises the fallback on every node
>   (arbiter-04 § Q-B). A resolver that returns empty prose on a missing key fails the test (negative
>   control). **Contested** by arbiter-02-none-of-these F2, which asks that a `nil` key with non-nil
>   `hintNodeId` render no hint prose (§9 cross-reference);

> All of these are `Core` tests over real data plus constructed states.

**Amended brief text**:
> - the hint prose follows the Rule 2 table of `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md`
>   over 02.11's `hintKey`. On `data/demo` after the Rule 4 task (task 1b), every `map_check_here` hint
>   terminal shows `hint_tree["none-of-these"][0]` with `internalCode == nil`. A constructed node without that
>   entry shows its `paraphrase` with `.loHintNotFound`. Negative controls:
>   - a resolver returning empty prose fails;
>   - a resolver returning a sibling type's tier 1 for the outcome token fails;
> - `data/demo` carries `hint_tree["none-of-these"]` on every node (task 1b; reconciliation Rule 4), each
>   instrument with empty = FAIL: schema decode and L0 (`core-cli validate` / `BundleIO.read`);
>   `BundleRenderCheckTests` over `data/demo` with 0 unresolved; a `CoreTests` assertion over every node
>   (count > 0) that the entry holds 3 non-empty strings and that its tier-1 string differs from every other
>   key's tier-1 string on that node (a planted copy of a sibling's tier fails it); and
>   `hintKey(node, "none_of_these") == "none-of-these"` on every node (02.11's derived T10, unedited). The
>   spike outcome's count table and its pinning test agree with the re-scan, and 03.4's embedded snapshot
>   copy stays byte-identical;

> All of these are `Core` tests over real data plus constructed states, except the render check, which is a
> `RenderingTests` test.

**Passage 11 — §8 size estimate, task 1, new task 1b, task 3 (reconciliation item 6; Rules 2, 4, 5).**

**Original brief text**:
> **7 work tasks + wrap(s)** [ESTIMATE: EPIC 03's planner found 11 work tasks against a similar-looking brief;
> this one is expected to exceed the 8-task cap once wraps are counted].

> 1. Contract: interaction-contract v0.9.3 (§9 Q-A, Q-G), domain-glossary v1.0.1 (§9 Q-B), the three
>    `docs/domains/diagnosis.md` edits (Q-B ×2, Q-D ×1), and both DEFERRED entries (Q-A tint deltas, Q-F hint
>    tiers).

> remediation / further-offer / terminal content, hint key→prose with the generic tier-1 fallback, the
> remediation selector, the `CoreError.loHintNotFound` case (the only EPIC 04 writer of `CoreError.swift`),
> the Door copy constants (Q-D), resume, and the **C1** façade-level full expedition + diagnosis test (§4
> items 2, 4).

**Amended brief text**:
> **8 work tasks + wrap(s)** [ESTIMATE: EPIC 03's planner found 11 work tasks against a similar-looking brief;
> this one is expected to exceed the 8-task cap once wraps are counted; task 1b was added by the hint-fallback
> reconciliation].

> 1. Contract: interaction-contract v0.9.3 (§9 Q-A, Q-G), domain-glossary v1.0.1 (§9 Q-B, with the
>    reconciliation Rule 5 texts: header, Remediation, Error type), the three `docs/domains/diagnosis.md` edits
>    (Q-B ×2 in the Rule 5 wording, Q-D ×1), the `docs/domains/learning-objects.md` Rule 5 edits, and both
>    DEFERRED entries (Q-A tint deltas, Q-F hint tiers).
> 1b. Demo data (ordered after task 1 and before task 3; it must not run concurrently with EPIC 03's 03.4 …):
>    `hint_tree["none-of-these"]` on every `data/demo` node … File scope, the cascade included: `data/demo/nodes.json`;
>    03.4's embedded snapshot copy (byte-identical); the spike outcome's hint-tree and total rows; the pinned table
>    in `OutcomeRecordAndImportBoundaryTests.swift` and the "63/143" comment in `FieldKindPolicyMutationTests.swift`;
>    `data/demo/manifest.json` only if its hashes are no longer placeholders (restamp with `bundle.py`); the
>    `CoreTests` data assertions of §4 item 4. No SymPy/CAS step. Agent-authored, machine-verified, no human
>    review step (I9). (Full text in §8.)

> remediation / further-offer / terminal content, hint key→prose per reconciliation Rule 2 (in-module
> `hintKey`; the none-of-these tier 1, else the paraphrase, never another type's hint), the remediation
> selector with the hint part omitted on a `nil` key, the `CoreError.loHintNotFound` case (the only EPIC 04
> writer of `CoreError.swift`), the Door copy constants (Q-D), resume, and the **C1** façade-level full
> expedition + diagnosis test (§4 items 2, 4). Depends on task 1b, so its real-data tests exercise the
> resolving path.

**Passage 12 — §8 plan mapping and file ownership (reconciliation item 6).**

**Original brief text**:
> **Mapping to the planner's split** (`docs/plans/epic-04-plan.md`, unchanged: 04a = 04.1–04.6, 04b =
> 04.7–04.13). The arbiter-04 rulings use the task numbers above; they map as 1 → 04.1; 2 → 04.2, 04.4, 04.5

> diagnosis.md Q-B edits. The plan's "Q-H" is `tasks/arbitration/arbiter-02-none-of-these.md` (§9
> cross-reference); the plan already gates 04.3 on it, and its open conflict with arbiter-04 § Q-B also reaches
> 04.1's glossary and diagnosis.md Q-B text.

**Amended brief text**:
> **Mapping to the planner's split** (`docs/plans/epic-04-plan.md`: 04a = 04.1–04.6, 04b =
> 04.7–04.13, plus task 1b). The arbiter-04 rulings use the task numbers above; they map as 1 → 04.1; 1b → a new
> 04a plan id between 04.1 and 04.3, assigned by the planner without renumbering existing ids, on which 04.3 then
> depends (04a becomes 7 tasks including its wrap); 2 → 04.2, 04.4, 04.5

> diagnosis.md Q-B edits and the learning-objects.md edits. The plan's "Q-H" is `tasks/arbitration/arbiter-02-none-of-these.md` (§9
> cross-reference); the plan already gates 04.3 on it. Its conflict with arbiter-04 § Q-B is reconciled by
> `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md`, which also fixes 04.1's glossary, diagnosis.md
> and learning-objects.md texts and adds task 1b.

New file-ownership bullet:
> - `data/demo/**`, 03.4's embedded snapshot copy, the spike outcome record and its pinning test are written by
>   exactly one task (task 1b).

**Passage 13 — §9 preamble, Q-B resolution, cross-reference, Q5 line (reconciliation item 7).**

**Original brief text** (preamble, last sentence):
> The entries below keep their original analysis. **One conflict between two arbiter rulings is
> open** (the cross-reference entry after Q-B), and it touches the Q-B hint fallback.

**Amended brief text**:
> The entries below keep their original analysis. The one conflict between two arbiter rulings (the
> cross-reference entry after Q-B), which touched the Q-B hint fallback, is **reconciled** by
> `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md` (Q4; no ESCALATE-Q5).

**Original brief text** (Q-B RESOLVED entry, from its third sentence):
> The hint resolver therefore falls back
> to the node's **generic tier-1 hint** (first `error_types[]` member with a `hint_tree` entry), else the
> `paraphrase` when `hint_tree` is empty, and returns `internalCode: .loHintNotFound` when the fallback fires
> (learning-objects W2). `CoreError` gains `loHintNotFound = "LO_HINT_NOT_FOUND"` (already registered,
> internal; no `error-codes.json` entry). Remediation order is confirmed; every `data/demo` node takes the
> `paraphrase` + tier-1 hint branch. Glossary v1.0.1 and the two `docs/domains/diagnosis.md` edits land in
> task 1 with the ruling's exact text. The kebab/snake naming split is not "fixed" from EPIC 04 (§2, §3,
> §4 item 4). **The generic-fallback branch is contested** by the ruling in the next entry.

**Amended brief text**:
> `CoreError` gains
> `loHintNotFound = "LO_HINT_NOT_FOUND"` (already registered, internal; no `error-codes.json` entry).
> Remediation order is confirmed; every `data/demo` node takes the `paraphrase` + tier-1 hint branch.
> Glossary v1.0.1 and the two `docs/domains/diagnosis.md` edits land in task 1. arbiter-04's own generic-hint
> definition (the first `error_types[]` member with a `hint_tree` entry) and its empty-`hint_tree` branch are
> **superseded** by the reconciliation below.
> - **RECONCILED** (`tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md`, Rules 1–5): the generic
>   hint is `hint_tree["none-of-these"][0]`, never another error type's hint (I2), and 02.11's `hintKey` is
>   unchanged; `LO_HINT_NOT_FOUND` is raised as internal data by task 3's `Core` hint resolver; a `nil` key shows
>   the origin's `paraphrase` in every hint slot, and remediation drops the hint part; task 1b adds the
>   `data/demo` entries; task 1 carries the Rule 5 spelling texts. `Classify.swift` and 02.11 are not edited.
>   (Full five-bullet text in §9.)

**Original brief text** (cross-reference, agreements bullets 2–3, wording tail, conflict and closing bullets):
> - neither `Classify.swift`, its tests nor the data change (Ruling 1, F1; arbiter-04 § Q-B naming note);
> - in `data/demo`, no node has a `hint_tree` entry for the none-of-these member in either spelling
>   (finding 4).

> On `data/demo` it is `nil` on every abstaining hint terminal (Ruling 4).

> - **Conflict, unresolved and not chosen here.** … (three sub-bullets)
> - **What the conflict reaches:** … (three sub-bullets)
> - This brief carries arbiter-04's text, as instructed, and marks it **contested**. Reconciling the two
>   rulings belongs to the spec-arbiter, before 04.1's glossary/diagnosis.md commits and before 04.3 is
>   dispatched. Parts of 04.1 that the conflict does not touch (interaction-contract v0.9.3, the Q-D edit,
>   DEFERRED) and 04.2 are unaffected.

**Amended brief text**:
> - neither `Classify.swift` nor its tests change (Ruling 1, F1);
> - today, in `data/demo`, no node has a `hint_tree` entry for the none-of-these member in either spelling
>   (finding 4). Task 1b adds the `none-of-these` entry.

> On `data/demo` it is `nil` on every abstaining hint terminal until task 1b lands, and `"none-of-these"`
> after it.

> - **Conflict — RECONCILED** (`tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md`). … The earlier
>   sentence "no lookup of either spelling is required to succeed" (arbiter-04's naming note, carried here as
>   "nor the data change" and "the naming split is not fixed") is **withdrawn**: `"none-of-these"` is a lookup
>   that succeeds on `data/demo` after task 1b.
> - **What it reached, now settled:** … and the new data task 1b. Parts of 04.1 that the conflict did not touch
>   (interaction-contract v0.9.3, the Q-D edit, DEFERRED) and 04.2 are unaffected.

(Full texts are in §9. The withdrawn sentence did not appear verbatim in the brief; its content appeared as the two quoted fragments, both removed.)

**Original brief text** (Q5 line, tail):
> The Q-B / none-of-these conflict is an arbiter-to-arbiter reconciliation (Q4), not
> a D-number change.

**Amended brief text**:
> The Q-B / none-of-these conflict was an arbiter-to-arbiter reconciliation (Q4), not
> a D-number change, and it is reconciled with no ESCALATE-Q5.

**Contested markers removed**: §2 remediation bullet, §2 hint bullet, §3 glossary bullet ("touched by the open conflict"), §3 I2 line ("unresolved"), §4 item 4 hint bullet, §8 mapping ("open conflict"), §9 preamble, §9 Q-B, §9 cross-reference (two sites). The remaining occurrences are in the Amendment 04.00.1 log, which is history.

**Plan consistency (`docs/plans/epic-04-plan.md`; not edited, outside brief-amender write authority).** The planner adds task 1b as a new 04a id between 04.1 and 04.3 without renumbering, makes 04.3 depend on it, and adds the learning-objects.md edits to 04.1. 04a then has 7 tasks including its wrap, within the 8-task cap. Where the plan differs from the brief, spec writers follow the brief.

**Source**: `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md` § Reconciled rule (Rules 1–5), § Parts of Ruling A superseded and § What the EPIC 04 brief and specs must reflect (items 1–7). That ruling cites:
- `contracts/error-codes.json` (`LO_HINT_NOT_FOUND`, internal) and `contracts/error-codes.md` § Rules;
- `contracts/schemas/nodes.schema.json` (`hint_tree` entries) and `contracts/data-model.md` (catalogue id `none-of-these`);
- `contracts/domain-glossary.md` (Error type) and `contracts/content-policy.md` § Generated content;
- `docs/domains/learning-objects.md` W1, W2 and HintTree, and `docs/domains/diagnosis.md` W1 and W3;
- `DEMO-BRIEF.md` §3.6 and §5;
- `docs/epics/epic-01-rendering-spike-outcome.md` and `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md` (I9 precedent);
- `CLAUDE.md` I2, I3, I6 and I9.

**Effect on deliverables**: specificity added, plus one data task.
- Task 1b adds `hint_tree["none-of-these"]` to the `data/demo` nodes and its cascade. This is content the brief already owed through diagnosis W1/W3 and DEMO-BRIEF §3.6 ("Show the original node's hint"). The reconciliation found it undeliverable on the current data and routed the task here as decomposition, not a Q5 (Rule 4, "Not a Q5": no D-number governs hint authoring, and D26 already allows hand-written Demo data).
- No deliverable is dropped. No contract gains a field. `error-codes.json` gains no entry.

**Effect on owner-facing acceptance**: NONE. DEMO-BRIEF §7/§8 and the v2.2 §B checklist are unchanged. Abstaining hint terminals now show the node's own none-of-these hint as §3.6 describes, and they never show a sibling error type's hint (I2).
