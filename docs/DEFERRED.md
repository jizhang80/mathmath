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
