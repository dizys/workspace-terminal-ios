# Coder Terminal for iOS

A native iOS / iPadOS app for [Coder](https://github.com/coder/coder) workspaces. First-class terminal experience: full ANSI/Unicode rendering, special keys, touch-native gestures, devcontainer support.

> **Status:** in development. Pre-v1.

> **Note:** unofficial third-party app. Not affiliated with Coder Inc.

## Why

Coder's web terminal works in a pinch but is painful on iPhone/iPad: no Ctrl/Alt/Esc/Tab/F-keys, broken Unicode/Powerline rendering, jittery touch scrolling, no reconnect, no multi-tab. This app fixes all of that.

## Features (planned)

- Native xterm-256, true color, Unicode 15, Powerline glyphs, emoji, sixel
- Floating modifier bar (Esc, Tab, Ctrl, Alt, arrows, F-keys)
- Two-finger scrollback, pinch-zoom, long-press selection with magnifier
- Reconnecting PTY — survives network blips
- OIDC, GitHub OAuth, password auth (whatever your deployment supports)
- Devcontainer / docker-in-docker sub-agent support
- Universal app: iPhone + iPad with multi-window, Stage Manager, hardware keyboard
- Themes: Tokyo Night, Catppuccin, Solarized, Dracula, Gruvbox, custom JSON
- Zero telemetry by default

## Documentation

See [`docs/`](docs/):

- [Vision](docs/vision.md)
- [Engineering Design](docs/engineering-design.md)
- [UX Design](docs/ux-design.md)
- [Coder Integration](docs/coder-integration.md)
- [Security & Privacy](docs/security-privacy.md)
- [Performance Budget](docs/performance.md)
- [Testing Strategy](docs/testing.md)
- [DX & CI/CD](docs/dx-cicd.md)
- [Roadmap](docs/roadmap.md)
- [Open Questions](docs/open-questions.md)
- [Architecture Decision Records](docs/adr/)

## Local development

Prerequisites: macOS, Xcode 16+. Toolchain versions are pinned via `mise.toml`.

```bash
mise install              # installs Tuist, SwiftFormat, SwiftLint, lefthook
tuist install             # fetch SwiftPM deps
tuist generate            # generate Xcode workspace
open CoderTerminal.xcworkspace
```

Pre-commit hooks (formatting + lint) are installed via:

```bash
lefthook install
```

## Reporting bugs / requesting features

Public issue tracker: <https://github.com/dizys/coder-terminal-ios/issues>

Security issues should NOT be filed publicly. Email: see Settings → About → Security in the app.

## License

All rights reserved. This is a closed-source commercial app. The contents of this repository are proprietary; no license is granted to use, copy, modify, or distribute the source code or assets.

The `docs/` directory is provided for transparency about design decisions and is not licensed for redistribution.
