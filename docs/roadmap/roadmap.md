# ctide Master Roadmap — building cmux-terminal-ide

> **This is the build plan, not a menu of options.** It synthesizes the approved
> product vision + design plan (merged PR #23,
> [`docs/vision/`](../vision/)) into one sequenced program: the strangler
> migration of the POSIX-sh `cide` dogfood into **cmux-terminal-ide**, a single
> daemonless Rust binary named **ctide**. Five recon notes feed it (see §8);
> where they agree, this roadmap is decisive; where the design plan left an open
> question, this roadmap rules. 2026-06-12.

---

## 1. North star + how to read this roadmap

**North star (from [`docs/vision/product-vision.md`](../vision/product-vision.md)):**
an agent-native terminal IDE composed *on* cmux — "the multiplexer IS the
supervisor" — that ships a solid **base IDE** plus a **dbt** vertical and a
**rust-dev** vertical, all as recipes over one library-first Rust binary. Seven
pillars (P1 spaces-as-unit-of-work, P2 review-queue-as-inbox, P3 attention
engineering, P4 fix-on-red, P5 agents-are-users, P6 keystroke-reachable flow,
P7 trust/zero-egress). The architecture is locked by
[`design-plan.md`](../vision/design-plan.md): **daemonless**, no tokio, a
hexagonal crate DAG with trait ports, an R1–R5 strangler migration, an 8-tier
testing model, and grafts g1–g7. **Read this roadmap top-to-bottom once** for
the shape, then use §3 (phase table) as the program contract, §4 (epic list) as
the work breakdown, §5 (walking skeleton) as the very first thing to build, and
§7 (dependency view) as the build-order guardrail. The five detail docs (§8)
expand each surface; this file is the index they hang off.

---

## 2. Sequencing principles (the load-bearing logic)

Every ordering decision below derives from one of these. They are not
negotiable; they are *why* the sequence is the sequence.

1. **Strangler-fig, in one tree.** Each `bin/cide-*` script grows a 3-line
   `exec ctide <verb>` preamble; `CTIDE_SHELL=1` is instant rollback. Old shell
   and new Rust coexist verb-by-verb through R1–R5. This *requires colocation* —
   it is the first reason the repo is renamed in place, not forked (§3 R0).
2. **Walking-skeleton first.** The very first slice proves *every layer* end to
   end (bin → adapter → port → contract crate → CI gate) before any feature
   rides the rails. That slice is `ctide doctor` over the `Multiplexer` port
   against FakeMux (§5).
3. **Docs + CI as-you-go, never big-bang.** R0 stands up the crap4rs-derived CI
   and the mdBook walking skeleton; *each epic ships its chapter and its gates in
   the same PR.* A verb is not "done" until its golden-master diff is clean, its
   chapter exists, and `mdbook-linkcheck` passes.
4. **Dogfood value in every increment.** No increment is pure plumbing. The
   first shell slice (E7 R0) ships dbt review *today*; the first Rust verb
   (`ctide doctor`) is useful day one; the first felt-every-session capability
   (`ctide run`) ships at R2. Risk #8 (two-generation limbo) is mitigated by
   never shipping a step the owner can't *use*.
5. **Keystone-first.** Two load-bearing investments gate everything downstream:
   **#1 the runner engine** (keystone A, R2 — feeds #4/#9/#13/#15) and **keystone B
   = the declarative hook tier** (the `policy` / `turn-complete` hook binaries, R4 —
   what actually ships and is depended upon; **NOT** the gated reactor daemon, which
   is tier-3, gated, and may never be built). Build keystones before their leaves.
6. **No new shell after R1.** The *only* sanctioned net-new shell feature is
   E7's R0 dbt-review slice (vision §4), which may be **authored and iterated
   through R0–R1**. The freeze applies to **net-new shell capability conceived
   after R1 lands** — design rule (4) — so new capability is Rust-only and the gap
   only ever closes; fixes/polish to the one sanctioned slice are not new features
   (see the v1-line freeze rule in §3).
7. **Hard human gates are real stops.** End-of-R2 re-approval (architecture-bet
   evidence) and the R3 live agent-resume round-trip (the P1 asterisk) are
   blocking. The roadmap does not advance past them on its own.
8. **Constraints win over best-practice.** Zero-egress/local-first,
   never-write-`~/.config`, no-tokio (runner wraps the watchexec *binary*, not
   the library), macOS-first/Linux-not-precluded. Where a 2026 convenience
   collides with one of these, the constraint wins, mechanically enforced by CI
   gates (deny.toml bans, the `~/.config` grep gate, the dep-budget assertion).

---

## 3. The phase table (R0 → R5)

> **Appetite key:** S = a session or two · M = 1–3-week PR arc · L = multi-month
> program. Grafts g1–g7 and risks #1–#9 reference
> [`design-plan.md`](../vision/design-plan.md) §§4/9/11.
>
> **Per-phase budget (authoritative).** These per-phase boxes are the **design-plan
> §9 numbers** — R1 = 3 wk, R2 = 2 wk, R3 = 3 wk, R4 = 2 wk, R5 dbt slice = 2 wk
> (≈12 build-weeks) — and they **supersede the vision §4's looser R1+R2 / R3+R4
> six-week pairings** (the design plan is the more precise, more recent source). v1
> appetite ≈ **12 build-weeks of solo-founder time, spread across calendar months**
> alongside mokumo/ops. The rule holds both ways: **when a phase blows its box, cut
> scope, not the box** (§2 principle 4 / design-plan §9).

### R0 — Rebrand + scaffold + CI/quality foundation  *(appetite: S–M)*

- **Goal.** Stand up the empty-but-real `ctide` Rust workspace, its CI/quality
  gates, and the dependency-rule enforcement *before a single verb is ported* —
  so R1's first port lands into a structure that already says "no" to tokio,
  HTTP, `~/.config` writes, and manifest-less adapters.
- **Headline epic.** **E0** (scaffold the workspace) + the **repo rename**.
- **Exit criteria (testable).** `cargo build/test --workspace` green on the
  empty 8-crate skeleton in CI, on aarch64-darwin **and** aarch64-linux-musl
  (compile-only); the dependency-rule gate *fails a planted violation* (core
  importing the bin); `cargo-deny` rejects a planted `tokio`/`reqwest` in a
  shipped crate but allows it as a dev-dep (the `exclude-dev` scope); the
  `~/.config` grep gate rejects a planted literal; crap4rs runs as a CRAP gate;
  the mdBook + Pages workflow exist (held un-triggered). **GitHub repo renamed
  `cmux-workspace-dbt → cmux-terminal-ide`; `homebrew-tap` created (empty).**
- **Dependencies.** None outside this repo. **Blocks everything.** Resolve the
  repo-location ruling first (resolved below).
- **Grafts / risks.** Builds the *homes* for g4 (`ctide-json` stub), g7
  (`ctide-testkit` stub), g1 (cucumber + proptest harness). **Retires the
  structural half of #4** (dep-creep — the deny allowlist is load-bearing from
  line one) and **part of #5** (bus-factor — proven CI template, not hand-rolled).

> **Repo-location ruling (decisive — the roadmap was asked to recommend, not
> assume).** **Rename `cmux-workspace-dbt → cmux-terminal-ide` in place. Do NOT
> start a new repo.** All three recon docs that examined it concur. Three reasons:
> (1) the **POSIX golden master** (`tests/run.sh` — ~120 emitted-command
> assertions[^gm]) — the strangler "permit" — lives in *this* repo and the
> migration is *defined* as diffing each
> Rust verb's emitted ops against its shell twin on the same fixtures; a fork
> severs that. (2) **Strangler coexistence requires one tree** — the `exec ctide`
> preamble + `CTIDE_SHELL=1` rollback are single-repo mechanisms by construction.
> (3) **`prior-decisions` §1 already ruled this way** ("colocated, executed at
> Cargo-scaffolding time; parallel greenfield repo rejected") — a fork
> re-litigates a settled decision and collapses R1–R5 into the big-bang rewrite
> the vision rejected. *Caveats at rename time:* update the brew formula
> (`cide → ctide`) + CI/`gh` refs; rename the GitHub repo at R0 but **defer the
> local-dir rename** (it orphans the Claude project-memory path key — keep the
> checkout path stable). See [`rebrand-ctide.md`](./rebrand-ctide.md).
>
> **Stale-label note.** The design plan's §2 directory layout still labels the
> workspace root `cmux-ide/` ("repo, post-rename") — that is a **pre-rebrand
> artifact** predating the 2026-06-09 decision. The authoritative repo/workspace
> name is **`cmux-terminal-ide`**; a builder mirroring §2's layout must not use
> `cmux-ide/` as the dir name (see [`rebrand-ctide.md`](./rebrand-ctide.md) §2.3).

[^gm]: "~120" = the live count of emitted-command assertion call sites in
    `tests/run.sh` (the helper invocations `log_has`/`out_has`/`has_file`/… plus the
    inline `ok`/`bad` branches), at commit `fda9418`. Earlier drafts said "113";
    the R5 cucumber-conversion target is the **full** golden-master assertion set as
    it stands at conversion time, not a frozen number — re-count at R5.

### R1 — Foundations: the trust surface + parser killers  *(appetite: M, ~3 wk)*

- **Goal.** Stand up the binary skeleton, the cmux socket adapter + quirk vault,
  and the read-only "parser killer" verbs — earning trust with **zero blast
  radius** (no live-state mutation).
- **Headline epic.** **E1** (foundations / doctor). **← the walking skeleton
  (§5) is proven here.**
- **Exit criteria.** `ctide doctor` prints the exact two-layer network surface
  (cide's own + cmux substrate) and runs offline; `ctide theme` produces a
  themed result with **zero `~/.config` writes** and no tracked-file churn;
  `ctide agent ls` / `ctide statusline` read shell-format state through versioned
  readers and match shell output; the port conformance kit is green against
  **FakeMux** (always) **and** the **recorded replay server** (g7); the
  capability probe diffs live cmux vs the pinned fidelity snapshot.
- **Dependencies.** R0.
- **Grafts / risks.** Lands **g4** (`ctide-json` frozen + shipped), **g5**
  (doctor provenance), **g6** (`ctide state migrate` discipline established),
  **g7** (replay-conformance tier live). **Retires #1's standing exposure** (one
  wire module + versioned fixtures + capability probe + CLI second oracle) and
  the hygiene violations #9/#10. First *bite* of #1 happens here — the
  regen→diff→fix→green playbook gets its first exercise.

### R2 — Runner + guarded writes  *(appetite: M, ~2 wk)*  ← KEYSTONE A

- **Goal.** Ship the runner engine (the #1 keystone, first capability that never
  existed in shell) plus the first mutating verbs — proving the write paths and
  `InjectionGuard` safety under golden-master parity, and **load-hardening the
  socket/pipe/state paths before the crown jewels ride them** (graft g2's
  runner-before-spaces reorder).
- **Headline epics.** **E2** (runner + status bus). **E3 is the gate, not work.**
- **Exit criteria.** `jump`/`open`/`set-role`/`md-open`/`agent new|rename` pass
  the **golden-master diff** vs their shell twins (the *first* golden-master
  gate); `InjectionGuard` makes a blind `send_text` *uncompilable*; `ctide run
  wrap` drives a red→fix→green cycle producing a structured `Diagnostic` (never
  pasted ANSI) and, with `fix_on_red`, submits via `prompt_submit`; the g1
  hook-storm convergence property runs against `run wrap`; the agents state
  family refuses to run unmigrated (g6).
- **Dependencies.** R1 (socket adapter, quirk vault, `ctide-json`,
  `state migrate`). Runner wraps the **external watchexec binary** (no tokio).
- **Grafts / risks.** Realizes **g2** (runner-first), first applies **g1**
  (convergence), applies **g3** (binary-version self-check on the long-lived
  `run wrap` pane), migrates the agents family (g6). **Retires #8 materially**
  (never-had capability + ~zero-cost exec shims) and **#3** (hook-storm races via
  g1 + flock + atomic rename). Exposes #6 (helix), partially #4 (latency).
- **🚦 HARD GATE — end-of-R2 re-approval.** Golden-master parity holding +
  the runner shipped and dogfooded **is** the evidence the architecture bet paid
  off. Christopher re-evaluates *here*, before R3. **The program does not
  advance to R3 on its own.**
- **Early product-signal read (closes the late-flagship risk).** The flagship
  review-queue hypothesis (P2 — "review is the new inbox") is the architecture's
  whole justification, yet its first *full* falsification (`ctide review` walking
  turns across a space) is structurally late: it cannot land until R4, after the
  R3 spaces crown jewels are built *for* it. To get a product read **before**
  committing to R3, the end-of-R2 gate must **also surface fleet-log / shell-era
  evidence of whether the review-shaped behaviors are actually used** (the E7 R0
  dbt-review loop's adoption + how often the owner inspects agent turns in the
  dogfood) — so the re-approval doubles as the P2 hypothesis's first read, not just
  an architecture-bet read. *(Optional accelerator: a minimal single-agent
  `ctide review` — current workspace, no cross-space walk, riding the R2 runner +
  a `Stop` hook — does **not** structurally require the full spaces port and could
  ride R2/early-R4 to get a 2-week P2 read sooner; the full cross-space review
  still lands at R4/E6.)* This risk is named, not eliminated: the flagship's first
  full falsification remains R4, and that is an accepted, surfaced risk.

### R3 — Spaces + place (the crown jewels)  *(appetite: M, ~3 wk)*

- **Goal.** Port the unit of work itself — resumable spaces (P1) — and
  monitor-aware placement, gated hard on golden-master parity **and the live
  agent-resume round-trip.**
- **Headline epic.** **E4** (spaces / resume / placement; native containers
  **pending Q4**).
- **Exit criteria.** `space new|open|close|rm|ls` and `place` pass the
  golden-master diff; **the live agent-resume round-trip verify passes** (a space
  closed Friday reopens Monday with layout + role-stamped agent conversations +
  tool sessions as one object — the pending verify that gates task #29); the g1
  convergence property covers space open/close writes; spaces + registry families
  round-trip via `ctide state migrate` collision-free; placement returns typed
  `Placed | Skipped { reason }` (never silent); Linux `NoopPlacement` never
  blocks.
- **Open ruling — native space containers (#6).** Whether `workspace.group.*`
  native containers land **at R3 alongside the spaces port** or as a **post-R3
  enhancement** is design-plan §12 Q4, still unresolved (groups are within-window
  only; the registry stays the cross-monitor join either way). The roadmap does
  **not** silently commit #6 to R3 — it is listed here as *pending Q4*, the same
  way r1-walking-skeleton §9 / ci-quality §10 flag the other open §12 questions.
  Resolve Q4 (an owner ruling) before E4 is shaped.
- **Dependencies.** R2 **and the end-of-R2 gate passed.** `ctide-place-macos`
  needs objc2 + the live AX grant.
- **Grafts / risks.** Completes **g6** (spaces + registry migrated), extends
  **g1** to space writes. **Retires the P1 asterisk** (the single biggest open
  verification in the vision) and **#8 fully** (crown jewels Rust-native, shell =
  shims). Exposes #1 *hardest* (spaces are the most quirk-dense verbs) and #6
  again (AX fragility, confined to one adapter).
- **🚦 HARD GATE — the live agent-resume round-trip** is itself a blocking
  verification, not just an exit test.

### R4 — Rust-only capability: review loop + config compiler  *(appetite: M, ~2 wk)*  ← KEYSTONE B (tier-1)

- **Goal.** Ship the flagship review loop, the config→`.cmux/*` compiler, and the
  policy hook — all Rust-from-birth, riding **declarative hooks + catch-up** (no
  reactor).
- **Headline epics.** **E5** (sync / setup / policy / keymap / replace / focus —
  keystone B tier-1) + **E6** (the review-queue flagship + fix-on-red + triage +
  dashboard).
- **Exit criteria.** `ctide sync` deterministically compiles resolved config →
  `.cmux/cmux.json` + `.cmux/dock.json` (idempotent re-run; hand-edited
  `.cmux/cmux.custom.json` survives); the generated Feed control is `--legacy`
  (doctor audits — no npm fetch); `ctide review` (cucumber-rs) walks unreviewed
  turns across ≥2 agent slots vs FakeMux; `ctide policy` round-trips a
  notification JSON as a pure stdin→stdout filter; the g1 **canonical** 50-way
  hook-storm runs against `policy × turn-complete`; `ctide setup` is the **only**
  path that writes a global file (a planted write elsewhere fails consent-token +
  grep gates); flow-SLO hyperfine benches (cold start < 10 ms, `jump --dry`
  < 30 ms) pass as release blockers (**relative-regression-gated vs a pinned
  reference binary; the absolute budgets are asserted with warmup + tolerance and
  are authoritative only on the release machine — hosted runners are too noisy for
  10 ms-scale absolutes; see ci-quality-framework §4.8**).
- **Dependencies.** R3 (review walks turns *across a space*; sync compiles
  space/binding config).
- **Grafts / risks.** Fully realizes **g1** (the canonical hook-storm target).
  **Retires #4** in earnest (hot-path budgets now release-blocking). Exposes #2
  (the reactor/residency bet — if `review`/`policy` *need* residency, the
  promotion gate is first pressure-tested) and tests #9 (Sherlocking — review
  queue is the most absorbable differentiator). **The kill-condition metric
  (≥80% turns reviewed within 2 weeks of R4) is measured here** — and this is the
  P2 thesis's *first full* falsification, structurally late (after R3 spaces are
  built *for* it). The end-of-R2 gate's product-signal note (§3 R2) gets an earlier,
  partial read so the bet is not discovered wrong only after the crown jewels ship.
- **Note.** The daemon-shaped reactor **tier-3 is NOT here** — it is gated and
  may never be built (vision §8, risk #2). E6 ships on hooks + catch-up alone.

### R5 — Verticals + retirement: the dbt recipe + v1 close  *(appetite: M, 2–3 wk for the dbt slice)*

- **Goal.** Land the dbt vertical **as data** (recipe + adapter code), trigger
  the rust-dev recipe at the Rule-of-Two point, delete the shell bodies, and
  convert the POSIX golden master to cucumber features — closing v1.
- **Headline epic.** **E7** (the dbt-recipe slice, R5 half). E8/E9/E10 are
  *post-v1*.
- **Exit criteria.** A bare machine runs `ctide space new --type dbt` in a dbt
  repo and gets the full recipe via `include_str!` (no runtime downloads);
  `DbtReview` snapshot→compare round-trips against cute-dbt with **egress label
  zero** (network-block CI proves it); the **Rule-of-Two acceptance test
  passes** — rust-dev's bacon/nextest/mutants jobs run through the *same*
  RunnerEngine/status/review ports as dbt's, recipe-only differences, **zero
  rust-specific branches in `ctide-core`** (the architecture's own falsifier);
  the converted cucumber suite passes the **full POSIX golden-master assertion set**
  (~120 emitted-command assertions in `tests/run.sh`[^gm], re-counted at conversion
  time — never fewer); `cargo-dist` ships per-arch darwin artifacts + the brew
  formula.
- **Dependencies.** R4 (`ctide focus`/`review`/`sync` the dbt recipe rides). The
  fully-composed dbt journey depends on **cute-dbt F1 (#105 SemVer'd JS
  contract) + F6 (crates.io publish)** — *but the `DbtReview` shell-out works
  pre-publish.* rust-dev is gated on the Rule-of-Two trigger, not a date.
- **Grafts / risks.** All grafts land by R4; R5 *exercises* them across
  verticals. **Retires #7** (dbt churn — knowledge quarantined behind `DbtReview`
  + recipe data; base/rust ship zero dbt deps) and **validates the whole
  ports/adapters bet.**

> **v1 line:** **v1 = R1–R4 base (E1, E2, E4, E5, E6) + the R5 dbt-recipe slice
> (E7, with backlog #5 behind `DbtReview`).** E8/E9/E10 (#12/#13/#15) are
> explicitly post-v1 L-effort vertical moats. The lone "now" exception: backlog
> #5's review loop ships from the **POSIX dogfood before R1 begins** (E7 R0
> slice). **Freeze rule, precisely:** the E7 R0 dbt-review shell slice may be
> authored and iterated through R0–R1; the shell freeze applies to **net-new shell
> capability conceived after R1 lands** — fixes/polish to the one sanctioned slice
> are not new features, and do not violate the freeze (principle 6).

---

## 4. The epic list

> **Tag key:** base / dbt / rust / agent / cross. **Top-20** = the ranked
> opportunity backlog item(s) the epic realizes (see
> [`docs/vision/research/opportunity-backlog.md`](../vision/research/opportunity-backlog.md)).
> Full mapping + per-opportunity disposition:
> [`first-issues.md`](./first-issues.md) (backlog→epics detail).

| Epic | Scope (one line) | Phase | Tag | Depends on | Top-20 realized |
|---|---|---|---|---|---|
| **E0** | Scaffold the `ctide` workspace (8-crate DAG, crap4rs CI template, deny/lefthook/release-plz, mdBook skeleton) + **repo rename** | R0 | cross | — | (foundation; none) |
| **E1** | Foundations: socket adapter + quirk vault + `ctide-json` (g4) + `ctide doctor` (g5/g7) + `state migrate` (g6) + parser killers (`theme`/`agent ls`/`statusline`) | R1 | cross | E0 | **#17** |
| **E2** | Runner engine + status bus (`run`/`run wrap` wrapping watchexec binary; just/make/npm/cargo catalog; bacon fast-path) + agents-cluster write-verbs (`set-role`/`jump`/`open`/`md-open`/`agent new|rename`) | R2 | cross | E1 | **#1** (keystone A), **#4** (R2 half) |
| **E3** | *(reserved — the end-of-R2 re-approval gate; a decision point, not shippable work)* | R2→R3 | — | E2 | — |
| **E4** | Spaces + N-slot resume + capture-layout + monitor-aware placement (objc2 in-process, retires Swift helper); native space containers (#6) **pending Q4 — R3-with-spaces vs post-R3 (design-plan §12)** | R3 | cross | E2 + gate | **#11, #7, #8 (core), #18-substrate; #6 pending Q4** |
| **E5** | Rust-only infra: `sync` (config→`.cmux/*`) + `policy`/`turn-complete` (**keystone B = the declarative hook tier — the `policy`/`turn-complete` binaries; NOT the gated reactor daemon**) + `setup` (sole consented `~/.config` write) + keymap layer + `replace` + `focus` | R4 | base/cross | E4 | **#3 (tier-1 hooks), #14, #19, #20** |
| **E6** | Review-and-loop flagship: `review` queue (subsumes #25 inline PR review + #26 stacked diffs) + fix-on-red (#9) + triage cockpit / fleet log (#10) + spaces dashboard (#16 v1) | R4 | agent | E5 (+ consumes E2) | **#2 (flagship), #9, #10, #16 (v1)** |
| **E7** | dbt recipe slice: R0 shell demo (cute-dbt review loop — *the one allowed shell feature*; must ship its own golden-master assertions, see note) → R5 rebuild behind `DbtReview` port + `recipes/dbt.toml` + Warehouse port + defer/slim slice | R0 demo → R5 | dbt | E5 (R5 half); standalone (R0 slice) | **#5 (v1), #13 defer/slim slice** |
| **E8** | Local-first dbt intelligence ladder (LSP→watch-compile→L2 intelligence on Apache dbt-core v2→plan/impact apex). **BLOCKED pending OQ#6 (verify v2-crate LSP coverage) + dbt-core v2 leaving alpha — research-gate, do not shape until both clear** | post-v1 (rides R5) | dbt | E7 | **#12** (L moat) |
| **E9** | dbt-aware harlequin bridge + full execution (`ref()` resolution, CTE preview via cute-dbt F2, `dbt show`-grade). **BLOCKED pending OQ#6 + dbt-core v2 leaving alpha — same research-gate as E8** | post-v1 (rides R5) | dbt | E7, E8 | **#13** (destination, L moat) |
| **E10** | Rust quality cockpit (test-tree explorer, bacon `.bacon-locations`, mutation-survivor triage TUI, unified pill row) — the Rule-of-Two validator | post-v1 (Rule-of-Two trigger) | rust | E2, E4, E5 | **#15** (L moat) |

Notes on the table:
- **Local task crosswalk** (so nothing is double-counted): #23→#1 (E2); #24
  prompt-line is *not* top-20 → a recipe/setup chore under E2, not an epic;
  #25/#26 fold into #2 (E6); #27→#19 (E5); #28 already shipped (shell) → E4 ports
  it; #29→#11 (E4, gates the R3 live round-trip); #30→#7 capture-layout (E4);
  #31/#32→`place` (E4).
- **Net-new vs strangler-reuse** is itemized in [`first-issues.md`](./first-issues.md):
  reuse (port behind golden master) = theme/agent/statusline (E1), the
  agents-cluster verbs (E2), `cide-space`/`cide-place`/`cide-layout.sh` (E4),
  `cide-regen`→`sync` and `cwd-*` (E5/E7), `hq-wrap`/`hq-preview` (E7); net-new
  (never in shell) = runner *engine*, review queue, event reactor, status bus,
  fix-on-red, fleet log, dashboard, doctor, capture-layout, `ctide replace`, and
  all of #12/#15 + the gated reactor.
- **The E7 R0 shell slice is not exempt from the strangler's own rules.** Although
  it *reuses* `hq-wrap`/`hq-preview`/`cwd-*`, the **review-loop composition itself
  is net-new shell surface** — so it must (i) **extend `tests/run.sh` with
  assertions for its emitted commands**, giving it a golden-master twin to convert
  at R5 (consistent with the permit discipline — no untested, un-permitted shell
  exception), and (ii) it is **exempt from the `exec ctide <verb>` preamble until
  its Rust twin exists at R5** (it can't grow the preamble at R0 — `ctide` does
  nothing yet). It still passes the strangler gate it lands into
  (`shellcheck bin/* lib/*.sh` + `sh tests/run.sh`).

---

## 5. The walking skeleton — the first thing we build

**Build this first, exactly: `ctide doctor` over the `Multiplexer`
(`MuxTopology`) port, against `FakeMux`, green in CI.**

This is the smallest slice that exercises *every layer* of the architecture with
**zero blast radius** (it mutates nothing):

- **Port:** the `Multiplexer` supertrait — `ctide doctor` calls
  `MuxTopology::tree()` / `capabilities()` / `manifest()`, the single most
  load-bearing port, read-only.
- **Verb:** `ctide doctor` — a low-frequency trust/diagnostic verb (its job is to
  prove the rails + the zero-egress posture, *not* to change the daily loop — see
  §6.2); it aggregates egress labels (P7), config provenance (g5), and capability
  drift (g7 probe), so the *first* slice already demonstrates the trust posture,
  the contract crate (g4 via `--json`), and the conformance probe.
- **FakeMux + the three-impl proof:** the *same* conformance assertion runs
  against **FakeMux** (always), against `CmuxSocketAdapter` over the **recorded
  replay server** (g7), and against **live cmux behind `--ignored`**. Getting
  `doctor` green across all three *is* the proof that "the third impl is the
  testing story."
- **The CI gate that must be green** (the walking-skeleton definition of done):
  1. `ctide doctor --json` returns a `ctide-json`-typed, `schema`-versioned payload.
  2. `conform_multiplexer(&FakeMux, fixtures)` is green.
  3. The same suite is green against `CmuxSocketAdapter` over the replay server (g7).
  4. The `~/.config` grep gate + `cargo-deny` (no-tokio/no-HTTP) gates are green.
  5. The flow-SLO hyperfine harness records `doctor` cold start (first budget point).

Full slice detail — crate-by-crate, the FakeMux contract, the conformance kit
shape — is in [`r1-walking-skeleton.md`](./r1-walking-skeleton.md).

**Runner-up (do *not* start here):** `ctide run wrap` over `MuxSurfaces` proves
the *write* paths but is heavier (state writes, parser, fix-on-red). Use
`doctor` to prove the **architecture**; use `run wrap` to prove the **write
paths** immediately after, at R2.

---

## 6. The first increment for daily dogfood value

There are two co-equal "firsts," because the vision pins one shell slice *and* one
Rust slice, and they ship in parallel from week zero. **The morale-and-validation
win is the shell slice — ship it in week 0, before/parallel to the E0 scaffold —
then scaffold.** The two are *different kinds of first*: the shell slice is the
first **daily-flow value**; `ctide doctor` is the first **Rust slice to build** (it
proves the architecture, not the daily loop).

### 6.1 First daily-value increment (week 0): the E7 R0 cute-dbt review loop  *(backlog #5)*

This is the highest appetite-efficiency win in the whole program: **zero Rust,
reuses tools already on disk, ships in week 0** — the owner's actual
analytics-engineering inner loop and the dbt vertical's identity demo. It is also
the *only* sanctioned net-new shell feature (vision §4); after R1 the freeze holds
(authoring/iteration permitted through R0–R1, see the v1-line freeze rule in §3).

- **What ships (concrete, shippable):** a `bin/` shell composition — `dbt compile`
  → `cute-dbt --baseline-manifest <prev> --manifest <current>` → render the diff to
  a themed `file://` report surface opened via `hq-preview`, reusing
  `hq-wrap`/`hq-preview`/`cwd-*` + the cute-dbt CLI already on disk. A one-key
  re-run from the runner pane. No new external tools; no network beyond what cute-dbt
  already does locally.
- **Acceptance (week-0 done):**
  1. In a real dbt repo, the loop compiles, diffs vs the baseline manifest, and
     surfaces the themed report — **fully offline** (egress label zero).
  2. The net-new review-loop composition **ships its own assertions in
     `tests/run.sh`** (its emitted commands), so it has a golden-master twin to
     convert at R5 — it is not an untested, un-permitted shell exception (§4 note).
  3. It passes the strangler gate it lands into (`shellcheck bin/* lib/*.sh` +
     `sh tests/run.sh`).
  4. It is **exempt from the `exec ctide <verb>` preamble** until its Rust twin
     exists at R5 (`ctide` does nothing at R0).
- **Why first:** it is the literally-first thing that delivers value and needs no
  Rust, *and* it is an early read on whether "review-as-primary-loop" (the P2
  thesis) resonates in the owner's real dbt workload — months before `ctide review`
  lands (the late-flagship risk surfaced in §3 R2's product-signal note).

### 6.2 First Rust slice to build: `ctide doctor` (E1), then the first flow verb `ctide run` (E2)

- **`ctide doctor` (E1) — the architecture-proving walking skeleton, *not* a
  daily-flow verb.** Its job is to prove the rails (every layer, the three-impl
  testing story) and the zero-egress posture at zero blast radius. It is a
  **low-frequency trust/diagnostic verb** — run when something is wrong, when
  auditing egress, or when asking "why is it doing that?" — not part of the flow
  loop. It does kill two standing hygiene bugs the day it lands (the
  `~/.config/ghostty` write + tracked-file churn move under typed `ApplyPlan` via
  the parser killers), but do **not** gold-plate it as a daily verb (see
  r1-walking-skeleton §5).
- **`ctide run` (E2) — the first flow-changing Rust verb.** A real test/build
  runner with one-key restart + finish notifications, turning the `just --list`
  stub into an engine — the first *felt-every-session* capability. **E2 ships
  keystone A**, so it is the increment that unlocks the rest of the roadmap.

**`firstEpic` for the program is E0** (scaffold + rename) — nothing compiles until
the workspace exists. The **first *daily value overall*** is the **E7 R0 dbt-review
shell slice (§6.1), shipped week 0**; the **first *value-bearing Rust epic*** is
**E1** (the walking skeleton); the **first *flow-changing* Rust verb** is **`ctide
run` (E2)**.

---

## 7. Dependency view — the build order (nothing out of order)

```
R0 ── E0 Scaffold (crap4rs CI template + 8-crate DAG, born "ctide") + REPO RENAME
   │      └─ resolves repo-location ruling (rename in place) BEFORE crates land
   │      ‖ E7(R0 slice): cute-dbt review loop in shell  ── the LAST allowed shell feature
   ▼
R1 ── E1 Foundations: socket adapter + quirk vault + ctide-json(g4) + doctor(g5/g7)
   │      + state-migrate(g6) + replay conformance(g7) + parser killers
   │      ◄── WALKING SKELETON proven here (ctide doctor / MuxTopology / FakeMux)
   ▼
R2 ── E2 Runner(g2, KEYSTONE A) + status bus + agents-cluster writes
   │      + agents family migrated(g6) + g1 convergence + g3 self-check
   ▼
   🚦 E3 = END-OF-R2 RE-APPROVAL GATE  (golden-master parity + runner dogfooded)
   ▼
R3 ── E4 Spaces + N-slot resume + capture-layout + place  (native containers #6: pending Q4)
   │      + spaces/registry families migrated(g6)
   │      🚦 HARD GATE: live agent-resume round-trip verify (task #29)
   ▼
R4 ── E5 sync/setup/policy/keymap/replace/focus (KEYSTONE B tier-1)
   │      └─ E6 review queue flagship + fix-on-red + triage + dashboard
   │            (rides hooks + catch-up ALONE — never the gated reactor)
   │            g1 canonical hook-storm (policy × turn-complete)
   ▼
R5 ── E7(R5) dbt recipe behind DbtReview + defer/slim
   │      + rust-dev recipe at the Rule-of-Two trigger
   │      + delete shell bodies + POSIX→cucumber conversion
   │   ◀── v1 COMPLETE (R1–R4 base + dbt recipe)
   ▼
post-v1 ── E8 dbt intelligence ladder · E9 harlequin bridge · E10 rust cockpit
           + gated tier-3 reactor (built ONLY if the promotion gate trips)
```

**Why this order, in one line each:** E0 before everything (CI/golden-master/
conformance assumed by all later phases; born "ctide" so no rename churn
mid-stream). E1 before E2 (the socket adapter + quirk vault + `ctide-json` are
the substrate the runner's RPCs ride; doctor delivers trust value at zero blast
radius first). E2 (keystone A) before the crown jewels (g2 pull-forward: zero
parity burden, immediate value, load-hardens socket/pipe/state paths; the
re-approval gate sits here by design). E4 (R3) before E5/E6 (spaces are the unit
of work the review queue operates *over*). E5 (keystone B tier-1) before E6 (the
flagship needs the `Stop` hook + `sync` palette wiring E5 ships). E7's R0 slice
runs from day zero (the only sanctioned new shell work). E8/E9/E10 are post-v1
L-moats with phased rungs.

**Cross-cutting, every phase:** the golden-master permit gates each migrated verb
R2→R3 (empty diff or annotated improvement); flow-SLO hyperfine benches are
release blockers from the first hot-path verb; the egress / `~/.config` /
`cargo-deny` gates run on every commit; each epic ships its mdBook chapter in the
same PR (first publish at the end-R2 checkpoint, after the rename).

---

## 8. The five detail docs

This roadmap is the index; each surface expands into its own doc — all five are
written and live as siblings under [`docs/roadmap/`](./), with their source recon
notes under `research/`.

- **[`r1-walking-skeleton.md`](./r1-walking-skeleton.md)** — the §5 slice in full:
  the `Multiplexer`/`MuxTopology` port shape, the `FakeMux` contract, the
  `ctide doctor` verb, the conformance kit (FakeMux + replay server g7 + live
  `--ignored`), and the five-gate CI definition-of-done. *Source recon:*
  [`research/backbone.md`](./research/backbone.md).
- **[`ci-quality-framework.md`](./ci-quality-framework.md)** — the deterministic
  CI job graph (PR / main / release depths), the 8-tier→CI-job mapping, the CRAP
  threshold model (default 15, `ctide-core` strict 8), the zero-egress deny.toml
  ban, the macOS-primary matrix, and the shell golden-master coexistence gate.
  *Source recon:* [`research/ci-quality-framework.md`](./research/ci-quality-framework.md).
- **[`rebrand-ctide.md`](./rebrand-ctide.md)** — the naming map
  (`cide-*`→`ctide-*`, `CIDE_*`→`CTIDE_*`, state dir, `ctide.toml`, brew formula
  + tap), the rename-in-place migration steps (gh rename, remote, ops + memory
  path fixups, redirect caveats), born-new vs retire-not-rename, and identifier
  availability. *Source recon:*
  [`research/rebrand-repo-strategy.md`](./research/rebrand-repo-strategy.md).
- **[`product-docs-plan.md`](./product-docs-plan.md)** — the mdBook tree
  (9 sections, `SUMMARY.md`), generated CLI/config reference (clap/serde +
  sync-tests), zero-egress Pages publish, and the epic→chapter docs-as-you-go
  map. *Source recon:*
  [`research/product-docs-plan.md`](./research/product-docs-plan.md).
- **[`first-issues.md`](./first-issues.md)** — the backlog→epics detail: the
  per-opportunity disposition table, keystone graph, net-new vs strangler-reuse
  ledger, the local-task crosswalk, and the GitHub-issue skeleton for E0/E1/E2.
  *Source recon:* [`research/backlog-to-epics.md`](./research/backlog-to-epics.md).

### Provenance

- Approved vision + design: [`docs/vision/product-vision.md`](../vision/product-vision.md),
  [`docs/vision/design-plan.md`](../vision/design-plan.md) (merged PR #23), and the
  18-file evidence corpus in [`docs/vision/research/`](../vision/research/).
- Five recon notes synthesized into this roadmap: all under
  [`docs/roadmap/research/`](./research/) — `backbone.md`, `backlog-to-epics.md`,
  `ci-quality-framework.md`, `rebrand-repo-strategy.md`, `product-docs-plan.md`.
- In-house assets: `crap4rs` (`/Users/cmbays/github/crap4rs`) — CI/quality/release
  template + adopted CRAP gate; `cute-dbt` (`/Users/cmbays/github/cute-dbt`) — dbt
  gap-filler, F1/F6 contract the E7 dbt journey pins against.

---

*Master roadmap complete. R0 scaffold + rename → R1 foundations (walking
skeleton: `ctide doctor`) → R2 runner (re-approval gate) → R3 spaces (live-resume
hard gate) → R4 Rust-only review loop → R5 dbt recipe + v1. Honors the daemonless
decision, zero-egress, never-write-`~/.config`, no-tokio, and the
`cmux-terminal-ide`/`ctide` rebrand throughout.*
