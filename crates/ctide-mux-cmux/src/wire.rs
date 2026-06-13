//! The cmux wire format — serde types + PURE parse functions, fixture-tested
//! against real captured cmux output (`fidelity/<version>/`, never hand-authored).
//!
//! This is the quirk vault: every hard-won cmux fact is encoded here behind a
//! `// fact:` comment + a fixture test, and lives nowhere else (the `quirk-vault`
//! lint enforces it). Parsing is pure (string → domain), so it is unit-tested
//! without a live cmux; the I/O shell that fetches the strings is `adapter.rs`.

use ctide_core::MuxError;
use ctide_core::domain::{CapabilitySet, Identity, Topology, WindowNode, WorkspaceNode};
use serde::Deserialize;

// ── tree --all --id-format both --json ──────────────────────────────────────
// fact: cmux `tree --all` is the ONLY global enumeration of windows/workspaces.
// `workspace.list` (and `rpc workspace.list`) is FOCUSED-WINDOW-ONLY — its window
// params are ignored — so ctide never uses it for enumeration. There is, by design,
// no scoped-listing method exposed on the port.
#[derive(Debug, Deserialize)]
struct WireTree {
    #[serde(default)]
    windows: Vec<WireWindow>,
}

#[derive(Debug, Deserialize)]
struct WireWindow {
    id: String,
    #[serde(rename = "ref")]
    ref_hint: Option<String>,
    #[serde(default)]
    workspaces: Vec<WireWorkspace>,
}

#[derive(Debug, Deserialize)]
struct WireWorkspace {
    id: String,
    #[serde(rename = "ref")]
    ref_hint: Option<String>,
    description: Option<String>,
    #[serde(default)]
    panes: Vec<WirePane>,
    // fact: a workspace node in `tree` has NO `current_directory` — that field is
    // only on `workspace.list`. A verb that needs the cwd merges it from a
    // secondary call inside the adapter. `doctor` does not, so cwd stays None.
}

#[derive(Debug, Deserialize)]
struct WirePane {
    #[serde(default)]
    surface_ids: Vec<String>,
}

/// fact: cmux entity ids are UUIDs (case-insensitive); ctide normalizes them to
/// uppercase on construction so a UUID compares equal regardless of source casing.
/// Positional refs ("workspace:N") are display hints only — they die across restarts.
fn norm_id(id: &str) -> String {
    id.to_uppercase()
}

/// Parse `cmux tree --all --id-format both --json` into the global [`Topology`].
pub fn parse_tree(json: &str) -> Result<Topology, MuxError> {
    let wire: WireTree = serde_json::from_str(json).map_err(|e| MuxError::Parse(e.to_string()))?;
    let windows = wire
        .windows
        .into_iter()
        .map(|w| WindowNode {
            id: norm_id(&w.id),
            ref_hint: w.ref_hint,
            workspaces: w.workspaces.into_iter().map(workspace_from_wire).collect(),
        })
        .collect();
    Ok(Topology { windows })
}

fn workspace_from_wire(w: WireWorkspace) -> WorkspaceNode {
    let surface_ids = w
        .panes
        .into_iter()
        .flat_map(|p| p.surface_ids.into_iter().map(|s| norm_id(&s)))
        .collect();
    WorkspaceNode {
        id: norm_id(&w.id),
        ref_hint: w.ref_hint,
        description: w.description,
        current_directory: None,
        surface_ids,
    }
}

// ── identify --json ─────────────────────────────────────────────────────────
#[derive(Debug, Deserialize)]
struct WireIdentify {
    caller: Option<WireRef>,
    focused: Option<WireRef>,
}

#[derive(Debug, Deserialize)]
struct WireRef {
    workspace_id: Option<String>,
    workspace_ref: Option<String>,
}

impl WireRef {
    /// Prefer the UUID; fall back to the positional ref for display.
    fn workspace(self) -> Option<String> {
        self.workspace_id
            .map(|id| norm_id(&id))
            .or(self.workspace_ref)
    }
}

/// Parse `cmux identify --json` into caller/focused workspace.
pub fn parse_identify(json: &str) -> Result<Identity, MuxError> {
    let wire: WireIdentify =
        serde_json::from_str(json).map_err(|e| MuxError::Parse(e.to_string()))?;
    Ok(Identity {
        caller: wire.caller.and_then(WireRef::workspace),
        focused: wire.focused.and_then(WireRef::workspace),
    })
}

// ── capabilities ──────────────────────────────────────────────────────────────
// fact: `cmux capabilities` returns {access_mode, methods:[...]} — the advertised
// RPC surface. The version is NOT in that payload; it comes from `cmux version`
// ("cmux X.Y.Z (build) [sha]"), so the adapter combines the two.
#[derive(Debug, Deserialize)]
struct WireCaps {
    #[serde(default)]
    methods: Vec<String>,
}

/// Parse `cmux capabilities` (+ a separately-fetched version) into [`CapabilitySet`].
pub fn parse_capabilities(json: &str, version: &str) -> Result<CapabilitySet, MuxError> {
    let wire: WireCaps = serde_json::from_str(json).map_err(|e| MuxError::Parse(e.to_string()))?;
    Ok(CapabilitySet {
        rpcs: wire.methods.into_iter().collect(),
        version: version.to_string(),
    })
}

/// Parse the version token out of `cmux version` (`cmux 0.64.15 (95) [sha]`).
pub fn parse_version(version_output: &str) -> String {
    version_output
        .split_whitespace()
        .nth(1)
        .unwrap_or("unknown")
        .to_string()
}

#[cfg(test)]
mod fixture_tests {
    //! Fixture tests against REAL captured cmux output (fidelity/<version>/),
    //! proving the parsers handle the actual wire shape — the quirk-vault contract.
    use super::*;

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

    #[test]
    fn parses_real_tree_globally() {
        let topo = parse_tree(TREE).expect("tree parses");
        assert!(!topo.windows.is_empty(), "captured tree has >=1 window");
        assert!(
            topo.workspace_count() >= 1,
            "captured tree has >=1 workspace"
        );
        // ids are normalized uppercase UUIDs.
        let first = &topo.windows[0].id;
        assert_eq!(first, &first.to_uppercase());
    }

    #[test]
    fn parses_real_identify() {
        let id = parse_identify(IDENTIFY).expect("identify parses");
        // the captured session has a focused workspace.
        assert!(id.focused.is_some());
    }

    #[test]
    fn parses_real_capabilities() {
        let caps = parse_capabilities(CAPS, "0.64.15").expect("capabilities parse");
        assert!(
            caps.rpcs.contains("system.tree"),
            "advertises the system.tree RPC"
        );
        assert_eq!(caps.version, "0.64.15");
    }

    #[test]
    fn version_token_extracted() {
        assert_eq!(parse_version("cmux 0.64.15 (95) [693081782]"), "0.64.15");
        assert_eq!(parse_version("garbage"), "unknown");
    }
}
