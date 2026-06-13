# cmux API / Composition Surface — Complete Inventory for cide

> Research artifact for Task #33 (Product vision + design plan — cide Rust tool).
> Probed live against **cmux 0.64.14 (94) [1c8f9e261]** on 2026-06-09 (read-only: `--help`, `cmux docs *`, `cmux capabilities`, `cmux tree`, `cmux identify`, plus upstream raw docs).
> Each primitive is tagged with **dogfood status** against the current cide shell (`bin/cide-*`, `lib/`, `.cmux/`):
> **USED** (cide exploits it today) / **PARTIAL** (touched, not exploited) / **UNTAPPED** (gold — nothing in cide uses it).

---

## 0. The mental model

- **Window** → macOS window. **Workspace** → sidebar tab inside a window. **Pane** → split region. **Surface** → tab inside a pane (terminal | browser | markdown | file-preview | diff). **Panel** = internal content alias.
- Every command accepts UUIDs, short refs (`window:1`, `workspace:2`, `pane:3`, `surface:4`, `tab:5`), or indexes. `--id-format refs|uuids|both`, `--json` everywhere.
- Caller anchoring: `CMUX_WORKSPACE_ID`, `CMUX_SURFACE_ID`, `CMUX_TAB_ID`, `CMUX_SOCKET_PATH` are auto-set in every cmux terminal and default the `--workspace/--surface` flags. `cmux identify --json` returns **both** `caller` and `focused` context — the bedrock of non-disruptive automation (agent works in one workspace while the user looks at another).
- Transport: a Unix socket (`~/.local/state/cmux/cmux.sock`), v2 JSON protocol. `cmux capabilities --json` advertises **~200 RPC methods**. `automation.socketControlMode` gates access (`off | cmuxOnly | automation | password | allowAll`); current machine runs `cmuxOnly`.
- **Rust implication**: cide-rs does not need to shell out to the `cmux` binary at all — it can speak the socket protocol directly (one connection per event-stream, request/response for verbs). The CLI is just a reference client. This is the natural seam for a `CmuxPort` trait in the hexagonal design, with a `SocketAdapter` (direct) and a `CliAdapter` (subprocess fallback / debugging).

---

## 1. Topology & routing (windows / workspaces / panes / surfaces)

| Primitive | What it does | IDE exploitation | Dogfood |
|---|---|---|---|
| `tree [--all] [--json]` | Full window→workspace→pane→surface tree with `[selected]`, `[focused]`, `◀ active`, `◀ here` markers | The single source of truth for live topology; cide-space already resolves space membership from it (UUIDs die across restarts, tree survives) | **USED** (cide-space, cide-jump, cide-agent) |
| `identify --json` | Caller vs focused context + socket path | Anchor for every cide verb; distinguish "where I run" from "where the user looks" | **USED** |
| `list-windows / current-window / new-window / focus-window / close-window` | Window lifecycle | cide-space builds one window per layout orientation; cide-place moves them to monitors | **USED** |
| `new-workspace --name --cwd --command --layout <json>` | Workspace with **declarative layout JSON** (nested direction/split/pane/surfaces, each surface has type/name/command/url) | THE layout-as-data primitive: cide layouts are pure data, replayable, diffable | **USED** (cide-space §198 instantiates layouts) |
| `workspace-action --action <name>` | `pin, unpin, rename, clear-name, set-description, clear-description, move-up/down/top, close-others/above/below, mark-read, mark-unread, set-color, clear-color` | Workspace **color** = per-vertical visual identity (dbt=orange, rust=red); **set-description** carries machine tags; mark-unread = attention engineering | **PARTIAL** — only `set-description` used as the `cide:instance=…;role=…` join key (cide-set-role) |
| `reorder-workspace / reorder-workspaces --order …` | Atomic sidebar reordering (respects pinned groups) | Keep IDE-space members adjacent in sidebar; deterministic ordering after relaunch | UNTAPPED |
| `move-workspace-to-window`, `move-tab-to-new-workspace`, `break-pane`, `join-pane`, `swap-pane` | Surgical re-topology | "promote this tool tab to its own window on monitor 2" journeys (#32 move taxonomy) | **PARTIAL** (move-workspace-to-window in cide-place) |
| `new-pane --type terminal\|browser --direction … --url`, `new-surface`, `new-split`, `split-off`, `move-surface --focus false`, `reorder-surface` | Additive layout, focus-neutral by default | Build/repair layouts without yanking user focus — cide's relaunch/repair verbs | **USED** (new-surface in cide-agent/cide-open) |
| `resize-pane -L/-R/-U/-D --amount`, `workspace.equalize_splits` (rpc) | Programmatic split sizing | "zen mode" / "focus mode" presets; restore exact split ratios in Phase-3 full-fidelity relaunch | UNTAPPED |
| `rename-tab`, `tab-action --action` | `rename, clear-name, close-left/right/others, new-terminal-right, new-browser-right, reload, duplicate, pin, unpin, mark-unread` | Tab pinning for the editor surface; `duplicate` for "fork this shell"; mark-unread for tool-driven attention | **PARTIAL** (rename-tab only, in cide-agent) |
| `find-window [--content] [--select] <query>` | Search workspace titles **and terminal content** | Instant "jump to wherever the failing test output is" — a content-addressed goto | **UNTAPPED — gold** |
| `surface-health`, `refresh-surfaces`, `debug-terminals` | Detect hidden/detached/non-windowed surfaces | Self-healing IDE: detect zombie panes after crash, repair layout | UNTAPPED |
| `trigger-flash --surface/--workspace` | Visual attention cue | Flash the runner pane on test failure; flash editor on agent-edit landing | UNTAPPED |
| **`workspace.group.*` (RPC-only, 17 verbs)** | `create, delete, add, remove, rename, pin/unpin, collapse/expand, focus, move, new_workspace, set_anchor, set_color, set_icon, ungroup, list` — native sidebar **workspace groups** with anchor cwd, color, icon | **This is the native primitive for cide IDE spaces.** cide-space currently fakes coupling with hidden description tags; groups give real first-class containers with per-cwd `workspaceGroups.byCwd` config (color, SF-symbol icon, context menu, new-workspace placement) | **UNTAPPED — top gold** |

Also: `workspace.prompt_submit` (rpc) submits an agent prompt into a workspace programmatically; `app.iMessageMode` surfaces submitted prompts in the sidebar.

---

## 2. Command palette + custom actions (`cmux.json` `actions` / `ui` / `commands`)

- `actions` registry: entries appear in **Cmd+Shift+P** (`palette: true`), surface tab bars (`ui.surfaceTabBar.buttons`), shortcuts, and the plus-button menu (`ui.newWorkspace.action` + `ui.newWorkspace.contextMenu`).
- Action types observed: `"type": "agent"` (launch claude/codex/etc., `target: newTabInCurrentPane`), `"type": "workspaceCommand"` (`commandName` → a `commands[]` entry), built-ins (`cmux.newTerminal`, `cmux.newBrowser`, `cmux.splitRight`, `cmux.splitDown`).
- `commands[]`: named, keyworded workspace definitions with full layout JSON — the team-shareable "open this IDE" verbs. Project-local `.cmux/cmux.json` **overrides global by ID/name** and travels with the repo (trust-gated).
- `workspaceGroups.byCwd`: per-cwd group color/icon/context-menu/placement (fnmatch globs, longest-match).
- `app.commandPaletteSearchesAllSurfaces`: palette as a global surface switcher.

**IDE exploitation**: the palette is cide's free command UI — every cide verb (`cide-space new`, `cide-agent`, `cide diff`, `cide run`) can be a palette action with zero UI code; the plus-button becomes "New cide space"; tab-bar buttons become per-vertical tool launchers (dbt: "open harlequin", rust: "cargo watch").
**Dogfood**: **PARTIAL** — `.cmux/cmux.json` defines exactly 2 actions (`cide-demo-space` workspaceCommand + `cide-claude-tab` agent) and 1 command. No plus-button override, no tab-bar buttons, no workspaceGroups, no keywords-driven palette taxonomy.

---

## 3. Dock (`.cmux/dock.json`)

- Right-sidebar **persistent terminal controls**; each control = `{id, title, command, cwd, height, env}`; runs in its own Ghostty-backed terminal (full TUI keyboard support); command exit drops to an interactive shell; file order = display order.
- Precedence: `.cmux/dock.json` (project, walks parents, trust-gated by content fingerprint) → `~/.config/cmux/dock.json` (global).
- Toggle/focus via `right-sidebar dock`, `shortcuts.bindings.switchRightSidebarToDock`.

**IDE exploitation**: the Dock is cide's "status bar + tool drawer": runner output, lazygit, btop, Feed TUI, dbt artifacts watcher, `cargo watch` — vertical-specific docks shipped per repo.
**Dogfood**: **USED** — 5 controls (Runner watchexec, cide Spaces ls, lazygit, btop, `cmux feed tui --opentui`). Untapped within it: per-control `env`, programmatic dock switching from journeys.

---

## 4. Feed + events stream (the reactive backbone)

### Feed
- Inline approval surface for agent decisions: **Permission requests** (Once/Always/All tools/Bypass/Deny), **ExitPlanMode** (Ultraplan/Manual/Auto), **AskUserQuestion** (multi-choice) — plus an informational latest-first timeline of every tool use/assistant message/TodoWrite.
- Plumbing: agent hooks → `cmux hooks feed --source <agent>` → `feed.push` socket verb → semaphore parks the hook (≤120 s, advisory not blocking) → UI/notification reply via `feed.permission.reply` / `feed.question.reply` / `feed.exit_plan.reply` rpc.
- Audit: `~/.cmuxterm/workstream.jsonl` (append-only, every event); ring buffer 2000 in memory; `feed.list` + `feed.jump` rpc (jump focuses the agent's workspace+surface via session store).
- `cmux feed tui [--opentui|--legacy]` keyboard-first TUI (NOTE: first OpenTUI run **downloads `@opentui/core` via Bun** — an egress event; the legacy Swift TUI is fully local).

### Events
- `cmux events` = reconnectable **NDJSON event stream** over the socket (`events.stream` v2 method): `--after <seq>`, `--cursor-file`, `--name`, `--category`, `--reconnect`, `--limit`, `--no-heartbeat`.
- Durable mirror: `~/.cmuxterm/events.jsonl` (16 MiB, one rotation). Replay buffer 4096 events; 16 KiB/frame cap; slow consumers dropped at 1024 pending; `ack.resume.gap` contract → refresh via snapshot verbs (`tree`, `list-workspaces`, `extension.sidebar.snapshot`).
- **Catalog**: `window.created/focused/keyed/unkeyed/closed`; `workspace.created/selected/closed/renamed/reordered/moved/action/prompt.submitted`; `surface.created/selected/focused/closed/moved/reordered/action/input_sent/key_sent`; `pane.created/closed/focused/resized/swapped/broken/joined`; `sidebar.metadata.*`, `sidebar.progress.*`, `sidebar.log.*`; `notification.*` (10 names); `feed.item.received/completed/resolved`; **`agent.hook.<HookEventName>`** (native Claude/Codex hook names!); `browser.navigation/interaction/input`; `config.reloaded`. Payloads redact text (lengths only) but keep operational IDs.

**IDE exploitation**: this is the **event bus a Rust cide daemon subscribes to**: react to `surface.created` (auto-tag roles), `workspace.closed` (space GC), `agent.hook.Stop` (turn-complete → auto-open `cmux diff --last-turn`), `pane.focused` (context-aware status), `workspace.prompt.submitted` (journey telemetry) — all with cursor-file resume across cide restarts. It converts cide from poll-based shell scripts into a reactive daemon.
**Dogfood**: **UNTAPPED — top gold.** Nothing in `bin/` or `lib/` reads `cmux events` or the JSONL logs. (Feed TUI sits in the Dock but no cide logic consumes feed/agent events.)

---

## 5. Agent integration

| Primitive | What it does | IDE exploitation | Dogfood |
|---|---|---|---|
| `hooks setup/<agent> install` (15 agents: claude wrapper-injected, codex, grok, opencode, pi, omp, amp, cursor, gemini, kiro, rovodev, copilot, codebuddy, factory, qoder) | Installs running-state, Feed, notification + **session-restore** hooks | cide-agent already requires claude hooks; multi-agent verticals (Codex variant, task #22) ride the same rail | **USED** (cide-agent `cide_ensure_claude_hooks`) |
| Session stores `~/.cmuxterm/<agent>-hook-sessions.json` | session-id ↔ workspace/surface/cwd/pid/lifecycle (`running/idle/needsInput`) + sanitized launch command | cide-agent's vault (`cide-agent ls`) reads it; lifecycle field is an **agent-status API** for status pills | **USED** (vault), lifecycle field UNTAPPED |
| Native resume on relaunch (`claude --resume <id>` etc.), `terminal.autoResumeAgentSessions` | App relaunch rebuilds workspaces and resumes agents | Phase-2 IDE-space conversation-resume (#29) gets this for free per-surface | **PARTIAL** (Phase 2 in progress) |
| `surface resume set --kind --checkpoint --name [--shell\|-- argv]` / `show/get/clear` | Attach **arbitrary restart metadata to any surface** (signed, prefix-approved auto-restore) | Generalized resume for non-agent surfaces: harlequin sessions, `just dev`, watchexec runners — full-fidelity relaunch (#30) without cide storing commands itself | **UNTAPPED — gold** |
| `agent-hibernation on/off` + `terminal.agentHibernation {idleSeconds, maxLiveTerminals}` | SIGTERM idle background agents, placeholder + auto-resume on revisit | Solo founder running 6 IDE spaces × agents: RAM governor; cide could enable per-space budgets | UNTAPPED |
| `claude-teams` | Launches Claude with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` + a **tmux shim that maps tmux pane verbs to cmux splits** | Agent teams spawn into real cide panes — multi-agent dbt-doc/test swarms visible as IDE surfaces | UNTAPPED |
| `codex-teams`, `omo`, `omx`, `omc` | Same pattern for Codex/OpenCode/OMX/OMC | Codex-variant agent surface (#22 follow-on) | UNTAPPED |
| `vault.agents` (cmux.json) | **Register custom JSONL-backed agents** (detect by process/argv, sessionIdSource, resumeCommand) without an app update | Register cide's own long-running tools (e.g. a cute-dbt REPL, harlequin) as "agents" so cmux Vault lists/resumes them natively | **UNTAPPED — gold** |
| `workspace.prompt_submit` (rpc) | Programmatically submit a prompt to a workspace's agent | "Send selection to agent", journey glue (blame→explain), scripted standup prompts | UNTAPPED |
| Right-sidebar `sessions` / `vault` modes | Native session browser UI | complements `cide-agent ls` | UNTAPPED |

---

## 6. Notifications & attention engineering

- `notify --title --subtitle --body [--workspace --surface]` routes to macOS banner + sidebar history + unread badges. `list-notifications` (with `created_at`, `tab_title`), `mark-notification-read`, `dismiss-notification --all-read`, `open-notification --id` (focus + mark read), `jump-to-unread`, `clear-notifications`.
- Unread machinery: dock badge, menu-bar extra, **unread pane ring**, pane flash, `app.reorderOnNotification` (bubble noisy workspaces up), shortcuts `jumpToUnread` / `markOldestUnreadAndJumpNext` (inbox-zero triage over agent panes).
- **`notifications.hooks`** (cmux.json, global-then-project, `hooksMode: append|replace`): shell pipelines that receive a **notification policy JSON on stdin and return modified policy on stdout** — per-event control of `record / markUnread / reorderWorkspace / desktop / sound / command / paneFlash`, with `cwd`, `appFocused`, `focusedPanel` context.
- Sidebar metadata API: `set-status <key> <value> [--icon SF-symbol --color #hex --priority n]` (status pills), `set-progress 0..1 --label`, `log --level`, `list-status/list-log`, `sidebar-state --json`, all per-workspace.

**IDE exploitation**: a complete IDE status system with zero UI code — `dbt run` progress as a sidebar progress bar, `cargo build` status pills, runner failures as unread notifications with jump-to-unread triage, **notification hooks as a cide-owned policy engine** (e.g. silence agent chatter while the editor pane is focused, escalate test failures to sound). The hooks pipeline is exactly a port: cide ships one binary that cmux pipes every notification through.
**Dogfood**: **UNTAPPED** (one error-path `cmux notify` in cide-editor.sh; layout has a placeholder "notifications pane — tracked: #25"). No set-status, no set-progress, no log, no notification hooks, no unread workflows.

---

## 7. Diff viewer

- `cmux diff [patch|-] --source unstaged|staged|branch|last-turn --base <ref> --cwd <repo> --layout split|unified --font-size --title --no-focus` → renders in a browser split. Reads stdin (`git diff | cmux diff`).
- **`--source last-turn`** = changes since **this surface's last agent-turn baseline** — cmux tracks per-surface agent-turn snapshots.
- `diffViewer.defaultLayout` setting; toolbar persists last layout choice.

**IDE exploitation**: the review half of the IDE: after every agent turn, auto-open last-turn diff (event-triggered via `agent.hook.Stop`); `cide review` journey = branch diff vs merge-base; pipe `gh pr diff | cmux diff` for PR review (#25); stacked-diff visualization (#26) by piping per-layer patches with `--title`.
**Dogfood**: **UNTAPPED** — the git-tools pane literally runs `cmux diff --help` as a placeholder.

---

## 8. Embedded browser surfaces

- Full automation verb set on WKWebView surfaces: open/open-split/goto/back/forward/reload; `snapshot [--interactive --compact --max-depth --selector]` with stable `eN` refs; click/dblclick/hover/fill/type/press/select/check/scroll; `wait --selector|--text|--url-contains|--load-state|--function`; `get url|title|text|html|value|attr|count|box|styles`; `is visible|enabled|checked`; `find role|text|label|placeholder|testid|…`; `eval`; `frame`; `dialog`; `download wait`; `cookies/storage get|set|clear`; `state save|load <path>` (per-surface isolated sessions); `tab new|list|switch|close`; `console/errors list`; `highlight`; `screenshot`; `addinitscript/addscript/addstyle` (persistent JS/CSS injection!); `profiles list|add|…`; `browser import` (cookie import from system browsers); `disable-browser/enable-browser/browser-status`.
- Not supported (WKWebView): viewport/offline emulation, network interception, screencast, raw input.
- Routing settings: `browser.openTerminalLinksInCmuxBrowser`, `interceptTerminalOpenCommand…`, `hostsToOpenInEmbeddedBrowser`, `urlsToAlwaysOpenExternally`, `insecureHttpHostsAllowedInEmbeddedBrowser` (localhost pre-allowed), default search engine, theme.
- Layout JSON + `new-pane --type browser --url` create browser panes declaratively.

**IDE exploitation (dbt vertical is the killer)**: `dbt docs serve` + lineage DAG in an in-IDE browser pane; cute-dbt HTML artifacts; query-result HTML previews; `addstyle` to theme dbt docs to match the IDE theme; localhost link-clicks from the runner terminal auto-open inside the IDE; gh PR pages for #25. `state save/load` keeps a logged-in GitHub session per repo. All zero-egress when pointed at localhost.
**Dogfood**: **UNTAPPED** (hq-preview mentions `cmux browser --surface` once; no browser pane in any layout).

---

## 9. Markdown viewer + file preview/editor

- `cmux markdown open <path> [--workspace --surface --window]` → rendered, read-only, **live-reload** viewer split (kernel-level file watcher; handles atomic replace; survives session restore). Headings/tables/code/links/images, light+dark.
- `cmux open <files...>` → file preview tabs (text, code, PDF, images, audio, video, Quick Look) with Open-With menu; markdown routes to the viewer (`app.openMarkdownInCmuxViewer`); Cmd-click file paths in terminals opens previews (`app.openSupportedFilesInCmux`, `app.preferredEditor` fallback).
- Settings: `markdown.fontSize/fontFamily/maxWidth`; `fileEditor.wordWrap` (there is a built-in plain-text **file editor**).

**IDE exploitation**: live plan/README/dbt-model-doc pane; agent writes `plan.md`, panel updates in real time; `cide.toml` docs rendered in-IDE; PDF/image preview for dbt lineage exports.
**Dogfood**: **PARTIAL** — `cide-md-open` wraps `cmux markdown open`; live-reload-driven workflows (agent plan files, journey docs) unexploited.

---

## 10. Themes

- `cmux themes [list|set <t>|set --light X --dark Y|clear]`; interactive TTY picker with live app preview; themes are Ghostty themes; `reload-config` hot-reloads Ghostty config + cmux.json with terminals refreshed in place.
- Adjacent: `config get/set sidebar-font-size`, `surface-tab-bar-font-size` (CLI-writable Ghostty-side values); `workspaceColors.*` (palette, indicator style); `sidebarAppearance.*` tint.

**Dogfood**: **USED** — `cide-theme` is a multi-tool theme switcher already driving `cmux themes set` (+ helix/bat/etc.). Untapped: per-vertical workspace color identity via `workspace-action set-color` + `workspaceColors.colors`.

---

## 11. Settings / config schema (`cmux.json`)

- Single JSONC file `~/.config/cmux/cmux.json`, **file-watcher hot reload**, schema at `web/data/cmux.schema.json`. Top level: `actions, ui, commands, vault, newWorkspaceCommand (legacy), workspaceGroups, surfaceTabBarButtons (legacy), app, terminal, notifications, sidebar, workspaceColors, sidebarAppearance, automation, browser, markdown, fileEditor, diffViewer, shortcuts`.
- **Project-local `.cmux/cmux.json`** carries actions/commands/ui/notification-hooks per repo (trust-gated) — this is cide's config delivery vehicle under the "never write ~/.config" constraint.
- Validation: `cmux config doctor [--json]` (checks primary + project + legacy files, no socket needed) — cide doctor should wrap this.
- Key flags for cide: `app.newWorkspacePlacement`, `app.workspaceInheritWorkingDirectory`, `app.minimalMode` + `app.menuBarOnly` (chrome-less IDE look), `app.focusPaneOnFirstClick`, `terminal.copyOnSelect`, `terminal.showTextBoxOnNewTerminals` (beta prompt TextBox), `automation.portBase/portRange` (**per-workspace `CMUX_PORT` reservations** — deterministic dev-server ports per IDE space!).
- **Zero-egress red flags**: `app.sendAnonymousTelemetry` **defaults to `true`** — cide setup must flip it off (user-consented, since it lives in ~/.config); `browser.reactGrabVersion` implies a pinned remote fetch for the browser toolbar helper; `cmux feed tui --opentui` first run installs `@opentui/core` from npm (use `--legacy` for air-gap); `vm/auth` are cloud opt-ins.

**Dogfood**: **PARTIAL** — repo `.cmux/cmux.json` exists but uses ~10% of the surface.

---

## 12. Shortcuts

- `shortcuts.bindings.<actionId>` = `"cmd+b"`, two-element chord arrays `["ctrl+b","c"]` (tmux-style leaders!), `null`/`""` to unbind. ~70 action ids across app/tabs/workspace/panes/palette/notifications/right-sidebar/browser/find/files (`toggleSplitZoom`, `equalizeSplits`, `jumpToUnread`, `markOldestUnreadAndJumpNext`, `switchRightSidebarToDock`, `globalSearch`, `findInDirectory`…).
- **Custom actions from the `actions` registry are bindable** → cide verbs can own real keystrokes (e.g. `["ctrl+a","d"]` → open diff).

**Dogfood**: **UNTAPPED** — cide ships no keymap. A "cide keymap layer" (tmux-style chords for space/agent/diff/runner verbs) is free product surface.

---

## 13. Workspace-level "commands", terminal I/O & tmux-compat glue

| Primitive | What it does | IDE exploitation | Dogfood |
|---|---|---|---|
| `send / send-key [--surface]`, `send-panel` | Keystroke/text injection to any surface | cide-jump drives helix (`:open <file>`); cwd routes commands | **USED** |
| `read-screen [--scrollback --lines]` / `capture-pane` | Read terminal text | hq-preview scrapes; runner-failure parsing | **USED** |
| `pipe-pane --command` | Pipe pane text **into a shell command** | Stream runner output into a cide parser → set-status/notify on FAIL without owning the process | **UNTAPPED — gold** |
| `wait-for [-S] <name> [--timeout]` | Named sync tokens (tmux `wait-for`) | Orchestrate multi-pane journeys: editor waits for runner-ready signal; space-open barriers | **UNTAPPED — gold** |
| `respawn-pane [--command]` | Restart a surface's process | One-keystroke runner restart; crash recovery | UNTAPPED |
| `set-buffer / paste-buffer / list-buffers` | Named paste buffers | Cross-pane snippet transport (model name → harlequin) | UNTAPPED |
| `set-hook <event> <command>` | tmux-compat hooks | superseded by `cmux events` | UNTAPPED |
| `clear-history`, `display-message`, `last-pane`, `next/previous/last-window` | misc tmux parity | muscle-memory bridge | UNTAPPED |

---

## 14. Session restore / persistence

- `restore-session` — reopen previous saved session (app running or not). Windows, workspaces, panes, scrollback, browser state, markdown panels all restore.
- Per-surface resume bindings (§5) + agent session stores + `terminal.autoResumeAgentSessions`.
- **Dogfood**: **PARTIAL** — cide-space rebuilds layouts itself from cide.toml; it does not yet lean on `surface resume` for non-agent surfaces (Phase 3 #30 should).

## 15. RPC surface (rpc-only gold)

`cmux rpc <method> [json]` reaches ~200 v2 methods. Not exposed as CLI verbs (or richer via rpc):
- **`workspace.group.*`** (17 methods — see §1).
- **`extension.sidebar.snapshot`** — one-shot JSON of selected workspace + ordered workspaces with title/description/pinned/paths/branch+dirty/remote/latest prompt+message/ports/PR URLs/panel dirs — the documented bootstrap for sidebar-style consumers; pairs with the event stream. **Untapped: cide's "space dashboard" data source, no scraping.**
- `feed.list / feed.jump / feed.*.reply` — build cide's own approval UI / auto-policies.
- `workspace.prompt_submit`, `surface.read_text`, `terminal.replay/viewport`, `surface.report_shell_state`, `surface.ports_kick`, `mobile.*` (phone-attach machinery), `app.simulate_active` (test rigs).

## 16. vm / cloud + SSH

- `vm new|ls|rm|exec|shell|ssh` (alias `cloud`) — **requires `cmux auth login` and a SaaS backend → out of scope for zero-egress cide**. Mark as explicitly excluded in the product doc (the design must not depend on it; `CMUX_VM_API_BASE_URL` exists for self-hosted but is still network).
- `cmux ssh <dest>` SSH-backed workspaces with **persisted remote PTY sessions** (`ssh-session-list/attach/cleanup`), agent-forwarding opt-in, bundled remote daemon (darwin/linux, `remote-daemon-status`). **Relevant later**: Linux-future and "IDE over SSH to a beefy box" stay inside the local-first rule (SSH is user-initiated, no third party). UNTAPPED.

## 17. Custom sidebars (beta) — with a constraint catch

- Runtime-interpreted **SwiftUI-style files** in `~/.config/cmux/sidebars/<name>.swift` (or `.json`): hot reload on save, live bindings (`workspaces` with branch/dirty/PR/ports/unread/progress/latestPrompt, `tabs`, `clock`, `unreadTotal`), tappable rows running real `cmux("workspace.select", …)` actions, `Reorderable` drag-and-drop persisted via `workspace.reorder`, `HSplitView` two-column layouts. Opt-in: `customSidebars.beta.enabled`.
- **IDE exploitation**: a bespoke "cide Spaces" sidebar — spaces as groups, member workspaces with role icons, agent lifecycle dots, runner status, click-to-jump — without building any GUI.
- **Constraint tension**: sidebars load **only** from `~/.config/cmux/sidebars/` — cide "never writes to ~/.config". Resolution options for the vision doc: (a) explicit user-consented `cide sidebar install` step (documented, reversible), (b) symlink from ~/.config to repo file (still a ~/.config write), or (c) upstream feature request for project-local sidebar paths. **UNTAPPED**.

## 18. Diagnostics & resource accounting

- `cmux top [--processes --sort --format tsv --json]` — CPU/RAM per window/workspace/pane/surface/webview (process-tree attribution); `cmux memory` — app vs child RSS by command group; `surface-health`; `config doctor --json`; bundled `cmux-diagnostics` script (support-safe report).
- **IDE exploitation**: `cide doctor` (wrap doctor + ping + capabilities + hooks state); `cide top` per-space resource accounting ("this dbt space is eating 6 GB"); hibernation tuning evidence. UNTAPPED.

---

## 19. Dogfood usage map (summary)

**Already used by cide shell**: tree/identify/refs; new-window/new-workspace `--layout`; focus-window/select-workspace (space open); close-workspace; move-workspace-to-window (cide-place); workspace-action set-description (role tags); rename-tab; new-surface; send/send-key/read-screen (cide-jump, cwd, hq-preview); markdown open (cide-md-open); themes set (cide-theme); claude hooks + session store (cide-agent vault); Dock with 5 controls; palette actions ×2; reload-config.

**UNTAPPED (ranked gold)**:
1. **`cmux events` stream + cursor-file resume** — the reactive backbone; turns cide-rs into an event-driven daemon (auto-diff after agent turns, space GC, attention routing).
2. **`workspace.group.*` rpc + `workspaceGroups.byCwd`** — native IDE-space containers (replaces description-tag hack from Phase 1).
3. **`cmux diff --source last-turn` (and branch/staged/stdin)** — agent-turn review loop and PR review (#25, #26) for free.
4. **Sidebar status API**: set-status pills / set-progress / log + notification hooks policy pipeline — full IDE status system, zero UI code.
5. **`surface resume set --kind --checkpoint`** — generalized session resume for non-agent surfaces (Phase 3 #30).
6. **`vault.agents`** — register cute-dbt/harlequin/etc. as resumable first-class "agents".
7. **Browser surfaces for dbt docs/lineage/PR pages** + `addstyle` theming + localhost link routing.
8. **`pipe-pane` / `wait-for` / `respawn-pane`** — runner orchestration primitives (#23) without owning child processes.
9. **`find-window --content`** — content-addressed jump journeys (#27).
10. **Custom shortcuts layer** (chords bound to cide actions) + plus-button override + tab-bar buttons.
11. **`extension.sidebar.snapshot`** — structured dashboard data (branch/dirty/PR/ports per workspace).
12. **Custom sidebar (beta)** — cide Spaces UI (needs a consented ~/.config install).
13. **claude-teams / codex-teams** — multi-agent teams materializing as cide panes.
14. **agent-hibernation** — RAM governance across many spaces.
15. **`top`/`memory`/`config doctor --json`** — `cide doctor`/`cide top`.
16. **`automation.portBase/portRange` (`CMUX_PORT`)** — deterministic per-space dev-server ports.
17. **`workspace.prompt_submit`** — "send to agent" journey glue.
18. **trigger-flash / mark-unread / jump-to-unread** — attention engineering for runner failures.

---

## 20. Hard-constraint audit (zero-egress / no-~/.config / Linux-future)

- **Telemetry**: `app.sendAnonymousTelemetry` defaults **true** → cide onboarding must surface/flip it (user-consented ~/.config edit or documented manual step).
- **Network touchpoints to document**: Feed OpenTUI first-run npm install (use `--legacy` when air-gapped); `browser.reactGrabVersion` helper fetch; `cmux vm`/`auth` (excluded); embedded browser is egress-by-use (fine: localhost-first defaults already allowlist localhost HTTP).
- **No ~/.config writes**: everything cide needs ships via repo-local `.cmux/cmux.json` + `.cmux/dock.json` (trust-gated, hot-reloaded) — except global app settings, shortcuts, and custom sidebars, which only live in `~/.config/cmux/` → those become explicit, consented `cide setup` steps, never silent writes.
- **Linux-future**: cmux is macOS-native (Swift/Ghostty/WKWebView). The Rust hexagonal design must keep cmux behind a `Multiplexer`/`Shell` port: the socket-protocol adapter is macOS-only today; a future Zellij/tmux/WezTerm adapter is the Linux story. The CLI contract doc (ArgumentParser migration) shows the verbs are stable, but the **socket v2 protocol + events stream is the contract to bind**, not CLI text output.

---

## Sources

**Local skill files (read in full):**
- /Users/cmbays/.agents/skills/cmux/SKILL.md (+ references/handles-and-identify.md, panes-surfaces.md, trigger-flash-and-health.md, windows-workspaces.md)
- /Users/cmbays/.agents/skills/cmux-workspace/SKILL.md (+ references/commands.md)
- /Users/cmbays/.agents/skills/cmux-customization/SKILL.md (+ references/examples.md)
- /Users/cmbays/.agents/skills/cmux-settings/SKILL.md (+ references/all-keys.md, shortcut-actions.md, scripts/cmux-settings)
- /Users/cmbays/.agents/skills/cmux-browser/SKILL.md (+ references/commands.md, snapshot-refs.md, authentication.md, session-management.md, proxy-support.md, video-recording.md; templates/*.sh)
- /Users/cmbays/.agents/skills/cmux-markdown/SKILL.md (+ references/commands.md, live-reload.md)
- /Users/cmbays/.agents/skills/cmux-diagnostics/SKILL.md (+ scripts/cmux-diagnostics)
- /Users/cmbays/.agents/skills/agent-browser/SKILL.md

**Live CLI interrogation (cmux 0.64.14 (94)):** `cmux --help`, `cmux docs api|dock|settings|agents|sidebars|browser|shortcuts`, `cmux capabilities`, `cmux version`, `cmux ping`, `cmux identify --json`, `cmux tree --all`, and `--help` for: feed, events, hooks, diff, themes, open, claude-teams, agent-hibernation, restore-session, rpc, vm, surface, top, memory, find-window, pipe-pane, wait-for.

**Upstream docs (fetched per the CLI's printed curl commands):**
- https://raw.githubusercontent.com/manaflow-ai/cmux/main/docs/cli-contract.md
- https://raw.githubusercontent.com/manaflow-ai/cmux/main/docs/events.md
- https://raw.githubusercontent.com/manaflow-ai/cmux/main/docs/feed.md
- https://raw.githubusercontent.com/manaflow-ai/cmux/main/docs/agent-hooks.md
- https://raw.githubusercontent.com/manaflow-ai/cmux/main/docs/notifications.md
- https://raw.githubusercontent.com/manaflow-ai/cmux/main/docs/dock.md
- https://raw.githubusercontent.com/manaflow-ai/cmux/main/docs/custom-sidebars.md
- https://raw.githubusercontent.com/manaflow-ai/cmux/main/web/data/cmux.schema.json
- Web docs index: https://cmux.com/docs (api, dock, configuration, browser-automation, keyboard-shortcuts, agent-integrations, custom-sidebars)

**cide dogfood inspected:** /Users/cmbays/github/cmux-workspace-dbt/bin/* (cide-space, cide-agent, cide-jump, cide-place, cide-theme, cide-md-open, cide-set-role, cwd, hq-preview, …), lib/ (common.sh, cide-layout.sh, cide-editor.sh), .cmux/cmux.json, .cmux/dock.json, cide.toml.
