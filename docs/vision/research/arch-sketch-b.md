# Architecture Sketch B — Core + Session Supervisor

> Research artifact for task #33 (cide Rust tool vision). Sketch B of the architecture
> panel. Design philosophy: **the same hexagonal core crate as any sketch, plus a small
> per-cmux-instance supervisor process the CLI talks to over a unix socket.** CLI verbs
> are thin clients; the cmux palette/dock call the same verbs; the supervisor owns
> everything that must *stay alive*: the cmux events subscription, runner jobs
> (watchexec embedded as a library), agent-checkpoint watching, placement
> reconciliation, notification routing.
> Grounded in: `base-vision-synthesis.md`, `cmux-api-surface.md`, `cide-current-state.md`,
> and the locked decisions in `.claude/architecture-direction.md` (crate names, strangler
> fig, golden-master conformance). 2026-06-09.

---

## 1. The argument: why the event-driven half of the vision *requires* a resident process

Strip the vision to its differentiators and count which ones are **reactions**:

| Vision capability (synthesis §4/§5) | Trigger | Required residency |
|---|---|---|
| Agent-turn review queue (`cide review`, bet 2) | `agent.hook.Stop` event → queue turn, open `diff --source last-turn` beside the pane, maintain **review cursors** per agent | Cross-event state (what's been reviewed) + live subscription |
| Fix-on-red diagnostics routing (bet 8) | Runner job goes red → parse → structured `Diagnostics` → `workspace.prompt_submit` to `agent:builder` | Someone must *own the runner process* and hold its parse state |
| Focus-aware notification policy (P3) | Every notification, decided against `appFocused`/`focusedPanel` context | Stateless per-event — **does not need the supervisor** (see §1.2) |
| Space GC / role auto-tagging | `workspace.closed`, `surface.created` | Live subscription + registry reconciliation |
| Fleet segment in prompt (`agents: 2▶ 1✋ 1💤`) | Agent lifecycle changes in `~/.cmuxterm/*-hook-sessions.json` | File watcher + cached aggregate (a poll here burns the latency SLO) |
| Placement reconciliation (`[monitors]` post-pass; ghost-window cleanup) | `window.created`, space open, monitor topology change | Periodic + event-triggered reconciler |
| Sub-second space-switch SLO (P6a) | Every interactive verb | Warm socket connection + event-invalidated topology cache |
| Hibernation budgets / `cide top` aggregation (bet 9) | Continuous | Resident accounting |

The synthesis names the alternative and kills it by name: *"an event-driven reactor
instead of settle-polling"* and *"the death of settle-polling"* (bet 3). The dogfood
already documents what polling costs: `hq-preview` runs **three nested read-screen
poll loops** just to pace one TUI boot (cide-current-state §6.7). Scale that pattern to
review cursors, agent lifecycle, runner state, and placement, and every CLI invocation
becomes a tour of snapshots — latency paid at the *interactive* moment, which is
exactly where P6 says it may not be paid.

There are only three ways to get reactions; cide needs all the state-bearing ones in
one place:

1. **Per-event spawn (cmux `notifications.hooks` pipeline)** — cmux pipes a policy JSON
   through a shell command per notification. Perfect for *stateless* policy. Cannot
   hold review cursors, cannot debounce, cannot own a watchexec task, and only covers
   the notification slice of the event catalog (no `agent.hook.*`, no `workspace.closed`).
2. **N resident loops** — this is the dogfood *today*: the Dock already runs watchexec,
   `cmux feed tui`, and git-glance as three independent resident processes with no
   shared state, no coordination, and three lifecycles to babysit. Adding review
   cursors and checkpoint watching this way means five-plus loops.
3. **One supervisor** — a single process that holds the one events subscription
   (cursor-file resumable), hosts runner jobs as in-process watchexec tasks, watches
   the agent session stores, and exposes the same verb surface to the CLI over a UDS.

The supervisor is therefore **not added daemon complexity — it is daemon
consolidation**. The dogfood already runs resident processes; sketch B replaces N
unsupervised loops with one supervised, crash-safe, version-handshaked process that
the CLI spawns and the user never thinks about.

### 1.1 The latency dividend (why the SLOs want it too)

A warm supervisor holds: an open cmux socket connection, a topology cache invalidated
by events (not TTL), the parsed registry/space state, and the agent-lifecycle
aggregate. A CLI verb then costs: UDS connect (~100 µs) + one request/response against
warm state. Cold path (no supervisor running) still works — the verb opens its own
cmux socket connection and takes a fresh snapshot — it is just slower. The SLO story
becomes: *interactive verbs hit the warm path; the cold path is correct but not
budgeted.* CI benches both.

### 1.2 The declarative-first boundary (what the supervisor must NOT own)

The synthesis is explicit (bet 2): *"v1 ships on declarative notification hooks alone —
never blocked on the daemon."* Sketch B adopts that as a **standing rule**:

> **Every cide verb has a supervisor-less path. The supervisor adds reactions, jobs,
> and warmth; it never gates a verb.** Stateless policy stays in the declarative layer
> (`cide hook notify` invoked by cmux's `notifications.hooks` pipeline — same binary,
> no daemon needed). The supervisor owns only what is *stateful across events* or
> *long-running*.

This rule is the scope-creep firewall (risk R4) and the reason daemon-management hell
cannot take the product hostage: if the supervisor is down, cide degrades to exactly
the architecture of sketch A (one-shot CLI), not to a brick.

---

## 2. Process model: lightweight, crash-safe, no daemon hell

### 2.1 Shape

```
┌─────────────────────────────────────────────────────────────────┐
│  cide (ONE binary, brew-installed)                              │
│                                                                 │
│  cide <verb> …            cide supervisor run   cide hook notify│
│  (thin client)            (hidden subcommand)   (stateless,     │
│       │                          │               per-event)     │
└───────┼──────────────────────────┼──────────────────────────────┘
        │ UDS (newline-JSON,       │
        │ version handshake)       │ one persistent cmux socket conn
        ▼                          ▼
~/.local/state/cide/sup-<hash>.sock      ~/.local/state/cmux/cmux.sock
                                   │  events.stream (cursor-file resume)
                                   │  rpc verbs (tree, set-status, diff…)
```

- **One distributable binary.** The supervisor is `cide supervisor run` — a hidden
  subcommand of the same binary brew installs. No second artifact, no plist shipped.
- **One supervisor per cmux instance**, not per IDE instance: the socket name embeds a
  hash of `CMUX_SOCKET_PATH`, so a second cmux app (rare) gets a second supervisor.
  Per-space/per-instance state is multiplexed inside it (jobs are keyed by space).
  Rationale: the events stream and the topology are per-cmux-app; one subscription,
  fan-out inside.
- **Lazy auto-spawn.** Any verb that benefits from the warm path checks socket
  liveness; if dead, it spawns `cide supervisor run` detached (setsid, stdout →
  rotated log under `~/.local/state/cide/`), guarded by an `flock` so concurrent verbs
  single-flight the spawn. The user never runs the daemon by hand.
- **Version handshake, self-upgrading.** First frame on every connection carries
  semver + git hash. On mismatch (post-`brew upgrade`), the client asks the old
  supervisor to drain (stop jobs gracefully, flush cursor) and exit, then respawns the
  new binary. Stale-socket detection is handshake-based, never pid-based (pid reuse).
- **Idle exit.** Zero running jobs + zero open spaces + N minutes quiet → the
  supervisor flushes its cursor file and exits. Next verb respawns it and it resumes
  from the cursor. A daemon that isn't there most of the time generates no hell.
- **launchd is opt-in only.** Default lifecycle is lazy-spawn/idle-exit. For users who
  want always-on reactions, `cide setup --launchd` is an explicit, consented,
  reversible step (it writes `~/Library/LaunchAgents/`, which is disclosed in the
  consent prompt — consistent with the settled "one explicit consented `cide setup`"
  posture; it is not a `~/.config` write, and it never happens silently).
- **Observability is a product surface.** `cide doctor` prints supervisor
  pid/version/uptime/cursor-lag/jobs; `cide supervisor status|stop|restart|logs` exist
  from day one; supervisor health is also pushed as a sidebar status pill
  (`set-status cide …`) so the IDE itself shows it.

### 2.2 Crash-safety: state files as the only truth

The supervisor holds **zero durable state of its own** except the events cursor file.
Everything else is derived:

| State | Durable owner | Supervisor's copy |
|---|---|---|
| Spaces, registry, instances, agent slots | `~/.local/state/cide/` files (atomic temp+rename, written by the **core use-cases**, whichever process runs them) | In-memory cache, invalidated by file-watch + events |
| Desired runner jobs | `jobs.json` per space (written by `cide run start`) | Live watchexec tasks, **reconstructed from desired state on every start** |
| Review cursors | `review-cursors.json` (append/compact) | Cache |
| cmux topology | cmux itself (snapshot verbs) | Event-invalidated cache; on `ack.resume.gap` or slow-consumer drop → full snapshot refresh |
| Event position | `events.cursor` file | — |

`kill -9` the supervisor at any moment: nothing is lost. cmux's event bus is built for
exactly this — `--after <seq>`, `--cursor-file`, a 4096-event replay buffer, and a
durable `~/.cmuxterm/events.jsonl` mirror (cmux-api-surface §4). On restart the
supervisor: reads state files → resubscribes from cursor → replays missed events →
takes one reconciling snapshot → restarts desired jobs. This is the **watchman model**
(client-spawned, derived-state, crash-respawn-converge), and it is a *tested property*,
not a hope — see §8 (crash-replay property tests).

Reconciliation discipline: **level-triggered with edge-triggered acceleration.** Events
are hints; snapshots (`tree --all`, `extension.sidebar.snapshot`) are truth. Any doubt
→ re-snapshot. This single rule absorbs the entire class of "missed event" bugs.

### 2.3 IPC

Newline-delimited JSON over the UDS; requests/responses use the **same serde structs as
the CLI's `--json` output** (machine-first verb surface, bet 12, for free — the
supervisor protocol *is* the public JSON contract, shared via `cide-proto`). Palette
actions and Dock controls invoke `cide <verb>`, which transparently rides the warm
path — human, agent, palette, and dock all drive one verb registry (P5).

---

## 3. Crate layout

Extends the locked layout (architecture-direction.md, 2026-06-04: `cide-core`,
`cide-adapters`, `cide-dbt`, `cide`) with two crates the supervisor needs. All arrows
point inward; the bin crate is the only composition root.

```
cmux-ide/  (Cargo workspace; [workspace.package] unified version)
├── crates/
│   ├── cide-core/         # domain + ports (traits) + use-cases. Deps: serde, thiserror. NO io, NO tokio.
│   │   ├── domain/        #   ids, space, instance, layout, role, runner, agent, theme, egress
│   │   ├── ports/         #   Multiplexer, Editor, Explorer, Vcs, RunnerEngine, TaskCatalog,
│   │   │                  #   Agent, Theme, Placement, Warehouse, EventBus, Clock, StateStore
│   │   └── usecases/      #   space_open, space_close, review_next, fix_on_red, focus_subject…
│   ├── cide-proto/        # serde types for CLI⇄supervisor IPC + --json output. Deps: serde. Tiny, stable.
│   ├── cide-adapters/     # one MODULE per tool (per-adapter crates deferred per the locked trigger)
│   │   ├── cmux/          #   socket-v2 adapter (primary) + cli adapter (fallback/debug) — ALL quirks live here
│   │   ├── helix/  yazi/  lazygit/  gh/  watchexec/  bacon/  claude/  theme/
│   │   ├── place_macos/   #   cfg(target_os="macos"): objc2 + CoreGraphics/AX, AeroSpace-aware
│   │   └── place_noop/    #   Linux / headless / --dry
│   ├── cide-dbt/          # dbt vertical ADAPTERS only (Warehouse=harlequin/duckdb, DbtReview=cute-dbt,
│   │                      # dbt task-catalog, compiled-SQL diagnostics). The dbt RECIPE itself is data (§7).
│   ├── cide-supervisor/   # reactor: event pump, reconciler, job host, checkpoint watcher,
│   │                      # notification router, UDS server. Deps: core, adapters, proto, tokio, watchexec.
│   └── cide-testkit/      # FakeMultiplexer + fakes for every port, conformance suite macros,
│                          # fixture loader, event-stream replayer, golden-master harness
├── src/ (cide bin)        # clap CLI (thin client + cold path) + `supervisor run` + `hook notify`
│                          # + composition root. The ONLY crate depending on everything.
├── recipes/               # base.toml, dbt.toml, rust.toml — verticals as DATA, embedded via include_str!
├── fixtures/              # GENERATED golden fixtures per cmux version (never hand-authored — G1)
└── tests/                 # BDD features + golden-master replay + crash-replay properties
```

Dependency diet (lightweight is a hard requirement): `clap`, `serde`/`serde_json`,
`toml`, `thiserror`/`anyhow`, `tracing`, `notify`, `watchexec` (+ its tokio), and std
`UnixStream`. **The CLI path never initializes tokio** — thin-client verbs are
blocking I/O over the UDS; only `supervisor run` boots a runtime. Cold-start budget
for `cide <verb> --help`: <10 ms, enforced in CI (§8). `cargo-deny` bans network
crates (`reqwest`, `hyper` client, `openssl`) — **zero-egress enforced at the
dependency graph**, not just by policy.

---

## 4. Core domain model

```rust
// ── identity (fixes dogfood pain #5: one identity type, refs never persisted) ──
pub struct WorkspaceUuid(Uuid);   // normalized casing at the adapter boundary
pub struct WindowUuid(Uuid);
pub struct SurfaceUuid(Uuid);
pub enum HostRef { Uuid(Uuid), Positional { kind: RefKind, index: u32 } }
// Positional refs are accepted at the CLI edge and resolved to UUIDs immediately;
// only UUIDs are stored; a tag check defends against UUID-slot reuse.

// ── verticals as data ──
pub struct IdeType {                       // deserialized from recipes/<name>.toml
    pub name: String,                      // "base" | "dbt" | "rust" | user-defined
    pub extends: Option<String>,           // composition, not inheritance: dbt = base ⊕ overrides
    pub bindings: PortBindings,            // port → adapter name (warehouse="harlequin", editor="helix")
    pub layout: LayoutPreset,
    pub identity: VisualIdentity,          // workspace-group color/icon (dbt=orange, rust=red)
    pub runner: RunnerRecipe,              // catalogs to detect, on_red routing, diagnostics kind
    pub routing: Vec<RouteRule>,           // "*.sql" → editor+compiled_preview
    pub palette: Vec<PaletteAction>,       // projected into .cmux/cmux.json by `cide setup --repo`
    pub dock: Vec<DockControl>,
}

// ── instances & spaces ──
pub struct Instance {                      // named coupling of N workspaces across windows/monitors
    pub name: String, pub ide_type: String, pub repo_root: PathBuf,
    pub members: Vec<RoleBinding>,
}
pub struct Space {                         // lifecycle-managed instantiation; P1's unit of work
    pub id: SpaceId, pub name: String, pub instance: String,
    pub worktree: Option<PathBuf>,
    pub status: SpaceStatus,               // Active | Closed { closed_at }
    pub members: Vec<RoleBinding>,
    pub agents: Vec<AgentSlot>,            // N role slots (builder, reviewer, …)
    pub jobs: Vec<JobSpec>,                // desired runner jobs (durable)
}
pub struct RoleBinding { pub role: Role, pub workspace: WorkspaceUuid,
                         pub window: WindowUuid, pub orientation: Orientation }
pub enum Role { Editor, Tools, Custom(String) }          // window-grained
pub enum SurfaceRole { Agent(AgentRoleLabel), Runner, Viewer, Shell, Warehouse } // surface-grained

// ── layout as data (cmux layout JSON + the one thing it can't express: multi-window) ──
pub struct LayoutPreset { pub name: String, pub windows: Vec<WindowPlan> }
pub struct WindowPlan { pub role: Role, pub orientation: Orientation, pub tree: LayoutNode,
                        pub monitor: Option<MonitorPref> }
pub enum LayoutNode {
    Split { direction: SplitDir, ratio: f32, first: Box<LayoutNode>, second: Box<LayoutNode> },
    Pane  { surfaces: Vec<SurfaceSpec> },
}
pub struct SurfaceSpec { pub kind: SurfaceKind, pub name: String, pub capability: CapabilityToken }
pub enum CapabilityToken {                 // compiled to a concrete command by the bound adapter —
    Editor, Explorer { variant: String },  // the recipe never hardcodes "hx-wrap"; the Editor
    AgentSlot { label: String },           // adapter decides what launching an editor means
    Runner, VcsPorcelain, WarehouseAttach { read_only: bool },
    Viewer { what: ViewerKind }, Browser { url: UrlTemplate }, Shell, Raw { command: String },
}

// ── runner ──
pub struct JobSpec { pub id: JobId, pub space: SpaceId, pub entry: CatalogEntry,
                     pub watch: WatchSpec, pub debounce: Duration }
pub enum JobState { Idle, Running { since: Instant }, Green { last: Instant },
                    Red { diags: Diagnostics } }
pub struct Diagnostics {                   // structured, never pasted ANSI (P4)
    pub kind: DiagKind,                    // BaconLocations | CompiledSql | TestFailures | Raw
    pub locations: Vec<FileLoc>, pub artifacts: Vec<PathBuf>, pub summary: String,
}

// ── agents ──
pub struct AgentSlot { pub label: String /* builder|reviewer|… */, pub agent: AgentKind,
                       pub checkpoint: Option<CheckpointId>,       // durable resume key; cide READS,
                       pub surface: Option<SurfaceUuid>,           // never writes, the binding (settled)
                       pub lifecycle: AgentLifecycle }
pub enum AgentLifecycle { Running, Idle, NeedsInput, Dead }
pub struct ReviewCursor { pub slot: String, pub last_reviewed_turn: TurnId }

// ── trust ──
pub enum EgressLabel { Zero, DefensibleEgress(&'static str), TelemetryDisabledVerified }
pub trait AdapterManifest { fn egress(&self) -> EgressLabel; fn required_tools(&self) -> &[ToolReq]; }
// `cide doctor` aggregates manifests into the printed network surface (the egress contract).
```

---

## 5. Port traits (the key signatures)

Ports live in `cide-core::ports` (extraction to `cide-ports` deferred per the locked
trigger). Async via native AFIT (`async fn` in traits, Rust ≥1.75) with
`trait_variant::make` for `Send` bounds where the supervisor needs them; the CLI cold
path drives them with a tiny `block_on`.

### 5.1 `Multiplexer` — the cmux port (all quirks encapsulated; see §6.1)

```rust
#[trait_variant::make(Send)]
pub trait Multiplexer {
    // identity & topology
    async fn identify(&self) -> Result<IdentityCtx>;          // {caller, focused, socket_path}
    async fn snapshot(&self) -> Result<Topology>;             // ALWAYS global (tree --all), enriched
                                                              // with per-ws cwd; callers never know
                                                              // workspace.list is focused-window-only
    async fn capabilities(&self) -> Result<CapabilitySet>;    // feature-gate against cmux version

    // lifecycle (ghost-window-safe, caller-protected — adapter's job, not caller's)
    async fn create_workspace(&self, spec: &WorkspaceSpec) -> Result<WorkspaceUuid>;
    async fn create_window_with(&self, spec: &WorkspaceSpec) -> Result<(WindowUuid, WorkspaceUuid)>;
    async fn close_workspace(&self, id: WorkspaceUuid) -> Result<CloseOutcome>,
        // CloseOutcome::Closed | ::DeferredSelf { hint } — caller-workspace protection is a
        // TYPED outcome the use-case must match on, not a silent failure
    async fn set_meta(&self, id: WorkspaceUuid, meta: WorkspaceMeta) -> Result<()>; // name/desc-tag/color
    async fn group(&self, op: GroupOp) -> Result<GroupOutcome>;  // workspace.group.* (within-window only —
                                                                 // the type says so: GroupScope::Window)
    // focus & interaction
    async fn focus(&self, target: FocusTarget) -> Result<()>;
    async fn send_text(&self, surface: SurfaceUuid, text: &str, guard: InjectionGuard) -> Result<()>,
        // InjectionGuard::None is not constructible outside the adapter; callers must pass
        // ::PromptIdle (read-screen heuristic) or ::ControlChannel — blind injection is unrepresentable
    async fn read_screen(&self, surface: SurfaceUuid, opts: ReadOpts) -> Result<ScreenText>;
    async fn pipe_pane(&self, surface: SurfaceUuid, sink: PipeSink) -> Result<PipeHandle>;
    async fn respawn(&self, surface: SurfaceUuid, cmd: Option<CommandSpec>) -> Result<()>;

    // IDE surfaces
    async fn open_diff(&self, req: DiffRequest) -> Result<SurfaceUuid>;     // source: Unstaged|Staged|
                                                                            // Branch{base}|LastTurn|Stdin
    async fn open_markdown(&self, req: MdRequest) -> Result<SurfaceUuid>;   // --window plumbed (cross-
                                                                            // window split quirk)
    // status & attention
    async fn notify(&self, n: Notification) -> Result<()>;
    async fn set_status(&self, ws: WorkspaceUuid, pill: StatusPill) -> Result<()>;
    async fn set_progress(&self, ws: WorkspaceUuid, frac: f32, label: &str) -> Result<()>;
    async fn flash(&self, target: FlashTarget) -> Result<()>;

    // resume & vault
    async fn surface_resume_set(&self, surface: SurfaceUuid, b: ResumeBinding) -> Result<()>;
    async fn agent_sessions_raw(&self) -> Result<Vec<RawAgentSession>>;     // store read; Agent port interprets

    // the reactive backbone (supervisor is the only production consumer)
    async fn subscribe(&self, cursor: EventCursor) -> Result<BoxStream<'static, Result<MuxEvent, StreamGap>>>;
        // StreamGap (ack.resume.gap / slow-consumer drop) is IN the type → the reactor
        // cannot forget to re-snapshot
}
```

### 5.2 `RunnerEngine` + `TaskCatalog` (watchexec embedded, not spawned)

```rust
#[trait_variant::make(Send)]
pub trait RunnerEngine {
    async fn start(&self, job: &JobSpec) -> Result<JobId>;
    async fn stop(&self, id: JobId) -> Result<()>;
    async fn state(&self, id: JobId) -> Result<JobState>;
    fn events(&self) -> BoxStream<'static, JobEvent>;   // Started | OutputChunk | Finished{status}
}                                                       // raw chunks → DiagnosticsParser (per recipe)

pub trait TaskCatalog {                                 // sync, cheap, pure-ish
    fn detect(&self, root: &Path) -> Vec<CatalogEntry>; // just/make/npm/cargo/dbt
    fn fast_path(&self, entry: &CatalogEntry) -> Option<FastPath>; // bacon for cargo repos
}
```

`WatchexecEngine` hosts watchexec **as a crate inside the supervisor's runtime** — no
spawned watchexec CLI, no orphan processes, jobs die with the supervisor and are
reconstructed from `jobs.json` on respawn. The Dock's "Runner" control becomes
`cide run attach` (a thin log/status tail over the UDS), so the visible UX is unchanged
while ownership moves inside.

### 5.3 `Agent`

```rust
#[trait_variant::make(Send)]
pub trait Agent {
    fn kind(&self) -> AgentKind;
    async fn sessions(&self, scope: &SessionScope) -> Result<Vec<AgentSession>>,
        // interprets ~/.cmuxterm/<agent>-hook-sessions.json; matches surfaceId against the LIVE
        // topology (the store's workspaceId goes stale across restarts — encapsulated here)
    fn launch(&self, label: &str, cfg: &AgentConfig) -> CommandSpec;          // claude --name <label>
    fn resume(&self, slot: &AgentSlot, cfg: &AgentConfig) -> Result<CommandSpec>; // claude --resume <ckpt>
    async fn submit_prompt(&self, target: &AgentTarget, p: StructuredPrompt) -> Result<()>,
        // fix-on-red lands here: Diagnostics → prompt with file:line + artifact paths, never ANSI
    async fn ensure_hooks(&self) -> Result<HookState>;                        // idempotent
}
```

### 5.4 `Editor`, `Explorer`, `Placement`, `Warehouse` (port family), `Theme`, `Vcs`

```rust
pub trait Editor {
    fn launch(&self, ctx: &LaunchCtx) -> CommandSpec;                  // the hx-wrap successor
    async fn liveness(&self, t: &EditorTarget) -> Result<EditorLiveness>; // Running | AtShell | Gone
    async fn open(&self, t: &EditorTarget, file: &Path, o: OpenOpts) -> Result<OpenOutcome>;
        // helix: guarded :open injection; neovim: --server --remote (no injection at all);
        // OpenOutcome::Healed(new_target) surfaces self-healing to the use-case
}
pub trait Explorer {
    fn launch(&self, ctx: &LaunchCtx) -> CommandSpec;                  // stable client-id for control
    async fn reveal(&self, t: &ExplorerTarget, p: &Path) -> Result<()>;  // yazi: DDS emit-to with the
}                                                                        // DARWIN_USER_TEMP_DIR fix inside
pub trait Placement {
    fn supported(&self) -> bool;
    async fn monitors(&self) -> Result<Vec<Monitor>>;                  // name | uuid | portrait | landscape | index
    async fn move_window(&self, w: WindowUuid, to: &MonitorRef) -> Result<PlacementOutcome>;
        // PlacementOutcome::Moved | ::BestEffortFailed(reason) | ::Unsupported — best-effort is
        // a TYPED, logged outcome (fixes the `|| true` invisibility, pain #6), never a blocker
}
pub trait Warehouse {                                                  // the dbt vertical port family;
    fn resolve_target(&self, cfg: &DbConfig, root: &Path) -> Result<DbTarget>; // [database] → derived
    fn attach(&self, t: &DbTarget, read_only: bool) -> CommandSpec;    //   dbt warehouse → :memory:
    fn preview(&self, rel: &RelationRef) -> Result<PreviewSpec>;       // read-only LIMIT 100
}
pub trait DbtReview { /* compile → cute-dbt vs baseline → report surface; baseline lifecycle */ }
pub trait Theme {
    fn targets(&self) -> &[ThemeTarget];                               // helix, btop, yazi, cmux/ghostty…
    fn apply(&self, name: &str, plan: &mut ThemePlan) -> Result<()>;   // plan = seed→STATE copies +
}                                                                      // cmux themes set; ~/.config writes
                                                                       // are unrepresentable in ThemePlan
pub trait Vcs { /* status/branch/dirty (cheap), worktree_add, porcelain launch, forge ops via gh */ }
```

---

## 6. Adapter examples — swapability shown concretely

### 6.1 `Multiplexer`: `CmuxSocketAdapter` vs `CmuxCliAdapter` vs `FakeMux`

The trait is the clean room; **every hard-won cmux fact from cide-current-state §4
lives inside the adapters and nowhere else**:

| Quirk (documented) | Where it dies |
|---|---|
| `workspace.list` is focused-window-only; `tree --all` lacks `current_directory` | `snapshot()` composes `tree --all --id-format both` + per-window `workspace.list` joins into ONE `Topology` with cwd on every node. Callers can't even ask the broken question. |
| `OK <uuid>` vs `OK workspace:N` output formats; `list-windows` prints UUIDs not refs | CLI-adapter parsing tables, pinned per cmux version by the `fidelity/` snapshots; socket adapter avoids text parsing entirely (typed v2 frames — the primary reason it's primary). |
| Ghost blank windows (closing last workspace auto-spawns a default) | `create_window_with()` creates the real workspace FIRST, then drops the window's default "Terminal" workspace — the never-momentarily-empty ordering is adapter-internal. |
| Caller-workspace protection (can't close own tab) | `CloseOutcome::DeferredSelf { hint }` — typed, surfaced, handled last + best-effort by the use-case, "press Cmd+W" hint to the human. |
| UUID case differences | Normalized in the id newtypes' `FromStr` at the adapter boundary. |
| `close-window` returned OK but didn't close | Adapter verifies via post-close snapshot; emits `CloseOutcome::Unverified` until the upstream investigation (#31 fold-in) resolves. |
| Placement not CLI-controllable; AeroSpace re-tiles raw AX moves | Not this port at all — `Placement` port; the cmux adapter only reports window frames. |
| `markdown open` splits follow the caller's window unless `--window` passed | `open_markdown(MdRequest { window: WindowUuid, .. })` — the field is required. |
| Settle timing / read-screen polling | Socket adapter exposes `wait_for` tokens + the supervisor's event stream; `ReadOpts::settle` exists only as a documented fallback. |

Three adapters, one trait:

- **`CmuxSocketAdapter`** (default): speaks socket v2 directly, one persistent
  connection in the supervisor, per-verb connections on the cold path. Egress: `Zero`.
- **`CmuxCliAdapter`** (fallback/debug, flag-selectable): shells out to `cmux`, parses
  with the pinned tables. Exists because it is the cheapest oracle when the socket
  protocol drifts, and because `--via-cli` turns any bug report into a transcript.
- **`FakeMux`** (cide-testkit): in-memory topology + scripted event stream + recorded-
  fixture mode. Every use-case test and every BDD scenario runs against it; it passes
  the same conformance suite as the real adapters (§8).

Swapping later to tmux/zellij (the Linux door): implement the trait, return honest
`CapabilitySet` gaps (no browser surfaces, no feed), pass the conformance suite's
core tier. The port keeps the door open without promising it (settled non-goal for v1).

### 6.2 `Editor`: `HelixEditor` vs `NeovimEditor` — the one-line swap

```toml
# cide.toml — the neovim colleague's entire migration:
[bindings]
editor = "neovim"
```

- `HelixEditor.open()` = liveness probe (`read_screen` prompt heuristic, the guarded
  path) → `send_text(":open <abspath>\r", InjectionGuard::PromptIdle)`; `AtShell` →
  relaunch via `launch()`; `Gone` → `OpenOutcome::Healed` after regen. All the danger
  the dogfood documented (blind injection deleted a tracked file) is inside this one
  adapter, behind a guard type that won't compile around.
- `NeovimEditor.open()` = `nvim --server <socket> --remote <file>` — a *control
  channel*, no injection, no heuristic. The use-case (`cide open`, `focus` fan-out,
  route rules) is byte-identical; only the adapter differs. That asymmetry — one
  adapter fragile-by-substrate, one clean — is exactly what the port is for.

### 6.3 `Placement`: `MacAxPlacement` vs `NoopPlacement` — Linux not precluded

- **`MacAxPlacement`** (`cfg(target_os = "macos")`): in-process `objc2` +
  CoreGraphics/AX bindings replacing the interpreted `swift lib/cide-place.swift`
  helper (kills the per-call `swift` startup latency and the Xcode CLT dependency,
  pain #16; keeps the single-binary promise). AeroSpace cooperation preserved: if
  `aerospace` is on PATH and running, delegate `move-node-to-monitor`; raw AX only as
  fallback. Accessibility-grant reality (the grant attaches to cmux/Ghostty) is a
  documented `PlacementOutcome::BestEffortFailed(NoAxTrust)` with a doctor hint.
- **`NoopPlacement`**: `supported() == false`; every move returns `Unsupported`. Linux
  builds compile **today** with this adapter bound; a future `WlrPlacement`/
  `X11Placement` is an adapter, not a redesign. Space-open never blocks on placement
  on any platform (the dogfood's best-effort post-pass, now typed).

---

## 7. Configuration: the recommendation

### 7.1 Options analyzed

| Option | Verdict |
|---|---|
| **`cmux.json` `actions`/`commands` block as cide's config home** | **Rejected as source of truth.** It is cmux's namespace and schema (JSONC, hot-reloaded by cmux, trust-gated); it cannot express cide's domain (spaces, roles, agent slots, runner catalogs, recipes); and the global copy lives in `~/.config/cmux/` — unwritable by rule. **Kept as a projection target**: `cide setup --repo` *generates* the repo-local `.cmux/cmux.json` + `.cmux/dock.json` (palette actions, plus-button, tab-bar buttons, dock controls, workspaceGroups colors) from the recipe, inside a marked generated block, idempotently. Config compiles *down* to cmux; it never lives there. |
| **Single `cide.toml`** | Right vehicle, insufficient alone: monitors and machine quirks don't belong in a committed file; a colleague's editor swap shouldn't dirty the repo's canonical config; user-wide preferences (theme) shouldn't be re-declared per repo. |
| **Layered project + user files** | **Recommended**, with a strict write-discipline (below). |

### 7.2 The layering (recommended)

Precedence, lowest → highest; later layers override per-key:

```
1. Built-in defaults + embedded recipes      (in the binary; recipes/{base,dbt,rust}.toml via include_str!)
2. User config       ~/.config/cide/config.toml        ← READ-ONLY-BY-CIDE, user-authored, optional
3. Project config    <repo>/cide.toml                  ← committed; the canonical, shareable layer
4. Project-local     <repo>/cide.local.toml            ← gitignored; machine-personal (monitors, paths)
5. Environment       CIDE_* vars
6. CLI flags
```

**The write-discipline honors "never write `~/.config`" precisely**: the rule is a
*write* rule, and cide's contract is — **cide never writes layer 2; ever**. It is the
user's hand-authored domain; `cide config set --user` does not exist; `cide doctor`
shows which layer each effective key came from. Everything cide itself mutates lives
in repo files (`cide.local.toml`, `.cmux/*` — generated, consented, repo-local) or in
cide's own XDG dirs: `~/.local/state/cide/` (state, logs, sockets, cursors) and
`~/.local/share/cide/` (installed packs: themes, layouts, ejected recipes). The two
global writes the product genuinely needs (cmux shortcuts/telemetry-flip in
`~/.config/cmux/cmux.json`; optional launchd plist) happen **only** inside the
explicit, diff-shown, consented, reversible `cide setup` — the settled posture.

(If the panel prefers maximal purism — no `~/.config` *reads* either — layer 2 falls
back to `~/.local/share/cide/config.toml` with zero architectural change; it's one
path constant. Sketch B's recommendation stands on the read-is-fine interpretation
because it keeps XDG conventions for the user's benefit.)

### 7.3 Example files

```toml
# <repo>/cide.toml  (committed — the shareable layer)
[ide]
type   = "dbt"                      # selects recipes/dbt.toml (or a project-local recipe file)
name   = "cide-dbt"
layout = "landscape-portrait"

[bindings]                          # the swap contract: one line, not one repo
editor    = "helix"                 # neovim colleague changes exactly this
warehouse = "harlequin"

[agents]
slots = ["builder", "reviewer"]
[agents.claude]
args = []                           # typed array — kills the comma-split parser bug (pain #2)

[runner]
catalog = ["just", "dbt"]
on_red  = { route_to = "agent:builder", attach = "compiled_sql" }

[theme]
active = "catppuccin-mocha"

[database]
adapter   = "duckdb"
read_only = true
```

```toml
# <repo>/cide.local.toml  (gitignored — this machine only)
[monitors]
editor = "DELL P2725DE"             # name | uuid | portrait | landscape | index
tools  = "LG FHD"

[supervisor]
idle_exit_minutes = 20
```

```toml
# ~/.config/cide/config.toml  (user-authored; cide NEVER writes it)
[theme]
active = "tokyonight"               # personal default; project layer may override
[bindings]
editor = "helix"
```

```toml
# recipes/dbt.toml  (embedded; `cide recipe eject dbt` copies it to ~/.local/share/cide/recipes/)
[recipe]
name = "dbt"
extends = "base"                    # composition: dbt = base ⊕ {…}
[recipe.bindings]
warehouse = "harlequin"
viewer    = "csvlens"
report    = "cute-dbt"
[recipe.identity]
color = "orange"
icon  = "cylinder.split.1x2"
[recipe.routing]
"*.sql" = "editor+compiled_preview"
"*.csv" = "viewer"
[[recipe.layout.windows]]
role = "editor"
orientation = "portrait"
# tree = cmux-native layout JSON with capability tokens at the leaves
```

A vertical is *only* this data plus (where genuinely needed) adapter code behind an
existing port family (`cide-dbt` implements `Warehouse`/`DbtReview`; the rust vertical
needs **zero new crates** — bacon/nextest/cargo-mutants are `RunnerEngine`/catalog
entries, which is exactly the Rule-of-Two validation the synthesis demands).

---

## 8. Testing strategy

Seven tiers, each answering a failure class the dogfood actually hit:

1. **Core unit tests** — use-cases against `cide-testkit` fakes; pure, fast, no IO.
2. **Port conformance suites** — a macro per port
   (`multiplexer_conformance!(adapter_factory)`) running one behavioral assertion set
   against `FakeMux`, `CmuxCliAdapter` (over recorded fixtures), and
   `CmuxSocketAdapter` (over a replay server). The fake is *proven equivalent*, so
   green-on-fake means something. This is also the published colleague on-ramp:
   "write an adapter, pass the suite."
3. **Generated golden fixtures** (the G1 mandate: *never hand-authored*) — a
   `fixturegen` xtask runs read-only verbs against the live cmux on Christopher's
   machine and commits `fixtures/<cmux-version>/` (tree output, identify, surface
   titles, event samples). The existing `fidelity/` static-CLI snapshots fold into
   this tier; an upgrade-diff just run flags drift on every cmux release.
4. **The 113-assertion POSIX golden master as strangler spec** — a stub socket server
   records every request the Rust binary emits per scenario; assertions translated
   once from the shell suite. A verb is "ported" only when its scenarios pass
   unchanged through the shell shim (§9).
5. **Supervisor reactor tests** — recorded NDJSON event streams (redacted from
   `~/.cmuxterm/events.jsonl`) replayed into the reactor against `FakeMux`; assert
   reactions (status pills set, diffs opened, prompts submitted). Plus the
   **crash-replay property**: for a random kill-point k in the stream, restart from
   the cursor and assert the end state converges with the never-killed run.
   Crash-safety is a tested invariant, not a design hope.
6. **BDD journeys** — cucumber-rs features for space lifecycle, review queue,
   fix-on-red, focus fan-out — all against fakes; the same `.feature` files double as
   the product's behavioral documentation.
7. **SLO + hygiene gates in CI** — hyperfine cold-start budget (<10 ms `--help`,
   interactive verbs against a local fake supervisor); `cargo-deny` network-crate ban
   (zero-egress structurally); a grep gate asserting no `~/.config` path literals
   outside the consented-setup module.

---

## 9. Distribution & migration

### 9.1 Distribution

- **One binary** via `cargo-dist` → `brew install breezy-bays-labs/tap/cide`
  (macOS arm64 + x86_64; Linux target compiles with `place_noop` + no cmux socket
  adapter gap — honest `CapabilitySet`). No runtime deps; no Xcode CLT (Swift helper
  replaced by in-crate objc2 bindings); no postinstall scripts; no telemetry, no
  update checks (zero-egress: brew is the update channel).
- The supervisor ships *inside* the binary; nothing to install, enable, or configure.
  `cide doctor` is the single trust/health surface: adapter egress labels, cmux
  capabilities check, hook state, supervisor status, config-layer provenance.

### 9.2 Incremental migration from the shell dogfood (strangler fig, verb by verb)

Shell commands are hyphenated (`cide-space`); the Rust binary is `cide` — **no name
collision, so they coexist from day zero.** As each verb ports, the shell script
becomes a two-line exec shim (`exec cide space "$@"`), which keeps every existing
muscle-memory path, AeroSpace binding, and dock entry working, *and* keeps the golden
master running through the shim asserting parity continuously.

| Slice | Ships | Strangles | Why this order |
|---|---|---|---|
| **M0** | `cide doctor`, `cide events tail`, the typed socket client, fixturegen xtask | nothing | The conformance scaffold first (standing posture in the synthesis); zero risk, immediate diagnostic value |
| **M1** | Supervisor skeleton (event pump + cursor + reconciler) + `cide hook notify` policy binary wired into `.cmux` `notifications.hooks` | the Feed-watching gap | Declarative-first: the hook binary is useful with the daemon *off*; the daemon proves resumability before owning anything critical |
| **M2** | `cide run` (embedded watchexec, catalogs, status pills, pipe-pane parser) | the Dock's raw `watchexec` line; the `just --list` stub pane (#23) | First *new* capability — runner never existed in shell, so no parity burden; exercises job-host + reconciler under real load |
| **M3** | `cide space` (new/open/close/ls/rm) + `cide state migrate` (pipe-files → versioned JSON, two-phase like the `cwd state-migrate` precedent) | `bin/cide-space` → shim | The crown jewels, ported only once M0–M2 hardened the adapter; golden-master gated |
| **M4** | `cide agent`, `cide jump`, `cide open` (Editor/Explorer/Agent ports), `cide place` (Placement port absorbs the Swift helper) | `cide-agent`, `cide-jump`, `cide-open`, `cide-place` → shims | Each rides ports proven by M3's space lifecycle |
| **M5** | `cide theme` (seed→state separation; ghostty via `cmux themes set` only) | `cide-theme` → shim; **fixes the two live hygiene violations** (pains #9/#10) | Independent; scheduled when it unblocks nothing |
| **M6** | dbt recipe + `cide-dbt` adapters (`Warehouse`, `DbtReview`, dbt catalog); `cwd focus` → `cide focus` | the `cwd` family last | Verticals land only after the base rails exist; cute-dbt review loop (bet 4) can ship from POSIX meanwhile, per the synthesis |

During the entire window: shell remains the daily driver until each shim's golden
scenarios are green; state is migrated once (M3), with the Rust side refusing to run
against unmigrated state rather than guessing (the collision-refusing `cwd
state-migrate` discipline, kept).

---

## 10. Risk register (top 5)

| # | Risk | Likelihood × impact | Mitigations |
|---|---|---|---|
| **R1** | **Supervisor lifecycle hell** — stale sockets, two supervisors racing, version skew after brew upgrade, zombie jobs | M × H | One binary (no separate artifact to skew); flock-guarded single-flight spawn; handshake-based liveness + version check with drain-and-respawn; idle-exit (the daemon usually isn't running); state-files-as-truth + crash-replay property tests (§8.5); `cide supervisor status/stop/logs` + doctor from day one; the standing degraded-mode rule means worst case = sketch A behavior, never a brick |
| **R2** | **cmux socket-v2 / event drift** — fast upstream cadence, protocol not a stability contract | H × M | Fidelity tier: generated fixtures per cmux version + upgrade-diff workflow (already proven in `fidelity/`); `capabilities()` feature-gating; the CLI adapter as a second oracle (`--via-cli`); quirk knowledge concentrated in ONE module so a breaking change is a one-module fix; version pin recorded in doctor output |
| **R3** | **Event-stream gaps corrupt derived state** — slow-consumer drop (1024 pending), `ack.resume.gap`, missed reactions | M × M | `StreamGap` in the subscription type (impossible to ignore at compile time); level-triggered reconciliation — events are hints, snapshots are truth; cursor-file resume + durable events.jsonl mirror; replay-based reactor tests including injected gaps |
| **R4** | **Supervisor scope creep** — the resident process gravitationally attracts every feature until the CLI is a stub and the daemon is a monolith | M × H | The standing rule (§1.2): every verb works supervisor-less; supervisor owns only cross-event state + long-running jobs; stateless policy stays in the declarative hook binary; PR review checklist item ("could this be a one-shot verb?"); the cold path is benchmarked in CI so it can't silently rot |
| **R5** | **Migration split-brain** — Rust and shell disagreeing about state mid-strangle; two writers, silent schema drift (the pipe-file legacy) | M × M | One-shot, two-phase, collision-refusing `cide state migrate` at M3 (precedent: `cwd state-migrate`); Rust refuses unmigrated state; shims (not parallel implementations) so exactly one code path serves each verb at any time; golden master runs through the shims continuously; versioned JSON state with explicit schema version field |

Watch-list (below top-5 cut): AX/Accessibility fragility for placement (typed
best-effort outcome, never blocks — absorbed into the Placement port design); helix
injection hazard (guard types, single adapter); watchexec crate API churn (it's a
library boundary inside one module; pin + adapter).

---

## 11. Summary — what sketch B buys, in one paragraph

The vision's identity is reactive: review queues, fix-on-red, attention policy, fleet
state. Reactions need residency, and the dogfood already pays for residency badly —
three uncoordinated dock loops and nested settle-polls. Sketch B consolidates that
into one crash-safe, lazily-spawned, idle-exiting, version-handshaked supervisor that
is *pure derived state* over cmux's own durable, cursor-resumable event bus — the same
hexagonal core and trait ports any sketch has, with one extra crate and one hidden
subcommand. The CLI stays thin and fast; every verb works with the daemon dead; the
palette, dock, human, and resident agent all drive one verb registry; and the parts of
the product that make it *the* agent-native terminal IDE — the loops — get the one
thing a one-shot CLI can never give them: something that's still listening.
