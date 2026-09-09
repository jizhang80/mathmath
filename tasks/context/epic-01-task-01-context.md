# Task 01.01 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-09
> Slug: core-bundle-types
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- Epic: 01
- Task: 01
- Slug: core-bundle-types
- Summary: `Core` `Codable` types for every bundle file (manifest, regions, nodes, edges, courses, landmarks, sources) plus `StudentState`, plus `CoreError`, plus deterministic bundle-directory read/write I/O; proven by a decode/re-encode round-trip over `contracts/examples/` and a `CoreError` ⊆ `contracts/error-codes.json` registry test.
- Invariants in play: I1, I5, I6, I8, I10, I14, I15

## §B. Applicable contract rules (verbatim)

### contracts/data-model.md — Rules (normative) — All sections

> **Collections (one file each; see `schemas/`)**
> | File | Schema | Notes |
> |---|---|---|
> | `manifest.json` | `manifest.schema.json` | `format_version`, `bundle_id`, `files[]` (name, `asset_version`, `sha256`), `spine_version`, `graph_version`, `built_at` |
> | `regions.json` | `regions.schema.json` | ten regions + horizon labels (+ shore); normalised polygon, `neighbours[]`, `about` (one sentence) |
> | `nodes.json` | `nodes.schema.json` | `id`, `name`, `region_id`, `strand?`, `expectation_codes[]?`, `source_ref?` (**at least one**), `courses[] {course_code, depth}`, `position {x,y}` (from `core-cli layout`), `layout_hint?`, `paraphrase`, `explanation?`, `worked_examples[]?`, `error_types[]` (closed, one `none-of-these`, each `implies_prerequisite?`), `hint_tree {error_type_id → [tier1, tier2, tier3]}`, `probe_items[]` |
> | `edges.json` | `edges.schema.json` | `from`, `to`, `sources[] {tag, origin}`, `generation_agreement`, `confidence` [0,1], `probe_stats {probes, confirmed, downstream_fail_given_upstream_fail}` |
> | `courses.json` | `courses.schema.json` | `course_code`, `name`, `vintage`, `strands[]`, `expectations[] {code, kind, paraphrase, official_url, unit_id}`, `units[] {unit_id, name, expectation_codes[]}`, `unit_source? {title, edition}`, `next_courses[]` |
> | `landmarks.json` | `landmarks.schema.json` | `id`, `name`, `what_it_is`, `source_url` (**required**, https), `node_ids[]` (≥ 1), `region_ids[]`, `position` |
> | `sources.json` | `sources.schema.json` | undergraduate sources: `source`, `title`, `edition`, `licence`, `attribution`, `url` |
> | (state) | `student-state.schema.json` | see below |

Source: `contracts/data-model.md:45–56`
Binds this task: defines the seven bundle files and StudentState that must have `Codable` types in `Core`.

### contracts/data-model.md — Identifiers

> Ids are **stable, opaque, lowercase kebab-case slugs** matching `^[a-z0-9]+(-[a-z0-9]+)*$`, unique within their collection. Never parse meaning from an id; never renumber. A renamed concept keeps its id.
> Fixed vocabularies: `region_id ∈ {number-operations, algebra, functions, geometry-measurement, trigonometry, calculus, linear-algebra, differential-equations, probability-statistics, discrete}` plus horizon labels `{analysis, topology, number-theory, abstract-algebra}` (flag `horizon: true`) and optional `shore`.
> `course_code` is the Ministry code verbatim in upper case (`MTH1W`, `MCR3U`); `unit_id` is `<course_code>.u<n>` (1-based, in unit order); `edge_id` is `<from>-->-<to>` (derived, never stored on the edge); `expectation_code` is the Ministry code verbatim (e.g. `B2.3`), scoped by course.
> Undergraduate `source_ref` is `{ source: "openstax" | "mit-ocw", edition, locator }` where `locator` is the section/chapter path the source publishes; it must resolve (L0-3b).

Source: `contracts/data-model.md:12–23`
Binds this task: types must preserve these exact vocabularies and patterns; no inference from ids.

### contracts/data-model.md — Versioning

> Every bundle file carries `format_version` (semver) = `CoreInfo.dataFormatVersion`; a major bump means `Core` needs a migration; the app refuses a bundle whose major differs from its own.
> `manifest.json` lists every file with `asset_version` (id) and `sha256`; a partial manifest is never activated (platform W2). Bundle files are **immutable**: a change is a new `asset_version`.
> `StudentState.schema_version` (integer) is migrated forward only (platform W3); older files are kept.

Source: `contracts/data-model.md:24–30`
Binds this task: versioning constants are in the types; no major version handling in this task (handled at load).

### contracts/data-model.md — Text

> All student-facing strings are English (DEFERRED D-1). LaTeX appears only in fields named `latex` or `prompt_latex` and must be in the SwiftMath-renderable subset or carry `render_fallback: "katex"`.
> No field may hold Ministry prose (I6): the schemas have no free-text field on Expectation other than `paraphrase`, and `content-policy.md`'s grep gate rejects a `verbatim` key anywhere.

Source: `contracts/data-model.md:35–40`
Binds this task: types must not permit `verbatim` key; LaTeX field naming must be exact.

### contracts/data-model.md — Nulls, enums, unknowns

> Optional means the key is **absent**, never `null`. Enums are closed; an unknown value fails decode.
> Every object schema sets `additionalProperties: false` — a new field is a versioned change.

Source: `contracts/data-model.md:41–43`
Binds this task: Swift `Decodable` must treat missing keys as absences; enums must be exact.

### contracts/data-model.md — ProbeItem

> `id`, `type ∈ {numeric, mc}`, `prompt_latex`, `why`, and either `answer {value (string, normalised decimal or rational), tolerance (≥ 0, default 0)}` with `wrong_answers[] {value, error_type_id}` (numeric) or `choices[] {id, latex, error_type_id?}` + `correct_choice_id` (mc; every non-correct choice carries an `error_type_id`). No free-text answer field exists (I1, I10).

Source: `contracts/data-model.md:58–63`
Binds this task: ProbeItem structure must exactly match; numeric vs mc must be discriminated.

### contracts/data-model.md — StudentState

> `schema_version`, `format_version_seen`, `syllabi[]` (course codes), `marker {course_code, unit_id}`, `nodes {node_id → {mastery ∈ {fog, cleared, blocked}, correct_count, last_probe?, next_due?, ladder_rung}}`, `trail {segments[] {kind ∈ {course, extension}, course_code?, node_ids[]}}` (derived, cached), `expedition_log[] {day, item_count, cleared, blocked, abandoned, diagnosis_events}`, `probe_log[] {day, node_id, item_id, correct, retry}`, `install_day`, `consent_on`. **No field may name a person, device, account, install or session** (I5); the schema's closed key set is the guard.

Source: `contracts/data-model.md:64–71`
Binds this task: StudentState structure is fixed; I5 blocklist enforced by schema (no `id`, `user_id`, `device_id`, `session_id`, `email`, `name`, `timestamp`, `ip`, `install_id`).

### contracts/error-codes.md — Rules

> - Prefixes are fixed per domain: `MAP`, `EXP`, `DIAG`, `GRAPH`, `LO`, `SPINE`, `GEN`, `PLATFORM`, `TELEM`, `TIER`, `VERIFY` (M5). A code appears in exactly one domain doc and in the registry.
> - Every code declares `recoverable` (bool), `surface ∈ {internal, student, owner}` and `user_text` — the student-facing sentence when `surface = student`, else `null`. Student text names a node or a situation, never the student, and never contains a score (content-policy voice).
> - `Core` defines `enum CoreError: String` mirroring the `GRAPH`, `EXP`, `MAP` (validation) and `DIAG` codes; the App and the pipeline each map their own. A code raised in code but absent from the registry fails the round-trip test.
> - Internal codes never reach a student surface; a `student` code always has a next action in its text.
> - `GRAPH_L0_FAILED` carries the failing rule ids from `graph-constraints.md` in `details`.

Source: `contracts/error-codes.md:9–20`
Binds this task: `CoreError` enum must be a subset of the registry; registry test must pass.

### contracts/graph-constraints.md — L0 rules (overview for this task)

> | Id | Rule | Fails with | Note |
> |---|---|---|---|
> | L0-1 | The edge set is acyclic. | `GRAPH_L0_FAILED{L0-1, cycle[]}` | — |
> | L0-2 | No edge goes from a later course to an earlier one: for every edge, `min depth(from) ≤ max depth(to)` over `courses[]`; nodes without `courses[]` (undergraduate) are treated as deeper than every course. | `GRAPH_L0_FAILED{L0-2, edge}` | depth = the course's position in the Ministry succession, from `courses.json` |
> | L0-3a | Every Ministry expectation in the spine maps to ≥ 1 node, and every node carrying `expectation_codes` maps to ≥ 1 existing code. | `GRAPH_L0_FAILED{L0-3a, codes[]}` | applies only to code-bearing nodes (v2.7 §1) |
> | L0-3b | Every node without `expectation_codes` carries a `source_ref` whose `source` exists in `sources.json` and whose `locator` is non-empty; the pipeline additionally checks that the locator resolves (HTTP 2xx) at build. A node with neither codes nor `source_ref` fails. | `GRAPH_L0_FAILED{L0-3b, node}` / `SPINE_SOURCE_REF_UNRESOLVED` | resolution is a build-time check; the app checks presence only |
> | L0-4 | In-degree outliers are **flagged, not failed**: nodes whose in-degree exceeds the threshold (default: 95th percentile of the bundle [ESTIMATE: set empirically at M2, concept-graph Q1]) are listed in the report. | report only | advisory |
> | L0-5 | The D14 starting chain is connected end-to-end: a directed path exists through the chain's nodes in order. | `GRAPH_L0_FAILED{L0-5, break}` | chain node ids are data in the bundle (`manifest.starting_chain[]`) |
> | L0-6 | Every node has exactly one `region_id`, and it names a non-horizon region in `regions.json`. | `GRAPH_L0_FAILED{L0-6, node}` / `MAP_REGION_UNKNOWN` | — |
> | L0-7 | Every node has a `position` inside its region's polygon. | `MAP_LAYOUT_MISSING` | produced by `core-cli layout`; checked after it |
> | L0-8 | Every unit of every course references only expectations of that course, every expectation is in exactly one unit, no unit is empty. | `SPINE_UNIT_EMPTY` / `GRAPH_L0_FAILED{L0-8}` | D45 |
> | L0-9 | Every course's `next_courses[]` names existing courses and contains no cycle. | `GRAPH_L0_FAILED{L0-9}` | D47 succession is data |
> | L0-10 | Every landmark's `node_ids[]` are existing nodes and `source_url` is present (https). | `MAP_LANDMARK_UNSOURCED` | resolution checked by the pipeline (I15) |

Source: `contracts/graph-constraints.md:11–23`
Binds this task: L0 validation is not part of task 01.01 (it is task 01.02), but types must support these validations; error codes must include the named failures.

### contracts/domain-glossary.md — Map and graph (excerpt)

> - **Map** — the concept graph rendered as one continent. *Banned:* "world", "board", "skill tree".
> - **Region** — one of the ten D21 territories (`region_id` fixed enum, `data-model.md`). *Banned:* "area", "zone", "strand" (a strand is a Ministry division, see below).
> - **Horizon** — a named label beyond the continent with no content (Analysis, Topology, Number Theory, Abstract Algebra).
> - **Shore** — the optional grade 7–8 region, drawn without content (not in the Demo; DEFERRED D-10).
> - **Node** — one concept; the unit of mastery. *Banned:* "topic", "skill", "concept card".
> - **Edge** — "A is prerequisite of B", directed `from → to`. Rendered as a **river**. *Banned:* "link", "dependency" (in data), "arrow".
> - **Course** — a Ministry course (`course_code`, e.g. `MCR3U`) = node subset + depth marker (D3). Courses have **Units** and **next courses** (succession).
> - **Unit** — a course's teaching unit (D45): an ordered group of expectations from the course's `unit_source` textbook, fallback by strand. *Banned:* "chapter" (that is the textbook's word), "module", "lesson".
> - **Landmark** — a real, named, sourced thing linked to nodes (D22). *Banned:* "application", "example", "story".

Source: `contracts/domain-glossary.md:9–24`
Binds this task: type names must match this vocabulary exactly.

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/concept-graph.md — Core entities

> **Node** — `id`, `name`, `strand`, `expectation_codes[]` (grade 9–12; owned by `curriculum-spine`) and/or `source_ref` (undergraduate: source, edition, chapter/section into a designated CC-licensed source — D2 as revised; a node with neither fails L0), `courses[]` each with a `depth` marker, `region` (exactly one, D21, I8), `position` (written by the layout build step, D33; an optional `layout_hint` seeds it), and per-node content owned by `learning-objects` (ErrorType, HintTree, ProbeItem), referenced by id. **Edge** — "A is prerequisite of B": `from`, `to`, `sources[]`, `generation_agreement`, `confidence`, `probe_stats` (§5); directed, and the set is acyclic (I8).
>
> **Source tag** — an entry in `sources[]`: `ministry_prereq | textbook_order | third_party_structure | model_generated`. The L1 rule is fixed by the brief: an edge with **≥ 2 independent sources is accepted** (§6). Independence is by tag *and* origin: chapter orders from one publisher count once, as does `model_generated` however many runs agreed.
>
> **Confidence** — a 0–1 scalar per Edge, from `sources[]` plus `generation_agreement`, updated from **ProbeStats** `{ probes, confirmed, downstream_fail_given_upstream_fail }` as L3 data arrives. Disputed edges ship low-confidence rather than dropped, settled by probe data (D13, I9). Inputs are per-batch-capped by telemetry (one observation per edge per batch).

Source: `docs/domains/concept-graph.md:20–37`
Binds this task: types must exactly model Node, Edge, and their sub-entities.

### docs/domains/learning-objects.md — Core entities

> **LearningObject** — per-node container keyed by a Node id, one per node in the graph bundle. The **LearningObject bundle** holds all of them, a manifest and the `graph_bundle_version` targeted; it is immutable and versioned, and platform's AssetManifest loads it. **Explanation** — short prose in the project's own words, no verbatim Ministry text (I6, D18); it may cite codes of the Expectations (curriculum-spine) the node realises. **WorkedExample** — a solved item as an ordered LaTeX step sequence, each step CAS-checked by the pipeline (D41); displayed via SwiftMath, and at M5 also on the homework-mode input path (D9).
>
> **ErrorType** — a member of the node's closed catalogue (brief §5 `error_catalogue[]`): per-node, with exactly one terminal `none_of_these`. Canonical example, the M4′ node *logarithmic equation solving*, six members verbatim from brief §8 — missed domain restriction; log-combination rule misapplied; exponent–log inverse relationship not internalised; quadratic solved incorrectly; arithmetic slip; none of these. Each has a stable id, a student-facing phrasing, a `probe_target`, and `implies_prerequisite`: `null`, or an upstream Node id — **the implies-prerequisite mapping**. Above, the exponent–log type points at the exponential-functions node of the D14 chain, "arithmetic slip" nowhere, and `none_of_these` is always `null`: abstention, not diagnosis.
>
> **HintTree** — per node, ErrorType → ordered tiers: tier 1 nudges at what to look at, tier 2 targets that ErrorType, tier 3 works the failing step through. Answers are never withheld (D5, I3), so the tree gates nothing: it exposes the *reason* for the failure. Tier order and semantics are fixed at generation.
>
> **ProbeItem** — a short item tagged with a node id, of type `numeric | mc` (I10): a `prompt` (LaTeX subset SwiftMath renders — the rendering spike, v2.2 §B), an `answer` (numeric, with an optional declared tolerance) or `choices[]` with the correct id, a one-line `why` shown with the answer (D5), and `distractor_error_types` — every distractor and each anticipated numeric wrong answer tagged with an `ErrorType` id, the Tier 0 classifier (diagnosis Q1). The answer is re-derived by SymPy in the pipeline (D41, I1); on the device it is checked in code, with no grader model and no free text. Two drawn per diagnosis probe [SOURCED: brief §2, §7], one per expedition slot (D23).
>
> **Landmark** — `id`, `name`, `what_it_is` (one plain-language paragraph, the project's own words), `source_url` (required; must resolve — D22, I15), `node_ids[]` (≥ 1, often across regions), `region_ids[]`, `position` on the map. Generated with its source in content-generation, validated here, placed by map. A landmark that cannot be sourced is dropped, never invented.

Source: `docs/domains/learning-objects.md:31–65`
Binds this task: types for Explanation, WorkedExample, ErrorType, HintTree, ProbeItem, and Landmark must exactly model this structure.

## §D. Schemas (all verbatim from contracts/schemas/)

### contracts/schemas/manifest.schema.json

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://mathmath.local/contracts/manifest.schema.json",
  "title": "manifest",
  "type": "object",
  "properties": {
    "format_version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "bundle_id": {
      "type": "string",
      "pattern": "^[a-z0-9]+(-[a-z0-9]+)*$"
    },
    "spine_version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "graph_version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "built_at": {
      "type": "string",
      "pattern": "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$"
    },
    "starting_chain": {
      "type": "array",
      "items": {
        "type": "string",
        "pattern": "^[a-z0-9]+(-[a-z0-9]+)*$"
      },
      "minItems": 1
    },
    "files": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": {
            "type": "string",
            "enum": [
              "regions.json",
              "nodes.json",
              "edges.json",
              "courses.json",
              "landmarks.json",
              "sources.json"
            ]
          },
          "asset_version": {
            "type": "string",
            "pattern": "^[a-z0-9]+(-[a-z0-9]+)*$"
          },
          "sha256": {
            "type": "string",
            "pattern": "^[a-f0-9]{64}$"
          }
        },
        "required": [
          "name",
          "asset_version",
          "sha256"
        ],
        "additionalProperties": false
      },
      "minItems": 1
    }
  },
  "required": [
    "format_version",
    "bundle_id",
    "spine_version",
    "graph_version",
    "built_at",
    "starting_chain",
    "files"
  ],
  "additionalProperties": false
}
```

Source: `contracts/schemas/manifest.schema.json:1–80`

### contracts/schemas/regions.schema.json

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://mathmath.local/contracts/regions.schema.json",
  "title": "regions",
  "type": "object",
  "properties": {
    "format_version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "regions": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": {
            "type": "string",
            "enum": [
              "number-operations",
              "algebra",
              "functions",
              "geometry-measurement",
              "trigonometry",
              "calculus",
              "linear-algebra",
              "differential-equations",
              "probability-statistics",
              "discrete",
              "analysis",
              "topology",
              "number-theory",
              "abstract-algebra",
              "shore"
            ]
          },
          "name": {
            "type": "string",
            "minLength": 1
          },
          "about": {
            "type": "string",
            "minLength": 1
          },
          "horizon": {
            "type": "boolean"
          },
          "polygon": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "x": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 1
                },
                "y": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 1
                }
              },
              "required": [
                "x",
                "y"
              ],
              "additionalProperties": false
            },
            "minItems": 3
          },
          "neighbours": {
            "type": "array",
            "items": {
              "type": "string",
              "enum": [
                "number-operations",
                "algebra",
                "functions",
                "geometry-measurement",
                "trigonometry",
                "calculus",
                "linear-algebra",
                "differential-equations",
                "probability-statistics",
                "discrete",
                "analysis",
                "topology",
                "number-theory",
                "abstract-algebra",
                "shore"
              ]
            }
          }
        },
        "required": [
          "id",
          "name",
          "about",
          "horizon",
          "polygon",
          "neighbours"
        ],
        "additionalProperties": false
      },
      "minItems": 1
    }
  },
  "required": [
    "format_version",
    "regions"
  ],
  "additionalProperties": false
}
```

Source: `contracts/schemas/regions.schema.json:1–113`

### contracts/schemas/nodes.schema.json (full file)

> [Full JSON Schema with 397 lines covering node structure with positions, probe items, error types, hint trees, expectation codes, and source references]

Source: `contracts/schemas/nodes.schema.json:1–397`
Note: This schema defines the comprehensive Node structure including ProbeItem discrimination (numeric vs mc via `allOf`), ErrorType catalogue with `implies_prerequisite` mapping, HintTree as object with error_type_id keys, and constraints that every node must have either `expectation_codes` or `source_ref` (via `anyOf`).

### contracts/schemas/edges.schema.json

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://mathmath.local/contracts/edges.schema.json",
  "title": "edges",
  "type": "object",
  "properties": {
    "format_version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "edges": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "from": {
            "type": "string",
            "pattern": "^[a-z0-9]+(-[a-z0-9]+)*$"
          },
          "to": {
            "type": "string",
            "pattern": "^[a-z0-9]+(-[a-z0-9]+)*$"
          },
          "sources": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "tag": {
                  "type": "string",
                  "enum": [
                    "ministry_prereq",
                    "textbook_order",
                    "third_party_structure",
                    "model_generated"
                  ]
                },
                "origin": {
                  "type": "string",
                  "minLength": 1
                }
              },
              "required": [
                "tag",
                "origin"
              ],
              "additionalProperties": false
            }
          },
          "generation_agreement": {
            "type": "integer",
            "minimum": 0
          },
          "confidence": {
            "type": "number",
            "minimum": 0,
            "maximum": 1
          },
          "probe_stats": {
            "type": "object",
            "properties": {
              "probes": {
                "type": "integer",
                "minimum": 0
              },
              "confirmed": {
                "type": "integer",
                "minimum": 0
              },
              "downstream_fail_given_upstream_fail": {
                "type": "number",
                "minimum": 0,
                "maximum": 1
              }
            },
            "required": [
              "probes",
              "confirmed"
            ],
            "additionalProperties": false
          }
        },
        "required": [
          "from",
          "to",
          "sources",
          "generation_agreement",
          "confidence",
          "probe_stats"
        ],
        "additionalProperties": false
      }
    }
  },
  "required": [
    "format_version",
    "edges"
  ],
  "additionalProperties": false
}
```

Source: `contracts/schemas/edges.schema.json:1–100`

### contracts/schemas/courses.schema.json

> [Full JSON Schema with 167 lines covering course_code, name, vintage, strands, expectations, units with expectation_codes, unit_source, and next_courses]

Source: `contracts/schemas/courses.schema.json:1–167`

### contracts/schemas/landmarks.schema.json

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://mathmath.local/contracts/landmarks.schema.json",
  "title": "landmarks",
  "type": "object",
  "properties": {
    "format_version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "landmarks": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": {
            "type": "string",
            "pattern": "^[a-z0-9]+(-[a-z0-9]+)*$"
          },
          "name": {
            "type": "string",
            "minLength": 1
          },
          "what_it_is": {
            "type": "string",
            "minLength": 1
          },
          "source_url": {
            "type": "string",
            "pattern": "^https://"
          },
          "node_ids": {
            "type": "array",
            "items": {
              "type": "string",
              "pattern": "^[a-z0-9]+(-[a-z0-9]+)*$"
            },
            "minItems": 1
          },
          "region_ids": {
            "type": "array",
            "items": {
              "type": "string",
              "enum": [
                "number-operations",
                "algebra",
                "functions",
                "geometry-measurement",
                "trigonometry",
                "calculus",
                "linear-algebra",
                "differential-equations",
                "probability-statistics",
                "discrete"
              ]
            },
            "minItems": 1
          },
          "position": {
            "type": "object",
            "properties": {
              "x": {
                "type": "number",
                "minimum": 0,
                "maximum": 1
              },
              "y": {
                "type": "number",
                "minimum": 0,
                "maximum": 1
              }
            },
            "required": [
              "x",
              "y"
            ],
            "additionalProperties": false
          }
        },
        "required": [
          "id",
          "name",
          "what_it_is",
          "source_url",
          "node_ids",
          "region_ids",
          "position"
        ],
        "additionalProperties": false
      }
    }
  },
  "required": [
    "format_version",
    "landmarks"
  ],
  "additionalProperties": false
}
```

Source: `contracts/schemas/landmarks.schema.json:1–98`

### contracts/schemas/sources.schema.json

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://mathmath.local/contracts/sources.schema.json",
  "title": "sources",
  "type": "object",
  "properties": {
    "format_version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "sources": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "source": {
            "type": "string",
            "enum": [
              "openstax",
              "mit-ocw"
            ]
          },
          "title": {
            "type": "string",
            "minLength": 1
          },
          "edition": {
            "type": "string",
            "minLength": 1
          },
          "licence": {
            "type": "string",
            "enum": [
              "CC BY 4.0",
              "CC BY-NC-SA 4.0"
            ]
          },
          "attribution": {
            "type": "string",
            "minLength": 1
          },
          "url": {
            "type": "string",
            "pattern": "^https://"
          }
        },
        "required": [
          "source",
          "title",
          "edition",
          "licence",
          "attribution",
          "url"
        ],
        "additionalProperties": false
      }
    }
  },
  "required": [
    "format_version",
    "sources"
  ],
  "additionalProperties": false
}
```

Source: `contracts/schemas/sources.schema.json:1–64`

### contracts/schemas/student-state.schema.json

> [Full JSON Schema with 219 lines covering schema_version, format_version_seen, syllabi, marker, nodes (with mastery states), trail (segments), expedition_log, probe_log, install_day, consent_on. Notably: no `id`, `device_id`, `session_id`, `user_id`, `timestamp`, `email`, `name`, `ip`, or `install_id` keys allowed (I5)]

Source: `contracts/schemas/student-state.schema.json:1–219`

## §E. Examples (all from contracts/examples/)

### contracts/examples/manifest.json

```json
{
  "format_version": "0.0.0",
  "bundle_id": "contracts-example",
  "spine_version": "0.0.0",
  "graph_version": "0.0.0",
  "built_at": "2026-09-09T00:00:00Z",
  "starting_chain": [
    "exponent-laws",
    "exponential-functions"
  ],
  "files": [
    {
      "name": "regions.json",
      "asset_version": "regions-v0",
      "sha256": "0000000000000000000000000000000000000000000000000000000000000000"
    },
    {
      "name": "nodes.json",
      "asset_version": "nodes-v0",
      "sha256": "0000000000000000000000000000000000000000000000000000000000000000"
    },
    {
      "name": "edges.json",
      "asset_version": "edges-v0",
      "sha256": "0000000000000000000000000000000000000000000000000000000000000000"
    },
    {
      "name": "courses.json",
      "asset_version": "courses-v0",
      "sha256": "0000000000000000000000000000000000000000000000000000000000000000"
    },
    {
      "name": "landmarks.json",
      "asset_version": "landmarks-v0",
      "sha256": "0000000000000000000000000000000000000000000000000000000000000000"
    },
    {
      "name": "sources.json",
      "asset_version": "sources-v0",
      "sha256": "0000000000000000000000000000000000000000000000000000000000000000"
    }
  ]
}
```

Source: `contracts/examples/manifest.json:1–43`

### contracts/examples/regions.json (excerpt)

First region (number-operations) and horizon labels (analysis, topology, number-theory, abstract-algebra) to show structure:

```json
{
  "format_version": "0.0.0",
  "regions": [
    {
      "id": "number-operations",
      "name": "Number & Operations",
      "about": "Numbers, operations and the laws that govern them.",
      "horizon": false,
      "polygon": [
        {"x": 0.0, "y": 0.0},
        {"x": 0.19, "y": 0.0},
        {"x": 0.19, "y": 0.3},
        {"x": 0.0, "y": 0.3}
      ],
      "neighbours": []
    },
    {
      "id": "analysis",
      "name": "Analysis",
      "about": "Beyond the continent; names only.",
      "horizon": true,
      "polygon": [
        {"x": 0.0, "y": 0.6666666666666666},
        {"x": 0.19, "y": 0.6666666666666666},
        {"x": 0.19, "y": 0.9666666666666666},
        {"x": 0.0, "y": 0.9666666666666666}
      ],
      "neighbours": []
    }
  ]
}
```

Source: `contracts/examples/regions.json:1–356` (ten regions shown; excerpt illustrates structure)

### contracts/examples/nodes.json (excerpt)

First node with full structure:

```json
{
  "format_version": "0.0.0",
  "nodes": [
    {
      "id": "exponent-laws",
      "name": "Exponent laws",
      "region_id": "number-operations",
      "strand": "B",
      "expectation_codes": [
        {
          "course_code": "MTH1W",
          "code": "B3.4"
        }
      ],
      "courses": [
        {
          "course_code": "MTH1W",
          "depth": 1
        }
      ],
      "position": {
        "x": 0.08,
        "y": 0.12
      },
      "paraphrase": "Simplify products, quotients and powers of powers using the exponent laws.",
      "error_types": [
        {
          "id": "added-exponents-on-power",
          "label": "Added the exponents instead of multiplying when raising a power to a power"
        },
        {
          "id": "none-of-these",
          "label": "None of these"
        }
      ],
      "hint_tree": {
        "added-exponents-on-power": [
          "Look at what happens to the exponent when a power is raised to a power.",
          "When you raise a power to a power, multiply the exponents.",
          "(2^3)^2 = 2^(3×2) = 2^6, not 2^5."
        ]
      },
      "probe_items": [
        {
          "id": "exp-1",
          "type": "numeric",
          "prompt_latex": "(2^3)^2 = 2^{\\,?}",
          "why": "Raising a power to a power multiplies the exponents: 3 × 2 = 6.",
          "answer": {
            "value": "6"
          },
          "wrong_answers": [
            {
              "value": "5",
              "error_type_id": "added-exponents-on-power"
            }
          ]
        },
        {
          "id": "exp-2",
          "type": "mc",
          "prompt_latex": "\\text{Which equals } x^4 \\cdot x^3 ?",
          "why": "Multiplying powers with the same base adds the exponents: 4 + 3 = 7.",
          "choices": [
            {
              "id": "a",
              "latex": "x^{7}"
            },
            {
              "id": "b",
              "latex": "x^{12}",
              "error_type_id": "added-exponents-on-power"
            }
          ],
          "correct_choice_id": "a"
        }
      ]
    }
  ]
}
```

Source: `contracts/examples/nodes.json:1–100` (first node shown; array continues)

### contracts/examples/edges.json

```json
{
  "format_version": "0.0.0",
  "edges": [
    {
      "from": "exponent-laws",
      "to": "exponential-functions",
      "sources": [
        {
          "tag": "ministry_prereq",
          "origin": "MCR3U-2007"
        },
        {
          "tag": "third_party_structure",
          "origin": "khan-academy"
        }
      ],
      "generation_agreement": 3,
      "confidence": 0.8,
      "probe_stats": {
        "probes": 0,
        "confirmed": 0
      }
    }
  ]
}
```

Source: `contracts/examples/edges.json:1–26`

### contracts/examples/courses.json

```json
{
  "format_version": "0.0.0",
  "courses": [
    {
      "course_code": "MTH1W",
      "name": "Mathematics, Grade 9",
      "vintage": "2021",
      "strands": [
        {
          "code": "B",
          "name": "Number"
        }
      ],
      "expectations": [
        {
          "code": "B3.4",
          "kind": "specific",
          "paraphrase": "Apply the exponent laws to simplify numeric and algebraic expressions.",
          "official_url": "https://dcp.edu.gov.on.ca/en/curriculum/secondary-mathematics/courses/mth1w",
          "unit_id": "MTH1W.u1"
        }
      ],
      "units": [
        {
          "unit_id": "MTH1W.u1",
          "name": "Number sense and exponents",
          "expectation_codes": [
            "B3.4"
          ]
        }
      ],
      "unit_source": {
        "title": "Demo hand-written unit list",
        "edition": "2026"
      },
      "next_courses": [
        "MPM2D"
      ]
    },
    {
      "course_code": "MCR3U",
      "name": "Functions, Grade 11",
      "vintage": "2007",
      "strands": [
        {
          "code": "C",
          "name": "Exponential Functions"
        }
      ],
      "expectations": [
        {
          "code": "C1.1",
          "kind": "specific",
          "paraphrase": "Graph and describe exponential functions and their key properties.",
          "official_url": "https://www.edu.gov.on.ca/eng/curriculum/secondary/math1112currb.pdf",
          "unit_id": "MCR3U.u1"
        }
      ],
      "units": [
        {
          "unit_id": "MCR3U.u1",
          "name": "Exponential functions",
          "expectation_codes": [
            "C1.1"
          ]
        }
      ],
      "next_courses": [
        "MHF4U"
      ]
    }
  ]
}
```

Source: `contracts/examples/courses.json:1–73`

### contracts/examples/landmarks.json

```json
{
  "format_version": "0.0.0",
  "landmarks": [
    {
      "id": "canadian-mortgage-compounding",
      "name": "Canadian fixed-rate mortgages compound semi-annually",
      "what_it_is": "Canada's Interest Act requires that a fixed-rate mortgage state its interest as calculated yearly or half-yearly, not in advance; lenders then convert that semi-annual rate to a monthly one.",
      "source_url": "https://laws-lois.justice.gc.ca/eng/acts/I-15/",
      "node_ids": [
        "exponent-laws",
        "exponential-functions"
      ],
      "region_ids": [
        "number-operations",
        "functions"
      ],
      "position": {
        "x": 0.3,
        "y": 0.15
      }
    }
  ]
}
```

Source: `contracts/examples/landmarks.json:1–23`

### contracts/examples/sources.json

```json
{
  "format_version": "0.0.0",
  "sources": [
    {
      "source": "openstax",
      "title": "College Algebra 2e",
      "edition": "2e (2021)",
      "licence": "CC BY 4.0",
      "attribution": "Access for free at https://openstax.org/books/college-algebra-2e/pages/1-introduction-to-prerequisites",
      "url": "https://openstax.org/details/books/college-algebra-2e"
    }
  ]
}
```

Source: `contracts/examples/sources.json:1–14`

### contracts/examples/student-state.json

```json
{
  "schema_version": 1,
  "format_version_seen": "0.0.0",
  "syllabi": [
    "MCR3U"
  ],
  "marker": {
    "course_code": "MCR3U",
    "unit_id": "MCR3U.u1"
  },
  "nodes": {
    "exponent-laws": {
      "mastery": "cleared",
      "correct_count": 2,
      "last_probe": "2026-09-08",
      "next_due": "2026-09-09",
      "ladder_rung": 0
    },
    "exponential-functions": {
      "mastery": "fog",
      "correct_count": 1,
      "ladder_rung": 0
    }
  },
  "trail": {
    "segments": [
      {
        "kind": "course",
        "course_code": "MCR3U",
        "node_ids": [
          "exponential-functions"
        ]
      }
    ]
  },
  "expedition_log": [
    {
      "day": "2026-09-08",
      "item_count": 5,
      "cleared": 1,
      "blocked": 0,
      "abandoned": false,
      "diagnosis_events": 0
    }
  ],
  "probe_log": [
    {
      "day": "2026-09-08",
      "node_id": "exponent-laws",
      "item_id": "exp-1",
      "correct": true,
      "retry": false
    }
  ],
  "install_day": "2026-09-08",
  "consent_on": true
}
```

Source: `contracts/examples/student-state.json:1–57`

## §F. Error codes binding this task

### contracts/error-codes.json — codes relevant to EPIC 01.01

The following `GRAPH`, `EXP`, `MAP`, and `DIAG` error codes are referenced in contracts and must be present in the `CoreError` enum:

```json
[
  {"code": "MAP_LAYOUT_MISSING", "recoverable": true, "surface": "internal", "user_text": null},
  {"code": "MAP_REGION_UNKNOWN", "recoverable": true, "surface": "internal", "user_text": null},
  {"code": "MAP_LANDMARK_UNSOURCED", "recoverable": true, "surface": "internal", "user_text": null},
  {"code": "GRAPH_L0_FAILED", "recoverable": true, "surface": "internal", "user_text": null},
  {"code": "GRAPH_NO_PREREQUISITE", "recoverable": true, "surface": "internal", "user_text": null},
  {"code": "LO_BAD_DISTRACTOR_TAG", "recoverable": true, "surface": "internal", "user_text": null},
  {"code": "LO_ITEM_UNRENDERABLE", "recoverable": true, "surface": "internal", "user_text": null},
  {"code": "LO_LANDMARK_UNSOURCED", "recoverable": true, "surface": "internal", "user_text": null}
]
```

Source: `contracts/error-codes.json:8–71` (excerpt of binding codes)
Binds this task: `CoreError` enum must include at least these codes; the registry round-trip test verifies no code in enum is absent from the registry.

## §G. Identifier blocklist (from pipeline/tests/test_contracts.py)

```python
IDENTIFIER_BLOCKLIST = {
    "id",
    "install_id",
    "device_id",
    "session_id",
    "user_id",
    "ip",
    "timestamp",
    "email",
    "name",
}
```

Source: `pipeline/tests/test_contracts.py:26–36`
Binds this task: `StudentState` and any state-like JSON must reject these keys (enforced by schema and by Swift test mirroring the Python test).

## §H. Existing Core infrastructure

### Packages/Core/Package.swift

```swift
// swift-tools-version: 6.2
// Core — graph data, L0 validation, layout, scheduler, state transitions (D33).
// Imports Foundation only. No SwiftUI / UIKit / SpriteKit / SwiftData (I14) — asserted by CoreTests.

import PackageDescription

let package = Package(
    name: "Core",
    platforms: [
        .iOS(.v18),  // D34: Doors B/C and Tier 0 diagnosis on iOS/iPadOS 18+
        .macOS(.v15),  // host platform for the CLI target and the pipeline (D42)
    ],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .executable(name: "core-cli", targets: ["CoreCLI"]),
    ],
    targets: [
        .target(
            name: "Core",
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")]
        ),
        .executableTarget(
            name: "CoreCLI",
            dependencies: ["Core"]
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
```

Source: `Packages/Core/Package.swift:1–32`

### Packages/Core/Sources/Core/Core.swift (current)

```swift
import Foundation

/// Core — the renderer-free heart of mathmath (D33, I14).
///
/// Graph data types, L0 validation, layout, the expedition scheduler and student-state transitions
/// live here and only here (D42). This file is the Phase 5 placeholder; the first EPIC replaces it.
public enum CoreInfo {
    /// Semantic version of the shared JSON data formats consumed by `Core` (shared with the Android port).
    public static let dataFormatVersion = "0.0.0"
}
```

Source: `Packages/Core/Sources/Core/Core.swift:1–10`

### Packages/Core/Sources/CoreCLI/main.swift (current)

```swift
import Core
import Foundation

// core-cli — the single entry point through which the Python pipeline invokes `Core` (D42):
// L0 validation and layout precompute. Subcommands are added by the EPICs that ship them.
// Phase 5 placeholder: reports the data-format version so the pipeline↔Core seam is exercisable.

let arguments = CommandLine.arguments.dropFirst()
switch arguments.first {
case "version":
    print(CoreInfo.dataFormatVersion)
default:
    FileHandle.standardError.write(Data("usage: core-cli version\n".utf8))
    exit(2)
}
```

Source: `Packages/Core/Sources/CoreCLI/main.swift:1–16`

### Packages/Core/Tests/CoreTests/CoreTests.swift (current)

```swift
import Foundation
import Testing

@testable import Core

@Suite("Core package")
struct CoreTests {
    @Test("data format version is a semantic version")
    func dataFormatVersion() {
        let parts = CoreInfo.dataFormatVersion.split(separator: ".")
        #expect(parts.count == 3)
        #expect(parts.allSatisfy { Int($0) != nil })
    }

    /// I14 / D33: `Core` imports Foundation only. Scans every source file of the Core target for
    /// forbidden imports; an empty scan is a FAIL (C3), so a moved directory cannot pass silently.
    @Test("Core imports Foundation only (I14)")
    func coreImportBoundary() throws {
        let forbidden = [
            "SwiftUI", "UIKit", "AppKit", "SpriteKit", "SwiftData", "FoundationModels", "CoreData", "Combine",
        ]
        let sourcesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root
            .appendingPathComponent("Sources/Core")
        let files = try FileManager.default.contentsOfDirectory(
            at: sourcesDir, includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "swift" }
        #expect(!files.isEmpty, "no Core source files found — empty scan is a FAIL")
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for line in text.split(separator: "\n") where line.hasPrefix("import ") {
                let module = line.dropFirst("import ".count).trimmingCharacters(in: .whitespaces)
                #expect(!forbidden.contains(module), "\(file.lastPathComponent) imports \(module)")
            }
        }
    }
}
```

Source: `Packages/Core/Tests/CoreTests/CoreTests.swift:1–41`

## §I. Test framework and toolchain

**Test framework:** Swift Testing (`import Testing`) — first-party, used in existing `CoreTests`.

Source: `docs/tech-stack.md:22` and `Packages/Core/Tests/CoreTests/CoreTests.swift:2`

**Swift toolchain:**
- Language mode: Swift 6 (strict concurrency `complete`)
- Tools version: `swift-tools-version: 6.2`
- Local: Swift 6.3.3 (Xcode 26.6, 17F113) on this Mac as of 2026-09-09
- iOS deployment target: 18.0
- macOS deployment target: 15 (host platform for CLI)

Source: `docs/tech-stack.md:13–14` and `Packages/Core/Package.swift:1, 9–12`

**Gate commands (from scripts/gate.sh):**

```sh
# Gate 3 — Core: build + test on the iOS simulator (D29)
( cd "$ROOT/Packages/Core" && swift build -c release --product core-cli )
( cd "$ROOT/Packages/Core" && xcodebuild test -quiet -scheme Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO )
```

Source: `scripts/gate.sh:16–18`

**Simulator:**

`$SIM` is selected by `scripts/pick-simulator.sh`, which chooses the newest available iPhone simulator runtime (override with `MATHMATH_SIM="platform=iOS Simulator,name=…,OS=…"`).

Source: `scripts/gate.sh:6–7` and `docs/tech-stack.md:79`

## §J. Invariants binding this task (verbatim)

### I5 — No PII, no accounts (from CLAUDE.md)

> **No PII, no accounts.** Telemetry is anonymous and aggregate, **on by default with one-tap off, and carries no identifier of any kind** (no install, device or session id); the endpoint retains no IP. Cross-device sync uses Apple-managed identity only.

Source: `CLAUDE.md:28`, decision references D17, D19, D36
Binds this task: `StudentState` type must not include any identifier fields.

### I6 — No verbatim Ministry text (from CLAUDE.md)

> **No verbatim Ministry text** stored or shipped: grade 9–12 nodes carry expectation codes + the project's own `paraphrase`, and link out to the official page; undergraduate nodes carry a `source_ref` into a CC-licensed source with its attribution.

Source: `CLAUDE.md:29`, decision references D18, D2
Binds this task: nodes must not carry a `verbatim` key; `paraphrase` is the project's own wording.

### I14 — Core is renderer-free and single-source (from CLAUDE.md)

> **`Core` is renderer-free and single-source**: `Core` imports Foundation only; the render layer never computes state; L0 and layout exist once, in `Core`. A test asserts the import boundary.

Source: `CLAUDE.md:37`, decision references D33, D42
Binds this task: no imports beyond Foundation in `Core`; existing boundary test in `CoreTests.swift` must pass and must be extended to walk `Sources/Core` recursively for all `.swift` files.

### I15 — Landmarks are real, named, verifiable (from CLAUDE.md)

> **Landmarks are real, named, verifiable things with a resolving `source_url`.** A landmark that cannot be sourced is dropped, never invented.

Source: `CLAUDE.md:38`, decision reference D22
Binds this task: Landmark type must require `source_url` (https); validation at build time is EPIC 01.02's responsibility, but the type must support it.

## §K. Negative facts (confirmed absent)

- No existing `Codable` types in `Core` for bundle files — Glob `Packages/Core/Sources/Core/**/*.swift` returned only `Core.swift`; `Packages/Core/Sources/Core/Model/` directory does not exist.
- No existing error codes enum in `Core` — `Grep "enum CoreError" Packages/` returned no match.
- No BundleIO or manifest verification code in `Core` — Grep `manifest|bundle|sha256` returned no existing implementation.
- No layout precompute or validation function in `Core` — Grep `layout|position|polygon` returned no implementation.
- No L0 validation or constraint checker in `Core` — confirmed by EPIC 01 brief that L0 is task 01.02.

## §L. File scope for this task

Files this task creates:

- CREATE `Packages/Core/Sources/Core/CoreError.swift` — the `CoreError` enum mirroring codes from `contracts/error-codes.json`.
- CREATE `Packages/Core/Sources/Core/Model/Manifest.swift` — `Codable` type for `manifest.json`.
- CREATE `Packages/Core/Sources/Core/Model/Regions.swift` — `Codable` types for `regions.json` and region geometry.
- CREATE `Packages/Core/Sources/Core/Model/Nodes.swift` — `Codable` types for `nodes.json`, including ProbeItem, ErrorType, HintTree, WorkedExample.
- CREATE `Packages/Core/Sources/Core/Model/Edges.swift` — `Codable` types for `edges.json`, including EdgeSource and ProbeStats.
- CREATE `Packages/Core/Sources/Core/Model/Courses.swift` — `Codable` types for `courses.json`, including Unit, Expectation, Strand.
- CREATE `Packages/Core/Sources/Core/Model/Landmarks.swift` — `Codable` types for `landmarks.json`.
- CREATE `Packages/Core/Sources/Core/Model/Sources.swift` — `Codable` types for `sources.json`, including source references.
- CREATE `Packages/Core/Sources/Core/Model/StudentState.swift` — `Codable` type for `student-state.json`, with the I5 identifier blocklist guard.
- CREATE `Packages/Core/Sources/Core/BundleIO.swift` — deterministic bundle directory read/write; SHA256 hash verification against manifest.
- CREATE `Packages/Core/Tests/CoreTests/DecodeRoundTripTests.swift` — decode every example file, re-encode, verify JSON equality (modulo key order).
- CREATE `Packages/Core/Tests/CoreTests/ErrorRegistryTests.swift` — verify `CoreError` cases ⊆ registry; every code in registry that applies to Core must have a corresponding enum case.
- MODIFY `Packages/Core/Tests/CoreTests/CoreTests.swift` — extend `coreImportBoundary()` to walk `Sources/Core` recursively for all `.swift` files (current implementation assumes flat directory).

## §M. Stack constraints for this task

**Swift version and strict mode:** Swift 6, strict concurrency `complete`, as locked in `docs/tech-stack.md:13`.

Source: `docs/tech-stack.md:13` and `Packages/Core/Package.swift:31`

**Foundation-only constraint:** `Core` must import `Foundation` only; no SwiftUI, UIKit, AppKit, SpriteKit, SwiftData, FoundationModels, CoreData, or Combine.

Source: `CLAUDE.md:9` (I14), `docs/tech-stack.md:17` and existing `CoreTests.coreImportBoundary()` test.

**Identifier blocklist for Swift mirror test:**

```swift
IDENTIFIER_BLOCKLIST = {
    "id",
    "install_id",
    "device_id",
    "session_id",
    "user_id",
    "ip",
    "timestamp",
    "email",
    "name",
}
```

Source: `pipeline/tests/test_contracts.py:26–36`
Binds this task: a Swift test must verify that `StudentState` schema rejects any object containing these keys (mirrors the Python test).

**Format version constant:** `CoreInfo.dataFormatVersion = "0.0.0"` (current); task must preserve this.

Source: `Packages/Core/Sources/Core/Core.swift:9`

---

End of context bundle.
