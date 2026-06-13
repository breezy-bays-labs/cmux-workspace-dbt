#!/usr/bin/env python3
"""no-config-write lint — ctide NEVER writes ~/.config (constraint 4, design-plan §5).

Rejects `~/.config` / `$HOME/.config` path literals in Rust CODE outside the consented
`setup` module (the only path allowed to write a global file, via a Consent token). Comment
lines are exempt so doc comments may *describe* the read-only user-config layer; the gate
targets code literals that could construct a writable path. Exit 1 on any violation.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CRATES = ROOT / "crates"

# Forbidden path-literal shapes (the home config dir).
PATTERNS = [re.compile(p) for p in (r"~/\.config", r"\$HOME/\.config", r"/\.config/ctide")]
# Files allowed to reference it (the consented writer). None exist yet at R0.
ALLOW_SUBSTR = ("setup",)


def is_comment(line: str) -> bool:
    s = line.lstrip()
    return s.startswith(("//", "/*", "*", "*/"))


def main() -> int:
    violations: list[str] = []
    for rs in CRATES.rglob("*.rs"):
        rel = rs.relative_to(ROOT).as_posix()
        if any(a in rel for a in ALLOW_SUBSTR):
            continue
        for n, line in enumerate(rs.read_text(encoding="utf-8").splitlines(), 1):
            if is_comment(line):
                continue
            if any(p.search(line) for p in PATTERNS):
                violations.append(f"{rel}:{n}: {line.strip()}")

    if violations:
        print("no-config-write lint FAILED (~/.config literal in code outside `setup`):",
              file=sys.stderr)
        for v in violations:
            print(f"  - {v}", file=sys.stderr)
        return 1
    print("no-config-write lint OK (no ~/.config write literals outside the setup module)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
