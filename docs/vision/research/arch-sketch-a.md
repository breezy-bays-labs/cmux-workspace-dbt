# Architecture Sketch A — Library-First Single Binary (Daemonless)

> Task #33 architecture exploration, sketch A of N. 2026-06-09.
> Philosophy: **one fast static binary, no daemon, ever.** Hexagonal core + adapter
> crates; every cide verb is a short-lived CLI invocation wired into cmux palette
> actions / dock buttons / shortcuts; live behavior achieved by spawning managed
> *foreground* processes into cmux panes and by writing durable state files; cmux
> events consumed via cursor-file catch-up and short-lived subscriptions only.
> Grounded in: `base-vision-synthesis.md`, `cmux-api-surface.md`,
> `cide-current-state.md`.

---

## 1. Thesis: the multiplexer IS the supervisor

The standard reflex for "reactive IDE glue" is a resident daemon. Sketch A's claim
is that for cide this reflex duplicates a daemon that **already exists and is
better at the job**: cmux itself is a long-lived, stateful, crash-recovering,
event-sourcing process supervisor with

- durable append-only logs (`~/.cmuxterm/events.jsonl`, `workstream.jsonl`,
  per-agent session stores) that survive cide not running;
- a **cursorable, reconnectable replay contract** (`events.stream --after <seq>`,
  `--cursor-file`, `ack.resume.gap` → snapshot refresh) explicitly designed so a
  consumer can be *absent* and catch up exactly;
- a hook pipeline (`notifications.hooks`, agent hooks, Claude Code hooks) that
  **pushes control to an external program at exactly the moments that matter**,
  with context (`appFocused`, `focusedPanel`, `cwd`) in the payload;
- native process supervision for anything that must stay resident: panes, dock
  controls (each its own Ghostty terminal), `respawn-pane`, session restore,
  `surface resume`, agent hibernation.

A second daemon beside that means a second lifecycle, a second crash story, a
second version-skew axis (daemon vs CLI vs cmux), launchd plumbing, an IPC
surface for the CLI to talk to its own daemon, and an invisible process the
zero-egress / "greppable local file" trust posture has to explain. Sketch A
spends none of that. Three mechanisms replace residency:

**A. Verbs as transactions.** Every invocation is: read durable truth (live
`tree --all`, cmux stores, cide state dir, event cursor catch-up) → decide in
the pure core → emit socket RPCs → write state atomically → exit. The dogfood
already proved the philosophy: *tree is truth, the store is a cache*; every
verb re-resolves. Staleness between invocations is therefore harmless by
construction.

**B. Residency by proxy.** Anything that genuinely must stay alive runs as a
**foreground process of the same binary inside a cmux pane or dock control**:
`cide run wrap -- watchexec ...` wraps the runner and parses failures; a
`pipe-pane --command 'cide run parse ...'` consumer is launched and owned by
cmux. cmux supervises, restarts (`respawn-pane`), displays, themes, and
resource-accounts these processes (`cmux top` attributes them to the space).
They die with their workspace — no orphan reaping, no PID files. The user can
*see* every live cide process in the UI. That visibility is itself a feature of
the trust posture.

**C. Reactivity by hooks + catch-up.** Time-critical reactions ride push:
Claude Code `Stop` hook → `cide turn-complete` (queue the diff, stamp the
review item); cmux `notifications.hooks` → `cide policy` (the focus-aware
silencing engine is a *stdin→stdout filter*, the canonical short-lived
program). Everything else is **eventually-correct-on-invocation**: each cide
verb begins with a cheap cursor catch-up over `events.jsonl` (review cursors,
space GC, registry repair). The contract is honest: cide reacts *when invoked
or when hooked*, and cmux's durable logs guarantee nothing is ever lost in
between.

### What this buys

- **Startup is the product.** No tokio, no async runtime, no IPC client: the
  binary is `clap + serde + std::os::unix::net`. Cold start target **< 10 ms**
  (CI-tested with hyperfine) — which is what makes "every verb is a palette
  action / hook filter / statusline segment" affordable at all. The flow-SLO
  posture from the synthesis is *served*, not violated: interactive verbs are
  one process spawn + one unix-socket round trip.
- **One artifact to trust.** `brew install cide` ships one Mach-O. `cide doctor`
  prints the entire network surface of *everything cide runs*, because
  everything cide runs is either this binary or a pane the user can see.
- **The agent contract is trivial.** P5 ("agents are users too") falls out: a
  resident agent calls the same short-lived verbs with `--json`; there is no
  daemon socket to authenticate, no state the CLI can't see.
- **Crash semantics are boring.** A short-lived verb that dies mid-flight leaves
  an atomic-rename state file either old or new, and the next verb re-resolves
  from the live tree. There is no "daemon wedged, everything stale" mode.

### Where daemonless genuinely hurts (the honest ledger)

| # | Hurt | Severity | Treatment |
|---|---|---|---|
| 1 | **No sub-second reactions without a hook.** `workspace.closed` by the user's Cmd+W fires no notification hook → space membership stale until the next verb runs. | Low | Tree-is-truth verbs make staleness invisible; lazy GC at verb entry. Documented contract, not a bug. |
| 2 | **Debounce / correlation windows** ("flash only if 3 reds in 10 s", bubbling noisy spaces) need memory across events. | Medium | Timestamped ring files in `~/.local/state/cide/` written by hook invocations; clunkier than in-memory, fully workable. |
| 3 | **Hook storms = process storms.** A chatty agent turn can fire dozens of hook invocations; each pays spawn + socket connect, and concurrent writers can race. | Medium | <10 ms spawn budget makes the cost ~feel-free; single-writer `flock` on the state dir + atomic renames; hooks that only *read* (statusline) touch cache files, zero socket. |
| 4 | **`events.jsonl` rotation gap** (16 MiB, one rotation): a cursor parked for weeks can fall off the log. | Low | The `ack.resume.gap` contract already defines the answer: detect gap → refresh from snapshot verbs (`tree`, `extension.sidebar.snapshot`) → re-anchor cursor. A daemon disconnected that long has the identical problem. |
| 5 | **Cross-invocation caching is impossible** — every verb re-reads `tree --all`. | Low | One RPC on a unix socket; measured µs-to-low-ms. Hot read-only paths (prompt segment) read hook-maintained cache files and make **zero** socket calls. |
| 6 | **A future feature may demand true residency** (e.g., a live always-on spaces sidebar driven at 10 Hz). | Honest risk | The escape hatch is pre-built and is *not* an architecture change: `cide reactor` — the same binary in a loop on `cmux events --reconnect --cursor-file` — runs as a **dock control**, i.e. a cmux-supervised foreground process. "Daemon" becomes a deployment mode of mechanism B, with the same ports, same state files, same testing. See §13. |

The synthesis's ranked bet 3 asks for "a small Rust daemon on `cmux events
--cursor-file`" for review cursors, role auto-tagging, and space GC. Sketch A's
position: all three are **catch-up-shaped, not residency-shaped** — cursors
advance at hook-time and verb-time; role tagging is already push-based at spawn
(`hx-wrap --as-editor` proved it; the Rust verbs tag at create time, no
reaction needed); GC is lazy. The bet's *outcome* (death of settle-polling,
event-driven reactions) is delivered by hooks + `wait-for` + catch-up; the
bet's *mechanism* (resident process) is the one thing declined — and §13 keeps
the door open at zero architectural cost if dogfooding proves the need.

---

## 2. Crate layout

Small, boring workspace. Verticals are **data**, so they do not get crates;
only genuinely separate compilation units do.

```
cide/                            # repo (this repo, post-migration)
├── Cargo.toml                   # [workspace] resolver = "2"
├── crates/
│   ├── cide-core/               # THE HEXAGON. Domain types + port traits + use-cases.
│   │   ├── src/domain/          #   space.rs, layout.rs, role.rs, ids.rs, runner.rs,
│   │   │                        #   agent.rs, review.rs, theme.rs, egress.rs, vertical.rs
│   │   ├── src/ports/           #   mux.rs, editor.rs, explorer.rs, vcs.rs, runner.rs,
│   │   │                        #   agent.rs, theme.rs, placement.rs, warehouse.rs, notify.rs
│   │   ├── src/usecases/        #   space_new.rs, space_open.rs, space_close.rs, jump.rs,
│   │   │                        #   open.rs, focus.rs, review.rs, run.rs, policy.rs, sync.rs
│   │   └── src/config/          #   layered loader, schema (serde), vertical recipe loader
│   │   # deps: serde, toml, thiserror. NO I/O, NO process spawning, NO sockets.
│   │
│   ├── cide-mux-cmux/           # Multiplexer port: cmux socket-v2 adapter (primary)
│   │   │                        # + CLI-subprocess adapter (fallback/debug) + quirk vault (§6)
│   │   # deps: serde_json, std unix sockets. Owns EVERY cmux fact from cide-current-state §4.
│   │
│   ├── cide-adapters/           # Tool adapters behind core ports, feature-gated modules:
│   │   │                        #   editor_helix, editor_neovim, explorer_yazi, vcs_lazygit,
│   │   │                        #   vcs_tig, runner_watchexec, runner_bacon, agent_claude,
│   │   │                        #   agent_codex, warehouse_harlequin, diff_multi, theme_engine
│   │   # deps: serde, minimal. Each module ships an AdapterManifest (id, egress label, tools).
│   │
│   ├── cide-place-macos/        # Placement port adapter: CoreGraphics + AX via objc2
│   │   # cfg(target_os = "macos"); AeroSpace cooperation lives here.
│   │   # Linux story: a future cide-place-wlr / NoopPlacement satisfies the same port.
│   │
│   ├── cide-testkit/            # FakeMux, fixture replayers, port conformance suites,
│   │                            # golden-master harness (the POSIX 113-assertion spec, ported)
│   │
│   └── cide/                    # the binary: clap wiring + composition root ONLY.
│       └── src/main.rs          # builds adapters from config, injects into use-cases.
│
├── recipes/                     # VERTICALS AS DATA (embedded via include_str! + overridable)
│   ├── base.toml                # base IDE: ports used, default layout, bindings, behaviors
│   ├── dbt.toml                 # dbt = base ⊕ {warehouse, viewer, dbt routing, dbt layout}
│   └── rust-dev.toml            # rust = base ⊕ {bacon fast-path, nextest, .bacon-locations}
├── layouts/                     # layout presets: cmux-native JSON with capability tokens
├── themes/                      # name-map theme packs (ported from config/themes/)
└── tests/features/              # BDD .feature files (behavioral spec, see §10)
```

Dependency rule (enforced by `cargo-deny`/CI + a dependency-cruiser-style
check): `cide-core` depends on nothing in the workspace; adapters depend on
core; the binary depends on everything; **nothing depends on the binary**.
`cide-core` compiles on Linux today — only `cide-place-macos` and the socket
path default are platform-aware, both behind ports.

Dependency budget for the whole workspace (hard requirement: lightweight):
`clap`, `serde`, `serde_json`, `toml`, `thiserror`, `jiff` (time), `objc2`
family (macOS placement only). No tokio, no reqwest (zero-egress means no HTTP
client at all), no sqlite (state is flat files + JSONL, greppable per the
vision's trust story).

---

## 3. Core domain model

```rust
// ---------- identity (kills the ref-vs-UUID ad-hockery, pain point #5) ----------
/// cmux refs ("workspace:3") are positional and die across restarts; UUIDs survive.
/// One type carries both; persistence ALWAYS serializes the UUID (normalized uppercase);
/// refs are derived live and never stored.
pub struct MuxId { pub uuid: Uuid, pub ref_hint: Option<RefHint> }
pub struct WindowId(pub MuxId);
pub struct WorkspaceId(pub MuxId);
pub struct PaneId(pub MuxId);
pub struct SurfaceId(pub MuxId);

// ---------- verticals as data ----------
/// An IDE type ("vertical") is a *recipe*: pure data, loaded from TOML, never a code fork.
pub struct IdeType {
    pub name: String,                       // "base" | "dbt" | "rust-dev" | user-defined
    pub extends: Option<String>,            // composition: dbt = base ⊕ {...}
    pub layout: LayoutPresetRef,            // default layout preset
    pub bindings: BTreeMap<PortKind, AdapterId>, // port → adapter (the swap table)
    pub runner_catalog: Vec<CatalogEntry>,  // detection rules + commands + parser id
    pub routing: Vec<RouteRule>,            // ".sql" → editor+sibling-yml, ".csv" → viewer …
    pub behaviors: Behaviors,               // fix_on_red, review_baseline, focus_fanout targets
    pub color: Option<WorkspaceColor>,      // per-vertical identity (dbt=orange, rust=red)
}

// ---------- layout as data ----------
pub struct LayoutPreset {
    pub name: String,                       // "landscape-portrait", …
    pub windows: Vec<WindowPlan>,           // the one thing cmux JSON can't express: multi-window
}
pub struct WindowPlan {
    pub role: WindowRole,                   // Editor | Tools (window-grained roles)
    pub orientation: Orientation,           // Portrait | Landscape (drives window reuse)
    pub tree: LayoutNode,                   // mirrors cmux layout JSON…
}
pub enum LayoutNode {
    Split { direction: Direction, ratio: f32, children: Vec<LayoutNode> },
    Pane { surfaces: Vec<SurfaceSpec> },
}
/// …except leaves carry CAPABILITY TOKENS, not raw commands. The bound adapter
/// compiles `Capability::Editor` → `hx-wrap --as-editor` (helix) or
/// `nvim --listen …` (neovim). This is the layout-pack swap seam.
pub struct SurfaceSpec {
    pub capability: Capability,             // Editor, Explorer, Agent(role), Runner(job),
                                            // Vcs(Porcelain|History), Warehouse, Shell, Viewer(kind)
    pub name: Option<String>,
}

// ---------- roles ----------
pub enum WindowRole { Editor, Tools }                       // window-grained
pub struct AgentRole(pub String);                           // surface-grained: "builder", "reviewer"

// ---------- instances & spaces ----------
/// Instance: named, self-healing coupling of N workspaces (one per WindowRole),
/// spanning monitors. The default instance = the implicit repo-baseline one.
pub struct Instance { pub name: String, pub members: BTreeMap<WindowRole, WorkspaceId> }

/// Space: lifecycle-managed instantiation of a preset — THE unit of work (P1).
pub struct Space {
    pub id: SpaceId,
    pub name: String,
    pub ide_type: String,
    pub repo: PathBuf,
    pub worktree: Option<PathBuf>,          // worktree-per-agent spaces (bet 6)
    pub state: SpaceState,                  // Open { members } | Closed { snapshot }
    pub agents: Vec<AgentSlot>,
    pub resume_stamps: Vec<ResumeStamp>,    // non-agent surfaces: harlequin, runners, `just dev`
    pub baseline: Option<ReviewBaseline>,   // dbt manifest snapshot at branch checkout (bet 4)
}
pub enum SpaceState {
    Open   { members: BTreeMap<WindowRole, WorkspaceId> },
    Closed { closed_at: Timestamp, history: Vec<SpaceEvent> },
}

// ---------- agents ----------
pub struct AgentSlot {
    pub role: AgentRole,                    // N role slots per space (bet 5)
    pub kind: AgentKind,                    // Claude | Codex | …
    pub label: AgentLabel,                  // rides to tab name, vault, /resume
    pub checkpoint: Option<CheckpointId>,   // durable key; cide READS bindings, never writes them
    pub surface: Option<SurfaceId>,         // live binding (resolved from tree, not trusted from store)
    pub lifecycle: AgentLifecycle,          // Running | Idle | NeedsInput (from cmux session store)
}

// ---------- runner ----------
pub struct RunnerJob {
    pub id: JobId,
    pub entry: CatalogEntry,                // engine + command + watch globs + parser id
    pub surface: SurfaceId,                 // the pane the foreground wrapper lives in
    pub status: RunnerStatus,               // Green | Red(Vec<Diagnostic>) | Running | Dead
}
/// Structured failure context — what fix-on-red sends to the agent (P4).
pub struct Diagnostic {
    pub file: PathBuf, pub line: Option<u32>,
    pub message: String,
    pub artifact: Option<PathBuf>,          // compiled SQL path | .bacon-locations — never pasted ANSI
}

// ---------- review ----------
pub struct ReviewItem {
    pub space: SpaceId, pub agent: AgentRole,
    pub turn_seq: u64,                      // event-stream sequence of agent.hook.Stop
    pub state: ReviewState,                 // Unreviewed | Reviewed { at } | Commented { … }
}
pub struct EventCursor { pub seq: u64, pub log_generation: u64 } // gap-detecting

// ---------- trust ----------
pub enum EgressLabel { Zero, DefensibleEgress { why: String }, TelemetryDisabledVerified }
pub struct AdapterManifest {
    pub id: AdapterId, pub port: PortKind,
    pub required_tools: Vec<ToolRequirement>,
    pub egress: EgressLabel,                // `cide doctor` aggregates these (the egress contract)
}
```

State on disk (all flat, greppable, atomic-rename-written, `flock`-guarded):
`~/.local/state/cide/` — `spaces/<id>/space.toml`, `registry.toml`,
`cursors/{review,gc}.json`, `cache/fleet.json` (hook-maintained, statusline
reads it socket-free), `agents.jsonl` (append-only index). One serde schema,
versioned with a `schema = 1` field; the pipe-delimited shell files are
imported once by `cide state migrate` (§12).

---

## 4. Port traits (the hexagon's edges)

Design rules: (1) ports are **role-shaped, not tool-shaped** — `Editor` knows
nothing of helix; (2) adapters never call each other — when a tool adapter
needs the multiplexer (helix needs `send`), the use-case passes a **narrowed
capability handle**, which keeps every interaction visible to the golden-master
op recorder; (3) every adapter ships an `AdapterManifest`; (4) everything is
object-safe (`dyn`-usable) so the composition root builds the adapter set from
config at runtime — swapping is a config edit, not a recompile.

```rust
// ============================== Multiplexer ==============================
// Split into narrow capabilities; `Multiplexer` is the umbrella supertrait.
// FakeMux (cide-testkit) implements all of them from fixture topologies.

pub trait MuxTopology {
    /// ALWAYS global enumeration (tree --all under the hood). There is no
    /// focused-window-scoped listing anywhere in the port — that cmux trap
    /// (workspace.list) is structurally unexpressible for callers. §6.
    fn tree(&self) -> Result<Topology, MuxError>;
    fn identify(&self) -> Result<Identity, MuxError>;          // caller vs focused
    fn find_window(&self, q: &ContentQuery) -> Result<Vec<SurfaceHit>, MuxError>;
    fn sidebar_snapshot(&self) -> Result<SidebarSnapshot, MuxError>; // branch/dirty/PR/ports
}

pub trait MuxWorkspaces {
    /// Encapsulates: "OK workspace:N" vs "OK <uuid>" parsing, ghost-window
    /// prevention (create-then-drop-default ordering), UUID normalization.
    fn create_workspace(&self, w: &WindowTarget, spec: &WorkspaceSpec)
        -> Result<WorkspaceId, MuxError>;
    /// Encodes caller-workspace protection: closing self returns
    /// CloseOutcome::CallerProtected { user_instruction } — never an error.
    fn close_workspace(&self, id: &WorkspaceId) -> Result<CloseOutcome, MuxError>;
    fn new_window(&self) -> Result<WindowId, MuxError>;
    fn close_window(&self, id: &WindowId) -> Result<CloseOutcome, MuxError>;
    fn tag(&self, id: &WorkspaceId, tag: &CideTag) -> Result<(), MuxError>;
    fn set_color(&self, id: &WorkspaceId, c: WorkspaceColor) -> Result<(), MuxError>;
    fn group(&self) -> Option<&dyn MuxGroups>;                 // capability-gated: groups are
}                                                              // within-window only — see §6

pub trait MuxSurfaces {
    fn new_surface(&self, pane: &PaneTarget, spec: &SurfaceSpec2) -> Result<SurfaceId, MuxError>;
    /// Injection is GUARDED — the port refuses blind sends (the yazi file-deletion
    /// incident is encoded as a type): callers must supply the guard evidence.
    fn send_text(&self, s: &SurfaceId, text: &str, g: InjectionGuard) -> Result<(), MuxError>;
    fn read_screen(&self, s: &SurfaceId, opts: ReadOpts) -> Result<Screen, MuxError>;
    fn respawn(&self, s: &SurfaceId, cmd: Option<&CommandSpec>) -> Result<(), MuxError>;
    fn pipe_pane(&self, s: &SurfaceId, cmd: &CommandSpec) -> Result<(), MuxError>;
    fn wait_for(&self, token: &SyncToken, t: Timeout) -> Result<(), MuxError>;
    fn signal(&self, token: &SyncToken) -> Result<(), MuxError>;
    fn resume_stamp(&self, s: &SurfaceId, stamp: &ResumeStamp) -> Result<(), MuxError>;
    fn rename_tab(&self, s: &SurfaceId, name: &str) -> Result<(), MuxError>;
}
pub enum InjectionGuard {
    /// read_screen matched a shell-prompt heuristic — the ONLY path for helix `:open`
    PromptVerified(PromptEvidence),
    /// the target was just spawned by us and hasn't run anything else
    FreshSpawn(SurfaceId),
}

pub trait MuxAttention {
    fn set_status(&self, ws: &WorkspaceId, pill: &StatusPill) -> Result<(), MuxError>;
    fn set_progress(&self, ws: &WorkspaceId, frac: f32, label: &str) -> Result<(), MuxError>;
    fn notify(&self, n: &Notification) -> Result<(), MuxError>;
    fn flash(&self, target: &FlashTarget) -> Result<(), MuxError>;
    fn mark_unread(&self, ws: &WorkspaceId) -> Result<(), MuxError>;
}

pub trait MuxEvents {
    /// Short-lived catch-up: read events after cursor, advance cursor, return.
    /// Detects log rotation (gap) → Err(Gap) → caller refreshes from snapshots
    /// and re-anchors. This is the DAEMONLESS event story in one method.
    fn catch_up(&self, cur: &mut EventCursor, f: &EventFilter)
        -> Result<Vec<MuxEvent>, CatchUpError>;
    /// Bounded blocking subscription for in-verb barriers (space-open settle).
    /// NEVER long-lived: deadline is mandatory.
    fn wait_event(&self, f: &EventFilter, deadline: Deadline)
        -> Result<MuxEvent, MuxError>;
}

pub trait MuxViewers {
    fn open_markdown(&self, path: &Path, at: &PanelTarget) -> Result<SurfaceId, MuxError>;
    fn open_diff(&self, spec: &DiffSpec) -> Result<SurfaceId, MuxError>; // unstaged|staged|branch|last-turn|stdin
    fn open_browser(&self, url: &Url, at: &PanelTarget, style: Option<&Css>) -> Result<SurfaceId, MuxError>;
}

pub trait Multiplexer:
    MuxTopology + MuxWorkspaces + MuxSurfaces + MuxAttention + MuxEvents + MuxViewers
{
    fn capabilities(&self) -> &CapabilitySet;   // probed once per invocation, cached in-process
    fn manifest(&self) -> &AdapterManifest;
}

// ============================== Editor ==============================
pub trait Editor {
    fn manifest(&self) -> &AdapterManifest;
    /// Compiled into layout leaves for Capability::Editor.
    fn launch(&self, ctx: &LaunchCtx) -> CommandSpec;
    /// Open a file in a live editor surface. `io` is the narrowed mux handle.
    fn open(&self, t: &EditorTarget, f: &Path, io: &dyn MuxSurfaces) -> Result<(), EditorError>;
    fn liveness(&self, t: &EditorTarget, io: &dyn MuxSurfaces) -> Result<Liveness, EditorError>;
    /// For atomic `cide replace`: write-all → (serpl) → reload-all.
    fn write_all(&self, t: &EditorTarget, io: &dyn MuxSurfaces) -> Result<(), EditorError>;
    fn reload_all(&self, t: &EditorTarget, io: &dyn MuxSurfaces) -> Result<(), EditorError>;
}

// ============================== Explorer (FileTree) ==============================
pub trait Explorer {
    fn manifest(&self) -> &AdapterManifest;
    fn launch(&self, ctx: &LaunchCtx) -> CommandSpec;          // yazi --client-id …
    /// Reveal via a PROPER control channel (yazi DDS), never keystrokes.
    fn reveal(&self, t: &ExplorerTarget, path: &Path) -> Result<(), ExplorerError>;
}

// ============================== Vcs ==============================
pub trait Vcs {
    fn manifest(&self) -> &AdapterManifest;
    fn porcelain(&self, ctx: &LaunchCtx) -> CommandSpec;       // lazygit
    fn history(&self, ctx: &LaunchCtx) -> CommandSpec;         // tig
    fn blame_journey(&self, f: &Path, line: u32) -> JourneyPlan; // blame→diff→history (P6c)
    fn merge_base_diff(&self, repo: &Path) -> Result<PatchRef, VcsError>;
}

// ============================== Runner ==============================
pub trait RunnerEngine {
    fn manifest(&self) -> &AdapterManifest;
    /// Foreground command for the pane. ALWAYS wrapped: `cide run wrap --job <id> -- <cmd>`
    /// so the parser lives inside the cmux-supervised process (mechanism B).
    fn plan(&self, entry: &CatalogEntry, repo: &RepoCtx) -> RunnerPlan;
}
pub trait FailureParser {                                       // runs INSIDE `cide run wrap`
    fn feed(&mut self, line: &str) -> Option<ParsedEvent>;      // Diagnostic | Green | Progress
}
pub trait RunnerCatalog {
    fn detect(&self, repo: &RepoCtx) -> Vec<CatalogEntry>;      // just/make/npm/cargo + recipe rules
}

// ============================== Agent ==============================
pub trait Agent {
    fn manifest(&self) -> &AdapterManifest;
    fn kind(&self) -> AgentKind;
    fn launch(&self, label: &AgentLabel, resume: Option<&CheckpointId>) -> CommandSpec;
    /// Read cmux's session store (read-only — cide never writes checkpoint bindings).
    /// Encapsulates: workspaceId-goes-stale (join surfaceId against live tree instead).
    fn sessions(&self, store_dir: &Path) -> Result<Vec<AgentSession>, AgentError>;
    fn ensure_hooks(&self) -> HooksRequirement;                 // idempotent `cmux hooks setup` plan
    fn submit_prompt(&self, s: &SurfaceId, p: &StructuredPrompt, io: &dyn MuxSurfaces)
        -> Result<(), AgentError>;                              // fix-on-red delivery
}

// ============================== Theme ==============================
pub trait ThemeTarget {                                          // one impl per themed tool
    fn manifest(&self) -> &AdapterManifest;
    fn apply(&self, theme: &ThemePack) -> Result<ApplyPlan, ThemeError>;
    // ApplyPlan = file edits in cide-managed dirs + mux RPCs. NEVER ~/.config writes:
    // the ghostty case routes through `cmux themes set` only (fixes live violation #9).
}

// ============================== Placement ==============================
pub trait Placement {
    fn manifest(&self) -> &AdapterManifest;
    fn displays(&self) -> Result<Vec<Display>, PlaceError>;
    fn resolve(&self, r: &MonitorRef) -> Result<DisplayId, PlaceError>; // name|uuid|portrait|landscape|index
    /// Best-effort BY TYPE: Ok(Placed) | Ok(Skipped { reason }) — skipped ≠ silent failure
    /// (fixes the `|| true` indistinguishability, pain point #6).
    fn move_window(&self, w: &WindowId, d: &DisplayId) -> Result<PlaceOutcome, PlaceError>;
}

// ============================== Warehouse (vertical port family, dbt) ==============================
pub trait Warehouse {
    fn manifest(&self) -> &AdapterManifest;
    fn resolve(&self, cfg: &DbConfig, dbt: Option<&DbtProject>) -> Result<Connection, WhError>;
    /// read_only enforced at the port: never fight dbt's writer lock.
    fn attach_spec(&self, c: &Connection, ro: ReadOnly) -> CommandSpec;   // harlequin launch
    fn preview(&self, c: &Connection, rel: &Relation) -> PreviewPlan;     // limit-100, not executed
}
pub trait DbtReview {                                            // bet 4, behind its own port
    fn snapshot_baseline(&self, repo: &Path) -> Result<ReviewBaseline, DbtError>;
    fn compare(&self, base: &ReviewBaseline, repo: &Path) -> Result<ReportRef, DbtError>; // cute-dbt
}
```

---

## 5. Use-case layer (what a verb actually is)

Every CLI verb is a thin shell over one use-case function with this shape:

```rust
pub struct Cide<'a> {                 // the composition root hands this to every use-case
    pub mux: &'a dyn Multiplexer,
    pub bindings: &'a PortBindings,   // resolved from IdeType.bindings (the swap table)
    pub state: &'a StateStore,        // flock + atomic-rename file store
    pub cfg: &'a ResolvedConfig,
}

pub fn space_open(cide: &Cide, name: &str, opts: &OpenOpts) -> Result<Report, CideError> {
    cide.state.catch_up(cide.mux)?;                 // mechanism C: lazy event catch-up + GC
    let space = cide.state.resolve_space(name)?;
    let plan  = plan_open(&space, &cide.cfg.preset(&space)?, cide.mux.tree()?)?;  // PURE
    execute(cide, plan)                              // emits RPCs; records ops when faked
}
```

`plan_*` functions are pure (`topology in → op-plan out`) and live in
`cide-core` with zero I/O — they are the unit-test surface and the golden-master
surface. `execute` is the only place ops hit the mux port. `--dry`/`--json`
print the plan; that *is* the machine-first verb contract (P5) — serde out the
same structs.

---

## 6. The cmux adapter: quirk vault (every hard-won fact, encapsulated)

`cide-mux-cmux` is where ALL of `cide-current-state.md §4` goes to live and
never bites again. The trait surface makes most traps unexpressible; the rest
are behaviors inside the adapter, each carrying a `// fact:` comment and a
fixture test:

| cmux fact | Encapsulation in the adapter |
|---|---|
| `workspace.list` is focused-window-only | Adapter never calls it for enumeration; `tree()` = `tree --all --id-format both` parsed once into `Topology`. The one thing `workspace.list` has that tree lacks (`current_directory`) is merged in by a secondary call **inside** `tree()`, so callers get one complete struct and the split-brain (pain #14) dies. |
| Output-format fragility (`OK <uuid>` vs `OK workspace:N`, list-windows prints UUIDs) | All parsing is in one `wire.rs` module with serde types per response shape + fixture tests generated from a live cmux (§10). The socket-v2 adapter avoids text parsing entirely where the RPC returns JSON; the CLI fallback adapter carries the `sed`-class parsers with golden fixtures. |
| Caller-workspace protection | `close_workspace` detects self via `identify()` and returns `CloseOutcome::CallerProtected { instruction: "Cmd+W" }`; use-cases order self-close last by construction. |
| Ghost windows (closing last workspace spawns a default; fresh windows leave blanks) | `create_workspace` on a fresh window does create-then-drop-default atomically inside the adapter; `close_window` verifies via `tree()` post-condition and reports `CloseOutcome::Unverified` when cmux says OK but the window persists (the known 0.64 bug). |
| UUID case inconsistency; refs die across restarts | `MuxId` normalizes on construction; serde serializes uuid-only; refs only ever derived from a live `tree()`. |
| `workspace.group.*` is within-window only | `group()` returns a capability that is **documented window-scoped**; cross-monitor coupling stays a cide-core concept (Instance), never delegated to groups. |
| Placement not CLI-controllable; AeroSpace re-tiles raw AX moves; AX grant attaches to cmux/Ghostty | Entirely outside the mux port — `Placement` port, macOS adapter prefers `aerospace move-node-to-monitor` when AeroSpace runs, AX fallback otherwise; outcome type distinguishes Placed/Skipped. |
| `read-screen` can't see TUIs; blind sends are dangerous | `send_text` requires `InjectionGuard`; tool control goes through tool adapters' proper channels (yazi DDS with `TMPDIR=$(getconf DARWIN_USER_TEMP_DIR)` — encoded in `explorer_yazi`). |
| Settle timing (Textual boot pacing, post-create send) | `wait_for`/`wait_event(deadline)` replace read-screen polling loops; the adapter offers `await_surface_ready(surface, deadline)` built on the events stream within the invocation. |
| markdown opens a SPLIT and follows the caller's window without `--window` | `open_markdown(at: &PanelTarget)` always resolves and passes the window explicitly. |
| `env VAR=val tool` shows "env" as tab title | `CommandSpec` renders launcher-script style (`hx-wrap` pattern) or schedules `rename_tab` post-spawn — adapter policy, invisible to core. |
| hooks store `workspaceId` goes stale | `agent_claude::sessions()` joins `surfaceId` against the live tree; store's workspaceId is ignored. |
| Telemetry default-on, OpenTUI npm fetch, reactGrab fetch | Surfaced by `cide doctor` (egress audit) and flipped only in consented `cide setup`. |

The adapter also owns the **capability probe**: `capabilities()` diffs the live
cmux's advertised RPC set against the pinned fidelity snapshot and warns on
drift (`cide doctor` prints it) — the fast-upgrade-cadence insurance.

---

## 7. Swapability: three concrete adapter pairs

### 7.1 Editor: helix vs neovim (the "one line of cide.toml" promise)

```rust
pub struct HelixEditor { wrap: PathBuf /* hx-wrap */ }
impl Editor for HelixEditor {
    fn launch(&self, ctx: &LaunchCtx) -> CommandSpec {
        CommandSpec::launcher(&self.wrap).arg("--as-editor").cwd(&ctx.cwd)   // push-registration
    }
    fn open(&self, t: &EditorTarget, f: &Path, io: &dyn MuxSurfaces) -> Result<(), EditorError> {
        // helix has NO remote-open socket → guarded keystroke injection is the only path.
        let screen = io.read_screen(&t.surface, ReadOpts::last_lines(3))?;
        match prompt_evidence(&screen) {
            Some(ev) => io.send_text(&t.surface, &format!(":open {}\r", f.display()),
                                     InjectionGuard::PromptVerified(ev)).map_err(Into::into),
            None     => Err(EditorError::NotAtPrompt { remedy: Remedy::RespawnEditor }),
        }
    }
    fn reload_all(&self, t, io) -> … { /* :reload-all via the same guard */ }
}

pub struct NeovimEditor { listen: SocketPathTemplate }
impl Editor for NeovimEditor {
    fn launch(&self, ctx: &LaunchCtx) -> CommandSpec {
        CommandSpec::new("nvim").arg("--listen").arg(self.listen.for_ctx(ctx))
    }
    fn open(&self, t: &EditorTarget, f: &Path, _io: &dyn MuxSurfaces) -> Result<(), EditorError> {
        // clean control channel: no injection, no guard needed, no mux involvement
        rpc_remote(&self.listen.resolve(t)?, &["--remote", &f.to_string_lossy()])
    }
}
```

The port absorbs an *asymmetric capability* (helix's missing remote channel)
without leaking it: callers say `editor.open(...)`; only the helix adapter
knows about prompt heuristics. The neovim colleague edits:

```toml
[bindings]            # in their cide.local.toml — one line, zero forks
editor = "neovim"
```

### 7.2 Runner engine: watchexec vs bacon (the Rule-of-Two seam)

```rust
impl RunnerEngine for WatchexecEngine {
    fn plan(&self, e: &CatalogEntry, repo: &RepoCtx) -> RunnerPlan {
        RunnerPlan::foreground(
            CommandSpec::new("cide").args(["run", "wrap", "--job", &e.id, "--parser", &e.parser])
                .arg("--").arg("watchexec").args(["-w", &repo.watch_glob(e), "--"]).args(&e.cmd))
    }
}
impl RunnerEngine for BaconEngine {                    // rust-dev fast-path
    fn plan(&self, e: &CatalogEntry, repo: &RepoCtx) -> RunnerPlan {
        RunnerPlan::foreground(
            CommandSpec::new("cide").args(["run", "wrap", "--job", &e.id, "--parser", "bacon-locations"])
                .arg("--").arg("bacon").arg(&e.bacon_job))
        // parser ingests .bacon-locations file events instead of stdout lines —
        // FailureParser is line- OR artifact-driven; same Diagnostic out.
    }
}
```

Both compile to *foreground commands wrapped by the same binary*, spawned into
a pane/dock control — the daemonless runner story. The dbt recipe binds
watchexec + a `dbt-build` parser (compiled-SQL paths in Diagnostics); rust-dev
binds bacon. Fix-on-red (`cide run wrap` on Red → `agent.submit_prompt`)
is engine-agnostic, inherited by every vertical: the synthesis's bet 8, free.

### 7.3 Multiplexer: socket vs CLI vs fake (one port, three transports)

- `CmuxSocketAdapter` — primary: persistent-per-invocation connection to
  `~/.local/state/cmux/cmux.sock`, v2 JSON protocol, typed requests. Fast path
  for the flow SLOs.
- `CmuxCliAdapter` — subprocess `cmux …` with the golden-fixture text parsers;
  fallback (`--mux-transport cli`) for debugging and version-skew triage.
- `FakeMux` (`cide-testkit`) — fixture-topology + scripted-response +
  **op-recording**; implements the same umbrella trait; the entire use-case
  layer runs against it. Its op log is what the ported 113-assertion golden
  master asserts against.

Same trait, demonstrably swappable, and the third impl is the testing story.

---

## 8. Live behavior, daemonless: the four flagship loops

**Runner / fix-on-red (P4, bets 7+8).** `cide run start <entry>` resolves the
catalog, spawns `RunnerPlan` into the dock control or runner pane
(`respawn-pane` if one exists). The wrapper (`cide run wrap`) is a foreground
loop: child stdout → `FailureParser` → on Red: write `state/jobs/<id>.json`,
`set_status` pill, `notify` (policy-filtered), `flash`, and — if the recipe's
`fix_on_red` behavior is on — `agent.submit_prompt` with structured
Diagnostics. cmux supervises the wrapper; closing the space kills it. No cide
process outlives its pane.

**Review queue (P2, bet 2).** Claude Code `Stop` hook (repo-local
`.claude/settings.json`, shipped by the recipe) runs `cide turn-complete`:
appends a `ReviewItem` keyed by event seq, opens `cmux diff --source last-turn
--no-focus` beside the agent. `cide review` = catch-up cursor over
`agent.hook.Stop` events (so turns that fired while no hook was installed are
*still found* — the durable log backstops the push path), then walks
Unreviewed items; commenting = `submit_prompt`. Cursor lives in
`cursors/review.json`. v1 of the synthesis's flagship explicitly "ships on
declarative notification hooks alone — never blocked on the daemon": sketch A
is that sentence, made permanent.

**Notification policy (P3).** `cmux.json → notifications.hooks` pipes every
notification through `cide policy` (stdin JSON → stdout JSON). Focus-aware
silencing uses the payload's `appFocused`/`focusedPanel`; escalation rules come
from the recipe's `behaviors`. A pure filter — the single best argument that
the platform *wants* short-lived programs.

**Fleet segment / statusline (P3).** Hook invocations (`turn-complete`,
`policy`, `run wrap`) maintain `cache/fleet.json` as a side effect. The prompt
segment (`cide statusline`) reads the file and prints `agents: 2▶ 1✋ 1💤` —
**zero socket calls, zero tree reads** on the hot path. Staleness is bounded by
"since the last hook fired," which for an active fleet is seconds.

Space open/close, jump, focus fan-out, replace, theme are plain transactions
(§5) — they never needed residency in the first place.

---

## 9. Config: analysis and recommendation

### Options considered

| Option | Verdict |
|---|---|
| **(a) Everything in `.cmux/cmux.json` `actions`/`commands`** | Rejected as the *source*. It's cmux's namespace (JSONC, trust-gated, schema owned upstream), it can't express cide's domain (spaces, bindings, catalogs, egress), and it makes cide's config hostage to cmux schema drift. It is, however, the perfect **compile target** — see below. |
| **(b) Single `cide.toml`, flat (status quo)** | Right instrument, wrong cardinality: it conflates committable team truth ("this repo is a dbt IDE") with machine truth (`[monitors]` = Christopher's DELL/LG) and personal taste (neovim, theme). The dogfood already hit this: `[monitors]` was designed and immediately wanted a different home, and `cide-theme` mutating tracked files is churn pain #10. |
| **(c) Layered project + local + user + embedded defaults** | **Recommended.** Standard tooling expectation (direnv/just/git all layer), each fact has exactly one home, and the layering rule is mechanical. |

### The recommendation: four read layers, one compile target, zero `~/.config` writes

Precedence (highest wins), all serde-merged into one `ResolvedConfig`:

```
1. $repo/cide.local.toml      machine/private truth — gitignored. [monitors], local db paths,
                              personal binding overrides for THIS repo.
2. $repo/cide.toml            committed team truth — IDE type, layout, agents, runner overrides,
                              theme default. The file a colleague edits one line of.
3. ~/.config/cide/config.toml user taste — READ if present, NEVER created or written by cide.
                              `cide setup --user` offers to create it, shows the diff, asks.
                              (Honors the constraint as written: cide never *writes* ~/.config
                              uninvited; reading a user-authored file is the user's choice.)
4. (embedded)                 recipes/*.toml, layouts/*, themes/* compiled into the binary —
                              the zero-config baseline; overridable by same-named files in
                              $repo/.cide/{recipes,layouts,themes}/ for layout/theme/recipe packs.
```

**Compile target:** `cide sync` deterministically generates the repo-local
`.cmux/cmux.json` (palette actions with keyword taxonomy, `commands[]`,
plus-button "New cide Space", per-vertical tab-bar buttons) and `.cmux/dock.json`
(runner, spaces, lazygit, btop, feed controls) from the resolved config. Marker
key `"//": "generated by cide sync — edit cide.toml"`; a user fragment
`.cmux/cmux.custom.json` is deep-merged if present so hand edits survive.
Generated files are **committed** — diffable, trust-gated by cmux, and they
work even when the binary isn't installed yet (graceful degradation for
colleagues). This is the entire daemonless wiring story: *verbs become palette
actions because cide compiles them into cmux's config, and cmux is the thing
that stays resident to serve them.*

**Global state that only lives in `~/.config/cmux/`** (shortcut chords,
telemetry flip, custom sidebar, hibernation budgets) is exclusively the job of
the explicit, consented, reversible **`cide setup`**: prints the exact diff,
asks, applies, records an undo file in `~/.local/state/cide/setup-undo/`.
Never silent, never on any other code path — mechanically enforceable because
the config writer module takes a `Consent` token only `setup` can construct.

### Example files

`cide.toml` (committed):

```toml
schema = 1

[ide]
type   = "dbt"                     # recipe name: base | dbt | rust-dev | $repo/.cide/recipes/*
name   = "cide-dbt"
layout = "landscape-portrait"

[bindings]                         # overrides over the recipe's defaults (the swap table)
# editor = "helix"                 # recipe default — shown for discoverability
# warehouse = "harlequin-duckdb"

[agents]
slots = ["builder", "reviewer"]    # N role slots (bet 5)
[agents.builder]
kind = "claude"
[agents.reviewer]
kind = "claude"
idle = true                        # spawned hibernated

[runner]
# catalog auto-detect (just/make/npm/cargo) unless overridden:
# entries = [{ id = "build", cmd = ["just", "build"], watch = ["models/**"] }]

[theme]
default = "catppuccin-mocha"
```

`cide.local.toml` (gitignored):

```toml
schema = 1
[monitors]                         # Christopher's desk, nobody else's
editor = "DELL P2725DE"            # name | UUID | portrait | landscape | index
tools  = "LG FHD"

[database]
connection = "warehouse/dev.duckdb"
read_only  = true
```

`~/.config/cide/config.toml` (user-authored, optional):

```toml
schema = 1
[bindings]
editor = "neovim"                  # the one-line swap, machine-wide
[theme]
default = "tokyonight"
```

`recipes/dbt.toml` (embedded — the vertical as data):

```toml
schema  = 1
name    = "dbt"
extends = "base"
color   = "orange"

[bindings]
warehouse = "harlequin-duckdb"
viewer    = "csvlens"

[[runner.entries]]
id = "dbt-build"; cmd = ["dbt", "build", "--select", "state:modified+"]
watch = ["models/**", "macros/**"]; parser = "dbt"

[[routing]]
match = "*.sql";  action = "editor+sibling-yml"
[[routing]]
match = "*.csv";  action = "viewer"

[behaviors]
fix_on_red      = { agent = "builder", attach = "compiled-sql" }
review_baseline = "manifest-at-checkout"          # bet 4: cute-dbt loop
focus_fanout    = ["editor", "explorer", "warehouse-preview"]
```

---

## 10. Testing strategy

Layered exactly like the architecture; the cmux port is fakeable by
construction, and the POSIX suite is the inherited behavioral spec.

1. **Pure-core unit tests** (`cide-core`): `plan_*` functions are
   `topology → op-plan`; property tests on layout compilation (every preset ×
   every binding set produces a valid plan); config-merge tests over the four
   layers.
2. **Golden master (the strangler-fig gate).** The 113-assertion POSIX suite
   asserts *emitted cmux commands*. Port: run each migrated verb against
   `FakeMux` with the same fixture topology, normalize the recorded op log to
   the suite's command-line shape, diff against the suite's expectations. A
   verb may not replace its shell twin until its golden diff is empty (or every
   delta is an annotated, intended improvement). The suite then lives on as
   `cide-testkit` fixtures.
3. **BDD integration** (`tests/features/*.feature`, cucumber-rs):
   `Given the fixture topology "two-windows-dbt" / When I run "cide space open mart-rework" / Then workspace "editor" is created in the portrait window / And the claude slot resumes checkpoint "…"`.
   Features double as the documented behavioral contract (and the colleague
   on-ramp artifact the synthesis wants published).
4. **Real-cmux fixture generation tier (G1's mandate).** A dev-only, read-only
   harness `cide-testkit gen-fixtures` captures `tree --all`, `identify`,
   `list-panes --json`, capability sets, and wire responses from a live cmux
   into `fidelity/<version>/`. Fixtures are **never hand-authored**. `FakeMux`
   replays them; CI diffs fixture sets across cmux versions (the existing
   `fidelity/` workflow, promoted).
5. **Port conformance suites** (`cide-testkit::conformance`): generic
   `fn conform_multiplexer(m: &dyn Multiplexer, fx: &FixtureSet)` etc., run (a)
   against every fake in CI always, (b) against a live cmux behind `--ignored`
   in a sacrificial scratch window (mutating tests gated, labeled, and pointed
   at a dedicated test workspace only). Publishing this crate is the "write an
   adapter, pass the suite" on-ramp.
6. **Flow SLO tests**: hyperfine harness in CI — binary cold start < 10 ms,
   `cide jump --dry` < 30 ms against FakeMux + recorded socket latencies;
   regressions block release (the synthesis's standing posture, kept honest by
   the daemonless design having exactly one latency story to test).
7. **Trust tests**: every `AdapterManifest` must declare an egress label (deny
   by default in CI); a lint greps the binary's dependency tree for network
   crates (`reqwest`, `hyper`, …) and fails if any appear — zero-egress proven
   structurally, not promised.

---

## 11. Distribution

- **One binary**, `cide`, via a Homebrew tap (`breezy-bays-labs/tap/cide`),
  built by `cargo-dist`: `aarch64-apple-darwin` + `x86_64-apple-darwin` lipo'd
  universal; `aarch64-unknown-linux-musl` built in CI from day one (it will
  lack a mux adapter until a Zellij/tmux adapter exists, but *compiling* it
  continuously is the cheap insurance that keeps Linux unprecluded).
- All recipes/layouts/themes embedded (`include_str!`) — the binary works on a
  bare machine with no repo files at all (`cide space new --type base` in any
  git repo).
- The Swift placement helper is **retired**: `cide-place-macos` binds
  CoreGraphics/AX via `objc2` in-process (kills the Xcode-CLT dependency and
  the per-call `swift` interpreter startup, pain #16). The AX permission
  attaches to the *target* app (cmux/Ghostty) per the dogfood's finding —
  documented in `cide doctor`'s placement check.
- No runtime downloads, no self-update (brew owns updates), no telemetry —
  `cide doctor` prints "network surface: gh (defensible-egress, opt-in)" and
  nothing else.
- Shell completions + man pages generated by clap at build time, shipped in
  the formula.

---

## 12. Migration path from the shell dogfood

Strangler fig, behind the existing commands; the POSIX golden master is the
permit system. Mechanism: each `bin/cide-*` script grows a 3-line preamble —
`command -v cide && [ -z "$CIDE_SHELL" ] && exec cide <verb> "$@"` — so the
binary takes over verb-by-verb, with `CIDE_SHELL=1` as the instant rollback at
every step. Shell and Rust share no state *formats*: `cide state migrate`
(R1) imports the pipe-delimited files into the serde store once, and ported
verbs read only the new store while unported shell verbs keep their own files
until their turn (verbs are ported in dependency clusters so no file is
co-written by both generations).

| Phase | Ports | Why this order |
|---|---|---|
| **R0 — skeleton** | `cide` binary, socket adapter, `cide doctor`, `cide state migrate`, fixture generator | Proves the socket client + quirk vault against live cmux with read-only verbs; zero blast radius; doctor immediately useful (egress audit, config doctor wrap, capability drift). |
| **R1 — parser killers** | `cide theme`, `cide agent ls` (vault), `cide statusline` | The three worst hand-rolled-parser sites (3× awk TOML, JSON-by-grep, session-store joins) die first; all read-mostly; theme also fixes the two `~/.config`/tracked-file violations (#9, #10) via the ApplyPlan design. |
| **R2 — guarded writes** | `cide set-role`, `cide jump`, `cide open`, `cide md-open` | First mutating verbs; small op surfaces; `InjectionGuard` and self-heal logic get golden-master parity here. `hx-wrap` stays a shell launcher but calls `cide set-role` (binary) — wrappers are adapters' launchers and may stay shell forever. |
| **R3 — the core** | `cide space new/open/close/rm/ls`, `cide place` | The big one, gated hard on golden-master parity + the live resume round-trip check. Swift helper retired here. After R3 the shell `cide-space` is a shim. |
| **R4 — Rust-only capability** | `cide sync`, `cide run` (+ wrap), `cide review`, `cide policy`, `cide replace`, `cide focus`, `cide setup` | New verbs never written in shell — runner engine (watchexec crate in-process where possible), review queue, config compiler, the cohesion bundle. The `.cmux/` smoke test graduates into `cide sync` output. |
| **R5 — verticals & retirement** | dbt recipe (`cwd focus` → `cide focus`, `cwd route` → routing data, warehouse port from hq-wrap logic), rust-dev recipe (Rule-of-Two trigger), delete shell bodies | `cwd` family folds into the dbt vertical; the POSIX suite converts to cucumber features; shell remains only as the wrapper-launcher scripts adapters own. |

Coexistence invariants: (1) every phase is independently shippable and
revertible via `CIDE_SHELL=1`; (2) tree-is-truth means generations can't
corrupt each other's view of cmux; (3) `cide doctor` reports which generation
owns each verb, so "what's running?" is never archaeology.

---

## 13. Risk register (top 5)

| # | Risk | Likelihood / impact | Mitigation |
|---|---|---|---|
| 1 | **A flagship flow turns out to be residency-shaped after all** — e.g., review-queue UX or a live spaces sidebar needs sub-100 ms reactions with no hook coverage, and catch-up semantics feel laggy in daily use. | Medium / High — this is the bet the sketch makes against synthesis bet 3. | The escape hatch is pre-designed and cheap: `cide reactor` = same binary, foreground loop on `events --reconnect --cursor-file`, deployed as a **dock control** (cmux-supervised, visible, respawnable). Ports, state files, and tests are identical; "daemon" becomes a deployment mode. Decision gate written into the plan: if two shipped loops independently need reactor mode, promote it from optional to default-on dock control — still never launchd. |
| 2 | **Hook-storm races corrupt state** — concurrent short-lived invocations (policy filter × turn-complete × run wrap) interleave writes. | Medium / Medium | Single `flock` over the state dir with sub-second hold times; atomic rename for every file; append-only JSONL for high-frequency paths (events out-pace state mutation by design); idempotent ops keyed by event seq so replays are no-ops. Conformance test: 50 parallel `cide policy` + `turn-complete` invocations, state must converge. |
| 3 | **cmux drift breaks the adapter** (fast upstream cadence; socket v2 not a stability-promised contract; the G1 bug class). | High / Medium | The fidelity tier: versioned fixtures generated from live cmux, CI diff on every upgrade; `capabilities()` probe + doctor warning at runtime; CLI fallback adapter as a second transport when the socket protocol shifts; all wire parsing in one module. Upgrade playbook: regen fixtures → diff → fix adapter → golden master still green. |
| 4 | **Startup budget erodes** — dependency creep (a TUI crate here, an async runtime there) quietly turns 8 ms into 80 ms, and the whole "every verb is a palette action / hook filter" economics collapse. | Medium / High | CI-enforced SLO (hyperfine, release-blocking, per the synthesis's posture); `cargo-deny` allowlist for new deps; the no-tokio/no-HTTP rule is written into the workspace lints; heavy interactive surfaces (a future `cide top` TUI) are feature-gated foreground modes that don't tax the hot verbs. |
| 5 | **Two-generation limbo** — the strangler migration stalls mid-way (solo founder bandwidth), leaving shell + Rust co-owned verbs and doubled maintenance, the exact fragmentation pain (#4) the rewrite exists to kill. | Medium / Medium | Phase order is value-front-loaded (R1 kills the worst parsers immediately; R4 delivers never-had capability), so every phase pays for itself; the exec-shim mechanism means zero user-facing migration cost per verb; golden master makes each port mechanical rather than judgment-heavy; explicit rule: no new shell features after R0 — new capability lands Rust-only, so the gap only ever closes. |

Honorable mentions: caller-protection/ghost-window regressions (covered by
adapter post-condition checks + fixtures); AX/TCC permission confusion on
placement (doctor check + docs); `events.jsonl` rotation gaps (gap-detecting
cursor + snapshot re-anchor, §1.A ledger #4).

---

## 14. Summary judgment (for the comparison round)

Sketch A buys: the smallest possible trusted artifact; one latency story,
CI-testable; zero lifecycle/IPC/version-skew surface; perfect alignment with
the zero-egress, greppable-files, "cmux owns rendering and transport" doctrine;
and a migration path where every step is a shell-to-binary exec swap. It
pays: catch-up semantics instead of true reactivity for unhooked events,
file-lock discipline instead of in-memory serialization, and a standing bet
against synthesis bet 3's daemon — hedged by `cide reactor` as a
cmux-supervised dock process, which keeps the daemonless invariant ("cide never
runs anything cmux can't see and supervise") even in the escape hatch. The
multiplexer is the supervisor; cide is the meaning, compiled on demand.
