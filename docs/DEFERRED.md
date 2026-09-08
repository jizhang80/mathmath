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

---

### D-1 — UI internationalization (English-only MVP)

**Observed:** scoped out in `PROJECT-BRIEF-v1.md` §9 / §12 — documentation and code are English, and no
locale set is defined for the UI. No hardcoded-string lint rung is wired.
**Configuration:** MVP baseline environment D8 — non-Chromebook desktop/laptop, ≥16 GB RAM, ≥20 GB free
storage, Chrome 148+ (or same-version Edge), WebGPU available; single static PWA, no accounts.
**Revisit trigger:** a French-language user request, or the M6 coverage-expansion scope review.
**Hypothesis (unverified):** none.

### D-2 — Tier 2 cloud inference

**Observed:** scoped out in `PROJECT-BRIEF-v1.md` §9 / **D15** — Tier 2 (Claude API) is queued, not built
in MVP; if the Tier 1 spike fails, the architecture is revisited, not patched.
**Configuration:** MVP baseline environment D8, as above. Tier 0 deterministic + Tier 1 local model only;
static hosting with the opt-in telemetry endpoint as the sole write path.
**Revisit trigger:** M4′ fails its go/no-go bar — top-1 accuracy below 80 % on synthetic data
[ESTIMATE: owner-set threshold leaving headroom for real-data degradation; not from literature] — or
post-release demand.
**Hypothesis (unverified):** none.

### D-3 — Chromebook, mobile/tablet, Safari/Firefox, handwriting/photo OCR

**Observed:** scoped out in `PROJECT-BRIEF-v1.md` §9 items 1–4. Chromebook is excluded on storage/GPU;
mobile/tablet because the Prompt API is desktop-only at present [SOURCED: Chrome developer
docs/tutorials; re-verify before release]; Safari/Firefox unsupported; OCR excluded by **D9** — input is
a structured math editor (MathLive → LaTeX).
**Configuration:** MVP baseline environment D8, as above.
**Revisit trigger:** post-release.
**Hypothesis (unverified):** none.
