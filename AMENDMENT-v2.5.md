# Amendment v2.5 — Telemetry without identifiers; map is the record

Date: 2026-09-09
Applies to: AMENDMENT-v2.3.md, AMENDMENT-v2.4.md
Status: rulings final.

## 1. D17 (amended again) — no install identifier.

Telemetry is on by default, one-tap off, and carries **no identifier of any kind** — no install ID, no device ID, no session token. All cross-event continuity is computed on the device and reported as derived events:

- Retention: the device emits a single "day-N return" event; the server never links days.
- **L3 graph validation** (this is the one place continuity is load-bearing): the device knows its own mastery state for every node. On each probe result for node B, it emits an edge-level event for each prerequisite edge A→B: `{edge_id, upstream_state: cleared|blocked|fog, downstream_result: pass|fail}`. The server only counts. The conditional "fail B given failed A" is a ratio of counts per edge; no per-student linkage is required.
- Everything else in D40 (node results, marker placement, landmark taps, session and expedition events) is aggregate-only as sent.

"Data Not Linked to You" is therefore a property of the data, not a declaration. The "reset ID" feature is dropped. I5 wording: "on by default, one-tap off; no identifiers".

## 2. Endpoint constraint — accepted.

"No IP retention" is a tech-stack hard constraint on the telemetry endpoint (request logging disabled or IP-stripped at ingress), chosen at Phase 5, and an L0-level acceptance item in the `telemetry` domain.

## 3. D4 / I4 — the map is the record.

Upstream nodes beyond the two-level backtrack cap are marked `blocked` and remain in fog on the map. The student may enter them at any time; the expedition scheduler never pushes them. No record page, no other consumer. I4: "deeper gaps are marked on the map only."

## 4. D42 — single implementation principle.

Anything for which the pipeline and the app must produce the same answer is implemented once, in `Core` (Swift), and exposed through the `Core` command-line target. Currently: L0 validation and layout. Python calls the binary; it does not reimplement. v2.4 §3's mention of L0 in the Python pipeline means "invoked by", not "implemented in".

## 5. Bookkeeping

- D30 and D37: unassigned. Do not reuse.
- iCloud sync (D36): applies only when the device is signed in to iCloud; otherwise silent fallback to local storage. Platform-domain default behaviour.
