# Arbiter rulings — EPIC 04 pre-dispatch (Q4)

**Date:** 2026-09-10
**Brief:** `docs/epics/epic-04-app-expedition-diagnosis-acceptance.md` § 9 Open questions (untracked; EPIC 04 runs
on its own branch after EPIC 03 merges)
**Trigger:** pre-dispatch Q4 routing by the brief itself (Q-A, Q-B, Q-D, Q-G), plus confirmation of the technical
defaults Q-E and Q-F and of the Q-C default path. No task spec exists yet.
**Result:** no ESCALATE-Q5. No locked decision D1–D49 changes, and no invariant changes meaning. Q-A and Q-D are
**CONFIRMED**, with exact text. Q-B is **CONFIRMED with a correction**: the brief's "`none_of_these` fallback"
matches no hint in `data/demo`. Q-G is **CORRECTED**: the ratified expedition Q6 can be honoured literally, with
no schema change. Q-E and Q-F are **CONFIRMED**. On Q-C, EPIC 04 **proceeds**, and the exclusion is stated
exactly. Owed artefacts:
- `interaction-contract.md` v0.9.3, then v1.0.0 at wrap;
- `domain-glossary.md` v1.0.1;
- two `docs/domains/diagnosis.md` edits;
- two `docs/DEFERRED.md` entries;
- one additive `CoreError` case, for a code that is already registered.

`error-codes.json` gains no entry.

## Summary table

| Q | Ruling | Lands in (brief § 8 numbering) |
|---|---|---|
| Q-A | **CONFIRMED.** The answer card stays until an explicit continue, which is itself a façade call. The summary shows no region tint deltas, and a DEFERRED entry records that. Exact contract text is below. | 1 (contract v0.9.3 + DEFERRED); 2, 3 (continue call); 8 (v1.0.0 flip) |
| Q-B | **CONFIRMED, with a correction.** Remediation = `explanation`, else the first worked example, else `paraphrase` + a tier-1 hint. The hint key is the classified error type when `hint_tree` has it, **else the node's generic tier-1 hint** (learning-objects W2). `none_of_these` never resolves in `data/demo`. Glossary patch v1.0.1. | 1 (glossary + diagnosis.md W4); 3 (resolver, `CoreError` case) |
| Q-D | **CONFIRMED.** The cost line is exactly "Two quick checks, about a minute." It is a `Core` string constant that the App renders. diagnosis.md W3 is edited to match. | 1 (doc edit); 3 (constant); 7 (render) |
| Q-G | **CORRECTED.** While a run is in progress, the persisted document carries that run's `end(abandoned: true)` log entry, so an OS-terminated run **is** logged as abandoned. There is no new field. A contract bullet is added. | 1 (contract bullet); 2 (façade sequencing) |
| Q-E | **CONFIRMED.** On a parse failure, `MathView` shows the LaTeX source as plain text. The fallback lives in `Rendering`, and there is no student code. | 5 |
| Q-F | **CONFIRMED.** Hint tier 1 only. Tiers 2–3 are deferred. | 1 (DEFERRED) or wrap; 3 |
| Q-C | **Proceed on option 1.** The claim is limited to logic, composition and static wiring. What the default path cannot claim is listed below. | 7, 8 (scan, record) |

---

## Q-A — The two remaining § Finalization items

**Ruling.** Both brief defaults are CONFIRMED. The items are contract-discovery text delegated to "the Demo EPIC"
and are not D-numbers, so this is not a Q5.

*Answer-card timing.* The ground truth:
- DEMO-BRIEF sets no timing. §3.5 names only the check and the end screen.
- Expedition W2 step 3 says "Show correct/incorrect **with the correct answer and the item's one-line why**
  immediately (D5, I3)". "Immediately" governs when the card appears, not when it leaves.
- Interaction-contract § 2 `answer(item)` says "always show correct answer + `why` (I3)", and § 2 Properties
  says "every item shown ends with its answer visible".

Any auto-advance timer could remove the answer before it is read, and that is the one outcome I3 forbids. So the
card persists until the student acts.

**Precision (needed to make the rule testable in `Core`).** "Continue" is a façade entry point, not an App-only
presentation flag. After an answer, the façade's current screen value is the answer card. Only the continue call
moves it on, to the next item, the retry, the second probe item, the hypothesis card (D27 hand-off), remediation,
a terminal line, or the summary. This is what makes the brief's § 4 item 3 guard ("No next-item, terminal or
summary value is reachable without one") assertable in `CoreTests`, with its planted negative control. The
continue call changes no `StudentState`, so it triggers no write. This matches arbiter-03 § Q-F item 4 ("Each
entry point takes values and returns (new value, `[CoreEvent]`)").

*Summary region tint deltas.* **Not shown.** The ground truth:
- DEMO-BRIEF §3.5: "End screen: nodes cleared this run, fog lifted, "Start another" button".
- Expedition § Core entities: "**ExpeditionSummary** — nodes cleared this run, fog lifted, blocked nodes marked,
  "Start another"".
- Expedition W5 step 3: "Offer "Start another" (W1) and "Back to the map"".
- Map W6: "re-derive `MapViewModel`; lift fog, place a blocked marker or a due ring, re-tint the region". The tint
  change is already shown on return to the map.

The brief's alternative, a per-region before/after fraction on the summary, is **rejected**. It would put a
fraction on a student surface, and `contracts/content-policy.md` § Voice says "no scores or percentages on
student surfaces". The Demo also tests the map, not a report (v2.5 §3: "the map is the record").

**Exact normative text.**

*Task 1: a `contract(interaction-contract)` commit that patches v0.9.2 to v0.9.3.* The header line reads
`**Contract version:** v0.9.3 (discovery zone — finalized just-in-time by the Demo EPIC)`. Append to the Source
sentence: `; v0.9.3 resolves the answer-card timing and summary-tint finalization items and records the in-run
abandoned log entry (arbiter Q-A, Q-G, \`tasks/arbitration/arbiter-04-predispatch.md\`)`.

In § 2 Expedition, insert after the `answer(item)` bullet:

> - **Answer card (timing):** after every checked item — expedition item, retry or probe item — the answer card
>   (correct/incorrect, the correct answer, `why`) stays on screen until the student taps an explicit continue
>   control. There is no timer and no auto-advance. No next item, probe item, hypothesis card, remediation,
>   terminal line or summary is reachable before that tap (I3).

In § 2 Expedition, insert after the `end` bullet:

> - **Summary content:** the summary lists the nodes cleared this run, the fog lifted, the nodes marked
>   `blocked`, and offers "Start another" and "Back to the map". It shows no region tint delta and no fraction;
>   the re-derived map shows the tint on return (map W6).
> - **In-run log entry (expedition Q6):** while a run is in progress, the persisted `StudentState` carries that
>   run's `expedition_log` entry exactly as `end` with `abandoned = true` would write it at that moment; `end`
>   replaces it with the final entry. A run the OS terminates is therefore logged as abandoned and never
>   resumed. No field is added.

Replace the § Finalization owed by the Demo EPIC paragraph. Keep the heading, because other documents cite it:

> Nothing remains owed. Resolved in v0.9.2: the marker is set from the unit list only — § 3; no drag. Resolved
> in v0.9.3: the answer card stays until the student continues, and the summary shows no region tint deltas —
> § 2. Bump to v1.0.0 on wrap.

*Wrap (brief task 8): a `contract(interaction-contract)` commit.* The header becomes `**Contract version:**
v1.0.0 (finalized by the Demo EPIC)`. Append to the Source sentence: `; v1.0.0 closes the discovery zone at the
Demo wrap`. In § Finalization owed by the Demo EPIC, replace the last sentence ("Bump to v1.0.0 on wrap.") with
`Finalized at v1.0.0.` No normative text changes at the flip.

*Task 1: DEFERRED entry.* Take the next free `D-n` after EPIC 03's entries:

```
### D-n — Region tint deltas on the expedition summary
**Observed:** interaction-contract v0.9.3 § 2 resolves the summary to nodes cleared, fog lifted, blocked marked,
"Start another" / "Back to the map", with no region tint delta (arbiter-04 Q-A). A per-region fraction on a
student surface would conflict with content-policy § Voice ("no scores or percentages on student surfaces").
**Configuration:** Demo (`data/demo`); the map re-tints on return (map W6).
**Revisit trigger:** Demo observations (DEMO-BRIEF §7 items 2 and 3).
**Hypothesis (unverified):** none.
```

**Citations.** `contracts/interaction-contract.md` § 2 Expedition (lines 38–39, 56–60) and § Finalization owed by
the Demo EPIC (lines 117–119); `DEMO-BRIEF.md` §3.5 (line 50); `docs/domains/expedition.md` § Core entities
(lines 55–57), W2 (lines 75–80), W5 (lines 98–103); `docs/domains/map.md` W6 (lines 97–100);
`contracts/content-policy.md` § Voice (lines 53–55); `AMENDMENT-v2.5.md` §3 (lines 21–23);
`tasks/arbitration/arbiter-03-predispatch.md` § Q-B (the v0.9.2 text this builds on).

---

## Q-B — Remediation content in the Demo

**What `data/demo/nodes.json` actually carries.** I read the whole file and counted with Grep `-o`:
- **20 nodes.** Each has `paraphrase` (20), `hint_tree` (20) and exactly 2 `probe_items`: 20 `numeric` and 20
  `mc`, with 40 `prompt_latex` and 40 `choices[].latex`.
- **0 `explanation` and 0 `worked_examples`.** This matches the spike outcome table.
- **Every `hint_tree` has exactly one key, the node's single non-`none-of-these` error type.**
  `exponential-functions` is the exception, with two keys: `base-exponent-swapped` and
  `multiplied-instead-of-power`.
- **No node has a `none-of-these` or `none_of_these` hint entry.** This is by design. Learning-objects W1 step 4
  reads "every ErrorType but `none_of_these` has a full tier list", and the `nodes.schema.json` `hint_tree`
  (lines 212–223) requires no such key.
- The error-type id in data is kebab `none-of-these` (`data-model.md` § Collections, `nodes.json` row).
  `Classify.classify` returns the literal `"none_of_these"` (`Classify.swift:41`). 02.11's `hintKey` also falls
  back to the literal `"none_of_these"` (02.11 spec § 4 step 5). That string is **never** a `hint_tree` key in
  `data/demo`.

**What 02.11 returns.** `DiagnosisOutcome.hintNodeId` / `hintErrorTypeId` are "keys, never hint prose" (02.11
§ 4 step 5, `hintKey`). They are non-nil only when a hint is shown: refuted, unconfirmed, noPrerequisite. They
are always keyed on the **origin**. Remediation is not keyed at all: the confirmed branch only sets `remediated =
true`. The candidate's failed attempts are public on the concluding advance, as
`DiagnosisAdvance.probeResult.incorrectAttempts`, where `DiagnosisProbeResult.incorrectAttempts` is `public let`
(02.11 § 4 step 2). `Classify.classify` is public. So the façade can key remediation without touching an
internal helper.

**Consequence for the brief.** § 4 item 4, "the hint prose equals the `hint_tree` tier resolved from
`hintErrorTypeId`, with the `none_of_these` fallback", is **unsatisfiable on `data/demo`**. Every `map_check_here`
event has `failedAttempts == []`, so `originErrorTypeId == "none_of_these"`, and the fallback prose does not
exist. The brief's remediation default has the same hole whenever a probe miss is untagged.

**Ruling.**
1. **Hint resolution (one `Core` function; the App never looks up a hint).** Given `(node, key)`: if
   `node.hintTree[key]` exists and is non-empty, the hint is its tier 1, `[0]`. Otherwise it is the node's
   **generic tier-1 hint**: tier 1 of the `hint_tree` entry for the first member of `node.errorTypes`, in
   catalogue order, that has one. If `hint_tree` is empty, the hint line is the node's `paraphrase`.
   - The fallback realises learning-objects W2 step 1: "a miss raises `LO_HINT_NOT_FOUND` and the session falls
     back to the node's generic tier-1 hint". It is also the EPIC 02 brief § 9 default, whose "node's
     `none-of-these` hint" does not exist in data.
   - The function returns, as data, the prose, the resolved key, and `internalCode: .loHintNotFound` whenever
     the fallback fired. `LO_HINT_NOT_FOUND` is already registered as `internal` (`error-codes.json` line 34).
     `CoreError` gains the additive case `loHintNotFound = "LO_HINT_NOT_FOUND"`. `ErrorRegistryTests` covers it
     unchanged. It is internal, so it has no `CoreErrorText.userText` entry, and the 03.3 parity test stays
     green.
   - This is not a guessed diagnosis (I2). A tier-1 hint is a nudge on a node the flow already names, with no
     `ErrorType` asserted. Learning-objects Q4 keeps `none_of_these` an abstention.
   - On `data/demo` the empty-`hint_tree` branch is unreachable, because every node has ≥ 1 entry.
     `contracts/examples/nodes.json` line 168 has `"hint_tree": {}`, so the branch exists for real data.
2. **Remediation piece (one `Core` function, for the confirmed candidate X).** Take the first of these that
   exists:
   1. `X.explanation`;
   2. `X.worked_examples[0]`;
   3. `X.paraphrase` plus the hint resolved (rule 1) for `(X, Classify.classify(probeResult.incorrectAttempts))`.
      `probeResult` is the one on the advance whose `probeResult.outcome == .confirmed`.

   The result is never empty, because `paraphrase` is schema-required. On `data/demo` every node takes branch
   3. This is DEMO-BRIEF §3.6 word for word: "Fail → mark X `blocked`, show X's paraphrase and one hint, then
   return".
   - **I6:** `paraphrase` is the project's own sentence (content-policy § Grade 9–12 tier), and hints are
     project-generated.
   - **I3:** remediation appears only after both probe answer cards (Q-A), so nothing is withheld.
   - **Registry:** no remediation path without content is reachable, so no new code is needed. That answers the
     brief § 3 re-check.
   - At the Demo budget of 1, every confirmed probe goes to `capped` in the same advance (02.11 AC6). The
     `capped` screen therefore shows the remediation piece and then the capped line, "further upstream — it's on
     your map". Remediation comes first, because `.diagnosisRemediationShown` precedes `.diagnosisCapped` in the
     advance's events.
3. **Glossary patch.** Without it, a reviewer could fairly BLOCK a spec that calls paraphrase + hint
   "Remediation". The ranking: `DEMO-BRIEF.md` is owner ground truth, and data-model makes `explanation?` and
   `worked_examples[]?` optional. This clarifies a definition; it does not change a decision, so it is not a Q5.

**Exact normative text** (task 1, a `contract(domain-glossary)` commit; per `contracts/README.md` line 43, a
locked-contract change is versioned):
- Header: `**Contract version:** v1.0.1 · Source: \`docs/domains/*.md\`, \`docs/idea.md\` (D1–D49); v1.0.1
  clarifies Remediation for nodes without an Explanation (arbiter-04 Q-B)`.
- § Diagnosis (Door A), replace the Remediation sentence with:
  > **Remediation** — one Explanation or WorkedExample for a confirmed candidate; when the node carries
  > neither, its `paraphrase` plus one tier-1 hint (DEMO-BRIEF §3.6).

**Cascade** (same task; `docs/*` edits are authorized for a contract task, per the arbiter-03 precedent):
- `docs/domains/diagnosis.md` § Core entities, Remediation: replace "one `Explanation` or `WorkedExample` from
  **learning-objects**, then return." with "one `Explanation` or `WorkedExample` from **learning-objects** — or,
  when the node carries neither, its `paraphrase` plus one tier-1 hint (DEMO-BRIEF §3.6) — then return."
- `docs/domains/diagnosis.md` § UI surfaces: replace "(W4, one explanation or worked example)" with "(W4, one
  explanation or worked example, else the paraphrase and one tier-1 hint)".

**Brief § 4 item 4, re-worded bullet:** "the hint prose equals tier 1 of `hint_tree[hintErrorTypeId]` when that
key exists, else the node's generic tier-1 hint (first `error_types[]` member with a `hint_tree` entry), with
`LO_HINT_NOT_FOUND` as internal data when the fallback fires; a `map_check_here` event on `data/demo` exercises
the fallback on every node". Its negative control: a resolver that returns empty prose on a missing key fails
the test.

**Naming note, no action in EPIC 04.** The kebab/snake split between `Classify`'s `"none_of_these"` and data's
`none-of-these` is harmless under rule 1. Neither string is ever used as a lookup that must succeed. Do not
"fix" `Classify.swift` or 02.11 from EPIC 04.

**Citations.** `contracts/domain-glossary.md` § Diagnosis (Door A) (line 43); `contracts/data-model.md`
§ Collections, `nodes.json` row (line 50); `contracts/schemas/nodes.schema.json` (lines 212–223);
`contracts/error-codes.json` (line 34); `docs/domains/learning-objects.md` W1 step 4 (lines 77–78), W2 (lines
89–95), Q4 (lines 162–166); `docs/domains/diagnosis.md` § Core entities (lines 41–42), W4 (lines 76–80);
`DEMO-BRIEF.md` §3.6 (lines 52–57); `Packages/Core/Sources/Core/Diagnosis/Classify.swift` (lines 20–42);
`tasks/epic-02-task-11-diagnosis-machine-seam.md` § 4 steps 2, 3d, 5 and § 6 (hint-key default);
`docs/epics/epic-02-core-behaviour.md` § 9 (quoted in 02.11 § 3); `data/demo/nodes.json` (read in full).

---

## Q-D — Hypothesis-card cost copy

**Ruling.** CONFIRMED. The cost line reads exactly **`Two quick checks, about a minute.`** The word "check" is
already the registered student-facing name for the probe: `DIAG_PROBE_UNAVAILABLE`'s `user_text` is "No quick
check is available for this one yet; here's a hint instead." (`error-codes.json` line 21). The map's "Check me
here" uses it too. "Check" is not a banned synonym anywhere in the glossary. "question" is banned under Item.

**Where it lives.** The line is a `public static let` string constant in the `Core` Door A screen-content file
(task 3). It is carried on the hypothesis-card value, and the App renders it verbatim. This follows the
arbiter-03 § Q-F precedent: "The list of student messages to display … is computed here". It keeps the wrap-(f)
copy grep a single-site check. The same file holds the other Door strings already fixed by ratified domain
text:
- "This may be blocked by **X**", where X is the candidate node's `name`;
- "Not the issue — back to where you were";
- "further upstream — it's on your map";
- "We'll come back to this one";
- "want to look one step further upstream?" (diagnosis Q3).

Registry codes still come from 03.3's `CoreErrorText.userText`. Accept/decline button labels are left to the
task-3 spec, which must pick words that pass the glossary grep. Suggested labels: "Check it" / "Skip".

**Cascade** (task 1, `docs/*` edit): in `docs/domains/diagnosis.md` W3 step 1, replace `("two quick questions,
about a minute")` with `("two quick checks, about a minute")`.

The template's quoting of v2.1 §D item 6 ("start marker") is source text in quotation marks, labelled
"course-progress marker". The brief handles this correctly; confirmed.

**Citations.** `contracts/domain-glossary.md` § Expedition (Door B), Item (line 30), and § Map and graph,
Course-progress marker (line 22); `contracts/error-codes.json` (line 21); `docs/domains/diagnosis.md` W3 (lines
68–73), Q3 (lines 162–166); `docs/domains/expedition.md` Q5 (lines 197–200); `AMENDMENT-v2.1.md` §D (line 48).

---

## Q-G — Abandoned run vs OS termination

**Ruling.** CORRECTED. The brief reads Q6 narrowly: an OS-terminated run would write no `expedition_log` entry.
That contradicts owner-ratified text. Expedition Q6: "the current item is kept for a short grace window
[ESTIMATE: until the app is terminated by the OS]; **a terminated run is logged as abandoned** and the next
launch starts fresh". So "terminated" here means OS-terminated. The ratified text can be met with **no schema
change and no `ExpeditionRun` edit**:

- **In-run write-ahead.** After every state-changing Door B or Door A call during a run, including the
  run-start call, the session persists `ExpeditionRun.end(run: <current run>, state: <threaded state>, today:,
  abandoned: true).state`. The in-memory threaded state never contains that entry. At a natural end the session
  persists `end(…, abandoned: false).state`. On "Back to the map" mid-run it persists `end(…, abandoned:
  true).state`. Either way, the provisional entry is replaced, because it was never in memory.
- **Where the natural end is called.** In the same façade call that produces the run's last result: the final
  answer, or the `returned` that resumes into an empty queue. The summary value is held behind that call's
  answer card and shown on continue (Q-A). So a completed run is never logged abandoned by an OS kill while its
  last card is on screen.
- **Why no schema change is needed.** `end` already builds a schema-valid entry: `ExpeditionRun.swift:176-191`
  (`abandoned: abandoned`, `diagnosisEvents: run.diagnosisUsed ? 1 : 0`). `student-state.schema.json` allows
  `item_count` minimum 0 (lines 138–141), so an entry killed before its first answer is valid.
- **What an OS kill leaves.** Every `probe_log` row, mastery change and diagnosis effect up to the last call,
  plus one abandoned entry with accurate counts. The next launch starts fresh, and nothing is resumed item by
  item (interaction-contract § 2 `end`).
- **Backgrounding without termination.** The run stays in the App's holder value, which is Q6's grace window.
  Nothing is written on backgrounding.
- **Exits from a Door A event.** Only its own decisions end it: decline, the two probe answers, the
  further-level choice. There is no mid-event "Back to the map", and diagnosis W5 "always terminates". "Back to
  the map" is offered on the Door B item view and answer card.
- **`map_check_here` outside a run.** No in-run entry exists, which is the EPIC 02 § 9 default: "logs no
  `expedition_log` entry".

The contract bullet is in Q-A's exact text ("In-run log entry"). It makes the persistence behaviour visible to
EPIC 10 and EPIC 11.

**Test obligations (task 2; they re-word brief § 4 items 1 and 5):**
- Item 1: "the state file is written after every state-changing call" becomes: during the run, the decoded file
  == the threaded state with exactly one trailing `abandoned: true` entry, matching `end(abandoned: true)`
  computed from the current run. After the natural end, it holds exactly one entry for the run, with
  `abandoned: false`.
- Item 5: "Back to the map" mid-run yields exactly one `abandoned: true` entry. A simulated kill (dropping the
  session after any call and re-reading the file) yields exactly one `abandoned: true` entry with that call's
  counts.
- Negative control: a session that skips the write-ahead fails the simulated-kill case.

**Note for EPIC 10, recorded here, not built.** `expedition_log` merges as a "multiset union by full-value
equality" (`data-model.md` § StudentState merge). A sync snapshot taken mid-run would carry the provisional entry
alongside the final one, and the merge would keep both. EPIC 10's sync spec must sync only at run boundaries, or
treat this explicitly. This does not affect EPIC 04, which has no sync.

**Citations.** `docs/domains/expedition.md` Q6 (lines 203–207) and W5 (lines 98–103);
`contracts/interaction-contract.md` § 2 `end` (line 56); `Packages/Core/Sources/Core/State/ExpeditionRun.swift`
(lines 58–69, 176–192); `contracts/schemas/student-state.schema.json` (lines 138–168);
`contracts/data-model.md` § StudentState (lines 130–137) and § StudentState merge (lines 159–164);
`contracts/telemetry.md` (line 21, `expedition` counts include `abandoned`); `tasks/arbitration/arbiter-03-predispatch.md`
§ Q-F item 4.

---

## Q-E — `MathView` parse failure at runtime

**Ruling.** CONFIRMED. The brief default has four precisions.

1. `MathView(latex:)` calls `RenderCheck.parseError(latex:)` (`Rendering.swift:9-13`). If the result is non-nil,
   it shows the unmodified source string as plain `Text`. It is never blank and never an error string. This is
   presentation, not state, so it belongs in `Rendering` (I14: `Core` cannot import SwiftMath).
2. An item carrying `render_fallback: "katex"` (`nodes.schema.json` lines 248–253) is shown the same way. KaTeX
   is brief § 7 item 4, trigger EPIC 09. `data/demo` has none: `RenderCheckReport` shows 0 unresolved of 143.
3. No student code. `LO_ITEM_UNRENDERABLE` is `internal` (`error-codes.json` line 32) and stays a
   pipeline/test outcome. `BundleRenderCheckTests` is the pre-ship gate.
4. **Field routing.** `MathView` is used only for `prompt_latex`, `choices[].latex`, and an `mc` answer card's
   `correctAnswerDisplay`, which is a choice's `latex` (`ItemChecker.swift:183-191`). A `numeric`
   `correctAnswerDisplay` (`answer.value`), `why`, hints and `paraphrase` are plain `Text`. That follows
   `data-model.md` § Text: "LaTeX appears only in fields named `latex` or `prompt_latex`".
   - The `Core` answer-card value carries an explicit display-kind flag (LaTeX or plain), so the App does not
     re-derive it from `item.type`.
   - Tension, not a conflict: the EPIC 01 spike also scanned 63 `hint_tree` strings as LaTeX, following
     content-policy's "Prompts and hints must render in SwiftMath". data-model § Text is the field-level display
     rule, and the Demo hints read correctly as plain text (e.g. "(2^3)^2 = 2^(3x2) = 2^6, not 2^5.").

Brief § 4 item 6's population is the 80 strings (40 `prompt_latex` + 40 `choices[].latex`). Empty = FAIL.

**Citations.** `Packages/Rendering/Sources/Rendering/Rendering.swift` (lines 7–19);
`docs/epics/epic-01-rendering-spike-outcome.md` (table, lines 13–20); `contracts/data-model.md` § Text (lines
35–37); `contracts/content-policy.md` § Generated content (lines 34–35); `docs/domains/learning-objects.md` W1
5b (lines 81–82) and Errors (line 129).

---

## Q-F — Hint tiers

**Ruling.** CONFIRMED. The Demo shows tier 1 only (DEMO-BRIEF §3.6: "Show the original node's hint
(hand-written, one level)"). The diagnosis actor row "ask for the next hint" and learning-objects W2 step 2
("Tiers issue one at a time on request") are deferred to after the Demo. I3 is unaffected: learning-objects
§ Invariants says "the tree gates nothing". This is a Demo scope cut by the owner's own Demo brief, not a Q5.

**DEFERRED entry** (task 1, or the 04b wrap; next free `D-n`):

```
### D-n — Hint tiers 2–3 ("ask for the next hint") on Door A screens
**Observed:** EPIC 04 shows only tier 1 of the resolved hint (arbiter-04 Q-F, per DEMO-BRIEF §3.6 "one
level"); `data/demo` carries three tiers per `hint_tree` entry (schema minItems/maxItems 3).
**Configuration:** Demo, Tier 0, iOS app.
**Revisit trigger:** Demo observations, or EPIC 12 (M3 screens on real data).
**Hypothesis (unverified):** none.
```

**Citations.** `DEMO-BRIEF.md` §3.6 (line 55); `docs/domains/diagnosis.md` § Actors (line 24);
`docs/domains/learning-objects.md` W2 (lines 89–95) and § Invariants (line 140);
`contracts/schemas/nodes.schema.json` (lines 220–221).

---

## Q-C — "Completable by touch on the simulator" without a UI-test target

**Not decided** (owner's Q5 candidate). The default path is **confirmed sufficient to proceed**, provided the
acceptance report states the exclusion.

**What the default path does evidence:**
- `Core` C1 tests drive the same façade entry points the buttons call, on real `data/demo`, through a full
  expedition and a full diagnosis on each trigger.
- A source scan shows each Door button's action is exactly one façade call, with a negative control.
- The App build is green.
- EPIC 03's launch smoke shows the App launches, and a seeded state migrates and survives relaunch.

**What it cannot claim** (the exclusion that must be stated verbatim in the 04b task specs and the acceptance
report):
1. that any tap on a simulator actually fires its action: hit-testing, sheet and navigation presentation, and
   keypad key → string binding at runtime;
2. that each Door screen is laid out so its controls are visible and reachable (e.g. continue and decline are
   on screen);
3. that no runtime trap occurs along the Door screens after launch. The smoke only covers launch and relaunch;
4. that the sequence of screens a student sees matches the façade's screen values at runtime, rather than only
   in `CoreTests`.

So the epic-plan row 04 criterion ("one full expedition + one diagnosis completable by touch on the simulator
(§8)") is **not claimed literally**. It is evidenced by logic, composition and static wiring.

**The acceptance record must split the v2.2 §B line** "one expedition and one diagnosis event completable by
touch" into two lines:
- *simulator — agent*: logic, composition and wiring, naming the three instruments above and exclusions 1–4;
- *device — owner*: the literal tap-through (D29).

If the owner adds `mathmathUITests` before dispatch (option 2), exclusions 1, 3 and 4 move to the agent side
for the scripted path. The brief's revisit trigger stands.

**Citations.** `docs/epic-plan.md` (line 23, row 04); `AMENDMENT-v2.2.md` §B (line 34); `docs/tech-stack.md` § 1
rows "Swift tests" and "App project" (lines 22, 24); `tasks/arbitration/arbiter-03-predispatch.md` § Q-G ("a
launch-argument hook is **not** permitted"); `CLAUDE.md` Gates (D29).

---

## Other claims verified in this run

| Brief claim | Verification | Result |
|---|---|---|
| `ItemChecker.swift:184-190` gives the `mc` display as the choice `latex` | `ItemChecker.swift:183-191` | VALID; the range is off by one line |
| `CoreError.swift:18-25` holds the six `EXP_*` / `DIAG_*` cases | `CoreError.swift:18-25` | VALID |
| `Rendering` is linked into the App target | `project.pbxproj`: 8 `Rendering` hits (count only) | VALID as far as a count shows; the planner re-reads the lines |
| 02.11 phase types have no public init; only `open`/`start`/`decideProbe`/`answerProbeItem`/`decideFurtherLevel` are public | 02.11 spec AC15, § 4 steps 2, 5; arbiter-02-11-stepwise-api Rulings 1–2 | VALID as specified. `Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift` is **absent on `main` at 590f40c** (Glob). Brief § 6 "EPIC 02b (merged)" must be true before dispatch |
| `data/demo`: 20 nodes, 40 items | `nodes.json` read in full | VALID |
| The glossary bans "session" (Expedition) | `domain-glossary.md` lines 29, 62 | Precision: new EPIC 04 identifiers and copy must not use "Session", "Quiz" or "Question". Reuse EPIC 03's landed session type name as-is; do not add a second one |

## Consequences for the planner

1. **Task 1 (contract).** Two contract commits:
   - `interaction-contract` v0.9.3: the three § 2 bullets and the Finalization paragraph (Q-A, Q-G);
   - `domain-glossary` v1.0.1 (Q-B).

   Plus the `docs/domains/diagnosis.md` edits (Q-B ×2, Q-D ×1) and the DEFERRED entries (Q-A tint; Q-F tiers,
   or at wrap). It depends on EPIC 03's v0.9.2 having landed.
2. **Task 2 (Door B façade).** The continue entry point, the Q-G write-ahead sequencing, and the re-worded items
   1 and 5. The natural `end` happens in the last-result call.
3. **Task 3 (Door A façade).** The hint resolver with the generic tier-1 fallback, and the remediation selector
   (Q-B). The `CoreError.loHintNotFound` additive case: this task is the only EPIC 04 writer of
   `CoreError.swift`. The Door copy constants (Q-D). The re-worded item 4 bullet.
4. **Task 5 (`MathView`).** The Q-E fallback and field routing. The population is 80 strings.
5. **Tasks 7/8.** The Q-C exclusion text, verbatim, and the split acceptance-record line. The v1.0.0 flip at
   wrap.
6. `error-codes.json` gains no entry. No D-number changes. No Q5 is raised.
