# Q5 ruling — EPIC 02, Q-E (meaning of I8's trail clause)

Owner ruling, 2026-09-10, in conversation. Escalation: `tasks/blocked/blocked-arbiter-02-03.md`; run stop:
`docs/blocked/run-stop-02-qe-trail-path.md`.

**Ruled: option A.**

- A trail's **course segment** is exactly that course's nodes resident in the bundle, ordered by **unit order**,
  then **topologically by the graph within each unit** (ties by node id).
- An edge that runs **against unit order** (e.g. `solving-linear-equations` u3 → `exponent-laws` u2) is
  **reported** (a warning in the L0 report), **not a failure**.
- Every **extension segment** node must be **reachable in the graph** from the segment before it.
- The L0-T row of `contracts/graph-constraints.md` and the I8 wording in `CLAUDE.md` are rewritten to match.
  The contract change is a versioned bump carried by task 02.3 (route a); **`data/demo` is not changed**.

Rejected: B (literal path over a subset; conflicts with D47), C (rewrite data; breaks D14 / AMENDMENT-v2.7 §2,
invents edges), D (drop the rule).

Unblocks 02.3, 02.5, 02.6, 02.7.
