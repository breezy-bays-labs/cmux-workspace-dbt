# Product Documentation Plan — `cmux-terminal-ide` / `ctide`

> **SUPERSEDED — recon note only.** This has been **promoted and rename-resolved**
> to the canonical, epic-tied detail doc [`../product-docs-plan.md`](../product-docs-plan.md).
> Kept here for source-recon provenance; do not edit as a live planning artifact —
> make changes upstream in the promoted doc. The roadmap §8 index links the promoted
> top-level copy, with this file cited as its *source recon*.
>
> Roadmap research artifact. Answers the owner's "rustbook.md" question: what the
> production product docs should be, how they are structured, how they build
> deterministically and publish zero-egress-friendly, and how each build epic
> contributes its doc slice as-you-go (not big-bang).
>
> **Scope discipline:** this is a *documentation* plan. It does not re-litigate the
> approved product vision or architecture — it consumes them. Product source:
> [`docs/vision/product-vision.md`](../../vision/product-vision.md). Architecture source:
> [`docs/vision/design-plan.md`](../../vision/design-plan.md) (§3 ports, §5 config UX are
> the load-bearing inputs here). Self-documentation template: crap4rs
> (`/Users/cmbays/github/crap4rs/README.md`, `/Users/cmbays/github/crap4rs/docs/`).
> 2026-06-12.

---

## 0. Naming note (rebrand-aware)

The owner decided (2026-06-09) the Rust product is **`cmux-terminal-ide`**, binary
**`ctide`**, born new from crate one (shell `cide-*` dogfood commands are *strangled and
retired*, not renamed). This plan uses **`ctide`** for the binary and **cmux-terminal-ide**
for the product throughout. The vision/design docs still say "cide" because they predate or
straddle the rename — every "cide" verb cited below (`cide doctor`, `cide review`, …) maps
1:1 to `ctide doctor`, `ctide review`, etc. The docs themselves must ship with the new
names; the rename is a docs-correctness requirement, not a docs decision.

The **repo-rename open question** (`cmux-workspace-dbt` → `cmux-terminal-ide` vs new repo)
is decided elsewhere (the roadmap proper). It bears on docs only in one way, called out in
§5: the docs site's published URL and the `book.toml` `site-url` must match the final repo
slug, so **the docs publish workflow lands *after* the repo-rename decision** to avoid a
re-pin. That is the only coupling.

---

## 1. Recommendation: an mdBook tree, not a single `rustbook.md`

**Recommendation: ship an mdBook tree (`docs/book/` with a `SUMMARY.md` table of contents),
not a single `rustbook.md` file.** Lean: mdBook wins decisively on both reader UX and
maintainer UX for this product, at near-zero added cost given the constraints already in
play.

### Why mdBook over a single file

**Reader UX.** The product is multi-audience and multi-surface: a base-IDE user, a dbt
analytics engineer, a Rust dev, an adapter author, and an *agent* consuming the `--json`
contract all need different entry points. A single `rustbook.md` forces every reader to
scroll past everyone else's chapter; mdBook gives each a sidebar TOC, in-page search (the
killer feature for a reference-heavy config/CLI doc — built into mdBook, runs client-side,
no egress), prev/next chapter nav, and stable deep-link anchors per section
(`/config/layering.html#never-write-config`). For a terminal power user who will `cmd-F` and
deep-link constantly, search + anchors are the difference between docs that get used and docs
that get skimmed once.

**Maintainer UX.** The docs-as-you-go model (§4) means ~8 build epics (R1–R5 plus verticals)
each append or edit a chapter. With one giant file, every epic's PR touches the same file →
constant merge conflicts in a solo-but-parallel-sessions workflow (the owner runs concurrent
cmux sessions). With an mdBook tree, each chapter is its own file under `src/`, so epics edit
disjoint files and `SUMMARY.md` is the only shared surface (small, append-mostly, rarely
conflicting). This is the same reason crap4rs split `docs/scorecard-row-contract.md` out of
its README once the README crossed ~900 lines (`/Users/cmbays/github/crap4rs/README.md` is
already 583 lines and groans under it).

**It is the Rust-native, on-brand toolchain.** mdBook is the toolchain the Rust ecosystem
uses (The Rust Book, the Cargo Book, the Rustonomicon, rustc dev guide). For a tool whose
audience is terminal-sovereign Rust developers, shipping docs as an mdBook signals
"built by one of us." crap4rs itself is the org's published-Rust-tool template; extending
that template with mdBook is the natural next step it hasn't yet taken (crap4rs documents via
README + per-topic markdown + a generated `crap.example.toml`; it has no book site).

**It satisfies every hard constraint by construction:**
- **Single Rust binary, zero-egress build.** mdBook is a self-contained Rust binary
  (`cargo install mdbook`, or a pinned pre-built binary); `mdbook build` does no network I/O —
  it reads `src/*.md` and writes static HTML. Search index is built at compile time and runs
  client-side (no SaaS search, no Algolia). This is *the* zero-egress docs toolchain.
  ([mdBook install](https://rust-lang.github.io/mdBook/guide/installation.html))
- **Deterministic.** `mdbook build` is a pure markdown→HTML transform; pin the mdBook version
  (`MDBOOK_VERSION` env, as the official workflow does) and the output is reproducible across
  machines and CI runs. Same input + same binary version = byte-stable HTML.
- **Never-write-`~/.config`.** mdBook builds into a repo-local `book/` dir; nothing touches
  global state. (The build *tool* respects the same posture the product preaches.)
- **macOS-first, Linux-not-precluded.** mdBook runs identically on both; CI builds on Linux,
  authors on macOS — no platform branch.

### The honest counter, and why it loses

A single `rustbook.md` is *marginally* simpler to start (no `book.toml`, no `SUMMARY.md`, no
CI job) and renders fine in any markdown viewer including cmux's own `markdown open` surface
(useful for in-product help). But that simplicity evaporates the moment the doc exceeds one
screen of topics — which it does on day one (install + 3 IDE guides + config reference +
adapter authoring + power-user + architecture + troubleshooting = 8+ top-level sections).
The single-file approach also can't give the agent-facing `--json` contract its own stable,
deep-linkable reference page, and it can't be searched.

**Hybrid mitigation (keep the single-file benefit):** the mdBook's chapter source files *are*
plain markdown and render fine in cmux's `markdown open` panel. So in-product help (`ctide
help <topic>` → opens the relevant `src/*.md` in a cmux markdown surface via the `MuxViewers`
port) gets the single-file ergonomics *for free* from the mdBook source tree, while the
published site gets search + nav. We get both, not one. This also means **the docs are the
in-product help** — one source, two render targets — which is exactly the
machine-first/keystroke-reachable ethos (P5/P6).

---

## 2. The documentation outline (the `SUMMARY.md` tree)

Structure mirrors the reader's journey: get it running → use your IDE type → reference when
stuck → extend it → understand it. Each entry below names the chapter, its primary source in
the approved docs, and the build epic that authors it (§4 maps epics→chapters in full).

```
# SUMMARY.md  (the mdBook spine)

[Introduction]                      # what ctide is, the 7 pillars in 1 screen, non-goals
                                    #   src: product-vision §1, §3, §8

# Getting Started
- [Install]                         # brew tap, single binary, completions+man, doctor first
                                    #   src: design-plan §10 (Distribution); R1
- [Quickstart]                      # `ctide space new --type base` in any git repo → flow
                                    #   src: product-vision §3 day-in-the-life (condensed); R3
- [First 10 minutes]                # the review-queue loop, fix-on-red, the focus chord
                                    #   src: pillars P2/P4/P6; R4

# User Guides (the three IDE types)
- [The Base IDE]                    # spaces, review queue, attention, fix-on-red, journeys
                                    #   src: product-vision §3 (pillars, capability map); R3/R4
- [The dbt IDE]                     # persona loop, compile-on-save, harlequin, cute-dbt review
                                    #   src: product-vision §5 + design-plan §9 R5; R5 dbt slice
- [The Rust IDE]                    # bacon fast-path, nextest test-tree, quality cockpit, gates
                                    #   src: product-vision §6; rust-dev vertical (post-v1, stub now)

# Configuration
- [cide.toml & the layering model]  # the 5-layer precedence, ResolvedConfig, provenance
                                    #   src: design-plan §5; R1 (loader) + R4 (sync)
- [Never writes ~/.config]          # the consent model, `ctide setup`, the one global-write path
                                    #   src: design-plan §5 + product-vision §8 non-goals; R4
- [Recipes (verticals as data)]     # base/dbt/rust-dev TOML, `extends`, the swap table
                                    #   src: design-plan §2 IdeType + §5 example files; R5
- [Generated cmux files]            # `ctide sync` → .cmux/*.json, the generated-by marker
                                    #   src: design-plan §5 ownership split; R4
- [Config reference]                # every key, every default, which layer, egress label
                                    #   GENERATED from the config type (see §3); R1→R5 incremental

# Extending ctide (adapter authoring)
- [Ports & adapters overview]       # role-shaped ports, narrowed capability handles, sync/object-safe
                                    #   src: design-plan §3; R1
- [Writing an adapter]              # implement the trait, declare an EgressLabel, pass the kit
                                    #   src: design-plan §3 conformance kit; R1→R2
- [Swapping a tool]                 # the 3 concrete swaps (gitui, warehouse, watchexec/bacon)
                                    #   src: design-plan §3 "Three concrete swaps"; R2/R5
- [The conformance kit]             # cide-testkit, generated fixtures, "pass the suite" on-ramp
                                    #   src: design-plan §3 + §8; R3 (publish gate)

# Power-User Setup
- [The default tool stack]          # the §7 table: every tool, role, why, swap alternatives
                                    #   src: product-vision §7; cross-epic
- [Keymaps & the workspace which-key]  # tmux-style chords, palette taxonomy, one `ctide setup`
                                    #   src: product-vision P6 + backlog #14; R4
- [Theming]                         # one-stroke theme, cmux/Ghostty + browser surfaces, no ~/.config
                                    #   src: product-vision P6 + ThemeTarget port; R1
- [Latency & flow SLOs]             # the budgets, why they're release blockers, what to expect
                                    #   src: design-plan §8.7 + product-vision P6; R2+

# Agents & ctide (machine-first surface)
- [The --json contract]            # cide-json, schema versioning, deprecation policy, pinning
                                    #   src: design-plan §2 cide-json (g4) + §12 Q5; R1
- [The repo-local agent skill]      # what ships, how an agent drives ctide, examples
                                    #   src: product-vision P5; R4

# Architecture (overview + deep-link out)
- [Architecture overview]           # daemonless, multiplexer-is-supervisor, the 4-crate hexagon
                                    #   src: design-plan §1, §2 (summarized); links to full design-plan
- [Trust & zero-egress]             # egress labels, the doctor network surface, both layers
                                    #   src: design-plan §3 trust labels + product-vision §2; R1

# Operations
- [ctide doctor]                    # the health/trust/provenance/drift command, read it first
                                    #   src: design-plan §3, §5 (provenance g5), §10; R1
- [Troubleshooting]                 # symptom → doctor output → fix; cmux drift, capability probe
                                    #   src: design-plan §11 risk register (user-facing slice); cross-epic
- [Migrating from the shell dogfood]  # `ctide state migrate`, per-family, CIDE_SHELL rollback
                                    #   src: design-plan §9 migration; R1→R5

# Reference
- [CLI reference]                   # every verb, every flag — GENERATED from clap (see §3)
                                    #   GENERATED; R1→R5 incremental
- [Changelog]                       # release-plz-generated; links each version to its chapters
                                    #   src: release-plz (crap4rs template); ongoing
```

### Outline rationale (mapping the owner's required sections)

The owner named eight required pieces; here is where each lives:

1. **install/quickstart** → *Getting Started* (Install + Quickstart + First 10 minutes).
2. **three IDE types as user guides** → *User Guides* (Base / dbt / Rust), each a task-shaped
   walkthrough, not a feature dump — anchored on the §3/§5/§6 day-in-the-life narratives.
3. **config reference (cide.toml + layering + never-write-~/.config)** → *Configuration*, split
   into a conceptual page (layering model), a constraint page (never-write), and a
   **generated** exhaustive key reference (§3). The split mirrors crap4rs's own choice:
   conceptual prose in README + an exhaustive generated `crap.example.toml`
   (`/Users/cmbays/github/crap4rs/crap.example.toml`, generated from the config type with a
   sync test that keeps it from rotting). We copy that pattern exactly.
4. **adapter-authoring guide (trait ports + how to swap a tool)** → *Extending ctide*, built
   directly on design-plan §3. The "Swapping a tool" page lifts the three concrete swaps
   verbatim; the "Writing an adapter" page is the colleague on-ramp the design plan already
   names ("write an adapter, pass the suite").
5. **power-user setup** → *Power-User Setup*, fronted by the product-vision §7 table (the
   single most reference-worthy table in the whole corpus — every tool, role, defensibility,
   swap). Keymaps/theming/SLOs are its sub-pages.
6. **architecture overview (links design-plan)** → *Architecture*, deliberately a *summary*
   that deep-links into the full `design-plan.md` rather than duplicating it. The design plan
   stays the canonical engineering doc; the book chapter is the 2-screen orientation a
   contributor reads before opening it. (Avoids the divergence trap the vision/design docs
   already guard against with their cross-reference discipline.)
7. **troubleshooting/doctor** → *Operations* (ctide doctor + Troubleshooting + Migration).
   doctor gets its own page because it is the product's self-describing trust surface — the
   first thing every reader runs and the answer to most "why is it doing that?" questions
   (the design plan's g5 provenance feature is literally built for this page).
8. *(implicit)* **agent-facing docs** → *Agents & ctide*, because P5 ("agents are users of
   the IDE too") makes the `--json` contract a first-class public API that needs a stable,
   deep-linkable reference page — something a single `rustbook.md` structurally cannot give.

---

## 3. How docs build deterministically + publish zero-egress-friendly

### Build determinism

Three layers of determinism, strongest to weakest:

1. **Pinned toolchain.** `MDBOOK_VERSION` pinned in the workflow env (the official
   starter-workflow pattern), plus any preprocessor versions pinned the same way. `mdbook
   build` with a fixed binary version is a pure function of `src/`. crap4rs already pins its
   whole toolchain (`rust-toolchain.toml`, `cargo-dist`, `release-plz`); the docs job inherits
   that discipline.
2. **Generated content is generated in CI, committed-and-diffed, never hand-typed.** Two
   chapters are *generated*, not authored:
   - **CLI reference** — from `clap`. The binary already ships clap-generated completions +
     man pages (design-plan §10). Add a `ctide gen-docs` (or `clap-markdown`) step that emits
     the full verb/flag reference as markdown into `src/reference/cli.md`. A CI sync-test
     fails if the committed file drifts from regenerated output — exactly how crap4rs keeps
     `crap.example.toml` from rotting ("generated from the config type, a sync test keeps it
     from rotting", `/Users/cmbays/github/crap4rs/README.md` §Config file).
   - **Config reference** — from the `ResolvedConfig`/recipe serde types. Same mechanism:
     emit an annotated `cide.example.toml` + a key table into `src/config/reference.md`,
     sync-tested. This *is* the crap4rs `crap.example.toml` pattern, applied to `cide.toml`.
   Because both are mechanical emissions of pinned source types, they are deterministic by
   construction and can never silently lie about the binary's real surface.
3. **Link + content checks as a gate.** `mdbook test` (validates fenced Rust code examples
   compile — the architecture/adapter chapters carry real trait snippets) and
   `mdbook-linkcheck` (broken internal/anchor links fail CI). Both run offline. This keeps the
   heavy cross-referencing (every chapter cites a vision/design section) honest — the same
   cross-reference-integrity discipline the vision/design docs enforce by hand, now mechanical.

### Publish, zero-egress-friendly

The product's hard constraint is *runtime* zero-egress (the binary phones nobody). Docs
*publishing* is a CI concern, and the allowed-egress rule already in the constitution is
"GitHub via `gh` OK; no SaaS/telemetry." GitHub Pages via GitHub Actions is squarely inside
that allowance (it is GitHub, not a third-party SaaS), and it is the same forge the whole org
already lives on. So:

**Recommended: GitHub Pages via the official artifact-based deploy.** Use the official
mdBook starter workflow shape
([actions/starter-workflows/pages/mdbook.yml](https://github.com/actions/starter-workflows/blob/main/pages/mdbook.yml)):
- `permissions: { contents: read, pages: write, id-token: write }` (least privilege),
- `concurrency: { group: "pages", cancel-in-progress: false }` (never abort an in-flight
  publish),
- steps: `actions/configure-pages@v5` → install pinned mdBook → `mdbook build` →
  `actions/upload-pages-artifact@v3` → `actions/deploy-pages@v5`,
- trigger on push to the default branch (so docs ship when the feature ships) +
  `workflow_dispatch`.

This is the **artifact-based** approach (`deploy-pages`), not the legacy `gh-pages` branch.
Prefer it because it needs no `contents: write`, leaves no generated-HTML commits polluting
git history, and is the path GitHub itself documents. (Note: crap4rs *does* use a `gh-pages`
branch — but for a *different* job: ephemeral per-PR HTML scorecard reports
(`/Users/cmbays/github/crap4rs/.github/workflows/pages-cleanup.yml`), which need a writable
branch to add/remove `pr-<N>/` dirs. A stable docs site has no such need; use the cleaner
artifact path. The two could coexist later if ctide ever wants per-PR doc previews, reusing
crap4rs's `concurrency: gh-pages-publish` lock pattern.)

**Zero-egress integrity of the *published* site itself.** mdBook's default theme bundles its
own CSS/JS/fonts and the search index runs client-side — the published pages load no
third-party CDN by default. **Constraint for authors:** do not add preprocessors or themes
that inject remote assets. Specifically — `mdbook-mermaid` ships its mermaid JS *locally*
(safe; `mdbook-mermaid install` vendors the assets), but any "load from CDN" theme variant is
banned. This mirrors the product's own egress discipline: the docs site is itself a
zero-third-party-egress artifact, which is on-message for a zero-egress product. A
link-and-asset audit can be a one-line CI grep (no `https://cdn`, no `googleapis`, etc.) —
cheap insurance, same spirit as the design-plan's `~/.config`-path grep gate (§8.8).

**The fully-air-gapped reader.** Because `mdbook build` produces a self-contained static
`book/` dir, the docs ship *with the binary's repo* and render offline — `mdbook serve` or
just opening `book/index.html`. An air-gapped user clones the repo and reads the docs with no
network at all. And the same `src/*.md` open in cmux's `markdown open` surface for in-product
help (§1 hybrid). The published Pages site is a convenience, never the only access path —
which is the right posture for an air-gappable product.

---

## 4. Docs-as-you-go: each build epic ships its doc slice

**Principle: a feature is not "done" until its chapter is written.** No big-bang doc sprint at
the end — that is how docs rot before they ship. The migration plan (design-plan §9, phases
R1–R5) already chunks the build into shippable slices; each slice carries its doc slice in the
*same PR*. This is enforceable as a quality gate: the design plan already makes egress labels,
golden-master parity, and latency budgets release blockers — add "the chapter for any new
user-facing verb exists and `mdbook-linkcheck` passes" to the same gate. crap4rs precedent:
its docs (`docs/scorecard-row-contract.md`) landed with the feature that needed them, not after.

### Epic → doc-slice map

| Build phase (design-plan §9) | Ships | Doc slice authored in the same epic |
|---|---|---|
| **R1 — foundations** | binary skeleton, socket adapter + quirk vault, `cide-json`, `ctide doctor`, `ctide state migrate`, `ctide theme`, fixture generator | *Install*; *ctide doctor*; *Trust & zero-egress*; *The --json contract* (the frozen schema gets its versioning page on day one); *Architecture overview* (stub, since the hexagon lands here); *cide.toml & layering* (loader exists); *Theming*; *Config reference* (generator wired, even if thin); *Migrating from the shell dogfood* (the `state migrate` runbook). **R1 is doc-heavy by design** — it ships the trust + config + contract spine every later chapter references. |
| **R2 — runner + guarded writes** | `ctide run`/`run wrap`, `set-role`, `jump`, `open`, `md-open`, agents cluster | *First 10 minutes* (the runner is the first interactive loop); *Latency & flow SLOs* (budgets become real); *Writing an adapter* (RunnerEngine is the worked example); the **re-approval checkpoint** at end-R2 is a natural doc milestone — publish the site for the first time here. |
| **R3 — spaces + place** | `space new/open/close/rm/ls`, `ctide place` | *Quickstart* (now `space new` actually works end-to-end); *The Base IDE* (spaces are the unit of work — the flagship user guide); *The conformance kit* (publish gate — design-plan §12 Q6 places kit publication around R3); monitor-placement section of *Power-User Setup*. |
| **R4 — Rust-only capability** | `ctide sync`, `ctide review`, `ctide policy`, `ctide replace`, `ctide focus`, `ctide setup` | *The review queue* deep-dive in *The Base IDE*; *Generated cmux files* (`ctide sync`); *Never writes ~/.config* + *Keymaps* (both gated on `ctide setup`, which lands here); *The repo-local agent skill*. |
| **R5 — verticals + retirement** | dbt recipe (cute-dbt behind `DbtReview`, warehouse port), rust-dev recipe at the Rule-of-Two trigger | *The dbt IDE* (the full vertical guide); *Recipes (verticals as data)*; *Swapping a tool* (warehouse swap is the example); *The Rust IDE* graduates from stub to full guide when rust-dev ships. |
| **Cross-epic / ongoing** | every release | *CLI reference* + *Config reference* regenerate every build (CI sync-test); *Troubleshooting* accretes per incident; *Changelog* from release-plz; *Power-User stack table* updated whenever a default tool changes. |

### Walking-skeleton for the docs

R1 also stands up the **docs skeleton itself** — `book.toml`, `SUMMARY.md` with every chapter
stubbed (one-line "coming in Rx" placeholders so the TOC is whole from the start), the Pages
workflow (held un-triggered or gated until the repo-rename + R2 checkpoint per §0/§3), and the
two generators (CLI + config) wired even if their first emission is thin. This means every
later epic *fills in* a stub rather than *creating structure* — the same walking-skeleton
discipline the build plan uses for code, applied to docs. A stubbed-but-complete `SUMMARY.md`
also makes the docs-as-you-go gate trivial to check: "did this epic turn its stub into prose?"

---

## 5. Where the docs live in the repo

```
<repo-root>/                         # cmux-terminal-ide (post-rename) — see §0
├── docs/
│   ├── vision/                      # EXISTING — the approval-gate corpus (frozen reference)
│   │   ├── product-vision.md        #   what & why (consumed by the book, not duplicated)
│   │   ├── design-plan.md           #   how (the canonical engineering doc the book links to)
│   │   └── research/                #   18-file evidence corpus
│   ├── roadmap/                     # EXISTING — planning artifacts (this file lives here)
│   │   └── research/
│   │       └── product-docs-plan.md #   THIS FILE
│   └── book/                        # NEW — the published product docs (mdBook)
│       ├── book.toml                #   title, authors, site-url (pinned to final repo slug),
│       │                            #   [output.html] (default theme, search on), preprocessors
│       ├── src/
│       │   ├── SUMMARY.md           #   the TOC spine (§2)
│       │   ├── introduction.md
│       │   ├── getting-started/…    #   install.md, quickstart.md, first-10-minutes.md
│       │   ├── guides/…             #   base.md, dbt.md, rust.md
│       │   ├── config/…             #   layering.md, never-write-config.md, recipes.md,
│       │   │                        #     generated-cmux.md, reference.md (GENERATED)
│       │   ├── extending/…          #   ports.md, writing-an-adapter.md, swapping.md, kit.md
│       │   ├── power-user/…         #   stack.md, keymaps.md, theming.md, slos.md
│       │   ├── agents/…             #   json-contract.md, agent-skill.md
│       │   ├── architecture/…       #   overview.md, trust.md
│       │   ├── operations/…         #   doctor.md, troubleshooting.md, migrating.md
│       │   └── reference/…          #   cli.md (GENERATED), changelog.md
│       └── (book/  → build output, gitignored)
└── .github/workflows/
    └── docs.yml                     # NEW — pinned mdBook build + linkcheck + Pages deploy (§3)
```

**Why `docs/book/` and not repo-root `/book/` or a separate repo:**
- **Co-located with the code it documents** → the docs-as-you-go gate (§4) can require a docs
  diff in the same PR as a feature diff; a separate docs repo breaks that 1:1 PR mapping the
  org constitution mandates.
- **Under the existing `docs/` umbrella** alongside `vision/` and `roadmap/`, so the whole
  knowledge surface is one tree: `vision/` = the frozen "why", `roadmap/` = planning, `book/`
  = the living product docs. Clean separation of audience (internal reference vs. public docs)
  without repo sprawl.
- **`docs/book/src/*.md` are reusable as in-product help** (§1 hybrid) precisely because they
  live in the repo the binary is built from — `ctide help <topic>` resolves a path under
  `docs/book/src/` and opens it in a cmux markdown surface, or the relevant subset is
  `include_str!`'d into the binary the way recipes/layouts/themes already are (design-plan
  §10). Same source, three render targets: Pages site, cmux markdown surface, embedded help.

**The README's role after the book exists.** The repo README shrinks to a launchpad (what
ctide is in 3 sentences, install one-liner, the badge row, and "Full docs: <Pages URL>") —
the crap4rs README is the *counter*-example here (it grew to 583 lines because it had no book
to offload into; ctide should not repeat that). The book is the home; the README points to it.

---

## 6. Summary of recommendations

1. **mdBook tree, not single `rustbook.md`** — better reader UX (search, nav, per-audience
   entry, agent-contract page) and maintainer UX (disjoint files = no merge wars across
   parallel epic PRs), and it is the zero-egress, deterministic, Rust-native toolchain. Keep
   the single-file benefit via the hybrid: `src/*.md` double as in-product help.
2. **Outline = 9 sections** (Getting Started, User Guides ×3, Configuration, Extending,
   Power-User, Agents, Architecture, Operations, Reference) covering all eight required pieces
   plus the agent-facing `--json` contract that P5 elevates to a public API.
3. **Determinism = pin mdBook version + generate CLI & config reference from clap/serde types
   with sync-tests** (the crap4rs `crap.example.toml` pattern) + `mdbook test` +
   `mdbook-linkcheck` as offline gates.
4. **Publish = GitHub Pages via official artifact-based `deploy-pages@v5`** (inside the
   "GitHub-OK" egress allowance), default bundled theme (no CDN), a one-line no-remote-asset
   grep gate; site ships with the repo so it also reads fully offline.
5. **Docs-as-you-go = each R1–R5 epic authors its chapter in the same PR**, enforced as a
   release gate; R1 stands up the walking-skeleton (`book.toml` + stubbed `SUMMARY.md` +
   generators + held workflow), publish first goes live at the end-R2 re-approval checkpoint.
6. **Location = `docs/book/`**, co-located under the existing `docs/` umbrella; README shrinks
   to a launchpad pointing at the book.

### Open coupling to flag for the roadmap
- **Repo-rename ordering:** the docs publish workflow's `site-url` must match the final repo
  slug → land/trigger the Pages deploy *after* the `cmux-workspace-dbt → cmux-terminal-ide`
  rename decision (§0). Authoring the book content can start before; only the publish pin waits.
- **License on the docs site:** the GPL-v3-vs-MIT ruling (design-plan §12 Q8) should be
  settled before the public Pages site goes live, so the footer license is correct from
  publish-one.

---

## Sources

- Product vision: [`docs/vision/product-vision.md`](../../vision/product-vision.md) — §1
  (pillars), §3 (base IDE + day-in-the-life + capability map), §5 (dbt IDE), §6 (rust IDE),
  §7 (power-user tool table), §8 (non-goals).
- Design plan: [`docs/vision/design-plan.md`](../../vision/design-plan.md) — §1 (architecture
  overview), §2 (crate layout, IdeType, cide-json g4), §3 (ports & adapters, three swaps,
  conformance kit, trust labels), §5 (config layering, never-write-~/.config, provenance g5),
  §8 (testing gates), §9 (migration R1–R5), §10 (distribution), §11 (risk register), §12
  (open questions Q6/Q8).
- Self-documentation template: `/Users/cmbays/github/crap4rs/README.md` (the generated
  `crap.example.toml` + sync-test pattern, §Config file),
  `/Users/cmbays/github/crap4rs/docs/scorecard-row-contract.md` (per-topic doc split),
  `/Users/cmbays/github/crap4rs/.github/workflows/pages-cleanup.yml` (gh-pages branch is used
  only for ephemeral per-PR HTML reports + the `gh-pages-publish` concurrency-lock pattern),
  `/Users/cmbays/github/crap4rs/crap.example.toml`.
- Repo README: `/Users/cmbays/github/cmux-workspace-dbt/README.md` (current `cwd` shell tool,
  the `cwd doctor` / state-migrate runbook precedents the docs inherit).
- mdBook: [Continuous integration](https://rust-lang.github.io/mdBook/continuous-integration.html)
  (`mdbook test`, linkcheck), [Installation](https://rust-lang.github.io/mdBook/guide/installation.html)
  (single self-contained Rust binary, offline build),
  [official Pages starter workflow](https://github.com/actions/starter-workflows/blob/main/pages/mdbook.yml)
  (pinned `MDBOOK_VERSION`, `configure-pages@v5` → `upload-pages-artifact@v3` →
  `deploy-pages@v5`, least-privilege permissions, `concurrency: pages`),
  [peaceiris/actions-mdbook](https://github.com/peaceiris/actions-mdbook),
  [mdbook-mermaid (vendors assets locally)](https://crates.io/crates/mdbook-mermaid),
  [mdbook-admonish](https://crates.io/crates/mdbook-admonish).
```
