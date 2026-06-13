# ctide Migration Backbone — the Program Skeleton (R0–R5)

> **Purpose.** This is the normalized *spine* for the ctide master roadmap: every
> migration phase as a self-contained work unit with goal, deliverables, hard
> dependencies, testable exit criteria, the design-plan grafts (g1–g7) it lands,
> and the risk-register items it retires or exposes. It also names the **walking
> skeleton** — the smallest end-to-end slice that proves the architecture.
>
> **Provenance.** Extracted from the approved design (merged PR #23):
> [docs/vision/design-plan.md](../../vision/design-plan.md) §1 (architecture), §2
> (crates + domain), §3 (ports), §8 (testing), §9 (migration R1–R5), §11 (risk),
> §12 (open arch questions); cross-read with
> [docs/vision/product-vision.md](../../vision/product-vision.md) (pillars P1–P7,
> top-20 backlog, v1 line) and the grafts in
> [docs/vision/research/arch-decision.md](../../vision/research/arch-decision.md)
> §4. Golden-master facts from
> [docs/vision/research/cide-current-state.md](../../vision/research/cide-current-state.md)
> §4–§5 and `tests/run.sh` (~120 emitted-command assertions). 2026-06-12.
>
> **Naming note (rebrand, owner 2026-06-09).** The design plan was written under
> the old names: repo `cmux-ide`, binary `cide`, crate stem `cide-*`. The owner
> has since rebranded the Rust product to **cmux-terminal-ide**, binary **ctide**,
> crate stem **ctide-\***. This document uses the **ctide** names throughout and
> flags the mapping where the source text says `cide`. The shell dogfood commands
> (`cide-space`, `cide-place`, `cide-agent`, …) are **strangled and retired, never
> renamed** — the Rust workspace is born `ctide` from crate one.

---

## 0. How to read this skeleton

Each phase below is a **revertible strangler increment**, not a sprint. The
design plan's coexistence contract (§9) is the invariant that makes the whole
spine safe:

1. Every phase is independently shippable and reverts via `CIDE_SHELL=1` (the
   3-line preamble each `bin/cide-*` script grows). *(Rebrand note: the env var
   stays `CIDE_SHELL` — it gates the legacy shell scripts, whose names do not
   change.)*
2. Verbs port in **dependency clusters** so no state file is ever co-written by
   both generations (graft **g6** enforces the boundary).
3. **Tree-is-truth** means the two generations cannot corrupt each other's view
   of cmux.
4. **No new shell features after R1** — new capability lands Rust-only, so the
   gap only ever closes.
5. `ctide doctor` reports which generation owns each verb.

The locked crate DAG (design-plan §2), rebranded:
`ctide-core` → `ctide-json` → `ctide-mux-cmux` → `ctide-adapters` →
`ctide-dbt` / `ctide-place-macos` → `ctide-testkit` → `ctide` (bin). Dependency
rule is CI-enforced: core depends on nothing in-workspace; nothing depends on the
binary.

---

## R0 — Repo decision + Cargo scaffold (the pre-phase the design plan folds into "R1")

> The design plan treats repo-rename + Cargo scaffolding as a one-line event
> ("executed at Cargo-scaffolding time", design-plan §2 line 80; prior-decisions
> §1: "colocated, executed at Cargo-scaffolding time, not mid-shape"). The
> rebrand + the strangler-coexistence requirement make this worth **splitting out
> as an explicit R0**, because it carries a genuine open decision (repo rename vs
> new repo) and because getting the CI/quality template right de-risks every
> phase after it.

- **Goal.** Stand up the empty-but-real Rust workspace, its CI/quality gates, and
  the dependency-rule enforcement *before* a single verb is ported — so R1's first
  port lands into a structure that already says "no" to the things the
  architecture bans (tokio, HTTP, `~/.config` writes, manifest-less adapters).

- **Concrete deliverables.**
  - **Repo-location ruling** (see *Repo decision* box below) — rename
    `cmux-workspace-dbt` → `cmux-terminal-ide`, *recommended*, vs new repo.
  - `Cargo.toml` workspace: `resolver = "2"`, unified version, the empty crate
    skeletons (`ctide-core`, `ctide-json`, `ctide-mux-cmux`, `ctide-adapters`,
    `ctide-dbt`, `ctide-place-macos`, `ctide-testkit`, `ctide` bin) — each
    compiling as a stub.
  - **CI/quality template adopted from crap4rs** (`~/github/crap4rs`): deterministic
    CI, lefthook, `deny.toml`, release-plz, `rust-toolchain` pin, cucumber-rs
    harness, **crap4rs itself adopted as a quality gate**.
  - **Dependency-rule CI check** (core-knows-no-domain; nothing depends on bin).
  - **`cargo-deny` allowlist scoped to the shipped binary's normal graph**
    (`exclude-dev`) — the carve-out for cucumber-rs's dev-only async stack, so the
    no-tokio/no-HTTP ban never fails the build *or* gets quietly weakened
    (design-plan §2, §8.6; risk #4's erosion mode).
  - `~/.config`-path-literal grep gate (rejects writes outside a consented module).
  - `aarch64-unknown-linux-musl` compiles in CI from day one (no adapter yet; cheap
    insurance — design-plan §10).
  - `cargo-dist` skeleton (brew tap target wired, not yet publishing).

- **Hard dependencies.** None outside this repo. **Must precede everything.**
  Blocks R1. Requires the repo-location ruling (Q below) resolved first.

- **Exit criteria (testable).**
  - `cargo build --workspace` and `cargo test --workspace` green on the empty
    skeleton, in CI, on aarch64-darwin + aarch64-linux-musl.
  - Dependency-rule check fails a deliberately-planted violation (core importing
    the bin) — proving the gate is live, not decorative.
  - `cargo-deny` rejects a deliberately-added `reqwest`/`tokio` in a *shipped*
    crate but allows it in a `dev-dependency` — proving the `exclude-dev` scope.
  - The `~/.config` grep gate rejects a planted path literal.

- **Grafts landed.** Foundations for **g4** (the `ctide-json` crate exists as a
  stub), **g7** (testkit crate exists), **g1** (cucumber + property-test harness
  wired). No graft is *completed* here — R0 builds their homes.

- **Risks retired / exposed.** **Retires the structural half of #4**
  (latency/dep-creep) by making the `cargo-deny` allowlist and no-tokio lints
  load-bearing from line one. **Retires part of #5** (solo bus-factor) by adopting
  a proven CI template instead of hand-rolling one. **Exposes #1** (cmux API
  drift) only once the mux adapter lands at R1 — R0 doesn't touch cmux.

> **Repo decision (roadmap must recommend, not assume — task constraint).**
> **Recommendation: rename `cmux-workspace-dbt` → `cmux-terminal-ide` in place.**
> Three reasons, all from the approved design + the constraints:
> (1) **Strangler coexistence requires colocation** — the 3-line `exec ctide`
> preamble in each `bin/cide-*` script (design-plan §9) and the `CIDE_SHELL=1`
> rollback only work if shell + Rust live in one tree; a new repo breaks the
> strangler.
> (2) **The POSIX golden master ("the permit", ~120 assertions) lives here** —
> `tests/run.sh` + `tests/stubs/` + `tests/fixtures/`
> ([cide-current-state.md](../../vision/research/cide-current-state.md) §5); the
> design plan makes "a verb may not replace its shell twin until the golden-master
> diff is empty" the gate for R2/R3 (design-plan §8.2). The permit must be
> in-repo.
> (3) **History continuity** — prior-decisions §1 already records the rename as
> "colocated, executed at Cargo-scaffolding time," so this is honoring a settled
> decision, not opening a new one.
> *The counter* (a clean greenfield repo) was **explicitly rejected** in
> prior-decisions §1 ("parallel greenfield repo"). The only open sub-question is
> cosmetic: the design plan's directory comment still says `cmux-ide/` — the
> rename target is now `cmux-terminal-ide`.

---

## R1 — Foundations (read-mostly, zero blast radius)

- **Goal.** Stand up the binary skeleton, the cmux socket adapter + quirk vault,
  and the read-only "parser killer" verbs — earning trust (`doctor` is useful day
  one) with no risk to live state. *(Design-plan §9 R1, 3-week appetite.)*

- **Concrete deliverables.**
  - `ctide` binary skeleton: clap + composition root only.
  - **`ctide-mux-cmux`**: `CmuxSocketAdapter` (primary, v2 JSON) + `CmuxCliAdapter`
    (fallback) + the **quirk vault** (every hard-won cmux fact from
    [cide-current-state.md](../../vision/research/cide-current-state.md) §4, each
    with a `// fact:` comment + fixture test — design-plan §4).
  - **`ctide-json`** (g4): the frozen `--json` contract structs, `schema`-versioned.
  - `ctide doctor`: egress audit (cide's own surface + cmux-substrate audit),
    config-layer provenance (g5), capability-drift probe.
  - `ctide state migrate` — the **per-state-family, re-runnable, collision-refusing**
    migrator (g6); families migrate in the phase where their owning *write*-verbs
    port (agents → R2, spaces+registry → R3).
  - Fixture generator (`ctide-testkit gen-fixtures`, captures from live cmux into
    `fidelity/<version>/`).
  - The **parser killers**: `ctide theme`, `ctide agent ls`, `ctide statusline`.

- **Retires (shell).** The three worst hand-rolled parser sites (3× awk-TOML,
  JSON-by-grep, session-store joins); the two live hygiene violations — #9
  (`~/.config/ghostty` write) and #10 (tracked-file churn) — via typed `ApplyPlan`
  (the `ThemeTarget` port makes `~/.config` writes *unrepresentable*, design-plan
  §3).

- **Hard dependencies.** R0 (scaffold + gates). The fixture generator needs a live
  cmux to capture from (the `--ignored` tier). `ctide state migrate` needs the
  versioned shell-format readers in place so R1's read-only verbs can read
  unmigrated families.

- **Exit criteria (testable).**
  - `ctide doctor` prints the exact network surface (one line for default bindings:
    `gh (defensible-egress, opt-in)`) + the cmux-substrate section; runs offline.
  - `ctide theme` produces a themed result with **zero `~/.config` writes** (grep
    gate green) and no tracked-file churn.
  - `ctide agent ls` and `ctide statusline` read the **shell-format** state through
    versioned readers (families not yet migrated) and match shell output.
  - Port conformance kit runs against `FakeMux` (always) and against the
    `CmuxSocketAdapter` over the **recorded replay server** (g7) — both green.
  - `capabilities()` probe diffs live cmux vs the pinned fidelity snapshot; doctor
    prints any drift.

- **Grafts landed.** **g4** (ctide-json frozen + shipped), **g5** (doctor
  provenance), **g6** (`ctide state migrate` discipline established; agents/spaces
  families migrate later), **g7** (replay-server conformance tier live in CI).

- **Risks retired / exposed.** **Retires #1's standing exposure** by building the
  one-module wire parser, versioned fixtures, capability probe, and CLI second
  oracle (the full mitigation lives here). **Exposes #1** in the sense that this is
  where cmux drift first *bites* — the playbook (regen fixtures → diff → fix
  adapter → golden green) gets its first exercise. **Retires hygiene violations #9
  / #10** (vision-tracked, not risk-register). Touches none of the residency
  risks (#2) — R1 ships no long-lived process.

---

## R2 — Runner + guarded writes (first mutations, first never-had capability)

> Graft **g2** reorders Sketch A's plan: **runner before the spaces port.** Zero
> golden-master parity burden, immediate dogfood value, and it **load-hardens the
> socket + pipe-pane + state-write paths before the crown jewels (R3) ride them.**

- **Goal.** Ship the runner engine (the #1 backlog keystone, the first
  capability that *never existed in shell*) plus the first mutating verbs, proving
  the write paths and `InjectionGuard` safety under golden-master parity.
  *(Design-plan §9 R2, 2-week appetite.)*

- **Concrete deliverables.**
  - **`ctide run` / `ctide run wrap`** — the g2 pull-forward. `run wrap` wraps the
    **external `watchexec` binary** (never as a library — preserves the no-tokio
    budget, design-plan §6, arch-decision §2.4): foreground loop, child stdout →
    `FailureParser` → on Red: write `state/jobs/<id>.json`, `set_status` pill,
    policy-filtered `notify`, `flash`; on Green: clear.
  - **`RunnerCatalog` detect** (just/make/npm/cargo) + the **bacon fast-path**
    (`.bacon-locations` artifact parser) — the Rule-of-Two seam first appears here.
  - First mutating verbs: `ctide set-role`, `ctide jump`, `ctide open`,
    `ctide md-open`, `ctide agent new/rename` (completes the agents cluster).
  - **Agents state-family migrates here** (g6) — kills the split-brain of shell
    appends vs Rust reads.
  - **g3 discipline applied today**: the binary-version self-check
    (exit-for-respawn when the on-disk binary changed post-`brew upgrade`) lands on
    the long-lived `ctide run wrap` pane now, not just the future reactor.

- **Retires (shell).** The Dock's raw watchexec line; the `just --list` stub pane
  (#23); shell `cide-jump` / `cide-open` / `cide-set-role` / `cide-agent` →
  reduced to `exec ctide` shims. (`hx-wrap` stays a shell launcher calling
  `ctide set-role` — wrapper-launchers are adapter-owned and may stay shell
  forever.)

- **Hard dependencies.** R1 (socket adapter, quirk vault, `ctide-json`,
  `state migrate`). Runner needs `MuxSurfaces` (`pipe_pane`, `set_status`,
  `notify`, `flash`) and the agents state migration. `fix_on_red` delivery needs
  `Agent::submit_prompt` over `workspace.prompt_submit`.

- **Exit criteria (testable).**
  - `ctide jump`, `open`, `set-role`, `md-open`, `agent new/rename` pass the
    **golden-master diff** against their shell twins on the shared fixture topology
    (empty diff or annotated intended improvement — design-plan §8.2). *This is the
    first golden-master gate.*
  - `InjectionGuard` makes a blind `send_text` **uncompilable**; a self-heal /
    fresh-spawn round-trip passes against `FakeMux`.
  - `ctide run wrap` drives a red→fix→green cycle: a runner failure produces a
    structured `Diagnostic` (file:line + artifact path, never pasted ANSI) and (if
    `fix_on_red` on) submits it via `prompt_submit`.
  - The **g1 hook-storm convergence property** runs in CI against `ctide run wrap`
    (random kill point → restart-from-cursor → end-state converges).
  - Agents family **refuses to run unmigrated** (g6) — a ported verb errors rather
    than co-writing shell-format state.

- **Grafts landed.** **g2** (runner-first ordering, *realized*), **g1**
  (convergence property first applied — to `run wrap`), **g3** (binary-version
  self-check on long-lived panes), **g6** (agents family migrated).

- **Risks retired / exposed.** **Retires #8** (two-generation limbo) materially —
  R2 delivers never-had capability + exec shims prove per-verb migration cost is
  ~zero. **Retires #3 (hook-storm races)** via the g1 convergence property + single
  `flock` + atomic rename on the write paths. **Exposes #6 (helix limits)** —
  editor-open via `InjectionGuard` keystroke injection is first stressed here.
  **Partially exposes #4 (latency)** — first verbs whose budgets the hyperfine
  release-blockers must hold.

- **🚦 RE-APPROVAL CHECKPOINT (end of R2).** Design-plan §9 + product-vision §4:
  **golden-master parity holding + the runner shipped and dogfooded** is the
  evidence the architecture bet paid off. Christopher re-evaluates *here*, before
  the crown jewels (R3 spaces) ride the rails. **The roadmap must treat the end of
  R2 as a hard human gate.**

---

## R3 — Spaces + place (the crown jewels)

- **Goal.** Port the unit-of-work itself — resumable spaces (P1) — and
  monitor-aware placement, gated hard on golden-master parity and the live
  agent-resume round-trip. *(Design-plan §9 R3, 3-week appetite.)*

- **Concrete deliverables.**
  - `ctide space new / open / close / rm / ls`.
  - `ctide place` (monitor-aware window placement).
  - **`ctide-place-macos`**: CoreGraphics + AX via `objc2` **in-process** —
    retires the Swift placement helper (kills the Xcode-CLT dep + per-call `swift`
    startup, pain #16); AeroSpace cooperation + AX-grant reality move into the
    adapter + a doctor check. Linux binds `NoopPlacement`
    (`Skipped { reason }`, never blocks).
  - **Spaces + registry state-families migrate here** (g6).

- **Retires (shell).** `bin/cide-space`, `bin/cide-place` → shims; the Swift
  placement helper retired entirely.

- **Hard dependencies.** R2 (load-hardened socket/pipe/state paths; agents family
  migrated). The **end-of-R2 re-approval gate must have passed.** Spaces resume
  needs the agent checkpoint read path (`AgentSlot.checkpoint`, read-only) and the
  `surface resume` stamps. Placement needs `objc2` (macOS) and the live AX grant.

- **Exit criteria (testable).**
  - `ctide space *` and `ctide place` pass the **golden-master diff** vs shell
    twins (the hard gate).
  - **The live agent-resume round-trip verify passes** — the pending verify that
    gates task #29 and is the *hard R3 gate*
    ([cide-current-state.md](../../vision/research/cide-current-state.md) §5;
    product-vision P1 asterisk). A space closed then reopened resumes layout +
    role-stamped agent conversations + tool sessions as one object.
  - The **g1 convergence property** covers the space open/close write paths.
  - Spaces + registry families **refuse to run unmigrated** (g6); `ctide state
    migrate` round-trips both families collision-free.
  - Placement returns **typed** `Placed | Skipped { reason }` (never silent —
    pain #6); Linux `NoopPlacement` never blocks.

- **Grafts landed.** **g6** (spaces + registry families migrated — completes the
  migration discipline), **g1** (convergence extended to space writes), **g3**
  (placement adapter inherits the long-lived-pane disciplines where relevant).

- **Risks retired / exposed.** **Retires the P1 asterisk** — the live
  resume round-trip is the single biggest open verification in the whole vision.
  **Retires #8 fully** once the crown jewels are Rust-native and shell is shims.
  **Exposes #1 hardest** (spaces lean heavily on `tree --all`, `identify`,
  workspace lifecycle — the most cmux-quirk-dense verbs). **Exposes #6** again
  (placement + AX grant fragility) — confined to `ctide-place-macos`.

> **Open arch Q feeding R3 (design-plan §12 Q4):** `workspace.group.*` native
> space containers (backlog #6) at R3 *alongside* the spaces port, or post-R3? The
> registry stays the cross-monitor join either way. Roadmap should sequence this as
> an in-phase option, not a blocker.

---

## R4 — Rust-only capability (verbs never written in shell)

- **Goal.** Ship the flagship review loop + the config compiler + the policy hook —
  all Rust-from-birth, riding declarative hooks + catch-up (design-plan §7), no
  reactor. *(Design-plan §9 R4, 2-week appetite.)*

- **Concrete deliverables.**
  - **`ctide sync`** — the config→`.cmux/*` compiler (palette actions w/ keyword
    taxonomy, `commands[]`, plus-button "New ctide Space", per-vertical tab-bar
    buttons; `.cmux/dock.json` controls; the Feed control generated `--legacy`,
    never the npm-fetching OpenTUI mode; deep-merged `.cmux/cmux.custom.json` so
    hand edits survive). *This is the daemonless wiring story.*
  - **`ctide review`** — the agent-turn review queue (P2 flagship); walks unreviewed
    turns across every agent in a space; comment = send back into the conversation.
    Ships on **declarative hooks alone** — never blocked on the gated reactor
    (product-vision §4 sequencing).
  - **`ctide policy`** — the stdin→stdout notification-policy filter
    (focus-aware silencing, failure escalation).
  - `ctide replace` (atomic write-all → serpl → reload-all), `ctide focus`
    (fan-out chord), `ctide setup` (the **only** module that can construct a
    `Consent` token for global writes; diff-shown, consented, reversible).
  - Claude `Stop` hook → `ctide turn-complete` (stamps `ReviewItem`s, opens
    `diff --source last-turn --no-focus`).

- **Retires (shell).** The `.cmux/` smoke test graduates into `ctide sync` output;
  the notify stub (Feed replaces it — #25 settled).

- **Hard dependencies.** R3 (spaces — `review` walks turns *across a space*; `sync`
  compiles space/binding config). `policy` + `turn-complete` need the hook pipeline
  + `MuxEvents` catch-up. `setup` is the gatekeeper for any `~/.config` write.

- **Exit criteria (testable).**
  - `ctide sync` deterministically compiles resolved config → `.cmux/cmux.json` +
    `.cmux/dock.json` with a generated-by marker; re-running is idempotent;
    hand-edited `.cmux/cmux.custom.json` survives a re-sync.
  - The Feed control in generated dock is `--legacy` (doctor audits it — no npm
    fetch).
  - `ctide review` (BDD, cucumber-rs) walks unreviewed turns across ≥2 agent slots
    against `FakeMux`; the `.feature` file is the published contract.
  - `ctide policy` round-trips a notification JSON (focus-aware silence + runner-red
    escalate) as a pure stdin→stdout filter.
  - The **g1 50-parallel hook-storm property** runs against `policy` ×
    `turn-complete` (the canonical concurrent-hook case).
  - `ctide setup` is the **only** path that writes a global file; a planted write
    elsewhere fails the consent-token + grep gates.
  - Flow-SLO hyperfine benches (cold start < 10 ms, `jump --dry` < 30 ms) pass as
    **release blockers** (relative-regression gated).

- **Grafts landed.** **g1** (the *canonical* hook-storm convergence target —
  `policy` × `turn-complete` — fully realized here). g5/g7 continue to run; no new
  graft introduced (g2/g3/g4/g6 already landed).

- **Risks retired / exposed.** **Retires #4** in earnest — R4's verbs are the
  hot-path palette actions whose budgets the release-blocker benches now enforce.
  **Exposes #2 (reactor/residency bet)** — if `review` or `policy` turns out to
  *need* reactor-mode residency, the promotion gate ("two shipped loops
  independently needing residency") is first pressure-tested here. **Tests #9
  (Sherlocking)** — the review queue is the most absorbable-by-cmux differentiator;
  the capability probe watches for upstream encroachment.

> **Open arch Qs feeding R4 (design-plan §12):** Q1 (user-config layer location —
> needs a ruling *before R1* but is a one-constant change), Q2 (generated `.cmux/*`
> committed vs gitignored — decided by `ctide sync`'s shape here, also decides the
> smoke-test's fate), Q5 (`ctide-json` versioning policy — agent consumers pin
> against it), Q7 (golden-master delta adjudication — who signs "intended
> improvement," matters across R2–R3).

---

## R5 — Verticals + retirement (the dbt recipe + v1 close-out)

- **Goal.** Land the dbt vertical as **data** (recipe + adapter code), trigger the
  rust-dev recipe at the Rule-of-Two point, and delete the shell bodies — leaving
  shell only as adapter-owned wrapper-launchers. *(Design-plan §9 R5; the dbt-recipe
  slice gets a 2–3-week appetite; this is the v1 close.)*

- **Concrete deliverables.**
  - **dbt recipe** (`recipes/dbt.toml` — vertical as data): `cwd focus` → `ctide
    focus`, `cwd route` → routing data, the **`Warehouse` port** from `hq-wrap`
    logic (harlequin, read-only dev attach, DuckDB default), **cute-dbt behind the
    `DbtReview` port** (snapshot baseline + compare; egress label zero,
    network-block CI proven).
  - **`ctide-dbt`** adapter code (Warehouse, DbtReview, dbt catalog/parser) — dbt
    knowledge **quarantined** here + in recipe data; base/rust ship zero dbt deps.
  - **rust-dev recipe** *at the Rule-of-Two trigger* (bacon/nextest/mutants through
    the *same* ports as dbt's jobs, recipe-only differences, zero rust-specific
    branches in `ctide-core` — the §6 acceptance test).
  - Delete shell command bodies; the POSIX suite **converts to cucumber features**.

- **Retires (shell).** The `cwd` family; the POSIX `tests/run.sh` golden master
  converts to cucumber `.feature` files. Shell remains only as wrapper-launcher
  scripts adapters own.

- **Hard dependencies.** R4 (`ctide focus`, `ctide review`, `ctide sync`, the
  config compiler the dbt recipe rides). The dbt warehouse derive needs
  `profiles.yml` read-only access. cute-dbt integration depends on cute-dbt's F1
  (#105 SemVer'd `focusModel()` contract) + F6 (crates.io publish #112) for the
  fully-composed journey — *but the `DbtReview` shell-out works pre-publish.*
  rust-dev recipe is gated on the **Rule-of-Two trigger**, not a date.

- **Exit criteria (testable).**
  - A bare machine runs `ctide space new --type dbt` in a dbt repo and gets the
    full recipe (embedded `include_str!` — no runtime downloads).
  - `DbtReview` snapshot→compare round-trips against cute-dbt with **egress label
    zero** (network-block CI proves it).
  - The **Rule-of-Two acceptance test passes**: rust-dev's bacon/nextest/mutants
    jobs run through the *same* `RunnerEngine`/status/review ports as dbt's, with
    recipe-only differences and **zero rust-specific branches in `ctide-core`**
    (product-vision §6). *If it fails, the seams were wrong — and we learn it on
    vertical #2, not #5.*
  - The converted cucumber suite passes the full POSIX golden-master assertion set
    (~120 emitted-command assertions, re-counted at conversion time, never fewer).
  - `cargo-dist` produces per-arch darwin artifacts + the brew formula; `ctide
    doctor` prints the full network surface (cide's own + cmux substrate).

- **Grafts landed.** All grafts are landed by R4; R5 *exercises* them across the
  verticals (g4's `ctide-json` contract is what the dbt/rust skills pin; g7's
  conformance kit is the "write an adapter, pass the suite" on-ramp — open Q6: when
  does `ctide-testkit` publish).

- **Risks retired / exposed.** **Retires #7 (dbt churn)** structurally — dbt
  knowledge is quarantined behind `DbtReview` + recipe data; base/rust have zero
  dbt deps, so dbt-toolchain upheaval cannot stall the spine. **Retires #5
  (bus-factor)** as much as it can be — conformance suites + BDD features are now
  executable documentation across two verticals. **Validates the whole
  ports/adapters bet** (the Rule-of-Two test is the architecture's own falsifier).

> **v1 line (both docs agree):** **v1 = R1–R4 base + the dbt recipe with backlog
> #5 behind `DbtReview`.** Backlog #12/#13/#15 are post-v1 L-effort programs,
> explicitly NOT v1 scope. Note the lone "now" exception: **backlog #5 (the
> cute-dbt review loop) ships from the POSIX dogfood BEFORE R1 begins** — after R1,
> coexistence rule (4) holds and further dbt capability waits for R5.

---

## The walking skeleton — smallest end-to-end slice that proves the architecture

> Task asks for *the* smallest slice that proves the architecture: which **port** +
> which **verb** + **FakeMux** + **CI green**. The design plan gives a clean
> answer because it already isolates a "read-mostly, zero blast radius" verb.

**Candidate: `ctide doctor` over the `Multiplexer` (`MuxTopology`) port, against
FakeMux, green in CI.**

Why this is the spine-proving slice (smallest thing that exercises *every layer*):

- **One port, the umbrella one.** `ctide doctor` calls `MuxTopology::tree()` /
  `capabilities()` / `manifest()` — it touches the `Multiplexer` supertrait, the
  single most load-bearing port, **without mutating anything** (zero blast radius,
  design-plan §9 R1).
- **One verb, useful day one.** `doctor` is explicitly "useful from day one"
  (design-plan §9 R1) and aggregates egress labels + config provenance (g5) +
  capability drift (g7 probe) — so the *first* slice already demonstrates the trust
  posture (P7), the contract crate (g4, via `--json`), and the conformance probe.
- **Proves the three-impl story end-to-end.** The same conformance assertion runs
  against **FakeMux** (always), against `CmuxSocketAdapter` over the **recorded
  replay server** (g7), and against **live cmux behind `--ignored`**. Getting
  `doctor` green across all three *is* the proof that "the third impl is the testing
  story" (design-plan §4).
- **Proves the dependency rule.** `doctor` flows `ctide` (bin/composition root) →
  `ctide-adapters` manifests → `ctide-mux-cmux` → `ctide-core` ports →
  `ctide-json` output — i.e. it walks the full crate DAG that the CI dependency-rule
  gate protects (R0).
- **CI-green definition for the walking skeleton:**
  1. `ctide doctor --json` returns a `ctide-json`-typed, `schema`-versioned payload.
  2. The `conform_multiplexer(&FakeMux, fixtures)` suite is green.
  3. The same suite is green against `CmuxSocketAdapter` over the replay server (g7).
  4. The `~/.config` grep gate + `cargo-deny` (no-tokio/no-HTTP) gates are green.
  5. The flow-SLO bench harness measures `doctor` cold start (the first hyperfine
     budget data point).

**Runner-up (if a *mutating* skeleton is wanted to prove write paths sooner):**
`ctide run wrap` over `MuxSurfaces` (`set_status` + `pipe_pane`) against FakeMux —
this is the g2 runner-first pull-forward and the first never-had capability, but it
is heavier (state writes, parser, fix-on-red) and so a *worse* "smallest" slice
than `doctor`. Use `doctor` to prove the *architecture*; use `run wrap` to prove
the *write paths* immediately after.

---

## Dependency graph (the spine, one glance)

```
R0 scaffold + repo rename + CI/quality gates (crap4rs template)
   │  (blocks everything; resolves repo-location ruling first)
   ▼
R1 foundations ── socket adapter + quirk vault + ctide-json(g4) + doctor(g5)
   │              + state-migrate(g6) + replay conformance(g7) + parser killers
   │              ◄── WALKING SKELETON proven here (ctide doctor / MuxTopology / FakeMux)
   ▼
R2 runner(g2) + guarded writes ── agents family migrated(g6) + g1 convergence
   │                              + g3 binary-self-check
   ▼
🚦 RE-APPROVAL GATE (golden-master parity + runner dogfooded)
   ▼
R3 spaces + place ── spaces+registry families migrated(g6)
   │                 ◄── HARD GATE: live agent-resume round-trip verify (task #29)
   ▼
R4 sync + review + policy (Rust-only) ── g1 canonical hook-storm (policy×turn-complete)
   │
   ▼
R5 dbt recipe + rust-dev(Rule-of-Two) + delete shell bodies + POSIX→cucumber
      ◄── v1 line: R1–R4 + dbt recipe behind DbtReview
```

**Cross-cutting, every phase:** the **golden-master permit** (`tests/run.sh`, ~120
emitted-command assertions) gates each migrated verb R2→R3 (empty diff or annotated
improvement); the **flow-SLO hyperfine benches** are release blockers from the first
hot-path verb; the **egress / `~/.config` / `cargo-deny` gates** (R0) run on every
commit.

---

## Risk-register coverage map (which phase retires / exposes each)

| Risk (design-plan §11) | Retired by | First exposed by |
|---|---|---|
| #1 cmux API drift | R1 (one wire module, fixtures, probe, CLI oracle, g7) | R1 first bite; R3 hardest (quirk-dense spaces verbs) |
| #2 reactor / residency bet wrong | gate pre-written (not a phase); g3 spec pre-agreed | R4 (review/policy are the residency-shaped candidates) |
| #3 hook-storm state races | R2 (g1 convergence + flock + atomic rename) | R2 (`run wrap`), R4 (`policy`×`turn-complete`) |
| #4 latency / dep-creep | R0 (cargo-deny scope + no-tokio lints) + R4 (release-blocker benches) | R2 (first verbs), R4 (hot-path palette verbs) |
| #5 solo bus-factor | R0 (crap4rs template) + R5 (BDD/conformance as docs) | ongoing (architecture *is* the mitigation) |
| #6 helix limits | confined to one adapter behind `InjectionGuard` | R2 (editor-open), R3 (placement/AX) |
| #7 dbt Fusion / core-v2 churn | R5 (quarantined behind `DbtReview` + recipe data) | R5 only (base/rust have zero dbt deps) |
| #8 two-generation limbo | R2 (never-had capability + zero-cost shims) → R3 (crown jewels Rust-native) | R1→R3 window (the strangler's exposed period) |
| #9 cmux Sherlocking | not retirable; capability probe = re-rank trigger | R4 (review queue is the absorbable differentiator) |

---

## Open questions the roadmap must resolve (carried from design-plan §12 / vision §9)

- **Before R0/R1:** repo-location ruling (recommended: rename in place — see R0
  box); Q1 user-config layer location (one path constant); Q8/§9-Q25 license (GPL-v3
  vs MIT, before the brew tap goes public — but only blocks R5 publish, not earlier).
- **Before R2:** Q3 runner default home (Dock vs layout tile); Q7 golden-master
  delta adjudication (who signs "intended improvement").
- **Before R3:** Q4 `workspace.group.*` adoption timing (in-phase option).
- **Before R4:** Q2 generated `.cmux/*` committed vs gitignored (decided by
  `ctide sync` shape; also decides the smoke-test fate); Q5 `ctide-json` versioning
  policy.
- **Before R5:** Q6 conformance-kit publication timing + colleague-extension
  mechanism; the dbt cluster (vision §9 Q6–Q14) + rust cluster (Q15–Q21, incl. the
  Rule-of-Two exit-criteria ratification Q21).

---

*Backbone complete. This is the spine the master roadmap is built on: R0 scaffold →
R1 foundations (walking skeleton: `ctide doctor`) → R2 runner (re-approval gate) →
R3 spaces (live-resume hard gate) → R4 Rust-only review loop → R5 dbt recipe + v1.
Source of truth for the increments: [design-plan.md](../../vision/design-plan.md)
§9; for the product line: [product-vision.md](../../vision/product-vision.md) §4.*
