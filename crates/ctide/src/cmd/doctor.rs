//! `ctide doctor` — the I/O shell around the pure `plan_doctor` use-case.
//!
//! Read-only: gathers `tree`/`identify`/`capabilities`/`manifest` from the
//! Multiplexer port, plus config provenance (g5), the pinned capability snapshot
//! (g7), and the substrate egress facts (P7); runs `plan_doctor`; renders the
//! human view or the schema-versioned `ctide-json` payload (g4). Mutates nothing.

use std::collections::BTreeSet;
use std::error::Error;

use ctide_core::Multiplexer;
use ctide_core::doctor::{DoctorInput, DoctorReport, plan_doctor};
use ctide_core::domain::{
    ConfigLayer, DeltaKind, EgressLabel, EgressLine, Generation, Provenance, VerbOwner,
};
use ctide_json::{
    CapabilityDeltaJson, DoctorPayload, EgressLineJson, EgressSurfaceJson, ProvenanceJson,
    SCHEMA_VERSION, TopologySummaryJson, VerbOwnerJson,
};

/// The pinned RPC surface (fidelity snapshot) `doctor` diffs the live cmux against.
const PINNED_CAPS: &str = include_str!(concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/../../fidelity/cmux-0.64.15/capabilities.json"
));

pub fn execute(mux: &dyn Multiplexer, json: bool) -> Result<(), Box<dyn Error>> {
    let input = DoctorInput {
        topology: mux.tree()?,
        identity: mux.identify()?,
        capabilities: mux.capabilities()?,
        pinned_rpcs: pinned_rpcs()?,
        manifests: vec![mux.manifest().clone()],
        substrate: substrate_egress(),
        provenance: provenance(),
        verb_owners: verb_owners(),
    };
    let report = plan_doctor(&input);

    if json {
        let payload = payload_from_report(&report);
        println!("{}", serde_json::to_string_pretty(&payload)?);
    } else {
        render_human(&report);
    }
    Ok(())
}

/// The pinned capability set, parsed from the embedded fidelity snapshot.
fn pinned_rpcs() -> Result<BTreeSet<String>, Box<dyn Error>> {
    let caps = ctide_mux_cmux::wire::parse_capabilities(PINNED_CAPS, "pinned")?;
    Ok(caps.rpcs)
}

/// ctide's channel to cmux is a local unix socket — no network egress. (A fuller
/// substrate telemetry audit is a follow-up; see the build log.)
fn substrate_egress() -> Vec<EgressLine> {
    vec![EgressLine {
        component: "cmux (control channel)".to_string(),
        label: EgressLabel::Zero,
        detail: "ctide drives cmux over a local unix socket; no network".to_string(),
    }]
}

/// Representative config provenance (g5), demonstrating layering. The cmux binary
/// path is the one key an env var (`CTIDE_CMUX_BIN`) can override.
fn provenance() -> Vec<Provenance> {
    let (cmux_bin, layer) = match std::env::var("CTIDE_CMUX_BIN") {
        Ok(v) => (v, ConfigLayer::EnvOrFlag),
        Err(_) => ("cmux".to_string(), ConfigLayer::Embedded),
    };
    vec![
        Provenance {
            key: "mux.transport".to_string(),
            value: "cli".to_string(),
            layer: ConfigLayer::Embedded,
        },
        Provenance {
            key: "mux.cmux_bin".to_string(),
            value: cmux_bin,
            layer,
        },
        Provenance {
            key: "json.schema".to_string(),
            value: SCHEMA_VERSION.to_string(),
            layer: ConfigLayer::Embedded,
        },
    ]
}

/// The strangler progress surface — which generation owns each verb today.
fn verb_owners() -> Vec<VerbOwner> {
    let rust = ["doctor"];
    let shell = ["space", "place", "agent", "jump", "open", "theme"];
    rust.iter()
        .map(|v| VerbOwner {
            verb: v.to_string(),
            owner: Generation::Rust,
        })
        .chain(shell.iter().map(|v| VerbOwner {
            verb: v.to_string(),
            owner: Generation::Shell,
        }))
        .collect()
}

fn render_human(r: &DoctorReport) {
    let t = &r.topology;
    println!("ctide doctor");
    println!(
        "  cmux {}  ·  {} window(s), {} workspace(s)",
        t.cmux_version, t.window_count, t.workspace_count
    );
    println!("  caller={}  focused={}", opt(&t.caller), opt(&t.focused));

    println!("\negress surface:");
    for line in &r.egress.ctide {
        println!(
            "  ctide   {:<22} {:<28} {}",
            line.component,
            line.label.summary(),
            line.detail
        );
    }
    for line in &r.egress.cmux_substrate {
        println!(
            "  cmux    {:<22} {:<28} {}",
            line.component,
            line.label.summary(),
            line.detail
        );
    }

    println!("\ncapability drift (live vs pinned fidelity):");
    if r.capability_drift.is_empty() {
        println!("  none — live cmux matches the pinned snapshot");
    } else {
        for d in &r.capability_drift {
            let mark = match d.kind {
                DeltaKind::AddedSincePin => "+ added",
                DeltaKind::RemovedSincePin => "- REMOVED",
            };
            println!("  {mark}: {}", d.rpc);
        }
    }

    println!("\nconfig provenance:");
    for p in &r.provenance {
        println!("  {:<16} = {:<10} ({})", p.key, p.value, p.layer.label());
    }

    println!("\nverb generation (strangler progress):");
    for v in &r.generation_owner {
        println!("  {:<8} {}", v.owner.label(), v.verb);
    }
}

fn opt(o: &Option<String>) -> String {
    o.clone().unwrap_or_else(|| "-".to_string())
}

// ── the frozen-contract bridge (g4): explicit, lives in the BINARY ──────────
// A free function rather than `impl From` — the orphan rule forbids implementing a
// foreign trait (`From`) for a foreign type (`DoctorPayload`) from this third crate.
// The g4 intent holds: the conversion is explicit and lives in the binary, so a
// ctide-core domain refactor surfaces here as a compile error, never a silent
// contract break.
fn payload_from_report(r: &DoctorReport) -> DoctorPayload {
    DoctorPayload {
        schema: SCHEMA_VERSION,
        topology: TopologySummaryJson {
            window_count: r.topology.window_count,
            workspace_count: r.topology.workspace_count,
            cmux_version: r.topology.cmux_version.clone(),
            caller: r.topology.caller.clone(),
            focused: r.topology.focused.clone(),
        },
        egress: EgressSurfaceJson {
            ctide: r.egress.ctide.iter().map(line_json).collect(),
            cmux_substrate: r.egress.cmux_substrate.iter().map(line_json).collect(),
        },
        capability_drift: r
            .capability_drift
            .iter()
            .map(|d| CapabilityDeltaJson {
                rpc: d.rpc.clone(),
                kind: match d.kind {
                    DeltaKind::AddedSincePin => "added-since-pin".to_string(),
                    DeltaKind::RemovedSincePin => "removed-since-pin".to_string(),
                },
            })
            .collect(),
        provenance: r
            .provenance
            .iter()
            .map(|p| ProvenanceJson {
                key: p.key.clone(),
                value: p.value.clone(),
                layer: p.layer.label().to_string(),
            })
            .collect(),
        generation_owner: r
            .generation_owner
            .iter()
            .map(|v| VerbOwnerJson {
                verb: v.verb.clone(),
                owner: v.owner.label().to_string(),
            })
            .collect(),
    }
}

fn line_json(l: &EgressLine) -> EgressLineJson {
    EgressLineJson {
        component: l.component.clone(),
        label: l.label.summary(),
        detail: l.detail.clone(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ctide_core::MuxTopology;
    use ctide_testkit::FakeMux;

    // Drive the full doctor verb against FakeMux (no live cmux): covers the I/O
    // shell, the provenance/substrate/verb-owner builders, the g4 payload bridge,
    // and both renderers.
    #[test]
    fn doctor_human_runs() {
        execute(&FakeMux::from_fidelity(), false).expect("human doctor runs");
    }

    #[test]
    fn doctor_json_runs() {
        execute(&FakeMux::from_fidelity(), true).expect("json doctor runs");
    }

    // The g4 bridge maps a report into a schema-1 payload with matching topology.
    #[test]
    fn payload_bridge_preserves_schema_and_topology() {
        let mux = FakeMux::from_fidelity();
        let report = plan_doctor(&DoctorInput {
            topology: mux.tree().unwrap(),
            identity: mux.identify().unwrap(),
            capabilities: mux.capabilities().unwrap(),
            pinned_rpcs: pinned_rpcs().unwrap(),
            manifests: vec![mux.manifest().clone()],
            substrate: substrate_egress(),
            provenance: provenance(),
            verb_owners: verb_owners(),
        });
        let payload = payload_from_report(&report);
        assert_eq!(payload.schema, SCHEMA_VERSION);
        assert_eq!(payload.topology.window_count, report.topology.window_count);
        assert_eq!(
            payload.generation_owner.len(),
            report.generation_owner.len()
        );
    }
}
