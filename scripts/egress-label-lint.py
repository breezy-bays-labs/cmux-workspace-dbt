#!/usr/bin/env python3
"""egress-label lint — every AdapterManifest declares an EgressLabel (deny-by-default, P7).

The trust surface ctide doctor prints is only falsifiable if every adapter is labelled.
This lint asserts that each `AdapterManifest { ... }` struct literal includes an `egress:`
field. At R0 there are no manifests yet, so it passes vacuously; it bites the moment the
first adapter lands without a label. Exit 1 on any unlabelled manifest.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CRATES = ROOT / "crates"
OPEN = re.compile(r"AdapterManifest\s*\{")


def main() -> int:
    violations: list[str] = []
    for rs in CRATES.rglob("*.rs"):
        text = rs.read_text(encoding="utf-8")
        for m in OPEN.finditer(text):
            # Only struct LITERALS, not type positions. Skip `&AdapterManifest {`
            # (a `-> &AdapterManifest` return type) and `struct AdapterManifest {`
            # (the definition itself).
            prefix = text[max(0, m.start() - 12):m.start()].rstrip()
            if prefix.endswith("&") or prefix.endswith("struct"):
                continue
            # scan the brace-balanced literal body for an `egress:` field.
            i, depth, body = m.end() - 1, 0, []
            while i < len(text):
                c = text[i]
                if c == "{":
                    depth += 1
                elif c == "}":
                    depth -= 1
                    if depth == 0:
                        break
                body.append(c)
                i += 1
            if "egress:" not in "".join(body):
                line = text[: m.start()].count("\n") + 1
                violations.append(f"{rs.relative_to(ROOT).as_posix()}:{line}: AdapterManifest without egress:")

    if violations:
        print("egress-label lint FAILED (AdapterManifest missing an EgressLabel):", file=sys.stderr)
        for v in violations:
            print(f"  - {v}", file=sys.stderr)
        return 1
    print("egress-label lint OK (every AdapterManifest declares an EgressLabel)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
