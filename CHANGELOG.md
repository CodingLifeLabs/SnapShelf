# Changelog

All notable changes to SnapShelf are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/). Dates are Asia/Seoul.

## [Unreleased]

### Added — Bootstrap (Phase 0)
- XcodeGen `Project.yml` with 6 static-framework layer modules + app + unified test bundle
- `.swiftlint.yml` (Gate 3), `.harness/linters/dependency-direction.js` (Gate 1, Swift-aware)
- `docs/architecture.md`, `docs/quality.md`, `docs/pmf.md`, full PLANNER doc set
- `App/Info.plist` (LSUIElement accessory app + TCC usage strings)
- Harness npm scripts (`gen:project`, `harness:lint`)

### Notes
- Stack decision: **Native Swift 6 / SwiftUI** (confirmed by user)
- Toolchain verified: Xcode 26.3, Swift 6.2.4, xcodegen 2.45.3, swiftlint 0.63.3
- Host: macOS 15.7.7 (Sequoia), Intel x86_64 — affects on-device LLM fallback strategy
