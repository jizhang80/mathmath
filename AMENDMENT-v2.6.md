# Amendment v2.6 — One map, one trail per student

Date: 2026-09-09
Applies to: PROJECT-BRIEF-v2.md, AMENDMENT-v2.1.md (D28), DEMO-BRIEF.md
Status: rulings final.

## A. The model

One full-size map. Each student has their own trail. Expeditions draw only from the outer fringe of that trail — nodes whose prerequisites the student has cleared and which the student has not. This one model serves the student sprinting ahead (trail continues past the course end), the student staying half a step ahead of class (trail is the course), and the student carrying upstream debt (trail has blocked nodes) — without modes.

Basis: Knowledge Space Theory — assess the knowledge state, present the outer fringe [SOURCED: Doignon & Falmagne 1985; ALEKS].

## B. Decisions

**D43 — Map scope: foundational through undergraduate engineering mathematics.** The continent is drawn at full size from the Demo onward. Content build order is unchanged and strict: D14 starting chain → remaining grade 9–12 strands → undergraduate. Undergraduate sources are CC-licensed (OpenStax CC BY 4.0 [SOURCED: openstax.org licensing]; MIT OCW CC BY-NC-SA).

**D21 (revised) — Regions:** Number & Operations · Algebra · Functions · Geometry & Measurement · Trigonometry · Calculus (single- and multivariable in one region; depth by node) · Linear Algebra · Differential Equations · Probability & Statistics · Discrete Mathematics. Horizon (names only, no content): Analysis, Topology, Number Theory, Abstract Algebra. Optional "shore" region for grade 7–8 fractions/integers/ratio: drawn, no content, no fog mechanics.

**D47 — The trail is the unit of personalization.** A trail is a per-student object generated from: the course syllabi selected, the course-progress marker (D45), and the student's mastery state. A trail may extend beyond a course's end into further territory (sprinter case). No per-archetype modes are designed.

**D44 — Trail first.** Default view and expedition scheduling are anchored on the student's trail; the continent is background, always reachable by zooming out.

**D45 — Course-progress marker (replaces D28's semantics; mechanics unchanged).** The student marks "we are here" from the course's unit list. Units map to expectation codes. The scheduler draws from the current and next unit's nodes on the trail's fringe. Nodes upstream of the marker are excluded from the fringe and reached only through Door A.

**D46 — Unit expeditions.** A student may request an expedition restricted to one unit (pre-test review). Scheduler parameter only.

**D48 — Fringe rule.** An item is eligible for an expedition only if its node is on the trail's outer fringe. Combined with D27 (tolerance) and Door A (blocked upstream), this is the whole scheduling policy.

**D49 — Additional syllabi as trails (queued).** AP Calculus AB/BC, AP Statistics, IB Mathematics AA/AI, and first-year undergraduate syllabi are added as trails when their nodes exist. A trail is a node-id list; cost is the list, not content.

## C. Queued design candidate (not a decision)

**Ideas layer.** A small set of cross-cutting mathematical ideas (inverse, linearity, rate of change, equivalence, symmetry, limit, …), each linking nodes across regions and grades, presented as internal landmarks. Purpose: show mathematics as recurring ideas rather than a staircase. Considered only after Demo observations show how testers relate to the map. Rationale recorded in conversation 2026-09-09.

## D. Demo brief deltas

- §3.1: initial camera on the tester's selected course trail (MTH1W or MCR3U), continent visible around it; zoom-out available. Ten regions drawn as outlines per revised D21; nodes still only in Number, Algebra, Functions.
- §3.3: the start marker is presented as "we are here in class" chosen from a short unit list for the course (hand-written for the two demo trails).
- §3.5: fringe selection per D48 within current + next unit.
- §7 acceptance: add item 7 — "Did the tester move the class marker, and did the first expedition feel related to what they are doing in class?"

## E. Residual unknowns (add to §11)

- Proof-based territory (Discrete, parts of Analysis): probes as numeric/MC do not fit; expedition form there is undecided. Does not block; content order reaches it last.
- Framing by motivation (sprint / stay ahead / recover): the same expedition may need different packaging. Decided from telemetry (D40), not designed now.
