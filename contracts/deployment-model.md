# Contract: Deployment model (LOCK-FIRST)

**Contract version:** v1.0.0 · Source: D29, D31, D34–D36, `docs/tech-stack.md` §4

> Single deployment, no per-client instances, **no application server**. The executable form of this contract
> is `.github/workflows/ci.yml`, `scripts/branch-ruleset.json` and (at M3) the Cloudflare configuration.

| Surface | Where | Write path? |
|---|---|---|
| Student app | iOS/iPadOS 18+; direct Xcode install on registered devices (Demo–M4), TestFlight external before release, App Store at release (D35) | — |
| Content bundles | Cloudflare Pages, immutable files keyed by `asset_version`; an offline **snapshot** of one complete bundle ships inside every app build (D36 a) | read-only GET |
| Telemetry | one Cloudflare Worker (POST, append-only) → R2; no read API; no IP retention (`telemetry.md`) (D36 b) | **the only POST** |
| Student state | local JSON (Application Support) + iCloud (Drive container or CloudKit, chosen at M3) under Apple's identity, only when signed in (v2.5 §5) | Apple-managed |
| Pipeline | owner's Mac; Claude API (offline generation only) | outbound to Anthropic only |

**Network allowlist for the app (asserted by a test, App EPIC):** the content host, the telemetry endpoint,
iCloud. Nothing else, ever — a spec adding a host is a Q5 (D36).

**Environments:** one. No staging: a bundle is promoted by publishing a new `asset_version` and manifest;
the app swaps atomically at next launch (platform Q2). Rollback = publish the previous manifest.

**CI/CD:** GitHub Actions on `macos-26`; `main` protected by ruleset (PR + both jobs green); no deploy
automation until M3 (content publish and Worker deploy are owner-run scripts recorded in the EPIC that adds
them, and exercised by a gate — C4).

**Secrets:** none in the app. The telemetry app token identifies the build, not a person, and is rotated by
publishing a new build. The Claude API key lives only in the owner's shell environment for the pipeline.
