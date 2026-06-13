#!/usr/bin/env python3
"""dependency-rule lint — the hexagon enforced mechanically (ci-quality-framework.md §4.9).

Asserts the crate DAG's two load-bearing invariants over NORMAL (non-dev) deps:
  1. `ctide-core` depends on NOTHING in-workspace.
  2. NOTHING in-workspace depends on the `ctide` binary.

Uses `cargo metadata --no-deps` (declared deps, not the resolved graph). Dev-deps are
exempt (tests may depend on anything, e.g. ctide-testkit). Exit 1 on any violation.
"""
from __future__ import annotations

import json
import subprocess
import sys

BIN = "ctide"
CORE = "ctide-core"


def main() -> int:
    out = subprocess.run(
        ["cargo", "metadata", "--no-deps", "--format-version", "1", "--locked"],
        capture_output=True, text=True, check=True,
    ).stdout
    meta = json.loads(out)
    members = {p["name"] for p in meta["packages"]}
    violations: list[str] = []

    for pkg in meta["packages"]:
        name = pkg["name"]
        for dep in pkg["dependencies"]:
            # kind is null for normal, "dev"/"build" otherwise; skip dev-deps.
            if dep.get("kind") == "dev":
                continue
            dname = dep["name"]
            if dname not in members:
                continue
            if name == CORE:
                violations.append(
                    f"{CORE} must depend on nothing in-workspace, but depends on {dname}"
                )
            if dname == BIN:
                violations.append(
                    f"{name} depends on the binary `{BIN}` — nothing may depend on the bin"
                )

    if violations:
        print("dependency-rule lint FAILED:", file=sys.stderr)
        for v in violations:
            print(f"  - {v}", file=sys.stderr)
        return 1
    print("dependency-rule lint OK (core depends on nothing in-ws; nothing depends on the bin)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
