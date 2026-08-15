# SnapShelf

> The fastest way to capture, organize and rediscover your screenshots.

A native macOS screenshot **lifecycle** manager — Sukurini's Shelf UX, plus
OCR search, AI rename/summary, and automatic Smart Folder organization.

**Website:** <https://codinglifelabs.github.io/SnapShelf/>

## What it does

- **Shelf** — every screenshot lands on a floating shelf in your menu bar.
  Hover to copy, drag anywhere, pin what matters.
- **OCR search** — Vision reads every capture; full-text search (SQLite +
  FTS5) finds screenshots by what they *showed*, not what they were named.
- **AI naming** — optional on-device or cloud models turn `IMG_4471.png`
  into "Stripe invoice error".
- **Auto-organize** — Smart Folders sort captures by app and subject;
  recordings file themselves by month.
- **Dedupe** — perceptual hashing groups near-identical shots; you approve
  the keeper, the rest go to Trash (undoable).
- **Privacy** — offline first. OCR, search, dedupe and organizing are all
  local. Cloud AI is opt-in and every transfer is logged on the privacy
  dashboard.

## Requirements

- macOS 14 Sonoma or newer (Apple Silicon and Intel)
- On-device AI naming requires Apple Silicon

## Download

Grab the latest `SnapShelf-*.dmg` from
[Releases](https://github.com/CodingLifeLabs/SnapShelf/releases/latest).

> The beta build is ad-hoc signed. On first launch, right-click the app and
> choose **Open** to bypass Gatekeeper, or run:
> `xattr -dr com.apple.quarantine /Applications/SnapShelf.app`

## Tech

Native Swift 6 / SwiftUI + AppKit. Capture via ScreenCaptureKit + FSEvents,
OCR via Vision, search via SQLite + FTS5, AI via a provider abstraction
(Foundation Models / OpenAI-compatible / Ollama).

## Quick start (development)

```bash
npm run gen:project          # xcodegen generate  (Project.yml -> SnapShelf.xcodeproj)
open SnapShelf.xcodeproj     # or build from CLI:
xcodebuild -project SnapShelf.xcodeproj -scheme SnapShelf -configuration Debug build
xcodebuild -project SnapShelf.xcodeproj -scheme SnapShelf \
  -configuration Debug test -enableCodeCoverage YES
```

## Architecture

```
Types → Config → Repo → Service → Runtime → UI
```

Six static-framework layer modules; reverse imports are blocked by both the
compiler and Gate 1 (`npm run harness:lint`). See
[docs/architecture.md](docs/architecture.md).

## Workflow

This project follows the 3-agent Harness workflow
(PLANNER → GENERATOR → EVALUATOR). See the `harness-workflow` skill and
[docs/skills/harness-workflow.md](docs/skills/harness-workflow.md).

## License

MIT — see [LICENSE](LICENSE).
