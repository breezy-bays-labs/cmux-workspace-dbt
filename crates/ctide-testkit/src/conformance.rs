//! The generic port conformance kit — the SAME assertions run against every
//! `Multiplexer` impl (FakeMux always; the live `CmuxCliAdapter` behind `--ignored`;
//! the recorded replay server in the next slice, g7). Getting `doctor` green across
//! impls is the proof the third impl is the testing story (design-plan §4).

use ctide_core::Multiplexer;

/// Expectations a conforming multiplexer must satisfy. Kept loose enough to hold
/// for both a fixed fixture and a live session (whose exact counts differ).
pub struct FixtureSet {
    pub min_windows: usize,
    pub require_focus: bool,
    pub required_rpc: String,
}

impl FixtureSet {
    /// The invariants any healthy cmux session satisfies.
    pub fn healthy_session() -> Self {
        FixtureSet {
            min_windows: 1,
            require_focus: true,
            required_rpc: "system.tree".to_string(),
        }
    }
}

/// Assert a multiplexer satisfies the port contract. Panics (test-style) on breach.
pub fn conform_multiplexer(m: &dyn Multiplexer, fx: &FixtureSet) {
    let tree = m.tree().expect("tree() must succeed (read-only)");
    assert!(
        tree.windows.len() >= fx.min_windows,
        "expected >= {} window(s), got {}",
        fx.min_windows,
        tree.windows.len()
    );

    let id = m.identify().expect("identify() must succeed");
    if fx.require_focus {
        assert!(
            id.focused.is_some(),
            "a healthy session has a focused workspace"
        );
    }

    let caps = m.capabilities().expect("capabilities() must succeed");
    assert!(
        caps.rpcs.contains(&fx.required_rpc),
        "capability set must advertise {}",
        fx.required_rpc
    );
    assert!(!caps.version.is_empty(), "version must be populated");

    assert!(
        !m.manifest().id.is_empty(),
        "manifest must identify the adapter"
    );
}
