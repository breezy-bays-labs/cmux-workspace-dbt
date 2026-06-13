# Terminal IDE Landscape 2025–2026 — The Competitive Frame for cide

> Web research, June 2026. Brief: how power users compose terminal IDEs today, what "IDE"
> features users actually expect, where DIY compositions hurt, and why a GUI multiplexer
> (cmux) + curated TUIs + one orchestrating tool (cide) is a defensible position.
> Companion local context: `/Users/cmbays/github/cmux-workspace-dbt/cide.toml`,
> `bin/cide-*`, `lib/cide-layout.sh` (the POSIX-sh dogfood this research informs).

---

## 1. Executive summary

The terminal IDE in 2025–2026 is not one product — it is a **composition pattern**:
a multiplexer (tmux or zellij) supplies layout/session, a modal editor (neovim or
helix) supplies LSP editing, and a constellation of single-purpose Rust/Go TUIs
(yazi, lazygit, gh-dash, television, serpl, atuin, btop, harlequin) supplies the
rest. Two schools dominate: the mature **tmux + neovim** school (sessionizer scripts,
vim-tmux-navigator, TPM plugins, LazyVim/AstroNvim as "config distros") and the
newer **zellij + helix** school (zide, yazelix, theylix), which exists precisely
because helix has no plugin system and outsources file-tree, git UI, and
search/replace to the multiplexer layer.

Every one of these compositions re-solves the same five problems with shell-script
glue: cross-pane file opening, session save/restore, unified theming, keybinding
discoverability, and project switching. None solves them well; each maintainer
openly documents the workarounds. Meanwhile the AI-agent wave (Warp "Agentic
Development Environment", Zed 1.0 parallel agents, opencode, Claude Code agent
teams running *on tmux*) has made the multiplexer the de-facto agent runtime —
without giving terminal compositions any first-class agent UX.

That intersection — IDE-grade glue + agent-native surfaces + GUI-quality rendering,
delivered as **one orchestrating tool over a curated stack** — is cide's wedge.

---

## 2. How power users compose terminal IDEs today

### 2.1 The composition pattern

The consensus recipe across 2025–2026 writeups (Joshua Michael Hall's
terminal-based development guide, the "tmux + Neovim + lazygit — The Stack That
Replaced My Entire IDE" Medium piece, johal.in's 2026 benchmark writeup):

- **One named multiplexer session per project**, with pre-configured windows
  (editor / shell / services / logs).
- **Editor pane** is neovim (or helix) carrying LSP, treesitter, pickers.
- **Everything else is a TUI launched into a pane or popup**: lazygit for git,
  a file manager, a process monitor, test runners in splits.
- **Project switching** via fuzzy-find scripts: ThePrimeagen's `tmux-sessionizer`
  (fzf over repo dirs → create-or-attach session) is the canonical pattern, with a
  Rust reimplementation (`tms`) adding git-worktree-aware session opening — proof
  that "project/worktree → session" is a felt need, not a nicety.

Claimed payoffs are real but operational: keyboard-driven flow, low memory, full
control, fast context switches (johal.in reports p99 context-switch 2.1s → 0.9s
and 12GB → 4GB idle memory moving a team from GUI IDEs to terminal stacks).

### 2.2 The tmux + neovim school (mature, plugin-heavy)

- **Glue plugins are mandatory, not optional**: `vim-tmux-navigator` (seamless
  C-h/j/k/l across vim splits *and* tmux panes — a plugin that must be installed
  on BOTH sides to fake one navigation model), `tmux-yank` + OSC 52 for clipboard,
  TPM as plugin manager, `tmux-resurrect`/`continuum` for session persistence.
- **"Oh my tmux!"** exists because raw tmux defaults are hostile: it ships 40+
  "sane" keybindings and a powerline theme — i.e., a curated-defaults distro for
  the multiplexer alone.
- **Session managers** (tmuxinator, smug, sesh, sessionizer scripts) encode
  per-project window layouts in YAML/scripts — layout-as-data, reinvented per user.
- The 2026 twist: tmux is having a renaissance **as an AI-agent runtime** —
  session persistence + process isolation + scriptable CLI made it the
  orchestration substrate for Claude Code agent teams (Anthropic's split-pane
  agent-teams mode is built on tmux), plus an emerging tool layer (NTM, amux,
  tmai, Tmux-Orchestrator) that tiles and monitors multiple coding agents in panes.

### 2.3 The zellij + helix school (newer, glue-as-product)

Helix's gaps are structural — no plugin system (Scheme-based one still pending as
of 2025), file explorer only recently landed and minimal, no global
search/replace, no integrated terminal — so the multiplexer becomes the plugin
system:

- **zide** (josephschmitt): zellij layouts + bash scripts = yazi picker pane +
  helix pane. File opening works by hijacking `$EDITOR` into a `zide-edit` script
  that calls `zellij action focus-next-pane` then types `:open <file>` into helix.
  Its README admits the core fragility: *the editor pane must sit next to the
  picker pane because zellij has no way to uniquely identify panes* outside a
  plugin. This is keystroke-injection IPC with positional addressing.
- **yazelix** (luccahuguet): yazi sidebar + zellij + helix/nvim, git integration,
  popup system (lazygit, config UI), zoxide, zjstatus widgets; installs via nix
  flake. Sells itself as "your terminal IDE."
- **theylix** (Codeberg): same recipe, zen-mode flavored.
- **Guillermo Aguirre's "Turning Helix into an IDE with Zellij"**: floating panes
  for yazi and serpl bound to helix keys via `:sh zellij run -c -f`; author
  concedes the serpl flow risks losing unsaved buffers and needs manual
  `:reload-all` after replacements — "workarounds rather than native solutions."
- zellij itself: KDL layouts (layout-as-data, natively), WASM plugin system,
  zjstatus + zjstatus-hints (mode-aware keybinding hints), zellij-autolock
  (auto-switch lock mode when an editor is focused — glue to stop keybinding
  collisions between zellij and helix). Session resurrection is still the weak
  spot: native persistence remains roadmap-grade; users script layout recreation,
  while tmux users live with tmux-resurrect's known failure modes.

### 2.4 Curated distributions — the "omakase" signal

- **Omarchy** (DHH): an Arch+Hyprland distro whose pitch is *curation* — Neovim
  (LazyVim), lazygit, a TUI roster, themes, and keybindings pre-wired
  (`Space G G` → lazygit floating pane). Its popularity is the strongest demand
  signal that power users want **someone else to make the composition decisions**
  while keeping terminal-native tools.
- **LazyVim / AstroNvim**: distros *within* the editor. LazyVim ships a picker
  abstraction (uniform interface over fzf-lua/telescope/snacks — note: an
  explicit ports-and-adapters move), trouble.nvim diagnostics panel, gitsigns,
  grug-far multi-file search/replace, todo-comments, workspace-root detection,
  and an "extras" system of per-language bundles. AstroNvim adds neotest (test
  explorer), nvim-dap (debugging), resession (per-directory session restore), and
  which-key (press leader → discover every binding). These distros define the
  feature bar a terminal IDE must meet (see §4).

### 2.5 Adjacent competitors

| Competitor | Position | Relevance to cide |
|---|---|---|
| **Zed** (1.0, Apr 2026) | Native GUI editor, Rust, parallel agents in one window, ACP protocol, Terminal Threads running Claude Code as sidebar agents. "Agent cockpit" framing; ~3.8/5 AI-power-user readiness per builder.io. | The strongest GUI gravity well for this exact audience. cide's counter: terminal tools stay sovereign; no editor lock-in; zero-egress. Zed normalized "editor as agent cockpit" — cide can claim "workspace as agent cockpit." |
| **Warp 2.0** | "Agentic Development Environment": IDE-like input, agent multithreading, Warp Drive shared knowledge. | SaaS-coupled, telemetry-heavy — disqualified for the zero-egress buyer. Validates the agent-cockpit terminal category. |
| **WaveTerm** | Open-source terminal with blocks, IDE-like input, native Claude/Codex/Gemini agents. | Closest open analog to cmux's surface model; weaker multiplexing/layout story. |
| **opencode** (~140k stars) | Provider-agnostic terminal coding agent; TUI with LSP diagnostics, sessions, vim-like input. | Terminal agents "won" 2026 — but opencode is the agent, not the workspace. cide hosts such agents. |
| **VS Code** | Free, integrated everything, Copilot-native. | The defection destination when DIY friction wins (see §4.3). |
| **XTide86, tmux-ide, NTM** | Niche "terminal IDE in a box" / agent-tiling projects. | Evidence the niche is being probed, with nobody owning it. |

---

## 3. The standalone TUI ecosystem (the parts bin)

The Rust/Go TUI renaissance (Terminal Trove, awesome-tuis catalog the breadth)
supplies best-in-class single-purpose tools — each one *better at its job than the
equivalent IDE panel*, none aware of the others:

| Tool | Role | Notes |
|---|---|---|
| **yazi** | File manager | Async Rust; image/PDF/video previews (Kitty/Sixel/iTerm2/Ghostty protocols); Lua plugin system + package manager; bulk rename; git integration; `DuckDB.yazi` previews CSV/Parquet — directly relevant to the dbt IDE. |
| **lazygit** | Git porcelain | The default git TUI of every curated setup (Omarchy binds it globally; gh-dash launches it). Interactive rebase, hunk staging, worktrees. |
| **gitui** | Git porcelain (alt) | Rust, faster on huge repos; smaller feature set; the standard fallback/swap for lazygit. |
| **gh-dash** | GitHub PR/issue dashboard | gh extension; custom keybindings can launch lazygit, fire Actions, or trigger AI review from a selected PR — already a mini-orchestrator. |
| **television** | Fuzzy finder | "Telescope outside neovim": channels over files/grep/git/env, nucleo matching, preview pane, ratatui. The picker primitive for a non-neovim IDE. |
| **serpl** / scooter | Project-wide search & replace | "VS Code-style global search and replace TUI" (HN framing); ripgrep-backed, AST-grep mode; the canonical helix companion, wired via keybinding + `:reload-all`. |
| **atuin** | Shell history | SQLite-backed full-screen search; e2e-encrypted sync (optional — local-only mode fits zero-egress). |
| **btop** | System/process monitor | The default "resources pane." |
| **harlequin** | SQL IDE TUI | Multi-backend (DuckDB, SQLite, Postgres…); the data pane for the dbt IDE (already wrapped in `bin/hq-wrap`). |
| **zoxide / fzf / fd / rg / bat / eza / just / difftastic / tig** | Substrate | Assumed present in every 2025 power-user environment. |
| **tinty / flavours (tinted-theming)** | Cross-tool theming | Exists *because* per-tool theming is a real pain: 250+ base16/base24 schemes templated per tool, applied via shell hooks that rewrite each tool's config. A whole project dedicated to one of cide's wedge pains. |

Key observation: **the parts are excellent; the product is missing.** Every tool
above ships its own config format, theme format, keymap, and zero knowledge of
project, session, or the file the editor has open.

---

## 4. (a) Table-stakes vs differentiators

### 4.1 Table stakes — what "IDE" means to this audience in 2026

Derived from what LazyVim/AstroNvim/VS Code provide and what every composition
tries to replicate. cide must have a credible answer for each:

| Capability | LazyVim/AstroNvim answer | DIY tmux/zellij answer | Status in compositions |
|---|---|---|---|
| Fuzzy file/symbol picker | picker abstraction (fzf-lua/telescope/snacks) | television / fzf in a popup | OK but not editor-wired |
| Project-wide live grep | telescope/snacks grep with preview | `tv grep` / rg+fzf scripts | OK |
| Project-wide search & **replace** | grug-far.nvim | serpl/scooter + manual `:reload-all` | Fragile (unsaved-buffer hazard) |
| File tree w/ file ops | neo-tree | yazi pane + `$EDITOR` hijack glue | Fragile (positional pane addressing) |
| LSP UX (rename, code actions, hover, refs) | built-in, polished | editor-internal only (helix/nvim) | OK inside editor, invisible outside |
| Diagnostics panel (project-wide) | trouble.nvim | **none** outside the editor | GAP |
| Git signs in gutter + hunk ops | gitsigns.nvim | helix has basic gutters; rest in lazygit | Split-brain |
| Integrated test explorer | neotest | a shell pane running the test command | GAP (no structure, no rerun-failed UX) |
| Debugging (DAP) | nvim-dap + UI | essentially absent (helix DAP experimental) | GAP — the perennial "go back to VS Code" trigger |
| Session/project management & restore | resession per-directory; sessionizer | tmux-resurrect (flaky) / zellij scripts | Universally painful |
| Keybinding discoverability | which-key | zjstatus-hints; tmux: nothing | GAP in tmux school |
| Unified theming | one colorscheme themes the whole editor | tinty/flavours config-rewriting hooks | Painful |
| Multi-root / monorepo awareness | workspace root detection | cd + sessionizer conventions | Weak |
| AI agent surface | Copilot/avante in-editor; Zed agent panel | a pane running claude/opencode | Unstructured (no feed, no status, no resume UX) |

### 4.2 Differentiators (where compositions can BEAT IDEs)

- **Tool sovereignty**: lazygit > any IDE git panel; yazi previews > any IDE file
  tree; harlequin > any IDE SQL scratchpad. Compositions win per-panel.
- **Process honesty**: real shells, real processes, scriptable everything.
- **Resource profile** and latency (the johal.in numbers).
- **Vertical assembly**: a *dbt* IDE (harlequin + DuckDB.yazi previews + cute-dbt
  + jinja-aware editor) is something no general IDE ships; compositions can be
  vertical-first. This is cide's clearest product-shaped differentiator.
- **Agent-native layout**: agents as first-class panes with persistence — the
  thing tmux is being bent into, done deliberately.
- **Zero-egress/local-first**: Warp can't claim it; Zed partially; a curated
  local TUI stack can claim it absolutely.

### 4.3 What drives defection back to GUI IDEs

From the "why I switched back to VS Code" literature: (1) AI integration quality
(Copilot et al. "just works" in VS Code/Zed), (2) configuration fatigue — more
time on the editor than in it, (3) debugging/test UX, (4) ecosystem-exclusive
tooling. cide's posture must be: kill #2 with curation, match #1 via cmux's
native agent machinery, and treat #3 as a roadmap vertical (test runner pane
first — already task #23 in the dogfood — DAP story later).

---

## 5. (b) The recurring pain of DIY compositions — cide's wedge

Every pain below is documented in the sources, not hypothesized:

1. **Glue fragility / no real IPC.** zide injects keystrokes into the editor pane
   and *requires adjacency* because zellij can't address panes by identity.
   Guillermo's serpl wiring can eat unsaved buffers. vim-tmux-navigator needs
   matched plugins on both sides of the boundary. All cross-tool integration is
   `$EDITOR` hijacking, keystroke injection, and positional addressing — there is
   **no shared workspace model** (current file, project root, selection, git
   state) that tools can read or subscribe to.
2. **Session restore is universally broken-ish.** tmux needs tmux-resurrect with
   known failure modes; zellij's native resurrection is still roadmap-grade and
   "too prescriptive" per switchers; every distro reinvents per-project layout
   scripts. Nobody restores *semantic* state (which file, which agent
   conversation) — only pane geometry at best. (cide's IDE-spaces +
   agent-conversation-resume work is already ahead of the field here.)
3. **Per-tool theming.** N tools × N theme formats. The tinted-theming project
   (tinty/flavours: 250+ schemes, per-tool templates, shell-hook config
   rewriting) is an entire ecosystem built to patch this one pain — and it still
   requires per-tool hook wiring. A curated stack can ship one theme switcher
   (cide-theme already does).
4. **Keybinding discoverability.** tmux has no which-key; zellij needed
   zjstatus-hints as a third-party plugin; every tool has its own keymap and
   collision surface (zellij-autolock exists solely to stop zellij/helix key
   fights). LazyVim's which-key and a single leader-key grammar is the bar.
5. **Project/session switching is everyone's homework.** sessionizer, tms, smug,
   tmuxinator, sesh — five+ tools for "fuzzy-pick repo → open its layout."
   The Rust `tms` adding worktree-awareness shows where the puck is going
   (worktree-per-task workflows, agent parallelism).
6. **Configuration sprawl and fatigue.** The composition touches ~/.config for
   tmux/zellij + editor + every TUI; dotfile repos and nix flakes (yazelix) are
   the coping mechanisms. The "spent more time configuring than coding" defection
   driver lives here. (cide's no-~/.config-writes, repo-local config is a direct
   answer.)
7. **No cross-tool journeys.** blame→diff→history→PR-comment→editor jumps require
   leaving one TUI and re-finding context in another. gh-dash's custom commands
   (launch lazygit on the selected PR) are the embryonic form of what an
   orchestrator should own end-to-end. (Matches dogfood task #27.)
8. **Agents bolted on, not designed in.** The tmux-as-agent-runtime wave (NTM,
   amux, Tmux-Orchestrator, Anthropic's tmux-based agent teams) gives agents
   panes but no feed, no notification routing, no per-agent identity, no
   conversation persistence tied to workspace restore.

---

## 6. (c) Why cmux + curated TUIs + one orchestrating tool can beat both

**Against DIY tmux/zellij compositions:**

- cmux is a **GUI multiplexer**: native rendering, real browser surfaces, a diff
  viewer, notification feed, command palette, dock — capabilities a TUI
  multiplexer structurally cannot host (zellij's answer to "show me an image" is
  a terminal graphics protocol; cmux's is a webview).
- cmux has **addressable topology** (windows/workspaces/surfaces via RPC — see
  `cmux capabilities`: browser.*, surface and window methods), which kills the
  zide-class fragility: cide can place, focus, and message panes by identity, not
  position. The dogfood already exploits this (cide-space layout-as-data,
  cide-place monitor-aware placement, cide-jump).
- cmux has **native agent machinery** (agent panes, session hooks, feed): cide's
  agent surfaces (cide-agent vault, conversation resume) are first-class, where
  tmux compositions have a bare pane running `claude`.
- One orchestrating tool ships **the missing shared state**: project, space,
  active file, theme, roles — the workspace model DIY glue never had. Hexagonal
  Rust with tool adapters formalizes what LazyVim's picker abstraction hints at:
  curated defaults, swappable ports.
- Curation kills configuration fatigue the omarchy way: opinionated defaults,
  repo-local config, zero ~/.config pollution — omakase without the distro.

**Against GUI editors (Zed/VS Code/Warp):**

- The audience's best tools remain sovereign (helix, lazygit, yazi, harlequin
  are *better* than the IDE-panel equivalents) — cide composes them rather than
  replacing them with worse built-ins.
- **Zero-egress/local-first** is a hard differentiator: Warp is SaaS-coupled;
  Zed phones home for AI; a curated local stack + gh CLI can be air-gapped.
  No GUI competitor will match this constraint-first posture.
- Editor-agnosticism: Zed wins only if you adopt Zed-the-editor. cide's bet is
  the workspace, not the buffer.
- Vertical IDEs (dbt, rust) out-specialize horizontal editors: harlequin +
  DuckDB yazi previews + cute-dbt is a stack VS Code's dbt extensions don't touch,
  locally.

**The honest risks:** macOS-only cmux narrows the initial market vs cross-platform
tmux/Zed; the composition's ceiling is set by helix's editor gaps (debugging,
plugin system) until helix matures; and Zed's velocity at "agent cockpit" means
cide's defensible ground is the *terminal-tool-sovereign, zero-egress, vertical*
buyer — which is exactly the founder's own profile (dogfood validity).

---

## 7. (d) Defensible default tools for cide

| Slot | Default | Why defensible (2025–2026 evidence) | Swap port |
|---|---|---|---|
| Editor | **helix** | Zero-config LSP, the rising "post-config" editor; its gaps are precisely what cide fills (file tree, global S&R, git UI) — symbiosis, not overlap | neovim (LazyVim users), kakoune |
| File manager | **yazi** | Category winner: async previews, Lua plugins, package manager, DuckDB preview for the dbt vertical; default in zide/yazelix | broot, lf, nnn |
| Git porcelain | **lazygit** | Default in omarchy, gh-dash integrations, every "stack that replaced my IDE" post | gitui, tig, gitu (magit-style) |
| GitHub | **gh-dash + gh CLI** | Terminal-native PR/issue dashboard; zero-egress-compatible (gh is allowed); extensible keybindings | octo.nvim-style flows later |
| Picker | **television** | The telescope-outside-neovim; channels = extensible search surfaces (files/grep/git/env → cide channels: models, dbt nodes, spaces) | fzf, fzf+scripts |
| Search & replace | **serpl** (watch **scooter**) | The named VS Code-S&R-in-terminal tool; AST-grep mode; known helix wiring | scooter, grug-far (nvim-only) |
| History | **atuin** | Best-in-class; local-only mode satisfies zero-egress | shell default |
| Monitor | **btop** | Uncontested default | bottom |
| SQL (dbt IDE) | **harlequin** | The terminal SQL IDE, multi-adapter; already dogfooded (hq-wrap) | usql, pgcli family |
| Theming | **cide-theme over per-tool adapters** | tinted-theming proves demand; cide owns the hook layer instead of the user | tinty as engine |
| Prompt | starship / oh-my-posh dual (task #24) | Both dominant; selectable engine fits ports-and-adapters | — |
| Runner | **just** + test-runner pane | justfile ubiquity in Rust ecosystem; per-vertical runners (cargo nextest, dbt build) plug in | make, mise tasks |

Defensibility logic: every default above is (1) Rust/Go, actively maintained,
(2) already the consensus pick in at least two independent curated setups, and
(3) wrappable behind a trait without forking. The moat is not the tools — it's
the **shared workspace model + cmux-native placement/agents/theming glue** that
makes them feel like one product.

---

## 8. Opportunity checklist distilled for cide's vision doc

1. Own the **shared workspace model** (project/space/file/git/agent state) as the
   IPC layer DIY glue never had — pane-identity addressing via cmux RPC.
2. **Semantic session restore**: spaces that reopen tools *and* agent
   conversations (already in flight; the field restores geometry at best).
3. **One-command theming** across all curated tools (tinty-class engine, owned).
4. **which-key for the whole workspace**: a cide keymap overlay/palette that
   makes every tool's bindings discoverable from one place (cmux command palette
   is the natural host).
5. **Project/worktree sessionizer**, worktree-aware like `tms`, agent-aware like
   nobody.
6. **Project-wide diagnostics + test-explorer panes** — the two loudest gaps vs
   LazyVim/VS Code; a structured test-runner pane (rerun-failed, per-vertical)
   is high-leverage and already started (task #23).
7. **Search/replace journey** without the unsaved-buffer hazard: cide mediates
   write-all → serpl → reload-all as one safe verb.
8. **Cross-tool journeys** (blame→diff→PR→editor) as named, wired flows (task #27).
9. **Agent cockpit**: feed-routed, resumable, multi-agent surfaces — the
   tmux-agent-orchestration demand (NTM/amux/agent-teams) with a real UI.
10. **Vertical IDEs as products**: dbt first (harlequin + DuckDB previews +
    cute-dbt + jinja-SQL tooling) — no competitor assembles this locally.

---

## Sources

### Compositions & schools
- https://github.com/josephschmitt/zide — zide (zellij+yazi+helix IDE layouts; pane-adjacency limitation)
- https://github.com/luccahuguet/yazelix — yazelix (yazi+zellij+helix/nvim "terminal IDE")
- https://codeberg.org/goblina/theylix — theylix
- https://www.guillermoaguirre.dev/articles/helix-to-ide-with-zellij — Turning Helix into an IDE with Zellij (serpl/yazi floating-pane wiring + admitted friction)
- https://guillermoap.medium.com/turning-helix-into-an-ide-with-the-help-of-zellij-03c4e52524da — same, Medium mirror
- https://github.com/helix-editor/helix/discussions/8000 — Helix-as-IDE with WezTerm discussion
- https://joshuamichaelhall.com/blog/2025/03/23/terminal-based-development-environment/ — terminal-based dev with neovim/tmux/CLI tools
- https://medium.com/the-software-journal/tmux-neovim-lazygit-the-stack-that-replaced-my-entire-ide-efe9234741eb — tmux+neovim+lazygit stack
- https://johal.in/use-tmux-neovim-terminal-based-development-2026-tmux/ — 2026 setup/benchmarks (context-switch + memory numbers)
- https://iampavel.dev/blog/tmux-neovim-opencode-workflow — tmux+neovim+AI tdev workflow
- https://github.com/ThePrimeagen/tmux-sessionizer — tmux-sessionizer
- https://crates.io/crates/tmux-sessionizer — tms (Rust; worktree-aware sessions)
- https://carlosbecker.com/posts/tmux-sessionizer/ — sessionizer workflow writeup

### tmux/zellij mechanics & pain
- https://github.com/christoomey/vim-tmux-navigator — seamless nav requires dual-side plugins
- https://www.terminal.guide/tools/multiplexer/tmux/plugins-guide/ — TPM/resurrect/continuum guide
- https://www.fosslinux.com/80608/how-to-copy-and-paste-with-a-clipboard-in-tmux.htm — tmux clipboard / OSC 52 (2026)
- https://www.blog.brightcoding.dev/2025/09/29/supercharging-tmux-with-oh-my-tmux-themes-plug-ins-and-zero-stress-customization/ — Oh my tmux! curated defaults
- https://dasroot.net/posts/2026/02/terminal-multiplexers-tmux-vs-zellij-comparison/ — tmux vs zellij 2026 (session resurrection comparison)
- https://www.mauriciopoppe.com/notes/tmux-to-zellij/ — tmux→zellij (and back); session-manager prescriptiveness
- https://bulimov.me/post/2025/03/22/tmux-zellij/ — switching from tmux to zellij
- https://github.com/dj95/zjstatus — zjstatus (+ zjstatus-hints, autolock ecosystem)
- https://github.com/zellij-org/awesome-zellij — zellij plugin ecosystem
- https://zellij.dev/news/ — KDL layouts, WASM plugin system

### Distros & editor feature bar
- https://learn.omacom.io/2/the-omarchy-manual — Omarchy manual (curation thesis)
- https://learn.omacom.io/2/the-omarchy-manual/56/neovim — Omarchy Neovim/LazyVim bindings (Space-G-G lazygit)
- https://learn.omacom.io/2/the-omarchy-manual/59/tuis — Omarchy TUI roster
- http://www.lazyvim.org/plugins/editor — LazyVim editor plugins (grug-far, gitsigns, trouble, todo-comments)
- https://deepwiki.com/LazyVim/LazyVim — LazyVim architecture (picker abstraction, extras, root detection)
- https://docs.astronvim.com/ — AstroNvim (neotest, nvim-dap, which-key, resession)
- https://docs.astronvim.com/recipes/sessions/ — AstroNvim session management
- https://helixeditor.com/2025/04/11/does-helix-support-plugins/ — helix plugin status
- https://biggo.com/news/202509120730_Helix_Editor_Gains_Developer_Traction — helix traction despite missing plugins
- https://github.com/helix-editor/helix/discussions/8314 — file explorer workaround thread
- https://felix-knorr.net/posts/2025-03-16-helix-review.html — Helix 1.5-year review
- https://github.com/helix-editor/helix/discussions/3793 — helix global search & replace gap
- https://dev.to/nexxeln/why-i-switched-from-neovim-to-vscode-1kdn — defection drivers (Copilot, config fatigue)
- https://www.nexxel.dev/blog/neovim-to-vscode — same author, canonical post

### TUI parts bin
- https://github.com/alexpasmantier/television — television (channels, nucleo, ratatui)
- https://terminaltrove.com/television/ — television on Terminal Trove
- https://lib.rs/crates/serpl — serpl
- https://news.ycombinator.com/item?id=43678158 — "Serpl – a VSCode-style global search and replace TUI" (HN)
- https://github.com/sxyazi/yazi — yazi
- https://nerdpress.org/2025/11/08/5-essential-plugins-for-yazi-file-manager/ — yazi plugins incl. DuckDB.yazi
- https://github.com/dlvhdr/gh-dash — gh-dash (custom keybindings → lazygit/Actions/AI review)
- https://wostal.eu/blog/tools-01-gh-and-gh-dash/ — gh + gh-dash daily workflow
- https://github.com/gitui-org/gitui — gitui
- https://terminaltrove.com/atuin/ — atuin
- https://www.terminal.guide/tools/system-monitor/btop/ — btop
- https://github.com/rothgar/awesome-tuis — TUI catalog
- https://terminaltrove.com/new/ — Terminal Trove (discovery hub)
- https://github.com/tinted-theming/tinty — tinty (cross-tool theming manager)
- https://www.davesnider.com/posts/base16-terminal-theme — base16 + flavours workflow

### Adjacent competitors & the agent wave
- https://zed.dev/ai — Zed AI
- https://www.builder.io/blog/zed-ai-2026 — Zed AI-power-user readiness (3.8/5)
- https://chatforest.com/reviews/zed-1-0-ai-code-editor-parallel-agents-rust-review/ — Zed 1.0 (Apr 2026), parallel agents
- https://zed.dev/acp — Agent Client Protocol
- https://www.warp.dev/blog/reimagining-coding-agentic-development-environment — Warp 2.0 ADE
- https://openalternative.co/compare/warp/vs/waveterm — Warp vs WaveTerm
- https://openalternative.co/waveterm — WaveTerm
- https://opencode.ai/ — opencode
- https://dev.to/ji_ai/opencode-hit-140k-stars-why-terminal-agents-won-2026-aci — terminal agents won 2026
- https://code.claude.com/docs/en/agent-teams — Claude Code agent teams (tmux split-pane mode)
- https://pasqualepillitteri.it/en/news/3493/tmux-runtime-coding-agents-2026 — tmux as agent runtime, 2026
- https://vibecoding.app/blog/ntm-review — NTM multi-agent tmux orchestrator
- https://github.com/absmartly/Tmux-Orchestrator — Tmux-Orchestrator
- https://dev.to/logicmagix/xtide86-a-terminal-ide-that-brings-neovim-tmux-cc-and-python-together-3omc — XTide86 (terminal-IDE-in-a-box niche)

### Local grounding
- /Users/cmbays/github/cmux-workspace-dbt/cide.toml — IDE instance model, spaces, agent surfaces
- /Users/cmbays/github/cmux-workspace-dbt/bin/ — cide-space, cide-agent, cide-place, cide-theme, cide-jump, hq-wrap, etc.
- /Users/cmbays/github/cmux-workspace-dbt/lib/cide-layout.sh — layout-as-data presets
- `cmux capabilities` (read-only, v0.64.14) — addressable RPC surface incl. browser.* methods
