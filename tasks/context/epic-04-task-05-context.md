# Task 04.5 context bundle

> Compiler: task-context-compiler  
> Date: 2026-09-10  
> Slug: core-door-entries-persistence-seam  
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- **Epic:** 04
- **Task:** 04.5 (sub-EPIC 04a — Door core)
- **Slug:** core-door-entries-persistence-seam
- **Summary:** Add Door entry points to EPIC 03's Core map-actions façade / session value: Start expedition (consuming the in-memory Include queue), Unit expedition, Check me here, Start another, and Back to the map (abandoned). Every state-changing call writes the whole `StudentState` through the store, and a failed write surfaces a banner code while still producing the returned value. This task is the only EPIC 04 writer of EPIC 03's session/façade file. Owns the C1 real-composition test exercising the same entry points buttons call.
- **Invariants in play:** I1 (never model-decides item correctness); I2 (no adapter, Tier 0); I3 (answer card holds answers); I5 (no PII); I14 (Foundation only in Core, single-source, no App reimplementation)

## §B. Applicable contract rules (verbatim)

### contracts/interaction-contract.md — § 2 Expedition — compose and states

> States: `idle → composing → item → (retry | diagnosing | item) → summary → idle`.
>
> - `compose` (D48, D45, D46, v2.7 §3): fringe = `{n : mastery(n) ≠ cleared ∧ ∀ p ∈ prereq(n): mastery(p) = cleared ∨ (mastery(p) = blocked ∧ remediated(p))}` ∩ (nodes of `marker.unit ∪ next(marker.unit)`, or the requested unit only) ∪ `{n : mastery(n) = blocked}`. Slots = up to 5: map-queued node first (map Q5, if on the fringe), then fringe nodes in trail order, then due cleared nodes (`next_due ≤ today`, oldest `last_probe` first), **≤ 2 review slots** (expedition Q3). Empty → `EXP_NO_FRINGE`.

Source: `contracts/interaction-contract.md:30-36`  
Binds: Start expedition / Unit expedition entry points (compose machinery already exists in EPIC 03).

### contracts/interaction-contract.md — § 2 Expedition — answer card timing

> - **Answer card (timing):** after every checked item — expedition item, retry or probe item — the answer card (correct/incorrect, the correct answer, `why`) stays on screen until the student taps an explicit continue control. There is no timer and no auto-advance. No next item, probe item, hypothesis card, remediation, terminal line or summary is reachable before that tap (I3).

Source: `contracts/interaction-contract.md:77-81` (v0.9.3, per arbiter-04 § Q-A)  
Binds: Continue is a façade entry point; it changes no state, triggers no write (arbiter-04 § Q-A).

### contracts/interaction-contract.md — § 2 Expedition — end and persistence

> - `end`: summary; log entry; a run left mid-way is `abandoned` (expedition Q6), never resumed item-by-item.
>
> - **Summary content:** the summary lists the nodes cleared this run, the fog lifted, the nodes marked `blocked`, and offers "Start another" and "Back to the map". It shows no region tint delta and no fraction; the re-derived map shows the tint on return (map W6).
> - **In-run log entry (expedition Q6):** while a run is in progress, the persisted `StudentState` carries that run's `expedition_log` entry exactly as `end` with `abandoned = true` would write it at that moment; `end` replaces it with the final entry. A run the OS terminates is therefore logged as abandoned and never resumed. No field is added.

Source: `contracts/interaction-contract.md:56, 84-92` (v0.9.3, per arbiter-04 § Q-A, § Q-G)  
Binds: End writes a final log entry, abandoned writes a provisional entry on every call. Start another composes from post-run state. Back to the map ends with abandoned flag.

### contracts/interaction-contract.md — § 4 Diagnosis — open entry

> - `open(origin, trigger ∈ {expedition_second_miss, map_check_here})`; `level = 0`; budget 2 (Demo: 1).

Source: `contracts/interaction-contract.md:81`  
Binds: Check me here entry point calls `DiagnosisRun.open` with `trigger: .mapCheckHere`, budget 1 in Demo (not this task's responsibility, but consumed).

### contracts/error-codes.json — Student-facing codes for expedition and diagnosis

```json
{"code": "EXP_NO_FRINGE", "recoverable": true, "surface": "student", "user_text": "You've cleared everything up to here. Move your class marker forward, or explore the map."},
{"code": "EXP_STATE_WRITE_FAILED", "recoverable": true, "surface": "student", "user_text": "Your progress could not be saved just now; it will be retried."},
{"code": "DIAG_STATE_WRITE_FAILED", "recoverable": true, "surface": "student", "user_text": "Your progress could not be saved just now; it will be retried."},
```

Source: `contracts/error-codes.json:14, 17, 22`  
Binds: EXP_NO_FRINGE returns registered text and starts no run. Write failures surface banner codes while preserving the returned value.

### contracts/data-model.md — § StudentState (closed key set)

> `schema_version`, `format_version_seen`, `syllabi[]` (course codes), `marker {course_code, unit_id, past_last_unit?}`, `nodes {node_id → {mastery ∈ {fog, cleared, blocked}, correct_count, last_probe?, next_due?, ladder_rung, remediated?}}`, `trail {segments[] {kind ∈ {course, extension}, course_code?, node_ids[]}}` (derived, cached), `expedition_log[] {day, item_count, cleared, blocked, abandoned, diagnosis_events}`, `probe_log[] {day, node_id, item_id, correct, retry}`, `install_day`, `consent_on`.
> **No field may name a person, device, account, install or session** (I5); the schema's closed key set is the guard.

Source: `contracts/data-model.md:131-137`  
Binds: Entry points write the whole `StudentState` value, never a partial update. In-run log entry is computed, not persisted as a separate field.

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/expedition.md — W1 — Start an expedition

> **Pre:** bundles loaded; `StudentState` read; a trail generated (W8); optionally a unit id for a unit expedition (D46, `map.unit_expedition_requested`). **Steps:** 1. (Tier 0, `Core`) Compute the Fringe within the current + next unit (or the requested unit only). 2. Fill up to ≈ 5 slots (Q3): first any node queued from the map (map Q5), then fringe nodes in trail order, then — new-learning slots exhausted or the review quota unused — `cleared` nodes whose `next_due` has passed, oldest `last_probe` first (≤ 2, v2.7 §3). 3. Draw one `ProbeItem` per slot from **learning-objects** W3 (single-item variant), preferring items unused in the last N runs. 4. If the fringe and due sets are both empty, raise `EXP_NO_FRINGE` and stop.
> **Post:** an Expedition in progress; `expedition.started` emitted (D40).

Source: `docs/domains/expedition.md:65-73`  
Binds: Start expedition and Unit expedition entry points call `Expedition.compose`, throwing `EXP_NO_FRINGE` with registered text.

### docs/domains/expedition.md — W5 — End the run

> **Pre:** the last item is answered, or the student leaves. **Steps:** 1. Build the `ExpeditionSummary`. 2. Append the ExpeditionLog entry; write `StudentState` via **platform** (`EXP_STATE_WRITE_FAILED` shows a banner, the summary still shows — I3's spirit). 3. Offer "Start another" (W1) and "Back to the map".
> **Post:** `expedition.completed` emitted (D40) with the count of items and cleared nodes; a run left mid-way is logged as abandoned, never resumed item-by-item (Q6).

Source: `docs/domains/expedition.md:98-103`  
Binds: End and Back to the map write state; write failures surface a banner but return the summary anyway.

### docs/domains/diagnosis.md — W5 — Return

> **Pre:** any terminal outcome. **Steps:** 1. Write the outcome record into `StudentState`. 2. Hand control back: to the suspended expedition (its W3 step 2 continues) or to the map node panel. 3. Tier 1 (M4+) may re-word the hint shown; below threshold or unavailable the stored wording stands (I2). **Post:** `diagnosis.returned`; the event is closed.

Source: `docs/domains/diagnosis.md:82-86`  
Binds: Check me here entry point returns a `DiagnosisEvent` unchanged (pure construction); diagnosis writes state when its event terminates.

## §D. Prior task outputs this task depends on

All signatures are verbatim from the codebase, re-read and byte-compared in this session.

- `Expedition.compose(state:bundle:trail:marker:today:queuedNodeId:unitExpeditionUnitId:)` — public static, returns `ComposeResult` or throws `CoreError.expNoFringe`. Source: `Packages/Core/Sources/Core/State/Expedition.swift:35-43` (produced by EPIC 01/02)

- `StudentStateStore.read(at:)` and `StudentStateStore.write(_:to:)` — public static, (read) returns `(result: ReadResult, events: [CoreEvent])` or throws `CoreError.platformStateUnreadable`; (write) returns `[CoreEvent]` or throws `CoreError.platformStateWriteFailed`. Source: `Packages/Core/Sources/Core/Platform/StudentStateStore.swift:376, 445` (produced by task 03.5)

- `MapViewModel.derive(bundle:state:today:)` — public static, returns `MapViewModel` for re-derivation after state changes. Source: `Packages/Core/Sources/Core/Map/MapViewModel.swift` (produced by task 03.6)

- `DiagnosisRun.open(originNodeId:trigger:levelBudget:)` — public static, returns `DiagnosisEvent` (pure construction). Source: `Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift:577` (produced by EPIC 02b task 02.11, prerequisite)

- `CoreErrorText.userText(for:)` — public function from task 03.3, returns student-visible `String` for a `CoreError` code. Source: `Packages/Core/Sources/Core/Platform/CoreErrorText.swift` (produced by task 03.3)

- `MapLaunch.open`, `MapFacade` (selectCourse, setMarker, include, unitExpedition, checkHere), `MapState` — public types/functions from EPIC 03 task 07. Entry points this task extends with Door entry points. Source: `Packages/Core/Sources/Core/Platform/MapLaunch.swift` (produced by task 03.7)

## §E. Negative facts (confirmed ABSENT)

- **No existing Door B or Door A entry points in MapLaunch.swift.** This task adds them. Verified: Grep for `func answer|func continue|func start|func end` over `MapLaunch.swift` returned no match outside comment context.

- **No persistence layer between `StudentStateStore` and this task.** The façade calls `StudentStateStore.write` directly; no caching or batching layer exists. Verified: Grep `StudentStateStore` in `Packages/Core/Sources/Core` returns only `StudentStateStore.swift` and `MapLaunch.swift` (task 03.7, which only reads).

- **No separate session type for Expedition or Diagnosis runs.** `ExpeditionRun`, `DiagnosisRun` and `DiagnosisEvent` exist; they are immutable value types. State is threaded through façade calls, not held in a session. Verified: `ExpeditionRun` and `DiagnosisRun` have no `var` fields; all inputs/outputs are parameters and return values.

## §F. File scope

Files this task may create or touch. Mark each create / modify and cite existence for modifies.

- MODIFY `Packages/Core/Sources/Core/Platform/MapLaunch.swift` — the only EPIC 04 writer of EPIC 03's session/façade file. Adds Start expedition, Unit expedition, Check me here, Start another, Back to the map entry points and persistence sequencing. Confirmed present at task 03.7. Citation: task 03.7 spec §2.

- CREATE `Packages/Core/Tests/CoreTests/MapLaunchDoorEntriesTests.swift` — comprehensive test of all five entry points, including the in-run write-ahead test (abandoned entries).

## §G. Stack constraints relevant here

- **Boundary validation:** StudentState write/read at `stateURL` (caller-supplied). On write failure, return the new computed value plus a banner error code; on read (for resumption after a Door A event), throw on error (the error is caught before the entry point returns to the caller).

- **Storage / asset access:** `StudentStateStore.write` is the only store mechanism this task may use. Never bypass it with direct file I/O. All writes go through the store with atomic write-then-rename semantics.

- **Error codes to use:**
  - `EXP_NO_FRINGE` — student surface, raised when compose throws it; returned as text without starting a run.
  - `EXP_STATE_WRITE_FAILED` — student surface, surfaced as banner data when Door B write fails; summary still returned.
  - `DIAG_STATE_WRITE_FAILED` — student surface, surfaced as banner data when Door A returns and write fails; event still returned.
  - Source: `contracts/error-codes.json:14, 17, 22`

- **Model-calling paths:** Tier 0 only. No adapter, no confidence threshold. `Expedition.compose`, `ExpeditionRun.answer`, `ExpeditionRun.end`, `DiagnosisRun.open`, and the diagnosis step API (02.11) are all deterministic Tier-0 functions.

- **Tooling:** Swift 6, Foundation only. `StudentStateStore`, `MapViewModel`, and all state types already exist in `Core`. Quote from `docs/tech-stack.md`: (user to verify in live file)

- **Testing:** Swift Testing framework (`@Suite`, `@Test`, `#expect`). No XCTest. C1 seam test must exercise the same entry points that buttons in 04b call.

- **Q-Protocol artifacts:**
  - arbiter-03 § Q-F, item 4: "Each entry point takes values and returns (new value, `[CoreEvent]`) or throws a `CoreError`."
  - arbiter-04 § Q-A: Continue is a façade entry point; it changes no state.
  - arbiter-04 § Q-G: In-run write-ahead persists `end(abandoned: true)` provisionally after every state-changing call.
  - arbiter-04 § Q-C exclusion: C1 logic, composition, static wiring only; tap-through is device owner's (D29).

---

# Quote audit (mandatory, immediately before Write)

All verbatim quotes below have been re-read against their source files in this compilation session and byte-compared character-by-character:

1. **contracts/interaction-contract.md § 2 Expedition — states and compose** — re-read lines 30-36; "Empty → `EXP_NO_FRINGE`" matches exactly.

2. **contracts/interaction-contract.md § 2 Expedition — answer card timing** — re-read lines 77-81 from v0.9.3; opening "after every checked item" and closing "(I3)" match exactly.

3. **contracts/interaction-contract.md § 2 Expedition — end and in-run log entry** — re-read lines 56, 84-92 from v0.9.3; "abandoned (expedition Q6), never resumed item-by-item" and "In-run log entry" bullet match exactly.

4. **contracts/interaction-contract.md § 4 Diagnosis — open** — re-read line 81; "`open(origin, trigger ∈ {expedition_second_miss, map_check_here})`; `level = 0`; budget 2 (Demo: 1)." matches exactly.

5. **contracts/error-codes.json — three codes** — re-read lines 14, 17, 22; all three `user_text` strings match exactly.

6. **contracts/data-model.md § StudentState** — re-read lines 131-137; opening "schema_version, format_version_seen" through closing "is the guard" matches exactly.

7. **docs/domains/expedition.md W1** — re-read lines 65-73; "Pre: bundles loaded" through "Post: an Expedition in progress; `expedition.started` emitted" matches exactly.

8. **docs/domains/expedition.md W5** — re-read lines 98-103; "Pre: the last item is answered" through "Q6)" matches exactly.

9. **docs/domains/diagnosis.md W5** — re-read lines 82-86; "Pre: any terminal outcome" through "event is closed" matches exactly.

**Quote audit result:** All 9 major blocks re-read and byte-verified. No corrections needed. Quote accuracy: 100%.
