# SnapShelf

> The fastest way to capture, organize and rediscover your screenshots.

A native macOS screenshot **lifecycle** manager — Sukurini's Shelf UX, plus
OCR search, AI rename/summary, and automatic Smart Folder organization.

## Status

🟡 Bootstrap → Sprint 1. See [ROADMAP](docs/ROADMAP.md).

## Tech

Native Swift 6 / SwiftUI + AppKit (macOS 14+). Capture via ScreenCaptureKit,
OCR via Vision, search via SQLite + FTS5.

## Quick start

```bash
npm run gen:project          # xcodegen generate  (Project.yml -> SnapShelf.xcodeproj)
open SnapShelf.xcodeproj     # or build from CLI:
xcodebuild -project SnapShelf.xcodeproj -scheme SnapShelf -configuration Debug build
```

## Architecture

```
Types → Config → Repo → Service → Runtime → UI
```

Six static-framework layer modules; reverse imports are blocked by both the
compiler and Gate 1 (`npm run harness:lint`). See [docs/architecture.md](docs/architecture.md).

## Workflow

This project follows the 3-agent Harness workflow
(PLANNER → GENERATOR → EVALUATOR). See the `harness-workflow` skill and
[docs/skills/harness-workflow.md](docs/skills/harness-workflow.md).
