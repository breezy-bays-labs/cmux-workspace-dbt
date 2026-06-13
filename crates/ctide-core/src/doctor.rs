//! The `doctor` use-case — `plan_doctor` is PURE (`input → report`, zero I/O).
//!
//! This is the asserted logic (the unit + golden surface). The binary's thin
//! `execute` shell reads the ports (`tree`/`identify`/`capabilities`/`manifest`),
//! builds the [`DoctorInput`], calls [`plan_doctor`], and renders the
//! [`DoctorReport`] (human or `--json` via `ctide-json`). doctor mutates nothing.

use std::collections::BTreeSet;

use crate::domain::{
    AdapterManifest, CapabilityDelta, CapabilitySet, DeltaKind, EgressLine, EgressSurface,
    Identity, Provenance, Topology, VerbOwner,
};

/// Everything `plan_doctor` needs, gathered by the I/O shell.
#[derive(Debug, Clone)]
pub struct DoctorInput {
    pub topology: Topology,
    pub identity: Identity,
    pub capabilities: CapabilitySet,
    /// The pinned fidelity snapshot of the RPC surface, to diff against (g7).
    pub pinned_rpcs: BTreeSet<String>,
    /// The bound adapter set — each contributes an egress line (P7).
    pub manifests: Vec<AdapterManifest>,
    /// Substrate (cmux) egress facts ctide rides on (telemetry, feed control, …).
    pub substrate: Vec<EgressLine>,
    /// Resolved config keys + their layer (g5).
    pub provenance: Vec<Provenance>,
    /// Which generation owns each verb (strangler progress).
    pub verb_owners: Vec<VerbOwner>,
}

/// A compact read-path summary — evidence the topology read succeeded.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TopologySummary {
    pub window_count: usize,
    pub workspace_count: usize,
    pub cmux_version: String,
    pub caller: Option<String>,
    pub focused: Option<String>,
}

/// The full doctor report — the four trust sections plus the topology summary.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DoctorReport {
    pub topology: TopologySummary,
    pub egress: EgressSurface,
    pub capability_drift: Vec<CapabilityDelta>,
    pub provenance: Vec<Provenance>,
    pub generation_owner: Vec<VerbOwner>,
}

/// The whole verb's logic as a pure function — this is what tests assert.
pub fn plan_doctor(input: &DoctorInput) -> DoctorReport {
    DoctorReport {
        topology: TopologySummary {
            window_count: input.topology.windows.len(),
            workspace_count: input.topology.workspace_count(),
            cmux_version: input.capabilities.version.clone(),
            caller: input.identity.caller.clone(),
            focused: input.identity.focused.clone(),
        },
        egress: egress_surface(&input.manifests, &input.substrate),
        capability_drift: capability_drift(&input.capabilities.rpcs, &input.pinned_rpcs),
        provenance: input.provenance.clone(),
        generation_owner: input.verb_owners.clone(),
    }
}

/// ctide's own egress surface (from the bound adapters) + the cmux substrate.
fn egress_surface(manifests: &[AdapterManifest], substrate: &[EgressLine]) -> EgressSurface {
    let ctide = manifests
        .iter()
        .map(|m| EgressLine {
            component: m.id.clone(),
            label: m.egress.clone(),
            detail: required_tools_detail(&m.required_tools),
        })
        .collect();
    EgressSurface {
        ctide,
        cmux_substrate: substrate.to_vec(),
    }
}

fn required_tools_detail(tools: &[String]) -> String {
    if tools.is_empty() {
        "no external tools".to_string()
    } else {
        format!("tools: {}", tools.join(", "))
    }
}

/// Diff the live RPC set against the pinned snapshot. Added = cmux grew a method;
/// Removed = cmux dropped one (the dangerous case for a pinned adapter).
fn capability_drift(live: &BTreeSet<String>, pinned: &BTreeSet<String>) -> Vec<CapabilityDelta> {
    let added = live.difference(pinned).map(|rpc| CapabilityDelta {
        rpc: rpc.clone(),
        kind: DeltaKind::AddedSincePin,
    });
    let removed = pinned.difference(live).map(|rpc| CapabilityDelta {
        rpc: rpc.clone(),
        kind: DeltaKind::RemovedSincePin,
    });
    added.chain(removed).collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{
        ConfigLayer, EgressLabel, Generation, PortKind, WindowNode, WorkspaceNode,
    };

    fn ws(id: &str) -> WorkspaceNode {
        WorkspaceNode {
            id: id.to_string(),
            ref_hint: None,
            description: None,
            current_directory: None,
            surface_ids: vec![],
        }
    }

    fn input_with(live: &[&str], pinned: &[&str]) -> DoctorInput {
        DoctorInput {
            topology: Topology {
                windows: vec![WindowNode {
                    id: "W1".to_string(),
                    ref_hint: Some("window:1".to_string()),
                    workspaces: vec![ws("A"), ws("B")],
                }],
            },
            identity: Identity {
                caller: Some("A".to_string()),
                focused: Some("B".to_string()),
            },
            capabilities: CapabilitySet {
                rpcs: live.iter().map(|s| s.to_string()).collect(),
                version: "0.64.15".to_string(),
            },
            pinned_rpcs: pinned.iter().map(|s| s.to_string()).collect(),
            manifests: vec![AdapterManifest {
                id: "cmux".to_string(),
                port: PortKind::Mux,
                egress: EgressLabel::Zero,
                required_tools: vec!["cmux".to_string()],
            }],
            substrate: vec![EgressLine {
                component: "cmux telemetry".to_string(),
                label: EgressLabel::TelemetryDisabledVerified,
                detail: "anonymous usage stats".to_string(),
            }],
            provenance: vec![Provenance {
                key: "bindings.editor".to_string(),
                value: "helix".to_string(),
                layer: ConfigLayer::Embedded,
            }],
            verb_owners: vec![VerbOwner {
                verb: "doctor".to_string(),
                owner: Generation::Rust,
            }],
        }
    }

    #[test]
    fn summarizes_topology_and_identity() {
        let report = plan_doctor(&input_with(&["tree"], &["tree"]));
        assert_eq!(report.topology.window_count, 1);
        assert_eq!(report.topology.workspace_count, 2);
        assert_eq!(report.topology.cmux_version, "0.64.15");
        assert_eq!(report.topology.caller.as_deref(), Some("A"));
        assert_eq!(report.topology.focused.as_deref(), Some("B"));
    }

    #[test]
    fn detects_added_and_removed_capabilities() {
        // live has {tree, new_rpc}; pinned has {tree, gone_rpc}.
        let report = plan_doctor(&input_with(&["tree", "new_rpc"], &["tree", "gone_rpc"]));
        let added: Vec<_> = report
            .capability_drift
            .iter()
            .filter(|d| d.kind == DeltaKind::AddedSincePin)
            .map(|d| d.rpc.as_str())
            .collect();
        let removed: Vec<_> = report
            .capability_drift
            .iter()
            .filter(|d| d.kind == DeltaKind::RemovedSincePin)
            .map(|d| d.rpc.as_str())
            .collect();
        assert_eq!(added, vec!["new_rpc"]);
        assert_eq!(removed, vec!["gone_rpc"]);
    }

    #[test]
    fn no_drift_when_live_matches_pinned() {
        let report = plan_doctor(&input_with(&["tree", "identify"], &["tree", "identify"]));
        assert!(report.capability_drift.is_empty());
    }

    #[test]
    fn egress_surface_carries_adapters_and_substrate() {
        let report = plan_doctor(&input_with(&["tree"], &["tree"]));
        assert_eq!(report.egress.ctide.len(), 1);
        assert_eq!(report.egress.ctide[0].component, "cmux");
        assert_eq!(report.egress.ctide[0].label, EgressLabel::Zero);
        // The substrate section is what makes the zero-egress claim falsifiable.
        assert_eq!(report.egress.cmux_substrate.len(), 1);
    }
}
