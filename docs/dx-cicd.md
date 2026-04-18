# DX & CI/CD

## Local dev setup

```
mise install              # pins Xcode, Swift, Tuist, SwiftFormat, SwiftLint versions
tuist install             # fetch SwiftPM deps
tuist generate            # produce .xcworkspace
open *.xcworkspace
```

`mise.toml` pins:
- Xcode 16+ (via `xcodes`)
- Tuist
- SwiftFormat
- SwiftLint
- lefthook

## Repo layout

```
.
├── App/                   # App target
├── Packages/              # SwiftPM packages (see engineering-design.md)
├── Tuist/                 # Project.swift, Workspace.swift, ProjectDescriptionHelpers
├── docs/                  # this folder
├── fastlane/              # release lanes
├── .github/
│   ├── workflows/         # CI
│   └── ISSUE_TEMPLATE/
├── .swiftformat
├── .swiftlint.yml
├── lefthook.yml
└── mise.toml
```

## Pre-commit (lefthook)

```yaml
pre-commit:
  parallel: true
  commands:
    swiftformat:
      glob: "*.swift"
      run: swiftformat {staged_files}
    swiftlint:
      glob: "*.swift"
      run: swiftlint lint --quiet --strict {staged_files}
```

## CI (GitHub Actions)

- **On PR**:
  - `lint` — SwiftFormat + SwiftLint (strict)
  - `build` — `tuist generate` + `xcodebuild build` for iOS Simulator
  - `test` — matrix across iOS 17 + iOS 18 simulators (iPhone 15 Pro, iPad Pro 12.9")
  - `coverage` — `xccov` against gates from [testing.md](testing.md)
  - `integration` — spin up `coder/coder` Docker, run integration suite (gated, 10min timeout)
- **On main**:
  - All of the above
  - `archive` — produce signed `.ipa` artifact
  - `testflight` — upload to TestFlight via Fastlane on tagged commits

## Release (Fastlane)

Lanes:
- `lane :test` — run unit + snapshot
- `lane :beta` — bump build, archive, upload to TestFlight, post Slack
- `lane :release` — submit to App Store
- `lane :screenshots` — generate App Store screenshots for iPhone + iPad on a fixed device matrix

## Secrets management

- `MATCH_PASSWORD`, `APP_STORE_CONNECT_API_KEY` in GitHub Actions secrets.
- Code signing via `match` (private repo for certs).
- No secrets in source.

## ADRs

Every non-obvious decision gets a one-pager in [`docs/adr/`](adr/). Format: context, decision, consequences. Numbered sequentially. Never edit a merged ADR — supersede with a new one.

## Issue templates

- Bug report (with deployment version, iOS version, app version, reproduction steps)
- Feature request
- Security report → routed to private email, never GitHub issues

PR template: tests added · snapshot deltas reviewed · telemetry-free verified · ADR linked if relevant.

## Observability (dev only)

- Verbose `os.Logger` subsystems: `app.workspaceterminal.api`, `.pty`, `.auth`, `.ui`.
- Filter in Console.app during dev.
- All redacted in release builds.
