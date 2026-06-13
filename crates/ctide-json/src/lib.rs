//! `ctide-json` — the frozen, schema-versioned `--json` output contract (g4).
//!
//! A `serde`-only crate holding the structs every `ctide … --json` verb emits.
//! Deliberately decoupled from `ctide-core`'s internal domain types: the binary
//! owns the explicit `From<&DomainType> for JsonType` conversions, so a domain
//! refactor cannot silently change the contract agents pin against
//! (design-plan §2, g4). The first payload (`DoctorPayload`, `schema = 1`) lands
//! with `ctide doctor` at R1. Empty by design at R0.
#![forbid(unsafe_code)]
