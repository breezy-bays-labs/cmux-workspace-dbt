# first-issues — start here: the first work items for the ctide build

> **What this is.** The "start here" breakdown for the
> [master roadmap](./roadmap.md): the first concrete work items to begin the
> build, in strict dependency order. Each item is sized to be picked up *cold* by
> a build session — it carries a crisp title, a summary, testable acceptance
> criteria, dependencies, the roadmap/design references it implements, and a
> `## Discovery` note of what is still unknown and must surface during the work.
>
> **Naming note.** These are **local task-list ids** (`#N — description`), in the
> owner's 1:1-PR style. This repo does **not** use GitHub issues for `cide`/`ctide`
> work — these ids are the unit of work for the build, one PR each. (The existing
> shell dogfood tasks #23–#33 already use this numbering; #34+ continue it. The
> roadmap's `EN` ids name the *epics*; these `#N` ids name the *startable slices*
> inside them.)
>
> **Conformance.** This document is bound by the roadmap's constraints: daemonless,
> no tokio (the runner wraps the **watchexec binary**, never the library), zero
> egress / local-first, **never writes `~/.config`**, macOS-first / Linux-not-
> precluded, the **rename in place** (not a fork), and the strangler-coexistence
> golden-master "permit". Where a convenience collides with one of those, the
> constraint wins. 2026-06-12.

---

## The first work items, at a glance (R0–R1 spine + the keystone-A target)

> **Honest sequencing.** These five are the **R0–R1 spine** (#34/#35/#36/#38) plus
> the **keystone-A target** (#37). #37 is **not** the 5th startable item — it is
> genuinely ~8th: between #38 and #37 sit several unnamed intermediate slices that
> are #37's real prerequisites — the remaining parser-killer ports (`ctide agent ls`,
> `ctide statusline`), the **agents-cluster write-verbs** (`set-role`/`jump`/`open`/
> `md-open`/`agent new|rename`, which migrate the agents state family), and
> `ctide state migrate` for that family. #37 is listed here as the *target the spine
> builds toward*, not as the immediately-next item. The true next-startable slice
> after #38 is `ctide agent ls` / `ctide statusline` (the other R1 parser killers).

| # | Title | Epic / Phase | Blocks | Blocked by | Appetite |
|---|---|---|---|---|---|
| **#34** | Rename `cmux-workspace-dbt → cmux-terminal-ide` + scaffold the empty 8-crate `ctide` workspace | E0 / R0 | everything | owner go-ahead on the rename ruling | S–M |
| **#35** | Walking skeleton: `ctide doctor` over `MuxTopology` against `FakeMux`, green in CI | E1 / R1 | all later verbs | #34 | M (first slice) |
| **#36** | CI/quality foundation: the crap4rs-derived gate graph + zero-egress/dep-rule/`~/.config` gates | E0 / R0 | the 5-gate DoD of #35; every later PR | #34 (lands *with/after* the crate tree) | S–M |
| **#37** | Runner engine: `ctide run` / `ctide run wrap` wrapping the watchexec binary (KEYSTONE A) | E2 / R2 | #2/#9/#13/#15 (all consumers of the runner) | **hard:** #35, #36 + the R1 `MuxSurfaces` substrate it rides · **soft (sibling E2, interleave):** agents-cluster write-verbs + `agents state migrate` | M (~2 wk) |
| **#38** | First parser-killer port: `ctide theme` behind the golden master (the strangler's first real cutover) | E1 / R1 | confidence for the agents-cluster ports | #35, #36 | S |

> **Why this order.** #34 first because nothing compiles until the workspace
> exists and the repo is born "ctide" (no mid-stream rename churn). #35 is the
> walking skeleton — the smallest slice that exercises *every layer* with zero
> blast radius; it is the first **value-bearing** work. #36 is split out because
> the walking skeleton's definition-of-done *is* its five CI gates, so the gate
> graph must be real, not stubbed — but it can land in the same PR arc as #34/#35
> rather than blocking them. #37 is the keystone: the first capability that never
> existed in shell, gated by the end-of-R2 re-approval. #38 is the gentlest
> strangler cutover (read-mostly, kills two live hygiene bugs) — a good "second
> Rust verb" once doctor proves the rails. **#34 → #35/#36 (parallel arc) → #38 →
> #37.** Roadmap dependency view: [`roadmap.md` §7](./roadmap.md);
> backbone graph: [`research/backbone.md`](./research/backbone.md).

---

## #34 — Rename `cmux-workspace-dbt → cmux-terminal-ide` + scaffold the empty 8-crate `ctide` workspace

**Epic / phase:** E0 / R0. **Appetite:** S–M. **This is the program's first epic —
the gate that unblocks everything.**

### Summary

Resolve the repo-location ruling (rename in place, *recommended* — see refs), then
stand up the empty-but-real `ctide` Rust workspace alongside the strangled `bin/`
shell tree: the locked 8-crate DAG, born `ctide` from crate one, each crate
compiling as a stub. Rename the GitHub repo `cmux-workspace-dbt →
cmux-terminal-ide` *in place* (defer the local-dir rename — it orphans the Claude
project-memory path key, keep the checkout path stable). The CI/quality gates
themselves are item **#36**; this item is the tree + the rename + the toolchain
pin so that the very next thing (the walking skeleton) lands into a structure that
already enforces the dependency rule.

### Acceptance criteria

- [ ] **Owner go-ahead recorded** for the rename-in-place ruling before any rename
      command runs (this item is *pending owner go* — see Discovery).
- [ ] `Cargo.toml` workspace exists: `resolver = "2"`, unified version, the locked
      crate skeletons — `ctide-core`, `ctide-json`, `ctide-mux-cmux`,
      `ctide-adapters`, `ctide-dbt`, `ctide-place-macos`, `ctide-testkit`, and the
      `ctide` binary — each compiling as a stub.
- [ ] `cargo build --workspace` and `cargo test --workspace` are green on the empty
      skeleton (locally and in CI once #36 lands).
- [ ] The crate DAG honors the dependency rule by construction: `ctide-core`
      depends on nothing in-workspace; the `ctide` bin depends on all; **nothing
      depends on the bin**. (`ctide-place-macos` is `cfg(target_os = "macos")`.)
- [ ] `rust-toolchain.toml` pins a **specific stable** `1.NN.0` (not floating
      `stable`) + `clippy`, `rustfmt`, `llvm-tools-preview`; `rustfmt.toml` sets
      `edition = "2024"`.
- [ ] `recipes/`, `layouts/`, `themes/`, `tests/features/` dirs exist (data homes,
      not crates).
- [ ] **GitHub repo renamed** `cmux-workspace-dbt → cmux-terminal-ide`; `git`
      remote + `gh` references updated; the brew formula / tap reference flips
      `cide → ctide` (formula `Formula/ctide.rb`); `breezy-bays-labs/homebrew-tap`
      created (empty).
- [ ] **The existing shell tree is untouched** — `bin/cide-*`, `lib/*`,
      `tests/run.sh` (the POSIX golden master, ~120 assertions) still pass `shellcheck` +
      `sh tests/run.sh` (the coexistence permit must survive the scaffold).
- [ ] The `ctide-json` and `ctide-testkit` crates exist as stubs (homes for grafts
      g4 and g7); a cucumber-rs + proptest dev-dependency harness compiles (home
      for g1) — **without** tripping the no-tokio ban (carved out via `exclude-dev`
      in #36).

### Dependencies / blocked-by

- **Blocked by:** owner go-ahead on the rename ruling (the only open governance
  gate). Nothing else — this item blocks the whole program.
- **Blocks:** #35, #36, #37, #38, and every later phase.

### References

- Roadmap: [`roadmap.md` §3 R0](./roadmap.md) (exit criteria + the repo-location
  ruling box), §7 (dependency view).
- Backbone: [`research/backbone.md`](./research/backbone.md) "R0 — Repo decision +
  Cargo scaffold" (deliverables, exit criteria, the repo-decision box).
- Rebrand map (the mechanical naming table + rename steps):
  [`research/rebrand-repo-strategy.md`](./research/rebrand-repo-strategy.md)
  §1 (naming map), §2 (rename vs fresh-repo), §4 (rename timing).
- Backlog→epics: [`research/backlog-to-epics.md`](./research/backlog-to-epics.md)
  §3 "E0", §6 (repo decision recommendation).
- Design plan (locked crate DAG + dep budget): `docs/vision/design-plan.md` §2.
- In-house template source: `/Users/cmbays/github/crap4rs` (workspace shape:
  `crap-core` library + `crap4rs` binary — the `ctide-core` + `ctide` precedent).

### Discovery (what's unknown that this item must surface)

- **Owner ruling on the rename is not yet given.** The roadmap *recommends* rename
  in place (~120-assertion golden-master permit + strangler coexistence + a settled prior
  decision), but executing the rename is an owner action — this item must stop at
  the go/no-go and not rename unilaterally.
- **Identifier availability is asserted, not proven.** `ctide`, `ctide-core`, …,
  `cmux-terminal-ide`, and `breezy-bays-labs/homebrew-tap` *appear* free (crates.io
  404s, 2026-06-12) but must be re-verified with `cargo publish --dry-run` at
  scaffolding time (authoritative). Surface any collision before locking names.
- **Local-dir rename caveat.** Renaming the local checkout dir orphans the Claude
  project-memory path key. This item must confirm the decision to *defer* the
  local-dir rename and keep the checkout path stable.
- **License ruling (GPL-v3 vs MIT)** affects `deny.toml`'s `[licenses].allow` and
  the public tap — only blocks R5 publish, but surface it now so the allow-list
  isn't churned later (design-plan OQ #8).
- **Q1 user-config-layer location** (one path constant, `~/.config/ctide/`) wants a
  ruling before R1 — surface it here even though it's a one-line change.
- **Q7 golden-master delta adjudication** wants a ruling **before R2** (the backbone
  recon places it there): who signs off an annotated "intended-improvement" delta. It
  is promoted to a hard pre-R2 gate on #37 (the first cutover) — note it now so the
  owner schedules the ruling before the first golden-master cutover, not when it bites.

---

## #35 — Walking skeleton: `ctide doctor` over `MuxTopology` against `FakeMux`, green in CI

**Epic / phase:** E1 / R1. **Appetite:** M (this is the first real slice).
**This is the smallest slice that proves the whole architecture — build it first
after the scaffold.**

### Summary

Implement `ctide doctor` reading *only* through the `Multiplexer` supertrait's
read-only methods (`MuxTopology::tree()` / `capabilities()` / `manifest()`),
proven green against three implementations of the port: **FakeMux** (always),
`CmuxSocketAdapter` over the **recorded replay server** (graft g7), and **live
cmux behind `--ignored`**. `doctor` mutates nothing (zero blast radius) yet
exercises every layer: bin → adapters → `ctide-mux-cmux` → `ctide-core` ports →
`ctide-json` output. It is useful day one — it prints the exact two-layer network
surface (cide's own + the cmux substrate, pillar P7), config-layer provenance
(graft g5), and capability drift (the g7 probe). Getting `doctor` green across all
three impls *is* the proof that "the third impl is the testing story."

### Acceptance criteria (the five-gate definition-of-done)

- [ ] `ctide doctor --json` returns a **`ctide-json`-typed, `schema`-versioned**
      payload (freezes the g4 contract for this verb).
- [ ] `conform_multiplexer(&FakeMux, fixtures)` (the port conformance kit in
      `ctide-testkit`) is **green**.
- [ ] The **same** conformance suite is green against `CmuxSocketAdapter` over the
      **recorded replay server** (g7) — proving the socket adapter, not just the fake.
- [ ] The `~/.config` grep gate + `cargo-deny` (no-tokio / no-HTTP) gates are green
      (the gates land in #36; this verb must pass them).
- [ ] The flow-SLO **hyperfine** harness records `doctor` cold start (the first
      budget data point; not yet a release blocker).
- [ ] `ctide doctor` runs **fully offline** and prints the exact network surface:
      cide's own egress labels (e.g. `gh (defensible-egress, opt-in)`) **and** the
      cmux-substrate section.
- [ ] The `capabilities()` probe diffs live cmux against the pinned fidelity
      snapshot and `doctor` prints any drift (the g7 capability-drift report).
- [ ] The live tier (`--ignored`) is wired (run on main / manual), not run per-PR.

### Dependencies / blocked-by

- **Blocked by:** #34 (the workspace + crate DAG must exist), and #36 for the four
  CI gates the DoD asserts (the two can share a PR arc — see the at-a-glance note).
- **Blocks:** every later verb (they ride the `Multiplexer` port, the `ctide-json`
  contract, and the conformance kit this item stands up).

### References

- Roadmap: [`roadmap.md` §5](./roadmap.md) (the walking skeleton, the five-gate
  DoD verbatim), §3 R1 (exit criteria), §6 (first Rust increment).
- Backbone: [`research/backbone.md`](./research/backbone.md) "The walking skeleton"
  (port + verb + FakeMux + the CI-green definition) and "R1 — Foundations".
- CI/quality (the gates this DoD invokes, conformance tiers 3+4+7):
  [`research/ci-quality-framework.md`](./research/ci-quality-framework.md)
  §4.6 (conformance kit), §4.8 (SLO benches), §7 (8-tier map).
- Design plan: `docs/vision/design-plan.md` §3 (ports + conformance kit), §4 (cmux
  adapter, FakeMux, g7 replay), §9 R1.
- The walking-skeleton detail doc (to be written next, expanding this item):
  `r1-walking-skeleton.md` (per [`roadmap.md` §8](./roadmap.md)).

### Discovery (what's unknown that this item must surface)

- **The exact `Multiplexer` / `MuxTopology` trait shape is not yet pinned** — this
  item *defines* it (object-safe, sync, read-only for `tree`/`capabilities`/
  `manifest`). It must surface whether `manifest()` belongs on the supertrait or on
  a per-adapter `AdapterManifest` carrying the `EgressLabel` (the egress-label gate
  in #36 depends on the answer).
- **The recorded replay server contract (g7)** has no recording yet — this item
  must capture a fixture set from live cmux (`ctide-testkit gen-fixtures` into
  `fidelity/<cmux-version>/`) and decide the replay transport's framing.
- **`ctide-json` versioning policy (Q5)** — this is the first frozen contract;
  surface the schema-version bump rule before agents pin against it.
- **Hyperfine in CI is noisy on hosted runners** — confirm the cold-start
  measurement is *recorded* (data point) here, and only becomes relative-regression-
  *gated* at R4 (so this item doesn't introduce a flaky release blocker prematurely).
- **Live-cmux conformance cadence (Q in CI note §10)** — main-only `--ignored` vs a
  nightly drift run; surface a default.

---

## #36 — CI/quality foundation: the crap4rs-derived gate graph + zero-egress / dep-rule / `~/.config` gates

**Epic / phase:** E0 / R0 (the gate half of E0). **Appetite:** S–M.
**The walking skeleton's definition-of-done IS these gates — so they must be real,
not decorative.**

### Summary

Clone and adapt the CI/quality/release template from `crap4rs`
(`/Users/cmbays/github/crap4rs`) into the renamed workspace: the deterministic CI
job graph (PR / main / release depths, macOS-primary matrix), `deny.toml` (extended
with the zero-egress crate ban + the `exclude-dev` carve-out for cucumber-rs's
dev-only async stack), `lefthook` (the pre-push mirror, lockstep with CI),
`release-plz`, the toolchain pin, the cucumber-rs harness, and **crap4rs itself
adopted as a CRAP gate**. Critically, stand up the *structural trust gates* the
architecture depends on from line one: the dependency-rule check, the dep-budget
(no-tokio/no-HTTP) assertion, the `~/.config` grep gate, and the egress-label lint.
Each must **fail a planted violation** to prove it is live. The existing shell
golden-master gate keeps running unchanged through R1–R5 (coexistence).

### Acceptance criteria

- [ ] The deterministic CI graph runs on **PR depth** (fmt, clippy, msrv, nextest
      on macos-arm + linux-x86, cucumber, coverage→crap, deny, audit, docs,
      `linux-musl-compile`, the structural-trust grep jobs) with
      `concurrency: cancel-in-progress` and least-privilege `permissions`.
- [ ] **Dependency-rule gate fails a planted violation** (`ctide-core` importing
      the bin) — proving the hexagon is mechanically enforced, not decorative.
- [ ] **`cargo-deny` rejects a planted `tokio`/`reqwest` in a *shipped* crate but
      allows it as a `dev-dependency`** — proving the `exclude-dev` scope (the
      no-tokio/no-HTTP zero-egress structural proof).
- [ ] **The `~/.config` grep gate rejects a planted path literal** outside the
      (not-yet-existing) consented `setup` module.
- [ ] The **egress-label lint** asserts every `AdapterManifest` declares an
      `EgressLabel` (deny-by-default), and the **`// fact:` quirk-vault lint**
      asserts cmux facts live only in `ctide-mux-cmux`.
- [ ] `aarch64-unknown-linux-musl` **compiles** in CI from day one (no adapter yet
      — cheap Linux-not-precluded insurance).
- [ ] **crap4rs runs as a CRAP gate**: workspace default preset `15`, `ctide-core`
      overridden to `strict` (`8`) via per-path `crap.toml` override; the gate
      blocks on threshold violations (auto-discovered config, no CLI flags).
- [ ] `lefthook.yml` mirrors the CI commands (lockstep) **and** keeps the unchanged
      shell gate (`shellcheck bin/* lib/*.sh` + `sh tests/run.sh`); a `mirror-drift`
      lint asserts the shell CI job and the lefthook command stay identical.
- [ ] The mdBook + Pages workflow exists but is **held un-triggered** (first publish
      at the end-R2 checkpoint, after the rename).
- [ ] `cargo-dist` skeleton wired (brew-tap target), **not yet publishing**.
- [ ] Every cargo invocation uses `--locked`; `Cargo.lock` is committed; `uses:`
      actions are SHA-pinned and `zizmor` enforces it.

### Dependencies / blocked-by

- **Blocked by:** #34 (needs the crate tree to gate). Lands in the same PR arc as
  #34/#35 — the walking-skeleton DoD (#35) *invokes* four of these gates, so #36
  must be green before #35 can claim done.
- **Blocks:** the five-gate DoD of #35, and every later PR (these gates run on
  every commit).

### References

- Roadmap: [`roadmap.md` §3 R0](./roadmap.md) (exit criteria: planted-violation
  gates, `cargo-deny` exclude-dev, `~/.config` gate, crap4rs CRAP gate, mdBook held).
- CI/quality framework (the full spec this item implements):
  [`research/ci-quality-framework.md`](./research/ci-quality-framework.md) — §2
  (CRAP threshold model), §3 (job graph PR/main/release), §4 (each gate in detail),
  §6 (determinism rules), §8 (starting config sketches: `deny.toml`,
  `.config/nextest.toml`, `crap.toml`, `lefthook.yml`, `release-plz.toml`,
  `setup-rust`).
- Backbone: [`research/backbone.md`](./research/backbone.md) "R0" (the gates as
  deliverables + exit criteria).
- Template source files (copy/adapt verbatim where noted):
  `/Users/cmbays/github/crap4rs/.github/workflows/ci.yml`, `release-plz.yml`,
  `.github/actions/setup-rust/action.yml`, `lefthook.yml`, `deny.toml`,
  `release-plz.toml`, `rust-toolchain.toml`, `clippy.toml`, `crap.toml`.

### Discovery (what's unknown that this item must surface)

- **The full no-tokio/no-HTTP deny list** must be reconciled against the real
  dependency closure once stubs gain bodies — surface any transitive HTTP/async
  crate the design budget didn't anticipate (the `exclude-dev` carve-out may need
  tuning for cucumber-rs's exact async stack).
- **CRAP starting-threshold ratchet (CI note §10 Q1)** — confirm workspace `15` +
  `ctide-core` `strict 8` now, ratcheting the workspace to strict after R4; or born
  strict everywhere with adapter per-path `15` floors.
- **Toolchain pin granularity (Q2)** — specific `1.NN.0` (max determinism) vs
  floating `stable`; this item recommends the pin but must surface the bump cost.
- **The `setup` module doesn't exist yet** — the `~/.config` grep gate must allow
  for its *future* path (consented writes land at R4 / E5); confirm the gate's
  allowlist shape so it doesn't need re-editing when `setup` arrives.
- **macOS-runner broken-rustup** (actions/runner-images#14097) — the `setup-rust`
  composite from crap4rs solves it; surface whether the verbatim copy still applies
  to the pinned toolchain.

---

## #37 — Runner engine: `ctide run` / `ctide run wrap` wrapping the watchexec binary (KEYSTONE A)

**Epic / phase:** E2 / R2. **Appetite:** M (~2 wk). **This is keystone A — the #1
load-bearing investment; the first capability that never existed in shell. It feeds
#2 (review), #9 (fix-on-red), #13 (dbt catalog), #15 (rust cockpit).** It is local
task **#23** realized as a real engine.

### Summary

Ship the runner engine: `ctide run` (catalog-driven one-shot) and `ctide run wrap`
(the foreground watch loop). `run wrap` wraps the **external `watchexec` binary** —
**never** as a library, to preserve the no-tokio budget — driving a red→fix→green
cycle: child stdout → `FailureParser` → on Red, write `state/jobs/<id>.json`, set a
status pill (`set_status`), emit a policy-filtered `notify`, and `flash`; on Green,
clear. It detects a `RunnerCatalog` (just/make/npm/cargo) with a **bacon
fast-path** (`.bacon-locations` artifact parser — the Rule-of-Two seam first
appears here). This is the g2 pull-forward (runner before spaces): zero
golden-master parity burden of its own, immediate daily value, and it
**load-hardens the socket / pipe-pane / state-write paths before the crown jewels
(R3 spaces) ride them.** The end-of-R2 re-approval gate sits right after this.

### Acceptance criteria

- [ ] `ctide run wrap` drives a **red→fix→green** cycle: a runner failure produces a
      structured `Diagnostic` (file:line + artifact path, **never pasted ANSI**) and,
      with `fix_on_red` on, submits it via `prompt_submit`
      (`Agent::submit_prompt` over `workspace.prompt_submit`).
- [ ] The runner wraps the **watchexec binary** (a `cargo metadata` / dep-budget
      assertion proves watchexec-as-library and tokio are **absent** from the
      shipped graph).
- [ ] `RunnerCatalog` detects just / make / npm / cargo; the **bacon fast-path**
      parses `.bacon-locations`.
- [ ] On Red: `state/jobs/<id>.json` written via single `flock` + atomic rename; a
      status pill is set; a policy-filtered `notify` + `flash` fire. On Green:
      cleared.
- [ ] The **g1 hook-storm convergence property** runs in CI against `run wrap`
      (random kill point → restart-from-cursor → end-state converges).
- [ ] **`InjectionGuard` makes a blind `send_text` uncompilable** (a self-heal /
      fresh-spawn round-trip passes against `FakeMux`).
- [ ] The agents-cluster write-verbs that ride this phase
      (`set-role` / `jump` / `open` / `md-open` / `agent new|rename`) pass the
      **golden-master diff** vs their shell twins (empty diff or annotated
      improvement) — the *first* golden-master gate.
- [ ] The **agents state-family is migrated** (g6): a ported verb **refuses to run
      unmigrated** rather than co-writing shell-format state.
- [ ] **g3 binary-version self-check** lands on the long-lived `run wrap` pane
      (exit-for-respawn when the on-disk binary changed post-`brew upgrade`).
- [ ] Flow-SLO hyperfine benches hold for the new hot-path verbs (relative-
      regression gated at release).
- [ ] **🚦 End-of-R2 re-approval gate prepared**: golden-master parity holding +
      runner shipped/dogfooded is presented as the architecture-bet evidence. *The
      program does not advance to R3 (spaces) on its own.*

### Dependencies / blocked-by

- **Hard cross-phase blocked-by:** #35 + #36 (the socket adapter, `ctide-json`,
  conformance kit, and the gates); the R1 `MuxSurfaces` substrate it rides
  (`pipe_pane`, `set_status`, `notify`, `flash`); **and the Q7 ruling below** (the
  golden-master delta-adjudication process must exist *before* the first cutover).
- **Soft within-epic sequencing (sibling E2 slices — interleave, not prerequisites):**
  `ctide state migrate` for the agents family (g6) and the agents-cluster write-verbs
  (`set-role`/`jump`/`open`/`md-open`/`agent new|rename`) are **co-resident E2 work**
  that lands *alongside* the runner, not gates ahead of it — the runner is the spine
  of E2, not a late dependent. A reasonable build order is: #35/#36 → the parser-killer
  ports (#38 + `agent ls`/`statusline`) → the agents-cluster writes ‖ this runner.
- **Pre-R2 ruling required (Q7 — promote from Discovery to a hard gate):** *Owner
  ruling recorded on **who signs off an annotated "intended-improvement" delta** when a
  ported write-verb's op log differs from its shell twin (inline PR review vs a recorded
  decision per delta class) — **before the first golden-master cutover.*** Q7 governs
  whether a ported write-verb may replace its shell twin (the golden-master permit, the
  core safety mechanism); the backbone recon places it "Before R2". Leaving it unowned
  until it "bites" mid-R2 risks stalling the first cutover with no decision process in
  place. **Block the first golden-master cutover on this ruling.**
- **Blocks:** #2 (review), #9 (fix-on-red), #13 (dbt catalog), #15 (rust cockpit) —
  everything that consumes a runner.

### References

- Roadmap: [`roadmap.md` §3 R2](./roadmap.md) (exit criteria, the hard re-approval
  gate), §4 (E2 row), §6 (the `ctide run` first felt-every-session increment).
- Backbone: [`research/backbone.md`](./research/backbone.md) "R2 — Runner +
  guarded writes" (deliverables, exit criteria, the re-approval checkpoint).
- Backlog→epics: [`research/backlog-to-epics.md`](./research/backlog-to-epics.md)
  §1 (keystone graph — #1 feeds #4/#9/#13/#15), §3 "E2".
- Design plan: `docs/vision/design-plan.md` §6 (runner #1, watchexec-binary-not-
  library), §7 (event posture / hooks), §3 (`InjectionGuard`, `MuxSurfaces` ports),
  §8.2 (golden-master permit), §9 R2.
- Shell sources the agents-cluster ports must match (golden master):
  `bin/cide-jump`, `bin/cide-open`, `bin/cide-set-role`, `bin/cide-agent`,
  `bin/cide-md-open`; the `just --list` stub + Dock raw-watchexec line this retires.

### Discovery (what's unknown that this item must surface)

- **The `FailureParser` contract per catalog** is unspecified — cargo/nextest,
  just, npm, and bacon emit different failure shapes. This item must surface a
  parser-per-tool plan and which one is the reference (likely the bacon fast-path).
- **Runner default home (Q3)** — Dock control vs a layout tile. Surface a default
  before wiring the palette.
- **Golden-master delta adjudication (Q7)** — **promoted out of Discovery to a hard
  pre-R2 ruling (see Dependencies / blocked-by above).** This item is the *first*
  place the question bites (the first golden-master gate), so the owner ruling on who
  signs off an "intended-improvement" delta must be recorded *before* the first
  cutover, not discovered when it bites.
- **`fix_on_red` ergonomics** — auto-submit vs one-key confirm; surface the default
  and whether it's per-recipe.
- **g3 respawn semantics on a foreground loop** — how `run wrap` exits and is
  re-`exec`'d without losing the watch cursor; surface the handoff mechanism.
- **Does the runner *need* residency?** If `run wrap` pushes toward a long-lived
  reactor, that pressure-tests the risk-#2 promotion gate early — surface it as
  evidence for the end-of-R2 re-approval, not as a reason to build the daemon.

---

## #38 — First parser-killer port: `ctide theme` behind the golden master

**Epic / phase:** E1 / R1. **Appetite:** S. **The gentlest strangler cutover — a
read-mostly verb that kills two live hygiene bugs and exercises the golden-master
"permit" for the first real port.** Good "second Rust verb" after the walking
skeleton.

### Summary

Port `bin/cide-theme` to `ctide theme` behind the golden master, replacing the
worst hand-rolled parser site (awk-TOML) with a typed reader and replacing the
direct `~/.config/ghostty` write with a typed `ApplyPlan` over a `ThemeTarget`
port that makes the `~/.config` write **unrepresentable**. This retires the two
standing hygiene violations (the `~/.config/ghostty` write #9 and the tracked-file
churn #10) and is the first verb to ride the golden-master diff discipline at zero
blast radius. (Its siblings `ctide agent ls` and `ctide statusline` follow the same
pattern and can be folded in or split as separate items.)

### Acceptance criteria

- [ ] `ctide theme` produces a themed result with **zero `~/.config` writes** (the
      grep gate from #36 stays green) and **no tracked-file churn**.
- [ ] The `~/.config` write is **unrepresentable**: the `ThemeTarget` port + typed
      `ApplyPlan` make a direct `~/.config/ghostty` write uncompilable, not merely
      linted away.
- [ ] `ctide theme`'s emitted ops **diff clean** against the `bin/cide-theme` shell
      twin on the shared fixture topology (empty diff or annotated intended
      improvement — the golden-master permit).
- [ ] The TOML read goes through a typed reader (kills the awk-TOML parser site),
      with a `// fact:` + fixture test for any cmux/ghostty quirk it encodes.
- [ ] The shell `bin/cide-theme` grows the strangler preamble
      (`command -v ctide && [ -z "$CTIDE_SHELL" ] && exec ctide theme`); `CTIDE_SHELL=1`
      is verified as instant rollback.

### Dependencies / blocked-by

- **Blocked by:** #35 (the binary skeleton, the `Multiplexer` adapter, the
  conformance kit) and #36 (the `~/.config` grep gate + golden-master harness).
- **Blocks:** nothing hard, but it de-risks the agents-cluster write-verb ports that
  #37 depends on (same golden-master discipline, higher stakes).

### References

- Roadmap: [`roadmap.md` §3 R1](./roadmap.md) (the parser killers, zero
  `~/.config` writes, theme exit criterion).
- Backbone: [`research/backbone.md`](./research/backbone.md) "R1 — Foundations"
  (parser killers; retires #9/#10 via typed `ApplyPlan`).
- Backlog→epics: [`research/backlog-to-epics.md`](./research/backlog-to-epics.md)
  §3 "E1" (strangler-reuse of `bin/cide-theme`), §7 (net-new vs reuse ledger).
- Design plan: `docs/vision/design-plan.md` §3 (`ThemeTarget` port makes `~/.config`
  writes unrepresentable), §8.2 (golden master), §9 R1.
- Shell source to port (golden-master twin): `bin/cide-theme`.

### Discovery (what's unknown that this item must surface)

- **The exact `ThemeTarget` port boundary** — what theme write paths are *legitimate*
  (project-local, `.cmux/`) vs forbidden (`~/.config`). Surface the allowed-target
  set so the port's type signature can forbid the rest.
- **Golden-master normalization rules** — how to normalize the op log (timestamps,
  uuids, path ordering) so the theme diff is stable. This is the first verb to
  exercise the normalizer; surface gaps.
- **Tracked-file churn source** — confirm exactly which tracked files `cide-theme`
  currently churns (#10) so the typed `ApplyPlan` provably eliminates it.
- **Whether `agent ls` + `statusline` fold in here or split** — they share the
  parser-killer pattern (versioned shell-format readers, unmigrated families); surface
  the sizing call so this stays an S item.

---

## How these work items tie back to the program

- **#34** lands the tree + the rename — E0's structural half. **Nothing compiles
  without it.**
- **#36** lands E0's gate half — the gates the rest of the program runs on. #34 + #36
  together complete **E0 / R0**.
- **#35** is the walking skeleton — E1's spine, the first **value-bearing** slice,
  and the proof that every layer (bin → adapter → port → contract crate → CI gate)
  holds end to end with zero blast radius.
- **#38** is the first real strangler cutover (E1) — gentle, read-mostly, kills two
  live hygiene bugs, and rehearses the golden-master permit before higher-stakes ports.
- **#37** is keystone A (E2 / R2) — the first never-had capability, the load-hardener
  for the crown-jewel paths, and the work that earns the **end-of-R2 re-approval gate**.
  It is **~8th in true start order** (the R1 parser-killers + agents-cluster writes +
  `state migrate` land between #38 and it); it is listed up front as the *target the
  R0–R1 spine builds toward*, not the immediately-next item.

After #37 passes that gate, the program proceeds to R3 (spaces — the crown jewels,
epic E4), then R4 (the Rust-only review loop, E5/E6), then R5 (the dbt recipe + v1
close, E7). The full backlog→epics mapping, keystone graph, and net-new-vs-reuse
ledger live in [`research/backlog-to-epics.md`](./research/backlog-to-epics.md); the
phase contract is [`roadmap.md`](./roadmap.md).

---

*First-issues complete. Start at #34 (pending owner go on the rename), then the
#35/#36 walking-skeleton arc, then #38 (first cutover), then #37 (keystone A). Each
honors daemonless + no-tokio + zero-egress + never-write-`~/.config` + rename-in-
place, with every constraint mechanically gated from line one.*
