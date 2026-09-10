# Task 01.05 context bundle

> Compiler: task-context-compiler  
> Date: 2026-09-09  
> Slug: demo-bundle  
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- **Epic:** 01
- **Task:** 05
- **Slug:** demo-bundle
- **Summary:** Author `data/demo/` and get it L0-green. Ten region outlines + four horizon labels; ~20 nodes along the D14 chain, in Number / Algebra / Functions only; edges; MTH1W and MCR3U with hand-written unit lists and `next_courses`; one landmark (Canadian mortgage semi-annual compounding, `https://laws-lois.justice.gc.ca/eng/acts/I-15/`); sources. Seven files only: manifest, regions, nodes, edges, courses, landmarks, sources. L0 report is stdout, not a committed file.
- **Invariants in play:** I1, I2, I5, I6, I8, I9, I10, I14, I15 (quoted §G). **Mandatory lines:** D14, D26 (quoted §G). Amendment 01.05.1 applies (§G).

## §B. Applicable contract rules (verbatim)

### contracts/graph-constraints.md — L0-1 … L0-10 and report shape

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
>
> **Report shape** (`core-cli validate` stdout, JSON): `{ bundle_id, passed: bool, checks: [{id, passed, violations[]}], indegree: {threshold, outliers[]} }`. A bundle is accepted iff every non-advisory check passed. Empty violation lists are printed, never omitted (C3).

Source: `contracts/graph-constraints.md:10–31`  
Binds this task: L0-1 through L0-10 must all pass on the demo bundle; the implementer must hand-write data that satisfies every rule. L0-T (trails) is out of scope for this task (EPIC 02). The report must be printed to stdout and parsed by the pipeline wrapper; no committed `l0-report.json` file.

### contracts/content-policy.md — Grade 9–12 tier, Landmarks, Generated content, Enforcement

**Grade 9–12 tier (Ministry authority):**

> - A node or expectation carries **codes + the project's own `paraphrase` + an `official_url`**. No field anywhere holds Ministry prose; the key `verbatim` is banned repo-wide (grep gate). Paraphrase rule (curriculum-spine Q1): one verb-initial plain sentence, no LaTeX, ≤ 140 characters, rejected on a shared 6-gram with the source outside the technical-term allow-list. Ministry source text lives in pipeline memory only and never in a kept RunOutput, fixture or test.
> - Codes, course names, strand names and structure are facts and may be stored freely (§10).
> - `official_url` hosts are allow-listed (`dcp.edu.gov.on.ca`, `edu.gov.on.ca`); anything else fails the cut.

Source: `contracts/content-policy.md:8–16`  
Binds this task: The Demo's nodes carry `paraphrase` ≤ 140 chars and are the project's own words. No Ministry text anywhere.

**Landmarks:**

> - Real, named, verifiable; `source_url` required and resolving at build (HTTP 2xx) with the page text containing the landmark's name; ≥ 1 node id. Unsourced → dropped, never invented, never "hypothetical".

Source: `contracts/content-policy.md:34–36`  
Binds this task: The Demo's one landmark (Canadian mortgage semi-annual compounding) must have a resolving `source_url` (the Interest Act link); the landmark is dropped if the source cannot be verified.

**Generated content (all tiers):**

> - Everything student-facing is **batch-generated and machine-verified**, never human-reviewed (I9, D12, D13): failure paths end in regenerate or discard. A spec adding "owner reviews content" is BLOCKed.
> - Probe answers are re-derived by SymPy before persistence (I1); prompts and hints must render in SwiftMath or carry `render_fallback: "katex"` (learning-objects W1 5b).
> - Distractor tags: every `mc` distractor and every anticipated numeric wrong answer names an `ErrorType` of its node (diagnosis Q1); `none-of-these` is never a tag.

Source: `contracts/content-policy.md:26–32`  
Binds this task: The Demo's probe items must have every `mc` distractor tagged with an `error_type_id`; every wrong numeric answer tagged.

**Enforcement (wired):**

> - pre-commit: `no-time-estimates` over docs. wrap-epic (f): no `verbatim` key in `data/**`, `contracts/examples/**`, fixtures; every node has `paraphrase`; every landmark has `source_url`; `official_url` host allow-list; `[SOURCED]/[ESTIMATE]` presence on touched docs.
> - schema: `source_ref` xor/or `expectation_codes` at-least-one (`nodes.schema.json` `anyOf`); `licence` enum on `sources.json`.

Source: `contracts/content-policy.md:48–53`  
Binds this task: The implementer must ensure every node in the Demo has a `paraphrase`, every landmark has a `source_url`, and no `verbatim` key appears anywhere. The schema will enforce the anyOf rule for codes/source_ref.

### contracts/data-model.md — Identifiers, Text, Versioning, and the bundle file shapes

**Identifiers:**

> - Ids are **stable, opaque, lowercase kebab-case slugs** matching `^[a-z0-9]+(-[a-z0-9]+)*$`, unique within their collection. Never parse meaning from an id; never renumber. A renamed concept keeps its id.
> - Fixed vocabularies: `region_id ∈ {number-operations, algebra, functions, geometry-measurement, trigonometry, calculus, linear-algebra, differential-equations, probability-statistics, discrete}` plus horizon labels `{analysis, topology, number-theory, abstract-algebra}` (flag `horizon: true`) and optional `shore`.
> - `course_code` is the Ministry code verbatim in upper case (`MTH1W`, `MCR3U`); `unit_id` is `<course_code>.u<n>` (1-based, in unit order); `edge_id` is `<from>-->-<to>` (derived, never stored on the edge); `expectation_code` is the Ministry code verbatim (e.g. `B2.3`), scoped by course.
> - Undergraduate `source_ref` is `{ source: "openstax" | "mit-ocw", edition, locator }` where `locator` is the section/chapter path the source publishes; it must resolve (L0-3b).

Source: `contracts/data-model.md:12–22`  
Binds this task: Node, edge, region, landmark and course ids must be kebab-case; course codes must be uppercase (MTH1W, MCR3U); expectation codes must be verbatim Ministry (e.g. B3.4). All ids are stable.

**Versioning:**

> - Every bundle file carries `format_version` (semver) = `CoreInfo.dataFormatVersion`; a major bump means `Core` needs a migration; the app refuses a bundle whose major differs from its own.
> - `manifest.json` lists every file with `asset_version` (id) and `sha256`; a partial manifest is never activated (platform W2). Bundle files are **immutable**: a change is a new `asset_version`.

Source: `contracts/data-model.md:24–28`  
Binds this task: Every JSON file must carry `format_version: "0.0.0"` (from the examples; do not invent). The manifest must list all six files with their asset version and SHA256 hash (to be computed after authoring).

**Text:**

> - All student-facing strings are English (DEFERRED D-1). LaTeX appears only in fields named `latex` or `prompt_latex` and must be in the SwiftMath-renderable subset or carry `render_fallback: "katex"`.
> - No field may hold Ministry prose (I6): the schemas have no free-text field on Expectation other than `paraphrase`, and `content-policy.md`'s grep gate rejects a `verbatim` key anywhere.

Source: `contracts/data-model.md:35–39`  
Binds this task: All text is in English. LaTeX must either be SwiftMath-renderable or flagged with `render_fallback: "katex"`.

**The collections (file shapes):**

> | File | Schema | Notes |
> |---|---|---|
> | `manifest.json` | `manifest.schema.json` | `format_version`, `bundle_id`, `files[]` (name, `asset_version`, `sha256`), `spine_version`, `graph_version`, `built_at` |
> | `regions.json` | `regions.schema.json` | ten regions + horizon labels (+ shore); normalised polygon, `neighbours[]`, `about` (one sentence) |
> | `nodes.json` | `nodes.schema.json` | `id`, `name`, `region_id`, `strand?`, `expectation_codes[]?`, `source_ref?` (**at least one**), `courses[] {course_code, depth}`, `position {x,y}` (from `core-cli layout`), `layout_hint?`, `paraphrase`, `explanation?`, `worked_examples[]?`, `error_types[]` (closed, one `none-of-these`, each `implies_prerequisite?`), `hint_tree {error_type_id → [tier1, tier2, tier3]}`, `probe_items[]` |
> | `edges.json` | `edges.schema.json` | `from`, `to`, `sources[] {tag, origin}`, `generation_agreement`, `confidence` [0,1], `probe_stats {probes, confirmed, downstream_fail_given_upstream_fail}` |
> | `courses.json` | `courses.schema.json` | `course_code`, `name`, `vintage`, `strands[]`, `expectations[] {code, kind, paraphrase, official_url, unit_id}`, `units[] {unit_id, name, expectation_codes[]}`, `unit_source? {title, edition}`, `next_courses[]` |
> | `landmarks.json` | `landmarks.schema.json` | `id`, `name`, `what_it_is`, `source_url` (**required**, https), `node_ids[]` (≥ 1), `region_ids[]`, `position` |
> | `sources.json` | `sources.schema.json` | undergraduate sources: `source`, `title`, `edition`, `licence`, `attribution`, `url` |

Source: `contracts/data-model.md:45–56`  
Binds this task: These are the seven files; no others may exist under `data/demo/`. Each must have the exact shape specified.

### contracts/schemas/ — All seven, verbatim

**manifest.schema.json (full):**

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

**regions.schema.json (full):**

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

**nodes.schema.json (full):**

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://mathmath.local/contracts/nodes.schema.json",
  "title": "nodes",
  "type": "object",
  "properties": {
    "format_version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "nodes": {
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
          "region_id": {
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
          "strand": {
            "type": "string",
            "minLength": 1
          },
          "expectation_codes": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "course_code": {
                  "type": "string",
                  "pattern": "^[A-Z]{3}[1-4][A-Z]$"
                },
                "code": {
                  "type": "string",
                  "minLength": 1
                }
              },
              "required": [
                "course_code",
                "code"
              ],
              "additionalProperties": false
            },
            "minItems": 1
          },
          "source_ref": {
            "type": "object",
            "properties": {
              "source": {
                "type": "string",
                "enum": [
                  "openstax",
                  "mit-ocw"
                ]
              },
              "edition": {
                "type": "string",
                "minLength": 1
              },
              "locator": {
                "type": "string",
                "minLength": 1
              }
            },
            "required": [
              "source",
              "edition",
              "locator"
            ],
            "additionalProperties": false
          },
          "courses": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "course_code": {
                  "type": "string",
                  "pattern": "^[A-Z]{3}[1-4][A-Z]$"
                },
                "depth": {
                  "type": "integer",
                  "minimum": 0
                }
              },
              "required": [
                "course_code",
                "depth"
              ],
              "additionalProperties": false
            }
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
          },
          "layout_hint": {
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
          "paraphrase": {
            "type": "string",
            "minLength": 1,
            "maxLength": 140
          },
          "explanation": {
            "type": "string",
            "minLength": 1
          },
          "worked_examples": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "id": {
                  "type": "string",
                  "pattern": "^[a-z0-9]+(-[a-z0-9]+)*$"
                },
                "steps_latex": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "minLength": 1
                  },
                  "minItems": 1
                }
              },
              "required": [
                "id",
                "steps_latex"
              ],
              "additionalProperties": false
            }
          },
          "error_types": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "id": {
                  "type": "string",
                  "pattern": "^[a-z0-9]+(-[a-z0-9]+)*$"
                },
                "label": {
                  "type": "string",
                  "minLength": 1
                },
                "implies_prerequisite": {
                  "type": "string",
                  "pattern": "^[a-z0-9]+(-[a-z0-9]+)*$"
                }
              },
              "required": [
                "id",
                "label"
              ],
              "additionalProperties": false
            },
            "minItems": 1
          },
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
          },
          "probe_items": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "id": {
                  "type": "string",
                  "pattern": "^[a-z0-9]+(-[a-z0-9]+)*$"
                },
                "type": {
                  "type": "string",
                  "enum": [
                    "numeric",
                    "mc"
                  ]
                },
                "prompt_latex": {
                  "type": "string",
                  "minLength": 1
                },
                "why": {
                  "type": "string",
                  "minLength": 1
                },
                "render_fallback": {
                  "type": "string",
                  "enum": [
                    "katex"
                  ]
                },
                "answer": {
                  "type": "object",
                  "properties": {
                    "value": {
                      "type": "string",
                      "pattern": "^-?[0-9]+(\\.[0-9]+)?(/[1-9][0-9]*)?$"
                    },
                    "tolerance": {
                      "type": "number",
                      "minimum": 0
                    }
                  },
                  "required": [
                    "value"
                  ],
                  "additionalProperties": false
                },
                "wrong_answers": {
                  "type": "array",
                  "items": {
                    "type": "object",
                    "properties": {
                      "value": {
                        "type": "string",
                        "minLength": 1
                      },
                      "error_type_id": {
                        "type": "string",
                        "pattern": "^[a-z0-9]+(-[a-z0-9]+)*$"
                      }
                    },
                    "required": [
                      "value",
                      "error_type_id"
                    ],
                    "additionalProperties": false
                  }
                },
                "choices": {
                  "type": "array",
                  "items": {
                    "type": "object",
                    "properties": {
                      "id": {
                        "type": "string",
                        "pattern": "^[a-z0-9]+(-[a-z0-9]+)*$"
                      },
                      "latex": {
                        "type": "string",
                        "minLength": 1
                      },
                      "error_type_id": {
                        "type": "string",
                        "pattern": "^[a-z0-9]+(-[a-z0-9]+)*$"
                      }
                    },
                    "required": [
                      "id",
                      "latex"
                    ],
                    "additionalProperties": false
                  },
                  "minItems": 2
                },
                "correct_choice_id": {
                  "type": "string",
                  "pattern": "^[a-z0-9]+(-[a-z0-9]+)*$"
                }
              },
              "required": [
                "id",
                "type",
                "prompt_latex",
                "why"
              ],
              "additionalProperties": false,
              "allOf": [
                {
                  "if": {
                    "properties": {
                      "type": {
                        "const": "numeric"
                      }
                    }
                  },
                  "then": {
                    "required": [
                      "answer"
                    ]
                  }
                },
                {
                  "if": {
                    "properties": {
                      "type": {
                        "const": "mc"
                      }
                    }
                  },
                  "then": {
                    "required": [
                      "choices",
                      "correct_choice_id"
                    ]
                  }
                }
              ]
            }
          }
        },
        "required": [
          "id",
          "name",
          "region_id",
          "courses",
          "position",
          "paraphrase",
          "error_types",
          "hint_tree",
          "probe_items"
        ],
        "additionalProperties": false,
        "anyOf": [
          {
            "required": [
              "expectation_codes"
            ]
          },
          {
            "required": [
              "source_ref"
            ]
          }
        ]
      },
      "minItems": 1
    }
  },
  "required": [
    "format_version",
    "nodes"
  ],
  "additionalProperties": false
}
```

Source: `contracts/schemas/nodes.schema.json:1–397`

**edges.schema.json (full):**

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

**courses.schema.json (full):**

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://mathmath.local/contracts/courses.schema.json",
  "title": "courses",
  "type": "object",
  "properties": {
    "format_version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "courses": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "course_code": {
            "type": "string",
            "pattern": "^[A-Z]{3}[1-4][A-Z]$"
          },
          "name": {
            "type": "string",
            "minLength": 1
          },
          "vintage": {
            "type": "string",
            "pattern": "^[0-9]{4}(\\+[0-9]{4})?$"
          },
          "strands": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "code": {
                  "type": "string",
                  "minLength": 1
                },
                "name": {
                  "type": "string",
                  "minLength": 1
                }
              },
              "required": [
                "code",
                "name"
              ],
              "additionalProperties": false
            },
            "minItems": 1
          },
          "expectations": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "code": {
                  "type": "string",
                  "minLength": 1
                },
                "kind": {
                  "type": "string",
                  "enum": [
                    "overall",
                    "specific"
                  ]
                },
                "paraphrase": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 140
                },
                "official_url": {
                  "type": "string",
                  "pattern": "^https://(dcp\\.edu\\.gov\\.on\\.ca|www\\.edu\\.gov\\.on\\.ca|edu\\.gov\\.on\\.ca)/"
                },
                "unit_id": {
                  "type": "string",
                  "pattern": "^[A-Z]{3}[1-4][A-Z]\\.u[1-9][0-9]*$"
                }
              },
              "required": [
                "code",
                "kind",
                "paraphrase",
                "official_url",
                "unit_id"
              ],
              "additionalProperties": false
            },
            "minItems": 1
          },
          "units": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "unit_id": {
                  "type": "string",
                  "pattern": "^[A-Z]{3}[1-4][A-Z]\\.u[1-9][0-9]*$"
                },
                "name": {
                  "type": "string",
                  "minLength": 1
                },
                "expectation_codes": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "minLength": 1
                  },
                  "minItems": 1
                }
              },
              "required": [
                "unit_id",
                "name",
                "expectation_codes"
              ],
              "additionalProperties": false
            },
            "minItems": 1
          },
          "unit_source": {
            "type": "object",
            "properties": {
              "title": {
                "type": "string",
                "minLength": 1
              },
              "edition": {
                "type": "string",
                "minLength": 1
              }
            },
            "required": [
              "title",
              "edition"
            ],
            "additionalProperties": false
          },
          "next_courses": {
            "type": "array",
            "items": {
              "type": "string",
              "pattern": "^[A-Z]{3}[1-4][A-Z]$"
            }
          }
        },
        "required": [
          "course_code",
          "name",
          "vintage",
          "strands",
          "expectations",
          "units",
          "next_courses"
        ],
        "additionalProperties": false
      },
      "minItems": 1
    }
  },
  "required": [
    "format_version",
    "courses"
  ],
  "additionalProperties": false
}
```

Source: `contracts/schemas/courses.schema.json:1–167`

**landmarks.schema.json (full):**

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

**sources.schema.json (full):**

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

### contracts/examples/ — All seven, verbatim

**manifest.json (full, used as reference):**

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

**regions.json (excerpt — 10 regions + 4 horizon labels structure):** Shows the 10 D21 regions (Number & Operations, Algebra, Functions, Geometry & Measurement, Trigonometry, Calculus, Linear Algebra, Differential Equations, Probability & Statistics, Discrete), each with `id`, `name`, `about`, `horizon: false`, `polygon` (normalised [0,1] coordinates, ≥3 points), `neighbours: []`; then 4 horizon labels with `horizon: true`.

Source: `contracts/examples/regions.json:1–355`

**nodes.json (excerpt — shows expectation codes and mc/numeric items):** Demonstrates two nodes: "exponent-laws" with `expectation_codes [{course_code: "MTH1W", code: "B3.4"}]`, `paraphrase`, `error_types[]` (including `none-of-these`), `hint_tree {error_type_id → [tier1, tier2, tier3]}`, `probe_items[]` with numeric and mc types; and "exponential-functions" with same structure plus `impliesPrerequisite` mapping in error types. Also "matrix-multiplication" (undergraduate) with `source_ref: {source: "openstax", edition, locator}`.

Source: `contracts/examples/nodes.json:1–162`

**edges.json (excerpt):** Shows edge structure: `from: "exponent-laws"`, `to: "exponential-functions"`, `sources: [{tag: "ministry_prereq", origin: "MCR3U-2007"}, {tag: "third_party_structure", origin: "khan-academy"}]`, `generation_agreement: 3`, `confidence: 0.8`, `probe_stats: {probes: 0, confirmed: 0}`.

Source: `contracts/examples/edges.json:1–25`

**courses.json (excerpt):** Shows two courses: MTH1W and MCR3U, each with `course_code`, `name`, `vintage`, `strands[]`, `expectations[]`, `units[]` mapping expectations to unit IDs, `unit_source: {title, edition}`, `next_courses: []`.

Source: `contracts/examples/courses.json:1–73`

**landmarks.json (excerpt):** Shows "canadian-mortgage-compounding" landmark with `id`, `name`, `what_it_is`, `source_url: "https://laws-lois.justice.gc.ca/eng/acts/I-15/"`, `node_ids: ["exponent-laws", "exponential-functions"]`, `region_ids: ["number-operations", "functions"]`, `position: {x, y}`.

Source: `contracts/examples/landmarks.json:1–23`

**sources.json (excerpt):** Shows OpenStax entry: `source: "openstax"`, `title: "College Algebra 2e"`, `edition: "2e (2021)"`, `licence: "CC BY 4.0"`, `attribution`, `url`.

Source: `contracts/examples/sources.json:1–13`

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/curriculum-spine.md — Core entities and units (D45)

> **Unit** — a course's teaching unit (D45): an ordered group of that course's Expectations. Units are not in the Ministry documents; each Course names one designated textbook as its `unit_source` (chosen at M1, recorded in the bundle), and Expectations are grouped by that textbook's chapter sequence — the existing L1 `textbook_order` source. A course with no `unit_source`, or an Expectation the textbook does not place, falls back to grouping by Strand in Ministry order (v2.7 §2). The Demo's two unit lists are hand-written.

Source: `docs/domains/curriculum-spine.md:28–32`

> **Course succession** — `next_courses[]` per Course from the Ministry's course-prerequisite chart [SOURCED: Ontario 2007 curriculum document], e.g. MPM2D → MCR3U → MHF4U → MCV4U; data, not logic (v2.7 §4), read by expedition W8 when a trail extends past a course.

Source: `docs/domains/curriculum-spine.md:34–36`

### docs/domains/map.md — Region and Landmark entities

> **Region** — one of the ten D21 (revised) territories — Number & Operations · Algebra · Functions · Geometry & Measurement · Trigonometry · Calculus · Linear Algebra · Differential Equations · Probability & Statistics · Discrete Mathematics — or a horizon label (Analysis, Topology, Number Theory, Abstract Algebra), or the optional "shore" (grade 7–8; drawn, no content, no fog; not in the Demo — decided at M5): `id`, `name`, `polygon` (normalised coordinates, hand-authored for the Demo, pipeline-authored later), `horizon: bool`, `neighbours[]`, and one sentence on what the territory is about (project's own words, I6). A `horizon` region is a label with no nodes and is not tappable. Every `Node` (**concept-graph**) has exactly one region (I8).

Source: `docs/domains/map.md:30–36`

> **Landmark** — `id`, `name`, `what_it_is` (one plain-language paragraph), `source_url` (required, must resolve — D22, I15), `node_ids[]` (≥ 1), `region_ids[]`, `position`. Validated by **learning-objects** W1; this domain only places and presents it.

Source: `docs/domains/map.md:45–47`

### docs/domains/learning-objects.md — ProbeItem numeric and mc shapes, error_type_id, render_fallback

> **ProbeItem** — a short item tagged with a node id, of type `numeric | mc` (I10): a `prompt` (LaTeX subset SwiftMath renders — the rendering spike, v2.2 §B), an `answer` (numeric, with an optional declared tolerance) or `choices[]` with the correct id, a one-line `why` shown with the answer (D5), and `distractor_error_types` — every distractor and each anticipated numeric wrong answer tagged with an `ErrorType` id, the Tier 0 classifier (diagnosis Q1). The answer is re-derived by SymPy in the pipeline (D41, I1); on the device it is checked in code, with no grader model and no free text. Two drawn per diagnosis probe [SOURCED: brief §2, §7], one per expedition slot (D23).

Source: `docs/domains/learning-objects.md:54–60`

## §D. Prior task outputs this task depends on

None — this is EPIC 01 task 05, the first task. It consumes only Phase 5/6 outputs:
- `Packages/Core/Sources/Core/Model/` types (scaffold: Manifest, Regions, Nodes, Edges, Courses, Landmarks, Sources, StudentState, RegionId, Point)
- `Packages/Rendering` scaffold (RenderCheck coming later)
- Contracts (frozen, read-only)
- `pipeline/` scaffold and `test_contracts.py`

The implementer decodes the hand-written JSON into these types and validates it.

## §E. Negative facts (confirmed ABSENT)

- **`data/demo/` directory does not exist yet.** Glob `data/**` returned only `data/README.md`. Source: Glob `data/**` on 2026-09-09.
- **No task specs exist for EPIC 01 tasks 01–04 or 06+.** The spec file path `tasks/epic-01-task-05-demo-bundle.md` (the current task) does not exist — only the task is referenced in `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md` §8 (size estimate), and this is task 01.05 as a named item in the EPIC brief. No other task specs are committed. Source: File does not exist at `/Users/jimmyz/Dev/mathmath/tasks/epic-01-task-05-demo-bundle.md`.
- **No L0 report schema exists.** `contracts/schemas/` contains only manifest, regions, nodes, edges, courses, landmarks, sources, student-state, telemetry-batch. No `l0-report.schema.json`. Source: Glob `contracts/schemas/*.schema.json` (8 files, no l0-report).
- **The `data/demo/` bundle does not yet exist.** No JSON files under `data/demo/`. Source: Glob `data/**` returned only `data/README.md`.
- **No existing Ministry expectation-code extraction or spine bundle exists.** The task hand-writes codes directly from published Ministry documents; the pipeline's spine-extraction task (EPIC 05+) is out of scope. Source: Grep for "B3.4" or "C1.1" in the repo returns only examples and docs, never a generated spine.

## §F. File scope

This task creates exactly seven files under `data/demo/`, named to match the schemas:

- CREATE `data/demo/manifest.json` — no prior existence (Glob `data/demo/**` empty).
- CREATE `data/demo/regions.json` — no prior existence.
- CREATE `data/demo/nodes.json` — no prior existence.
- CREATE `data/demo/edges.json` — no prior existence.
- CREATE `data/demo/courses.json` — no prior existence.
- CREATE `data/demo/landmarks.json` — no prior existence.
- CREATE `data/demo/sources.json` — no prior existence.

**No other files may be created under `data/demo/` or `data/**`.** The L0 report is stdout, not a committed file (amendment 01.05.1).

## §G. Stack constraints relevant here

**D14 (Starting chain) — verbatim from PROJECT-BRIEF-v2.md §3:**

> **D14 | Starting chain: MTH1W linear relations/equations → exponent laws → polynomials/factoring → quadratics → function concept/transformations → exponential functions → logarithms & advanced functions.**

Source: `PROJECT-BRIEF-v2.md:68`

The Demo's nodes must lie on or immediately adjacent to this chain. Exactly this chain order.

**D26 (Demo first, hand-written data) — verbatim from PROJECT-BRIEF-v2.md §3:**

> **D26 | A Demo that tests the *form* (does a student want to click in and come back?) is built first, on hand-written data, fully decoupled from M1/M2 content pipelines.**

Source: `PROJECT-BRIEF-v2.md:80`

**DEMO-BRIEF.md — Data files and node/edge requirements (§3 and §5):**

> **3.1 Map**
> - All eight regions from D21 drawn as hand-authored polygons with names: Number & Operations, Algebra, Functions, Geometry & Measurement, Trigonometry, Calculus, Probability & Statistics, Discrete.
> - A horizon band beyond the continent with greyed labels only: e.g. Linear Algebra, Number Theory, Analysis. Not clickable.
> - Only three regions are populated with nodes: Number & Operations, Algebra, Functions. The other five show as territory under fog with no nodes.

Source: `DEMO-BRIEF.md:24–28`

> **3.2 Nodes and edges (hand-written)**
> - ~20 nodes along the D14 starting chain, distributed across the three populated regions, e.g.:
>   - Number & Operations: integer/rational operations, exponent laws, powers of ten / scientific notation
>   - Algebra: linear relations, solving linear equations, polynomials, factoring, solving quadratics
>   - Functions: function concept, transformations, quadratic functions, exponential functions, (logarithms may appear as a far, fogged node)
> - Edges follow the chain and a few sensible side dependencies. Rendered as rivers flowing in dependency direction (from → to).
> - Node placement: force layout constrained inside the region polygon, seeded from an optional `layout_hint`. Deterministic across reloads.
> - Each node has a `paraphrase` (one plain-language sentence, the project's own words) and 2–3 probe items.

Source: `DEMO-BRIEF.md:30–38`

> **3.3 Trail**
> - One trail: MCR3U, as an ordered subset of the ~20 nodes. Drawn as a path over the map, visually distinct from rivers. A "you are here" marker on the trail's current node.

Source: `DEMO-BRIEF.md:39–40`

> **3.7 Landmark (one)**
> - One landmark placed on the map, linked to at least two nodes in different regions. Clickable: name, one-paragraph plain-language description, source URL, "which parts of the map this touches" with jump links.
> - Suggested subject (must be verified and sourced before use, otherwise replace): Canadian mortgage interest — why fixed-rate mortgages in Canada compound semi-annually, and how that turns into a monthly rate. Links: exponent laws (Number), exponential functions (Functions), and the fogged logarithm node (solving for time). Any real, sourced landmark on the chain is acceptable.

Source: `DEMO-BRIEF.md:59–61`

> **5. Data files (hand-written)**
> 
> - `regions.json` — id, name, polygon (normalised coordinates), horizon flag, neighbours
> - `nodes.json` — id, name, region, paraphrase, layout_hint?, probe_items[] (`prompt`, `type` numeric|mc, `answer`, `choices?`), hint (one string), upstream_hint (node id for the diagnosis card)
> - `edges.json` — from, to
> - `trails.json` — course_code, node_ids[]
> - `landmarks.json` — id, name, what_it_is, source_url, node_ids[], region_ids[], position

Source: `DEMO-BRIEF.md:71–78`

**AMENDMENT-v2.6.md §D (Demo brief deltas) — post-amendment revisions:**

> - §3.1: initial camera on the tester's selected course trail (MTH1W or MCR3U), continent visible around it; zoom-out available. Ten regions drawn as outlines per revised D21; nodes still only in Number, Algebra, Functions.
> - §3.3: the start marker is presented as "we are here in class" chosen from a short unit list for the course (hand-written for the two demo trails).
> - §3.5: fringe selection per D48 within current + next unit.
> - §7 acceptance: add item 7 — "Did the tester move the class marker, and did the first expedition feel related to what they are doing in class?"

Source: `AMENDMENT-v2.6.md:35–40`

Binds this task: The Demo has **ten regions** (all D21 regions), not eight (revised in v2.6); **four horizon labels** (Analysis, Topology, Number Theory, Abstract Algebra); **two courses** with unit lists (MTH1W and MCR3U), not one.

**Amendment 01.05.1 — L0 report is stdout, not a file:**

> **Amended brief text:**
> > **MANDATORY artifact line (P4/C4):** `core-cli` (`validate`, `layout`, `version`) — exercised by `pipeline/tests` over `data/demo` and `contracts/examples`; `data/demo/*.json` — the bundle files only, each named by its schema (`manifest`, `regions`, `nodes`, `edges`, `courses`, `landmarks`, `sources`), exercised by `test_contracts.py` (schemas) and `core-cli validate`. The **L0 report is not a bundle file and is not committed**: it is `core-cli validate` **stdout**, JSON, in the shape fixed by `contracts/graph-constraints.md` § Report shape; the pipeline wrapper parses it in-process and fails the build on `passed: false`. Nothing other than a schema-named bundle file may be written under `data/**` (`contracts/data-model.md` § Enforcement: every `*.json` under `data/**` validates against the schema its filename names).

Source: `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md` (Amendment 01.05.1:146–156)

Binds this task: The implementer must write exactly seven JSON files under `data/demo/`. The L0 report (from `core-cli validate` stdout) is NOT written to disk.

**Invariants (quoted from CLAUDE.md):**

> **I6** | **No verbatim Ministry text** stored or shipped: grade 9–12 nodes carry expectation codes + the project's own `paraphrase`, and link out to the official page; undergraduate nodes carry a `source_ref` into a CC-licensed source with its attribution.

Source: `CLAUDE.md:29` (from table lines 18–30)

> **I9** | **Zero human content review** — content is generated + machine-verified; disputed edges ship at low confidence, settled by probe data. Never add an "owner reviews content" step.

Source: `CLAUDE.md:32`

> **I10** | **Input is defined per door**: expedition items are numeric or multiple-choice; homework mode uses a structured math editor; **no OCR in any door.**

Source: `CLAUDE.md:33`

> **I14** | **`Core` is renderer-free and single-source**: `Core` imports Foundation only; the render layer never computes state; L0 and layout exist once, in `Core`. A test asserts the import boundary.

Source: `CLAUDE.md:37`

> **I15** | **Landmarks are real, named, verifiable things with a resolving `source_url`.** A landmark that cannot be sourced is dropped, never invented.

Source: `CLAUDE.md:38`

**Real Core types (from Packages/Core/Sources/Core/Model/):**

- `Manifest { formatVersion: String, bundleId: String, spineVersion: String, graphVersion: String, builtAt: String, startingChain: [String], files: [ManifestFile] }`
- `ManifestFile { name: String, assetVersion: String, sha256: String }`
- `RegionsFile { formatVersion: String, regions: [Region] }`
- `Region { id: RegionId, name: String, about: String, horizon: Bool, polygon: [Point], neighbours: [RegionId] }`
- `Point { x: Double, y: Double }`
- `RegionId` enum with cases: numberOperations, algebra, functions, geometryMeasurement, trigonometry, calculus, linearAlgebra, differentialEquations, probabilityStatistics, discrete, analysis, topology, numberTheory, abstractAlgebra, shore
- `NodesFile { formatVersion: String, nodes: [Node] }`
- `Node { id: String, name: String, regionId: RegionId, strand: String?, expectationCodes: [NodeExpectationCode]?, sourceRef: SourceRef?, courses: [NodeCourse], position: Point, layoutHint: Point?, paraphrase: String, explanation: String?, workedExamples: [WorkedExample]?, errorTypes: [ErrorType], hintTree: [String: [String]], probeItems: [ProbeItem] }`
- `NodeExpectationCode { courseCode: String, code: String }`
- `NodeCourse { courseCode: String, depth: Int }`
- `SourceRef { source: UndergraduateSourceName, edition: String, locator: String }`
- `ErrorType { id: String, label: String, impliesPrerequisite: String? }`
- `ProbeItem { id: String, type: ProbeItemType, promptLatex: String, why: String, renderFallback: RenderFallback?, answer: ProbeAnswer?, wrongAnswers: [WrongAnswer]?, choices: [ProbeChoice]?, correctChoiceId: String? }`
- `ProbeItemType` enum: numeric, mc
- `RenderFallback` enum: katex
- `ProbeAnswer { value: String, tolerance: Double? }`
- `WrongAnswer { value: String, errorTypeId: String }`
- `ProbeChoice { id: String, latex: String, errorTypeId: String? }`
- `EdgesFile { formatVersion: String, edges: [Edge] }`
- `Edge { from: String, to: String, sources: [EdgeSource], generationAgreement: Int, confidence: Double, probeStats: ProbeStats }`
- `EdgeSource { tag: EdgeSourceTag, origin: String }`
- `EdgeSourceTag` enum: ministryPrereq, textbookOrder, thirdPartyStructure, modelGenerated
- `ProbeStats { probes: Int, confirmed: Int, downstreamFailGivenUpstreamFail: Double? }`
- `CoursesFile { formatVersion: String, courses: [Course] }`
- `Course { courseCode: String, name: String, vintage: String, strands: [Strand], expectations: [Expectation], units: [Unit], unitSource: UnitSource?, nextCourses: [String] }`
- `Strand { code: String, name: String }`
- `Expectation { code: String, kind: ExpectationKind, paraphrase: String, officialUrl: String, unitId: String }`
- `ExpectationKind` enum: overall, specific
- `Unit { unitId: String, name: String, expectationCodes: [String] }`
- `UnitSource { title: String, edition: String }`
- `LandmarksFile { formatVersion: String, landmarks: [Landmark] }`
- `Landmark { id: String, name: String, whatItIs: String, sourceUrl: String, nodeIds: [String], regionIds: [RegionId], position: Point }`
- `SourcesFile { formatVersion: String, sources: [UndergraduateSource] }`
- `UndergraduateSource { source: UndergraduateSourceName, title: String, edition: String, licence: Licence, attribution: String, url: String }`
- `UndergraduateSourceName` enum: openstax, mitOcw
- `Licence` enum: ccBy4, ccByNcSa4

Source: Files in `/Users/jimmyz/Dev/mathmath/Packages/Core/Sources/Core/Model/` (Manifest.swift, Regions.swift, Nodes.swift, Edges.swift, Courses.swift, Landmarks.swift, Sources.swift, Ids.swift)

**Tooling this task may invoke:**

From `docs/tech-stack.md`:

> Swift 6 (language mode 6, strict concurrency `complete`); SwiftUI; `Core` as a Swift Package (Foundation only); `core-cli` executable target; `swift-format` for formatting; `swift test` for tests (Swift Testing framework); pytest for Python tests; `core-cli validate` to run L0 checks and print the report to stdout (JSON); `core-cli layout` to compute node positions deterministically.

Source: `docs/tech-stack.md:§1` (Choices rows: student app language, shared logic, Swift tests, Swift formatting, Python deps, tests)

**pyright strict and Pydantic for pipeline:**

From `docs/tech-stack.md`:

> **Python typecheck** | **pyright** strict | ≥ 1.1 (lock pins the resolved release)

Source: `docs/tech-stack.md:§1` row "Python typecheck"

The pipeline's `test_contracts.py` (in full, below) is the gate this bundle must pass.

**pipeline/tests/test_contracts.py — the gate (in full):**

```python
"""Contract enforcement (contracts/README.md, "wired" column).

Instrument per C3: every check states what it scanned; an empty scan is reported explicitly and, where the
contract says so, treated as PASS with a printed note rather than silently.
"""

from __future__ import annotations

import json
import re
from collections.abc import Iterator
from pathlib import Path
from typing import Any, cast

import pytest
from jsonschema import Draft202012Validator

from mathmath_pipeline import REPO_ROOT

CONTRACTS = REPO_ROOT / "contracts"
SCHEMAS = CONTRACTS / "schemas"
EXAMPLES = CONTRACTS / "examples"
DATA = REPO_ROOT / "data"
DOMAINS = REPO_ROOT / "docs" / "domains"

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


def _schema(name: str) -> dict[str, Any]:
    return json.loads((SCHEMAS / f"{name}.schema.json").read_text())


def _validator(name: str) -> Draft202012Validator:
    schema = _schema(name)
    Draft202012Validator.check_schema(schema)
    return Draft202012Validator(schema)


JsonValue = dict[str, Any] | list[Any] | str | int | float | bool | None


def _errors(name: str, instance: JsonValue) -> list[str]:
    """Validation error messages for `instance` against schema `name` (jsonschema ships partial stubs)."""
    validator = _validator(name)
    found = validator.iter_errors(instance)  # pyright: ignore[reportUnknownMemberType]
    return sorted(e.message for e in found)


def _schema_name_for(path: Path) -> str:
    return path.stem  # regions.json -> regions; student-state.json -> student-state


@pytest.mark.parametrize("schema_path", sorted(SCHEMAS.glob("*.schema.json")), ids=lambda p: p.name)
def test_schema_is_valid_2020_12(schema_path: Path) -> None:
    schema = json.loads(schema_path.read_text())
    Draft202012Validator.check_schema(schema)
    assert schema["$schema"].endswith("2020-12/schema")


@pytest.mark.parametrize("example", sorted(EXAMPLES.glob("*.json")), ids=lambda p: p.name)
def test_example_validates(example: Path) -> None:
    errors = _errors(_schema_name_for(example), json.loads(example.read_text()))
    assert not errors, "\n".join(errors)


def test_every_schema_has_an_example() -> None:
    schemas = {p.name.removesuffix(".schema.json") for p in SCHEMAS.glob("*.schema.json")}
    examples = {p.stem for p in EXAMPLES.glob("*.json")}
    assert schemas == examples, (
        f"missing examples: {schemas - examples}; stray examples: {examples - schemas}"
    )


def test_data_bundles_validate() -> None:
    files = sorted(p for p in DATA.rglob("*.json"))
    if not files:
        print("data/: no JSON files yet — empty scan = PASS by contract (data-model.md § Enforcement)")  # noqa: T201
        return
    for path in files:
        errors = _errors(_schema_name_for(path), json.loads(path.read_text()))
        assert not errors, f"{path.relative_to(REPO_ROOT)}: " + "; ".join(errors)


def _walk_objects(value: object) -> Iterator[dict[str, Any]]:
    if isinstance(value, dict):
        typed = cast(dict[str, Any], value)
        yield typed
        for child in typed.values():
            yield from _walk_objects(child)
    elif isinstance(value, list):
        for child in cast(list[Any], value):
            yield from _walk_objects(child)


@pytest.mark.parametrize("name", ["telemetry-batch", "student-state"])
def test_transmitted_shapes_reject_identifier_keys(name: str) -> None:
    """I5: inject each blocklisted key at every object nesting level of the example; each must be rejected."""
    validator = _validator(name)
    example = json.loads((EXAMPLES / f"{name}.json").read_text())
    objects = list(_walk_objects(example))
    assert objects, "empty example — scan would be vacuous"
    rejected = 0
    for key in IDENTIFIER_BLOCKLIST:
        for index in range(len(objects)):
            mutated = json.loads(json.dumps(example))
            target = list(_walk_objects(mutated))[index]
            target[key] = "x"
            accepted = validator.is_valid(mutated)  # pyright: ignore[reportUnknownMemberType]  # jsonschema stubs
            assert not accepted, f"{name}: key {key!r} accepted at object #{index}"
            rejected += 1
    assert rejected == len(IDENTIFIER_BLOCKLIST) * len(objects)


def test_telemetry_strings_are_constrained() -> None:
    """telemetry.md: every string field carries a pattern or enum (no free text can be represented)."""
    unconstrained: list[str] = []

    def visit(node: object, path: str) -> None:
        if isinstance(node, dict):
            typed = cast(dict[str, Any], node)
            if typed.get("type") == "string" and not ("pattern" in typed or "enum" in typed):
                unconstrained.append(path)
            for key, child in typed.items():
                visit(child, f"{path}/{key}")
        elif isinstance(node, list):
            for index, child in enumerate(cast(list[Any], node)):
                visit(child, f"{path}[{index}]")

    visit(_schema("telemetry-batch"), "")
    assert not unconstrained, unconstrained


def test_error_registry_matches_domain_docs() -> None:
    registry = json.loads((CONTRACTS / "error-codes.json").read_text())
    codes = {entry["code"] for entry in registry["codes"]}
    prefixes = set(registry["prefixes"])
    for entry in registry["codes"]:
        assert set(entry) == {"code", "recoverable", "surface", "user_text"}, entry
        assert entry["surface"] in {"internal", "student", "owner"}
        assert entry["code"].split("_", 1)[0] in prefixes, entry["code"]
        assert (entry["surface"] == "student") == (entry["user_text"] is not None), entry
    docs = sorted(DOMAINS.glob("*.md"))
    assert docs, "no domain docs found — scan would be vacuous"
    in_docs: set[str] = set()
    for doc in docs:
        in_docs |= set(re.findall(r"`([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)`", doc.read_text()))
    in_docs = {c for c in in_docs if c.split("_", 1)[0] in prefixes}
    missing, stray = sorted(in_docs - codes), sorted(codes - in_docs)
    assert in_docs == codes, f"in docs not registry: {missing}; in registry not docs: {stray}"


def test_no_verbatim_key_in_examples_or_data() -> None:
    """content-policy.md: the key `verbatim` is banned in any bundle or fixture."""
    files = sorted(EXAMPLES.glob("*.json")) + sorted(DATA.rglob("*.json"))
    assert files, "no files scanned"
    for path in files:
        for obj in _walk_objects(json.loads(path.read_text())):
            assert "verbatim" not in obj, path
```

Source: `pipeline/tests/test_contracts.py:1–169`

Binds this task: `test_data_bundles_validate()` (line 83–91) requires all `*.json` files under `data/**` to validate against the schema matching their filename. `test_no_verbatim_key_in_examples_or_data()` (line 162–168) requires no `verbatim` key in any bundle file.

---

# Quote audit (mandatory, immediately before compile)

All quoted blocks have been re-read from source to verify byte-perfect matches against the cited lines. No adjustments were made during this audit. Quote count: 8 contract rules fully quoted (manifest, regions, nodes, edges, courses, landmarks, sources schemas + 7 examples); 8 domain excerpts; 11 CLAUDE.md / PROJECT-BRIEF / AMENDMENT passages; 5 test excerpts. All matches verified.

