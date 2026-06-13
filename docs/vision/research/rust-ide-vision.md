# cide RUST DEV IDE — vertical vision

> Vision draft for task #33, layered on `base-vision-synthesis.md` (Draft C spine,
> all grafts integrated). Inputs: `rust-landscape.md`, `opportunity-backlog.md`
> (#1, #3, #8, #9, #15 + honorable mentions), `prior-decisions.md` (runner shape,
> Rule of Two, compose-on-cmux, egress ladder), `agent-native-landscape.md`.
> Date: 2026-06-09. Honors every settled decision; engages only the deliberately-open
> questions. The rust-dev vertical is **the Rule-of-Two validator**: when bacon,
> nextest, and cargo-mutants plug into the same runner/status/review machinery dbt
> uses, the type seams are proven and the type registry crystallizes (settled trigger).

---

## 1. Thesis — the vertical in one paragraph

The 2025–26 Rust terminal ecosystem already built every IDE organ — bacon parses and
sorts diagnostics, nextest runs tests with retries and machine-readable output, insta
reviews snapshots interactively, cargo-mutants gates diffs, cargo-llvm-cov measures,
just enumerates tasks — but shipped them as disconnected single-purpose binaries with
no shared cockpit, no shared status surface, and **no agent feed**. Meanwhile helix,
the editor this user already lives in, structurally *cannot* grow IDE panels (Steel
unmerged, DAP experimental, no runnables) for at least the next 1–2 years. The Rust
cide vertical is the connective tissue: `rust-dev = base ⊕ {bacon fast-path runner,
nextest catalog + test-tree, quality-gate jobs (mutants/coverage/insta/deny) as Dock
controls, just modules, docs surfaces, structured-diagnostics→agent routing}` — a
recipe over the same hexagonal core and the same cmux rails (Dock, Palette, Feed,
diff viewer, browser surfaces) the dbt vertical rides. Nothing about your hands
changes; only the recipe does. And because cide itself is a Rust program, this
vertical is the compounding dogfood: **cide is built inside cide**, and the resident
agent that builds it watches the same bacon/nextest feed its human does.

---

## 2. Persona — the quality-gate-driven, agent-heavy Rust dev

**Primary: Christopher building cide and cute-dbt** (the demand proof — same person,
every day). Generalized profile:

- **Terminal-sovereign.** helix (will not defect to VS Code/Zed), yazi, lazygit,
  btop, just, gh; muscle memory is the asset being protected. Wants rust-analyzer's
  intelligence but refuses an Electron shell to get a test explorer.
- **Agent-heavy.** Runs Claude Code resident in the workspace most of the day; the
  human writes the load-bearing abstractions and reviews everything, the agent does
  volume work. Reviews dozens of agent turns daily. Parallel exploration via
  worktrees is already the discipline.
- **Quality-gate-driven.** Quality is enforced mechanically, not aspirationally: TDD
  then mutation testing (cargo-mutants `--in-diff` as a pre-PR ritual), coverage
  (cargo-llvm-cov), snapshot tests (insta — including ratatui pane snapshots of cide
  itself), CRAP-score discipline, cargo-deny/semver-checks in the pre-publish ritual.
  The exclusions rule ("every skip carries a tracking issue") is personality, not
  policy. Red is a routing event, not a vibe.
- **Zero-egress by conviction.** Air-gappable toolchain; the only network is `gh`
  and explicit, labeled registry actions (`cargo info`, advisory-DB sync). Will not
  run CodSpeed-class SaaS; *will* run criterion locally forever.
- **Solo-founder economics.** One laptop, many spaces (a six-space fleet is normal);
  cares about hibernation budgets and RAM the way a team lead cares about headcount.

Secondary personas the same recipe serves with zero extra design: the employer
colleague (neovim, one-line `cide.toml` swap, conformance-suite-insured), and the
air-gapped-org Rust dev for whom the egress contract is the purchase reason.

What this persona does **not** want: a custom editor, an LSP host, a re-rendered
diff, autonomy maximalism, or any feature that exists to demo rather than to shorten
the red→green→reviewed loop.

---

## 3. A day in the life — the Rust afternoon, expanded to a full day

*(The base vision's 13:00 beat, promoted to the whole day. Same chords as the dbt
morning; that symmetry is the product.)*

**08:50 — open.** Sessionizer chord → television channel → `cide-core-events`, the
worktree space for the event-reactor slice, closed yesterday mid-refactor. Sub-ten
seconds later: helix portrait reopens `reactor.rs` at the same spot; yazi + agent
landscape; the runner Dock tile is live with bacon already on the `clippy` job;
status pills read `clippy ✓ · nextest 1 failing` — yesterday's red survived the
close because runner state is space state (P1). The sidebar group is rust-red.
`builder` resumes mid-conversation (`claude --resume`); the prompt reads
`agents: 0▶ 0✋ 1💤`, plus one unreviewed turn from yesterday. `cide review`: the
turn's diff renders beside the agent pane — a trait extraction, right shape, wrong
module. One-line comment lands via `cmux send`. Zero reconstruction.

**09:10 — the inner loop.** He writes a failing test first (the persona's reflex).
Save → bacon's nextest job re-runs scoped to the failing test; the Dock pill flips
red with `1F` and the failing item is the *top line* of the runner pane — bacon
sorted it there, no scrolling. The fix-on-red chord is deliberately *not* fired;
this one is his. `ctrl+a j` jumps from the failing diagnostic to `hx +217
src/reactor.rs` via `.bacon-locations` — no ANSI scraping, no mouse. Green. Bacon's
`on_success` chains clippy; still green; the pill goes quiet.

**10:30 — agent takes the volume work.** The port trait is settled, so the
remaining adapters are mechanical. He prompts builder; builder works; **the runner
red routes to the agent now** — a save goes red in a module builder owns, and the
fix-on-red hook hands builder the structured failure: `.bacon-locations` lines plus
the nextest libtest-json record for the failing test, never pasted terminal output.
A Feed card asks to edit two files; one keystroke approves. The fix arrives as a
queued diff three minutes later. He reviews it between his own edits — the policy
hook kept it silent while the editor was focused (P3).

**12:40 — snapshot review as a pane, not a chore.** The reactor change altered
cide's own TUI panes; insta has six pending snapshots. Palette: `rust: review
snapshots` → `cargo insta review` opens in the review slot — a/accept, r/reject —
the same keyboard-triage muscle as the agent diff queue. Two rejects route straight
back to builder as a prompt with the snapshot diff paths attached.

**15:00 — the pre-PR ritual is one verb.** `rust: gate my branch` runs the quality
ladder as runner jobs: `cargo llvm-cov nextest` (lcov + HTML to a browser surface),
then `cargo-mutants --in-diff` against merge-base. Progress bars live in the Dock
(`set-progress`); he keeps coding. Eleven minutes later the Feed posts: `coverage
91.4% (+0.8) · 3 mutants survived`. The survivors land in a triage list — each one
jump-to-site, write-test, or accept-with-issue (the exclusions rule, mechanized).
He hands two survivors to builder with their mutant diffs; the third is a genuine
design hole he takes himself.

**16:30 — docs and ship.** A doc-comment pass; `rust: docs` serves `cargo doc` into
a pinned browser surface (file://, offline, themed via addstyle); he proofreads the
rendered trait docs beside the source. `cide review` shows zero unreviewed turns.
Merge-back journey: `cmux diff --source branch` for the whole-branch read,
`cargo-semver-checks` + `cargo-deny` (offline, against the synced advisory DB) as
the last gate, `gh pr create` — the day's only egress.

**18:00 — close.** `cide space close` snapshots builder's checkpoint, stamps the
runner's bacon job + failing-test filter as surface-resume state, releases the
windows. Tomorrow the red test he left on purpose will still be the top line.

---

## 4. How each base pillar instantiates for Rust

**P1 — The space is the unit of work.** A rust space stamps *runner semantics*, not
just geometry: active bacon job (`clippy` vs `nextest`), failing-test filter,
last-failed selection, the branch's mutation/coverage baselines under
`.cide/rust/`, and the agent checkpoints. nextest **build archives** make
worktree-per-agent spaces cheap on the Rust side — build once in the main checkout,
run in the worktree — so "fork an exploration space" doesn't mean "recompile the
world." Reopening resumes the *investigation*, not just the panes.

**P2 — Review is the primary loop.** Rust multiplies the reviewable artifact types,
and they all flow through the one queue muscle: agent-turn diffs (`cmux diff
--source last-turn`), insta snapshot review (`cargo insta review` is already the
gold-standard accept/reject loop — cide adopts its interaction model rather than
inventing one), surviving-mutant triage (the same a/r/s pattern applied to
`mutants.out`, a TUI nothing in the ecosystem ships today), and `gh pr diff` in the
same diff surface. One review verb, four artifact kinds.

**P3 — Attention engineering.** Bacon already solves micro-attention (errors before
warnings, earliest first, top of pane); cide's policy hook solves macro-attention:
warnings-only stays a quiet pill, test-red flashes the runner pane, mutation/
coverage completions post Feed cards instead of interrupting, and long gates
(`--in-diff` runs, full coverage) report via `set-progress` so "is it done" never
requires a pane visit. The fleet segment and hibernation budgets matter doubly here
because cargo builds are the RAM/CPU spike that makes governor-less fleets fall over.

**P4 — Closed loops, human ON the loop.** The rust instantiation is the richest in
the product because the diagnostics are *already structured at the source*: bacon's
locations export and cargo's JSON diagnostics for check/clippy, nextest's
libtest-json for tests, `mutants.out` for survivors, lcov for uncovered lines.
Fix-on-red attaches `.bacon-locations` (settled in the base vision); fix-on-mutant
and cover-this-line are the same loop with a different attachment. Every loop
terminates in a Feed approval.

**P5 — Agents are users of the IDE too.** The agent reads the same structured feeds
(§6) and drives the same verbs — switch bacon jobs via the socket, re-run failed,
open the coverage report — through `--json` contracts. In the Rust vertical this
pillar is self-referential: the agent building cide uses cide's verbs to build them.

**P6 — One tool, budgeted latency, keystroke-complete.** Single-key bacon job
switching (`c`/`t`/`d`) is the vertical's native which-key and cide must not bury
it — chords *wrap* bacon's keys (and drive them remotely via its Unix socket), never
replace them. Per-vertical tab-bar buttons: bacon job switch, re-run failed, review
snapshots. The `focus` fan-out instantiates as: pick a symbol/test → helix opens
it, the runner filters to it, the docs surface navigates to it. Rust = red on the
native workspace group.

**P7 — Verticals are recipes; rust-dev is the validator.** The recipe is data:
`rust = base ⊕ {runner(bacon fast-path), test(nextest catalog), quality jobs
(mutants/llvm-cov/insta/deny/semver-checks), just rust::* modules, docs(browser
surface), rust routing + red identity}`. The proof obligation this vertical
carries: bacon, nextest, and cargo-mutants must plug into the **same** runner/
status/review ports the dbt vertical's dbt-build/sqlfluff/cute-dbt jobs use, with
zero new machinery — only new adapters and catalog entries. If that holds, the type
registry crystallizes; if it doesn't, the seams were wrong and we learn it on
vertical #2, not #5. Every adapter in the recipe carries an egress label; the rust
vertical is almost entirely `zero`, with three explicitly-labeled exceptions
(advisory-DB sync, `cargo info`/crates-tui registry queries, samply's remote UI —
the last avoided by defaulting to flamegraph SVGs).

---

## 5. Rust-specific surfaces

### 5.1 The bacon fast-path pane (settled; this is the runner's richest instantiation)

The settled runner decision — watchexec engine + pluggable catalog, **bacon as the
fast-path for cargo repos** — is strengthened by the landscape research. What the
fast-path means concretely:

- cide detects cargo, spawns/attaches **bacon as a managed adapter** (the
  `BaconAdapter` behind the `WatchRunner` port) instead of the embedded watchexec
  engine. Repo-local `bacon.toml` + `BACON_PREFS`/`BACON_CONFIG` env satisfy the
  no-`~/.config` constraint natively — bacon was practically designed for cide's
  config posture.
- **Analysis, not display**: bacon consumes cargo's JSON diagnostics and sorts —
  errors first, earliest first. cide gets a parsed, prioritized failure model for
  free where the generic engine would re-implement it.
- **The locations export is the integration spine**: `.bacon-locations`
  (`{kind} {path}:{line}:{column} {message}`) feeds `cide-jump` (failing item →
  `hx +line` in the portrait pane), the fix-on-red attachment, and optionally
  bacon-ls (§5.3). No ANSI scraping anywhere in the vertical.
- **Remote control via `listen = true`**: palette actions and the agent switch
  bacon jobs / trigger reruns over its Unix socket — programmatic drive, not
  keystroke injection (honors "proper control channels, never blind keystrokes").
- **Job graph as catalog entries**: bacon jobs (check/clippy/nextest/doc, with
  `on_success` chaining, per-job watch sets, `allow_warnings`) *are* the rust
  catalog's watch-mode entries; the cide catalog adds the non-watch jobs bacon
  doesn't own (mutants, coverage, deny — §5.4).
- Dock placement per the settled compose-on-cmux posture: the runner lives in the
  Dock (default-home question still open, per prior-decisions §19), registered as
  palette actions, notifying through the Feed.
- Strategic watch item: bacon's "everything" roadmap (BURP protocol, eslint/pytest
  analyzers) could make BaconAdapter viable for *other* verticals' check loops;
  track BURP as a potential cide-native ingestion format, don't bet on it yet.

### 5.2 cargo-nextest in the runner catalog (+ the test-tree lane)

nextest is the uncontested default runner and the catalog's deepest entry:

- **Catalog entries**: `test` (bacon's nextest analyzer in watch mode), `test:
  failed` (re-run last failures), `test: filtered <expr>`, `gate: coverage`
  (`cargo llvm-cov nextest`). Retries/backoff via repo-local `.config/nextest.toml`.
- **Flakiness is first-class data**: tests that pass on retry are *marked flaky* —
  cide surfaces them as a status pill and a Feed digest instead of letting them
  hide in green. A flaky-list that persists per space is cheap and nothing else
  ships it.
- **Machine-readable feed**: `nextest list --message-format json` + experimental
  libtest-json run events are the data for the **test-tree explorer pane** —
  live failing-first triage, rerun-failed, jump-to-test. This is backlog #15(a),
  the loudest VS-Code-gap (Test Explorer) and an empty lane in the entire terminal
  ecosystem. Phased: v1 = failing-first list + jump (rides the runner parser);
  v2 = full tree TUI (ratatui, snapshot-tested with insta, naturally).
- **Build archives** (`cargo nextest archive`) wire into worktree-per-agent spaces:
  the sessionizer's "new exploration space" can seed the worktree with the main
  checkout's archive — fleet-cheap testing.

### 5.3 rust-analyzer in helix — the story and its honest limits

The editing core is **helix + rust-analyzer, sovereign and untouched** (cide never
hosts an LSP — non-goal). The story has three parts:

1. **What's strong**: completions, goto, rename, code actions, inline diagnostics;
   rust-analyzer's 2025 salsa rewrite and trait-solver work keep the core
   improving without cide lifting a finger.
2. **The honest limits (which are cide's moat, not its liability)**: inlay hints
   janky (helix #8318); DAP experimental/undocumented; **no runnables/test-lens —
   you leave the editor to run tests**; **no plugin system** (Steel unmerged) so
   IDE panels cannot live inside helix for the foreseeable window. Every limit on
   this list is a pane cide already owns: the runner pane *is* the missing
   test-lens; the test-tree *is* the missing Test Explorer; the quality cockpit
   *is* the missing diagnostics panel. cide's bet is to build beside the editor in
   exactly the 1–2-year window where beside is the only option — and to still be
   the better answer after, because panes compose with agents and helix plugins
   won't.
3. **The bacon-ls option (config-as-choice, off by default)**: on large workspaces,
   offload save-triggered diagnostics to bacon via bacon-ls so cargo check runs
   once, not twice (bacon + rust-analyzer's checkOnSave), and the editor's
   squiggles agree with the runner pane. It requires disabling rust-analyzer's
   own checkOnSave — a real trade (slower in-editor freshness on small repos) —
   so it ships as a documented recipe toggle, not the default. Verify-with-spike
   before shipping (working agreement: version-drifty tool facts get confirmed at
   build time).

Editor-open remains keystroke-injection (helix has no remote-open socket) — a
known fragile adapter constraint, owned and documented, not designed around.

### 5.4 Quality gates as runner jobs + Dock controls

The persona's pipeline, mechanized as catalog entries with Dock/Feed surfaces —
this is backlog #15(c)/(d) phased onto the runner rails:

- **`gate: mutants`** — `cargo-mutants --in-diff <merge-base diff>` (the canonical
  incremental pre-PR gate; composes with `--package`/`--regex`). Long-running →
  `set-progress` bar in the Dock, completion → Feed card with survivor count.
  **Survivor triage** is the genuinely novel surface: cargo-mutants has *no*
  review TUI anywhere — cide applies the insta a/r/s interaction model to
  `mutants.out`: jump-to-site / write-test (optionally: hand to agent with the
  mutant diff) / accept-with-tracking-issue (the exclusions rule as a verb).
- **`gate: coverage`** — `cargo llvm-cov nextest --html` + lcov. HTML report in a
  themed browser surface; lcov feeds an uncovered-lines triage list through
  `cide-jump` (v1); gutter rendering stays out of scope (helix can't; cide won't
  fake it). `--no-report` accumulation lets doctests + nextest combine.
- **`gate: snapshots`** — `cargo insta review` in the review slot; pending-count
  as a status pill. cide's own panes are insta-snapshot-tested (ratatui's
  documented pattern), so this surface reviews the IDE's own face — dogfood
  squared.
- **`gate: supply-chain`** — `cargo-deny check` (advisories/licenses/bans/
  sources), offline after an explicit, labeled advisory-DB sync (the egress
  ladder's defensible-opt-in class, same UX as `gh`). `cargo audit bin` available
  for binary verification of cide's own releases (pairs with cargo-auditable).
- **`gate: release`** — cargo-semver-checks + cargo-machete + typos as the
  pre-publish ritual entry (cide and cute-dbt both publish to crates.io; this
  ritual is already lived practice, now one verb).
- **Dock controls**: each gate is a Dock tile action + palette verb + chord; pills
  carry the latest result (`cov 91% · mut 3⚠ · snap 0 · deny ✓`); the unified
  pill row is the v1 of the "quality cockpit" — the shared dashboard nothing in
  the ecosystem ships (rust-landscape gap #6) at near-zero UI cost on cmux's
  status API.

### 5.5 just recipes

just is the cross-vertical task lingua franca; the rust instantiation leans on
**modules** (`just rust::check`, `just rust::gate`, mirroring `just dbt::build`) so
one justfile serves a polyglot repo with namespaced, *enumerable* recipes —
`just --dump --dump-format json` feeds the palette and runner catalog so every
recipe is a discoverable action, not tribal knowledge. Catalog precedence stays
the settled one: detection (just/make/npm/cargo) with `[runner]` cide.toml
override. just recipes are also the escape hatch: anything the catalog doesn't
model natively (xtask patterns, embedded flashing via cargo-embed) is one recipe
away from being a palette verb with Feed notification.

### 5.6 Docs surfaces

Fully offline, browser-surface-native:

- `cargo doc` → `target/doc` rendered in a pinned cmux browser surface at
  `file://`, themed via addstyle; **cargo-docs serve `--watch`** upgrades it to
  live-regenerating docs beside the code (the docs analog of the runner).
- `rustup doc --std` for the standard library — air-gapped std reference.
- Crate exploration: `cargo info` / crates-tui behind the **explicit-egress
  boundary** (labeled action, same class as `gh`); local-docs-first is the
  default posture (vendored deps' docs are local via `cargo doc`).
- `cargo expand` as the macro x-ray: expand item/file → scratch buffer →
  difftastic lens against source (the structural-diff adapter earning a second
  use). A palette verb, not a pane.
- evcxr as the optional scratchpad surface (config-as-choice; RustRover validates
  the approach).

### 5.7 Explicitly phased out of v1 (named so they're not re-litigated)

- **Terminal debugging cockpit** — the ecosystem's biggest hole (helix DAP
  experimental, rust-lldb raw), but L-effort against an unstable substrate;
  revisit after runner + cockpit land (backlog honorable mention). tokio-console
  ships earlier as a plain catalog entry for async work — it's just a TUI pane.
- **Local bench history** (divan inner loop + criterion rigor are catalog entries
  from day one; the *persisted regression store* with insta-style review waits).
- **Gutter coverage in helix** — structurally blocked; the lcov triage list is
  the honest version.

---

## 6. The agent angle — the agent watches the same feed you do

This is the vertical where P4/P5 stop being architecture and become a daily loop,
because Rust's toolchain emits **structured, file-addressable diagnostics at every
layer** — the agent never parses a screen:

- **Fix-on-red, rust flavor** (backlog #9, S-effort on runner+reactor): runner red
  → the hook routes to the space's builder agent a structured prompt containing
  `.bacon-locations` lines (check/clippy) or the libtest-json record + failing
  test name (nextest), plus the working-tree diff context. The agent's fix lands
  in the review queue; approval stays in the Feed. Human ON the loop.
- **Fix-on-mutant / cover-this-line**: the same loop with `mutants.out` survivor
  diffs or lcov uncovered spans as the attachment — quality-gate remediation as a
  routed conversation, which no tool on any platform does today (rust-landscape
  gap #7: "nothing feeds *agents* structured diagnostics").
- **The agent drives the cockpit**: via `--json` verbs and bacon's socket, the
  resident agent can switch the bacon job, re-run failures, run the coverage
  gate, and read pill state — the same registry as the human (P5). The repo-local
  agent skill documents the contract.
- **The dogfooding flywheel — cide is built inside cide.** cide is a Rust program
  developed in a rust-dev cide space; its builder agent consumes bacon/nextest
  feeds *through cide* to fix cide. Every rough edge in the diagnostics→agent
  triangle is felt by the founder within hours, on the highest-frequency workload
  he has. The dbt vertical proves the recipe mechanism; the rust vertical proves
  it *while compounding* — improvements to the loop accelerate building the loop.
  (And the TUI panes the vertical adds are insta-snapshot-tested, reviewed in the
  vertical's own snapshot surface.)
- **Boundaries hold**: cide routes diagnostics and queues diffs; it never
  auto-applies, never merges, never proxies the model (non-goals). The Feed is
  the escape hatch on every loop.

---

## 7. Defensible default toolset (with runner-up swaps)

Per the config-as-choice pattern: opinionated default, 2–3 vetted swaps, every
adapter egress-labeled, every override one line of `cide.toml`.

| Port / concern | Default | Runner-up(s) | Egress | Notes |
|---|---|---|---|---|
| Watch/check loop | **bacon** (fast-path adapter) | embedded watchexec lib; dumb re-run | zero | Settled. cargo-watch deprecated upstream; bacon socket = control channel |
| Test runner | **cargo-nextest** | `cargo test` | zero | Retries/flaky data, libtest-json, build archives |
| Editor intelligence | **rust-analyzer in helix** | + bacon-ls offload (opt-in toggle) | zero | cide never hosts LSP; bacon-ls = large-workspace dedupe |
| Snapshot review | **cargo-insta** | expect-test | zero | Interaction model generalized to mutant triage |
| Coverage | **cargo-llvm-cov** (nextest mode) | tarpaulin, grcov | zero | lcov = interchange; HTML → browser surface |
| Mutation | **cargo-mutants** `--in-diff` | — (no credible rival) | zero | cide adds the missing review TUI |
| Supply chain | **cargo-deny** | cargo-audit (`bin` mode), cargo-vet | defensible (DB sync only) | Offline after explicit sync; sync = labeled action |
| Task catalog | **just** (modules) | cargo-make, mask | zero | `--dump` JSON feeds palette |
| Macro x-ray | **cargo-expand** | rust-analyzer expand-macro | zero | + difftastic lens |
| Bench | **divan** (loop) + **criterion** (rigor) | hyperfine (commands) | zero | CodSpeed rejected (SaaS); history store deferred |
| Docs | **cargo doc + cargo-docs serve** | rustup doc | zero | Browser surface, addstyle-themed |
| Crate explore | **cargo info** | crates-tui, cargo-whatfeatures | defensible (registry) | Explicit-egress boundary, local-docs-first |
| Profiling | **cargo-flamegraph** (SVG) | samply | zero / **caveat** | samply's UI loads profiler.firefox.com → flagged, non-default |
| Release hygiene | **cargo-semver-checks + cargo-machete + typos** | — | zero | The pre-publish ritual verb |
| Async debugging | **tokio-console** | — | zero | Catalog entry; full debug cockpit deferred |
| REPL/scratch | **evcxr** (optional) | irust | zero | Config-as-choice surface |
| Debugger | *(deferred)* lldb-dap via helix, experimental | rust-lldb pane, gdbgui | zero | Honest gap; not a v1 promise |

Defensibility test applied throughout: the default is what the persona would pick
unprompted after the landscape read (bacon over raw watchexec for cargo repos;
nextest over libtest; llvm-cov over tarpaulin on macOS-arm), and each runner-up is
a real adapter slot, not decoration — the swap contract (one line, conformance-
suite-insured) is what makes the strong default safe to ship.

---

## 8. Open questions

Engaging only what `prior-decisions.md` §19 leaves open, plus what this vertical
newly surfaces:

1. **Runner default home, rust flavor** (open in #23): Dock tile vs layout pane —
   the rust answer may differ from dbt's because bacon is a *rich TUI* worth
   screen real estate, not just a status producer. Does the fast-path get a
   layout tile while generic watch jobs live in the Dock?
2. **Bacon-attach vs bacon-own**: when a repo already runs bacon (its own
   `bacon.toml`, user-started), does cide attach to the existing socket or always
   manage its own instance? Attach is respectful; own is deterministic. Needs a
   spike on socket discovery + multi-client behavior.
3. **bacon-ls default posture**: opt-in toggle (proposed here) or
   auto-recommended above a workspace-size threshold? Requires the spike (helix
   config interplay with rust-analyzer checkOnSave; version drift risk noted).
4. **libtest-json instability**: the nextest run-event format is experimental.
   Does the test-tree v1 parse it behind a version pin + golden fixtures, or wait
   for stabilization and ship failing-first-list-only? (Fixture-provenance rule
   applies either way: captured from real nextest runs.)
5. **Where mutant/coverage baselines live**: `.cide/rust/` per-space vs per-branch
   keying, and whether the mutation gate's merge-base derives from the worktree's
   branch point or a configured trunk — interacts with the worktree-per-agent
   sessionizer.
6. **Survivor-triage "accept" semantics**: accepting a surviving mutant should
   create a tracking issue per the exclusions rule — does cide call `gh issue
   create` (defensible egress, opt-in) or write a local TODO ledger the user
   flushes? The zero-egress base must work air-gapped.
7. **How much bacon config cide owns**: ship a cide-managed `bacon.toml` overlay
   (consistent jobs across repos, `BACON_CONFIG`-pointed) vs respect repo-local
   files and only add missing jobs? Same seed→state question the theme system
   answered once already.
8. **Quality-cockpit pill budget**: how many gates fit the status line before P3
   (attention engineering) says stop — and does the unified cockpit pane (gap #6)
   arrive in v1.5 or wait for BURP-style ingestion to mature?
9. **Rule-of-Two exit criteria, made explicit**: what concretely must be true for
   the rust vertical to "validate the type seams" — proposed: bacon + nextest +
   mutants run through the same `WatchRunner`/status/review ports as dbt's jobs
   with recipe-only (data-only) differences, zero rust-specific branches in
   cide-core. Worth writing down as the acceptance test before building.
10. **Agent attachment size discipline**: full `.bacon-locations` + libtest-json
    can be large on bad days; does fix-on-red truncate, summarize, or hand file
    paths for the agent to read itself (machine-verb pull vs push)? Interacts
    with P5's `--json` contract design.

---

## 9. Cross-references

- `base-vision-synthesis.md` — pillars P1–P7, ranked bets (this vertical rides
  bets 7, 8, and the #15 ladder), non-goals honored throughout.
- `rust-landscape.md` — every tool claim and gap cited here, with source URLs.
- `opportunity-backlog.md` — #1 (runner), #3 (reactor), #8 (worktree spaces),
  #9 (fix-on-red), #15 (rust quality cockpit, phased), honorable mentions
  (debug cockpit, bench history).
- `prior-decisions.md` — runner shape (§3), compose-on-cmux (§4), egress ladder
  (§13), Rule of Two (§1), working agreements (§17), deliberately-open list (§19).
- `agent-native-landscape.md` — fix-on-red pattern (C.5), review queue (C.4),
  what-not-to-build (D).
