# The 2025–2026 dbt Developer-Experience Landscape

> Web research for the cide DBT IDE vertical (cute-dbt). Researched 2026-06-09.
> Purpose: define "world-class dbt DX" from the GUI tools that set the benchmark, map what already
> exists in terminal form vs. what is a gap, assess how dbt Fusion's Rust engine + LSP changes what a
> terminal dbt IDE can do, and recommend defensible default tool choices.
> Constraints applied throughout: zero-egress / local-first, no SaaS, macOS-first but Linux-compatible.

---

## 1. State of the ecosystem (mid-2026): the ground just shifted

Three tectonic events between mid-2025 and June 2026 reshape every assumption about dbt tooling:

1. **dbt Fusion shipped (May 2025, Preview)** — a ground-up Rust rewrite of the dbt engine
   ("industrial-grade engine"), originally source-available under ELv2, claiming up to 30x faster
   parsing and a real SQL-comprehending compiler (via the acquired SDF technology) instead of
   string-templating-only Jinja rendering.
2. **Fivetran ⇄ dbt Labs merger (announced 2025-10-13, expected to close mid-to-late 2026)** —
   Fivetran had already acquired Census (May 2025) and **Tobiko Data / SQLMesh (Sept 2025)**.
   SQLMesh was subsequently **donated to the Linux Foundation**. dbt and its main competitor are
   converging under one roof; SQLGlot/SQLMesh ideas are likely to bleed into dbt.
3. **dbt Core v2 alpha (2026-06-01)** — the bombshell for terminal tooling: the Rust engine is now
   **Apache 2.0 open source in the dbt-core repository** ("the two-engine era is drawing to a
   close"). The `dbt-fusion` GitHub repo is archived; its code moved into `dbt-core`. Fusion remains
   as the *enhanced binary distribution* (free, with proprietary extras like a built-in
   high-performance SQL linter), while dbt Core v2 = the open Apache 2.0 Rust runtime. Core v2 also
   promises **Parquet artifacts** (queryable with DuckDB) as a high-performance alternative to the
   giant `manifest.json`/`catalog.json` JSON files, and a **revamped local documentation
   experience** that scales to arbitrary project sizes.

Implication for cide: building a terminal dbt IDE in Rust in 2026 means you can link against /
shell out to an **Apache-2.0 Rust dbt runtime** — something impossible a year ago. The proprietary
edge that dbt Labs keeps is the *editor intelligence layer* (the LSP's registration-gated features)
and the platform — which is exactly the layer a terminal IDE wants to own anyway.

---

## 2. dbt Fusion deep dive: the Rust engine + LSP

### What Fusion is

- A standalone Rust binary (no Python runtime) implementing parse/compile/run for dbt projects.
  Up to 30x faster project parsing, ~10x faster parse/compile/execute overall vs dbt Core v1.
- True **SQL comprehension**: Fusion understands each model's schema and dialect, so it can do
  static analysis the Python engine never could — type errors, unresolved column references,
  dialect incompatibilities, missing GROUP BY, invalid function args — *without hitting the
  warehouse* ("error detection without hitting the warehouse").
- **State-aware**: ships `dbt state`-style incremental behavior; requires only `profiles.yml`
  for CLI use.
- Adapters (as of the supported-features matrix): Snowflake (GA), BigQuery (Preview), Redshift
  (Preview), Databricks (Private Preview), Apache Spark (Beta, CLI only), **DuckDB (Beta, CLI
  only)** — DuckDB support matters for fully-local dev loops.
- Not yet supported / gaps vs Core v1: Python-API programmatic invocations, exact dbt-Core-shaped
  logs (tools that scrape log output break), some materialization configs; SQLFluff is *not
  natively compatible* with Fusion — Fusion offers its own `dbt lint` instead.

### The dbt LSP

- The Fusion engine powers an LSP implementation ("dbt LSP"); the VS Code extension
  **auto-downloads the correct dbt Language Server binary for your OS** on activation.
- LSP-powered features: autocomplete for `ref()`/`source()`/macros and dialect-aware SQL
  functions; hover insights (hover `*` → expanded column list with types; hover a column → its
  type); go-to-definition/references (models, sources, macros — and columns/CTEs with strict
  static analysis); inline diagnostics as you type; **column-level lineage**; rename-refactoring
  of models *and columns* with project-wide `ref()` updates; **live CTE preview**; compiled-SQL
  side-by-side view; **lazy compilation** (compile the open model + upstreams first, background
  full-project compile after; LSP runs independently of CLI runs) and an LSP cache for fast
  incremental recompiles.
- **Feature gating**: L1 features (syntax diagnostics for Jinja/YAML/SQL, ref/source autocomplete,
  table-level lineage tab, go-to-def, compiled-code view, model preview) are free to all.
  L2 features (Fusion SQL-comprehension diagnostics, column-level lineage, column/CTE go-to-def,
  column rename, CTE preview codelens, LSP cache, catalog tab) require **registration / dbt
  platform sign-in after a 14-day trial**, capped at 15 users/org.
- Official LSP availability: VS Code / Cursor / Windsurf extension, Studio IDE, Insights. The docs
  do **not** document standalone use in other editors (a community plea exists: "Please make the
  official language server IDE-agnostic, @dbt-labs" — fsorodrigues/dbt-ls).
- Licensing timeline: Fusion launched ELv2 ("use freely internally, can't offer as a managed
  service"); with Core v2 (June 2026), **all code required for the Rust dbt v2 runtime is Apache
  2.0 in dbt-core**, and the Fusion binary itself moved to a *more permissive* license than ELv2.
  What remains proprietary: premium features in the Fusion binary distribution (e.g. the
  high-performance SQL linter) and, in practice, the registration-gated LSP intelligence tier.
  **Open question to verify**: how much of the LSP itself landed in the Apache 2.0 dbt-core repo
  vs. stayed in the proprietary binary.

### Zero-egress assessment

- Fusion CLI: free, local binary, only needs `profiles.yml` → compatible with zero-egress
  (verify telemetry flags; dbt ecosystem honors `DBT_SEND_ANONYMOUS_USAGE_STATS=false` /
  `DO_NOT_TRACK`; confirm for Fusion specifically).
- VS Code extension L2 features: **require sign-in to dbt platform** → violates zero-egress.
  A terminal IDE that re-creates L2-class features locally (column lineage, SQL-aware
  diagnostics) on top of the Apache 2.0 engine is therefore *differentiated, not duplicative*.

---

## 3. The GUI benchmark tools (where "world-class dbt DX" is defined)

### 3.1 Official dbt VS Code extension (Fusion-powered, 2025–2026)

Canonical feature set (from docs.getdbt.com/docs/dbt-extension-features):

- **Live error detection**: L1 syntax-tree diagnostics (Jinja/YAML/SQL; missing commas, misspelled
  keywords) in Problems panel; L2 Fusion SQL comprehension (missing GROUP BY, ungrouped columns,
  invalid functions, type/schema errors, linter warnings).
- **IntelliSense**: ref()/source() autocomplete with available resources; dialect-aware SQL
  function autocomplete.
- **Hover insights**: expand `*` to columns+types; column type on hover.
- **Navigation**: go-to-definition/references for models, sources, macros (Jinja-aware);
  column & CTE go-to-definition (L2).
- **Refactoring**: rename model → all `ref()`s update project-wide, with preview; rename column →
  downstream references update (L2; not yet for snapshots/yml resources).
- **Lineage**: per-file table-level lineage tab (double-click node opens file; updates as you
  navigate); column-level lineage with `column:` selector syntax (L2).
- **Compile & preview**: compiled SQL side-by-side, updates on save, macro↔compiled-block focus
  sync; model/snippet preview (cmd+enter) into sortable Query Results tab; **CTE preview**
  codelens (L2).
- **Build**: quickpick menu for building with complex selectors (cmd+shift+enter).
- **Catalog tab** (beta, L2): model description, columns w/ types + test results, build status /
  last run duration (platform-sourced).
- **Compare changes** (beta, Enterprise): diff working copy vs production manifest in-editor.
- Utilities: system report generator.

### 3.2 dbt Power User (AltimateAI) — the de-facto DX benchmark

The community benchmark; works with dbt Core (Python). Full feature enumeration (README +
docs.myaltimate.com), organized by phase:

**Develop**
1. Autocomplete: model names, macros, sources, docs blocks.
2. Go-to-definition: click model/macro/source names.
3. Compiled SQL live preview as you type.
4. **Click-to-run**: run/test/build a model, or its parents/children, from CodeLens buttons.
5. Generate dbt model from a YAML source definition (scaffold staging models).
6. Generate dbt model from raw SQL (auto-populates `ref()`s).
7. SQL Visualizer (visualize query structure), Query Explanation (AI), Query Translation
   (dialect→dialect, AI).
8. **Defer to prod from the UI** — toggle defer so unbuilt parents resolve to production.
9. SQL validation **without execution** (mistyped keywords, unbalanced parens, missing columns).

**Test**
10. Preview query results in-panel; export CSV; chart/filter/group results (data analysis panel).
11. Tests generation (AI-assisted) + run tests from the editor.
12. **Project health check**: detect columns missing from the warehouse, unmaterialized models,
    stale docs, etc.
13. BigQuery cost estimator (bytes-scanned preflight).
14. dbt logs viewer with tail-follow.
15. Query history and query bookmarks.

**Collaborate**
16. **Model lineage AND column lineage** in-editor — nodes for models/seeds/sources/exposures,
    overlays for model type, tests, docs, linkage type, with code visibility per edge.
17. Documentation generation (AI or manual) in a UI editor, auto-saved into YAML correctly
    formatted.
18. Project governance checks in IDE/Git/CI-CD; SaaS UI for shared docs + lineage (Altimate
    cloud — the part a local-first tool would *not* copy).

### 3.3 dbt Cloud "Studio IDE" (browser)

- Full browser IDE: editor with SQL syntax highlight, autocomplete (tables, args, columns),
  files/folders, **version control UI (git branch/commit/PR) built in**, command/console bar,
  build/test/run buttons.
- Format & lint integration: **sqlfmt powers the Format button**; SQLFluff linting integration.
- Generate + view project docs in-IDE; DAG/lineage explorer (dbt Explorer / dbt Catalog product).
- YAML validation against **Fusion-aligned JSON Schema** (autocomplete + structural feedback for
  schema/config YAML) — note: those JSON schemas are a reusable artifact for any editor.
- AI tier: dbt Copilot (generate docs, tests, semantic models, metrics, SQL from natural
  language), Developer agent (beta; write/refactor models from NL), dbt Wizard agent.
- Dev/prod environment management; "next-gen engine" (Fusion) with sub-second parse in beta;
  dark mode (2025, GA — amusing how late).

### 3.4 SQLMesh — competitor DX ideas worth stealing

SQLMesh (Tobiko → Fivetran → Linux Foundation) is the richest source of *workflow* ideas:

- **`plan` / `apply` (Terraform for data)**: before running anything, compute the full impact of
  your changes — which models are affected, breaking vs non-breaking (decided via **column-level
  lineage analysis**), what will backfill, what it will cost — show a diff, prompt to apply.
  Unit tests run automatically as part of `plan`.
- **Virtual Data Environments**: dev environments are views over physical tables — create a
  perfect "copy" of prod without copying data; promoting to prod is a pointer swap (blue-green).
  State-aware: only changed tables rebuild.
- **`table_diff`**: schema diff + row-level data diff of a model across two environments (or two
  arbitrary tables) — "what did my change do to the data?" as a first-class command.
- **Unit tests** (known input → expected output, in YAML, run on plan) distinct from **audits**
  (data-quality assertions post-build) — dbt only recently got unit tests; SQLMesh's are wired
  into the dev loop.
- **Column-level lineage computed locally** by SQLGlot (no warehouse, no service); `sqlmesh dag`
  renders the DAG from the CLI; UI has column lineage clicking.
- SQL transpilation across dialects (SQLGlot) and real SQL parsing/validation at authoring time.
- DX gaps SQLMesh itself has: its UI is a *browser* app (`sqlmesh ui`), not a TUI — nobody owns
  the terminal here either.

---

## 4. Terminal-native tooling today (what already exists)

| Tool | What it gives you in the terminal | Maturity / notes |
|---|---|---|
| **Fusion CLI / dbt Core v2 (Rust)** | 30x parse, compile/run/build, state/defer, static analysis errors at compile time, DuckDB adapter | GA-track; Core v2 alpha is Apache 2.0 |
| **harlequin** (Python/Textual) | Full SQL IDE TUI: editor w/ autocomplete + syntax highlight, data catalog tree, results viewer for large sets, query history, export; adapters: DuckDB, SQLite, Postgres, MySQL, Snowflake, BigQuery, … | Mature, beloved; **no dbt adapter** — no ref() resolution, no compile-then-run; you point it at the warehouse/dev schema and write raw SQL |
| **sqlfluff** | Lint + fix + format templated SQL; dbt templater renders via dbt for accuracy | Standard but slow with dbt templater (~20s/file vs ~2s jinja templater); **not natively compatible with Fusion** |
| **sqruff** (Rust, Quary) | sqlfluff-compatible-ish linter/formatter, ~10–100x faster, zero-config, AI-agent-friendly output | Active; the speed answer for lint-on-save in a TUI |
| **sqlfmt** (tconbeer) | Opinionated, Black-style formatter that **handles Jinja natively** (formats source, not rendered SQL), hundreds of files/sec, only-changed-files | Mature; powers dbt Cloud IDE Format button |
| **dbt-osmosis** | Automated schema-YAML management: scaffold YAML, **inherit/propagate column docs from upstream**, sync columns with warehouse schema, organize YAML by rules; also sql/diff/lint/test/nl commands; (workbench is Streamlit/browser) | Active (v1.2.x, Jan 2026); the YAML-drudgery killer |
| **dbt-lineage** (Rust crate) | CLI lineage: parses `ref()`/`source()` from SQL directly (no dbt, no Python) or from manifest.json; **column-level lineage with confidence levels**; outputs ASCII, DOT, JSON, Mermaid, SVG, interactive HTML, and a **ratatui TUI** with mouse support | Young (v0.2.0) but exactly the right shape |
| **jinja-lsp** (Rust, uros-5) | LSP for Jinja: completion, hover, goto-def, code actions, linting; Helix & Neovim configs documented | Built for minijinja/web backends, not dbt-aware semantics |
| **j-clemons/dbt-language-server** (Go) | dbt-focused LSP: completion/hover/goto-def for models, sources, seeds, macros, vars; **can shell out to dbt Fusion for static-analysis diagnostics**; Neovim, **Helix**, Zed configs | v0.4.x, early but the most dbt-aware editor-agnostic LSP |
| **fsorodrigues/dbt-ls** (Go) | Community dbt LS for Neovim (born of frustration that the official LSP is VS Code-only) | Early |
| **MetricFlow CLI** (`mf` / `dbt sl`) | Define + query metrics locally from dbt Core: `mf query --metrics ... --group-by ...`, `mf validate-configs`, semantic_manifest.json from `dbt parse` | Works fully locally with dbt Core |
| **dbt docs generate/serve** | Static docs site + DAG explorer locally | Pain: needs warehouse for catalog, giant JSON artifacts, sluggish on big projects; Core v2 promises Parquet artifacts + revamped local docs that scale |
| **state/defer CLI workflow** | `dbt run -s state:modified+ --defer --state path/to/prod-artifacts` = build only what changed, read unbuilt parents from prod ("Slim" local builds); `selectors.yml` for reusable named selections | Pure CLI; the workflow is powerful but artifact plumbing (fetching prod manifest, keeping it fresh) is DIY |

**Jinja editing pain (the terminal's open wound):** there is still no first-class jinja-SQL
editing experience outside VS Code. Tree-sitter/editor ecosystems struggle to combine two grammars
(Zed issue: can't merge jinja2 + SQL tree-sitter support downstream); Helix has no built-in
jinja-sql language; community LSPs are partial. The official dbt LSP — which solves all of this —
is only shipped inside the VS Code/Cursor/Windsurf extension and the dbt platform.

---

## 5. Deliverable (a): the canonical "world-class dbt DX" checklist

Drawn from the union of the dbt VS Code extension, dbt Power User, Studio IDE, and SQLMesh.
A world-class dbt IDE provides:

**Language intelligence**
1. ref()/source()/macro/docs-block autocomplete
2. Dialect-aware SQL + column-name autocomplete (schema-aware)
3. Hover: column types, `*` expansion, model/macro docs
4. Go-to-definition/references: models, sources, macros, columns, CTEs
5. Live diagnostics without warehouse: syntax (SQL/Jinja/YAML) + SQL comprehension (types,
   unknown columns, missing GROUP BY, dialect errors)
6. Rename refactoring: models and columns, project-wide, with preview
7. YAML schema validation + autocomplete for dbt config files (JSON Schema)

**The compile/preview loop**
8. Compiled-SQL live preview, side-by-side, macro↔output sync
9. Execute model / arbitrary selection preview → results grid (sort/filter/export CSV)
10. **CTE-level preview** (run any CTE in isolation)
11. SQL validation without execution (dry-run / static)
12. Cost preflight (e.g. BigQuery bytes scanned)

**Build & state**
13. One-keystroke run/test/build of model / parents / children (graph operators)
14. Selector builder (state:modified+, tags, paths; saved selectors.yml)
15. **Defer-to-prod as a toggle** with managed prod-artifact freshness
16. Plan-before-run impact preview (SQLMesh `plan`: affected models, breaking vs non-breaking,
    backfill scope) — *no dbt GUI has this fully; SQLMesh does*
17. Fast iteration: sub-second parse, lazy compilation, watch mode

**Understanding & lineage**
18. Model-level lineage view, scoped to current file, click-through navigation
19. **Column-level lineage**, computed locally, with selector syntax
20. Project docs browsing (descriptions, columns, tests) without leaving the editor
21. Project health checks (undocumented/untested models, schema drift vs warehouse, unused
    sources)

**Testing & data quality**
22. Generate + run tests from the editor; surface test results per column
23. Unit tests with fixtures wired into the dev loop (SQLMesh-style)
24. **Data diff: compare a model's output across envs / before-after a change** (SQLMesh
    table_diff; dbt "Compare changes" is Enterprise-only)

**Scaffolding & docs upkeep**
25. Generate staging model from source YAML; generate model from raw SQL with refs populated
26. YAML scaffolding + column-doc inheritance/propagation (dbt-osmosis behavior)
27. Docs editor that writes correctly-formatted YAML

**Workflow glue**
28. Lint/format on save (sqlfmt/sqlfluff-class)
29. Logs viewer with tail
30. Query history + bookmarks
31. Git integration in the IDE surface
32. Semantic layer: define + query metrics locally (MetricFlow)
33. (GUI-era extra) AI assist: docs/tests/model generation — in cide-land this maps to the
    Claude agent pane, which a terminal IDE gets *for free* via cmux

---

## 6. Deliverable (b): terminal coverage matrix — exists vs GAP

✅ = exists in usable terminal form · 🟡 = partial/immature · ❌ = GAP (no terminal equivalent)

| # | Capability | Terminal status | Via |
|---|---|---|---|
| 1 | ref/source/macro autocomplete | 🟡 | j-clemons dbt-language-server (Helix-ready), dbt-ls; early-stage |
| 2 | Schema-aware column autocomplete | ❌ | only official LSP (VS Code) |
| 3 | Hover types / `*` expansion | ❌ | only official LSP |
| 4 | Goto-def models/macros | 🟡 | community LSPs |
| 4b | Goto-def columns/CTEs | ❌ | official LSP L2 only |
| 5 | Static SQL-comprehension diagnostics | 🟡 | Fusion CLI compile errors; j-clemons LSP can pipe Fusion diagnostics; not interactive-grade yet |
| 6 | Rename refactoring | ❌ | nothing outside VS Code |
| 7 | YAML JSON-Schema validation | 🟡 | Fusion-aligned JSON Schemas exist; wire into yaml-language-server |
| 8 | Compiled-SQL live preview | 🟡 | `dbt compile` + watch + bat/delta; no editor-synced pane |
| 9 | Query preview → results grid | 🟡 | harlequin (but dbt-unaware: no ref resolution) |
| 10 | CTE-level preview | ❌ | nothing |
| 11 | Validate without execution | 🟡 | Fusion static analysis at compile |
| 12 | Cost preflight | ❌ | Power User only (BigQuery) |
| 13 | Run model/parents/children quickly | ✅ | dbt CLI graph operators (`+model+`) |
| 14 | Selector workflows | ✅ | CLI + selectors.yml (UX is flag-soup though) |
| 15 | Defer-to-prod toggle | 🟡 | flags work; artifact fetch/freshness plumbing is DIY |
| 16 | Plan/impact preview before run | ❌ | SQLMesh-only concept; nothing for dbt anywhere |
| 17 | Sub-second parse / lazy compile / watch | 🟡 | Fusion CLI is fast; no watch-mode TUI loop |
| 18 | Model-level lineage view | 🟡 | dbt-lineage crate (ASCII/TUI), `dbt ls` selectors, dbt docs DAG (browser) |
| 19 | Column-level lineage | 🟡 | dbt-lineage crate (heuristic, confidence levels); official = VS Code L2; SQLGlot can compute locally |
| 20 | Docs browsing in-editor | ❌ | dbt docs serve = browser; no TUI catalog browser for dbt metadata |
| 21 | Project health checks | 🟡 | dbt-osmosis (schema drift, docs coverage), dbt-checkpoint hooks |
| 22 | Test gen + per-column results | ❌ | run via CLI yes; generation/result-surfacing no |
| 23 | Unit tests in dev loop | 🟡 | dbt unit tests exist (CLI); not wired into an interactive loop |
| 24 | Data diff across envs | ❌ for dbt-terminal | SQLMesh table_diff exists; for dbt: Recce/Datafold are web/SaaS |
| 25 | Scaffold model from source / SQL→model | 🟡 | dbt-codegen macros (clunky), dbt-osmosis partial |
| 26 | YAML scaffold + doc propagation | ✅ | dbt-osmosis |
| 27 | Docs-editing UX → YAML | ❌ | hand-edit YAML |
| 28 | Lint/format | ✅ | sqlfmt (jinja-native), sqlfluff (accurate, slow), sqruff (fast) |
| 29 | Logs tail | ✅ | `tail -f logs/dbt.log` (raw; no structured viewer) |
| 30 | Query history/bookmarks | 🟡 | harlequin history (its own queries only); atuin for CLI |
| 31 | Git surface | ✅ | lazygit/gh dash — already cide's strength |
| 32 | Metrics locally | ✅ | MetricFlow `mf query` / `dbt sl` |
| 33 | AI assist | ✅ | Claude agent pane in cmux — arguably *better* than GUI copilots |

**The big five gaps** (nothing credible in any terminal form): schema-aware
completion/hover/rename (the L2 intelligence tier), CTE preview, dbt-aware query execution with a
results grid (harlequin-with-refs), data diff for dbt, and a TUI catalog/docs/lineage browser.
Plus the workflow gap nobody has: SQLMesh-style plan/impact preview for dbt.

---

## 7. Deliverable (c): how Fusion (Rust engine + LSP) changes the terminal game

1. **An Apache 2.0 Rust dbt runtime now exists (dbt Core v2, June 2026).** A Rust terminal IDE
   can embed or link the actual engine — same parser, same JSON-schema configs, same artifacts —
   instead of scraping a Python CLI. Sub-second parse makes *interactive* terminal features
   (preview-on-keystroke, lineage-on-cursor-move) physically possible for the first time.
2. **Static analysis without the warehouse.** Fusion understands schemas/dialects locally, so a
   terminal IDE can surface unknown-column/type/GROUP BY errors at edit time — previously this
   class of feedback required running against the warehouse. Zero-egress-friendly by nature.
3. **The official LSP is real but caged.** It ships only inside the VS Code/Cursor/Windsurf
   extension + dbt platform, auto-downloaded per-OS, and its best tier (column lineage,
   schema-aware completion, rename) is **registration-gated** — i.e., incompatible with cide's
   zero-egress constraint *and* unavailable to helix anyway. Two paths:
   - **Path A (opportunistic):** run the dbt LSP binary under helix/any LSP client; L1 features
     may work unauthenticated. Fragile: undocumented, gating may move, licensing of the binary's
     premium tier must be respected.
   - **Path B (defensible):** build terminal intelligence on the **Apache 2.0 dbt-core v2 crates**
     (+ SQLGlot/sqruff-style local analysis) — own the features, no auth, no egress. The
     j-clemons LSP already demonstrates the hybrid pattern: editor-agnostic LSP front, Fusion
     static analysis as a diagnostics backend.
4. **Artifacts become queryable.** Core v2's Parquet artifacts (replacing megabyte JSON) are
   tailor-made for a terminal IDE: DuckDB/harlequin can query project metadata directly — catalog
   browser, health checks, lineage queries become SQL over local Parquet.
5. **State/defer gets cheap.** Fusion's speed + dbt state support means a TUI can keep a
   continuously-fresh "what changed vs prod" computation running and render it as an ambient
   status (the SQLMesh-plan-like preview in §6 #16 becomes feasible for dbt).
6. **Watch out:** Fusion breaks log-scraping tools (log format not Core-compatible), SQLFluff
   doesn't work natively with it (sqlfmt/sqruff do, since they don't render through dbt), and
   adapter coverage is still Snowflake-first (DuckDB is Beta, CLI-only — fine for local dev).

---

## 8. Deliverable (d): defensible default tool choices for a terminal dbt IDE

| Slot | Default | Why defensible | Alternates |
|---|---|---|---|
| Engine | **dbt Fusion CLI** today → **dbt Core v2 (Rust, Apache 2.0)** as it GAs | Speed makes interactivity possible; v2 is open + embeddable from Rust; state/defer built in | dbt Core v1 (Python) compat mode for projects Fusion can't parse yet |
| Formatter | **sqlfmt** | Jinja-native (formats source, not rendered), opinionated/zero-debate, fast, is what dbt Cloud's Format button uses | sqruff format; sqlfluff fix |
| Linter | **sqruff** for the hot loop (save-time), **sqlfluff + dbt templater** as deep/CI lint | sqruff = Rust-fast, zero-config, agent-friendly output; sqlfluff = accuracy when rendering matters; note Fusion ships its own `dbt lint` (proprietary tier) | Fusion `dbt lint` if licensing comfort |
| SQL workbench | **harlequin** (already in the owner's stack) | Best-in-class TUI results grid/catalog/history; gap to close: a thin "compile-via-dbt then execute" bridge (no dbt adapter exists — that bridge is a cute-dbt opportunity) | usql, pgcli-family |
| Local warehouse for dev loop | **DuckDB** | Fusion/Core v2 Beta adapter, fully local (zero-egress), harlequin's default adapter | — |
| Lineage | **dbt-lineage (Rust crate)** seed, or build on manifest/Parquet artifacts + ratatui | Only existing terminal column-lineage; Rust = composable into cide | Graphviz/Mermaid render-to-pane; `sqlmesh dag` ideas |
| Editor intelligence | helix + **j-clemons/dbt-language-server** (with `--fusion` diagnostics) now; long-term: cide-native LSP on Apache 2.0 v2 crates | Only editor-agnostic dbt-aware LSP with documented Helix config; hybrid Fusion-diagnostics pattern is the right architecture | jinja-lsp (jinja-only), official dbt LSP (Path A above, licensing/egress caveats) |
| YAML | yaml-language-server + **Fusion-aligned dbt JSON Schemas**; **dbt-osmosis** for scaffold/doc-propagation | Free parity with Studio IDE's YAML validation; osmosis kills the docs drudgery | — |
| Metrics | **MetricFlow CLI** (`mf` / `dbt sl`) | Fully local metric queries with dbt Core | — |
| Docs/catalog | `dbt docs generate` + DuckDB-over-artifacts (Parquet when v2 lands) for a TUI catalog | docs serve is browser-bound and slow; querying artifacts directly is the terminal-native move | dbt docs serve in cmux browser surface (interim) |
| Diff/CI | state:modified+ + defer with **managed prod-artifact fetch** (gh CLI artifact download) | Turns the DIY artifact plumbing into a one-keystroke "slim build" | Recce (web) — egress-dependent, skip |
| AI | Claude agent pane (cmux-native) | Replaces dbt Copilot/Power User AI with a stronger, local-controlled agent | Codex variant |

**Positioning synthesis:** the GUI tools have decided what world-class dbt DX is (L2 language
intelligence + lineage + preview loop + defer). The terminal has the *pieces* (fast engine, best
formatter, best SQL TUI, git/AI superiority via cmux) but no *composition* — and the official
intelligence tier is auth-gated SaaS, which cide's zero-egress stance turns from a weakness into
the product thesis: **all of the intelligence, none of the sign-in.** The five build-targets that
would make cide-dbt category-defining: (1) dbt-aware harlequin bridge (compile ref()s → execute →
grid), (2) TUI catalog/lineage browser over local artifacts, (3) CTE-level preview, (4) a
plan/impact preview for dbt (SQLMesh's best idea, absent from every dbt tool), (5) one-keystroke
defer/slim workflows with managed prod artifacts.

---

## 9. Risks & open questions

- **How much of the LSP is in Apache 2.0 dbt-core v2?** If the language-server itself stayed
  proprietary, cide must build intelligence from the v2 crates (parser/schemas) — more work, more
  defensible. Verify in the dbt-core repo.
- **Fusion telemetry behavior** under zero-egress — verify flags (`DBT_SEND_ANONYMOUS_USAGE_STATS`,
  `DO_NOT_TRACK`) apply to the Rust binary.
- **Adapter maturity**: Fusion DuckDB/Spark are Beta-CLI-only; Snowflake is the only GA. Projects
  on Postgres/other adapters may need Core v1 fallback for a while.
- **Merger turbulence**: Fivetran+dbt close expected mid/late 2026; product roadmaps (Fusion
  pricing tiers, SQLMesh feature absorption) may shift. SQLMesh under Linux Foundation is a
  stability positive for stealing its ideas.
- **dbt Core v1 compatibility tail**: many real projects still fail Fusion's stricter parser;
  `dbt-autofix` exists; cide should treat "engine = v1 Python" as a supported degraded mode.
- **Power User dependency on Altimate SaaS** for its AI/collab tier is a reminder: enumerate its
  *local* features as the benchmark, not its cloud ones.

---

## Sources

### dbt Fusion / Core v2 / LSP
- https://docs.getdbt.com/blog/dbt-fusion-engine — Meet the dbt Fusion Engine (Rust, 30x parse, SDF tech)
- https://docs.getdbt.com/docs/fusion — Fusion overview
- https://docs.getdbt.com/docs/fusion/about-fusion — About Fusion
- https://docs.getdbt.com/docs/fusion/supported-features — adapter matrix, feature gaps, LSP availability
- https://docs.getdbt.com/docs/fusion/fusion-availability — availability
- https://docs.getdbt.com/guides/fusion — Fusion quickstart
- https://docs.getdbt.com/blog/dbt-core-v2-is-here — dbt Core v2 alpha (Apache 2.0 Rust, Parquet artifacts, June 2026)
- https://github.com/dbt-labs/dbt-fusion — archived repo ("code & issue tracking in dbt-core")
- https://www.getdbt.com/blog/new-code-new-license-understanding-the-new-license-for-the-dbt-fusion-engine — ELv2 explainer
- https://docs.getdbt.com/docs/about-dbt-lsp — dbt LSP (lazy compilation, feature matrix)
- https://www.getdbt.com/blog/language-server-protocol — dbt Labs on LSP
- https://infinitelambda.com/dbt-fusion-faq/ — Fusion FAQ (internal use licensing)
- https://hiflylabs.com/blog/2025/6/27/dbt-fusion-first-look — hands-on review
- https://datalakehousehub.com/blog/2026-05-dbt-fusion-analytics-engineering/ — Fusion impact analysis
- https://www.theinformationlab.com/community/blog/dbt-fusion-the-complete-guide-to-the-new-engine-by-dbt-labs/ — Fusion guide
- https://www.tobikodata.com/blog/dbt-fusion-death-of-dbt-core — competitor perspective
- https://www.ssp.sh/brain/dbt-fusion/ — Simon Späti notes

### dbt VS Code extension
- https://docs.getdbt.com/docs/about-dbt-extension — about the extension
- https://docs.getdbt.com/docs/dbt-extension-features — canonical feature list (L1 vs registration-gated)
- https://docs.getdbt.com/docs/install-dbt-extension — install/configure (LSP auto-download)
- https://www.getdbt.com/blog/fusion-and-dbt-vs-code-extension-preview-launch — preview launch
- https://marketplace.visualstudio.com/items?itemName=dbtLabsInc.dbt — marketplace listing

### dbt Power User
- https://github.com/AltimateAI/vscode-dbt-power-user — README (feature enumeration)
- https://docs.myaltimate.com/ — full docs
- https://marketplace.visualstudio.com/items?itemName=innoverio.vscode-dbt-power-user — marketplace

### dbt Cloud / Studio IDE
- https://docs.getdbt.com/docs/cloud/dbt-cloud-ide/develop-in-the-cloud — Studio IDE
- https://docs.getdbt.com/docs/cloud/about-cloud/dbt-cloud-features — platform features
- https://www.getdbt.com/blog/whats-new-in-dbt-cloud-april-2025 — 2025 updates (Copilot, dark mode)
- https://www.getdbt.com/blog/dbt-developer-day-2025 — Developer Day announcements
- https://docs.getdbt.com/docs/dbt-versions/2025-release-notes — release notes (Fusion-aligned YAML JSON Schema)
- https://docs.getdbt.com/docs/cloud/dbt-cloud-ide/lint-format — lint/format (sqlfmt powers Format)

### SQLMesh
- https://www.tobikodata.com/blog/virtual-data-environments — virtual data environments
- https://sqlmesh.readthedocs.io/en/stable/guides/tablediff/ — table_diff
- https://sqlmesh.readthedocs.io/en/stable/reference/cli/ — CLI reference
- https://sqlmesh.readthedocs.io/en/latest/guides/ui/ — browser UI (column lineage)
- https://sqlmesh.readthedocs.io/en/stable/integrations/dbt/ — dbt integration
- https://blog.brightcoding.dev/2026/04/05/sqlmesh-the-revolutionary-data-framework-every-engineer-needs — plan/apply, lineage overview
- https://medium.com/@jared_86317/dbt-vs-sqlmesh-a-deep-dive-comparison-for-analytics-engineering-f3a022bdc705 — comparison
- https://thenewstack.io/fivetran-donates-sqlmesh-lf/ — Linux Foundation donation
- https://www.fivetran.com/press/fivetran-acquires-tobiko-data-to-power-the-next-generation-of-advanced-ai-ready-data-transformation — Tobiko acquisition

### Fivetran / dbt merger
- https://peliqan.io/blog/dbt-fivetran-merger-explained/ — merger explainer
- https://datacoves.com/post/dbt-fivetran — risks/lock-in analysis
- https://news.ycombinator.com/item?id=45568842 — HN thread

### Lint / format
- https://github.com/sqlfluff/sqlfluff — SQLFluff
- https://docs.sqlfluff.com/en/stable/configuration/templating/dbt.html — dbt templater (speed tradeoff)
- https://github.com/sqlfluff/sqlfluff/issues/651 — 10x slower with dbt templater
- https://github.com/quarylabs/sqruff — sqruff (Rust)
- https://www.quary.dev/blog/sqruff-launch — sqruff launch (translating sqlfluff to Rust)
- https://www.getdbt.com/blog/1000x-faster-sql-linting — dbt Labs on fast linting (SDF lineage)
- https://github.com/tconbeer/sqlfmt — sqlfmt
- https://sqlfmt.com/ — sqlfmt docs

### Terminal tools
- https://harlequin.sh/ — Harlequin
- https://github.com/tconbeer/harlequin — Harlequin repo
- https://harlequin.sh/docs/adapters — adapters (no dbt adapter)
- https://harlequin.sh/docs/contributing/adapter-guide — adapter authoring guide
- https://github.com/z3z1ma/dbt-osmosis — dbt-osmosis
- https://pypi.org/project/dbt-osmosis/ — dbt-osmosis releases
- https://crates.io/crates/dbt-lineage/0.2.0 — dbt-lineage Rust crate (ASCII/TUI/column lineage)
- https://discourse.getdbt.com/t/dbt-dag-lineage-graph-for-cli-version/3056 — CLI lineage demand thread

### Jinja / community LSPs
- https://github.com/uros-5/jinja-lsp — jinja-lsp (Rust; Helix/Neovim)
- https://github.com/j-clemons/dbt-language-server — Go dbt LSP (Helix config, Fusion diagnostics)
- https://github.com/fsorodrigues/dbt-ls — community dbt LS ("make the official LSP IDE-agnostic")
- https://github.com/zed-industries/extensions/issues/3205 — jinja-SQL grammar-combination pain

### State / defer / selectors
- https://docs.getdbt.com/reference/node-selection/defer — defer
- https://docs.getdbt.com/reference/node-selection/state-selection — state selection
- https://select.dev/posts/best-practices-for-dbt-workflows-1 — slim local builds
- https://select.dev/posts/best-practices-for-dbt-workflows-2 — slim CI
- https://datacoves.com/post/dbt-slim-ci — slim CI with --empty

### MetricFlow / semantic layer
- https://docs.getdbt.com/docs/build/metricflow-commands — MetricFlow commands (mf / dbt sl)
- https://github.com/dbt-labs/metricflow — MetricFlow repo
- https://docs.getdbt.com/docs/build/about-metricflow — about MetricFlow

### Lineage / docs
- https://stellans.io/dbt-lineage-visualization-tools/ — lineage tool survey
- https://www.getdbt.com/product/dbt-catalog — dbt Catalog
- https://medium.com/inthepipeline/dbt-data-lineage-diff-impact-analysis-visualized-bec9927b0c4e — lineage diff (Recce)

### Local files
- /Users/cmbays/github/cmux-workspace-dbt/docs/vision/research/cute-dbt-capabilities.md — sibling research note (cute-dbt capabilities)
