//! `ctide-dbt` — the dbt-vertical adapter (Warehouse + DbtReview ports).
//!
//! Adapter CODE only: harlequin warehouse access, the cute-dbt review bridge,
//! compiled-SQL/lineage surfaces. The dbt IDE *itself* is a data recipe over the
//! base (workspace type = data, not a code fork — design-plan §7). Stub at R0;
//! earns code at R5 (the dbt vertical). Empty by design at R0.
#![forbid(unsafe_code)]
