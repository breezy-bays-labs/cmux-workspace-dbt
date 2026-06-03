# cmux fidelity snapshots

`cwd` drives **cmux** through its CLI. cmux ships frequently and its API is still
stabilizing, so an upgrade can quietly change a surface `cwd` depends on (command
names, flags, output shapes). This directory makes that risk **visible and reviewable**.

## What this captures (and doesn't)

`cmux-snapshot.sh` captures the **static CLI surface**, versioned by cmux version:

- `version.txt` — full `cmux version` string (the pin)
- `capabilities.txt` — `cmux capabilities`
- `help.txt` — top-level `cmux --help` (the command list)
- `subcommand-help.txt` — `--help` for each command `cwd` drives (flag-signature drift)

It is **static only** — no workspace is spawned, nothing is mutated, safe to run anytime.
It does **not** capture the *dynamic* surface (live `tree` output, surface-title formats);
that's the job of the eventual Rust tool's golden WorkspaceHost fixtures, generated from a
real controlled workspace. This is the cheap precursor.

## Workflow on a cmux upgrade

```sh
# 1. BEFORE upgrading — snapshot the known-good version (e.g. 0.64.10)
sh fidelity/cmux-snapshot.sh

# 2. Upgrade cmux, then snapshot the new version
sh fidelity/cmux-snapshot.sh

# 3. Diff — does anything cwd depends on change?
diff -ru fidelity/snapshots/0.64.10 fidelity/snapshots/0.64.12
```

If the diff touches a command/flag `cwd` uses, that's a fix to schedule (and, later, a
golden-fixture regeneration). If it doesn't, bump the supported-version pin with confidence.

## Supported versions (verified)

| cmux | static surface `cwd` drives | G1 dynamic surface (editor title) | notes |
|---|---|---|---|
| **0.64.10** | baseline | baseline | original capture |
| **0.64.12** | identical to 0.64.10 | live-verified intact (`"<cwd>> hx-wrap"`, matcher resolves) | safe upgrade |

`0.64.10 → 0.64.12` changed **nothing** in the surface `cwd` drives (every `subcommand-help` is
byte-identical). The additions are purely additive and are **`/shape` inputs** for the Rust hexagonal
manager, not `cwd` fixes:

- **`cmux diff`** (new top-level command) — opens a git diff in a **browser split**
  (`--source unstaged|staged|branch|last-turn`, `--layout split|unified`). A natural **second adapter**
  for the `diff` capability alongside the terminal `hunk` adapter.
- **`workspace.group.*`** (17 new RPC methods) — workspace grouping; relevant to multi-workspace
  organization and possibly the workspace-type model.
- (also additive, unused by `cwd`: `agent-hibernation`, `simulate-sidebar-drag`.)

> The editor-title check is **dynamic** — the static snapshot structurally cannot cover it, so it must
> be confirmed by a live probe on each upgrade (and, in the Rust tool, by the generated golden-fixture
> tier). 0.64.12 was confirmed this way.

This is a **spike** toward a more robust cmux-compatibility / version-pinning tool.
