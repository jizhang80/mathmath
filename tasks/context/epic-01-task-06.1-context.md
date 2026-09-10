# Task 01.6.1 context bundle

> Compiler: task-context-compiler  
> Date: 2026-09-09  
> Slug: contract-v1-1-probe-check  
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- Epic: 01
- Task: 06.1
- Slug: contract-v1-1-probe-check
- Summary: Apply the owner's Q5 ruling (Q5-RULING-01-07.md) to extend the contracts with ProbeItem `check` field (SymPy source, never LaTeX) and Landmark `source_title` field; carry the changes through every artifact that conforms to it — the two JSON Schemas, the two contract documents, `contracts/examples/`, the `Core` `Codable` types, and `data/demo/`.
- Invariants in play: I1 (CAS decides correctness, never a model; `check` is a declaration SymPy evaluates), I15 (landmarks are verifiable; `source_title` is the real thing's title from the source page, never edited), I6 (codes and course names are facts; `paraphrase`, `why`, `what_it_is`, `name` are project content, untouched), I14 (`Core` gains two `Codable` types, Foundation only, no logic).

## §B. Applicable contract rules (verbatim)

### contracts/README.md — Lock-first rule (§ Lock-first rule)

> A change to a locked contract is a **versioned** change: bump `Contract version`, ripple to every conforming EPIC, and flag the commit scope (`contract(<name>)`) so the ripple is auditable.

Source: `contracts/README.md:42-44`  
Binds this task: this task applies a versioned contract change under the owner's Q5 ruling; the scope must be `contract(data-model)` and `contract(content-policy)` per §4 step 9.

### contracts/data-model.md — Rule on additionalProperties (§ Nulls, enums, unknowns)

> Every object schema sets `additionalProperties: false` — a new field is a versioned change.

Source: `contracts/data-model.md:43`  
Binds this task: both new fields (`check` and `source_title`) are versioned changes requiring schema bumps because `additionalProperties: false` is set everywhere.

### contracts/data-model.md — Rule on optional fields (§ Nulls, enums, unknowns)

> Optional means the key is **absent**, never `null`. Enums are closed; an unknown value fails decode.

Source: `contracts/data-model.md:42`  
Binds this task: `check` is optional on `ProbeItem` (its key is absent for `mc` items); if present on a `numeric` item it is required by schema. Enums `ProbeCheckKind` and `ProbeCheckSelect` are closed.

### contracts/data-model.md — ProbeItem shape rule (§ ProbeItem)

> `id`, `type ∈ {numeric, mc}`, `prompt_latex`, `why`, and either `answer {value (string, normalised decimal or rational), tolerance (≥ 0, default 0)}` with `wrong_answers[] {value, error_type_id}` (numeric) or `choices[] {id, latex, error_type_id?}` + `correct_choice_id` (mc; every non-correct choice carries an `error_type_id`). No free-text answer field exists (I1, I10).

Source: `contracts/data-model.md:58-62`  
Binds this task: this rule is kept in full; the new paragraphs are appended to it (§4 step 3 of the spec).

### contracts/data-model.md — Text rule (§ Text)

> All student-facing strings are English (DEFERRED D-1). LaTeX appears only in fields named `latex` or `prompt_latex` and must be in the SwiftMath-renderable subset or carry `render_fallback: "katex"`.

Source: `contracts/data-model.md:36-37`  
Binds this task: `check.expr` and `check.equations[]` hold **SymPy source, not LaTeX**, and are never rendered or shown to a student; they are therefore not `latex`-suffixed and are outside the LaTeX regime.

### contracts/data-model.md — Collections row for landmarks (§ Collections)

> | `landmarks.json` | `landmarks.schema.json` | `id`, `name`, `what_it_is`, `source_url` (**required**, https), `node_ids[]` (≥ 1), `region_ids[]`, `position` |

Source: `contracts/data-model.md:53`  
Binds this task: after this task lands, the row reads: `id`, `name`, `source_title`, `what_it_is`, `source_url` (**required**, https), `node_ids[]` (≥ 1), `region_ids[]`, `position` (source_title is inserted after name per §4 step 3).

### contracts/content-policy.md — Generated content answer rule (§ Generated content)

> Probe answers are re-derived by SymPy before persistence (I1); prompts and hints must render in SwiftMath or carry `render_fallback: "katex"` (learning-objects W1 5b).

Source: `contracts/content-policy.md:29-30` (current v1.0.0)  
Binds this task: this bullet is replaced in the v1.1.0 version, per §4 step 4 of the spec.

### contracts/content-policy.md — Landmarks rule (§ Landmarks, I15, D22)

> Real, named, verifiable; `source_url` required and resolving at build (HTTP 2xx) with the page text containing the landmark's name; ≥ 1 node id. Unsourced → dropped, never invented, never "hypothetical".

Source: `contracts/content-policy.md:35-36` (current v1.0.0)  
Binds this task: this bullet is replaced in the v1.1.0 version, per §4 step 4 of the spec.

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/learning-objects.md — Probe checkability (W1, step 5/5c)

> 5. **Probe checkability** — every ProbeItem answer re-derived by SymPy in the pipeline and every WorkedExample step CAS-checked there (D41), else `LO_PROBE_UNCHECKABLE`; every `mc` item has ≥ 1 distractor tag and every tag names a member of the node's enum, else `LO_BAD_DISTRACTOR_TAG`. 5c. **Landmarks** — `source_url` present and resolving at build (HTTP 2xx), `node_ids[]` non-empty and known, else `LO_LANDMARK_UNSOURCED` (D22, I15).

Source: `docs/domains/learning-objects.md:240-245` (quoted in task spec §3)  
Binds this task: task 01.6.1 adds the `check` field so that 01.7's implementation of this rule (re-deriving the answer from `check` alone) becomes possible.

## §D. Prior task outputs this task depends on

- `Node` type with `probeItems: [ProbeItem]` — source: `Packages/Core/Sources/Core/Model/Nodes.swift:9-25` (produced by task 01.1)
- `ProbeItem` type with fields `id`, `type`, `promptLatex`, `why`, `renderFallback`, `answer`, `wrongAnswers`, `choices`, `correctChoiceId` — source: `Packages/Core/Sources/Core/Model/Nodes.swift:54-64` (produced by task 01.1)
- `Landmark` type with fields `id`, `name`, `whatItIs`, `sourceUrl`, `nodeIds`, `regionIds`, `position` — source: `Packages/Core/Sources/Core/Model/Landmarks.swift:11-19` (produced by task 01.1)
- `NodesFile` and `LandmarksFile` types — source: `Packages/Core/Sources/Core/Model/Nodes.swift:4-7` and `Packages/Core/Sources/Core/Model/Landmarks.swift:4-7` (produced by task 01.1)
- Schema files `contracts/schemas/nodes.schema.json` and `contracts/schemas/landmarks.schema.json` at v1.0.0 — source: the files themselves, currently locked at v1.0.0
- Example contract files `contracts/examples/nodes.json` and `contracts/examples/landmarks.json` at v1.0.0 — source: the files themselves
- Data bundle files `data/demo/nodes.json` and `data/demo/landmarks.json` — source: the files themselves, authored in task 01.5 and amended in task 01.6
- Core integration test `Packages/Core/Tests/CoreTests/DecodeRoundTripTests.swift` — source: the file itself (produced by task 01.1), the test `decodeRoundTrip` already exists and will be extended
- Python contract test `pipeline/tests/test_contracts.py` — source: the file itself (produced by task 01.1), will be extended with negative controls per AC7

## §E. Negative facts (confirmed ABSENT)

- No `check` field currently exists on `ProbeItem`. Grep query `"check"` in `Packages/Core/Sources/Core/Model/Nodes.swift` returned no match (lines 54-64 contain only `id`, `type`, `promptLatex`, `why`, `renderFallback`, `answer`, `wrongAnswers`, `choices`, `correctChoiceId`).
- No `sourceTitle` field currently exists on `Landmark`. Grep query `"sourceTitle"` in `Packages/Core/Sources/Core/Model/Landmarks.swift` returned no match (lines 11-19 contain only `id`, `name`, `whatItIs`, `sourceUrl`, `nodeIds`, `regionIds`, `position`).
- No `ProbeCheck`, `ProbeCheckKind`, or `ProbeCheckSelect` types exist in `Core`. Glob `Packages/Core/Sources/Core/**/*` for any file containing these names returned no matches.
- Current `contracts/schemas/nodes.schema.json` does NOT contain a `check` property in `probe_items[].items.properties`. Grep query `"check"` in the file returned no match.
- Current `contracts/schemas/landmarks.schema.json` does NOT contain a `source_title` property. Grep query `"source_title"` in the file returned no match.
- No fixture under `Packages/Core/Tests/CoreTests/Fixtures/**` is schema-validated. Source: `tasks/epic-01-task-06.1-contract-v1-1-probe-check.md:132-134` states "these fixtures are not schema-validated (`test_data_bundles_validate` scans `data/**` only)"; verified by reading `pipeline/tests/test_contracts.py:84-91`, which shows `test_data_bundles_validate` iterates only over `DATA.rglob("*.json")` where `DATA = REPO_ROOT / "data"`.
- No existing test in `Packages/Core/Tests/CoreTests/DecodeRoundTripTests.swift` asserts the new fields. Current tests end at `wireKeyCollectorCatchesNestedIdentifierKey()` (line 237-238).

## §F. File scope

Files this task may create or touch. Mark each create / modify and cite existence for modifies.

- MODIFY `contracts/schemas/nodes.schema.json` — confirmed present; current version v1.0.0 (schema has no version field; versioning is tracked in contract document)
- MODIFY `contracts/schemas/landmarks.schema.json` — confirmed present; current version v1.0.0
- MODIFY `contracts/data-model.md` — confirmed present; current `Contract version: v1.0.0` (line 3)
- MODIFY `contracts/content-policy.md` — confirmed present; current `Contract version: v1.0.0` (line 3)
- MODIFY `contracts/examples/nodes.json` — confirmed present; adds `check` to `exp-1` and `expf-1` only
- MODIFY `contracts/examples/landmarks.json` — confirmed present; adds `source_title` field
- MODIFY `Packages/Core/Sources/Core/Model/Nodes.swift` — confirmed present; adds `check: ProbeCheck?` field to `ProbeItem` and adds three new `public` types: `ProbeCheck`, `ProbeCheckKind`, `ProbeCheckSelect`
- MODIFY `Packages/Core/Sources/Core/Model/Landmarks.swift` — confirmed present; adds `sourceTitle: String` field to `Landmark`
- MODIFY `Packages/Core/Sources/Core/CoreCoding.swift` — confirmed present; no code changes needed (`.convertFromSnakeCase` strategy already handles the new fields)
- MODIFY `Packages/Core/Sources/Core/BundleIO.swift` — confirmed present; no code changes needed (already re-encodes all seven files)
- MODIFY `Packages/Core/Tests/CoreTests/DecodeRoundTripTests.swift` — confirmed present; adds T1 (round-trip with anti-vacuity assertion) and T5b (Landmark without sourceTitle fails decode) tests
- MODIFY `data/demo/nodes.json` — confirmed present; adds `check` key to exactly 20 `numeric` probe items (section §4 step 6 table pinned values)
- MODIFY `data/demo/landmarks.json` — confirmed present; adds `source_title: "Interest Act"` to the landmark; `name` field is NOT edited
- MODIFY `pipeline/tests/test_contracts.py` — confirmed present; adds T5a negative controls (schema requires `check` on numeric, forbids on mc; schema requires `source_title` on landmarks)

## §G. Stack constraints relevant here

- **Boundary validation**: `contracts/schemas/nodes.schema.json` and `contracts/schemas/landmarks.schema.json` are normative (Source: `contracts/data-model.md:5-8`). Every change to the schemas is a versioned contract change.
- **Storage / asset access**: Bundle files are immutable; changes require new `asset_version` (Source: `contracts/data-model.md:27-28`). `core-cli layout` writes all seven files from the `Core` types, so `ProbeItem.check` and `Landmark.sourceTitle` must be present in the types to avoid erasure (Source: `tasks/epic-01-task-06.1-contract-v1-1-probe-check.md:72-75`, the seam risk).
- **Error codes to use**: Task 01.6.1 registers no new error codes. The codes `LO_PROBE_UNCHECKABLE`, `LO_LANDMARK_UNSOURCED`, `LO_BAD_DISTRACTOR_TAG` are already registered in `contracts/error-codes.json` and will be used by task 01.7 (Source: `contracts/error-codes.json`, verified at `tasks/epic-01-task-06.1-contract-v1-1-probe-check.md:§5 T3`).
- **Model-calling paths (if any)**: This task has zero model-calling paths. `check` is content the pipeline verifies; it is not computed or derived here. No threshold, no fallback.
- **Tooling this task may name**: Source: `docs/tech-stack.md:1-8` (locked 2026-09-09). Swift 6 toolchain, Xcode 26.6, Python 3.14 with uv, pytest, pyright strict. No new tools named. The gates are in `scripts/gate.sh` (Source: `scripts/gate.sh:9-23`).

---

# Full source material (verbatim from repo)

## contracts/schemas/nodes.schema.json (current, v1.0.0)

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

Source: `contracts/schemas/nodes.schema.json:1-397`

## contracts/schemas/landmarks.schema.json (current, v1.0.0)

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

Source: `contracts/schemas/landmarks.schema.json:1-98`

## contracts/data-model.md (current, v1.0.0)

```markdown
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
```

Source: `contracts/data-model.md:1-79`

## contracts/content-policy.md (current, v1.0.0)

```markdown
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
```

Source: `contracts/content-policy.md:1-54`

## contracts/examples/nodes.json (current, v1.0.0)

Source: `contracts/examples/nodes.json:1-162` — complete file quoted (contains exp-1 and expf-1 on lines 45-58 and 121-134).

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
    },
    {
      "id": "exponential-functions",
      "name": "Exponential functions",
      "region_id": "functions",
      "strand": "C",
      "expectation_codes": [
        {
          "course_code": "MCR3U",
          "code": "C1.1"
        }
      ],
      "courses": [
        {
          "course_code": "MCR3U",
          "depth": 3
        }
      ],
      "position": {
        "x": 0.45,
        "y": 0.2
      },
      "paraphrase": "Recognise, graph and interpret functions of the form y = a·b^x.",
      "error_types": [
        {
          "id": "base-exponent-swapped",
          "label": "Treated the base as the exponent",
          "implies_prerequisite": "exponent-laws"
        },
        {
          "id": "none-of-these",
          "label": "None of these"
        }
      ],
      "hint_tree": {
        "base-exponent-swapped": [
          "Which number is being multiplied repeatedly?",
          "In y = 3^x the base 3 is repeated x times.",
          "3^2 = 9 while 2^3 = 8: order matters."
        ]
      },
      "probe_items": [
        {
          "id": "expf-1",
          "type": "numeric",
          "prompt_latex": "y = 3^x,\\ x = 2 \\Rightarrow y = ?",
          "why": "3 multiplied by itself twice is 9.",
          "answer": {
            "value": "9"
          },
          "wrong_answers": [
            {
              "value": "8",
              "error_type_id": "base-exponent-swapped"
            }
          ]
        }
      ]
    },
    {
      "id": "matrix-multiplication",
      "name": "Matrix multiplication",
      "region_id": "linear-algebra",
      "source_ref": {
        "source": "openstax",
        "edition": "College Algebra 2e",
        "locator": "9.5"
      },
      "courses": [],
      "position": {
        "x": 0.28,
        "y": 0.55
      },
      "paraphrase": "Multiply two matrices by combining rows of the first with columns of the second.",
      "error_types": [
        {
          "id": "none-of-these",
          "label": "None of these"
        }
      ],
      "hint_tree": {},
      "probe_items": []
    }
  ]
}
```

## contracts/examples/landmarks.json (current, v1.0.0)

Source: `contracts/examples/landmarks.json:1-24` — complete file quoted.

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

## Packages/Core/Sources/Core/Model/Nodes.swift (current, v1.0.0)

Source: `Packages/Core/Sources/Core/Model/Nodes.swift:1-90` — complete file quoted.

```swift
import Foundation

/// `Codable` types for `nodes.json` (`contracts/schemas/nodes.schema.json`).
public struct NodesFile: Codable, Equatable {
    public let formatVersion: String
    public let nodes: [Node]
}

public struct Node: Codable, Equatable {
    public let id: String
    public let name: String
    public let regionId: RegionId
    public let strand: String?
    public let expectationCodes: [NodeExpectationCode]?
    public let sourceRef: SourceRef?
    public let courses: [NodeCourse]
    public let position: Point
    public let layoutHint: Point?
    public let paraphrase: String
    public let explanation: String?
    public let workedExamples: [WorkedExample]?
    public let errorTypes: [ErrorType]
    public let hintTree: [String: [String]]
    public let probeItems: [ProbeItem]
}

public struct NodeExpectationCode: Codable, Equatable {
    public let courseCode: String
    public let code: String
}

public struct NodeCourse: Codable, Equatable {
    public let courseCode: String
    public let depth: Int
}

public struct SourceRef: Codable, Equatable {
    public let source: UndergraduateSourceName
    public let edition: String
    public let locator: String
}

public struct WorkedExample: Codable, Equatable {
    public let id: String
    public let stepsLatex: [String]
}

public struct ErrorType: Codable, Equatable {
    public let id: String
    public let label: String
    public let impliesPrerequisite: String?
}

public struct ProbeItem: Codable, Equatable {
    public let id: String
    public let type: ProbeItemType
    public let promptLatex: String
    public let why: String
    public let renderFallback: RenderFallback?
    public let answer: ProbeAnswer?
    public let wrongAnswers: [WrongAnswer]?
    public let choices: [ProbeChoice]?
    public let correctChoiceId: String?
}

public enum ProbeItemType: String, Codable {
    case numeric
    case mc
}

public enum RenderFallback: String, Codable {
    case katex
}

public struct ProbeAnswer: Codable, Equatable {
    public let value: String
    public let tolerance: Double?
}

public struct WrongAnswer: Codable, Equatable {
    public let value: String
    public let errorTypeId: String
}

public struct ProbeChoice: Codable, Equatable {
    public let id: String
    public let latex: String
    public let errorTypeId: String?
}
```

## Packages/Core/Sources/Core/Model/Landmarks.swift (current, v1.0.0)

Source: `Packages/Core/Sources/Core/Model/Landmarks.swift:1-20` — complete file quoted.

```swift
import Foundation

/// `Codable` types for `landmarks.json` (`contracts/schemas/landmarks.schema.json`).
public struct LandmarksFile: Codable, Equatable {
    public let formatVersion: String
    public let landmarks: [Landmark]
}

/// `sourceUrl` is a required, non-optional `String`: I15's "a landmark that cannot be sourced is
/// dropped, never invented" is satisfied structurally — decode fails without a `source_url`.
public struct Landmark: Codable, Equatable {
    public let id: String
    public let name: String
    public let whatItIs: String
    public let sourceUrl: String
    public let nodeIds: [String]
    public let regionIds: [RegionId]
    public let position: Point
}
```

## Packages/Core/Sources/Core/CoreCoding.swift (current)

Source: `Packages/Core/Sources/Core/CoreCoding.swift:1-28` — complete file quoted.

```swift
import Foundation

/// The one JSON coder configuration for the bundle wire format and `student-state.json`.
///
/// `contracts/data-model.md` defines one shape set that "every bundle file, the student state and
/// `Core`'s `Codable` types share", so there is one key strategy: JSON keys are snake_case, Swift
/// properties are camelCase, and Foundation converts between them. No `Model/` type declares an
/// explicit `CodingKeys` — `.convertFromSnakeCase` rewrites the incoming key before it is matched
/// against a `CodingKey` raw value, so the two mechanisms cannot be combined.
public enum CoreCoding {
    /// A fresh decoder per access: `JSONDecoder` is a non-`Sendable` class, so a shared `static let`
    /// would not compile under Swift 6 strict concurrency.
    public static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    /// `.sortedKeys` is what makes `BundleIO.write` deterministic — byte-identical output for
    /// byte-identical input across runs. It is harmless for every other consumer because every
    /// comparison in this task's tests is structural (key order excluded).
    public static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
```

## Packages/Core/Sources/Core/BundleIO.swift (current)

Source: `Packages/Core/Sources/Core/BundleIO.swift:1-72` — complete file quoted.

```swift
import Foundation

/// The six content files of a bundle directory, decoded (`manifest.json` plus `regions.json`,
/// `nodes.json`, `edges.json`, `courses.json`, `landmarks.json`, `sources.json`).
///
/// `student-state.json` is not part of `ContentBundle` — it has no bundle-directory consumer until
/// a later EPIC; it ships as a standalone `Codable` type only in this task.
public struct ContentBundle {
    public let manifest: Manifest
    public let regions: RegionsFile
    public let nodes: NodesFile
    public let edges: EdgesFile
    public let courses: CoursesFile
    public let landmarks: LandmarksFile
    public let sources: SourcesFile
}

/// Deterministic bundle-directory read/write I/O.
///
/// `BundleIO` never computes or verifies `sha256` (`Manifest.files[].sha256` is a stored `String`
/// field only) — hash computation is a pipeline concern and hash verification at load is an App-side
/// concern (`docs/plans/epic-01-task-plan.md` planner note 2).
public enum BundleIO {
    /// Reads a bundle directory, checking manifest file-presence completeness before decoding any
    /// content file. Throws `CoreError.platformBundleIntegrityFailed` if a file named in
    /// `manifest.files` is absent from `directory` — no partial `ContentBundle` is ever constructed.
    public static func read(from directory: URL) throws -> ContentBundle {
        let manifestData = try Data(contentsOf: directory.appendingPathComponent("manifest.json"))
        let manifest = try CoreCoding.decoder.decode(Manifest.self, from: manifestData)

        for file in manifest.files {
            let path = directory.appendingPathComponent(file.name)
            guard FileManager.default.fileExists(atPath: path.path) else {
                throw CoreError.platformBundleIntegrityFailed
            }
        }

        let regions = try CoreCoding.decoder.decode(
            RegionsFile.self, from: Data(contentsOf: directory.appendingPathComponent("regions.json")))
        let nodes = try CoreCoding.decoder.decode(
            NodesFile.self, from: Data(contentsOf: directory.appendingPathComponent("nodes.json")))
        let edges = try CoreCoding.decoder.decode(
            EdgesFile.self, from: Data(contentsOf: directory.appendingPathComponent("edges.json")))
        let courses = try CoreCoding.decoder.decode(
            CoursesFile.self, from: Data(contentsOf: directory.appendingPathComponent("courses.json")))
        let landmarks = try CoreCoding.decoder.decode(
            LandmarksFile.self, from: Data(contentsOf: directory.appendingPathComponent("landmarks.json")))
        let sources = try CoreCoding.decoder.decode(
            SourcesFile.self, from: Data(contentsOf: directory.appendingPathComponent("sources.json")))

        return ContentBundle(
            manifest: manifest, regions: regions, nodes: nodes, edges: edges, courses: courses,
            landmarks: landmarks, sources: sources)
    }

    /// Writes a bundle directory. `.sortedKeys` output formatting makes the write deterministic:
    /// byte-identical output for byte-identical input across runs.
    public static func write(_ bundle: ContentBundle, to directory: URL) throws {
        try CoreCoding.encoder.encode(bundle.manifest).write(
            to: directory.appendingPathComponent("manifest.json"))
        try CoreCoding.encoder.encode(bundle.regions).write(
            to: directory.appendingPathComponent("regions.json"))
        try CoreCoding.encoder.encode(bundle.nodes).write(to: directory.appendingPathComponent("nodes.json"))
        try CoreCoding.encoder.encode(bundle.edges).write(to: directory.appendingPathComponent("edges.json"))
        try CoreCoding.encoder.encode(bundle.courses).write(
            to: directory.appendingPathComponent("courses.json"))
        try CoreCoding.encoder.encode(bundle.landmarks).write(
            to: directory.appendingPathComponent("landmarks.json"))
        try CoreCoding.encoder.encode(bundle.sources).write(
            to: directory.appendingPathComponent("sources.json"))
    }
}
```

## Packages/Core/Tests/CoreTests/DecodeRoundTripTests.swift (current)

Source: `Packages/Core/Tests/CoreTests/DecodeRoundTripTests.swift:1-238` — complete file quoted.

```swift
import Foundation
import Testing

@testable import Core

@Suite("Decode round trip (contracts/examples/)")
struct DecodeRoundTripTests {
    /// `contracts/examples/`, located the same way `coreImportBoundary()` locates `Sources/Core`:
    /// from `#filePath` (`Packages/Core/Tests/CoreTests/DecodeRoundTripTests.swift`), three
    /// `.deletingLastPathComponent()` calls reach the package root (`Packages/Core`), two more reach
    /// the repo root, then `.appendingPathComponent("contracts/examples")`.
    private static var examplesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root (Packages/Core)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("contracts/examples")
    }

    /// Decodes `data` into `T`, re-encodes it, and asserts the original and re-encoded documents are
    /// structurally JSON-equal (key order excluded) by comparing their `JSONSerialization` object
    /// graphs — order-independent on objects, order-sensitive on arrays.
    private static func assertRoundTrip<T: Codable>(_ type: T.Type, data: Data, file: String) throws {
        let decoded = try CoreCoding.decoder.decode(type, from: data)
        let reencoded = try CoreCoding.encoder.encode(decoded)
        let original = try JSONSerialization.jsonObject(with: data) as? NSObject
        let roundTripped = try JSONSerialization.jsonObject(with: reencoded) as? NSObject
        #expect(original == roundTripped, "\(file) did not round-trip to a structurally equal document")
    }

    // AC2: `telemetry-batch.json` is excluded by name — there is no `Core` type for it (telemetry is
    // EPICs 10–11's scope).
    @Test("all 8 named example files round-trip (AC1, AC2, AC5)")
    func decodeRoundTrip() throws {
        let files = [
            "manifest.json", "regions.json", "nodes.json", "edges.json", "courses.json",
            "landmarks.json", "sources.json", "student-state.json",
        ]
        // C3 anti-vacuity guard: an empty or partial list is a FAIL.
        #expect(files.count == 8, "expected 8 example files — empty or partial list is a FAIL")

        for file in files {
            let data = try Data(contentsOf: Self.examplesDir.appendingPathComponent(file))
            switch file {
            case "manifest.json":
                try Self.assertRoundTrip(Manifest.self, data: data, file: file)
            case "regions.json":
                try Self.assertRoundTrip(RegionsFile.self, data: data, file: file)
            case "nodes.json":
                try Self.assertRoundTrip(NodesFile.self, data: data, file: file)
            case "edges.json":
                try Self.assertRoundTrip(EdgesFile.self, data: data, file: file)
            case "courses.json":
                try Self.assertRoundTrip(CoursesFile.self, data: data, file: file)
            case "landmarks.json":
                try Self.assertRoundTrip(LandmarksFile.self, data: data, file: file)
            case "sources.json":
                try Self.assertRoundTrip(SourcesFile.self, data: data, file: file)
            case "student-state.json":
                try Self.assertRoundTrip(StudentState.self, data: data, file: file)
            default:
                Issue.record("unhandled example file \(file)")
            }
        }
    }

    // T2: enums are closed — an unknown value fails decode (`contracts/data-model.md` § Nulls).
    @Test("unrecognized enum raw value fails decode")
    func unrecognizedEnumValueFailsDecode() throws {
        let data = try Data(contentsOf: Self.examplesDir.appendingPathComponent("nodes.json"))
        var json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        var nodes = try #require(json?["nodes"] as? [[String: Any]])
        nodes[0]["region_id"] = "made-up-region"
        json?["nodes"] = nodes
        let mutated = try JSONSerialization.data(withJSONObject: json as Any)
        #expect(throws: DecodingError.self) {
            try CoreCoding.decoder.decode(NodesFile.self, from: mutated)
        }
    }

    // T5: negative control for the recursive import-boundary walk — proves the walk actually
    // descends into `Model/` rather than staying flat.
    @Test("import boundary walk includes Model/ files")
    func importBoundaryWalkIncludesModelDirectory() throws {
        let sourcesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root
            .appendingPathComponent("Sources/Core")
        let enumerator = FileManager.default.enumerator(
            at: sourcesDir, includingPropertiesForKeys: [.isDirectoryKey])
        var files: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension == "swift" {
                files.append(url)
            }
        }
        let hasModelFile = files.contains { url in
            url.deletingLastPathComponent().lastPathComponent == "Model"
        }
        #expect(hasModelFile, "recursive walk did not find any Model/*.swift file")
    }

    // T6: `BundleIO.write` idempotency — deterministic output across two writes.
    @Test("BundleIO.write is deterministic across two writes")
    func bundleWriteIsIdempotent() throws {
        let manifest = try CoreCoding.decoder.decode(
            Manifest.self,
            from: Data(contentsOf: Self.examplesDir.appendingPathComponent("manifest.json")))
        let regions = try CoreCoding.decoder.decode(
            RegionsFile.self,
            from: Data(contentsOf: Self.examplesDir.appendingPathComponent("regions.json")))
        let nodes = try CoreCoding.decoder.decode(
            NodesFile.self, from: Data(contentsOf: Self.examplesDir.appendingPathComponent("nodes.json")))
        let edges = try CoreCoding.decoder.decode(
            EdgesFile.self, from: Data(contentsOf: Self.examplesDir.appendingPathComponent("edges.json")))
        let courses = try CoreCoding.decoder.decode(
            CoursesFile.self,
            from: Data(contentsOf: Self.examplesDir.appendingPathComponent("courses.json")))
        let landmarks = try CoreCoding.decoder.decode(
            LandmarksFile.self,
            from: Data(contentsOf: Self.examplesDir.appendingPathComponent("landmarks.json")))
        let sources = try CoreCoding.decoder.decode(
            SourcesFile.self,
            from: Data(contentsOf: Self.examplesDir.appendingPathComponent("sources.json")))
        let bundle = ContentBundle(
            manifest: manifest, regions: regions, nodes: nodes, edges: edges, courses: courses,
            landmarks: landmarks, sources: sources)

        let tempDir1 = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let tempDir2 = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tempDir2, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir1)
            try? FileManager.default.removeItem(at: tempDir2)
        }

        try BundleIO.write(bundle, to: tempDir1)
        try BundleIO.write(bundle, to: tempDir2)

        for name in [
            "manifest.json", "regions.json", "nodes.json", "edges.json", "courses.json", "landmarks.json",
            "sources.json",
        ] {
            let data1 = try Data(contentsOf: tempDir1.appendingPathComponent(name))
            let data2 = try Data(contentsOf: tempDir2.appendingPathComponent(name))
            #expect(data1 == data2, "\(name) was not written deterministically")
        }
    }

    // AC7 / T6: `BundleIO.read` throws `CoreError.platformBundleIntegrityFailed` when a manifest-listed
    // file is missing from disk, before constructing any `ContentBundle`.
    @Test("BundleIO.read throws platformBundleIntegrityFailed on a missing manifest-listed file")
    func bundleReadThrowsOnMissingFile() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manifestData = try Data(contentsOf: Self.examplesDir.appendingPathComponent("manifest.json"))
        try manifestData.write(to: tempDir.appendingPathComponent("manifest.json"))
        // Deliberately omit every file named in manifest.files (nodes.json etc.).

        #expect(throws: CoreError.platformBundleIntegrityFailed) {
            try BundleIO.read(from: tempDir)
        }
    }

    /// Identifier blocklist (mirrors `pipeline/tests/test_contracts.py::IDENTIFIER_BLOCKLIST`, §3).
    private static let identifierBlocklist: Set<String> = [
        "id", "install_id", "device_id", "session_id", "user_id", "ip", "timestamp", "email", "name",
    ]

    /// Collects every object key at every nesting level of a `JSONSerialization` object graph,
    /// descending into both dictionaries and arrays.
    private static func collectKeys(_ value: Any) -> Set<String> {
        var keys: Set<String> = []
        if let dict = value as? [String: Any] {
            for (key, nested) in dict {
                keys.insert(key)
                keys.formUnion(collectKeys(nested))
            }
        } else if let array = value as? [Any] {
            for element in array {
                keys.formUnion(collectKeys(element))
            }
        }
        return keys
    }

    /// AC6 / I5: the wire key set of the **re-encoded** `StudentState` document is disjoint from the
    /// identifier blocklist. `contracts/data-model.md` § StudentState: "the schema's closed key set is
    /// the guard" — this replaced the `CodingKeys`-reflection instrument that `StudentState` no longer
    /// has (`tasks/blocked/tester-blocked-01-01.md`).
    @Test("re-encoded StudentState document carries no identifying key (I5, AC6)")
    func studentStateWireKeysRejectIdentifierBlocklist() throws {
        let data = try Data(contentsOf: Self.examplesDir.appendingPathComponent("student-state.json"))
        let decoded = try CoreCoding.decoder.decode(StudentState.self, from: data)
        let reencoded = try CoreCoding.encoder.encode(decoded)
        let reencodedObject = try JSONSerialization.jsonObject(with: reencoded)
        let collected = Self.collectKeys(reencodedObject)

        // Anti-vacuity: a collector that returned an empty or shallow set cannot pass.
        let requiredTopLevelNames: Set<String> = [
            "schema_version", "format_version_seen", "syllabi", "marker", "nodes", "trail",
            "expedition_log", "probe_log", "install_day", "consent_on",
        ]
        #expect(
            requiredTopLevelNames.isSubset(of: collected),
            "collected key set is missing required top-level names — empty or shallow collector is a FAIL")

        #expect(
            collected.isDisjoint(with: Self.identifierBlocklist),
            "re-encoded StudentState document carries identifying keys: \(collected.intersection(Self.identifierBlocklist))"
        )
    }

    // T5 negative control for the I5 wire-key guard: injecting an identifier key into the nested
    // `marker` object must make the same collector report the intersection — proving the collector
    // descends past the top level and the disjointness assertion is live, not vacuous.
    @Test("wire-key collector catches an identifier key injected into a nested object")
    func wireKeyCollectorCatchesNestedIdentifierKey() throws {
        let data = try Data(contentsOf: Self.examplesDir.appendingPathComponent("student-state.json"))
        let decoded = try CoreCoding.decoder.decode(StudentState.self, from: data)
        let reencoded = try CoreCoding.encoder.encode(decoded)
        var document = try #require(JSONSerialization.jsonObject(with: reencoded) as? [String: Any])
        var marker = try #require(document["marker"] as? [String: Any])
        marker["device_id"] = "x"
        document["marker"] = marker

        let collected = Self.collectKeys(document)
        #expect(
            collected.intersection(Self.identifierBlocklist) == ["device_id"],
            "collector failed to catch device_id injected into the nested marker object")
    }
}
```

## pipeline/tests/test_contracts.py (current, selected excerpts)

Source: `pipeline/tests/test_contracts.py:1-169` — lines 26-36, 43-57, 84-92 excerpted; full file linked.

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

[… 50 lines omitted for brevity …]

def test_data_bundles_validate() -> None:
    files = sorted(p for p in DATA.rglob("*.json"))
    if not files:
        print("data/: no JSON files yet — empty scan = PASS by contract (data-model.md § Enforcement)")  # noqa: T201
        return
    for path in files:
        errors = _errors(_schema_name_for(path), json.loads(path.read_text()))
        assert not errors, f"{path.relative_to(REPO_ROOT)}: " + "; ".join(errors)
```

Source: `pipeline/tests/test_contracts.py:84-92` — confirms that `test_data_bundles_validate` scans `DATA` (= `REPO_ROOT / "data"`) only, not fixtures.

## docs/tech-stack.md (relevant excerpts)

Source: `docs/tech-stack.md:1-43` — §1 and §2 quoted; full file is locked.

```markdown
# Tech stack — locked (bootstrap Phase 5)

Date: 2026-09-09. Ground truth: `PROJECT-BRIEF-v2.md` + `AMENDMENT-v2.1`–`v2.5` (D24, D29, D31–D36,
D41, D42); `docs/idea.md`. Preferences input: `claude-tech-stack-preferences.md` — its principle layer
(strict typing, explicit state, thin runtime, boundary validation, observability at the review surface)
is binding; its web-tool layer is overridden by D32/D33 for the iOS app and by D41 for the pipeline.
**Every pin below was validated on this date**; the citation is the validation. Agents BLOCK on any spec
that pins a tool this file does not name (CLAUDE.md).

## 1. Choices

[… table omitted for brevity; key rows: Swift 6 / Xcode 26.6 / iOS 18.0 / `Core` Foundation-only / SwiftMath 1.7.3 / Python 3.14 / uv / pytest / pyright strict / swift-format / pre-commit …]

## 2. Repository layout

```
/
├── App/
│   ├── mathmath.xcodeproj/         # hand-authored; synchronized `Sources` group — never edited by agents
│   ├── mathmath.xcworkspace/       # project + Packages/Core (gives xcodebuild the Core scheme)
│   └── Sources/                    # SwiftUI app: views, adapters (Foundation Models, persistence, sync)
├── Packages/Core/                  # Swift package: Core (lib), CoreCLI → core-cli (exe), CoreTests
├── Packages/Rendering/             # Swift package over SwiftMath: MathView + RenderCheck (rendering spike; LO W1 5b)
├── pipeline/                       # Python (uv): src/mathmath_pipeline, tests; calls core-cli (D42)
├── data/                           # JSON bundles: Demo hand-written; later pipeline output (+ L0 report)
├── scripts/gate.sh                 # the four gates (§3); scripts/check-no-time-estimates.sh (I11)
├── .github/workflows/ci.yml        # macos-26: Swift job + Python job
├── .pre-commit-config.yaml · .swift-format · .gitignore
└── docs/ contracts/ tasks/ modules/ (unchanged)
```
```

Source: `docs/tech-stack.md:1-8, 45-67`

## scripts/gate.sh (current)

Source: `scripts/gate.sh:1-26` — complete file quoted.

```bash
#!/bin/sh
# The four gates (R-1) for mathmath, as locked in docs/tech-stack.md. Agents run this before every commit;
# CI runs the same steps. Exit non-zero on the first failure.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIM="$("$ROOT/scripts/pick-simulator.sh")"
echo "simulator destination: $SIM"

echo "== 1/4 format + lint =="
xcrun swift-format lint --strict --recursive --configuration "$ROOT/.swift-format" "$ROOT/Packages" "$ROOT/App/Sources"
( cd "$ROOT/pipeline" && uv run ruff check . && uv run ruff format --check . )

echo "== 2/4 typecheck =="
( cd "$ROOT/pipeline" && uv run pyright )

echo "== 3/4 Core: build + test on the iOS simulator (D29) =="
( cd "$ROOT/Packages/Core" && swift build -c release --product core-cli )
( cd "$ROOT/Packages/Core" && xcodebuild test -quiet -scheme Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO )
( cd "$ROOT/Packages/Rendering" && xcodebuild test -quiet -scheme Rendering -destination "$SIM" CODE_SIGNING_ALLOWED=NO )

echo "== 4/4 App build on the simulator + pipeline tests =="
xcodebuild build -quiet -workspace "$ROOT/App/mathmath.xcworkspace" -scheme mathmath -destination "$SIM" CODE_SIGNING_ALLOWED=NO
( cd "$ROOT/pipeline" && uv run pytest -q )

echo "gates green"
```

## CLAUDE.md — Invariants I1 and I15 (verbatim)

Source: `CLAUDE.md:24-25, 38` — from the invariants table.

| I1 | **Wherever step verification exists, step correctness is decided by CAS, never by a language model.** No code path lets a model output decide whether a step or a probe answer is right; expedition items are checked deterministically in code. | D6 |

| I15 | **Landmarks are real, named, verifiable things with a resolving `source_url`.** A landmark that cannot be sourced is dropped, never invented. | D22 |

## data/demo/nodes.json — 20 numeric probe items (IDs, prompts, answers)

The 20 numeric ProbeItems from `data/demo/nodes.json` (as of 2026-09-09, authored in task 01.5, amended in task 01.6):

| # | item id | prompt_latex | answer.value |
|---|---|---|---|
| 1 | `integer-operations-1` | `-3 - (-7) = ?` | `4` |
| 2 | `order-of-operations-1` | `2 + 3 \times 4 = ?` | `14` |
| 3 | `rational-numbers-1` | `\frac{1}{2} + \frac{1}{3} = ?` | `5/6` |
| 4 | `exponent-laws-1` | `(2^3)^2 = 2^{\\,?}` | `6` |
| 5 | `scientific-notation-1` | `3.2\times 10^4 = ?` | `32000` |
| 6 | `linear-relations-1` | `y = 3x + 5 \Rightarrow \text{slope} = ?` | `3` |
| 7 | `solving-linear-equations-1` | `2x + 3 = 11 \Rightarrow x = ?` | `4` |
| 8 | `solving-systems-of-equations-1` | `x+y=10,\ x-y=2 \Rightarrow x = ?` | `6` |
| 9 | `simplifying-expressions-1` | `3x+5x = kx.\ k = ?` | `8` |
| 10 | `polynomials-1` | `(3x^2+2x) + (x^2+5x)\text{, coefficient of }x^2 = ?` | `4` |
| 11 | `factoring-1` | `x^2+5x+6=(x+a)(x+b).\ a\cdot b = ?` | `6` |
| 12 | `solving-quadratics-1` | `x^2-5x+6=0 \Rightarrow \text{larger root} = ?` | `3` |
| 13 | `rational-expressions-1` | `\frac{x^2-9}{x-3}\text{ at } x=5 = ?` | `8` |
| 14 | `quadratic-functions-1` | `y=(x-3)^2+4 \Rightarrow \text{vertex } x\text{-coordinate} = ?` | `3` |
| 15 | `function-concept-1` | `f(x)=2x+1,\ f(3) = ?` | `7` |
| 16 | `function-transformations-1` | `y=f(x-4) \text{ shifts the graph right by } ?\text{ units}` | `4` |
| 17 | `function-notation-1` | `g(x)=3x-2,\ g(4) = ?` | `10` |
| 18 | `domain-and-range-1` | `f(x)=\sqrt{x-3}\text{, domain requires } x \geq ?` | `3` |
| 19 | `exponential-functions-1` | `y = 3^x,\ x = 2 \Rightarrow y = ?` | `9` |
| 20 | `logarithms-1` | `\log_2 8 = ?` | `3` |

Source: `data/demo/nodes.json` (minified, parsed for item id, prompt_latex, answer.value from the 20 numeric entries; the file is one-line JSON, line count = 1 but contains all node data)

## data/demo/landmarks.json — The landmark

Source: `data/demo/landmarks.json:1-23` — current landmark record (will gain `source_title: "Interest Act"` in this task).

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

---

# Repo state facts (ground truth at 2026-09-09)

- Current `contracts/data-model.md` version string: `v1.0.0` (line 3)
- Current `contracts/content-policy.md` version string: `v1.0.0` (line 3)
- Both schemas exist and are at `$schema: https://json-schema.org/draft/2020-12/schema` (JSON Schema 2020-12)
- `contracts/examples/nodes.json` and `contracts/examples/landmarks.json` currently validate against their respective schemas (confirmed by `pytest` suite `test_example_validates`)
- No `Fixtures/**/*.json` under `Packages/Core/Tests/CoreTests/` is schema-validated by the `test_contracts.py` test suite; `test_data_bundles_validate` scans `data/**` only (verified by reading the test code, line 84: `files = sorted(p for p in DATA.rglob("*.json"))` where `DATA = REPO_ROOT / "data"`)
- Exact pytest invocation: `cd "$ROOT/pipeline" && uv run pytest -q` (from `scripts/gate.sh:23`)
- Exact xcodebuild invocation: `xcodebuild build -quiet -workspace "$ROOT/App/mathmath.xcworkspace" -scheme mathmath -destination "$SIM" CODE_SIGNING_ALLOWED=NO` (from `scripts/gate.sh:22`) and `xcodebuild test -quiet -scheme Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO` (from `scripts/gate.sh:18` for Core tests)
- `swift-format` version: 6.3.0 (Source: `docs/tech-stack.md:23` — "xcrun swift-format --version")
