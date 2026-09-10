# ARBITER ESCALATION: task 01.07

**Date**: 2026-09-09
**Spec**: tasks/epic-01-task-07-pipeline-content-verification.md
**Route**: Q5-owner (findings B and C) — finding A resolved in-spec, no escalation
**Trigger**: task-reviewer BLOCK (Q4)

## Triggering report (verbatim)

=== FINDING A — mechanical, fix it directly. ===
The spec wires `ResolutionFailure` to `MAP_LANDMARK_UNSOURCED` throughout §4 step 4, AC5, AC6 and T3. That is the wrong code: `docs/domains/map.md:127` registers `MAP_LANDMARK_UNSOURCED` as `Core`'s structural L0-10 **presence** check, while `docs/domains/learning-objects.md:130` registers `LO_LANDMARK_UNSOURCED` as "`source_url` missing or **not resolving**… landmark dropped (I15)" — the pipeline's live-HTTP resolution check, which is exactly this task's job (`docs/tech-stack.md:67`). `contracts/error-codes.md` says a code appears in exactly one domain doc. The spec's own §3 quotes both correctly and then uses the wrong one. Replace it throughout; keep `MAP_LANDMARK_UNSOURCED` only where citing `Core`'s separate L0-10 check, which this task does not implement.

=== FINDING B — the substantive one. Do NOT force a fix. ===
The brief's §3 MANDATORY invariant line requires SymPy to "re-derive every numeric answer… (a test lists the items it could not express, **empty = FAIL for this bundle since all are simple**)".

I measured the landed `data/demo/nodes.json` (task 01.5, commit `7f7000d`) myself. Facts, not estimates:
- **20 numeric probe items.** Zero `$` characters anywhere in the file — the spec's `extract_math_span` regex `\$(.+?)\$` matches nothing, so as written every item is unexpressible and the mandatory "empty list" criterion fails by construction.
- LaTeX commands actually used across all prompts and choices: `\times`(5), `\frac`(7), `\text`(20), `\cdot`(2), `\Rightarrow`(12), `\sqrt`(1), `\geq`(1), `\log`(2). **34 prompts end in the literal `= ?`.**
- **The brief's premise "all are simple" does not hold.** Several items are semantic, not arithmetic. Example, verbatim: `y = 3x + 5 \Rightarrow \text{slope} = ?` with answer `3`. Deriving that requires knowing what "slope" means — no arithmetic CAS translator can do it. Others: `(2^3)^2 = 2^{\,?}` (answer `6`) asks for an exponent in a hole, not an evaluation.

So the requirement, the authored data and the available schema do not line up.

Candidate directions, to weigh not to adopt:
(a) Broaden the translator to cover the real token set AND the semantic prompts. Assess honestly whether that is a CAS check at all, or a bespoke question-understander — I1 says correctness is decided by CAS, never by a model, and a parser that mis-reads a prompt and then "confirms" a wrong answer is worse than no check.
(b) Re-author the demo's numeric prompts so each is genuinely CAS-expressible. That changes `data/demo/nodes.json`, task 01.5's landed output — outside your write authority, and it may conflict with the pedagogical point of those items.
(c) Give ProbeItem an optional machine-checkable expression field. That is a **contract/schema change** — `contracts/` is READ-ONLY and this would be a Q5 owner decision.
(d) Scope the check to the items that are genuinely CAS-expressible and record the rest explicitly, which contradicts the brief's "empty = FAIL" line as written and therefore needs the brief amended.
(e) Something better you find in the evidence.

=== ALSO CLOSE ===
The reviewer judged the `landmarks.json` file-scope exclusion coherent (a resolution failure blocks the gate rather than silently dropping a landmark, and the edit belongs to whoever owns that file). Confirm and make sure the spec states the failure behaviour unambiguously.

## Findings analysis

| # | Claim | Verification (path:line / contract quote) | Classification |
|---|-------|-------------------------------------------|----------------|
| A1 | `MAP_LANDMARK_UNSOURCED` is a presence check, not a resolution check | `docs/domains/map.md:127` — "\| `MAP_LANDMARK_UNSOURCED` \| A landmark lacks `source_url` \| Internal; bundle refused (I15) \| Yes — pipeline \|" | VALID |
| A2 | `LO_LANDMARK_UNSOURCED` is the resolution code and is this task's | `docs/domains/learning-objects.md:130` — "\| `LO_LANDMARK_UNSOURCED` \| `source_url` missing or not resolving; no node ids \| Internal; landmark dropped (I15) \| Yes — re-source, never invent \|"; `docs/domains/learning-objects.md` W1 5c names it for "resolving at build (HTTP 2xx)" | VALID |
| A3 | One code, one domain doc | `contracts/error-codes.md` "## Rules": "A code appears in exactly one domain doc and in the registry." | VALID |
| A4 | `LO_LANDMARK_UNSOURCED` is registered | `contracts/error-codes.json:33` — `{"code": "LO_LANDMARK_UNSOURCED", "recoverable": true, "surface": "internal", "user_text": null},` | VALID |
| A5 | (counter-check) The EPIC brief §3 code list names `MAP_LANDMARK_UNSOURCED`, not `LO_LANDMARK_UNSOURCED` | `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:32`. That list also omits `LO_PROBE_UNCHECKABLE`, which this task indisputably uses, so it is a non-exhaustive citation of codes the EPIC touches (L0-10 is implemented by another task in this EPIC), not a code assignment overriding `contracts/error-codes.md`. Does not block finding A. | INVALID as an objection |
| B1 | `data/demo/nodes.json` contains 20 `numeric` probe items | Grep of `"answer":\{…\},"id":"…","prompt_latex":"…","type":"numeric"` over `data/demo/nodes.json` returns exactly 20 matches | VALID |
| B2 | The file contains zero `$` characters, so `extract_math_span`'s `\$(.+?)\$` matches nothing | Grep `\$` on `data/demo/nodes.json` — "No matches found" | VALID |
| B3 | Several numeric prompts are semantic, not arithmetic | Verbatim from the file: `y = 3x + 5 \Rightarrow \text{slope} = ?` (answer `3`); `(3x^2+2x) + (x^2+5x)\text{, coefficient of }x^2 = ?` (`4`); `x^2-5x+6=0 \Rightarrow \text{larger root} = ?` (`3`); `y=(x-3)^2+4 \Rightarrow \text{vertex } x\text{-coordinate} = ?` (`3`); `y=f(x-4) \text{ shifts the graph right by } ?\text{ units}` (`4`); `f(x)=\sqrt{x-3}\text{, domain requires } x \geq ?` (`3`). Each requires interpreting an English mathematical noun phrase, not evaluating an expression. | VALID |
| B4 | No machine-readable expression field exists, and none can be added without a contract change | `contracts/schemas/nodes.schema.json:228-329` — `probe_items[].items.properties` is exactly `id, type, prompt_latex, why, render_fallback, answer, wrong_answers, choices, correct_choice_id`, with `"additionalProperties": false` at line 329 | VALID |
| B5 | The contract requires re-derivation of *every* probe answer, unqualified | `contracts/content-policy.md` "## Generated content (all tiers)": "Probe answers are re-derived by SymPy before persistence (I1)". `docs/domains/learning-objects.md` W1 step 5: "every ProbeItem answer re-derived by SymPy in the pipeline … else `LO_PROBE_UNCHECKABLE`". Neither carries the EPIC brief's qualifier "where the prompt is expressible". | VALID — and it makes the conflict worse, not better |
| B6 | The EPIC brief's own line is internally ambiguous | `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:51-54`: "the pipeline re-derives every numeric answer with SymPy **where the prompt is expressible** (a test lists the items it could not express, **empty = FAIL** for this bundle since all are simple)". The qualifier admits a non-empty list; the parenthetical forbids one; and under the C3 convention "empty = FAIL" normally declares an *empty scan* vacuous, a third reading. Three readings, no tie-breaker in the text. | OUT-OF-SCOPE (brief-level ambiguity) |
| C1 | (found at arbitration, not in the report) AC5's landmark-name conjunct is unsatisfiable against the landed data | `data/demo/landmarks.json:6` — `"name": "Canadian fixed-rate mortgages compound semi-annually"`. That sentence is the project's own claim (I6 prose), not a string on `https://laws-lois.justice.gc.ca/eng/acts/I-15/`. `contracts/content-policy.md` "## Landmarks (I15, D22)" requires "the page text containing the landmark's name"; the EPIC brief's invariant line instead requires 'page text contains "Interest Act"' (`…:48-49`) while its AC 7 requires "the fetched text contains the landmark's name" (`…:81`). Contract, brief invariant line and brief AC do not agree, and the landed `name` satisfies none of the name-based readings. | OUT-OF-SCOPE (contract vs. data) |
| D1 | The `landmarks.json` file-scope exclusion is coherent | Confirmed. `docs/tech-stack.md:67` puts learning-objects validation in `pipeline/`; planner note [6] in `docs/plans/epic-01-task-plan.md` requires the live fetch to run in the gate and "No mock may make the assertion vacuous"; the exclusion makes a resolution failure block the gate instead of being silently repaired by the verifier. Spec §1 (I15 bullet), §2 (out-of-scope), §4 step 4 (closing paragraph) and §6 now state the single failure behaviour explicitly. | VALID — closed in-spec |

## Finding A — resolved in the spec (no escalation)

Applied throughout `tasks/epic-01-task-07-pipeline-content-verification.md`:

- §3 gains a "Which landmark code, and why" note quoting `docs/domains/map.md:127` and
  `docs/domains/learning-objects.md:130` side by side, anchored on `contracts/error-codes.md` "## Rules".
- §3 registry block now lists `LO_LANDMARK_UNSOURCED` (`contracts/error-codes.json:33`) in place of
  `MAP_LANDMARK_UNSOURCED`; the L0-10 quote is retained and re-labelled "cited for contrast only".
- §4 step 4: module constant `LO_LANDMARK_UNSOURCED: str`; the `fetch_page_text` raise site is
  `ResolutionFailure(LO_LANDMARK_UNSOURCED, url, …)`; an explicit line states `MAP_LANDMARK_UNSOURCED` is
  deliberately not a constant of this module.
- AC6, §5 T3, §5 T4 and `test_landmark_resolution_failure_path_is_real` now assert
  `.code == LO_LANDMARK_UNSOURCED`.
- §5 T3 gains a negative control for the code split: the literal token `MAP_LANDMARK_UNSOURCED` must appear
  in no `verify/*.py` file (scan asserts ≥ 3 files covered, anti-vacuity).
- §6 gains a decision-default fixing presence → `MAP_LANDMARK_UNSOURCED` (`Core`, L0-10, not this task) vs.
  resolution → `LO_LANDMARK_UNSOURCED` (this task).
- §1's I15 bullet, §2's out-of-scope entry, §4 step 4 and §6 now state the failure behaviour once and
  unambiguously (raise, red test, blocked gate, reported gap — never drop, catch, mock or edit here).

AC5 was left untouched by the finding-A pass because it names no error code; it is frozen under finding C.

## Why arbitration cannot resolve findings B and C at the spec level

Finding B is not spec drift. Three independent artifacts each say something the other two cannot satisfy:
`contracts/content-policy.md` requires *every* probe answer to be re-derived by SymPy with no expressibility
qualifier; `contracts/schemas/nodes.schema.json` closes the ProbeItem object (`additionalProperties: false`)
against any machine-readable expression field, leaving only the presentation string `prompt_latex`; and the
landed, merged `data/demo/nodes.json` encodes roughly two-thirds of its 20 numeric prompts as English
mathematical noun phrases inside `\text{…}` ("slope", "coefficient of x^2", "larger root", "vertex
x-coordinate", "shifts the graph right by", "domain requires x ≥"). Every available direction crosses a
boundary I do not hold: (a) is not a fix but a hazard — a LaTeX-plus-English phrase interpreter that decides
what a prompt is *asking* is a bespoke question-understander, and when it mis-parses it does not fail, it
silently "confirms" the hand-authored answer, which is exactly the laundered guess I1 exists to forbid;
(b) edits task 01.5's landed bundle and re-opens the Demo's pedagogical item design; (c) edits
`contracts/schemas/nodes.schema.json`; (d) edits `contracts/content-policy.md` and/or the EPIC brief. (c) and
(d) are contract changes, which are never an agent's to make; (b) is decomposition plus product judgment. No
rewrite of the spec's own words reconciles them, and widening the translator until the unexpressible list
empties would be fitting the tool to the test.

Finding C is the same failure mode on a smaller surface: the contract's landmark rule ("page text containing
the landmark's name") cannot be satisfied by the landed landmark, whose `name` is a project-authored claim
sentence rather than a string that appears on the Justice Laws page; the EPIC brief already improvises a
relaxation to the literal `"Interest Act"` in one place while restating the name rule in another. Choosing
between them means choosing which artifact governs — again above the spec level.

Both findings share one root question, which is why they are escalated together on one route.

## Recommended action

Owner ruling (Q5) on two questions. No D-number is being changed; the decision is which artifact governs and
how, and the answer determines whether the follow-up is a contract edit, a `brief-amender` pass, or a
`spec-architect` re-decomposition.

**Q5-1 (finding B) — What does "re-derived by SymPy" bind over, for prompts whose only machine-readable form
is a presentation LaTeX string that embeds an English question?** Choose one:

1. **Re-author the data.** `data/demo`'s 20 numeric prompts are rewritten so each is a pure expression or a
   single-unknown equation, keeping the pedagogy in `why`/`choices` rather than in the prompt's noun phrase.
   Contract and schema stand unchanged; AC2 stands as written. Follow-up: `spec-architect` — the edit lands
   in task 01.5's file and needs a decomposition decision about who owns that re-authoring, since 01.7's file
   scope excludes `prompt_latex`.
2. **Extend the schema.** Add an optional machine-checkable expression field to ProbeItem (e.g. a `check`
   object carrying a SymPy-parsable expression plus the intended unknown) so the CAS verifies a *declared*
   expression rather than inferring one from prose. Contract change to
   `contracts/schemas/nodes.schema.json` and `contracts/data-model.md`; also the strongest long-term answer,
   since the same problem recurs for every generated item beyond the Demo. Follow-up: owner edits the
   contract, then `spec-architect` re-scopes 01.5/01.7.
3. **Qualify the requirement.** `contracts/content-policy.md` is amended so re-derivation binds only over
   items that carry a machine-checkable form, and the verifier must *enumerate and commit* the ones it could
   not check (a named, non-empty, reviewed-by-machine list, empty = PASS declared explicitly per C3) rather
   than assert it is empty. Follow-up: owner edits the contract; `brief-amender` then reconciles the EPIC
   brief's "empty = FAIL" parenthetical.

Arbiter's recommendation, offered not adopted: **2, with 1 as the Demo-scoped interim.** Option 3 is the only
one that leaves an unchecked answer shipping, and the whole point of I1 is that no answer ships unchecked.
Option (a) from the reviewer's list — broadening the translator — should be ruled out explicitly whichever
way the owner goes, for the reason given above.

**Q5-2 (finding C) — What must the fetched landmark page contain?** `contracts/content-policy.md` says "the
landmark's name"; the landed landmark's `name` is the project's own claim sentence and appears on no page.
Choose: (i) the landmark gains a separate sourced-entity field (e.g. `source_title: "Interest Act"`) that the
page must contain — a `contracts/schemas/landmarks.schema.json` change; or (ii) the landmark's `name` is
re-authored to the real sourced thing and the claim sentence moves to `what_it_is` — a `data/demo` edit, and
the contract stands; or (iii) the contract's name rule is amended to "a declared substring of the source's
own title". Until this is settled, AC5 is frozen; AC6 (the failure path) is unaffected and already correct.

**Do not dispatch task 01.07 to an implementer before both rulings land.** The spec header carries the same
hold. Everything outside AC2 and AC5 in that spec is arbitrated and final.
