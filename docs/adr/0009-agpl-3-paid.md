# ADR-0009: AGPL-3.0 source + paid App Store distribution

- **Status:** Accepted
- **Date:** 2026-04-18
- **Supersedes:** [ADR-0004](0004-closed-source-paid.md) (closed-source, paid)

## Context

ADR-0004 chose closed-source + paid. Reconsidered after one day of M0 work.

The product builds on top of Coder, which is itself open-source under AGPL-3.0. The community is open-source-native and is more likely to trust, contribute to, and recommend an open-source companion app. Closed-source signals "untrusted black box wrapped around my dev environment" — the opposite of the brand we want.

The economic concern from ADR-0004 ("how does this fund itself") is addressable without closing the source: sell the convenience of the App Store binary. Anyone can build from source if they want; most users will pay for the one-tap install + auto-update.

This is exactly Coder's own model: AGPL source on GitHub, commercial Coder Enterprise binaries.

## Decision

**License source under AGPL-3.0. Sell the binary on the App Store.**

- Public GitHub repo at https://github.com/dizys/coder-terminal-ios — full source, AGPL-3.0
- App Store distribution remains the official paid channel
- Commercial reuse / re-distribution requires a separate license (standard dual-licensing)

## Consequences

**Positive:**
- Trust signal to a security-conscious developer audience.
- Community contributions become possible (bug fixes, new themes, accessibility improvements).
- Aligns with Coder's own licensing — easy story to tell.
- Researchers / enterprise security reviews can audit the source before approving.
- AGPL specifically blocks competitors from making a closed-source SaaS clone.

**Negative:**
- Anyone *can* build from source and sideload, bypassing payment. In practice this is friction enough that most users will buy.
- Code review of community PRs becomes ongoing work.
- License compatibility check: every dependency must be AGPL-compatible (TCA is MIT — fine; SwiftTerm is MIT — fine; future deps must be checked).
- AGPL has a reputation that makes some commercial users nervous; need to be clear that *using the App Store app* doesn't trigger any AGPL obligations on the user's part — only modifying-and-redistributing does.

**Mitigations:**
- README clearly explains the dual model: free to use the source under AGPL, App Store for convenience.
- Contributor License Agreement (CLA) optional for v1 — revisit if commercial dual-licensing becomes a real revenue path.
- App Store description includes the "open source on GitHub" angle as a feature, not a footnote.
- Maintain a simple support email for license questions to defuse enterprise FUD.

## Open follow-ups

- Branding: should the project name include "Open" (e.g., "OpenCoderTerminal")? Probably no — the App Store name is the canonical product name; the repo can stay `coder-terminal-ios`.
- CONTRIBUTING.md: write before opening to community PRs.
- CLA decision: not needed for v1, decide when first non-trivial PR arrives.
