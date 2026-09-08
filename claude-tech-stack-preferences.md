# Claude's Tech Stack Self-Assessment

> **Role in the document set:** this is the **concrete-instantiation layer**. The *abstract*, durable stack-selection principles (strict typing, explicit state, thin runtime, boundary validation, explicit data access, observability at the review surface) live in the SicLab framework doc, §6. This file holds the specific tool choices those principles point to, and is what `bootstrap.md` Phase 5 derives from. **The principle is binding; the tool name is not** — a principle is satisfiable multiple ways, and a specific choice should be validated against your own correction-round data, not adopted on faith.

> Honest self-report of where Claude's code output tends to be most reliable. Based on pattern observation, not measured benchmarks. Use this as a reference when picking stacks for new projects where Claude will do most of the implementation.

---

## TL;DR Meta-Principle

Claude's output quality goes up sharply when:

1. The type system catches mistakes at compile time
2. State is explicit rather than implicit
3. The runtime is small enough that Claude isn't threading needles through framework magic

Lean toward: strict typing, validation at boundaries, SQL-first, server-rendered when possible, small composable modules.

**A fourth criterion, for an AI-first shop where the human does not read code:** choose for *observability at the review surface*. Since review happens at the test/UI layer and debugging is Claude-assisted, prefer stacks whose failures surface as **build errors, test failures, or visible UI defects** rather than silent runtime behavior. Strict typing and boundary validation are not only error-reducers — they relocate failures into the human's visibility. The buildability bound is: **Claude can diagnose and repair it, its failures are observable at the test/UI surface, and there is an escalation path for the catastrophic case.**

---

## TypeScript Ecosystem — Strongest Tier

### Preferred stack

- **TypeScript strict mode, everywhere.** No JS unless legacy.
- **PostgreSQL** with **Drizzle** or **Kysely** (raw-ish SQL with types). Avoid Prisma — its generated types help, but its query API has edge cases Claude gets wrong.
- **Zod at every boundary** — HTTP input, env vars, external API responses, queue payloads. Single source of truth for types.
- **Hono** or **Fastify** for backend, not Express. Better TS ergonomics, no middleware-mutation patterns.
- **Next.js App Router** for full-stack web, or **Vite + React + TanStack Router** for SPA.
- **Tailwind + shadcn/ui** for UI. shadcn over black-box libraries — composing visible primitives is more reliable than threading props.
- **TanStack Query** for server state. **Zustand** for the small slice of true client state. Avoid Redux unless project already has it.
- **pnpm workspaces monorepo** with a shared `packages/contracts` (Zod schemas) consumed by both server and client. End-to-end type safety without tRPC's weight. (This package *is* the Layer 0 reusable contract library made executable.)
- **Vitest** for unit/integration tests. **Playwright** for E2E.

### Where Claude is less reliable (even in TS)

- Complex Redux reducer logic spanning many slices
- WebSocket state machines with reconnection edge cases
- Non-boilerplate build tool configuration (custom Vite/webpack plugins)
- ORM-heavy queries with deep relation traversal (Prisma especially)
- Codebases with strong implicit conventions Claude is expected to infer from a couple of files

**Note on mitigation:** several of these are softened by contract discipline. "All DB access goes through a typed repository layer" neutralizes much of the ORM-traversal risk; explicit conventions written into `contracts/` remove the "infer from a couple of files" failure mode. A stack's *effective* reliability is partly a function of how well your contracts constrain it.

---

## Other Languages

### Go — top non-TS pick, strong tier

Best for: high-throughput services, CLIs, infrastructure tools, single-binary deployments, fast-startup workloads.

- Small language, explicit error handling, excellent standard library, `gofmt` removes style debates.
- Less hidden behavior than almost any modern language.

Weaker zones: non-trivial generics, reflection-heavy code, goroutine coordination beyond simple worker pools or fan-out/fan-in.

### Kotlin — strong tier (best JVM pick)

- Type expressiveness comparable to TS, better null safety than Java.
- **Ktor** for backends, or Spring Boot with Kotlin if required.

### Java — workable, looks more confident than it is

- Modern Java (21, records, sealed classes, pattern matching) — okay.
- Spring Boot annotation magic, classpath conventions, Gradle beyond boilerplate, AOP-heavy enterprise patterns — Claude misses conventions an experienced Spring dev would catch.

### Python — strong for data/scripts/ML, riskier for large untyped backends

- With strict `mypy`/`pyright` + Pydantic, reliability approaches TS.
- Without types: same silent-mistake problem as plain JS.
- FastAPI — strong. Django — workable, sometimes misses convention details.

### Rust — narrow zone of confidence, high effort

- Simple Rust (CLIs, parsers, single-threaded logic, basic axum web) — good.
- Async Rust with lifetimes, `Pin`/`Unpin`, complex trait bounds, unsafe — much higher iteration cost.
- Cost-per-feature is higher than Go for most backend work.

### Elixir — surprisingly comfortable

- Pattern matching and immutability align with Claude's structuring of logic.
- Phoenix, LiveView pleasant. Main risk is ecosystem maturity for specific niches.

### C# / .NET — decent

- Profile similar to Java. Modern C# pleasant. Slower than Go or Kotlin.

### Avoid for production unless necessary

- **C / C++** — memory safety risks where Claude isn't confident
- **Scala** — advanced type-level code is high-risk
- **PHP / Laravel** — rusty on modern idioms
- **Ruby / Rails** — Claude misses Rails conventions more than it should

---

## Practical Selection Guidance

### Main application backend + frontend

Stay on TypeScript. End-to-end type sharing is too valuable, and TS is in Claude's strongest tier.

### Cases for reaching off TypeScript inside the same system

- **High-throughput ingestion / sidecar / agent** → Go
- **Ops CLI tool** → Go
- **Infrastructure (Kubernetes controller, custom proxy, etc.)** → Go
- **ML / analytics work** → Python with strict types

### Cases where another language might be a better default

- JVM mandate from organization → Kotlin (not Java)
- Memory-constrained / latency-critical service → Go
- Massively concurrent stateful service with supervision trees → Elixir

---

## Verification Note

This is partly self-report, and self-report is the weakest evidence here. Claude cannot fully separate "what it's actually best at" from "what it prefers in the abstract," and can dress an abstract preference up as a reliability finding. **Treat the tool-level calls (Drizzle-vs-Prisma, Hono-vs-Express) as priors, not measurements. Trust the principle-level claims (strict typing, Zod boundaries, SQL-first, shared contracts) more — they align with general engineering wisdom.**

The cleanest empirical signal is which features in a real project need the fewest correction rounds — that is far better data than this document. Before locking a tool whose choice diverges from a stack you already run, check it against your own correction-round history first. A deliberate greenfield rebuild is the ideal moment to gather that measurement.
