# Contract: Data model (LOCK-FIRST)

**Contract version:** v1.0.0 · Source: brief v2 §5 as amended (D20–D22, D32, D33, D43–D48), `docs/domains/*.md`

> The shapes every bundle file, the student state and `Core`'s `Codable` types share. The **JSON Schemas in
> `contracts/schemas/` are normative**; this file states the rules the schemas cannot. `Core` decodes exactly
> these shapes (a decode test over `contracts/examples/` is owed by the Demo EPIC); Android's `core` will
> too (D33). Retrofitting corrupts shipped bundles and synced state — locked first.

## Rules (normative)

### Identifiers
- Ids are **stable, opaque, lowercase kebab-case slugs** matching `^[a-z0-9]+(-[a-z0-9]+)*$`, unique within
  their collection. Never parse meaning from an id; never renumber. A renamed concept keeps its id.
- Fixed vocabularies: `region_id ∈ {number-operations, algebra, functions, geometry-measurement, trigonometry,
  calculus, linear-algebra, differential-equations, probability-statistics, discrete}` plus horizon labels
  `{analysis, topology, number-theory, abstract-algebra}` (flag `horizon: true`) and optional `shore`.
- `course_code` is the Ministry code verbatim in upper case (`MTH1W`, `MCR3U`); `unit_id` is
  `<course_code>.u<n>` (1-based, in unit order); `edge_id` is `<from>-->-<to>` (derived, never stored on the
  edge); `expectation_code` is the Ministry code verbatim (e.g. `B2.3`), scoped by course.
- Undergraduate `source_ref` is `{ source: "openstax" | "mit-ocw", edition, locator }` where `locator` is the
  section/chapter path the source publishes; it must resolve (L0-3b).

### Versioning
- Every bundle file carries `format_version` (semver) = `CoreInfo.dataFormatVersion`; a major bump means
  `Core` needs a migration; the app refuses a bundle whose major differs from its own.
- `manifest.json` lists every file with `asset_version` (id) and `sha256`; a partial manifest is never
  activated (platform W2). Bundle files are **immutable**: a change is a new `asset_version`.
- `StudentState.schema_version` (integer) is migrated forward only (platform W3); older files are kept.

### Time
- Dates in state and telemetry are **calendar days** (`YYYY-MM-DD`, device-local) — never finer (I5). Bundle
  provenance uses ISO 8601 UTC timestamps. No sub-day timestamp exists in any transmitted shape.

### Text
- All student-facing strings are English (DEFERRED D-1). LaTeX appears only in fields named `latex` or
  `prompt_latex` and must be in the SwiftMath-renderable subset or carry `render_fallback: "katex"`.
- No field may hold Ministry prose (I6): the schemas have no free-text field on Expectation other than
  `paraphrase`, and `content-policy.md`'s grep gate rejects a `verbatim` key anywhere.

### Nulls, enums, unknowns
- Optional means the key is **absent**, never `null`. Enums are closed; an unknown value fails decode.
- Every object schema sets `additionalProperties: false` — a new field is a versioned change.

### Collections (one file each; see `schemas/`)
| File | Schema | Notes |
|---|---|---|
| `manifest.json` | `manifest.schema.json` | `format_version`, `bundle_id`, `files[]` (name, `asset_version`, `sha256`), `spine_version`, `graph_version`, `built_at` |
| `regions.json` | `regions.schema.json` | ten regions + horizon labels (+ shore); normalised polygon, `neighbours[]`, `about` (one sentence) |
| `nodes.json` | `nodes.schema.json` | `id`, `name`, `region_id`, `strand?`, `expectation_codes[]?`, `source_ref?` (**at least one**), `courses[] {course_code, depth}`, `position {x,y}` (from `core-cli layout`), `layout_hint?`, `paraphrase`, `explanation?`, `worked_examples[]?`, `error_types[]` (closed, one `none-of-these`, each `implies_prerequisite?`), `hint_tree {error_type_id → [tier1, tier2, tier3]}`, `probe_items[]` |
| `edges.json` | `edges.schema.json` | `from`, `to`, `sources[] {tag, origin}`, `generation_agreement`, `confidence` [0,1], `probe_stats {probes, confirmed, downstream_fail_given_upstream_fail}` |
| `courses.json` | `courses.schema.json` | `course_code`, `name`, `vintage`, `strands[]`, `expectations[] {code, kind, paraphrase, official_url, unit_id}`, `units[] {unit_id, name, expectation_codes[]}`, `unit_source? {title, edition}`, `next_courses[]` |
| `landmarks.json` | `landmarks.schema.json` | `id`, `name`, `what_it_is`, `source_url` (**required**, https), `node_ids[]` (≥ 1), `region_ids[]`, `position` |
| `sources.json` | `sources.schema.json` | undergraduate sources: `source`, `title`, `edition`, `licence`, `attribution`, `url` |
| (state) | `student-state.schema.json` | see below |
| (telemetry) | `telemetry-batch.schema.json` | see `telemetry.md` |

### ProbeItem (inside `nodes.json`)
`id`, `type ∈ {numeric, mc}`, `prompt_latex`, `why`, and either `answer {value (string, normalised decimal or
rational), tolerance (≥ 0, default 0)}` with `wrong_answers[] {value, error_type_id}` (numeric) or
`choices[] {id, latex, error_type_id?}` + `correct_choice_id` (mc; every non-correct choice carries an
`error_type_id`). No free-text answer field exists (I1, I10).

### StudentState (`student-state.schema.json`)
`schema_version`, `format_version_seen`, `syllabi[]` (course codes), `marker {course_code, unit_id}`,
`nodes {node_id → {mastery ∈ {fog, cleared, blocked}, correct_count, last_probe?, next_due?, ladder_rung}}`,
`trail {segments[] {kind ∈ {course, extension}, course_code?, node_ids[]}}` (derived, cached),
`expedition_log[] {day, item_count, cleared, blocked, abandoned, diagnosis_events}`,
`probe_log[] {day, node_id, item_id, correct, retry}`, `install_day`, `consent_on`. **No field may name a
person, device, account, install or session** (I5); the schema's closed key set is the guard.

## Enforcement
- `pipeline/tests/test_contracts.py`: every schema is valid Draft 2020-12; every example in
  `contracts/examples/` validates; every `*.json` under `data/**` validates against the schema its filename
  names (empty `data/` = PASS, stated in the test output); `student-state` and `telemetry-batch` schemas
  reject any object containing a key from the identifier blocklist.
- Demo EPIC: `CoreTests` decode every example file into the `Core` types and re-encode byte-equal (modulo
  key order); `core-cli validate` runs L0 (`graph-constraints.md`).
