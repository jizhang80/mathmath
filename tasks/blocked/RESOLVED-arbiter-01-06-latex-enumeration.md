# ARBITRATION RECORD: task 01.06 — LaTeX field enumeration

> **RESOLVED AT SPEC LEVEL — THIS IS NOT A BLOCK.** The filename deliberately does not match the
> `blocked-*` pattern so that a dispatcher globbing `tasks/blocked/blocked-*.md` does not halt EPIC 01 on
> it. Task 01.6 is unblocked and dispatchable. One item below is carried to the EPIC-01 wrap ledger.

**Date**: 2026-09-09
**Spec**: `tasks/epic-01-task-06-rendering-spike.md`
**Trigger**: `task-reviewer` BLOCK — contract-vs-contract conflict, writer resolved unilaterally
**Route**: resolved by `spec-arbiter`; one ledger item to task 01.8 and to EPICs 05–09; no owner stop

## The disagreement

`contracts/data-model.md` § Text is a field-naming rule and, read as a scan boundary, yields a NARROW
enumeration (`prompt_latex`, `choices[].latex`, `worked_examples[].steps_latex[]`).
`contracts/content-policy.md` § Generated content names **hints** explicitly and, with the rule it
cross-references (`docs/domains/learning-objects.md:81-82`), yields a BROAD enumeration that adds each
`hint_tree` tier string and `explanation`.

The task-writer chose narrow in a §6 decision-default citing only `data-model.md`, without reconciling the
`content-policy.md` text the spec itself quoted verbatim in its own §3. The reviewer BLOCKed on exactly that.

## Findings analysis

| # | Claim | Verification | Classification |
|---|---|---|---|
| 1 | `contracts/data-model.md` § Text restricts LaTeX to `latex`/`prompt_latex`-named fields | `contracts/data-model.md:36-37` — quoted exactly in the spec's §3 | VALID |
| 2 | `contracts/content-policy.md` § Generated content names hints and must render or carry `render_fallback: "katex"` | `contracts/content-policy.md:29-30` — confirmed | VALID |
| 3 | The spec's §3 quote of `content-policy.md` was not verbatim — it dropped `: "katex"` | Spec's old §3 read "carry `render_fallback` (learning-objects W1 5b)"; contract reads "carry `render_fallback: \"katex\"` (learning-objects W1 5b)" | VALID (self-sufficiency defect the reviewer did not catch; fixed) |
| 4 | The writer's narrow default contradicts the EPIC brief | `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:20-22`: "`Rendering.RenderCheck` over every `prompt_latex`, hint, explanation and choice in the bundle" — the EPIC brief states the broad set as this task's mandate, and does **not** name `worked_examples`, which the narrow set included. The writer's default was directly counter to its own EPIC brief. | VALID — decisive |
| 5 | `hint_tree` / `explanation` have no `render_fallback` sibling ⇒ rewrite-only (reviewer warning 1) | `render_fallback` occurs exactly ONCE in `contracts/schemas/nodes.schema.json`, at `:248`, inside the probe-item object; the node object is closed at `:375` (`"additionalProperties": false`), so no node-level flag can be added. `worked_examples` (`:161-184`) has only `id` and `steps_latex`. | VALID — confirmed; spec now marks them rewrite-only **and** out-of-mandate (STOP, not a prose edit) |
| 6 | Owner's empirical finding: zero LaTeX-looking content in `hint_tree`/`explanation`/`paraphrase`/`name` in the landed `data/demo/nodes.json` | Confirmed by direct read of the whole file. Stronger form established: `explanation` and `worked_examples` occur ZERO times in the file; after JSON decoding no `hint_tree` string contains a backslash, `{`, `}`, `&`, `%`, `$` or `#` (the `\/` sequences in the raw file are JSON-escaped forward slashes). | VALID |
| 7 | Broadening is therefore free | Confirmed and strengthened by a source-level check the owner did not run: SwiftMath's builder **silently skips unrecognised characters** rather than erroring (`Packages/Rendering/.build/checkouts/SwiftMath/Sources/SwiftMath/MathRender/MTMathListBuilder.swift:301-306`, `// Not a recognized character` → `continue`); its `setError` paths fire only on unknown backslash commands, brace mismatch, `\left`/`\right`/`\begin`/`\end` imbalance and invalid delimiters. Prose punctuation (`?`, `:`, `'`, `,`) cannot red the scan. | VALID |
| 8 | 01.5/01.7 shared-file sequencing unaffected (reviewer warning 2) | `data/demo/nodes.json` exists on `main` (01.5 landed). No `tasks/epic-01-task-07-*.md` exists ⇒ 01.7 has not landed. Planner note [3] (`docs/plans/epic-01-task-plan.md:45-47`) sequencing 01.5 → 01.6 → 01.7 holds; 01.6 is the sole current writer. | VALID — no change needed; now stated in the spec's §3 |
| 9 | Reviewer fix #3 — decode shape and entry emission if broadened | Applied. Two latent defects found while applying it: (a) `hint_tree` is a `[String: [String]]` dictionary, whose Swift iteration order is unstable, which would have broken the spec's own T6 byte-equality test — the spec now pins `keys.sorted()`; (b) `.convertFromSnakeCase` also rewrites dictionary keys, but `hint_tree`'s keys are `error_types[].id` values constrained to kebab-case by `nodes.schema.json:191-193` (`^[a-z0-9]+(-[a-z0-9]+)*$`), which admits no underscore, so the strategy is a no-op on them. Both recorded as §6 decision-defaults. | VALID |

## Resolution

**Scan the broad set.** Authority: the EPIC brief §2 states it in so many words (finding 4); it is a strict
superset of the narrow set, so it cannot violate `data-model.md` § Text — that rule constrains where LaTeX
may *appear*, not where a checker may *look*; and it is empirically outcome-identical on the landed bundle
(findings 6, 7). No contract text needed to change to unblock the task.

Bundle census established by direct read (`data/demo/nodes.json` at commit `7f7000d`):
`prompt_latex` 40, `choices[].latex` 40, `steps_latex` 0, `hint_tree` tier strings 63 (21 tiers × 3),
`explanation` 0, existing `render_fallback` keys 0. Broad total **143**; narrow total would have been 80.
Expected data edits to `nodes.json`: **zero**.

**The two questions are separate and were kept separate.** Unblocking task 01.6 did NOT require reconciling
the two contracts, and this arbitration does not reconcile them.

## Ledger item — for `docs/plans/epic-01-task-plan.md` wrap ledger (task 01.8)

Proposed wording, to be applied by the owner:

> **`content-policy.md` names a fallback for hints that the node schema cannot carry.**
> `contracts/content-policy.md` § Generated content requires that "prompts and hints must render in SwiftMath
> or carry `render_fallback: "katex"` (learning-objects W1 5b)", and
> `docs/domains/learning-objects.md:81-82` extends the same rule to `explanation`. But `render_fallback`
> occurs exactly once in `contracts/schemas/nodes.schema.json` — at `:248`, inside the probe-item object —
> and the node object is closed at `:375` (`"additionalProperties": false`). There is therefore no
> schema-legal place to flag a `hint_tree` tier string or an `explanation`, so for those two fields the
> contract's escape hatch does not exist and the only available remedy is rewriting student-facing prose.
> `contracts/data-model.md` § Text compounds this by confining LaTeX to fields named `latex` or
> `prompt_latex`, which excludes both. Task 01.6 was unblocked without settling this: it scans the broad
> field set (EPIC §2's mandate, a strict superset), and on `data/demo/nodes.json` at commit `7f7000d` the
> point is moot — zero LaTeX markup in any `hint_tree` string, `explanation` absent from all 20 nodes, zero
> `render_fallback` keys `[SOURCED: arbiter direct read of `data/demo/nodes.json`, 2026-09-09]`. **The
> question stops being academic in EPICs 05–09, where hints are model-generated.** Owner decision required
> before those EPICs: either (a) add `render_fallback` to the node object in `nodes.schema.json` and open
> `additionalProperties` accordingly, (b) narrow `content-policy.md` § Generated content and
> `learning-objects.md` W1 5b to prompts and choices only, making "no LaTeX in hints" an enforced
> containment rule instead, or (c) keep prose-rewrite as the sole remedy and say so explicitly in
> `content-policy.md`. No agent may edit `contracts/**` to close this.

## Anything remaining for the owner

Only the ledger item above, and only before EPICs 05–09. Nothing blocks EPIC 01. No locked decision
(D1–D49) is implicated, so this is not a Q5 today; option (a) or (b) above would become a contract change
and therefore an owner decision at that point.
