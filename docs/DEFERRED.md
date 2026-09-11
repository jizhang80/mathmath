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

---

### D-1 — UI internationalization (English-only MVP)

**Observed:** scoped out in `PROJECT-BRIEF-v2.md` §9 / §12 — documentation and code are English, and no
locale set is defined for the UI. No hardcoded-string lint rung is wired.
**Configuration:** native iOS app (D31–D34), English UI only.
**Revisit trigger:** a French-language user request, or the M5 coverage-expansion scope review.
**Hypothesis (unverified):** none.

### D-2 — Tier 2 cloud inference

**Observed:** queued, not built (D15). Rationale changed by `AMENDMENT-v2.1.md` A4 from "fallback when
Tier 1 fails" to "possible attractor if in-product AI conversation proves part of the appeal"; `AMENDMENT-v2.3.md`
§D records that Tier 2 now carries two costs — inference and an API-key proxy server (D36).
**Configuration:** no application server (D36); Tier 1 = on-device Foundation Models (D32, D34).
**Revisit trigger:** Demo observations (tester feedback on in-product AI conversation), or M4′ failing its
top-1 ≥ 80 % bar [ESTIMATE: owner-set] — the latter revisits the architecture, not a patch (D15).
**Hypothesis (unverified):** none.

### D-3 — Android port

**Observed:** `AMENDMENT-v2.2.md` D31 — native iOS first; Android is a second codebase built after iOS
ships, with `core` ported from the Swift package and JSON data formats shared (D33). Tier 1 on Android via
ML Kit GenAI / AICore where available, decided at that time (D34).
**Configuration:** iOS/iPadOS 18+ app (D34); `Core` renderer-free and Foundation-only (I14).
**Revisit trigger:** iOS release after M5 (`AMENDMENT-v2.3.md` §B).
**Hypothesis (unverified):** none.

### D-4 — Door A homework mode (structured editor + CAS step verification), desktop web

**Observed:** `AMENDMENT-v2.2.md` D34 and §C — the homework flow is removed from M3 and built at M5 as a
desktop web app (Pyodide + SymPy, MathLive); its design is preserved in `docs/domains/verification.md`
and the homework-mode variant in `docs/domains/diagnosis.md`; the v1 prototype's `student-session-*`
pages are its reference. TypeScript is retained only for it (`AMENDMENT-v2.4.md` §2).
**Configuration:** iOS app checks numeric and multiple-choice items in code (I1, I10); no CAS on device.
**Revisit trigger:** M5 scope.
**Hypothesis (unverified):** none.

### D-5 — Firefox (all doors); Chrome Prompt API; Chromebook

**Observed:** `AMENDMENT-v2.1.md` §9 amendment excludes Firefox for all doors; `AMENDMENT-v2.2.md` D34
takes the Chrome Prompt API off the critical path (Tier 1 is Foundation Models on iOS). Chromebook and
Safari constraints now apply only to the M5 desktop homework mode's Tier 1, designed at M5.
**Configuration:** native iOS app for all student surfaces in MVP.
**Revisit trigger:** M5 (homework mode's desktop baseline and Tier 1 choice).
**Hypothesis (unverified):** none.

### D-6 — Parent view

**Observed:** removed by `AMENDMENT-v2.3.md` D38 ("no parent view; single-user game for students"); D16
and the former M5 milestone void. The v1 design is in git history (`docs/domains/parent-view.md`, deleted
2026-09-09) and the v1 prototype's `parent*.html` pages, now void.
**Configuration:** no accounts, no sync of ours (D17, D36); a personal phone, not a shared family desktop.
**Revisit trigger:** none scheduled — an owner decision (Q5) only.
**Hypothesis (unverified):** none.

### D-7 — Game Center leaderboards and achievements

**Observed:** `AMENDMENT-v2.3.md` D39 — if ever built, use Game Center; no self-built accounts or ranking
service; not built now.
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
**Revisit trigger:** EPIC 03, when the App first surfaces this code to the student.
**Hypothesis (unverified):** either suppress the message on the load path or register a separate code; this is
the UI-text owner's call.

### D-13 — Untracked SwiftPM artefact under the Xcode project's embedded workspace

**Observed:** after EPIC 02 simulator builds, `App/mathmath.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`
appears untracked. `.gitignore` covers `xcuserdata/` there, not `xcshareddata/swiftpm/`. It is neither
committed nor deleted.
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
hashes. Every `sha256` in `data/demo/manifest.json` is an all-zero placeholder of 66 hex characters, not the 64 of a
SHA-256 digest. The EPIC 04 task 04.1b reviewer found this; it is recorded in `docs/audits/epic-02-acceptance.md` §6.
**Configuration:** the Demo. The embedded snapshot is the only bundle, and there is no network.
**Revisit trigger:** EPIC 10 hosted bundles (platform W2). The task that first writes real hashes into a manifest
also corrects the placeholder length.
**Hypothesis (unverified):** none.
