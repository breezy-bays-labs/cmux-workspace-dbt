//! `ctide-mux-cmux` — the cmux adapter for the `Multiplexer` port (the quirk vault).
//!
//! Encapsulates every hard-won cmux fact behind the clean port trait so the rest
//! of ctide never re-learns them (design-plan §4). Facts live in [`wire`] (pure
//! parsers + `// fact:` comments + fixture tests); [`adapter`] is the I/O shell.
//! `doctor` uses the read-only path; the v2-socket transport + replay-server CI
//! tier (g7) are the next slice.
#![forbid(unsafe_code)]

pub mod adapter;
pub mod wire;

pub use adapter::CmuxCliAdapter;
