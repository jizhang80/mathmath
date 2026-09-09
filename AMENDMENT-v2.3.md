# Amendment v2.3 — Single-user game, no server, telemetry default-on

Date: 2026-09-09
Applies to: PROJECT-BRIEF-v2.md, AMENDMENT-v2.1.md, AMENDMENT-v2.2.md
Status: rulings final.

## A. Decisions

**D17 (amended) — Telemetry.** Anonymous, on by default, one-tap off in settings. Random install identifier (user-resettable); no IP retention, no identifiers linkable to a person, no accounts. Declared in the App Store privacy label under "Data Not Linked to You". The privacy-policy page (D35) states this in one paragraph.

**D36 — No application server.** Runtime infrastructure is (a) static content hosting of versioned JSON, with an offline snapshot bundled in the app, and (b) one anonymous telemetry write endpoint (serverless, append-only). Cross-device sync of student state uses CloudKit private database (Apple-managed identity, no accounts of ours). A server is introduced only for Tier 2 (API-key proxy) or accounts — both queued.

**D38 — No parent view.** D16 and the parent-view milestone are void. The product is a single-user game for students. (D37 never took effect.)

**D39 — Leaderboards and achievements, if ever built, use Game Center.** No self-built accounts or ranking service. Not built now; decided during operation from telemetry.

**D40 — Telemetry doubles as product-behaviour observation.** Event set: session start/end; expedition started/completed; per-item node and result (L3); start-marker placement and moves; landmark taps; day-N return. All anonymous per D17.

**D16, D37 — void.**

## B. Milestone changes

- Former M5 (parent view) removed.
- M5 = former M6: coverage expansion; Door A homework mode as desktop web; Android port planned.
- Release: iOS after M5; Android after its port.

## C. Demo brief

No change. Demo has no telemetry, no server, no parent view.

## D. Queue additions

- Game Center leaderboards/achievements (D39)
- Tier 2 now carries two costs: inference and an API-key proxy server (D36)
