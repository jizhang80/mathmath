# ARBITER RULING: 04.1b generic (none-of-these) hints vs I2

**Date**: 2026-09-11
**Trigger**: Q4. The committed 04.1b data (`1474a74`) and its spec, `tasks/epic-04-task-01b-data-demo-none-of-these-hints.md`, contradict the governing ruling `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md`, § Rule 4 content constraints. That rule reads: "No string names or describes a sibling `error_types[]` member's misconception (I2)."
**Scope of authority**: `tasks/*` only. This file and `arbiter-04-01b-replacement-hints.json` are new. No spec, data, code, doc or contract is edited here; the orchestrator applies the spec edits in § Required spec edits.
**Route**: no escalation and no Q5. No D-number changes. I2 and the governing ruling's constraint are applied as written, and the fix stays inside 04.1b's existing §2 file scope.

## Facts verified in this run

- **The committed strings are the spec's §4 table, verbatim.** I compared all 60 strings in `data/demo/nodes.json` (Grep `-o` over `"hint_tree":{…}`) against the spec's §4 step 2 table: all 20 × 3 match. I read the working tree on branch `epic-04a-door-core`, not the commit object. The implementer's "no deviations" report is accurate. The defect is in the spec's table, not in the implementation.
- **The I2 claim sits at spec §1, "Invariants in play", I2 bullet (spec lines 48–51), not lines 14–16.** It reads: "Satisfied by construction: every string in §4's table is written generically ('look again at…', 'recheck…', 'redo…') and never repeats or paraphrases a sibling key's tier text." AC2 (line 62) checks tier-1 literal inequality only.
- **Siblings per node**: each node has exactly one non-`none-of-these` `error_types[]` member, except `exponential-functions`, which has two. Every sibling has a `hint_tree` entry (Grep over `"error_types":[…]`; see the table below).
- **`Node` fields**: `name`, `paraphrase`, `errorTypes[].id` and `.label`, and `hintTree` (`Packages/Core/Sources/Core/Model/Nodes.swift:9-25, 48-52`).
- **`RenderCheck.canRender`** runs SwiftMath's `MTMathListBuilder.build(fromString:)` over the raw tier string (`Packages/Rendering/Sources/Rendering/Rendering.swift:9-18`). The scan emits one entry per tier (`RenderCheckReport.swift:106-121`). Committed plain-text tiers containing `,` `.` `:` `?` `'` `-` scan clean, since the outcome shows 0 unresolved (`docs/epics/epic-01-rendering-spike-outcome.md:18,20`: hint row `123`, total `203`).
- **The tester's suite** is `Packages/Core/Tests/CoreTests/DemoBundleNoneOfTheseHintsConformanceTests.swift`. It checks: sibling tier text quoted at ≥ 12 chars (:50-71), sibling `label` containment (:73-90), banned words `attempt fail level quiz session quest` (:160), no `\ $ { }` (:190), and manifest placeholders (:206-220). None of these catches the I2 defect: the committed strings contain no sibling label or tier verbatim.
- **Glossary** (`contracts/domain-glossary.md`): the item entry bans "question" (:30), and the retry entry bans "fail" for an item (:34). The diagnosis-event entry bans "attempt" (:40), and the telemetry entry bans "tracking" (:61). The committed `logarithms` t2 uses "question", and `function-transformations` t3 uses "tracking". Both strings are replaced below.

## The rule (what an agent applies when authoring a generic hint)

The generic hint is shown exactly when `classify` abstains. The system therefore has **no evidence** about which mistake was made, and I2 says it must not guess one. The hard case is a node whose only catalogued misconception is the concept's central pitfall. There the line is drawn at **selection**:

- **R1 (concept by name).** A tier may name the node's concept using the words of the node's `name`. The flow already names the node (`content-policy.md` § Voice: "a node is named"), so repeating the name adds no diagnostic information.
- **R2 (generic moves only).** A tier prescribes a verification move that is equally useful whatever went wrong:
  - reread what is asked;
  - redo from the start, one step at a time;
  - check each step against the node's definition or its rules, named by the node's name;
  - try a simpler case;
  - check the answer by substitution, a back-conversion or expansion, or by estimation.
- **R3 (no selection of the failure locus).** A tier must not single out the component, operation, direction or quantity that a sibling's `id`, `label` or hint tiers identify as the place the error happens. Examples: the sign, which operation went first, the decimal-point places or direction, slope versus intercept, which terms were combined, cancelling, replacing every x, the shift direction, repeated multiplication, and the log-to-exponential conversion. The test: *if this tier were served after the sibling's misconception was confirmed, would it work as that misconception's targeted hint?* If yes, it diagnoses.
- **Why the `paraphrase` is not a free allowlist.** Governing ruling Rule 3 shows the paraphrase whole as the non-diagnosing fallback, and a whole paraphrase points at nothing. Paraphrases spell out method components, for example "by factoring and cancelling common factors", "the slope and y-intercept" and "by isolating the variable". A tier that picks one of those components and says "recheck it" asserts that the error is there. That is R3's selection.
- **R4 (no pointing qualifiers).** A tier must not use an evaluative qualifier that implies which way the work went wrong. Examples: "the correct order", "factoring fully", "only truly like terms", "actually alike".

R1, R2 and R4 and the token core of R3 are machine-checked (next section). The residue of R3 that tokens cannot see is authoring discipline for whoever writes generic hints. For this task that residue is discharged by this ruling's pre-checked replacement strings. I9 holds because no human review step is added: the check is a machine gate, and a failing string is rewritten, never approved.

## The mechanical check (binding; AC9)

A pure function in `Packages/Core/Tests/CoreTests/DemoBundleNoneOfTheseHintsTests.swift`. It uses Foundation and Testing only, with no new dependency.

```swift
static func i2Violations(
    name: String,
    siblings: [(id: String, label: String, tiers: [String])],
    noneTiers: [String]
) -> [String]
```

**Inputs**, per node:
- `name` = `node.name`;
- `siblings` = every `node.errorTypes` member whose `id != "none-of-these"`, with its `id`, its `label` and `node.hintTree[id] ?? []`;
- `noneTiers` = `node.hintTree["none-of-these"]`.

**Tokenization**, `tokens(_ s: String) -> [String]`:
1. Lowercase `s`.
2. Split on every character that is not ASCII `a`–`z`. Digits, `-`, `_`, `^`, `'` and whitespace are all separators, so `sign-error` becomes `sign`, `error`; `y-intercept` becomes `y`, `intercept`; and `log_b` becomes `log`, `b`.
3. Drop tokens shorter than 4 characters.
4. Drop tokens in the closed **stoplist**. The stoplist holds function words and generic nudge words only. It never contains a mathematical word, and adding to it is a spec change, not an implementer choice. Its members are:
   `again, also, been, being, does, each, from, have, into, look, that, their, them, then, there, these, they, this, those, were, what, when, where, which, while, will, with, would`.
5. **Stem**: `stem(t) = String(t.prefix(4))`.

**Derived sets**:
- `U` (sibling tokens) = `tokens` of every sibling's `id`, `label` and each `tiers` element, kept **unstemmed**.
- `A` (the per-node concept allowlist) = `{ stem(t) | t ∈ tokens(name) }`.
  - The allowlist is derived and never hand-kept. Its justification is R1: the node `name` is already on screen.
  - Examples: `order-of-operations` gives `{orde, oper}`; `logarithms` gives `{loga}`; `quadratic-functions` gives `{quad, func, vert, form}`.

**Rules**, over each `noneTiers[i]` and each token `t` of it:
- **S1 (sibling content).** A violation `"\(i):\(t)"` if `stem(t) ∉ A` and some `u ∈ U` satisfies `u.contains(stem(t))`.
  - Substring containment, not equality, is deliberate. It catches `read` against `misread` and `combine` against `combined`.
  - It is over-inclusive by design. A false positive costs a rewrite, the I9 posture.
- **S2 (pointing qualifiers).** A violation `"\(i):\(t)"` if `t` is in the closed **qualifier list**:
  `correct, correctly, incorrect, incorrectly, wrong, wrongly, right, mistake, mistakes, error, errors, fully, truly, actually, properly, only`.
  - S2 is checked on the raw lowercase letter-run tokens before the stoplist and length filters. Every listed word is at least 4 letters.
- **Result**: all S1 and S2 violations, in tier order, then token order. Duplicates are kept.

**Real-bundle assertion (empty = FAIL).**
- `bundle.nodes.nodes.count > 0`.
- For every node:
  - `U` is non-empty (every `data/demo` node has at least one sibling);
  - `A` is non-empty;
  - `i2Violations(…) == []`.

**Committed controls.** These are in-memory fixtures built from literal strings, with no file edit and nothing to revert. Each asserts its **exact** result.

| # | Fixture (siblings = that node's real sibling id, label and tiers, copied as literals) | Expected | Proves |
|---|---|---|---|
| NC1 | `integer-operations`, with the 04.1b committed tiers `["Look again at how the signs combine in this expression.", "Rewrite the expression one operation at a time before evaluating.", "Redo the calculation step by step, checking the sign at each step."]` | `["0:signs", "2:sign"]` | S1 reds on sibling content |
| NC2 | `function-notation`, with `["Look again at how the function notation was read.", <replacement t2>, <replacement t3>]` | `["0:read"]` | substring containment (`read` ⊂ `misread`) |
| NC3 | `order-of-operations`, with `["Reread the expression and list the operations it contains.", "Work through the expression one operation at a time, in the correct order.", "Redo the expression from the start, following the order of operations."]` | `["1:correct"]` | S2 reds; the `name` allowlist admits `order`/`operations` |
| NC3b | NC3 with `name: ""` | contains `"2:order"` | the allowlist is load-bearing, not blanket-green |
| NC4 | `exponent-laws`, with `["Look again at which exponent rule applies here.", …replacement t2, t3]` | `[]` | the stoplist admits the generic `look`, which the sibling's tier 1 also uses |

**Instrument**: `xcodebuild test -scheme Core-Package` on the simulator.
- **What it excludes**: the semantic residue of R3 that tokens cannot see, and any language-model judgment (I1 and I2: no model decides).
- **Stack**: Swift Testing + Foundation only, per `docs/tech-stack.md`; no new tool.

## Per-node verdicts

Columns:
- **Sibling**: the id, then "label".
- **Committed tier result**: S1/S2 hits under the check above, plus R3 where tokens alone miss it.

For the sibling hint tiers, see `data/demo/nodes.json` `hint_tree` (Grep `-o`, this run).

| Node | Sibling | Committed tier result | Verdict |
|---|---|---|---|
| integer-operations | `sign-error`, "Dropped or mishandled a negative sign" | t1 `signs`, t3 `sign` (S1); t2 passes | **violates** |
| order-of-operations | `wrong-order`, "Evaluated operations left to right, ignoring precedence" | t1 `evaluated`, `first` (S1); t2 `correct` (S2); t3 passes (the name allowlist) | **violates**; t3 kept |
| rational-numbers | `common-denominator-error`, "Combined fractions without a common denominator" | t1 `fractions`, `combined`; t2 `rewrite`, `fraction`, `combination`; t3 `fractions` (S1). "How were combined" selects the common-denominator step (R3) | **borderline → violating** |
| exponent-laws | `added-exponents-on-power`, "Added the exponents instead of multiplying…" | t2 `multiplies`, `powers`, `raises`, `power` (S1): it lists the sibling's exact case; t1 and t3 pass | **borderline → violating**; t1 and t3 kept |
| scientific-notation | `decimal-point-error`, "Moved the decimal point the wrong number of places or the wrong direction" | t2 `direction`, `number`, `places`, `decimal`, `point`, `moved`; t3 `number`, `place` (S1); t1 passes | **violates**; t1 kept |
| linear-relations | `slope-intercept-swap`, "Swapped the slope and the y-intercept" | t2 `number`, `slope`, `intercept` (S1). t1 "which part … was read off" selects slope versus intercept (R3) | **violates** |
| solving-linear-equations | `sign-flip-error`, "Mishandled a sign when isolating the variable" | t1 `variable`, `isolated`; t2 `isolating`, `variable`, `both`, `sides` (S1); t3 passes | **borderline → violating**; t3 kept |
| solving-systems-of-equations | `substitution-error`, "Substituted or eliminated incorrectly, mixing up the two equations" | t2 `variable`, `eliminated`; t3 `elimination`, `substitution` (S1). t1 "how … were combined" selects the mixing step (R3) | **borderline → violating** |
| simplifying-expressions | `unlike-terms-combined`, "Combined terms that are not alike…" | t1 `terms`, `combined`; t2 `combined`, `terms`, `alike` (S1) and `actually` (S2); t3 `only`, `truly` (S2) and `like`, `terms` (S1) | **violates** |
| polynomials | `like-terms-miscombined`, "Combined the wrong pair of like terms…" | t1 `combined`; t2 `terms`, `paired`; t3 `terms`, `variable`, `exponent` (S1) | **violates** |
| factoring | `sign-error-in-factors`, "Chose factor signs that do not multiply to the constant term" | t1 `numbers`, `chosen`; t2 `numbers`, `multiplies`; t3 `numbers` (S1) | **borderline → violating** |
| solving-quadratics | `quadratic-formula-sign-error`, "Dropped a sign when reporting a root" | t1 `roots`, t2 `root` (S1: the label says "root"); t3 passes. Semantically clean under R3, but it fails the binding check, and the fix is a one-word swap to "solution" | **borderline → violating (mechanical)**; t3 kept |
| rational-expressions | `cancelled-terms-not-factors`, "Cancelled individual terms instead of common factors" | t2 `factoring`; t3 `factoring`, `cancelling` (S1) and `fully` (S2); t1 passes | **violates**; t1 kept |
| quadratic-functions | `vertex-sign-error`, "Read the vertex coordinate with the wrong sign" | t1 `coordinates`, `read`; t2 `coordinate` (S1); t3 passes | **violates**; t3 kept |
| function-concept | `function-evaluation-error`, "Substituted the input incorrectly when evaluating the function" | t1 `input`, `substituted`; t2 `every`, `replaced`, `given`, `value`; t3 `substitution`, `rule` (S1) | **violates** |
| function-transformations | `shift-direction-error`, "Reported the transformation shift in the wrong direction" | t1 `graph`; t2 `direction`, `shift`; t3 `graph` (S1); t3 also uses the banned "tracking" | **violates** |
| function-notation | `notation-misread`, "Misread the function rule when substituting the input" | t1 `read` ⊂ `misread`; t2 `rule`, `applied`, `input` (S1) and `correct` (S2); t3 `reading` (S1) | **violates** |
| domain-and-range | `domain-range-swap`, "Missed a restriction that shifts the domain boundary" | t1 `restricts`, t3 `restriction` (S1). t2 "which values would make the expression undefined" is the definition of domain: it passes and is R2 | **borderline → violating**; t2 kept |
| exponential-functions | `base-exponent-swapped`, "Treated the base as the exponent"; and `multiplied-instead-of-power`, "Multiplied the base by the exponent instead of raising it to a power" | t1 `power`; t2 `times`, `base`, `multiplied`, `itself`; t3 `repeated`, `multiplication` (S1). t2 and t3 restate the second sibling's hint | **violates** |
| logarithms | `log-exponent-confusion`, "Combined the base and argument instead of finding the exponent" | t1 `exponential`, t3 `exponential` (S1). t2 "what question the logarithm is asking" paraphrases the sibling's tier 1 ("log_b(a) asks: …", R3) and uses the banned "question" | **violates** |

**Counts: 13 violating, 7 borderline → violating, 0 clean.** All 20 `none-of-these` arrays change. Nine committed tiers survive unchanged at their index, as marked above. The replacements are in `tasks/arbitration/arbiter-04-01b-replacement-hints.json`.

**The replacements, pre-checked by hand under S1 and S2** against each node's `U` and `A`, token by token: 0 violations on all 60. The implementer's AC9 test is the binding re-verification. The replacements also meet the following:
- **AC2**: every tier 1 differs from every sibling's tier 1.
- **The tester's suite**: no sibling tier of ≥ 12 chars is quoted, no sibling label appears, and no word from `attempt fail level quiz session quest` is used.
- **Glossary**: no "question" or "tracking".
- **Plain text**: only letters, spaces, `,`, `.` and `-`, with no `\ $ { } ^ _ & % #`. These are characters already present in committed tiers that scan clean.
- **Voice**: no "you", no score, no persona.
- **I6**: the project's own prose.

## Required spec edits (orchestrator applies to `tasks/epic-04-task-01b-data-demo-none-of-these-hints.md`)

**E1: §1 "Invariants in play", I2 bullet.** Replace the whole bullet with:

> - **I2** — every `none-of-these` string names no specific `error_types[]` member of its node and describes no sibling member's misconception; the fallback never borrows a sibling error type's hint (`tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md` Rule 1 and Rule 4: "No string names or describes a sibling `error_types[]` member's misconception (I2)."). This is not satisfied by construction: it is machine-verified by the I2 token check of `tasks/arbitration/arbiter-04-01b-generic-hint-i2.md` § The mechanical check (AC9), which has committed negative controls. §4's table is that ruling's replacement set.

**E2: AC2 stays unchanged.** Literal tier-1 distinctness is the governing ruling's own instrument. It is kept, but it is not the I2 guard. **Add, after AC8:**

> - AC9: `Packages/Core/Tests/CoreTests/DemoBundleNoneOfTheseHintsTests.swift` implements `i2Violations(name:siblings:noneTiers:)` exactly as specified in `tasks/arbitration/arbiter-04-01b-generic-hint-i2.md` § The mechanical check (tokenization, stoplist, 4-character prefix stem, `name`-derived allowlist, S1 substring rule, S2 qualifier list — all copied as literals). It asserts `i2Violations(…) == []` for every node in `data/demo` (node count > 0, and every node's sibling-token set and allowlist non-empty; empty = FAIL). It also asserts the exact results of the committed controls NC1, NC2, NC3, NC3b and NC4 of that section. Instrument: `xcodebuild test -scheme Core-Package` on the simulator. It excludes the semantic residue of that ruling's R3, which is discharged by the ruling's pre-checked strings.

**E3: §2.** In the `DemoBundleNoneOfTheseHintsTests.swift` line:
- change "CREATE" to "MODIFY (created by this task's first pass)";
- change "AC1/AC2/AC6" to "AC1/AC2/AC6/AC9".

No other §2 change.

**E4: §4 step 2.**
- In the lead-in, replace "so each nudges toward the node's own method without naming any of the node's `error_types[]` members" with "so each is a non-diagnosing nudge (reread, check against the node's definition, a simpler case, substitution, estimation) that passes the AC9 I2 token check (`tasks/arbitration/arbiter-04-01b-generic-hint-i2.md`)".
- Replace the 20-row table with the 20 arrays of `tasks/arbitration/arbiter-04-01b-replacement-hints.json`, verbatim.
- In the `exponential-functions` paragraph, replace `Its \`none-of-these\` tier 1 ("Look again at how the power was evaluated.")` with `Its \`none-of-these\` tier 1 ("Reread the exponential function and the value it is evaluated at.")`.

**E5: §4 step 4.** Add a bullet:

> - The I2 token check (AC9): add `i2Violations` and its real-bundle assertion and committed controls NC1–NC4 (incl. NC3b) as specified in the arbiter ruling § The mechanical check. The controls are in-memory literal fixtures, committed, never planted-and-reverted. If a §4 string fails the check, report it as a BLOCK; do not edit the stoplist, the qualifier list or the allowlist rule.

**E6: §5.**
- **T1**: append "and the AC9 I2 token check (zero violations on all 20 nodes)".
- **T4**: replace "I2 is satisfied by construction (§4 step 2's table review) and further guarded by T5 below" with "I2 is machine-verified by the AC9 token check".
- **T5**: add "(c) AC9's guard — NC1/NC2/NC3 red with their exact expected violations, NC3b proves the allowlist is load-bearing, NC4 proves the stoplist admits generic nudge words (all committed)".

**E7: §6.** Add the decision default:

> - IF a hint needs a concept word that the AC9 check flags THEN rewrite it using a word from the node's `name` or a generic move (reread, redo, substitution, estimation, simpler case); never widen the stoplist, qualifier list or allowlist in this task (per `tasks/arbitration/arbiter-04-01b-generic-hint-i2.md` § The mechanical check).

AC1, AC3–AC8, §3, §7 and the risk tier (`seam`) are unchanged.

## How the fix lands

**A single retry of task 04.1b per `/run-task`**: implementer rework, then tester. This is not a new task. The file scope is identical to 04.1b's §2, and no other task owns these files.

1. **Implementer** (after the orchestrator applies E1–E7):
   - replaces the 20 `none-of-these` arrays in `data/demo/nodes.json` with the JSON's arrays;
   - re-embeds with `scripts/embed-demo-snapshot.sh`, so that `App/Sources/DemoSnapshot/nodes.json` is byte-identical (AC8; T6 idempotency);
   - extends `DemoBundleNoneOfTheseHintsTests.swift` with AC9;
   - runs the full gate.
2. **Ripple**:
   - **Rendering count: unchanged.** Every node still has 3 tiers, so the hint row stays `123` and the total stays `203` (`docs/epics/epic-01-rendering-spike-outcome.md:18,20`, confirmed this run). The implementer still confirms these by a fresh scan, as AC5 requires. The `staleText` literal in `OutcomeRecordAndImportBoundaryTests.swift` and the comment at `FieldKindPolicyMutationTests.swift:180` need no edit.
   - **Manifest**: the hashes are still placeholders, so it is left untouched; the tester's `manifestHashesRemainPlaceholders` stays green.
3. **Tester**:
   - **Suite: no required change.** Its five checks stay green on the replacement strings (verified above: no quoted sibling tier, no sibling label, no banned word, no LaTeX characters). Its in-memory distinctness control plants `base-exponent-swapped`'s tier 1 and still reds as expected.
   - **Verification**: the tester re-runs its suite and verifies AC9's controls produce their exact expected lists.
   - **Optional**: the tester may add an independent re-implementation of `i2Violations` as a second instrument; this is not required.
4. **The smoke test**: `DemoBundleNoneOfTheseHintsTests.swift` must change (AC9 is added). Its existing AC1/AC2 assertions stay as they are.

## Q5 check

No locked decision is touched. I2 (D7), I9 (D10, D12, D13), D26 (hand-written Demo data) and the governing ruling's Rule 4 are applied as written. The contracts are unchanged. No escalation.
