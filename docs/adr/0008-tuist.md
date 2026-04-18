# ADR-0008: Tuist for project generation

- **Status:** Accepted
- **Date:** 2026-04-17

## Context

`.xcodeproj` files are infamous for merge conflicts and inscrutable diffs. Options:

1. **Hand-managed `.xcodeproj`** — works, but every PR risks conflict.
2. **XcodeGen** — YAML manifest, generates `.xcodeproj`. Lightweight.
3. **Tuist** — Swift manifest (`Project.swift`), generates `.xcodeproj` and `.xcworkspace`. More opinionated, supports caching, modular projects, signing helpers.
4. **Pure SwiftPM** — no `.xcodeproj` at all. Limited; can't easily configure entitlements, capabilities, App Store metadata.

## Decision

**Tuist.** `.xcodeproj` is gitignored; regenerated from `Tuist/Project.swift` on demand.

## Consequences

**Positive:**
- No more `.xcodeproj` merge conflicts.
- Project structure is code-reviewable Swift.
- Tuist's cache makes incremental builds faster across team.
- Modular project setup matches our SwiftPM package layout.

**Negative:**
- One more tool to install (`mise.toml` handles this).
- Contributors unfamiliar with Tuist face a small learning curve.
- Couples us to Tuist's release cadence.

**Mitigations:**
- `tuist generate` is one command, documented in README.
- mise pins the Tuist version so everyone is on the same release.
- If Tuist becomes a problem, migration to XcodeGen or hand-managed is straightforward (project structure is preserved).
