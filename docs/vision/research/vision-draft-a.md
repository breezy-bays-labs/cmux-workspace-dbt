# cide Vision — Draft A: Flow-State First

> Competing vision draft (A) for task #33. Lens: **the IDE as instant, zero-friction
> flow** — speed-to-flow and daily-driver delight above all. Honors every settled
> decision in `prior-decisions.md`; bets drawn from `opportunity-backlog.md`.

---

## 1. Thesis

cide is the terminal IDE that gets you into flow faster than anything else on the
machine — and never charges re-entry tax. One command rebuilds a perfect
multi-monitor workspace: splits, tools, theme, runner, and your **agent
conversations**, exactly where you left them. Every verb is a keystroke; every
state change finds your attention instead of being polled for; every surface wears
the same theme and speaks the same status language. The parts stay sovereign,
best-in-class TUIs (helix, yazi, lazygit, harlequin), but cide erases the seams by
composing cmux's GUI-grade primitives — palette, Feed, diff viewer, Dock, events
stream — under one keymap and one workspace model, so the composition *feels* like
a single tool with the latency of a local Rust binary and zero egress. Zed sells
you an editor; Warp sells you a SaaS terminal. cide sells the scarcest resource of
the agent era: **uninterrupted developer attention**.

---

## 2. Pillars

**P1 — Instant-on workspaces.** `cide open <space>` (or two keystrokes in the
sessionizer) is the entire morning ritual. A space — layout + repo/worktree +
roles + runner + conversations — materializes across monitors in seconds, on the
right monitors, with nothing to re-arrange. Worktree-per-task spaces make "start a
parallel thing" as cheap as "switch to it." The benchmark is the johal.in number
the DIY world brags about (sub-second context switches) — cide makes it the
*default*, not the reward for a weekend of tmux scripting.

**P2 — Total resume. Nothing is ever set up twice.** Sessions in this field
restore pane geometry at best (tmux-resurrect is flaky; zellij's story is
roadmap-grade). cide restores *meaning*: which file helix had open, which DB
harlequin was attached to, which runner was watching, and — the lead nobody else
holds — which agent conversation each role slot was mid-thought in
(`claude --resume <checkpoint>`, N role-stamped slots). Closing a space is a
checkpoint, not a loss. Reopening is continuation, not reconstruction.

**P3 — Keystroke-complete, attention-engineered.** Hands never leave the keys;
eyes never lose the thread. Every cide verb is a palette action and a chord
(tmux-style leaders on cmux's shortcuts registry, shipped via one consented
`cide setup` step — never a silent `~/.config` write). The reverse direction is
engineered too: state comes *to* you — status pills, progress bars, pane flash on
failure, unread-walk triage, focus-aware silencing — so you never tab around
checking on things. Polling your own workspace is a flow leak; cide plugs it.

**P4 — One-tool feel.** The magic is that it doesn't feel composed. One theme
command restyles helix, yazi, btop, delta, harlequin, cmux/Ghostty — and the
browser surfaces via `addstyle` — in one stroke. Cross-tool journeys
(blame→diff→history, send-selection-to-agent, safe project-wide replace) are
named, wired flows, not README workarounds. Spaces are *visible* first-class
containers (native workspace groups: color, icon, collapse), not hidden metadata.
The shared workspace model — project, space, active file, roles, agent state — is
the IPC layer the DIY world never had.

**P5 — Latency is a budgeted feature.** Flow dies in the 300ms gaps. The Rust cide
speaks cmux's socket protocol directly (no subprocess tax), reacts to the events
stream instead of settle-polling (the death of hq-preview's nested poll loops),
and carries explicit flow SLOs: interactive verbs feel instant, space-switch is
sub-second, space-open is seconds not minutes. `cide top` + agent hibernation keep
a six-space fleet snappy on one laptop. Performance is tested like correctness.

---

## 3. A day in the life

**08:55 — Morning open.** Christopher sits down, hits the sessionizer chord, types
`mart`, Enter. The `dbt-mart` space reopens: portrait monitor gets helix with
yesterday's model still open; landscape monitor gets yazi, the review stack, and
harlequin re-attached read-only to the dev warehouse. The space's group in the
sidebar is orange (dbt), collapsed neighbors stay quiet. The agent slot relaunches
`claude --name mart-pair --resume <checkpoint>` — the conversation continues from
"I'll refactor the staging joins next." Total elapsed: under ten seconds, zero
arrangement, zero "where was I."

**09:00 — Coding.** He edits `stg_orders.sql`. The runner (watchexec engine, dbt
catalog) sees the save; a sidebar progress bar tracks the compile; the status pill
flips green. No terminal tab was visited. A `ctrl+a f` chord fires *focus* on a
model: helix opens it, yazi reveals it, harlequin loads its compiled preview — one
subject, every surface re-centered.

**10:30 — Testing.** A save goes red. The runner pane flashes; a single unread
notification lands; the prompt's fleet segment ticks. `Cmd+Shift+U` jumps straight
to the failing output — no hunting. One key routes the failure tail plus compiled
SQL path to the space's agent ("runner failed: …"). He keeps editing while the
agent works; approvals surface as Feed cards, answered without leaving the editor.

**11:15 — Review.** The agent's turn completes; a notification hook opens
`cmux diff --source last-turn --no-focus` beside the agent pane. `cide review`
walks the queue of unreviewed turns across both agents in the space; a comment is
a keystroke that lands back in the agent's prompt. Before lunch he pipes
`gh pr diff 41` into the same diff surface and finishes a colleague's PR review
without opening a browser.

**17:40 — Close.** `cide space close mart`. Agent checkpoints captured, layout and
surface resume-state stamped, workspaces gone, sidebar clean. Tomorrow's open is
this morning's open. The flow loop has no setup phase and no teardown anxiety.

---

## 4. Capability map

### Table stakes (the LazyVim / VS Code bar — cide must simply have answers)

| Capability | cide answer |
|---|---|
| Fuzzy file/picker + project grep | television channels + palette (no custom picker — settled) |
| File tree with ops | yazi, DDS-controlled, role-placed |
| Git porcelain, signs, hunks | lazygit / tig / hunk / delta, pre-wired |
| Project-wide search & replace | one atomic `cide replace` verb (write-all → serpl → reload-all; no unsaved-buffer hazard) |
| Session restore | spaces (geometry **and** semantics — see differentiators) |
| Project/worktree switching | agent-aware sessionizer |
| Unified theming | `cide theme` across every tool, one command |
| Keybinding discoverability | palette keyword taxonomy + chord keymap = workspace-wide which-key |
| Test/task runner | cide-run engine + catalog (just/make/npm/cargo, bacon fast-path) |
| Trust/diagnostics | `cide doctor` (egress labels surfaced), `cide top` |

### Differentiators (what nobody else has, and the flow lens sharpens)

| Differentiator | Why it wins |
|---|---|
| **Spaces that resume conversations** | Layout + repo + runner + N agent checkpoints reopen as one unit; mainstream tools can't resume teammates at all |
| **Sub-second, keystroke-only context switching** | Addressable topology (UUIDs, not zide-style positional hacks) + chords + sessionizer; the DIY pain list, deleted |
| **Attention engineering as a system** | Status pills/progress/flash/unread-walk + focus-aware notification policy — state finds you |
| **Agent-turn review queue in the layout** | `diff --source last-turn` beside the agent, queue semantics across agents — the "diff inbox," terminal-native |
| **One-tool cohesion** | Single theme incl. themed browser surfaces, named journeys, visible colored space containers |
| **Zero-egress, single binary** | Air-gappable flow; no sign-in between you and your workspace; Warp/Zed structurally can't follow |
| **Vertical flow packs** | dbt and rust spaces ship with catalog, viewers, and journeys pre-tuned (the moat programs ride later) |

---

## 5. Top 10 bets (flow-ranked)

1. **Keymap layer + workspace which-key** (backlog #14, S). Elevated to first by
   the lens: chords on cide palette actions, plus-button = "New cide Space,"
   per-vertical tab-bar buttons, palette keywords — one consented `cide setup`
   step. Cheapest path to "keystroke-complete"; makes every other bet reachable.
2. **Agent-aware sessionizer + worktree-per-task spaces** (backlog #8, M). The
   one-command morning and the two-keystroke context switch; television channel
   over repos/worktrees/spaces, opening spaces with agents resumed; merge-back =
   `diff --source branch` → `gh pr create`.
3. **Total resume: generalized surface resume + cide-capture-layout** (backlog
   #7, M). Stamp harlequin/runners/`just dev` with `surface resume set`; register
   harlequin-class tools as `vault.agents`; capture live layouts to replayable
   JSON. Any hand-tuned workspace becomes a preset.
4. **Multi-agent space resume — N role slots** (backlog #11, M). The defining
   object completed: role-stamped slots, per-slot placement, `fork`/`revive`.
   cide reads checkpoint bindings, never writes them (settled).
5. **Native space containers via `workspace.group.*`** (backlog #6, M). Spaces
   become visible, colored, collapsible sidebar citizens; deterministic ordering
   after relaunch; registry stays the cross-monitor join (settled caveat).
6. **cide-run runner engine** (backlog #1, M). The already-shaped keystone:
   watchexec engine + catalog + bacon fast-path on Dock/Palette/Feed, with
   respawn-pane one-key restart. Flow needs an always-on feedback loop; this is it
   — and it's the first genuine Rust strangler slice.
7. **IDE status bus + attention engineering** (backlog #4, S). set-status pills,
   set-progress bars, structured logs, failure→unread→jump-to-unread→flash. The
   "state finds you" pillar, near-zero UI cost, instant daily payoff.
8. **Event reactor backbone, declarative-first** (backlog #3, M). The notification
   hook policy binary (focus-aware silencing, failure escalation) plus the small
   Rust daemon on `cmux events --cursor-file`. Kills settle-polling; gives every
   reaction sub-second latency. Enabler for bets 7, 9, 10.
9. **Agent-turn review queue — `cide review`** (backlog #2, M). Turn-complete →
   last-turn diff beside the agent; queue across the space's agents; comment =
   send-back. Ships v1 on declarative hooks alone (no daemon dependency). The
   human–agent flow loop closed inside the layout. Hosts #25 PR review too.
10. **Cross-tool journeys + the safe replace verb** (backlog #19, M, per-journey
    S). blame→diff→history on tig, `find-window --content` as content-addressed
    goto, send-selection-to-agent, atomic `cide replace`. The connective tissue
    that makes the composition feel like one product.

**Lens-added bet (the backlog under-priced it): Flow SLOs + the direct socket
adapter.** The Rust `CmuxPort` binds the socket v2 protocol (CLI adapter as
fallback/debug only), and the product carries explicit, CI-tested latency budgets:
interactive verb feel-instant, space-switch sub-second, space-open in seconds.
Pair with `cide top` + per-space hibernation budgets so a six-space fleet never
gets sluggish. Speed regressions are release blockers, same as correctness — this
is the discipline that separates "feels like one tool" from "feels like scripts."

Riding along, not separately ranked: per-space color identity and themed browser
surfaces extend the shipped theme system (cohesion pillar); the runner→agent
fix-on-red loop (backlog #9, S) lands nearly free once bets 6+8 exist and is the
signature demo of the whole flow story.

---

## 6. Non-goals — what this vision says NO to

- **Not an editor.** helix's gaps are cide's symbiosis, not its roadmap. No
  buffers, no LSP host, no editor lock-in — ever.
- **No re-implementing cmux.** No custom picker, notify pane, approval UI, diff
  renderer, session capturer, or event transport (all settled). cide owns meaning
  — roles, spaces, journeys — cmux owns rendering and transport.
- **No SaaS, no telemetry, no cloud mission control.** The fleet log is a local
  greppable file. `cmux vm`/cloud are explicitly out of scope.
- **No silent `~/.config` writes.** Keymap, sidebar, telemetry-off are one
  explicit, consented, reversible `cide setup` — or they don't ship.
- **The L-programs are not v1 spearheads.** The dbt intelligence ladder (#12),
  harlequin bridge (#13), and rust quality cockpit (#15) are vertical moats this
  draft *defers*: flow-first means the base loop earns daily-driver status before
  the moats are dug. They ride the runner/status/browser surfaces this draft builds.
- **No debugger (DAP), no plugin marketplace, no drop-a-file shell-adapter
  framework, no agent teams by default** — all either rejected (settled) or
  premature; teams stay an opt-in variant (`cide-team`).
- **No Linux port in v1** — the `Multiplexer` port keeps the door open; the
  socket adapter is honestly macOS-today.
- **No committee features.** If a capability doesn't shorten time-to-flow or
  remove an interruption, it waits — whatever the backlog rank says.

---

## 7. Why a terminal power user — and especially a cmux user — must have this

The terminal power user already *paid* for their stack: hundreds of hours of
dotfiles, sessionizer scripts, theming hooks, and `$EDITOR`-hijack glue — and they
still live with the five documented pains (fragile IPC, broken session restore,
N×N theming, undiscoverable keys, homework project-switching). The defection
literature is blunt: people go back to VS Code because of configuration fatigue
and bolted-on AI, not because they stopped loving their tools. cide deletes the
fatigue (curated, repo-local, zero `~/.config` pollution) while keeping every
sovereign tool they'd refuse to give up — and it adds the one thing no terminal
composition has: a first-class human+agent flow loop with resume, review, and
attention triage built into the workspace itself.

For the cmux user the argument is sharper: you are sitting on ~200 RPC methods,
an events stream, a diff viewer, status APIs, workspace groups, and surface resume
— and using maybe a tenth of it. cide is the missing product layer over the
substrate you already run: it turns cmux's primitives into spaces that come back,
keys that do everything, and agents that pick up mid-sentence. Day one delivers
what the entire tmux world scripts badly — instant project switching with real
restore — and week one delivers what nobody anywhere has: closing your laptop
mid-conversation with two agents and a red test, and reopening *that exact
moment* tomorrow with one command, fully offline, on your own machine.

That's the must-have: not a feature list, but the elimination of every tax between
sitting down and being in flow. Once you've worked a week without re-entry cost,
going back feels like dial-up.

---

*Draft A competes on: fastest time-to-flow, total resume, keystroke-complete
operation, one-tool cohesion, and budgeted latency. ~2,350 words.*
