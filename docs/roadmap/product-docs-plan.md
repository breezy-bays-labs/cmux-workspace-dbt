# Product Documentation Plan — `cmux-terminal-ide` / `ctide`

> One of the five roadmap detail docs (the [master roadmap](./roadmap.md) §8 is the
> index this hangs off). It answers the owner's "rustbook.md" question for the *production
> product docs*: what they should be, how they are structured, how they build
> deterministically and publish zero-egress-friendly, and how each build **epic** (E0–E10)
> contributes its doc slice as-you-go so docs never lag the build. It conforms to the
> roadmap's phase ids (R0–R5), epic ids (E0–E10), the **rename-in-place** ruling (roadmap
> §3 R0), and the daemonless + zero-egress + never-write-`~/.config` + no-tokio constraints.
>
> **Scope discipline.** This is a *documentation* plan. It consumes the approved product
> vision and architecture, it does not re-litigate them. Product source:
> [`docs/vision/product-vision.md`](../vision/product-vision.md). Architecture source:
> [`docs/vision/design-plan.md`](../vision/design-plan.md) (§3 ports, §5 config UX are the
> load-bearing inputs). Self-documentation template: crap4rs
> (`/Users/cmbays/github/crap4rs/`). Promoted from the recon note
> [`research/product-docs-plan.md`](./research/product-docs-plan.md) — epic-tied and
> rename-resolved here. 2026-06-12.

---

## 0. Naming + rename: what is settled, what the docs inherit

The owner decided (2026-06-09) the Rust product is **`cmux-terminal-ide`**, binary
**`ctide`**, born new from crate one — the shell `cide-*` dogfood commands are *strangled
and retired*, not renamed (roadmap §1, design-plan §9). This plan uses **`ctide`** for the
binary and **cmux-terminal-ide** for the product throughout. The vision/design docs still
say "cide" because they predate the rename; every "cide" verb cited there (`cide doctor`,
`cide review`, …) maps 1:1 to `ctide doctor`, `ctide review`. **Shipping the new names is a
docs-correctness requirement, not a docs decision** — the book must never echo a retired
identifier. (The full naming map — `cide-*`→`ctide-*`, `CIDE_*`→`CTIDE_*`, state dir,
`ctide.toml`, brew formula + tap — is the sibling doc [`rebrand-ctide.md`](./rebrand-ctide.md);
the docs build pins against its final values.)

The **repo-rename open question is no longer open.** The roadmap ruled (§3 R0):
**rename `cmux-workspace-dbt → cmux-terminal-ide` in place at R0; do not start a new repo**
(the POSIX golden master ~120 assertions, strangler coexistence, and `CTIDE_SHELL` rollback
all require one tree). This bears on docs in exactly one place, the only coupling worth a flag:
the docs site's published URL and the `book.toml` `site-url` must match the final repo slug,
so **the docs *publish* workflow triggers only after the R0 rename lands** (§3, §6). The
rename is a known R0 deliverable, so this is a sequencing note, not an unknown — authoring
the book *content* can start before the publish pin is set.

---

## 1. Recommendation: an mdBook tree, not a single `rustbook.md`

**Ship an mdBook tree (`docs/book/` with a `SUMMARY.md` table of contents), not a single
`rustbook.md` file.** mdBook wins decisively on reader UX *and* maintainer UX for this
product, at near-zero added cost given the constraints already in play, and it is the
Rust-native, zero-egress, deterministic toolchain the architecture already preaches.

### Why mdBook over a single file

**Reader UX — multi-audience, multi-surface.** The product has five distinct readers who
need different entry points: a base-IDE user, a dbt analytics engineer, a Rust dev, an
adapter author, and an *agent* consuming the `--json` contract (P5 makes the agent a
first-class reader). A single `rustbook.md` forces every reader to scroll past everyone
else's chapter. mdBook gives each a sidebar TOC, **in-page search** (the killer feature for
a reference-heavy CLI/config doc — built into mdBook, compiled at build time, runs
client-side, **no egress**), prev/next nav, and stable deep-link anchors per section
(`/config/layering.html#never-write-config`). For a terminal power user who lives in `cmd-F`
and deep-links, search + anchors are the difference between docs that get used and docs
skimmed once.

**Maintainer UX — disjoint files survive parallel epic PRs.** The docs-as-you-go model (§4)
has ~8 build epics (E1–E7 plus the post-v1 verticals) each append or edit a chapter. With
one giant file, every epic's PR touches the same file → constant merge conflicts in the
owner's solo-but-concurrent cmux-session workflow. With an mdBook tree, each chapter is its
own file under `src/`, so epics edit disjoint files and `SUMMARY.md` is the only shared
surface (small, append-mostly, rarely conflicting). This is the same reason crap4rs split
`docs/scorecard-row-contract.md` out of its README once the README crossed ~900 lines
(`/Users/cmbays/github/crap4rs/README.md` is already 582 lines and groans under it; the
current ctide repo README is 168 lines and should *stay* small — §5).

**It is the Rust-native, on-brand toolchain.** mdBook is what the Rust ecosystem ships docs
in (The Rust Book, the Cargo Book, the Rustonomicon, rustc dev guide). For a tool whose
audience is terminal-sovereign Rust developers, an mdBook signals "built by one of us."
crap4rs is the org's published-Rust-tool template; it documents via README + per-topic
markdown + a generated `crap.example.toml`, but has **no book site** — adding mdBook is the
natural next step the template hasn't taken, and ctide is the right place to take it.

**It satisfies every hard constraint by construction:**

- **Single Rust binary, zero-egress build.** mdBook is a self-contained Rust binary
  (`cargo install mdbook`, or a pinned prebuilt); `mdbook build` does no network I/O — it
  reads `src/*.md`, writes static HTML, builds the search index at compile time, runs it
  client-side. This is *the* zero-egress docs toolchain.
  ([install](https://rust-lang.github.io/mdBook/guide/installation.html))
- **Deterministic.** `mdbook build` is a pure markdown→HTML transform; pin the version
  (`MDBOOK_VERSION`) and output is byte-stable across machines and CI runs (§3).
- **Never-write-`~/.config`.** mdBook builds into a repo-local `book/` dir; nothing touches
  global state. The build *tool* respects the posture the product preaches.
- **macOS-first, Linux-not-precluded.** mdBook runs identically on both; CI builds on Linux,
  authors on macOS — no platform branch (matches the roadmap's
  aarch64-darwin + aarch64-linux-musl compile matrix, §3 R0).

### The honest counter, and the hybrid that captures its one benefit

A single `rustbook.md` is *marginally* simpler to start (no `book.toml`, no `SUMMARY.md`, no
CI job) and renders fine in any markdown viewer — including cmux's own `markdown open`
surface (the `MuxViewers` port, design-plan §3), which is useful for in-product help. But
that simplicity evaporates on day one: install + 3 IDE guides + config reference + adapter
authoring + power-user + architecture + troubleshooting = 9 top-level sections immediately.
The single file also cannot give the agent-facing `--json` contract its own stable,
deep-linkable reference page, and it cannot be searched.

**Hybrid mitigation — keep the single-file benefit for free.** An mdBook's chapter sources
*are* plain markdown and render fine in cmux's `markdown open` panel. So in-product help
(`ctide help <topic>` → opens the relevant `src/*.md` in a cmux markdown surface via
`MuxViewers`) gets single-file ergonomics from the same tree, while the published site gets
search + nav. **The docs are the in-product help** — one source, multiple render targets
(Pages site, cmux markdown surface, `include_str!`-embedded help) — which is exactly the
machine-first / keystroke-reachable ethos (P5/P6) and the same "embed everything" posture
the binary already uses for recipes/layouts/themes (design-plan §10). We get both, not one.

---

## 2. The documentation outline (the `SUMMARY.md` tree)

Structure follows the reader's journey: get it running → use your IDE type → reference when
stuck → extend it → understand it. Each entry names the chapter, its primary source in the
approved docs, the **phase** it first ships in, and the **epic that authors it** (§4 is the
full epic→chapter map; the epic tags here are the at-a-glance version).

```
# SUMMARY.md  (the mdBook spine)

[Introduction]                      # what ctide is, the 7 pillars in 1 screen, non-goals
                                    #   src: product-vision §1, §3, §8 · authored: E1

# Getting Started
- [Install]                         # brew tap, single binary, completions+man, doctor first
                                    #   src: design-plan §10 · R1/E1
- [Quickstart]                      # `ctide space new --type base` in a git repo → flow
                                    #   src: product-vision §3 day-in-the-life · R3/E4
- [First 10 minutes]                # the review-queue loop, fix-on-red, the focus chord
                                    #   src: pillars P2/P4/P6 · R2/E2 (loop) → R4/E6 (review)

# User Guides (the three IDE types)
- [The Base IDE]                    # spaces, review queue, attention, fix-on-red, journeys
                                    #   src: product-vision §3 · R3/E4 (spaces) + R4/E6 (review)
- [The dbt IDE]                     # persona loop, compile-on-save, harlequin, cute-dbt review
                                    #   src: product-vision §5 + design-plan §9 R5 · R5/E7
- [The Rust IDE]                    # bacon fast-path, nextest test-tree, quality cockpit, gates
                                    #   src: product-vision §6 · stub R2/E2 → full post-v1/E10

# Configuration
- [ctide.toml & the layering model] # the 5-layer precedence, ResolvedConfig, provenance
                                    #   src: design-plan §5 · R1/E1 (loader) + R4/E5 (sync)
- [Never writes ~/.config]          # the consent model, `ctide setup`, the one global-write path
                                    #   src: design-plan §5 + product-vision §8 · R4/E5
- [Recipes (verticals as data)]     # base/dbt/rust-dev TOML, `extends`, the swap table
                                    #   src: design-plan §2 IdeType + §5 example files · R5/E7
- [Generated cmux files]            # `ctide sync` → .cmux/*.json, the generated-by marker
                                    #   src: design-plan §5 ownership split · R4/E5
- [Config reference]                # every key, every default, which layer, egress label
                                    #   GENERATED from the config type (§3) · R1→R5 incremental

# Extending ctide (adapter authoring)
- [Ports & adapters overview]       # role-shaped ports, narrowed handles, sync/object-safe
                                    #   src: design-plan §3 · R1/E1
- [Writing an adapter]              # implement the trait, declare an EgressLabel, pass the kit
                                    #   src: design-plan §3 conformance kit · R1/E1 → R2/E2
- [Swapping a tool]                 # the 3 concrete swaps (gitui, warehouse, watchexec/bacon)
                                    #   src: design-plan §3 "Three concrete swaps" · R2/E2 + R5/E7
- [The conformance kit]             # ctide-testkit, generated fixtures, "pass the suite" on-ramp
                                    #   src: design-plan §3 + §8 · R3/E4 (publish gate, §12 Q6)

# Power-User Setup
- [The default tool stack]          # the §7 table: every tool, role, why, swap alternatives
                                    #   src: product-vision §7 · cross-epic
- [Keymaps & the workspace which-key]  # tmux-style chords, palette taxonomy, one `ctide setup`
                                    #   src: product-vision P6 + backlog #14 · R4/E5
- [Theming]                         # one-stroke theme, cmux/Ghostty + browser surfaces, no ~/.config
                                    #   src: product-vision P6 + ThemeTarget port · R1/E1
- [Latency & flow SLOs]             # the budgets, why they're release blockers, what to expect
                                    #   src: design-plan §8.7 + product-vision P6 · R2/E2 onward

# Agents & ctide (machine-first surface)
- [The --json contract]             # ctide-json (g4), schema versioning, deprecation, pinning
                                    #   src: design-plan §2 ctide-json + §12 Q5 · R1/E1
- [The repo-local agent skill]      # what ships, how an agent drives ctide, examples
                                    #   src: product-vision P5 · R4/E6

# Architecture (overview + deep-link out)
- [Architecture overview]           # daemonless, multiplexer-is-supervisor, the hexagon
                                    #   src: design-plan §1, §2 (summarized) · stub R1/E1
- [Trust & zero-egress]             # egress labels, doctor's two-layer network surface
                                    #   src: design-plan §3 trust labels + product-vision §2 · R1/E1

# Operations
- [ctide doctor]                    # health/trust/provenance/drift command, read it first
                                    #   src: design-plan §3, §5 (provenance g5), §10 · R1/E1
- [Troubleshooting]                 # symptom → doctor output → fix; cmux drift, capability probe
                                    #   src: design-plan §11 risk register (user slice) · cross-epic
- [Migrating from the shell dogfood]  # `ctide state migrate`, per-family, CTIDE_SHELL rollback
                                    #   src: design-plan §9 migration · R1/E1 → R5/E7

# Reference
- [CLI reference]                   # every verb, every flag — GENERATED from clap (§3)
                                    #   GENERATED · R1→R5 incremental
- [Changelog]                       # release-plz-generated; links each version to its chapters
                                    #   src: release-plz (crap4rs template) · ongoing
```

### Outline rationale (mapping the owner's eight required pieces)

The owner named eight required pieces; here is where each lives, and which epic owns it:

1. **install / quickstart** → *Getting Started* (Install + Quickstart + First 10 minutes).
   Install lands in **E1**; Quickstart graduates to true end-to-end when `space new` works
   at **E4**; First-10-minutes is the runner loop (**E2**) growing the review loop (**E6**).
2. **three IDE types as user guides** → *User Guides* (Base / dbt / Rust), each a
   task-shaped walkthrough, not a feature dump — anchored on the §3/§5/§6 day-in-the-life
   narratives. Base is **E4**+**E6**; dbt is **E7**; Rust is a stub from **E2** that
   graduates to a full guide when **E10** ships rust-dev at the Rule-of-Two trigger.
3. **config reference (ctide.toml + layering + never-write-~/.config)** →
   *Configuration*, split into a conceptual page (layering model, **E1** loader), a
   constraint page (never-write, **E5** `ctide setup`), and a **generated** exhaustive key
   reference (§3). The split mirrors crap4rs exactly: conceptual prose in README + a
   generated `crap.example.toml` kept honest by a sync test
   (`/Users/cmbays/github/crap4rs/crap.example.toml`). We copy that pattern for
   `ctide.toml`.
4. **adapter-authoring guide (trait ports + how to swap a tool)** → *Extending ctide*,
   built directly on design-plan §3 (**E1** ports + writing-an-adapter; **E2**/**E7** add
   the concrete swaps). "Swapping a tool" lifts the three concrete swaps verbatim; "Writing
   an adapter" is the colleague on-ramp the design plan names ("write an adapter, pass the
   suite").
5. **power-user setup** → *Power-User Setup*, fronted by the product-vision §7 table (the
   single most reference-worthy table in the corpus — every tool, role, defensibility,
   swap). Keymaps (**E5**), Theming (**E1**), SLOs (**E2**) are its sub-pages.
6. **architecture overview (links design-plan)** → *Architecture*, deliberately a
   *summary* that deep-links into the full `design-plan.md` rather than duplicating it. The
   design plan stays the canonical engineering doc; the book chapter is the 2-screen
   orientation a contributor reads before opening it (avoids the divergence trap the
   vision/design docs guard against by cross-reference discipline). Stubbed at **E1** (the
   hexagon lands there).
7. **troubleshooting / doctor** → *Operations* (ctide doctor + Troubleshooting +
   Migration). `doctor` gets its own page because it is the product's self-describing trust
   surface — the first thing every reader runs and the answer to most "why is it doing
   that?" questions (g5 provenance is literally built for this page). All seeded at **E1**;
   Troubleshooting accretes per incident cross-epic.
8. *(implicit but required)* **agent-facing docs** → *Agents & ctide*. P5 ("agents are
   users of the IDE too") makes the `--json` contract a first-class public API that needs a
   stable, deep-linkable reference page — something a single `rustbook.md` structurally
   cannot give. The contract page lands **E1** (the frozen schema gets its versioning page
   on day one); the agent-skill page lands **E6**.

---

## 3. How docs build deterministically + publish zero-egress-friendly

### Build determinism (three layers, strongest first)

1. **Pinned toolchain.** `MDBOOK_VERSION` pinned in the workflow env (the official
   starter-workflow pattern), plus any preprocessor versions pinned the same way. `mdbook
   build` with a fixed binary is a pure function of `src/`. crap4rs already pins its whole
   toolchain (`rust-toolchain.toml`, `cargo-dist`, `release-plz`); the docs job inherits
   that discipline, and **E0** stands up the rust-toolchain pin the roadmap requires (§3 R0).
2. **Generated content is generated in CI, committed-and-diffed, never hand-typed.** Two
   chapters are *generated*, not authored — the same mechanism the walking skeleton uses to
   keep the `--json` contract honest (g4):
   - **CLI reference** — from `clap`. The binary already ships clap-generated completions +
     man pages (design-plan §10). Add a `ctide gen-docs` (or `clap-markdown`) step emitting
     the full verb/flag reference as markdown into `src/reference/cli.md`. A CI sync-test
     fails if the committed file drifts from regenerated output — exactly how crap4rs keeps
     `crap.example.toml` from rotting ("generated from the config type, a sync test keeps it
     from rotting", crap4rs README §Config file).
   - **Config reference** — from the `ResolvedConfig`/recipe serde types. Same mechanism:
     emit an annotated `ctide.example.toml` + a key table into `src/config/reference.md`,
     sync-tested. This *is* the crap4rs `crap.example.toml` pattern applied to `ctide.toml`,
     and it carries the per-key **egress label** + **layer provenance** (g5) so the
     reference can never silently lie about the binary's real surface.
3. **Link + content checks as offline gates.** `mdbook test` (validates fenced Rust code
   examples compile — the architecture/adapter chapters carry real trait snippets from
   design-plan §3) and `mdbook-linkcheck` (broken internal/anchor links fail CI). Both run
   offline. This keeps the heavy cross-referencing (every chapter cites a vision/design
   section) honest — the cross-reference-integrity discipline the vision/design docs enforce
   by hand, made mechanical.
   ([mdBook CI](https://rust-lang.github.io/mdBook/continuous-integration.html))

### Publish, zero-egress-friendly

The product's hard constraint is *runtime* zero-egress (the binary phones nobody). Docs
*publishing* is a CI concern, and the constitution's allowed-egress rule is "GitHub via `gh`
OK; no SaaS/telemetry." **GitHub Pages via GitHub Actions is squarely inside that
allowance** (it is GitHub, not third-party SaaS) and is the same forge the org already lives
on. So:

**Recommended: GitHub Pages via the official artifact-based deploy.** Follow the official
mdBook starter workflow shape
([actions/starter-workflows pages/mdbook.yml](https://github.com/actions/starter-workflows/blob/main/pages/mdbook.yml)):

- `permissions: { contents: read, pages: write, id-token: write }` — least privilege;
- `concurrency: { group: "pages", cancel-in-progress: false }` — never abort an in-flight
  publish;
- steps: `actions/configure-pages@v5` → install pinned mdBook → `mdbook build` →
  `actions/upload-pages-artifact@v3` → `actions/deploy-pages@v5`;
- trigger on push to the default branch (docs ship when the feature ships) +
  `workflow_dispatch`. **Held un-triggered until the R0 rename + first publish at the
  end-R2 checkpoint** (§0, §4).

This is the **artifact-based** path (`deploy-pages`), not the legacy `gh-pages` branch.
Prefer it: it needs no `contents: write`, leaves no generated-HTML commits polluting git
history, and is the path GitHub itself documents. (Note: crap4rs *does* use a `gh-pages`
branch — but for a *different* job, ephemeral per-PR HTML scorecard reports
(`/Users/cmbays/github/crap4rs/.github/workflows/pages-cleanup.yml`), which need a writable
branch to add/remove `pr-<N>/` dirs. A stable docs site has no such need; use the cleaner
artifact path. The two could coexist later if ctide ever wants per-PR doc previews, reusing
crap4rs's `concurrency: gh-pages-publish` lock pattern.)

**Zero-egress integrity of the *published* site itself.** mdBook's default theme bundles its
own CSS/JS/fonts and the search index runs client-side — the published pages load no
third-party CDN by default. **Constraint for authors:** do not add preprocessors or themes
that inject remote assets. `mdbook-mermaid` ships its mermaid JS *locally* (safe;
`mdbook-mermaid install` vendors the assets); any "load from CDN" theme variant is banned. A
one-line CI grep (`no https://cdn`, `no googleapis`, …) audits this — cheap insurance, same
spirit as the design-plan's `~/.config`-path grep gate (§8.8) and the roadmap's egress gates
(§7 cross-cutting). The docs site is itself a zero-third-party-egress artifact — on-message
for a zero-egress product.

**The fully-air-gapped reader.** Because `mdbook build` produces a self-contained static
`book/` dir, the docs ship *with the binary's repo* and render offline — `mdbook serve` or
just opening `book/index.html`. An air-gapped user clones the repo and reads the docs with
no network at all; the same `src/*.md` open in cmux's `markdown open` surface for in-product
help (§1 hybrid). The published Pages site is a convenience, never the only access path —
the right posture for an air-gappable product.

---

## 4. Docs-as-you-go: each build epic ships its doc slice

**Principle (roadmap sequencing principle 3): a verb is not "done" until its chapter exists,
its golden-master diff is clean, and `mdbook-linkcheck` passes — all in the same PR.** No
big-bang doc sprint at the end; that is how docs rot before they ship. The migration plan
(design-plan §9, R1–R5) already chunks the build into shippable slices; each slice carries
its doc slice in the *same epic PR*. This is enforceable as a quality gate: the roadmap
already makes egress labels, golden-master parity, and latency budgets release blockers —
add "the chapter for any new user-facing verb exists and linkcheck passes" to the same gate.
crap4rs precedent: its docs (`docs/scorecard-row-contract.md`) landed *with* the feature
that needed them, not after.

### Epic → doc-slice map (the program contract)

| Epic (roadmap §4) | Phase | Ships (verbs/surfaces) | Doc slice authored in the same epic |
|---|---|---|---|
| **E0** — scaffold + repo rename | R0 | the 8-crate skeleton, crap4rs CI template, deny/lefthook/release-plz, **mdBook skeleton itself** | **The docs walking skeleton** (below): `book.toml`, fully-stubbed `SUMMARY.md`, the two generators wired (thin first emission), the `docs.yml` Pages workflow created **but held un-triggered** (roadmap §3 R0 exit). No prose chapters yet — E0 stands up *structure*, exactly as it does for code. |
| **E1** — foundations / doctor (walking skeleton) | R1 | binary skeleton, socket adapter + quirk vault, `ctide-json` (g4), `ctide doctor`, `ctide state migrate`, `ctide theme`, parser killers, fixture generator | **R1 is doc-heavy by design** — it ships the trust + config + contract spine every later chapter references: *Introduction*; *Install*; *ctide doctor*; *Trust & zero-egress*; *The --json contract* (frozen schema → versioning page day one); *Architecture overview* (stub — the hexagon lands here); *ctide.toml & layering* (loader exists); *Theming*; *Config reference* (generator wired, even if thin); *Ports & adapters overview* + *Writing an adapter* (the ports land here); *Migrating from the shell dogfood* (the `state migrate` runbook). |
| **E2** — runner + status bus + agents-cluster writes | R2 | `ctide run`/`run wrap`, `set-role`, `jump`, `open`, `md-open`, `agent new\|rename` | *First 10 minutes* (the runner is the first interactive loop); *Latency & flow SLOs* (budgets become real, release-blocking); *Writing an adapter* gains its worked example (RunnerEngine); *Swapping a tool* gains the watchexec↔bacon swap; *The Rust IDE* stub (bacon fast-path). **The end-R2 re-approval checkpoint (E3) is the natural first-publish milestone — the site goes live here, after the rename.** |
| **E3** — end-of-R2 re-approval gate | R2→R3 | *(decision point, not shippable work)* | No new chapters — but **publish trigger flips on here** (§3): the held `docs.yml` goes live, so the book is public from the moment the architecture bet is re-approved. |
| **E4** — spaces + resume + place + native containers | R3 | `space new/open/close/rm/ls`, `ctide place` | *Quickstart* graduates to true end-to-end (`space new` actually works); *The Base IDE* (spaces are the unit of work — the flagship user guide); *The conformance kit* (publish gate — design-plan §12 Q6 places kit publication around R3); the monitor-placement section of *Power-User Setup*. |
| **E5** — Rust-only infra: sync/policy/setup/keymap/replace/focus | R4 | `ctide sync`, `ctide policy`, `ctide setup`, keymap layer, `ctide replace`, `ctide focus` | *Generated cmux files* (`ctide sync`); *Never writes ~/.config* + *Keymaps & the which-key* (both gated on `ctide setup`, which lands here — the sole consented global-write path). |
| **E6** — review-and-loop flagship | R4 | `ctide review` queue, fix-on-red, triage cockpit / fleet log, spaces dashboard | the *review queue* deep-dive inside *The Base IDE*; the fix-on-red half of *First 10 minutes*; *The repo-local agent skill*. (The kill-condition metric — ≥80% turns reviewed within 2 weeks of R4 — is measured against the loop this epic + its docs describe.) |
| **E7** — dbt recipe slice | R0 demo → R5 | R0 shell demo (the one allowed shell feature); R5 rebuild behind `DbtReview` + `recipes/dbt.toml` + Warehouse port | *The dbt IDE* (the full vertical guide); *Recipes (verticals as data)*; *Swapping a tool* gains the warehouse swap as its example. The **R0 shell demo** carries a short "dbt review loop (preview)" note now; it is rewritten into the full guide at R5. |
| **E8 / E9 / E10** — post-v1 verticals | post-v1 | dbt intelligence ladder; harlequin bridge; **rust quality cockpit (Rule-of-Two)** | *The dbt IDE* deepens (E8 LSP/intelligence, E9 execution/CTE preview); ***The Rust IDE* graduates from stub to full guide when E10 ships rust-dev** at the Rule-of-Two trigger. |
| **Cross-epic / ongoing** | every release | every release | *CLI reference* + *Config reference* regenerate every build (CI sync-test); *Troubleshooting* accretes per incident; *Changelog* from release-plz; the *Power-User stack table* updates whenever a default tool changes. |

### The docs walking skeleton (mirrors the code walking skeleton)

**E0 stands up the docs skeleton the same way it stands up the empty 8-crate code skeleton**
— structure first, content later. Concretely, E0 ships: `book.toml`; a `SUMMARY.md` with
**every chapter stubbed** (one-line "coming in Rx" placeholders, so the TOC is whole from
the start); the two generators (CLI + config) wired even if their first emission is thin;
and the `docs.yml` Pages workflow **created but held un-triggered** (per §0/§3 — it goes
live at E3, the end-R2 checkpoint, after the rename). This is the documentation analog of
the roadmap's walking-skeleton discipline (§5): just as `ctide doctor` proves every *code*
layer end-to-end at zero blast radius, the stubbed-but-complete `SUMMARY.md` proves every
*doc* layer (toc → generators → linkcheck → held publish) before any prose lands. Every
later epic then *fills in a stub* rather than *creating structure* — and the docs-as-you-go
gate becomes trivial to check: "did this epic turn its stub into prose?"

---

## 5. Where the docs live in the repo

```
<repo-root>/                         # cmux-terminal-ide (post-R0 rename in place — §0)
├── docs/
│   ├── vision/                      # EXISTING — the approval-gate corpus (frozen reference)
│   │   ├── product-vision.md        #   what & why (consumed by the book, not duplicated)
│   │   ├── design-plan.md           #   how (the canonical engineering doc the book links to)
│   │   └── research/                #   18-file evidence corpus
│   ├── roadmap/                     # EXISTING — planning artifacts
│   │   ├── roadmap.md               #   the master roadmap (the index)
│   │   ├── product-docs-plan.md     #   THIS FILE (promoted)
│   │   └── research/                #   the five recon notes
│   └── book/                        # NEW — the published product docs (mdBook) · stood up at E0
│       ├── book.toml                #   title, authors, site-url (pinned to final repo slug — §0),
│       │                            #     [output.html] (default theme, search on), preprocessors
│       ├── src/
│       │   ├── SUMMARY.md           #   the TOC spine (§2) — fully stubbed at E0
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
                                     #   created (held) at E0; trigger flips on at E3
```

**Why `docs/book/` and not repo-root `/book/` or a separate repo:**

- **Co-located with the code it documents** → the docs-as-you-go gate (§4) can require a docs
  diff in the same PR as a feature diff; a separate docs repo breaks the 1:1 PR mapping the
  org constitution mandates, and the rename-in-place ruling (§0) exists precisely to keep one
  tree.
- **Under the existing `docs/` umbrella** alongside `vision/` and `roadmap/`, so the whole
  knowledge surface is one tree: `vision/` = the frozen "why", `roadmap/` = planning,
  `book/` = the living product docs. Clean audience separation (internal reference vs. public
  docs) without repo sprawl.
- **`docs/book/src/*.md` are reusable as in-product help** (§1 hybrid) precisely because
  they live in the repo the binary is built from — `ctide help <topic>` resolves a path
  under `docs/book/src/` and opens it in a cmux markdown surface, or the relevant subset is
  `include_str!`'d into the binary the way recipes/layouts/themes already are (design-plan
  §10). Same source, three render targets: Pages site, cmux markdown surface, embedded help.

**The README's role after the book exists.** The repo README stays a launchpad (what ctide
is in 3 sentences, the install one-liner, a badge row, "Full docs: <Pages URL>"). The
crap4rs README is the *counter*-example — it grew to 582 lines because it had no book to
offload into. The current ctide repo README is 168 lines today; with the book as the home,
it should *stay* small and point at the book, never re-grow.

---

## 6. Summary of recommendations

1. **mdBook tree, not single `rustbook.md`** — better reader UX (search, nav, per-audience
   entry, agent-contract page) and maintainer UX (disjoint files = no merge wars across
   parallel epic PRs); the zero-egress, deterministic, Rust-native toolchain. Keep the
   single-file benefit via the hybrid: `src/*.md` double as in-product help.
2. **Outline = 9 sections** (Getting Started, User Guides ×3, Configuration, Extending,
   Power-User, Agents, Architecture, Operations, Reference) covering all eight required
   pieces plus the agent-facing `--json` contract P5 elevates to a public API.
3. **Determinism = pin mdBook version + generate CLI & config reference from clap/serde
   types with sync-tests** (the crap4rs `crap.example.toml` pattern, carrying egress labels
   + layer provenance) + `mdbook test` + `mdbook-linkcheck` as offline gates.
4. **Publish = GitHub Pages via official artifact-based `deploy-pages@v5`** (inside the
   "GitHub-OK" egress allowance), default bundled theme (no CDN), a one-line no-remote-asset
   grep gate; the site ships with the repo so it also reads fully offline.
5. **Docs-as-you-go, epic-tied = each E1–E7 epic authors its chapter in the same PR**,
   enforced as a release gate; **E0 stands up the docs walking skeleton** (`book.toml` +
   stubbed `SUMMARY.md` + generators + held workflow); **E3 (the end-R2 checkpoint) flips on
   the publish trigger** so the site goes live the moment the architecture bet is
   re-approved.
6. **Location = `docs/book/`**, co-located under the existing `docs/` umbrella; README stays
   a launchpad pointing at the book.

### Open couplings to flag for the roadmap

- **Repo-rename ordering (resolved upstream, sequencing only).** The roadmap ruled
  rename-in-place at R0 (§0). The docs publish workflow's `site-url` must match the final
  repo slug, so **trigger the Pages deploy at E3 (after the R0 rename + the end-R2
  checkpoint), not before.** Authoring book content can start at E1; only the publish pin
  waits. This is the doc analog of the roadmap's "first publish at the end-R2 checkpoint,
  after the rename" cross-cutting rule (§7).
- **License on the docs-site footer.** The GPL-v3-vs-MIT ruling (design-plan §12 Q8,
  product-vision §9 #25) should be settled before the public Pages site goes live at E3, so
  the footer license is correct from publish-one. Track it alongside the brew-tap-goes-public
  decision.

---

## Sources

- **Master roadmap:** [`docs/roadmap/roadmap.md`](./roadmap.md) — §1 (north star, how to
  read), §2 (sequencing principles 3 docs-as-you-go, 4 dogfood-value, 8 constraints), §3 R0
  (the rename-in-place ruling + mdBook/Pages-held exit), §4 (the E0–E10 epic list this doc
  ties chapters to), §5 (the walking-skeleton discipline the docs skeleton mirrors), §7
  (build order + the "each epic ships its mdBook chapter in the same PR; first publish at the
  end-R2 checkpoint, after the rename" cross-cutting rule), §8 (this doc's slot among the
  five detail docs).
- **Product vision:** [`docs/vision/product-vision.md`](../vision/product-vision.md) — §1
  (pillars), §3 (base IDE + day-in-the-life + capability map), §5 (dbt IDE), §6 (rust IDE),
  §7 (power-user tool table), §8 (non-goals incl. never-write-`~/.config`), §9 (open
  questions #25 license, #26 distribution trigger).
- **Design plan:** [`docs/vision/design-plan.md`](../vision/design-plan.md) — §1
  (architecture overview), §2 (crate layout, IdeType, ctide-json g4), §3 (ports & adapters,
  three swaps, conformance kit, trust labels), §5 (config layering, never-write-`~/.config`,
  provenance g5), §8 (testing gates incl. §8.7 SLOs, §8.8 grep gate), §9 (migration R1–R5),
  §10 (distribution / `include_str!` embedding / completions+man), §11 (risk register), §12
  (open questions Q6 kit publication, Q8 license).
- **Sibling roadmap detail docs (all written, cross-referenced):**
  [`rebrand-ctide.md`](./rebrand-ctide.md) (the naming map the docs pin against),
  [`ci-quality-framework.md`](./ci-quality-framework.md) (the CI job graph the `docs.yml`
  job joins), [`r1-walking-skeleton.md`](./r1-walking-skeleton.md) (the code skeleton the
  docs skeleton mirrors).
- **Self-documentation template:** `/Users/cmbays/github/crap4rs/README.md` (the generated
  `crap.example.toml` + sync-test pattern, §Config file — 582 lines, the
  no-book-to-offload-into counter-example), `/Users/cmbays/github/crap4rs/crap.example.toml`,
  `/Users/cmbays/github/crap4rs/docs/scorecard-row-contract.md` (per-topic doc split),
  `/Users/cmbays/github/crap4rs/.github/workflows/pages-cleanup.yml` (the `gh-pages` branch
  used only for ephemeral per-PR HTML reports + the `gh-pages-publish` concurrency-lock
  pattern).
- **Repo README:** `/Users/cmbays/github/cmux-workspace-dbt/README.md` (168 lines today —
  the launchpad that must stay small).
- **mdBook:** [Continuous integration](https://rust-lang.github.io/mdBook/continuous-integration.html)
  (`mdbook test`, linkcheck), [Installation](https://rust-lang.github.io/mdBook/guide/installation.html)
  (single self-contained Rust binary, offline build),
  [official Pages starter workflow](https://github.com/actions/starter-workflows/blob/main/pages/mdbook.yml)
  (pinned `MDBOOK_VERSION`, `configure-pages@v5` → `upload-pages-artifact@v3` →
  `deploy-pages@v5`, least-privilege permissions, `concurrency: pages`),
  [peaceiris/actions-mdbook](https://github.com/peaceiris/actions-mdbook),
  [mdbook-mermaid (vendors assets locally)](https://crates.io/crates/mdbook-mermaid),
  [mdbook-admonish](https://crates.io/crates/mdbook-admonish).
