//! `ctide-core` — the hexagonal core of cmux-terminal-ide.
//!
//! The pure domain model + capability **ports** (traits) + use-cases. All sync,
//! all object-safe — cmux is request/response over a unix socket, so blocking I/O
//! is correct and no async machinery enters the core (design-plan §3 rule 4).
//!
//! The dependency rule: this crate depends on **nothing** else in the workspace.
//! Use-cases follow the `plan_*` (pure, the asserted logic) / `execute` (the thin
//! I/O shell, in the binary) split. The first verb is `doctor`
//! (`docs/roadmap/r1-walking-skeleton.md`).
#![forbid(unsafe_code)]

pub mod doctor;
pub mod domain;
pub mod ports;

pub use ports::{Multiplexer, MuxError, MuxTopology};
