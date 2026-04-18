# ADR-0005: Single active deployment with switcher

- **Status:** Accepted
- **Date:** 2026-04-17

## Context

Some users have multiple Coder deployments (e.g., personal + work). Options for the UI:

1. **Multi-deployment, single workspace list** — show workspaces from all deployments mixed together. Cluttered, requires per-row deployment badge.
2. **Multi-deployment, segmented list** — switcher at top filters list. Adds complexity to every screen.
3. **Single active deployment, switcher in Settings** — one deployment at a time; switching is explicit. Multiple deployments retained in Keychain for one-tap switch-back.

## Decision

**Option 3.** One active deployment at a time. Known deployments stored in Keychain. Switcher lives in Settings.

## Consequences

**Positive:**
- Simpler state model (`currentDeployment: Deployment?` in `AppFeature`).
- Less cognitive load for the common case (one deployment).
- Switching is explicit, so no confusion about which deployment a terminal is connected to.

**Negative:**
- Power users with multiple deployments need to switch explicitly (~3 taps).
- Can't run terminals from two deployments side-by-side on iPad.

**Mitigations:**
- Switcher is fast (re-validates token in background, falls back to login if expired).
- "Recent deployments" list in Settings is sorted by last-used.
- If user demand warrants, post-v1 can add a multi-deployment iPad mode that supersedes this.
