# Prototype — mathmath (Phase 4b)

> **Status 2026-09-09 — superseded for student and parent surfaces.** Per `AMENDMENT-v2.2.md` §D the
> native iOS Demo is the Phase 4 UI/UX artifact for Doors B and C (map, expedition); no static-HTML map
> prototype is built. `parent*.html` are void (D38, no parent view). `student-browse.html` and
> `student-node.html` are replaced by the map's panels. `student-session-*.html` remain **reference** for
> the M5 desktop web homework mode (diagnosis domain, homework-mode variant). `owner-*.html` reports
> remain valid for the offline pipeline. `settings-*.html` and `unsupported.html` are void (native
> Settings screens replace them; no environment gate on iOS). The Phase 4c owner click-through is not
> required.

Status (2026-09-08): **draft for the Phase 4c PDCA review**. Clickable static HTML over mocked data; no backend, no
business logic, no framework, no CDN. It exists to prove *interaction completeness*: every workflow in
every `docs/domains/*.md` has an entry point and a termination on these pages.

## How to open it

Any static server over `docs/` works; the pages reference `../design-system/*.css` relatively.

```bash
python3 -m http.server 8765 --directory docs
```

Then open <http://localhost:8765/prototype/index.html>. (`.claude/launch.json` carries the same command
under the name `prototype`.) Opening the files directly with `file://` also works in Chrome.

## How to read a page

- The yellow **proto-bar** at the top names the route, the domain workflows the page realises, and a row
  of **variant buttons** — each switches the page to one state (first failure, offline, empty, capped…).
  The state is also in the URL hash, so links between pages land on a specific state.
- Yellow dotted **prototype notes** tell the owner which workflow step, invariant or ratified open
  question a piece of UI comes from, and flag `GAP:` items. They are not product copy.
- Everything else is meant to read as the product would.

## Files

| Kind | Files |
|---|---|
| Route map + walk-through | `index.html` |
| Student §7 flow | `student-session*.html` (entry, steps, classify, hint, probe, remediation, answer) |
| Student other | `student-history.html`, `student-browse.html`, `student-node.html` |
| Parent | `parent.html`, `parent-gap.html`, `parent-trend.html` |
| Settings and shell | `settings-data.html`, `settings-storage.html`, `settings-models.html`, `unsupported.html` |
| Owner offline reports | `owner-*.html` — the written reports the Owner-run CLIs produce; local only |
| Prototype plumbing | `proto.css`, `proto.js`, `_template.html` (not part of the design system) |
| Review | `CHECKLIST.md` — the Phase 4c completeness checklist, route proposals and gap list |

## Mock data

One consistent world: the D14 starting chain (nine nodes, MTH1W → MHF4U), the M4′ six-value error enum
for logarithmic equations, one worked problem (log₂(x) + log₂(x − 2) = 3, first failure at step 2), and
three sessions on one device (day granularity only). No names, no accounts, no identifiers — I5 holds even
in the mock.
