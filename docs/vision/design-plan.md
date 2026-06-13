# cide Design Plan — the Daemonless Library-First Single Binary

> The engineering companion to [product-vision.md](product-vision.md). That document owns
> *what* cide is and *why* anyone wants it (pillars P1–P7, ranked bets, day-in-the-life);
> this document owns *how it is built* and proves the vision is buildable by a solo founder.
> Spine: [research/arch-decision.md](research/arch-decision.md) (Sketch A wins, grafts g1–g7
> binding), [research/arch-sketch-a.md](research/arch-sketch-a.md) (the winning design),
> with mechanisms imported from [research/arch-sketch-b.md](research/arch-sketch-b.md).
> Every hard-won cmux fact in [research/cide-current-state.md](research/cide-current-state.md) §4
> is a mandatory design input here, not trivia. Settled decisions in
> [research/prior-decisions.md](research/prior-decisions.md) are honored, never re-litigated.
> 2026-06-09.

---

## 1. Architecture overview

**Philosophy: the multiplexer IS the supervisor.** cmux is already a long-lived,
crash-recovering, event-sourcing process supervisor with durable append-only logs
(`events.jsonl`, `workstream.jsonl`, agent session stores), a cursorable replay contract
(`events.stream --after <seq> --cursor-file`, `ack.resume.gap` → snapshot refresh), a hook
pipeline that pushes control to external programs at exactly the moments that matter, and
native supervision for anything resident (panes, dock controls, `respawn-pane`, session
restore). cide does not build a second one. Three mechanisms replace residency
([research/arch-sketch-a.md](research/arch-sketch-a.md) §1):

- **Verbs as transactions.** Every invocation: read durable truth (`tree --all`, cmux
  stores, cide state, event-cursor catch-up) → decide in the pure core → emit socket RPCs →
  write state atomically → exit. Tree is truth; the store is a cache; staleness between
  invocations is harmless by construction.
- **Residency by proxy.** Anything that must stay alive runs as a *foreground process of
  the same binary inside a cmux pane or dock control* (`cide run wrap -- watchexec …`).
  cmux supervises, respawns, themes, and resource-accounts it; it dies with its workspace.
  The user can see every live cide process — visibility is part of the trust posture.
- **Reactivity by hooks + catch-up.** Time-critical reactions ride push (Claude `Stop`
  hook → `cide turn-complete`; `notifications.hooks` → `cide policy`, a stdin→stdout
  filter). Everything else is eventually-correct-on-invocation via cheap cursor catch-up
  over `events.jsonl`. The durable log guarantees nothing is lost in between.

**Why this beat the supervisor sketch** (full scorecard: 6–1–1 for A in
[research/arch-decision.md](research/arch-decision.md) §1–2):

1. **B = A + supervisor, permanently.** Sketch B's own scope firewall ("every verb has a
   supervisor-less path") obligated building the whole of Sketch A anyway, then maintaining
   a lifecycle subsystem on top — lazy-spawn flocks, stale-socket handshakes, version
   negotiation, idle-exit, four `supervisor *` commands that manage the architecture
   instead of the product. A hard fail against the solo-maintainer constraint.
2. **B's consolidation premise was wrong on the facts.** The dock loops it proposed to
   consolidate are already *cmux-supervised* — visible, restartable, space-scoped. B moved
   work out of supervision that exists into supervision that must be written, and weakened
   the zero-egress story ("everything cide runs is a pane you can see").
3. **Crash safety by construction vs by design-and-test.** A short-lived verb dies leaving
   an atomic-rename file old or new; the next verb re-resolves from the live tree. B's
   crash story was well designed, but against failure modes (dual-supervisor races,
   post-upgrade socket skew, zombie jobs) that A simply does not have.
4. **B's one won criterion was narrow and recoverable.** Its continuous-reaction edge sits
   below user-perceptible thresholds given tree-is-truth verbs, is backstopped by the
   durable log, and is recoverable through A's own escape hatch.

**The promotion-gated reactor.** The escape hatch is pre-built and is not an architecture
change: `cide reactor` — the same binary in a loop on `cmux events --reconnect
--cursor-file` — deployed as a **cmux-supervised dock control**, never launchd, never a
UDS server. Its lifecycle spec is pre-written (graft g3, §7 below). The gate: **if two
shipped loops independently need reactor-mode reactions, the reactor is promoted to a
default-on dock control.** Until then it does not exist. Reopening "should cide have a
daemon?" before the gate trips starts by re-reading
[research/arch-decision.md](research/arch-decision.md), not the question.

---

## 2. Crate layout + domain model

The locked four-crate DAG (`cide-core` / `cide-adapters` / `cide-dbt` / `cide`,
[research/prior-decisions.md](research/prior-decisions.md) §2) is preserved as the
dependency spine; the architecture decision adds compilation-unit splits that respect it
(`cide-mux-cmux`, `cide-place-macos`, `cide-testkit`) plus the frozen contract crate
`cide-json` (graft g4):

```
cmux-ide/                          # repo, post-rename (executed at Cargo-scaffolding time)
├── Cargo.toml                     # [workspace], unified version, resolver = "2"
├── crates/
│   ├── cide-core/                 # THE HEXAGON: domain + ports + use-cases + config resolver.
│   │   ├── src/domain/            #   ids, space, instance, layout, role, runner, agent,
│   │   │                          #   review, theme, egress, vertical
│   │   ├── src/ports/             #   mux, editor, explorer, vcs, runner, agent, theme,
│   │   │                          #   placement, warehouse, notify
│   │   ├── src/usecases/          #   space_*, jump, open, focus, review, run, policy, sync
│   │   └── src/config/            #   layered loader + recipe loader (serde)
│   │   # deps: serde, toml, thiserror. NO I/O, NO process spawn, NO sockets.
│   ├── cide-json/                 # g4: FROZEN --json contract structs. deps: serde only.
│   ├── cide-mux-cmux/             # Multiplexer port: socket-v2 adapter (primary) + CLI
│   │                              # adapter (fallback) + the quirk vault (§4)
│   ├── cide-adapters/             # one feature-gated module per tool: editor_helix,
│   │                              # editor_neovim, explorer_yazi, vcs_lazygit, vcs_tig,
│   │                              # runner_watchexec, runner_bacon, agent_claude,
│   │                              # agent_codex, warehouse_harlequin, diff_multi, theme
│   ├── cide-dbt/                  # dbt vertical ADAPTER CODE only (Warehouse, DbtReview,
│   │                              # dbt catalog/parser). The dbt recipe itself is data.
│   ├── cide-place-macos/          # Placement adapter: CoreGraphics + AX via objc2,
│   │                              # AeroSpace cooperation. cfg(target_os = "macos").
│   ├── cide-testkit/              # FakeMux, fixture replayers, conformance suites,
│   │                              # replay server, golden-master harness
│   └── cide/                      # the binary: clap + composition root ONLY
├── recipes/                       # VERTICALS AS DATA: base.toml, dbt.toml, rust-dev.toml
├── layouts/                       # presets: cmux-native JSON with capability-token leaves
├── themes/                        # name-map theme packs
└── tests/features/                # BDD .feature files
```

Dependency rule, CI-enforced: `cide-core` depends on nothing in the workspace; adapters
depend on core (and `cide-json` where they serialize output); the binary depends on
everything; nothing depends on the binary. **Workspace dependency budget** (hard
lightweight requirement): `clap`, `serde`, `serde_json`, `toml`, `thiserror`, `jiff`,
`uuid` (default-features off — `MuxId` carries one), `rustix` (std exposes no `flock`),
`url`, `objc2` (macOS only). No tokio, no HTTP client of any kind (zero-egress is
structural), no sqlite — state is flat files + JSONL, greppable. The `cargo-deny`
allowlist that blocks creep is scoped to the **shipped binary's normal dependency graph**
(`exclude-dev`) — the explicit carve-out for cucumber-rs's dev-only async stack (§8.6),
so the gate neither fails the R1 build nor gets quietly weakened (risk #4's erosion mode).

**`cide-json` (g4).** A tiny crate holding the versioned `--json` output structs — the
machine-first public contract (synthesis P5/bet 12) — deliberately decoupled from
`cide-core` domain types so internal refactors cannot silently break agent consumers.
Domain → contract conversion is explicit `From` impls in the binary. The crate is the
thing agents and skills pin against; its schema carries a version field and a documented
deprecation policy (open question #5, §12).

### Core domain types (condensed from [research/arch-sketch-a.md](research/arch-sketch-a.md) §3)

```rust
// identity — refs are positional and die across restarts; UUIDs survive.
// Persistence ALWAYS serializes the UUID (normalized); refs derived live, never stored.
pub struct MuxId { pub uuid: Uuid, pub ref_hint: Option<RefHint> }
pub struct WindowId(pub MuxId);  pub struct WorkspaceId(pub MuxId);
pub struct PaneId(pub MuxId);    pub struct SurfaceId(pub MuxId);

// vertical = a RECIPE: pure data loaded from TOML, never a code fork
pub struct IdeType {
    pub name: String,                            // "base" | "dbt" | "rust-dev" | user-defined
    pub extends: Option<String>,                 // composition: dbt = base ⊕ {…}
    pub layout: LayoutPresetRef,
    pub bindings: BTreeMap<PortKind, AdapterId>, // port → adapter (the swap table)
    pub runner_catalog: Vec<CatalogEntry>,       // detection rules + commands + parser id
    pub routing: Vec<RouteRule>,                 // "*.sql" → editor+sibling-yml, …
    pub behaviors: Behaviors,                    // fix_on_red, review_baseline, focus_fanout
    pub color: Option<WorkspaceColor>,           // dbt = orange, rust = red
}

// layout as data: cmux-native nested JSON, except leaves carry CAPABILITY TOKENS.
// The bound adapter compiles Capability::Editor → `hx-wrap --as-editor` (helix)
// or `nvim --listen …` (neovim). This is the layout-pack swap seam.
pub struct LayoutPreset { pub name: String, pub windows: Vec<WindowPlan> }
pub struct WindowPlan { pub role: WindowRole, pub orientation: Orientation, pub tree: LayoutNode }
pub enum LayoutNode {
    Split { direction: Direction, ratio: f32, children: Vec<LayoutNode> },
    Pane  { surfaces: Vec<SurfaceSpec> },
}
pub struct SurfaceSpec { pub capability: Capability, pub name: Option<String> }

pub enum WindowRole { Editor, Tools }            // window-grained
pub struct AgentRole(pub String);                // surface-grained: "builder", "reviewer"

// instance = named, self-healing coupling of N workspaces across monitors;
// space = lifecycle-managed instantiation of a preset — THE unit of work (P1)
pub struct Instance { pub name: String, pub members: BTreeMap<WindowRole, WorkspaceId> }
pub struct Space {
    pub id: SpaceId, pub name: String, pub ide_type: String,
    pub repo: PathBuf, pub worktree: Option<PathBuf>,
    pub state: SpaceState,                       // Open { members } | Closed { snapshot }
    pub agents: Vec<AgentSlot>,
    pub resume_stamps: Vec<ResumeStamp>,         // non-agent surfaces: harlequin, runners
    pub baseline: Option<ReviewBaseline>,        // dbt manifest snapshot at branch checkout
}

pub struct AgentSlot {
    pub role: AgentRole, pub kind: AgentKind, pub label: AgentLabel,
    pub checkpoint: Option<CheckpointId>,        // durable key; cide READS, never writes
    pub surface: Option<SurfaceId>,              // resolved from live tree, never trusted
    pub lifecycle: AgentLifecycle,               // Running | Idle | NeedsInput
}

pub struct RunnerJob { pub id: JobId, pub entry: CatalogEntry,
                       pub surface: SurfaceId, pub status: RunnerStatus }
pub struct Diagnostic {                          // what fix-on-red sends — never pasted ANSI
    pub file: PathBuf, pub line: Option<u32>, pub message: String,
    pub artifact: Option<PathBuf>,               // compiled-SQL path | .bacon-locations
}

pub struct ReviewItem { pub space: SpaceId, pub agent: AgentRole,
                        pub turn_seq: u64, pub state: ReviewState }
pub struct EventCursor { pub seq: u64, pub log_generation: u64 }   // gap-detecting

pub enum EgressLabel { Zero, DefensibleEgress { why: String }, TelemetryDisabledVerified }
pub struct AdapterManifest { pub id: AdapterId, pub port: PortKind,
                             pub required_tools: Vec<ToolRequirement>, pub egress: EgressLabel }
```

State on disk (`~/.local/state/cide/`): `spaces/<id>/space.toml`, `registry.toml`,
`cursors/*.json`, `cache/fleet.json` (hook-maintained; statusline reads it socket-free),
`agents.jsonl`. All flat, atomic-rename-written, `flock`-guarded, `schema = 1` versioned.
This replaces the pipe-delimited shell files (dogfood pains #3/#5,
[research/cide-current-state.md](research/cide-current-state.md) §6) via a per-family,
re-runnable import (§9).

---

## 3. Ports & adapters

Design rules: (1) ports are **role-shaped, not tool-shaped**; (2) adapters never call each
other — a tool adapter needing the multiplexer receives a **narrowed capability handle**
(`&dyn MuxSurfaces`), so an Editor adapter physically cannot close workspaces; (3) every
adapter ships an `AdapterManifest` with an egress label; (4) everything is **sync and
object-safe** — cmux is request/response over a unix socket, so blocking I/O is correct,
`dyn` works, and no AFIT/`trait_variant` machinery is needed (a scored differentiator vs
Sketch B's one fat async trait, [research/arch-decision.md](research/arch-decision.md) §2.2).
(Naming note: earlier research vocabulary — `CmuxPort`, `WorkspaceHost`, `DbtReviewPort` —
resolves to the final trait names `Multiplexer` and `DbtReview` below; same seams, settled here.)

```rust
// ===== Multiplexer: seven narrow capability traits under an umbrella supertrait =====
pub trait MuxTopology {
    fn tree(&self) -> Result<Topology, MuxError>;     // ALWAYS global (tree --all); the
                                                      // workspace.list trap is unexpressible
    fn identify(&self) -> Result<Identity, MuxError>; // caller vs focused
    // + find_window (--content goto), sidebar_snapshot (dashboard data, no scraping)
}
pub trait MuxWorkspaces {
    fn create_workspace(&self, w: &WindowTarget, s: &WorkspaceSpec) -> Result<WorkspaceId, MuxError>;
    fn close_workspace(&self, id: &WorkspaceId) -> Result<CloseOutcome, MuxError>;
    fn tag(&self, id: &WorkspaceId, tag: &CideTag) -> Result<(), MuxError>;
    fn group(&self) -> Option<&dyn MuxGroups>;        // capability-gated; within-window only
    // + new_window, close_window (post-condition-verified), set_color
}
pub trait MuxSurfaces {
    fn send_text(&self, s: &SurfaceId, text: &str, g: InjectionGuard) -> Result<(), MuxError>;
    fn prompt_submit(&self, ws: &WorkspaceId, p: &PromptText)  // workspace.prompt_submit RPC —
        -> Result<(), MuxError>;                               // the proper agent-delivery channel
    fn read_screen(&self, s: &SurfaceId, o: ReadOpts) -> Result<Screen, MuxError>;
    fn respawn(&self, s: &SurfaceId, cmd: Option<&CommandSpec>) -> Result<(), MuxError>;
    fn pipe_pane(&self, s: &SurfaceId, cmd: &CommandSpec) -> Result<(), MuxError>;
    fn resume_stamp(&self, s: &SurfaceId, st: &ResumeStamp) -> Result<(), MuxError>;
    // + new_surface, wait_for(SyncToken, Timeout), rename_tab
}
pub enum InjectionGuard {            // blind injection is unrepresentable (the yazi
    PromptVerified(PromptEvidence),  // file-deletion incident, encoded as a type)
    FreshSpawn(SurfaceId),
}
pub trait MuxAttention {                       // the P3 surface: pills, progress, attention
    fn set_status(&self, ws: &WorkspaceId, p: &StatusPill) -> Result<(), MuxError>;
    fn notify(&self, n: &Notification) -> Result<(), MuxError>;
    fn flash(&self, t: &FlashTarget) -> Result<(), MuxError>;
    // + set_progress, mark_unread
}
pub trait MuxEvents {
    /// Short-lived catch-up: read after cursor, advance, return. Gap (log rotation,
    /// slow-consumer drop) is IN the error type → callers must re-snapshot + re-anchor.
    fn catch_up(&self, c: &mut EventCursor, f: &EventFilter) -> Result<Vec<MuxEvent>, CatchUpError>;
    /// Bounded blocking wait for in-verb barriers. NEVER long-lived: deadline mandatory.
    fn wait_event(&self, f: &EventFilter, d: Deadline) -> Result<MuxEvent, MuxError>;
}
pub trait MuxFeed {                  // the P3 fleet surface backlog #10 names explicitly
    fn feed_list(&self, f: &FeedFilter) -> Result<Vec<FeedItem>, MuxError>;   // feed.list
    fn feed_jump(&self, item: &FeedItemId) -> Result<(), MuxError>;           // feed.jump
    fn workstream(&self, since: &EventCursor) -> Result<Vec<WorkstreamEntry>, MuxError>;
    // read-only over ~/.cmuxterm/workstream.jsonl; partial coverage also derivable from
    // feed.item.* events in events.jsonl (cmux-api-surface.md §4, §15). The triage
    // cockpit's --next-blocked walk and `cide agent log --today` ride this port.
}
pub trait MuxViewers {
    fn open_markdown(&self, p: &Path, at: &PanelTarget) -> Result<SurfaceId, MuxError>;
    fn open_diff(&self, spec: &DiffSpec) -> Result<SurfaceId, MuxError>;  // unstaged|staged|
    fn open_browser(&self, u: &Url, at: &PanelTarget, css: Option<&Css>)  // branch|last-turn|stdin
        -> Result<SurfaceId, MuxError>;
}
pub trait Multiplexer:
    MuxTopology + MuxWorkspaces + MuxSurfaces + MuxAttention + MuxEvents + MuxFeed + MuxViewers
{
    fn capabilities(&self) -> &CapabilitySet;   // probed once per invocation
    fn manifest(&self) -> &AdapterManifest;
}

// ===== Tool ports =====
pub trait Editor {
    fn manifest(&self) -> &AdapterManifest;
    fn launch(&self, ctx: &LaunchCtx) -> CommandSpec;   // compiled into Capability::Editor leaves
    fn open(&self, t: &EditorTarget, f: &Path, io: &dyn MuxSurfaces) -> Result<(), EditorError>;
    fn liveness(&self, t: &EditorTarget, io: &dyn MuxSurfaces) -> Result<Liveness, EditorError>;
    // + write_all / reload_all — the atomic `cide replace` (write-all → serpl → reload-all)
}
pub trait Explorer {
    fn manifest(&self) -> &AdapterManifest;
    fn launch(&self, ctx: &LaunchCtx) -> CommandSpec;   // yazi --client-id …
    fn reveal(&self, t: &ExplorerTarget, p: &Path) -> Result<(), ExplorerError>; // DDS, never keys
}
pub trait Vcs {
    fn manifest(&self) -> &AdapterManifest;
    fn porcelain(&self, ctx: &LaunchCtx) -> CommandSpec;      // lazygit (default)
    fn history(&self, ctx: &LaunchCtx) -> CommandSpec;        // tig
    fn blame_journey(&self, f: &Path, line: u32) -> JourneyPlan;   // blame→diff→history
    fn merge_base_diff(&self, repo: &Path) -> Result<PatchRef, VcsError>; // review/merge-back
}
pub trait RunnerEngine {
    fn manifest(&self) -> &AdapterManifest;
    fn plan(&self, e: &CatalogEntry, repo: &RepoCtx) -> RunnerPlan;  // ALWAYS wrapped (§6)
}
pub trait FailureParser { fn feed(&mut self, line: &str) -> Option<ParsedEvent>; }
pub trait RunnerCatalog { fn detect(&self, repo: &RepoCtx) -> Vec<CatalogEntry>; }
pub trait Agent {
    fn manifest(&self) -> &AdapterManifest;
    fn kind(&self) -> AgentKind;
    fn launch(&self, label: &AgentLabel, resume: Option<&CheckpointId>) -> CommandSpec;
    fn sessions(&self, store_dir: &Path) -> Result<Vec<AgentSession>, AgentError>; // read-only
    fn ensure_hooks(&self) -> HooksRequirement;
    fn submit_prompt(&self, s: &SurfaceId, p: &StructuredPrompt, io: &dyn MuxSurfaces)
        -> Result<(), AgentError>;  // fix-on-red delivery: prefers io.prompt_submit (the
                                    // proper control channel, prior-decisions §17); falls
                                    // back to InjectionGuard-ed send_text ONLY where the
                                    // RPC is capability-absent
}
pub trait ThemeTarget {
    fn manifest(&self) -> &AdapterManifest;
    fn apply(&self, theme: &ThemePack) -> Result<ApplyPlan, ThemeError>;
    // ApplyPlan = edits in cide-managed dirs + mux RPCs. ~/.config writes are
    // unrepresentable in the type — fixes live violations #9/#10.
}
pub trait Placement {
    fn manifest(&self) -> &AdapterManifest;
    fn displays(&self) -> Result<Vec<Display>, PlaceError>;
    fn resolve(&self, r: &MonitorRef) -> Result<DisplayId, PlaceError>; // name|uuid|portrait|…
    fn move_window(&self, w: &WindowId, d: &DisplayId) -> Result<PlaceOutcome, PlaceError>;
    // Ok(Placed) | Ok(Skipped { reason }) — best-effort is typed, never silent (pain #6)
}
pub trait Warehouse {
    fn manifest(&self) -> &AdapterManifest;
    fn resolve(&self, cfg: &DbConfig, dbt: Option<&DbtProject>) -> Result<Connection, WhError>;
    fn attach_spec(&self, c: &Connection, ro: ReadOnly) -> CommandSpec;  // harlequin launch
    fn preview(&self, c: &Connection, rel: &Relation) -> PreviewPlan;    // LIMIT 100, not run
}
pub trait DbtReview {
    fn manifest(&self) -> &AdapterManifest;  // egress label: zero (network-block CI proven)
    fn snapshot_baseline(&self, repo: &Path) -> Result<ReviewBaseline, DbtError>;
    fn compare(&self, base: &ReviewBaseline, repo: &Path) -> Result<ReportRef, DbtError>; // cute-dbt
}
// FailureParser / RunnerCatalog are intentionally manifest-free: in-process strategy
// objects owned by an adapter, not adapters themselves.
```

### Three concrete swaps

- **`vcs.porcelain = "gitui"`** — one line in any config layer. The `Vcs` port returns a
  `CommandSpec`; lazygit and gitui are both "launch a TUI in the tools pane" adapters, so
  the swap is purely a binding edit. Honesty: gitui was *dropped from v1 defaults* (likely
  unmaintained, no parent-blame loop — [research/prior-decisions.md](research/prior-decisions.md)
  §10); the seam is exactly what makes that a cheap product default rather than a hard
  dependency, revisable without touching core.
- **Warehouse swap** — `warehouse = "harlequin-duckdb"` is the dbt recipe default;
  `attach_spec` is just a `CommandSpec`, so any SQL TUI taking a connection argument
  (or a future `harlequin-sqlite`, or a usql adapter) implements the same three methods.
  `read_only` is enforced at the port: nothing can fight dbt's writer lock.
- **`RunnerEngine`: watchexec vs bacon** — the Rule-of-Two seam. Both compile to a
  foreground command wrapped by `cide run wrap` (§6); the difference is the parser:
  watchexec's is line-driven over piped stdout, bacon's ingests `.bacon-locations`
  artifact events. Same `Diagnostic` out; fix-on-red is engine-agnostic and inherited by
  every vertical.

### Trust labels and the conformance kit

Every adapter declares an `EgressLabel`; CI rejects adapters without one. `cide doctor`
aggregates the *bound* adapter set and prints **cide's own** exact network surface — for
the default bindings, one line: `gh (defensible-egress, opt-in)` — **plus a
cmux-substrate section**, since the claim is falsifiable if it scopes only cide's
adapters: telemetry still off (setup flips it; doctor proves it stayed flipped), the
generated Feed dock control on `--legacy` (OpenTUI's first run fetches `@opentui/core`
from npm — cide never generates it), and `browser.reactGrabVersion`'s pinned helper fetch
([research/cmux-api-surface.md](research/cmux-api-surface.md) §11, §20). The egress ladder
([research/prior-decisions.md](research/prior-decisions.md) §13), made mechanical (P7).

The **port conformance kit** (`cide-testkit`) ships generic suites —
`fn conform_multiplexer(m: &dyn Multiplexer, fx: &FixtureSet)` and siblings per port —
run against every fake in CI always, against the recorded replay server for the socket
adapter (g7, §8), and against a live cmux behind `--ignored` in a sacrificial scratch
window. Golden fixtures are **generated from a real cmux, never hand-authored** (G1's
mandate). Publishing the kit is the colleague on-ramp: "write an adapter, pass the suite."

---

## 4. The cmux adapter (`cide-mux-cmux`)

The quirk vault: every hard-won fact from
[research/cide-current-state.md](research/cide-current-state.md) §4 lives here, each with
a `// fact:` comment and a fixture test, and **nowhere else**. The trait surface makes
most traps unexpressible; the rest are adapter-internal behaviors:

| cmux fact (paid for live) | Encapsulation |
|---|---|
| `workspace.list` is focused-window-only | The port has no scoped listing. `tree()` = `tree --all --id-format both` parsed once; the one field tree lacks (`current_directory`) is merged in by a secondary call *inside* the adapter — callers get one complete `Topology`, and the dogfood's scoping split-brain (pain #14) dies. |
| `OK <uuid>` vs `OK workspace:N` output formats; `list-windows` prints UUIDs | All wire parsing in one `wire.rs` module: serde types per response shape, fixture tests generated from live cmux. The socket-v2 adapter avoids text parsing where the RPC returns JSON; the CLI fallback carries the pinned text parsers. |
| Caller-workspace protection | `close_workspace` detects self via `identify()` → `CloseOutcome::CallerProtected { instruction: "Cmd+W" }` — typed, never an error; use-cases order self-close last by construction. |
| Ghost windows (closing last workspace spawns a default; fresh windows leave blanks) | `create_workspace` on a fresh window does create-then-drop-default atomically; `close_window` verifies via post-condition `tree()` and reports `CloseOutcome::Unverified` for the known 0.64 close-window bug. |
| UUID case inconsistency; refs die across restarts | `MuxId` normalizes on construction; serde serializes UUID-only; refs derived only from a live tree. |
| `workspace.group.*` is within-window only | `group()` returns a capability documented window-scoped; cross-monitor coupling stays `Instance` in core, never delegated to groups. |
| AeroSpace re-tiles raw AX moves; AX grant attaches to cmux/Ghostty | Outside this port entirely — the `Placement` port; the macOS adapter prefers `aerospace move-node-to-monitor` when AeroSpace runs, raw AX otherwise. |
| `read-screen` can't see TUIs; blind sends once deleted a tracked file | `send_text` requires `InjectionGuard`; tool control goes through proper channels (yazi DDS with the `DARWIN_USER_TEMP_DIR` fix, encoded in `explorer_yazi`). |
| Settle timing (Textual boot pacing) | `wait_for` / `wait_event(deadline)` replace read-screen polling loops. |
| `markdown open` splits follow the caller's window | `open_markdown(at: &PanelTarget)` resolves and passes `--window` explicitly, always. |
| `env VAR=val tool` titles the tab "env"; hook store `workspaceId` goes stale | `CommandSpec` renders launcher-script style (or `rename_tab` post-spawn); `agent_claude::sessions()` joins `surfaceId` against the live tree, ignoring the stale field. |
| `cmux popup` is an unsupported tmux-compat placeholder — no floating panes in 0.64.x | `CapabilitySet` reports no popup capability; git-TUI popup UX compiles to split/zoom pane by design ([research/prior-decisions.md](research/prior-decisions.md) §10) until upstream ships floating panes. |
| `identify --surface <arg>` ignores the arg; `surface-health` reports only `in_window` | The port offers no surface-scoped identify; liveness derives from `tree()` + each tool port's own `liveness` check, never from `surface-health`. |
| `direction:"horizontal"` = side-by-side columns; `"vertical"` = stacked rows — verified, easy to invert | The layout compiler's `Split` direction semantics are pinned by a fixture test against a captured real-cmux layout, never asserted from memory. |

One adjacent fact bounds backlog #7's `cide capture-layout`: live capture recovers the
exact split tree + ratios (`list-panes` pixel frames) but **not per-surface launch
commands** (cmux stores only tab titles) — capture reconstructs commands from cide's own
capability→launcher mapping, never from cmux
([research/cide-current-state.md](research/cide-current-state.md) §4, [research/prior-decisions.md](research/prior-decisions.md) §11).

**Transports.** `CmuxSocketAdapter` (primary): per-invocation connection to
`~/.local/state/cmux/cmux.sock`, v2 JSON protocol, typed requests — the flow-SLO path
(P6: cold start < 10 ms, `cide jump --dry` < 30 ms, space-switch sub-second — numeric
budgets from [research/arch-sketch-a.md](research/arch-sketch-a.md) §10 and
[research/arch-decision.md](research/arch-decision.md); all hyperfine-tested in CI as
**release blockers**, the posture [research/base-vision-synthesis.md](research/base-vision-synthesis.md) §5 sets).
`CmuxCliAdapter` (fallback, `--mux-transport cli`): subprocess `cmux …` with golden-fixture
parsers — the cheapest oracle when the socket protocol drifts. `FakeMux` (testkit):
fixture topology + scripted responses + **op recording**; the third impl *is* the testing
story.

**Conformance in CI (g7).** The same conformance assertions run against
`CmuxSocketAdapter` over a **recorded replay server**, so the primary transport has CI
coverage without a live cmux; the live `--ignored` tier remains for fidelity generation.
The adapter also owns the **capability probe**: `capabilities()` diffs the live cmux's
advertised RPC set against the pinned fidelity snapshot; `cide doctor` prints drift —
the fast-upstream-cadence insurance (0.64.10 → 0.64.12 was additive, but the cadence is
fast: [research/cide-current-state.md](research/cide-current-state.md) §4).

---

## 5. Configuration UX

**Recommendation: layered read model, one compile target, zero `~/.config` writes**
(both sketches converged here; analysis in [research/arch-sketch-a.md](research/arch-sketch-a.md) §9).
A single flat `cide.toml` conflates committable team truth with machine truth
(`[monitors]` is Christopher's desk) and personal taste — the dogfood already hit this;
hosting config inside `cmux.json` makes cide hostage to cmux's schema. So: layered TOML,
serde-merged into one `ResolvedConfig`, precedence lowest → highest:

```
1. (embedded)                  recipes/*.toml, layouts/*, themes/* compiled in — the
                               zero-config baseline; overridable via $repo/.cide/{recipes,…}
2. ~/.config/cide/config.toml  user taste — READ if present, NEVER created or written.
                               (Honors the constraint as written: it is a write rule;
                               reading a user-authored file is the user's choice.)
3. $repo/cide.toml             committed team truth — type, layout, agents, bindings.
                               The file a colleague edits one line of.
4. $repo/cide.local.toml       gitignored machine truth — [monitors], local db paths.
5. CIDE_* env  >  CLI flags    highest; for scripts and one-shots.
```

**Ownership split.** `cide.toml` owns *cide semantics* (spaces, bindings, catalogs,
agents, behaviors). `cmux.json` owns *cmux-side surfaces* — and cide **generates** them:
`cide sync` deterministically compiles the resolved config into repo-local
`.cmux/cmux.json` (palette actions with keyword taxonomy, `commands[]`, plus-button
"New cide Space", per-vertical tab-bar buttons) and `.cmux/dock.json` (runner, spaces,
lazygit, btop, feed controls — the feed control is generated `--legacy`, never the
OpenTUI mode whose first run fetches npm; doctor audits this, §3), with a generated-by marker and a deep-merged
`.cmux/cmux.custom.json` user fragment so hand edits survive. This is the daemonless
wiring story: *verbs become palette actions because cide compiles them into cmux's
config, and cmux is the thing that stays resident to serve them.* The few genuinely
global writes (`~/.config/cmux/` shortcut chords, telemetry flip-off — it defaults **on**
upstream, [research/cmux-api-surface.md](research/cmux-api-surface.md) §11) happen only
inside the explicit, diff-shown, consented, reversible `cide setup`, mechanically
enforced: the config-writer module takes a `Consent` token only `setup` can construct.

**Provenance in doctor (g5).** `cide doctor` prints, for every effective key, which layer
it came from — `bindings.editor = "neovim"  (user: ~/.config/cide/config.toml)` — so
"why is it doing that?" is never archaeology.

Example files (full versions in [research/arch-sketch-a.md](research/arch-sketch-a.md) §9):

```toml
# $repo/cide.toml (committed)
schema = 1
[ide]      type = "dbt"  name = "cide-dbt"  layout = "landscape-portrait"
[bindings] # overrides over the recipe defaults — the swap table
[agents]   slots = ["builder", "reviewer"]
[runner]   # catalog auto-detect (just/make/npm/cargo) unless overridden
[theme]    default = "catppuccin-mocha"

# $repo/cide.local.toml (gitignored)
[monitors] editor = "DELL P2725DE"  tools = "LG FHD"
[database] connection = "warehouse/dev.duckdb"  read_only = true

# recipes/dbt.toml (embedded — the vertical as data)
name = "dbt"  extends = "base"  color = "orange"
[bindings]  warehouse = "harlequin-duckdb"  viewer = "csvlens"
[[runner.entries]]
id = "dbt-build"; cmd = ["dbt", "build", "--select", "state:modified+"]
watch = ["models/**", "macros/**"]; parser = "dbt"
[behaviors]
fix_on_red = { agent = "builder", attach = "compiled-sql" }
review_baseline = "manifest-at-checkout"
```

---

## 6. Runner engine (#23)

The keystone of backlog #1 ([research/opportunity-backlog.md](research/opportunity-backlog.md))
and the first never-existed-in-shell capability. One resolved note overrides the original
task-#23 phrasing: **`cide run wrap` wraps the external `watchexec` binary — never
watchexec-as-library** — the crate drags in tokio and breaks the no-runtime dependency
budget ([research/arch-decision.md](research/arch-decision.md) §2.4). If an in-process
watcher is ever wanted, the sync-capable `notify` crate inside the wrap process is the
sanctioned path. The budget holds either way.

- **Catalog detect.** `RunnerCatalog::detect` recognizes `just` / `make` / `npm` /
  `cargo` in the base recipe; vertical recipes contribute data entries — dbt's
  `dbt build --select state:modified+` with the `dbt` parser (compiled-SQL paths into
  `Diagnostic.artifact`), rust-dev's cargo/nextest entries. `[runner]` in `cide.toml`
  overrides everything.
- **bacon fast-path.** Cargo repos bind `BaconEngine`: same wrap, parser ingests
  `.bacon-locations` file events instead of stdout lines. `FailureParser` is line- *or*
  artifact-driven; identical `Diagnostic` out.
- **Composition, not construction.** The job runs as a foreground process in cmux's
  **Dock** (default home pending the open fork, §12) or a layout pane; palette actions
  start/restart it; the **Feed** is notify-on-finish (replacing the #25 notify stub —
  settled). `respawn-pane` is one-key restart; cmux owns the lifecycle; the job dies with
  its space.

```rust
impl RunnerEngine for WatchexecEngine {
    fn plan(&self, e: &CatalogEntry, repo: &RepoCtx) -> RunnerPlan {
        RunnerPlan::foreground(
            CommandSpec::new("cide").args(["run", "wrap", "--job", &e.id, "--parser", &e.parser])
                .arg("--")
                .arg("watchexec").args(["-w", &repo.watch_glob(e), "--"]).args(&e.cmd))
    }
}
```

`cide run wrap` is mechanism B incarnate: a foreground loop — child stdout (or
`pipe-pane`-delivered text) → `FailureParser` → on Red: write `state/jobs/<id>.json`,
`set_status` pill, policy-filtered `notify`, `flash`; on Green: clear. If the recipe's
`fix_on_red` behavior is on, it calls `Agent::submit_prompt` with structured
`Diagnostic`s — file:line plus artifact path, never pasted ANSI (P4), delivered over the
`workspace.prompt_submit` RPC where the capability probe finds it (§3). The parser lives
*inside* the cmux-supervised process, which is why fix-on-red needed no daemon.

---

## 7. Event posture

**Declarative-first, three tiers** (settled in
[research/prior-decisions.md](research/prior-decisions.md) §4; mechanism in
[research/arch-sketch-a.md](research/arch-sketch-a.md) §1.C, §8):

1. **Hooks (push).** `cmux.json → notifications.hooks` pipes every notification through
   `cide policy` — stdin policy JSON → stdout modified policy: focus-aware silencing
   (`appFocused`/`focusedPanel` in the payload), failure escalation, noisy-space
   bubbling. Claude `Stop` hook → `cide turn-complete` stamps `ReviewItem`s and opens
   `diff --source last-turn --no-focus`. Both are short-lived filters — the canonical
   programs the pipeline was designed for.
2. **Durable backstop (catch-up).** Every verb begins with a cheap cursor catch-up over
   cmux's `events.jsonl` (review cursors, lazy space GC, registry repair). Turns that
   fired while no hook was installed are *still found*. `CatchUpError::Gap` (log
   rotation) forces snapshot refresh + cursor re-anchor — the gap is in the type.
3. **The reactor (gated).** `cide reactor` = the same binary looping on
   `cmux events --reconnect --cursor-file`, deployed as a cmux-supervised **dock
   control**. It is built ONLY after the promotion gate trips: **two shipped loops
   independently needing reactor-mode residency.** Its lifecycle spec is pre-agreed
   (graft g3): level-triggered reconciliation — *events are hints, snapshots are truth*;
   gap-mandatory subscriptions (`CatchUpError` stays in the type); desired-state
   reconstruction from files on every start; and a **binary-version self-check**
   (exit-for-respawn when the on-disk binary changed post-`brew upgrade`). That last
   discipline applies to long-lived `cide run wrap` panes **today**, not just the future
   reactor. No UDS server, no launchd, ever; verbs keep reading state files.

The honest ledger is accepted and documented ([research/arch-decision.md](research/arch-decision.md)
§3.1): no sub-second reaction to unhooked events (Cmd+W close → stale membership until
the next verb — invisible because tree-is-truth); debounce via timestamped ring files
(clunky, workable, revisit at the gate); flock-discipline under hook storms (enforced by
the g1 property test).

---

## 8. Testing strategy

Layered like the architecture; the POSIX suite is the inherited behavioral spec.

1. **Pure-core units.** `plan_*` functions are `topology → op-plan`, zero I/O — the unit
   and golden-master surface. Property tests: every layout preset × binding set produces
   a valid plan; config-merge across the five layers.
2. **Golden master (the strangler permit).** The 113-assertion POSIX suite asserts
   emitted cmux commands. Each migrated verb runs against `FakeMux` on the same fixture
   topology; the recorded op log is normalized and diffed against the suite. A verb may
   not replace its shell twin until the diff is empty or every delta is an annotated,
   intended improvement.
3. **Port conformance kit (P7).** Generic per-port suites over generated-never-
   hand-authored fixtures (`cide-testkit gen-fixtures` captures from live cmux into
   `fidelity/<version>/`); run against fakes always, live behind `--ignored`.
4. **Replay-server tier (g7).** The socket adapter runs the same conformance assertions
   against a recorded replay server in CI — primary-transport coverage with no live cmux.
5. **Crash-replay convergence properties (g1).** For a random kill point *k* in a
   recorded event/invocation stream, restart from the cursor and assert end-state
   convergence with the never-killed run. Applied to: 50-parallel hook-storm invocations
   (`cide policy` × `turn-complete`), `cide run wrap`, and the reactor when promoted.
   A CI property, not a one-off.
6. **BDD** (cucumber-rs) where behavior is cross-port: space lifecycle, review queue,
   fix-on-red, focus fan-out — against fakes; `.feature` files double as the published
   behavioral contract. cucumber-rs pulls an async stack as a **dev-dependency only**;
   the no-tokio/no-HTTP bans (§2, risk #4) are scoped to the shipped binary's normal
   dependency graph, so the test harness never trips — or weakens — the gate.
7. **Flow-SLO benches as release blockers.** hyperfine in CI: cold start < 10 ms,
   `cide jump --dry` < 30 ms against FakeMux + recorded socket latencies
   ([research/arch-sketch-a.md](research/arch-sketch-a.md) §10). Methodology: shared
   runners gate on **relative regression vs a pinned reference binary compiled and timed
   in the same job** — 10 ms-scale absolutes flake on hosted macOS runners; the absolute
   budgets are asserted with warmup runs and a stated tolerance on the release machine.
   Regression fails the release, same as correctness (P6).
8. **Trust gates.** Every manifest must declare an egress label (CI deny-by-default);
   `cargo-deny` bans network crates from the dependency tree — zero-egress proven
   structurally; a grep gate rejects `~/.config` path literals outside the consented
   `setup` module.

---

## 9. Migration plan

Strangler fig behind the existing commands. Mechanism: each `bin/cide-*` script grows a
3-line preamble — `command -v cide && [ -z "$CIDE_SHELL" ] && exec cide <verb> "$@"` — so
the binary takes over verb-by-verb with `CIDE_SHELL=1` as instant rollback at every step.
Phases reorder Sketch A's plan per graft g2 (**runner before the spaces port**: zero
parity burden, immediate dogfood value, load-hardens socket + pipe-pane + state-write
paths before the crown jewels ride them):

| Phase | Ships | Retires | Notes |
|---|---|---|---|
| **R1 — foundations** | `cide` binary skeleton, socket adapter + quirk vault, `cide-json`, `cide doctor` (egress audit, provenance, capability drift), `cide state migrate`, fixture generator; then the parser killers: `cide theme`, `cide agent ls`, `cide statusline` | the three worst hand-rolled parser sites (3× awk TOML, JSON-by-grep, session-store joins); the two live hygiene violations (#9 `~/.config/ghostty` write, #10 tracked-file churn) via `ApplyPlan` | Read-mostly, zero blast radius; doctor useful from day one. **g6 lands here**: `cide state migrate` is **per-state-family and re-runnable** (two-phase, collision-refusing — the `cwd state-migrate` precedent), each family migrating in the phase where its owning *write*-verbs port: agents at R2, spaces + registry at R3. Until a family migrates, R1's read-only verbs (`agent ls`, `statusline`) read the shell-format files through versioned readers; ported verbs **refuse to run against an unmigrated family**, never guess, never co-write. |
| **R2 — runner + guarded writes** | `cide run` / `cide run wrap` (the g2 pull-forward); `cide set-role`, `cide jump`, `cide open`, `cide md-open`, `cide agent new/rename` (completing the agents cluster — its state family migrates here, killing the split-brain of shell appends vs Rust reads) | the Dock's raw watchexec line; the `just --list` stub pane (#23); shell `cide-jump`/`cide-open`/`cide-set-role`/`cide-agent` → shims | First mutating verbs + first never-existed capability. `InjectionGuard` and self-heal get golden-master parity here. `hx-wrap` stays a shell launcher calling `cide set-role` — wrappers are adapters' launchers and may stay shell forever. |
| **R3 — spaces + place** | `cide space new/open/close/rm/ls`, `cide place` | `bin/cide-space`, `bin/cide-place` → shims; the Swift placement helper retired (objc2 in-process) | The crown jewels, gated hard on golden-master parity + the live agent-resume round-trip check. |
| **R4 — Rust-only capability** | `cide sync` (config→`.cmux/*` compiler), `cide review` (the review queue), `cide policy`, `cide replace`, `cide focus`, `cide setup` | the `.cmux/` smoke test graduates into `cide sync` output; the notify stub (Feed replaces it) | New verbs never written in shell. The flagship loop (review queue) lands on declarative hooks + catch-up, per §7. |
| **R5 — verticals + retirement** | dbt recipe (`cwd focus` → `cide focus`, `cwd route` → routing data, warehouse port from hq-wrap logic, cute-dbt behind `DbtReview`); rust-dev recipe at the Rule-of-Two trigger; delete shell bodies | the `cwd` family; the POSIX suite converts to cucumber features | Shell remains only as wrapper-launcher scripts adapters own. |

**Appetite and the v1 line.** Phases carry timeboxes, not estimates — when a phase blows
its appetite, scope is cut inside the phase or the strangler pauses at a shippable
boundary (rollback is `CIDE_SHELL=1`, so stopping is cheap): **R1 = 3 weeks, R2 = 2
weeks, R3 = 3 weeks, R4 = 2 weeks, R5's v1 slice = 2 weeks** — each within the backlog's
M-class effort honesty ([research/opportunity-backlog.md](research/opportunity-backlog.md)),
sized for a solo founder with cute-dbt, mokumo, and ops work concurrent. **v1 = the
R1–R4 base plus the dbt recipe with backlog #5 behind `DbtReview`**; #12/#13/#15 are
post-v1 L-effort programs, explicitly not v1 scope (backlog sequencing notes). **The end
of R2 is a re-approval checkpoint**: golden-master parity holding plus the runner shipped
and dogfooded is the evidence the architecture bet paid off — Christopher re-evaluates
the bet there, before the crown jewels (R3 spaces) ride it.

Coexistence rules: (1) every phase independently shippable and revertible via
`CIDE_SHELL=1`; (2) verbs port in dependency clusters so no state file is ever co-written
by both generations (g6 enforces the boundary); (3) tree-is-truth means generations
cannot corrupt each other's view of cmux; (4) **no new shell features after R1** — new
capability lands Rust-only, so the gap only closes; (5) `cide doctor` reports which
generation owns each verb. One sequencing note pins the lone "now" slice: **backlog #5
(the cute-dbt review loop) ships from the POSIX dogfood before R1 begins** — once R1
lands, rule (4) holds and further dbt capability waits for R5 behind `DbtReview`
([research/opportunity-backlog.md](research/opportunity-backlog.md) sequencing notes).

---

## 10. Distribution

- **One binary**, `brew install breezy-bays-labs/tap/cide`, built by `cargo-dist`:
  per-arch darwin artifacts (aarch64 + x86_64), the generated brew formula selecting
  `on_arm`/`on_intel` — cargo-dist does not lipo universal binaries (still an open
  upstream request), and per-arch is the zero-custom-CI answer for a brew-distributed
  tool. `aarch64-unknown-linux-musl` builds in CI
  from day one — it lacks a mux adapter until a tmux/zellij adapter exists, but
  continuously compiling it is the cheap insurance that keeps Linux unprecluded (settled
  non-goal for v1). No-tokio makes the musl static story trivially clean.
- All recipes/layouts/themes embedded (`include_str!`): the binary works on a bare
  machine (`cide space new --type base` in any git repo). No runtime downloads, no
  self-update (brew owns updates), no telemetry. `cide doctor` prints the entire network
  surface: cide's own (for the default binding set, one line —
  `gh (defensible-egress, opt-in)`) plus the cmux-substrate audit (§3): telemetry flag
  state, Feed-control `--legacy`, `reactGrabVersion`.
- **The Swift placement helper is retired** behind the `Placement` port:
  `cide-place-macos` binds CoreGraphics/AX via `objc2` in-process, killing the Xcode-CLT
  dependency and the per-call `swift` interpreter startup (pain #16). AeroSpace
  cooperation and the AX-grant-attaches-to-cmux/Ghostty reality move into the adapter and
  a doctor check. Linux binds `NoopPlacement` (`Skipped { reason }` outcomes, never blocks).
- clap-generated shell completions + man pages ship in the formula.

---

## 11. Risk register

| # | Risk | L×I | Mitigation |
|---|---|---|---|
| 1 | **cmux API drift** — fast upstream cadence; socket v2 is not a stability-promised contract; the G1 bug class | H×M | All wire parsing in one module; versioned fixtures regenerated per cmux release with an upgrade-diff workflow (proven in `fidelity/`); `capabilities()` probe + doctor warning; CLI adapter as second transport/oracle; g7 replay tier keeps the socket path CI-covered. Playbook: regen fixtures → diff → fix adapter → golden master green. |
| 2 | **Reactor scope creep / the residency bet is wrong** — a flagship flow turns out residency-shaped, or the reactor, once promoted, gravitationally attracts features | M×H | The promotion gate is written (two shipped loops independently needing residency) and the g3 lifecycle spec is pre-agreed, so promotion is a deployment-mode change, not a redesign — same ports, state files, tests; still a dock control, never launchd, never a UDS server. Review checklist item: "could this be a one-shot verb?" |
| 3 | **Hook-storm state races** — concurrent `policy` × `turn-complete` × `run wrap` invocations interleave writes | M×M | Single `flock` over the state dir, sub-second holds; atomic rename everywhere; append-only JSONL on hot paths; idempotent ops keyed by event seq; the g1 convergence property (50 parallel invocations must converge) runs in CI permanently. |
| 4 | **Latency SLO misses / startup-budget erosion** — dependency creep turns 8 ms into 80 ms and the every-verb-is-a-palette-action economics collapse | M×H | CI-enforced hyperfine budgets are release blockers (relative-regression gated, §8.7); `cargo-deny` allowlist for new deps (scoped to the shipped graph, `exclude-dev` — §2); no-tokio/no-HTTP as workspace lints; hot read paths (statusline) read hook-maintained cache files with zero socket calls; heavy TUI surfaces are feature-gated modes off the hot path. |
| 5 | **Solo bus-factor** — one maintainer, a Rust workspace, an adapter zoo | M×H | The architecture is the mitigation: sync code, tiny dep budget, no lifecycle subsystem, no IPC protocol — the boring half of the A-vs-B decision was chosen *for* this. Conformance suites + BDD features are executable documentation; every migration phase is independently shippable with shell rollback; doctor makes system state self-describing. |
| 6 | **Helix limitations** — no remote-open socket, so editor-open is guarded keystroke injection; cannot host TUIs | H×M | The fragility is confined to one adapter behind `InjectionGuard` (typed evidence required; `NotAtPrompt` returns a remedy, not a crash); git TUIs spawn as sibling panes by design (settled); the neovim adapter is the proven clean-channel escape; version-drifty helix facts verified by spikes per slice, never from memory. |
| 7 | **dbt Fusion / dbt-core v2 churn** — the dbt toolchain is mid-upheaval; parsers and manifests move | M×M | dbt knowledge is quarantined: `cide-dbt` adapter code + `recipes/dbt.toml` data; manifest semantics live in cute-dbt behind the `DbtReview` port (its own ADRs own fail-closed preflight); the warehouse derive reads `profiles.yml` read-only. The base IDE and rust-dev vertical ship with zero dbt dependency, so churn cannot stall the spine. |
| 8 | **Two-generation migration limbo** — the strangler stalls mid-way on solo bandwidth, doubling maintenance (the fragmentation pain #4 the rewrite exists to kill) | M×M | Value-front-loaded phases (R1 kills the worst parsers + both hygiene violations; R2 delivers never-had capability); exec shims make per-verb migration cost zero; golden master makes ports mechanical; g6 prevents state split-brain; no-new-shell-features rule means the gap only ever closes. |
| 9 | **cmux ships the meaning layer natively (Sherlocking)** — the vendor already owns the Feed, diff viewer, session stores, and a teams shim, and ships at a fast cadence; native spaces, a turn-review queue, or a fleet log would evaporate the base IDE's differentiators | M×H | Verticals-as-recipes and the dbt/rust intelligence ladders are not absorbable by a multiplexer vendor; composition keeps cide's base layer cheap enough to lose; the dogfood feedback speed is the moat on iteration; the capability probe watches upstream releases — any meaning-layer encroachment is a backlog re-rank trigger, not a crisis. |

---

## 12. Open architecture questions (for Christopher)

> Canonical home: architecture-residency questions live here and only here —
> [product-vision.md](product-vision.md) §9 cross-references #2/#3 (and the license
> ruling, #8) rather than restating them, so iterating revisions cannot diverge.

1. **User-config layer location.** Keep `~/.config/cide/config.toml` as a *read-only*
   layer (the recommendation — XDG-conventional, honors the write rule as written), or
   maximal purism: relocate to `~/.local/share/cide/config.toml`? One path constant;
   needs a ruling before R1.
2. **Generated `.cmux/*` files: committed or gitignored?** Sketch A recommends committed
   (diffable, trust-gated, degrades gracefully for colleagues without the binary);
   the counter is generated-file churn in PRs. Also decides the fate of the current
   untracked `.cmux/` smoke test.
3. **Runner default home: Dock vs layout tile** — the fork carried open from
   [research/prior-decisions.md](research/prior-decisions.md) §19; needed at R2.
4. **`workspace.group.*` adoption timing.** Native space containers (backlog #6) at R3
   alongside the spaces port, or as a post-R3 enhancement? Groups are within-window only;
   the registry stays the cross-monitor join either way.
5. **`cide-json` versioning policy.** Single `schema = N` integer vs semver; what
   deprecation window do agent/skill consumers get when a field changes?
6. **Conformance-kit publication + colleague-extension mechanism.** When does
   `cide-testkit` publish (crates.io at R3? R5?), and is the extension path a Rust PR
   behind a port or a config-declared command template with a pinned contract (the open
   /shape decision in [research/prior-decisions.md](research/prior-decisions.md) §19)?
7. **Golden-master delta adjudication.** Who signs off "annotated, intended improvement"
   diffs during R2–R3 — inline PR review, or a recorded decision per delta class?
8. **License confirmation at productization.** Org default is GPL v3 for dev tools;
   cute-dbt recorded MIT. One-line ruling before the brew tap goes public (flagged, not a
   vision topic, in [research/prior-decisions.md](research/prior-decisions.md) §17).

---

*Plan complete. Architecture: Sketch A, grafts g1–g7 binding
([research/arch-decision.md](research/arch-decision.md)). Product content:
[product-vision.md](product-vision.md). The next step after approval is R1.*
