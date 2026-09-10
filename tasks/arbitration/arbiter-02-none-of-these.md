# ARBITER RULING: `none_of_these` (classify outcome) vs `none-of-these` (catalogue id)

**Date**: 2026-09-10
**Trigger**: Q4 — spelling split found by the EPIC 04 planner; blocks task 02.11 (`tasks/epic-02-task-11-diagnosis-machine-seam.md`), whose `hintKey` resolves hint keys with a none-of-these fallback.
**Scope of authority**: `tasks/*` only. No contract, source, data or doc is changed by this ruling.

## Findings analysis

| # | Claim | Verification | Classification |
|---|-------|--------------|----------------|
| 1 | Data and the data contracts use the hyphen form `none-of-these` | `contracts/data-model.md:50` nodes.json row: "`error_types[]` (closed, one `none-of-these`, each `implies_prerequisite?`), `hint_tree {error_type_id → [tier1, tier2, tier3]}`"; `contracts/content-policy.md:36-37`: "`none-of-these` is never a tag"; `contracts/examples/nodes.json:32, :113, :164` (`"id": "none-of-these"`); `data/demo/nodes.json`: 20 occurrences of `"none-of-these"`, 0 of `none_of_these` | VALID |
| 2 | Classify, the diagnosis contract and the glossary use the underscore form `none_of_these` | `Packages/Core/Sources/Core/Diagnosis/Classify.swift:22, :41` (`return "none_of_these"`); `Packages/Core/Tests/CoreTests/ClassifyTests.swift:71-74` (asserts `== "none_of_these"` and `!= "none-of-these"`); `contracts/interaction-contract.md` § `## 4. Diagnosis (Door A)` :82: "`classify`: distractor-tag lookup over the failed items → `error_type` or `none_of_these`"; `contracts/domain-glossary.md:45`; `contracts/runtime-tiers.md:20` | VALID |
| 3 | These are the same identifier spelled two ways | REFUTED. They are two different kinds of token: (a) a **catalogue id**, which must be kebab-case: `contracts/data-model.md` § `### Identifiers` :13, "Ids are **stable, opaque, lowercase kebab-case slugs** matching `^[a-z0-9]+(-[a-z0-9]+)*$`", repeated for `error_types[].id` at `contracts/schemas/nodes.schema.json:191-193`. `none_of_these` cannot be a valid catalogue id or `hint_tree` key id under that pattern. (b) The **classify outcome**, which the interaction contract states as an alternative to `error_type`: "→ `error_type` or `none_of_these`" (:82). That is an abstention outcome, not a member id. The landed `Classify` returns (a) on a match (`:30`, `:37` return `errorTypeId`) and (b) otherwise (`:41`) | INVALID (as a "same identifier" claim) |
| 4 | 02.11's fallback resolves on real `data/demo` if the spelling is fixed | REFUTED. No `data/demo` node has a `hint_tree` entry for the none-of-these member in **either** spelling. All 20 `"none-of-these"` occurrences in `data/demo/nodes.json` are inside `error_types[]` (`{"id":"none-of-these","label":"None of these"}`). Each `hint_tree` holds only the node's real error types (one key per node; two on `exponential-functions`, whose second key is `multiplied-instead-of-power`). This is allowed: `nodes.schema.json:212-222` requires no key, and `docs/domains/learning-objects.md:77-78` exempts the member: "every ErrorType but `none_of_these` has a full tier list". `contracts/examples/nodes.json:168` even ships `"hint_tree": {}` | VALID (new, and more serious than the spelling) |
| 5 | The 02.11 spec's `hintKey` is defective | VALID. Spec §4 step 5 returns the literal `"none_of_these"` as the fallback, and §6 says it does so "regardless" of whether the key exists. That key can never match a `hint_tree` key, because hint keys are catalogue ids (finding 3). So on every `map_check_here` diagnosis (`failedAttempts == []` → `none_of_these`), `hintErrorTypeId` would name a non-existent key. The spec's own T4 I5 check ("always equal to a `Node.id` or a `hintTree` key") would then be false | VALID |
| 6 | Landed `Classify.swift` / `ClassifyTests.swift` (02.10) must change | INVALID. Classify returns what `interaction-contract.md` § 4 specifies. Bias is unaffected: `PrerequisiteQuery.swift:97-100` looks the bias id up in `originNode.errorTypes`. `none_of_these` matches no member, which means no bias. `none-of-these` would match a member with no `implies_prerequisite` (`docs/domains/learning-objects.md:47-48`: "`none_of_these` is always `null`"), which also means no bias. The two spellings behave identically there | INVALID |

## Ruling

1. **Two distinct tokens; both spellings stand.** `none_of_these` is the classify **outcome** token (abstention), per `interaction-contract.md` § 4. `none-of-these` is the **catalogue id** of the node's none-of-these `ErrorType`, and it is the only form that may appear as an `error_types[].id` or a `hint_tree` key, per `data-model.md` § Identifiers and `nodes.schema.json:193`. No contract, landed code, test or data changes.
2. **The two are never compared or looked up as each other.** A consumer that needs a data key maps the outcome token to the catalogue id explicitly.
3. **02.11 `hintKey`** becomes `hintKey(originNode: Node, errorTypeId: String) -> String?`. It resolves in this order:
   1. `errorTypeId`, if it is not the outcome token `"none_of_these"` and `originNode.hintTree[errorTypeId]` is non-nil and non-empty;
   2. otherwise the catalogue id `"none-of-these"`, if `originNode.hintTree["none-of-these"]` is non-nil and non-empty;
   3. otherwise `nil`.

   It never returns `"none_of_these"`. It never substitutes another error type's hint: that would present a misconception the student was not classified with, which is guessing a diagnosis (`CLAUDE.md` I2: "the system never guesses a diagnosis"; `docs/domains/learning-objects.md:47-48`: "abstention, not diagnosis").
4. **Consequence on real `data/demo`:** the fallback resolves to `nil` on every node (finding 4). A hint terminal therefore still carries `hintNodeId == originNodeId` (the hint location), but `hintErrorTypeId == nil`. That is an honest "no keyed hint exists", not a dangling key. No new error code is raised; none is registered, and adding one would need a contract bump.

## Spec change applied

`tasks/epic-02-task-11-diagnosis-machine-seam.md` (rewritten in the same pass):
- **§1:** I2 note; new AC16.
- **§3:** verbatim anchors for § Identifiers, the nodes.json row, the schema pattern and `hint_tree` shape, learning-objects hint coverage, `Classify.swift:22/:41`, and the `data/demo` fact.
- **§4 step 2:** `hintErrorTypeId` / `originErrorTypeId` comments.
- **§4 step 5:** the `hintKey` signature and rule; the `terminal` wiring.
- **§5:** T4 I5 wording, T5 two new negative controls, T8 real-data hint assertion, new T10.
- **§6:** the fallback default replaced with two defaults.
- **§7:** T1–T10.

## Follow-ups (not in 02.11's scope)

- **F1 — landed code (02.10):** none required. `Classify.swift` and `ClassifyTests.swift` stay as they are.
- **F2 — EPIC 04 (route: spec-architect / EPIC 04 planner), `docs/epics/epic-04-app-expedition-diagnosis-acceptance.md`:**
  - **:254-255** ("the hint prose equals the `hint_tree` tier resolved from `hintErrorTypeId`, with the `none_of_these` fallback"): restate it as "resolved from `hintErrorTypeId` as returned by `Core` (02.11 `hintKey`); a `nil` key with non-nil `hintNodeId` renders no hint prose".
  - **:403-405** (Q-B, "tier-1 hint keyed by `Classify` … with the `none_of_these` fallback. It is never empty"): restate it to call 02.11's `hintKey`. Q-B is non-empty only because of the `paraphrase` part. On `data/demo` the hint part is absent whenever classify abstains.
  - EPIC 04 must define the presentation for a hint terminal with `hintErrorTypeId == nil`. DEMO-BRIEF §3.6 and the origin's `paraphrase` are the natural candidates. That is an EPIC 04 spec decision.
- **F3 — content gap (route: spec-architect):**
  - `docs/domains/diagnosis.md` W1 step 3 and W3 step 4 promise "a tier-1 hint on the origin" on abstention and on `refuted`.
  - With classify abstaining, every `map_check_here` hint terminal on `data/demo` has no keyed hint, because the content rules exempt the none-of-these member from hint coverage (`learning-objects.md:77-78`).
  - Whether the pipeline must generate a `hint_tree["none-of-these"]` branch is a versioned learning-objects / content-policy + data change. It is not arbiter scope, and no D-number is touched.
  - If it lands, 02.11's `hintKey` resolves to `"none-of-these"` with no code change: that is AC16's fixture case.
- **F4 — contract editorial (route: spec-architect, PATCH):**
  - `contracts/domain-glossary.md:45` ("a member of a node's closed catalogue, incl. `none_of_these`") names the catalogue member with the outcome spelling. A clarifying PATCH should read: catalogue id `none-of-these`, classify outcome `none_of_these`.
  - The same applies to `docs/domains/learning-objects.md:42, :47, :75, :77`.
  - `contracts/runtime-tiers.md:20`'s `@Generable` enum case `none_of_these` is a Swift enum case. The EPIC 13 adapter maps it to the outcome token, never to a data key.
- **F5 — telemetry (EPIC 11):** the `diagnosis.hypothesis_formed` payload `error_type|null` (`docs/domains/diagnosis.md` notifications-produced) maps the outcome token `none_of_these` to `null`, never to either string.
