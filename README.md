# cmux-terminal-ide (`ctide`)

[![ci](https://github.com/breezy-bays-labs/cmux-terminal-ide/actions/workflows/ci.yml/badge.svg)](https://github.com/breezy-bays-labs/cmux-terminal-ide/actions/workflows/ci.yml)

**ctide** is a lightweight, agent-native terminal IDE composed on
[cmux](https://github.com/manaflow-ai/cmux) — spaces, roles, review queues, and
vertical recipes (base · dbt · rust-dev) over the only multiplexer with native
AI-agent primitives. The product vision and architecture live in
[`docs/vision/`](docs/vision/); the build plan and progress in
[`docs/roadmap/`](docs/roadmap/) (running log: [`build-log.md`](docs/roadmap/build-log.md)).

> **Status.** The Rust `ctide` workspace is live (`crates/ctide-*`; `ctide doctor`
> works against cmux) and is being built out per the
> [roadmap](docs/roadmap/roadmap.md), strangling the Phase-0 POSIX-sh dogfood
> documented below. MIT licensed (see [LICENSE](LICENSE)).

---

## Phase-0 dogfood — `cwd` (dbt workspace tooling)

An opinionated **cmux** workspace for dbt development on macOS: select a model and
your whole workspace — editor, file tree, diff viewer, and (when the data axis
enables it) a read-only SQL preview — follows it. This is the orchestration glue,
*not* the report (that's the companion
[cute-dbt](https://github.com/breezy-bays-labs/cute-dbt)) and *not* the warehouse
client (harlequin, off the shelf).

> **Status: Phase 0** — hardened POSIX scripts, battle-tested, now being strangled
> into the Rust `ctide` (see the [roadmap](docs/roadmap/roadmap.md)).

## What it does — quick reference

| command | what it does |
|---|---|
| `cwd focus [--hq] <model>` | **The spine.** Point the whole workspace at one model: open/focus it in helix, reveal it in the yazi tree, drive the hunk diff if it's changed, and (when the data axis enables warehouse access) load a read-only harlequin preview. |
| `cwd route <path>` | Open a file/dir in the right place: `.sql`→helix (+sibling yml), `.csv`→csvlens, dir→buffer all files, else→helix tab. Also what yazi's file-open invokes. |
| `cwd doctor` | Print the three resolved axes (machine profile · dbt project · data/policy), per-workspace state, and tool availability. Read-only — run it first to sanity-check. |
| `cwd new <worktree\|branch>` | **Birth a dbt workspace.** `git worktree add` the target (if needed), then `cmux new-workspace --cwd <wt>` with a static dbt layout (yazi tree · helix · dbt-shell + a `cwd register dbt` surface that writes the UUID marker), and report the new workspace ref. |
| `cwd register dbt` | Runs **inside** a new workspace (`$CMUX_WORKSPACE_ID` = the UUID): parses `cmux tree` for the editor/tools panes and writes the UUID-keyed `ws_type=dbt` marker. The layout invokes it; you rarely run it by hand. |
| `cwd resume` | *(Phase 1, not yet)* re-attach to an existing workspace. |

`focus` and `route` are the same fan-out from two entry points: a **model** drives
every tool; a **file** routes to its editor/viewer.

**Workspace types.** A workspace is `dbt` only when `cwd register dbt` wrote its marker
(i.e. the launcher created it); every other workspace is `general` — there is **no
heuristic**, absence of the marker *is* `general`. The type-gated behaviors read
`ws_type` and leave `general` workspaces untouched:

- **yazi config** (`yazi-wrap`): a `dbt` workspace uses `config/yazi/dbt`; any other uses
  the machine profile's variant (the "untouched" path).
- **opener** (`cwd-route`): in a `dbt` workspace, `.sql` → helix **model-open**, `.csv` →
  csvlens, and any other file → the user's `open-helix.sh`; a `general` workspace defers
  **everything** to `open-helix.sh` (the "open every model" routing is a dbt-only extra).

The user's `open-helix.sh` is the dotfiles opener ([`cmbays/dotfiles`](https://github.com/cmbays/dotfiles), slice S8); the `dbt` yazi config reuses the user's `keymap.toml`/`theme.toml` (symlinks wired by the stow installer).

## Configuration — three independent axes

Config is **three orthogonal axes**, not one "workstation" enum. Any combination is
valid; none is baked into the others.

| axis | values | owns | set by |
|---|---|---|---|
| **1 · machine profile** | `bare` · `stow` | config regime only — shell, prompt, which `config/yazi/<variant>` dir, bundled-config vs. dotfiles | `install.sh <profile>` + `DBT_WS_PROFILE` |
| **2 · dbt project** | per workspace | the `dbt_dir` (repo + dbt project); **auto-derives the warehouse** from `dbt_project.yml`'s `profile:` + the active `profiles.yml` target | the launcher / per-workspace state |
| **3 · data / policy** | warehouse · harlequin · profiles dir | whether the interactive warehouse-query surface is active here | env → state → warehouse auto-derive |

- **`bare`** is the clean distributable: bundled config, no dotfiles dependency, and
  the `hq-preview` warehouse-query command is **structurally absent** (`install.sh`
  never links it). **`stow`** complements an existing `~/.config` GNU-Stow dotfiles
  setup (read-only — never clobbered).
- The **data axis is independent of the machine profile**: a `bare` machine can run
  `harlequin=on` and a `stow` machine `harlequin=off`. The runtime gate `hq_enabled`
  keys on the data axis (`harlequin=on` **and** `warehouse=duckdb`); the `bare`
  install's omission of `hq-preview` is the *structural* belt to that *runtime* brace
  — defense-in-depth, two independent layers.
- `base.env` holds the safe `bare` defaults (warehouse `none`, harlequin `off`); each
  profile overrides only its config-regime fields. `SQL_QUERY_MODE` is **derived**
  from the gate, never set by hand.
- **Warehouse auto-derive** (axis 2 → 3): when `WAREHOUSE` isn't set explicitly, `cwd`
  reads the workspace's `dbt_project.yml` `profile:` and the active target's `type:`
  in `$DBT_PROFILES_DIR/profiles.yml` (default `~/.dbt`) — `duckdb` (with its `path:`)
  / `snowflake` / else `none`. The `profiles.yml` is **read only, never written**, and
  any missing file/target degrades to `warehouse=none` without erroring. `profiles.yml`
  stays yours — `cwd` only references it via `DBT_PROFILES_DIR`.

Run `cwd doctor` to see all three axes resolved for the current workspace.

## Requirements

**macOS only** — the tool orchestrates cmux, a native macOS terminal multiplexer.

**Core (both profiles)**

| tool | role | install |
|---|---|---|
| **cmux** | the terminal multiplexer it drives | (macOS app — its own installer) |
| **helix** (`hx`) | editor (+ dbt LSP) | `brew install helix` |
| **yazi** (`ya`) | file tree / model browser | `brew install yazi` |
| **dbt-fusion** | `dbtf` + the SQL language server | (fusion installer) |
| **fd · fzf · bat · git** | search / pick / preview / VCS | `brew install fd fzf bat git` |
| **csvlens** | seed/CSV viewer | `brew install csvlens` |
| **hunk** | review-first diff viewer | (its own installer) |
| **watchexec** | git-glance refresh | `brew install watchexec` |

**When the data axis uses DuckDB + harlequin also:** `duckdb`, `harlequin` —
`brew install duckdb` / `uv tool install harlequin`.

**Companion (optional):** [cute-dbt](https://github.com/breezy-bays-labs/cute-dbt)
(`cute-dbt`) — the model / CTE / unit-test report, rendered in a browser surface.

> The installer guarantees a real `dbtf` executable on `PATH` (helix spawns its LSP
> via `execvp`, not a shell alias), so fusion is invoked explicitly and never shadows
> a teammate's venv `dbt-core`.

## Setup

```sh
git clone https://github.com/breezy-bays-labs/cmux-terminal-ide ~/github/cmux-terminal-ide
cd ~/github/cmux-terminal-ide
./install.sh --profile bare   # clean distributable (default); or: --profile stow
```

`install.sh` symlinks the `cwd*` commands into `~/.local/bin` (ensure it's on
`PATH`). **`bare` is the default profile**; set `DBT_WS_PROFILE=stow` on a machine
with GNU-Stow dotfiles. (A bare positional — `./install.sh stow` — still works.) The
warehouse / harlequin **data axis is configured separately** (per workspace, via env
or state), independent of this profile.

It also builds the **dbt yazi overlay** (`$DBT_WS_DBT_YAZI`, default
`~/.local/share/cmux-workspace-dbt/yazi-dbt`) that a dbt workspace uses: it symlinks
the bundled `config/yazi/dbt/yazi.toml`, and on **`--profile stow`** detects `~/.config`
and **symlinks the user's `keymap.toml`/`theme.toml`** so keybinds/theme carry over.
`install` only ever **reads** `~/.config` — the symlinks live under the overlay dir, so
your Stow dotfiles are **never clobbered**. `--profile bare` uses the bundled config
only (and omits the `hq-preview` warehouse-query command — structural absence).

Per-workspace state lives in `state/<workspace>/` (gitignored) and is keyed by
`$CMUX_WORKSPACE_ID` (a UUID) automatically, so multiple worktree-workspaces coexist
without colliding. Verify the whole thing with:

```sh
cwd doctor
```

### Migrating a pre-UUID state dir (one-time runbook)

If `cwd doctor` lists an **`other state dirs`** line (e.g. a Phase-0 dir keyed by the
workspace *ref* like `workspace_12` rather than the UUID), this workspace's pane refs
live under the wrong key. Re-key them once, **from inside that workspace**:

```sh
cwd doctor                          # confirm: workspace key = <uuid>, other state dirs = workspace_12
cwd state migrate workspace_12      # shows from/to side-by-side, asks to confirm
```

`state migrate` is **single-shot and collision-refusing**: it moves pane refs only if
the live UUID dir has no conflicting key, otherwise it refuses and prints each conflict
(old vs. current) so you can resolve it by hand — the old ref-keyed value is the
authoritative one. After a clean migration the old dir is removed; a re-run is a no-op.
Add `--yes` to skip the confirmation. This is an operator action, not part of any
automated flow.

## Testing

Logic tests run a **stub cmux** (and friends) on `PATH` and assert the exact
commands the scripts *would* send — no real cmux, no live workspace touched, CI-safe:

```sh
./tests/run.sh
```

## Layout

```
profiles/   base.env · bare.env · stow.env               # AXIS 1 (machine profile = config regime)
lib/        common.sh                                     # 3-axis resolution + $CMUX_WORKSPACE_ID containment
bin/        cwd  cwd-focus  cwd-route  hx-wrap  yazi-wrap  hq-preview  git-glance(-render)
config/     helix/languages.toml · yazi/{bare,stow}/yazi.toml
tests/      run.sh · stubs/* · fixtures/*                 # stub-cmux logic tests
install.sh  README.md
state/      <workspace>/{edit_pane,tools_pane,dbt_dir,duckdb,yazi_client_id}   # gitignored
```
