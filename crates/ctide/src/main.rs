//! `ctide` — cmux-terminal-ide. The composition root (clap + wiring only).
//!
//! R1 ships the first verb, `ctide doctor` over the `Multiplexer` port — a
//! read-only trust/diagnostic verb that proves the rails and the zero-egress
//! posture (`docs/roadmap/r1-walking-skeleton.md`). More verbs land R2+.
#![forbid(unsafe_code)]

mod cmd;

use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(
    name = "ctide",
    version,
    about = "A lightweight, agent-native terminal IDE on cmux."
)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Print ctide's trust surface: topology, egress, capability drift, config provenance.
    Doctor {
        /// Emit the schema-versioned ctide-json payload instead of the human view.
        #[arg(long)]
        json: bool,
    },
}

fn main() -> std::process::ExitCode {
    let cli = Cli::parse();
    let result = match cli.command {
        Command::Doctor { json } => {
            let mux = ctide_mux_cmux::CmuxCliAdapter::new();
            cmd::doctor::execute(&mux, json)
        }
    };
    match result {
        Ok(()) => std::process::ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("ctide: {e}");
            std::process::ExitCode::FAILURE
        }
    }
}
