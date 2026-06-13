//! `ctide-testkit` — ctide's test infrastructure (not shipped).
//!
//! Home of `FakeMux` (the third `Multiplexer` impl, and *the* testing story —
//! design-plan §4), the generated `fidelity/<cmux-version>/` fixtures, the
//! recorded-socket replay server (g7), and the generic port conformance kit
//! (`conform_multiplexer`, …). Excluded from the production CRAP aggregate by
//! design (test infra). The FakeMux + conformance kit land with `ctide doctor`
//! at R1. Empty by design at R0.
#![forbid(unsafe_code)]

#[cfg(test)]
mod exclude_dev_carveout {
    //! Proves the deny.toml `exclude-dev = true` carve-out: tokio (banned from
    //! the shipped graph) is usable as a DEV dependency. If this compiles and
    //! `cargo deny check` stays green, the carve-out works. The real consumer of
    //! the dev async stack is cucumber-rs, which arrives at R1.
    #[tokio::test]
    async fn tokio_is_available_dev_only() {
        let two = tokio::spawn(async { 1 + 1 }).await.expect("join");
        assert_eq!(two, 2);
    }
}
