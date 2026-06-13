#!/usr/bin/env python3
"""quirk-vault lint — every cmux `// fact:` lives ONLY in ctide-mux-cmux (design-plan §4).

The cmux adapter is the single home for hard-won cmux quirks. A `// fact:` comment anywhere
else means a quirk is leaking into the core or the binary, which the adapter is supposed to
encapsulate. At R0 there are no facts yet (passes vacuously). Exit 1 on any leak.
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CRATES = ROOT / "crates"
VAULT = "crates/ctide-mux-cmux/"
MARKER = "// fact:"


def main() -> int:
    violations: list[str] = []
    for rs in CRATES.rglob("*.rs"):
        rel = rs.relative_to(ROOT).as_posix()
        if rel.startswith(VAULT):
            continue
        for n, line in enumerate(rs.read_text(encoding="utf-8").splitlines(), 1):
            if MARKER in line:
                violations.append(f"{rel}:{n}: cmux `// fact:` outside the quirk vault")

    if violations:
        print("quirk-vault lint FAILED (cmux facts must live only in ctide-mux-cmux):",
              file=sys.stderr)
        for v in violations:
            print(f"  - {v}", file=sys.stderr)
        return 1
    print("quirk-vault lint OK (all cmux `// fact:` comments confined to ctide-mux-cmux)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
