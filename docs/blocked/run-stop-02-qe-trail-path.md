# Run stop — EPIC 02, Q-E: what I8's "every generated trail is a path in the graph" means

Raised: 2026-09-10, `/run-epic 02` (chain 02–04), pre-dispatch arbitration.
Detail: `tasks/blocked/blocked-arbiter-02-03.md`; rulings on the other questions:
`tasks/arbitration/arbiter-02-predispatch.md`.

## Conflict
`PROJECT-BRIEF-v2.md:126`, I8 and the L0-T row of `contracts/graph-constraints.md` require each course segment of
a trail to be a path in the graph. In `data/demo` neither MTH1W nor MCR3U, in unit order, is a directed path, and
no ordering of either can be (multiple sources/sinks within each course; `rational-expressions` is isolated within
MCR3U). The edge `solving-linear-equations` (u3) → `exponent-laws` (u2) runs against unit order and is part of the
D14 chain; AMENDMENT-v2.7 §2 keeps the Demo's hand-written unit lists. Every real course will meet the same shape.

## Options
- **A (arbiter's recommendation):** a segment is exactly the course's nodes, ordered by unit then topologically
  within a unit; an edge against unit order is reported, not failed; every extension node must be reachable from
  the segment before it.
- **B:** literal path over a subset of the course — drops most course nodes, conflicts with D47.
- **C:** literal path + rewrite the data — breaks D14 / v2.7 §2, invents prerequisite edges.
- **D:** drop the trail rule from L0.

## Blocked until ruled
02.3, 02.5, 02.6, 02.7 (and thus the 02a wrap and EPICs 03–04). 02.1, 02.2, 02.4 are not blocked.
