# ADR-0004: Closed-source, paid distribution

- **Status:** Accepted
- **Date:** 2026-04-17

## Context

Coder itself is open-source (AGPL). The app could be open-source (free or paid) or closed-source (paid).

## Decision

**Closed-source, paid app on the iOS App Store.** Public GitHub repo for issue tracking only (`coderterminal-issues`), source repo private.

## Consequences

**Positive:**
- Funds ongoing development.
- Easier to maintain quality bar without coordinating with external contributors.
- Faster iteration without API stability promises to non-paying users.

**Negative:**
- Smaller addressable market than free.
- Some Coder users will fork the open-source web terminal instead.
- Open-source advocates in the Coder community may view this critically.

**Mitigations:**
- Be transparent: "unofficial third-party app, paid because it's how I keep maintaining it".
- Public issues repo so the user community can still report bugs and request features.
- Free trial via App Store's "1-week free trial" mechanism if subscription model is chosen.
- Generous refund policy if users find it doesn't work for their setup.

## Pricing model (deferred)

See [open-questions.md](../open-questions.md). Choosing between one-time purchase and subscription. Current lean: one-time purchase for v1.
