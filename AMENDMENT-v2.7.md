# Amendment v2.7 — Conflict rulings on v2.6

Date: 2026-09-09
Applies to: PROJECT-BRIEF-v2.md (D1, D2, I8), AMENDMENT-v2.6.md (D45, D47, D48)
Status: rulings final.

## 1. D1 and D2 revised; I8 amended.

**D1 (revised) — Scope.** The map covers foundational through undergraduate engineering mathematics (D43). Content build order is strict: D14 chain → remaining grade 9–12 strands → undergraduate. "Ontario grades 9–12" is the first content tier, not the product boundary.

**D2 (revised) — Authority by tier.** For grade 9–12 nodes, the Ontario Ministry of Education curriculum documents are the sole authority; nodes carry `expectation_codes`. For undergraduate nodes, the authority is a designated CC-licensed source (OpenStax CC BY 4.0; MIT OCW CC BY-NC-SA); nodes carry `source_ref` (source, edition, chapter/section). A node must carry at least one of `expectation_codes` or `source_ref`; a node with neither fails L0.

**I8 (amended).** The bidirectional code↔node coverage check applies only to nodes with `expectation_codes` (and to every Ministry expectation in the spine). Undergraduate nodes are checked instead for a resolvable `source_ref`. Both checks are L0.

## 2. D45 — unit source.

Units are not in the Ministry documents. Default: for each course, one designated textbook (chosen at M1, recorded in the spine data as the course's `unit_source`) defines unit order; expectations are grouped by that textbook's chapter sequence — this is the existing L1 `textbook_order` source. If a course has no designated textbook or an expectation is unplaced, fall back to grouping by strand in Ministry order. The student picks from that list. The Demo's hand-written unit lists stand.

## 3. D48 — scope corrected; spaced repetition stands (reading a).

D48 governs eligibility of **new-learning** items only. An expedition is composed of: new-learning slots drawn from the trail's outer fringe (D48, within current + next unit per D45), plus up to 2 due-review slots drawn from cleared nodes per the approved spaced-repetition policy (expedition Q2/Q3). The map's "due" ring and the D40 review signals are unchanged. The v2.6 sentence "this is the whole scheduling policy" is withdrawn; the policy is D48 + D27 + Door A + the review slots.

## 4. D47 — trail extension rule.

When the course-progress marker is moved past the course's last unit, the trail extends from the course's terminal nodes along downstream prerequisite edges, preferring the next course in the same stream per the Ministry's course-prerequisite chart (e.g. MPM2D → MCR3U → MHF4U → MCV4U) [SOURCED: Ontario secondary mathematics prerequisite chart in the 2007 curriculum document], then into undergraduate trails when those nodes exist. The extension is opt-in by marker position, never automatic. Extension segments are drawn dashed to mark "beyond the course". Course succession is data in the spine (`next_courses[]` per course), not logic.

## 5. Confirmed without ruling

Everything the harness listed as "will apply directly" is confirmed as written, including: shore region not drawn in the Demo (product decision at M5); UI English-only per DEFERRED D-1; ideas layer to DEFERRED.
