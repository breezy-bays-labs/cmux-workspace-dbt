//! Verb implementations (the thin I/O shells). Each gathers port reads, calls the
//! pure `plan_*` use-case in ctide-core, and renders the result.
pub mod doctor;
