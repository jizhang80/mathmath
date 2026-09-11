# Epic 03 · Task 02: Contract — `error-codes.json` `PLATFORM_SNAPSHOT_REFUSED` (additive)

---
epic: 03
task: 02
slug: contract-error-codes-snapshot-refused
kind: feat
risk: seam
depends_on: []
model: sonnet
---

## §1 Goal & acceptance criteria

Goal: register one new error code, `PLATFORM_SNAPSHOT_REFUSED`, in `contracts/error-codes.json` (additive, no
version bump), and land its `docs/domains/platform.md` row plus the one-sentence W1 amendment the arbiter
ruled — closing the gap where the embedded offline snapshot itself fails a load-time check and no other
content set is installed. This task lands contracts and docs only. It does not raise the code anywhere: the
`CoreError` case is added by task 03.3, and the launch path that throws it is task 03.4/03.7's.

Invariants in play:

- **I2** — "Tier 0 alone must be a usable product: every model call has a confidence threshold and a
  deterministic fallback; the system never guesses a diagnosis." No model call is involved anywhere in this
  task; the registered failure path (manifest completeness, format major, L0 — all deterministic Tier 0
  checks) fails closed with an honest message rather than guessing, which is the invariant's Tier-0-only
  case.
- **I5** — no field or text this task adds names a person, device, account, install or session.
  `contracts/error-codes.md` § Rules: "Student text names a node or a situation, never the student, and
  never contains a score (content-policy voice)." The registered `user_text`, "The map could not be loaded
  from this copy of the app; reinstall the app to fix it.", names a situation (this build copy) and gives a
  next action, and identifies nothing about the student.
- **I9** — "Zero human content review — content is generated + machine-verified... Never add an "owner
  reviews content" step." This registration is carried out mechanically from the arbiter's Q4 ruling
  (`tasks/arbitration/arbiter-03-predispatch.md` § Q-C); it adds no review gate.

Acceptance criteria (each independently verifiable):

- AC1: `contracts/error-codes.json` contains exactly one new array entry,
  `{"code": "PLATFORM_SNAPSHOT_REFUSED", "recoverable": false, "surface": "student", "user_text": "The map
  could not be loaded from this copy of the app; reinstall the app to fix it."}`, placed immediately after
  the `PLATFORM_BUNDLE_INTEGRITY_FAILED` entry and before `PLATFORM_STATE_WRITE_FAILED`, matching the file's
  existing key order (`code`, `recoverable`, `surface`, `user_text`) and one-line-per-entry formatting; no
  other entry, the `prefixes` object, or `contract_version` changes.
  Instrument: `cd pipeline && uv run pytest tests/test_contracts.py::test_error_registry_matches_domain_docs -q`
  green; `git diff contracts/error-codes.json` shows exactly one added line.
- AC2: `docs/domains/platform.md` § W1 step 1 ends with the appended sentence "If the snapshot itself fails,
  `PLATFORM_SNAPSHOT_REFUSED` and no map is rendered." after the existing
  "`PLATFORM_BUNDLE_INTEGRITY_FAILED`)." clause; step 1's prior text and steps 2–4 are byte-unchanged.
  Instrument: `rg -n "PLATFORM_SNAPSHOT_REFUSED" docs/domains/platform.md` shows a hit inside § W1.
- AC3: `docs/domains/platform.md` § Errors produced gains exactly one table row for
  `PLATFORM_SNAPSHOT_REFUSED`, placed immediately after the `PLATFORM_BUNDLE_INTEGRITY_FAILED` row and before
  the `PLATFORM_STATE_WRITE_FAILED` row, with the four columns (When / User sees / Recoverable) exactly as
  ruled; the other four rows are byte-unchanged.
  Instrument: `rg -n "PLATFORM_SNAPSHOT_REFUSED" docs/domains/platform.md` shows a second hit inside the table.
- AC4: `pipeline/tests/test_contracts.py::test_error_registry_matches_domain_docs` passes unmodified,
  proving registry ⇔ domain-doc round-trip equality now includes `PLATFORM_SNAPSHOT_REFUSED` on both sides,
  and proving the new entry's field set, `surface` enum membership, prefix membership and the
  `surface == "student" ⇔ user_text is not null` constraint.
  Instrument: `cd pipeline && uv run pytest tests/test_contracts.py -q` green, no diff to the test file.
- AC5: `Packages/Core/Tests/CoreTests/ErrorRegistryTests.swift` passes unmodified. The test asserts
  `CoreError.allCases ⊆ registryCodes`; a registry entry with no matching `CoreError` case does not fail it
  (only the reverse direction — a `CoreError` case absent from the registry — would).
  Instrument: `xcodebuild test -scheme Core-Package -destination 'platform=iOS Simulator,name=iPhone 16'`
  (or the simulator target `scripts/gate.sh` uses) green, no diff to the test file.
- AC6: `contracts/error-codes.md`'s `Contract version` line stays `v1.0.0`, unchanged, per the file's own
  rule that additive registration needs no version bump.
  Instrument: `rg -n "Contract version" contracts/error-codes.md` shows `v1.0.0`; `git diff contracts/error-codes.md` is empty.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `contracts/error-codes.json` — MODIFY. Add one entry to `codes[]` (AC1).
- `docs/domains/platform.md` — MODIFY. § W1 step 1 sentence (AC2); § Errors produced new row (AC3).

Out-of-scope (do not touch even if tempted):

- `Packages/Core/Sources/Core/CoreError.swift` — task 03.3's file. No `CoreError` case is added by this
  task; the plan's task-scope note ("This is the only task in the EPIC that writes `CoreError.swift`") names
  03.3, not this task.
- `contracts/error-codes.md` — the rules file itself is untouched; only the registry (`error-codes.json`)
  and one domain doc change, per its own "Additive registration... is allowed without a version bump" rule.
- `docs/domains/map.md`, `contracts/interaction-contract.md`, `docs/DEFERRED.md` — task 03.1's files (the
  Q-B marker-unit-list contract task); unrelated to Q-C.
- `pipeline/tests/test_contracts.py` — no new test is needed; the existing
  `test_error_registry_matches_domain_docs` already exercises the round-trip for any code appearing in both
  the registry and a domain doc, with no parametrization to add.
- `Packages/Core/Tests/CoreTests/ErrorRegistryTests.swift` — no edit; it stays green unmodified (AC5), and
  editing it would be scope creep into task 03.3.
- `data/demo/**`, `App/**` — no bundle asset or application code is touched; this task is contracts + docs
  only.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/error-codes.md` — the header block immediately below the `# Contract: Error codes registry`
  title, before the `## Rules` heading:
  > The single registry of every error code. **`error-codes.json` is normative**; this file states the rules.
  > Codes are stable strings `<DOMAINPREFIX>_<REASON>`; a change is a versioned change. Additive registration
  > (a new code with its domain doc row) is allowed without a version bump.

- `contracts/error-codes.md` — heading `## Rules`:
  > - Prefixes are fixed per domain: `MAP`, `EXP`, `DIAG`, `GRAPH`, `LO`, `SPINE`, `GEN`, `PLATFORM`, `TELEM`,
  >   `TIER`, `VERIFY` (M5). A code appears in exactly one domain doc and in the registry.
  > - Every code declares `recoverable` (bool), `surface ∈ {internal, student, owner}` and `user_text` — the
  >   student-facing sentence when `surface = student`, else `null`. Student text names a node or a situation,
  >   never the student, and never contains a score (content-policy voice).
  > - `Core` defines `enum CoreError: String` mirroring the `GRAPH`, `EXP`, `MAP` (validation) and `DIAG`
  >   codes; the App and the pipeline each map their own. A code raised in code but absent from the registry
  >   fails the round-trip test.
  > - Internal codes never reach a student surface; a `student` code always has a next action in its text.
  > - `GRAPH_L0_FAILED` carries the failing rule ids from `graph-constraints.md` in `details`.

- `contracts/error-codes.md` — heading `## Enforcement (wired)`:
  > - `pipeline/tests/test_contracts.py`: the set of codes in `error-codes.json` equals the set of
  >   backticked `UPPER_SNAKE` codes across `docs/domains/*.md`; every entry has the required fields; prefixes
  >   match the domain. EPIC-time: `CoreError` cases ⊆ registry (Swift test).

Normative ruling text (`tasks/arbitration/arbiter-03-predispatch.md` § Q-C — "The embedded snapshot itself is
refused"), copied byte-for-byte:

- Exact registry entry (placement: "`contracts/error-codes.json`, `codes[]`, placed after
  `PLATFORM_BUNDLE_INTEGRITY_FAILED`"):
  ```json
  {"code": "PLATFORM_SNAPSHOT_REFUSED", "recoverable": false, "surface": "student", "user_text": "The map could not be loaded from this copy of the app; reinstall the app to fix it."},
  ```

- Exact domain row (placement: "`docs/domains/platform.md` § Errors produced, after
  `PLATFORM_BUNDLE_INTEGRITY_FAILED`"):
  ```
  | `PLATFORM_SNAPSHOT_REFUSED` | The offline snapshot shipped in the build fails a load-time check (manifest completeness, format major, L0) and no other set is installed | "The map could not be loaded from this copy of the app; reinstall the app to fix it." No map is rendered | No — needs a new build |
  ```

- W1 amendment sentence:
  > Also amend platform § W1 step 1 by appending: "If the snapshot itself fails, `PLATFORM_SNAPSHOT_REFUSED` and no
  > map is rendered."

- Ordering constraint (why this lands as one task, before 03.3):
  > The registry entry, the platform row and the `CoreError` case are coupled.
  > `test_error_registry_matches_domain_docs` fails if the registry and the domain docs disagree, and
  > `ErrorRegistryTests` fails if the Swift case precedes the registry entry. So the registry entry and the platform
  > row land in **task 1**, the same contract task as Q-B (a separate `contract(error-codes)` commit), before task 2
  > adds the `CoreError` case.

Prior shapes this task extends (verified by direct read):

- `contracts/error-codes.json` — the existing `PLATFORM` group, entries as currently in file:
  ```json
      {"code": "PLATFORM_BUNDLE_FETCH_FAILED", "recoverable": true, "surface": "student", "user_text": "Could not refresh content; still using the installed version."},
      {"code": "PLATFORM_BUNDLE_INTEGRITY_FAILED", "recoverable": true, "surface": "student", "user_text": "Could not refresh content; still using the installed version."},
      {"code": "PLATFORM_STATE_WRITE_FAILED", "recoverable": true, "surface": "internal", "user_text": null},
      {"code": "PLATFORM_STATE_UNREADABLE", "recoverable": true, "surface": "student", "user_text": "Earlier progress could not be read; it has been kept."},
      {"code": "PLATFORM_SYNC_UNAVAILABLE", "recoverable": true, "surface": "internal", "user_text": null},
  ```
  (verified by direct read of `contracts/error-codes.json`; the group is contiguous — no blank lines between
  entries — and every entry is one line, four keys, in this order.)

- `docs/domains/platform.md` § W1 — Launch, current text in full:
  > **Pre:** app start. **Steps:** 1. Load the active `ContentBundle` (installed hosted set, else the offline
  > snapshot); verify hashes; a failure falls back to the snapshot (`PLATFORM_BUNDLE_INTEGRITY_FAILED`).
  > 2. Read `StudentState` (W3); none → a fresh default. 3. Collect `CapabilityFacts`. 4. Hand control to
  > **map** W1. Tier 0. **Post:** `platform.launched` emitted.

- `docs/domains/platform.md` § Errors produced, current table in full:
  > | Code | When | User sees | Recoverable |
  > |---|---|---|---|
  > | `PLATFORM_BUNDLE_FETCH_FAILED` | A hosted bundle could not be fetched | "Could not refresh content; still using the installed version" | Yes |
  > | `PLATFORM_BUNDLE_INTEGRITY_FAILED` | Hash mismatch or a bundle failing load-time validation (`MAP_LAYOUT_MISSING`, I8) | Same message; the snapshot or installed set stays | Yes, never tolerated |
  > | `PLATFORM_STATE_WRITE_FAILED` | The JSON write failed | Banner from the calling domain | Yes — retried |
  > | `PLATFORM_STATE_UNREADABLE` | Migration failed | "Earlier progress could not be read; it has been kept" | Yes — file retained |
  > | `PLATFORM_SYNC_UNAVAILABLE` | Not signed in, or iCloud errored | Nothing (silent); status in Settings | Yes |

- `pipeline/tests/test_contracts.py` — `test_error_registry_matches_domain_docs` (existing, unmodified by
  this task):
  ```python
  def test_error_registry_matches_domain_docs() -> None:
      registry = json.loads((CONTRACTS / "error-codes.json").read_text())
      codes = {entry["code"] for entry in registry["codes"]}
      prefixes = set(registry["prefixes"])
      for entry in registry["codes"]:
          assert set(entry) == {"code", "recoverable", "surface", "user_text"}, entry
          assert entry["surface"] in {"internal", "student", "owner"}
          assert entry["code"].split("_", 1)[0] in prefixes, entry["code"]
          assert (entry["surface"] == "student") == (entry["user_text"] is not None), entry
      docs = sorted(DOMAINS.glob("*.md"))
      assert docs, "no domain docs found — scan would be vacuous"
      in_docs: set[str] = set()
      for doc in docs:
          in_docs |= set(re.findall(r"`([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)`", doc.read_text()))
      in_docs = {c for c in in_docs if c.split("_", 1)[0] in prefixes}
      missing, stray = sorted(in_docs - codes), sorted(codes - in_docs)
      assert in_docs == codes, f"in docs not registry: {missing}; in registry not docs: {stray}"
  ```

- `Packages/Core/Tests/CoreTests/ErrorRegistryTests.swift` — existing test in full (unmodified by this
  task; confirms the assertion direction named in AC5):
  ```swift
  @Test("CoreError.allCases is a subset of the error-codes.json registry")
  func coreErrorIsSubsetOfRegistry() throws {
      ...
      for errorCase in CoreError.allCases {
          #expect(
              registryCodes.contains(errorCase.rawValue),
              "\(errorCase.rawValue) raised in Core but absent from the registry")
      }
  }
  ```
  (elided body verified by direct read; the loop iterates `CoreError.allCases`, never `registryCodes`, so an
  entry in the registry with no `CoreError` case cannot fail this test — only a `CoreError` case missing from
  the registry can.)

## §4 Implementation outline

1. **Layer.** This task adds no application-layer (①–④) code. It is a contracts-layer registration
   (`contracts/error-codes.json`) plus its platform domain-doc mirror (`docs/domains/platform.md`), which the
   error-codes contract requires to move together ("A code appears in exactly one domain doc and in the
   registry").

2. **`contracts/error-codes.json`.** Insert one line into the `PLATFORM` group of `codes[]`, immediately
   after the `PLATFORM_BUNDLE_INTEGRITY_FAILED` line and before the `PLATFORM_STATE_WRITE_FAILED` line, with
   the exact text quoted in §3 ("Exact registry entry"), preserving the file's existing four-key order
   (`code`, `recoverable`, `surface`, `user_text`), its one-entry-per-line formatting, and its trailing comma
   convention (every non-final entry ends `},`). Do not add a blank line — the `PLATFORM` group has none
   between its entries. Do not touch `contract_version`, `prefixes`, or any other group.

3. **`docs/domains/platform.md` § W1 — Launch.** Append, to the end of step 1's existing sentence (after
   "`PLATFORM_BUNDLE_INTEGRITY_FAILED`).", within the same step, before "2. Read `StudentState`..."), the
   sentence quoted in §3 ("W1 amendment sentence"): `If the snapshot itself fails,
   \`PLATFORM_SNAPSHOT_REFUSED\` and no map is rendered.` Steps 2–4 and the Pre/Post/Tier annotations are
   byte-unchanged.

4. **`docs/domains/platform.md` § Errors produced.** Insert the exact row quoted in §3 ("Exact domain row")
   at the position the ruling names — immediately after the `PLATFORM_BUNDLE_INTEGRITY_FAILED` row, i.e.
   immediately before the `PLATFORM_STATE_WRITE_FAILED` row — matching the registry's own insertion point
   from step 2 above, so the two files stay in the same relative order. The header row and separator row are
   unchanged; the other four data rows are byte-unchanged.

5. **Error codes and model-calling paths.** This task defines, but does not raise, `PLATFORM_SNAPSHOT_REFUSED`
   — no runtime code path in this task's file scope throws it (there is no runtime code in this task's file
   scope at all). The code will be thrown by `Core`'s launch entry point once task 03.3 adds the `CoreError`
   case and task 03.4/03.7 wires the launch path that detects a refused snapshot. No model-calling path
   exists in this task; I2's confidence-threshold/Tier-0-fallback requirement is satisfied by the fact that
   this failure path is entirely deterministic (manifest completeness, format major, L0 checks) — no model is
   ever consulted to decide whether the snapshot is usable, and none is added here.

6. **Storage/asset shape.** `contracts/error-codes.json` is not one of the seven `ContentBundle` files
   `manifest.json` lists, nor is it `StudentState`; it is the cross-domain error registry itself, read at
   test time by `pipeline/tests/test_contracts.py` and (at EPIC 03a build time) by
   `ErrorRegistryTests.swift` — neither of which this task edits. No storage/asset boundary schema applies
   beyond the round-trip test's own structural assertions (§3, `test_error_registry_matches_domain_docs`),
   which are unmodified and already cover the new entry once it exists.

7. **Smoke check.**
   ```
   cd pipeline && uv run pytest tests/test_contracts.py -q
   ```
   must be green, in particular `test_error_registry_matches_domain_docs`; then
   ```
   xcodebuild test -scheme Core-Package -destination 'platform=iOS Simulator,name=iPhone 16'
   ```
   (or the simulator target `scripts/gate.sh` uses) must stay green, in particular
   `ErrorRegistryTests.coreErrorIsSubsetOfRegistry`, unmodified and unaffected by the new registry entry.

8. **Commit.** One commit — the registry entry and its domain-doc row and W1 sentence cannot land separately
   without leaving `test_error_registry_matches_domain_docs` red in between (a code in the registry with no
   domain-doc mention, or vice versa, fails the round-trip test):
   ```
   contract(error-codes): register PLATFORM_SNAPSHOT_REFUSED (additive)
   ```
   Scope: `contracts/error-codes.json`, `docs/domains/platform.md`.

## §5 Test plan (seam risk — full plan)

- **T1 happy path.** `pipeline/tests/test_contracts.py::test_error_registry_matches_domain_docs`, run
  unmodified after this task's edits, proves the new code is present, correctly shaped, and mentioned in
  exactly one domain doc — the registry-set-equals-docs-set assertion (§3) now includes
  `PLATFORM_SNAPSHOT_REFUSED` on both sides for the first time. `ErrorRegistryTests.coreErrorIsSubsetOfRegistry`,
  run unmodified, proves the new entry does not break the existing `CoreError ⊆ registry` direction (AC5).
- **T2 negative — invalid input rejected at the boundary.** Not applicable as a new instrument: this task
  adds no boundary-validated input path (no schema, no decode path). The existing structural assertions
  inside `test_error_registry_matches_domain_docs` (`set(entry) == {"code", "recoverable", "surface",
  "user_text"}`, `entry["surface"] in {"internal", "student", "owner"}`,
  `entry["code"].split("_", 1)[0] in prefixes`, `(entry["surface"] == "student") == (entry["user_text"] is
  not None)`) are the negative guard: an entry missing a key, a bad `surface` value, an unregistered prefix,
  or a `student` surface with `user_text: null` would fail one of these four assertions on the new entry, as
  it does for every existing entry. Recorded as a decision, not a gap — the guard is real and pre-existing,
  and this task's job is to conform to it, not add a new one.
- **T3 error-taxonomy.** The taxonomy assertion is the round-trip test itself
  (`test_error_registry_matches_domain_docs`): `PLATFORM_SNAPSHOT_REFUSED` must appear in both
  `error-codes.json` and `docs/domains/platform.md`, or the test reds with the code named in `missing` or
  `stray`. This is the correct instrument per §3's "Enforcement (wired)" quote naming exactly this test.
- **T4 conformance per `contracts/error-codes.md` § Rules and § Enforcement (wired), and I2/I5/I9:** the
  four structural assertions above conform the new entry to § Rules ("Every code declares `recoverable`
  (bool), `surface ∈ {internal, student, owner}` and `user_text`..."); the registry-docs equality conforms
  to § Enforcement's named test; I5 is conformed by the `user_text` naming a situation and giving a next
  action, never the student, never a score (asserted by inspection against the § Rules quote — the registry
  has no automated content-policy-voice linter, so this is a spec-level conformance check the implementer
  performs by comparing the landed string against the ruling's exact text, not a new test); I9 is conformed
  by this task adding no review-gate code or process of any kind (verifiable by the file scope in §2
  containing no workflow or process file).
- **T5 negative control for every regression guard:** the guard "a code in the registry must also appear in
  a domain doc, and vice versa" is the one this task's edits are coupled by (§4 step 8). Its negative control
  is implicit and pre-existing: if the implementer landed the registry entry (step 2) without the domain
  row/W1 sentence (steps 3–4), `test_error_registry_matches_domain_docs` would red with
  `PLATFORM_SNAPSHOT_REFUSED` in `stray` (in registry, not in docs) — proving the guard fires. No new test
  file is added to demonstrate this; the existing test is the demonstration, and the one-commit rule in step
  8 is how the implementer avoids ever observing that red state on `main`.
- **T6 idempotency / no-leak.** Not applicable: this task adds no runtime writer, no persisted or
  transmitted student-facing shape, and no side effect of any kind — it is a static text change to two files
  checked into version control. Recorded as a decision, not a gap.

## §6 Decision defaults

- IF the new registry entry's placement relative to the domain-doc row should differ (e.g. registry appended
  at array end, doc row appended at table end) THEN it must NOT — the ruling names an explicit placement
  ("placed after `PLATFORM_BUNDLE_INTEGRITY_FAILED`") for both, and §4 steps 2 and 4 place them at the same
  relative position in each file so a future diff reading either file finds the new code adjacent to the
  code it most resembles in cause (both are bundle-validation failures).
- IF `contracts/error-codes.md`'s `Contract version` line should bump THEN it must NOT — per the file's own
  header quote (§3), "Additive registration (a new code with its domain doc row) is allowed without a
  version bump," and this registration adds a new code with its domain doc row and nothing else.
- IF the `user_text` string should be reworded for house style (e.g. shortened, or "reinstall" softened)
  THEN it must NOT — the ruling gives the exact string and AC1 requires it byte-for-byte; any edit is a Q5
  content-policy-voice question the arbiter has already ruled on, not this task's to revisit.
- IF `pipeline/tests/test_contracts.py` needs a new, code-specific test (e.g. asserting
  `PLATFORM_SNAPSHOT_REFUSED`'s `recoverable` is `false`) THEN it does not — the existing
  `test_error_registry_matches_domain_docs` already asserts every entry's field set and the
  `surface`/`user_text` pairing generically, and no code-specific pytest exists for any other entry in the
  registry (verified by reading the whole file's test list); adding one here would be an unrequested,
  inconsistent precedent (RULE 2: no speculative abstraction).
- IF this task should add the `CoreError` case now, since the entry and the case are "coupled" per the
  ruling's ordering-constraint quote THEN it must NOT — the same quote states the coupling is about landing
  order ("the registry entry and the platform row land in task 1... before task 2 adds the `CoreError`
  case"), not about which task's file scope owns the Swift file; `Packages/Core/Sources/Core/CoreError.swift`
  is out-of-scope here per §2 and the plan's explicit statement that 03.3 is "the only task in the EPIC that
  writes `CoreError.swift`".
- IF `ErrorRegistryTests.swift` should gain an assertion proving `platformSnapshotRefused` specifically
  round-trips THEN it should not, yet — no `CoreError` case named `platformSnapshotRefused` exists before
  task 03.3 lands it (confirmed absent: `grep -r "platformSnapshotRefused" Packages/` returns no match), so
  no such case exists for a test in this task to reference; AC5 instead proves the *existing*, unmodified
  test still passes with the registry's new (Core-caseless) entry present.

Standing defaults: identifiers and timestamps are untouched by this task (no id or timestamp field is
added); no model-calling path exists, so no confidence threshold or Tier-0 fallback applies beyond the
observation in §4 step 5; telemetry is untouched; the new `user_text` names no person, device, account,
install or session (I5); no Ministry text, verbatim or paraphrased, is added by this task.

## §7 Done definition

The task is done when ALL gates pass:

- `cd pipeline && uv run ruff check . && uv run ruff format --check .` clean (no Python file is touched by
  this task, so this gate is a no-op pass-through)
- `cd pipeline && uv run pyright` clean (strict) — no Python file is touched
- `cd pipeline && uv run pytest tests/test_contracts.py -q` green, including
  `test_error_registry_matches_domain_docs` with the new entry on both sides
- `xcodebuild test -scheme Core-Package -destination 'platform=iOS Simulator,name=iPhone 16'` (or the
  simulator target `scripts/gate.sh` uses) green, including `ErrorRegistryTests.coreErrorIsSubsetOfRegistry`
  unmodified
- `contracts/error-codes.json` contains the new entry exactly as in §3/§4 step 2; `docs/domains/platform.md`
  carries the W1 sentence and the new table row exactly as in §3/§4 steps 3–4; the commit carries the
  `contract(error-codes)` scope named in §4 step 8
- `contracts/error-codes.md`'s `Contract version` stays `v1.0.0` (AC6)
- tests green for every case in §5
- conforms to every contract section cited in §3 and §4, and to every invariant listed in §1
