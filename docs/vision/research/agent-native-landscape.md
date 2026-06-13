# Agent-Native IDE Landscape — 2025–2026

Research brief for the cide product vision (task #33). Question: what does an
**agent-native IDE** mean in 2025–2026, what agent primitives does cmux already ship
natively, and where can cide — a terminal IDE composed on top of cmux — be the first
terminal IDE designed around human+agent pair work?

Constraints that frame every opportunity below: zero-egress / local-first (no SaaS, no
telemetry; `gh` CLI is fine), never writes to `~/.config` (repo-local `.cmux/` + cide's
own files), macOS-first without precluding Linux, hexagonal Rust destination.

---

## A. cmux's agent-primitive inventory (local findings)

cmux (v0.64.14 at time of research) is not "a terminal with an AI button" — it ships a
full agent control plane. Everything below is **native cmux**; cide composes over it.

### A.1 Agent hooks — the capture layer

`cmux hooks setup [agent]` installs lifecycle hooks for **15 agents**: Claude Code,
Codex, Grok, OpenCode, Pi, OMP, Amp, Cursor CLI, Gemini, Kiro, Rovo Dev, Copilot,
CodeBuddy, Factory, Qoder. Claude Code hooks are injected automatically by cmux's
claude wrapper.

Hooks record every agent session to `~/.cmuxterm/<agent>-hook-sessions.json`
(claude: `claude-hook-sessions.json`), storing:

- agent **sessionId** (the resume checkpoint) and **transcriptPath**
- cmux **workspace/surface UUIDs** (placement — where the agent lives in the layout)
- cwd, pid, and a **lifecycle state**: `running` / `idle` / `needsInput` / `unknown`
- a **sanitized launch command** (model/config flags kept, prompts/secrets dropped) —
  which is how cide recovers the `--name <label>` it launched with

Per-process opt-out via env (e.g. `CMUX_CODEX_HOOKS_DISABLED=1`). This store is the
single most important primitive for cide: it is the bridge between "a terminal pane"
and "a resumable agent conversation with a known place in the layout."

### A.2 The Feed — inline decision surface (approvals)

`cmux feed tui` / Ctrl-4 sidebar. Three **actionable** card types that block on a human:

1. **PermissionRequest / PreToolUse** — allow/deny tool runs, file edits, shell commands
   (modes: Once / Always / All tools / Bypass / Deny)
2. **ExitPlanMode** — plan finished; choose Ultraplan (reject+refine) / Manual / Auto / Deny
   with feedback
3. **AskUserQuestion** — multiple-choice questions answered from the Feed

Everything else (tool uses, messages, session events) is an informational timeline.
Mechanics worth knowing:

- Agents pipe hook events to `cmux hooks feed --source <agent>` → socket `feed.push`
  frames → `FeedCoordinator`.
- **Audit log**: `~/.cmuxterm/workstream.jsonl` (persistent), plus a 2,000-item ring
  buffer in memory.
- **Soft-wait model**: a Feed card blocks the agent's hook max ~120s, then falls back to
  the agent's native prompt — no frozen workflows.
- **Jump**: double-click a Feed item to navigate to its workspace (`feed.jump` RPC).
- RPC surface: `feed.push`, `feed.list`, `feed.jump`, `feed.permission.reply`,
  `feed.question.reply`, `feed.exit_plan.reply`.

### A.3 Notifications — unread triage built in

- `cmux notify` (agent-invocable), `cmux list-notifications`, dismiss one/all-read.
- **Triage keys**: `Cmd+Shift+U` jumps to latest unread; `Ctrl+Cmd+U` marks current as
  oldest-unread and advances — a real inbox-walk, not just banners.
- **Composable notification hooks** in `~/.config/cmux/cmux.json` AND project-level
  `.cmux/cmux.json` (the repo-local config channel cide already uses). Hooks process the
  notification JSON and can toggle **effects**: record history, mark-unread, workspace
  reordering, desktop alert, sound, run command, pane flash.
- Child processes get `CMUX_SOCKET_PATH`, `CMUX_TAB_ID`, `CMUX_PANEL_ID` — context for
  anything cide spawns.
- RPCs: `notification.create[_for_caller|_for_surface|_for_target]`, `notification.list`,
  `notification.jump_to_unread`, `notification.mark_read`, `notification.dismiss`, etc.

### A.4 Session restore, resume, and hibernation

- **App-relaunch restore**: cmux rebuilds workspaces and re-invokes each agent's native
  resume command with the saved session id (`codex resume <id>`, `grok -r <id>`, claude
  `--resume`). Toggle: Settings → "Resume Agent Sessions on Reopen" /
  `autoResumeAgentSessions`. CLI: `cmux restore-session`, RPC `session.restore_previous`.
- **Custom resume commands per surface**: `cmux surface resume set|show|get|clear`
  (`--shell <command>`) — arbitrary terminal surfaces become resumable. Auto-run is
  approval-gated; approvals are prefix-signed and bind cwd+env (a real security design).
- **Agent hibernation** (`cmux agent-hibernation on|off`): opt-in termination of idle
  *background* agents to free RAM — criteria: restorable session + idle lifecycle +
  background terminal + >12 live terminals (default) + ≥5s quiet. SIGTERM to the process
  group, lightweight placeholder swapped in, native-resume on tab visit, ~60s
  confirmation window that cancels on any output/fingerprint change. Tunables:
  `idleSeconds` (5–604800), `maxLiveTerminals` (1–256).

### A.5 Diff viewer — agent-turn aware

`cmux diff [--source unstaged|staged|branch|last-turn]` opens a native diff surface,
split or unified, with `--base`, `--cwd`, `--title`. **`--source last-turn` renders
exactly what the agent changed in its last turn** — the primitive for "review what the
agent just did" without leaving the terminal.

### A.6 Teams — multi-agent split panes without tmux

`cmux claude-teams [claude-args...]`:

- sets `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, defaults teammate mode to auto
- presents a **tmux-like environment via a private PATH shim** that translates tmux
  window/pane commands into **cmux workspace/split operations**

This matters: Claude Code's split-pane teams officially require tmux or iTerm2 and are
explicitly **unsupported in Ghostty** — cmux (Ghostty-backed) fills that hole natively.
Also: `cmux codex-teams`, `omo`/`omx`/`omc` (opencode/omx/omc wrappers).

### A.7 Observation & control plumbing

- `cmux events` — reconnectable, cursor-tracked event stream (`--after`, `--cursor-file`,
  `--name`, `--category`, `--reconnect`, `--no-ack`) — the bus for any cide daemon.
- `cmux read-screen [--scrollback --lines N]` and `cmux send` — observe and drive any
  surface programmatically (babysitter patterns).
- `cmux trigger-flash` — visual attention cue on a surface; `cmux top` / `cmux memory` —
  per-workspace process/resource views; `cmux rename-tab` — label surfaces.
- `cmux tree --all --id-format both --json` — full topology with workspace descriptions
  (cide stamps `cide:spaces=<id>;role=<role>` tags there).
- Browser surfaces + full `browser.*` RPC suite (snapshot-driven automation) — agents can
  drive a browser pane in-layout.

### A.8 cide's existing agent surface (what we've already built)

- **`bin/cide-agent`** — first-class labeled agent surfaces: `cide-agent [new] [label]`
  launches `claude --name <label>` in the current surface (tab renamed to match,
  hooks ensured via `cide_ensure_claude_hooks`), records
  `instance|label|surfaceId|cwd|started` in an append-only **vault index**
  (`CIDE_AGENTS`) that outlives cmux's lossy store. `cide-agent ls` = the vault: ACTIVE
  (scoped to the current space via live-tree UUID membership) vs DEAD (repo-wide
  history by cwd), with lifecycle + time-since-active read from cmux's store.
  `cide-agent rename` keeps tab + vault label in sync. Cross-monitor focus =
  `cide-jump agent [label]`.
- **`bin/cide-space` agent capture/resume** (Phase 2, task #29) — `close` snapshots every
  restorable claude session inside the space's member workspaces into
  `spaces/<id>/agents` (`role|label|checkpoint|transcriptPath`), resolved **globally by
  the `cide:spaces` tag** so capture survives cmux restarts and cross-window closes;
  `open` rebuilds the layout and relaunches the agent slot as
  `claude --name <label> --resume <checkpoint>` (stale transcript → hint shell).
  v1 = one agent slot per space (first restorable row wins).
- **`cide.toml [agents.claude]`** — `command`/`args`/`name_flag`/`resume_flag` are
  config, not hardcode; a `[agents.codex]` slot is reserved. `[agents].placement =
  "landscape"` anticipates layout-aware agent placement.
- **`lib/cide-editor.sh`** — the agent role is the first *surface-grained,
  multi-instance* role (vs workspace-grained editor/tools), deliberately composed over
  cmux's native machinery rather than a parallel session system.

Key local file paths: `bin/cide-agent`, `bin/cide-space` (lines ~120–300),
`lib/cide-editor.sh` (lines ~154–197), `cide.toml` (lines ~35–56),
`~/.agents/skills/cmux/SKILL.md`.

---

## B. The emerging "agent-native IDE" — interaction patterns (web findings)

The category formed fast. Warp coined "Agentic Development Environment" with Warp 2.0
(June 2025); Google shipped Antigravity, an "agent-first" platform, in Nov 2025 and
expanded it to desktop app + CLI + SDK in May 2026; GitHub launched Agent HQ + the VS
Code "Agent Sessions" view (Oct–Nov 2025); Cursor 2.0 shipped a multi-agent interface;
Zed shipped an Agent Panel, parallel agents with a Threads sidebar, and the open Agent
Client Protocol (ACP). Claude Code grew worktree-native parallel sessions, checkpoints/
rewind, hooks, and experimental Agent Teams. The convergent interaction patterns:

### B.1 Mission control / fleet dashboard

One surface listing **all agent sessions and their states**, with jump-to-session.
GitHub's Agent HQ "mission control" spans GitHub, VS Code, mobile, CLI: active sessions,
which repos agents work in, live logs. VS Code 1.106's Agent Sessions view centralizes
local + background agents with search/filter. Warp 2.0's management UI shows status of
all running agents + completion/help notifications. Zed's Threads sidebar manages
parallel agents in one window. The dashboard is the *defining* surface of the category —
every vendor built one.

### B.2 Worktree-per-agent isolation

The 2025 consensus answer to parallel agents stepping on each other: one git worktree
per agent/task. Claude Code made it native (`claude -w / --worktree`, subagent
`isolation: worktree` frontmatter, `WorktreeCreate`/`WorktreeRemove` hooks,
`.worktreeinclude` for copying gitignored-but-needed files). A whole tool tier exists
just to manage this: Conductor (macOS GUI: parallel Claude Code/Codex/Cursor agents in
isolated workspaces, review-and-merge), Claude Squad (terminal/tmux), Vibe Kanban
(kanban card = agent task), Crystal, dmux, amux. Practical ceiling reported: 2–4
parallel sessions before review overhead and rate limits dominate.

### B.3 Review surfaces — the diff queue is the new inbox

Agents produce changes faster than humans read them, so editors grew dedicated review
UIs: Zed's Review Changes multi-buffer (accept/reject per hunk or wholesale, plus
optional inline single-file review); Cursor's Composer diff review before apply;
Antigravity's **Artifacts** (task lists, implementation plans, screenshots, browser
recordings) as *verifiable deliverables* so you check the agent's logic at a glance,
not just its diff. The pattern: review is **per-agent-turn**, not per-commit, and it is
a first-class IDE surface, not a git command.

### B.4 Checkpoint / resume / fork as first-class session semantics

Claude Code auto-checkpoints **every user prompt**; `/rewind` offers restore code+
conversation / conversation only / code only / summarize-from-here; the Agent SDK
exposes `rewindFiles(checkpointUUID)`. Sessions are named, resumable days later, and
**forkable** into parallel exploration branches. Ecosystem session managers (Nimbalyst
et al.) exist purely to organize Claude/Codex sessions. Notable gap: `/resume` and
`/rewind` do **not** restore in-process teammates (agent teams) — multi-agent resume is
unsolved in the mainstream tools (cmux + cide-space's checkpoint capture is ahead here).

### B.5 Attention management / notification triage

With fleets, **human attention is the bottleneck** ("speed of control"). Patterns:
differentiated waiting states — *blocked on approval* must look different from *idle at
prompt* (a daintree issue documents exactly this failure); orchestrator-level triage so
the human reviews a distilled set of escalations, not ten raw agents; event-driven
notification hooks (Claude Code `idle_prompt` / `permission_prompt` matchers, iTerm2
trigger recipes); unread-walk navigation. cmux's Feed + unread-jump keys are already a
strong native implementation of this pattern.

### B.6 Hooks as quality gates and orchestration glue

Claude Code hooks fire on tool use, idle, teammate lifecycle (`TeammateIdle`,
`TaskCreated`, `TaskCompleted` exit-code-2 gating), worktree create/remove. The hook
layer is where teams enforce "definition of done" mechanically (tests pass before a
task may complete). Agent-native engineering essays frame this as: invest in rulesets
and config that make agents behave like trained ICs.

### B.7 Panes-per-agent vs in-process multiplexing

Claude Agent Teams has two display modes: in-process (Shift+Down cycles teammates) and
**split panes — requires tmux or iTerm2; explicitly unsupported in Ghostty/Windows
Terminal/VS Code terminal**. The shared task list + mailbox + lead/teammate structure
is the coordination model; panes are the visibility model. Multiplexer-level agent
awareness (which pane is which teammate, what state it's in) is exactly the seam cmux
occupies and where everyone else is improvising with raw tmux.

### B.8 What "agent-native" means as architecture

Recurring definition across Warp ("editors built for manual editing struggle as control
planes for autonomous parallel agents"), Every's agent-native architectures guide, and
the agent-native engineering essays: the product's primary loop assumes the agent does
the work and the human directs/verifies; tools must be atomic and composable; context
must be scoped per agent; observation surfaces (artifacts, diffs, logs) matter more
than editing surfaces. An agent-native IDE is a **control plane + verification
environment**, with the editor demoted to one surface among several.

---

## C. Opportunities — where cide can be the first terminal IDE built for human+agent pair work

cide's structural advantage: every GUI player (Antigravity, Cursor, Conductor, Agent
HQ) is rebuilding window management, session capture, approvals, and notifications from
scratch inside an Electron/VS Code shell — and every terminal player (Claude Squad,
dmux) is duct-taping tmux. cide sits on a multiplexer that already ships those
primitives natively, and adds the missing layer: **IDE semantics** (roles, spaces,
vaults, journeys). Concrete opportunities, roughly ordered by leverage:

1. **Agent-aware spaces as the unit of work** (extends #28/#29/#30). A space =
   layout + repo + *agent conversation(s)* + runner state. Close/open already
   round-trips one claude checkpoint; generalize to N agent slots with roles
   (`role=agent:reviewer`), and make "open the space" mean "resume the whole working
   session, conversations included." Nobody else has layout+conversation as one
   resumable object — Claude teams can't even resume teammates.

2. **Checkpoint/resume/fork as a first-class IDE concept.** The vault (`cide-agent ls`)
   becomes a session timeline: `cide-agent fork <label>` (new surface, `--resume` same
   checkpoint — parallel exploration branch), `cide-agent revive <label>` (dead session
   → new surface in the right role slot), and space-level "reopen as of <close>". Pure
   composition: cmux store has sessionId+transcriptPath; claude has `--resume`/`--fork-session`.

3. **Worktree-per-agent spaces.** `cide-space new --worktree <branch>`: space creation
   makes the worktree, stamps it, launches a labeled agent inside; `cide-space close`
   captures the checkpoint; a merge-back journey runs `cmux diff --source branch` then
   `gh pr create`. This out-Conductors Conductor in the terminal, zero-egress, and ties
   into the user's existing worktrees-exclusively git discipline (tasks #26/#27 synergy).

4. **The review surface: agent-turn diff queue.** Wire an agent-stop notification hook
   (project `.cmux/cmux.json`) so when an agent goes idle, cide offers/opens
   `cmux diff --source last-turn` in the diff slot of the layout. Add
   `cide-review` — a queue across all active agents in the space: next unreviewed
   turn → diff surface → accept/comment (comment = `cmux send` back to the agent's
   surface). This is Zed's review pane, terminal-native, multi-agent (task #25 synergy:
   the same surface hosts gh PR review).

5. **Runner ⇄ agent feedback loop** (task #23 synergy). The runner pane is a role cide
   already owns; on red, a cide hook routes the failure tail (`cmux read-screen` on the
   runner surface) to the space's agent via `cmux send`, tagged "runner failed: …".
   Closed-loop fix-on-red with the human watching both panes — agent-driven testing as
   an IDE behavior, not a CI behavior. dbt vertical: failed model/test → agent gets the
   compiled SQL path.

6. **Triage cockpit with differentiated states.** `cide-agent ls` already splits
   active/dead; add the state the GUI tools get wrong: **needs-approval** (Feed has a
   blocking card) vs **needsInput/idle** (waiting at prompt) vs **running**, sourced from
   the cmux store lifecycle + `feed.list`. `cide-jump agent --next-blocked` walks
   attention like `Cmd+Shift+U` walks unreads. The status line (task #24) gets a fleet
   segment: `agents: 2▶ 1✋ 1💤` driven off `cmux events`.

7. **First Ghostty-world home for Claude Agent Teams.** Split-pane teams are unsupported
   in Ghostty — except under cmux's tmux shim. `cide-team <preset>`: launch
   `cmux claude-teams` with teammates landing in role-stamped panes of a team layout
   preset, vault-labeled, space-captured. cide becomes the only terminal IDE where a
   team is a *layout* you can name, place per-monitor (#31/#32), and (with capture)
   partially revive.

8. **Artifact surfaces, terminal-native.** Antigravity's insight: agents should produce
   verifiable artifacts (plans, task lists, recordings), not just diffs. cide analog:
   an `artifacts` role slot — agent writes `PLAN.md`/findings to a known path; a
   notification hook opens it in cmux's markdown viewer panel (cmux-markdown) in the
   artifact slot. The human verifies logic at a glance without leaving the layout.

9. **Local-first fleet observability.** `~/.cmuxterm/workstream.jsonl` (Feed audit) +
   the cide vault + `cmux events` = a complete zero-egress activity record.
   `cide-agent log [--today]`: what every agent did, what was approved/denied, per
   space/repo. Every competitor's "mission control" is a SaaS dashboard; cide's is a
   greppable local file with a TUI — exactly the differentiator the zero-egress NFR buys.

10. **Rust-port ports for all of it.** In the hexagonal design, define ports now:
    `AgentSessionStore` (read cmux's store), `DecisionFeed` (feed.* RPCs),
    `Notifier` (notification.*), `DiffSurface`, `EventBus` (cmux events), `Multiplexer`
    (topology). cmux is the first adapter for each; tmux/Zellij adapters keep the
    Linux door open. The agent layer is where adapter-swappability earns its keep.

---

## D. What NOT to build — cmux already does it natively

Do not re-implement; compose. Anything below built into cide would be wasted motion and
a maintenance liability:

- **Approval/permission UI** — the Feed (cards, reply RPCs, soft-wait, audit log) is
  done. cide may *read* feed state for triage, never replace it.
- **Notification plumbing + unread triage** — `cmux notify`, unread-jump keys, effect
  hooks, project-level `.cmux/cmux.json`. cide ships hook *configs*, not a notifier.
- **Session capture/restore/hibernation** — the hook-sessions store, native-resume
  matrix (15 agents), `surface resume`, hibernation thresholds, signed resume
  approvals. cide's vault stays a thin label/history index over it (as designed).
- **Diff rendering** — `cmux diff` with `--source last-turn` already exists; cide's job
  is routing and queueing, not rendering.
- **tmux shim / teams plumbing** — `cmux claude-teams` handles the Ghostty gap; cide
  adds layout presets and labels only.
- **Event transport** — `cmux events` is a reconnectable cursor-tracked bus; no
  watcher daemons of cide's own invention.
- **Browser automation, screen reading, input injection, flash cues, process/memory
  views, tab renaming** — all native (`browser.*`, `read-screen`, `send`,
  `trigger-flash`, `top`/`memory`, `rename-tab`).
- **Agent hook installation** — `cmux hooks setup --agent <name>` is idempotent; cide's
  marker-guarded `cide_ensure_claude_hooks` is the right amount of wrapping. Don't
  write hook integrations per agent.

The division of labor that falls out: **cmux owns capture, decisions, notifications,
rendering, transport; cide owns meaning** — roles, spaces, vault identity, journeys
(review queue, fix-on-red, merge-back), and vertical defaults (dbt/rust). That meaning
layer is precisely what no one in the 2025–2026 landscape has built for the terminal.

---

## Sources

### Local

- `/Users/cmbays/.agents/skills/cmux/SKILL.md` — cmux core-control skill (topology, handles, settings)
- `cmux --help`, `cmux docs`, `cmux docs agents`, `cmux hooks --help`, `cmux claude-teams --help`, `cmux capabilities`, `cmux version` (cmux 0.64.14, read-only CLI inspection)
- https://raw.githubusercontent.com/manaflow-ai/cmux/main/docs/agent-hooks.md — hooks matrix, session store schema, hibernation, resume mechanics
- https://raw.githubusercontent.com/manaflow-ai/cmux/main/docs/feed.md — Feed cards, FeedCoordinator, workstream.jsonl, soft-wait
- https://raw.githubusercontent.com/manaflow-ai/cmux/main/docs/notifications.md — notify, unread triage keys, effect hooks, project `.cmux/cmux.json`
- `/Users/cmbays/github/cmux-workspace-dbt/bin/cide-agent` — labeled agent surfaces + vault
- `/Users/cmbays/github/cmux-workspace-dbt/bin/cide-space` — `_capture_agents` / `_resume_agent_cmd` (lines ~120–300)
- `/Users/cmbays/github/cmux-workspace-dbt/lib/cide-editor.sh` — agent-surface helpers (lines ~154–197)
- `/Users/cmbays/github/cmux-workspace-dbt/cide.toml` — `[agents]` / `[agents.claude]` config (lines ~35–56)

### Web

- https://www.warp.dev/blog/reimagining-coding-agentic-development-environment — Warp 2.0, the original "ADE" framing (June 2025)
- https://www.warp.dev/ and https://thenewstack.io/warp-goes-agentic-a-developer-walk-through-of-warp-2-0/ — Warp agent management UI, permissions, Warp Drive
- https://developers.googleblog.com/build-with-google-antigravity-our-new-agentic-development-platform/ — Antigravity agent-first IDE, Artifacts (Nov 2025)
- https://blog.google/innovation-and-ai/technology/developers-tools/google-io-2026-developer-highlights/ — Antigravity 2.0: desktop app, CLI, SDK (May 2026)
- https://github.blog/news-insights/company-news/welcome-home-agents/ — GitHub Agent HQ, mission control
- https://visualstudiomagazine.com/articles/2025/11/12/vs-code-1-106-adds-agent-hq-new-security-controls.aspx — VS Code Agent Sessions view
- https://zed.dev/docs/ai/agent-panel — Zed Agent Panel, Review Changes multi-buffer, keep/reject hunks
- https://zed.dev/ai — Zed parallel agents, Threads sidebar, ACP external agents
- https://code.claude.com/docs/en/worktrees — Claude Code worktree-per-session, `-w`, `isolation: worktree`, WorktreeCreate hooks, `.worktreeinclude`
- https://code.claude.com/docs/en/agent-teams — Agent Teams: lead/teammates, shared task list + mailbox, display modes (split panes require tmux/iTerm2; Ghostty unsupported), TeammateIdle/TaskCreated/TaskCompleted hooks, no teammate resume
- https://platform.claude.com/docs/en/agent-sdk/file-checkpointing — checkpoint-per-prompt, rewindFiles
- https://www.mindstudio.ai/blog/claude-code-rewind-command-rollback — /rewind options
- https://conductor.build/ — Conductor: parallel Claude Code/Codex/Cursor agents in isolated workspaces, review-and-merge
- https://amux.io/blog/best-multi-agent-orchestrators-2026/ and https://nimbalyst.com/blog/best-multi-agent-coding-tools-2026/ — orchestrator tier landscape (Claude Squad, Conductor, Vibe Kanban, dmux, Crystal)
- https://addyosmani.com/blog/code-agent-orchestra/ — what makes multi-agent coding work
- https://htdocs.dev/posts/from-conductor-to-orchestrator-a-practical-guide-to-multi-agent-coding-in-2026/ — conductor vs orchestrator mental models
- https://www.mindstudio.ai/blog/speed-of-control-attention-management-ai-agents — attention as the bottleneck, escalation triage
- https://github.com/daintreehq/daintree/issues/3940 — differentiated blocked-on-approval vs idle UI states
- https://librabit.co.uk/articles/iterm2-notifications-for-ai-agents — idle_prompt / permission_prompt notification hooks
- https://www.augmentcode.com/guides/what-is-an-agentic-development-environment — ADE definition, agent-native tool requirements
- https://every.to/guides/agent-native — agent-native architectures framing
- https://www.generalintelligencecompany.com/writing/agent-native-engineering — agents as ICs, rulesets as management
- https://www.codecademy.com/article/agentic-ide-comparison-cursor-vs-windsurf-vs-antigravity — Cursor 2.0 multi-agent interface vs agent-first IDEs
