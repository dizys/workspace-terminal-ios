# ADR-0002: SwiftTerm as terminal emulator

- **Status:** Accepted
- **Date:** 2026-04-17

## Context

Building a terminal emulator from scratch is a multi-year effort. ANSI/CSI/OSC parsing, true color, Unicode width handling, scrollback, mouse tracking, sixel/Kitty image protocols — all non-trivial.

Options considered:

1. **Build from scratch** — full control, total cost.
2. **WebView + xterm.js** — fast to integrate, but defeats the "native-first" pillar (laggy input, no native gestures, no first-class iOS keyboard handling). This is exactly what the Coder web terminal does today and exactly what we're trying to escape.
3. **SwiftTerm** (Miguel de Icaza) — production-grade Swift xterm emulator. Ships in Termius and other commercial apps. CSI/SGR/OSC, true color, mouse, sixel, image protocol, 24-bit color, Unicode 15.

## Decision

Use SwiftTerm.

## Consequences

**Positive:**
- Years of battle-testing in production apps.
- Native rendering, first-class touch + hardware keyboard event delivery.
- Active maintenance; permissive license (MIT).
- Supports advanced features (sixel, image protocol) that web terminals lack.

**Negative:**
- External dependency we don't control.
- API is UIKit-flavored; needs `UIViewRepresentable` wrapper for SwiftUI integration.
- Some advanced theming requires diving into SwiftTerm internals.

**Mitigations:**
- Wrap all SwiftTerm usage inside `TerminalUI` package — only one place touches it.
- If SwiftTerm becomes unmaintained, we can fork. Reasonable contingency.
