//! `ctide-adapters` — concrete tool adapters behind ctide-core's ports.
//!
//! One feature-gated module per swappable tool (helix `Editor`, yazi `Explorer`,
//! lazygit `Vcs`, watchexec/bacon `Runner`, …). Each implements a `ctide-core`
//! port and ships an `AdapterManifest` carrying an `EgressLabel` (the
//! `egress-labels` lint rejects a manifest without one). Adapters arrive with
//! their verbs in R2+. Empty by design at R0.
#![forbid(unsafe_code)]
