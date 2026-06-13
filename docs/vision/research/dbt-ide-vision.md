# cide DBT IDE — Vertical Vision

> The dbt vertical of cide, layered on `base-vision-synthesis.md` (Draft C spine +
> grafts). Inputs: `dbt-landscape.md`, `cute-dbt-capabilities.md`,
> `opportunity-backlog.md`, `prior-decisions.md`. Honors every settled decision —
> nothing here re-litigates the hexagonal architecture, the base/dbt recipe split,
> the runner shape, the egress ladder, or cute-dbt's own ADRs. 2026-06-09.

---

## 1. Persona: the analytics engineer who lives in jinja-SQL

She spends her day inside `models/`: staging models that rename and cast, marts
that join and aggregate, schema YAML that documents and tests, macros that DRY the
jinja. Her inner loop is *edit jinja-SQL → compile → read the compiled SQL → run a
subset → look at the data → adjust*. Her outer loop is *unit tests + schema YAML →
slim CI → PR review of SQL diffs and fixture diffs*. She is terminal-native:
helix, not VS Code; `dbt build --select state:modified+`, not a Run button; git
worktrees, not branch-switching.

Her structural problem in 2026: **all of the world-class dbt intelligence moved
into surfaces she cannot or will not use.** The official dbt LSP's best tier
(schema-aware completion, column lineage, rename, CTE preview) ships only inside
the VS Code/Cursor extension and is registration-gated behind a dbt-platform
sign-in — a SaaS dependency, an editor defection, and an egress violation in one
move. dbt Power User is VS Code-only with an Altimate-cloud AI tier. dbt Cloud
Studio is a browser. Meanwhile the terminal has the *pieces* — the fastest engine
(Fusion/Core v2 Rust), the best formatter (sqlfmt), the best SQL TUI (harlequin),
the best git and agent surfaces (cide's base) — and **no composition**.

She also works near data that makes tool trust non-negotiable. Warehouse
credentials live in a local `profiles.yml`; the org's risk posture (and cide's
hard constraint) is zero-egress: no telemetry, no sign-in, no third-party SaaS in
the dev loop. The official intelligence tier is therefore not just inconvenient —
it is *structurally unavailable* to her. That flips the thesis: **all of the
intelligence, none of the sign-in.**

Persona zero is Christopher himself: dbt work at the employer, cute-dbt as his own
gap-filling tool, the exact toolchain above already on disk. The dogfood is the
demand proof, same as the base vision.

---

## 2. A day in the cide dbt IDE

**08:40 — open.** Sessionizer chord → `mart-rework`, the dbt worktree space
closed Friday. Sub-ten-seconds later: helix portrait with `stg_claims.sql` open,
yazi + two agent tabs landscape, harlequin re-attached **read-only** to the dev
DuckDB (resume-stamped, no setup), the runner tile live with the dbt catalog
loaded, the report browser surface showing Friday's cute-dbt report, sidebar
group orange. The status pill reads `dbt: 7 modified vs baseline` — the
baseline manifest cide snapshotted at branch checkout is still fresh. One
unreviewed agent turn from Friday sits in the queue; `cide review` opens the diff
beside the builder pane; a one-line comment goes back via `cmux send`.

**09:05 — the inner loop.** She writes a new CTE in `stg_claims`. On save the
runner's watchexec engine fires the dbt catalog's compile entry —
`dbt compile --select stg_claims` on the Fusion engine, sub-second — and the
compiled-SQL pane refreshes beside the editor. Fusion's static analysis flags an
unknown column *without touching the warehouse*; the pill goes red, the pane
flashes. She fixes it, saves; green. A `ctrl+a f` *focus* chord on `stg_claims`
fans out: helix centers it, yazi reveals it, harlequin loads its compiled SQL
into the query pane, and the explorer DAG calls `focusModel('stg_claims')` —
one subject, every surface re-centered.

**10:30 — data check.** She runs the compiled query in harlequin against the
local DuckDB dev target — results grid, sort, export. For the downstream mart she
doesn't want to rebuild locally: one keystroke runs the slim entry —
`dbt build --select state:modified+ --defer --state .cide/dbt/baseline` —
unbuilt parents resolve to prod artifacts cide fetched via `gh` and cached. The
runner streams progress to a `set-progress` bar; she keeps editing.

**11:15 — red, routed.** A downstream test fails mid-build. Fix-on-red routes
the failure to the builder agent as structured diagnostics: the failing node, the
**compiled SQL path** (never pasted ANSI), the relevant `dbt.log` tail. A Feed
card asks to edit the mart; one keystroke approves; the fix lands in the review
queue as a diff she reads next to the fixture tables it changes.

**13:30 — unit tests and the identity demo.** She authors a dbt unit test for
the new CTE logic — Given/Expected in YAML. Palette: `dbt: review my changes` —
compile → `cute-dbt --baseline-manifest .cide/dbt/baseline/manifest.json` →
the Test Review browser surface reloads: her new test rendered with fixture
tables, the CTE dependency DAG with join-typed edges, the **cell-level semantic
fixture diff** against baseline, the compiled SQL of each CTE sliced exactly.
She verifies the *logic*, not just the text diff. The report is themed to the
cide theme via addstyle and loads from `file://` — zero egress, works offline.

**15:00 — docs upkeep, delegated.** dbt-osmosis propagates column docs from
staging into the mart YAML; the reviewer agent drafts the two missing
descriptions; both land as a diff in the review queue. The explorer's test-count
badges show the one model still untested.

**16:30 — PR review, same muscles.** A teammate's dbt PR:
`gh pr diff 84 --patch` → `cute-dbt --pr-diff @diff.patch` → the same report
surface shows exactly which unit tests changed, fixture-cell-level. The SQL diff
renders in the same `cmux diff` surface agent turns use. Forge-only egress.

**18:00 — close.** `cide space close` snapshots agent checkpoints, stamps
harlequin and runner resume metadata, records the baseline ref. Tomorrow the
whole dbt working set — layout, tools, conversations, baseline — is one chord
away. **Nothing about her hands changed from a Rust afternoon; only the recipe
did.**

---

## 3. Base pillars, instantiated for dbt

**P1 — The space is the unit of work.** A dbt space adds dbt-specific state to
the resumable object: the harlequin attachment (read-only dev target,
resume-stamped via `surface resume set` / `vault.agents`), the runner's dbt
catalog state, the report/explorer browser surfaces (self-contained `file://`
HTML — they resume by construction), and — the dbt-only member — **the baseline
manifest** in `.cide/dbt/baseline/`. Reopening a dbt space restores not just
panes but *the comparison frame*: what "modified vs prod" means today.

**P2 — Review is the primary loop.** dbt gets a third review layer beyond
agent-turn diffs and PR diffs: **data-semantic review.** cute-dbt's cell-level
fixture diff, inline model SQL diff, and YAML diff drawer turn "review my
changes" into reviewing *behavior* (Given/Expected deltas) rather than text. The
review queue and the report surface are two lenses on the same verb; ranked bet 4
(cute-dbt review loop + cide-owned baseline lifecycle) is the dbt vertical's
flagship and the first proof that verticals-as-recipes works.

**P3 — Attention is engineered.** dbt's long-running warehouse builds are the
canonical background task: `set-progress` for `dbt build` node counts,
`set-status` pills for `state:modified` drift and baseline staleness (dimmed when
stale, per the settled staleness-dimming pattern), red escalation only on
failure. The fleet segment counts dbt agents like any other; warehouse runs never
steal focus.

**P4 — Closed loops, human ON the loop.** The dbt fix-on-red variant attaches
**compiled SQL paths** plus the structured failure (node id, file:line in source
*and* in `target/compiled/`, `dbt.log` tail) — the agent reasons over what the
warehouse actually saw, not jinja guesses. cute-dbt's fail-closed
`PreflightError`s route to the Feed as remediation cards ("manifest is
parse-only; run dbt compile") instead of silent failures.

**P5 — Agents are users of the IDE too.** The dbt verbs are machine-callable:
an agent can run `cide run dbt:build --select <sel> --json`, request a report
regeneration, read the modified-set, and query the manifest. Crucially, agents
get the same *grounding* surfaces humans do — compiled SQL, manifest facts,
fixture tables — which is what makes agent-authored dbt changes reviewable.

**P6 — One tool, budgeted latency, reachable from keys.** Fusion's sub-second
parse is what makes the SLOs *physically achievable* for dbt: compile-on-save
inside the feel-instant budget, the focus fan-out (editor → yazi → harlequin →
explorer `focusModel()`) inside an interactive budget. dbt chords ride the base
keymap: review-changes, slim-build, explore, snapshot-baseline. Space identity:
dbt = orange.

**P7 — Verticals are recipes.** The settled recipe stands:
`dbt = base ⊕ {viewer(csvlens), warehouse(harlequin), report(cute-dbt), dbt
routing, dbt layout}`. This vision adds the runner's **dbt catalog** and a
`DbtReviewPort` (shell-out adapter to the cute-dbt binary now; crate adapter
after cute-dbt v1.0 — the CLI is the contract in v0.x). Every dbt adapter
carries an egress label (§8); `cide doctor` prints the dbt network surface,
including the one honest egress class: *your own warehouse*.

---

## 4. dbt-specific surfaces

### 4.1 Model navigation & lineage

- **Now:** television "models" channel (fuzzy-pick any model → focus fan-out);
  `dbt ls` selectors behind palette verbs; the dbt-lineage Rust crate's
  ASCII/TUI as a stopgap lineage view.
- **Soon (cute-dbt #99–#105):** the `explore` surfaces — `dag.html` (Cytoscape +
  dagre, pan/zoom/fuzzy-search, validated at 372 nodes, CTE⇄model toggle) as the
  persistent lineage pane, `tests.html` as the test overview tab. The **#105
  external-drive contract** (`focusModel()` / `setView()` / `data-selected-model`,
  SemVer'd) is the strategic seam: editor→DAG follow-mode on file open, and
  DAG→IDE (Space-select a node → open in helix, or queue `dbt build --select
  <model>+`). cide pins the contract version.
- **Later:** column-level lineage via the intelligence ladder (backlog #12
  destination — Apache 2.0 dbt-core v2 crates), not via cute-dbt (explicitly out
  of its zero-compute scope).

### 4.2 Compiled-SQL preview

Two complementary forms, honoring "`.sql` models route to the editor, never
harlequin" (settled):

- **Live pane:** runner compile-on-save (`dbt compile --select <model>`, Fusion
  fast) + a viewer surface on `target/compiled/<path>.sql` (bat/helix tab),
  re-centered by the focus fan-out. Fusion's lazy-compilation model (open model +
  upstreams first) is the behavior to mirror once the engine is driven natively.
- **Exact-fidelity per-CTE slices:** cute-dbt's compiled-SQL drawer — sqlparser
  span-sliced, comments/casing preserved — inside the report/explorer surfaces.
  This is comprehension-grade (review), the live pane is iteration-grade (edit).

### 4.3 DAG-aware runner — watchexec engine + dbt catalog

The settled runner (watchexec engine + pluggable catalog; dbt adapter
deliberately deferred *to this vertical*) gets its dbt catalog here. Detection:
`dbt_project.yml`. Engine selection: Fusion/Core v2 binary preferred; dbt Core
v1 (Python) as a **supported degraded mode** (many real projects still fail
Fusion's stricter parser).

| Catalog entry | Command sketch | Notes |
|---|---|---|
| `dbt: compile (this model)` | `dbt compile --select <model-from-saved-path>` | The on-save default; path→model mapping is the DAG-awareness seed |
| `dbt: build modified+` | `dbt build --select state:modified+ --defer --state .cide/dbt/baseline` | The one-keystroke slim loop; baseline managed by cide |
| `dbt: test (this model)` | `dbt test --select <model>` | Includes unit tests |
| `dbt: run +model+` | `dbt run --select +<model>+` | Graph operators from the focused subject |
| `dbt: snapshot baseline` | copy `target/manifest.json` → `.cide/dbt/baseline/` | Also auto-fired on branch checkout |
| `dbt: fetch prod baseline` | `gh run download`-class artifact fetch → cache | Defensible egress (gh); staleness-dimmed |
| `cute-dbt: report (local)` | compile → `cute-dbt --baseline-manifest …` → reload surface | Exit-0-on-empty-scope = valid green |
| `cute-dbt: report (PR #N)` | `gh pr diff N --patch` → `cute-dbt --pr-diff @patch` | |
| `cute-dbt: explore` | `cute-dbt explore --out-dir .cide/dbt/explore/` | Post-#100 |
| `dbt: docs` | `dbt docs generate` → browser surface | Interim; Parquet-artifact path later |
| `lint: hot` / `lint: deep` | sqruff on save / sqlfluff dbt-templater on demand | §4.6 |

DAG-awareness beyond selectors: the pipe-pane parser emits **structured
failures** (node, status, compiled path, log excerpt) feeding fix-on-red and the
status bus; the saved-file→model→selector mapping makes "run what this save
affects" a runner behavior, not a flag the user types. Version-gate cute-dbt
command shapes (v0.x CLI may break on minor bumps; `report`/`explore` subcommand
split is coming).

### 4.4 harlequin warehouse pane

harlequin is the warehouse surface: catalog tree, editor, results grid, history.
cide's settled DB-target resolution applies — explicit `cide.toml [database]` →
derived read-only from dbt `profiles.yml` → in-memory DuckDB — and the
attachment is resume-stamped so reopening a space restores it. Default dev loop:
**DuckDB locally** (structural zero-egress; Fusion's DuckDB adapter covers the
engine side). The known gap — harlequin has **no dbt adapter** anywhere (no
`ref()` resolution) — is the cide-owned **harlequin bridge** (backlog #13):
compile-via-dbt then execute, so model SQL runs with refs resolved; CTE-level
preview rides the same bridge (§6). Until then: focus fan-out loads compiled SQL
into harlequin, which is already 80% of the daily need.

### 4.5 Docs preview — cmux browser/markdown surfaces

- **Common-subset, zero-egress, instant:** cute-dbt explore's model-detail card
  (#104: description, materialization, tags, meta, grain, columns) + tests.html —
  the local answer to the questions `dbt docs serve` is usually opened for.
- **Full catalog, interim:** `dbt docs generate` rendered in a cmux browser
  surface (addstyle-themed), local only.
- **Destination:** Core v2's Parquet artifacts make docs a query target —
  catalog browsing becomes SQL over local Parquet in harlequin/DuckDB, and a TUI
  catalog becomes cheap. Rendered model docs also land in the live-reload
  markdown pane (artifact surface) when agents draft them.

### 4.6 Lint & format — sqlfluff and friends

- **Format:** **sqlfmt** on save — jinja-native (formats source, not rendered),
  zero-debate, the same engine behind dbt Cloud's Format button.
- **Hot-loop lint:** **sqruff** (Rust-fast, zero-config, agent-friendly output)
  wired as a runner catalog entry on save; findings flow into the status bus and,
  on demand, to the agent as structured input.
- **Deep lint:** **sqlfluff + dbt templater** as the on-demand/CI tier where
  rendered-SQL accuracy matters (accepting its ~20s/file cost). Caveat tracked:
  sqlfluff is **not natively compatible with Fusion**; on Fusion-engine projects
  the deep tier degrades to sqruff/jinja-templater, and Fusion's own `dbt lint`
  (proprietary tier) remains an optional alternate if licensing is comfortable.

### 4.7 Editor intelligence — dbt LSP in helix, if viable

Three-step posture, mirroring the landscape's Path A/B analysis:

1. **Default now:** helix + **j-clemons/dbt-language-server** (documented Helix
   config; completion/hover/goto-def for models/sources/macros; can shell out to
   Fusion for static-analysis diagnostics — the right hybrid architecture).
   Plus yaml-language-server with the **Fusion-aligned dbt JSON Schemas** for
   free Studio-IDE-parity YAML validation, and jinja-lsp as a niche alternate.
2. **Spike (cheap, time-boxed):** run the official dbt LSP binary standalone
   under helix's LSP client. L1 features (syntax diagnostics, ref/source
   completion, goto-def, compiled view) may work unauthenticated. Treat as
   opportunistic only: undocumented, gating may move, the L2 tier requires
   platform sign-in (zero-egress violation — never adopted), and binary
   licensing must be respected. A positive spike is a nice interim win; a
   negative one costs a day.
3. **Destination (the moat):** cide-native intelligence on the **Apache 2.0
   dbt-core v2 crates** — schema-aware completion, hover types, rename, column
   lineage, CTE preview — owned, local, no auth (backlog #12's ladder). The L2
   tier being registration-gated SaaS makes this *differentiated, not
   duplicative*.

---

## 5. GAP TABLE — world-class dbt DX, dispositioned

Legend: **EXISTING** = covered by an existing tool in the default set (cide
composes it) · **CUTE-DBT TODAY** = shipped in cute-dbt v0.1 · **CUTE-DBT
BUILD** = cute-dbt should build it (roadmap-committed or proposed here — the
gap-fill list, §6) · **OPEN GAP** = no credible terminal coverage; owner noted.

| # | World-class DX feature (landscape §5) | Disposition | Detail |
|---|---|---|---|
| 1 | ref/source/macro autocomplete | EXISTING (partial) | j-clemons LSP in helix; early-stage |
| 2 | Schema-aware column autocomplete | OPEN GAP | cide intelligence ladder destination (v2 crates); official L2 is sign-in-gated |
| 3 | Hover types / `*` expansion | OPEN GAP | same ladder rung as #2 |
| 4 | Goto-def models/macros | EXISTING (partial) | j-clemons LSP |
| 4b | Goto-def columns/CTEs | OPEN GAP | ladder destination |
| 5 | Live diagnostics w/o warehouse | EXISTING (partial) | Fusion static analysis via runner compile-on-save + LSP `--fusion` pipe; not yet keystroke-grade |
| 6 | Rename refactoring (model/column, project-wide) | OPEN GAP | ladder; atomic `cide replace` (serpl) is the text-level interim |
| 7 | YAML JSON-Schema validation | EXISTING | yaml-language-server + Fusion-aligned schemas; cide recipe wires it |
| 8 | Compiled-SQL live preview | CUTE-DBT TODAY + cide glue | per-CTE exact slices (report); live pane = runner compile-on-save + viewer (§4.2) |
| 9a | Query preview → results grid | EXISTING | harlequin |
| 9b | dbt-aware execution (refs resolved) | OPEN GAP — **cide owns** | harlequin bridge, backlog #13; no dbt adapter exists anywhere |
| 10 | CTE-level preview (run a CTE in isolation) | SPLIT: CUTE-DBT BUILD + cide | cute-dbt emits machine-readable CTE slices (§6, F2); cide + bridge executes them. No tool anywhere has this |
| 11 | SQL validation without execution | EXISTING | Fusion compile-time static analysis |
| 12 | Cost preflight (bytes scanned) | OPEN GAP | low priority; BigQuery-specific; Power User-only today |
| 13 | Run model/parents/children one-keystroke | EXISTING | dbt CLI graph operators + runner catalog + chords |
| 14 | Selector workflows (saved, composable) | EXISTING (UX gap) | CLI flag-soup; cide palette selector-builder is recipe glue |
| 15 | Defer-to-prod toggle w/ managed artifacts | OPEN GAP — **cide owns** | flags exist; baseline fetch/freshness lifecycle is ranked bet 4 + §4.3 |
| 16 | Plan/impact preview before run (SQLMesh `plan`) | OPEN GAP — **cide owns (apex)** | absent from every dbt tool on any platform; cute-dbt's StateComparator modified-set is a substrate, breaking/non-breaking needs column lineage (ladder) |
| 17 | Fast iteration: watch mode, lazy compile | EXISTING + recipe | Fusion speed + watchexec runner; no other terminal watch-loop exists |
| 18 | Model-level lineage view (pan/zoom/focus) | CUTE-DBT BUILD (committed) | explore #99 V1/V2, priority:soon; dbt-lineage crate as stopgap |
| 19 | Column-level lineage, locally computed | OPEN GAP — **cide ladder** | out of cute-dbt's scope by design; dbt-lineage crate heuristic partial; v2 crates/SQLGlot-class destination |
| 20 | Docs browsing in-editor | CUTE-DBT BUILD (committed) | #104 detail card + tests.html = common subset; full catalog via docs-in-browser interim, Parquet later |
| 21 | Project health checks | SPLIT: EXISTING + CUTE-DBT BUILD | dbt-osmosis (schema drift vs warehouse); manifest-derived coverage overlay proposed (§6, F3) |
| 22 | Test generation + per-column result surfacing | SPLIT: EXISTING + CUTE-DBT BUILD (candidate) | generation = agent pane; result surfacing = run_results.json ingestion (§6, F4) |
| 23 | Unit tests wired into the dev loop | CUTE-DBT TODAY + runner | comprehension is best-in-class (unique); runner runs them on save |
| 24 | Data diff across envs (table_diff) | OPEN GAP — **cide owns, later** | SQLMesh-only concept; Recce/Datafold are web/SaaS (rejected); rides the harlequin bridge; not cute-dbt's lane (zero-compute) |
| 25 | Scaffold model from source YAML / raw SQL | EXISTING (partial) | dbt-codegen + dbt-osmosis + agent pane; cide palette verbs |
| 26 | YAML scaffold + column-doc propagation | EXISTING | dbt-osmosis |
| 27 | Docs-editing UX → correct YAML | EXISTING (partial) | dbt-osmosis + helix + agent drafts; no dedicated UI needed in terminal-land |
| 28 | Lint/format on save | EXISTING | sqlfmt + sqruff hot / sqlfluff deep (§4.6) |
| 29 | Structured logs viewer w/ tail | EXISTING (partial) | tail/lnav today; an lnav format file for dbt.log is cheap cide polish |
| 30 | Query history + bookmarks | EXISTING | harlequin history + atuin |
| 31 | Git surface in the IDE | EXISTING | lazygit/tig/gh — base-IDE strength |
| 32 | Local semantic layer / metrics | EXISTING | MetricFlow `mf` / `dbt sl` |
| 33 | AI assist (docs/tests/models) | EXISTING (superior) | Claude agent pane via cmux — stronger and local-controlled vs GUI copilots |
| 34 | Unit-test comprehension + semantic fixture diff | CUTE-DBT TODAY | the headline; nothing else renders dbt unit tests like this, on any platform |
| 35 | dbt change review (SQL diff + YAML diff + cell diff) | CUTE-DBT TODAY | `--baseline-manifest` local / `--pr-diff` CI |
| 36 | IDE ⇄ lineage-surface drive contract | CUTE-DBT BUILD (committed) | #105 `focusModel`/`data-selected-model`, SemVer'd — purpose-built for cide |

**Reading of the table:** the terminal already covers the build/run/lint/git/AI
floor by composition; cute-dbt uniquely owns comprehension-and-review; the four
structural open gaps — L2-class language intelligence (#2/3/4b/6/19), dbt-aware
execution (#9b/10/24), managed defer/baseline (#15), and plan/impact preview
(#16) — are all **cide-owned**, which is exactly where a product wants its gaps:
in its own backlog (#12, #13, bet 4), not in someone else's roadmap.

---

## 6. The cute-dbt gap-fill list (what cute-dbt SHOULD build)

Ordered; respects cute-dbt's settled identity — zero-compute, manifest-only,
fail-closed `report` / fail-open `explore`, single-binary, zero-egress.

- **F1 — Ship the explore epic (#99: V1–V6, esp. #100/#101/#104/#105).** Already
  committed, priority:soon. This vision's dependency: dag.html is the lineage
  pane, the detail card is the docs answer, and **#105's external-drive contract
  is the integration keystone** — cide should treat it as a launch dependency of
  the dbt vertical's flagship journey and pin its version string.
- **F2 — Machine-readable CTE-slice output (new proposal).** cute-dbt already
  computes exact per-CTE compiled-SQL extents via sqlparser spans. Expose them as
  data (JSON sidecar or `--out -` stdout mode — already noted as an upstream
  candidate in the backlog): `{model, cte, role, join_type, compiled_sql,
  span}`. cide feeds a slice to the harlequin bridge / `dbt show` and **CTE-level
  preview** (gap #10, nothing has it anywhere) becomes a composition instead of a
  program. Keeps cute-dbt zero-compute; execution stays cide's.
- **F3 — Manifest-derived health overlay.** Extend #103's test-count badges into
  a coverage view: untested models, undocumented models/columns, models with no
  unique grain — all answerable from manifest.json alone. The warehouse-drift
  half stays with dbt-osmosis (it needs a connection; out of cute-dbt scope).
- **F4 — `run_results.json` ingestion (decision needed).** Surfacing last-run
  test status per model/column in explore would close gap #22's display half.
  Reading a second *artifact* preserves zero-compute, but widens the settled
  "reads only manifest.json" posture — needs a deliberate cute-dbt ADR, not a
  drive-by. Flagged as a candidate, not assumed.
- **F5 — Committed fidelity widening, sequenced for the IDE:** #160 sub-modifier
  selectors (`state:modified` parity for scope), #57 `source()` fixture binding,
  #15 per-CTE `@desc` docs. Each one deepens the report the IDE leans on daily.
- **F6 — Unblock the publish (#112)** so `cide doctor`'s detect-and-advise can
  say `cargo install cute-dbt` instead of pointing at a local build.

Explicit non-asks (respecting scope): no SQL execution, no warehouse drivers, no
column-level lineage, no LSP, no scaffolding — those belong to cide's ladder or
other tools.

---

## 7. Defensible default toolset (dbt recipe)

Extends the base table; every row a documented swap point with an egress label.

| Port / concern | Default adapter | Egress label | Notes / alternates |
|---|---|---|---|
| Engine | **dbt Fusion CLI → dbt Core v2 (Rust)** as it GAs | zero* (verify telemetry flags) | dbt Core v1 (Python) = supported degraded mode; engine detection in the catalog |
| Report / review | **cute-dbt** behind `DbtReviewPort` | zero (proven by headless network-block CI) | shell-out adapter in v0.x; crate adapter post-v1.0 |
| Warehouse TUI | **harlequin** | zero on DuckDB; defensible-egress on remote targets | read-only dev attach; resume-stamped; bridge is the build target |
| Local dev warehouse | **DuckDB** | structural zero (`autoinstall_known_extensions=false`, settled) | the default inner loop |
| Formatter | **sqlfmt** | zero | jinja-native; sqruff-format alternate |
| Linter (hot) | **sqruff** | zero | Rust-fast, on-save |
| Linter (deep/CI) | **sqlfluff + dbt templater** | zero | not Fusion-compatible — degrade documented; Fusion `dbt lint` optional alternate |
| Editor intelligence | helix + **j-clemons dbt-language-server** (`--fusion` diagnostics) | zero | official-LSP L1 spike pending; destination = cide-native on v2 crates |
| YAML | yaml-language-server + **Fusion-aligned JSON Schemas**; **dbt-osmosis** | zero (osmosis: warehouse target = same label as harlequin) | kills the YAML drudgery |
| Lineage (stopgap) | **dbt-lineage crate** / explore dag.html | zero | until ladder column-lineage |
| Data viewer | **csvlens** (recipe member, settled) | zero | seeds/exports |
| Metrics | **MetricFlow** (`mf` / `dbt sl`) | zero locally | |
| Docs | cute-dbt detail card + `dbt docs` in browser surface | zero | Parquet-over-DuckDB destination |
| Baseline transport | **gh CLI** artifact fetch | defensible-egress | the same forge-only profile as the base IDE |
| AI | **Claude Code** agent pane | per base-IDE posture | replaces dbt Copilot / Power User AI |

---

## 8. Zero-egress: warehouse credentials and local profiles

The dbt vertical is where zero-egress meets real credentials, so the posture is
explicit:

1. **`profiles.yml` is sovereign and read-only.** cide derives the warehouse
   target from it (settled DB-target resolution) and **never writes it, never
   copies credentials** into cide.toml, the registry, resume stamps, or logs.
   Secrets stay where the user keeps them (`{{ env_var() }}` + direnv/Keychain —
   Christopher's existing pattern); cide stores *target names*, never values.
2. **The warehouse is the one honest egress.** Connecting to your own Snowflake
   is the same trust class as `git push` to your own forge — **defensible
   egress**, declared per adapter, surfaced by `cide doctor` ("this space's
   network surface: gh, snowflake:<account> via profiles.yml target `dev`").
   The default inner loop (DuckDB) is structural zero; an air-gapped dbt IDE is
   real, not aspirational.
3. **The intelligence tier never signs in.** The official LSP's L2
   registration gate is rejected on principle, not just inconvenience; local
   intelligence on Apache 2.0 crates is the moat (§4.7).
4. **Engine telemetry is verified, not assumed.** Fusion/Core v2 must honor
   `DBT_SEND_ANONYMOUS_USAGE_STATS=false` / `DO_NOT_TRACK` — test the silence
   (the settled telemetry posture: warn → disable → test → document).
5. **Report surfaces are zero-egress by construction** — cute-dbt's
   network-block CI gate is the proof standard the rest of the vertical should
   aspire to; synthetic fixtures repo-wide; no PHI hand-wringing (settled).

---

## 9. Open questions

1. **How much of the dbt LSP landed in Apache 2.0 dbt-core v2?** Determines
   whether the ladder's destination is "embed" or "rebuild on the crates."
   Verify in the dbt-core repo before shaping backlog #12's rungs.
2. **Official-LSP-under-helix spike outcome** — do L1 features work
   unauthenticated/standalone, and is the binary license comfortable? (Time-boxed;
   either answer is fine — j-clemons is the default regardless.)
3. **Fusion telemetry flags** — verify the Rust binary honors the opt-outs
   (zero-egress gate for the engine's `zero` label).
4. **Engine detection & degraded mode** — how does the dbt catalog pick
   Fusion/Core-v2 vs Python v1 per project (probe `dbt --version`? config key?),
   and which catalog entries degrade (no static analysis, slower compile)?
5. **Baseline lifecycle design** (the deliberate cide value-add): snapshot on
   branch checkout vs CI artifact fetch as primary; staleness threshold and
   dimming; where merge-base resolution lives; one store for both dbt defer
   `--state` and cute-dbt `--baseline-manifest`?
6. **harlequin bridge shape** — cide-side wrapper (compile → inject SQL) vs
   contributing a dbt adapter upstream to harlequin (adapter guide exists) vs
   waiting for v2-crate embedding? Affects effort class of gaps #9b/#10/#24.
7. **cute-dbt F2/F4 acceptance** — does the CTE-slice JSON output and (separately)
   run_results ingestion clear cute-dbt's own ADR bar? File as cute-dbt issues
   for triage there, not assumed here.
8. **sqlfluff-on-Fusion drift** — as projects migrate engines, does the deep-lint
   tier quietly die? Decide whether sqruff-only is acceptable or Fusion's
   `dbt lint` (proprietary) earns an opt-in slot.
9. **Doctor's warehouse-egress UX** — exact presentation of profiles.yml-derived
   network surface (accounts, hosts) without ever echoing secrets.
10. **dbt docs interim vs Parquet timing** — invest in an lnav/dbt.log format
    file and docs-in-browser polish now, or wait for Core v2 Parquet artifacts
    and jump straight to catalog-as-SQL?
11. **Column-lineage seeding** — adopt the young dbt-lineage crate (heuristic,
    confidence-leveled) as a stopgap pane, or hold for the ladder to avoid
    shipping two lineage UXs?
12. **Plan/impact preview scoping** (the apex differentiator): what is the
    smallest honest v1 — modified-set + downstream closure + estimated rebuild
    scope (no breaking/non-breaking judgment until column lineage lands)?

---

*Layered on `base-vision-synthesis.md` (2026-06-09). The dbt vertical's identity
move is ranked bet 4 (cute-dbt review loop + baseline lifecycle) — shippable from
the POSIX dogfood now; its moat is the intelligence ladder (backlog #12) and the
execution bridge (#13), both riding rails the base IDE builds once.*
