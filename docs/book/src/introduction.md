# cmux-terminal-ide (`ctide`)

> **Status: scaffold (R0).** This book grows one chapter per shipping epic
> (docs-as-you-go). The architecture and product rationale live in
> [`docs/vision/`](https://github.com/breezy-bays-labs/cmux-terminal-ide/tree/main/docs/vision);
> the build plan in [`docs/roadmap/`](https://github.com/breezy-bays-labs/cmux-terminal-ide/tree/main/docs/roadmap).

**ctide is a lightweight, agent-native terminal IDE composed on
[cmux](https://github.com/manaflow-ai/cmux).** Not an editor (helix stays
sovereign), not an agent (Claude Code stays the agent) — the meaning layer:
spaces, roles, review queues, journeys, and vertical recipes over the only
multiplexer that ships AI-agent primitives natively.

It is a single daemonless Rust binary ("the multiplexer is the supervisor"),
zero-egress and air-gappable by construction, with strong power-user defaults and
swap-safe trait seams so every tool is replaceable.

## The three IDE types

- **Base** — the agent-native terminal IDE: resumable spaces, the diff/review
  queue as the primary loop, engineered attention, closed human-on-the-loop fix loops.
- **dbt** — analytics engineering in jinja-SQL: "all of the intelligence, none of
  the sign-in" (local-first dbt DX), with cute-dbt filling the review/lineage gaps.
- **rust-dev** — the connective cockpit over bacon, nextest, insta, and mutants.

This documentation is filled in as each capability ships; see the
[roadmap](https://github.com/breezy-bays-labs/cmux-terminal-ide/blob/main/docs/roadmap/roadmap.md)
for what is built and what is next.
