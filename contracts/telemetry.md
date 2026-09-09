# Contract: Telemetry (LOCK-FIRST)

**Contract version:** v1.0.0 · Source: D17 (v2.3, v2.5 §1), D36, D40, v2.5 §2; `docs/domains/telemetry.md`

> The only bytes that leave the device besides iCloud sync and content GETs. **Anonymous, aggregate, on by
> default with one-tap off, no identifier of any kind.** The schema `schemas/telemetry-batch.schema.json` is
> normative and closed (`additionalProperties: false` everywhere); this file states what the schema cannot.

## The batch
- One `AggregateBatch` per device per calendar day at most (telemetry Q2), sent on launch when online;
  buffered offline to a bounded cap (oldest dropped). Fields: `format_version`, `app_version`,
  `bundle_versions {graph, spine, objects}`, `day` (`YYYY-MM-DD`), `events[]`.
- **No batch id, no install id, no device id, no session token, no sequence number, no sub-day time.** Two
  batches from one install are indistinguishable from two installs'.
- Cap: at most **one edge observation per edge per batch** (Q3), applied on the device before send.

## Event kinds (closed enum `kind`) and their fields
| kind | fields | source |
|---|---|---|
| `session` | `count` (foreground periods that day) | platform |
| `expedition` | `started`, `completed`, `abandoned`, `unit_scoped` (counts) | expedition W1/W5 |
| `item_result` | `node_id`, `correct`, `retry`, `tier` | expedition W2, diagnosis W3 |
| `edge_observation` | `edge_id`, `upstream_state ∈ {cleared, blocked, fog}`, `downstream_result ∈ {pass, fail}` | derived on device per prerequisite edge of the item's node (v2.5 §1) |
| `marker` | `course_code`, `unit_id`, `moves` | map W5 |
| `landmark_tap` | `landmark_id`, `count` | map W4 |
| `diagnosis` | `origin_node`, `candidate_id?`, `outcome ∈ {refuted, confirmed, unconfirmed, capped}`, `error_type_id?`, `tier` | diagnosis W5 |
| `fallback` | `task ∈ {classify, reword}`, `reason ∈ {below_threshold, unavailable, timeout, guardrail}` | runtime-tiers W4 |
| `capability` | `tier1_available` (bool) | runtime-tiers W1 |
| `return` | `day_bucket ∈ {1, 2-3, 4-7, 8-14, 15-30, 31+}` | derived on device from `install_day` (Q2) |

**Allowlist of value types:** ids from the bundle (node, edge, course, unit, landmark, error type),
booleans, small closed enums, small non-negative integers, calendar day, app and bundle versions. **Never:**
free text, the student's typed line (diagnosis Q1), device model/OS build/locale/storage, Apple
Intelligence eligibility as a device fact, coordinates, timestamps finer than a day.

## Consent
- `consent_on` defaults **true** on first launch; **Settings › Data** shows the table above in plain words and
  a single switch; turning it off discards the unsent buffer before the next write. No modal, no prompt
  mid-run. Sent batches cannot be recalled (they cannot be located); the surface says so.

## Endpoint (D36; v2.5 §2 — hard constraint)
- One HTTPS POST target, append-only, no read API, no auth beyond a static app token that identifies the
  **app build**, not the install. Deployed per `deployment-model.md` (Cloudflare Worker + R2).
- **No IP retention**: Workers invocation logs off (`[observability.logs] invocation_logs = false`); the
  "Remove visitor IP headers" managed transform on; zone HTTP request logs not retained. Verified by the
  owner at the wrap-gate of the EPIC that deploys it (telemetry W5); `TELEM_ENDPOINT_MISCONFIGURED` blocks
  the wrap.

## Aggregation (owner-run, pipeline)
- Per edge: counts by `upstream_state × downstream_result`; `downstream_fail_given_upstream_fail` and its
  complement; edges below 30 `blocked` observations [ESTIMATE: telemetry Q4] are dropped. Output feeds
  `ProbeStats` (concept-graph). Product counts (returns, marker distribution, landmark taps, completion
  rates) are reported as counts only. No model, no per-batch retention beyond aggregation.

## Enforcement (wired)
- `schemas/telemetry-batch.schema.json` — closed; `test_contracts.py` asserts a batch with any key from the
  identifier blocklist (`id`, `install_id`, `device_id`, `session_id`, `user_id`, `ip`, `timestamp`,
  `email`, `name`) is rejected at every nesting level, and that no `string` field is unconstrained (every
  string has a `pattern` or `enum`).
- App EPIC: a network test asserts the only POST host is the endpoint and that with `consent_on = false` no
  request is made (I5 c); the serialised batch is validated against the schema before send.
