# Epic 04 · Task 01b: Demo `hint_tree["none-of-these"]` data

---
epic: 04
task: 01b
slug: data-demo-none-of-these-hints
kind: feat
risk: seam
depends_on: ["04.1"]
model: sonnet
---

## §0 Preconditions (branch context)

This task runs on branch `epic-04a-door-core`, after EPIC 03 has merged into `main` and after task **04.1**
has landed (`depends_on`). Two facts this spec relies on are NOT yet true on the tree this spec was written
against and MUST be verified true before editing:

1. `App/Sources/DemoSnapshot/nodes.json` exists as the byte-identical copy of `data/demo/nodes.json`, created
   by EPIC 03 task 03.4 (`tasks/epic-03-task-04-bundle-loader-snapshot-seam.md`), guarded by
   `Packages/Core/Tests/CoreTests/DemoSnapshotSeamTests.swift` and kept in sync by
   `scripts/embed-demo-snapshot.sh` (a regenerating script — never hand-edit the copy independently of the
   source; run the script, or apply the byte-identical edit by hand and diff against the script's output).
   Verified ABSENT on the pre-EPIC-03-merge tree this spec was written against
   (`tasks/context/epic-04-task-01b-context.md` §E). If it is still absent when this task executes, EPIC 03
   has not actually merged — stop and report the dependency gap; do not fabricate the directory.
2. `docs/domains/learning-objects.md` and `contracts/domain-glossary.md` carry the Rule 5 texts from
   `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md` (the `none-of-these` kebab-case catalogue-id
   spelling and the W2 generic-hint definition), landed by task 04.1 per that ruling's § Rule 5 ("Owning
   task: 04.1"). Verified NOT YET landed on the tree this spec was written against (current
   `contracts/domain-glossary.md:45` and `docs/domains/learning-objects.md:77,92-93` still carry the
   pre-amendment text). Since 04.1 is this task's dependency, it must be landed by the time this task runs;
   §3 quotes the Rule-5 text as the arbiter ruling specifies it, not as read from the current file.

## §1 Goal & acceptance criteria

Goal: add a `hint_tree["none-of-these"]` entry (exactly three non-empty, plain-text tiers) to every one of
the 20 nodes in `data/demo/nodes.json`, so that the generic (non-diagnosing) hint the Door-A flow shows on
abstention has real content on the Demo bundle, and propagate the ripple this data change causes: the
embedded App snapshot copy, the rendering-spike count table, and the tests/comments that pin the old counts.
This is a hand-written data change plus its ripple edits — no `Core`, `Rendering` or App product code changes.

Invariants in play:

- **I1** — not implicated: hints are neither `ProbeItem` answers nor `WorkedExample` steps, so no CAS
  re-derivation applies to this task's content (`contracts/content-policy.md` § Generated content, quoted
  §3: CAS re-derivation binds `numeric` `ProbeItem.check` only).
- **I2** — every `none-of-these` string names no specific `error_types[]` member of its node; the fallback
  never borrows a sibling error type's hint (arbiter ruling Rule 1). Satisfied by construction: every string
  in §4's table is written generically ("look again at…", "recheck…", "redo…") and never repeats or
  paraphrases a sibling key's tier text.
- **I6** — every string is the project's own plain English, never Ministry prose; no `verbatim` key is
  touched or added.
- **I9** — zero human content-review step: the 60 strings are agent-authored in this spec and machine-verified
  by `core-cli validate`, `RenderCheck`, and the new `CoreTests` assertion (§4); a failing string is rewritten
  and re-validated, never "approved as-is".

Acceptance criteria (each independently verifiable):

- AC1: every one of the 20 nodes in `data/demo/nodes.json` has a `hint_tree["none-of-these"]` key whose value
  is an array of exactly 3 strings, each non-empty (schema `minLength: 1`, `minItems`/`maxItems` 3).
- AC2: on every node, the `none-of-these` tier-1 string is different (as a literal string) from the tier-1
  string of every other key in that node's `hint_tree` (the two-key case is `exponential-functions`, whose
  `hint_tree` carries `base-exponent-swapped` and `multiplied-instead-of-power`).
- AC3: `core-cli validate data/demo` (through the existing pipeline wrapper) reports `passed: true` with all
  ten L0 checks green, unaffected by this change (this task changes no id, edge, course or region data).
- AC4: `Packages/Rendering/Tests/RenderingTests/BundleRenderCheckTests.swift`'s
  `scansRealBundleClean` test (AC1 of that suite) stays green: `report.unresolvedCount == 0` over the
  updated `data/demo/nodes.json`, and `report.entries.count` increases by exactly 60 (20 nodes × 3 tiers).
- AC5: `Packages/Rendering/Tests/RenderingTests/OutcomeRecordAndImportBoundaryTests.swift`'s
  `outcomeRecordCountsMatchFreshScan` test stays green against the updated
  `docs/epics/epic-01-rendering-spike-outcome.md` table (hint row `123`, total `203`), recomputed from a
  fresh scan, not hand-typed into the test.
- AC6: a new `CoreTests` test asserts, for every node in `data/demo` (count > 0, an empty bundle is a test
  FAIL, not a vacuous pass): `hint_tree["none-of-these"]` has exactly 3 non-empty strings, and its tier-1
  string differs from every other key's tier-1 string on that node; a planted duplicate of a sibling's tier-1
  string fails this test (negative control, run once during authoring and reverted, per §5).
- AC7: `Packages/Core/Tests/CoreTests/DiagnosisMachineTests.swift`'s existing `hintKeyOnRealDataDemo` test
  (§3, T10/AC16 from task 02.11) stays green with no edit, and now resolves `DiagnosisRun.hintKey(originNode:
  errorTypeId: "none_of_these")` to `"none-of-these"` on every node instead of `nil` (the fallback path is
  now live on `data/demo`, per `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md` Rule 4).
- AC8: `App/Sources/DemoSnapshot/nodes.json` is byte-identical to `data/demo/nodes.json` after this task's
  edit; `Packages/Core/Tests/CoreTests/DemoSnapshotSeamTests.swift`'s byte-identity test (03.4 AC8) stays
  green.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `data/demo/nodes.json` — MODIFY. Add `"none-of-these": [tier1, tier2, tier3]` to the `hint_tree` object of
  each of the 20 nodes, using the exact strings in §4's table. No other key, node, edge, course or region
  data in this file changes.
- `App/Sources/DemoSnapshot/nodes.json` — MODIFY. Apply the byte-identical edit (regenerate via
  `scripts/embed-demo-snapshot.sh`, or hand-apply and diff against the script's output — the file must be
  byte-identical to `data/demo/nodes.json` when done, per AC8).
- `docs/epics/epic-01-rendering-spike-outcome.md` — MODIFY. Update the row `| \`hint_tree\` tier strings |
  63 | 0 |` to `| \`hint_tree\` tier strings | 123 | 0 |` and `| **Total** | **143** | **0** |` to
  `| **Total** | **203** | **0** |` (lines 18 and 20 in the current file). Recompute both numbers from a live
  run of `RenderCheckReport.scanning(nodesJSON:)` over the updated `data/demo/nodes.json`; do not merely type
  the arithmetic from this spec.
- `Packages/Rendering/Tests/RenderingTests/OutcomeRecordAndImportBoundaryTests.swift` — MODIFY exactly the
  fabricated-stale-table string literal at lines 96-105 (the `staleText` fixture inside
  `countStalenessGuardRedsOnFabricatedMismatch`): update its `hint_tree` row from `63` to `123` and its Total
  row from `143` to `203`, keeping `prompt_latex` at the deliberately-wrong `999` (§4 explains why this edit,
  though not load-bearing to that test's own assertions, is made for table consistency). No other line in
  this file changes; do not touch `outcomeRecordCountsMatchFreshScan` (it derives its expectation from a
  fresh scan, not from a hand-typed literal, and needs no edit — see AC5).
- `Packages/Rendering/Tests/RenderingTests/FieldKindPolicyMutationTests.swift` — MODIFY exactly the comment
  at line 180 (`/// \`hint_tree\` tier strings are 63/143 of the real scan and all parse clean — ...`):
  update `63/143` to `123/203`. This is a comment only; the test body below it (`mutationProofHintTree`,
  lines 182-189) uses a synthetic fixture, not the real bundle counts, and needs no other edit.
- `Packages/Core/Tests/CoreTests/DemoBundleNoneOfTheseHintsTests.swift` — CREATE. The companion test for
  AC1/AC2/AC6 (§4 step 4, §5).

Out-of-scope (do not touch even if tempted):

- `data/demo/manifest.json` — CONDITIONAL, do not touch unless the precondition check in §4 step 5 finds real
  (non-placeholder) hashes; verified all-zero placeholders on the current tree (`data/demo/manifest.json:24,
  29, 34, 39, 44, 49`) — per `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md` § Rule 4 cascade:
  "while they are placeholders, leave them."
- `Packages/Core/Tests/CoreTests/DiagnosisMachineTests.swift` — the `hintKeyOnRealDataDemo` test (AC7) derives
  its expectation from each node's own `hint_tree["none-of-these"]` data at test-run time; it needs no edit
  and must NOT be edited by this task (02.11's file; per the project's "no two tasks own the same file for
  writes" discipline, `docs/plans/epic-01-task-plan.md:22-23`, applied here by analogy).
- Any `Packages/Core/Sources/Core/**`, `Packages/Rendering/Sources/Rendering/**`, or `App/Sources/**` (other
  than the `DemoSnapshot/nodes.json` data copy) file — this is a data task; no product code changes.
- `contracts/**` — read-only ground truth; this task edits no contract or schema.
- `docs/domains/learning-objects.md`, `contracts/domain-glossary.md` — owned by task 04.1 (§0 precondition
  2); this task reads their post-04.1 state but writes neither file.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/schemas/nodes.schema.json` (byte-verified, lines 212-222), the `hint_tree` object definition:
  ```json
  "hint_tree": {
    "type": "object",
    "additionalProperties": {
      "type": "array",
      "items": {
        "type": "string",
        "minLength": 1
      },
      "minItems": 3,
      "maxItems": 3
    }
  }
  ```
  Binds this task: keys are open (`additionalProperties`); `"none-of-these"` is a legal key like any other,
  and its value must be exactly 3 non-empty strings.

- `contracts/data-model.md` heading `### Collections (one file each; see \`schemas/\`)`, the `nodes.json` row
  (byte-verified):
  > `hint_tree {error_type_id → [tier1, tier2, tier3]}`

- `contracts/data-model.md` heading `### Text` (byte-verified):
  > All student-facing strings are English (DEFERRED D-1). LaTeX appears only in fields named `latex` or
  > `prompt_latex` and must be in the SwiftMath-renderable subset or carry `render_fallback: "katex"`.
  > No field may hold Ministry prose (I6): the schemas have no free-text field on Expectation other than
  > `paraphrase`, and `content-policy.md`'s grep gate rejects a `verbatim` key anywhere.

  Binds this task: `hint_tree` is not `latex` or `prompt_latex`, so its strings are plain text — no LaTeX
  markup in any `none-of-these` tier, and no `render_fallback` key applies to `hint_tree` entries.

- `contracts/data-model.md` heading `### Identifiers` (byte-verified):
  > Ids are **stable, opaque, lowercase kebab-case slugs** matching `^[a-z0-9]+(-[a-z0-9]+)*$`, unique within
  > their collection. Never parse meaning from an id; never renumber. A renamed concept keeps its id.

  Binds this task: the key added is spelled `"none-of-these"` (kebab-case), matching the schema pattern.

- `contracts/content-policy.md` heading `## Voice` (byte-verified against the live file; note the bundle's
  copy of this rule used bold emphasis and an inline em-dash heading not present in the source — this spec
  quotes the file as it actually reads):
  > Teacher, not chatbot: one thing at a time, no persona, no filler, no scores or percentages on student
  > surfaces; a node is named, the student never is (diagnosis §7 stance).

  Binds this task: no tier string may show a score or percentage, address the student by name, or use a
  chatbot persona; every string speaks about the mathematics only.

- `contracts/content-policy.md` heading `## Generated content (all tiers)` (byte-verified), the sentence
  binding hint rendering:
  > Prompts and hints must render in SwiftMath or carry `render_fallback: "katex"` (learning-objects W1 5b).

  Binds this task: since every `none-of-these` string is plain text (no LaTeX), it renders trivially and
  needs no `render_fallback` flag — verified by AC4/`BundleRenderCheckTests`.

- `contracts/content-policy.md` heading `## Grade 9–12 tier (Ministry authority)` (byte-verified), the
  paraphrase-style sentence this task's hint voice follows without being a paraphrase itself:
  > Paraphrase rule (curriculum-spine Q1): one verb-initial plain sentence, no LaTeX, ≤ 140 characters,
  > rejected on a shared 6-gram with the source outside the technical-term allow-list.

  Binds this task: hints are not `paraphrase` fields and carry no 140-character schema limit, but follow the
  same plain-sentence, no-LaTeX discipline; every string in §4 is one short plain sentence.

- `contracts/domain-glossary.md`, the `Error type` line, **post-04.1 state** (quoted as
  `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md` § Rule 5 specifies it verbatim; NOT yet the
  text of the current, pre-04.1 file — see §0 precondition 2):
  > **Error type** (`ErrorType`) — a member of a node's closed catalogue, incl. the none-of-these member,
  > whose catalogue id is `none-of-these`; `classify` reports abstention as the outcome token
  > `none_of_these`, which is never a catalogue id or a `hint_tree` key.

  Binds this task: the `hint_tree` key is the kebab-case catalogue id `"none-of-these"`, never the outcome
  token spelling `none_of_these`.

Prior signatures / test shapes this task builds on (verbatim from direct file reads):

- `Packages/Core/Tests/CoreTests/DiagnosisMachineTests.swift:1033-1044` (`hintKeyOnRealDataDemo`, byte-verified
  by direct read):
  ```swift
  @Test("real data/demo: hintKey is derived from each node's own data, never a hand-kept list")
  func hintKeyOnRealDataDemo() throws {
      let bundle = try Self.loadDemoBundle()
      #expect(bundle.nodes.nodes.count > 0)
      for node in bundle.nodes.nodes {
          let expectedNoneOfThese =
              (node.hintTree["none-of-these"] ?? []).isEmpty ? nil : "none-of-these"
          #expect(DiagnosisRun.hintKey(originNode: node, errorTypeId: "none_of_these") == expectedNoneOfThese)
          #expect(DiagnosisRun.hintKey(originNode: node, errorTypeId: "none_of_these") != "none_of_these")
          for errorType in node.errorTypes where !(node.hintTree[errorType.id] ?? []).isEmpty {
              #expect(DiagnosisRun.hintKey(originNode: node, errorTypeId: errorType.id) == errorType.id)
          }
  ```
  This test needs no edit (out-of-scope, §2); it is quoted here so the implementer sees exactly how it will
  behave once `hint_tree["none-of-these"]` is non-empty on every node (AC7).

- `Packages/Rendering/Tests/RenderingTests/BundleRenderCheckTests.swift:31-40` (`scansRealBundleClean`,
  byte-verified by direct read):
  ```swift
  @Test("AC1: the real bundle scans clean across the broad field set")
  func scansRealBundleClean() throws {
      let data = try Data(contentsOf: Self.nodesJSONURL())
      let report = try RenderCheckReport.scanning(nodesJSON: data)

      #expect(report.entries.count > 0)
      #expect(report.entries.contains { $0.field == "prompt_latex" })
      #expect(report.entries.contains { $0.field.hasPrefix("choices[") })
      #expect(report.entries.contains { $0.field.hasPrefix("hint_tree[") })
      #expect(report.unresolvedCount == 0)
  ```
  This test needs no edit either; it is a positive-instance smoke over the live file (AC4).

## §4 Implementation outline

1. **Layer placement.** This task authors layer ③ (learning-objects) data embedded in `nodes.json`
   (`hint_tree`) — the same layer EPIC 01 task 05 authored the rest of `hint_tree` in. No layer ① spine, ②
   graph structure, or ④ interaction code is touched.

2. **Add the 60 strings to `data/demo/nodes.json`.** For each of the 20 nodes below, add
   `"none-of-these": [tier1, tier2, tier3]` to that node's existing `hint_tree` object (do not replace or
   reorder the node's existing key(s); add `none-of-these` alongside them). Use these exact strings —
   verified against the node's `name`, `paraphrase` and existing `hint_tree` entry in `data/demo/nodes.json`
   (`tasks/context/epic-04-task-01b-context.md` §H), so each nudges toward the node's own method without
   naming any of the node's `error_types[]` members:

   | Node id | tier 1 | tier 2 | tier 3 |
   |---|---|---|---|
   | `integer-operations` | Look again at how the signs combine in this expression. | Rewrite the expression one operation at a time before evaluating. | Redo the calculation step by step, checking the sign at each step. |
   | `order-of-operations` | Look again at which operation was evaluated first. | Work through the expression one operation at a time, in the correct order. | Redo the expression from the start, following the order of operations. |
   | `rational-numbers` | Look again at how the fractions were combined. | Rewrite each fraction and recheck every step of the combination. | Redo the calculation from the original fractions, checking each step. |
   | `exponent-laws` | Look again at which exponent rule applies here. | Identify whether the expression multiplies powers, raises a power to a power, or divides powers. | Redo the simplification, applying the matching exponent law one step at a time. |
   | `scientific-notation` | Look again at how the conversion between forms was done. | Recheck the direction and number of places the decimal point moved. | Redo the conversion from the original number, one place at a time. |
   | `linear-relations` | Look again at which part of the equation was read off. | Match each number in the equation to its role: slope or y-intercept. | Redo the identification directly from the equation's form. |
   | `solving-linear-equations` | Look again at how the variable was isolated. | Redo each step of isolating the variable, checking both sides stay balanced. | Solve the equation again from the start, one step at a time. |
   | `solving-systems-of-equations` | Look again at how the two equations were combined. | Recheck which variable was eliminated and how. | Redo the elimination or substitution from the original two equations. |
   | `simplifying-expressions` | Look again at which terms were combined. | Recheck that each pair of combined terms is actually alike. | Redo the simplification, grouping only truly like terms. |
   | `polynomials` | Look again at how the two polynomials were combined. | Recheck which terms from each polynomial were paired together. | Redo the addition or subtraction, matching terms by variable and exponent. |
   | `factoring` | Look again at the pair of numbers chosen for the factors. | Recheck that the pair of numbers multiplies and adds correctly. | Redo the factoring, testing pairs of numbers against both conditions. |
   | `solving-quadratics` | Look again at how the roots were found. | Recheck each root against the original equation. | Redo the solving process from the original equation, one step at a time. |
   | `rational-expressions` | Look again at how the expression was simplified. | Recheck the factoring before simplifying. | Redo the simplification, factoring fully before cancelling. |
   | `quadratic-functions` | Look again at how the vertex coordinates were read. | Recheck each coordinate against the equation's form. | Redo the identification of the vertex directly from the equation. |
   | `function-concept` | Look again at how the input was substituted. | Recheck that every occurrence of x was replaced with the given value. | Redo the substitution and evaluation from the original rule. |
   | `function-transformations` | Look again at how the transformation changes the graph. | Recheck the direction and size of the shift or reflection. | Redo the transformation, tracking each change to the graph one at a time. |
   | `function-notation` | Look again at how the function notation was read. | Recheck that the rule was applied to the correct input. | Redo the evaluation, reading the notation carefully from the start. |
   | `domain-and-range` | Look again at what restricts the domain here. | Recheck which values would make the expression undefined. | Redo the domain check, testing the expression for each kind of restriction. |
   | `exponential-functions` | Look again at how the power was evaluated. | Recheck how many times the base is multiplied by itself. | Redo the evaluation by writing out the repeated multiplication. |
   | `logarithms` | Look again at how the log was converted to exponential form. | Recheck what question the logarithm is asking. | Redo the conversion, writing the equivalent exponential equation first. |

   For `exponential-functions`, this node's `hint_tree` carries two existing keys
   (`base-exponent-swapped`: "Which number is being multiplied repeatedly?"; `multiplied-instead-of-power`:
   "Exponentiation is repeated multiplication of the base by itself, not base times exponent."). Its
   `none-of-these` tier 1 ("Look again at how the power was evaluated.") is verified distinct from both
   (AC2).

3. **Sync the embedded copy.** Run `scripts/embed-demo-snapshot.sh` (the regenerating script from EPIC 03
   task 03.4) to regenerate `App/Sources/DemoSnapshot/nodes.json` from the updated `data/demo/nodes.json`. If
   the script is not present or not operative when this task executes, that is a blocking dependency gap on
   EPIC 03 task 03.4 — report it; do not hand-copy the file in a way that could drift, and do not skip AC8.

4. **Write the companion test**, `Packages/Core/Tests/CoreTests/DemoBundleNoneOfTheseHintsTests.swift`. Load
   `data/demo` the same way `DiagnosisMachineTests.swift`'s `loadDemoBundle()` does (walk up from
   `#filePath` to the repo root, then down to `data/demo`; re-derive this helper in the new file rather than
   sharing private state across files). Assert, over every node in the bundle (`bundle.nodes.nodes.count > 0`
   is itself an assertion — an empty bundle must FAIL this test, not vacuously pass):
   - `node.hintTree["none-of-these"]` is non-nil, has exactly 3 elements, and every element is non-empty
     (AC1);
   - `node.hintTree["none-of-these"]![0]` differs from `node.hintTree[key]![0]` for every other key in
     `node.hintTree` (AC2) — derive the set of "every other key" from `node.hintTree.keys` itself (excluding
     `"none-of-these"`), never a hand-maintained literal list of error-type ids, so a future node with a
     third `hint_tree` key is still checked correctly.
   - As the negative control (AC6), during authoring temporarily plant one node's `none-of-these` tier-1 as
     an exact copy of that node's other key's tier-1, confirm this test reds, then revert before committing
     — record the red/green pair in the PR description; do not ship the planted duplicate.

5. **Manifest hash check (conditional).** Read `data/demo/manifest.json`'s six `files[].sha256` values. If
   all six are still the all-zero placeholder (`"00000000000000000000000000000000000000000000000000000000000000"`,
   64 hex chars) — the confirmed state on the tree this spec was written against
   (`data/demo/manifest.json:24,29,34,39,44,49`) — leave the manifest untouched (per the arbiter ruling's
   Rule 4 cascade: "while they are placeholders, leave them"). If any hash is no longer a placeholder (a
   later-landed task has started stamping real hashes), run the pipeline's restamp helper
   (`pipeline/src/mathmath_pipeline/bundle.py`) to recompute the `nodes.json` entry's hash, and no other
   entry.

6. Smoke check: `pytest pipeline/tests/test_contracts.py -k data_bundles` — must be green (schema validation
   over `data/demo/nodes.json` including the new `hint_tree` entries) before proceeding to the full gate.

## §5 Test plan (seam risk — full plan)

- T1 happy path: `swift test --filter DemoBundleNoneOfTheseHintsTests` is green — every node's
  `hint_tree["none-of-these"]` has 3 non-empty tiers, tier 1 distinct from every sibling key's tier 1 (AC1,
  AC2, AC6).
- T2 negative — invalid input rejected at the boundary: `pytest pipeline/tests/test_contracts.py::test_data_bundles_validate`
  fails loudly if any `none-of-these` array does not have exactly 3 non-empty strings (schema `minItems`/
  `maxItems`/`minLength`); this task's Done gate requires that test green, so a malformed entry surfaces
  before merge.
- T3 error-taxonomy: not applicable — this task raises no error code (hints are not probe answers or step
  verifications, I1); no CAS check applies. `core-cli validate data/demo` continues to report `passed: true`
  on all ten L0 checks (AC3), unaffected since no id/edge/course/region data changes.
- T4 conformance per requirements §B.1: `BundleRenderCheckTests.scansRealBundleClean` (AC4) confirms every
  new `hint_tree[N]` field entry is scanned and resolves (plain text has no LaTeX to fail parsing); I2 is
  satisfied by construction (§4 step 2's table review) and further guarded by T5 below; I6 is satisfied since
  no string is Ministry prose and no `verbatim` key is touched.
- T5 negative control for every regression guard: (a) AC6's guard — plant a sibling-tier-1 duplicate, confirm
  `DemoBundleNoneOfTheseHintsTests` reds, then revert (§4 step 4); (b) AC5's guard —
  `countStalenessGuardRedsOnFabricatedMismatch` in `OutcomeRecordAndImportBoundaryTests.swift` already proves
  the staleness comparison is load-bearing (its own `999`-mismatch fixture), unaffected by this task's
  63→123/143→203 literal-consistency edit to the surrounding rows in that same fixture.
- T6 idempotency / no-leak: re-running `scripts/embed-demo-snapshot.sh` after this task's edit is
  idempotent — a second run produces no further diff in `App/Sources/DemoSnapshot/nodes.json` (03.4's
  determinism guarantee, exercised here as a regression check over this specific edit).

## §6 Decision defaults

- IF the implementer is unsure whether a tier string should use "you"/second person THEN omit it — match the
  existing `hint_tree` entries' impersonal style (e.g. "Subtracting a negative is the same as adding its
  opposite.") and the Voice rule's "a node is named, the student never is": every string in §4's table speaks
  about the expression, equation or method, never "you". (`contracts/content-policy.md` heading `## Voice`,
  quoted §3.)
- IF a future node is added to `data/demo/nodes.json` with more than two `hint_tree` keys THEN the companion
  test's derived-allowlist check (§4 step 4) still holds — it compares against `node.hintTree.keys` itself,
  not a count fixed at 20 or 2.
- IF `App/Sources/DemoSnapshot/` is still absent when this task executes (EPIC 03 03.4 not actually landed
  despite the branch's stated precondition) THEN stop and report the dependency gap; do not create the
  directory by hand outside the 03.4-defined shape, since this task owns none of that seam's scaffolding.
- IF the manifest hashes are no longer all-zero placeholders at execution time THEN run the pipeline restamp
  helper for the `nodes.json` entry only (§4 step 5); the schema-validation smoke check (§4 step 6) catches a
  malformed hash if the helper is misapplied.
- IF `RenderCheckReport.scanning` counts `hint_tree` entries per-string (not per-array) THEN the +60 delta in
  AC4/AC5 is exactly 20 nodes × 3 new strings = 60, matching the existing 63→123 and 143→203 arithmetic —
  verified by the field-kind breakdown already using `hint_tree[N]` per-entry field names
  (`OutcomeRecordAndImportBoundaryTests.swift:66`, `$0.field.hasPrefix("hint_tree[")`), confirming one scan
  entry per tier string, not per node or per key.

Standing defaults: identifiers are stable, opaque, lowercase kebab-case slugs (`contracts/data-model.md` §
Identifiers, quoted §3) — the key added is `"none-of-these"`, never `none_of_these`; no field anywhere
becomes identifying (I5 — this task adds no new key shape, only string values inside an existing open-keyed
object); nodes continue to carry `paraphrase`, never verbatim Ministry text (I6, untouched by this task);
telemetry is not touched by this task (no telemetry field exists in `nodes.schema.json`).

## §7 Done definition

The task is done when ALL gates pass:

- format + lint clean (`swift-format lint --strict` over the new `Packages/Core/Tests/CoreTests` file and the
  two modified `Packages/Rendering/Tests/RenderingTests` files; `ruff check` / `ruff format --check` — no
  Python file is touched by this task's in-scope list, so this gate is a no-op confirmation)
- typecheck clean (Swift's typecheck is the build; no `pipeline/` file is touched)
- `Core` build + test green (`swift build`; `xcodebuild test -scheme Core-Package` on the simulator),
  including the new `DemoBundleNoneOfTheseHintsTests` (T1) and the untouched `hintKeyOnRealDataDemo` (AC7)
- App build green (`xcodebuild build -scheme mathmath` on the simulator) — this task touches
  `App/Sources/DemoSnapshot/nodes.json`, a plain resource file picked up by the synchronized group; no
  Swift source changes, so the build is unaffected beyond re-embedding the resource
- `pytest pipeline/tests/test_contracts.py` green (T2), and `core-cli validate data/demo` reports `passed:
  true` on all ten L0 checks (AC3)
- `Packages/Rendering` tests green: `BundleRenderCheckTests.scansRealBundleClean` (AC4),
  `OutcomeRecordAndImportBoundaryTests.outcomeRecordCountsMatchFreshScan` and
  `.countStalenessGuardRedsOnFabricatedMismatch` (AC5, T5b), `FieldKindPolicyMutationTests.mutationProofHintTree`
  (comment-only edit, unaffected assertion)
- `Packages/Core/Tests/CoreTests/DemoSnapshotSeamTests.swift`'s byte-identity test green (AC8)
- tests green for every case in §5
- conforms to every contract section cited in §3 and §4, and to every invariant listed in §1
