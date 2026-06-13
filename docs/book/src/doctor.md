# `ctide doctor`

`ctide doctor` is the trust/diagnostic verb. It is **read-only** — it mutates
nothing — and prints ctide's trust surface so you can answer "what is it doing,
and what can it reach?" It is the first verb of the Rust build (the walking
skeleton) and proves the rails the rest of ctide rides on.

## Usage

```console
$ ctide doctor
ctide doctor
  cmux 0.64.15  ·  1 window(s), 5 workspace(s)
  caller=workspace:3  focused=workspace:1

egress surface:
  ctide   cmux-cli               zero                         tools: cmux
  cmux    cmux (control channel) zero                         ctide drives cmux over a local unix socket; no network

capability drift (live vs pinned fidelity):
  none — live cmux matches the pinned snapshot

config provenance:
  mux.transport    = cli        (embedded)
  mux.cmux_bin     = cmux       (embedded)
  json.schema      = 1          (embedded)

verb generation (strangler progress):
  rust     doctor
  shell    space
  …
```

## What it reports

- **Topology** — a global read of cmux (`tree --all`): window and workspace
  counts, plus the caller/focused workspace. Proof the multiplexer read path works.
- **Egress surface** — ctide's own network surface *and* the cmux substrate it
  rides on. Every adapter carries an egress label; the claim "zero egress" is only
  falsifiable because the substrate is shown alongside.
- **Capability drift** — the live cmux RPC surface diffed against a pinned
  fidelity snapshot. cmux moves fast; this surfaces methods added or (dangerously)
  removed since the snapshot.
- **Config provenance** — every effective config key and which layer it came from
  (embedded / user / repo / repo-local / env-or-flag). "Why is it doing that?"
  stops being archaeology.
- **Verb generation** — which generation (Rust or shell) currently owns each verb,
  so the strangler migration's progress is always visible.

## The `--json` contract

`ctide doctor --json` emits a schema-versioned payload (the `ctide-json` frozen
contract) that agents and scripts can pin against:

```console
$ ctide doctor --json | jq '.schema, .topology.window_count'
1
1
```

The `schema` field is the contract version; it is bumped deliberately. The shape
is decoupled from ctide's internal types, so internal refactors cannot silently
change what machine consumers see.

## Trust posture

`ctide doctor` makes no network calls. It drives cmux over a local unix socket
and reads three things (`tree`, `identify`, `capabilities`); it never writes cmux
state, and it never writes `~/.config`.
