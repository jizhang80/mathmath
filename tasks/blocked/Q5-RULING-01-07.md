# Q5 ruling — task 01.7 (owner decision, 2026-09-09)

Escalated by `spec-arbiter` in `tasks/blocked/blocked-arbiter-01-07.md`, after the arbiter declined to
resolve it at spec level. Two questions were put to the owner; both are answered. This file is the record
the downstream specs cite.

## Q5-1 — SymPy re-derivation of probe answers

**Facts verified before escalation** (orchestrating session):
- `contracts/content-policy.md:29` requires "Probe answers are re-derived by SymPy before persistence (I1)",
  **unqualified** — stronger than the EPIC brief's "where the prompt is expressible".
- `contracts/schemas/nodes.schema.json` ProbeItem is `"additionalProperties": false` with properties exactly
  `answer, choices, correct_choice_id, id, prompt_latex, render_fallback, type, why, wrong_answers`. There is
  no machine-readable expression field and none can be added without a schema edit.
- `data/demo/nodes.json` has 20 `numeric` probe items and zero `$` characters. Roughly two thirds encode the
  question as an English phrase inside `\text{…}` (`slope`, `larger root`, `vertex } x\text{-coordinate`,
  `coefficient of }x^2`). No CAS can derive those from the prompt string.
- The arbiter explicitly refused to widen a LaTeX-plus-English interpreter until the unexpressible list
  emptied: such a parser does not fail when it mis-reads — it silently confirms the hand-authored answer,
  which is the laundered guess I1 exists to forbid.

**OWNER RULING: extend the schema.** ProbeItem gains a machine-readable expression field; SymPy derives the
answer from that field and compares against `answer`. Chosen over re-authoring the demo data and over
qualifying the contract, because the problem is not Demo-local: the generated-content EPICs (05–09) need
machine-checkable answers for I1 to hold at product scale, and both other options leave that unsolved.

This is a **versioned contract change** (`contracts/README.md`): bump the contract version, ripple to every
conforming EPIC, commit under scope `contract(<name>)`.

## Q5-2 — the landmark `source_url` assertion

**Facts verified before escalation:**
- `data/demo/landmarks.json`'s landmark `name` is `Canadian fixed-rate mortgages compound semi-annually`, a
  project-authored claim sentence that appears verbatim on no page.
- `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:48-49` requires the fetched page text to contain
  `"Interest Act"`; the same brief at `:81` (criterion 7) and `contracts/content-policy.md` § Landmarks
  require it to contain **the landmark's name**. The two cannot both hold.

**OWNER RULING: assert `"Interest Act"`.** The general rule — "the fetched page contains the landmark's
name" — is amended, because a landmark `name` is by design the project's own descriptive claim and not a
term from the source document, so the rule is unsatisfiable for essentially every landmark, not just this
one. The landmark's `name` is NOT edited to suit the test.

## Consequences to carry out

1. Contract + schema: add the ProbeItem expression field; document it; bump the contract version.
2. Contract: amend the § Landmarks name rule to an assertion the source can actually satisfy.
3. Brief: amend `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md` §4 criterion 7 so it agrees with §3.
4. Data: populate the new field for the 20 `numeric` probe items in `data/demo/nodes.json`.
5. Task 01.7: unfreeze AC2 and AC5; re-derive from the new field, not from `prompt_latex`.

I15 is unchanged: on a resolution failure the landmark is dropped, never edited into truth.
