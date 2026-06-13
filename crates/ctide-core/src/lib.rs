//! `ctide-core` — the hexagonal core of cmux-terminal-ide.
//!
//! The pure domain model + capability **ports** (traits). All sync, all
//! object-safe — cmux is request/response over a unix socket, so blocking I/O
//! is correct and no async machinery enters the core (design-plan §3 rule 4).
//!
//! The dependency rule: this crate depends on **nothing** else in the workspace.
//! Domain types and ports arrive with their owning verbs starting at R1
//! (`ctide doctor` over the `Multiplexer` port — see
//! `docs/roadmap/r1-walking-skeleton.md`). Empty by design at R0.
#![forbid(unsafe_code)]
