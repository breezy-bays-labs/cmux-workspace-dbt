//! `ctide-json` — the frozen, schema-versioned `--json` output contract (g4).
//!
//! A `serde`-only crate holding the structs every `ctide … --json` verb emits.
//! Deliberately decoupled from `ctide-core`'s internal domain types: the binary
//! owns the explicit `From<&DomainType> for JsonType` conversions, so a domain
//! refactor cannot silently change the contract agents pin against
//! (design-plan §2, g4). Leaf enums are flattened to strings on the wire so the
//! contract is stable across internal enum churn.
#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

/// The `--json` schema version. Bump deliberately; agents pin against it.
pub const SCHEMA_VERSION: u32 = 1;

/// `ctide doctor --json` output.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DoctorPayload {
    pub schema: u32,
    pub topology: TopologySummaryJson,
    pub egress: EgressSurfaceJson,
    pub capability_drift: Vec<CapabilityDeltaJson>,
    pub provenance: Vec<ProvenanceJson>,
    pub generation_owner: Vec<VerbOwnerJson>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TopologySummaryJson {
    pub window_count: usize,
    pub workspace_count: usize,
    pub cmux_version: String,
    pub caller: Option<String>,
    pub focused: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EgressSurfaceJson {
    pub ctide: Vec<EgressLineJson>,
    pub cmux_substrate: Vec<EgressLineJson>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EgressLineJson {
    pub component: String,
    /// Flattened label, e.g. "zero" | "defensible-egress (gh)" | "telemetry-disabled (verified)".
    pub label: String,
    pub detail: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CapabilityDeltaJson {
    pub rpc: String,
    /// "added-since-pin" | "removed-since-pin".
    pub kind: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ProvenanceJson {
    pub key: String,
    pub value: String,
    /// "embedded" | "user" | "repo" | "repo-local" | "env/flag".
    pub layer: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct VerbOwnerJson {
    pub verb: String,
    /// "shell" | "rust".
    pub owner: String,
}

#[cfg(test)]
mod round_trip {
    use super::*;
    use proptest::prelude::*;

    fn line() -> impl Strategy<Value = EgressLineJson> {
        (any::<String>(), any::<String>(), any::<String>()).prop_map(
            |(component, label, detail)| EgressLineJson {
                component,
                label,
                detail,
            },
        )
    }

    prop_compose! {
        fn payload()(
            window_count in any::<usize>(),
            workspace_count in any::<usize>(),
            cmux_version in any::<String>(),
            caller in any::<Option<String>>(),
            focused in any::<Option<String>>(),
            ctide in prop::collection::vec(line(), 0..4),
            substrate in prop::collection::vec(line(), 0..4),
            drift in prop::collection::vec((any::<String>(), any::<String>()), 0..4),
            prov in prop::collection::vec((any::<String>(), any::<String>(), any::<String>()), 0..4),
            verbs in prop::collection::vec((any::<String>(), any::<String>()), 0..4),
        ) -> DoctorPayload {
            DoctorPayload {
                schema: SCHEMA_VERSION,
                topology: TopologySummaryJson { window_count, workspace_count, cmux_version, caller, focused },
                egress: EgressSurfaceJson { ctide, cmux_substrate: substrate },
                capability_drift: drift.into_iter().map(|(rpc, kind)| CapabilityDeltaJson { rpc, kind }).collect(),
                provenance: prov.into_iter().map(|(key, value, layer)| ProvenanceJson { key, value, layer }).collect(),
                generation_owner: verbs.into_iter().map(|(verb, owner)| VerbOwnerJson { verb, owner }).collect(),
            }
        }
    }

    proptest! {
        // gate 1: the payload is a stable serde round-trip (string -> struct -> string).
        #[test]
        fn json_round_trips(p in payload()) {
            let s = serde_json::to_string(&p).expect("serialize");
            let back: DoctorPayload = serde_json::from_str(&s).expect("deserialize");
            prop_assert_eq!(p, back);
        }
    }

    #[test]
    fn schema_version_is_one() {
        assert_eq!(SCHEMA_VERSION, 1);
    }
}
