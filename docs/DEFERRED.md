# Deferred items

> Items explicitly deferred, with the trigger that should bring them back. Recorded so a "not now"
> decision is traceable, not lost.
>
> **Entry template (control C6 / principle P6 — see [`docs/carry-forward.md`](carry-forward.md)).**
> Every entry is written as:
>
> ```
> ### D-n — <item>
> **Observed:** what was actually measured or decided, and where that is recorded.
> **Configuration:** the environment/config under which that observation holds.
> **Revisit trigger:** the condition that brings this item back.
> **Hypothesis (unverified):** any diagnosis or proposed remedy — or "none".
> ```
>
> A deferral records **a measurement and its conditions, never a diagnosis**. Any diagnosis or prescribed
> remedy goes under `Hypothesis (unverified)` and nowhere else, because the recorded diagnosis is
> otherwise read as ground truth by whoever picks the item up later — and it is the one part of the entry
> nobody re-derives. **Consuming work re-measures before planning against an entry.**
>
> Re-cut 2026-09-09 for the v2 pivot (`PROJECT-BRIEF-v2.md` + `AMENDMENT-v2.1`–`v2.5`). Entry ids D-n are
> ledger ids, unrelated to the brief's decision numbers Dn.
>
> **2026-10-06 — v2.8 (web first, native frozen).** D-1 to D-7 are re-stated for the web platform. D-12 to
> D-19 record observations made on the frozen native Demo (D50); their configuration is the Swift code, and
> any web EPIC that consumes one re-measures it on the web build first. D-20 to D-23 are new.

---

### D-1 — UI internationalization (English-only MVP)

**Observed:** scoped out in `PROJECT-BRIEF-v2.md` §9 / §12 — documentation and code are English, and no
locale set is defined for the UI. No hardcoded-string lint rung is wired.
**Configuration:** web app (D31 as revised by v2.8), English UI only.
**Revisit trigger:** a French-language user request, or the M5 coverage-expansion scope review.
**Hypothesis (unverified):** none.

### D-2 — Tier 2 cloud inference

**Observed:** queued, not built (D15). Rationale changed by `AMENDMENT-v2.1.md` A4 from "fallback when
Tier 1 fails" to "possible attractor if in-product AI conversation proves part of the appeal"; `AMENDMENT-v2.3.md`
§D records that Tier 2 now carries two costs — inference and an API-key proxy server (D36).
**Configuration:** no application server (D36); Tier 1 deferred (v2.8 §8, D-20), so Tier 0 is the only runtime tier.
**Revisit trigger:** Demo observations (tester feedback on in-product AI conversation), or the D-20 re-entry
decision.
**Hypothesis (unverified):** none.

### D-3 — Android

**Observed:** `AMENDMENT-v2.8.md` §1 — the student product is a web app; Android users reach it in the browser.
A native or wrapped Android app is part of the app-store question in D-23.
**Configuration:** web app; primary targets iPad and iPhone Safari, desktop Chrome/Safari supported (D34).
Android Chrome is not a stated target and has no test path of its own.
**Revisit trigger:** D-23, or a tester on Android.
**Hypothesis (unverified):** none.

### D-4 — Door A homework mode (structured editor + CAS step verification)

**Observed:** `AMENDMENT-v2.2.md` §C removed the homework flow from M3 and placed it at M5;
`AMENDMENT-v2.8.md` §6 makes it a desktop-first surface of the same web app instead of a separate app. Its
design is preserved in `docs/domains/verification.md` and the homework-mode variant in
`docs/domains/diagnosis.md`; the v1 prototype's `student-session-*` pages are its reference.
**Configuration:** the web app checks numeric and multiple-choice items in code (I1, I10); no CAS in the client.
**Revisit trigger:** M5 scope.
**Hypothesis (unverified):** none.

### D-5 — Firefox (all doors); Chromebook

**Observed:** `AMENDMENT-v2.1.md` §9 amendment excludes Firefox for all doors. `AMENDMENT-v2.8.md` §6 names
Safari on iOS/iPadOS 18+ and current desktop Chrome/Safari as the baseline; Firefox and Chromebook are not
named. Any browser on-device model API is part of D-20.
**Configuration:** web app; CI end-to-end tests run under the WebKit and Chromium engines only (D29).
**Revisit trigger:** M5 (homework mode's desktop baseline), or a tester on an unlisted browser.
**Hypothesis (unverified):** none.

### D-6 — Parent view

**Observed:** removed by `AMENDMENT-v2.3.md` D38 ("no parent view; single-user game for students"); D16
and the former M5 milestone void. The v1 design is in git history (`docs/domains/parent-view.md`, deleted
2026-09-09) and the v1 prototype's `parent*.html` pages, now void.
**Configuration:** no accounts, no sync of ours (D17, D36); a personal phone, not a shared family desktop.
**Revisit trigger:** none scheduled — an owner decision (Q5) only.
**Hypothesis (unverified):** none.

### D-7 — Leaderboards and achievements

**Observed:** `AMENDMENT-v2.3.md` D39, revised by `AMENDMENT-v2.8.md` §11 — Game Center is unavailable on
the web; not built now; if ever built, the mechanism is decided then, with no self-built accounts or ranking
service.
**Configuration:** streaks, region completion and trail progress emerge from local state (D23).
**Revisit trigger:** decided during operation from telemetry (D40 day-N return, expedition completion).
**Hypothesis (unverified):** none.

### D-8 — Handwriting / photo OCR

**Observed:** excluded by D9 / I10 — input is defined per door (numeric or multiple-choice items;
structured editor in homework mode); no OCR in any door.
**Configuration:** all doors.
**Revisit trigger:** post-release.
**Hypothesis (unverified):** none.

### D-9 — Ideas layer (cross-cutting mathematical ideas as internal landmarks)

**Observed:** `AMENDMENT-v2.6.md` §C records it as a queued design candidate, not a decision: a small set of
ideas (inverse, linearity, rate of change, equivalence, symmetry, limit, …) each linking nodes across regions
and grades, presented like landmarks, to show mathematics as recurring ideas rather than a staircase.
**Configuration:** map with regions, trails and real-world landmarks (D20–D22, D47).
**Revisit trigger:** Demo observations showing how the testers relate to the map.
**Hypothesis (unverified):** none.

### D-10 — Shore region (grade 7–8 fractions / integers / ratio)

**Observed:** `AMENDMENT-v2.6.md` D21 (revised) allows an optional "shore" region drawn with no content and
no fog mechanics; `AMENDMENT-v2.7.md` §5 confirms it is not drawn in the Demo.
**Configuration:** ten-region continent per D21 revised.
**Revisit trigger:** M5 (product decision after the grade 9–12 strands are covered).
**Hypothesis (unverified):** none.

### D-11 — Additional syllabi as trails (AP Calculus AB/BC, AP Statistics, IB Mathematics AA/AI, first-year undergraduate)

**Observed:** `AMENDMENT-v2.6.md` D49 — added as trails when their nodes exist; a trail is a node-id list,
so the cost is the list, not content.
**Configuration:** per-student generated trails (D47) over one graph (I7).
**Revisit trigger:** the undergraduate content tier reaching the relevant nodes (D1 order), or a tester request.
**Hypothesis (unverified):** none.

### D-12 — `MAP_MARKER_OFF_TRAIL` user text vs. the load-time marker fallback

**Observed:** EPIC 02 pre-dispatch arbitration Q-D (`tasks/arbitration/arbiter-02-predispatch.md`). On load,
a saved marker naming a unit absent from the bundle makes `Core` return `MAP_MARKER_OFF_TRAIL` as data
together with the default marker (`MarkerTrail.reconcileMarker`, EPIC 02 task 02.5). The registered
`user_text` in `contracts/error-codes.json` says the marker stays where it was, but on this path the marker
moves.
**Configuration:** `contracts/error-codes.json` v1.0.0; `Core` returns the code as data and shows no UI text.
**Resolved (EPIC 03):** arbiter ruling Q-A (`tasks/arbitration/arbiter-03-predispatch.md`), option (a):
- No student text on the load path. `Core` computes the message list, which is empty for this code on this
  path; the App shows what `Core` hands it and never branches on a code.
- When no course in `syllabi[]` resolves, the outcome is "course selection needed", again with no text.
- Loading never writes the state file.
- The registered `user_text` belongs to the marker-drag path, which the Demo does not build (D-14). The
  registry is unchanged.

Verified by `Packages/Core/Tests/CoreTests/MapLaunchTests.swift`: the W7 `MCR3U.u9` fallback with empty
messages (AC4), and the `MHF4U` variant returning `courseSelectionNeeded`. The App side is checked by
`AppShellStructuralTests` (EPIC 03 task 03.12): it never names `MAP_MARKER_OFF_TRAIL`.
**Revisit trigger:** EPIC 10, when a content refresh can change unit ids and the load path becomes reachable in
practice.
**Hypothesis (unverified):** none.

### D-13 — Untracked SwiftPM artefact under the Xcode project's embedded workspace

**Observed:** after EPIC 02 simulator builds, `App/mathmath.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`
appears untracked. `.gitignore` covers `xcuserdata/` there, not `xcshareddata/swiftpm/`. It is neither
committed nor deleted. Re-measured at the EPIC 03b wrap:
- The directory is still present and untracked. It holds `Package.resolved` (390 bytes) and an empty
  `configuration/`.
- `git check-ignore` reports that it is not ignored.
- Its single pin is `swiftmath` 1.7.3.
- It differs from both tracked `Package.resolved` files (`App/mathmath.xcworkspace/xcshareddata/swiftpm/` and
  `Packages/Rendering/`) only in `originHash`; the pins are identical.
**Configuration:** `xcodebuild` runs from `scripts/gate.sh` on the iOS simulator; the App builds through
`App/mathmath.xcworkspace`.
**Revisit trigger:** the next tooling or `.gitignore` change, or when the directory is first found staged by
mistake.
**Hypothesis (unverified):** it is SwiftPM resolution state that Xcode writes when the project is resolved
directly. An ignore rule is likely correct, but whether `Package.resolved` there should be tracked has not been
checked.

### D-14 — Marker drag with unit-boundary snap

**Observed:** `interaction-contract.md` v0.9.1 listed "the unit-boundary snap for dragging the marker" as a
finalization item owed by the Demo EPIC. Arbiter ruling Q-B (`tasks/arbitration/arbiter-03-predispatch.md`)
resolved it for the Demo: the marker is set only by choosing an entry from the selected course's unit list,
with a final "past the last unit" entry; no drag gesture is built, and `docs/domains/map.md` § W5 no longer
describes a drag path.
**Configuration:** `interaction-contract.md` v0.9.2 § 3; the Demo's marker picker (EPIC 03 task 03.11) is a
unit-list picker only, with no drag gesture.
**Revisit trigger:** Demo observations (`DEMO-BRIEF.md` § 7 Acceptance).
**Hypothesis (unverified):** none.

### D-15 — Snapshot `sha256` verification at load

**Observed:** `docs/plans/epic-01-task-plan.md` planner note 2 deferred "hash *verification at load*" to EPIC 03.
EPIC 03 ruled that it belongs to the hosted-bundle fetch, not the embedded snapshot (arbiter ruling Q-H,
`tasks/arbitration/arbiter-03-predispatch.md`). Three reasons:
- `docs/domains/platform.md` § AssetVersion says the hash is "checked on fetch".
- The snapshot ships inside the signed build.
- A hash check in `Core` would need CryptoKit, which D33 forbids.

EPIC 03 therefore enforces manifest completeness, the format major version and L0 at load, and verifies no
hashes. Every `sha256` in `data/demo/manifest.json` is an all-zero placeholder of 64 hex characters, which is the length of a
SHA-256 digest (re-measured 2026-09-11 at the EPIC 04a start). An earlier report of 66 characters was a measurement
error. It appeared in `docs/audits/epic-02-acceptance.md` §6 and in this entry as first written. Its likely source is
a 62-zero literal mis-quoted in the 04.1b spec, which has since been corrected.
**Configuration:** the Demo. The embedded snapshot is the only bundle, and there is no network.
**Revisit trigger:** EPIC 10 hosted bundles (platform W2).
**Hypothesis (unverified):** none.

### D-16 — Region and landmark panels have no tap trigger in the Demo

**Observed:** EPIC 03 task 03.11 ships `RegionPanelView` and `LandmarkPanelView` (`App/Sources/MapUI/`). Task
03.10's `MapCanvasView` resolves node taps only: its single callback is `onNodeTap` (03.10 §6 decision default).
Task 03.12 §4.2 records that neither panel can be opened in the Demo, and calls this "a known, intentionally
deferred gap, not a Q5".
**Configuration:** the Demo map screen (`App/Sources/Shell/AppShell.swift`, task 03.12) presents `NodePanelView`
from `onNodeTap` and the unit-list picker from the toolbar. Nothing presents the region or landmark panel.
**Revisit trigger:** the owner's Demo review (`DEMO-BRIEF.md` § 7 Acceptance), or the first task that adds region
or landmark tap resolution to `MapCanvasView`.
**Hypothesis (unverified):** none.

### D-17 — Region tint deltas on the expedition summary
**Observed:** interaction-contract v0.9.3 § 2 resolves the summary to nodes cleared, fog lifted, blocked marked,
"Start another" / "Back to the map", with no region tint delta (arbiter-04 Q-A). A per-region fraction on a
student surface would conflict with content-policy § Voice ("no scores or percentages on student surfaces").
**Configuration:** Demo (`data/demo`); the map re-tints on return (map W6).
**Revisit trigger:** Demo observations (DEMO-BRIEF §7 items 2 and 3).
**Hypothesis (unverified):** none.

### D-18 — Hint tiers 2–3 ("ask for the next hint") on Door A screens
**Observed:** EPIC 04 shows only tier 1 of the resolved hint (arbiter-04 Q-F, per DEMO-BRIEF §3.6 "one
level"); `data/demo` carries three tiers per `hint_tree` entry (schema minItems/maxItems 3).
**Configuration:** Demo, Tier 0, iOS app.
**Revisit trigger:** Demo observations, or EPIC 12 (M3 screens on real data).
**Hypothesis (unverified):** none.

### D-19 — Glossary identifier gate over the Python pipeline and `data/` JSON keys
**Observed:** the glossary identifier gate (`Packages/Core/Tests/CoreTests/GlossaryIdentifierGateTests.swift`,
domain-glossary v1.0.2) scans Swift identifiers only. Measured on 2026-09-14 with the same rule (59 banned
phrases parsed from the glossary; camel/snake word split; last word inflected): 48 distinct Python
identifiers under `pipeline/` hit a banned term (`path`, `parent`, `module`, `attempt`, `example`, `fail`,
`position`, `task`, `unknown`), and 8 distinct JSON keys across `data/` and `contracts/schemas/` hit one
(`strand`, `strands`, `position`, `unknown`, `worked_examples`, `tier1_available`, `task`,
`downstream_fail_given_upstream_fail`). Every one of those JSON keys is fixed by a locked schema, and
the pipeline's `attempt` is a transport retry count that `tasks/arbitration/arbiter-03-audit-f1-attempt.md`
ruling 2 already rules not in violation.
**Configuration:** pipeline Python 3 under `uv` (pyright strict, ruff, pytest); JSON keys governed by
`contracts/schemas/` (JSON Schema 2020-12).
**Revisit trigger:** a pipeline EPIC that adds Python identifiers naming glossary concepts, or an audit
finding of glossary drift in `pipeline/` or in a schema key.
**Hypothesis (unverified):** a pytest gate over the Python AST (`ast.Name`/`attr`/`arg`) and schema keys
with its own allowlist, reading the same glossary lists.

### D-20 — Tier 1 on-device model (M4′ spike, M4 integration)

**Observed:** `AMENDMENT-v2.8.md` §8 — Foundation Models is unavailable to a web app; Tier 1, the M4′ spike
and M4 are deferred. Tier 0 remains the product (I2). The M4′ design (six-way error enum, synthetic
round-trip data, top-1 ≥ 80 % go line [ESTIMATE: owner-set]) is preserved in `docs/domains/runtime-tiers.md`
and `docs/epic-plan.md` EPICs 05–06 as written on 2026-09-10.
**Configuration:** web app, Tier 0 only; no runtime server (D36).
**Revisit trigger:** an on-device model API available in the target Safari versions, or a native wrapper
decided under D-23.
**Hypothesis (unverified):** none.

### D-21 — Cross-device sync of student state

**Observed:** `AMENDMENT-v2.8.md` §9 — Apple-managed identity is unavailable to a web app and accounts remain
queued, so no sync is provided. State lives in browser storage with a persistent-storage request and file
export/import. Introducing sync is a Q5.
**Configuration:** web app, no accounts (I5), no application server (D36).
**Revisit trigger:** a tester reporting lost or split progress across devices, or D-23.
**Hypothesis (unverified):** none.

### D-22 — Safari storage eviction (installed vs. not installed)

**Observed:** `AMENDMENT-v2.8.md` §9 names the risk that Safari may evict storage for a site that is not
installed to the home screen. Not yet measured on this app.
**Configuration:** web app on iPad/iPhone Safari, state in browser storage with a persistent-storage request.
**Revisit trigger:** the web Demo — measure, installed and not installed, whether state survives and what
the persistent-storage request returns; record the result here.
**Hypothesis (unverified):** none.

### D-23 — Native app-store presence (iOS, Android)

**Observed:** `AMENDMENT-v2.8.md` §1–§2 — the native iOS code is frozen (D50); an app-store presence is
decided later, and wrapping the web app is one option, not a commitment.
**Configuration:** the frozen Swift code under `Packages/` and `App/` (EPICs 01–04); the web app is the product.
**Revisit trigger:** an owner decision (Q5) after the web Demo or M3.
**Hypothesis (unverified):** none.
