# Domain — telemetry

## Purpose

Collect the minimum evidence needed to validate the concept graph empirically (brief §6, L3: the graph
predicts that students failing A fail B at a higher rate), under D17: **anonymous, aggregate, opt-in,
account-less; no personally identifiable data**. D17 is the whole specification of this domain; everything
below is mechanism. Milestone: **M3** (decomposition row 9; brief §8 — L3 telemetry ships with the Tier 0
prototype). Output feeds `downstream_fail_given_upstream_fail` in `ProbeStats` (**concept-graph**).

It also owns the product's only server-side component: the PWA is static-hosted with no server-side
application logic (brief §4.3), so **the telemetry write endpoint is the sole write path**. It is not part
of the PWA's static build, and is deployed and operated separately.

## Actors and roles

| Actor | What they can do here | What they cannot |
|---|---|---|
| Student | Opt in explicitly, turn it off at any time, read which fields are sent | Be identified; send anything while consent is off |
| Parent | The same controls on the same profile | Enable telemetry on another device (D19) |
| Owner | Run the offline aggregation, apply the `Confidence` update | Recover a person, device or session thread; add a field that identifies anyone (I5) |
| System | Buffer events, assemble an `AggregateBatch`, POST it, drop it on failure | Emit anything while `ConsentState` is off; attach an id, sub-day timestamp or free text |

The **Local model** (Tier 1) and **Generation model** have no role here; a `FallbackDecision` is only an
event subject.

## Core entities

**ConsentState** — a local record: **off by default**, set on only by an explicit affirmative action,
revocable from the same surface, revocation taking effect before the next event is written. It stores the
state and the app version at the time of choice — no identifier, no sub-day timestamp. Consent is per
browser profile, the only scope that exists without accounts (D19).

**TelemetryEvent** — one observation, in four kinds, each sourced from exactly one upstream event:
*probe outcome* (from `session.probe_completed`, **tutoring-session**) and *diagnosis outcome* (from
`session.error_classified`, **tutoring-session**), carrying the upstream/downstream node pair L3 needs;
*fallback decision* (from `tier.fallback_decided`, **runtime-tiers**) and *tier capability* (from
`tier.capability_detected`, **runtime-tiers**), saying whether a Tier 1 path was active when a diagnosis
was recorded (otherwise the statistics confound). The field allowlist is
hard: node ids (**concept-graph**), `ErrorType` ids (**learning-objects**), pass/fail booleans, tier (0 or
1), app version and bundle versions (`AssetVersion`, **platform**). Nothing else may appear: never free
text, never the student's LaTeX or any part of a `Problem` (**verification**), never a timestamp finer than
the day, never a device fingerprint (user agent, screen size, `deviceMemory`, locale, storage figure).
Those exclusions make the payload non-identifying, and are enforced by the type, not by convention.

**AggregateBatch** — the unit that leaves the device: `TelemetryEvent`s with per-day counts, carrying app
and bundle versions and nothing that orders or links the events within it. POSTed once to the single write
endpoint; no read path and no id, so two batches from one install are indistinguishable from two
installs' batches — the point of the design. Capped at one observation per edge per batch: a batch may
contribute at most one probe/diagnosis observation toward any given edge's `ProbeStats`, so a heavy single
user cannot dominate an edge's statistics (Q3).

## Workflows

### W1 — Set or change consent
**Pre:** any `ConsentState` (off on a fresh profile). **Steps:** 1. On a settings surface — never
mid-session, never as a blocking modal — show what would be sent. 2. The student or parent chooses.
3. Write the new state; if off, discard the unsent buffer. Tier 0. **Post:** state persisted;
`telemetry.consent_changed` emitted; while off, nothing further happens. Batches already sent cannot be
recalled — anonymous and aggregate, they cannot be located; the consent surface says so.

### W2 — Capture an event
**Pre:** consent on; **tutoring-session** has completed a probe (`session.probe_completed`) or a diagnosis
(`session.error_classified`) (seam **tutoring-session↔telemetry**), or **runtime-tiers** has decided a
fallback (`tier.fallback_decided`) or detected tier capability (`tier.capability_detected`) (seam
runtime-tiers↔telemetry). **Steps:** 1. The source domain offers the outcome. 2. Validate against
the allowlist schema; a field outside it fails the write rather than being stripped. 3. Append to the
buffer in the platform `Store`. Tier 0 — no model call, even when the subject is a Tier 1 outcome.
**Post:** one buffered event, nothing sent.

### W3 — Send a batch
**Pre:** consent on; buffer non-empty; device online. **Steps:** 1. Assemble an `AggregateBatch` (cadence
per Q2). 2. POST to the write endpoint. 3. On success clear the sent events; on failure keep them to a
bounded cap, then drop oldest. Tier 0. **Post:** `telemetry.batch_sent` or `telemetry.batch_failed`
emitted; both branches terminate, so telemetry never blocks a session.

### W4 — Owner-run aggregation and confidence update (offline)
**Pre:** batches have accumulated at the endpoint. **Steps:** 1. Export received batches. 2. Aggregate
into per-edge counts: upstream probes, failures, and the rate `downstream_fail_given_upstream_fail`,
counting at most one observation per edge from any single `AggregateBatch` (Q3 mitigation), so one heavy
batch cannot dominate an edge's statistics. 3. Drop edges below the minimum aggregate (Q4). 4. Hand the
result to `ProbeStats` (**concept-graph**),
which recomputes `Confidence` by its own rules. No model at any step. **Post:** **concept-graph** produces
an updated bundle; this domain writes nothing to the graph.

## UI surfaces

- `/settings/data` — the consent surface (W1), reachable from `/student/...` and `/parent`. No other
  surface. Path confirmed in Phase 4.

## Notifications produced

- `telemetry.consent_changed` — new state. Consumers: **tutoring-session** (stops offering outcomes when
  off), **platform** (store cleanup).
- `telemetry.batch_sent` / `telemetry.batch_failed` — event count / failure class. Consumer: **platform**
  (diagnostics).

## Errors produced

- `TELEM_CONSENT_ABSENT` — an event was offered while consent is off. Internal; discarded, not buffered.
  Recoverable; expected.
- `TELEM_FIELD_NOT_ALLOWED` — a field outside the allowlist reached the writer. Internal; the event is
  rejected whole. The I5 tripwire: a CI failure, not a runtime tolerance.
- `TELEM_ENDPOINT_UNREACHABLE` — the POST failed. Internal; the batch stays buffered. Recoverable.
- `TELEM_BATCH_REJECTED` — the endpoint refused the payload (schema drift). Internal; dropped after
  bounded retries. Recoverable.

## Invariants enforced here

- **I5** — primary owner. Mechanisms: (a) `TelemetryEvent` is a closed union whose fields are all id-typed
  or boolean, so free text is not representable; (b) a boundary schema check rejects unknown fields rather
  than stripping them; (c) a test asserts that with consent off no session path makes a network call;
  (d) a test asserts a serialised batch has no sub-day timestamp and no field derived from `navigator` or
  `EnvironmentCheck` (**platform**).
- **I11** — the aggregation output states instrument and exclusions per C3, including edges dropped for
  insufficient aggregate.

## Open questions

**Q1 — Where does the write endpoint live?** Default: deferred to Phase 5, between a serverless function
and a hosted static-form endpoint.
Trade-off: a serverless function gives boundary validation and clean export, but is an operated service
whose request logs typically capture IP addresses — defeating D17 unless disabled; a form endpoint is near
free but cedes control over what a third party retains.
**Ratified 2026-09-08:** default accepted.

**Q2 — Batch cadence.** Default: at most once per day, on app start, when online.
Trade-off: daily batching blurs session boundaries and keeps the request rate low, but a student who uses
the app once contributes nothing; more frequent sends recover that data while making sessions more
distinguishable in the stream.
**Ratified 2026-09-08:** default accepted.

**Q3 — Is a random per-install id acceptable?** Default: **no id at all** — aggregate only.
Trade-off: an install id would allow de-duplication and per-student sequences, genuinely stronger L3
evidence; but D17 says account-less, and any stable id is a fingerprint.
**Ratified 2026-09-08:** no id at all. Mitigation added: each AggregateBatch contributes at most one
observation per edge to ProbeStats, so a heavy single user cannot dominate an edge's statistics.

**Q4 — Minimum aggregate before an edge's data may move `Confidence`.** Default: 30 upstream probes per
edge [ESTIMATE: mirrors the M4′ synthetic-set size, brief §8; not from literature].
Trade-off: a low threshold updates confidence early on the starting chain (D14) where data is thinnest, but
risks moving a disputed edge (D13) on noise; a high one leaves L3 contributing nothing for a long stretch.
**Ratified 2026-09-08:** default accepted.

## Change log

| 2026-09-08 | Drafted (Phase 3b). |
| 2026-09-08 | Phase 3b consistency fixes (event consumers aligned with telemetry's four event kinds). |
| 2026-09-08 | Open questions ratified by owner (all defaults; see docs/plans/phase3b-open-questions.md). Q3 ratified as no-id-at-all plus a per-batch cap: AggregateBatch contributes at most one observation per edge to ProbeStats. |
