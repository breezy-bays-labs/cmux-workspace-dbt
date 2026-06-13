# cide — Product Vision

> The approval-gate document for the Rust build. Companion: [design-plan.md](design-plan.md)
> (architecture — all structural content lives there, not here). Evidence corpus: [research/](research/).
> Settled inputs honored throughout: the unanimous Draft C base vision
> ([research/base-vision-synthesis.md](research/base-vision-synthesis.md)), the daemonless Sketch A
> architecture ([research/arch-decision.md](research/arch-decision.md)), and every locked decision in
> [research/prior-decisions.md](research/prior-decisions.md). 2026-06-09.

---

## 1. Executive summary

**cide is a terminal IDE composed on cmux, designed around human+agent pair work.** Not an editor
(helix stays sovereign), not an agent (Claude Code stays the agent), not a plugin platform. It is the
meaning layer — spaces, roles, review queues, journeys, vertical recipes — over the only multiplexer
anywhere that ships agent primitives natively.

**The thesis.** The IDE category forked in 2025: editors became control planes for agents, and every
vendor — Zed, Cursor, Warp, Antigravity, GitHub Agent HQ — rebuilt the same four primitives (session
capture, approvals, per-turn diff review, notification triage) inside a GUI shell coupled to SaaS
([research/agent-native-landscape.md](research/agent-native-landscape.md) §B). Meanwhile the terminal,
where agents actually run, got duct-taped tmux. cmux ships those primitives natively — lifecycle hooks
for 15 agents, the Feed approval surface, `diff --source last-turn`, a cursor-resumable event bus,
agent teams inside Ghostty — and the API audit shows that surface largely untapped
([research/cmux-api-surface.md](research/cmux-api-surface.md) §19). cide exploits that monopoly: a
space is a resumable, conversation-bearing unit of work; every agent turn lands in a review queue;
failures route themselves as structured diagnostics to the agent that owns them; and the whole control
plane is a greppable local file instead of a SaaS dashboard.

**Why now.** Three windows are open at once and none stays open forever: (1) cmux's agent surface
exists and nobody composes it; (2) helix structurally cannot grow IDE panels for 1–2 years (Steel PR
#8675 still unmerged, re-verified live June 2026; no runnables, DAP experimental —
[research/rust-landscape.md](research/rust-landscape.md) §3.3; the 1–2-year horizon is §5's forecast,
re-verify at rust-dev shaping), so "IDE beside the editor" is the only way this audience gets one;
(3) dbt's engine just went Apache 2.0 Rust (Core v2 alpha, June 2026) while its intelligence tier
went sign-in-gated SaaS ([research/dbt-landscape.md](research/dbt-landscape.md) §1) — the license
event stands regardless of maturity, handing a zero-egress terminal tool both the parts and the
positioning.

**The proof already exists — with one honest asterisk.** Today cide is a POSIX-sh dogfood worked in
daily: spaces with layout-as-data, monitor-aware placement, a multi-tool theme system, and Phase 2's
shipped close/open agent-checkpoint mechanism — layout + conversation as one resumable object, which
nothing else in the field has (single-session resume is mainstream; even Claude's own agent teams
cannot resume teammates — [research/agent-native-landscape.md](research/agent-native-landscape.md)
§B.4). The asterisk: the live resume round-trip verify is still pending — it gates task #29 and is
the hard R3 gate ([research/cide-current-state.md](research/cide-current-state.md) §5). The vision
unanimously selected by a three-judge panel (Draft C, 3–0) keeps that spine and commits to seven
pillars: resumable spaces, the review queue as the primary loop, engineered attention, closed loops
with the human ON the loop, agents as IDE users, budgeted latency, verticals as recipes.

**What approval unlocks.** The Rust build: a daemonless, library-first single binary where the
multiplexer is the supervisor — sync code, no tokio, plan/execute split, atomic state files —
migrating from the shell dogfood strangler-fig style against a 113-assertion golden master. Crates,
ports, and the seven grafts: [design-plan.md](design-plan.md). This document sells the product; that
one specifies the machine.

---

## 2. The wedge — why this wins

### DIY composition pain is documented, not hypothesized

Every tmux/zellij+helix composition re-solves the same five problems with shell glue and openly
documents the failure ([research/terminal-ide-landscape.md](research/terminal-ide-landscape.md) §5):

| Pain | Evidence |
|---|---|
| No real IPC — keystroke injection + positional addressing | zide's README admits the editor pane *must sit adjacent* to the picker because zellij can't address panes by identity |
| Search/replace eats unsaved buffers | the helix+serpl wiring writeup concedes the hazard and the manual `:reload-all` |
| Session restore is geometry-only and flaky | tmux-resurrect's known failure modes; zellij resurrection roadmap-grade; nobody restores *semantic* state |
| Per-tool theming | tinted-theming (tinty/flavours) is an entire ecosystem built to patch this one pain |
| Discoverability & switching | tmux has no which-key; project switching is five+ tools of homework (sessionizer, tms, smug, sesh, tmuxinator) |

Omarchy's popularity is the demand signal that power users want someone else to make the composition
decisions while keeping terminal-native tools. cide is omakase without the distro: curated defaults,
repo-local config, zero `~/.config` pollution.

### GUI editors are terminal-hostile by construction

The defection destinations all demand giving something up: Zed requires adopting Zed-the-editor and
phones home for AI; Warp is SaaS-coupled and telemetry-heavy; Cursor/Antigravity are Electron shells.
The audience's best tools — lazygit, yazi, harlequin, helix — are *better* than the IDE-panel
equivalents; compositions win per-panel and lose only on glue. cide keeps the tools sovereign and owns
only the glue.

### cmux's monopoly on native agent primitives

cmux advertises a ~200-method RPC surface that includes a native agent control plane
([research/cmux-api-surface.md](research/cmux-api-surface.md) §0): hook-captured sessions for 15 agents with
resume checkpoints, the Feed (blocking approval cards + a `workstream.jsonl` audit log),
`cmux diff --source last-turn`, a reconnectable cursor-tracked `cmux events` stream, `surface resume`
for arbitrary tools, `vault.agents`, agent hibernation, and the `claude-teams` shim — the only way
split-pane Agent Teams run in Ghostty at all. The dogfood audit found the events stream unread by
anything, the diff viewer running `--help` as a placeholder, and `workspace.group.*` / `pipe-pane` /
`wait-for` / status-pill APIs untouched ([research/cmux-api-surface.md](research/cmux-api-surface.md)).
cide's differentiators (turn queue, N-slot resume, total resume, local fleet log, Teams-in-Ghostty)
are structurally unavailable to anyone not built on cmux — and cide composes rather than rebuilds, so
it is the only tool that *can* exist at this altitude without re-implementing cmux badly.

### Zero-egress is positioning no competitor's business model permits

Every adapter declares an egress label (`zero` | `defensible-egress` | `telemetry-disabled-verified`);
`cide doctor` audits the network surface of **both layers** — cide's own adapters *and* the cmux
substrate's three documented vectors: telemetry flag state, the Feed TUI's first-run OpenTUI npm
fetch (the generated dock defaults the feed control to `--legacy`), and `browser.reactGrabVersion`
([research/cmux-api-surface.md](research/cmux-api-surface.md) §4, §11, §20). The base IDE is
air-gappable by construction. The terminal-sovereign, zero-egress, agent-heavy developer currently
has **no product at all**. The trust surface also keeps an org-distribution option open — a version
you could hand a colleague near sensitive data — but that is optionality, not v1 reach (next
subsection).

### Why a cmux user especially

If you run cmux and Claude Code today, you own the only multiplexer with native agent primitives and
use almost none of them. The counting argument: a heavy agent user reviews dozens of turns, answers
dozens of approvals, and triages dozens of notifications daily — each one today a manual `git diff`, a
copy-paste into a chat box, a tour of panes. The review queue, fix-on-red loop, and blocked-walk each
amortize a many-times-daily cost, and the latency SLOs (P6) make that compound instead of decay. Day
one costs nothing: your tools stay, your muscle memory stays, nothing touches `~/.config` without
consent.

### Who can actually adopt v1 — the honest funnel

v1's addressable user is Christopher plus macOS cmux users. The tmux/zellij pain evidence above
proves the *problem class*, not v1 reach: that population structurally cannot adopt v1 (no Linux, no
second multiplexer — §8), and the port discipline is what keeps it reachable later. Likewise the
forward-looking claims — org distribution, layout/theme/recipe packs, the colleague on-ramp — are
optionality riding the same discipline, with zero demand evidence beyond persona zero today. The
must-have case that stands on evidence now is the cmux-user case above; who user #2 is, and what
evidence triggers a distribution investment, is an explicit open question (§9).

---

## 3. The base IDE

**Thesis:** the primary loop is a human directing and verifying resident agents. The editor is one
surface among several; the agent pane is the other half of the pair. Full statement:
[research/base-vision-synthesis.md](research/base-vision-synthesis.md).

### The seven pillars

**P1 — The space is the unit of work; closing it is a checkpoint, not a loss.** A space = layout +
repo/worktree + role-stamped agent conversations + runner state + tool sessions, resumed as one
object. Phase 2 shipped the close/open checkpoint mechanism (the live round-trip verify is pending —
it gates task #29 and R3, [research/cide-current-state.md](research/cide-current-state.md) §5); the
vision generalizes to
N role slots (`agent:builder`, `agent:reviewer`) with `fork`/`revive`, and to every non-agent surface.
Nothing is ever set up twice. *(hook-session stores, `claude --resume`, `surface resume`,
`vault.agents`; backlog #11, #7.)*

**P2 — Review is the primary loop; the diff queue is the new inbox.** Turn completes → diff appears
beside the agent, no focus steal. `cide review` walks unreviewed turns across every agent in the
space; commenting is `cmux send` back into the conversation. The same surface hosts `gh pr diff` and
stacked patches — one review muscle for agent turns and human PRs alike.
*(`cmux diff --source last-turn`, `agent.hook.Stop`, notifications.hooks, Feed; backlog #2.)*

**P3 — Attention is the scarce resource; engineer it and govern the fleet.** cide distinguishes
**needs-approval** (the agent-side prompt blocks; the Feed card parks the hook ≤120 s, advisory —
[research/cmux-api-surface.md](research/cmux-api-surface.md) §4, an expiry the cockpit must encode)
vs **idle** vs **running** — the states GUI tools blur — and
walks blocked agents the way Cmd+Shift+U walks unreads. A notification-policy binary silences agent
chatter while the editor is focused and escalates runner reds; the prompt carries `agents: 2▶ 1✋ 1💤`;
`cide top` + global hibernation tuning keep a six-space fleet snappy on one laptop (cmux's
hibernation knob is app-global — per-space budgets are the destination, reactor-gated or
upstream-dependent; [research/cmux-api-surface.md](research/cmux-api-surface.md) §5).
*(notifications.hooks, feed.list, set-status/trigger-flash/jump-to-unread, agent-hibernation;
backlog #4, #10, #17.)*

**P4 — Closed loops, human ON the loop.** Runner fails → the agent gets structured diagnostics
(file:line, `.bacon-locations`, compiled-SQL paths — never pasted ANSI) → the fix lands in the review
queue → approval happens in the Feed. Autonomy is composed, never assumed.
*(pipe-pane parser + `cmux send`/`workspace.prompt_submit` + Feed; backlog #9 on rails from #1 + #3.)*

**P5 — Agents are users of the IDE too.** Every cide verb is machine-callable with `--json` and a
stable contract, shipped with a repo-local agent skill. The resident agent opens files, focuses the
runner, queues diffs, and reads space state through the same registry as the human.
*(serde on the same structs; the frozen cide-json contract crate — design-plan graft g4.)*

**P6 — One tool, at budgeted latency, reachable from the keys.** Flow SLOs are release blockers:
interactive verbs feel instant, space-switch sub-second, space-open in seconds — CI-tested, backed by
a direct socket-v2 `Multiplexer` port, push hooks + `wait-for` barriers, and durable-log cursor
catch-up instead of settle-polling (the promotion-gated reactor is the escape hatch, not the plan —
[design-plan.md](design-plan.md) §7).
Keystroke-complete: every verb is a palette action and a tmux-style chord via one consented
`cide setup`. Cohesion: the atomic `cide replace` (write-all → serpl → reload-all, killing the
documented unsaved-buffer hazard), the `focus` fan-out chord (one subject, every surface re-centered),
one-stroke theming including addstyle-themed browser surfaces.
*(shortcuts chords on the actions registry, palette keywords, plus-button/tab-bar; backlog #14, #19.)*

**P7 — Verticals are recipes over swap-safe, trust-labeled seams.** A workspace type is data:
`{ports used, default layout, port→adapter bindings, behaviors}`; `dbt = base ⊕ {viewer(csvlens),
warehouse(harlequin), report(cute-dbt), dbt routing, dbt layout}`; rust-dev is the Rule-of-Two
validator. Three contracts keep the seams honest: fidelity (typed socket client, golden fixtures
generated from a real cmux, the 113-assertion POSIX golden master), swap (a neovim colleague edits one
line of `cide.toml`, not one repo), and egress (per-adapter labels; doctor prints the network
surface). Every customization is a committable, diffable, handable file — layout/theme/catalog/recipe
packs keep ecosystem growth *possible* without a plugin runtime (optionality, not a v1 promise — §2).
*(capability-token layout JSON, TOML catalogs, the conformance kit — [design-plan.md](design-plan.md).)*

### A day in the life (condensed; full narrative in the synthesis §3)

**08:40** — sessionizer chord → `mart-rework`, a dbt worktree space closed Friday. Under ten seconds:
helix with Friday's model open, harlequin re-attached read-only, runner tile live, both conversations
resumed, one unreviewed Friday turn in the queue. `cide review` opens it beside the pane; a one-line
comment lands via `cmux send`. Zero "where was I."
**09:15** — he codes the staging half; builder owns the downstream mart. A save goes red; cide routes
the structured failure to builder; a Feed card asks to edit; one keystroke approves; the fix arrives
as a queued diff. No error message was ever copied.
**13:00** — afternoon is Rust work on cide itself. Same chords, different recipe: bacon fast-path,
pills read `clippy ✓ · nextest 2 failing`, fix-on-red attaches `.bacon-locations` instead of compiled
SQL. **Nothing about your hands changed; only the recipe did.**
**18:00** — `cide space close` snapshots checkpoints and surface-resume stamps. `cide-agent log
--today` prints the day's fleet record — every turn, approval, denial, per space — a local greppable
file. No dashboard. No cloud.

### Capability map

**Table stakes** (the LazyVim / VS Code 2026 bar, met by composition):

| Capability | cide answer |
|---|---|
| Fuzzy picker / global grep | television channels (files, grep, models, spaces) + palette |
| File tree wired to editor | yazi, DDS-controlled, identity-addressed |
| Git suite | lazygit + tig spine + delta + hunk + difftastic; blame→diff→history journey |
| Project-wide search & replace | atomic `cide replace` (unsaved-buffer hazard killed) |
| Session restore | spaces — geometry **and** semantics |
| Project/worktree switching | agent-aware sessionizer; sub-second (SLO) |
| Test/task runner | cide-run engine + catalog (just/make/npm/cargo, bacon fast-path) |
| Unified theming | `cide theme`, one stroke, incl. cmux/Ghostty + addstyle browser surfaces |
| Keybinding discoverability | chords + palette keyword taxonomy = workspace-wide which-key |
| Status & notifications | cmux status pills, progress bars, flash, jump-to-unread |
| Health/trust check | `cide doctor` (printed network surface), `cide top` |
| Native space containers | `workspace.group.*`: visible, colored, collapsible |

**Differentiators** (no terminal tool has any; no GUI tool has them zero-egress):

| Capability | Why only cide |
|---|---|
| Agent-turn review queue | cmux alone snapshots per-surface turns natively |
| N-slot resume + fork/revive; total resume of tools *and* conversations | the field cannot resume teammates; competitors restore pane geometry at best |
| Worktree-per-agent spaces + agent-aware sessionizer | the 2025–26 isolation consensus, terminal-native, zero-egress |
| Fix-on-red structured diagnostics routing | nobody feeds agents structured failure context |
| Triage cockpit + local fleet log + focus-aware notification policy | every competitor's mission control is SaaS; cmux's hooks pipeline is unique substrate |
| Sub-second context switch **as a tested SLO** | the DIY pain list, deleted, kept deleted by CI |
| Verticals as recipes + shareable artifacts | recipe seams proven in v1; the pack ecosystem is post-v1 optionality, no plugin runtime |
| Zero-egress, provably | doctor prints the network surface; air-gappable by construction |
| `cide-team`: Agent Teams in Ghostty | unsupported everywhere except cmux's shim |
| Machine-first verb surface | the first IDE the agent can *drive*, not just live in |

---

## 4. Top improvements backlog

Ranked top 20 (full scoring, dedupe map, per-item reasoning:
[research/opportunity-backlog.md](research/opportunity-backlog.md)):

| # | Opportunity | Layer | Effort | Impact | Key cmux primitive | What |
|---|---|---|---|---|---|---|
| 1 | cide-run runner engine | cross | M | 5 | Dock, pipe-pane, respawn-pane, wait-for | wrapped-watchexec engine (external binary via `cide run wrap`) + pluggable catalog + bacon fast-path; the keystone port |
| 2 | Agent-turn review queue (`cide review`) | agent | M | 5 | `diff --source last-turn`, agent.hook.Stop | walk unreviewed turns across all agents; comment = `cmux send` |
| 3 | Event reactor backbone (declarative-first) | cross | M | 5 | notifications.hooks, `events --cursor-file` | policy hook binary + promotion-gated reactor (cmux-supervised dock control, built only if the g3 gate trips — design-plan §7); the death of settle-polling |
| 4 | IDE status bus + attention engineering | base | S | 4 | set-status/set-progress, trigger-flash | pills, progress bars, failure→unread→jump triage, zero UI code |
| 5 | cute-dbt review loop + baseline lifecycle | dbt | M | 5 | browser surfaces, palette, Feed | compile → cute-dbt vs baseline → themed `file://` report surface |
| 6 | Native space containers (workspace.group.*) | base | M | 4 | workspace.group.* (17 RPCs) | replace description-tag hack with visible, colored, collapsible groups |
| 7 | Generalized resume + layout capture | cross | M | 4 | surface resume set, vault.agents | stamp harlequin/runners/`just dev`; capture live layouts as replayable JSON |
| 8 | Worktree-per-agent spaces + sessionizer | agent | M | 4 | hooks store, `diff --source branch` | one verb births worktree + space + labeled agent; merge-back journey |
| 9 | Runner→agent fix-on-red loop | agent | S | 4 | pipe-pane, send, prompt_submit | structured failure → agent prompt → fix in review queue |
| 10 | Agent triage cockpit + fleet log | agent | M | 4 | feed.list, events, workstream.jsonl | needs-approval vs idle vs running; `--next-blocked` walk; local fleet log |
| 11 | Multi-agent space resume (N role slots) | agent | M | 4 | hook-sessions, claude --resume | role slots + fork/revive; generalizes the proven Phase-2 single slot |
| 12 | Local-first dbt intelligence ladder | dbt | L | 5 | (engine-side; status bus surfaces) | LSP-now → watch-compile → L2-class intelligence on Apache 2.0 v2 crates |
| 13 | dbt-aware harlequin bridge + defer/slim | dbt | L | 4 | palette, runner catalog | compile-then-execute with refs resolved; one-key managed defer |
| 14 | cide keymap layer + workspace which-key | base | S | 3 | shortcuts chords, plus-button, tab-bar | tmux-style chords on cide verbs; one consented `cide setup` |
| 15 | Rust quality cockpit | rust | L | 4 | runner pane, Feed, browser surfaces | test-tree, mutant triage TUI, coverage triage, unified pill row |
| 16 | Spaces dashboard + consented sidebar | base | M | 3 | extension.sidebar.snapshot | mission-control surface from structured snapshots, no scraping |
| 17 | cide doctor / cide top (trust surface) | cross | S | 3 | config doctor --json, top, hibernation | egress-label aggregation (cide adapters + cmux substrate); RAM governor (global tuning now; per-space gated) |
| 18 | cide-team: Ghostty home for Agent Teams | agent | S | 3 | claude-teams shim, layout JSON | teams as nameable, placeable, partially-revivable layouts |
| 19 | Cross-tool journeys + safe S&R verb | base | M | 3 | find-window --content, set-buffer | blame→diff→history, send-selection-to-agent, atomic replace |
| 20 | Artifact surfaces (live plan pane) | agent | S | 3 | markdown open (live-reload) | agent writes PLAN.md → live pane; verify the logic, not just the diff |

**Sequencing logic.** #1 and #3 are the load-bearing investments — #1 feeds #4/#9/#13/#15, #3 feeds
#2/#4/#9/#10/#16 — and both are strangler-aligned natural first Rust slices. #2 ships a v1 on
declarative hooks alone; never block the review queue on the gated reactor. #5 is independent of
everything and shippable **from the POSIX dogfood now** — the dbt vertical's identity demo and the
first proof of verticals-as-recipes, ranked high so base-IDE focus does not orphan it. To pin the
sequence against design-plan coexistence rule (4): the #5 dogfood slice ships in shell **before R1
begins**; once R1 lands, further dbt capability waits for R5. #12/#13/#15 are L-effort
vertical moats with phased rungs, not v1 scope. Everything touching `~/.config` (#14, #16, the
telemetry flip in #17) flows through one consented `cide setup` UX, designed once. The synthesis's
ranked bets put the keymap first as the cheapest reachability unlock, then the review queue as the
flagship.

**Appetite and the v1 line.** Effort classes above are estimates; phases get *budgets* — when a
phase blows its box, scope is cut, not the box (solo-founder work running beside mokumo and ops;
M = 1–3 weeks per [research/opportunity-backlog.md](research/opportunity-backlog.md)). R1+R2 share a
six-week appetite; R3+R4 share six more; the dbt-recipe slice of R5 gets three. **v1 = R1–R4 plus
the R5 dbt-recipe slice** (the cute-dbt review loop, backlog #5, as the recipe proof); #12/#13/#15
are post-v1 programs. **The post-R2 boundary is an explicit re-approval checkpoint:** golden-master
parity holding plus the runner shipping in Rust is the evidence the architecture bet paid off —
Christopher re-evaluates there, before the crown jewels (R3 spaces/resume) ride those rails.

**How we'll know — and what kills it.** Output (verbs shipped) is not the thesis; observed use is.
The local fleet log and state files already record every turn, approval, and review per space, so
the dogfood metrics read for free:

- ≥80% of agent turns reviewed via `cide review` within two weeks of R4 landing (P2's direct test);
- `cide space open` chosen over fresh setup ≥5×/week from R3 on (P1);
- fix-on-red fires in anger ≥1×/day in the rust-dev dogfood space once the loop lands (P4);
- review-hop and space-switch latency inside the P6 budgets in real use, not only in CI.

**Kill condition:** if the review queue goes unused after a month of dogfood, P2 was wrong — the
backlog re-ranks and the flagship slot goes to whichever loop the fleet log shows actually used.

---

## 5. The dbt IDE

Full vertical vision: [research/dbt-ide-vision.md](research/dbt-ide-vision.md).

### Persona

The analytics engineer who lives in jinja-SQL: staging models, marts, schema YAML, macros. Inner loop:
edit → compile → read compiled SQL → run a subset → look at the data. Terminal-native: helix not
VS Code, `dbt build --select state:modified+` not a Run button, worktrees not branch-switching. She
works near data that makes tool trust non-negotiable: credentials in a local `profiles.yml`, org risk
posture zero-egress. Persona zero is Christopher — dbt at the employer, cute-dbt as his own
gap-filler, the exact toolchain already on disk.

### The structural insight

**The best tier of dbt intelligence (L2) moved into surfaces she cannot or will not use.** The
official dbt LSP's L2 tier (SQL-comprehension diagnostics, column-level lineage, column/CTE
go-to-definition, project-wide rename, CTE preview) ships only inside the VS Code/Cursor extension
and is registration-gated behind a dbt-platform sign-in — a SaaS dependency, an editor defection, and
an egress violation in one move ([research/dbt-landscape.md](research/dbt-landscape.md) §2); L1
(ref/source autocomplete, table-level lineage, go-to-def, compiled-code view) is free and may even
run under helix (open question #7). Meanwhile dbt Core v2 (alpha, June 2026) put the
Rust engine under Apache 2.0, and the terminal already has the fastest engine, best formatter
(sqlfmt), best SQL TUI (harlequin), and best git/agent surfaces — with no composition. That flips the
constraint into the thesis: **all of the intelligence, none of the sign-in.** Zero-egress terminal
intelligence on the open crates is differentiated, not duplicative.

### A day in the dbt IDE (sketch)

Open `mart-rework`: harlequin re-attached read-only to dev DuckDB, runner with the dbt catalog,
Friday's cute-dbt report surface, a pill reading `dbt: 7 modified vs baseline`. Save → Fusion-fast
`dbt compile --select <model>` (Fusion's DuckDB adapter is Beta/CLI-only today and Core v2 is alpha —
the intelligence ladder #12 prices this in); static analysis flags an unknown column *without
touching the warehouse*. The `focus` chord on `stg_claims` fans out: helix centers it, yazi reveals it, harlequin
loads its compiled SQL, the explorer DAG calls `focusModel('stg_claims')`. One keystroke runs the slim
loop (`--defer --state .cide/dbt/baseline`, parents resolved from prod artifacts fetched via gh). A
failing downstream test routes to the builder agent with the compiled-SQL path attached. Palette:
`dbt: review my changes` — compile → cute-dbt vs the baseline cide snapshotted at branch checkout →
the Test Review surface reloads with cell-level semantic fixture diffs. She verifies the *logic*, not
just the text diff. Teammate PRs review through the same surface via `gh pr diff | cute-dbt
--pr-diff`. Close stamps everything, baseline included.

### dbt surfaces

| Surface | Now → destination |
|---|---|
| Lineage | television models channel + dbt-lineage crate → cute-dbt `explore` dag.html (Cytoscape, 372-node-validated) driven via the #105 SemVer'd JS contract → column lineage via the ladder |
| Compiled-SQL preview | runner compile-on-save + viewer pane (iteration-grade) + cute-dbt's exact per-CTE sqlparser slices (review-grade) |
| DAG-aware runner | dbt catalog on the cide-run engine (wrapped watchexec binary): compile-this-model, build modified+ with managed defer, snapshot/fetch baseline, cute-dbt report, sqruff hot / sqlfluff deep; pipe-pane parser emits structured failures for fix-on-red; Fusion/Core v2 preferred, Python v1 a supported degraded mode |
| Warehouse | harlequin, resume-stamped, read-only dev attach, DuckDB default; the missing dbt adapter (no ref() resolution anywhere) is the cide-owned bridge (#13) |
| Docs | cute-dbt detail card + tests.html (common subset); `dbt docs` in themed browser surface interim; Core v2 Parquet artifacts → catalog-as-SQL |
| Editor intelligence | helix + j-clemons LSP (Fusion diagnostics) + Fusion-aligned JSON Schemas now; time-boxed official-LSP spike; destination = cide-native on Apache 2.0 v2 crates (#12) |

### The gap table, summarized

The full 38-row disposition is in [research/dbt-ide-vision.md](research/dbt-ide-vision.md) §5.
Reading: the terminal already covers the build/run/lint/git/AI floor by composition; cute-dbt uniquely
owns comprehension-and-review (its semantic fixture diff and per-CTE slicing exist on no other
platform); and the **four structural open gaps are all cide-owned**:

| Open gap | cide owner |
|---|---|
| L2-class language intelligence (schema-aware completion, hover, rename, column lineage) | intelligence ladder, backlog #12 |
| dbt-aware execution (refs-resolved queries, CTE preview, data diff) | harlequin bridge, backlog #13 |
| Managed defer/baseline lifecycle (snapshot, fetch, staleness) | ranked bet 4 — the flagship |
| Plan/impact preview before run (SQLMesh's best idea, absent from every dbt tool) | the apex differentiator, ladder destination |

That is exactly where a product wants its gaps: in its own backlog, not in someone else's roadmap.

### The cute-dbt gap-fill list (required deliverable)

What cute-dbt should build to make the dbt IDE world-class — ordered, respecting its settled identity
(zero-compute, manifest-only, fail-closed, single-binary, zero-egress;
[research/cute-dbt-capabilities.md](research/cute-dbt-capabilities.md)):

- **F1 — Ship the explore epic (#99: V1–V6, esp. #100/#101/#104/#105).** Already committed,
  priority:soon. dag.html is the lineage pane, the detail card is the docs answer, and **#105's
  external-drive contract (`focusModel()` / `data-selected-model`, SemVer'd) is the integration
  keystone** — a launch dependency of the dbt flagship journey; cide pins the contract version.
- **F2 — Machine-readable CTE-slice output (new proposal).** Expose the already-computed per-CTE
  compiled-SQL extents as JSON (`{model, cte, role, join_type, compiled_sql, span}`). cide feeds a
  slice to the harlequin bridge and **CTE-level preview — which nothing has, anywhere — becomes a
  composition instead of a program.** Execution stays cide's; cute-dbt stays zero-compute.
- **F3 — Manifest-derived health overlay.** Extend #103's test-count badges into a coverage view:
  untested models, undocumented columns, missing unique grain — all from manifest.json alone.
- **F4 — `run_results.json` ingestion (decision needed).** Would close gap #22's display half but
  widens the "reads only manifest.json" posture — needs a deliberate cute-dbt ADR, flagged not assumed.
- **F5 — Committed fidelity widening, sequenced for the IDE:** #160 sub-modifier selectors, #57
  `source()` fixture binding, #15 per-CTE `@desc` docs.
- **F6 — Unblock the crates.io publish (#112)** so `cide doctor` can advise `cargo install cute-dbt`.

Explicit non-asks: no SQL execution, no warehouse drivers, no column lineage, no LSP, no
scaffolding — those belong to cide's ladder or other tools.

### Defensible defaults (dbt recipe)

| Concern | Default | Egress | Notes |
|---|---|---|---|
| Engine | dbt Fusion CLI → Core v2 (Rust) at GA | zero* (verify telemetry) | Python v1 = supported degraded mode |
| Report/review | cute-dbt behind the `DbtReview` port | zero (network-block CI proven) | shell-out in v0.x; crate post-v1.0 |
| Warehouse TUI | harlequin | zero on DuckDB | bridge is the build target |
| Local dev warehouse | DuckDB | structural zero | `autoinstall_known_extensions=false` (settled) |
| Format / lint | sqlfmt · sqruff (hot) · sqlfluff+dbt templater (deep) | zero | sqlfluff not Fusion-native — degrade documented |
| Editor intelligence | helix + j-clemons LSP + Fusion JSON Schemas | zero | destination: cide-native on v2 crates |
| YAML upkeep | dbt-osmosis | warehouse-target label | kills the docs drudgery |
| Baseline transport | gh CLI artifact fetch | defensible-egress | same profile as the forge |
| AI | Claude Code agent pane | per base posture | replaces dbt Copilot / Power User AI |

The warehouse is the one honest egress — connecting to your own Snowflake is the same trust class as
`git push`; `cide doctor` names it. `profiles.yml` is sovereign and read-only; cide stores target
names, never values.

---

## 6. The rust-dev IDE

Full vertical vision: [research/rust-ide-vision.md](research/rust-ide-vision.md).

### Persona

The quality-gate-driven, agent-heavy Rust dev — primary instance: Christopher building cide and
cute-dbt, every day. Terminal-sovereign (helix, yazi, lazygit, just, gh; will not defect to Electron
for a test explorer). Quality enforced mechanically: TDD, cargo-mutants `--in-diff` pre-PR, coverage,
insta snapshots, cargo-deny — red is a routing event, not a vibe. Zero-egress by conviction;
solo-founder economics (one laptop, six spaces, RAM budgets matter).

### The disconnected-organs insight

The 2025–26 Rust ecosystem built every IDE organ and shipped them as disconnected single-purpose
binaries: bacon parses and sorts diagnostics, nextest runs tests with retries and machine-readable
output, insta reviews snapshots interactively, cargo-mutants gates diffs, cargo-llvm-cov measures —
**no shared cockpit, no shared status surface, no agent feed**
([research/rust-landscape.md](research/rust-landscape.md) §1, §5). And helix structurally cannot grow
panels for 1–2 years (§5's forecast; standing instruction — re-verify Steel/plugin status when the
rust-dev vertical is shaped). Every helix limit is a pane cide already owns: the runner pane *is* the missing
test-lens, the test-tree *is* the missing Test Explorer, the quality cockpit *is* the missing
diagnostics panel. cide builds beside the editor in exactly the window where beside is the only
option — and stays the better answer after, because panes compose with agents and helix plugins won't.

### Surfaces

- **bacon fast-path pane** (settled): bacon as a managed adapter — analysis not display (errors
  first, earliest first), the `.bacon-locations` export as the integration spine (cide-jump,
  fix-on-red attachments, optional bacon-ls), remote control via its Unix socket (never keystroke
  injection), repo-local config fitting the no-`~/.config` constraint natively.
- **nextest catalog + test-tree lane:** retries with first-class flakiness data (a persistent
  per-space flaky list nothing else ships); libtest-json feeds the test-tree explorer — the loudest
  VS-Code gap and an empty lane in the terminal ecosystem. Build archives make worktree-per-agent
  fleets compile-cheap.
- **Quality gates as runner jobs + Dock controls:** `gate: mutants` (--in-diff) with **survivor
  triage** — the insta a/r/s interaction model applied to `mutants.out`, a review TUI cargo-mutants
  lacks entirely; `gate: coverage` (HTML to a browser surface, lcov triage via cide-jump);
  `gate: snapshots` (`cargo insta review` in the review slot); `gate: supply-chain` (cargo-deny,
  offline after explicit labeled advisory sync); `gate: release` (semver-checks + machete + typos as
  one verb). The unified pill row (`cov 91% · mut 3⚠ · snap 0 · deny ✓`) is the v1 of the quality
  cockpit nothing in the ecosystem ships.
- **just modules** (`just rust::gate`) with `--dump` JSON feeding the palette; `cargo doc`/cargo-docs
  serve in a pinned offline browser surface; cargo-expand with a difftastic lens. Phased out of v1:
  the debug cockpit, bench history, gutter coverage.

### The Rule-of-Two validator role — with exit criteria

rust-dev exists to prove the type seams (settled trigger). Proposed acceptance test, written down
before building: **bacon, nextest, and cargo-mutants run through the same `WatchRunner`/status/review
ports as dbt's dbt-build / sqlfluff / cute-dbt jobs, with recipe-only (data-only) differences and zero
rust-specific branches in cide-core.** If that holds, the type registry crystallizes; if it doesn't,
the seams were wrong and we learn it on vertical #2, not #5.

### The compounding dogfood loop

cide is a Rust program developed in a rust-dev cide space: its builder agent consumes bacon/nextest
feeds *through cide* to fix cide, and the vertical's TUI panes are insta-snapshot-tested and reviewed
in its own snapshot surface. Every rough edge in the diagnostics→agent triangle is felt by the founder
within hours, on his highest-frequency workload. The dbt vertical proves the recipe mechanism; the
rust vertical proves it *while compounding* — improvements to the loop accelerate building the loop.

### Defensible defaults (rust recipe)

| Concern | Default | Runner-up | Egress |
|---|---|---|---|
| Watch/check loop | bacon (fast-path adapter) | watchexec binary via `cide run wrap` | zero |
| Test runner | cargo-nextest | cargo test | zero |
| Editor intelligence | rust-analyzer in helix | + bacon-ls offload (opt-in) | zero |
| Snapshot review | cargo-insta | expect-test | zero |
| Coverage | cargo-llvm-cov (nextest mode) | tarpaulin, grcov | zero |
| Mutation | cargo-mutants --in-diff | — (no rival) | zero |
| Supply chain | cargo-deny | cargo-audit bin, cargo-vet | defensible (DB sync only) |
| Bench | divan (loop) + criterion (rigor) | hyperfine | zero — CodSpeed rejected (SaaS) |
| Profiling | cargo-flamegraph (SVG) | samply (flagged: UI loads profiler.firefox.com) | zero / caveat |
| Release hygiene | semver-checks + machete + typos | — | zero |
| Debugger | *(deferred)* lldb-dap experimental | rust-lldb pane | zero — honest gap, not a v1 promise |

---

## 7. The power-user setup

Strong defaults across base + both verticals; every row a documented swap point. Evidence standard
**for the composition-layer tools**: actively maintained, the consensus pick in at least two
independent curated setups, and wrappable behind a trait without forking
([research/terminal-ide-landscape.md](research/terminal-ide-landscape.md) §7). Substrate and own-tool
rows (cmux, cute-dbt, Claude Code, watchexec, csvlens) don't fit that yardstick and are defended
individually in their "Why defensible" cells and the §5/§6 tables.

| Tool | Role | Why defensible | Swap alternatives |
|---|---|---|---|
| **cmux** (on Ghostty) | `Multiplexer` substrate (the umbrella port — [design-plan.md](design-plan.md) §3) | the only multiplexer with native agent primitives; socket v2 direct | not swappable in v1 (port keeps the door open) |
| **helix** | Editor (sovereign) | zero-config LSP; its gaps are precisely what cide fills — symbiosis, not overlap | neovim = one line of `cide.toml`; kakoune |
| **yazi** | Explorer | category winner: async previews, DDS control channel, DuckDB.yazi for dbt | broot, lf |
| **lazygit** | VCS porcelain | the default of every curated setup (Omarchy, gh-dash integrations) | gitu, tig |
| **tig** | History/blame spine | owns the parent-blame loop gitui lacks | — |
| **hunk · delta · difftastic · cmux diff** | Diff (multi-bind) | one port, sub-use bindings: review / pager / structural / browser+turns | — |
| **television** | Picker | telescope-outside-neovim; channels extend to models/spaces | fzf + scripts |
| **serpl** | Replace engine | the named VS-Code-S&R-in-terminal tool; only ever inside atomic `cide replace` | scooter |
| **harlequin** | Warehouse TUI | the terminal SQL IDE, multi-adapter, already dogfooded | usql, pgcli family |
| **watchexec** (external binary) | Runner engine | maintained generic watcher, wrapped by `cide run wrap` — never embedded as a library (no-tokio budget, [research/arch-decision.md](research/arch-decision.md) §2.4) | sync `notify` watcher in-process; bacon fast-path for cargo |
| **just** | Task catalog | ubiquity; modules + JSON dump = enumerable palette actions | make, npm, cargo detection |
| **Claude Code** | Agent | first-class, instance-scoped; 15 agents reachable via cmux hooks | codex variant slot reserved |
| **gh** CLI | Forge | the only defensible egress, labeled | — |
| **bacon / nextest / insta / mutants / llvm-cov / deny** | Rust quality stack | see §6 table | per-row |
| **Fusion→Core v2 / cute-dbt / DuckDB / sqlfmt / sqruff** | dbt stack | see §5 table | per-row |
| **csvlens** | Data viewer (dbt recipe) | settled recipe member | jless (json), lnav (logs) |
| **btop** + `cide top` | Monitor / fleet governor | uncontested default; per-space visibility (budgets gated — P3) | bottom |
| **atuin · eza · bat · fd · rg** | Ambient shell | best-in-class, local-only modes, themed with everything else | shell defaults |
| **starship** | Prompt (default engine) | structurally zero-egress; dual-engine settled | oh-my-posh (locked-down config) |
| `cide theme` | Theming | tinted-theming proves the demand; cide owns the hook layer | tinty as engine |

---

## 8. Non-goals

Explicit NOs, from the synthesis's rejected alternatives (read §7/§9 there before re-litigating):

- **Not an editor, not an agent, not a model broker.** No buffers, no LSP host, no LLM proxying, ever.
- **Never rebuild what cmux ships** (settled): no approval UI, notification plumbing, session
  capture, diff rendering, custom picker, event transport, or teams shim. cmux owns rendering and
  transport; cide owns meaning.
- **No SaaS, telemetry, cloud sync, or external-LLM features.** `cmux vm`/cloud are out of scope.
  The fleet record is a local file, forever.
- **No autonomy maximalism.** Every loop terminates at a human Feed decision. Autopilot-style layers
  may consume cide; they are not cide.
- **No plugin runtime, marketplace, or drop-a-file shell-adapter framework** (settled — reintroduces
  the stringly-typed G1 boundary). Extensibility = Rust adapters behind ports + shareable data
  artifacts.
- **No silent or uninvited `~/.config` writes, ever.** Global-state changes happen only inside the
  one explicit, diff-shown, consented, reversible `cide setup` — or the feature doesn't ship.
- **No second multiplexer adapter and no Linux port in v1.** The port discipline keeps the
  tmux/zellij/Linux door open; promising more now dilutes the wedge.
- **Teams are not the default launch** (settled): bare agent + hooks is; `cide-team` is opt-in.
- **The dbt/rust intelligence ladders are not the v1 spine** — vertical moats riding the base rails.
  (The cute-dbt review loop *is* in scope: it is the recipe proof.)
- **No fork-per-vertical repos; no type DSL before rust-dev demands one.**
- **No committee features.** If it doesn't serve the pair-work loop, shorten time-to-flow, or remove
  an interruption, it waits.

---

## 9. Open questions

Consolidated from the base synthesis, dbt vision §9, and rust vision §8. Each is phrased so
Christopher can answer it directly; answers revise this document. Architecture-residency questions
live in [design-plan.md](design-plan.md), not here.

### Base product & UX

1. **Runner default home:** canonical in [design-plan.md](design-plan.md) §12 (Q3). The product
   nuance feeding that ruling: may the answer differ per vertical (bacon is a rich TUI worth real
   estate; dbt's runner is mostly a status producer)?
2. **`.cmux/` smoke-test composition:** canonical in [design-plan.md](design-plan.md) §12 (Q2 —
   committed vs gitignored decides the smoke test's fate too); cross-referenced here, not duplicated.
3. **Quality-pill budget:** how many status pills before P3 says stop — unified cockpit pane in v1.5
   or wait for BURP-style ingestion?
4. **Agent attachment size:** on fix-on-red, truncate, summarize, or hand file paths for the agent to
   pull itself? Interacts with the `--json` contract design.
5. **Sessionizer scope:** repos + worktrees + spaces in one television channel, or spaces-first?

### dbt vertical

6. **v2-crate intelligence:** how much of the dbt LSP landed in Apache 2.0 dbt-core v2? Determines
   "embed" vs "rebuild on the crates" — verify before shaping backlog #12.
7. **Official-LSP spike:** do L1 features work unauthenticated under helix; is the binary license
   comfortable? (Time-boxed; j-clemons is the default regardless.)
8. **Fusion telemetry:** does the Rust binary honor `DBT_SEND_ANONYMOUS_USAGE_STATS=false` /
   `DO_NOT_TRACK`? Gates the engine's `zero` label.
9. **Engine detection:** how does the dbt catalog pick Fusion/Core-v2 vs Python v1 per project, and
   which entries degrade?
10. **Baseline lifecycle:** snapshot-on-checkout vs CI artifact fetch as primary; staleness
    threshold; one store for both dbt `--state` and cute-dbt `--baseline-manifest`?
11. **harlequin bridge shape:** cide-side wrapper vs upstream dbt adapter vs waiting for v2-crate
    embedding? Sets the effort class for three gap rows.
12. **cute-dbt F2/F4 acceptance:** do the CTE-slice JSON and run_results proposals clear cute-dbt's
    ADR bar? (File as issues there.)
13. **Plan/impact preview v1 scope:** is modified-set + downstream closure + estimated rebuild scope
    an honest first rung (no breaking/non-breaking call until column lineage lands)?
14. **sqlfluff-on-Fusion drift:** is sqruff-only acceptable for deep lint, or does Fusion's
    proprietary `dbt lint` earn an opt-in slot?

### rust vertical

15. **Bacon attach-vs-own:** when a repo already runs bacon, attach to its socket or always manage a
    cide instance? Needs a socket-discovery spike.
16. **bacon-ls posture:** opt-in toggle (proposed) or auto-recommended above a workspace-size
    threshold? Requires the checkOnSave-interplay spike.
17. **libtest-json instability:** parse the experimental nextest run-event format behind a version
    pin + golden fixtures, or ship failing-first-list-only until stabilization?
18. **Baseline keying:** `.cide/rust/` baselines per-space or per-branch; merge-base from the
    worktree's branch point or a configured trunk?
19. **Survivor-accept semantics:** accepted mutants must get a tracking issue (the exclusions rule) —
    `gh issue create` (defensible egress, opt-in) or a local TODO ledger, so air-gapped still works?
20. **Bacon config ownership:** cide-managed `bacon.toml` overlay via `BACON_CONFIG`, or respect
    repo-local files and only add missing jobs? (The theme system's seed→state question, again.)
21. **Rule-of-Two exit criteria:** ratify the acceptance test in §6 as written, or amend before the
    vertical starts?

### Distribution, trust & setup

22. **`cide setup` scope:** which global-state needs (keymap chords, sidebar install, telemetry flip)
    ship in the one consented step at v1, and which wait?
23. **Doctor's warehouse-egress UX:** how to present the profiles.yml-derived network surface
    (accounts, hosts) without ever echoing secrets?
24. **v1 PR/GitHub scope cut:** true-air-gap vs no-third-party-SaaS for the PR review area (the
    egress ladder is settled; this is the scope line)?
25. **License confirmation:** canonical in [design-plan.md](design-plan.md) §12 (Q8) — one-line
    GPL-v3-vs-MIT ruling before the brew tap goes public; cross-referenced here, not duplicated.
26. **User #2 and the distribution trigger:** who is the second user, and what observed evidence
    (a colleague adopting the binary? inbound from the cmux community?) triggers investing in
    distribution — conformance-kit publication, a Linux/tmux adapter? Until then, org-distribution
    and pack-ecosystem claims stay optionality (§2).

---

*This document is the product half of the task #33 approval gate. The architecture half — daemonless
library-first single binary, crate layout, ports, the seven grafts, migration order — is
[design-plan.md](design-plan.md). Approval of both starts the Rust build.*
