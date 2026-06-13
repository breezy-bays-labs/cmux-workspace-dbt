//! `CmuxCliAdapter` — the I/O shell that drives the real cmux via its CLI.
//!
//! Read-only for `doctor`: it shells `cmux tree --all`, `cmux identify`,
//! `cmux capabilities`, and `cmux version`, then hands the strings to the pure
//! parsers in [`crate::wire`]. The richer v2-socket transport (and its recorded
//! replay-server CI tier, g7) is the next slice; the CLI path works today and is
//! the fallback transport thereafter.

use std::process::Command;

use ctide_core::domain::{
    AdapterManifest, CapabilitySet, EgressLabel, Identity, PortKind, Topology,
};
use ctide_core::{Multiplexer, MuxError, MuxTopology};

use crate::wire;

/// Drives cmux through its CLI binary (default `cmux`, override via `CTIDE_CMUX_BIN`).
pub struct CmuxCliAdapter {
    bin: String,
    manifest: AdapterManifest,
}

impl Default for CmuxCliAdapter {
    fn default() -> Self {
        Self::new()
    }
}

impl CmuxCliAdapter {
    pub fn new() -> Self {
        let bin = std::env::var("CTIDE_CMUX_BIN").unwrap_or_else(|_| "cmux".to_string());
        CmuxCliAdapter {
            bin,
            manifest: AdapterManifest {
                id: "cmux-cli".to_string(),
                port: PortKind::Mux,
                // The cmux adapter speaks to a local unix socket via the local CLI —
                // no network egress of its own (the substrate's telemetry is audited
                // separately in doctor's substrate section).
                egress: EgressLabel::Zero,
                required_tools: vec!["cmux".to_string()],
            },
        }
    }

    /// Run `cmux <args...>` and return stdout, mapping every failure to a typed error.
    fn run(&self, args: &[&str]) -> Result<String, MuxError> {
        let out = Command::new(&self.bin)
            .args(args)
            .output()
            .map_err(|e| MuxError::Unreachable(format!("{} {}: {e}", self.bin, args.join(" "))))?;
        if !out.status.success() {
            let stderr = String::from_utf8_lossy(&out.stderr);
            return Err(MuxError::CommandFailed(format!(
                "{} {} -> {}: {}",
                self.bin,
                args.join(" "),
                out.status,
                stderr.trim()
            )));
        }
        Ok(String::from_utf8_lossy(&out.stdout).into_owned())
    }
}

impl MuxTopology for CmuxCliAdapter {
    fn tree(&self) -> Result<Topology, MuxError> {
        let json = self.run(&["tree", "--all", "--id-format", "both", "--json"])?;
        wire::parse_tree(&json)
    }

    fn identify(&self) -> Result<Identity, MuxError> {
        let json = self.run(&["identify", "--json"])?;
        wire::parse_identify(&json)
    }
}

impl Multiplexer for CmuxCliAdapter {
    fn capabilities(&self) -> Result<CapabilitySet, MuxError> {
        let caps = self.run(&["capabilities"])?;
        let version = wire::parse_version(&self.run(&["version"])?);
        wire::parse_capabilities(&caps, &version)
    }

    fn manifest(&self) -> &AdapterManifest {
        &self.manifest
    }
}
