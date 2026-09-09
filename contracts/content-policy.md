# Contract: Content policy (LOCK-FIRST)

**Contract version:** v1.0.0 · Source: I6, I9, I11, I15; D2 (revised), D12, D13, D18, D22, D43; brief §10

> What may be stored, shipped or shown, by content tier, and how claims are tagged. A violation is a
> compliance problem, not a bug — locked first.

## Grade 9–12 tier (Ministry authority)
- A node or expectation carries **codes + the project's own `paraphrase` + an `official_url`**. No field
  anywhere holds Ministry prose; the key `verbatim` is banned repo-wide (grep gate). Paraphrase rule
  (curriculum-spine Q1): one verb-initial plain sentence, no LaTeX, ≤ 140 characters, rejected on a shared
  6-gram with the source outside the technical-term allow-list. Ministry source text lives in pipeline memory
  only and never in a kept RunOutput, fixture or test.
- Codes, course names, strand names and structure are facts and may be stored freely (§10).
- `official_url` hosts are allow-listed (`dcp.edu.gov.on.ca`, `edu.gov.on.ca`); anything else fails the cut.

## Undergraduate tier (CC-licensed authority — D2 revised, D43)
- A node carries a `source_ref` into a source listed in `sources.json` with its `licence` and `attribution`.
- OpenStax (CC BY 4.0): excerpts, paraphrases and derived items are permitted with the attribution string
  shipped in the bundle and shown on the node panel's "source" line. MIT OCW (CC BY-NC-SA): non-commercial
  only — the product is non-profit (brief header); a change to charging money (D19 trigger) **re-opens this
  tier's licensing before release**, recorded here as the standing condition.
- Even under CC BY, the product's own `paraphrase`/`explanation` are generated, not copied: the same
  6-gram overlap check applies against the source text, so the licence is a safety net, not the design.

## Generated content (all tiers)
- Everything student-facing is **batch-generated and machine-verified**, never human-reviewed (I9, D12,
  D13): failure paths end in regenerate or discard. A spec adding "owner reviews content" is BLOCKed.
- Probe answers are re-derived by SymPy before persistence (I1); prompts and hints must render in SwiftMath
  or carry `render_fallback: "katex"` (learning-objects W1 5b).
- Distractor tags: every `mc` distractor and every anticipated numeric wrong answer names an `ErrorType` of
  its node (diagnosis Q1); `none-of-these` is never a tag.

## Landmarks (I15, D22)
- Real, named, verifiable; `source_url` required and resolving at build (HTTP 2xx) with the page text
  containing the landmark's name; ≥ 1 node id. Unsourced → dropped, never invented, never "hypothetical".

## Documentation claims (I11)
- Every quantitative claim in `docs/`, `contracts/`, briefs and amendments carries `[SOURCED: …]` or
  `[ESTIMATE: …]`. **No time estimates anywhere** (pre-commit `no-time-estimates` hook). `[ESTIMATE]` values
  that are thresholds (e.g. 0.7, 30 probes, 95th percentile) live in one config file per consumer and are
  cited by name, never re-typed.

## Voice
- Teacher, not chatbot: one thing at a time, no persona, no filler, no scores or percentages on student
  surfaces; a node is named, the student never is (diagnosis §7 stance).

## Enforcement (wired)
- pre-commit: `no-time-estimates` over docs. wrap-epic (f): no `verbatim` key in `data/**`,
  `contracts/examples/**`, fixtures; every node has `paraphrase`; every landmark has `source_url`;
  `official_url` host allow-list; `[SOURCED]/[ESTIMATE]` presence on touched docs.
- schema: `source_ref` xor/or `expectation_codes` at-least-one (`nodes.schema.json` `anyOf`); `licence`
  enum on `sources.json`.
