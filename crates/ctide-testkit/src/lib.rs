//! `ctide-testkit` — ctide's test infrastructure (not shipped).
//!
//! Home of [`fake_mux::FakeMux`] (the third `Multiplexer` impl, and *the* testing
//! story — design-plan §4), the generic port [`conformance`] kit, and the
//! `fidelity/<version>/` fixtures. The recorded-socket replay server (g7) lands in
//! the next slice. Excluded from the production CRAP aggregate by design (test infra).
#![forbid(unsafe_code)]

pub mod conformance;
pub mod fake_mux;

pub use conformance::{FixtureSet, conform_multiplexer};
pub use fake_mux::FakeMux;

#[cfg(test)]
mod tests {
    use super::*;

    // gate 2: the conformance suite is green against FakeMux (the always-on impl).
    #[test]
    fn fakemux_conforms() {
        let mux = FakeMux::from_fidelity();
        conform_multiplexer(&mux, &FixtureSet::healthy_session());
    }

    // blast-radius: a read-only verb records ZERO mutating ops on the fake.
    #[test]
    fn reads_record_no_mutations() {
        use ctide_core::{Multiplexer, MuxTopology};
        let mux = FakeMux::from_fidelity();
        let _ = mux.tree().unwrap();
        let _ = mux.identify().unwrap();
        let _ = mux.capabilities().unwrap();
        assert!(
            mux.recorded_ops().is_empty(),
            "doctor's reads must mutate nothing"
        );
    }

    // The live tier (design-plan §3): the SAME conformance suite against real cmux.
    // #[ignore] — needs a running cmux; run with `--ignored` for fidelity/drift checks.
    // Read-only (tree/identify/capabilities), safe against a live session.
    #[test]
    #[ignore = "tracked: cmux-terminal-ide#36 — live tier; run with --ignored against a real cmux"]
    fn live_cmux_conforms() {
        let mux = ctide_mux_cmux::CmuxCliAdapter::new();
        conform_multiplexer(&mux, &FixtureSet::healthy_session());
    }

    mod exclude_dev_carveout {
        //! Proves the deny.toml `exclude-dev = true` carve-out: tokio (banned from
        //! the shipped graph) is usable as a DEV dependency. If this compiles and
        //! `cargo deny check` stays green, the carve-out works.
        #[tokio::test]
        async fn tokio_is_available_dev_only() {
            let two = tokio::spawn(async { 1 + 1 }).await.expect("join");
            assert_eq!(two, 2);
        }
    }
}
