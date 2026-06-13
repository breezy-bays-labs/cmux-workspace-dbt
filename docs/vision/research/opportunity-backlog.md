# cide Opportunity Backlog — merged, deduped, ranked

> Synthesis artifact for Task #33 (product vision + design plan, Rust cide).
> Date: 2026-06-09. Inputs: all eight research notes in this directory
> (cmux-api-surface, cide-current-state, prior-decisions, cute-dbt-capabilities,
> dbt-landscape, rust-landscape, terminal-ide-landscape, agent-native-landscape).
> Posture: respects every settled decision in `prior-decisions.md` — items build on
> them, never re-litigate. ~90 raw opportunity lines across the notes were merged
> into 20 ranked items + an honorable-mention tier; the dedupe map at the bottom
> shows where everything went.

---

## Ranking criteria

Each item was scored on five axes, in priority order:

1. **Daily felt pain / user pull** — does the solo-founder dogfood hit this every
   session? (Heavy Claude Code user, multi-space, dbt + Rust work.)
2. **Untapped-primitive leverage** — does it exploit cmux surface cide doesn't touch
   yet (events, diff viewer, groups, status API, surface-resume, browser, palette,
   markdown, pipe-pane/wait-for)? Compose-don't-build means these items get
   GUI-grade capability at near-zero marginal UI cost.
3. **Agent-native wedge** — does it advance the one position nobody else holds
   (terminal IDE designed for human+agent pair work, zero-egress)?
4. **Strangler-fig alignment** — does it create or widen the POSIX→Rust migration
   path (watchexec-as-crate, typed event consumption, ports for the hexagonal core)?
5. **Effort honesty** — S = a session or two; M = a multi-slice PR arc (1–3 weeks of
   slices); L = a program (multi-month, possibly multi-release).

Impact: 5 = product-defining or felt many times daily · 4 = major capability ·
3 = strong leverage / strategic positioning.

---

## The ranked top 20

| # | Opportunity | Layer | Effort | Impact | Key cmux primitives |
|---|---|---|---|---|---|
| 1 | cide-run runner engine (#23) | cross | M | 5 | Dock, palette actions, Feed, pipe-pane, respawn-pane, wait-for |
| 2 | Agent-turn review queue (`cide review`) | agent | M | 5 | `diff --source last-turn`, agent.hook.Stop, notifications.hooks, feed |
| 3 | Event reactor backbone (declarative-first) | cross | M | 5 | notifications.hooks, `events --cursor-file --reconnect`, set-hook/wait-for |
| 4 | IDE status bus + attention engineering | base | S | 4 | set-status/set-progress/log, notify, trigger-flash, mark-unread, jump-to-unread |
| 5 | cute-dbt review loop + baseline lifecycle | dbt | M | 5 | browser surfaces, palette actions, Feed, runner catalog |
| 6 | Native IDE-space containers (workspace.group.*) | base | M | 4 | workspace.group.* RPCs, workspaceGroups.byCwd, set-color |
| 7 | Generalized resume + layout capture (#30) | cross | M | 4 | `surface resume set`, vault.agents, list-panes pixel_frame, restore-session |
| 8 | Worktree-per-agent spaces + sessionizer | agent | M | 4 | hooks session store, `diff --source branch`, workspace --cwd, palette |
| 9 | Runner→agent fix-on-red loop | agent | S | 4 | read-screen/pipe-pane, send, workspace.prompt_submit, notifications.hooks |
| 10 | Agent triage cockpit + fleet log | agent | M | 4 | feed.list, session-store lifecycle, events, jump-to-unread, workstream.jsonl |
| 11 | Multi-agent space resume (N role slots) | agent | M | 4 | hook-sessions store, claude --resume/--name, surface resume get |
| 12 | Local-first dbt intelligence ladder | dbt | L | 5 | (engine-side; surfaced via status bus, palette, markdown viewer) |
| 13 | dbt-aware harlequin bridge + one-key defer/slim | dbt | L | 4 | palette, runner catalog, Feed, browser surface |
| 14 | cide keymap layer + workspace which-key | base | S | 3 | shortcuts chords on custom actions, plus-button, tab-bar buttons, palette keywords |
| 15 | Rust quality cockpit (test-tree, mutants, coverage) | rust | L | 4 | runner pane, Feed, set-status, diff viewer, browser surface |
| 16 | Spaces dashboard + consented sidebar | base | M | 3 | extension.sidebar.snapshot, events, custom sidebars (beta) |
| 17 | cide doctor / cide top (trust surface) | cross | S | 3 | config doctor --json, capabilities, top/memory, agent-hibernation |
| 18 | cide-team: Ghostty home for Agent Teams | agent | S | 3 | claude-teams tmux shim, layout JSON, vault labels |
| 19 | Cross-tool journeys (#27) + safe S&R verb | base | M | 3 | find-window --content, send/prompt_submit, set-buffer, markdown viewer |
| 20 | Artifact surfaces (live plan pane) | agent | S | 3 | markdown open (live-reload), notifications.hooks, cmux open |

---

## Item detail + reasoning

### 1. cide-run runner engine (#23) — the shaped slice, ranked where it belongs
**What.** Build the already-shaped runner: watchexec engine + pluggable catalog
(just/make/npm/cargo, `[runner]` override) + bacon fast-path for cargo repos,
composed onto cmux's Dock (default watcher home), Command Palette (verbs), and Feed
(notify-on-finish — replacing the #25 notify stub per the settled decision).
Use `pipe-pane` to stream runner output into a cide parser, `respawn-pane` for
one-key restart, `wait-for` for journey barriers.
**Why #1.** It is the only fully shaped-and-decided item, it is felt every session
(the runner pane is literally a `just --list` stub today), and it is the keystone
dependency: items 4 (status content), 9 (fix-on-red), 13 (dbt catalog), and 15
(rust cockpit) all hang off it. watchexec-as-crate makes it the first genuine
strangler slice — the dogfood engine literally becomes the Rust engine.
**Settled-decision fit.** Engine/catalog/bacon/mprocs-separation/Dock+Palette+Feed
all locked; only the Dock-vs-layout default fork stays open for Christopher's verdict.
**Primitives.** Dock, palette actions, Feed, pipe-pane (untapped gold), respawn-pane,
wait-for. **Layer** cross · **Effort** M · **Impact** 5.

### 2. Agent-turn review queue — `cide review`
**What.** On agent turn-complete (notification hook on agent-idle first; the
`agent.hook.Stop` event when the reactor lands), auto-offer/open
`cmux diff --source last-turn --no-focus` beside the agent pane. `cide review`
walks unreviewed turns across all of the active space's agents; "comment" =
`cmux send` back into the agent surface. The same surface hosts
`gh pr diff | cmux diff` for terminal PR review (#25) and per-layer `--title`
patches for stacked diffs (#26).
**Why #2.** "The diff queue is the new inbox" is the convergent pattern of every
2025–26 agent IDE (Zed review multi-buffer, Cursor Composer, Antigravity), and cmux
already ships the hard part: per-surface agent-turn snapshots rendered natively.
cide adds only routing + queue semantics. Today the diff viewer is so untapped the
git-tools pane runs `cmux diff --help` as a placeholder. Highest
agent-native-wedge-per-effort in the entire backlog for a daily Claude Code user.
**Primitives.** `diff --source last-turn|branch|stdin` (untapped top-gold),
notifications.hooks, agent.hook.* events, feed. **Layer** agent · **Effort** M ·
**Impact** 5.

### 3. Event reactor backbone — declarative-first, daemon-where-stateful
**What.** Two tiers, honoring the settled "declarative-first" posture: (a) ship a
cide notification-hook binary (stdin policy JSON → stdout modified policy) declared
in repo-local `.cmux/cmux.json` — silence agent chatter while the editor is focused,
escalate failures to sound/flash, route runner reds; (b) for reactions that need
state (review-queue cursors, space GC on workspace.closed, role auto-tagging on
surface.created, journey telemetry on workspace.prompt.submitted), a small Rust
daemon subscribing to `cmux events --cursor-file --reconnect`. This is the EventBus
port of the hexagonal design and the death of read-screen polling loops (hq-preview's
three nested polls, settle-timing hacks).
**Why #3.** It converts cide from poll-based shell scripts into a reactive system and
is the enabling substrate for items 2, 4, 9, 10, 16. The events stream is the #1
untapped primitive in the API audit — nothing in bin/ or lib/ reads it today.
**Primitives.** notifications.hooks pipeline, `cmux events` NDJSON + cursor-file
resume, set-hook/wait-for. **Layer** cross · **Effort** M (hook binary is S; daemon
is M) · **Impact** 5.

### 4. IDE status bus + attention engineering
**What.** Adopt the sidebar status API as cide's status system: `set-progress` for
dbt run/cargo build progress bars, `set-status` pills (runner state, agent fleet
counts, branch-vs-prod drift), `log --level` for structured space logs; failures
become unread notifications with `jump-to-unread` triage and `trigger-flash` on the
offending pane; `app.reorderOnNotification` bubbles noisy spaces up.
**Why.** A complete GUI-grade status system with zero UI code — currently 100%
untapped (one error-path `cmux notify` exists). Pairs with the runner for instant
payoff and gives every later vertical (dbt, rust) a place to surface state. Small
effort, daily visibility.
**Primitives.** set-status/set-progress/log, notify + unread machinery,
trigger-flash, mark-unread. **Layer** base · **Effort** S · **Impact** 4.

### 5. cute-dbt review loop + cide-owned baseline lifecycle
**What.** The dbt vertical's flagship journey: palette action "dbt: review my
changes" = `dbt compile` → `cute-dbt --baseline-manifest` → open/refresh a
"Test Review" browser surface at `file://…/report.html`; "dbt: review PR #N" =
`gh pr diff` → `cute-dbt --pr-diff @patch` → same surface. cide owns what cute-dbt
deliberately doesn't: baseline lifecycle (snapshot `target/manifest.json` to
`.cide/dbt/baseline/` on branch checkout, or pull from CI via gh), compile-before-
report sequencing, and PreflightError→Feed remediation messages. Post-#99, adopt
`explore`'s dag.html as the persistent lineage pane and wire the #105 JS contract
(editor→`focusModel()` follow-mode; `data-selected-model`→open in helix / queue
`dbt build --select <model>+`). Wrap behind a `DbtReviewPort` (shell-out adapter
now, crate adapter post-v1.0).
**Why.** This is the dbt IDE's identity move: no competitor assembles local
unit-test comprehension + lineage + review, and the philosophical match (zero-egress,
fail-closed, file:// HTML) is exact. Browser surfaces — fully untapped today — are
the natural home; `addstyle` even themes the report to the cide theme.
**Primitives.** browser surfaces (+addstyle, localhost/file routing), palette,
Feed, runner catalog. **Layer** dbt · **Effort** M · **Impact** 5.

### 6. Native IDE-space containers via workspace.group.*
**What.** Migrate space membership from the hidden description-tag hack to native
sidebar workspace groups: one group per space-per-window, with `set_color`/
`set_icon`/`set_anchor` for per-space (and per-vertical: dbt=orange, rust=red)
visual identity, `workspaceGroups.byCwd` for context menus and new-workspace
placement, `reorder-workspaces` for deterministic post-relaunch ordering.
**Caveat honored:** groups are within-window — the cide registry remains the
cross-monitor join (settled); groups upgrade the within-window 80%.
**Why.** The #2 untapped gold; replaces the most fragile coupling mechanism in the
dogfood with a first-class container users can see, collapse, and color. Spaces
stop being invisible metadata.
**Primitives.** workspace.group.* (17 rpc-only verbs), workspaceGroups.byCwd,
workspace-action set-color. **Layer** base · **Effort** M · **Impact** 4.

### 7. Generalized resume + cide-capture-layout (#30)
**What.** Full-fidelity space relaunch as mostly-a-cmux-feature: stamp every
non-agent surface with `surface resume set --kind <tool> --checkpoint <state>`
(harlequin sessions, `just dev`, runners), register cute-dbt/harlequin-class tools
as `vault.agents` so cmux detects/lists/resumes them natively, and build
`cide-capture-layout` (list-panes `pixel_frame` → ratios → replayable layout JSON,
merged with cide's launcher command map — the one thing cmux can't recover).
Restores exact split ratios via `resize-pane`/`equalize_splits`.
**Why.** Semantic session restore is the field-wide pain (tmux-resurrect flaky,
zellij roadmap-grade); cide already leads on agent-conversation resume — this
extends the lead to every tool surface and turns any hand-tuned live workspace
into a shareable preset (capability-token layout packs later).
**Primitives.** surface resume set/get, vault.agents, restore-session, list-panes
pixel_frames. **Layer** cross · **Effort** M · **Impact** 4.

### 8. Worktree-per-agent spaces + agent-aware sessionizer
**What.** `cide-space new --worktree <branch>`: create the worktree, build the
space, launch a labeled agent inside; close captures checkpoints; a merge-back
journey runs `cmux diff --source branch` → `gh pr create`. Pair with a tms-class
fuzzy sessionizer (television channel: repos/worktrees/spaces) that opens a space
with its agents resumed — worktree-aware like tms, agent-aware like nobody.
**Why.** Worktree-per-agent is the 2025–26 consensus isolation model (Conductor,
Claude Squad, Vibe Kanban) and exactly matches Christopher's worktrees-exclusively
git rule. A terminal, zero-egress Conductor with real layout semantics is unheld
ground. nextest build archives later make worktree fleets cheap on the Rust side.
**Primitives.** hooks session store, diff --source branch, new-workspace --cwd,
palette/television. **Layer** agent · **Effort** M · **Impact** 4.

### 9. Runner→agent fix-on-red loop
**What.** On runner failure (exit-code/pattern from the pipe-pane parser), route the
failure tail to the space's agent: `cmux send`/`workspace.prompt_submit` with
"runner failed: <tail + file:line>"; dbt variant attaches compiled-SQL paths,
rust variant attaches `.bacon-locations`/libtest-json instead of pasted ANSI.
Human watches both panes; approval stays in the Feed.
**Why.** Closed-loop agent-driven testing as an IDE behavior is a category gap
(nothing feeds agents structured diagnostics today — rust-landscape gap #7), and it
is nearly free once items 1+3 exist. Small effort, signature demo moment.
**Primitives.** pipe-pane/read-screen, send, workspace.prompt_submit,
notifications.hooks. **Layer** agent · **Effort** S · **Impact** 4.

### 10. Agent triage cockpit + local-first fleet log
**What.** Extend vault states with the distinction GUI tools get wrong:
**needs-approval** (blocking Feed card via feed.list) vs **needsInput/idle** vs
**running** (session-store lifecycle). `cide-jump agent --next-blocked` walks
attention like Cmd+Shift+U walks unreads; prompt line gets a fleet segment
(`agents: 2▶ 1✋ 1💤`) driven off events. Companion: `cide-agent log [--today]` —
a greppable digest of workstream.jsonl + vault + events: what every agent did,
what was approved/denied, per space/repo.
**Why.** Human attention is the fleet bottleneck ("speed of control"); cmux ships
the raw signals natively and nobody composes them. Every competitor's mission
control is SaaS — cide's is a local file with a TUI, the exact differentiator the
zero-egress NFR buys. Reads feed state only — never replaces the Feed UI (settled).
**Primitives.** feed.list, hook-sessions lifecycle, events, jump-to-unread pattern,
workstream.jsonl. **Layer** agent · **Effort** M · **Impact** 4.

### 11. Multi-agent space resume — N role-stamped slots
**What.** Generalize Phase-2's single-slot resume (first restorable row wins) to N
agent slots per space with roles (`role=agent:reviewer`), per-slot placement from
`[agents].placement`, and `cide-agent fork <label>` (same checkpoint → new surface,
parallel exploration) / `revive <label>` (dead session → correct role slot).
checkpoint_id stays the durable key; cide reads the resume binding, never writes it
(settled).
**Why.** "Space = layout + repo + conversations, reopened as one unit" is cide's
defining object, and mainstream tools can't even resume teammates. v1's one-slot
model is the known limit (pain point #15 in current-state); multi-agent work is
already the daily reality.
**Primitives.** hook-sessions store, claude --resume/--name, surface resume get.
**Layer** agent · **Effort** M · **Impact** 4.

### 12. Local-first dbt intelligence ladder
**What.** The dbt vertical's long game, in rungs: (1) now — helix +
j-clemons dbt-language-server with Fusion static-analysis diagnostics; Fusion-aligned
JSON Schemas in yaml-language-server; sqlfmt-on-save + sqruff hot-loop; (2) next —
watch-mode compile-on-save (sub-second Fusion parse) with an inline error pane and
ambient changed-vs-prod status pills; (3) destination — L2-class intelligence
(schema-aware completion, hover types, column lineage, CTE preview) built on the
Apache 2.0 dbt-core v2 crates, embedded in the Rust cide; apex: SQLMesh-style
plan/impact preview ("what changes, what breaks, what rebuilds") — absent from every
dbt tool on any platform.
**Why.** The official LSP's best tier is registration-gated SaaS and VS Code-only —
incompatible with zero-egress AND unavailable to helix. That turns local-first
intelligence into the product thesis: "all of the intelligence, none of the
sign-in." This is the defensible moat of the dbt IDE; L effort, phased delivery.
**Primitives.** engine-side mostly; surfaced via status bus, palette, markdown/
browser panes. **Layer** dbt · **Effort** L · **Impact** 5.

### 13. dbt-aware harlequin bridge + one-key defer/slim
**What.** Close the two biggest dbt workflow gaps: (a) a compile-via-dbt-then-execute
bridge so harlequin runs model SQL with `ref()`s resolved (no dbt adapter exists
anywhere today) — `cwd focus` already proves the fan-out seam; (b) a single cide
verb for the slim loop: managed prod-manifest fetch (gh artifact download, cached,
staleness-dimmed) + `dbt build --select state:modified+ --defer` — turning DIY
artifact plumbing into one keystroke. Add `dbt show`-grade CTE preview when the
engine path (item 12) matures.
**Why.** These are #1 and #5 of the dbt-landscape's five category-defining build
targets, both pure workflow composition over tools already in the stack.
**Primitives.** palette, runner catalog, Feed, set-status; harlequin via wrapper.
**Layer** dbt · **Effort** L · **Impact** 4.

### 14. cide keymap layer + workspace which-key
**What.** Ship a cide keymap: tmux-style chord shortcuts (`["ctrl+a","d"]` → diff,
`r` → runner, `space` → sessionizer) bound to cide palette actions; plus-button
override = "New cide Space"; per-vertical tab-bar buttons (dbt: open harlequin /
review changes; rust: bacon job switch); palette keyword taxonomy so every cide verb
is discoverable from Cmd+Shift+P — the workspace-wide which-key the DIY world lacks.
Shortcuts/global bits live in ~/.config → delivered as an explicit consented
`cide setup keymap` step, never silent (settled constraint).
**Why.** Keybinding discoverability is pain #4 of every composition; the palette is
already proven by the .cmux smoke test, and custom-action bindings are entirely
untapped. Cheap, daily-felt, makes everything above reachable.
**Primitives.** shortcuts.bindings chords on actions registry, ui.newWorkspace,
surfaceTabBar.buttons, palette keywords. **Layer** base · **Effort** S · **Impact** 3.

### 15. Rust quality cockpit
**What.** The rust-dev vertical's flagship: (a) test-tree explorer pane over
`nextest list --message-format json` + libtest-json run events — live failing-first
triage, rerun-failed, jump-to-test (nothing in the ecosystem renders this);
(b) cide-jump consumption of bacon's `.bacon-locations` (failing diagnostic →
`hx +line`, zero scraping); (c) mutation review TUI (cargo-mutants --in-diff
survivors triaged insta-style) and lcov uncovered-lines triage as follow-on slices;
(d) one runner-pane + Feed surface unifying check/clippy/test/coverage/mutants/deny
status (track bacon's BURP as ingestion format). Flamegraph SVGs and cargo-docs
serve render in browser surfaces.
**Why.** The Rule-of-Two validator vertical gets bacon + cargo catalog nearly free
from item 1; the cockpit pieces are the loudest gaps versus VS Code (test explorer,
diagnostics panel) and double as cide's own dev environment — compounding dogfood.
**Primitives.** runner pane, Feed, set-status, diff viewer, browser surfaces.
**Layer** rust · **Effort** L (sliced) · **Impact** 4.

### 16. Spaces dashboard + consented custom sidebar
**What.** Build the "cide Spaces" dashboard from `extension.sidebar.snapshot`
(branch/dirty/PR URLs/ports/latest prompt per workspace) + events reduce — no tree
scraping. v1 = TUI/Dock control; v2 = an offered, consented `cide sidebar install`
dropping a SwiftUI custom sidebar (spaces as groups, role icons, agent lifecycle
dots, click-to-jump) into ~/.config/cmux/sidebars/ — explicit, documented,
reversible.
**Why.** The mission-control surface every agent IDE built, on cmux's documented
sidebar-consumer bootstrap; complements items 6 and 10.
**Primitives.** extension.sidebar.snapshot, events, custom sidebars (beta).
**Layer** base · **Effort** M · **Impact** 3.

### 17. cide doctor / cide top — the trust surface
**What.** Wrap `cmux config doctor --json` + ping + capabilities + hooks state into
`cide doctor`, surfacing every adapter's declared egress label — "cide doctor prints
your exact network surface." Onboarding flips `app.sendAnonymousTelemetry` off
(consented), defaults feed TUI to `--legacy` offline, documents vm/cloud as
excluded; detects missing/stale cute-dbt and advises install. `cide top` maps
`cmux top --json` to per-space CPU/RAM and tunes agent-hibernation budgets
(idleSeconds/maxLiveTerminals) per space. Adopt `automation.portBase` so every
space gets deterministic `CMUX_PORT` dev-server ports.
**Why.** Turns the egress ladder (settled) into a marketable feature for air-gapped
orgs, closes the zero-egress red flags found in the API audit, and gives the
6-spaces-with-agents workload a RAM governor.
**Primitives.** config doctor --json, capabilities, top/memory, agent-hibernation,
automation.portBase. **Layer** cross · **Effort** S · **Impact** 3.

### 18. cide-team — first Ghostty-world home for Claude Agent Teams
**What.** `cide-team <preset>`: launch `cmux claude-teams` (the tmux shim) so
teammates land in role-stamped, vault-labeled panes of a named team layout preset,
placeable per-monitor, with checkpoints captured at space close (partial revive —
upstream can't resume teammates at all). Opt-in variant, never the default launch
(settled).
**Why.** Split-pane teams are explicitly unsupported in Ghostty except under cmux's
shim — cide becomes the only terminal IDE where an agent team is a nameable,
placeable layout. Small effort, distinctive demo.
**Primitives.** claude-teams shim, layout JSON, vault labels, cide-place.
**Layer** agent · **Effort** S · **Impact** 3.

### 19. Cross-tool journeys (#27) + the safe search/replace verb
**What.** Named, wired flows over the curated stack: blame→diff→history on the tig
spine (`cide-blame` from helix/yazi, settled); `find-window --content` as a
content-addressed goto ("jump to wherever the failing output is");
`workspace.prompt_submit` for "send selection to agent"; set-buffer/paste-buffer for
cross-pane snippet transport; and one atomic `cide replace` verb mediating
write-all → serpl → reload-all, removing the unsaved-buffer hazard every helix
composition documents.
**Why.** Journeys are the connective tissue that makes the parts feel like one
product — the gh-dash custom-command pattern generalized. Each journey is small;
the category is the differentiator.
**Primitives.** find-window --content, send/prompt_submit, set-buffer, markdown
viewer. **Layer** base · **Effort** M (per-journey S) · **Impact** 3.

### 20. Artifact surfaces — the live plan pane
**What.** An `artifacts` role slot: agents write PLAN.md/findings to a known path; a
notification hook opens it in cmux's live-reload markdown viewer in the artifact
region (split with `--window`, per the known cross-window gotcha). The human
verifies the agent's logic at a glance — terminal-native Antigravity Artifacts.
Doubles as the home for rendered dbt model docs and cide.toml docs.
**Why.** Review-the-logic (not just the diff) is the second half of the verification
story; the markdown viewer's live-reload is already proven (cide-md-open) but
agent-driven workflows are unexploited. Very small composition.
**Primitives.** markdown open (kernel-watcher live reload), notifications.hooks,
cmux open. **Layer** agent · **Effort** S · **Impact** 3.

---

## Honorable mentions (below the line, tracked not lost)

- **Terminal debugging cockpit** (lldb-dap layout + tokio-console/probe-rs variants)
  — the ecosystem's biggest hole, but L effort against an experimental helix DAP;
  revisit after the rust vertical's runner/cockpit land.
- **Local bench-history store** with insta-style regression review — uncovered
  ground; pairs with item 15 later.
- **dbt-osmosis YAML automation pane, structured dbt-log viewer, model scaffolding
  verbs, MetricFlow TUI** — solid catalog/palette entries inside the dbt vertical;
  ride items 1+5 rather than rank independently.
- **Theme-system hygiene fix** — cide-theme's ~/.config/ghostty write (live
  constraint violation) and tracked-file churn → seed→state copies in the Rust theme
  compiler. This is a correctness obligation of the rewrite, not a market
  opportunity; it rides the Rust port unconditionally.
- **Typed cmux socket client + generated golden fixtures** — mandated quality gate
  (settled), part of the Rust scaffold itself rather than a rankable opportunity.
- **Unified typed state store / identity type** — same: intrinsic to cide-core.
- **PR-review workspace preset** (gh-pr-review + tuicr + gh-dash, defensible-egress
  class) — decided decomposition (#25); its surface is item 2's diff pane + palette.
- **nextest build archives across worktrees** — fold into item 8 when the rust
  vertical meets worktree fleets.
- **Ghost-window lifecycle manager / close-window investigation** — open substrate
  bug (#31 fold-in), scheduled with placement work, not vision-rank material.
- **`cmux ssh` remote workspaces** — keeps the Linux/"beefy box" door open;
  watch-and-wait.
- **Upstream candidates**: cmux session.list RPC (dead-session index), project-local
  sidebar paths, cute-dbt --out stdout + JSON scope sidecar (#cute-dbt filing).

---

## Dedupe map (where the ~90 research opportunity lines went)

| Research line(s) | Folded into |
|---|---|
| cmux-api: events daemon; current-state: event-driven orchestration; agent-native: EventBus port | #3 |
| cmux-api: groups migration; terminal-ide: layout-as-data upgrade | #6 |
| cmux-api: agent-turn review; agent-native: review queue; prior-decisions: cmux diff as 2nd diff adapter; #25/#26 surfaces | #2 |
| cmux-api: status bus + notification-hook binary + trigger-flash/unread; current-state: native Feed as notification port | #3, #4 |
| cmux-api: surface resume + vault.agents; current-state: cide-capture-layout; prior-decisions: capture tool; agent-native: semantic restore | #7 |
| cmux-api: browser pane for dbt; cute-dbt: all panes/palette/runner/baseline/JS-contract lines; dbt-landscape: docs-in-browser interim | #5 |
| cmux-api: runner via pipe-pane; current-state: cide-run; prior-decisions: watchexec strangler; rust-landscape: WatchRunner port + 3 adapters; terminal-ide: test-runner pane | #1 (port detail), #15 (rust UX) |
| cmux-api: keymap/plus-button/tab-bar; terminal-ide: which-key | #14 |
| cmux-api: sidebar.snapshot dashboard + custom sidebar; agent-native: mission control | #16 |
| cmux-api: doctor/top/hibernation/ports/zero-egress hardening; prior-decisions: egress-label trust feature; rust-landscape: explicit-egress UX | #17 |
| cmux-api/current-state: find-window journeys + blame journey + prompt_submit; terminal-ide: safe S&R + journeys | #19 |
| agent-native: agent-aware spaces N slots; checkpoint/fork verbs; current-state: multi-agent resume | #11 |
| agent-native: worktree spaces; terminal-ide: sessionizer | #8 |
| agent-native: fix-on-red; rust-landscape: diagnostics→agent feed | #9 |
| agent-native: triage cockpit + fleet log; cmux-api: attention routing | #10 |
| agent-native: teams | #18 |
| agent-native: artifact surfaces; cmux-api: markdown live-reload workflows | #20 |
| dbt-landscape: L2 intelligence, LSP, watch-mode, plan/impact, lint/format, YAML | #12 (+ catalog rides #1/#5) |
| dbt-landscape: harlequin bridge, defer/slim, table_diff (later rung), TUI catalog over Parquet | #13 (+ #12 destination) |
| rust-landscape: test-tree, mutation TUI, coverage triage, quality cockpit, bench history, docs surface, macro x-ray | #15 (+ honorable mentions) |
| prior-decisions: options registry, typed client, state store, theme fix | Rust-scaffold intrinsics (honorable mentions) |

---

## Dependency / sequencing notes for the vision doc

- **#1 and #3 are the two load-bearing investments**: #1 feeds #4/#9/#13/#15; #3
  feeds #2/#4/#9/#10/#16. Both are M and strangler-aligned — natural first Rust
  slices alongside the mandated typed-client + golden-fixture scaffold.
- **#2 ships a v1 on declarative hooks alone** (no daemon needed) — don't block the
  review queue on the reactor.
- **#5 is independent of everything above** — pure composition over existing
  binaries; it can ship from the POSIX dogfood tomorrow and is the dbt vertical's
  first demo.
- **#12/#13/#15 are L programs** — the vision should frame them as the vertical
  moats with phased rungs, not v1 scope.
- **The ~/.config-touching items (#14 keymap, #16 sidebar, telemetry flip in #17)**
  must all flow through one consented `cide setup` UX — design it once.
