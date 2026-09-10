# Brief-amendment request: EPIC 01 §3 and §4.7 — carry the v1.1.0 contract change

**Date**: 2026-09-09
**Raised by**: spec-architect, executing `tasks/blocked/Q5-RULING-01-07.md`
**Route**: `brief-amender` (the EPIC brief is that agent's file; the spec-architect does not write it)
**Brief**: `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md`
**Blocks**: dispatch of `tasks/epic-01-task-07-pipeline-content-verification.md` (its AC2 and AC5 now
disagree with the brief text below until this amendment lands)

## Why an amendment is required

The owner's Q5 ruling (`tasks/blocked/Q5-RULING-01-07.md`, consequences 2 and 3) amends
`contracts/content-policy.md` and requires the EPIC brief to be brought into agreement. Two brief passages
are affected, and one of them is self-contradictory today.

### 1. §3 MANDATORY invariant line, I1/I10 clause

**Current text** (`docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:51-54`):

> I1 / I10 — every item is `numeric` or `mc` with a checked `answer`/`correct_choice_id`; the pipeline
> re-derives every numeric answer with SymPy where the prompt is expressible (a test lists the items it
> could not express, empty = FAIL for this bundle since all are simple).

**Problem**: the arbiter recorded three incompatible readings of this one sentence
(`tasks/blocked/blocked-arbiter-01-07.md:47`), and its premise ("all are simple") was measured false
against the landed data. The owner's ruling removes the premise entirely: the answer is no longer derived
from the prompt at all.

**Requested replacement text**:

> I1 / I10 — every item is `numeric` or `mc` with a checked `answer`/`correct_choice_id`; every `numeric`
> item carries a `check` (`contracts/data-model.md` § ProbeItem, v1.1.0) and the pipeline re-derives its
> answer from that field with SymPy, never from `prompt_latex` and never with a model. Every numeric item
> is derived — a scan covering fewer than all of them, or any item the CAS cannot derive exactly, FAILS.

### 2. §4 acceptance criterion 7

**Current text** (`docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:81`):

> 7. The landmark's `source_url` resolves (2xx) and the fetched text contains the landmark's name (I15).

**Problem**: it contradicts the same brief's own §3 invariant line at `:48-49` ("page text contains
\"Interest Act\""), and the landed landmark's `name` (`Canadian fixed-rate mortgages compound
semi-annually`) is a project-authored claim that appears on no page — so criterion 7 is unsatisfiable as
written. The owner ruled for the `"Interest Act"` reading and against editing the `name`.

**Requested replacement text**:

> 7. The landmark's `source_url` resolves (2xx) and the fetched text contains the landmark's
>    `source_title` — `"Interest Act"` for this bundle (I15, `contracts/content-policy.md` § Landmarks
>    v1.1.0). The landmark's `name` is the project's own claim and is never asserted against the page.

§3's I15 clause at `:48-49` already reads "page text contains \"Interest Act\"" and needs no change beyond,
optionally, naming the field: "page text contains the landmark's `source_title`, `\"Interest Act\"`".

## Source

- `tasks/blocked/Q5-RULING-01-07.md:39-42` (Q5-2 ruling) and `:44-50` (consequences 2 and 3).
- `contracts/content-policy.md` § Landmarks and § Generated content as amended to v1.1.0 by
  `tasks/epic-01-task-06.1-contract-v1-1-probe-check.md` §4 steps 3–4.

## Effect

**On deliverables**: NONE beyond the contract change already ruled. The landmark is still fetched live, the
failure still drops/blocks (I15), every numeric answer is still CAS-derived (I1) — more strictly than
before, since the "where the prompt is expressible" escape hatch is gone.
**On owner-facing acceptance**: criterion 7 becomes satisfiable; criterion 6, 8 and 9 unchanged.
**Owner-input requirement**: NONE — both changes are transcriptions of a ruling the owner already made.
