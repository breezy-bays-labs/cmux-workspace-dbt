# Architecture Decision — Sketch A wins (Daemonless Library-First), with seven named grafts from Sketch B

> Task #33 architecture judgment. Inputs: `arch-sketch-a.md`, `arch-sketch-b.md`,
> `base-vision-synthesis.md`, `cide-current-state.md`, the locked
> `.claude/architecture-direction.md`, and the live `.cmux/` composition probe.
> Judge criteria (fixed by the brief): lightweightness, hexagonal integrity +
> trait swapability, cmux composition fit, live/agent-native feature delivery,
> testability, crash/restart behavior, incremental migration, Linux path.
> 2026-06-09.

---

## Verdict

**Winner: Sketch A — Library-First Single Binary (Daemonless).** Not a hybrid.

A hybrid was seriously considered and rejected on a definitional ground: the only
B mechanism worth importing wholesale — the supervisor's reactor internals — is
*already present in A* as the `cide reactor` escape hatch (A §1.B + §13), deployed
as a cmux-supervised dock control rather than a UDS-serving background process.
Declaring "A's core + B's supervisor-as-dock-reactor" a named hybrid would rebrand
Sketch A, not improve it. What B genuinely adds beyond A's own escape hatch is a
set of *specific, separable mechanisms* — crash-replay property testing, runner-first
migration ordering, the frozen JSON-contract crate, reconciliation discipline,
provenance-printing doctor, refuse-unmigrated-state, replay-server conformance —
and those are taken as grafts (§4), not as a center.

The shared 80% (hexagonal `cide-core` with zero I/O, the cmux quirk vault as the
single home for every §4 hard-won fact, verticals-as-recipes data, capability-token
layouts, four-layer config compiling down to repo-local `.cmux/*`, generated-never-
hand-authored fixtures, the 113-assertion POSIX golden master as strangler permit,
egress labels + `cargo-deny` network ban) is identical in both sketches and is
hereby confirmed as settled. The decision below is entirely about the residency
question and its second-order effects.

---

## 1. Scorecard

| Criterion | A | B | Margin notes |
|---|---|---|---|
| Lightweightness (startup, deps, operational burden) | **9** | 6 | A: no tokio, no UDS protocol, no lifecycle subsystem. B: two extra crates + a lifecycle state machine + *both* paths maintained forever |
| Hexagonal integrity + trait swapability | **9** | 8 | Both clean; A's capability-split sync traits beat B's one fat AFIT trait on ISP, object safety, fake ergonomics |
| cmux composition fit (palette/dock/feed/hooks) | **9** | 6 | A's thesis *is* composition; B moves the runner out of cmux's process model into an invisible process |
| Live/agent-native feature delivery | 7.5 | **9** | B's only won criterion — narrowed to near-zero by A's hooks+catch-up coverage and the reactor gate |
| Testability | **9** | 7 | A: one latency story, sync code, pure planners. B: async traits, IPC protocol, lifecycle states, dual-path CI benches |
| Crash/restart behavior | **9** | 7.5 | A is boring *by construction*; B is safe by design-and-test, and adds failure modes A simply doesn't have |
| Incremental migration from shell dogfood | **8.5** | 8 | Same strangler mechanics; A's ported verbs keep the shell's process model, so parity is mechanical; B's M2 ordering insight is grafted |
| Linux path | 8 | 8 | Effectively identical: core compiles today, Noop placement, no mux adapter until tmux/zellij exists |

A wins six of eight, ties one, and loses one — the one it loses, it loses narrowly
and recoverably. Detail per criterion follows.

---

## 2. Criterion-by-criterion analysis

### 2.1 Lightweightness — decisive for A

This is a hard product constraint (solo founder maintains this) and the widest gap.

- **Dependency surface.** A: `clap, serde, serde_json, toml, thiserror, jiff, objc2`
  (macOS-only). B adds `tokio` (via watchexec-as-library), `tracing`, `notify`,
  `watchexec`, `trait_variant`, plus two extra workspace crates (`cide-proto`,
  `cide-supervisor`). B's "the CLI path never initializes tokio" is honest, but the
  binary still links and compiles it, and the supervisor's async surface is code the
  founder reads, upgrades, and debugs.
- **Operational subsystem count.** B's supervisor is not one feature; it is a
  subsystem: lazy single-flight spawn under flock, handshake-based stale-socket
  detection, semver+git-hash version negotiation with drain-and-respawn after
  `brew upgrade`, idle-exit accounting, rotated supervisor logs, and four new
  user-facing commands (`supervisor status|stop|restart|logs`) that exist purely to
  manage the architecture rather than the product. Every one of B's R1 mitigations
  is real code with real bugs. A has none of this because there is nothing to manage.
- **The double-path tax.** B's own scope-creep firewall (§1.2: "every cide verb has
  a supervisor-less path... the cold path is benchmarked in CI") means **B must
  build, test, and CI-maintain the entirety of Sketch A anyway**, then build the
  supervisor on top. B = A + supervisor, permanently. The question is therefore not
  "which architecture?" but "is the supervisor's *marginal* feature set worth a
  second permanently-maintained subsystem **now**?" §2.4 answers no.
- Startup budgets are nominally equal (<10 ms, CI-enforced in both), but A's budget
  is structurally protected (no runtime to creep in; cargo-deny allowlist), while
  B's depends on the tokio-free thin-client discipline holding forever.

### 2.2 Hexagonal integrity + trait swapability — both strong, A cleaner

Both sketches put every quirk in the adapter, make blind injection unrepresentable
(`InjectionGuard`), type best-effort outcomes (`CloseOutcome`, `PlacementOutcome`),
and demonstrate the one-line editor swap. Three differentiators favor A:

1. **Interface segregation.** A splits the mux port into six narrow capability
   traits (`MuxTopology`, `MuxWorkspaces`, `MuxSurfaces`, `MuxAttention`,
   `MuxEvents`, `MuxViewers`) under an umbrella supertrait; tool adapters receive
   *narrowed handles* (`&dyn MuxSurfaces`), so an Editor adapter physically cannot
   close workspaces. B has one ~25-method async `Multiplexer`. Narrow traits mean
   smaller fakes, smaller conformance suites, and visible blast radius per use-case.
2. **Sync vs AFIT.** A's everything-is-request/response-over-a-unix-socket reality
   makes blocking I/O correct and simple: object-safe `dyn` traits, no
   `trait_variant::make(Send)` machinery, no `block_on` shim on the cold path. B
   pays async-trait complexity across every port to serve one consumer (the
   supervisor's event pump).
3. **Functional core sharpness.** A's `plan_*` (pure, `topology → op-plan`) /
   `execute` split makes the hexagon's edge a value you can print (`--dry`), record
   (FakeMux op log), and golden-master. B's use-cases run "in whichever process
   runs them" — two execution contexts (CLI cold path, supervisor warm path) for
   the same use-case is a genuine, if manageable, integrity hazard.

B's one structural win here — `cide-proto` as a frozen, tiny, stable contract crate
for `--json` output — is graft g4.

### 2.3 cmux composition fit — decisive for A

The brief asks: does the design exploit palette/dock/feed/hooks *naturally*?

- **A's thesis is the criterion.** "The multiplexer IS the supervisor": verbs become
  palette actions because `cide sync` compiles them into repo-local `.cmux/cmux.json`;
  residency happens as foreground processes in panes and dock controls that cmux
  supervises, respawns (`respawn-pane`), themes, displays, and resource-accounts
  (`cmux top` attributes them to the space); the policy engine is a stdin→stdout
  hook filter — the canonical short-lived program the `notifications.hooks` pipeline
  was designed for; the statusline reads hook-maintained cache files with zero
  socket calls. Every cmux composition surface is load-bearing.
- **B regresses the runner.** B embeds watchexec as a library inside the supervisor
  and demotes the Dock's runner control to `cide run attach`, "a thin log/status
  tail over the UDS." That removes the actual work from cmux's process model: no
  `cmux top` attribution, no die-with-workspace lifecycle, no respawn-pane, no
  visible process. The live `.cmux/dock.json` probe shows the dock *already* running
  watchexec as a visible control — the dogfood's own direction of travel is A's.
- **B's consolidation premise is wrong on the facts.** B argues the dogfood "already
  runs N resident loops... with three lifecycles to babysit," so one supervisor is
  consolidation, not addition. But those dock loops are **cmux-supervised** —
  visible, restartable, space-scoped, killed with their workspace. Consolidating
  them into one invisible background process trades cmux's supervision (which
  exists and works) for hand-written supervision (which must be built), and weakens
  the trust posture: the zero-egress story is strongest when `cide doctor` can say
  "everything cide runs is this binary in a pane you can see." A consolidates the
  loops' *logic* into one binary while keeping cmux as the supervisor — the correct
  half of B's consolidation argument, without the regression.

### 2.4 Live/agent-native feature delivery — B's win, narrow and recoverable

B's strongest ground, and the honest accounting matters. Feature by feature
against the synthesis's bets:

| Vision capability | A | B | Verdict |
|---|---|---|---|
| Review queue (bet 2) | `Stop` hook → `turn-complete`; durable `events.jsonl` catch-up backstops uninstalled-hook gaps | Supervisor subscription | **Tie.** The synthesis itself: "v1 ships on declarative notification hooks alone — never blocked on the daemon." |
| Fix-on-red (bet 8) | Parser lives *inside* `cide run wrap`, the cmux-supervised foreground process that owns the runner | Parser inside supervisor | **Tie or A** — A's parser is exactly as resident, but visible and space-scoped |
| Notification policy (P3) | Stateless hook filter | Same — B concedes "does not need the supervisor" | **Tie** by B's own table |
| Fleet segment (P3) | Hook-maintained `cache/fleet.json`; staleness = "since last hook," seconds for an active fleet | File watcher, fresher | **B**, marginally |
| Space GC / role auto-tag on `workspace.closed` | No hook fires on Cmd+W → stale until next verb; tree-is-truth verbs make staleness invisible; lazy GC at verb entry | Live subscription | **B** on latency, **A** on "does it matter" — no user-visible behavior depends on sub-second GC |
| Debounce/correlation windows | Timestamped ring files — clunky, workable | In-memory | **B**, marginally |
| Sub-second space-switch SLO (P6a) | Process spawn (<10 ms, CI-tested) + one socket `tree` RPC (µs–low-ms measured) | Warm UDS + event-invalidated cache | **Tie in practice** — the warm cache saves one tree round-trip, single-digit ms; both budgets are CI-tested |
| Hibernation budgets / `cide top` (bet 9) | cmux-side settings + reactor when promoted | Resident accounting | **B**, deferred-recoverable |

Net: B wins this criterion by the breadth of *continuous* coverage, but every
delta is either (a) below user-perceptible thresholds given tree-is-truth verbs,
(b) covered by the durable-log backstop, or (c) recoverable through A's pre-built
escape hatch. The deciding fact: **A's `cide reactor` is B's supervisor minus the
parts that exist only to serve B's weakest justification.** B's supervisor has
three jobs — (1) event reactions, (2) job hosting, (3) warm-cache/UDS verb serving.
A shows (2) belongs in cmux panes (§2.3), (3) is unnecessary at measured latencies
(verbs read reactor-maintained cache files instead — the statusline pattern), and
(1) becomes a cmux-supervised dock-control loop *when dogfooding proves the need*.
The UDS server, proto handshake, lazy-spawn flock, and idle-exit machinery exist
to serve (3). A's promotion gate is explicit and kept: **if two shipped loops
independently need reactor-mode reactions, the reactor is promoted to a default-on
dock control** — still never launchd, still visible, same ports, same state files,
same tests.

One implementation note carried out of this analysis: A's R4 mention of
"watchexec crate in-process where possible" would smuggle tokio into the binary.
Resolved against it: `cide run wrap` wraps the external `watchexec` binary (already
a dogfood dependency, already in the dock today); if an in-process watcher is ever
wanted, use the sync-capable `notify` crate inside the wrap process. The no-tokio
budget holds either way.

### 2.5 Testability — A

Both share the strong tiers (pure-core units, FakeMux conformance, generated
fixtures, POSIX golden master, BDD features, SLO + egress gates). The deltas:

- A's surface is strictly smaller: sync code (no runtime in tests), one latency
  story (one hyperfine target instead of warm+cold matrices), no IPC protocol to
  version-test, no lifecycle state machine (spawn races, handshake skew, drain) to
  cover.
- B contributes the single best test idea in either sketch — the **crash-replay
  convergence property** (random kill-point k, restart from cursor, assert
  end-state convergence with the never-killed run). It is not supervisor-specific:
  it applies directly to A's hook-storm concurrency story (50 parallel
  `policy`/`turn-complete` invocations must converge — A already names this test),
  to `cide run wrap`, and to the reactor when promoted. Graft g1.
- B also contributes the **replay-server conformance tier**: running the *socket
  adapter* through the conformance suite against a recorded replay server gives the
  primary transport CI coverage without a live cmux — cheaper than A's
  live-behind-`--ignored` tier alone. Graft g7.

### 2.6 Crash/restart — A

B's crash story is genuinely well-designed (zero durable supervisor state, cursor
resume, watchman-model reconverge, tested by property). But it is safety
*achieved by design-and-test* against failure modes the architecture itself
introduces — stale sockets, dual-supervisor races, post-upgrade version skew,
zombie jobs (B's own R1, rated M×H). A's crash story is safety *by construction*:
a short-lived verb dies leaving an atomic-rename file old or new; the next verb
re-resolves from the live tree; foreground wrappers die with their pane and cmux
respawns them. There is no wedged-resident-process mode because there is no
resident process. When the reactor is promoted, it inherits B's discipline via
grafts g1 and g3 — including the one failure mode A's panes do share with B's
supervisor: a long-lived `run wrap` pane running a stale binary after
`brew upgrade`. B's version-handshake idea is adapted for it (g3).

### 2.7 Incremental migration — A, with B's ordering graft

Mechanically near-identical: exec shims in `bin/cide-*`, golden-master parity as
the permit, one-shot state migration, instant rollback. Three deltas:

- A's ported verbs keep the shell's process model (one-shot invocations), so every
  golden-master comparison is like-for-like; B's M-phases introduce the supervisor
  at M1, before the crown jewels port, putting the riskiest new subsystem inside
  the migration window.
- A's R1 ("parser killers first") front-loads value: the three worst hand-rolled
  parser sites and both live `~/.config`/tracked-file hygiene violations (pains
  #9/#10) die in the first mutating slice.
- B's one superior ordering insight: ship the **runner before the space port**
  (B's M2). The runner is new capability — zero parity burden — it immediately
  retires the dock's raw watchexec line and the `just --list` stub (#23), and it
  load-hardens the socket adapter + pipe-pane + state-write paths before R3 bets
  the crown jewels on them. Graft g2 reorders A's plan accordingly:
  R2 becomes "guarded writes + `cide run`/`run wrap`"; R4 keeps review/policy/sync.
- B's "Rust refuses to run against unmigrated state rather than guessing" (the
  `cwd state-migrate` collision-refusing discipline, made explicit) is graft g6.

### 2.8 Linux path — tie

Identical posture: `cide-core` compiles on Linux today; placement is a port
(`NoopPlacement`/future wlr); the mux port keeps the tmux/zellij door open with
honest `CapabilitySet` gaps; no Linux promise in v1 (settled non-goal). A builds
`aarch64-unknown-linux-musl` in CI from day one as cheap insurance; B states the
target compiles. No tokio makes A's musl static story marginally simpler; not
score-moving.

---

## 3. Where B fails on its own terms (the summary argument)

1. Its scope firewall obligates building all of A anyway — the supervisor is a
   permanent *addition*, never a substitution.
2. Its consolidation premise mischaracterizes the dock loops as unsupervised; they
   are cmux-supervised, and B's design moves work *out* of that supervision.
3. Its strongest residency client (the runner) is better served by A's
   residency-by-proxy, which B's own UX concedes by keeping the Dock control as a
   facade over the relocated work.
4. Its remaining exclusive features (warm cache, unhooked-event reactions,
   in-memory debounce, continuous accounting) are each below the threshold that
   justifies a lifecycle subsystem **today**, and all are recoverable through A's
   reactor gate **later** without architectural change.
5. The synthesis's bet 3 asked for a daemon's *outcomes* (death of settle-polling,
   event-driven reactions). A delivers the outcomes via hooks + `wait_for` +
   durable-log catch-up and declines only the mechanism — with the mechanism
   pre-designed, gated, and cmux-supervised if dogfooding ever demands it.

## 3.1 What A pays (the honest ledger, accepted)

- No sub-second reactions to events without hook coverage (Cmd+W workspace close
  → stale space membership until the next verb). Accepted: tree-is-truth verbs
  make this invisible; no shipped behavior depends on it.
- Debounce/correlation via ring files instead of memory. Accepted as clunky-but-
  workable; revisit at the reactor gate.
- File-lock discipline (flock + atomic rename + idempotent ops keyed by event seq)
  instead of in-process serialization, under hook storms. Accepted; enforced by
  the g1 convergence property test in CI.
- A standing bet against synthesis bet 3's mechanism. Accepted; hedged by the
  explicit promotion gate (two shipped loops independently requiring residency →
  reactor becomes a default-on dock control).

---

## 4. Grafts from Sketch B (binding; each is a named work item)

- **g1 — Crash-replay convergence property tests** (B §8 tier 5). For a random
  kill point k in a recorded event/invocation stream, restart and assert end-state
  convergence with the never-killed run. Applied to: 50-parallel hook-storm
  invocations (`cide policy` × `turn-complete`), `cide run wrap`, and the reactor
  when promoted. CI property, not a one-off.
- **g2 — Runner-first migration ordering** (B's M2 rationale). Pull `cide run` +
  `cide run wrap` ahead of the space port (into A's R2): zero golden-master parity
  burden, immediate dogfood value (retires the dock's raw watchexec + `just --list`
  stub), and load-hardens the socket adapter before R3.
- **g3 — Reactor lifecycle spec, pre-written from B §2**. When the promotion gate
  trips, the reactor adopts: level-triggered reconciliation ("events are hints,
  snapshots are truth"), gap-in-the-type subscriptions (A's `CatchUpError` already
  matches B's `StreamGap` — keep it mandatory), desired-state reconstruction from
  files on every start, and a **binary-version self-check** (exit-for-respawn when
  the on-disk binary's version differs post-`brew upgrade` — applied to long-lived
  `run wrap` panes *today*, not just the future reactor). Deployment remains a cmux
  dock control: no UDS server, no launchd, verbs keep reading state files.
- **g4 — Frozen JSON-contract crate** (B's `cide-proto`, repurposed). A tiny
  `cide-json` crate holding the `--json` output structs as the versioned,
  machine-first public contract (bet 12), decoupled from internal domain types so
  core refactors can't silently break agent consumers.
- **g5 — Config-layer provenance in doctor** (B §7.2). `cide doctor` prints which
  of the four layers each effective config key came from.
- **g6 — Refuse-unmigrated-state discipline** (B M3). Ported Rust verbs refuse to
  run against unmigrated shell state (collision-refusing, two-phase, the
  `cwd state-migrate` precedent) — never guess, never co-write.
- **g7 — Replay-server conformance tier for the socket adapter** (B §8 tier 2).
  Run the same conformance assertions against `CmuxSocketAdapter` over a recorded
  replay server in CI, so the primary transport is covered without a live cmux;
  the live `--ignored` tier remains for fidelity generation.

Also adopted as a one-line resolution (§2.4): the runner engine wraps the external
`watchexec` binary (or a sync `notify`-based watcher) inside `cide run wrap` —
never watchexec-as-library — preserving the no-tokio dependency budget.

---

## 5. Consequences

- The crate plan is A §2 (core / mux-cmux / adapters / place-macos / testkit /
  bin) **plus** the `cide-json` contract crate (g4). `cide-supervisor` and a UDS
  protocol are explicitly not built.
- The migration plan is A §12 with g2's reorder (runner into R2) and g6's refusal
  discipline at the R1 state migration.
- The testing plan is A §10 plus g1 (convergence properties) and g7 (replay-server
  socket conformance).
- The reactor remains an escape hatch with a written promotion gate and a
  pre-agreed lifecycle spec (g3); revisiting "should cide have a daemon?" before
  that gate trips should start by re-reading this document, not by reopening the
  question.

*Decision: Sketch A, grafts g1–g7. Judge: architecture-judge subagent, 2026-06-09.*
