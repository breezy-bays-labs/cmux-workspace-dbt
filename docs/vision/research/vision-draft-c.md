# cide Product Vision — Draft C: The Agent-Native Terminal IDE

> Competing draft for task #33. Lens: **human+agent pair work as the IDE's primary
> loop.** Honors every settled decision in `prior-decisions.md`; bets drawn from
> `opportunity-backlog.md`. This is an opinionated draft, not a committee document.

---

## 1. Thesis

The IDE category quietly forked in 2025: editors became control planes for agents, and every vendor — Zed, Cursor, Antigravity, Warp, GitHub Agent HQ — rebuilt the same four primitives (session capture, approvals, per-turn diff review, notification triage) inside a GUI shell, coupled to SaaS. Meanwhile the terminal, where agents actually run, got duct-taped tmux. cmux is the only multiplexer anywhere that ships those primitives natively: agent hooks and session stores for 15 agents, the Feed, `diff --source last-turn`, a cursor-resumable event bus, agent teams inside Ghostty. Nobody exploits that monopoly — the dogfood's own audit shows the diff viewer running `--help` as a placeholder and the events stream entirely unread. **cide is the IDE that exploits it**: a terminal IDE whose primary loop is a human directing and verifying resident agents — where a space is a resumable, conversation-bearing unit of work, every agent turn lands in a review queue, failures route themselves as structured diagnostics to the agent that owns them, and the whole control plane is a greppable local file instead of a SaaS dashboard. The editor is one surface among several. The agent pane is the other half of the pair.

## 2. Pillars

**P1 — The space is the unit of work; conversations are part of the workspace.**
A cide space = layout + repo/worktree + role-stamped agent conversations + runner state, opened, closed, and resumed as one object. Phase 2 already round-trips a Claude checkpoint through close/open — ahead of the entire field (mainstream tools cannot resume teammates at all). The vision generalizes the single slot to N role slots (`agent:builder`, `agent:reviewer`), plus `fork` (same checkpoint, parallel exploration) and `revive` (dead session into its role slot). `checkpoint_id` stays the durable key; cide reads the resume binding, never writes it.

**P2 — Review is the primary loop; the diff queue is the new inbox.**
Agents produce changes faster than humans read them — that is the structural fact of the category. cide therefore makes per-turn review the IDE's central verb, not a git command you remember to run. Turn completes → diff appears beside the agent, no focus steal. `cide review` walks unreviewed turns across every agent in the space; commenting is `cmux send` back into the conversation. Artifacts (PLAN.md, findings) get the same treatment in the live-reload markdown pane: verify the logic, not just the diff.

**P3 — Attention is the scarce resource; engineer it.**
With a fleet, the human is the bottleneck ("speed of control"). cide distinguishes the states GUI tools blur — **needs-approval** (blocking Feed card) vs **idle at prompt** vs **running** — and walks blocked agents the way Cmd+Shift+U walks unreads. A declarative notification-policy binary on cmux's hooks pipeline silences agent chatter while the editor is focused, escalates runner reds to flash and sound, and bubbles noisy spaces up. The prompt carries a fleet segment: `agents: 2▶ 1✋ 1💤`.

**P4 — Closed loops, human ON the loop.**
Runner fails → the agent gets structured diagnostics (file:line, `.bacon-locations`, compiled-SQL paths — never pasted ANSI) → the fix lands in the review queue → approval happens in the Feed. cide wires the loops; cmux's Feed keeps every loop's escape hatch human-shaped. Autonomy is composed, never assumed.

**P5 — Agents are users of the IDE too.**
Every cide verb is machine-callable with JSON output and a stable contract. The resident agent can open a file in the editor, focus the runner, queue a diff, read space state — the same verbs, the same registry, as the human. A pair-work IDE gives both halves first-class hands.

## 3. A day in the life

**08:40 — open.** Christopher hits the sessionizer chord. A television channel lists repos, worktrees, and spaces; he picks `pricing-v2`, a worktree space closed Friday. cide rebuilds the layout — helix on the portrait monitor, yazi+agents on the landscape — and resumes both conversations: `builder` (`claude --resume`, mid-task) and `reviewer` (idle). The prompt reads `agents: 0▶ 1✋ 1💤`: one turn from Friday is still unreviewed. `cide review` opens it — `cmux diff --source last-turn` beside builder's pane. The change is right but the test name is wrong; he types a one-line comment, which lands as `cmux send` into builder's conversation. Builder wakes, fixes, and its next turn queues silently.

**09:15 — coding.** He takes the pricing-rule half in helix; builder owns the serializer half of the same worktree. The runner — watchexec over `cargo nextest`, living in the Dock — flips its sidebar pill green on every save. Builder finishes a turn; the policy hook sees the editor is focused, so there's no sound, no banner — just an unread dot on the agent pane and one more entry in the review queue. He finishes his thought first. Attention spent on his terms.

**11:00 — testing.** A save goes red. The runner pill flips, the pane flashes — and cide routes the failure to builder automatically: tail plus `.bacon-locations`, structured, as a prompt. A Feed card appears: builder wants to edit `rules.rs`. One keystroke approves. Two minutes later the fix is a queued diff; he reviews it without ever having copied an error message.

**14:00 — a second pair of hands.** The refactor needs a devil's advocate. `cide-agent fork builder explorer` — same checkpoint, new surface — tries the trait-based approach in parallel while builder continues. An hour later the fork's diff loses the comparison; he closes it. The vault keeps its transcript; nothing is lost, nothing merged.

**16:30 — review and ship.** `cide review` shows zero unreviewed turns. The merge-back journey runs `cmux diff --source branch` against merge-base for a final whole-branch read, then `gh pr create`. A colleague's PR comes in; `gh pr diff 84 | cmux diff` renders it in the same surface — review without leaving the terminal, forge-only egress.

**18:00 — close.** `cide-space close pricing-v2` snapshots both agents' checkpoints, stamps surface-resume metadata on the runner and harlequin tabs, and releases the windows. `cide-agent log --today` prints the day's fleet record from workstream.jsonl + the vault + events: every turn, approval, and denial, per space — a local, greppable file. No dashboard. No cloud. Tomorrow, the whole working session — conversations included — is one chord away.

## 4. Capability map

**Table stakes** — earn the right to be an IDE; mostly built or shaped:

| Capability | Status |
|---|---|
| Spaces lifecycle + layout-as-data, monitor-aware placement | Built (POSIX dogfood) |
| Native space containers (`workspace.group.*`, color/icon) | Backlog #6 |
| Runner engine + catalog (just/make/npm/cargo, bacon fast-path) | Shaped (#23) |
| Status pills / progress bars / structured logs | Backlog #4 |
| Generalized surface resume + layout capture | Backlog #7 |
| Theme system, palette/keymap discoverability, sessionizer | Built / Backlog #14 |
| `cide doctor` trust surface (egress labels, telemetry off) | Backlog #17 |
| Git journeys: blame spine, PR review surface, stacked diffs | Decided (#25–#27) |

**Differentiators** — the monopoly exploiters; no terminal tool has any, no GUI tool has them zero-egress:

| Capability | Why only cide |
|---|---|
| Agent-turn review queue (`cide review`) | cmux alone snapshots per-surface turns natively |
| N-slot conversation resume + fork/revive per space | Field cannot resume teammates; cide already resumes one |
| Worktree-per-agent spaces + agent-aware sessionizer | Terminal Conductor, zero-egress, real layouts |
| Fix-on-red structured diagnostics routing | Nobody feeds agents structured failure context |
| Triage cockpit + local fleet log | Every competitor's mission control is SaaS |
| Focus-aware notification policy engine | cmux's hooks pipeline is unique substrate |
| `cide-team`: Agent Teams in Ghostty | Explicitly unsupported everywhere except cmux's shim |
| Artifact surfaces (live plan pane) | Terminal-native Antigravity Artifacts |
| Machine-first verb surface (agents drive the IDE) | Pair-work demands symmetric hands |

## 5. Top bets

Ordered by the agent-native lens; backlog rank in parentheses.

1. **Agent-turn review queue — `cide review`** (#2). The flagship. v1 ships on declarative notification hooks alone — do not block it on the daemon. Same surface hosts `gh pr diff` piping and per-layer stacked patches.
2. **Event reactor backbone, declarative-first** (#3). The hook policy binary (focus-aware silencing, failure escalation) plus a small Rust daemon on `cmux events --cursor-file` for stateful reactions: review cursors, role auto-tagging, space GC. The enabling substrate for bets 1, 4, 5, 6; the death of read-screen polling; the natural first Rust strangler slice alongside the typed socket client.
3. **Multi-agent space resume — N role slots + fork/revive** (#11). Generalizes the proven Phase-2 single slot; makes P1 literal.
4. **Worktree-per-agent spaces + agent-aware sessionizer** (#8). `cide-space new --worktree` births worktree, space, and labeled agent in one verb; merge-back = branch diff → `gh pr create`. Matches the worktrees-exclusively discipline already in force.
5. **Runner→agent fix-on-red loop** (#9). Small effort, signature demo; dbt variant attaches compiled SQL, rust variant attaches bacon locations.
6. **cide-run runner engine** (#1). Ranked here as bet 5's substrate and the watchexec strangler slice — built agent-aware from day one (pipe-pane parser emits structured failures, not screen scrapes).
7. **Agent triage cockpit + local-first fleet log** (#10). needs-approval vs idle vs running; `cide-jump agent --next-blocked`; `cide-agent log` as the zero-egress mission control.
8. **IDE status bus + attention engineering** (#4). Pills, progress, trigger-flash, jump-to-unread — the visible nervous system of pillars 3 and 4.
9. **Artifact surfaces — the live plan pane** (#20). Review-the-logic is the second half of verification; nearly free composition over the live-reload markdown viewer.
10. **`cide-team` — the Ghostty home for Claude Agent Teams** (#18). Opt-in, never default (settled); the only terminal where a team is a nameable, placeable, partially-revivable layout.

**Plus one bet the backlog missed (the lens demands it): the machine-first verb surface.** Every cide verb gets `--json` output and a documented contract, shipped with a repo-local agent skill so resident agents operate the IDE — open files, focus surfaces, queue reviews, read space state — through the same registry as the human. Cost is near zero in the Rust rewrite (serde out the same structs); the payoff is categorical: every competitor builds an IDE the agent lives *in*; cide is the first the agent can *drive*.

Supporting cast, not vision-rank: generalized resume (#7) and native group containers (#6) ride the space work; the dbt/rust intelligence ladders (#12/#15) are vertical moats that plug their diagnostics into bet 5's loop rather than competing with it.

## 6. Non-goals

- **Not an editor, not an agent, not a model broker.** helix stays sovereign; Claude/Codex stay the agents; cide never proxies, routes, or meters LLM traffic.
- **Never rebuild what cmux ships** (settled): no approval UI, no notification plumbing, no session capture, no diff rendering, no event transport, no teams shim. cide reads feed state; it never replaces the Feed.
- **No SaaS mission control, no telemetry, no cloud sessions.** `cmux vm/auth` are explicitly out of scope. The fleet record is a local file, forever.
- **No autonomy maximalism.** cide is not an auto-merge pipeline or an unattended-fleet babysitter; every loop terminates at a human Feed decision. Orchestration layers above (autopilot-style flows) may consume cide; they are not cide.
- **Teams are not the default launch** (settled): bare agent + hooks is; `cide-team` is the opt-in variant.
- **No second multiplexer adapter in v1.** Hexagonal port discipline keeps the tmux/Zellij door open for Linux; building it now is speculation. macOS-first, design never precludes Linux.
- **No re-litigation of settled ground**: no ~/.config writes (consented `cide setup` only), no custom picker or notify pane, no writing resume bindings, no fork-per-type repos, no hand-authored fixtures.
- **The dbt/rust intelligence ladders are not this draft's spine.** They are vertical moats; this vision is the base-IDE identity they plug into.

## 7. Why a terminal power user — a cmux user — must have it

**The monopoly argument.** cmux ships ~200 RPC methods of agent control plane, and the API audit shows the gold untapped: the events stream unread by anything, `diff --source last-turn` placeholder'd, feed state unconsumed, `vault.agents` and `surface resume` idle. If you run cmux and Claude Code today, you own the only multiplexer with native agent primitives and use almost none of them. cide is the meaning layer that turns that surface into an IDE — and because it composes rather than rebuilds, it is the only tool that *can* exist at this altitude without re-implementing cmux badly.

**The counting argument.** A heavy agent user reviews dozens of turns, answers dozens of approvals, and triages dozens of notifications daily. Each review today is a manual `git diff` and a scroll; each red test is a copy-paste into a chat box; each "is anything blocked?" is a tour of panes. The review queue, the fix-on-red loop, and the blocked-walk each amortize a many-times-daily cost. This is not a convenience product; it is a throughput product for the exact workflow its founder runs all day — the dogfood is the demand proof.

**The nowhere-else argument.** Zed and Cursor demand editor defection and phone home. Warp is SaaS-coupled. Conductor is a GUI with no terminal soul. Claude Squad and the tmux orchestrators have panes but no feed, no per-turn diffs, no conversation-bearing restore. The terminal-sovereign, zero-egress, agent-heavy developer — a real and growing profile — currently has no product at all. cide is that product, and its differentiators (turn queue, N-slot resume, fleet log, Teams-in-Ghostty) are structurally unavailable to anyone not built on cmux.

**The adoption argument.** Day one costs nothing: your tools (helix, yazi, lazygit, harlequin) stay; config ships repo-local; nothing touches ~/.config without consent; `cide doctor` prints your exact network surface. You get spaces that resume your conversations and a review queue for the agent you already run — and from there, every additional loop is one consented step deeper into the first IDE that treats the agent as the other half of the pair.

---

*Draft C complete. Word count ≈ 2,300. Sources: the six research notes in this directory; all settled decisions honored per `prior-decisions.md` §18–19.*
