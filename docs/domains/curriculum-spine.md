# Domain — curriculum-spine

## Purpose

The index of what Ontario requires taught in grades 9–12 mathematics: the twelve courses of brief §4.1,
their strands, and every expectation code, each with the project's own paraphrase and a link out to the
official Ministry page (D18, I6). It gives `concept-graph` a citable code set for Nodes, and the product
its Course → Strand → Node menu (§4.2). Milestones **M1**, **M6**.

## Actors and roles

| Actor | Can do here | Cannot |
|---|---|---|
| Owner | Run extraction, supply sources, cut and version a bundle | Write or edit a paraphrase; approve content on quality (I9) |
| System | Read the bundle, resolve code → Expectation, render the menu | Write to the spine; invent a code |
| Generation model | Produce each `paraphrase` offline via `content-generation` | Emit codes or names — those are extracted deterministically |
| Student / Parent | See code + paraphrase, follow the official link | Edit anything |

## Core entities

**Course** — one published course with grade, stream and vintage: MTH1W (2021); MPM2D, MFM2P (2005 plus
the 2022 addenda); MCR3U, MCF3M, MBF3C, MEL3E, MHF4U, MCV4U, MDM4U, MAP4C, MEL4E (2007) [SOURCED: brief
§4.1] — twelve in all. Vintage belongs to the Course: a nominal strand differs between vintages.
**Strand** — a division of a Course identified by its code prefix; the menu's middle level, never empty.

**Expectation** — the atom: the **code** as published (its identity; codes and names are facts, not
protected material — §10), its kind (overall / specific), the **paraphrase**, and the **official link** to
where verbatim text lives. It never stores Ministry wording, in any field, comment or fixture (I6).


**Spine bundle** — the immutable versioned artifact shipped to the product: Courses, Strands,
Expectations, provenance (source URL, retrieval date, vintage) and a content hash. No partial reads.

Referenced elsewhere: **Node**, **Graph bundle** (concept-graph) — `expectation_codes[]` point at codes
owned here, and the L0 coverage check (I8) reads a Spine bundle; **RunOutput**, **PromptVersion**
(content-generation); **AssetManifest** (platform).

## Workflows

### W1 — Extract a course into the spine

**Pre:** the official source for the Course and vintage is archived locally.
**Steps:**
1. (Tier 0) Record source URL and retrieval date, then parse strands and codes with a per-vintage parser —
   the 2021, 2005+addenda and 2007 documents differ in layout. Source text stays in memory only.
2. (Tier 0) Check the stubs: codes unique in the Course, prefixes matching their Strand, no empty Strand.
   Failure → `SPINE_PARSE_INCOMPLETE`, stop.
3. (Generation model, offline) Produce a `paraphrase` per Expectation — the only model step, and offline;
   no Tier 1 path exists here.
4. (Tier 0) Mechanical verification only (I9): non-empty, within the length bound and n-gram
   overlap threshold of Q1, English (I12). Failures regenerate; nothing is hand-edited, and a rejected
   paraphrase is never replaced by Ministry wording.
5. (Tier 0) Attach the official link from the per-Course template — `dcp.edu.gov.on.ca` for 2021 and the
   addenda, the PDF plus a section anchor for 2005/2007 [SOURCED: brief §4.1] — and drop the source text.

**Post:** the Course, its Strands and Expectations exist with paraphrases and one official link each (D18);
no Ministry prose is in any emitted file; the run is reproducible from the archived source and the recorded
`PromptVersion` (content-generation). Emits `spine.course_extracted`.

**Addendum variant (MPM2D, MFM2P):** the 2022 addendum runs the same steps; each code is classified
against the 2005 base as new, revised or unchanged — revised wins, new is added, unchanged keeps the base
entry, both vintages are recorded, and only new/revised codes are re-paraphrased (Q3).

### W2 — Cut, validate and re-version a bundle

**Pre:** every Course intended for the bundle is extracted.
**Steps:**
1. (Tier 0) Assemble Courses, provenance and a `spine_version`; validate against the schema; check no
   duplicate `(course, code)`, every Strand reachable, every Expectation carrying a paraphrase and a link
   on an allow-listed Ministry host, and zero verbatim-text findings — the I6 build gate, over bundles
   *and* fixtures. Failure stops the cut. Then hash, freeze, register with `AssetManifest`.
2. (Tier 0) On a Ministry revision, re-run W1 into a new `spine_version` and diff added, removed and
   revised codes — removals are the dangerous class, since a Node may map to nothing. Prior bundles stay
   retrievable, so an existing Graph bundle still validates against the spine it was built on.

**Post:** an immutable bundle is available to `concept-graph` and the System. Emits
`spine.bundle_published`, plus `spine.codes_changed` on a re-version.

## UI surfaces

- `/student/browse` — Course → Strand → Expectation menu (Tier 0 mapping): code, paraphrase, link.
- `/student/node/:nodeId`, `/parent/node/:nodeId` — "official expectations behind this node".
- No offline UI: extraction and bundling are Owner-run CLIs with a written report.

Routes are placeholders, confirmed in Phase 4.

## Notifications produced

- `spine.course_extracted` — `{ course_code, vintage, strand_count, expectation_count }`. Consumer:
  `content-generation`.
- `spine.bundle_published` — `{ spine_version, course_codes[], content_hash }`. Consumers: `concept-graph`
  (L0 coverage input), `platform` (asset registration).
- `spine.codes_changed` — `{ version_from, version_to, added[], removed[], revised[] }`. Consumers:
  `concept-graph` (recheck coverage), `parent-view`.

## Errors produced

| Code | When | User sees | Recoverable |
|---|---|---|---|
| `SPINE_PARSE_INCOMPLETE` | Empty Strand, malformed or duplicate code | Internal, with failing lines | Yes — fix parser |
| `SPINE_PARAPHRASE_REJECTED` | Missing, too long, overlapping the source, or non-English | Internal | Yes — regenerate, never edit (I9) |
| `SPINE_VERBATIM_TEXT_DETECTED` | The I6 gate finds source prose in a bundle or fixture | Internal; fails the build | Yes — fix first |
| `SPINE_LINK_UNRESOLVED` | Template cannot instantiate, or the check fails | Code + paraphrase render, link off | Yes |

## Invariants enforced here

- **I6 — primary owner.** Source text lives only in memory during W1; the overlap check at W1 step 4; the
  build gate at W2 over bundles and fixtures; the Expectation type has no field able to hold source prose,
  so a violation is a type error first.
- **I9 — co-owner.** The paraphrase path has no approval state and no editable field; rejection is answered
  only by regeneration.
- **I11 / I12** — thresholds are tagged and live in pipeline config; paraphrases pass an English check.
  Supports **I7**: no prerequisites here; course membership and depth live on the Node.

Seams: `content-generation` → curriculum-spine (paraphrase RunOutput accepted only after W1 step 4 and W2);
curriculum-spine → `concept-graph` (Spine bundle as L0 coverage input); `platform` → curriculum-spine
(asset loading, versioning).

## Open questions

**Q1 — Paraphrase format and overlap threshold.** **Default:** one verb-initial plain-text sentence, no
LaTeX, ≤ 140 characters [ESTIMATE: fits a menu row]; rejected if it shares a 6-gram with the source outside
an allow-list of technical terms. **Trade-off:** stricter settings defend I6 but force awkward wording and
more regeneration; looser ones read better and risk the "insubstantial excerpt" line (§10).
**Ratified 2026-09-08:** default accepted.

**Q2 — Do streamed courses sharing a code share one Expectation?** **Default:** no — one per
`(course, code)`, with `equivalent_to[]` so several map to one Node. **Trade-off:** duplication inflates
the bundle; merging would force one paraphrase across two vintages and depth markers.
**Ratified 2026-09-08:** default accepted.

**Q3 — Addendum conflicts with 2005 text.** **Default:** the addendum wins for any code it touches; the
base vintage survives as provenance. **Trade-off:** simple, but drops phrasing some classrooms follow.
**Ratified 2026-09-08:** default accepted.

## Change log

| Date | Change |
|---|---|
| 2026-09-08 | Drafted (Phase 3b). |
| 2026-09-08 | Open questions ratified by owner (all defaults; see docs/plans/phase3b-open-questions.md). |
