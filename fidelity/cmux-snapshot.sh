#!/bin/sh
# fidelity/cmux-snapshot.sh — capture cmux's STATIC CLI surface, versioned by cmux
# version, so a cmux upgrade can be diffed against a known-good baseline: does the
# change touch the surfaces `cwd` depends on?
#
# STATIC ONLY: reads `cmux version|capabilities|--help` and per-subcommand `--help`.
# No workspace is spawned, nothing is mutated — safe to run anytime. This is the
# cheap precursor to the Rust tool's golden WorkspaceHost fixtures (which capture
# the *dynamic* surface — tree/surface-titles — from a real controlled workspace).
#
# Usage:  sh fidelity/cmux-snapshot.sh
#         diff -ru fidelity/snapshots/0.64.10 fidelity/snapshots/0.65.0   # on upgrade
set -eu

here="$(cd "$(dirname "$0")" && pwd)"
command -v cmux >/dev/null 2>&1 || { echo "snapshot: cmux not on PATH" >&2; exit 1; }

ver_full="$(cmux version 2>&1)"
ver="$(printf '%s' "$ver_full" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
[ -n "$ver" ] || { echo "snapshot: could not parse a semver from 'cmux version': $ver_full" >&2; exit 1; }

dir="$here/snapshots/$ver"
mkdir -p "$dir"

printf '%s\n' "$ver_full"                  > "$dir/version.txt"
cmux capabilities > "$dir/capabilities.txt" 2>&1 || printf '(cmux capabilities unsupported on %s)\n' "$ver" > "$dir/capabilities.txt"
cmux --help       > "$dir/help.txt"         2>&1

# Per-subcommand help for the commands cwd drives — flag-signature drift hides here.
subs="new-workspace tree new-surface list-pane-surfaces send send-key read-screen rename-tab move-surface focus-pane close-workspace"
: > "$dir/subcommand-help.txt"
for sub in $subs; do
  printf '\n===== cmux %s --help =====\n' "$sub" >> "$dir/subcommand-help.txt"
  cmux "$sub" --help >> "$dir/subcommand-help.txt" 2>&1 || printf '(no --help for %s)\n' "$sub" >> "$dir/subcommand-help.txt"
done

printf 'cmux fidelity snapshot — %s\ncaptured by fidelity/cmux-snapshot.sh (static surface only)\n' "$ver_full" > "$dir/MANIFEST.txt"
printf 'subcommands probed: %s\n' "$subs" >> "$dir/MANIFEST.txt"

echo "snapshot written: $dir"
ls -1 "$dir"
