//! `ctide` — cmux-terminal-ide. The composition root (clap + wiring only).
//!
//! At R0 this is an intentional stub: the workspace must compile end-to-end and
//! exercise the full crate DAG before any verb lands. The first verb,
//! `ctide doctor` over the `Multiplexer` port, arrives at R1
//! (`docs/roadmap/r1-walking-skeleton.md`). Until then `ctide` prints its status
//! so the binary is runnable and the dependency rule (bin → everything) holds.
#![forbid(unsafe_code)]

fn main() {
    println!(
        "ctide {} — scaffold (R0). No verbs yet; `ctide doctor` lands at R1.",
        env!("CARGO_PKG_VERSION")
    );
}
