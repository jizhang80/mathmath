# ARBITER ESCALATION: task 02.3 (Q-E) — Q5

**Date**: 2026-09-10
**Spec**: tasks/epic-02-task-03-l0t-demo-trail-resolution.md (not yet written; held by this escalation)
**Route**: Q5-owner. This changes the meaning of hard invariant I8, "every generated trail is a path in the graph" (`PROJECT-BRIEF-v2.md:126`, CLAUDE.md I8). The locked decisions involved are D14, D45 and D47, and the delta is v2.7 §2.
**Triggering report** (planner Q-E, verbatim):

> L0-T / interaction-contract §3 require each course segment of a trail to be a directed path in the graph. In
> data/demo neither course's unit-ordered node list is a directed path, and no ordering can be: MTH1W's induced
> subgraph has 3 sources (integer-operations, rational-numbers, simplifying-expressions) and 3 sinks; adding
> scientific-notation→linear-relations creates a cycle (with solving-linear-equations→exponent-laws→scientific-notation);
> edge solving-linear-equations(u3)→exponent-laws(u2) runs against unit order. MCR3U: rational-expressions is
> isolated within the course (its only in-edge is from factoring in MTH1W). The only true path is the D14 starting
> chain (13 nodes across both courses). CLAUDE.md I8 and AMENDMENT-v2.7 §1 say "every generated trail is a path in
> the graph".

## Findings analysis

| # | Claim | Verification | Classification |
|---|-------|--------------|----------------|
| 1 | The locked text requires a trail to be a path. | `PROJECT-BRIEF-v2.md:126`: "every trail is a path in the graph". `contracts/graph-constraints.md` L0-T: "every segment's `node_ids[]` is a directed path in the graph; a course segment contains only that course's nodes". `interaction-contract.md` §3: "course segments in unit order … every segment a path (L0-T)". `expedition.md:112-113`: "order its nodes by unit". **Correction to the report:** AMENDMENT-v2.7 §1 amends only the coverage clause of I8 (`AMENDMENT-v2.7.md:13`). It contains no trail or path definition. CLAUDE.md's I8 cites "§5, v2.7 §1" as a combined source. | VALID |
| 2 | MTH1W's unit-ordered set is not a directed path. | Units come from `data/demo/courses.json:97-132` plus node codes from `nodes.json`: u1 {integer-operations, order-of-operations, rational-numbers}, u2 {exponent-laws, scientific-notation}, u3 {linear-relations, solving-linear-equations, solving-systems-of-equations}, u4 {simplifying-expressions, polynomials, factoring}. The induced edges (`edges.json`) have sources integer-operations, rational-numbers and simplifying-expressions, and sinks factoring, scientific-notation and solving-systems-of-equations. The edge solving-linear-equations→exponent-laws (`edges.json:20-35`) runs u3→u2. | VALID |
| 3 | MCR3U has an isolated node. | `rational-expressions` (MCR3U u1, A1.3) has one edge only, `factoring`→it (`edges.json:260-275`), and `factoring` is an MTH1W node. | VALID |
| 4 | A "path" reading exists that holds on `data/demo`. | Four readings were tested. (a) **Directed path** fails, per rows 2 and 3. (b) **Undirected simple path** fails: MTH1W's induced undirected graph is a tree with 6 leaves, and rational-expressions has no in-course neighbour. (c) **Consecutive pairs comparable in the transitive closure** fails: rational-numbers is incomparable with integer-operations and order-of-operations, and rational-expressions is incomparable with every MCR3U node. (d) **Topological consistency with unit order** fails because solving-linear-equations (u3)→exponent-laws (u2) points backwards. The only reading that passes is "every id is a graph node", which drops the word "path". | INVALID (no content-bearing reading exists) |
| 5 | A `data/demo` fix could resolve it. | The backward edge is the D14 step "MTH1W linear relations/equations → exponent laws" (`PROJECT-BRIEF-v2.md:68`). The unit order is protected: v2.7 §2 says "The Demo's hand-written unit lists stand." A fix must therefore break D14, break v2.7 §2, or add prerequisite edges that are not true. Door A's query would then hypothesise those false edges (`graph-constraints.md` § Query rules). The obstruction also returns for every generated course at M1, because a course is a node subset of a DAG with several entry concepts. | OUT-OF-SCOPE (data fix breaks locked decisions) |

## Why arbitration cannot resolve at the spec level

Every content-bearing meaning of "path" fails on the locked Demo data. It will also fail on any real course subset. The only passing rule redefines what I8's trail clause guarantees, and the meaning of a hard invariant is the owner's to set. The remedy of editing data would break D14 or v2.7 §2, which is also a Q5. No spec text can make `generate_trail` both honour the contract and succeed on `data/demo`. As written, every regeneration raises `EXP_TRAIL_INVALID` and "the previous trail stands", but a first launch has no previous trail. That blocks brief AC2 and AC8 and the whole of Door B.

## Decision the owner must make

What does "every generated trail is a path in the graph" (I8) guarantee for a **course segment**, given that a segment holds a course's nodes in unit order (D45, D47)?

**Options**

- **A (recommended): order-consistent and connected, not a literal path.**
  - A course segment is exactly the course's nodes.
  - They are ordered by unit and, within a unit, topologically, with ties by node id.
  - An edge that runs against unit order is *reported*, never failed. This mirrors the L0-4 "flagged, not failed" pattern.
  - Each extension node is reachable along directed edges from the segment before it.
  - Every id must be a graph node that occurs once in the trail.
  - D14, D45, D47, v2.7 §2 and all demo edges stay as they are. `EXP_TRAIL_INVALID` keeps real teeth: a foreign node, an unknown id, a unit-order violation, or an unreachable extension node.
  - Proposed L0-T text, for a later `contract(graph-constraints)` bump in task 02.3:
    > | L0-T | **Trail segments** (generated at runtime, expedition W8): every id in a segment's `node_ids[]` is a node
    > of the graph and occurs once in the trail; a course segment contains exactly the nodes whose `courses[]` names
    > that course, ordered by unit (a node's unit is the unit of its lowest-ordered expectation code of that course)
    > and, within a unit, in a topological order of the edge set, ties by node id; every node of an extension segment
    > is reachable along directed edges from a node of the segment before it, and the segment is in a topological
    > order. An edge between two nodes of one course segment that runs against unit order is listed in the trail
    > report, never failed. | `EXP_TRAIL_INVALID` | same `Core` function; runs at generation, not on the bundle |
  - I8's wording would read "… every generated trail is ordered consistently with the graph and connected to it", recorded by `brief-amender` as an amendment.
- **B: keep the literal directed path, on a subset.** A course segment becomes one directed path through part of the course, for example its stretch of the D14 chain. The other course nodes leave the trail and therefore the fringe (D48). 7 of 11 MTH1W nodes would never be scheduled except through Door A. This conflicts with D47 and `expedition.md` W8 ("the course's nodes in unit order"). Not recommended.
- **C: keep the literal rule and fix the data.** This means reordering MTH1W's units (against v2.7 §2) or deleting the D14 edge, and adding invented edges to make each course Hamiltonian. The same breakage returns at M1 for every generated course. Not recommended.
- **D: drop the trail clause from L0.** Keep only "a trail is a node-id list" (D49) plus course membership. This is simplest, but it loses the check that catches a mis-ordered or disconnected generator. Weaker than A.

## Recommended action

Owner ruling on I8's trail clause. The arbiter recommends **A**.
- After the ruling, `brief-amender` records it as an amendment (v2.8) and `spec-architect` or the planner re-scopes task 02.3 as a `contract(graph-constraints)` L0-T bump carrying the chosen text.
- Until then, hold 02.3, 02.5, 02.6 and 02.7. Tasks 02.1, 02.2 and 02.4 do not depend on the ruling and may proceed.
- Other pre-dispatch rulings: `tasks/arbitration/arbiter-02-predispatch.md`.
