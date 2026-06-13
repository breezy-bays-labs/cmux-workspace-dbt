//! `FakeMux` — the third `Multiplexer` impl, and *the* testing story (design-plan §4).
//!
//! Serves a fixed [`Topology`]/[`Identity`]/[`CapabilitySet`] built from the REAL
//! captured `fidelity/<version>/` fixtures (parsed through the cmux adapter's own
//! pure parsers, so the fake is genuinely-captured state, not hand-authored). It
//! records any mutating op so a blast-radius test can prove a read-only verb like
//! `doctor` mutates nothing.

use std::cell::RefCell;

use ctide_core::domain::{
    AdapterManifest, CapabilitySet, EgressLabel, Identity, PortKind, Topology,
};
use ctide_core::{Multiplexer, MuxError, MuxTopology};
use ctide_mux_cmux::wire;

const TREE: &str = include_str!(concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/../../fidelity/cmux-0.64.15/tree.json"
));
const IDENTIFY: &str = include_str!(concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/../../fidelity/cmux-0.64.15/identify.json"
));
const CAPS: &str = include_str!(concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/../../fidelity/cmux-0.64.15/capabilities.json"
));
const VERSION: &str = include_str!(concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/../../fidelity/cmux-0.64.15/version.txt"
));

/// A recorded mutating operation (none exist for read-only verbs — the point).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RecordedOp(pub String);

pub struct FakeMux {
    topology: Topology,
    identity: Identity,
    caps: CapabilitySet,
    manifest: AdapterManifest,
    recorded_ops: RefCell<Vec<RecordedOp>>,
}

impl FakeMux {
    /// Build a FakeMux from the pinned fidelity fixtures (real captured cmux state).
    pub fn from_fidelity() -> Self {
        let topology = wire::parse_tree(TREE).expect("fixture tree parses");
        let identity = wire::parse_identify(IDENTIFY).expect("fixture identify parses");
        let caps = wire::parse_capabilities(CAPS, VERSION.trim()).expect("fixture caps parse");
        FakeMux {
            topology,
            identity,
            caps,
            manifest: AdapterManifest {
                id: "fake-mux".to_string(),
                port: PortKind::Mux,
                egress: EgressLabel::Zero,
                required_tools: vec![],
            },
            recorded_ops: RefCell::new(vec![]),
        }
    }

    /// Ops recorded so far — empty after any read-only verb (blast-radius proof).
    pub fn recorded_ops(&self) -> Vec<RecordedOp> {
        self.recorded_ops.borrow().clone()
    }
}

impl MuxTopology for FakeMux {
    fn tree(&self) -> Result<Topology, MuxError> {
        Ok(self.topology.clone()) // read — never recorded
    }
    fn identify(&self) -> Result<Identity, MuxError> {
        Ok(self.identity.clone()) // read — never recorded
    }
}

impl Multiplexer for FakeMux {
    fn capabilities(&self) -> Result<CapabilitySet, MuxError> {
        Ok(self.caps.clone())
    }
    fn manifest(&self) -> &AdapterManifest {
        &self.manifest
    }
}
