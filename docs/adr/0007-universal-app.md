# ADR-0007: Universal app (iPhone + iPad) from day 1

- **Status:** Accepted
- **Date:** 2026-04-17

## Context

Options:

1. **iPhone-only at v1**, iPad as a follow-up.
2. **Universal at v1** (iPhone + iPad in one app, with adaptive layouts).
3. **Two separate apps** (iPhone, iPad-Pro) — uncommon, generally a mistake.

iPad users are a significant chunk of mobile-developer-tooling users. iPad + Magic Keyboard is an actual workstation for many users; a polished terminal on iPad is a real differentiator.

## Decision

**Universal app from day 1.** Adaptive layouts via `NavigationSplitView` and size classes. iPad-specific polish (multi-window, hardware keyboard, pointer support, Stage Manager) shipped in M3.

## Consequences

**Positive:**
- One app, one bundle ID, one App Store listing.
- iPad users are first-class from launch.
- Strong differentiator vs the web terminal on iPad.

**Negative:**
- More layout work in every screen (sidebar vs stack, 3-col vs 2-col).
- More device matrix in testing (iPhone SE, iPhone 15 Pro Max, iPad mini, iPad Pro 12.9").
- Multi-window adds complexity in M3.

**Mitigations:**
- Use SwiftUI's adaptive primitives (`NavigationSplitView`, `Layout`, size classes) rather than hand-rolling.
- Snapshot tests at fixed device sizes catch regressions cheaply.
- iPad-specific features (multi-window) are deferred to M3, not blocking M0–M2.
