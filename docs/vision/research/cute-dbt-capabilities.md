# cute-dbt — Capability Profile for the cide dbt IDE

> Research note for the cide dbt-IDE vision. Profiles what cute-dbt (the owner's own
> dbt DX tool, `breezy-bays-labs/cute-dbt`) does today, where its roadmap is headed,
> which dbt-IDE gaps it can fill, and how a cide dbt IDE should integrate it.
> Date: 2026-06-09.

---

## 1. What cute-dbt is

**cute** = **C**TE · **C**ontextualized · **C**LI — **U**nit **T**est **E**xplorer for **dbt**.

A **zero-compute, single-binary Rust CLI** that parses a dbt `manifest.json` (dbt >= 1.8,
must be `dbt compile`d, not just `dbt parse`d) and emits **one self-contained interactive
HTML report** visualizing dbt **unit tests in context**: per test, a header,
Given/Expected DataTables panels, an authoring-YAML drawer, and a left-to-right Mermaid
**CTE dependency DAG** with join-type-colored edges.

Identity facts:

- **Language/stack**: Rust (edition 2024, MSRV 1.85), single crate by deliberate design,
  hexagonal inward-dependency discipline enforced by module convention
  (`src/{domain, ports, adapters, cli}` + `main.rs`/`lib.rs`). Runtime deps are tiny:
  `clap`, `askama` 0.16, `serde/serde_json`, `sqlparser` 0.62, `thiserror`, `toml`.
- **Version**: v0.1.0 (v0.x unstable; CLI surface MAY break on minor bumps; v1.0 is the
  first stability commitment). Publishes to crates.io via release-plz + OIDC — note open
  issue #112: release-plz GitHub App token 404 **blocks the first publish**, so
  `cargo install cute-dbt` may not work yet; build-from-repo does (a debug binary exists
  at `target/debug/cute-dbt`; it is **not currently on PATH**).
- **License**: MIT. Docs: mdbook at https://breezy-bays-labs.github.io/cute-dbt/.
- **Privacy posture is the headline architectural property** — and it exactly matches
  cide's hard constraint set:
  - **Zero compute**: parses `manifest.json` only — no DB connection, no SQL execution,
    no warehouse driver. Reads bytes, writes one HTML file.
  - **Zero telemetry**: no analytics, crash reporting, or auto-update.
  - **Zero egress**: all report assets (Sakura CSS, jQuery, DataTables, Mermaid) are
    vendored + inlined at compile time; the report opens from `file://` and makes zero
    outbound requests. Proven by a headless-Chromium network-block test in CI (CDP
    capture of every `Network.requestWillBeSent`; filter to http/https/ws/wss → empty)
    plus a structural HTML lint (`tl` parser rejecting `<script src>`, `<link href>`,
    `@import`, `url()`, protocol-relative `//`).
  - **Fail-closed**: a parse-only manifest, pre-1.8 manifest, unreadable manifest, or
    unusable baseline → non-zero exit and **no HTML**, never a partial report.
  - **Synthetic-only fixtures** repo-wide.

## 2. CLI surface today (v0.1)

One command (no subcommands yet — `explore` is the planned second subcommand, see §4):

```
cute-dbt [OPTIONS] --manifest <PATH> --out <PATH> <--baseline-manifest <PATH> | --pr-diff <@FILE>>
```

| Flag | Purpose |
|---|---|
| `--manifest <PATH>` | Compiled `manifest.json` to visualize (required). |
| `--baseline-manifest <PATH>` | Scope source 1 (local-dev): diff against a baseline manifest, `state:modified.body` semantics (model body checksum differs). Exactly one scope source required. |
| `--pr-diff @<FILE>` | Scope source 2 (CI/PR review): a raw `git diff --unified=0` patch file. cute-dbt parses changed paths + hunks itself (block-precise updated-test detection, #96); it never shells out to git or reads `GITHUB_EVENT_PATH`. |
| `--out <PATH>` | Where `report.html` is written (required). |
| `--config <PATH>` | Optional TOML: `[report].title` / `[report].subtitle`. |
| `--project-root <PATH>` | Optional dbt project root; enables the "Authoring YAML" drawer (raw unit-test YAML with comments). Auto-derived by stripping `target/manifest.json` from `--manifest` when omitted; soft-fails. |

Error discipline: missing/conflicting scope source, bad `--config`, bad `--project-root`,
malformed `--pr-diff` file → clap usage errors (exit 2). Manifest-level problems →
`PreflightError` (4 variants, `#[non_exhaustive]`, frozen by ADR), non-zero exit.
**Empty scope is a valid exit-0 report**, not an error.

Full-manifest report is a documented trick only: diff against an empty/genesis baseline.
There is deliberately no implicit "whole project" path in `report` mode.

## 3. Report capabilities today (what the HTML shows)

Per in-scope unit test / model:

- **Header**: test name, target model, description; a diff-scope banner naming the
  baseline reference and in-scope test count.
- **Given / Expected fixture tables**: searchable, sortable DataTables, rendered
  uniformly regardless of authored format — dict rows, CSV, **raw/literal-row SQL**
  (#137/#142), and **external fixture files** (csv/sql, #126/#154).
- **Cell-level semantic data-table diff** for changed tests (#98, #130–#142 line):
  fusion-aligned, toggleable, bold red/green cells, **null-aware and type-aware**
  (dict↔csv reformat shows no diff thanks to value normalization #127), per-given source
  ordinal binding (#131/#152), display-vs-equality cell axes (#138/#140), bidirectional
  diff-hunk folding (#134/#136).
- **Inline SQL diff for changed models** (#111) and **YAML text-diff drawer** with
  `overrides` (env_vars/macros/vars) surfaced (#125/#144), pin-able override-only edits.
- **Report settings cog** (#141): diff context-lines + normalize-equality toggle.
- **CTE dependency DAG** (Mermaid `graph LR`): nodes classified `final`/`import`/
  `transform`; edges colored by join type (`from`/`inner`/`left`/`right`/`full`/`cross`/
  `union_all`/`union_distinct`); always-visible colorblind-safe legend; stable node
  identity even when a CTE shares the model's name (#155/#156).
- **Import-CTE fixture binding** (two-pass, case-insensitive: name match with strict
  Import-role gate, then body-leaf-ref match) so the node-detail panel shows fixture rows
  **next to the compiled SQL of the CTE they mock**; unbound Import CTEs surface dbt's
  "unspecified inputs are empty" semantics explicitly.
- **Compiled-SQL drawer with exact fidelity**: each CTE's source extent is sliced from
  `compiled_code` via sqlparser span metadata — comments, casing, indentation preserved
  (#31), with a nested-jinja token-stream highlighter (#132/#133).
- **Incremental-model unit-test semantics** surfaced (badge + strategy-correct
  expect-semantics tooltip, #145/#146, #159/#161).
- **Scope to updated tests by default + toggle to include unchanged** (#91).
- Mobile/stacked-viewport fixes (#157) — the report is responsive.

Delivery dogfood already proven in its own CI (#148/#149, #118, #134): per-PR GitHub
Pages preview + dual-link sticky PR comment, running `cute-dbt --pr-diff` on the repo's
own embedded `dbt-project/` (a dbt-fusion example project used as living showcase and
fixture single-source-of-truth, #114/#115).

Quality machinery worth knowing about (signals tool maturity): Gherkin/cucumber ATDD
features doubling as docs, insta golden snapshots, mutation testing (cargo-mutants),
crap4rs, llvm-cov, cargo-deny, MSRV job, zero-egress headless gate, fixture SHA-256
manifest, `non-mirror-guard` (rejects a future `[workspace]`).

## 4. Roadmap / direction (from open issues)

### Epic #99 — `cute-dbt explore` subcommand (the big one for the IDE)

An interactive, **full-manifest**, zero-egress static HTML **model explorer** for the
local-dev loop, alongside PR-review `report`:

- `cute-dbt explore --manifest M --out-dir D/` → **two self-contained pages**:
  `dag.html` (interactive **Cytoscape.js + cytoscape-dagre** model-lineage DAG —
  pan/zoom/fuzzy-search, validated on a 372-node graph; CTE ⇄ model view toggle) and
  `tests.html` (unit-test viewer). Fail-OPEN on uncompiled models (renders "not
  compiled"), each page passes the zero-egress gate independently.
- **Interaction model**: hover → tooltip; click/search-select → **highlight** (emphasize
  node + full upstream/downstream lineage, dim rest, show model-detail card); **Space**
  → **focus commit** that writes a `data-selected-model` DOM attribute.
- **V6 — external-drive JS contract** (#105): `focusModel(name)` / `setView()` JS API +
  commit-only `data-selected-model` attribute + version string — an explicit,
  SemVer-governed seam for **external tools (i.e., an IDE) to drive and observe the
  explorer**. This is purpose-built for cide integration.
- Slices: V1 `explore` two-page output (#100, priority:soon), V2 interactive Cytoscape
  lineage + highlight/focus (#101, soon), V3 view toggle + tests.html (#102), V4
  per-node test-count badges (#103), V5 model-detail card — description, materialization,
  tags, meta, unique grain, columns + hover tooltip (#104), V6 external-drive contract
  (#105), V7 optional `--baseline` diff-highlight (cut line, #106).
- CLI breaks at that point: bare `cute-dbt` → usage error; `report` becomes a subcommand.

### Epic #78 — Team PR-review ergonomics

Phase 1 (largely landed: `--pr-diff` flag, mdbook GitHub Actions recipe, sticky-comment +
Pages preview dogfood). Phase 2: a separate `breezy-bays-labs/cute-dbt-action`
Marketplace composite Action (≤7 lines of adopter YAML). Supporting: #92 low-friction
**private-repo report delivery** (no public Pages exposure), #82 two-track recipe docs,
#79 privacy guard (private-repo/public-Pages mismatch detection), #80 git-rename
detection on PR-diff scope.

### Fidelity widening

- #160: CLI selector for `.configs`/`.relation`/`.macros`/`.contract` sub-modifiers
  (`state:modified` parity; the `StateComparator::with_sub_selectors()` machinery already
  exists — only the flag is missing).
- #57: `source()` binding — bind `given: source(...)` fixtures to import-CTE nodes
  (v0.2 sources widening).
- #15: v0.2 epic — per-CTE `@desc` breakdown + tokenizer/CommentMap seam (inline CTE
  documentation annotations).
- #32: per-cell tooltip extensibility on Given/Expected tables (design).
- #112: unblock crates.io publish (release-plz token), priority:soon.

Direction summary: cute-dbt is evolving from "PR-review unit-test report" into a
**two-mode dbt comprehension surface** — fail-closed diff-scoped `report` for review, and
fail-open full-manifest `explore` for the live dev loop, with an explicit JS contract for
embedding/driving from other tools. Still strictly zero-compute (manifest-only — it will
not run dbt, query a warehouse, or execute SQL).

## 5. dbt-IDE gap analysis

### Gaps cute-dbt fills (today or near-term roadmap)

| dbt-IDE need | cute-dbt coverage |
|---|---|
| **Unit-test comprehension** (read Given/Expected in context, all fixture formats) | TODAY — core product, best-in-class; nothing else renders dbt unit tests like this. |
| **Compiled-SQL preview per CTE** (exact `dbt compile` output, comments preserved, sliced per CTE) | TODAY — node-detail compiled-SQL drawer. Requires a fresh `dbt compile` first (IDE's job). |
| **CTE-level dependency graph of a single model** (join-typed edges) | TODAY — the headline Mermaid DAG. |
| **Diff review of dbt changes** (model SQL diff, unit-test YAML diff, semantic cell-level fixture diff) | TODAY — `--baseline-manifest` locally, `--pr-diff` in CI. The semantic fixture diff is unique. |
| **Model-level lineage navigation** (pan/zoom/search the whole project DAG, focus a model, see its detail card, test badges) | ROADMAP #99 (V1/V2 priority:soon) — `explore` dag.html. |
| **"Is this model tested?" / test-count overview** | ROADMAP #103 (badges) + #102 (tests.html). |
| **Model metadata card** (description, materialization, tags, meta, grain, columns) | ROADMAP #104 — a local, zero-egress alternative to `dbt docs serve` for the common questions. |
| **IDE↔report two-way integration seam** | ROADMAP #105 — `focusModel`/`setView` + `data-selected-model` commit attribute, versioned. |
| **PR-review delivery** (Pages preview + sticky comment recipes, future Marketplace Action) | TODAY (recipe) / ROADMAP #78 Phase 2. |

### Gaps that need OTHER tools (out of cute-dbt's deliberate scope)

cute-dbt is zero-compute and read-only by design. A cide dbt IDE must source these
elsewhere:

| dbt-IDE need | Tool to use instead |
|---|---|
| **Running/compiling/building** (`dbt run/build/test/compile`, deferred state, `--select` graph operators) | dbt CLI (dbt-core or dbt-fusion) via the cide runner pane; cute-dbt consumes the resulting `manifest.json`. |
| **DAG-aware selective runs** (`state:modified+`, `+model+`) | dbt's own selector engine; cide can generate the selector strings. |
| **Querying the warehouse / data preview / ad-hoc SQL** | harlequin (already in the owner's stack) or `dbt show`. |
| **SQL/Jinja editing, LSP, formatting, linting** | helix + dbt LSP options (e.g. dbt-language-server / sqlmesh-style tooling), sqlfluff/sqlfmt — separate evaluation. |
| **Jinja rendering of an UNCOMPILED buffer** (live compile-on-keystroke) | `dbt compile --select <model>`; cute-dbt only ever sees compiled artifacts. |
| **Column-level lineage** | Not in cute-dbt (model-level + CTE-level only); would need sqlglot/sqlmesh-class tooling if ever wanted. |
| **Data tests / source freshness results** | dbt artifacts (`run_results.json`, `sources.json`) — cute-dbt reads only `manifest.json` today. |
| **Scaffolding** (new model/test/staging boilerplate) | Templates/justfile/dbt-codegen — not cute-dbt's lane. |
| **Full docs site** (`dbt docs`) | cute-dbt explore intentionally replaces the *common subset* locally; the full catalog (`catalog.json` types/stats) still needs `dbt docs` if required. |

## 6. How a cide dbt IDE should integrate cute-dbt

cute-dbt's output is **HTML opened from `file://`** — and cmux has first-class **browser
surfaces**. This is a natural pane, not a TUI shoehorn.

### Panes

1. **"Test Review" browser surface** — a cmux browser surface pointed at the generated
   `report.html`. Local loop: IDE runs `dbt compile` → `cute-dbt --manifest
   target/manifest.json --baseline-manifest <baseline> --out .cide/dbt/report.html` →
   (re)loads the surface. Baseline source = the manifest from the merge-base / a cached
   `prod` artifacts dir (the IDE should own baseline lifecycle: e.g. snapshot
   `target/manifest.json` on branch checkout or pull it from CI).
2. **"Model Explorer" browser surface** (once #100/#101 land) — `explore`'s `dag.html`
   as a persistent lineage-navigation pane in the dbt IDE layout; `tests.html` as a
   secondary tab. Until then, the genesis-baseline trick gives a crude full-project
   report.
3. The report/explorer pages are fully self-contained, so panes survive offline and
   never violate cide's zero-egress constraint.

### Palette actions (cide command palette / cmux actions)

- `dbt: review my changes` — compile → cute-dbt vs merge-base baseline → open/refresh
  report surface.
- `dbt: review PR #N` — `gh pr diff N --patch > diff.patch` (or
  `git diff --unified=0 base...head`) → `cute-dbt --pr-diff @diff.patch` → open surface.
  (gh CLI is allowed egress; cute-dbt itself stays offline.)
- `dbt: explore project` (post-#100) — compile if stale → `cute-dbt explore` → open
  `dag.html`.
- `dbt: snapshot baseline` — copy current `target/manifest.json` to
  `.cide/dbt/baseline/manifest.json` (the IDE-owned baseline store).
- `dbt: open test report for <model>` — future: combine with #105 `focusModel`.

### Runner-catalog entries (the dbt variant of the test/build runner pane, task #23)

| Entry | Command sketch |
|---|---|
| `dbt compile` | `dbt compile` (prereq for everything cute-dbt does) |
| `dbt build (modified+)` | `dbt build --select state:modified+ --defer --state .cide/dbt/baseline` |
| `cute-dbt report (local)` | compile → `cute-dbt --manifest target/manifest.json --baseline-manifest .cide/dbt/baseline/manifest.json --out .cide/dbt/report.html` → reload browser surface |
| `cute-dbt report (pr-diff)` | `git diff --unified=0 $(git merge-base origin/main HEAD)...HEAD > .cide/dbt/diff.patch` → `cute-dbt --pr-diff @.cide/dbt/diff.patch ...` |
| `cute-dbt explore` (post-#100) | `cute-dbt explore --manifest target/manifest.json --out-dir .cide/dbt/explore/` |

Exit-code semantics are runner-friendly: exit 0 incl. empty scope ("no dbt tests in
scope" is a valid green), exit 2 usage, non-zero PreflightError with remediation message
(surface in the cmux notification feed — e.g. "manifest is parse-only; run dbt compile").

### Deeper integration (when #105 lands)

The external-drive JS contract is the strategic hook: cide can call
`focusModel('stg_orders')` in the explorer surface when the editor opens
`models/staging/stg_orders.sql` (editor → DAG follow-mode), and watch
`data-selected-model` to drive the reverse (Space in the DAG → open the model file in
helix, or run `dbt build --select <model>+`). cmux browser-surface automation makes both
directions feasible. cide should pin the contract version string and treat it as a
SemVer'd API per cute-dbt's release discipline.

### Hexagonal fit for the Rust cide

Model cute-dbt behind a `DbtReviewPort` (trait): operations like
`generate_report(manifest, scope_source, out) -> Result<ReportArtifact>`,
`generate_explorer(...)`, capability discovery via `cute-dbt --version`. The adapter
shells out to the binary; a future adapter could link the crate directly once cute-dbt's
library surface stabilizes (it is **internal-only in v0.x** — do not depend on
`cute_dbt::` APIs yet; the CLI is the contract). Same philosophy match: both tools are
single-purpose, zero-egress, fail-closed, ports-and-adapters Rust.

### Practical cautions

- **Not on PATH yet / not yet on crates.io** (#112 blocks first publish). The IDE's
  doctor command should detect-and-advise: `cargo install --path
  ~/github/cute-dbt` or `cargo install cute-dbt` once published.
- **v0.x CLI instability**: minor bumps may rename flags and will introduce subcommands
  (`report`/`explore` split). The runner catalog should version-gate command shapes.
- **dbt >= 1.8 manifests only**, and **compiled** ones — the IDE must own the
  compile-before-report sequencing.
- **Baseline management is undefined product space** — cute-dbt requires a baseline but
  doesn't fetch/store one. This is a genuine cide value-add (baseline snapshot store +
  merge-base resolution), and worth designing deliberately.

## Sources

Local (all under `/Users/cmbays/github/cute-dbt/` unless noted):

- `README.md` — product overview, scope semantics, zero-egress story, fidelity limits, import-CTE binding, compiled-SQL fidelity
- `Cargo.toml` — language, deps, single-crate rationale, v0.1.0
- `src/cli/args.rs` — exact CLI surface + error semantics; `src/` module tree (`domain/ports/adapters/cli`)
- `ARCHITECTURE.md` — hexagonal layout, two-stage fail-closed contract, StateComparator strategy, zero-egress gates (headings reviewed)
- `CHANGELOG.md` — renderer/asset history
- `book/src/features/index.md`, `book/src/how-it-works.md`, `book/src/SUMMARY.md` — mdbook feature/product docs
- `dbt-project/` — embedded dbt-fusion dogfood project
- `target/debug/cute-dbt --help` — live CLI help output (binary not on PATH)
- Git: `git -C ~/github/cute-dbt remote -v` → `breezy-bays-labs/cute-dbt`; `git log --oneline -15`

GitHub (via `gh`):

- Open issues: https://github.com/breezy-bays-labs/cute-dbt/issues — #15, #32, #57, #64, #68, #78, #79, #80, #82, #92, #99, #100, #101, #102, #103, #104, #105, #106, #112, #129, #143, #153, #160
- Epic detail: https://github.com/breezy-bays-labs/cute-dbt/issues/99 (explore subcommand), https://github.com/breezy-bays-labs/cute-dbt/issues/78 (team PR-review ergonomics)
- Recently closed (trajectory): #91, #93, #96, #98, #109, #111, #114–#118, #121, #124–#128, #131–#139, #145–#150, #155–#159
- Product docs: https://breezy-bays-labs.github.io/cute-dbt/
- Crates.io (publish pending #112): https://crates.io/crates/cute-dbt
