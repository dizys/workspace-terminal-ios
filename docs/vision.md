# Vision & Product Pillars

## Problem

[Coder](https://github.com/coder/coder) is a great self-hosted cloud-development platform. The web terminal works in a pinch but on iPhone/iPad it's painful:

- Can't press Ctrl, Alt, Esc, Tab, F-keys, arrow keys reliably — the iOS software keyboard doesn't expose them.
- Renders only basic ANSI; Powerline glyphs, true color, emoji, box-drawing characters break.
- Touch scrolling is jittery and hijacks page scroll.
- No multi-tab, no persistent reconnect when network blips.
- No quick way to switch between workspaces or devcontainers.

## Vision

A **native iOS/iPadOS app** that makes Coder workspaces feel as good on a phone or tablet as they do in iTerm2 on a Mac.

## Pillars

1. **Native-first.** SwiftUI + UIKit interop where it matters. No web views in the hot path. (The in-app dev browser at M3.5 is a deliberate exception, scoped to forwarded workspace ports.)
2. **Terminal correctness.** Full xterm-256, true color, Unicode 15, Powerline glyphs, emoji, box-drawing, sixel — not the degraded subset the web terminal renders.
3. **Touch ergonomics that fit a terminal.** Floating modifier bar, two-finger scrollback, pinch-zoom font, long-press selection with magnifier, sticky Ctrl/Alt.
4. **One tap to a working shell — and to a forwarded port.** Cold-start → connected PTY in under ~2s. One tap from the workspace detail screen to a running dev server in the in-app browser.
5. **Self-hosted respect.** Arbitrary URLs, custom CAs, OIDC providers, no phone-home.
6. **iPad as a real workstation.** Universal app, multi-window, hardware keyboard support, Stage Manager friendly. Side-by-side terminal + browser is a first-class layout.
7. **Port forwarding + dev browser.** Run dev servers, internal UIs, Jupyter, Storybook inside the workspace; view them from the iPhone/iPad with auto-discovered ports, hot-reload tolerance, and a DevTools-lite panel. See [ports-and-browser.md](ports-and-browser.md).

## Non-goals (v1)

- **Not** a general SSH client. We use Coder's PTY API, not raw SSH.
- **Not** a replacement for the Coder web dashboard. We don't surface workspace templates, admin settings, audit logs, etc. — only what an end user does day-to-day.
- **Not** an editor. There are great mobile editors; we link out, we don't try to be one.
- **Not** Android. iOS/iPadOS only for v1.
- **Not** macOS. Possible follow-up via Mac Catalyst, but out of scope for v1.

## Target user

Developers who:

- Use Coder daily for cloud dev environments
- Want to do quick fixes, run tests, restart services from their phone or iPad
- Are willing to pay for a polished, telemetry-free experience
