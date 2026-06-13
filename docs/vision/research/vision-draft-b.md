# cide Vision — Draft B: The Composable Platform

> Competing vision draft (B of N) for task #33. Lens: **the IDE as a
> curated-but-swappable platform.** Honors every settled decision in
> `prior-decisions.md`; grounded in this directory's research notes. 2026-06-09.

---

## 1. Thesis

cide is the IDE you assemble once and own forever: a lightweight hexagonal Rust
core that turns the best terminal tools ever built — helix, yazi, lazygit, tig,
harlequin, just, Claude Code — into one coherent IDE on cmux, every capability
behind a trait port (editor, explorer, vcs, runner, warehouse, agent, theme,
placement), defaults fiercely opinionated, every seam a documented swap point.
Verticals are recipes, not forks: an IDE type is data — `{ports used, default
layout, port→adapter bindings, behaviors}` — so base, dbt, and rust-dev are
three profiles over one core, and the tenth vertical costs a recipe, not a
rewrite. The 2025–26 landscape proves the parts are excellent and
the product is missing: every zellij+helix composition re-solves the same five
glue problems badly, every GUI agent IDE rebuilds window management inside
Electron, and the curated-distro wave (Omarchy, LazyVim) shows users begging for
someone else's composition decisions — as long as they can override them. cide's
bet is that **the seams are the moat**: power users adopt opinionated software
exactly when making it theirs doesn't mean forking it.

---

## 2. Pillars

### P1 — The seams are the product

Hexagonal isn't an implementation detail; it's the user-facing promise.
Capabilities are ports; tools are adapters; cmux is the WorkspaceHost substrate
underneath all of them (settled). One port may bind multiple adapters for
different sub-uses — diff already does: hunk for review, delta for paging,
difftastic as the structural lens, `cmux diff` in the browser. The crate DAG
(`cide-core` / `cide-adapters` / `cide-dbt` / `cide`) compile-enforces that the
core knows no tool and no domain. What the user experiences: `cide.toml` names a
choice (`editor = "helix"`), and the verbs (`cide open`, `cide focus`,
`cide review`) keep working when the choice changes — a neovim colleague edits
one line, not one repo. Ports exist only where two real adapters exist or a
vertical demands one, never speculatively.

### P2 — Verticals are recipes, not repos

A workspace type is a *domain concept*: a composition policy declaring which
ports it uses, which adapters bind, and what behaviors run.
`dbt = base ⊕ {viewer(csvlens), warehouse(harlequin), report(cute-dbt), dbt
routing, dbt layout}` — composition, not inheritance. The rust-dev vertical is
the Rule-of-Two validator: when bacon, nextest, and cargo-mutants plug into the
*same* runner/status/review machinery dbt uses, the type seams are proven and the
type registry crystallizes (its settled trigger). This is the leverage engine:
every base investment is inherited by every vertical, and vertical-specific
moats (local-first dbt intelligence, the rust quality cockpit) ride on shared
rails. No competitor can assemble a *dbt* IDE or a *rust* IDE this way because
no competitor has a composition layer — they have products.

### P3 — Compose on cmux; own only the meaning

cmux already ships agent capture/resume/hibernation, the Feed, notifications and
unread triage, the diff viewer, browser and markdown surfaces, palette, dock,
and a cursor-resumable event stream. cide builds none of that. cide owns
**meaning**: roles, spaces, vault identity, journeys (review queue, fix-on-red,
merge-back), and vertical recipes. The API audit found the gold mostly untapped —
events, `workspace.group.*`, `diff --source last-turn`, the status API,
`surface resume`, `pipe-pane`/`wait-for` — so the near-term roadmap is largely
*routing existing GUI-grade machinery through cide semantics* at near-zero UI
cost. Reactor posture stays declarative-first: notification-hook policy binaries
in repo-local `.cmux/cmux.json` before any daemon, a daemon only where state
demands it.

### P4 — Configuration is layered choice, and choices are shareable artifacts

The config-as-choice pattern (settled) generalizes into the ecosystem story:
every concern — theme, prompt engine, layout preset, runner catalog, keymap, DB
target, agent roster — is a registry of named options with an opinionated
default and free override. Layering is exactly three levels: cide defaults →
user presets from dotfiles → repo-local `cide.toml` + `.cmux/` wins. Never
`~/.config`; the repo ships zero personal data; anything global flows through
one explicit, consented, reversible `cide setup` step. Because layouts are
cmux's own JSON with capability tokens, themes are name-maps, and catalogs are
TOML, **every customization is a data artifact you can commit, diff, and hand to
a colleague** — layout packs, theme packs, vertical recipes. That's how a solo
founder's tool grows an ecosystem without a plugin marketplace: the unit of
sharing is a file, not a binary.

### P5 — Trust is a swap-safe contract

Two contracts make "swappable" true instead of aspirational. The egress
contract: every adapter declares its required tools and an egress label
(`zero` | `defensible-egress` | `telemetry-disabled-verified`); `cide doctor`
prints your exact network surface; the base IDE is air-gappable by construction.
The fidelity contract: a typed cmux socket client, golden fixtures *generated
from a real cmux* (never hand-authored — G1's lesson), per-port conformance
suites, and the 113-assertion POSIX golden master as the strangler-fig
behavioral spec. Swapping an adapter or upgrading cmux is verified, not vibed.
For the zero-egress buyer — analytics teams near sensitive data, air-gapped
orgs, the founder's own colleagues — this is the feature no GUI competitor will
match, because their business models forbid it.

---

## 3. A day in the life

**08:50 — open.** You hit the sessionizer chord; a television channel lists
repos, worktrees, and spaces. You pick `mart-rework`, closed Thursday.
`cide space open` rebuilds the landscape-portrait layout on the right monitors,
reopens yazi, helix, and the runner dock tile, restores the harlequin session
against the dev DuckDB (read-only, no writer-lock fight), and relaunches
`claude --name mart-rework --resume <checkpoint>` — the agent continues the
*conversation* where it stopped, mid-plan. The space's sidebar group is orange
(dbt vertical), a status pill already showing `3 models modified vs prod`.

**09:00 — coding.** You edit `stg_claims.sql` in helix; the dbt LSP flags an
unknown ref; compile-on-save feeds diagnostics to the status bus. You ask the
agent to draft the downstream mart change while you fix staging — both visible
at once, editor portrait, agent landscape.

**10:30 — testing.** The runner (watchexec engine, dbt catalog) re-runs
`dbt build --select state:modified+` on save; the dock tile flips red, the
offending pane flashes, a Feed card carries the failing test. You hit the
fix-on-red verb: cide routes the failure tail *plus the compiled SQL path* into
the agent's prompt, and you watch the agent work in one pane while the runner
goes green in the other. Palette: `dbt: review my changes` — compile, cute-dbt
against the baseline manifest cide snapshotted at branch checkout, report opened
as a themed `file://` browser surface beside the lineage DAG.

**13:00 — context switch.** Afternoon is Rust work on cide itself. Same chords,
different recipe: the sessionizer opens the `cmux-ide` space, the catalog
detects cargo and takes the bacon fast-path, status pills read
`clippy ✓ · nextest 2 failing`, and the same fix-on-red verb attaches
`.bacon-locations` instead of compiled SQL. Nothing about your hands changed;
only the recipe did. That symmetry *is* the product.

**15:30 — review.** Two agents finished turns while you coded. `cide review`
walks the unreviewed-turn queue: each stop opens `cmux diff --source last-turn`
beside that agent's pane; accept moves on, comment sends your note straight back
into the agent's prompt. The third item in the queue is a colleague's PR — same
surface, fed by `gh pr diff`.

**17:40 — close.** `cide space close mart-rework`: agent checkpoints captured,
tool sessions stamped via `surface resume`, history appended; `gh pr create`
from the merge-back journey. Tomorrow, `open` resumes the whole working
session — layout, tools, *and* conversations — as one unit. Nobody else in the
field restores more than pane geometry.

---

## 4. Capability map

### Table stakes (the 2026 bar — met by composition, not invention)

| Capability | cide answer |
|---|---|
| Project/space switching + restore | spaces + worktree/agent-aware sessionizer; semantic restore |
| Fuzzy picker / global grep | television channels (files, grep, models, spaces) |
| File tree wired to editor | yazi + DDS control + `cide open` (identity-addressed, no zide-class adjacency hacks) |
| Project-wide search & replace | one atomic `cide replace` verb: write-all → serpl → reload-all (kills the unsaved-buffer hazard) |
| Git suite | lazygit + tig spine + delta pager + hunk review + blame journey |
| Runner / test pane | cide-run engine + catalog (just/make/npm/cargo, bacon fast-path) |
| Unified theming | cide-theme name-swap across all tools, cmux included |
| Keybinding discoverability | palette taxonomy + tmux-style chords on cide actions; consented setup |
| Status & notifications | cmux status API + Feed; jump-to-unread triage |
| Health/trust check | `cide doctor` (config, hooks, adapters, egress labels) |

### Differentiators (what nobody else can claim)

- **Swap without forking** — ports with curated defaults and documented seams;
  conformance suites make a swap verifiable.
- **Verticals as data** — dbt and rust as recipes over one core; vertical moats
  (dbt intelligence ladder, rust quality cockpit) on shared rails.
- **Agent-native semantics** — turn-review queue, fix-on-red, worktree-per-agent
  spaces, multi-agent resume, fleet triage with needs-approval ≠ idle ≠ running.
- **Semantic session restore** — layout + tool state + agent conversations as
  one resumable object; the field restores geometry at best.
- **Zero-egress, provably** — per-adapter egress labels, air-gappable base,
  doctor as the printed network surface.
- **Shareable composition artifacts** — layout packs, theme packs, catalogs,
  recipes: ecosystem growth without a plugin runtime.

---

## 5. Top bets

1. **cide-run runner engine** (backlog #1, task #23). The first strangler slice
   and the keystone port: watchexec-as-crate engine, catalog as an adapter
   registry, bacon fast-path, composed onto Dock/Palette/Feed. Four other bets
   hang off it; the dogfood engine literally becomes the Rust engine.
2. **Event reactor backbone** (backlog #3). The EventBus port, declarative-first:
   a notification-hook policy binary in `.cmux/cmux.json`, plus a small Rust
   daemon on `cmux events --cursor-file` for stateful reactions. Converts cide
   from polling scripts into a reactive system; feeds bets 3, 4, 8.
3. **Agent-turn review queue — `cide review`** (backlog #2). The diff queue is
   the new inbox; cmux ships the hard part (`diff --source last-turn`). cide adds
   routing + queue semantics; the same surface hosts PR review and stacked
   patches. Highest agent-wedge-per-effort in the backlog.
4. **IDE status bus + attention engineering** (backlog #4). Adopt
   set-status/set-progress/log + unread machinery as the StatusPort — GUI-grade
   status with zero UI code, inherited by every vertical.
5. **Native space containers** (backlog #6). Migrate spaces from hidden
   description tags to `workspace.group.*` with per-vertical color/icon; the
   registry stays the cross-monitor join. Spaces become visible, first-class
   containers.
6. **Generalized resume + layout capture → preset packs** (backlog #7, task
   #30). `surface resume` for every tool surface, `vault.agents` for
   harlequin-class tools, `cide capture-layout` turning any hand-tuned live
   workspace into replayable JSON. The ecosystem seed: composition becomes a
   shareable file.
7. **cute-dbt review loop + baseline lifecycle** (backlog #5). The dbt
   vertical's identity move behind a `DbtReviewPort`: compile → cute-dbt vs
   merge-base baseline → themed `file://` browser surface; cide owns baselines
   and PreflightError→Feed remediation. First proof that verticals-as-recipes
   works.
8. **Worktree-per-agent spaces + agent-aware sessionizer** (backlog #8). The
   2025–26 consensus isolation model, terminal-native and zero-egress; matches
   the worktrees-exclusively discipline. Worktree-aware like tms, agent-aware
   like nobody.
9. **Adapter manifest + `cide doctor` trust surface** (backlog #17, elevated by
   this lens). Doctor wraps cmux's doctor/capabilities/hooks state and prints
   the exact network surface; onboarding flips telemetry off, consented. Turns
   the egress ladder into the org-distribution unlock.
10. **cide keymap layer + palette taxonomy** (backlog #14). Chords bound to cide
    actions, plus-button = New cide Space, per-vertical tab-bar buttons — the
    whole verb surface discoverable from Cmd+Shift+P, via the one consented
    `cide setup` step.
11. **Port conformance kit** (lens-added; promoted from the backlog's "scaffold
    intrinsics"). Typed socket client, generated golden fixtures, per-port
    conformance suites, POSIX golden master as migration spec — published as a
    first-class artifact, because it's also the colleague-extension on-ramp:
    "write an adapter, pass the suite." (Rust PR vs pinned-contract command
    template stays the open /shape decision.)

Sequencing: bets 1 and 2 are the load-bearing first Rust slices alongside bet
11's scaffold; bet 3 v1 ships on declarative hooks alone; bet 7 can ship from
the POSIX dogfood tomorrow. The L-rated vertical moats (dbt intelligence ladder
#12, harlequin bridge #13, rust cockpit #15) are phased ladders the recipes
climb, not v1 scope.

---

## 6. Non-goals

- **Not an editor.** cide never renders a buffer, never builds LSP UI. helix is
  one artifact adapter among several; tool sovereignty is the point.
- **No plugin runtime, no marketplace, no drop-a-file shell-adapter framework**
  (settled rejection — it reintroduces the stringly-typed G1 boundary).
  Extensibility = Rust adapters behind ports + data artifacts, full stop.
- **No SaaS, no telemetry, no cloud sync, no external-LLM features.** `cmux
  vm/cloud` is out of scope. GitHub via `gh` is the only defensible egress,
  opt-in and labeled.
- **Never rebuild what cmux ships natively** — no approval UI, no notifier, no
  diff renderer, no command picker, no session-capture system, no event
  transport. cide reads and routes; it does not replace.
- **No fork-per-vertical repos; no type DSL before the rust vertical demands
  one** (Rule-of-Two trigger, settled).
- **No `~/.config` writes, ever; no silent setup.** One consented `cide setup`
  gathers every global-state need (keymap, sidebar, telemetry flip).
- **No cross-multiplexer support in v1.** cmux behind the WorkspaceHost port
  keeps the Linux/tmux/zellij door open; promising it now dilutes the wedge.
- **Not a committee of preferences.** 2–3 curated options per concern, one
  opinionated default. The override exists so the default can be strong.

---

## 7. Why a cmux power user adopts — the must-have argument

The terminal power user has already made the hard choices: helix over an IDE
buffer, lazygit over a git panel, harlequin over a SQL tab, Claude Code in a
pane. What they don't have is the connective tissue, and everyone feels it:
keystroke-injection IPC with positional addressing, session restore that
recovers geometry but not meaning, N theme formats, no which-key for the
workspace, sessionizer homework, agents bolted into bare panes with no review
loop. The DIY answer is personal shell glue that breaks on every upgrade; the
GUI answer (Zed, Warp, Cursor) surrenders tool sovereignty and, usually,
locality.

cide is the only offer that refuses that trade. Adoption cost approaches zero:
your tools, your muscle memory, your repos — cide supplies the shared workspace
model they never had, addressed by identity over cmux RPC instead of pane
position and prayer. The payoff compounds daily: spaces that reopen with
conversations intact, a review queue for agent turns, a runner that feeds
failures to the agent with structured context, one theme command, one verb
grammar across dbt mornings and Rust afternoons. And the platform promise
removes the risk that kills opinionated tools: nothing locks in. Every default
is your tool; every seam is documented; every customization is a shareable
file; `cide doctor` proves it never phones home. You can make it yours on day
one and still run it, unforked, in five years — which no DIY composition and no
GUI IDE can say.
