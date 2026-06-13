# cide — Current State of the Shell Dogfood (research snapshot)

> Prepared 2026-06-09 for the cide Rust-tool vision work (task #33). Maps what EXISTS
> in `/Users/cmbays/github/cmux-workspace-dbt` at `main` @ `80a151a` so vision work
> builds on reality, not memory. All findings grounded in the repo's files; no live
> cmux instance was mutated.

## 0. Orientation: two command families, one repo

The repo contains **two generations layered in one tree**:

1. **`cwd` (Phase 0, dbt-specific)** — the original "cmux-workspace-dbt" POSIX tool:
   `cwd new/route/focus/doctor/register/state-migrate`, with a 3-axis config model
   (machine profile / dbt project / data-policy) and a stub-cmux golden-master test
   suite (`tests/run.sh`, ~113 assertions asserting *emitted cmux commands*).
2. **`cide-*` (the base-IDE dogfood)** — the newer, type-agnostic IDE command family
   built live against real cmux 0.64.12: IDE instances, roles, spaces, agents, theme,
   placement. This is the direct precursor of the Rust `cide`.

The destination (per `.claude/architecture-direction.md`, council-ratified and
demand-confirmed) is a **Rust hexagonal workspace manager** (`cide` binary, crates
`cide-core` / `cide-adapters` / `cide-dbt` / `cide`), strangler-fig migrated behind the
POSIX daily-driver, with the POSIX suite as the behavioral conformance spec.

---

## 1. (a) Command inventory

### 1.1 `cide-*` family (IDE dogfood — installed on every profile)

| command | what it does |
|---|---|
| `cide-space [ls\|new\|open\|use\|current\|close\|rm]` | IDE **spaces**: named, lifecycle-managed containers built FRESH from the `cide.toml [ide].layout` preset. `new` resolves a window per layout role (reuse same-orientation window or create), instantiates `cmux new-workspace --layout <json>` per window, stamps each workspace `description` with `cide:spaces=<id>;role=<role>`. `close` snapshots live claude checkpoints first; `open` rebuilds windows AND relaunches the agent slot as `claude --name <label> --resume <checkpoint>`. `--dry` prints the window plan. Store: `~/.local/state/cide/spaces/<id>/{meta,members,history,agents}`. |
| `cide-place [ls\|move-window\|move-workspace\|move-ide]` | Monitor-aware placement, macOS-native (Swift helper `lib/cide-place.swift`: CoreGraphics geometry + AX move; no aerospace/yabai dependency, but **AeroSpace-aware** — uses `aerospace move-node-to-monitor` when AeroSpace runs, since it re-tiles raw AX moves). Monitor ref = name \| UUID \| portrait \| landscape \| index. Three granularities: whole window ⊃ this window's cide workspaces (`move-ide`, auto-detected by cide tags) ⊃ one workspace. Accessibility grant attaches to cmux/Ghostty, NOT `swift`. |
| `cide-agent [new\|ls\|rename]` | First-class agent surfaces composed over cmux's native agent machinery. `new` launches `claude --name <label>` in the current surface (label = tab name = vault name = /resume name), records to an append-only index (`$CIDE_STATE/agents`), ensures cmux claude hooks installed (idempotent marker). `ls` = the **vault**: active sessions scoped to the active space (live surface ∈ member workspaces, read from live tree, not the store's stale workspaceId) vs dead sessions (repo-wide by cwd, honestly labeled). Reads cmux's store `~/.cmuxterm/claude-hook-sessions.json` (read-only). |
| `cide-jump [role\|agent [label]] [--dry]` | Cross-monitor focus: toggles editor↔tools via the registry (focus-window + select-workspace + focus-pane), self-heals a missing editor by regenerating it. `agent` mode picks the labeled (or most-recently-active) live agent surface and focuses it via `focus-panel`. Bound to AeroSpace `alt-o` (cmux cannot hotkey shell commands). |
| `cide-open <file...>` | Open files in the IDE editor, possibly in another window/monitor. Liveness-checks the editor target; if helix is running, injects `:open <abspath>` via `cmux send` (helix has no remote-open socket); if helix exited (read-screen shows a shell prompt: `❯|➜|[$%#]$`), relaunches `hx-wrap` instead; if the editor workspace is gone, **self-heals** via `cide_regen_editor` (or opens locally when interactive). |
| `cide-md-open <file.md...>` | Markdown dual-open: file in helix (artifact region) AND a live `cmux markdown` preview split DOWN from the editor surface — passing `--window` explicitly (a `--workspace`-only split follows the CALLER's window). |
| `cide-regen [role]` | Manual regeneration of a missing role-workspace. Only the `editor` recipe is wired (portrait `hx-wrap` launch + tag + registry); `tools` reports "no recipe yet (#21/layout-as-data)". |
| `cide-set-role <role>` / `cide-set-editor` | Push-based self-registration of the CURRENT surface as a role: `cmux identify` → tag the workspace description (`cide:instance=<name>;role=<role>`) → log registry → (editor) write `editor_target`. `hx-wrap --as-editor` calls this on launch. |
| `cide-theme [name\|--list]` | Multi-tool theme switcher: name-swaps per-tool theme settings from `config/themes/<name>.toml` (helix / btop / delta-bat / yazi flavor / ghostty+cmux), updates `cide.toml [theme].active`, `cmux themes set` + `reload-config` live. ANSI-following tools (lazygit/tig/gh-dash) ride along free. Seeded: catppuccin-mocha, tokyonight, nord, gruvbox, dracula. |
| `cide-yazi [--sidebar] [path]` | IDE explorer launcher: `YAZI_CONFIG_HOME` → `config/yazi/cide-wide` (3-col + preview) or `cide` (2-col sidebar), stable `--client-id` for DDS control, cide openers (edit→cide-open, .md→cide-md-open, .json→jless, .csv→csvlens, .log→lnav, .duckdb/.sqlite→hq-wrap). |

### 1.2 `cwd` family (Phase-0 dbt spine)

| command | what it does |
|---|---|
| `cwd focus [--hq] <model>` | The "set active subject" use-case: fan-out one model across every surface — editor (via cwd-route), yazi reveal (`ya emit-to <client-id>` with `TMPDIR=$(getconf DARWIN_USER_TEMP_DIR)`), hunk session reload/navigate if changed, harlequin read-only preview (data-axis gated), report/DAG slot pending cute-dbt. No arg = fzf pick. |
| `cwd route <path>` | Type-gated router. `general` ws → defer everything to user's `open-helix.sh`; `dbt` ws → `.sql` → helix model tab in edit pane (+ sibling yml, focus-if-open), `.csv` → csvlens in tools pane, dir → buffered helix tab, else open-helix.sh. Mechanism: `new-surface` → `send` + `send-key Return` → `rename-tab`. |
| `cwd new <worktree\|branch>` | Births a dbt workspace: `git worktree add` if needed, `cmux new-workspace --cwd … --layout <static JSON>` (yazi / helix / dbt-shell + a `cwd register dbt` surface), parses `OK workspace:N`. |
| `cwd register dbt` | Runs inside the new workspace: parses `cmux tree` for the editor pane (matcher `hx-wrap|^hx:` — the G1 fix) + last-other pane, writes UUID-keyed `ws_type=dbt` marker + `edit_pane`/`tools_pane` state. |
| `cwd doctor` | Read-only resolution dump: 3 axes, ws type/key/state, derived warehouse, tool availability. |
| `cwd state migrate <old-key> [--yes]` | One-shot, two-phase (scan-then-commit), collision-refusing re-key of a Phase-0 ref-keyed state dir to the live UUID key. |
| `cwd resume` | Stub — "Phase 1, not built." |

### 1.3 Wrappers & widgets (the adapter-launcher pattern)

| script | purpose |
|---|---|
| `hx-wrap` | helix with `XDG_CONFIG_HOME=$repo/config` (bundled config, dbt-fusion LSP). `--as-editor` / `CIDE_AS_EDITOR=1` self-registers the editor role. Exists because nushell can't do inline `VAR=val cmd`. |
| `yazi-wrap` | yazi with the ws_type-gated config home (dbt overlay vs profile variant) + stable `--client-id` (default 1717) for `ya emit-to` control. |
| `hq-wrap [conn]` | harlequin with theme-follow + zero-egress duckdb init (`autoinstall_known_extensions=false` via `-i config/duckdb/cide-init.sql`). File-arg = adapter-by-extension; no-arg target resolution: `cide.toml [database].connection` → derived dbt warehouse (read-only, won't fight dbt's writer lock) → in-memory duckdb. |
| `hq-preview <relation>` | (stow-only, structural data boundary) read-only harlequin preview tab in the tools pane; loads `select * … limit 100` without running it. Notable: read-screen polling loops to pace Textual's boot (settle timing is a real problem). |
| `btop-wrap` | btop with bundled XDG config + hand-written catppuccin theme (zero-egress). Known gotcha: btop rewrites its conf on quit → tracked-file churn → "seed→state copy" design TODO. |
| `git-glance(-render)` | watchexec-driven live `git status -sb` widget. |
| `stgrev` | alias → `stagereview` (loopback-only local review tool; egress-verified PASS). |

### 1.4 lib/

- **`lib/common.sh`** — 3-axis resolution; `$CMUX_WORKSPACE_ID`-keyed state get/set; hand-rolled awk YAML parse of `dbt_project.yml` + `profiles.yml` (warehouse auto-derive, `:memory:`/URI passthrough); `hq_enabled` gate; walk-up dbt-project discovery.
- **`lib/cide-editor.sh`** — the de-facto cide runtime library: minimal TOML reader (`cide_toml_get`), registry (pipe-delimited `instance|role|ws|pane|sf|win`), editor target + liveness (workspace exists AND contains surface AND still tagged `role=editor`), window orientation via `list-panes --json` `container_frame` (width<height ⇒ portrait), `cide_find_window <orientation>`, `cide_regen_editor`, claude-hooks ensure, agent index, spaces store + active-space scoping (`cide_space_members` — the scope boundary all features honor).
- **`lib/cide-layout.sh`** — layout-as-data: `[ide].layout` preset → window plan (TSV `role<TAB>orientation<TAB>cmux-layout-JSON`). The cmux layout tree IS the format (no cide DSL); a preset is just a list of windows because the one thing cmux JSON can't express is multi-window. Only `landscape-portrait` and `single-portrait` are specialized; the other three fall back with a warning.
- **`lib/cide-place.swift`** — display list/resolve/move via CoreGraphics + AX (CGDisplayBounds = AX coordinate space, no Y-flip), run interpreted (`swift file.swift`, no build step).

### 1.5 Supporting infra

- **`install.sh [--profile bare|stow]`** — symlinks into `~/.local/bin`; `bare` structurally omits `hq-preview` (data-access boundary); builds the dbt yazi overlay under `~/.local/share/…` (reads, never writes, `~/.config`).
- **`tests/run.sh`** — stub-cmux logic suite: sandboxed read-only `$HOME`, asserts exact emitted cmux commands; the behavioral golden master the Rust port must pass.
- **`fidelity/`** — versioned static-CLI snapshots of cmux (0.64.10, 0.64.12 — byte-identical for the driven surface) + upgrade-diff workflow; explicit precursor to the mandated real-cmux golden-fixture tier.
- **`justfile`** — `doctor` / `fidelity` / `hooks` (the task-runner pane content today).
- **`.cmux/`** — UNTRACKED smoke test of native composition (below, §5).

---

## 2. (b) The `cide.toml` config surface

Single repo-root file; read today by `lib/cide-editor.sh` (`[ide]`, `[agents]`, `[theme]`) and `bin/hq-wrap` (`[database]`). The Rust cide will own this schema.

```toml
[ide]
name              = "cide-dbt"            # IDE identity; default = repo/dir name; coupled
                                          # workspaces all share it as their VISIBLE name
layout            = "landscape-portrait"  # single-landscape | single-portrait |
                                          # dual-landscape | dual-portrait | landscape-portrait
on_missing_window = "reuse"               # reuse (existing same-orientation window — right
                                          # monitor, no drag) | new (fresh window — lands on
                                          # main monitor, drag once)

[agents]
active    = ["claude"]                    # v1 claude-only; codex slot reserved
placement = "landscape"                   # landscape | portrait | both

[agents.claude]
command     = "claude"
args        = []                          # user-opinionated; cide ships SAFE defaults
name_flag   = "--name"                    # label rides to tab + vault + /resume
resume_flag = "--resume"                  # cide-space open relaunch flag

[theme]
active = "catppuccin-mocha"               # cide-theme updates this

[database]                                # v1: ONE connection = ONE target
# adapter    = "duckdb"                   # duckdb | sqlite
# connection = "warehouse/dev.duckdb"     # local path or URI (md: = explicit opt-in egress)
# read_only  = false
# no-arg resolution: [database].connection → derived dbt warehouse → in-memory duckdb
```

**Planned extensions (designed, not yet present):**
- `[monitors]` (#31): `editor = "DELL P2725DE"`, `tools = "LG FHD"` — value = macOS name | UUID | portrait | landscape | index; consumed by a best-effort `cide-place move-window` post-pass in `cide-space _instantiate`.
- `[runner]` (#23): catalog override for the runner engine.

Theme files (`config/themes/<name>.toml`) carry per-tool name mappings (`[tool] helix/btop/bat/yazi/ghostty/harlequin` + `[install] yazi_flavor`) — name-swap, no palette maintenance.

Adjacent config model (cwd side): `profiles/{base,bare,stow}.env` = AXIS 1 only (shell kind, config regime, prompt glyph, yazi variant); axes 2 (dbt project, per-workspace state + walk-up discovery) and 3 (warehouse/harlequin/profiles-dir, env → state → derive) are deliberately orthogonal. Council direction: replace baked profiles with one unified resolver + named presets in dotfiles; repo ships zero personal data.

---

## 3. (c) The layout / spaces / roles model

The conceptual stack, bottom-up:

1. **cmux substrate**: window (one macOS window = one monitor) → workspace (tab group) → pane (layout region) → surface (tab in a pane). Layout = nested binary split JSON (`direction` horizontal=columns / vertical=rows, `split` ratio, leaf `pane.surfaces[]` with `{type, name, command}`). Stable UUIDs via `--id-format`; `description` is a separate, settable field — cide's tag channel.
2. **Role** = a window-grained function in the IDE: **editor/artifact** (portrait; helix + on-demand markdown/viewer/html tabs) and **tools** (landscape; yazi+agent | review stack tig·lazygit·gh-dash·difft·cmux-diff | shell | task-runner just·notify). Agents are the first **surface-grained** role (multi-instance, not in the workspace registry).
3. **IDE instance** = a NAMED, config-declared, self-healing coupling of N cmux workspaces (one per role/window), spanning monitors — a **cide concept**, because cmux has no cross-window/monitor link primitive (`workspace.group.*` is scoped within a window). Coupling = registry (functional source of truth) + same visible name (human UX) + description tag `cide:instance=<name>;role=<role>` (rebuild fallback). Single-monitor = degenerate N=1.
4. **Layout preset** = data: the 5-name taxonomy maps to a per-window plan (role, orientation, cmux layout JSON). Reuse cmux's native JSON with launcher commands at the leaves; future Rust direction = `capability` tokens compiled to commands by the WorkspaceHost adapter.
5. **IDE space** = a named, lifecycle-managed *instantiation* of the preset, disjoint by construction from the default (repo-baseline) instance and from every other space. Spaces own their workspaces; close/rm only ever touch their own. Lifecycle: `new` (fresh build, active) → `close` (workspaces closed, record + history + agent checkpoints kept) → `open` (rebuild + `claude --resume`) → `rm` (purge). The default space = the implicit repo instance (no tag, cwd==repo), byte-for-byte the pre-spaces behavior.
6. **Self-healing**: editor target carries liveness + tag checks; any open against a dead editor regenerates it from the recipe (reuse a portrait window or create one), re-tags, re-registers, and continues. `cide-jump` heals on the way to a missing editor. Orientation detection (`container_frame` w<h) is what makes `reuse` land roles on the right monitor without CLI-controllable placement.

State lives at `~/.local/state/cide/`: `editor_target`, `registry`, `agents`, `current_space`, `spaces/<id>/*` — all flat pipe/space-delimited files. Per-workspace cwd state lives at `$repo/state/<uuid>/` (gitignored).

---

## 4. (d) Hard-won cmux facts (LOAD-BEARING for the Rust design)

These were discovered live and repeatedly bit the build. The Rust tool must encode them in its WorkspaceHost adapter + fidelity fixtures, not re-learn them.

**Enumeration & identity**
- `cmux rpc workspace.list` is **FOCUSED-WINDOW ONLY** (window params ignored). Global enumeration = `cmux tree --all --id-format both --json`; anchor workspace nodes on `select(has("panes") and has("description") and has("id"))`. This bug class (incl. `_capture_agents`) silently broke cross-window close/scoping more than once.
- BUT `workspace.list` carries `current_directory`, which `tree --all` lacks — default-space scoping intentionally still uses it (a known cross-window gap, deferred until placement spreads the default IDE across windows).
- `cmux new-window` → `OK <uuid>` (NOT `window:N`); `cmux workspace create` → `OK workspace:N` (legacy `new-workspace` adds a deprecation notice). Parse: `sed -n 's/^OK //p' | tr -d '[:space:]'`. **Verify output formats before parsing** — this was the session's repeated bug class.
- `cmux list-windows` prints UUIDs/indexes, NOT `window:N` refs — enumerate windows via `tree --all`.
- Persist **UUIDs, not refs** (refs are positional and die/reuse across restarts); a tag check defends against ref reuse. UUID case differs across surfaces — everything normalizes via `tr 'a-f' 'A-F'`.
- `cmux identify` is the substrate identity primitive (`{caller,focused,socket_path}`, `--id-format both` adds UUIDs) → register inverts from PULL (title scanning, the G1 fragility) to PUSH (each adapter's wrapper self-reports). `identify --surface <arg>` ignores the arg; `surface-health` only gives `in_window`.

**Windows & lifecycle**
- Closing a window's LAST workspace makes cmux auto-spawn a default workspace → fresh role-windows leave **ghost blank windows** on close. The mitigation pattern: create your workspace first, THEN drop the window's default "Terminal" workspace (never momentarily empty).
- `cmux close-window --window <uuid>` returned OK but **did not close** in testing — window-close needs investigation (#31 fold-in).
- cmux **PROTECTS the caller's workspace** — a command cannot close its own tab; close/rm must handle self last, best-effort, and tell the user "Cmd+W".
- Physical monitor placement is **not CLI-controllable** — a new window lands on the main monitor (hence `on_missing_window=reuse` + `cide-place`). AeroSpace re-tiles raw AX moves → cooperate via `aerospace move-node-to-monitor <name>`; AX fallback only when no WM. The Accessibility grant attaches to cmux/Ghostty (the responsible app), not `swift`.
- `workspace.group.*` (17 RPCs) is **within-window** — cannot be the cross-monitor link.

**Driving tools in panes**
- `read-screen` **cannot see inside TUIs** (alternate screen buffer) → agents can't verify interactive behavior; division of labor: agent owns config/scripts/layout JSON, human owns live testing.
- **Blind keystroke injection is dangerous** (a stray send into live yazi deleted a tracked file). Drive tools via proper control channels: yazi DDS `ya emit-to`, hunk session CLI, `cmux browser eval`, cmux RPC. helix is the exception — no remote-open socket; `:open` injection is the only path and must be guarded (read-screen prompt heuristic `(❯|➜|[$%#][[:space:]]*$)`; `$PROMPT_GLYPH=%` was wrong for the live nushell/starship).
- **Rebuild, don't poke**: declarative `new-workspace --layout` is reliable; sending keys into running panes tangles state. cide should respawn.
- `env VAR=val tool` shows "env" as the cmux tab title → thin per-tool launcher scripts (hx-wrap pattern) or rename-tab post-spawn.
- Surface shells persist after their `command` exits → `echo "hint"` = a labeled, ready shell (used for agent/notify hint slots); "lazy" tools open to `--help`.
- Settle timing is real: hq-preview paces Textual boot with read-screen polling round-trips (no sleep); `new-workspace --command` handles post-create send timing; `wait-for` exists as a future primitive.
- `cmux markdown open` opens a SPLIT, not a tab (the artifact "pane" is really a REGION); cross-window panel placement requires `--window`, not just `--workspace` (the split otherwise follows the caller's window).
- `cmux open <file>` opens cmux's OWN preview tabs, not the editor — routing must spawn adapter instances (`new-surface` → send → rename-tab).
- `cmux popup` is an unsupported tmux-compat placeholder — **no floating panes** in 0.64.x; git-TUI popup UX waits on cmux.
- cmux **cannot hotkey a shell command** (`shortcuts.bindings` map only built-in action IDs; `bind-key` is a placeholder) → custom hotkeys go through the window manager (AeroSpace `alt-o → cide-jump`); cide documents/offers a WM snippet, it cannot ship hotkeys itself.
- Live layout capture IS possible: `cmux --json list-panes` returns per-pane `pixel_frame` + `container_frame` → exact split tree + ratios are recoverable and replayable; but per-surface launch *commands* are NOT stored (only tab titles) → full capture needs cide's own launcher mapping. (`pane.resize` / `workspace.equalize_splits` exist too.)
- `direction:"horizontal"` = side-by-side columns; `"vertical"` = stacked rows (verified — easy to invert).
- yazi DDS socket lives under `DARWIN_USER_TEMP_DIR`, not the sandbox `$TMPDIR` — wrap `ya emit-to` calls with `TMPDIR=$(getconf DARWIN_USER_TEMP_DIR)`.
- The G1 lesson (generalized): fresh-launch surface titles are `"<cwd>> hx-wrap"` (cwd + command), NOT the post-open `"hx: model"` — never model external surfaces from memory; the hand-authored fixture shared the wrong assumption. Hence the **mandated real-cmux golden-fixture tier** (fixtures generated from a live workspace, never hand-authored) and the `fidelity/` static-snapshot spike.
- cmux upgrade cadence is fast but additive so far (0.64.10 → 0.64.12 byte-identical for the driven surface; additions: `cmux diff` browser split — a second diff adapter; `workspace.group.*`).

**Process facts**
- Agent session capture: cmux hooks (`cmux hooks setup --agent claude`, idempotent) write `~/.cmuxterm/claude-hook-sessions.json` (sessionId/checkpoint, surfaceId, transcriptPath, launch args incl. `--name`); without hooks there is nothing to resume. The store's `workspaceId` goes stale across restarts — match `surfaceId` against the live tree instead.
- nushell can't do inline `VAR=val cmd` → flag forms (`--as-editor`) and wrapper scripts are required, not optional.

---

## 5. (e) In-flight and queued work themes

Tracked via the session task list (not GitHub issues). Status as of `main` @ `80a151a`:

| # | theme | state |
|---|---|---|
| #29 | IDE spaces Phase 2 — open/relaunch + agent conversation-resume | **Shipped; ONE pending live verify**: the resume round-trip (`new t2` → chat → `close` captures checkpoint → `open` continues conversation → `rm`). Gates closing #29. |
| #31 | Monitor-aware placement | `cide-place` shipped (PR #22). **Remaining: `[monitors]` wiring** — cide.toml role→monitor map + `_instantiate` placement post-pass (best-effort, never blocks). Fold-ins: deterministic fresh role-windows, ghost-window cleanup, `close-window` reliability investigation. |
| #32 | Move taxonomy (window / workspace / IDE → monitor) | Moves shipped; `move-ide` full flow build-blind (only `move-workspace` confirmed live). |
| #23 | Runner pane | **Shaped, not built.** Decided concept: generic **engine** (watchexec — a Rust crate, continuous path to Rust cide) + pluggable **catalog** (detect `just`/`make`/`npm`/`cargo`; `[runner]` override) + **bacon fast-path** for cargo repos; dbt adapter deferred to the dbt IDE. Compose into cmux's **Dock** (native home for test watchers) + **Command Palette** actions + **Feed** for notify-on-finish (likely replaces the #25 notify stub). The untracked `.cmux/` smoke test (cmux.json palette actions + workspaceCommand demo layout + dock.json with Runner/Spaces/Git/Monitor/Feed controls) probes exactly this; awaiting Christopher's verdict on Fork 1 (runner in Dock vs in layout) and Fork 2 (native Feed vs custom notify pane). |
| #24 | Prompt dual-engine | Queued: starship + oh-my-posh as selectable providers (`STARSHIP_CONFIG` etc.), strong defaults each; omp has an update-check egress flag to disable + verify. |
| #25 | Terminal PR review | Queued: GitHub inline-comment review in the terminal; lean on cmux Feed; candidates from research: agynio/gh-pr-review, tuicr, prr, gh-dash orchestration; defensible-egress class (forge-only). |
| #26 | Stacked diffs | Queued: evaluate ghstack/spr/git-machete (Graphite BLOCKED on egress); design swappable for GitHub-native gh-stack at GA. |
| #27 | Cross-tool journeys | Queued: connective tissue (blame→diff→history); the cross-tool blame explorer is the one genuinely-new-port candidate, named + deferred past base v1; tig is the traversable-blame pick. |
| #30 | IDE spaces Phase 3 — full-fidelity layout relaunch | Queued; pairs with the proven `pixel_frame` capture path (a `cide-capture-layout` tool: read list-panes → ratios → layout JSON with launcher commands). |
| #33 | Product vision + design plan (Rust cide) | In progress — this research feeds it. |
| — | Default-branch cross-window scoping | Deferred; matters once placement spreads the default IDE across windows. |
| — | AeroSpace `alt-a → cide-jump agent` binding | Offered, not done (would edit `~/.config/aerospace/aerospace.toml` with backup + permission). |

---

## 6. (f) Pain points and rough edges worth fixing in the Rust rewrite

**Parsing & typing (the named Rust trigger, now well past threshold)**
1. Hand-rolled parsers everywhere: THREE separate awk TOML readers (`cide_toml_file_get`, hq-wrap's `_cide_db_get`, common.sh's YAML helpers), grep/regex extraction of JSON fields alongside jq, prompt-glyph heuristics. The council's Rust trigger was "about to hand-roll a 2nd parser" — the dogfood is several parsers deep. Rust: serde TOML/JSON once, typed.
2. TOML array parsing for agent `args` is a naive comma-split with quote-stripping — breaks on args containing commas/spaces/quotes.
3. Everything is stringly-typed pipe-delimited state files (`registry`, `meta`, `members`, `agents`) with field-number access (`cut -d'|' -f3`) — schema drift is silent.

**State model fragmentation**
4. Two generations of state coexist: `$repo/state/<ws-uuid>/` (cwd) vs `~/.local/state/cide/` (cide), two naming families (`DBT_WS_*` vs `CIDE_*`), two yazi launchers (`yazi-wrap` vs `cide-yazi`), duplicated yazi config dirs (`cide` vs `cide-wide` — opener rules doubled, reconcile debt acknowledged in-tree).
5. ref-vs-UUID duality is handled ad hoc (uppercasing `tr`, "uuid or ref" parsing, refs derived live because stored ones go stale). Rust should have one identity type with explicit ref/uuid distinction.

**Error handling & observability**
6. `|| true` + `2>/dev/null` blanket-suppression everywhere makes failures silent and undebuggable; "best-effort" is the right policy for placement but is currently indistinguishable from genuine breakage. Rust: typed errors + a `--verbose`/log channel; reserve best-effort for explicitly-marked operations.
7. Settle timing via read-screen polling loops (hq-preview's three nested poll loops) — replace with `wait-for`/event subscription (`set-hook` + `events` stream are unexploited substrate).

**Substrate gaps to design around (not fix)**
8. Ghost windows + unreliable `close-window`; caller-workspace protection; no floating panes; no cmux-native hotkeys; placement not CLI-controllable; helix has no remote-open. Each is a documented WorkspaceHost/adapter constraint, not something Rust dissolves.

**Constraint violations / hygiene**
9. `cide-theme` **writes `~/.config/ghostty/config`** (sed-in-place of the theme line) — a live violation of the NEVER-write-`~/.config` invariant; the Rust theme compiler must route Ghostty theming differently (cmux `themes set` only, or a cide-managed ghostty include).
10. `cide-theme` mutates TRACKED config files in the repo (helix/btop/gitconfig/yazi theme lines + cide.toml) — config-as-working-tree churn; same class as btop rewriting its own conf on quit. Design: seed (tracked) → state (runtime copy) separation.
11. `stow.env` personal-default smell was fixed (zero personal data now), but the lesson generalizes: public acceptance gate = fresh clone, no dotfiles/env, discovery resolves and runs; grep tree for home paths = nothing.

**Architecture debts the Rust design already answers**
12. Title-scanning register (G1) → adapter `identify`-ownership (push-based self-registration is already proven in POSIX via `hx-wrap --as-editor`).
13. Layout presets are hardcoded jq in `cide-layout.sh` (3 of 5 presets unspecialized; tools-role regen "no recipe yet") → layout-as-data with capability tokens, full role-maps, user-creatable layouts.
14. Scoping split brain: named spaces enumerate globally (tree --all), the default space uses focused-window `workspace.list` for its cwd filter — unify on one enumeration with cwd data.
15. Single-agent-slot resume (first restorable row wins); vault label resolution is latest-row-wins over an append-only file — fine for v1, needs a real model for multi-agent.
16. The Swift helper is run interpreted per call (`swift lib/cide-place.swift`) — startup latency + Xcode CLT dependency; Rust can bind CoreGraphics/AX directly or ship a tiny compiled helper.
17. `cide-space new` names collide globally (names unique across spaces) but `_resolve` scans linearly over dirs; meta/members rewrites are non-atomic (`.tmp` + mv only sometimes).
18. The justfile/runner pane is a stub (`just --list`) until #23; the notify pane is an echo hint until #25 — both have decided directions (Dock/Palette/Feed composition).

**Quality machinery to carry forward**
19. The stub-cmux suite asserts emitted commands (substrate-agnostic golden master — the strangler-fig safety net); the `fidelity/` snapshots catch static CLI drift. The MANDATED missing piece: a thin real-cmux integration tier that GENERATES golden fixtures (tree output, surface titles, identify results) — never hand-authored. G1 proved no type system catches external-fidelity bugs.
20. Egress policy is implemented piecemeal (duckdb init SQL, lazygit update-check note, omp flag, stagereview verification) — Rust design: every adapter declares required tools AND an egress label (`zero` | `defensible-egress (opt-in, documented)` | `telemetry-disabled-verified`); doctor surfaces it.

---

## 7. Quick reference: recent history

```
80a151a  #31 — cide-place: monitor-aware placement + move taxonomy + cide-space cross-window fixes (#22)
205686e  #29 — IDE spaces Phase 2: space open/relaunch + agent conversation-resume (#21)
8ef4f23  #21 — layout-as-data + create-fresh IDE spaces (cide-space) (#20)
e9d8a7c  #17 — agent surfaces (Claude first-class, instance-scoped) (#18)
68ace78  #15 — cide theme system (multi-tool theme switcher) (#16)
ff47430  #13 — Base IDE config + dogfood tooling (pre-Rust spike) (#14)
6180379  #11 — record cmux 0.64.12 fidelity pin
8599ff6  #8  — de-personalize stow profile + auto-discover the dbt project
68de31f  #6  — versioned cmux fidelity snapshot spike + 0.64.10 baseline
2f93690  fix: duckdb :memory: / md: URI passthrough (G2)
640a8ed  fix: edit_pane from real cmux surface titles + graceful degradation (G1/G3)
03f95d4  Initial commit
```

Working pattern (non-negotiable, from focus.md): agent owns config/scripts (text, verifiable); Christopher owns live testing; de-risk build-blind unknowns with reversible throwaway probes; verify cmux output formats before parsing; never write `~/.config`; zero-egress/local-first; PR-per-slice off fresh main.

## Sources

All findings are local to `/Users/cmbays/github/cmux-workspace-dbt`:

- `README.md` — cwd command reference, 3-axis config, requirements, state model
- `cide.toml` — the IDE/agents/theme/database config surface
- `install.sh`, `justfile`, `lefthook.yml` — install + task-runner surface
- `bin/` — `cwd`, `cwd-focus`, `cwd-route`, `cide-space`, `cide-place`, `cide-agent`, `cide-jump`, `cide-open`, `cide-md-open`, `cide-regen`, `cide-set-editor`, `cide-set-role`, `cide-theme`, `cide-yazi`, `hx-wrap`, `yazi-wrap`, `hq-wrap`, `hq-preview`, `btop-wrap`, `git-glance`, `git-glance-render`, `stgrev`
- `lib/` — `common.sh`, `cide-editor.sh`, `cide-layout.sh`, `cide-place.swift`
- `.claude/focus.md` — session focus, cmux facts, open threads, task status
- `.claude/architecture-direction.md` — hexagonal design, council verdict, naming/crates, IDE-instance model, substrate findings, egress policy
- `.claude/base-ide-research.md` — VCS/git ecosystem research (83 findings)
- `.claude/base-ide-recipes.md` — paste-ready helix/yazi/git/layout recipes + steal-list
- `.claude/base-ide-toolkit.md` — dogfood findings, monitoring/viewer wave, editor-resilience, IDE-instance Phase 1, cide-jump, DB-target config
- `.claude/validation-findings.md` — live-validation gaps G1-G4 + decisions
- `.cmux/SMOKE-TEST.md`, `.cmux/cmux.json`, `.cmux/dock.json` — native-composition probe (palette/dock/feed/commands)
- `profiles/base.env`, `profiles/bare.env`, `profiles/stow.env` — AXIS 1 machine profiles
- `config/` — helix/yazi(cide, cide-wide, dbt, bare, stow)/btop/tig/gitconfig/duckdb/themes/lazygit/gh-dash
- `tests/run.sh` + `tests/stubs/`, `tests/fixtures/` — stub-cmux golden-master suite
- `fidelity/README.md` + `fidelity/snapshots/{0.64.10,0.64.12}/` — cmux version pins
- `git log` (`/opt/homebrew/bin/git -C … log --oneline -25`) — commit history
