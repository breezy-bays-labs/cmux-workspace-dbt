#!/usr/bin/env python3
"""dep-budget lint — the no-tokio / no-HTTP / no-sqlite shipped-graph guard.

A fast, manifest-level check (mirrors crap4rs's direct-dep `cargo metadata --no-deps`
pattern): no banned crate may appear as a NORMAL (non-dev) dependency of any workspace
crate. cargo-deny (deny.toml, exclude-dev) is the transitive backstop; this is the
direct-dep early-warning. Dev-deps (tokio via cucumber) are exempt. Exit 1 on violation.
"""
from __future__ import annotations

import json
import subprocess
import sys

# The shipped binary must carry no async runtime, no HTTP client, no embedded SQL DB
# (design-plan §2 dependency budget). The runner wraps the external watchexec BINARY.
BANNED = {
    "tokio", "async-std", "smol",
    "reqwest", "hyper", "isahc", "ureq", "surf",
    "rusqlite", "libsqlite3-sys", "sqlx",
}


def main() -> int:
    out = subprocess.run(
        ["cargo", "metadata", "--no-deps", "--format-version", "1", "--locked"],
        capture_output=True, text=True, check=True,
    ).stdout
    meta = json.loads(out)
    violations: list[str] = []

    for pkg in meta["packages"]:
        for dep in pkg["dependencies"]:
            if dep.get("kind") == "dev":
                continue
            if dep["name"] in BANNED:
                violations.append(
                    f"{pkg['name']} declares banned shipped dependency `{dep['name']}`"
                )

    if violations:
        print("dep-budget lint FAILED (banned crate in the shipped graph):", file=sys.stderr)
        for v in violations:
            print(f"  - {v}", file=sys.stderr)
        print("  (async/HTTP/sqlite stacks are dev-only via [dev-dependencies] + deny exclude-dev)",
              file=sys.stderr)
        return 1
    print("dep-budget lint OK (no tokio/HTTP/sqlite in the shipped dependency graph)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
