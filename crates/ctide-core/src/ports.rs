//! Capability **ports** — the trait seams adapters implement.
//!
//! Sync and object-safe (`&dyn Multiplexer` works): cmux is blocking
//! request/response over a unix socket (design-plan §3 rule 4). `doctor` is
//! read-only, so this slice defines only the read side — `MuxTopology` plus the
//! `Multiplexer` reflection methods. The write-side capability traits
//! (`MuxWorkspaces`, `MuxSurfaces`, `MuxAttention`, …) arrive with their verbs in
//! R2+ and will extend the `Multiplexer` supertrait then.

use crate::domain::{AdapterManifest, CapabilitySet, Identity, Topology};

/// Typed multiplexer errors — the adapter never panics on a quirk; it maps every
/// failure into one of these.
#[derive(Debug, thiserror::Error)]
pub enum MuxError {
    /// The multiplexer CLI/socket could not be reached.
    #[error("cmux is not reachable: {0}")]
    Unreachable(String),
    /// A command ran but returned an error or unexpected status.
    #[error("cmux command failed: {0}")]
    CommandFailed(String),
    /// The wire payload did not parse into the expected shape.
    #[error("could not parse cmux output: {0}")]
    Parse(String),
    /// A method exists on the supertrait but is not implemented in this slice.
    #[error("not implemented in this slice: {0}")]
    NotImplementedThisSlice(&'static str),
}

/// The read-only topology capability.
pub trait MuxTopology {
    /// Global topology — always `tree --all`. The focused-window-only
    /// `workspace.list` trap is unexpressible here: there is no scoped listing.
    fn tree(&self) -> Result<Topology, MuxError>;
    /// Caller vs focused workspace.
    fn identify(&self) -> Result<Identity, MuxError>;
}

/// The umbrella capability trait. `doctor` calls `capabilities()` + `manifest()`
/// plus (via `MuxTopology`) `tree()`/`identify()`. Object-safe: `&dyn Multiplexer`.
pub trait Multiplexer: MuxTopology {
    /// The advertised RPC surface + version (probed per invocation).
    fn capabilities(&self) -> Result<CapabilitySet, MuxError>;
    /// This adapter's self-description (id, port, egress label, required tools).
    fn manifest(&self) -> &AdapterManifest;
}
