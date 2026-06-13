# Backlog → Roadmap Epics — mapping the top-20 to R0–R5

> Roadmap research artifact. Maps the ranked top-20 opportunity backlog
> ([../../vision/research/opportunity-backlog.md](../../vision/research/opportunity-backlog.md))
> onto the strangler migration phases of the approved design plan
> ([../../vision/design-plan.md](../../vision/design-plan.md) §9), grouped into
> named, shippable EPICS and sequenced. Inputs cross-checked: product-vision §3–§6
> (seven pillars + dbt/rust verticals), the design-plan crate/port/graft layout, the
> local Claude Code task themes (#23 runner, #24 prompt, #25 PR review, #26 stacked
> diffs, #27 journeys, #29 spaces-resume, #30 layout-fidelity, #31/#32 placement),
> and the on-disk POSIX-sh dogfood (`bin/*`, `lib/*`). 2026-06-12.
>
> **Naming:** per the 2026-06-09 owner rebrand, the Rust product/workspace is
> **cmux-terminal-ide**, binary **ctide**. The design-plan crate names map
> `cide-* → ctide-*`, `cide bin → ctide`. Shell dogfood commands (`cide-space`,
> `cwd`, …) are **strangled and retired, not renamed** — the Rust workspace is born
> "ctide" from crate one. This doc keeps backlog item numbers (#1–#20) verbatim for
> traceability but uses `ctide` for the product and verbs.

---

## 0. How to read this

The design plan defines five Rust migration phases, **R1–R5** (design-plan §9).
There is no "R0" in the design plan — but the prompt asks for R0–R5, and there is a
genuine pre-Rust slice the vision pins explicitly: **backlog #5 (the cute-dbt review
loop) ships from the POSIX dogfood *before R1 begins*** (vision §4 sequencing;
design-plan §9 coexistence rule 5). So this doc names that **R0 = "the last shell
slice + the Rust scaffold"** — the only net-new shell work that is allowed, plus the
crate/CI scaffolding that R1 stands on. After R0, design-plan rule (4) holds: **no new
shell features ever again**; the gap only closes.

For each opportunity I record six attributes, then group into epics:

- **Phase** — R0–R5 (the phase whose *write-verbs* the item rides).
- **Layer** — base / dbt / rust / agent / cross (from the backlog table).
- **Effort** — S / M / L (backlog honesty: S = session or two, M = 1–3-week PR arc,
  L = multi-month program).
- **Keystone vs leaf** — *keystone* = load-bearing; multiple other items hang off it.
  *leaf* = consumes keystones, nothing hangs off it.
- **Deps** — other backlog items / ports it requires first.
- **Reuse** — *strangler-reuse* (a POSIX-sh impl exists in `bin/`/`lib/` to port
  behind golden master) vs *net-new* (never existed in shell).

---

## 1. Keystone graph (what hangs off what)

Two load-bearing investments, exactly as the backlog and vision say (backlog
"Dependency / sequencing notes"; vision §4 "Sequencing logic"):

- **#1 cide-run runner engine (keystone A)** → feeds #4 (status content), #9
  (fix-on-red), #13 (dbt catalog), #15 (rust cockpit). Also the *first genuine
  strangler slice* (g2 pull-forward: runner before spaces) and the load-hardener for
  the socket + `pipe-pane` + state-write paths.
- **#3 event reactor backbone (keystone B)** → feeds #2 (turn-stamp on `Stop` hook),
  #4 (failure→unread), #9 (fix-on-red trigger), #10 (fleet log/triage), #16 (sidebar
  reduce). Its **tier-1 (the `ctide policy` / `ctide turn-complete` hook binaries) is
  what actually ships**; the daemon-shaped reactor tier-3 is *gated and may never be
  built* (design-plan §1, §7 — promotion gate: two shipped loops independently needing
  residency).

Secondary keystones (single-layer, but several leaves depend on them):

- **#5 cute-dbt review loop** → the dbt vertical's identity; #12/#13 destination rungs
  build *toward* what it proves, and F2 (CTE-slice JSON) feeds #13.
- **#11 N-slot resume + #7 generalized resume** → the P1 "space is the unit of work"
  spine; #8 (worktree spaces) and #18 (teams) ride the same checkpoint/resume model.
- **#4 status bus** → leaf-ish but a *prerequisite surface* for every vertical's pills
  (#12, #15); cheap, so it ships early and everything paints onto it.

Everything else (#6, #14, #16, #17, #19, #20, plus the L-program verticals
#12/#13/#15) are leaves or vertical-moat programs that consume the keystones.

---

## 2. Per-opportunity disposition table

Phase column reflects *where the item's owning write-verbs land*, per design-plan §9.
"Reuse" cites the concrete `bin/` script the strangler ports, where one exists.

| # | Opportunity | Layer | Effort | Keystone? | Phase | Deps | Reuse / net-new |
|---|---|---|---|---|---|---|---|
| 1 | cide-run runner engine | cross | M | **KEYSTONE A** | **R2** | RunnerEngine + FailureParser ports; socket adapter (R1) | **net-new** capability, but reuses `bin/git-glance`/runner-pane stub patterns; retires the `just --list` stub + Dock raw-watchexec line |
| 2 | Agent-turn review queue (`ctide review`) | agent | M | leaf (flagship) | **R4** | #3 tier-1 (`Stop` hook); MuxViewers `open_diff`; #1 (shared review surface) | **net-new** (diff viewer runs `--help` today); subsumes local task #25/#26 |
| 3 | Event reactor backbone (declarative-first) | cross | M | **KEYSTONE B** | tier-1 **R4** (`ctide policy`/`turn-complete`); tier-3 **gated/post-v1** | MuxEvents catch-up + hooks pipeline | **net-new** (events stream unread today); replaces `hq-preview` nested polls |
| 4 | IDE status bus + attention engineering | base | S | secondary keystone | **R2** (pills on runner) → **R4** (failure→unread via #3) | MuxAttention port; #1 for content | **net-new** (one error-path `cmux notify` exists); reuses nothing material |
| 5 | cute-dbt review loop + baseline lifecycle | dbt | M | secondary keystone (dbt id) | **R0** (shell demo) → **R5** (behind `DbtReview`) | cute-dbt #99 `explore` + #105 JS contract; DbtReview port | partial **strangler-reuse**: `bin/hq-wrap`/`hq-preview` warehouse logic + cute-dbt CLI; report surface net-new |
| 6 | Native space containers (workspace.group.*) | base | M | leaf | **R3** (with spaces) — *open Q (design §12 Q4)* | MuxWorkspaces `group()`; #7/#11 spaces | **strangler-reuse**: replaces the `cide-set-role` description-tag hack |
| 7 | Generalized resume + layout capture (#30) | cross | M | secondary keystone (P1) | **R3** | MuxSurfaces `resume_stamp`; `tree()` pixel-frames; spaces port | **strangler-reuse**: extends `cide-space` Phase-2 resume; capture-layout net-new (local task #30) |
| 8 | Worktree-per-agent spaces + sessionizer | agent | M | leaf | **R3** (spaces) + early **R5** (sessionizer/journeys) | #7/#11 resume; Vcs `merge_base_diff`; television | **strangler-reuse**: builds on `cide-space`; worktree birth + merge-back journey net-new |
| 9 | Runner→agent fix-on-red loop | agent | S | leaf (signature demo) | **R4** | #1 (pipe-pane parser) **and** #3 tier-1; Agent `submit_prompt` | **net-new**; "nearly free once #1+#3 exist" |
| 10 | Agent triage cockpit + fleet log | agent | M | leaf | **R4** | MuxFeed port (`feed.list`, `workstream`); #3 events | **net-new** (workstream.jsonl unread today); `ctide agent log` extends `cide-agent` reads |
| 11 | Multi-agent space resume (N role slots) | agent | M | secondary keystone (P1) | **R3** | spaces port; Agent `sessions()`; checkpoint key | **strangler-reuse**: generalizes `cide-space` single-slot Phase-2 resume |
| 12 | Local-first dbt intelligence ladder | dbt | L | leaf (vertical moat) | **post-v1** (rungs ride R5) | dbt-core v2 Apache crates; #4 status bus; #5 | **net-new** L-program; open Q #6 (how much LSP landed in v2) |
| 13 | dbt-aware harlequin bridge + defer/slim | dbt | L | leaf (vertical moat) | **post-v1** (defer/slim slice could ride R5) | Warehouse port; #1 catalog; cute-dbt F2 CTE-slice JSON; #12 destination | partial **strangler-reuse**: `bin/hq-wrap` warehouse derive + `cwd focus` fan-out seam; bridge net-new |
| 14 | ctide keymap layer + which-key | base | S | leaf | **R4** (rides `ctide setup` + `ctide sync`) | `ctide sync` (config→`.cmux/*`); consented `ctide setup` | **strangler-reuse**: `bin/cide-regen` smoke-test palette → `ctide sync` output |
| 15 | Rust quality cockpit | rust | L | leaf (vertical moat) | **post-v1** (Rule-of-Two trigger; bacon/nextest rungs ride R5) | #1 (bacon fast-path); #4 pills; MuxViewers | **net-new** L-program (sliced); the compounding dogfood loop |
| 16 | Spaces dashboard + consented sidebar | base | M | leaf | **R4** (TUI) → **post-v1** (custom sidebar v2) | MuxTopology `sidebar_snapshot`; #3 events reduce; #6/#10 | **net-new**; v2 sidebar install through `ctide setup` |
| 17 | ctide doctor / ctide top (trust surface) | cross | S | leaf | **R1** (doctor) → **R2/post-v1** (top/per-space budgets) | config doctor JSON; capabilities probe | **net-new** doctor (design §3, §4); reuses nothing material |
| 18 | ctide-team: Ghostty home for Agent Teams | agent | S | leaf | **R5** (recipe-adjacent) / opt-in | claude-teams shim; layout JSON; #7 capture; #31/#32 placement | **strangler-reuse**: rides `cide-place` placement + layout presets |
| 19 | Cross-tool journeys (#27) + safe S&R verb | base | M (per-journey S) | leaf | **R4** (`ctide replace`) + **R5** (dbt/blame journeys) | Editor `write_all`/`reload_all`; Vcs `blame_journey`; MuxTopology `find_window` | partial **strangler-reuse**: `cwd-focus`/`cwd-route`/`bin/stgrev` blame spine; `ctide replace` net-new |
| 20 | Artifact surfaces (live plan pane) | agent | S | leaf | **R4** (rides #3 hooks) | MuxViewers `open_markdown`; #3 notification hook | **strangler-reuse**: `bin/cide-md-open` live-reload proven; agent-driven trigger net-new |

### Local task ↔ backlog crosswalk

The local Claude Code task list themes map cleanly onto backlog items (so the roadmap
does not double-count them):

| Local task | Backlog item | Epic |
|---|---|---|
| #23 runner pane | #1 | E2 |
| #24 prompt line (omp+starship) | *(not in top-20; honorable — power-user §7 row)* | E2 (rides R2 sync) as a small recipe/setup chore |
| #25 GitHub inline PR review | folded into #2 (review surface) | E6 |
| #26 stacked diffs | folded into #2 (per-layer `--title` patches) | E6 |
| #27 cross-tool journeys | #19 | E7 |
| #28 spaces Phase 1 | already shipped (shell) → R3 ports it | E4 |
| #29 spaces Phase 2 resume | #11 (and gates the R3 live round-trip) | E4 |
| #30 layout fidelity | #7 (`ctide capture-layout`) | E4 |
| #31/#32 placement + move taxonomy | rides design §9 R3 `ctide place`; honorable-mention "ghost-window" fold-in | E4 |

> Note on **#24 prompt line**: it is *not* in the ranked top-20 (it is a power-user §7
> default row — starship/oh-my-posh dual engine). It is a small recipe/setup default,
> not an epic. It rides E2's `ctide sync`/`ctide setup` as a config default and should
> be tracked as a chore under E2, not promoted to roadmap-epic status.

---

## 3. The epics (a coherent shippable chunk = one epic)

Eight epics. E1–E7 are the v1 line (R0–R5 base + dbt-recipe slice); E8–E10 are the
post-v1 vertical-moat programs. Each epic states the increment, the keystone(s) it
delivers or consumes, the phase(s), and the strangler reuse posture.

### E0 — Scaffold the ctide workspace (R0, foundations-of-foundations)

**Ships:** the Rust workspace skeleton, born "ctide" — the locked crate DAG
(`ctide-core` / `ctide-json` / `ctide-mux-cmux` / `ctide-adapters` / `ctide-dbt` /
`ctide-place-macos` / `ctide-testkit` / `ctide` bin), `recipes/` `layouts/` `themes/`
`tests/features/` dirs, and the **CI/quality template cloned from crap4rs**
(`/Users/cmbays/github/crap4rs`): deterministic `ci.yml`, `release-plz.toml`,
`deny.toml` (extended with the design-plan zero-egress network-crate ban +
`exclude-dev` carve-out for cucumber's async stack, design §2/§8.6),
`rust-toolchain.toml` pin, lefthook, and the cucumber BDD harness pattern
(`crates/crap4rs/tests/features/*.feature` + `*_cucumber.rs` is the template). **Adopt
crap4rs itself as a quality gate** (CRAP scorecard in CI). Workspace dep budget locked
(no tokio, no HTTP, no sqlite — design §2).

**Keystone:** none delivered; this is the bedrock R1 stands on. Sequenced first because
every later phase's CI/golden-master/conformance work assumes it exists.
**Effort:** S–M (template clone + adaptation). **Reuse:** crap4rs scaffolding (proven
template); net-new crate bodies.
**Repo decision (recommend):** see §6 — **rename `cmux-workspace-dbt` →
`cmux-terminal-ide` in place**; E0 lands the `crates/` tree alongside the strangled
`bin/`.

### E1 — Foundations: the trust surface + parser killers (R1)

**Ships (design §9 R1):** `ctide` binary skeleton + `ctide-mux-cmux` socket adapter
with the quirk vault (design §4) + frozen `ctide-json` contract crate (g4) +
**`ctide doctor`** (egress audit of both layers, config provenance g5, capability-drift
probe g7) + `ctide state migrate` (g6, per-family, re-runnable) + the live-cmux fixture
generator; then the three parser killers: **`ctide theme`, `ctide agent ls`,
`ctide statusline`**.

**Retires:** the three worst hand-rolled parser sites (3× awk-TOML, JSON-by-grep,
session-store joins); the two live hygiene violations — `cide-theme`'s
`~/.config/ghostty` write (#9) and tracked-file churn (#10) — via typed `ApplyPlan`.

**Backlog delivered:** **#17 (`ctide doctor`)** in full; foundations for everything.
**Keystone consumed:** none (read-mostly, zero blast radius). **Reuse:**
**strangler-reuse** — ports `bin/cide-theme`, `bin/cide-agent` (ls path),
`bin/cide-set-editor`/`lib/cide-editor.sh` statusline logic behind golden master.
**Effort:** M (3-week appetite, design §9). **First daily value:** `ctide doctor`
prints your exact network surface on day one; theme writes stop polluting `~/.config`.

### E2 — The runner engine + status bus (R2) ← KEYSTONE A

**Ships (design §9 R2):** **#1 `ctide run` / `ctide run wrap`** (the g2 pull-forward —
wrapped-watchexec engine, pluggable catalog just/make/npm/cargo, bacon fast-path,
`FailureParser` line- or artifact-driven) composed onto cmux Dock + palette + Feed
notify-on-finish; **#4 IDE status bus** (pills/progress on the runner — the first place
state paints); and the agents-cluster write-verbs `ctide set-role / jump / open /
md-open / agent new/rename` (so the agents state family migrates here, killing the
shell-append-vs-Rust-read split-brain).

**Retires:** the Dock raw-watchexec line; the `just --list` stub pane (local task #23);
shell `cide-jump`/`cide-open`/`cide-set-role`/`cide-agent`/`cide-md-open` → exec shims.

**Backlog delivered:** **#1** (keystone A), **#4** (its R2 half — pills; the
failure→unread half waits for #3 at R4). **Keystone:** delivers A; everything
downstream (#9, #13, #15) now has a runner. **Reuse:** mostly **net-new** (runner never
existed in shell), but ports `cide-jump`/`cide-open`/`cide-set-role`/`cide-agent`/
`cide-md-open` write-verbs behind golden master. **Effort:** M (2-week appetite).
**Includes the #24 prompt-line default** as a small recipe chore (not its own epic).
**First daily value:** a real test/build runner with one-key restart + finish
notifications, felt every session. **← End-of-R2 re-approval checkpoint** (design §9,
vision §4): golden-master parity holding + runner shipped/dogfooded is the evidence the
architecture bet paid off, *before* the crown jewels ride R3.

### E3 — *(reserved — the checkpoint, not an epic)*

The post-R2 re-approval gate is a decision point, not shippable work. Kept as a named
slot so the sequence numbering matches the phases. After E2 passes the gate, proceed to
E4.

### E4 — Spaces, resume, placement, native containers (R3) ← the crown jewels

**Ships (design §9 R3):** `ctide space new/open/close/rm/ls` + `ctide place`; **#11
N-slot resume** (generalizes the proven Phase-2 single slot — local task #29); **#7
generalized resume + capture-layout** (stamp harlequin/runners/`just dev`; replayable
layout JSON — local task #30); **#6 native space containers** via `workspace.group.*`
(open Q design §12 Q4 — at R3 or just after); the foundation for **#8 worktree-per-agent
spaces** (worktree birth + space + labeled agent; merge-back journey can trail into R5);
and the **#31/#32 placement + move taxonomy** (the Swift helper retired behind the
`Placement` port, objc2 in-process).

**Retires:** `bin/cide-space`, `bin/cide-place`, `lib/cide-place.swift`,
`lib/cide-layout.sh` → shims; the per-call `swift` interpreter startup (pain #16).

**Backlog delivered:** **#11, #7, #6, #8 (core), #18-substrate**. **Gated hard** on
golden-master parity **+ the live agent-resume round-trip check** (the pending asterisk
in vision §1 / current-state §5). **Reuse:** heavy **strangler-reuse** — `cide-space`
Phase-1/2 (#28/#29), `cide-place` (#31/#32), `cide-layout.sh`; capture-layout net-new.
**Effort:** M (3-week appetite). **First daily value:** "close it Friday, reopen it
Monday in <10s — layout + conversations + runner, all back" — P1 realized as the unit
of work.

### E5 — Rust-only capability: sync, setup, keymap, replace, focus (R4 infra) ← KEYSTONE B tier-1

**Ships (design §9 R4, the infra half):** **`ctide sync`** (config→`.cmux/cmux.json` +
`.cmux/dock.json` compiler — verbs become palette actions); **`ctide policy`** +
`ctide turn-complete` (the **#3 keystone-B tier-1 hook binaries** — focus-aware
silencing, failure escalation, `Stop`-hook turn-stamping); **`ctide setup`** (the one
consented `~/.config` write path — keymap chords, telemetry flip, sidebar install);
**#14 keymap layer + which-key**; **#19 `ctide replace`** (atomic write-all→serpl→
reload-all, killing the unsaved-buffer hazard) + the safe-S&R journeys; **#20 artifact
surfaces** (live plan pane via the markdown viewer + notification hook).

**Retires:** the `.cmux/` smoke test graduates into `ctide sync` output (`bin/cide-regen`
retired); the notify stub.

**Backlog delivered:** **#3 (tier-1 — the only part that ships pre-gate), #14, #19, #20**.
**Keystone:** delivers B tier-1; #2/#9/#10/#16 now have hooks + sync to ride.
**Reuse:** **strangler-reuse** of `cide-regen` (smoke→sync), `cwd-focus`/`cwd-route`
(journeys), `cide-md-open` (#20); `ctide replace`/`policy`/`sync` net-new.
**Effort:** M (2-week appetite). **Note:** tier-3 reactor is **NOT here** — it is gated
and may never be built (design §1, §7; risk #2).

### E6 — The review-and-loop flagship (R4 flagship) ← consumes A + B

**Ships:** **#2 agent-turn review queue (`ctide review`)** — walk unreviewed turns
across every agent in the space; comment = `cmux send`; the same surface hosts
`gh pr diff | cmux diff` (local task **#25** PR review) and per-layer `--title` stacked
patches (local task **#26**); **#9 fix-on-red loop** (structured `Diagnostic` →
`Agent::submit_prompt` over `workspace.prompt_submit`); **#10 agent triage cockpit +
fleet log** (`feed.list`, `--next-blocked` walk, `ctide agent log --today`); **#16 spaces
dashboard** (TUI v1 from `sidebar_snapshot` + events reduce).

**Backlog delivered:** **#2 (the flagship), #9, #10, #16 (v1)**. Subsumes local tasks
#25 + #26. **Keystone:** consumes A (#1 shared review surface, runner failures) **and** B
(#3 tier-1 `Stop` hook + events). Ships on **declarative hooks + catch-up alone** — never
block the review queue on the gated reactor (vision §4; design §9). **Reuse:**
**net-new** (diff viewer is a `--help` placeholder today; events/workstream unread).
**Effort:** M (review-queue) + S (fix-on-red) within the R4 appetite. **First daily
value:** "the diff queue is the new inbox" — the P2 flagship; the kill-condition metric
(≥80% turns reviewed in 2 weeks) is measured here.

### E7 — The dbt recipe slice — verticals-as-recipes proof (R0 demo → R5) ← dbt identity

**Ships:** **R0 (pre-R1, the one allowed shell slice):** the **#5 cute-dbt review loop**
as a POSIX-dogfood palette demo — `dbt compile` → `cute-dbt --baseline-manifest` →
themed `file://` report surface — the dbt vertical's first proof. **R5:** rebuild it
behind the **`DbtReview` port** + the **dbt recipe as data** (`recipes/dbt.toml`),
`cwd focus → ctide focus`, `cwd route → routing data`, the warehouse port from `hq-wrap`
logic; **#13 defer/slim slice** (managed prod-manifest fetch + `dbt build --select
state:modified+ --defer`) as the recipe's one-key loop; cute-dbt **F1 (#99/#105 JS
contract — the integration keystone), F2 (CTE-slice JSON), F3 (health overlay), F6
(crates.io publish)** land in cute-dbt's own repo on this timeline.

**Backlog delivered:** **#5 (the recipe proof — *in v1 scope*), #13's defer/slim slice.**
**Keystone:** secondary (dbt identity); proves verticals-as-recipes (the Rule-of-Two
seam). **Reuse:** partial **strangler-reuse** (`hq-wrap`/`hq-preview`/`cwd-focus`/
`cwd-route` + cute-dbt CLI); report surface + bridge net-new. **Effort:** M (3-week
appetite for the R5 dbt-recipe slice; vision §4). **First daily value:** "dbt: review my
changes" — semantic fixture diffs in a themed terminal report, zero-egress.

**This closes v1.** v1 = R1–R4 base (E1, E2, E4, E5, E6) + the R5 dbt-recipe slice (E7).

### E8 — Local-first dbt intelligence ladder (#12, post-v1, L)

LSP-now → watch-compile → L2-class intelligence on Apache 2.0 dbt-core v2 crates → the
SQLMesh-style plan/impact apex. Open Q #6 (how much LSP landed in v2) gates "embed vs
rebuild". The defensible dbt moat. **Phased rungs, not a single drop.**

### E9 — dbt-aware harlequin bridge + full execution (#13 destination, post-v1, L)

The compile-then-execute bridge with `ref()`s resolved (no dbt adapter exists anywhere),
CTE preview fed by cute-dbt's F2 JSON, `dbt show`-grade preview when E8 matures. The
defer/slim *slice* already shipped in E7; this is the execution destination.

### E10 — Rust quality cockpit (#15, post-v1, L) ← the Rule-of-Two validator

test-tree explorer (nextest libtest-json), bacon `.bacon-locations` consumption,
mutation-survivor triage TUI (cargo-mutants `--in-diff`, insta-style), coverage triage,
the unified pill row (`cov 91% · mut 3⚠ · snap 0 · deny ✓`). Triggers at the
Rule-of-Two acceptance test (vision §6): bacon/nextest/mutants must run through the
*same* WatchRunner/status/review ports as dbt's jobs with recipe-only differences and
zero rust-specific branches in `ctide-core`. **The compounding dogfood** — ctide is a
Rust program developed in a rust-dev ctide space.

---

## 4. Epic sequence (the line)

```
R0 ─ E0 Scaffold (crap4rs template, crate DAG, born "ctide")
   └ E7(R0 slice) cute-dbt review loop in shell  ── the last allowed shell feature
R1 ─ E1 Foundations: ctide doctor + parser killers + quirk vault + state migrate
R2 ─ E2 Runner engine (KEYSTONE A) + status bus + agents-cluster write-verbs
   └ ★ END-OF-R2 RE-APPROVAL CHECKPOINT (E3 = the gate, not an epic)
R3 ─ E4 Spaces + N-slot resume + capture-layout + placement + native containers
        (crown jewels; gated on golden-master parity + live resume round-trip)
R4 ─ E5 sync/setup/policy/keymap/replace/focus (KEYSTONE B tier-1)
   └ E6 Review queue flagship + fix-on-red + triage cockpit + dashboard
R5 ─ E7(R5) dbt recipe behind DbtReview + defer/slim  ◀── v1 COMPLETE
─── post-v1 (vertical moats, L programs, phased rungs) ───
   E8 dbt intelligence ladder · E9 harlequin bridge · E10 rust quality cockpit
   + gated tier-3 reactor (built ONLY if the promotion gate trips)
```

**Why this order (the load-bearing logic):**

1. **E0 before everything** — the crap4rs-derived CI + golden-master + conformance
   harness is assumed by every later phase; the workspace is born "ctide" so there is no
   rename churn mid-stream.
2. **E1 before E2** — the socket adapter + quirk vault + `ctide-json` are the substrate
   the runner's RPCs and state writes ride; doctor delivers trust value at zero blast
   radius first.
3. **E2 (keystone A) before the crown jewels** (g2 pull-forward, design §9) — runner has
   zero parity burden, immediate dogfood value, and load-hardens socket + pipe-pane +
   state-write paths *before* spaces depend on them. The re-approval gate sits here by
   design.
4. **E4 (R3) before E5/E6** — spaces are the unit of work the review queue operates
   *over* ("walk unreviewed turns across every agent **in the space**").
5. **E5 (keystone B tier-1) before E6** — the review flagship needs the `Stop` hook +
   `ctide sync` palette wiring that E5 ships; but E6 rides hooks+catch-up alone, never
   the gated reactor.
6. **E7's R0 slice runs in parallel from day zero** — it is the *only* sanctioned new
   shell work (vision §4; design §9 rule 5); after R1 lands, rule (4) freezes shell and
   the dbt recipe waits for R5.
7. **E8/E9/E10 are post-v1** — L-effort vertical moats with phased rungs, explicitly out
   of v1 scope (vision §4, §8).

---

## 5. The FIRST shippable increment for daily dogfood value

Two answers, because the vision pins one shell slice *and* one Rust slice:

**Shell, today (E7's R0 slice — #5):** the cute-dbt review loop is independent of
everything and shippable from the POSIX dogfood **now** (vision §4: "shippable from the
POSIX dogfood now"; design §9 rule 5). It is the dbt vertical's identity demo and the
first proof of verticals-as-recipes — ranked high so base-IDE focus does not orphan it.
It reuses `hq-wrap`/`hq-preview`/`cwd-*` + the cute-dbt CLI already on disk. **This is
the literally-first thing that delivers value, and it needs no Rust.**

**Rust, first real increment (E1 → E2):** **`ctide doctor` (E1)** is the first Rust verb
with daily value — it prints your exact two-layer network surface and the parser killers
(`ctide theme`/`agent ls`/`statusline`) immediately stop the `~/.config/ghostty`
pollution and tracked-file churn. Then **`ctide run` (E2)** is the first *felt-every-
session* capability: a real test/build runner with one-key restart and finish
notifications — the `just --list` stub becomes an engine. The keystone (A) ships here, so
E2 is the increment that unlocks the rest of the roadmap.

> **Sequencing nuance to honor:** do NOT ship any *new* shell feature except E7's R0
> slice. Once E1 lands, design-plan rule (4) holds — new capability is Rust-only, the gap
> only closes (risk #8 mitigation). The #24 prompt-line default rides E2's `ctide sync`
> as a recipe chore, not a standalone shell feature.

---

## 6. Repo decision (the OPEN item the prompt asked us to recommend, not assume)

**Question:** rename `cmux-workspace-dbt` → `cmux-terminal-ide` in place, or start a new
repo for ctide?

**Recommendation: rename in place to `cmux-terminal-ide`.** Evidence:

- **The 113-assertion golden master — the strangler "permit" — lives in this repo**
  (design §8.2: "the inherited behavioral spec"). The entire R1–R5 migration is defined
  as *diffing each Rust verb's emitted ops against the shell twin on the same fixture
  topology*. Splitting repos severs the Rust verb from the shell behavior it must match,
  breaking the mechanical-port discipline that makes the migration safe (design §8.2,
  risk #8). The permit is not portable without dragging the whole shell tree along — at
  which point you have copied the repo, not started fresh.
- **Strangler coexistence requires both generations in one tree** (design §9: exec shims
  `command -v cide && exec cide <verb>`; `CIDE_SHELL=1` rollback at every step;
  generation-ownership reported by `ctide doctor`). Coexistence is a single-repo
  mechanism by construction.
- **The fidelity corpus + the 18-file research/vision evidence corpus** (`docs/vision/`,
  `fidelity/` snapshots) are the design inputs the Rust adapter cites with `// fact:`
  comments (design §4). Co-locating them with the crates keeps the quirk-vault citations
  live.
- The design plan *already names the post-rename repo* `cmux-ide/` in its crate-layout
  header (design §2: "repo, post-rename (executed at Cargo-scaffolding time)") and the
  migration is "executed at Cargo-scaffolding time" — i.e., **the rename is scheduled for
  E0**, in place, not a fork.

**Caveat / what to verify before executing:** GitHub repo rename auto-redirects the
remote and existing clones, but **update the `breezy-bays-labs/tap` brew formula name**
(`cide` → `ctide`, design §10) and any CI secrets/`gh` references at E0. The local
worktree dir can stay `cmux-workspace-dbt` until convenient; only the GitHub repo + the
Cargo workspace name need to flip at E0. Recommend `cmux-terminal-ide` (matches the
product name) over the design-plan's placeholder `cmux-ide/`.

---

## 7. Net-new vs strangler-reuse — the consolidated ledger

**Strangler-reuse (a `bin/`/`lib/` POSIX impl exists to port behind golden master):**

| Item / verb | Shell source on disk |
|---|---|
| #17 theme / agent-ls / statusline (E1) | `bin/cide-theme`, `bin/cide-agent`, `bin/cide-set-editor`, `lib/cide-editor.sh` |
| #1 agents-cluster write-verbs (E2) | `bin/cide-jump`, `bin/cide-open`, `bin/cide-set-role`, `bin/cide-agent`, `bin/cide-md-open` |
| #11/#7/#6 spaces + resume + containers (E4) | `bin/cide-space`, `lib/cide-layout.sh`, `bin/cide-set-role` (description-tag → groups) |
| #31/#32 placement (E4) | `bin/cide-place`, `lib/cide-place.swift` |
| #14 keymap/sync (E5) | `bin/cide-regen` (smoke-test palette → `ctide sync`) |
| #19 journeys / #20 artifacts (E5) | `bin/cwd-focus`, `bin/cwd-route`, `bin/stgrev`, `bin/cide-md-open` |
| #5/#13 dbt warehouse + focus (E7) | `bin/hq-wrap`, `bin/hq-preview`, `bin/cwd`, `bin/cwd-focus`, `bin/cwd-route` |

**Net-new (never existed in shell — capability the rewrite creates):**

- #1 runner *engine* (the `just --list` stub is not an engine) · #2 review queue (diff
  viewer is a `--help` placeholder) · #3 event reactor (events stream unread) · #4 status
  bus (one error-path `cmux notify` only) · #9 fix-on-red · #10 fleet log/triage
  (workstream unread) · #16 dashboard · #17 doctor · #7 capture-layout · #19 `ctide
  replace` · #8 worktree-birth + merge-back journey · the report surface in #5 · the
  bridge in #13 · all of #12/#15 · the gated tier-3 reactor.

**In-house assets the scaffold consumes (not opportunities, but load-bearing):**

- **crap4rs** (`/Users/cmbays/github/crap4rs`) — the CI/quality/release template
  (`ci.yml`, `release-plz.toml`, `deny.toml`, `rust-toolchain.toml`, cucumber harness)
  cloned at E0, *and* adopted as a CRAP-score quality gate.
- **cute-dbt** (`/Users/cmbays/github/cute-dbt`) — fills dbt-IDE gaps; its #99/#105 work
  (E7 F1) is the integration keystone the dbt flagship journey pins a contract version
  against.

---

## 8. Source citations

- Backlog: `docs/vision/research/opportunity-backlog.md` (ranked top-20, dedupe map,
  dependency/sequencing notes).
- Vision: `docs/vision/product-vision.md` §3 (seven pillars), §4 (backlog + sequencing
  logic + v1 line + kill condition), §5 (dbt vertical, cute-dbt F1–F6), §6 (rust
  vertical, Rule-of-Two exit criteria), §8 (non-goals — gated reactor, no new shell).
- Design plan: `docs/vision/design-plan.md` §1 (multiplexer-is-supervisor, promotion
  gate), §2 (crate DAG, dep budget, `cide-json` g4), §3 (ports), §4 (quirk vault,
  capture-layout bound), §5 (config UX, `ctide sync`), §6 (runner #1), §7 (event posture
  tiers), §8 (testing, golden master), §9 (migration R1–R5, appetites, coexistence
  rules), §10 (distribution, repo-rename note), §11 (risk register), §12 (open Qs incl.
  group timing Q4).
- POSIX-sh dogfood on disk: `bin/*` (22 scripts), `lib/*` (`common.sh`, `cide-editor.sh`,
  `cide-layout.sh`, `cide-place.swift`) — verified via `git ls-files`.
- Local Claude Code task themes #23–#33 (runner, prompt, PR review, stacked diffs,
  journeys, spaces phases, placement) — verified against the session task list.
- In-house assets: `/Users/cmbays/github/crap4rs` (CI template: `ci.yml`,
  `release-plz.yml`, `deny.toml`, `rust-toolchain.toml`, `tests/features/*.feature`),
  `/Users/cmbays/github/cute-dbt` (dbt gap-filler).
- GitHub: `breezy-bays-labs/cmux-workspace-dbt` issue #10 (Epic: Rust hexagonal cmux
  workspace manager Phase 1) — the standing epic this roadmap fleshes out.
