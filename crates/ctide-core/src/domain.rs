//! The domain types `doctor` touches: read-only topology + identity, the trust
//! labels (P7), config provenance (g5), and capability drift (g7).
//!
//! IDs are carried as normalized strings at this slice (cmux UUIDs are
//! uppercased on construction in the adapter). The typed `MuxId { uuid, ref_hint }`
//! the design plan describes — encoding "refs die across restarts, UUIDs survive" —
//! lands when persistence needs it (spaces, R3); `doctor` only reads and displays.

use std::collections::BTreeSet;
use std::path::PathBuf;

// ── Read-only topology (what `tree()` returns) ──────────────────────────────

/// The whole multiplexer topology — always global (cmux `tree --all`), never the
/// focused-window-only `workspace.list` (the quirk the adapter encapsulates).
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct Topology {
    pub windows: Vec<WindowNode>,
}

impl Topology {
    /// Total workspaces across every window.
    pub fn workspace_count(&self) -> usize {
        self.windows.iter().map(|w| w.workspaces.len()).sum()
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WindowNode {
    pub id: String,
    pub ref_hint: Option<String>,
    pub workspaces: Vec<WorkspaceNode>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WorkspaceNode {
    pub id: String,
    pub ref_hint: Option<String>,
    pub description: Option<String>,
    /// `tree` does not carry the cwd; an adapter merges it from a secondary call
    /// when a verb needs it. `doctor` does not, so it may be `None` here.
    pub current_directory: Option<PathBuf>,
    pub surface_ids: Vec<String>,
}

/// Caller vs focused workspace (cmux `identify`).
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct Identity {
    pub caller: Option<String>,
    pub focused: Option<String>,
}

// ── Capability set + drift (g7) ─────────────────────────────────────────────

/// The RPC surface a multiplexer advertises, plus its version. Diffed against a
/// pinned fidelity snapshot to surface drift (cmux's fast upstream cadence, risk #1).
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct CapabilitySet {
    pub rpcs: BTreeSet<String>,
    pub version: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CapabilityDelta {
    pub rpc: String,
    pub kind: DeltaKind,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DeltaKind {
    /// Present live, absent from the pinned snapshot (cmux added it).
    AddedSincePin,
    /// In the pinned snapshot, absent live (cmux removed it — the dangerous case).
    RemovedSincePin,
}

// ── Trust / egress posture (P7) ─────────────────────────────────────────────

/// The egress classification of an adapter or substrate component. Deny-by-default:
/// every `AdapterManifest` must carry one (the `egress-labels` lint enforces it).
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum EgressLabel {
    /// No network egress at all.
    Zero,
    /// Egress that is defensible + opt-in (e.g. `gh`).
    DefensibleEgress { why: String },
    /// A tool that phones home by default, with telemetry verified disabled.
    TelemetryDisabledVerified,
}

impl EgressLabel {
    pub fn summary(&self) -> String {
        match self {
            EgressLabel::Zero => "zero".to_string(),
            EgressLabel::DefensibleEgress { why } => format!("defensible-egress ({why})"),
            EgressLabel::TelemetryDisabledVerified => "telemetry-disabled (verified)".to_string(),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PortKind {
    Mux,
    Editor,
    Explorer,
    Vcs,
    Runner,
    Agent,
    Theme,
    Placement,
    Warehouse,
    Notify,
}

/// An adapter's self-description, including its egress label (P7) and the external
/// tools it requires. CI rejects a manifest without an `EgressLabel`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AdapterManifest {
    pub id: String,
    pub port: PortKind,
    pub egress: EgressLabel,
    pub required_tools: Vec<String>,
}

/// One line of the egress surface `doctor` prints — a component and its label.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EgressLine {
    pub component: String,
    pub label: EgressLabel,
    pub detail: String,
}

/// ctide's own network surface PLUS the cmux substrate it rides on. The zero-egress
/// claim is only falsifiable if the surface includes the substrate (design-plan §3).
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct EgressSurface {
    pub ctide: Vec<EgressLine>,
    pub cmux_substrate: Vec<EgressLine>,
}

// ── Config provenance (g5) ──────────────────────────────────────────────────

/// Which layer an effective config value came from — so "why is it doing that?"
/// stops being archaeology. The user-config layer is READ-ONLY (never written).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ConfigLayer {
    Embedded,
    UserConfig,
    RepoCommitted,
    RepoLocal,
    EnvOrFlag,
}

impl ConfigLayer {
    pub fn label(&self) -> &'static str {
        match self {
            ConfigLayer::Embedded => "embedded",
            ConfigLayer::UserConfig => "user",
            ConfigLayer::RepoCommitted => "repo",
            ConfigLayer::RepoLocal => "repo-local",
            ConfigLayer::EnvOrFlag => "env/flag",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Provenance {
    pub key: String,
    pub value: String,
    pub layer: ConfigLayer,
}

// ── Verb generation ownership (strangler visibility) ────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Generation {
    Shell,
    Rust,
}

impl Generation {
    pub fn label(&self) -> &'static str {
        match self {
            Generation::Shell => "shell",
            Generation::Rust => "rust",
        }
    }
}

/// Which generation currently owns a verb — the strangler progress surface.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VerbOwner {
    pub verb: String,
    pub owner: Generation,
}
