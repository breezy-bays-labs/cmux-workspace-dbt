#!/usr/bin/env python3
"""mirror-drift lint — the shell golden-master gate stays identical in CI and lefthook.

The repo's lockstep rule (ci.yml header, lefthook header): the shell `gate` commands in
.github/workflows/ci.yml and lefthook.yml must match exactly, so a change to one without the
other can't silently weaken the strangler permit. Asserts both files carry the same two
canonical shell-gate commands. Exit 1 on drift.
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CI = ROOT / ".github/workflows/ci.yml"
LEFTHOOK = ROOT / "lefthook.yml"

# The canonical shell golden-master commands (must appear verbatim in BOTH files).
CANONICAL = [
    "shellcheck bin/* lib/*.sh install.sh tests/*.sh",
    "sh tests/run.sh",
]


def main() -> int:
    ci = CI.read_text(encoding="utf-8") if CI.exists() else ""
    lh = LEFTHOOK.read_text(encoding="utf-8") if LEFTHOOK.exists() else ""
    violations: list[str] = []
    for cmd in CANONICAL:
        if cmd not in ci:
            violations.append(f".github/workflows/ci.yml missing shell-gate command: {cmd!r}")
        if cmd not in lh:
            violations.append(f"lefthook.yml missing shell-gate command: {cmd!r}")

    if violations:
        print("mirror-drift lint FAILED (shell gate out of lockstep):", file=sys.stderr)
        for v in violations:
            print(f"  - {v}", file=sys.stderr)
        return 1
    print("mirror-drift lint OK (shell golden-master gate identical in CI and lefthook)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
