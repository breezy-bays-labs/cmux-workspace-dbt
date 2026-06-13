# cide Base-IDE Vision — Final Synthesis

> Synthesis of the judged panel for task #33. **Winner: Draft C ("The Agent-Native
> Terminal IDE"), unanimous 3–0** (product 44, architecture 44, adoption 47 — vs
> A 41/40/40 and B 41/43/37). This document keeps C's spine and integrates every
> graft all three judges flagged: A's flow-SLO discipline, keymap-first
> reachability, one-tool cohesion bundle, and total-resume commitment; B's
> verticals-as-recipes mechanism, port conformance kit, egress contract, shareable
> composition artifacts, and the cute-dbt review loop. It also fixes the
> weaknesses the judges found in C. Honors every settled decision in
> `prior-decisions.md`; bets reference `opportunity-backlog.md`. 2026-06-09.

---

## 1. Thesis

The IDE category quietly forked in 2025: editors became control planes for
agents, and every vendor — Zed, Cursor, Antigravity, Warp, GitHub Agent HQ —
rebuilt the same four primitives (session capture, approvals, per-turn diff
review, notification triage) inside a GUI shell, coupled to SaaS. Meanwhile the
terminal, where agents actually run, got duct-taped tmux. cmux is the only
multiplexer anywhere that ships those primitives natively — agent hooks and
session stores for 15 agents, the Feed, `diff --source last-turn`, a
cursor-resumable event bus, agent teams inside Ghostty — and the dogfood's own
audit shows that surface almost entirely untapped.

**cide is the IDE that exploits that monopoly**: a terminal IDE whose primary
loop is a human directing and verifying resident agents — where a space is a
resumable, conversation-bearing unit of work; every agent turn lands in a review
queue; failures route themselves as structured diagnostics to the agent that
owns them; and the whole control plane is a greppable local file instead of a
SaaS dashboard. The editor is one surface among several. The agent pane is the
other half of the pair.

Two disciplines make that loop a daily driver rather than a demo. First, **the
pair-work loop collapses if the human half waits**, so latency is a budgeted,
CI-tested feature: interactive verbs feel instant, space-switch is sub-second,
space-open is seconds — speed regressions are release blockers. Second, the
loop is **built once on swap-safe seams and inherited everywhere**: a workspace
type is data, dbt and rust-dev are recipes over one hexagonal Rust core, and
every port boundary is insured by conformance suites generated from a real
cmux. Same chords, different recipe; the agent loops come along for free.

---

## 2. Pillars

**P1 — The space is the unit of work; closing it is a checkpoint, not a loss.**
A cide space = layout + repo/worktree + role-stamped agent conversations +
runner state + tool sessions, opened, closed, and resumed as **one object**.
Phase 2 already round-trips a Claude checkpoint through close/open — ahead of
the entire field. The vision generalizes in two directions at once. *Agents*:
N role slots (`agent:builder`, `agent:reviewer`), plus `fork` (same checkpoint,
parallel exploration) and `revive` (dead session into its role slot);
`checkpoint_id` stays the durable key, cide reads the resume binding and never
writes it. *Everything else* — and this is a pillar-level commitment, not a
footnote: every non-agent surface is stamped too. harlequin's DB attachment,
runner watchers, `just dev`, viewer panes — captured via `surface resume set`
and `vault.agents` registration so the resume lead covers the whole workspace.
**Nothing is ever set up twice.** Reopening is continuation, not reconstruction.

**P2 — Review is the primary loop; the diff queue is the new inbox.**
Agents produce changes faster than humans read them — that is the structural
fact of the category. cide makes per-turn review the IDE's central verb, not a
git command you remember to run. Turn completes → diff appears beside the
agent, no focus steal. `cide review` walks unreviewed turns across every agent
in the space; commenting is `cmux send` back into the conversation. Artifacts
(PLAN.md, findings) get the same treatment in the live-reload markdown pane:
verify the logic, not just the diff. The same surface hosts `gh pr diff` and
stacked patches — one review muscle for agent turns and human PRs alike.

**P3 — Attention is the scarce resource; engineer it — and govern the fleet
that consumes it.** With a fleet, the human is the bottleneck ("speed of
control"). cide distinguishes the states GUI tools blur — **needs-approval**
(blocking Feed card) vs **idle at prompt** vs **running** — and walks blocked
agents the way Cmd+Shift+U walks unreads. A declarative notification-policy
binary on cmux's hooks pipeline silences agent chatter while the editor is
focused, escalates runner reds to flash and sound, and bubbles noisy spaces up.
The prompt carries a fleet segment: `agents: 2▶ 1✋ 1💤`. And because a
six-space fleet with resident agents creates exactly the resource pressure that
kills attention, the governor is part of the pillar: `cide top` plus per-space
agent-hibernation budgets (`idleSeconds` / `maxLiveTerminals` tuned per space)
keep the whole fleet snappy on one laptop.

**P4 — Closed loops, human ON the loop.**
Runner fails → the agent gets structured diagnostics (file:line,
`.bacon-locations`, compiled-SQL paths — never pasted ANSI) → the fix lands in
the review queue → approval happens in the Feed. cide wires the loops; cmux's
Feed keeps every loop's escape hatch human-shaped. Autonomy is composed, never
assumed.

**P5 — Agents are users of the IDE too.**
Every cide verb is machine-callable with `--json` output and a stable contract,
shipped with a repo-local agent skill. The resident agent can open a file in
the editor, focus the runner, queue a diff, read space state — the same verbs,
the same registry, as the human. A pair-work IDE gives both halves first-class
hands.

**P6 — One tool, at budgeted latency, reachable from the keys.**
This is the pillar Draft C was missing, and it is load-bearing: the agent spine
cannot ship inside a composition that still feels like separate scripts.
Three commitments. *(a) Flow SLOs as release blockers*: explicit, CI-tested
latency budgets — interactive verbs feel instant, space-switch sub-second,
space-open in seconds — backed by a Rust `CmuxPort` that speaks cmux's socket
v2 protocol directly (the CLI adapter is fallback/debug only) and an event-
driven reactor instead of settle-polling. Performance is tested like
correctness. *(b) Keystroke-complete*: every cide verb is a palette action and
a tmux-style chord; workspace-wide which-key; palette keyword taxonomy;
plus-button = "New cide Space"; per-vertical tab-bar buttons — all delivered
through the single consented `cide setup` step, never a silent `~/.config`
write. `cide review`, `jump --next-blocked`, and fix-on-red are only as good as
their reachability. *(c) One-tool cohesion*: the atomic `cide replace` verb
(write-all → serpl → reload-all, killing the documented unsaved-buffer hazard);
named cross-tool journeys — blame→diff→history on tig, send-selection-to-agent,
`find-window --content` as content-addressed goto, and the subject-centric
`focus` fan-out chord (pick a model → helix opens it, yazi reveals it,
harlequin loads its compiled preview — one subject, every surface re-centered);
one-stroke theming across every tool *including* `addstyle`-themed browser
surfaces; and per-space/per-vertical color identity (dbt = orange, rust = red)
on native workspace groups. This is the difference between "composed" and
"cohesive."

**P7 — Verticals are recipes over swap-safe, trust-labeled seams.**
A workspace type is a *domain concept expressed as data*:
`{ports used, default layout, port→adapter bindings, behaviors}`.
`dbt = base ⊕ {viewer(csvlens), warehouse(harlequin), report(cute-dbt), dbt
routing, dbt layout}` — composition, not inheritance, not forks. The rust-dev
vertical is the Rule-of-Two validator: when bacon, nextest, and cargo-mutants
plug into the *same* runner/status/review machinery dbt uses, the type seams
are proven and the type registry crystallizes (its settled trigger). This is
the leverage engine: C's agent loops — review queue, fix-on-red, status bus —
are built once on shared rails and inherited by every vertical. Three contracts
keep the seams honest. *The fidelity contract*: a typed cmux socket client,
golden fixtures **generated from a real cmux** (never hand-authored — G1's
lesson), per-port conformance suites, and the 113-assertion POSIX golden master
as the strangler-fig behavioral spec — published as a first-class artifact that
doubles as the colleague-extension on-ramp ("write an adapter, pass the
suite"), and the boundary-integrity insurance that makes cide's deep coupling
to cmux's agent-hook surface safe to bet on. *The swap contract*: a neovim
colleague edits one line of `cide.toml`, not one repo — swap without forking,
verified, not vibed. *The egress contract*: every adapter declares an egress
label (`zero` | `defensible-egress` | `telemetry-disabled-verified`);
`cide doctor` prints your exact network surface; the base IDE is air-gappable
by construction. That contract is a product surface and the org-distribution
unlock — the feature no GUI competitor's business model permits. And because
layouts are cmux-native JSON with capability tokens, themes are name-maps, and
catalogs are TOML, **every customization is a committable, diffable, handable
file** — layout packs (via `cide capture-layout`), theme packs, runner
catalogs, vertical recipes. That is the long-game ecosystem story: growth
without a plugin runtime or marketplace.

---

## 3. A day in the life

**08:40 — open.** Christopher hits the sessionizer chord; a television channel
lists repos, worktrees, and spaces. He picks `mart-rework`, a dbt worktree
space closed Friday. Under ten seconds later the layout is rebuilt on the right
monitors: helix portrait with Friday's model still open, yazi + agents
landscape, harlequin re-attached read-only to the dev DuckDB, the runner dock
tile live, the space's sidebar group orange (dbt). Both conversations resume:
`builder` (`claude --resume`, mid-task) and `reviewer` (idle). The prompt reads
`agents: 0▶ 1✋ 1💤` — one turn from Friday is still unreviewed. `cide review`
opens it: `cmux diff --source last-turn` beside builder's pane. The change is
right but a test name is wrong; a one-line comment lands as `cmux send` into
builder's conversation. Zero arrangement, zero "where was I."

**09:15 — coding.** He takes the staging half in helix; builder owns the
downstream mart in the same worktree. A `ctrl+a f` chord fires *focus* on
`stg_claims`: helix opens it, yazi reveals it, harlequin loads its compiled
preview. A rename ripples across twelve models — `cide replace` runs the
atomic write-all → serpl → reload-all, no unsaved-buffer hazard. The runner
(watchexec engine, dbt catalog) re-runs `dbt build --select state:modified+`
on save; the status pill flips green. No terminal tab was visited. Builder
finishes a turn; the policy hook sees the editor is focused — no sound, no
banner, just an unread dot and one more entry in the review queue. He finishes
his thought first.

**11:00 — testing and the dbt identity demo.** A save goes red. The runner
pill flips, the pane flashes, and cide routes the failure to builder
automatically: tail plus the compiled SQL path, structured, as a prompt. A Feed
card asks to edit `stg_claims.sql`; one keystroke approves; two minutes later
the fix is a queued diff he reviews without ever copying an error message.
Then palette: `dbt: review my changes` — compile, cute-dbt against the baseline
manifest cide snapshotted at branch checkout, report opened as a themed
`file://` browser surface beside the lineage DAG. The whole-change review is a
recipe behavior, not a script he maintains.

**13:00 — context switch.** Afternoon is Rust work on cide itself. Same
chords, different recipe: the sessionizer opens the `cmux-ide` space
sub-second, the catalog detects cargo and takes the bacon fast-path, status
pills read `clippy ✓ · nextest 2 failing`, and the same fix-on-red verb
attaches `.bacon-locations` instead of compiled SQL. **Nothing about your
hands changed; only the recipe did.** That symmetry is the product.

**14:00 — a second pair of hands.** The refactor needs a devil's advocate.
`cide-agent fork builder explorer` — same checkpoint, new surface — tries the
trait-based approach in parallel. An hour later the fork's diff loses the
comparison; he closes it. The vault keeps its transcript; nothing lost,
nothing merged. `cide top` shows the fleet's terminals within budget; the
morning's dbt space hibernated its idle agents on schedule.

**16:30 — review and ship.** `cide review` shows zero unreviewed turns. The
merge-back journey runs `cmux diff --source branch` against merge-base for a
final whole-branch read, then `gh pr create`. A colleague's PR comes in;
`gh pr diff 84 | cmux diff` renders it in the same surface — forge-only egress.

**18:00 — close.** `cide space close` snapshots both agents' checkpoints,
stamps surface-resume metadata on the runner and harlequin tabs, and releases
the windows. `cide-agent log --today` prints the day's fleet record from
workstream.jsonl + the vault + events — every turn, approval, and denial, per
space — a local, greppable file. No dashboard. No cloud. Tomorrow, the whole
working session — layout, tools, *and* conversations — is one chord away.

---

## 4. Capability map

### Table stakes — the LazyVim / VS Code / 2026 bar, met by composition

| Capability | cide answer |
|---|---|
| Fuzzy picker / global grep | television channels (files, grep, models, spaces) + palette — no custom picker (settled) |
| File tree wired to editor | yazi, DDS-controlled, identity-addressed (no zide-class positional hacks) |
| Git suite | lazygit + tig spine + delta pager + hunk review + difftastic lens; blame→diff→history journey |
| Project-wide search & replace | one atomic `cide replace` verb (write-all → serpl → reload-all; unsaved-buffer hazard killed) |
| Session restore | spaces — geometry **and** semantics (see differentiators) |
| Project/worktree switching | agent-aware sessionizer; sub-second switch (SLO) |
| Test/task runner | cide-run engine + catalog (just/make/npm/cargo, bacon fast-path) |
| Unified theming | `cide theme` across every tool incl. cmux/Ghostty and `addstyle`-themed browser surfaces, one stroke |
| Keybinding discoverability | chord keymap + palette keyword taxonomy = workspace-wide which-key; consented setup |
| Status & notifications | cmux status API + Feed; pills, progress, flash, jump-to-unread |
| Health/trust check | `cide doctor` (config, hooks, adapters, **printed network surface**), `cide top` |
| Native space containers | `workspace.group.*`: visible, colored, collapsible; per-vertical identity |

### Differentiators — the monopoly exploiters; no terminal tool has any, no GUI tool has them zero-egress

| Capability | Why only cide |
|---|---|
| Agent-turn review queue (`cide review`) | cmux alone snapshots per-surface turns natively; cide adds routing + queue semantics |
| N-slot conversation resume + fork/revive per space | The field cannot resume teammates at all; cide already resumes one |
| Total resume — tools *and* conversations as one object | `surface resume` + `vault.agents` + checkpoints; competitors restore pane geometry at best |
| Worktree-per-agent spaces + agent-aware sessionizer | The 2025–26 isolation consensus, terminal-native, zero-egress, real layouts |
| Fix-on-red structured diagnostics routing | Nobody feeds agents structured failure context (compiled SQL / bacon locations, never pasted ANSI) |
| Triage cockpit + local fleet log | Every competitor's mission control is SaaS; cide's is a greppable file |
| Focus-aware notification policy engine | cmux's hooks pipeline is unique substrate |
| Sub-second, keystroke-only context switching — **as a tested SLO** | Budgeted latency + direct socket adapter; the DIY pain list, deleted, and kept deleted by CI |
| Verticals as recipes + shareable composition artifacts | dbt/rust as data over one core; layout/theme/catalog/recipe packs — ecosystem without a plugin runtime |
| Zero-egress, **provably** | Per-adapter egress labels; doctor prints the network surface; air-gappable by construction |
| `cide-team`: Agent Teams in Ghostty | Explicitly unsupported everywhere except cmux's shim; opt-in |
| Artifact surfaces (live plan pane) | Terminal-native Antigravity Artifacts |
| Machine-first verb surface | Every competitor builds an IDE the agent lives *in*; cide is the first the agent can *drive* |

---

## 5. Ranked bets

**Standing engineering posture (not a bet — a gate on every bet):**
Flow SLOs as release blockers — CI-tested budgets (interactive verbs
feel-instant, space-switch sub-second, space-open in seconds); the Rust
`CmuxPort` speaks socket v2 directly (CLI adapter = fallback/debug only); the
port conformance kit (typed socket client, golden fixtures generated from a
real cmux, per-port suites, the 113-assertion POSIX golden master as the
strangler-fig behavioral spec) ships alongside the first Rust slice and gates
every adapter; every adapter manifest carries an egress label that `cide
doctor` aggregates. Speed and boundary regressions block release, same as
correctness.

1. **Keymap layer + workspace which-key** (backlog #14, S). Elevated to first
   enabler on all three judges' verdicts: chords on cide palette actions,
   palette keyword taxonomy, plus-button = "New cide Space," per-vertical
   tab-bar buttons — one consented `cide setup` step. Keystroke-complete
   discoverability is the cheapest unlock that makes every agent verb
   reachable; `cide review` is only as good as its chord.
2. **Agent-turn review queue — `cide review`** (#2). The flagship. v1 ships on
   declarative notification hooks alone — never blocked on the daemon. Same
   surface hosts `gh pr diff` piping and per-layer stacked patches.
3. **Event reactor backbone, declarative-first** (#3). The hook policy binary
   (focus-aware silencing, failure escalation) plus a small Rust daemon on
   `cmux events --cursor-file` for stateful reactions: review cursors, role
   auto-tagging, space GC. The first Rust strangler slice, built on the typed
   socket client + conformance scaffold; the death of settle-polling and the
   substrate of the SLOs. Enables bets 2, 5, 7, 8, 9.
4. **cute-dbt review loop + cide-owned baseline lifecycle** (#5), behind a
   `DbtReviewPort`. Compile → cute-dbt vs merge-base baseline → themed
   `file://` browser surface; cide owns baseline snapshots and
   PreflightError→Feed remediation. Independent of every other bet, shippable
   **from the POSIX dogfood now**, the dbt vertical's identity demo, and the
   first concrete proof that verticals-as-recipes works. Deliberately ranked
   this high so the base-IDE focus does not orphan it.
5. **Multi-agent space resume — N role slots + fork/revive** (#11).
   Generalizes the proven Phase-2 single slot; makes P1's agent half literal.
   cide reads checkpoint bindings, never writes them (settled).
6. **Worktree-per-agent spaces + agent-aware sessionizer** (#8).
   `cide-space new --worktree` births worktree, space, and labeled agent in
   one verb; merge-back = branch diff → `gh pr create`. Matches the
   worktrees-exclusively discipline already in force.
7. **cide-run runner engine** (#1). The keystone port and watchexec strangler
   slice, agent-aware from day one (pipe-pane parser emits structured
   failures, not screen scrapes); catalog as adapter registry; bacon
   fast-path.
8. **Runner→agent fix-on-red loop** (#9, S). Lands nearly free on bets 3 + 7
   and is the signature demo of the whole story; dbt variant attaches compiled
   SQL, rust variant attaches `.bacon-locations`. Inherited by every vertical
   through the recipe mechanism.
9. **IDE status bus + attention engineering + the fleet governor** (#4 + A's
   graft). set-status pills, set-progress bars, structured logs,
   failure→unread→jump→flash; `cide top` and per-space hibernation budgets
   (idleSeconds / maxLiveTerminals) so a six-space fleet stays snappy. The
   visible nervous system of P3/P4, at near-zero UI cost.
10. **Total resume: generalized surface resume + `cide capture-layout`** (#7).
    Stamp harlequin/runners/`just dev` via `surface resume set`; register
    harlequin-class tools as `vault.agents`; capture any hand-tuned live
    workspace into replayable, capability-token JSON. Completes P1's
    "nothing is ever set up twice" and seeds shareable layout packs.
11. **One-tool cohesion bundle** (#19 et al., per-journey S). Atomic
    `cide replace`; named journeys — blame→diff→history on tig,
    send-selection-to-agent, `find-window --content` goto, the `focus`
    fan-out chord; themed browser surfaces via addstyle; per-space color
    identity on native groups. The connective tissue that makes the agent
    cockpit also feel like an IDE.
12. **Machine-first verb surface** (C's lens-added bet). Every verb gets
    `--json` and a documented contract, shipped with a repo-local agent skill
    so resident agents drive the IDE through the same registry as the human.
    Near-zero cost in the Rust rewrite (serde out the same structs);
    categorical payoff.

**Supporting cast, not vision-rank:** native space containers (#6) ride the
space work; agent triage cockpit + local fleet log (#10) rides bets 3 + 9;
artifact surfaces / live plan pane (#20) is nearly-free composition;
`cide-team` (#18) stays the opt-in variant (settled). The L-rated vertical
moats — dbt intelligence ladder (#12), harlequin bridge (#13), rust quality
cockpit (#15) — are phased ladders the recipes climb, plugging their
diagnostics into bet 8's loop; they are not v1 scope, but bet 4 proves the
rails they will ride.

---

## 6. Power-user default toolset

Curated defaults, every one a documented swap point (2–3 vetted options per
concern; the override exists so the default can be strong):

| Port / concern | Default adapter | Notes |
|---|---|---|
| WorkspaceHost | **cmux** (on Ghostty) | The substrate; socket v2 direct; not swappable in v1 (port keeps the door open) |
| Editor | **helix** | Sovereign; cide never renders a buffer. neovim = one line of `cide.toml` |
| Explorer | **yazi** | DDS-controlled, identity-addressed |
| VCS porcelain | **lazygit** | |
| History/blame spine | **tig** | blame→diff→history journey |
| Diff (multi-bind) | **hunk** (review) · **delta** (pager) · **difftastic** (structural) · **cmux diff** (browser/turns) | One port, sub-use bindings |
| Warehouse | **harlequin** | Resume-stamped via `vault.agents`; read-only dev attach |
| Picker | **television** | Channels: files, grep, models, spaces |
| Runner engine | **watchexec** (crate) | bacon fast-path for Rust |
| Task catalog | **just** (+ make/npm/cargo detection) | |
| Agent | **Claude Code** | First-class, instance-scoped; 15 agents reachable via cmux hooks |
| Forge | **gh** CLI | The only defensible egress, labeled |
| Replace | **serpl** | Only ever inside atomic `cide replace` |
| Data viewer | **csvlens** (dbt recipe) | |
| Monitor | **btop** + `cide top` | Fleet governor |
| Ambient shell | eza · bat · fd · rg · atuin | Themed with everything else |
| Theme | `cide theme` | One stroke: tools + cmux/Ghostty + addstyle browser surfaces |

---

## 7. Non-goals

- **Not an editor, not an agent, not a model broker.** helix stays sovereign;
  Claude/Codex stay the agents; cide never proxies, routes, or meters LLM
  traffic. No buffers, no LSP host, ever.
- **Never rebuild what cmux ships** (settled): no approval UI, no notification
  plumbing, no session capture, no diff rendering, no custom picker or notify
  pane, no event transport, no teams shim. cide owns meaning — roles, spaces,
  journeys, recipes; cmux owns rendering and transport.
- **No SaaS, no telemetry, no cloud sync, no external-LLM features.**
  `cmux vm`/cloud are out of scope. The fleet record is a local file, forever.
- **No autonomy maximalism.** cide is not an auto-merge pipeline or an
  unattended-fleet babysitter; every loop terminates at a human Feed decision.
  Orchestration layers above (autopilot-style flows) may consume cide; they
  are not cide.
- **No plugin runtime, no marketplace, no drop-a-file shell-adapter framework**
  (settled rejection — it reintroduces the stringly-typed G1 boundary).
  Extensibility = Rust adapters behind ports (pass the conformance suite) +
  shareable data artifacts, full stop.
- **No `~/.config` writes, ever; no silent setup.** One explicit, consented,
  reversible `cide setup` gathers every global-state need (keymap, sidebar,
  telemetry flip) — or it doesn't ship.
- **No second multiplexer adapter and no Linux port in v1.** The port
  discipline keeps the tmux/zellij/Linux door open; the socket adapter is
  honestly macOS-today. Promising more now dilutes the wedge.
- **Teams are not the default launch** (settled): bare agent + hooks is;
  `cide-team` is the opt-in variant.
- **The dbt/rust intelligence ladders are not this vision's spine.** They are
  vertical moats that plug into the base loops via recipes. (The cute-dbt
  review loop, bet 4, *is* in scope — it is the recipe proof, not the ladder.)
- **No fork-per-vertical repos; no type DSL before rust-dev demands one**
  (Rule-of-Two trigger, settled).
- **No committee features.** If a capability doesn't serve the pair-work loop,
  shorten time-to-flow, or remove an interruption, it waits — whatever the
  backlog rank says.

---

## 8. Why a terminal power user — a cmux user — must have this

**The monopoly argument.** cmux ships ~200 RPC methods of agent control plane,
and the API audit shows the gold untapped: the events stream unread by
anything, `diff --source last-turn` placeholder'd, feed state unconsumed,
`vault.agents` and `surface resume` idle. If you run cmux and Claude Code
today, you own the only multiplexer with native agent primitives and use
almost none of them. cide is the meaning layer that turns that surface into an
IDE — and because it composes rather than rebuilds, it is the only tool that
*can* exist at this altitude without re-implementing cmux badly.

**The counting argument.** A heavy agent user reviews dozens of turns, answers
dozens of approvals, and triages dozens of notifications daily. Each review
today is a manual `git diff` and a scroll; each red test is a copy-paste into
a chat box; each "is anything blocked?" is a tour of panes. The review queue,
the fix-on-red loop, and the blocked-walk each amortize a many-times-daily
cost. This is a throughput product for the exact workflow its founder runs all
day — the dogfood is the demand proof. And the throughput claim is honest only
because latency is budgeted: a review queue that takes 300ms per hop is a
queue you stop using. The SLOs are what make the counting argument compound.

**The nowhere-else argument.** Zed and Cursor demand editor defection and
phone home. Warp is SaaS-coupled. Conductor is a GUI with no terminal soul.
Claude Squad and the tmux orchestrators have panes but no feed, no per-turn
diffs, no conversation-bearing restore. The terminal-sovereign, zero-egress,
agent-heavy developer — a real and growing profile — currently has no product
at all. cide's differentiators (turn queue, N-slot resume, total resume, fleet
log, Teams-in-Ghostty) are structurally unavailable to anyone not built on
cmux, and its trust posture — per-adapter egress labels, `cide doctor`
printing your exact network surface, air-gappable by construction — is
structurally unavailable to anyone whose business model needs your telemetry.
That trust surface is also the distribution unlock: it is the version of this
product you can hand to a colleague near sensitive data, or an air-gapped org.

**The adoption argument.** Day one costs nothing: your tools (helix, yazi,
lazygit, harlequin) stay; your muscle memory stays; config ships repo-local;
nothing touches `~/.config` without consent. A neovim colleague edits one line
of `cide.toml`, not one repo — and the conformance suite, not a promise, is
what makes that swap safe. You get spaces that resume your conversations, a
review queue for the agent you already run, and a workspace where a dbt
morning and a Rust afternoon use identical chords. Every customization you
make is a file you can commit, diff, and hand to someone. From there, every
additional loop is one consented step deeper into the first IDE that treats
the agent as the other half of the pair — and once you've worked a week
without re-entry cost, going back feels like dial-up.

---

## 9. Rejected alternatives (read before re-litigating)

The losing lenses were not wrong; they were not the center. What each wanted
as the *spine*, and why the synthesis declines:

- **Draft A wanted flow-first sequencing** — defer the agent moats until the
  base loop earns daily-driver status, and lead with "cide sells uninterrupted
  attention." Rejected as ordering: the agent loop *is* the category wedge and
  the identity; deferring it spends cide's monopoly window polishing what
  LazyVim already approximates. A's real contribution survives as discipline,
  not sequence — Flow SLOs gate every release, the keymap ships first, the
  cohesion bundle is a ranked bet, and total resume is a pillar. We keep A's
  engineering posture and decline A's roadmap.
- **Draft B wanted platform-first identity** — "the seams are the moat" as the
  thesis, with the conformance kit and shareable artifacts as the lead story.
  Rejected as center: seams are insurance, leverage, and an on-ramp — not the
  reason a user shows up. Ports exist only where two real adapters exist or a
  vertical demands one, never speculatively; the conformance kit is published
  and real but framed as the trust mechanism and colleague on-ramp, not the
  marketing lead; the shareable-artifact ecosystem is the explicit long game,
  not a v1 spearhead. We keep B's mechanism (recipes, contracts, artifacts)
  and decline B's billing order.
- **Both losing lenses implicitly wanted breadth earlier** — more verticals,
  more swap points, more polish surfaces in v1. Declined: the spine is the
  pair-work loop on one substrate (cmux, macOS), proven by one vertical demo
  (the cute-dbt review loop) and validated by one Rule-of-Two trigger
  (rust-dev). Everything else rides those rails or waits.

These were judged, scored, and grafted deliberately (3–0 for C, with eight
named grafts integrated above). A future "shouldn't we lead with
swappability/flow instead?" conversation should start by re-reading the panel
verdicts, not by reopening the question.

---

*Synthesis complete. Spine: Draft C (unanimous). Grafts integrated: A — flow
SLOs + direct socket adapter, keymap-first, cohesion bundle, total resume,
fleet governor; B — verticals-as-recipes, conformance kit, egress contract,
shareable artifacts, cute-dbt review loop, day-in-life symmetry beat.*
