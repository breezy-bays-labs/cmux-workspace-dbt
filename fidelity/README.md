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
diff -ru fidelity/snapshots/0.64.10 fidelity/snapshots/0.65.0
```

If the diff touches a command/flag `cwd` uses, that's a fix to schedule (and, later, a
golden-fixture regeneration). If it doesn't, bump the supported-version pin with confidence.

This is a **spike** toward a more robust cmux-compatibility / version-pinning tool.
