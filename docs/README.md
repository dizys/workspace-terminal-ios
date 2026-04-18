# Workspace Terminal — Docs

Native iOS/iPadOS app for [Coder](https://github.com/coder/coder) workspaces. First-class terminal experience: full ANSI/Unicode rendering, special keys, touch-native gestures, devcontainer support.

## Index

- [Vision & Product Pillars](vision.md) — what we're building and why
- [Engineering Design](engineering-design.md) — architecture, modules, tech choices
- [UX Design](ux-design.md) — screens, interactions, hardware keyboard, iPad
- [Coder Integration](coder-integration.md) — API surfaces, PTY, OIDC, devcontainers
- [Security & Privacy](security-privacy.md) — credentials, certs, telemetry stance
- [Performance Budget](performance.md) — latency/memory/energy targets
- [Testing Strategy](testing.md) — unit, snapshot, integration, a11y
- [DX & CI/CD](dx-cicd.md) — tooling, workflows, release process
- [Roadmap](roadmap.md) — milestones M0–M5
- [Open Questions](open-questions.md) — decisions still pending

## Architecture Decision Records

ADRs live in [`adr/`](adr/). One per non-obvious decision.

- [ADR-0001: TCA for state management](adr/0001-tca.md)
- [ADR-0002: SwiftTerm as terminal emulator](adr/0002-swiftterm.md)
- [ADR-0003: PTY over WebSocket (no SSH for v1)](adr/0003-pty-over-websocket.md)
- [ADR-0004: Closed-source, paid distribution](adr/0004-closed-source-paid.md)
- [ADR-0005: Single active deployment with switcher](adr/0005-single-deployment-switcher.md)
- [ADR-0006: OIDC required at v1](adr/0006-oidc-v1.md)
- [ADR-0007: Universal app from day 1](adr/0007-universal-app.md)
- [ADR-0008: Tuist for project generation](adr/0008-tuist.md)
- [ADR-0009: AGPL-3.0 source + paid App Store distribution](adr/0009-agpl-3-paid.md) — supersedes ADR-0004
