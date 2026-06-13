# CI + Quality/Testing Framework — the ctide Rust workspace

> The deterministic CI job graph and the 8-tier quality/testing model for
> **cmux-terminal-ide** (binary `ctide`), born "ctide" from crate one while the
> POSIX-sh `cide` dogfood is **strangled, not renamed**. This is the canonical
> build spec for **E0** (R0 — scaffold + CI/quality foundation): the gates stand
> up *before any verb is ported*, so R1's first port lands into a structure that
> already says "no" to tokio, HTTP, `~/.config` writes, and manifest-less
> adapters. It is adapted from the owner's own proven template,
> [crap4rs](https://github.com/breezy-bays-labs/crap-rs)
> (`/Users/cmbays/github/crap4rs`), and maps every gate to the 8 testing tiers in
> [`docs/vision/design-plan.md`](../vision/design-plan.md) §8 and the
> socket-adapter / FakeMux contract in §4.
>
> **Where it sits in the roadmap.** This doc is the §8 detail behind
> [`roadmap.md`](./roadmap.md): R0/E0 stands up everything here; R1/E1 proves the
> [walking skeleton](./r1-walking-skeleton.md) green against the five-gate
> definition-of-done; R2–R5 each ship their verbs *into* these gates with the
> shell golden-master gate running in lockstep until R5 retires it. Conforms to
> the daemonless decision, zero-egress/local-first, never-write-`~/.config`,
> no-tokio, and the `cmux-terminal-ide`/`ctide` rebrand throughout. 2026-06-12.

---

## 0. Sources

**Template (read in full):** `/Users/cmbays/github/crap4rs/.github/workflows/ci.yml`,
`release-plz.yml`, `quick-start-smoke.yml`, `.github/actions/setup-rust/action.yml`,
`lefthook.yml`, `deny.toml`, `release-plz.toml`, `rust-toolchain.toml`, `rustfmt.toml`,
`clippy.toml`, `crap.toml`, `crap.example.toml`, `README.md` (the CRAP formula + threshold
model).

**Roadmap spine:** [`roadmap.md`](./roadmap.md) — R0/E0 exit criteria (§3),
the walking-skeleton five-gate DoD (§5), the dependency view (§7), the §8 doc index.
This framework is the buildable expansion of the CI/quality bullet in each.

**Design inputs:** [`design-plan.md`](../vision/design-plan.md) §2 (crate layout +
dependency budget), §3 (ports + conformance kit), §4 (cmux adapter, transports, FakeMux, g7
replay), §8 (8-tier testing), §9 (R1–R5 strangler), §10 (cargo-dist distribution), §11
(risk register), §12 (open questions). Existing strangler gate: this repo's
`.github/workflows/ci.yml` (`gate` job: shellcheck + `tests/run.sh`) and `lefthook.yml` (the
lockstep pre-push mirror). Golden master: `tests/run.sh` (~120 assertions on emitted cmux
commands — [`docs/vision/research/cide-current-state.md`](../vision/research/cide-current-state.md)
§15/§4; the R5 conversion target is the full set as it stands at conversion time,
[`roadmap.md`](./roadmap.md) §3 footnote).

**Web best-practice checks (June 2026):**
[cargo-llvm-cov + nextest coverage](https://nexte.st/docs/integrations/test-coverage/),
[nextest retries/flaky + CI profile](https://nexte.st/docs/features/retries/),
[cargo-audit vs cargo-deny](https://blog.logrocket.com/comparing-rust-supply-chain-safety-tools/),
[hyperfine in CI](https://github.com/sharkdp/hyperfine/discussions/741),
[cucumber-rs harness=false](https://cucumber-rs.github.io/cucumber/current/quickstart.html),
[Swatinem/rust-cache + `--locked`](https://github.com/Swatinem/rust-cache),
[corrode: faster Rust CI](https://corrode.dev/blog/tips-for-faster-ci-builds/),
[cargo-dist 0.32 (May 2026)](https://github.com/axodotdev/cargo-dist/releases).

---

## 1. Design principles (inherited, non-negotiable)

These constrain every choice below; where a 2026 best practice collides with a constraint,
**the constraint wins** ([`roadmap.md`](./roadmap.md) §2 principle 8). They are why the
gates are what they are.

1. **Zero-egress / local-first.** CI may use `gh` and crates.io (advisory DB, OIDC publish),
   but the *product's tests* hit no network. `cargo-deny` proves the shipped binary's dep
   graph carries no HTTP client (design-plan §2, §8.8). No Codecov, no telemetry uploads —
   coverage stays an in-CI artifact feeding crap4rs, never an external SaaS.
2. **Lightweight single binary, no tokio.** The dependency budget (`clap`, `serde`,
   `serde_json`, `toml`, `thiserror`, `jiff`, `uuid` no-default, `rustix`, `url`, `objc2`
   macOS-only) is a *quality gate*, not a guideline (risk #4). The runner wraps the
   **external watchexec binary, not the library** (design-plan §6) precisely so this holds.
   cucumber-rs's async stack is dev-only and carved out via `exclude-dev`.
3. **macOS-first, Linux-not-precluded.** The product needs macOS (`ctide-place-macos` via
   objc2; `tests/run.sh` has darwin assumptions). CI is therefore a **macOS-primary**
   matrix, with a `*-linux-musl` target continuously *compiled* from day one as cheap
   insurance keeping Linux unprecluded (design-plan §10; roadmap R0 exit criteria). **Cross-
   compile caveat:** the musl compile needs both `rustup target add` (the `setup-rust`
   `targets:` input) *and* a cross-linker; for the cheap-insurance reading,
   `x86_64-unknown-linux-musl` (native on the x86 runner, only `musl-tools`) suffices and the
   aarch64-musl cross-link can wait for a real Linux mux adapter (§3.1, §3.3; r1-walking-
   skeleton §1.7).
4. **NEVER writes `~/.config`.** A grep gate (tier 8) rejects `~/.config` path literals
   outside the consented `setup` module — enforced in CI and pre-push. `ctide setup` is the
   *only* path that may write a global file, and the config-writer module takes a `Consent`
   token only `setup` can construct (design-plan §5).
5. **Determinism is structural.** Pinned toolchain, `--locked` everywhere, frozen
   version-stamped fixtures, no network in tests, no wall-clock or random ordering in
   asserted output. Determinism rules are §6.
6. **Solo-maintainer economy (risk #5).** Every gate must pay for itself on a one-person
   team. Cheap fast gates run per-PR; expensive gates (full mutation, full conformance
   against live cmux, full convergence sweeps) run per-merge or `--ignored`/release — exactly
   the crap4rs cadence split (per-PR `view.rs` mutants vs per-merge walker mutants, ci.yml
   `if: github.event_name == 'push'`).
7. **Born ctide, strangler-coexistent.** The Rust gates are born under the `ctide-*` crate
   names; the shell golden-master gate keeps running unchanged in the *same repo* (the
   reason for rename-in-place, §9) until R5 retires it. Both generations green is the
   strangler permit.

---

## 2. The CRAP gate adopted from crap4rs (the threshold model)

crap4rs computes, per function, `CRAP(c, cov) = c² × (1 − cov)³ + c` (README). The gate
fires when a function's CRAP exceeds a threshold; presets align to risk-tier boundaries:

| preset | cognitive / cyclomatic cutoff | risk boundary |
|---|---|---|
| `--strict` | 8 | Low → Acceptable |
| default | 15 | Acceptable → Moderate |
| `--lenient` | 25 | Moderate → High |

**Adoption decision for ctide.** ctide is a brand-new Rust codebase whose hexagon
(`ctide-core`) is *designed* pure and low-complexity (sync, object-safe, no I/O). It should
be held high. But "born strict" on a workspace under active strangler construction risks the
gate being a constant red wall during R1–R3. The crap4rs precedent resolves this: crap4rs
gates its *production* source at `strict` (8) via root `crap.toml` `preset = "strict"`
(crap.toml L15), and the config schema supports per-path threshold overrides to hold the
domain core tighter than adapters.

**ctide starting threshold** (matches [`roadmap.md`](./roadmap.md) §8 — "default 15,
`ctide-core` strict 8"; config sketch in §8):

- **Workspace default: `default` (15).** The honest starting line for a strangler-built
  workspace; it will not flake-red on R1 scaffolding.
- **`ctide-core/src/**`: override to `strict` (8).** The hexagon is the asset; it stays in
  the Low risk band by construction. This is a mechanically-enforced per-path override, not a
  code comment.
- **`ctide-mux-cmux/src/wire.rs` + adapters: stay at default (15).** Wire parsing and
  capability probing carry irreducible branchiness; holding them to 8 would punish the quirk
  vault for doing its job.
- **Ratchet plan.** Once R4 lands and the core stabilizes, propose tightening the workspace
  default to `strict` and giving adapters their own per-path 15 floor — a single `crap.toml`
  edit, reviewable as one diff. Recorded as open question #1 (§10).

The gate is **unshapeable**: `result.passed` always ranges over the full codebase;
`--top`/`--only-failing` only shape the *displayed* report (the `[views.ci]` preset in
crap.toml L75 is a report-shaping reference, not a gate). ctide consumes crap4rs exactly as
crap4rs dogfoods itself — `crap4rs` with **no analysis flags**, letting repo-root `crap.toml`
own `preset`, `metric = "cognitive"` (under `[language.rust]`, crap.toml L67 — *never*
top-level, or a crap4ts discovery would error), `src = [crate roots]`, and the per-path
overrides, all via auto-discovery. `gate-mode: gate-on-analysis` blocks the PR on threshold
violations; a `--delta-gate` against the main baseline (§3.2) blocks *new* violations even
when the absolute set is already over.

---

## 3. The CI job graph (PR vs main vs release)

Three triggers, three depths. The shape mirrors crap4rs (`on: push:[main] + pull_request`
with `concurrency: cancel-in-progress`) but the matrix is **macOS-primary** (constraint 3),
inverting crap4rs's Linux-primary default.

```yaml
# .github/workflows/ci.yml (sketch — the E0 deliverable)
name: CI
on:
  pull_request: { branches: [main] }   # PR depth   — fast; every cheap+deterministic gate
  push:         { branches: [main] }    # main depth — PR depth + the expensive periodic gates
  # (tag / release-plz merge)           # release    — main depth + SLO blockers + cargo-dist
concurrency: { group: ci-${{ github.ref }}, cancel-in-progress: true }
permissions: { contents: read }         # least privilege; per-job elevation only where needed
```

Every `uses:` is SHA-pinned with a version comment, and `zizmor` enforces it (§6 rule 7).
Every job runs the `setup-rust` composite ported verbatim from crap4rs (§8) — it is the
single highest-value copy, solving the macOS broken-rustup problem this matrix hits
immediately.

### 3.1 PR depth — every push to a PR (must stay minutes, not tens of minutes)

Parallel, fail-fast-independent jobs (crap4rs structure). All cargo invocations carry
`--locked`.

| job | command (essence) | runner | gate |
|---|---|---|---|
| `fmt` | `cargo fmt --all --check` | ubuntu | block |
| `clippy` | `cargo clippy --workspace --all-targets --locked -- -D warnings` | ubuntu | block |
| `msrv` | `cargo +<pin> check --workspace --all-targets --locked` | ubuntu | block |
| `test` (matrix) | `cargo nextest run --workspace --all-targets --locked --profile ci` | **macos-arm primary** + linux-x86 | block |
| `cucumber` | `cargo test --test <feature-suite>… --locked` (harness=false targets) | macos-arm | block |
| `coverage` | `cargo llvm-cov nextest --workspace --locked --lcov --output-path lcov.info` + upload artifact | ubuntu | artifact only |
| `crap` | download `lcov`, stage the **version-pinned** `crap4rs` binary (`cargo install crap4rs --version =X.Y.Z --locked`, §4.4), run `crap4rs` (config from `crap.toml`), `gate-mode: gate-on-analysis` + `--delta-gate` | ubuntu | **block** (the CRAP gate) |
| `deny` | `cargo deny check` (advisories + licenses + bans + sources) | ubuntu | block |
| `audit` | `cargo audit --deny warnings` (RustSec, focused 2nd opinion) | ubuntu | block |
| `docs` | `RUSTDOCFLAGS=-D warnings cargo doc --workspace --no-deps --locked` | ubuntu | block |
| `linux-musl-compile` | `cargo build --workspace --locked --target <musl-target>` — **pass `targets: <musl-target>` to `setup-rust` AND supply a cross-linker** (zigbuild/`cross`, or prebuilt `aarch64-linux-musl-cross` + `CARGO_TARGET_*_LINKER`); or run `x86_64-unknown-linux-musl` natively with only `musl-tools` for the cheap "Linux-not-precluded" variant — `musl-tools` is x86-only and does NOT satisfy an aarch64 cross-link (see r1-walking-skeleton §1.7 musl note) | ubuntu | block (compile-only) |
| `egress-labels` | grep gate: every `AdapterManifest` declares an `EgressLabel` | ubuntu | block |
| `no-config-write` | grep gate: no `~/.config` literal outside `setup` | ubuntu | block |
| `dep-budget` | `cargo metadata` assertion: no tokio / no HTTP client in shipped graph | ubuntu | block |
| `dependency-rule` | assert `ctide-core` depends on nothing in-workspace; bin depends on all; nothing depends on bin | ubuntu | block |
| `quirk-vault` | grep lint: every `// fact:` cmux fact lives only in `ctide-mux-cmux`, with a fixture test | ubuntu | block |
| `strangler-gate` | shellcheck `bin/* lib/*.sh install.sh tests/*.sh` + `sh tests/run.sh` | **macos** | block (during coexistence, §5) |
| `mirror-drift` | lint: the shell CI job and its lefthook command stay identical | ubuntu | block |
| `zizmor` | `pipx run 'zizmor>=1.5,<2' .github/` (workflow supply-chain) | ubuntu | block |
| `conformance` | conformance kit over **fakes** + **replay server** (g7) — runs *inside* `test`/`cucumber` | (in those jobs) | block |
| `lint-*` (python) | `tracked:`-exclusion lint, BDD-status-tag lint, `// fact:` lint | ubuntu | block |

> **macOS-minute economy (honors §1 principle 6 mechanically, not just by assertion).**
> Inverting crap4rs's matrix to macOS-primary is correct for a macOS-first product, but
> macOS runners cost ~10× ubuntu minutes and run slower — a real cost on a solo-founder
> budget. The split above already routes the cheap gates (fmt/clippy/deny/audit/docs/the
> grep-lints/`linux-musl-compile`) to **ubuntu** and only `test`/`cucumber`/`strangler-gate`
> to **macOS**. To stop doc-only or shell-only PRs from burning macOS minutes, **gate the
> macOS `test` + `cucumber` jobs behind a `changes`-filter** (run only when Rust files
> change, exactly crap4rs's `needs.changes.outputs.rust` pattern); the `strangler-gate`
> (macOS) is itself naturally scoped to shell PRs. **Intended ceiling:** per-PR macOS time
> is one arm `test` + `cucumber` run on Rust-touching PRs only; everything else stays on
> ubuntu. State the filter in the E0 workflow so the economy principle is enforced, not
> merely asserted.

### 3.2 main depth — push to main (PR depth PLUS the periodic deep gates)

Too slow per-PR on a solo team — crap4rs gates its walker mutants per-merge for exactly this
reason (ci.yml L334 `if: github.event_name == 'push'`).

| job | what | cadence rationale |
|---|---|---|
| `mutants` | `cargo mutants` on the highest-leverage pure-core files (the layout compiler, config merge, `wire.rs` parsers) | per-merge; mutation is the deep behavioral net, proptests are the per-PR net |
| `conformance-live` | conformance kit against a **live cmux in a sacrificial scratch window**, `--ignored` tier (design-plan §3) | fidelity generation + drift detection; needs a real cmux, can't run on hosted Linux |
| `crap-baseline-publish` | run crap4rs, write the analysis envelope as the delta baseline (crap4rs `publish-production-report` pattern) | main is the baseline every PR's `--delta-gate` diffs against |
| `test` (full matrix) | add macos-x86 (`macos-15-intel`) to the matrix | per-PR runs arm only; main proves both darwin arches |

### 3.3 release depth — tag / release-plz merge (main depth PLUS blockers + build)

| job | what | gate |
|---|---|---|
| `slo-bench` | hyperfine flow-SLO benches (tier 7) — **release blocker** | **block release** on regression |
| `crash-replay` | g1 convergence property tests at full sample count (tier 5) | block |
| `cargo-dist` | per-arch darwin artifacts (aarch64 + x86_64) + brew formula; musl built but unshipped | block |
| `release-plz` | OIDC trusted publish of crates (`ctide-json` first; `ctide-core`; testkit if published) + per-crate tags | block |

The SLO benches are deliberately **not** per-PR: 10 ms-scale absolutes flake on hosted
runners (design-plan §8.7). They gate the release the way correctness does (P6). The
crash-replay convergence properties run a small randomized sample per-PR (cheap) and the full
sweep at release.

> **R0/E0 acceptance for the job graph.** Per [`roadmap.md`](./roadmap.md) R0 exit criteria,
> E0 is "done" when: `cargo build/test --workspace` is green on the empty 8-crate skeleton on
> aarch64-darwin **and** aarch64-linux-musl (compile-only); the `dependency-rule` gate
> *fails a planted violation* (core importing the bin); `cargo-deny` rejects a planted
> `tokio`/`reqwest` in a shipped crate but allows it as a dev-dep; the `no-config-write` gate
> rejects a planted `~/.config` literal; `crap` runs as a CRAP gate; and the mdBook + Pages
> workflow exist (held un-triggered). The first *value-bearing* CI run is R1/E1's walking
> skeleton (§5 of the roadmap; [`r1-walking-skeleton.md`](./r1-walking-skeleton.md)).

---

## 4. Each quality gate, in detail (command · pass criteria · starting threshold)

### 4.1 fmt — `cargo fmt --all --check`
crap4rs runs this both pre-commit (`*.rs` glob) and pre-push + CI. `rustfmt.toml` carries
`edition = "2024"` (verbatim crap4rs). **Pass:** no diff. **Threshold:** none — binary.

### 4.2 clippy — `-D warnings`, all targets
`cargo clippy --workspace --all-targets --locked -- -D warnings` (crap4rs ci.yml). The
no-tokio/no-HTTP bans are *also* encoded as workspace lints where expressible (risk #4
mitigation, design-plan §11), so a forbidden import fails clippy, not just `dep-budget`.
`clippy.toml` seeds `cognitive-complexity-threshold = 15` (verbatim crap4rs) — a cheap
early-warning that front-runs the CRAP gate. **Pass:** zero warnings. **Threshold:** the
clippy cognitive-complexity floor 15 mirrors the workspace CRAP default.

### 4.3 nextest — the unit/integration runner
`cargo nextest run --workspace --all-targets --locked --profile ci`. The CI profile
(`.config/nextest.toml`, §8) sets **bounded retries + `fail-fast = false` + deterministic
output** per the [nextest CI guidance](https://nexte.st/docs/features/retries/).
**Determinism caveat:** retries mask flakes; ctide's posture is **retries = surface, never
silently pass** — a retried-then-passed test is *reported* (`status-level = "retry"`) and
treated as a bug to fix, not a green. cucumber-rs `harness = false` targets bypass libtest's
`--list` probe, so nextest **excludes** them via `.config/nextest.toml` and they run via
`cargo test` in a separate `cucumber` job — verbatim the crap4rs split (ci.yml L88–99,
lefthook L168). **Pass:** all tests green, zero retried-passes silently accepted.

### 4.4 coverage → crap4rs (the CRAP gate) — how lcov is produced and fed
Two jobs, crap4rs's exact shape — **this is the concrete crap4rs integration:**

- **`coverage`:** `cargo llvm-cov nextest --workspace --locked --lcov --output-path lcov.info`,
  uploaded as the `lcov` artifact (crap4rs ci.yml L214: `cargo llvm-cov nextest --workspace
  --exclude crap-examples --lcov --output-path lcov.info`; ctide's analog excludes
  `ctide-testkit`). `rust-toolchain.toml` adds `llvm-tools-preview` (verbatim crap4rs). Per
  the [nextest coverage docs](https://nexte.st/docs/integrations/test-coverage/), doctests
  are a separate `--no-report --doc` pass merged in `report` **only if** ctide ships doctests
  (needs nightly); for a binary-heavy workspace this is optional and gated behind "do we have
  doctests yet" (open question #3, §10).
- **`crap`:** download the `lcov` artifact, stage a **version-pinned** `crap4rs` binary
  (see the pin decision below), and run it with **no analysis flags** so repo-root
  `crap.toml` owns `preset`/`metric`/`src`/overrides (crap4rs's config dogfood, ci.yml
  `scorecard-production` pattern). `gate-mode: gate-on-analysis` blocks the PR on threshold
  violations; `--delta-gate` against the main baseline (§3.2) blocks *new* violations even
  when the absolute set is already over. **Zero-egress:** the lcov never leaves CI — no
  Codecov, no upload service; the artifact is consumed only by the in-CI `crap` job.

  > **Pin decision (resolves the either/or — wire one path, not a choice).** crap4rs is the
  > owner's own crate, **published to crates.io**, so the gate consumes the *published*
  > crate: `cargo install crap4rs --version =X.Y.Z --locked` (the exact version pinned at
  > E0, bumped deliberately) — **not** an unpinned `cargo install crap4rs`, which would
  > violate the determinism posture the rest of this framework enforces (§6). The pinned
  > `crap4rs` version joins the determinism-rule list (§6.1) alongside `MDBOOK_VERSION` and
  > the toolchain pin. (Building crap4rs from a git SHA is the alternative if a fix is
  > needed ahead of a release; default to the crates.io pin.)

**Pass:** `crap4rs` exits 0 — no function over its (per-path) threshold; `--delta-gate` finds
no regression vs the main baseline. **Starting threshold:** workspace 15, `ctide-core` 8 (§2).

### 4.5 cargo-deny + cargo-audit (use both — the 2026 recommendation)
Per [the comparison](https://blog.logrocket.com/comparing-rust-supply-chain-safety-tools/),
run both: `cargo-deny` for advisories + licenses + bans + sources (the supply-chain
*policy*), `cargo-audit --deny warnings` as the focused RustSec second opinion. `deny.toml`
(§8) is adapted from crap4rs (verbatim `[advisories]`, `[sources]`, `[licenses]` allow-list
shape) with **the zero-egress ban added**: `[bans].deny` lists HTTP-client and async-runtime
crates (`tokio`, `reqwest`, `hyper`, `isahc`, `ureq`, `surf`, `async-std`, `smol`) scoped to
the **shipped binary's normal graph** via `exclude-dev`, so cucumber-rs's dev-only async
stack does not trip it (design-plan §2, §8.6). This is the structural zero-egress proof.
**Pass:** `cargo deny check` and `cargo audit` both exit 0. **Threshold:** the deny-list is
the threshold — any listed crate in the shipped graph fails.

### 4.6 conformance kit (tiers 3 + 4)
The port conformance suites (`ctide-testkit`) run inside the `test`/`cucumber` jobs: against
every **fake** always (`conform_multiplexer(&FakeMux, fixtures)`), against the **recorded
replay server** for `CmuxSocketAdapter` (g7), and against a **live cmux** behind `--ignored`
only on main / manual (design-plan §3, §4). Fixtures are **generated from real cmux, never
hand-authored** (G1 mandate), stored under `fidelity/<cmux-version>/` via `ctide-testkit
gen-fixtures`. A `conformance-fixtures-fresh` lint asserts the fixture set matches a pinned
cmux version, so drift surfaces as a failed gate, not a silent stale pass. **Pass:** the
generic per-port suites green against fakes (per-PR) and the replay server (per-PR); live
tier green per-merge. This is the walking skeleton's gates 2 + 3 ([`r1-walking-skeleton.md`](./r1-walking-skeleton.md)).

### 4.7 property tests (tiers 1 + 5)
Pure-core proptests (every layout preset × binding → valid plan; 5-layer config merge) run in
`test` per-PR. The g1 **crash-replay convergence** properties (random kill point *k* →
restart from cursor → assert end-state convergence; 50-parallel hook-storm of `policy` ×
`turn-complete` × `run wrap`) run a **small sample per-PR** (cheap, catches obvious
regressions) and the **full sweep at release** (tier 5, design-plan §8.5). proptest runs with
a **fixed seed in CI** for reproducibility; the failing seed is printed for local replay
(determinism rule §6.5). **Pass:** no shrunk counterexample; convergence holds across all
sampled kill points. **Threshold:** per-PR sample count is small (speed); release sweep is
the canonical 50-way storm.

### 4.8 SLO benches (tier 7 — release blocker)
hyperfine, against FakeMux + recorded socket latencies (never a live cmux — non-deterministic):
**cold start < 10 ms, `ctide jump --dry` < 30 ms, space-switch sub-second** (design-plan
§8.7, §4). Methodology per [hyperfine-in-CI](https://github.com/sharkdp/hyperfine/discussions/741):
shared hosted runners are noisy, so the gate is **relative regression vs a pinned reference
binary compiled and timed in the same job**, with `--warmup` and a stated tolerance; the
absolute budgets are asserted with warmup + tolerance and are authoritative only on the
release machine. `--min-runs` ≥ 10 (50+ for high-variance paths). A regression fails the
release exactly like a correctness failure (P6, risk #4). The walking skeleton's gate 5
records `doctor` cold start as the first budget point ([`r1-walking-skeleton.md`](./r1-walking-skeleton.md)).
**Pass:** no path regresses beyond tolerance vs the reference binary; absolutes hold on the
release machine. **Threshold:** the numeric budgets above; relative tolerance stated per path.

### 4.9 structural trust gates (tier 8)
Cheap grep/metadata jobs — the load-bearing constraint enforcement, sub-second, no toolchain,
mirrored into `lefthook.yml` so they fail at `git push`, not in CI (exactly crap4rs's
`bdd-tracked-lint` / `config-discovery-lint` / `ast-purity` family):

- **`egress-labels`:** every `AdapterManifest` declares an `EgressLabel` (deny-by-default).
- **`no-config-write`:** reject `~/.config` literals outside the `setup` module (constraint 4).
- **`dep-budget`:** `cargo metadata` assertion — shipped graph carries no tokio / no HTTP
  client (mirrors crap4rs's `ast-purity` direct-dep `cargo metadata --no-deps` pattern,
  ci.yml).
- **`dependency-rule`:** assert the crate DAG (core depends on nothing in-workspace; bin
  depends on all; nothing depends on the bin) — the hexagon enforced mechanically, the analog
  of crap4rs's `ast-purity` keeping `crap-core` AST-library-pure.
- **`quirk-vault`:** every cmux fact lives in `ctide-mux-cmux` with a `// fact:` comment + a
  fixture test, and **nowhere else** (design-plan §4) — a grep lint that the quirk vault is
  not leaking into core or the binary.

**Pass:** each grep/metadata assertion exits 0. **Threshold:** a single planted violation
must turn each gate red (the R0 acceptance test, §3).

---

## 5. Coexistence: the shell golden-master gate during the strangler

The existing `gate` job (shellcheck + `sh tests/run.sh`, ~120 assertions on emitted cmux
commands) and its `lefthook.yml` pre-push mirror **keep running unchanged** through R1–R5.
The rule the repo already documents — *"keep the two files in lockstep; any change touches
BOTH atomically"* (ci.yml header, lefthook header) — is preserved and extended to the Rust
gates: the Rust CI and the Rust pre-push are also lockstep mirrors (crap4rs's own discipline,
lefthook L1–10). **Both generations green is the strangler permit.**

**How the golden master becomes the strangler permit (tier 2, design-plan §8.2, §9):**

1. The shell `gate` is the inherited behavioral spec and runs **every PR until R5 deletes the
   shell bodies**. It is **never weakened** to let a Rust port through.
2. Each migrated verb (R2→R3) gets a **golden-master parity test in the Rust workspace**: run
   the verb against `FakeMux` on the *same fixture topology* the shell suite uses, normalize
   the recorded op log, and diff it against the shell suite's asserted commands. **The verb
   may not replace its shell twin until the diff is empty OR every delta is an annotated,
   intended improvement** (design-plan §8.2; delta adjudication is design-plan open question
   #7 — who signs off a delta).
3. The strangler preamble (`command -v ctide && [ -z "$CTIDE_SHELL" ] && exec ctide <verb>`)
   means `CTIDE_SHELL=1` is instant rollback (design-plan §9). CI runs **both generations**:
   the shell `gate` proves the shell still works; the Rust `test` + `cucumber` + `crap` jobs
   prove the port matches. g6 (per-state-family migration) guarantees no state file is
   co-written, so the two CI generations never corrupt each other.
4. At **R5**, `tests/run.sh` converts to cucumber `.feature` files (design-plan §9, roadmap
   E7 exit criteria: "the converted cucumber suite passes the full POSIX golden-master
   assertion set" — ~120 emitted-command assertions, re-counted at conversion time, never
   fewer); the shell `gate` job retires, and the `strangler-gate` +
   `mirror-drift` rows drop out of the job graph. Until then they are first-class required
   checks.

A `mirror-drift` lint (Python, like crap4rs's `config-discovery-lint`) asserts the shell CI
job and the lefthook shell command stay identical — the lockstep rule mechanically enforced.

---

## 6. Determinism rules

The framework is "deterministic CI" only if these hold. Each is a gate or a structural fact.

1. **Pinned toolchain.** `rust-toolchain.toml` pins `channel` + `components` (crap4rs pins
   `channel = "stable"` + `clippy`, `rustfmt`, `llvm-tools-preview`). For ctide, prefer
   pinning to a **specific stable version** (e.g. `1.NN.0`) rather than the floating `stable`
   channel, so a new stable release cannot flip CI between identical commits (open question
   #2, §10). An `msrv` job at the declared `rust-version` with `--all-targets` (crap4rs's
   `cargo +1.93 check --workspace --all-targets`, lefthook L144) catches dev-dep MSRV breaks
   — cucumber-rs's async stack has a real MSRV floor (crap4rs notes cucumber 0.22 needs 1.88).
   **Pinned CI tooling.** The same discipline binds the *tools* the gates invoke, not just
   the toolchain: the **`crap4rs` gate binary is version-pinned** (`cargo install crap4rs
   --version =X.Y.Z --locked`, §4.4), `MDBOOK_VERSION` is pinned (product-docs-plan §3), and
   every `uses:` is SHA-pinned (rule 7). An unpinned `cargo install` of any gate tool is a
   determinism violation — a new release could flip CI between identical commits.
2. **Locked deps.** `--locked` on **every** cargo invocation (build, check, test, clippy,
   doc, llvm-cov). `Cargo.lock` is committed (it is a binary-shipping workspace). The
   [Cargo.lock determinism contract](https://github.com/Swatinem/rust-cache) is the whole
   point: identical inputs → identical dependency builds.
3. **No network in tests.** Enforced two ways: (a) `cargo-deny` proves no HTTP client is in
   the shipped graph; (b) tests use `FakeMux` / the recorded replay server, never a live
   socket, except the explicitly `--ignored` live tier. A test that opens a real socket on
   the default path is a bug the `conformance` design forbids structurally.
4. **Frozen fixtures.** Conformance + golden-master fixtures are version-stamped
   (`fidelity/<cmux-version>/`), generated by `ctide-testkit gen-fixtures`, committed, and
   regenerated **only** via a deliberate upgrade-diff workflow (crap4rs's `fidelity/`
   precedent, risk #1 playbook: regen → diff → fix adapter → golden master green). A
   fixture-freshness lint pins the cmux version.
5. **No wall-clock / random ordering in asserted output.** `jiff` timestamps in op logs are
   normalized before diffing; `uuid`s are normalized (design-plan §2: serde serializes UUID
   normalized). proptest runs with a **fixed CI seed**, the failing seed printed for local
   replay; nextest output order is deterministic under the CI profile.
6. **Caching is restore-only-safe.** `Swatinem/rust-cache` with `cache-bin: false` (crap4rs
   `setup-rust` rationale: `cache-bin: true` strips the macOS rustup reinstall — see the
   action's L92–98); release-relevant jobs set `enable-cache: false` to close the
   cache-poisoning audit (crap4rs `setup-rust` L23–33, `release-plz enable-cache: "false"`).
   Cache is a speed optimization that can never change a result — keyed on `Cargo.lock` hash.
7. **SHA-pinned actions.** Every `uses:` is SHA-pinned with a version comment; `zizmor`
   enforces it (crap4rs ci.yml). Supply-chain determinism for the CI itself.

---

## 7. Mapping to the 8 design-plan tiers (§8)

| design-plan tier | CI realization | cadence |
|---|---|---|
| **1. Pure-core units + property tests** | `test` job (`nextest`), proptest with fixed CI seed; `crap` gate holds `ctide-core` at strict-8 | per-PR |
| **2. Golden master (strangler permit)** | Rust FakeMux parity tests diffed vs `tests/run.sh`'s ~120 asserted cmux commands; shell `gate` runs alongside (`strangler-gate` + `mirror-drift`) | per-PR (both generations) |
| **3. Port conformance kit over generated fixtures** | conformance suites in `test`/`cucumber` against fakes (always) + live cmux (`--ignored`, main) | per-PR (fakes) / per-merge (live) |
| **4. Replay-server tier (g7)** | same conformance assertions vs recorded replay server for `CmuxSocketAdapter` | per-PR |
| **5. Crash-replay convergence properties (g1)** | small randomized sample per-PR; full sweep (50-parallel hook-storm) at release (`crash-replay`) | per-PR (sample) / release (full) |
| **6. BDD cross-port (cucumber-rs)** | `cucumber` job, `harness=false` targets via `cargo test`, nextest-excluded; `.feature` files = published contract | per-PR |
| **7. Flow-SLO benches as release blockers** | `slo-bench` (hyperfine, FakeMux + recorded latencies, relative-regression gated) | **release blocker** |
| **8. Structural trust gates** | `egress-labels`, `no-config-write`, `dep-budget`, `dependency-rule`, `quirk-vault`, `deny` + `audit` | per-PR |

The CRAP gate (§2/§4.4) is the quality layer crap4rs contributes that sits *across* tiers 1
and 8 — the complexity-vs-coverage risk lens the design-plan testing section assumes
("structural trust gates") made mechanical with the owner's own tool.

**Walking-skeleton crosswalk** ([`roadmap.md`](./roadmap.md) §5 five-gate DoD →
this framework): gate 1 (`ctide doctor --json` typed + schema-versioned) = the `ctide-json`
contract proven by `test`; gate 2 (`conform_multiplexer(&FakeMux, fixtures)`) = tier 3
per-PR; gate 3 (same suite vs `CmuxSocketAdapter`/replay server) = tier 4 per-PR; gate 4
(`~/.config` grep + `cargo-deny` no-tokio/no-HTTP) = tier 8 `no-config-write` + `deny`; gate 5
(`doctor` cold-start recorded) = tier 7 `slo-bench` first budget point.

---

## 8. Starting config-file sketches (adapted from crap4rs)

> Drafts for the **E0 scaffolding commit**. Crate names map per the rebrand:
> `cide-core`→`ctide-core`, `cide-json`→`ctide-json`, `cide-mux-cmux`→`ctide-mux-cmux`,
> `cide-adapters`→`ctide-adapters`, `cide-dbt`→`ctide-dbt`, `ctide-place-macos`,
> `cide-testkit`→`ctide-testkit`, bin `cide`→`ctide` — the locked 8-crate DAG
> ([`roadmap.md`](./roadmap.md) E0; design-plan §2).

### `rust-toolchain.toml`
```toml
[toolchain]
channel = "1.NN.0"          # PIN a specific stable, not floating "stable" (determinism rule 1; OQ #2)
components = ["clippy", "rustfmt", "llvm-tools-preview"]
```

### `rustfmt.toml`
```toml
edition = "2024"
```

### `clippy.toml`
```toml
cognitive-complexity-threshold = 15    # early-warning front-running the CRAP gate
```

### `crap.toml` (the CRAP gate config — auto-discovered, no CLI flags in CI)
```toml
# Workspace default: born at "default" (15) for a strangler-built tree (§2; OQ #1).
preset = "default"

# Production source roots (boundary-safe per-crate roots, never the workspace recurse —
# mirrors crap4rs's three-root crap.toml L41-45).
src = [
    "crates/ctide-core/src",
    "crates/ctide-json/src",
    "crates/ctide-mux-cmux/src",
    "crates/ctide-adapters/src",
    "crates/ctide-dbt/src",
    "crates/ctide-place-macos/src",
    "crates/ctide/src",
]
# ctide-testkit (fakes, fixtures, replay server) is test infra — excluded from the
# production aggregate (mirrors crap4rs excluding crap-examples, ci.yml L214).
exclude = [
    # adr: ops/decisions/cmux-terminal-ide/adr-testkit-coverage.md — ctide-testkit is
    # test infrastructure (fakes, fixtures, replay server); 0% production-gate by design.
]

# NOTE: `metric` is NOT set at the shared top level — a top-level cognitive metric would
# make any crap4ts discovery of this file error out (crap4rs crap.toml L15-24). It lives in
# [language.rust] below, which only crap4rs reads.
[language.rust]
metric = "cognitive"

# Per-path override: the hexagon stays in the Low band (strict-8); wire parsing keeps 15.
[[thresholds.overrides]]
glob = "crates/ctide-core/src/**"
threshold = 8               # strict tier — the core is the asset
```

### `.config/nextest.toml`
```toml
[profile.ci]
retries = { backoff = "fixed", count = 2, delay = "1s" }   # surface flakes, never hide
fail-fast = false
slow-timeout = { period = "60s", terminate-after = 3 }
failure-output = "immediate-final"
status-level = "retry"      # report retried-then-passed as a flake signal (determinism §6.5)

# Exclude cucumber-rs harness=false targets (they speak their own CLI, not libtest —
# crap4rs lefthook L168 + ci.yml L88 split). They run via `cargo test` in the `cucumber` job.
[[profile.default.overrides]]
filter = "binary(/_cucumber$/)"
test-group = "cucumber"
```

### `deny.toml` (adapted from crap4rs + the zero-egress ban)
```toml
[graph]
all-features = true
exclude-dev = true          # scope bans to the SHIPPED graph; cucumber's async stack is dev-only

[advisories]                # verbatim crap4rs deny.toml L11-14
version = 2
yanked = "deny"
ignore = []

[licenses]                  # crap4rs allow-list shape; GPL-v3 vs MIT ruling pending (design-plan OQ #8)
version = 2
allow = ["Apache-2.0", "MIT", "BSD-3-Clause", "ISC", "Unicode-3.0"]
confidence-threshold = 0.93

[bans]
multiple-versions = "warn"  # v0.x; promote to "deny" at v1.0 (crap4rs deny.toml L42-44)
wildcards = "deny"
allow-wildcard-paths = true # self-referential path dev-deps (crap4rs precedent)
# ZERO-EGRESS / NO-RUNTIME structural proof — these may not enter the SHIPPED graph.
deny = [
    { name = "tokio" }, { name = "reqwest" }, { name = "hyper" },
    { name = "isahc" }, { name = "ureq" }, { name = "surf" },
    { name = "async-std" }, { name = "smol" },
]

[sources]                   # verbatim crap4rs deny.toml L100-104
unknown-registry = "deny"
unknown-git = "deny"
allow-registry = ["https://github.com/rust-lang/crates.io-index"]
```

### `lefthook.yml` (Rust gates added; shell gate preserved in lockstep)
```yaml
# MIRROR: .github/workflows/ci.yml runs the IDENTICAL commands (the `mirror-drift` lint
# enforces it). Lockstep rule inherited from the existing shell gate + crap4rs lefthook L1-10.
pre-commit:
  parallel: true
  commands:
    fmt: { glob: "*.rs", run: "cargo fmt --all --check", timeout: 60s }

pre-push:
  parallel: false
  commands:
    # --- existing shell golden-master gate, UNCHANGED through R1-R5 (retires at R5, §5) ---
    shellcheck: { run: "shellcheck bin/* lib/*.sh install.sh tests/*.sh" }
    stub-suite: { run: "sh tests/run.sh" }
    # --- Rust gates (mirror of ci.yml) ---
    fmt:     { run: "cargo fmt --all --check", timeout: 60s }
    clippy:  { run: "cargo clippy --workspace --all-targets --locked -- -D warnings", timeout: 300s }
    deny:    { run: "cargo deny check", timeout: 60s }
    msrv:    { run: "cargo +1.NN.0 check --workspace --all-targets --locked", timeout: 180s }
    test:    { run: "cargo nextest run --workspace --all-targets --locked --profile ci", timeout: 300s }
    cucumber:{ run: "cargo test --test <feature-suite> --locked", timeout: 300s }
    docs:    { env: { RUSTDOCFLAGS: "-D warnings" }, run: "cargo doc --workspace --no-deps --locked", timeout: 120s }
    egress-labels:   { run: "python3 scripts/egress-label-lint.py", timeout: 30s }
    no-config-write: { run: "python3 scripts/no-config-write-lint.py", timeout: 30s }
    quirk-vault:     { run: "python3 scripts/quirk-vault-lint.py", timeout: 30s }
    mirror-drift:    { run: "python3 scripts/mirror-drift-lint.py", timeout: 30s }
```

### `release-plz.toml` (adapted from crap4rs)
```toml
[workspace]                                # verbatim crap4rs release-plz.toml shape
dependencies_update = true
git_tag_name = "{{ package }}-v{{ version }}"
release_always = false
semver_check = true                        # cargo-semver-checks on every release PR
release_commits = "^(feat|fix|perf|refactor)(\\(.+\\))?!?:"

# Publish the library crates so adapter authors can pin; the bin ships via brew/cargo-dist.
[[package]]
name = "ctide-json"        # the FROZEN --json contract (g4) — first to stabilize (R1)
changelog_path = "crates/ctide-json/CHANGELOG.md"
[[package]]
name = "ctide-core"
changelog_path = "crates/ctide-core/CHANGELOG.md"
[[package]]
name = "ctide-testkit"     # the conformance kit — publication timing is design-plan OQ #6
changelog_path = "crates/ctide-testkit/CHANGELOG.md"
```

### `setup-rust` composite action
Port crap4rs's `.github/actions/setup-rust/action.yml` **verbatim** — it solves the
macOS-runner broken-rustup problem (actions/runner-images#14097) ctide hits immediately on
its macOS-primary matrix: the unconditional clean-rustup reinstall on macOS, the
`cache-bin: false` interaction (so the reinstall is not stripped), and the
`enable-cache: false` release-poisoning guard (release jobs neither read nor write caches).
This is the single highest-value copy from the template.

---

## 9. The repo-rename question (CI lens — confirms the roadmap ruling)

[`roadmap.md`](./roadmap.md) §3 already rules **rename `cmux-workspace-dbt` →
`cmux-terminal-ide` in place; do NOT start a new repo** (all three recon docs concur). This
framework supplies the CI-specific evidence that confirms it:

1. **The golden master is the strangler permit and it lives here.** Tier 2 (§5) requires the
   Rust FakeMux parity tests to diff against `tests/run.sh`'s ~120 asserted commands *in the
   same CI run, on the same fixtures*. A new repo severs the shell gate from the Rust gate;
   coexistence (design-plan §9, rule 1: every phase revertible via `CTIDE_SHELL=1`) becomes a
   cross-repo dance. The whole strangler design assumes one repo where both generations run
   side by side.
2. **`git mv` preserves the golden-master provenance (~120 assertions) + the `bin/` shell bodies** the Rust
   ports must match. A new repo loses the blame trail that adjudicates "annotated, intended
   improvement" deltas (design-plan OQ #7).
3. **CI history continuity.** Branch-protection required checks, the `gate` job's history, and
   the eventual retirement of `strangler-gate` + `mirror-drift` at R5 (§5) are all smoother as
   a renamed repo than a fresh one + an archived old one.
4. **The rename is cheap and reversible.** GitHub redirects the old name; `gh` and remotes
   keep working. The crate names are born `ctide-*` regardless (the rebrand decision), so the
   *repo* name is cosmetic relative to the *workspace* identity.

Counter-cost (generated `.cmux/*` churn, design-plan OQ #2) is orthogonal to the repo name.
The one thing to do at rename time: update the brew formula / tap path and any absolute doc
links — mechanical, one PR. Naming-map detail: [`rebrand-ctide.md`](./rebrand-ctide.md).

---

## 10. Open questions for the owner

1. **CRAP starting threshold ratchet (§2).** Confirm: workspace `default` (15) with
   `ctide-core` overridden to `strict` (8) at R0/R1, ratcheting the workspace to `strict`
   after R4? Or born `strict` everywhere with adapter per-path 15 floors? (Roadmap §8 records
   "default 15, `ctide-core` strict 8" — this confirms that reading.)
2. **Toolchain pin granularity (§6.1).** Pin a specific stable `1.NN.0` (max determinism,
   manual bumps) vs the floating `stable` channel crap4rs uses (less determinism, zero bump
   cost)?
3. **Doctest coverage pass (§4.4).** Will ctide ship doctests worth the extra
   `--no-report --doc` coverage pass (needs nightly per the nextest docs), or skip it for a
   binary-heavy workspace?
4. **Live-cmux conformance cadence (§4.6).** main-only `--ignored`, or also a nightly
   scheduled run to catch cmux upstream drift between merges (risk #1, fast cmux cadence)?
5. **`ctide-testkit` / `ctide-json` publication timing (release-plz §8).** `ctide-json` (the
   frozen contract) likely publishes at R1; testkit publication is design-plan OQ #6 (R3? R5?).
6. **License before the tap goes public (deny.toml §8).** GPL-v3 org default vs cute-dbt's
   MIT — the `[licenses].allow` list and the public brew tap both need the ruling
   (design-plan OQ #8).
7. **Repo rename (§9).** Confirmed by the roadmap (rename-in-place); schedule it for the R0/E0
   Cargo-scaffolding commit (design-plan §2 already annotates the layout "post-rename").

---

*Framework complete. It reuses crap4rs's deterministic CI scaffolding, `setup-rust`
composite, lefthook lockstep, `deny.toml`, `release-plz`, toolchain pin, and the CRAP
threshold model; adds the zero-egress dep-ban, the macOS-primary matrix, the
shell-golden-master coexistence, the determinism rules, and the 8-tier mapping. It is the E0
deliverable (R0 — scaffold + CI/quality foundation), gating R1's walking skeleton
([`r1-walking-skeleton.md`](./r1-walking-skeleton.md)) and every verb R2→R5. Next step after
owner sign-off on §10: implement at E0 alongside the empty 8-crate skeleton and the repo
rename ([`roadmap.md`](./roadmap.md) §3 R0).*
