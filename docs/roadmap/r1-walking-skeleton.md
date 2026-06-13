# R0/R1 Walking Skeleton — `ctide doctor` over the `Multiplexer` port

> **The first thing we build, in full.** This is the concrete, buildable spec for
> the smallest end-to-end slice that proves the whole architecture, plus the R0
> scaffold it lands into. It expands [§5 of the master
> roadmap](./roadmap.md#5-the-walking-skeleton--the-first-thing-we-build) and is
> the implementation contract for **epic E0** (R0 scaffold + repo rename) and the
> first slice of **epic E1** (R1 foundations).
>
> **The slice, in one line:** `ctide doctor` resolves config provenance + egress
> labels + capability drift by calling `MuxTopology::tree()` /
> `capabilities()` / `manifest()` (read-only) through `ctide-core` ports onto a
> `FakeMux` test double, emits a `ctide-json`-typed, schema-versioned payload, and
> is green in CI against **FakeMux**, the **recorded replay server** (g7), and
> live cmux behind `--ignored`. **It mutates nothing** — zero blast radius.
>
> **Sources.** Master roadmap [`roadmap.md`](./roadmap.md) §5/§7; recon
> [`research/backbone.md`](./research/backbone.md) (R0/R1 + the walking-skeleton
> section); recon [`research/ci-quality-framework.md`](./research/ci-quality-framework.md)
> (the five-gate CI definition, config sketches); approved design
> [`../vision/design-plan.md`](../vision/design-plan.md) §2 (crate DAG + dep
> budget), §3 (the `Multiplexer` supertrait + conformance kit), §4 (the cmux
> adapter, transports, FakeMux, g7 replay), §8 (8-tier testing). Template:
> `/Users/cmbays/github/crap4rs` (`Cargo.toml`, `crap.toml`, `deny.toml`,
> `rust-toolchain.toml`, `.config/nextest.toml`, `.github/actions/setup-rust`).
> Golden master: [`tests/run.sh`](../../tests/run.sh) (~120 emitted-command
> assertions — the strangler permit, kept running unchanged; the R5 conversion
> target is the full set as it stands at conversion time, see
> [`roadmap.md`](./roadmap.md) §3 footnote). 2026-06-12.

---

## 0. What "done" means (read this first)

The walking skeleton is **done** when all five CI gates below are green on a PR
into the renamed repo. Nothing in this slice writes live cmux state, no `~/.config`
literal appears outside a (not-yet-built) `setup` module, and the shipped
dependency graph contains no tokio and no HTTP client.

| # | Gate | Where it lives |
|---|---|---|
| 1 | `ctide doctor --json` emits a `ctide-json`-typed, `schema = 1`-versioned payload that round-trips serde. | `crates/ctide-json` + `crates/ctide` (`From` impls) |
| 2 | `conform_multiplexer(&FakeMux::from(fixtures), &fx)` is green. | `crates/ctide-testkit` conformance kit |
| 3 | The **same** conformance suite is green against `CmuxSocketAdapter` over the recorded replay server (g7). | `crates/ctide-testkit` replay server + `crates/ctide-mux-cmux` |
| 4 | The `~/.config` grep gate + `cargo-deny` (no-tokio / no-HTTP, `exclude-dev` scope) gates are green. | `deny.toml`, `scripts/no-config-write-lint.py`, CI |
| 5 | The flow-SLO hyperfine harness records `ctide doctor` cold start (first budget data point; informational on this slice, release-blocker later). | `slo-bench` job |

These map 1:1 to the master roadmap's walking-skeleton definition-of-done
([`roadmap.md`](./roadmap.md) §5) and the backbone's CI-green list
([`research/backbone.md`](./research/backbone.md), walking-skeleton section).
**Scope discipline:** if a task does not advance one of these five gates, it is
out of scope for this slice — it belongs to the rest of E1 (theme / agent ls /
statusline / state migrate) or later phases.

> **The `crap` gate is part of this slice's DoD, and it must be *wired*, not just
> configured.** The five gates above are the *value*-proving gates; the structural
> gates from E0 (§6 — `deny`, `dependency-rule`, `dep-budget`, `egress-labels`,
> `quirk-vault`, **`crap`**) also run on this PR. The CRAP gate is not standalone:
> the `crap` job consumes an `lcov` artifact produced by the `coverage` job
> (`cargo llvm-cov nextest --workspace --lcov`), so **the `coverage`→`crap` two-job
> dependency must be wired before the walking skeleton can claim done** — otherwise
> a builder can land gates 1–5 green and discover `crap` is red or unwired. For
> this slice the only production code with meaningful coverage is `plan_doctor` +
> a few domain types; `ctide-testkit` is excluded from the production aggregate
> (already in the `crap.toml` sketch, §6), so the strict-8 `ctide-core` gate is
> evaluated only over that tiny `plan_doctor`+domain surface — a near-empty core is
> fine at strict-8, but confirm the gate is green, not merely absent.

---

## 1. R0 — the workspace scaffold (epic E0)

Nothing compiles until the workspace exists, so E0 is the program's first epic.
Build the empty-but-real `ctide` workspace and its gates **before** the doctor
slice, so the slice lands into a structure that already says "no" to tokio, HTTP,
`~/.config` writes, and manifest-less adapters.

### 1.1 The locked 8-crate DAG

Born `ctide` from crate one (the rebrand is not a later rename of `cide-*`
crates — see [`research/backbone.md`](./research/backbone.md) naming note). The
DAG is the design plan's four-crate spine plus its compilation-unit splits
([`../vision/design-plan.md`](../vision/design-plan.md) §2):

```
ctide-core  ──▶  ctide-json
     │              ▲
     │   (core depends on NOTHING in-workspace; json depends on serde only)
     ▼
ctide-mux-cmux ─▶ (depends on ctide-core ports + ctide-json output types)
     │
     ▼
ctide-adapters ─▶ (ctide-core + ctide-json; one feature-gated module per tool)
     │
     ├─▶ ctide-dbt        (dbt adapter code only; recipe is data — empty stub at R0)
     ├─▶ ctide-place-macos (cfg(target_os="macos"); empty stub at R0)
     │
     ▼
ctide-testkit  ─▶ (FakeMux, fixtures, replay server, conformance suites)
     │
     ▼
ctide (bin)    ─▶ (clap + composition root ONLY; depends on everything; nothing depends on it)
```

**Dependency rule (CI-enforced, `dependency-rule` job):** `ctide-core` depends on
nothing in-workspace; the binary depends on all; **nothing** depends on the
binary. The R0 exit test plants a violation (`ctide-core` importing the bin) and
asserts CI rejects it ([`research/ci-quality-framework.md`](./research/ci-quality-framework.md)
§4.9; [`research/backbone.md`](./research/backbone.md) R0 exit criteria).

### 1.2 Cargo workspace member list + the dependency budget

`Cargo.toml` (workspace root), modeled on
`/Users/cmbays/github/crap4rs/Cargo.toml` (the catalog pattern: every version
pins once at workspace scope, crates reference `{ workspace = true }`):

```toml
[workspace]
resolver = "2"
members = [
    "crates/ctide-core",
    "crates/ctide-json",
    "crates/ctide-mux-cmux",
    "crates/ctide-adapters",
    "crates/ctide-dbt",
    "crates/ctide-place-macos",
    "crates/ctide-testkit",
    "crates/ctide",
]

[workspace.package]
edition = "2024"
rust-version = "1.NN"          # the pinned floor (see rust-toolchain.toml below)
license = "GPL-3.0-only"       # OQ: GPL-v3 org default vs cute-dbt's MIT — ruling
                               # blocks the PUBLIC brew tap (R5), not this slice.
repository = "https://github.com/breezy-bays-labs/cmux-terminal-ide"
authors = ["Christopher Bays <cmbays@breezybayslabs.com>"]

# ── Workspace dependency budget (HARD constraint, not a guideline; risk #4) ──
# design-plan §2 line 113–120. NO tokio, NO HTTP client, NO sqlite.
[workspace.dependencies]
ctide-core    = { path = "crates/ctide-core",    version = "0.1.0" }
ctide-json    = { path = "crates/ctide-json",    version = "0.1.0" }
ctide-mux-cmux = { path = "crates/ctide-mux-cmux", version = "0.1.0" }
ctide-adapters = { path = "crates/ctide-adapters", version = "0.1.0" }
ctide-testkit = { path = "crates/ctide-testkit", version = "0.1.0" }

clap       = { version = "4", features = ["derive", "string"] }
serde      = { version = "1", features = ["derive"] }
serde_json = { version = "1" }                       # add float_roundtrip only if a
                                                     # wire round-trip proptest needs it
toml       = { version = "0.8" }
thiserror  = { version = "2" }
jiff       = { version = "0.1" }                      # timestamps; normalized before diff
uuid       = { version = "1", default-features = false, features = ["v4", "serde"] }
rustix     = { version = "0.38" }                    # flock; std exposes none
url        = { version = "2" }
objc2      = { version = "0.5" }                      # macOS-only, ctide-place-macos

# ── Dev-only (carved out of the cargo-deny ban via exclude-dev) ──
cucumber          = { version = "0.22" }             # pulls an async stack DEV-ONLY
tokio             = { version = "1", features = ["macros", "rt-multi-thread"] }
proptest          = { version = "1" }
insta             = { version = "1", features = ["json"] }
pretty_assertions = { version = "1" }
tempfile          = { version = "3" }
assert_cmd        = { version = "2" }
```

> **Why `tokio` appears at all.** It is a transitive **dev-dependency** of
> cucumber-rs's harness. `deny.toml`'s `exclude-dev = true` (§1.5) scopes the
> no-async ban to the *shipped binary's normal graph*, so cucumber's async stack
> never trips the gate and the gate never has to be weakened
> ([`../vision/design-plan.md`](../vision/design-plan.md) §2/§8.6; risk #4's
> erosion mode). This is the single most important carve-out to get right at R0.

For **this slice**, only these crates carry non-trivial deps:
- `ctide-core`: `serde`, `toml`, `thiserror`, `uuid`, `url`, `jiff`.
- `ctide-json`: `serde` **only** (the frozen contract crate, g4).
- `ctide-mux-cmux`: `ctide-core`, `ctide-json`, `serde`, `serde_json`, `rustix`.
- `ctide-testkit`: `ctide-core`, `ctide-json`, `ctide-mux-cmux`, `serde_json`;
  dev-side `cucumber`, `proptest`, `tempfile`.
- `ctide`: `clap`, `ctide-core`, `ctide-json`, `ctide-mux-cmux`, `ctide-adapters`.

`ctide-dbt` and `ctide-place-macos` are **stub crates** at R0 (a `lib.rs` with a
doc comment and nothing else) — they exist so the DAG and the `cargo-deny` scope
are complete; they earn code at R5 / R3 respectively.

### 1.3 `rust-toolchain.toml` (pin a specific stable)

Per determinism rule 1
([`research/ci-quality-framework.md`](./research/ci-quality-framework.md) §6.1) —
**pin a specific stable `1.NN.0`**, not the floating `stable` channel crap4rs
uses, so a new stable release cannot flip CI between identical commits:

```toml
[toolchain]
channel = "1.NN.0"          # PIN — pick the current stable at scaffold time
components = ["clippy", "rustfmt", "llvm-tools-preview"]
```

(`llvm-tools-preview` is required by `cargo-llvm-cov` for the coverage → CRAP
pipeline; this matches crap4rs's toolchain pin.)

### 1.4 CI/quality template adopted from crap4rs

Clone the *patterns*, not the literal files (crate names differ). The
[CI/quality framework recon](./research/ci-quality-framework.md) §8 carries the
full config sketches; the load-bearing copies for R0:

- **`.github/actions/setup-rust`** — port **verbatim**. It solves the macOS-runner
  broken-rustup problem (`actions/runner-images#14097`) ctide hits immediately on
  its macOS-primary matrix, including `cache-bin: false` and the
  `enable-cache: false` release-poisoning guard. *Highest-value single copy.*
- **`crap.toml`** — adopt crap4rs as a CRAP gate. Workspace default `preset =
  "default"` (15) for a strangler-built tree; `ctide-core/src/**` overridden to
  `strict` (8) via per-path override. (Sketch in §6.)
- **`deny.toml`** — crap4rs's shape + the zero-egress ban (§1.5).
- **`lefthook.yml`** — Rust gates as a lockstep mirror of CI; the existing shell
  golden-master gate (shellcheck + `sh tests/run.sh`) preserved **unchanged**.
- **`release-plz.toml`**, **`rustfmt.toml`** (`edition = "2024"`), **`clippy.toml`**
  (`cognitive-complexity-threshold = 15`), **`.config/nextest.toml`** (CI profile:
  bounded retries that *surface*, never hide, flakes).
- **mdBook skeleton** + Pages workflow — exist, held un-triggered (first publish at
  the end-R2 checkpoint per [`roadmap.md`](./roadmap.md) §7).
- **`cargo-dist` skeleton** — brew-tap target wired, not publishing.

### 1.5 `deny.toml` — the zero-egress structural proof

Adapted from `/Users/cmbays/github/crap4rs/deny.toml` with the no-egress /
no-runtime ban added and **`exclude-dev` scoping** (the carve-out that makes the
ban survivable):

```toml
[graph]
all-features = true
exclude-dev = true          # scope bans to the SHIPPED graph; cucumber's async is dev-only

[advisories]
version = 2
yanked = "deny"

[licenses]
version = 2
allow = ["Apache-2.0", "MIT", "BSD-3-Clause", "ISC", "Unicode-3.0"]  # GPL-v3 ruling pending
confidence-threshold = 0.93

[bans]
multiple-versions = "warn"  # v0.x; promote to "deny" at v1.0 (crap4rs precedent)
wildcards = "deny"
allow-wildcard-paths = true # path-dep crates (the in-workspace crates) are implicit-wildcard
# ZERO-EGRESS / NO-RUNTIME structural proof — may not enter the SHIPPED graph.
deny = [
    { name = "tokio" }, { name = "reqwest" }, { name = "hyper" },
    { name = "isahc" }, { name = "ureq" }, { name = "surf" },
    { name = "async-std" }, { name = "smol" },
]

[sources]
unknown-registry = "deny"
unknown-git = "deny"
allow-registry = ["https://github.com/rust-lang/crates.io-index"]
```

**R0 exit test:** plant `reqwest` as a *shipped* dep → `cargo deny check` fails;
move it to `[dev-dependencies]` → passes. Plant `tokio` in `ctide-core` →
fails; the cucumber dev-dep tokio → passes (proves `exclude-dev`).

### 1.6 The repo rename (in place)

**Ruling (decisive, from the master roadmap):** rename
`cmux-workspace-dbt → cmux-terminal-ide` **in place**; do **not** fork. The
POSIX golden master (~120 emitted-command assertions), strangler coexistence
(`exec ctide` preamble + `CTIDE_SHELL=1` rollback), and `prior-decisions` §1 all
require one tree
([`roadmap.md`](./roadmap.md) §3 R0 box; [`research/backbone.md`](./research/backbone.md)
R0 repo-decision box; [`research/ci-quality-framework.md`](./research/ci-quality-framework.md)
§9). The full naming map + rename steps live in
[`rebrand-ctide.md`](./rebrand-ctide.md). **Caveats at
rename time:** rename the *GitHub repo* but **defer the local-dir rename** (it
orphans the Claude project-memory path key — keep the checkout path stable);
update the brew formula (`cide → ctide`) + CI/`gh` refs; create the empty
`homebrew-tap`. **Note:** the design plan's §2 directory layout still labels the
root `cmux-ide/` — that is a pre-rebrand artifact; the authoritative name is
`cmux-terminal-ide` ([`rebrand-ctide.md`](./rebrand-ctide.md) §2.3).

> **Agent safety note.** This document is planning-only. Do **not** run the rename,
> create the workspace, or mutate the repo — these steps are the builder's job in
> the E0 PR.

### 1.7 R0 exit criteria (testable — what makes E0 done)

From [`research/backbone.md`](./research/backbone.md) R0 + [`roadmap.md`](./roadmap.md)
§3 R0:

- `cargo build --workspace` and `cargo test --workspace` green on the empty
  8-crate skeleton, in CI, on **aarch64-darwin** and **`*-linux-musl`**
  (compile-only — see the linker note below).

> **musl cross-link note (resolve at E0 — don't let the builder rediscover it).**
> `cargo build --target aarch64-unknown-linux-musl` on an `ubuntu-latest`
> (x86_64) runner is a **cross-compile** and needs two things the bare command
> does not provide: (1) `rustup target add aarch64-unknown-linux-musl` — pass
> `targets: aarch64-unknown-linux-musl` to the crap4rs `setup-rust` step (it accepts
> a `targets:` input, verified — one line); and (2) **an aarch64 musl
> cross-linker** — `apt-get install musl-tools` is **x86-only** and will *not*
> satisfy aarch64. **Pick one, and record the choice as a one-line CI comment:**
> (a) build through [`cargo-zigbuild`](https://github.com/rust-cross/cargo-zigbuild)
> (zig as the cross-linker — least fuss, one tool) or `cross`; (b) install a
> prebuilt `aarch64-linux-musl-cross` toolchain and set
> `CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_LINKER`; **or (c) — recommended for the
> "Linux-not-precluded" insurance goal only — downgrade R0 to
> `x86_64-unknown-linux-musl`** (native-arch musl on an x86 runner; needs only
> `musl-tools`, no cross-linker) and **defer the aarch64-musl cross-link to when a
> real Linux mux adapter exists.** The point of this gate is "Linux is not
> precluded," not "aarch64-Linux ships" — (c) buys that cheaply today; (a)/(b) buy
> aarch64 if wanted. Do **not** ship the bare `cargo build --target
> aarch64-unknown-linux-musl` — it link-fails on the first E0 CI run.
- The `dependency-rule` gate **fails a planted violation** (core importing the
  bin) — proving the gate is live, not decorative.
- `cargo-deny` rejects a planted `tokio`/`reqwest` in a shipped crate but allows
  it as a dev-dep (the `exclude-dev` scope).
- The `~/.config` grep gate rejects a planted literal.
- crap4rs runs as a CRAP gate; the mdBook + Pages workflow exist (held
  un-triggered).
- GitHub repo renamed; `homebrew-tap` created (empty).

---

## 2. The minimal domain types (ctide-core)

The slice needs only the types `doctor` touches — read-only topology + identity,
the trust labels, and config provenance. These are condensed from
[`../vision/design-plan.md`](../vision/design-plan.md) §2 (domain) and §3 (the
`Multiplexer` supertrait). **All sync, all object-safe** (cmux is request/response
over a unix socket — blocking I/O is correct, `dyn` works, no async machinery —
[`../vision/design-plan.md`](../vision/design-plan.md) §3 rule 4).

```rust
// crates/ctide-core/src/domain/ids.rs
// fact: refs are positional and die across restarts; UUIDs survive. Persistence
// ALWAYS serializes the UUID (normalized); refs derived live, never stored.
pub struct MuxId { pub uuid: Uuid, pub ref_hint: Option<RefHint> }
pub struct WindowId(pub MuxId);
pub struct WorkspaceId(pub MuxId);
pub struct PaneId(pub MuxId);
pub struct SurfaceId(pub MuxId);
pub enum RefHint { Workspace(u32), Window(u32) }   // "workspace:N" / "window:N" display hints

// crates/ctide-core/src/domain/topology.rs — what tree() returns (read-only).
pub struct Topology { pub windows: Vec<WindowNode> }
pub struct WindowNode {
    pub id: WindowId,
    pub workspaces: Vec<WorkspaceNode>,
}
pub struct WorkspaceNode {
    pub id: WorkspaceId,
    pub current_directory: Option<PathBuf>,   // merged in by a 2nd adapter call (§4 quirk)
    pub surfaces: Vec<SurfaceId>,
    pub tags: Vec<CideTag>,                    // which generation owns this ws, etc.
}
pub struct Identity { pub caller: Option<WorkspaceId>, pub focused: Option<WorkspaceId> }
pub struct CideTag(pub String);

// crates/ctide-core/src/domain/capability.rs — the drift probe input.
pub struct CapabilitySet { pub rpcs: BTreeSet<String>, pub cmux_version: String }

// crates/ctide-core/src/domain/egress.rs — the trust posture (P7).
pub enum EgressLabel {
    Zero,
    DefensibleEgress { why: String },          // e.g. "gh (opt-in)"
    TelemetryDisabledVerified,
}
pub struct AdapterManifest {
    pub id: AdapterId,
    pub port: PortKind,
    pub required_tools: Vec<ToolRequirement>,
    pub egress: EgressLabel,                    // CI rejects a manifest without one
}
pub struct AdapterId(pub String);
pub enum PortKind { Mux, Editor, Explorer, Vcs, Runner, Agent, Theme, Placement, Warehouse, Notify }
pub struct ToolRequirement { pub bin: String, pub min_version: Option<String> }

// crates/ctide-core/src/config/provenance.rs — the g5 doctor surface.
pub enum ConfigLayer {
    Embedded,                                   // recipes/layouts/themes compiled in
    UserConfig,                                 // ~/.config/ctide/config.toml (READ only)
    RepoCommitted,                              // $repo/ctide.toml
    RepoLocal,                                  // $repo/ctide.local.toml (gitignored)
    EnvOrFlag,                                  // CTIDE_* / CLI
}
pub struct Provenance { pub key: String, pub value: String, pub layer: ConfigLayer }

pub enum MuxError { /* … typed; never panics on a quirk */ }
```

> **Note on scope.** The full domain model (`Space`, `AgentSlot`, `RunnerJob`,
> `LayoutPreset`, `ReviewItem`, …) is **not** built in this slice — those types
> arrive with their owning verbs in R2–R5. The walking skeleton builds only what
> `doctor` reads. Keep `ctide-core` tiny; the CRAP gate holds it at strict-8.

---

## 3. The first port trait (the `Multiplexer` supertrait)

`doctor` is read-only, so it only needs the read-side capability traits. The full
supertrait is defined in [`../vision/design-plan.md`](../vision/design-plan.md) §3;
**for this slice, implement only `MuxTopology` + the supertrait's two reflection
methods.** The write-side traits (`MuxWorkspaces`, `MuxSurfaces`, `MuxAttention`,
`MuxEvents`, `MuxFeed`, `MuxViewers`) are *declared* (so `FakeMux` and the adapter
satisfy the supertrait bound) but their methods can be stubbed (`unimplemented!()`
behind a `// tracked:` marker, or returning `MuxError::NotImplementedThisSlice`)
since nothing in `doctor` calls them.

```rust
// crates/ctide-core/src/ports/mux.rs

pub trait MuxTopology {
    /// ALWAYS global (tree --all). The workspace.list-is-focused-window-only trap
    /// is unexpressible: there is no scoped listing method. (design-plan §3/§4)
    fn tree(&self) -> Result<Topology, MuxError>;
    /// caller vs focused workspace.
    fn identify(&self) -> Result<Identity, MuxError>;
}

// The umbrella supertrait. doctor calls capabilities() + manifest() + (via
// MuxTopology) tree()/identify(). Object-safe: &dyn Multiplexer works.
pub trait Multiplexer:
    MuxTopology + MuxWorkspaces + MuxSurfaces + MuxAttention + MuxEvents + MuxFeed + MuxViewers
{
    fn capabilities(&self) -> &CapabilitySet;   // probed once per invocation
    fn manifest(&self) -> &AdapterManifest;
}
```

### The `plan_doctor` / `execute` split (the architecture's core discipline)

Every verb is `plan_*` (pure, `topology → report`, zero I/O — the unit + golden
surface) then a thin `execute` (the I/O shell). `doctor` is read-only, so its
"execute" is just *reading* (`tree()`, `identify()`, `capabilities()`,
`manifest()`) and *printing*; the interesting logic is all in `plan_doctor`:

```rust
// crates/ctide-core/src/usecases/doctor.rs  — PURE. No I/O. Unit-tested directly.

pub struct DoctorInput {
    pub topology: Topology,
    pub identity: Identity,
    pub capabilities: CapabilitySet,
    pub bound_manifests: Vec<AdapterManifest>,   // the bound adapter set
    pub pinned_caps: CapabilitySet,              // the fidelity snapshot to diff against
    pub provenance: Vec<Provenance>,             // resolved config layers (g5)
}

pub struct DoctorReport {
    pub egress: EgressSurface,                    // ctide's own + cmux-substrate audit (P7)
    pub capability_drift: Vec<CapabilityDelta>,   // live vs pinned (g7 probe)
    pub provenance: Vec<Provenance>,              // every effective key + its layer (g5)
    pub generation_owner: Vec<VerbOwner>,         // which gen owns each verb (R1: all shell)
}

/// The whole verb's logic, as a pure function. THIS is what tests assert.
pub fn plan_doctor(input: &DoctorInput) -> DoctorReport { /* aggregate, no I/O */ }
```

```rust
// crates/ctide/src/cmd/doctor.rs  — the thin I/O shell (composition root side).

pub fn execute(mux: &dyn Multiplexer, cfg: &ResolvedConfig, json: bool) -> Result<(), CtideError> {
    let input = DoctorInput {
        topology:       mux.tree()?,            // read-only
        identity:       mux.identify()?,        // read-only
        capabilities:   mux.capabilities().clone(),
        bound_manifests: cfg.bound_manifests(),
        pinned_caps:    cfg.pinned_capabilities(),
        provenance:     cfg.provenance(),
    };
    let report = ctide_core::usecases::doctor::plan_doctor(&input);   // PURE
    if json {
        // ctide-core::DoctorReport  ──From──▶  ctide_json::DoctorPayload  (explicit, in bin)
        let payload: ctide_json::DoctorPayload = (&report).into();
        println!("{}", serde_json::to_string_pretty(&payload)?);
    } else {
        render_human(&report);
    }
    Ok(())
}
```

The `From<&DoctorReport> for ctide_json::DoctorPayload` impl lives **in the
binary**, not in either crate — that explicit conversion is what keeps internal
domain refactors from silently breaking the frozen `--json` contract
([`../vision/design-plan.md`](../vision/design-plan.md) §2, g4).

---

## 4. The `FakeMux` test double + the cmux adapter seam

`FakeMux` (in `ctide-testkit`) is the third impl — and *the* testing story
([`../vision/design-plan.md`](../vision/design-plan.md) §4 "the third impl IS the
testing story"). For the slice it needs only the read path plus op-recording
infrastructure (which the write verbs use later):

```rust
// crates/ctide-testkit/src/fake_mux.rs

pub struct FakeMux {
    topology: Topology,
    identity: Identity,
    caps: CapabilitySet,
    manifest: AdapterManifest,
    recorded_ops: RefCell<Vec<RecordedOp>>,   // proves doctor records ZERO mutating ops
}

impl FakeMux {
    pub fn from_fixture(fx: &FixtureSet) -> Self { /* load fidelity/<ver>/ snapshot */ }
    pub fn recorded_ops(&self) -> Vec<RecordedOp> { self.recorded_ops.borrow().clone() }
}

impl MuxTopology for FakeMux {
    fn tree(&self) -> Result<Topology, MuxError> { Ok(self.topology.clone()) }   // no record
    fn identify(&self) -> Result<Identity, MuxError> { Ok(self.identity.clone()) }
}
impl Multiplexer for FakeMux {
    fn capabilities(&self) -> &CapabilitySet { &self.caps }
    fn manifest(&self) -> &AdapterManifest { &self.manifest }
}
// MuxWorkspaces/Surfaces/... : record-and-stub; doctor never calls them, and a
// blast-radius test asserts FakeMux.recorded_ops() is EMPTY after a doctor run.
```

**The real adapter (`ctide-mux-cmux`), slice scope.** Build only what gate 3
needs: `CmuxSocketAdapter::tree()` / `identify()` / `capabilities()` over the v2
JSON socket protocol, with **all wire parsing in one `wire.rs` module** (serde
types per response shape, fixture tests generated from live cmux — never
hand-authored). The quirk vault facts this slice must encode
([`../vision/design-plan.md`](../vision/design-plan.md) §4):

- `tree()` = `tree --all --id-format both` parsed once; the one field tree lacks
  (`current_directory`) is merged in by a secondary call **inside** the adapter —
  callers get one complete `Topology` (kills the dogfood scoping split-brain).
  Each fact carries a `// fact:` comment + a fixture test (the `quirk-vault` lint
  enforces this and that the facts live nowhere else).
- `OK <uuid>` vs `OK workspace:N` output formats live in `wire.rs` serde types.
- `MuxId` normalizes UUID case on construction; refs derived only from a live tree.
- `capabilities()` diffs the live cmux RPC set against the pinned
  `fidelity/<cmux-version>/` snapshot — the drift surface `doctor` prints (g7
  insurance against cmux's fast cadence).

The `CmuxCliAdapter` fallback and the write-side methods are **not** in this
slice (they arrive in R1's parser killers / R2's runner).

### The three-impl proof (the heart of the slice)

The **same** `conform_multiplexer` assertion runs against all three impls; getting
`doctor` green across all three *is* the proof that the third impl is the testing
story ([`roadmap.md`](./roadmap.md) §5; [`research/backbone.md`](./research/backbone.md)
walking-skeleton section):

```rust
// crates/ctide-testkit/src/conformance/mux.rs  — the generic suite.
pub fn conform_multiplexer(m: &dyn Multiplexer, fx: &FixtureSet) {
    let tree = m.tree().expect("tree() must succeed read-only");
    assert_eq!(tree.windows.len(), fx.expected_window_count);
    for ws in tree.windows.iter().flat_map(|w| &w.workspaces) {
        assert!(ws.current_directory.is_some(), "cwd must be merged in (quirk vault)");
    }
    let id = m.identify().expect("identify() must succeed");
    assert!(id.focused.is_some() || fx.allows_no_focus);
    let caps = m.capabilities();
    assert!(caps.rpcs.contains("tree"));
    // … the full per-port invariant battery, fixture-driven.
}
```

| Impl | When it runs | Gate |
|---|---|---|
| `FakeMux` (always) | every PR, in `test`/`nextest` | gate 2 |
| `CmuxSocketAdapter` over the **recorded replay server** (g7) | every PR, in `test` | gate 3 |
| live cmux behind `#[ignore]` | main / manual, sacrificial scratch window | fidelity gen, not a PR gate |

The replay server (in `ctide-testkit`) replays a recorded socket session so the
*primary transport* has CI coverage **with no live cmux**
([`../vision/design-plan.md`](../vision/design-plan.md) §4/§8.4). It is a recorded
fixture, not a network service — zero egress.

---

## 5. The first verb end-to-end (`ctide doctor`)

The data flow that walks the full crate DAG (the dependency rule the R0 gate
protects):

```
ctide (bin, clap + composition root)
   │  parses `ctide doctor [--json] [--mux-transport socket|cli]`
   │  builds the Multiplexer impl + ResolvedConfig (config loader)
   ▼
ctide-core::usecases::doctor::plan_doctor(&DoctorInput)   ← PURE, the asserted logic
   ▲                                                          (reads ports, no I/O)
   │  via ports:
   ▼
MuxTopology::tree() / identify() · Multiplexer::capabilities() / manifest()
   │
   ├── FakeMux                         (ctide-testkit)        ← tests
   ├── CmuxSocketAdapter (replay)      (ctide-mux-cmux)       ← gate 3
   └── CmuxSocketAdapter (live)        (ctide-mux-cmux)       ← --ignored
   │
   ▼
DoctorReport ──From(in bin)──▶ ctide_json::DoctorPayload ──serde──▶ stdout (--json)
```

**`doctor`'s trust value** (why it earns *trust* — not daily flow — at zero blast
radius). It is a **low-frequency trust/diagnostic verb**: you run it when something
is wrong, when auditing egress, or to answer "why is it doing that?" — *not* as part
of the flow loop. Its job is to prove the rails + the zero-egress posture, so do
**not** gold-plate it as a daily verb. The first *flow-changing* Rust verb is `ctide
run` (R2); the first daily value overall is the E7 R0 dbt-review shell slice
([`roadmap.md`](./roadmap.md) §6). What it delivers:

1. **Egress surface (P7).** Prints ctide's own network surface (default bindings:
   one line, `gh (defensible-egress, opt-in)`) **plus** a cmux-substrate section:
   telemetry flag state, the Feed control `--legacy`, `reactGrabVersion` — the
   claim is falsifiable only if it includes the substrate
   ([`../vision/design-plan.md`](../vision/design-plan.md) §3).
2. **Config provenance (g5).** For every effective key, which layer it came from
   (`bindings.editor = "neovim"  (user: ~/.config/ctide/config.toml)`) — "why is
   it doing that?" stops being archaeology.
3. **Capability drift (g7).** Diffs live cmux's advertised RPC set vs the pinned
   fidelity snapshot; prints any drift — the fast-upstream-cadence insurance.
4. **The `--json` contract (g4).** `ctide doctor --json` emits the
   `schema`-versioned `ctide_json::DoctorPayload` — the machine-first contract
   agents pin against.

### `ctide-json` (g4) — the frozen contract crate, slice scope

`serde`-only crate. The slice ships exactly the payload `doctor --json` emits, with
a schema version field:

```rust
// crates/ctide-json/src/lib.rs
pub const SCHEMA_VERSION: u32 = 1;

#[derive(serde::Serialize, serde::Deserialize, PartialEq, Debug)]
pub struct DoctorPayload {
    pub schema: u32,                    // = SCHEMA_VERSION
    pub egress: EgressSurfaceJson,
    pub capability_drift: Vec<CapabilityDeltaJson>,
    pub provenance: Vec<ProvenanceJson>,
    pub generation_owner: Vec<VerbOwnerJson>,
}
// … the leaf structs, serde-only, decoupled from ctide-core domain types.
```

**Gate 1** is satisfied by: (a) `--json` sets `schema = 1`; (b) a
`serde_json::to_string` → `serde_json::from_str` round-trip proptest in
`ctide-json` proves the payload is stable; (c) an `insta` snapshot of
`doctor --json` against the FakeMux fixture pins the exact shape.

---

## 6. The CI gate (the slice's definition of done)

The walking skeleton counts as done when these run green in CI
([`roadmap.md`](./roadmap.md) §5; [`research/ci-quality-framework.md`](./research/ci-quality-framework.md)
§3.1/§4). PR-depth jobs relevant to the slice:

| job | command (essence) | gate |
|---|---|---|
| `fmt` | `cargo fmt --all --check` | block |
| `clippy` | `cargo clippy --workspace --all-targets --locked -- -D warnings` | block |
| `test` (macos-arm primary + linux-x86) | `cargo nextest run --workspace --all-targets --locked --profile ci` — runs `conform_multiplexer` over FakeMux (**gate 2**) **and** the replay server (**gate 3**); the blast-radius test (`recorded_ops().is_empty()`); the `ctide-json` round-trip proptest + insta snapshot (**gate 1**) | block |
| `deny` | `cargo deny check` (no-tokio/no-HTTP, `exclude-dev`) — **gate 4a** | block |
| `no-config-write` | `python3 scripts/no-config-write-lint.py` (reject `~/.config` literal outside `setup`) — **gate 4b** | block |
| `dep-budget` | `cargo metadata` assertion: shipped graph has no tokio / no HTTP client | block |
| `dependency-rule` | assert core depends on nothing in-workspace; nothing depends on bin | block |
| `egress-labels` | every `AdapterManifest` declares an `EgressLabel` | block |
| `quirk-vault` | every cmux fact in `ctide-mux-cmux` carries `// fact:` + a fixture test, and nowhere else | block |
| `crap` | `crap4rs` (config from `crap.toml`); `ctide-core` at strict-8 | block |
| `linux-musl-compile` | `cargo build --workspace --locked --target <musl-target>` — pass `targets: <musl-target>` to `setup-rust`, **and** provide the cross-linker (zigbuild/`cross`, or a prebuilt `aarch64-linux-musl-cross` + `CARGO_TARGET_*_LINKER`); or run `x86_64-unknown-linux-musl` natively with only `musl-tools` for the cheap insurance variant (see §1.7 musl note) | block (compile-only) |
| `strangler-gate` | `shellcheck bin/* lib/*.sh` + `sh tests/run.sh` (the ~120-assertion shell golden master, **unchanged**) | block (during coexistence) |
| `slo-bench` (release depth) | hyperfine cold-start of `ctide doctor` against FakeMux — **gate 5**, informational on this slice | record |

`crap.toml` (adopt crap4rs as the CRAP gate;
[`research/ci-quality-framework.md`](./research/ci-quality-framework.md) §8):

```toml
preset = "default"                       # 15 — honest line for a strangler-built tree
src = [
    "crates/ctide-core/src",
    "crates/ctide-json/src",
    "crates/ctide-mux-cmux/src",
    "crates/ctide-adapters/src",
    "crates/ctide/src",
]
exclude = [
    # adr: ops/decisions/cmux-terminal-ide/adr-testkit-coverage.md — ctide-testkit is
    # test infrastructure (FakeMux, fixtures, replay server); 0% production-gate by design.
]
[language.rust]
metric = "cognitive"
[[thresholds.overrides]]
glob = "crates/ctide-core/src/**"
threshold = 8                            # strict — the hexagon is the asset
```

**Determinism (must hold for "deterministic CI"):** `--locked` on every cargo
invocation; `Cargo.lock` committed; fixtures version-stamped under
`fidelity/<cmux-version>/`, generated by `ctide-testkit gen-fixtures`, never
hand-authored; `jiff` timestamps + `uuid`s normalized before any diff; SHA-pinned
actions ([`research/ci-quality-framework.md`](./research/ci-quality-framework.md)
§6).

---

## 7. The step-ordered task list (one focused build session)

Sized to finish in one focused session: small enough to land, real enough to prove
the architecture. Each step references the section that specifies it.

**Phase A — R0 scaffold (epic E0).** Land before any doctor code.

1. **Rename the GitHub repo** `cmux-workspace-dbt → cmux-terminal-ide` in place;
   create the empty `homebrew-tap`; **defer the local-dir rename** (§1.6,
   [`rebrand-ctide.md`](./rebrand-ctide.md)). *(Owner/builder action — not in this
   planning doc.)*
2. **Create the workspace `Cargo.toml`** with the 8-crate member list + the
   dependency budget catalog (§1.2). Add `rust-toolchain.toml` pinned to a
   specific stable (§1.3), `rustfmt.toml`, `clippy.toml`.
3. **Stub all 8 crates** so `cargo build --workspace` compiles (`ctide-dbt` /
   `ctide-place-macos` are doc-only stubs) (§1.1).
4. **Port the crap4rs CI/quality template**: `setup-rust` action verbatim,
   `deny.toml` (§1.5), `crap.toml` (§6), `lefthook.yml` (Rust gates + the
   preserved shell gate), `.config/nextest.toml`, `release-plz.toml`, mdBook +
   Pages (un-triggered), `cargo-dist` skeleton (§1.4).
5. **Write the structural lint scripts**: `dependency-rule`, `dep-budget`,
   `no-config-write`, `egress-labels`, `quirk-vault` (§6).
6. **Prove the gates with planted violations** (R0 exit, §1.7): core→bin import,
   shipped `tokio`, `~/.config` literal — each must turn CI red, then revert.
   Confirm `linux-musl-compile` green.

**Phase B — the doctor slice (first slice of epic E1).**

7. **`ctide-core` domain types** the slice touches: ids, topology, identity,
   capability, egress/manifest, provenance (§2). Keep it tiny (CRAP strict-8).
8. **`ctide-core` ports**: `MuxTopology` (full) + `Multiplexer` supertrait
   (reflection methods full; write-side traits declared, methods stubbed) (§3).
9. **`ctide-core` use-case**: `plan_doctor(&DoctorInput) -> DoctorReport` — pure;
   unit-test it directly with hand-built `DoctorInput`s (§3). *This is where the
   logic — egress aggregation, drift diff, provenance — and most tests live.*
10. **`ctide-json`**: `DoctorPayload` + `SCHEMA_VERSION = 1`; the round-trip
    proptest (gate 1) (§5).
11. **`ctide-testkit` FakeMux**: read path + op-recording; `from_fixture`; the
    blast-radius test (`recorded_ops().is_empty()` after a doctor run) (§4).
12. **`ctide-testkit` conformance kit**: `conform_multiplexer(&dyn Multiplexer,
    &FixtureSet)` (§4) + `gen-fixtures` writing `fidelity/<cmux-version>/`.
13. **`ctide-mux-cmux`**: `CmuxSocketAdapter::{tree, identify, capabilities,
    manifest}` over v2 JSON; all wire parsing in `wire.rs` with `// fact:` +
    fixture tests; the cwd-merge quirk; the capability-drift diff (§4).
14. **`ctide-testkit` replay server**: replay a recorded socket session so
    `conform_multiplexer` runs against `CmuxSocketAdapter` with no live cmux —
    **gate 3** (§4).
15. **`ctide` bin**: clap `doctor [--json] [--mux-transport]`; the composition
    root that builds the Multiplexer impl + `ResolvedConfig`; `execute` (the I/O
    shell) calling `plan_doctor`; the `From<&DoctorReport> for DoctorPayload` impl
    **in the bin**; human + `--json` rendering (§3/§5).
16. **Wire the five gates in CI** and confirm green: gate 1 (round-trip + insta
    snapshot), gate 2 (FakeMux conformance), gate 3 (replay conformance), gate 4
    (`deny` + `no-config-write`), gate 5 (`slo-bench` cold-start record) (§0/§6).
17. **Ship the mdBook chapter** for `ctide doctor` in the same PR (docs-as-you-go;
    `mdbook-linkcheck` passes) — [`roadmap.md`](./roadmap.md) §2 principle 3.
18. **Run `ctide doctor` against live cmux behind `--ignored`** once to generate
    the first `fidelity/<cmux-version>/` snapshot (the live tier; not a PR gate).

**Definition of done:** all five gates in §0 green on a PR into
`cmux-terminal-ide`; `FakeMux.recorded_ops()` empty after a doctor run (zero blast
radius proven); the `ctide doctor` chapter exists and link-checks.

---

## 8. Explicitly out of scope for this slice

To keep the slice finishable in one session, these are **deferred** to the rest of
E1 and later phases (do not pull them forward):

- **Write-side traits' real bodies** (`MuxSurfaces`, `MuxWorkspaces`, etc.) — R2+.
  Declared and stubbed only.
- **The other parser killers** `ctide theme` / `ctide agent ls` / `ctide
  statusline` — rest of E1 (they need the versioned shell-format readers + the
  `ThemeTarget`/`ApplyPlan` port).
- **`ctide state migrate`** (g6) — rest of E1; no state family migrates for a
  read-only verb.
- **`CmuxCliAdapter` fallback** — rest of E1.
- **The runner, spaces, place, sync, review, policy, recipes** — R2–R5.
- **`cargo-dist` actually publishing** + the public brew tap — R5 (and gated on the
  GPL-v3-vs-MIT license ruling, [`../vision/design-plan.md`](../vision/design-plan.md)
  §12 OQ #8).
- **`slo-bench` as a release blocker** — it only *records* on this slice; it
  becomes a blocker once hot-path verbs land (R2/R4).

---

## 9. Open questions this slice surfaces (resolve at or before scaffold)

From [`../vision/design-plan.md`](../vision/design-plan.md) §12 and
[`research/ci-quality-framework.md`](./research/ci-quality-framework.md) §10 — the
ones that touch R0/R1:

- **Q1 user-config layer location** ([`../vision/design-plan.md`](../vision/design-plan.md)
  §12): keep `~/.config/ctide/config.toml` as a **read-only** layer
  (recommended — honors the write rule as written) vs relocating to
  `~/.local/share/ctide/`. One path constant; **needs a ruling before R1** because
  `doctor`'s provenance (g5) names the layer.
- **Q5 `ctide-json` versioning policy**: single `schema = N` integer (this slice
  ships `1`) vs semver; what deprecation window agent consumers get. The slice can
  ship `schema = 1` and defer the *policy*; flag it.
- **Toolchain pin granularity** ([`research/ci-quality-framework.md`](./research/ci-quality-framework.md)
  §10.2): pin specific stable `1.NN.0` (recommended, max determinism) — confirm the
  exact version at scaffold time.
- **CRAP ratchet** ([`research/ci-quality-framework.md`](./research/ci-quality-framework.md)
  §10.1): confirm workspace `default` (15) with `ctide-core` at strict-8, ratchet
  the workspace to strict after R4. (Adopted as-is in §6.)
- **License** ([`../vision/design-plan.md`](../vision/design-plan.md) §12 OQ #8):
  GPL-v3 org default vs cute-dbt's MIT. Blocks the **public** tap (R5), not this
  slice — `[licenses].allow` and `[workspace.package].license` carry GPL-3.0-only
  provisionally.

---

*Spec complete. This slice builds the empty-but-real `ctide` workspace (E0) and
the smallest verb that exercises every layer — `ctide doctor` over `MuxTopology`,
green across FakeMux + replay server (g7) + live `--ignored`, with the five CI
gates as the definition of done. It mutates nothing, earns trust day one, and
proves the dependency rule, the contract crate (g4), the conformance kit (g7), and
the three-impl testing story before any feature rides the rails. Next after this:
the rest of E1 (parser killers + state migrate), then E2's runner (keystone A) at
R2.*
