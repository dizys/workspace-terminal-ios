#!/usr/bin/env bash
# Local equivalent of the CI workflow. Run before pushing.
# Usage:  bin/check.sh                 # everything
#         bin/check.sh lint            # lint only
#         bin/check.sh packages        # per-package swift test only
#         bin/check.sh app             # tuist generate + xcodebuild build/test
#
# Exits non-zero on first failure. Run from repo root.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PACKAGES=(
  CoderAPI
  PTYTransport
  Auth
  DesignSystem
  TerminalUI
  StoreKitClient
  WorkspaceFeature
  TerminalFeature
  AppFeature
  TestSupport
)

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; }

lint() {
  step "Lint (SwiftFormat + SwiftLint)"
  if ! command -v swiftformat >/dev/null; then
    err "swiftformat not found. Run: mise install"
    exit 127
  fi
  if ! command -v swiftlint >/dev/null; then
    err "swiftlint not found. Run: mise install"
    exit 127
  fi
  swiftformat --lint .
  ok "SwiftFormat clean"
  swiftlint lint --strict --quiet
  ok "SwiftLint clean"
}

packages() {
  step "Per-package swift test"
  for pkg in "${PACKAGES[@]}"; do
    printf '\n--- %s ---\n' "$pkg"
    (cd "Packages/$pkg" && swift test --parallel)
    ok "$pkg tests pass"
  done
}

app() {
  step "Tuist generate + xcodebuild"
  if ! command -v tuist >/dev/null; then
    err "tuist not found. Run: mise install"
    exit 127
  fi
  tuist install
  tuist generate --no-open
  xcodebuild \
    -workspace WorkspaceTerminal.xcworkspace \
    -scheme WorkspaceTerminal \
    -configuration Debug \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath build \
    -skipMacroValidation \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build | (command -v xcbeautify >/dev/null && xcbeautify || cat)
  ok "App build clean"
}

case "${1:-all}" in
  lint)     lint ;;
  packages) packages ;;
  app)      app ;;
  all)      lint; packages; app ;;
  *)        err "Unknown subcommand: $1 (use lint | packages | app | all)"; exit 2 ;;
esac

step "All checks passed"
