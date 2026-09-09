# Domain — telemetry

Prefix: `TELEM`. Ground truth: `PROJECT-BRIEF-v2.md` + amendments (D17 as amended by v2.3 and v2.5, D36,
D40); invariants I1–I15 in `CLAUDE.md`.

## Purpose

Collect the minimum evidence needed to validate the concept graph empirically (brief §6, L3: the graph
predicts that students failing A fail B at a higher rate) and to observe product behaviour (D40), under
D17 as amended: **anonymous, aggregate, on by default with one-tap off, account-less, and carrying no
identifier of any kind** — no install, device or session id. All cross-event continuity is computed on the
device and sent as derived events; the server only counts. D17 is the whole specification of this domain;
everything below is mechanism. Milestone **M3** (the Demo has no telemetry — DEMO-BRIEF §2). Output feeds
`downstream_fail_given_upstream_fail` in `ProbeStats` (**concept-graph**).

It also owns the product's only write path off the device: one anonymous, serverless, append-only endpoint
(D36), deployed and operated separately from the app, under a hard Phase 5 constraint — **no IP retention**
(request logging disabled or IP-stripped at ingress; v2.5 §2). That constraint is an L0-level acceptance
item here.

## Actors and roles

| Actor | Can do here | Cannot |
|---|---|---|
| Student | Turn telemetry off (one tap) or back on; read which fields are sent | Be identified; be asked mid-run |
| Owner | Run the offline aggregation; apply the `Confidence` update; verify the endpoint's no-IP configuration at the wrap-gate | Recover a person, device or session thread; add an identifying field (I5) |
| System | Derive events on-device, buffer them, assemble an `AggregateBatch`, POST it, drop it on failure | Emit anything while off; attach an id, sub-day timestamp, free text or device fact |
| Local model (Tier 1), Generation model | No role | Anything (a `FallbackDecision` is only an event subject) |

## Core entities

**ConsentState** — a local record: **on by default** (v2.3), turned off by one tap on the settings
surface, revocable and restorable from the same place; a change takes effect before the next event is
written. It stores the state and the app version at the time of the last change — no identifier, no
sub-day timestamp. The settings surface shows the full field list of what is sent.

**TelemetryEvent** — one observation, from a closed set (D40 + v2.5 §1), each sourced from exactly one
upstream notification:

| Kind | Source | Fields |
|---|---|---|
| session start / end | `platform.launched`, app background | day, app version, bundle versions |
| expedition started / completed | **expedition** W1 / W5 | item count, cleared count, blocked count, abandoned flag |
| item result | `expedition.item_answered`, `diagnosis.probe_completed` | node id, correct, retry flag, tier |
| **edge observation (L3)** | derived on the device from every item result on node B, one per prerequisite edge A→B | `edge_id`, `upstream_state ∈ {cleared, blocked, fog}`, `downstream_result ∈ {pass, fail}` |
| marker placement / move | `map.marker_moved`, `expedition.marker_changed` | trail code, node id |
| landmark tap | `map.landmark_opened` | landmark id |
| diagnosis outcome | `diagnosis.returned` | origin node, candidate id, outcome, error type id or null, tier |
| fallback decision / tier capability | **runtime-tiers** W4 / W1 | task, reason, threshold side; availability |
| **day-N return** | derived on the device from install day | N (bucketed per Q2) |

The field allowlist is hard: node, edge, trail, landmark and `ErrorType` ids; booleans and small enums;
tier (0 or 1); day granularity; app and bundle versions. Nothing else may appear: never free text, never a
typed "what did you do" line (**diagnosis** Q1), never a timestamp finer than the day, never a device fact
(model, OS build, locale, storage, Apple Intelligence eligibility as a device property). Those exclusions
make the payload non-identifying, enforced by the type, not by convention.

**AggregateBatch** — the unit that leaves the device: `TelemetryEvent`s rolled into per-day counts,
carrying app and bundle versions and nothing that orders or links events within it. POSTed once; no read
path and no id, so two batches from one install are indistinguishable from two installs' batches — the
point of the design. The L3 conditional "fail B given A failed" is a ratio of counts per edge on the
server; no per-student linkage exists (v2.5 §1). Capped at **one observation per edge per batch** so a
heavy single user cannot dominate an edge's statistics (Q3).

## Workflows

### W1 — Change consent
**Pre:** any `ConsentState` (on on a fresh install). **Steps:** 1. On **Settings › Data** — never
mid-run, never a modal — show the field table above in plain words and the one-tap switch. 2. Write the
new state; if off, discard the unsent buffer. Tier 0. **Post:** `telemetry.consent_changed`; while off
nothing further happens. Batches already sent cannot be recalled — anonymous and aggregate, they cannot be
located; the surface says so.

### W2 — Derive and capture an event
**Pre:** consent on; a source notification arrived. **Steps:** 1. Map it to its kind; for an item result
on node B, also derive one edge observation per incoming edge A→B using the device's own `StudentState`
for `upstream_state` (**expedition**). 2. Validate against the allowlist schema; a field outside it fails
the write rather than being stripped (`TELEM_FIELD_NOT_ALLOWED`). 3. Append to the local buffer. Tier 0.
**Post:** buffered, nothing sent.

### W3 — Send a batch
**Pre:** consent on; buffer non-empty; online (**platform** connectivity). **Steps:** 1. Roll the buffer
into an `AggregateBatch` (cadence per Q2; edge cap per Q3). 2. POST to the endpoint. 3. On success clear
the sent events; on failure keep them to a bounded cap, then drop oldest. Tier 0. **Post:**
`telemetry.batch_sent` or `telemetry.batch_failed`; both terminate, so telemetry never blocks anything.

### W4 — Owner-run aggregation and confidence update (offline)
**Pre:** batches accumulated at the endpoint. **Steps:** 1. Export. 2. Aggregate per edge: observations by
`upstream_state` × `downstream_result`, giving `downstream_fail_given_upstream_fail` and its complement;
count at most one observation per edge per batch. 3. Drop edges below the minimum aggregate (Q4). 4. Hand
the result to `ProbeStats` (**concept-graph**), which recomputes `Confidence`; also emit the D40 product
report (returns by day-N, marker distribution, landmark taps, expedition completion) as counts. No model
at any step. **Post:** concept-graph produces an updated bundle; this domain writes nothing to the graph.

### W5 — Verify the endpoint configuration (Owner, wrap-gate)
**Pre:** the endpoint chosen at Phase 5 is deployed. **Steps:** confirm request logging is off or
IP-stripped at ingress, storage is append-only, and no read API exists; record instrument and exclusions
(C3). **Post:** the L0-level acceptance item passes or the EPIC does not wrap (v2.5 §2).

## UI surfaces

Native: **Settings › Data** — the one-tap switch and the field table (W1). No other surface.

## Notifications produced

- `telemetry.consent_changed` — new state. Consumers: **expedition**, **diagnosis**, **map**,
  **runtime-tiers** (stop offering outcomes when off), **platform** (buffer cleanup).
- `telemetry.batch_sent` / `telemetry.batch_failed` — event count / failure class. Consumer: **platform**
  (diagnostics).

## Errors produced

- `TELEM_CONSENT_ABSENT` — an event was offered while off. Internal; discarded, not buffered. Expected.
- `TELEM_FIELD_NOT_ALLOWED` — a field outside the allowlist reached the writer. Internal; the event is
  rejected whole. The I5 tripwire: a CI failure, not a runtime tolerance.
- `TELEM_ENDPOINT_UNREACHABLE` — the POST failed. Internal; the batch stays buffered. Recoverable.
- `TELEM_BATCH_REJECTED` — the endpoint refused the payload (schema drift). Internal; dropped after
  bounded retries. Recoverable.
- `TELEM_ENDPOINT_MISCONFIGURED` — W5 finds request logging or a read path. Owner-facing; blocks the
  wrap-gate. Recoverable by reconfiguration.

## Invariants enforced here

- **I5 — primary owner.** Mechanisms: (a) `TelemetryEvent` is a closed union whose fields are ids, small
  enums, booleans and day-level dates, so free text and identifiers are not representable; (b) a boundary
  schema check rejects unknown fields rather than stripping them; (c) a test asserts that with consent off
  no code path makes a network call to the endpoint; (d) a test asserts a serialised batch has no sub-day
  timestamp, no field derived from `CapabilityFacts` (**platform**) or the device, and no field that is
  constant per install beyond app and bundle versions; (e) W5's no-IP check is a wrap-gate item.
- **I11** — the aggregation output states instrument and exclusions per C3, including edges dropped for
  insufficient aggregate.
- **D36** — the endpoint is the app's only POST target; asserted in **platform**'s network test.

Seams: expedition, diagnosis, map, runtime-tiers, platform → telemetry (source notifications);
telemetry → concept-graph (offline `ProbeStats` hand-off).

## Open questions

**Q1 — Where does the write endpoint live?** **Default:** deferred to Phase 5, between a serverless
function and an append-only object store with a signed-PUT front; whichever is chosen must satisfy W5.
**Trade-off:** a function gives boundary validation and clean export at the cost of an operated service
whose logs must be provably off; a store is near free but validation happens only at aggregation.
**Ratified 2026-09-08 (v1 form):** deferred to Phase 5; the no-IP constraint is now hard (v2.5 §2).

**Q2 — Batch cadence and day-N bucketing.** **Default:** at most one batch per day, on launch, when
online; day-N reported in buckets {1, 2–3, 4–7, 8–14, 15–30, 31+} [ESTIMATE: coarse enough that a bucket
plus a day is not a fingerprint]. **Trade-off:** daily batching blurs session boundaries and keeps request
rate low; a one-time user contributes nothing, which is acceptable.
**Ratified 2026-09-09:** default accepted.

**Q3 — Per-batch edge cap.** **Default:** at most one observation per edge per batch (carried from the v1
ratification). **Trade-off:** a heavy user cannot dominate an edge; a student who probes one edge many
times in a day contributes one observation, thinning L3 on the starting chain.
**Ratified 2026-09-08:** carried.

**Q4 — Minimum aggregate before an edge's data may move `Confidence`.** **Default:** 30 observations with
`upstream_state = blocked` per edge [ESTIMATE: mirrors the M4′ synthetic-set size; not from literature].
**Trade-off:** a low threshold updates the starting chain early on noise; a high one leaves L3 idle.
**Ratified 2026-09-08:** default accepted; re-stated over the new edge-observation event.

## Change log

| 2026-09-08 | Drafted (Phase 3b, opt-in PWA form). Open questions ratified. |
| 2026-09-09 | Rewritten for D17 as amended by v2.3/v2.5 and D36/D40: on by default with one-tap off; no identifiers of any kind; device-derived edge observations and day-N return; D40 product events; no-IP endpoint constraint as a wrap-gate item (W5). Q1–Q4 restated; Q2's bucketing is new and pending ratification. |
