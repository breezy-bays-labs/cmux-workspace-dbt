# Prior settled decisions — cide (do NOT re-litigate in the vision)

> Compiled 2026-06-09 from the ops decision records, the local design records
> (`.claude/architecture-direction.md`, `.claude/focus.md`, `.claude/base-ide-toolkit.md`),
> the live config (`cide.toml`, `.cmux/SMOKE-TEST.md`), and the cute-dbt ADRs.
> Each entry: **the decision**, its one-line rationale, and (where they exist) the
> **explicitly rejected alternatives** so vision drafts don't re-propose them.
> A final section lists what is *deliberately still open* — the only things the vision
> may treat as undecided.

---

## 1. Strategy & identity

| Decision | Rationale | Rejected |
|---|---|---|
| **Rust is GO** (revised 2026-06-02, supersedes the council DEFER) | Real demand confirmed — Christopher's employer colleagues; single-binary distribution; compile-enforced clean architecture; adapter extensibility is a *named requirement*; builder motivation is named honestly | "Rust fixes the G1/G2 bug class" — **empirically false** rationale, never re-use it (G1 = wrong model of cmux titles, G2 = missing case branch; both cured in POSIX identically) |
| **ONE repo, general core, NOT fork-per-type** | Forking duplicates the hardest code (launcher/state/config/cmux orchestration) and forces N× bugfixes | Fork-per-workspace-type |
| **Names locked:** repo `cmux-ide`, binary **`cide`** (= Cmux IDE), crate stem `cide-*` | "cide just feels better"; repo-name ≠ crate-stem is normal (ripgrep/rg); `-rs` suffix dropped as impl detail | `idec`, `ide-cmux`, `cmux-ide-rs` |
| **Public identity: "an opinionated, configurable IDE on top of cmux" — composable, not monolithic** | Type-aware tool composition is the strength vs dumb session managers | Monolithic IDE framing |
| **General surface from day one:** `cide new dbt <path>` takes a TYPE argument from line one | The settled one-repo/general-core stance made concrete in the CLI | dbt-only entrypoint over a hidden general core |
| **Migration = Strangler Fig; POSIX stays the daily driver until Rust parity** | The 113-assertion emitted-command golden-master is the safety net; a Rust capability is "done" only when it passes the same assertions; kills half-finished-rewrite risk | Big-bang rewrite; parallel greenfield repo (repo rename `cmux-workspace-dbt`→`cmux-ide` is colocated, executed at Cargo-scaffolding time, not mid-shape) |
| **Verticals:** BASE IDE first, then DBT IDE, then RUST-DEV IDE as the validating 2nd type | Rule of Two — let rust-dev prove the type seams; don't theorize the framework from one example | Designing the type framework / declarative type-DSL up front (deferred to type #2 trigger) |

## 2. Architecture (hexagonal, locked at council + /shape session 1)

- **Hexagonal ports & adapters via traits.** Capabilities = ports (editor, explorer,
  viewer, warehouse, diff, report); tools = adapters (helix, yazi, csvlens, harlequin,
  hunk, cute-dbt); **cmux = WorkspaceHost, a SUBSTRATE, not a peer port** (altitude split:
  platform → terminal capability adapters → browser adapters).
- **Workspace type = a DOMAIN concept** (composition policy/recipe), not a port, not an
  adapter. `type = { ports used, default layout, port→adapter bindings, behaviors }`.
- **Crate layout (locked):** `cide-core` (domain + ports + use-cases, depends on nothing
  domain-specific) · `cide-adapters` (one module per tool incl. host/cmux) · `cide-dbt`
  (first type crate, sibling-above-core) · `cide` (bin, the only crate depending on
  everything). Workspace-unified version. The DAG compile-enforces core-knows-no-domain,
  dependency inversion, type isolation. **Rejected:** single bin+lib (module privacy
  enforces visibility but not dependency *direction*). **Deferred with triggers:**
  `cide-ports` contract crate (trigger: first external adapter), per-adapter crates
  (trigger: colleague-extension goes real), type registry/DSL (trigger: type #2).
- **Adapters = INLINE tool calls (`std::process::Command`), NOT a drop-a-file shell-adapter
  framework.** Shell adapters re-introduce the stringly-typed parsing boundary (the G1
  class one layer out); "no recompile" solves a non-problem. If the Rust↔shell process
  line is ever crossed, a typed versioned wire contract is the recorded precondition —
  best honored by not crossing it.
- **An adapter = tool binary + cide-managed config + a control channel** (e.g. helix +
  `XDG_CONFIG_HOME` overlay + keystroke-inject; yazi + `YAZI_CONFIG_HOME` + DDS
  `ya emit-to`). Two addressing schemes coexist: cmux surface/pane UUIDs AND tool-native
  handles. Adapters **declare required tools and an egress label**; doctor surfaces both.
- **`identify`-ownership is the generalized G1 fix:** each adapter's launch wrapper calls
  `cmux identify` and self-reports its own stable UUID, keyed by capability. Register
  inverted from PULL (core scans titles — the G1 fragility) to PUSH. Use UUIDs, never
  positional refs, for persisted state.
- **Verb altitude (resolved):** use-cases live in core; CLI is ONE driving adapter among
  many (hooks, yazi opener, editor keybinds). `new` is the real human verb; `register`
  auto-runs inside `new`; `route` fires on events; pane-focus is internal. **The real user
  "focus" verb = SET ACTIVE SUBJECT** (pick a model → every surface re-centers) — already
  proven in POSIX (`cwd focus`), fan-out with wildly different per-adapter impls
  (helix tab vs yazi socket vs hunk CLI vs browser eval) — validates abstract port verbs.
- **Type argument explicit at `new`** (`cide new dbt <path>`); afterwards the type is a
  stored workspace property read by every adapter. **Rejected:** per-command type
  inference ("solved a non-problem").
- **Base/type split (locked):** base = editor (helix) + explorer (yazi) + vcs (git
  status/blame/history/diff). `dbt = base ⊕ {viewer(csvlens), warehouse(harlequin),
  report(cute-dbt), dbt routing, dbt layout}`. Base = composition not inheritance
  (`Default` + struct-update for values; trait default methods for behavior). Note the
  observed drift: the explorer pane is blurring toward a "data-aware base"
  (harlequin/jless/csvlens/lnav/btop in base) — flagged for synthesis, not yet re-decided.
- **Capability discriminator:** "is cide in the loop at runtime?" Set-up-and-step-away →
  adapter CONFIG; runtime orchestration → use-case; new PORT for v1 → default NO.
  (~80% of base git is config, not use-cases.)
- **Quality gate (mandated, non-negotiable):** a thin real-cmux integration tier
  GENERATES golden WorkspaceHost fixtures (never hand-authored) — compile-time safety
  protects internal consistency but does nothing for external fidelity (G1's lesson).
  Required in Rust exactly as much as POSIX.
- **Helix constraint (load-bearing):** helix cannot host interactive TUIs → every
  interactive git TUI is spawned by cmux as a sibling pane, never from inside the editor.
  Helix has no remote-open socket → editor-open is keystroke-injection, a known fragile
  adapter constraint.

## 3. Runner (task #23 — shaped/decided, not yet built)

- **Decision:** a generic **engine + pluggable catalog**. `cide-run` is built over
  **watchexec** as the watch engine — chosen explicitly because it's a Rust *crate*,
  giving a continuous path into the Rust cide (shell dogfood today, library tomorrow).
- **Catalog detection:** `just` / `make` / `npm` / `cargo`, with a `[runner]` cide.toml
  override.
- **bacon is the fast-path for cargo repos** (drop-in Rust-IDE runner later).
- **mprocs = the future multi-service pane ("services")** — deliberately SEPARATE from the
  runner concept; not installed yet.
- **dbt runner adapter deferred to the dbt-IDE vertical.**
- **Compose on cmux natives, don't rebuild:** runner lives in cmux's **Dock** (the native
  home for "test watchers / dev servers / queues" per cmux's own docs) + registered as
  **Command Palette** actions + uses the **Feed** for notify-on-finish — the Feed
  **replaces the planned custom `notify` pane stub (#25)**.
- Open (gut-read pending, from the `.cmux/` smoke test): runner-in-Dock vs
  runner-in-layout as the *default* home; whether the smoke-test `.cmux/` composition gets
  formalized into the workspace template.

## 4. Compose-on-cmux principle (overarching)

- **"Compose, don't reinvent."** cmux already owns agent session capture/resume/
  hibernation, the Feed/vault sidebar, notifications, lifecycle events, palette, dock,
  diff viewer, browser surfaces — all reachable via `cmux rpc` / `cmux events`. cide is a
  THIN layer: launcher + role/label registry + vault reader + event reactor. cide owns
  ONLY role/label/instance semantics + a durable dead-session history index.
- cide verbs register into cmux's **Command Palette** instead of building a picker; the
  **Dock** hosts watchers/monitors; the **Feed** is the notification surface.
- **Reactor posture: declarative-first** — prefer cmux.json `notifications.hooks` effects
  (flash/sidebar/sound/custom command) over a long-running `cmux events` daemon.

## 5. Agent surfaces (tasks #22 + deep research — decided & largely built)

- **Agent = a first-class cide ROLE** via thin `bin/cide-agent` launcher (Claude default,
  `--codex` variant), self-registering through the existing generic role/registry/
  `cide-jump` machinery. cide.toml `[agents]` block: `active = ["claude"]`,
  per-agent `command/args/name_flag/resume_flag` (capabilities absorb cross-agent flag
  asymmetry). cide ships SAFE defaults (no forced model, no skipped permissions).
- **Capture is automatic via cmux hooks** (`cmux hooks setup --agent claude|codex`) —
  bare `claude`/`codex` in any surface is captured (verified live). Default launch = bare
  agent + hooks ensured once. **Rejected as default:** teams wrappers
  (`claude-teams`/`omc`/etc.) — opt-in variant only.
- **The durable key is `checkpoint_id`** (the agent session UUID from
  `cmux surface resume get`). The resume binding is single-slot, agent-hook-owned →
  **cide READS it, never writes it** (writing fights the hook).
- **Registry redesign:** durable row = `instance | role | label | checkpoint_id`;
  **DROP ephemeral `ws|pane|sf|win`** (refs recycle; UUIDs don't survive restart) —
  derive live by matching `checkpoint_id` across surfaces. Workspace-granular roles join
  via the workspace `description` tag (`cide:instance=…;role=…`); per-surface agent roles
  join via `checkpoint_id`. Human labels live in cide's registry — **no native cmux
  per-surface metadata field exists**, so don't go looking for one.
- **The "vault" = cmux's Feed sidebar + RPC snapshots** for live state; cide owns an
  append-only **history index for dead sessions** (cmux has no `session.list` RPC) —
  hydrated from `~/.cmuxterm/<agent>-hook-sessions.json` + transcripts.
- **Self-heal = resume the CONVERSATION:** surface gone → look up `checkpoint_id` →
  new surface + `claude --resume <id>`. `cide-space close` captures agent checkpoints;
  `cide-space open` relaunches `claude --name <label> --resume <checkpoint>` (built in
  PR #29/#21; the round-trip live-verify was the last gate).
- **Placement:** agent rides as a 2nd tab in the yazi pane on the landscape/tools monitor
  (intentional: review + agent + editor simultaneously visible); cide.toml
  `[agents].placement = landscape|portrait|both`.

## 6. Theme system (built, merged PR #16)

- **A GLOBAL cide theme compiled to per-tool configs** — `cide-theme <name>` applies
  `config/themes/<name>.toml` across helix/yazi/btop/delta/harlequin + cmux/ghostty and
  records `[theme].active` in cide.toml. ANSI-following tools (lazygit/tig/gh-dash)
  inherit from cmux/ghostty automatically. Seeded: catppuccin-mocha · tokyonight · nord ·
  gruvbox. Theme is the template for the recurring **config-as-choice pattern** (below).
  Themes are hand-written from published palettes — zero-egress, no upstream fetch.

## 7. Prompt line (task #24 — decided, not built)

- **Support BOTH engines, user-selectable** in cide.toml (`[prompt] engine = "starship" |
  "oh-my-posh"`) — same pattern as themes; ship a strong opinionated default config for
  EACH, exported via env (`STARSHIP_CONFIG`, omp `--config`), never `~/.config`.
- **Default engine = starship** (structurally zero-egress: no network code path; TOML;
  better nushell support). omp is first-class but its default config MUST lock down the
  upgrade machinery (`auto_upgrade:false`, `disable_notice:true`, etc. — otherwise it
  touches `cdn.ohmyposh.dev`). **Rejected:** picking one engine only.
- **Default segments (pure-local):** dir · git branch/status/state · cmd duration ·
  exit status · jobs · **python+virtualenv elevated (dbt is Python)** · node/rust contextual.
- **Ambient CI/branch status = a decoupled launchd LaunchAgent** polling `gh pr checks`
  to a JSON cache; the prompt does a pure file read (structurally cannot egress); opt-in
  by installing the agent; MUST dim on staleness. **Rejected:** in-prompt polling; cron.

## 8. GitHub inline PR review (task #25 — decided, not built)

- Decomposed by role: **`agynio/gh-pr-review`** = primary inline engine (full
  read/write/reply/resolve loop; GraphQL-only; agent-friendly JSON; pin a version —
  single maintainer) · **tuicr** = human authoring TUI (doesn't read others' threads —
  pair it) · **raw `gh api`** = dependency-free fallback (TRAP: use the `/reviews`
  endpoint with a `comments[]` array; `POST /pulls/{n}/comments` 422s — cli/cli#13358) ·
  **gh-dash** = triage layer · **browser pane** = last resort.
- `gh` native does NOT do inline review (cli/cli#359 — don't re-research).
- **Rejected:** `octorus` AI-Rally (external-LLM egress); `octo.nvim` (Neovim-only, no
  helix transfer). Notify-on-review goes through the cmux **Feed**, not a custom pane.

## 9. Stacked diffs (task #26 — decided layering, adoption open)

1. **Zero-install floor: `git rebase --update-refs`** (rebase.updateRefs=true) viewed in
   tig/lazygit — everything else must beat this.
2. **Opt-in local management: Jujutsu (`jj`)** colocated (local-by-default; lazyjj/jjui as
   TUIs). Gate per repo — no LFS/submodules support yet.
3. **GitHub submission (opt-in):** prefer **`gh stack`** at GA; until then `spr`/`ghstack`
   (GitHub-API-only).
4. **Rejected by default: Graphite (`gt`)** — mandatory third-party SaaS backend +
   telemetry + token storage; violates zero-egress. (`charcoal` fork exists if ever needed.)
5. **git-branchless** = design inspiration only — dormant, don't depend on it.

## 10. Cross-tool journeys / blame (task #27 — decided, not built)

- **tig is the spine** of the blame→blame→diff journey; helix (no native blame) is the
  launcher seam. ONE launcher `bin/cide-blame <file> <line>` → `tig blame +<line>`,
  bound from helix (`space g b/B/l`) and yazi (`g b`). gitui lacks the parent-blame loop
  (PR #2285 unmerged) → tig owns it.
- **delta = the git pager** (via `GIT_CONFIG_GLOBAL`), `navigate=true`, hyperlinks OFF or
  `file://`-only for zero-egress. **difftastic** = on-demand structural lens, not the
  default. **hunk** = primary working-tree diff pane (already cmux/agent-wired).
  **cmux diff** (native browser split) = a second diff adapter — a real test of
  adapter-extensibility verbs.
- **Rejected/out:** gitui (likely unmaintained — dropped from v1); serie/git-who/
  git-quick-stats (off-topic for this journey).
- lazygit stays the git-ops TUI; popup pattern blocked on cmux floating panes
  (`cmux popup` is an unsupported placeholder) → v1 = split/zoom pane.

## 11. Placement & multi-monitor (tasks #20/#28–#32 — decided, mostly built)

- **Multi-monitor IDE = a cide-level "IDE instance"** spanning N cmux workspaces (one per
  window/monitor), each with a ROLE (tools=landscape, artifact/editor=portrait) — cmux
  has NO cross-monitor primitive (`workspace.group.*` is window-scoped). Single monitor =
  the degenerate N=1 case (never special-cased).
- **Instance identity & coupling:** named + config-declared (`cide.toml [ide]`:
  `name`, `layout`, `on_missing_window`). Functional join = the **cide registry** +
  hidden workspace `description` tag `cide:instance=<name>;role=<role>` (rebuild
  fallback); the visible workspace NAME is shared purely for human UX and is NOT the join
  key (user-editable + non-unique → fragile). **Rejected:** joining on names; title/
  content scanning (`find-window`).
- **Layout taxonomy (5):** single-landscape · single-portrait · dual-landscape ·
  dual-portrait · **landscape-portrait** (active focus). Layout-as-data; presets are
  pickable + extensible; yazi column ratios are per-preset.
- **Layout format direction:** reuse **cmux's native nested layout JSON with `command`
  leaves replaced by `capability` tokens**; WorkspaceHost compiles capability-layout →
  cmux JSON; the type never speaks cmux. **Rejected:** inventing a TOML layout tree.
  Live-layout capture IS possible (`list-panes` `pixel_frame` → ratios) but commands are
  not recoverable from cmux → a capture tool needs cide's launcher mapping.
- **Self-heal regeneration:** missing role-window → regenerate from the layout spec, tag,
  re-register, recouple; manual `cide-regen [role]`; `on_missing_window = reuse | new`
  with **reuse as the DEFAULT** (orientation-detect an existing window via
  `container_frame` aspect → land on the right monitor with no drag).
- **Physical placement (`cide-place`, merged PR #22):** macOS-native, **NO hard
  aerospace/yabai dependency** — `aerospace move-node-to-monitor` when AeroSpace runs
  (cooperate, don't fight the tiler), else raw AX move via bundled Swift
  (CGDisplayBounds = AX coords). Verbs: `ls` · `move-window` · `move-workspace` ·
  `move-ide` (this window's cide workspaces only, auto-detected from tags).
  Accessibility grant attaches to cmux/Ghostty, not `swift`.
- **`[monitors]` auto-placement (shaped #31):** per-role monitor in cide.toml
  (`editor = "DELL P2725DE"`; values = name|UUID|portrait|landscape|index); a best-effort
  post-pass after window creation — never blocks the IDE.
- **cmux cannot hotkey shell commands** (bindings map only to built-in action IDs) →
  cross-window jump hotkeys go through the WM (aerospace `alt-o → cide-jump`). cide spec
  implication: **cide documents/offers a WM snippet; it does not ship its own hotkeys.**
- Load-bearing cmux facts (don't re-research): `workspace.list` is focused-window-only →
  enumerate globally via `cmux tree --all --id-format both --json`; `new-window` returns
  `OK <uuid>`; closing a window's last workspace spawns a ghost default; cmux protects
  the caller's own tab from closure; `cmux close-window` unreliable (open investigation).

## 12. Config posture (cross-cutting, settled)

- **The "config-as-choice" pattern is the uniform model:** a registry of named options +
  an opinionated default + free user override — applied to themes, prompt engine, DB
  target, `on_missing_window`, layout presets, agents. The Rust config port treats all of
  these uniformly.
- **Swappability ethos ("opinionated BUT configurable"):** 2-3 curated setups per concern;
  one port may bind MULTIPLE adapters for different sub-uses (diff: hunk=review ·
  delta=pager · difftastic=structural · cmux-diff=browser).
- **NEVER write `~/.config`.** Config ships by LAUNCHING tools pointed at cide-managed
  config (`XDG_CONFIG_HOME`, `YAZI_CONFIG_HOME`, `hx -c`, `GIT_CONFIG_GLOBAL`,
  `STARSHIP_CONFIG`, harlequin `-i`/profiles) via wrappers. `~/.config` is read-only at
  most (stow profile symlinks INTO the overlay).
- **Repo ships ZERO personal data**; public acceptance gate = fresh clone, no dotfiles/env
  → discovery resolves and runs; grep for home paths = nothing. Personal defaults =
  named presets layered from the dotfiles repo. Minimal-first config (no speculative
  6-level cascade); ONE unified resolver + one documented precedence.
- **New scripts stay POSIX sh** (documented invariant; the workspace shell may be nu/zsh —
  wrappers absorb it; nushell can't do inline `VAR=val cmd` → flag forms like
  `--as-editor` are required).
- Tools that rewrite their own config (btop) get a seed→state copy so tracked files stay
  pristine (named general pattern).

## 13. Egress policy (refined NFR — settled framing)

- **Base IDE = zero-egress, fully local, air-gappable** (a separate org machine handles
  sensitive data; also the org-distribution unlock). **No PHI concern** — synthetic data
  is fine; do not scrub or hand-wring.
- **Additive capabilities MAY egress — only DEFENSIBLE egress** (the user's own forge via
  `gh`; same profile as `git push`), opt-in + documented + never silent.
  **Telemetry/phone-home = hard NO**; optional telemetry = warning flag → disable, TEST
  silence, document.
- **The egress ladder (reusable framing):** structural-zero (no network code path) >
  policy-zero (capability present, configured off) > defensible-opt-in (GitHub via gh) >
  avoid (third-party SaaS/telemetry/external LLM).
- **Every adapter carries an egress label** (`zero` | `defensible-egress` |
  `telemetry-disabled-verified`), surfaced by doctor.
- Verified specifics: duckdb `autoinstall_known_extensions=false` via
  `config/duckdb/cide-init.sql` (the one real silent-egress vector; missing extension now
  fails loud); btop clean; stagereview loopback-only.

## 14. Database target (built v1)

- `cide.toml [database]`: `adapter` (duckdb|sqlite) · `connection` (local path or
  explicit opt-in `md:` URI) · `read_only`. No-arg resolution: explicit cide.toml →
  derived dbt warehouse from `profiles.yml` (read-only; opened read-only to avoid dbt's
  writer lock) → in-memory duckdb. **Layers on** the existing POSIX warehouse derive —
  cide.toml is the explicit override, profiles.yml the auto source. `profiles.yml` is
  never written. Data axis is independent of machine profile; `bare` install
  structurally omits the warehouse-query command (defense-in-depth with the runtime gate).

## 15. Explorer/viewer pane decisions (built)

- **Explorer pane = the "inspect-state" pane:** yazi=files · btop=machine ·
  jless/csvlens/lnav=file-contents · harlequin=data/SQL; vs the portrait artifact region
  for authoring. **"Artifact pane"** replaces "editor pane" as the capability name —
  helix is ONE artifact adapter among markdown/HTML/CSV/report tabs.
- **Typed viewers are the DEFAULT open** for their types (json→jless, csv/tsv→csvlens,
  log→lnav, db files→harlequin); helix stays the alternate. **`.sql` models still route
  to the editor, never harlequin** — models are authored, not queried-as-db.
- Conventions: "lazy" tools open to `--help` (they act on a target); pane = layout
  region, surface = a tab within a pane (shared cmux/cide vocabulary).

## 16. cute-dbt (the dbt report adapter — own ADRs, settled)

- cute-dbt = Christopher's dbt DX tool: renders dbt unit-tests/CTE-graph into **one
  self-contained zero-egress HTML** (the adoption gate is that a risk team can trust it
  near PHI). cide consumes it as the `report` port's browser-surface adapter.
- Settled there (don't re-open in cide's vision): single-crate hexagonal
  (inward-dependency discipline only — explicitly NOT the dry-rs multi-crate apparatus);
  fail-closed two-stage manifest checking (`PreflightError`, non-exhaustive enum);
  `state:modified` diff-scoping via a `StateModifier` strategy (body-checksum only v0.1);
  assets compile-embedded via `include_*!` (no runtime asset paths, no ESM Mermaid),
  zero-egress proven by a **headless network-block test, not grep**; Mermaid `'strict'` +
  Cytoscape+dagre for `explore`; fixtures synthetic-only (hard constraint); crates.io
  publish at v0.1.0+, SemVer, release-plz, OIDC trusted publishing.
- Ports only where >1 real-or-test impl exists; otherwise free functions — "trait
  indirection earns its keep only with polymorphism" (a useful precedent for cide's port
  discipline too).

## 17. Process & working agreements (settled, carry into the vision)

- **Division of labor:** agent owns config/scripts/layout-JSON (text-verifiable);
  **never blind-pokes running TUIs** (read-screen can't see alternate-screen TUIs; blind
  keystrokes once deleted a tracked file). Christopher owns live interactive testing.
  **"Rebuild, don't poke"** — declarative spawns over sending keys to live panes.
  Tools are driven via **proper control channels** (yazi DDS, hunk CLI, browser eval,
  cmux RPC), never blind keystroke injection.
- **Verify external fidelity with spikes** — version-drifty tool facts (yazi plugin APIs,
  helix features) are confirmed when building that slice, never asserted from memory.
- **Open dialogue over menus** during design exploration.
- **Golden fixtures are captured-from-real, regenerable, diff-reviewed** — never
  hand-authored.
- Org licensing context: dev tools default **GPL v3** (org ADR; forks must stay open) —
  though cute-dbt's ADR records it as MIT/public; the cide repo currently carries its own
  LICENSE. Flag for a one-line confirmation at productization, not a vision topic.

## 18. Explicitly rejected alternatives — quick index

| Don't propose | Why it was rejected |
|---|---|
| Fork-per-type repos | Duplicates the hardest code, N× bugfixes |
| Drop-a-file shell-adapter framework in Rust | Re-introduces the stringly-typed G1 boundary; recompile is cheap |
| "Rust because it prevents the G1/G2 bug class" | Empirically false; fidelity bugs need the golden-fixture tier |
| Type inference per command | Type is a stored workspace property after `new` |
| TOML layout tree / bespoke layout format | Reuse cmux's native nested JSON with capability tokens |
| Joining coupled workspaces by visible name or title scan | Names are user-editable/non-unique; use registry + description tag |
| Writing the cmux resume binding | Hook-owned, single-slot — cide reads only |
| Storing ephemeral ws/pane/surface refs in the durable registry | Refs recycle, UUIDs don't survive restart; derive live via checkpoint_id |
| cide-native keyboard hotkeys | cmux can't bind shell commands; document a WM snippet instead |
| Graphite (`gt`) | Mandatory SaaS backend + telemetry + token custody |
| octorus AI-Rally | External-LLM egress |
| octo.nvim pattern | Neovim-only, doesn't transfer to helix |
| git-branchless dependency | Dormant since 2023 — inspiration only |
| gitui in v1 | Likely unmaintained; no parent-blame loop |
| In-prompt CI polling / cron poller | launchd LaunchAgent + file-read segment (structural zero-egress) |
| Single prompt engine | Dual-engine config-as-choice (starship default, omp locked-down) |
| Custom notify pane | cmux Feed is the notification surface |
| Custom command picker | cmux Command Palette registration |
| Teams wrappers as default agent launch | Bare agent + hooks capture; teams = opt-in variant |
| `POST /pulls/{n}/comments` for inline review | 422s — use `/reviews` with `comments[]` (cli/cli#13358) |
| Hand-authored golden fixtures | Fixture-provenance rule: captured-from-real only |
| Speculative 6-level config cascade / full type-DSL now | Minimal-first; Rule of Two triggers |
| AskUserQuestion menus mid-exploration | Open dialogue preferred |
| Scrubbing synthetic healthcare-shaped data | No PHI concern — synthetic is safe by design |

## 19. Deliberately OPEN (the vision may engage these — nothing else)

- Runner default home: Dock vs layout tile; formalize `.cmux/` composition into the
  template or discard (Christopher's verdict pending).
- Agent registration guard: explicit `--as-agent` flag vs guard-if-alive; where the agent
  pane regenerates (needs layout-as-data); codex session/resume flags (probe was empty —
  verify before shipping).
- Prompt: db-context segment; CI segment richness; instance/role indicator; transient
  prompt; vendoring `bkt` in Rust.
- PR review: exact extension flags; helix-native review-file wrapper; tuicr thread
  ingestion in newer versions.
- Stacked diffs: LFS/submodule audit of target repos (jj gate); `gh stack` GA; blessed
  in-pane viewer; bundle-vs-detect jj; restack-on-edit for plain git.
- Blame: transient overlay vs persistent side-pane; custom tigrc; delta `file://`
  hyperlinks for the return loop.
- Window lifecycle: `cmux close-window` reliability; ghost-window cleanup;
  default-branch cross-window scoping; `move-ide` full-flow verify.
- Colleague-extension mechanism (Rust PR vs config-declared command template with pinned
  contract) — a /shape decision.
- True-air-gap vs no-third-party-SaaS scoping of the PR/GitHub area in v1 (the egress
  ladder is settled; this is the v1 scope cut).
- Exact port set for v1; how much layout customization v1 exposes; richer browser-port
  verbs; the base/dbt line drift toward "data-aware base" (revisit at synthesis).

---

## Sources

Local repo (`/Users/cmbays/github/cmux-workspace-dbt`):
- `/Users/cmbays/github/cmux-workspace-dbt/.claude/architecture-direction.md` — the converged design record: hexagonal model, council verdict, Rust GO, naming/crates, verb altitude, base/dbt split, IDE-instance model, layout presets, artifact pane, dogfood lessons, substrate findings.
- `/Users/cmbays/github/cmux-workspace-dbt/.claude/focus.md` — current state, runner shape (watchexec/catalog/bacon/mprocs/Dock/Palette/Feed), load-bearing cmux facts, working agreements.
- `/Users/cmbays/github/cmux-workspace-dbt/.claude/base-ide-toolkit.md` — viewer/monitoring wave, harlequin/duckdb egress verification, editor-target resilience, IDE-instance Phase 1, cide-jump/WM-hotkey finding, DB-target config.
- `/Users/cmbays/github/cmux-workspace-dbt/.cmux/SMOKE-TEST.md` — the cmux composition probe (Palette/Dock/Feed/native commands; runner + mprocs + bacon framing; the two open forks).
- `/Users/cmbays/github/cmux-workspace-dbt/cide.toml` — live settled config surface: `[ide]`, `[agents]`, `[theme]`, `[database]`.
- `/Users/cmbays/github/cmux-workspace-dbt/README.md` — Phase-0 `cwd` spine, three config axes, type-gating via marker, bare/stow profiles.

Ops vault (`~/Github/ops`):
- `/Users/cmbays/Github/ops/decisions/cmux-workspace-dbt/2026-06-07-integrations-ux-tooling.md` — the integrations decision record: agent surface, cmux-native agent integration, prompt line, inline PR review, stacked diffs, blame journeys, config-as-choice, instance scope, egress ladder.
- `/Users/cmbays/Github/ops/decisions/cute-dbt/adr-mvp-architecture.md` — cute-dbt ADR-1..5 + amendments (single-crate hexagonal, fail-closed, StateComparator, zero-egress assets, manifest ingestion).
- `/Users/cmbays/Github/ops/decisions/cute-dbt/adr-release-discipline.md` — D1–D6 (crates.io publish, SemVer, release-plz, yank policy, OIDC provenance).
- `/Users/cmbays/Github/ops/decisions/org/adr-gplv3-dev-tools.md` — org default GPL v3 for dev tools.
- `/Users/cmbays/Github/ops/standards/decision-records.md` and `/Users/cmbays/Github/ops/standards/issue-hierarchy.md` — exist; canonical conventions for recording decisions and issue/PR hierarchy (noted, not extracted).
- Note: the "rust-hexagonal-workspace-manager" ADR referenced in architecture-direction.md (ops PR #387) was **not found** under `~/Github/ops/decisions/cmux-workspace-dbt/` — only the 2026-06-07 record exists there; the local architecture-direction.md carries the full content regardless.
- Note: `~/Github/ops/prd/` does not exist; the adjacent dirs are `~/Github/ops/products/` (kata/mokumo/tankyu-rs manifests only — no cide/cute-dbt) and `~/Github/ops/vision/` (no cide entries yet).
