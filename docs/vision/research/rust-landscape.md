# The 2025–2026 Rust Terminal-DX Landscape — research for the cide Rust IDE vertical

> Research date: 2026-06-09. Scope: every capability a "magical terminal Rust IDE" needs, which
> tool is the defensible default per capability (cide uses swappable adapters, so runner-ups
> matter), what bacon does that a generic watchexec runner does not, and the gaps nothing covers
> well. All claims web-sourced; URLs in `## Sources`.
>
> Context: cide = terminal IDE composed on top of cmux (agent panes, notification feed, palette,
> diff viewer, browser surfaces). Today a POSIX-sh dogfood in this repo (`bin/cide-*`, `lib/`,
> `cide.toml`); destination is a hexagonal Rust tool. Hard constraints: zero-egress / local-first,
> never writes `~/.config`, macOS-first but Linux-compatible design.

---

## 1. Executive summary

The 2025–2026 Rust terminal ecosystem has quietly assembled almost every piece of an IDE — but as
disconnected single-purpose tools. **bacon** (the officially blessed successor to the now-dormant
cargo-watch) is the background brain: a job-based watch/check/test loop that *parses* cargo's JSON
diagnostics, sorts them intelligently, exports locations for editors, and is remote-controllable
over a Unix socket. **cargo-nextest** is the uncontested test runner (process-per-test, retries,
partitioning, machine-readable output, build archives). **helix + rust-analyzer** is a strong but
incomplete editing core — inlay hints are janky, DAP debugging is experimental and undocumented,
and the Steel plugin system is still unmerged, which is precisely why composing an IDE *around*
helix (cide's thesis) beats waiting for helix to grow IDE features. The quality stack
(cargo-mutants, insta/cargo-insta, cargo-llvm-cov, cargo-deny, cargo-semver-checks) is mature and
CI-proven but has no shared cockpit. The two genuinely weak fronts are **terminal-native
debugging** (lldb-dap exists; the UX around it doesn't) and **terminal test/coverage/bench
exploration UIs** (the data formats exist; nobody renders them). Both are open lanes for cide.

Architecturally decisive finding: **watchexec is not just a CLI — it is an embeddable, Tokio-based
Rust library** (`watchexec`, `watchexec-events`, `watchexec-signals`, `watchexec-supervisor`
crates). The Rust cide can embed the watch engine itself for generic/dbt verticals while driving
bacon as a managed adapter for the Rust vertical. Bacon's own roadmap ("bacon for everything",
BURP protocol, eslint/pytest analyzers) confirms the same convergence from the other side.

---

## 2. (a) The "magical terminal Rust IDE" capability checklist

A terminal Rust IDE is magical when all of these run without leaving the keyboard, without a
browser (except deliberately, via a cmux browser surface), and without SaaS:

| # | Capability | What "magical" means |
|---|---|---|
| 1 | **Background check/lint loop** | Errors/warnings appear seconds after save, parsed and sorted (errors first, earliest first), not raw compiler spew; one key to flip check↔clippy↔test↔doc |
| 2 | **Editing intelligence (LSP)** | rust-analyzer completions, goto, rename, code actions in helix; diagnostics offloadable to the background loop on big workspaces |
| 3 | **Test running** | nextest speed + retries/flaky detection; watch-triggered; failing-test filter; one key to re-run last failure |
| 4 | **Test review (snapshots)** | `cargo insta review` interactive accept/reject as a first-class pane; TUI snapshot testing of cide itself |
| 5 | **Coverage on demand** | One action → cargo-llvm-cov (nextest-integrated) → HTML in a browser surface + lcov for future gutter rendering |
| 6 | **Mutation gate** | cargo-mutants `--in-diff` against the branch diff as a pre-PR ritual, not a CI-only afterthought |
| 7 | **Benchmarks** | divan for the inner loop (fast, low-noise, CI-able), criterion for statistical rigor + HTML reports |
| 8 | **Supply-chain & license gate** | cargo-deny (advisories+licenses+bans+sources) runnable offline against a vendored advisory DB clone |
| 9 | **Task surface** | justfile recipes surfaced in the palette / runner pane; just is the lingua franca across cide verticals |
| 10 | **Macro x-ray** | cargo-expand on the symbol/file under cursor, diffable against previous expansion |
| 11 | **Docs** | `cargo doc` / `cargo-docs serve` rendered into a cmux browser surface; `rustup doc` for std — all fully offline |
| 12 | **Crate exploration** | `cargo info` (now built into cargo), crates-tui for browsing, cargo-whatfeatures for feature flags |
| 13 | **Debugging** | lldb-dap via helix (experimental) or rust-lldb in a pane; tokio-console for async; probe-rs/cargo-embed for embedded |
| 14 | **Profiling** | samply / cargo-flamegraph / hyperfine one-keystroke away (with an egress caveat on samply's web UI) |
| 15 | **Release hygiene** | cargo-semver-checks, cargo-machete (unused deps), typos — the "pre-publish ritual" |
| 16 | **Scratchpad/REPL** | evcxr pane for trying API shapes without a scratch crate |
| 17 | **Git/PR layer** | Already cide's base: lazygit, tig, gh-dash, difftastic, cmux diff viewer |
| 18 | **Agent integration** | Claude/Codex panes that can *read* the runner's structured output (locations export, libtest-json) instead of scraping ANSI |

The connective tissue — jump from failing test → editor at line → diff → re-run — is the IDE; no
single tool above provides it. That is cide's product.

---

## 3. (b) Defensible defaults per capability (+ runner-ups for swappable adapters)

### 3.1 Background watch/check loop — **default: bacon** (runner-up: watchexec CLI; legacy: cargo-watch)

- bacon is a "background rust code checker" by Canop (broot's author), actively maintained
  through 2025–2026 (3.20.x Dec 2025 → 3.22 Jan 2026).
- **Job model**: `bacon.toml` defines jobs — a job = a command bacon runs in background on file
  change, whose result is *analyzed*, sorted, and displayed. Key job properties: `command`
  (token array), `analyzer` (standard | cargo_json | nextest | eslint | python_unittest |
  python_pytest), `need_stdout`, `allow_warnings`/`allow_failures`, `background`, `watch`
  (explicit paths), `env`, `on_success` (chain another action), and on-change kill/restart
  strategy. Config layers: internal defaults → global `prefs.toml` → `BACON_PREFS` → workspace
  `Cargo.toml` metadata → project `bacon.toml` → package config → `BACON_CONFIG` → CLI args.
  (Note for cide: bacon's config never requires `~/.config` — repo-local `bacon.toml` +
  `BACON_PREFS`/`BACON_CONFIG` env vars fit the no-home-config constraint perfectly.)
- **Keybindings**: single-key job switching — `c` clippy, `t` test, `d` doc, `f` filter failing
  tests, `Ctrl-J` job list, `Esc` back. Bindings map keys → actions: `job:name`,
  `scroll-lines(n)`, `toggle-summary`, `toggle-wrap`, `toggle-backtrace(level)`, `focus-search`,
  `export:name`. Vim-like binding sets supported in `prefs.toml`.
- **Exports**: the IDE-integration surface. `[exports.locations]` writes `.bacon-locations` with
  templated lines (`{kind} {path}:{line}:{column} {message}`) consumed by nvim-bacon /
  emacs-bacon / **bacon-ls**; a `cargo_json` analyzer can export full diagnostic spans.
- **Remote control**: `listen = true` opens a Unix socket so external processes can command bacon
  (switch jobs, rerun) — i.e., the cide palette can drive bacon without keystroke injection.
- **Succession**: cargo-watch is officially "on life support"; its maintainer recommends bacon
  ("everything I wanted to achieve in Cargo Watch") with watchexec as the maintained generic
  alternative. The jj project switched its contributor docs from cargo-watch to bacon.
- **Runner-up — watchexec CLI** for non-cargo watch loops; **watchexec the library** is the
  embed path (see §4).

### 3.2 Test runner — **default: cargo-nextest** (runner-up: plain `cargo test` / libtest)

- Process-per-test execution model, dramatically faster on multi-core; JetBrains' RustRover blog
  (May 2026) and the Rust Project Primer both treat it as the de-facto modern runner.
- **Retries & flakiness**: `--retries`, fixed/exponential backoff, per-test retry overrides via
  `.config/nextest.toml`; tests that pass on retry are *marked flaky* and listed at the end —
  flakiness is first-class data an IDE can surface.
- **Partitioning/sharding**: new `--partition slice:m/n` distributes tests evenly across shards
  regardless of binary boundaries (deprecating `count:m/n`).
- **Machine-readable output**: `cargo nextest list --message-format json` (stable-ish) and
  experimental `--message-format libtest-json[-plus]` for runs — the data feed for a test-tree
  pane.
- **Build archives**: `cargo nextest archive` / `--archive-file` lets you build once and run
  elsewhere — relevant for worktree-heavy workflows (build in main checkout, run in worktree).
- bacon has a dedicated `nextest` analyzer, so the watch loop and the test runner compose.
- cargo-llvm-cov has a dedicated `nextest` subcommand (see 3.5), so coverage composes too.

### 3.3 Editing intelligence — **default: helix + rust-analyzer** (+ optional bacon-ls offload)

What works in helix (25.01/25.07 era):
- LSP is core: completions, goto, rename, code actions, document colors (25.07), file explorer
  (`space+e`, 25.07), tree-house injection-robust highlighting (25.07), inline diagnostics
  rendering (25.01 UI revamp).
- rust-analyzer itself had a strong 2025: new salsa (incremental crate graph, groundwork for
  parallelism & persistence), large memory/perf wins, ongoing switch from chalk to the rustc-shared
  next-gen trait solver.

What is missing vs VS Code (the honest gap list):
- **Inlay hints**: supported but "laggy/janky under some circumstances"; rust-analyzer inlay-hint
  config options are sometimes ignored (helix #8318).
- **Debugging**: DAP is *experimental, undocumented, clunky* (see 3.10); VS Code + CodeLLDB is
  still the reference debugging experience.
- **No runnables/test-lens UX**: VS Code's "Run test" code lens and Test Explorer have no helix
  equivalent — you leave the editor to run tests (cide's runner pane is exactly this gap).
- **No plugin system yet**: Steel (Scheme) plugin PR #8675 still unmerged as of mid-2025 — no
  ecosystem of editor-embedded panels. Strategic consequence: IDE features must live *beside*
  helix (cide/cmux panes), not inside it. This is cide's moat, not a liability.
- **bacon-ls**: an LSP server that publishes diagnostics from bacon's export file (or runs
  cargo check/clippy JSON itself). Helix-supported since bacon-ls 0.12.0; requires turning off
  rust-analyzer's checkOnSave/diagnostics. Value: on large workspaces, save-triggered cargo check
  runs once (in bacon) instead of twice (bacon + rust-analyzer), and diagnostics stay consistent
  between the runner pane and the editor.

### 3.4 Mutation testing — **default: cargo-mutants** (no credible terminal rival)

- Actively maintained (releases every ~1–2 months as of Aug 2025; v27.x line).
- **`--in-diff git.diff`**: tests only mutants overlapping a diff — composes with `--package`,
  `--regex`; the canonical pre-PR incremental gate (mutants.rs documents the GH Actions pattern).
  Caveat: diff is matched against code under test, not test code.
- Output is console + `mutants.out` files; there is **no review TUI** (gap, §5).

### 3.5 Snapshot testing — **default: insta + cargo-insta** (runner-up: expect-test)

- `cargo insta review` is the gold-standard interactive review loop: a/accept, r/reject, s/skip
  over all pending snapshots.
- Ratatui officially documents insta for TUI snapshot testing (each line = a terminal row) — the
  Rust cide should snapshot its own panes this way.
- The review interaction model (pending artifacts → keyboard triage) is a pattern cide can
  generalize (mutants review, bench-regression review).

### 3.6 Coverage — **default: cargo-llvm-cov** (runner-ups: grcov, tarpaulin)

- taiki-e's cargo subcommand over LLVM source-based coverage; emits HTML
  (`target/llvm-cov/html`), lcov, JSON, Cobertura; `cargo llvm-cov nextest --html` integrates the
  default runner; `--no-report` accumulates runs (e.g., doctests + nextest) before reporting.
- Fully local; lcov.info is the interchange format if cide ever renders gutter coverage.

### 3.7 Supply chain & licensing — **default: cargo-deny** (companions: cargo-audit `bin`, cargo-vet)

- cargo-deny (EmbarkStudios, 0.19.x) = four checks: **advisories** (RustSec DB — subsumes
  cargo-audit), **licenses** (allow/deny lists), **bans** (denied crates + duplicate versions),
  **sources** (trusted registries/git only). `cargo deny init` scaffolds `deny.toml`; each check
  is warn-or-error for incremental adoption.
- cargo-audit remains relevant for one unique trick: `cargo audit bin` scans *compiled binaries*
  (fully accurate when built with cargo-auditable, which zlib-embeds the dep list in a `.dep-v0`
  linker section).
- Zero-egress note: the advisory DB is a git pull from RustSec — cide should treat "advisory DB
  sync" as an explicit, user-visible fetch (gh-CLI-class egress), and runs are offline after.
- cargo-vet (Mozilla lineage) is the audit-attestation alternative; heavier process, runner-up.

### 3.8 Task runner — **default: just** (runner-ups: cargo-make, mask, plain scripts)

- Command runner, not build system; recipes in any language; **modules** (default since 1.31)
  give namespaced recipes for multi-component projects — maps cleanly onto cide verticals
  (`just rust::check`, `just dbt::build`).
- `just --list`/`--summary`/`--dump` (and JSON dump) make recipes *enumerable* — the cide palette
  and runner pane can introspect the justfile and present recipes as first-class actions. Already
  in the owner's stack and in cide's landscape layout (just·notify pane).

### 3.9 Macro inspection — **default: cargo-expand** (runner-up: rust-analyzer "Expand macro" in-editor)

- dtolnay's wrapper over `cargo rustc -- -Zunpretty=expanded` with rustfmt'd output; the standard
  macro x-ray. Lossy/debug-only by design. An IDE affordance: expand current file/item into a
  scratch buffer and difft against the source.

### 3.10 Debugging — **no defensible default exists; assemble: lldb-dap + helix (experimental), rust-lldb pane, tokio-console, probe-rs**

The weakest capability in the entire landscape:
- **helix DAP**: built-in, works for breakpoints/step/locals with lldb-dap (née lldb-vscode), but
  officially *experimental*: undocumented, buggy, "UX is a bit clunky" (helix #505, discussion
  #9269).
- **rust-lldb / rust-gdb**: shipped with Rust; wrappers that pretty-print Rust values; raw CLI UX.
  `gdb -tui` / lldb `gui` mode are primitive. Debugging *of* TUI programs needs a second terminal
  (users.rust-lang.org thread on debugging ratatui apps with rust-gdb).
- **gdbgui**: browser-based gdb frontend — usable via a cmux browser surface, gdb-only (Linux
  bias; lldb is the macOS native).
- **tokio-console**: the async-Rust debugger TUI — live task/resource view, detects stuck/
  self-waking tasks; requires app instrumentation (console-subscriber). The only polished
  debugger-class TUI in the ecosystem.
- **probe-rs / cargo-embed**: embedded ARM/RISC-V/Xtensa flashing + RTT logging + GDB server +
  its own DAP server; *the* embedded story, and proof that a Rust-native DAP server with good CLI
  ergonomics is achievable.
- VS Code + CodeLLDB remains the reference experience — the terminal has no equivalent. (Gap §5.)

### 3.11 Benchmarks — **dual default: divan (inner loop) + criterion (rigor)** 

- **divan** (Nikolai Vazquez): attribute-based registration, parameterization, low overhead,
  sample scaling that reduces CI timing noise; the ergonomic choice for fast local iteration.
- **criterion**: statistics-driven, change detection over time, HTML reports. Maintenance
  history matters: original repo stalled ~4 years, but development moved to the **criterion-rs
  org** with new maintainers (lemmih, berkus) — 0.6.0 May 2025, 0.8.x current. Safe again as the
  rigor option.
- CodSpeed supports both but is SaaS → excluded by zero-egress; local bench-history tracking is a
  gap (§5).

### 3.12 Docs — **default: cargo doc + cargo-docs serve into a cmux browser surface**

- `cargo doc` emits self-contained offline HTML in `target/doc`; `rustup doc --std` for std —
  the whole docs story is already air-gappable.
- **cargo-docs** crate: serves crate docs locally with `--watch` regeneration and can serve the
  Rust book/std too — pairs perfectly with a pinned cmux browser surface (no external browser).
- bacon's `d` job conventionally runs doc + open — precedent for a one-key docs action.

### 3.13 Crate exploration — **default: built-in `cargo info` + crates-tui** (runner-up: cargo-whatfeatures)

- `cargo info <crate>` is now a built-in cargo command (stabilized from cargo-information) —
  version/MSRV-aware metadata at the CLI. Note: queries the registry index → counts as explicit
  egress, same class as `gh`.
- **crates-tui** (ratatui org): full TUI for searching crates.io, copying `cargo add` commands,
  opening docs. Online by nature — in cide it belongs behind the same "explicit network action"
  boundary.
- cargo-whatfeatures lists a crate's feature flags — the most common "what do I enable?" question.

### 3.14 Profiling — **default: samply (with egress caveat) + cargo-flamegraph + hyperfine**

- **samply**: sampling profiler, best-in-class macOS support, opens the Firefox Profiler UI —
  *the profile data is served from localhost but the UI loads from profiler.firefox.com* →
  not air-gapped by default; cide must flag or wrap this (gap §5).
- **cargo-flamegraph**: dtrace-backed on macOS, produces a local SVG — fully zero-egress, render
  in a cmux browser surface.
- **hyperfine** (sharkdp): CLI benchmark harness for whole-command timing — belongs in the runner
  pane vocabulary.

### 3.15 Release/code hygiene — **defaults: cargo-semver-checks, cargo-machete, typos**

- **cargo-semver-checks**: semver-violation linter; lints doubled in 2025 (120 → 242); a Rust
  project goal is merging it into cargo itself. Belongs in the pre-publish ritual for the Rust
  cide and cute-dbt crates.
- cargo-machete (unused dependencies), typos (source-tree spell check) — cheap, fast, CI-proven.

### 3.16 REPL — **default: evcxr** (runner-up: irust)

- evcxr_repl: maintained REPL + Jupyter kernel (0.21.x); RustRover builds its REPL on it —
  validation of the approach. A scratchpad pane candidate for the Rust vertical.

### 3.17 Notable Rust TUI dev-tool ecosystem signals (2025–2026)

- **ratatui** is the de-facto TUI framework (20k+ stars, immediate-mode + diffed rendering) —
  the natural rendering layer for any cide-owned panes.
- awesome-ratatui now lists *agent-orchestration TUIs* — bosun (tmux-native AI coding-agent
  session orchestrator), claudectl (multi-Claude mission control with cost tracking), ygrep
  (Tantivy-indexed code search tuned for AI assistants) — the market is converging on cide's
  thesis (terminal cockpit for agent-augmented dev), but nobody else has a GUI-multiplexer
  substrate like cmux.
- gitu (magit-like), yazi, and the established TUI stack (lazygit, btop, harlequin) round out the
  non-Rust-specific layer cide already composes.

---

## 4. (c) What bacon does that a generic watchexec runner does not — enriching the fast-path decision

The existing decision (bacon fast-path for the Rust vertical) is *strengthened* by this research,
and gains a second leg: watchexec-as-library for everything else.

**What bacon adds over "watch files, re-run command, dump output":**

1. **Analysis, not display.** Bacon consumes `cargo check --message-format
   json-diagnostic-rendered-ansi` via its `cargo_json` analyzer (3.4.0+), then *sorts* the
   result — errors before warnings, earliest errors first — so the actionable item is always at
   the top without scrolling. watchexec can only re-run and stream raw bytes.
2. **A job graph with semantics.** Jobs carry `allow_warnings`, `need_stdout`, `on_success`
   chaining, per-job watch sets and env — and the user flips between them with one key
   (`job:name` actions). A watchexec wrapper would re-implement all of this.
3. **Analyzer plurality.** standard / cargo_json / nextest / eslint / python_unittest /
   python_pytest — bacon already understands *test* output shapes, not just compiler output.
   The "Bacon for everything" roadmap (BURP — Bacon Unified Report Protocol — plus configurable
   line-transformers) is explicitly aimed at becoming the universal background analysis runner.
   Strategic read for cide: bacon may become a viable adapter even for the dbt vertical's
   check loop; BURP is worth tracking as a potential cide-native ingestion format.
4. **Editor/IDE integration surface.** The locations export (`.bacon-locations`, templated
   line format) and span export give *structured, file-addressable diagnostics* that bacon-ls
   turns into LSP diagnostics inside helix. cide's jump system (`cide-jump`) can consume the same
   file directly: failing item → `hx +line file` in the portrait pane. No ANSI scraping.
5. **Remote control.** `listen = true` → Unix socket commands. The cide palette / agent pane can
   switch bacon jobs programmatically. This is the difference between "a pane running a watcher"
   and "an IDE subsystem."
6. **TUI affordances already done**: summary mode, wrap, search, failing-test filter, backtrace
   toggle, scroll anchoring, skins, sound notifications.
7. **Ecosystem blessing**: cargo-watch's own maintainer designates bacon the successor; projects
   (e.g., jj) are migrating contributor docs to it. Defensible default, not a fashion choice.

**What watchexec offers that bacon does not — and why both belong in the architecture:**

- **It is an embeddable library.** The `watchexec` crate (8.x, Tokio-based) is built "for
  utilities and programs which respond to events by launching or managing other programs":
  construct a `Watchexec` around a `Config`, attach handlers, run. Companion crates split the
  domain cleanly: `watchexec-events` (event types, also for tools *running under* watchexec —
  ~53k downloads/month), `watchexec-signals`, `watchexec-supervisor` (process lifecycle), plus
  `notify`/`clearscreen`/`process-wrap` underneath. Bacon is an application with integration
  points; watchexec is a toolkit.
- **Hexagonal mapping for the Rust cide:** define a `WatchRunner` port. Adapters:
  (a) **BaconAdapter** — spawn/attach bacon, read locations export, command via socket
  (Rust vertical fast-path; richest UX for zero build effort);
  (b) **EmbeddedWatchexecAdapter** — in-process watchexec lib + cide-owned analyzers
  (dbt vertical: `dbt build` / sqlfluff / cute-dbt output; BASE vertical: anything);
  (c) **DumbCommandAdapter** — plain re-run for arbitrary commands (today's sh dogfood behavior).
  The bacon fast-path decision stands; the new information is that the *generic* runner should be
  the watchexec library embedded in the Rust binary, not the watchexec CLI shelled out — that
  keeps event filtering, debouncing, and process supervision in-process and testable.
- One caution: watchexec's author self-describes maintenance as "slow but continuing" — but as a
  vendored library dependency (local-first, no service), that risk is acceptable and the
  supervisor/notify layers are independently replaceable.

---

## 5. (d) Gaps no tool covers well — cide's open lanes

1. **Terminal debugging cockpit.** lldb-dap + helix DAP is experimental/undocumented; rust-lldb
   is raw; gdbgui is browser+gdb; nothing terminal-native approaches CodeLLDB. A cide debug
   layout (source pane + lldb-dap-driven control pane + locals/watch pane, orchestrated over
   cmux) would be genuinely novel. probe-rs proves a polished Rust DAP server is feasible.
2. **Test-tree explorer.** nextest emits structured lists (`list --message-format json`) and
   experimental libtest-json run events — no tool renders a live test tree / failing-first triage
   TUI. The runner pane (task #23) can own this: parse events, render tree, jump-to-test.
3. **Coverage in the terminal.** cargo-llvm-cov produces lcov/HTML, but there is no gutter
   rendering in helix and no coverage TUI (uncovered-lines triage). lcov + `cide-jump` is a
   cheap v1; a coverage heat list pane is a v2.
4. **Mutation review UX.** cargo-mutants has `--in-diff` but no interactive review TUI à la
   `cargo insta review`. "Surviving mutants → accept-as-known / write-test / jump-to-site"
   triage is an obvious cide affordance (and pairs with the owner's CRAP/mutation pipeline).
5. **Local bench history.** criterion tracks change-over-time per run dir, divan doesn't persist;
   CodSpeed is SaaS (egress-banned). A local bench-result store + regression diff view (insta-style
   review) is uncovered ground.
6. **Unified quality cockpit.** check/clippy/test/coverage/mutants/deny/semver-checks each have
   output formats but no shared dashboard. bacon's BURP proposal gestures at this; nothing ships
   it. cide's notification feed + runner pane could be the first.
7. **Diagnostics ↔ editor ↔ agent triangle.** bacon-ls solves editor ingestion; nothing feeds
   *agents* structured diagnostics. cide already owns agent surfaces — handing Claude the
   locations export / libtest-json as context (instead of pasted ANSI) is a cheap, differentiating
   win.
8. **Zero-egress profiling.** samply's UI loads profiler.firefox.com (data stays local, UI
   doesn't) — needs an offline-bundled UI or a flamegraph-SVG-first default in cide.
9. **Offline crate intelligence.** crates-tui and `cargo info` hit the network; docs of *vendored*
   deps are local via `cargo doc`. An "explicit egress boundary" UX (like gh) plus
   local-docs-first exploration is unclaimed.
10. **Helix extensibility vacuum (timing window).** Steel plugins unmerged; inlay hints janky; no
    runnables. For the next 1–2 years, "IDE features beside the editor" is the only way to get
    them in a helix workflow — cide's window of differentiation.

---

## 6. Adapter defaults summary table

| Capability (port) | Default adapter | Runner-up(s) | Notes |
|---|---|---|---|
| Watch/check loop | bacon | embedded watchexec lib; watchexec CLI | cargo-watch deprecated |
| Test runner | cargo-nextest | cargo test | nextest analyzer in bacon; llvm-cov subcommand |
| Editor LSP | rust-analyzer in helix | + bacon-ls diagnostics offload | RA: new salsa, next-gen trait solver |
| Snapshot review | cargo-insta | expect-test | also: snapshot-test cide's own TUI panes |
| Coverage | cargo-llvm-cov (nextest mode) | grcov, tarpaulin | lcov = interchange |
| Mutation | cargo-mutants (--in-diff) | — | no review TUI exists |
| Supply chain | cargo-deny | cargo-audit (`bin` mode), cargo-vet | advisory sync = explicit egress |
| Tasks | just (modules) | cargo-make, mask | recipes enumerable for palette |
| Macro expand | cargo-expand | RA expand-macro | |
| Bench | divan (loop) + criterion (rigor) | hyperfine (commands) | criterion revived under criterion-rs org |
| Docs | cargo doc + cargo-docs serve | rustup doc | render in cmux browser surface |
| Crate explore | cargo info (built-in) | crates-tui, cargo-whatfeatures | network = explicit action |
| Debug | lldb-dap (helix experimental) | rust-lldb pane, gdbgui, tokio-console, probe-rs | weakest capability |
| Profiling | cargo-flamegraph (offline) | samply (egress caveat) | |
| Hygiene | cargo-semver-checks, cargo-machete, typos | — | pre-publish ritual |
| REPL | evcxr | irust | |

---

## Sources

### bacon / watch loops
- https://github.com/Canop/bacon — bacon repo
- https://dystroy.org/bacon/ — bacon overview (jobs, keybinds, philosophy)
- https://dystroy.org/bacon/config/ — job properties, analyzers, exports, keybindings, socket `listen`
- https://dystroy.org/blog/bacon-everything-roadmap/ — "Bacon for everything": analyzers (eslint, python_unittest, python_pytest, cargo_json, nextest), BURP protocol
- https://github.com/watchexec/cargo-watch — cargo-watch "on life support", recommends bacon/watchexec
- https://github.com/jj-vcs/jj/pull/5310 — jj contributor docs: recommend bacon over cargo-watch
- https://terminaltrove.com/bacon/ — bacon on Terminal Trove
- https://github.com/crisidev/bacon-ls — bacon-ls LSP server (helix support since 0.12.0; cargo vs bacon backends)

### watchexec library
- https://docs.rs/watchexec/latest/watchexec/index.html — embeddable, Tokio-based; Config + handlers
- https://crates.io/crates/watchexec — lib crate
- https://crates.io/crates/watchexec-events — event types for tools running under watchexec (~53k dl/mo)
- https://github.com/watchexec/watchexec — CLI + workspace (events/signals/supervisor crates)

### nextest
- https://nexte.st/docs/features/retries/ — retries, flaky marking, backoff, per-test overrides
- https://nexte.st/changelog/ — `--partition slice:m/n`, failing/flaky summary output
- https://nexte.st/docs/machine-readable/ and https://nexte.st/docs/machine-readable/libtest-json/ — JSON output
- https://nexte.st/docs/ci-features/archiving/ — build archives / --archive-file
- https://blog.jetbrains.com/rust/2026/05/01/faster-rust-tests-with-cargo-nextest/ — RustRover on nextest
- https://nexte.st/docs/integrations/test-coverage/ — llvm-cov integration

### helix + rust-analyzer
- https://helix-editor.com/news/release-25-07-highlights/ — tree-house, file explorer, color swatches
- https://helix-editor.com/news/release-25-01-highlights/ — UI revamp, path completion
- https://github.com/helix-editor/helix/issues/8318 — inlay-hint config ignored
- https://github.com/helix-editor/helix/issues/505 and https://github.com/helix-editor/helix/discussions/9269 — DAP experimental/undocumented/clunky
- https://github.com/helix-editor/helix/issues/9964 — lldb-vscode → lldb-dap rename
- https://app.semanticdiff.com/gh/helix-editor/helix/pull/8675/overview — Steel plugin PR (unmerged)
- https://felix-knorr.net/posts/2025-03-16-helix-review.html — helix 1.5-year review
- https://rust-analyzer.github.io/thisweek/2025/03/17/changelog-277.html — new salsa upgrade
- https://rust-analyzer.github.io/thisweek/2025/12/01/changelog-304.html — solver-type GC perf, next trait solver work
- https://rust-analyzer.github.io/book/other_editors.html — RA editor matrix

### quality stack
- https://mutants.rs/in-diff.html and https://mutants.rs/pr-diff.html — cargo-mutants --in-diff CI pattern
- https://github.com/sourcefrog/cargo-mutants — maintenance cadence
- https://insta.rs/docs/cli/ — cargo insta review (a/r/s)
- https://ratatui.rs/recipes/testing/snapshots/ — insta for TUI snapshot testing
- https://github.com/taiki-e/cargo-llvm-cov — nextest subcommand, HTML/lcov/JSON/Cobertura, --no-report
- https://github.com/EmbarkStudios/cargo-deny — advisories/licenses/bans/sources; deny.toml; subsumes cargo-audit
- https://rustprojectprimer.com/checks/audit.html — cargo-audit vs cargo-deny vs cargo-vet
- https://github.com/rustsec/rustsec/blob/main/cargo-audit/README.md — `cargo audit bin`
- https://github.com/rust-secure-code/cargo-auditable — .dep-v0 embedded dep lists
- https://github.com/obi1kenobi/cargo-semver-checks and https://rust-lang.github.io/rust-project-goals/2026/cargo-semver-checks.html — 242 lints; cargo-merge goal

### tasks, macros, bench, docs, crates, REPL
- https://just.systems/man/en/ and https://github.com/casey/just — just manual/repo
- https://www.stuartellis.name/articles/just-task-runner/ — modules guidance (default since 1.31)
- https://github.com/dtolnay/cargo-expand — cargo-expand (lossy, debugging aid)
- https://nikolaivazquez.com/blog/divan/ — divan design
- https://github.com/criterion-rs/criterion.rs and https://docs.rs/crate/criterion/latest — criterion revival under criterion-rs org
- https://codspeed.io/changelog/2025-02-13-divan-support — CodSpeed divan support (SaaS — excluded)
- https://doc.rust-lang.org/cargo/commands/cargo-doc.html — cargo doc
- https://crates.io/crates/cargo-docs — local docs server with --watch
- https://doc.rust-lang.org/nightly/cargo/commands/cargo-info.html — built-in cargo info
- https://github.com/ratatui/crates-tui — crates.io TUI
- https://crates.io/crates/cargo-whatfeatures — feature listing
- https://github.com/evcxr/evcxr and https://www.jetbrains.com/help/rust/rust-repl.html — evcxr REPL; RustRover builds on it

### debugging & profiling
- https://rust-training.ferrous-systems.com/latest/book/debugging-rust — rust-gdb/rust-lldb
- https://users.rust-lang.org/t/debugging-tui-programs-with-rust-gdb/132139 — debugging TUI apps
- https://www.gdbgui.com/guides/ — gdbgui
- https://probe.rs/ and https://probe.rs/docs/tools/cargo-embed/ — probe-rs, cargo-embed, RTT, DAP server
- https://github.com/tokio-rs/console — tokio-console async debugger TUI
- https://nnethercote.github.io/perf-book/profiling.html — profiling overview (samply, flamegraph)
- https://ntietz.com/blog/profiling-rust-programs-the-easy-way/ — samply workflow (Firefox Profiler UI)
- https://github.com/flamegraph-rs/flamegraph — cargo-flamegraph (dtrace on macOS)

### ecosystem signals
- https://github.com/ratatui/awesome-ratatui — bosun, claudectl, ygrep, gitu, yazi listings
- https://github.com/ratatui/ratatui — ratatui (de-facto TUI framework)

### local context
- /Users/cmbays/github/cmux-workspace-dbt/cide.toml — cide dogfood config (IDE instance, layouts, agent surfaces)
- /Users/cmbays/github/cmux-workspace-dbt/bin/ — cide-* command set (cide-jump, cide-agent, cide-space, …)
- /Users/cmbays/github/cmux-workspace-dbt/docs/vision/research/cute-dbt-capabilities.md — sibling research note (dbt vertical)
