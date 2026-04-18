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

# Resolve a tool: prefer mise-managed, fall back to PATH. Echos the absolute
# path or empty string. mise installs may not be on PATH for non-interactive
# bash, so we use `mise which` to ask mise where the binary is.
resolve_tool() {
  local name="$1"
  if command -v mise >/dev/null 2>&1; then
    local path
    path=$(mise which "$name" 2>/dev/null || true)
    if [[ -n "$path" && -x "$path" ]]; then
      echo "$path"
      return 0
    fi
  fi
  command -v "$name" 2>/dev/null || true
}

require_tool() {
  local name="$1"
  local path
  path=$(resolve_tool "$name")
  if [[ -z "$path" ]]; then
    err "$name not found. Try: mise install (and ensure mise is activated)"
    exit 127
  fi
  echo "$path"
}

lint() {
  step "Lint (SwiftFormat + SwiftLint)"
  local swiftformat swiftlint
  swiftformat=$(require_tool swiftformat)
  swiftlint=$(require_tool swiftlint)
  "$swiftformat" --lint .
  ok "SwiftFormat clean"
  "$swiftlint" lint --strict --quiet
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
  local tuist xcbeautify
  tuist=$(require_tool tuist)
  xcbeautify=$(resolve_tool xcbeautify)

  "$tuist" install
  "$tuist" generate --no-open

  local pipe="cat"
  if [[ -n "$xcbeautify" ]]; then
    pipe="$xcbeautify"
  fi

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
    build | $pipe
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
