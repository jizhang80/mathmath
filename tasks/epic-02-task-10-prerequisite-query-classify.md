# Epic 02 · Task 10: Deepest-unmastered-prerequisite query + Tier-0 distractor-tag classify

---
epic: 02
task: 10
slug: prerequisite-query-classify
kind: feat
risk: seam
depends_on: [02.8]
model: sonnet
---

## §1 Goal & acceptance criteria

Goal: `Core` gains two pure, Tier-0-only functions that the diagnosis machine (task 02.11) will call
without needing to touch either file: `PrerequisiteQuery.deepestUnmasteredPrerequisite` (concept-graph W3
— a breadth-first walk over the graph's incoming edges, at most `levelBudget` levels upward from an origin
node, returning the deepest unmastered candidate) and `Classify.classify` (diagnosis W1 step 2 — a
deterministic distractor-tag lookup over failed probe attempts, returning an `ErrorType` id or the literal
fallback `"none_of_these"`). Neither function calls a model, takes an adapter, or reads any free-text
input.

Invariants in play:
- **I1** — neither function decides "correctness" of a student answer; `classify` only tags an
  already-known-wrong answer against a pre-generated distractor tag, and the prerequisite query only
  selects a candidate to probe next. Actual item correctness checking is task 02.7's `ItemChecker`, not
  touched here.
- **I2** — both functions are Tier 0, unconditional, with no confidence threshold and no fallback branch
  to reason about: there is no model call to gate. `classify` never reads the optional Tier-1 free-text
  line (deferred to EPIC 13).
- **I4** — `levelBudget` is an explicit parameter of `deepestUnmasteredPrerequisite`, never a
  caller-invisible constant; the walk never exceeds it.
- **I10** — `classify`'s only input is `ProbeItem`s and a submitted value that is either a normalised
  numeric string or a choice id — never free text.
- **I14** — both files import Foundation only, are pure value transformations over their arguments (no
  system clock read, no file I/O, no global mutable state), and live in `Core` — the only place this logic
  exists.

Acceptance criteria (each independently verifiable):

- AC1: `deepestUnmasteredPrerequisite` never returns a candidate at depth > `levelBudget`.
- AC2: on a constructed tie (≥ 2 unmastered nodes at the same, deepest, in-budget depth), the returned
  candidate is the one the Q3 order picks (highest incoming-edge confidence, then lowest node id).
- AC3: when no unmastered node exists within `levelBudget`, the result carries `candidate: nil` and
  `code: .graphNoPrerequisite`.
- AC4: for every `data/demo` `ProbeItem` wrong answer (`numeric`) or distractor choice (`mc`) that carries
  an `errorTypeId`, `classify` given a single matching failed attempt returns that exact `errorTypeId`.
- AC5: `classify` given a failed attempt whose submitted value matches neither a `wrongAnswers[].value` nor
  a `choices[].id` on the item returns the literal string `"none_of_these"`.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Core/Sources/Core/Graph/PrerequisiteQuery.swift` — NEW. `PrerequisiteQuery` enum,
  `deepestUnmasteredPrerequisite`, `PrerequisiteCandidate`, `PrerequisiteQueryResult`.
- `Packages/Core/Sources/Core/Diagnosis/Classify.swift` — NEW. `Classify` enum, `classify`,
  `FailedProbeAttempt`.
- `Packages/Core/Tests/CoreTests/PrerequisiteQueryTests.swift` — NEW. Companion test suite for
  `PrerequisiteQuery`.
- `Packages/Core/Tests/CoreTests/ClassifyTests.swift` — NEW. Companion test suite for `Classify`.
- `Packages/Core/Tests/CoreTests/Support/PropertyGen.swift` — MODIFY. Add this task's own graph-generator
  functions (small synthetic node/edge sets for the tie-break and depth-cap property tests), appended to
  the existing namespace per its own doc comment: "Later tasks (02.5-02.7, 02.10-02.12) add their own
  generator functions to this same file/namespace rather than duplicating a parallel helper" (`Packages/Core/Tests/CoreTests/Support/PropertyGen.swift:9-10`). Do not alter any existing function in this
  file.

Out-of-scope (do not touch even if tempted):

- `Packages/Core/Sources/Core/CoreError.swift` — **already carries** both `graphNoPrerequisite =
  "GRAPH_NO_PREREQUISITE"` (`Packages/Core/Sources/Core/CoreError.swift:26`) and `diagNoPrerequisite =
  "DIAG_NO_PREREQUISITE"` (`Packages/Core/Sources/Core/CoreError.swift:23`), confirmed by direct read of
  the file at spec-writing time. No edit is needed or permitted here.
- `Packages/Core/Sources/Core/Events/CoreEvent.swift` — `graphPrerequisiteReturned = "graph.prerequisite_returned"` already exists (`Packages/Core/Sources/Core/Events/CoreEvent.swift:49`); this task
  reuses it, it does not add to it.
- `Packages/Core/Sources/Core/Validation/GraphIndex.swift` — read-only precedent; this task does not add
  an `edgesByTo` field to it (see §6 default on why).
- Any file under `Packages/Core/Sources/Core/State/` (`MarkerTrailGeneration.swift`,
  `MasteryTransitions.swift`) — owned by tasks 02.4/02.5; the diagnosis machine (02.11) is the only later
  task allowed to call into this task's two new files.
- `data/demo/**` — read-only fixture for this task's tests; no edit.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/graph-constraints.md` — heading `## L0 rule table` / § *Query rules (also `Core`)*
  (v1.1.0), re-read and byte-verified at `contracts/graph-constraints.md:29-31`:
  > **Query rules (also `Core`):** the deepest-unmastered-prerequisite query walks ≤ 2 levels breadth-first
  > (I4), treats `fog` as a candidate (concept-graph Q2), breaks ties by highest edge confidence, then lowest
  > depth marker, then node id (Q3). The fringe (D48) and the clear rule are in `interaction-contract.md`.

- `contracts/interaction-contract.md` — § 4 Diagnosis, `classify` bullet (v0.9.1), re-read and
  byte-verified at `contracts/interaction-contract.md:82-83`:
  > - `classify`: distractor-tag lookup over the failed items → `error_type` or `none_of_these` (diagnosis Q1); Tier 1 may *suggest* from the optional typed line (runtime-tiers), never decides.

- `contracts/interaction-contract.md` — § 4 Diagnosis, `hypothesise` bullet (v0.9.1), re-read and
  byte-verified at `contracts/interaction-contract.md:84-85`:
  > - `hypothesise`: candidate = deepest unmastered prerequisite within remaining levels (graph query), biased by `implies_prerequisite`; none → `DIAG_NO_PREREQUISITE` → hint → returned.

- `contracts/content-policy.md` — § Generated content (implicit heading; the file has no explicit `##`
  before this paragraph — cited by its enclosing bullet "Distractor tags"), re-read and byte-verified at
  `contracts/content-policy.md:36-37`:
  > - Distractor tags: every `mc` distractor and every anticipated numeric wrong answer names an `ErrorType` of
  > its node (diagnosis Q1); `none-of-these` is never a tag.

- `contracts/error-codes.json` — entries `DIAG_NO_PREREQUISITE` and `GRAPH_NO_PREREQUISITE`, re-read and
  byte-verified at `contracts/error-codes.json:20` and `:25`:
  > {"code": "DIAG_NO_PREREQUISITE", "recoverable": true, "surface": "student", "user_text": "Nothing upstream to check — here's a hint."},
  > {"code": "GRAPH_NO_PREREQUISITE", "recoverable": true, "surface": "internal", "user_text": null},

Ratified domain-doc text (`docs/domains/concept-graph.md`, re-read and byte-verified):

- W3, `:75-88`:
  > **Pre:** a Node id (from the Diagnosis in `diagnosis`) and that student's local mastery state (`StudentState`, expedition).
  > **Steps:**
  > 1. (Tier 0) Read the Node's incoming edges; no model runs here, the query is deterministic (I2).
  > 2. (Tier 0) Filter to unmastered prerequisites; with no prior data a node is **unknown**, and unknown is a
  > candidate (Q2) — the probe, not the graph, decides.
  > 3. (Tier 0) Walk upward breadth-first, **at most 2 levels** (I4, D4), returning the deepest unmastered
  > candidate, ties broken per Q3. If none is found, return "none within reach"; deeper gaps are marked `blocked` on the map only (D4, v2.5 §3).
  >
  > **Post:** one candidate Node (or none) with its edge confidence, ready to be presented as a hypothesis and probed. The walk terminates: acyclic graph, hard cap. Emits `graph.prerequisite_returned`.

- Q2/Q3, `:150-158`:
  > **Q2 — What "unmastered" means with no prior data.** **Default:** unknown counts as a candidate, so a
  > fresh student can be probed on any prerequisite. **Trade-off:** diagnostic reach and early L3 data against
  > probing nodes the student already knows — bounded by the ~60 s probe.
  > **Ratified 2026-09-08:** default accepted.
  >
  > **Q3 — Tie-breaking among equally deep prerequisites.** **Default:** highest edge confidence, then lowest
  > depth marker, then node id. **Trade-off:** deterministic and testable, but biases probing toward confident
  > edges, starving disputed ones.
  > **Ratified 2026-09-08:** default accepted.

Prior signatures / schema / registry entries this task builds on, re-read and byte-verified directly from
the current tree (not the bundle) — see §6 for a bundle-fidelity note on the mastery-filter language:

- `Packages/Core/Sources/Core/Model/Nodes.swift:9-25,48-65,105-114`:
  ```swift
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
      public let check: ProbeCheck?
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

- `Packages/Core/Sources/Core/Model/Edges.swift:9-16`:
  ```swift
  public struct Edge: Codable, Equatable {
      public let from: String
      public let to: String
      public let sources: [EdgeSource]
      public let generationAgreement: Int
      public let confidence: Double
      public let probeStats: ProbeStats
  }
  ```
  Edge direction verified from `contracts/graph-constraints.md:12` (L0-2): "No edge goes from a later
  course to an earlier one: for every edge, `min depth(from) ≤ max depth(to))`" — `from` is the
  prerequisite (shallower), `to` is the dependent (deeper). Confirmed against `data/demo/edges.json:5-6`:
  `"from": "linear-relations", "to": "solving-linear-equations"` (a prerequisite-of relationship). A
  node's *incoming edges* in the W3 sense ("Read the Node's incoming edges") are therefore the edges of
  `bundle.edges.edges` whose `to == nodeId`; their `from` fields are that node's direct prerequisites.

- `Packages/Core/Sources/Core/Model/StudentState.swift:10-42`:
  ```swift
  public struct StudentState: Codable, Equatable {
      public let schemaVersion: Int
      public let formatVersionSeen: String
      public let syllabi: [String]
      public let marker: Marker
      public let nodes: [String: NodeState]
      public let trail: Trail
      public let expeditionLog: [ExpeditionLogEntry]
      public let probeLog: [ProbeLogEntry]
      public let installDay: String
      public let consentOn: Bool
  }
  public struct NodeState: Codable, Equatable {
      public let mastery: Mastery
      public let correctCount: Int
      public let lastProbe: String?
      public let nextDue: String?
      public let ladderRung: Int
      public let remediated: Bool?
  }
  public enum Mastery: String, Codable {
      case fog
      case cleared
      case blocked
  }
  ```

- `Packages/Core/Sources/Core/Validation/GraphIndex.swift:5-21` (internal, same module — usable from any
  file in the `Core` target, including this task's two new files):
  ```swift
  struct GraphIndex {
      let nodesById: [String: Node]
      let edges: [Edge]
      let edgesByFrom: [String: [Edge]]
      let regionsById: [RegionId: Region]
      let coursesByCode: [String: Course]
      let sortedNodeIds: [String]

      init(bundle: ContentBundle) { ... }
  }
  ```
  `GraphIndex` has no `edgesByTo` — only `edgesByFrom`. This task's query walks *upward* (toward
  prerequisites), which needs edges grouped by `to`, so `PrerequisiteQuery` builds its own local `[String:
  [Edge]]` grouped by `to` from `GraphIndex.edges` (a `Dictionary(grouping:by:)` one-liner mirroring
  `edgesByFrom`'s own construction) rather than extending `GraphIndex` (out of scope, §2).

- `Packages/Core/Sources/Core/CoreError.swift:10-28` (full enum, already carries both codes this task
  needs — see §2 out-of-scope):
  ```swift
  public enum CoreError: String, Error, CaseIterable {
      case graphL0Failed = "GRAPH_L0_FAILED"
      case mapLayoutMissing = "MAP_LAYOUT_MISSING"
      case mapRegionUnknown = "MAP_REGION_UNKNOWN"
      case mapLandmarkUnsourced = "MAP_LANDMARK_UNSOURCED"
      case spineUnitEmpty = "SPINE_UNIT_EMPTY"
      case spineSourceRefUnresolved = "SPINE_SOURCE_REF_UNRESOLVED"
      case platformBundleIntegrityFailed = "PLATFORM_BUNDLE_INTEGRITY_FAILED"
      case expNoFringe = "EXP_NO_FRINGE"
      case expTrailInvalid = "EXP_TRAIL_INVALID"
      case expItemPoolEmpty = "EXP_ITEM_POOL_EMPTY"
      case expStateWriteFailed = "EXP_STATE_WRITE_FAILED"
      case expNodeNotInGraph = "EXP_NODE_NOT_IN_GRAPH"
      case diagNoPrerequisite = "DIAG_NO_PREREQUISITE"
      case diagProbeUnavailable = "DIAG_PROBE_UNAVAILABLE"
      case diagStateWriteFailed = "DIAG_STATE_WRITE_FAILED"
      case graphNoPrerequisite = "GRAPH_NO_PREREQUISITE"
      case mapMarkerOffTrail = "MAP_MARKER_OFF_TRAIL"
  }
  ```

- `ContentBundle` (`Packages/Core/Sources/Core/BundleIO.swift:8-16`):
  ```swift
  public struct ContentBundle {
      public let manifest: Manifest
      public let regions: RegionsFile
      public let nodes: NodesFile
      public let edges: EdgesFile
      public let courses: CoursesFile
      public let landmarks: LandmarksFile
      public let sources: SourcesFile
  }
  ```

- `CoreEvent.graphPrerequisiteReturned` (`Packages/Core/Sources/Core/Events/CoreEvent.swift:49`):
  ```swift
  case graphPrerequisiteReturned = "graph.prerequisite_returned"
  ```

Precedent for this task's file shape (cited for shape only, not to be mirrored line-for-line — see the
independent invariant obligations in §1 and §4): `Packages/Core/Sources/Core/State/MarkerTrailGeneration.swift`
uses a `public enum <Name> { public static func ... }` namespace, builds a `GraphIndex(bundle:)` once per
call, returns a small `Equatable` result struct, and (in `MarkerReconciliationResult`) pairs a nullable
payload with a nullable `CoreError` "code" field returned as data rather than thrown — this task's
`PrerequisiteQueryResult` follows that same "data, not thrown" shape (§4 default).

## §4 Implementation outline

1. **Layer.** Both functions live in layer ② concept graph (query) and layer ④ interaction (diagnosis
   classify) respectively, per the plan's task description. Neither performs I/O, encoding, or rendering.

2. **`PrerequisiteQuery.swift`** (`Packages/Core/Sources/Core/Graph/`):
   - `public struct PrerequisiteCandidate: Equatable { public let node: Node; public let depth: Int; public let edgeConfidence: Double }`
   - `public struct PrerequisiteQueryResult: Equatable { public let candidate: PrerequisiteCandidate?; public let code: CoreError? }`
     — `code` is `nil` when `candidate` is non-nil, and `.graphNoPrerequisite` when `candidate` is `nil`
     (mirroring `MarkerReconciliationResult`'s "code as data" shape — §3 precedent note).
   - `public enum PrerequisiteQuery { public static func deepestUnmasteredPrerequisite(originId: String, biasErrorTypeId: String?, state: StudentState, bundle: ContentBundle, levelBudget: Int) -> PrerequisiteQueryResult }`
   - Algorithm (BFS upward from `originId`, at most `levelBudget` levels):
     a. Build `edgesByTo: [String: [Edge]] = Dictionary(grouping: bundle.edges.edges, by: \.to)` once.
     b. `visited = [originId: 0]` (depth map); `frontier = [originId]`.
     c. For `depth` in `1...levelBudget` (stop early if `frontier` is empty): for each node `n` in
        `frontier`, gather `edgesByTo[n] ?? []`; for each such edge, if `edge.from` is not already in
        `visited`, record `visited[edge.from] = depth` and remember the edge's `confidence` for
        `edge.from` (if `edge.from` is reached by more than one edge at this depth, keep the
        higher-confidence one). The next frontier is the set of newly-visited node ids at this depth.
     d. Mastery filter: a node id is **unmastered** iff `state.nodes[id]` is absent (unknown — Q2), or
        `state.nodes[id]!.mastery == .fog`, or `state.nodes[id]!.mastery == .blocked`. A node whose
        `mastery == .cleared` is never a candidate but the walk still passes through it upward (the walk
        is over graph structure only; mastery filtering happens after the walk, §6 default).
     e. Candidates = `{ id ∈ visited.keys, id != originId, unmastered(id) }`. If empty, return
        `PrerequisiteQueryResult(candidate: nil, code: .graphNoPrerequisite)`.
     f. `deepest = candidates.map { visited[$0]! }.max()!`; `deepestCandidates = candidates.filter { visited[$0] == deepest }`.
     g. Bias (`hypothesise` bullet, `implies_prerequisite`): if `biasErrorTypeId` is non-nil, look up
        `bundle.nodes.nodes.first { $0.id == originId }?.errorTypes.first { $0.id == biasErrorTypeId }?.impliesPrerequisite`;
        if that id is a member of `deepestCandidates`, it is the winner — skip step h.
     h. Otherwise, Q3 tie-break over `deepestCandidates`: highest `edgeConfidence` (from step c), then
        lowest node id (ascending, string/byte order — depth is already equal within this set, so "lowest
        depth marker" from the contract text is vacuous here and not applied as a separate step).
     i. Look up the winning id's `Node` from `bundle.nodes.nodes` (must exist — every visited id came
        from an edge in an already-L0-passed bundle, so `nodesById` coverage is guaranteed by L0
        code↔node coverage, I8); return `PrerequisiteQueryResult(candidate: PrerequisiteCandidate(node: winnerNode, depth: visited[winnerId]!, edgeConfidence: winnerConfidence), code: nil)`.
   - This function does not itself emit `CoreEvent.graphPrerequisiteReturned` — task 02.11 (the diagnosis
     machine, the only caller) emits it alongside its own event sequence, consistent with `CoreEvent`'s
     own doc comment that only a caller pairs an event with data (`Packages/Core/Sources/Core/Events/CoreEvent.swift:5-7`).

3. **`Classify.swift`** (`Packages/Core/Sources/Core/Diagnosis/`):
   - `public struct FailedProbeAttempt: Equatable { public let item: ProbeItem; public let submittedValue: String; public init(item: ProbeItem, submittedValue: String) { self.item = item; self.submittedValue = submittedValue } }`
   - `public enum Classify { public static func classify(_ attempts: [FailedProbeAttempt]) -> String }`
   - Matching, per attempt, in `attempts` order (first match wins):
     - `.numeric` item: match iff `attempt.submittedValue == wrongAnswer.value` for some entry of
       `item.wrongAnswers ?? []`; on match, return that entry's `errorTypeId`.
     - `.mc` item: match iff `attempt.submittedValue == choice.id` for some entry of `item.choices ?? []`
       whose `errorTypeId != nil`; on match, return that entry's `errorTypeId!`.
   - If no attempt in `attempts` matches, return the literal string `"none_of_these"`.
   - `submittedValue` for a numeric attempt is assumed already normalised to the same canonical string
     space as `wrongAnswers[].value` by the caller (the expedition run machine, task 02.7) — `classify`
     performs exact string equality only and does not re-derive or re-normalise a numeric value itself
     (§6 default; this keeps `classify` a pure lookup, not a second correctness engine, consistent with
     I1).

4. **Error codes thrown.** Neither function throws. `PrerequisiteQueryResult.code` carries
   `CoreError.graphNoPrerequisite` (`contracts/error-codes.json:25`) as data on the no-candidate path; it
   is never thrown as a Swift `Error`. `classify` raises no error code — an unmatched attempt is not a
   failure, it is the documented `"none_of_these"` abstention.

5. **Model-calling path.** Neither function calls a model; there is no confidence threshold or Tier-0
   fallback to state because there is no Tier-1/Tier-2 branch in either function (I2). The CAS is not
   invoked here either — `classify` never decides correctness, it tags an already-known-wrong answer
   (I1).

6. Smoke check: `swift test --package-path Packages/Core --filter PrerequisiteQueryTests` and `swift test
   --package-path Packages/Core --filter ClassifyTests` — both green.

## §5 Test plan (risk: seam — full plan)

- T1 happy path:
  - `deepestUnmasteredPrerequisite` on a small constructed graph (via this task's own `PropertyGen`
    additions) returns the correct single unmastered candidate at depth 1 when only one exists.
  - `deepestUnmasteredPrerequisite` on `data/demo`, origin `"polynomials"`, both `"exponent-laws"` and
    `"simplifying-expressions"` unmastered (`fog`), `levelBudget: 1`: returns `"exponent-laws"` (edge
    confidence 0.95, `data/demo/edges.json:36-51`) over `"simplifying-expressions"` (edge confidence 0.7,
    `data/demo/edges.json:228-243`) — this is AC2's real-bundle instance of the Q3 tie-break, and mirrors
    the scenario the arbiter verified reachable in `tasks/arbitration/arbiter-02-predispatch.md` § Q-G.
  - `classify` given one `FailedProbeAttempt` per `data/demo` item whose submitted value is a tagged
    `wrongAnswers[].value` (numeric items) or a tagged `choices[].id` (mc items) returns that entry's
    `errorTypeId`, for every such tagged entry in the bundle (AC4) — iterate `bundle.nodes.nodes`,
    `probeItems`, `wrongAnswers ?? []` and `choices ?? []`, assert each tagged entry round-trips through
    `classify`.
- T2 negative — invalid input rejected at the boundary: N/A in the schema-validation sense (neither
  function decodes untrusted JSON — that is `BundleIO`'s job, already tested). The seam-appropriate
  negative here is AC5: `classify` given a `FailedProbeAttempt` whose `submittedValue` matches no
  `wrongAnswers[].value` and no `choices[].id` on that item returns `"none_of_these"`, not a match by
  coincidence and not a thrown error.
- T3 error-taxonomy: `deepestUnmasteredPrerequisite` on a constructed state where every reachable node
  within `levelBudget` is `.cleared` (or the origin has no incoming edges at all) returns
  `PrerequisiteQueryResult(candidate: nil, code: .graphNoPrerequisite)` — assert `code ==
  .graphNoPrerequisite` exactly, the registry code from `contracts/error-codes.json:25`.
- T4 conformance per requirements §B.1 (contract + invariant assertions):
  - AC1 as a property test: for 20+ generated small acyclic graphs (this task's `PropertyGen` additions,
    seeded, deterministic) and `levelBudget ∈ {1, 2}`, every returned candidate's `depth ≤ levelBudget`.
  - I4: same property test also asserts the function accepts `levelBudget` as an explicit call argument
    (a compile-time fact — the test simply calls it with two different values and observes two different
    max-depths are respected).
  - I2/I14: a grep-style or reflective assertion is unnecessary here — no model import exists in either
    file (the existing `ImportBoundaryNegativeControlTests.swift` / import-boundary test already covers
    "Foundation only" for the whole `Core` target and is not re-scoped by this task).
  - `content-policy.md:36-37` conformance: the T1 AC4 test's iteration only ever sees `errorTypeId` values
    other than `"none-of-these"` (hyphen) on any `wrongAnswers`/`choices` entry — assert this as a guard
    inside the AC4 test (`#expect(matched.errorTypeId != "none-of-these")`), proving the fixture and the
    match logic are never coincidentally exercising the catalogue sentinel instead of a real tag.
- T5 negative control for every regression guard:
  - Tie-break guard: construct a fixture where the *lower*-confidence candidate has the lexicographically
    *lower* node id (so a buggy "id-first, confidence-second" implementation would pick the same winner as
    a correct "confidence-first" implementation on this fixture alone) — the real regression-guard fixture
    additionally includes a **second** constructed case where the higher-confidence candidate has the
    lexicographically *higher* id, so only a correct confidence-first ordering passes both; assert a
    hand-swapped confidence-value fixture (confidences deliberately inverted from the intended winner)
    reds against the expected winner, proving the assertion is load-bearing.
  - `"none_of_these"` vs `"none-of-these"` guard: assert `Classify.classify([])` (empty attempts list)
    returns exactly `"none_of_these"` (underscore) — a negative control that constructs the same call but
    compares against `"none-of-these"` (hyphen) must fail, proving the test does not pass on either
    spelling.
- T6 idempotency / no-leak: `deepestUnmasteredPrerequisite` and `classify` are pure functions with no
  persisted or mutated external state; calling either twice with identical arguments returns
  `Equatable`-equal results (`PrerequisiteQueryResult == PrerequisiteQueryResult`, `String == String`) —
  assert this directly for one `data/demo` case per function.

## §6 Decision defaults

- IF the bundle's §D gloss ("Binds this task: The query filters prerequisites by mastery state: `cleared`
  always satisfies, `fog` is a candidate, `blocked` does not satisfy...") conflicts with the ratified
  domain doc THEN the domain doc wins: `docs/domains/concept-graph.md:81-82` says "Filter to unmastered
  prerequisites" with no exclusion of `blocked`, and Q2 (`:150-152`) defines "unmastered" only by contrast
  with `cleared` ("unknown counts as a candidate"). "Unmastered" = `{fog, blocked, absent}`; only `cleared`
  is excluded. The bundle's phrase appears to have carried over the *different* expedition-fringe-guard
  predicate `remediated(p)` (Q-A ruling, `tasks/arbitration/arbiter-02-predispatch.md` § Q-A) — that
  predicate governs a *downstream* node's eligibility for new-learning slots in `compose` (task 02.6), not
  this query's upstream candidate filter. This is a bundle-fidelity correction — flagged separately outside
  this spec for the bundle's own record.
- IF a node visited during the BFS walk is itself `.cleared` THEN the walk still passes through it to
  explore its own prerequisites (the walk is over graph structure, independent of mastery; only the
  candidate *selection* step filters by mastery) — per `docs/domains/concept-graph.md` W3 step 1 ("Read
  the Node's incoming edges; no model runs here") preceding step 2's filter, i.e. traversal and filtering
  are sequential, not fused.
- IF the `implies_prerequisite` bias node exists in the graph but is not among the deepest-stratum
  candidates (wrong depth, mastered, or unreachable within budget) THEN it is ignored and the normal Q3
  tie-break applies — the contract's "biased by `implies_prerequisite`" (`contracts/interaction-contract.md:84-85`) never overrides "deepest" itself, only breaks a tie within the deepest stratum (this
  task's own reading, since neither contract nor domain doc states the interaction between "deepest" and
  "biased" explicitly; this reading keeps "deepest unmastered prerequisite" true in all cases).
- IF `classify`'s `submittedValue` needs numeric normalisation before matching THEN that normalisation is
  the caller's responsibility (task 02.7's expedition run machine, per its file-scope ownership of
  numeric-answer checking under interaction-contract §2) — `classify` performs exact string equality only,
  keeping it a pure lookup rather than a second correctness engine (I1).
- IF multiple edges reach the same upstream node at the same BFS depth with different confidences THEN the
  higher confidence is kept for that node's tie-break comparison (no contract text addresses this
  multi-edge-same-node case directly; this is the conservative reading consistent with "breaks ties by
  highest edge confidence").
- Standing defaults: identifiers and timestamps are untouched by this task (no new `StudentState` field);
  no model call exists in either function, so no confidence threshold/fallback rule applies; telemetry is
  untouched; no identifying field is introduced; nodes' `paraphrase`/Ministry-text rules are untouched (no
  node content is authored here).

## §7 Done definition

The task is done when ALL gates pass:

- format + lint clean (`swift-format lint --strict`)
- `Core` build + test green (`swift build --package-path Packages/Core`; `xcodebuild test -scheme
  Core-Package` on the simulator)
- tests green for every case in §5
- conforms to every contract section cited in §3 and §4 (`graph-constraints.md` § Query rules,
  `interaction-contract.md` § 4 `classify`/`hypothesise`, `content-policy.md` § Distractor tags,
  `error-codes.json` `GRAPH_NO_PREREQUISITE`/`DIAG_NO_PREREQUISITE`), and to every invariant listed in §1
  (I1, I2, I4, I10, I14)

Commit subject: `feat(core): deepest-unmastered-prerequisite query and Tier-0 distractor classify`
