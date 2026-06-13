//! `ctide-mux-cmux` — the cmux adapter for the `Multiplexer` port (the quirk vault).
//!
//! Encapsulates every hard-won cmux fact behind the clean port trait so the rest
//! of ctide never re-learns them (design-plan §4):
//! `workspace.list` is focused-window-only → always enumerate via `tree --all`;
//! `OK <uuid>` vs `OK workspace:N` output formats; the caller-workspace cmux
//! protects; ghost windows; the `current_directory` merge. Each fact carries a
//! `// fact:` comment + a fixture test and lives **only** here (quirk-vault lint).
//! `CmuxSocketAdapter` (v2 JSON socket) lands with `ctide doctor` at R1.
//! Empty by design at R0.
#![forbid(unsafe_code)]
