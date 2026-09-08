# Idea — mathmath

> Phase 2 output. This is a **structured extract of [`PROJECT-BRIEF-v1.md`](../PROJECT-BRIEF-v1.md)**,
> ratified by the owner on 2026-09-08. The brief is ground truth: **on any conflict, the brief wins.**
> Decisions D1–D19 are locked there; changing one is a Q5 owner decision.

## One-line description

An Ontario grade 9–12 math learning system that **diagnoses** rather than merely explains: it verifies each of a student's homework steps with a CAS, finds the first wrong step, classifies the error, walks a cross-grade concept dependency graph to the deepest unmastered prerequisite, confirms that hypothesis with a ~60-second probe, remediates the minimum piece, and returns to the original problem.

## Who uses it

| Role | Surface | Primary use |
|---|---|---|
| **Student** (grades 9–12) | PWA | Enter a current homework problem in a structured math editor; get step verification, error diagnosis, tiered hints, a probe, and just-in-time remediation |
| **Parent** | read-only parent view (M5) | See which node the student is stuck on, why, and whether they are progressing |
| **Owner** | — | Product testing at M3 acceptance and delivery verification at each wrap-gate. **Not a content reviewer** (D10, D12, D13) |

## Core problem it solves

"Falling behind in math." The differentiator over generic AI chat: **it knows which concept node a student is weak on, why, and which downstream courses that node feeds.** Generic AI explains a problem; this system diagnoses. The method is *just-in-time remediation* — keep moving on the current homework, backfill only the minimum upstream gap, then return to the main line. Answers are never withheld (D5); what is withheld is a cost-free answer — every answer arrives with its diagnosis.

## Reference applications

As cited in the brief §6:

- **ALEKS / Knowledge Space Theory** (Doignon & Falmagne, 1985) — the theoretical basis; ALEKS has operated on it commercially since the late 1990s [SOURCED: aleks.com; Cosyn et al., J. Math. Psychology 2021]. Its public topic structure is an L1 agreement source.
- **Khan Academy**, **OpenStax**, **CK-12** — independently built prerequisite structures used as L1 multi-source agreement inputs. An edge with ≥ 2 independent sources is accepted.

## Scale expectation

A **single static PWA**, no accounts, no server-side application logic in MVP; the opt-in anonymous telemetry endpoint is the sole write path. Concept graph, student state and probe records live in IndexedDB on the device.

Baseline machine (D8): non-Chromebook desktop/laptop, ≥16 GB RAM, ≥20 GB free storage, Chrome 148+ (or same-version Edge), WebGPU available. Storage budget on that baseline: Gemini Nano ≈ 4 GB [SOURCED: press reporting, medium confidence] + app assets < 100 MB [ESTIMATE] + optional fallback model ≈ 2 GB [ESTIMATE: 3B × 4-bit] ≈ 6–7 GB total, leaving > 13 GB — above Chrome's 10 GB free-space threshold below which it evicts the on-device model [SOURCED: developer.chrome.com/docs/ai/prompt-api].

## Compliance constraints

- **D17** — telemetry is anonymous, aggregate, opt-in and account-less; no personally identifiable data is collected.
- **D18** — Crown-copyright permission from the Ontario government is *not* required for MVP: nodes store expectation codes plus the project's own paraphrase and link out to the official page for verbatim text. Request permission only if verbatim curriculum text is ever displayed.
- **D19** — no legal entity, domain, or compliance work until either money is charged or identifiable data is collected. Neither is in scope.
- **§10 licensing position** — Ontario curriculum documents are Crown copyright; non-commercial use of insubstantial excerpts with attribution is permitted, substantial reproduction requires King's Printer permission [SOURCED: publications.gov.on.ca General FAQs]. Codes, course names, strand names and structure are facts and not protected. No permission request is on the critical path.

## Explicit non-goals

Out of scope (brief §9 — queued and stated on the product page):

1. Chromebook (storage/GPU)
2. Mobile / tablet — the Prompt API is desktop-only at present [SOURCED: Chrome developer docs/tutorials; re-verify before release]
3. Safari / Firefox
4. Handwriting / photo OCR (**D9** — input is a structured math editor, MathLive → LaTeX)
5. Tier 2 cloud inference (**D15** — queued, not built; if the Tier 1 spike fails, the architecture is revisited, not patched)
6. Accounts, payments, any legal entity

Also out of scope: **grade 8 and below** (**D1** — Ontario grades 9–12 only).

## Change log

| Date | Change |
|---|---|
| 2026-09-08 | Initial extract from `PROJECT-BRIEF-v1.md` (owner-ratified same day). |
