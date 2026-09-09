# Contract: Domain glossary (LOCK-FIRST)

**Contract version:** v1.0.0 · Source: `docs/domains/*.md`, `docs/idea.md` (D1–D49)

> One agreed term per concept. Every EPIC, type, JSON key, screen label and doc uses the same word. Code
> identifiers are the term in `PascalCase` (types) / `camelCase` (Swift members) / `snake_case` (JSON,
> Python). **Banned synonyms** are listed so the grep gate can catch drift.

## Map and graph (Door C)

- **Map** — the concept graph rendered as one continent. *Banned:* "world", "board", "skill tree".
- **Region** — one of the ten D21 territories (`region_id` fixed enum, `data-model.md`). *Banned:* "area", "zone", "strand" (a strand is a Ministry division, see below).
- **Horizon** — a named label beyond the continent with no content (Analysis, Topology, Number Theory, Abstract Algebra).
- **Shore** — the optional grade 7–8 region, drawn without content (not in the Demo; DEFERRED D-10).
- **Node** — one concept; the unit of mastery. *Banned:* "topic", "skill", "concept card".
- **Edge** — "A is prerequisite of B", directed `from → to`. Rendered as a **river**. *Banned:* "link", "dependency" (in data), "arrow".
- **Fog** — the rendering of an uncleared node. Mastery states: **fog · cleared · blocked** (`data-model.md`). *Banned:* "locked", "unknown" (as a state), "mastered".
- **Due** — a cleared node whose `next_due` has passed; drawn with a *due ring*. Not a mastery state.
- **Trail** — the student's one generated path over the graph (D47): **segments** that are either a **course segment** (`course_code`) or an **extension** (dashed). *Banned:* "path", "route", "track", "course trail" (a course is not a trail).
- **Course** — a Ministry course (`course_code`, e.g. `MCR3U`) = node subset + depth marker (D3). Courses have **Units** and **next courses** (succession).
- **Unit** — a course's teaching unit (D45): an ordered group of expectations from the course's `unit_source` textbook, fallback by strand. *Banned:* "chapter" (that is the textbook's word), "module", "lesson".
- **Course-progress marker** ("we are here in class") — the student's chosen current unit (D45). Short form in code: `marker`. *Banned:* "start marker" (v2.1 D28 name), "position", "cursor".
- **Position indicator** — the first uncleared trail node at or after the marker (display only).
- **Landmark** — a real, named, sourced thing linked to nodes (D22). *Banned:* "application", "example", "story".
- **Layout / coordinates** — node positions precomputed by `core-cli` (D33). *Banned:* "force simulation" at runtime.

## Expedition (Door B)

- **Expedition** — one run of ≈ 5 items (D23). *Banned:* "quiz", "session" (a session is a telemetry day-unit), "quest", "level".
- **Item** (`ProbeItem`) — one numeric or multiple-choice question with a `why` (I10). *Banned:* "question", "exercise", "task".
- **Slot** — one of the ≈ 5 places in an expedition: **new-learning slot** (from the fringe) or **review slot** (due node).
- **Fringe** — the trail's outer fringe (D48): nodes not cleared whose prerequisites are cleared. *Banned:* "frontier" (v2 name), "next up", "available".
- **Unit expedition** — an expedition restricted to one unit (D46).
- **Retry** — the second item on the same node after a miss (D27). **Miss** — an incorrect answer. **Clear** — reaching the clear rule (two correct on distinct items). *Banned:* "fail" for an item (fail is a probe outcome), "pass a node".
- **Spaced repetition ladder** — the fixed due intervals (expedition Q2).
- **Student state** (`StudentState`) — the one persisted document (D32). *Banned:* "profile", "progress file", "save".

## Diagnosis (Door A)

- **Diagnosis event** — one Door A occurrence, from an expedition second miss or "Check me here". *Banned:* "tutoring session", "attempt".
- **Hypothesis** — "this may be blocked by X" (a `Diagnosis`); never a verdict (D11). **Candidate** — the upstream node X.
- **Probe** — two items on the candidate, ~60 s; outcome **pass / fail / declined** → diagnosis outcome **refuted / confirmed / unconfirmed / capped**.
- **Remediation** — one Explanation or WorkedExample for a confirmed candidate. **Backtrack level** — distance from the origin node (≤ 2, I4).
- **Blocked** — the mastery state set on a candidate that failed its probe, or beyond the cap. The map is the record (v2.5 §3). *Banned:* "deeper gap recorded", "record page".
- **Error type** (`ErrorType`) — a member of a node's closed catalogue, incl. `none_of_these`. **Distractor tag** — the error type an `mc` distractor or anticipated wrong numeric answer carries (diagnosis Q1). **Hint tier** — one of three levels of a `HintTree` branch.
- **Homework mode** — the M5 desktop web variant with structured input and CAS verification (`verification` domain). *Banned:* "Door A web", "tutor".

## Content and pipeline

- **Spine** — the index of authority: Ministry courses/strands/expectations (grade 9–12) and undergraduate sources. **Expectation** — one Ministry expectation code. **Strand** — a Ministry division of a course. **Paraphrase** — the project's own one-sentence rendering (I6). **Official link** — the outbound link to the Ministry page.
- **`source_ref`** — an undergraduate node's citation into a CC-licensed source (D2 revised). **Undergraduate source** — OpenStax / MIT OCW edition record.
- **Learning object** — a node's Explanation, WorkedExamples, ErrorType catalogue, HintTree, ProbeItem pool.
- **Bundle** — an immutable versioned set of JSON files with a manifest (`ContentBundle`); **snapshot** — the bundle shipped inside the app. **Asset version** — id + content hash.
- **Generation run / RunOutput / PromptVersion / IntersectionResult / SyntheticSolutionSet** — as in `content-generation.md`; **L0/L1/L2/L3** — structural / multi-source / multi-run / probe-data verification levels (brief §6).
- **Pipeline** — the owner-run Python program (D41). **`core-cli`** — the `Core` executable the pipeline invokes for L0 and layout (D42).

## Runtime and platform

- **Tier 0 / Tier 1 / Tier 2** — deterministic / on-device Foundation Models / cloud (queued). **Threshold** — the per-task confidence floor. **Fallback decision** — the record of a Tier 1 call that ended in Tier 0 behaviour.
- **Capability facts** — OS version + Foundation Models availability (platform). *Banned:* "device fingerprint".
- **Telemetry event / batch** — one derived observation / the per-day aggregate that leaves the device (`telemetry.md`). **Consent** — the one-tap switch, on by default. *Banned:* "analytics", "tracking", "user id", "install id".
- **Session** — in telemetry only: one app foreground period on one day. Not a product concept.
- **Owner** — the product owner (tester, delivery verifier, never content reviewer). **Student** — the only user role (D38). *Banned:* "parent", "teacher", "learner", "player".

## Process words

- **Door A / B / C** — diagnosis / expedition / map. **Demo, M4′, M1 … M5** — milestones per `docs/idea.md`. **Q1–Q5** — the question protocol (CLAUDE.md RULE 1), not to be confused with a domain doc's open questions **Q1–Q6**, which are always qualified by domain ("map Q2").
