# ARBITER RULING: hint fallback — reconciling arbiter-04 § Q-B with arbiter-02-none-of-these

**Date**: 2026-09-10
**Trigger**: Q4. Two arbitrations disagree on what happens when no classified hint key resolves.
- **Ruling A**: `tasks/arbitration/arbiter-04-predispatch.md` § Q-B.
- **Ruling B**: `tasks/arbitration/arbiter-02-none-of-these.md`, applied to `tasks/epic-02-task-11-diagnosis-machine-seam.md`.

The EPIC 04 brief (`docs/epics/epic-04-app-expedition-diagnosis-acceptance.md`, untracked) calls this "the separate none-of-these arbitration" in its §9 cross-reference (:524-531): "If it lands and conflicts with arbiter-04 § Q-B, that conflict goes back to the spec-arbiter". This file answers that.

**Scope of authority**: `tasks/*` only. No contract, source, data, doc or brief is changed by this ruling. No EPIC 04 task spec exists yet.
**Route**: no ESCALATE-Q5. No D-number and no invariant meaning changes (see § Q5 check).

## Findings analysis

| # | Claim | Verification | Classification |
|---|-------|--------------|----------------|
| 1 | Ruling A: "the node's generic tier-1 hint" (learning-objects W2) means tier 1 of the first `error_types[]` member, in catalogue order, that has a `hint_tree` entry | **REFUTED.** Every prior source reads it as a node-level hint that names no specific mistake:<br>(a) `docs/epics/epic-02-core-behaviour.md:476`: "A hint whose error type has no `hint_tree` entry falls back to the node's `none-of-these` hint."<br>(b) The Phase-4 prototype that realised W2, `docs/prototype/student-session-hint.html`. The **"generic"** variant (:31, :54) shows "No specific mistake picked" and "Hint 1 of 3 · general" with the prose "Look again at the step where the logarithm disappears. Every log equation hides an exponential one." The **"notfound"** (`LO_HINT_NOT_FOUND`) variant (:33, :39) shows the *same* general prose. The *specific* hint for the classified type ("Look at how you went from a logarithm to a power…", :39, :46) is a different string. So the generic hint is the none-of-these branch, never a sibling type's branch.<br>(c) `DEMO-BRIEF.md` §5 :74 gives each Demo node a single node-level "hint (one string)", and §3.6 :55 says "Show the original node's hint".<br>Borrowing another member's tier 1 would present a misconception the classifier did not name. That breaks `CLAUDE.md` I2 ("the system never guesses a diagnosis") and `docs/domains/learning-objects.md:47-48` ("`none_of_these` is always `null`: abstention, not diagnosis"). | VALID against Ruling A |
| 2 | Ruling B: `hintKey` returns the classified id, else the catalogue id `"none-of-these"`, else `nil`; never another type's key | Confirmed by the 02.11 spec AC16 (:62-71) and §6 (:1122-1141). It matches reading (a) of finding 1 exactly. `contracts/data-model.md:50` gives the catalogue id as kebab: "one `none-of-these`". `contracts/schemas/nodes.schema.json:212-222` lets any id key a `hint_tree` entry of exactly 3 non-empty strings. | VALID — Ruling B stands |
| 3 | On `data/demo`, no node carries `hint_tree["none-of-these"]` | Confirmed. `data/demo/nodes.json` `hint_tree` objects hold only real error types, for example `{"sign-error":[…]}` and `{"wrong-order":[…]}` (Grep `-o`). The arbiter-04 § Q-B count ("Every `hint_tree` has exactly one key… `exponential-functions` is the exception, with two keys") and arbiter-02 finding 4 agree. | VALID |
| 4 | `LO_HINT_NOT_FOUND` is not registered (02.11 §6 :1137: "No new error code is raised, since none is registered"; arbiter-02 Ruling 4: "none is registered") | **REFUTED as a fact.** `contracts/error-codes.json:34`: `{"code": "LO_HINT_NOT_FOUND", "recoverable": true, "surface": "internal", "user_text": null}`. `CoreError.swift:11-27` has no case for it yet. | INVALID (the premise). 02.11's *behaviour* is still correct: the machine returns keys and raises no code (see Rule 2). |
| 5 | The 02.11 spec must change | **No.**<br>(a) `hintKey` is correct under finding 1.<br>(b) Its real-data assertions are *derived* from each node's own data, not pinned. T10 (:1035): "`hintKey(node, "none_of_these") == ((node.hintTree["none-of-these"] ?? []).isEmpty ? nil : "none-of-these")`". T8 (:988-992) likewise. Both stay green before and after the Rule 4 data change.<br>(c) Two non-normative sentences are imprecise and are corrected here by reference, not by edit:<br>• §6 :1137 has a wrong rationale (finding 4).<br>• §6 :1135-1136 says the nil-key presentation is "outside `Core` (I14)". Under Rule 3 the prose is resolved by EPIC 04's Door A façade *inside* `Core`; only the rendering is App-side.<br>Neither sentence drives any AC or test. The implementer builds exactly what AC16 and T10 state. | INVALID (no spec change) |
| 6 | Without a none-of-these hint, W1/W3's "a tier-1 hint on the origin" is undeliverable on `data/demo` (Ruling B F3) | Confirmed.<br>• `docs/domains/diagnosis.md` W1 step 3 (:57-58): "on `none_of_these` with no candidate, a tier-1 hint on the origin".<br>• W3 step 4 (:72-73): "Pass → `refuted` … W5 with a tier-1 hint on the origin".<br>• `DEMO-BRIEF.md` §3.6 :55: "Pass → 'Not the issue.' Show the original node's hint".<br>Every `map_check_here` event starts with `failedAttempts == []`, so `originErrorTypeId == "none_of_these"` (arbiter-04 § Q-B), and `hintKey` is `nil` on every node. | VALID |
| 7 | Adding `hint_tree["none-of-these"]` is allowed without a contract change | Confirmed.<br>• `nodes.schema.json:212-222` (`additionalProperties`, 3 strings, `minLength: 1`) accepts it.<br>• `learning-objects.md` W1 step 4 (:77-78), "every ErrorType but `none_of_these` has a full tier list", *exempts* the member from coverage and does not forbid an entry.<br>• `content-policy.md` § Generated content (:34-35): "Prompts and hints must render in SwiftMath or carry `render_fallback`".<br>• I9: the Demo bundle is "hand-written *data* (D26 allows it for the Demo), validated by machine; a failing item is rewritten, not approved" (`docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:50-51`). | VALID |
| 8 | A data change has cascades beyond `nodes.json` | Confirmed. Each of the following would change:<br>• The rendering-spike outcome pins "`hint_tree` tier strings \| 63" and "**Total** \| **143**" (`docs/epics/epic-01-rendering-spike-outcome.md:18, :20`), and a test pins that table (`Packages/Rendering/Tests/RenderingTests/OutcomeRecordAndImportBoundaryTests.swift:102, :104`). A comment cites "63/143" at `FieldKindPolicyMutationTests.swift:180`.<br>• EPIC 03 task 03.4 embeds a byte-identical copy of `data/demo` with a mandatory byte-identity test (`tasks/context/epic-03-task-04-context.md:91, :116`).<br>• `data/demo/manifest.json` carries placeholder `asset_version`/`sha256` values (`"nodes-v0"`, all zeros, :27-29). The restamp helper is `pipeline/src/mathmath_pipeline/bundle.py:24-38`. | VALID → decomposition (spec-architect / EPIC 04 planner) |
| 9 | Glossary and learning-objects spell the catalogue member with the outcome token (Ruling B F4) | Confirmed:<br>• `contracts/domain-glossary.md:45`: "a member of a node's closed catalogue, incl. `none_of_these`".<br>• `docs/domains/learning-objects.md:42` "exactly one terminal `none_of_these`", `:47` "`none_of_these` is always `null`", `:75` "exactly one `none_of_these`", `:77` "every ErrorType but `none_of_these`".<br>• W2 :92-93 leaves "the node's generic tier-1 hint" undefined, which is the root of finding 1. | VALID |

## Reconciled rule (binding on EPIC 04 brief and specs)

### Rule 1: what `Core` returns when no hint resolves

This is 02.11's rule, unchanged. `hintKey(originNode:errorTypeId:) -> String?` resolves in this order and never returns another error type's key:
1. the classified id;
2. else `"none-of-these"`;
3. else `nil`.

`DiagnosisOutcome.hintErrorTypeId` carries that result. `hintNodeId == originNodeId` on every hint terminal.

**The definition that replaces Ruling A.** "The node's generic tier-1 hint" (learning-objects W2) is **`hint_tree["none-of-these"][0]`**, and nothing else.

### Rule 2: `LO_HINT_NOT_FOUND`

It is raised **as internal data, never thrown and never shown**, by EPIC 04's Door A hint-prose resolver in `Core` (task 04.3, per `docs/plans/epic-04-plan.md:20, :43-45`). It is not raised in 02.11, whose machine returns keys only (02.11 T3 :924: "An unresolved hint key raises no code" — that is about `DiagnosisOutcome.code`, and it stands).

**The resolver.** Input is `(node, classifiedToken)`. For a terminal hint the token is `context.originErrorTypeId` (`public let`, 02.11 :659). For remediation it is `Classify.classify(probeResult.incorrectAttempts)`. The key is `hintKey(originNode: node, errorTypeId: classifiedToken)`, called in-module. `hintKey` is internal (arbiter-02-11-stepwise-api Ruling 2), and the Door façade is in `Core` (brief §8, 04a is "all `Core`"), so no reimplementation occurs.

Let `expected` = `"none-of-these"` if the token is the outcome token `"none_of_these"`, else the token itself. Then:

| Case | Prose | `internalCode` |
|---|---|---|
| key == `expected` | `node.hintTree[key]![0]` | nil |
| key ≠ nil, key ≠ `expected` (a classified type had no entry, so the none-of-these branch served) | `node.hintTree[key]![0]` | `.loHintNotFound` |
| key == nil | `node.paraphrase` | `.loHintNotFound` |

`CoreError` gains the additive case `loHintNotFound = "LO_HINT_NOT_FOUND"` in 04.3. That is registered and internal, so it has no userText entry. This part of Ruling A stands.

### Rule 3: what the student sees when the key is `nil`

Every hint slot shows the **origin node's `paraphrase`** in place of hint prose, with no label naming a mistake. This applies to the refuted terminal, `DIAG_NO_PREREQUISITE`, `DIAG_PROBE_UNAVAILABLE`, declined-`unconfirmed`, and the W1 abstention path.

The slot is never blank and never shows a sibling type's hint. `LO_HINT_NOT_FOUND` never reaches the screen (`contracts/error-codes.md` § Rules: "Internal codes never reach a student surface"). The prototype's "No hint written for that exact mistake yet" banner (:33) is therefore **not** built.

Why:
- **Honest wording.** The registered texts promise a hint: "Nothing upstream to check — here's a hint." and "No quick check is available for this one yet; here's a hint instead." (quoted in 02.11 :228-229 from `error-codes.json`). A blank slot would make that copy false.
- **Content policy.** The paraphrase is the project's own sentence, so I6 and `content-policy.md` § Grade 9–12 tier are satisfied.
- **I2.** It asserts no `ErrorType`, and learning-objects' error table (:131) says the user sees a "Generic node hint".
- **I3.** Terminals follow the answer cards (arbiter-04 § Q-A), so nothing is withheld.

**Remediation (confirmed candidate X).** The order is `X.explanation` → `X.worked_examples[0]` → `X.paraphrase` plus the Rule 2 hint prose for `(X, Classify.classify(probeResult.incorrectAttempts))`. When the key is nil, the hint part is **omitted**, so the paraphrase is not shown twice, and the piece is the paraphrase alone. It is never empty.

**Ruling A's empty-`hint_tree` branch.** Ruling A said "if `hint_tree` is empty, the hint line is the node's `paraphrase`". That is subsumed by the key == nil row.

### Rule 4: the F3 content gap

**Yes.** The Demo bundle carries `hint_tree["none-of-these"]` on **every** node. This delivers W1 step 3, W3 step 4 and DEMO-BRIEF §3.6/§5 "the original node's hint" on the Demo's commonest path (`map_check_here`). After this change the Rule 3 nil branch is unreachable on `data/demo`. It remains live for any bundle that lacks the entry: `contracts/examples/nodes.json` ships `"hint_tree": {}`.

This is a **new task**, so it is decomposition. Route: EPIC 04 planner / spec-architect; the brief-amender adds it to the brief. The recommended placement is an 04a task ordered **after 04.1 and before 04.3**, so 04.3's real-data tests exercise the resolving path. It must not run concurrently with EPIC 03's 03.4 (the embedded snapshot).

It is not an EPIC 03 task: no EPIC 03 spec writes `data/demo` (03.1 :88 "no data edit"; 03.7 :191 "`data/demo/**` … read-only").

**Content constraints for the task spec** (I9: hand-written data, machine-validated, no review step):
- Each of the 20 nodes gets `"none-of-these": [t1, t2, t3]`, three non-empty strings (schema :212-222).
- Voice follows learning-objects HintTree :50-51: tier 1 "nudges at what to look at", and tier 3 works the step through.
- No string names or describes a sibling `error_types[]` member's misconception (I2).
- Plain text, no Ministry prose (I6).

**Instruments.** Each names empty = FAIL and a negative control:
- **Schema decode and L0**, via `core-cli validate` / `BundleIO.read`.
- **`BundleRenderCheckTests` over `data/demo`**, 0 unresolved.
- **A `CoreTests` data assertion.** For every node (count > 0, empty = FAIL):
  - `hint_tree["none-of-these"]` has 3 non-empty strings;
  - its tier-1 string differs from every other key's tier-1 string on that node. A planted copy of a sibling's tier fails this.
- **A second `CoreTests` assertion.** For every node, `hintKey(node, "none_of_these") == "none-of-these"`. 02.11's derived T10 assertion already covers this and needs no edit.

No SymPy/CAS step applies: hints are neither ProbeItem answers nor WorkedExample steps (`content-policy.md` § Generated content :29-35; EPIC 01 brief :51-54).

**Cascade in the same task's file scope:**
- `data/demo/nodes.json`;
- the 03.4 embedded snapshot copy, if 03.4 has landed (byte-identity test);
- the spike outcome's hint and total rows, now 63 + 3×20 = 123 and 143 + 60 = 203 [SOURCED: arithmetic over finding 8 and the 20-node count, arbiter-04 § Q-B], **recomputed by the task's scan, not typed from this line**;
- the pinned table in `OutcomeRecordAndImportBoundaryTests.swift`, and the comment at `FieldKindPolicyMutationTests.swift:180`;
- `data/demo/manifest.json`, only if a landed task has replaced the placeholder hashes. In that case run `bundle.py` restamp; while they are placeholders, leave them. EPIC 03 ruled "no embedded-snapshot hash check" (arbiter-03 § Q-H; `epic-03-app-map-shell.md:602-609`).

**Not a Q5.** No D-number governs hint authoring, and D26 already allows hand-written Demo data.

### Rule 5: F4 clarifications

**Owning task: 04.1**, in the same `contract(domain-glossary)` commit and `docs/domains` cascade that 04.1 already carries (brief §8 item 1; plan :38). The texts are exact.

**Glossary header (v1.0.1)**, replacing Ruling A's header text:
```
**Contract version:** v1.0.1 · Source: `docs/domains/*.md`, `docs/idea.md` (D1–D49); v1.0.1 clarifies Remediation for nodes without an Explanation and the two none-of-these tokens (arbiter-04 Q-B; arbiter-04-hint-fallback-reconciliation)
```

**Glossary § Diagnosis (Door A), Remediation**, replacing Ruling A's sentence:
> **Remediation** — one Explanation or WorkedExample for a confirmed candidate; when the node carries neither, its `paraphrase` plus, when one resolves, one tier-1 hint (DEMO-BRIEF §3.6).

**Glossary :45, Error type**:
> **Error type** (`ErrorType`) — a member of a node's closed catalogue, incl. the none-of-these member, whose catalogue id is `none-of-these`; `classify` reports abstention as the outcome token `none_of_these`, which is never a catalogue id or a `hint_tree` key.

**`docs/domains/diagnosis.md` edits**, amending Ruling A's cascade:
- **§ Core entities, Remediation.** Replace "one `Explanation` or `WorkedExample` from **learning-objects**, then return." with "one `Explanation` or `WorkedExample` from **learning-objects** — or, when the node carries neither, its `paraphrase` plus, when one resolves, one tier-1 hint (DEMO-BRIEF §3.6) — then return."
- **§ UI surfaces.** Replace "(W4, one explanation or worked example)" with "(W4, one explanation or worked example, else the paraphrase and, when one resolves, one tier-1 hint)".
- **Ruling A's Q-D edit** to W3 step 1 is untouched by this ruling.

**`docs/domains/learning-objects.md` edits** (catalogue-id spelling; W2 definition):
- **:41-42.** "with exactly one terminal `none_of_these`" → "with exactly one terminal member `none-of-these` (catalogue id; `classify`'s abstention outcome is the token `none_of_these`)".
- **:47-48.** "and `none_of_these` is always `null`: abstention, not diagnosis." → "and `none-of-these` is always `null`: abstention, not diagnosis."
- **:75.** "exactly one `none_of_these`" → "exactly one `none-of-these`".
- **:77.** "every ErrorType but `none_of_these` has a full tier list" → "every ErrorType but `none-of-these` has a full tier list (a `none-of-these` entry is optional; when present it is the node's generic hint)".
- **W2 step 1 (:92-93).** "a miss raises `LO_HINT_NOT_FOUND` and the session falls back to the node's generic tier-1 hint" → "a miss raises `LO_HINT_NOT_FOUND` (internal data) and the session falls back to the node's generic tier-1 hint, `hint_tree["none-of-these"][0]`, else the node's `paraphrase`; never another ErrorType's hint (I2)".
- **Q4 heading (:162)**: keep "`none_of_these`" there. It names the outcome.
- Change-log row: `| 2026-09-10 | Catalogue id spelled \`none-of-these\`; W2 generic hint defined (arbiter-04-hint-fallback-reconciliation). |`

**`contracts/runtime-tiers.md:20`**: no edit (Ruling B F4 stands; EPIC 13 adapter maps its enum case to the outcome token). **F5** (telemetry maps the outcome token to `null`): stands, EPIC 11.

## Parts of Ruling A (arbiter-04 § Q-B) superseded

| Ruling A text | Status |
|---|---|
| Rule 1: "the node's **generic tier-1 hint**: tier 1 of the `hint_tree` entry for the first member of `node.errorTypes`, in catalogue order, that has one" | **SUPERSEDED.** The generic hint is `hint_tree["none-of-these"][0]` via 02.11 `hintKey`. |
| Rule 1: "If `hint_tree` is empty, the hint line is the node's `paraphrase`" | **SUPERSEDED.** The paraphrase is used whenever the key is nil (Rule 3). |
| Rule 1: returns prose, key and `internalCode: .loHintNotFound` when the fallback fired; `CoreError.loHintNotFound` additive case, internal, no userText | **STANDS**, with the firing condition of Rule 2. |
| Rule 1 I2 bullet: "A tier-1 hint is a nudge on a node the flow already names, with no `ErrorType` asserted" | **SUPERSEDED** for sibling-type borrowing: a sibling type's tier 1 does assert that type. It stands for the none-of-these branch and the paraphrase. |
| Rule 1: "On `data/demo` the empty-`hint_tree` branch is unreachable" | Moot after Rule 3. |
| Rule 2 remediation order, "never empty", the §3.6 alignment, I6, I3, the Registry note and the capped ordering | **STANDS**, except that the hint part is omitted when the key is nil (Rule 3). |
| Rule 3 glossary text and header; Cascade diagnosis.md texts | **AMENDED** to the Rule 5 texts ("plus, when one resolves, one tier-1 hint"). |
| "Brief § 4 item 4, re-worded bullet" | **SUPERSEDED** (see below). |
| "Naming note … Neither string is ever used as a lookup that must succeed" | **SUPERSEDED.** `"none-of-these"` is a lookup that succeeds on `data/demo` after Rule 4. Do not edit `Classify.swift` or 02.11 (this part stands). |

**Ruling B** stands whole. One correction: its Ruling 4 premise "none is registered" is wrong (`error-codes.json:34`), but its conclusion that the machine raises no code is correct under Rule 2. Its F2 wording ("a `nil` key … renders no hint prose") is replaced by Rule 3 (the paraphrase is shown).

## What the EPIC 04 brief and specs must reflect

These are for the brief-amender. This file edits none of them.

1. **§2 hint bullet (:83-89).** The resolver calls 02.11 `hintKey` in-module. Prose and `internalCode` follow the Rule 2 table. Delete "(tier 1 of the first `error_types[]` member, in catalogue order, with a `hint_tree` entry)".
2. **§2 remediation bullet (:77-81).** Add "the hint part omitted when no key resolves".
3. **§3 I2 line (:231-232).** Replace it with: "The hint fallback is `hint_tree["none-of-these"]`, else the paraphrase; it never borrows another ErrorType's hint (arbiter-04-hint-fallback-reconciliation)."
4. **§3 glossary bullet (:176-179) and Passage 11.** Use the Rule 5 texts; the glossary bullet also carries the :45 Error-type line. The domains cascade adds the `learning-objects.md` edits.
5. **§4 item 4, hint bullet (:312-316).** Replace it with: "the hint prose follows the Rule 2 table of `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md` over 02.11's `hintKey`. On `data/demo` after the Rule 4 task, every `map_check_here` hint terminal shows `hint_tree["none-of-these"][0]` with `internalCode == nil`. A constructed node without that entry shows its `paraphrase` with `.loHintNotFound`. Negative controls:
   - a resolver returning empty prose fails;
   - a resolver returning a sibling type's tier 1 for the outcome token fails."
6. **§8 and plan.** Add the Rule 4 data task (04a, between 04.1 and 04.3) with its cascade scope. 04.1 carries the Rule 5 texts.
7. **§9 Q-B resolution (:514-523) and cross-reference (:524-531).** Record this reconciliation. The cross-reference sentence "no lookup of either spelling is required to succeed" is withdrawn.

## Q5 check

The following are clarifications and data within existing rules, not changes to any locked decision or invariant:
- I2 (never guess), and it now applies uniformly;
- I3 (answers shown before any terminal);
- I9 (machine-validated hand-written Demo data, D26);
- D5, D7 and D26.

No D-number is touched, so no ESCALATE-Q5.
