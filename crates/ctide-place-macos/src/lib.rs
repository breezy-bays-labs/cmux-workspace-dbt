//! `ctide-place-macos` — macOS implementation of ctide-core's `Placement` port.
//!
//! Monitor detection + per-role window placement (today's `lib/cide-place.swift`,
//! ported to `objc2`: CoreGraphics `CGDisplayBounds`, AppKit `NSScreen`, the
//! Accessibility API, AeroSpace cooperation). `cfg(target_os = "macos")`; a
//! `NoopPlacement` in `ctide-core`/`ctide-adapters` keeps Linux unprecluded.
//! Lands at R3. Empty by design at R0.
//!
//! Note: this crate will need `unsafe` for the objc2 FFI, so (unlike the other
//! crates) it does not `forbid(unsafe_code)` — it will `deny(unsafe_op_in_unsafe_fn)`
//! and contain unsafe to the FFI boundary when the code lands.
