# Changelog

All notable changes to SnapShelf are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/). Dates are Asia/Seoul.

## [Unreleased]

### Added — Sprint 5: Smart Folder auto-organize
- FolderRule + FolderRuleKind (Types); FolderRuleEngine (priority/keyword/regex/category, defaultRules)
- SourceDetector: TCC-free heuristic app/category detection from OCR + filename
- Organizer: atomic file move into app-owned Library subpaths (best-effort, collision-safe)
- IntakePipeline: capture → OCR → AI rename → organize (source_url updated)
- 21 new unit tests (detection/engine/organizer); 99/99 pass, 87.2% coverage
- EVAL PASS: dropped image auto-moved to Library/Supabase/, app detected, renamed
- Scope: TCC-safe path (app Library); user-folder watch + accessibility detection deferred

### Added — Sprint 4: AI provider abstraction + rename/summary
- AIService protocol (rename/summarize) + AIError
- RuleBasedAIService (offline fallback; default ON — privacy-safe heuristic rename)
- FoundationModelsAIService (on-device, macOS 26 #available gate)
- HTTPAIService (OpenAI-compatible chat completions; injectable HTTPClient for tests)
- OllamaAIService + AIServiceFactory (selection: off/unavailable/no-key → rule fallback)
- SecretStore (Keychain + in-memory), AIProviderConfig (opt-in)
- IntakePipeline: optional AI rename after OCR (best-effort, opt-in)
- App wired to RuleBasedAIService by default; 22 new tests; 78/78 pass, 85.9% coverage
- EVAL PASS: dropped image display_name auto-renamed to OCR-derived "Supabase auth error 401"

### Added — Sprint 3: storage + OCR + text search
- SQLiteShelfRepository (system libsqlite3 + FTS5, WAL, schema_meta v1) behind ShelfItemRepository
- VisionOCRService (Vision VNRecognizeTextRequest, accurate, en/ko/ja, top→bottom)
- IntakePipeline runs OCR after ingest (best-effort, never loses the item)
- ShelfItemRepository.search / searchExcerpts (bm25 + snippet) + setOCR reindex
- ShelfView search bar (onSubmit/onChange → runSearch) + results list w/ excerpts
- App wired to SQLite + Vision OCR (falls back to JSON store if DB open fails)
- 14 new unit tests; 56/56 pass, 91.6% coverage
- EVAL PASS: real text image → Vision OCR extracted text → FTS5 search returns it

### Added — Sprint 2: Shelf interactions
- Hover toolbar per item: copy image, share (ShareLink), pin/unpin, stow
- Drag-anywhere via .onDrag (NSItemProvider file URL) -> Finder/Slack/Discord/ChatGPT/...
- Pinned + Recent sections; history-limit enforcement (pinned always kept, newest non-pinned)
- Auto-stow policy + scheduler (hoverSeconds); cancelled on pin/stow
- ClipboardService (file/image to pasteboard, injectable pasteboard for tests)
- 7 new unit tests (sections, limit, auto-stow policy, clipboard); 42/42 pass, 95.0% coverage
- EVAL PASS: app runs, core loop intact; UI clicks/screenshot deferred to interactive env (shell TCC)

### Added — Sprint 1: Foundation (capture→shelf core loop)
- 6 static-framework layer modules build clean (Types/Config/Repo/Service/Runtime) + app
- Menu bar accessory (LSUIElement) with status item (Open Shelf / Simulate Capture / Quit)
- DirectoryWatcher (dispatch source) → IntakePipeline → FileShelfRepository (JSON)
- @Observable ShelfModel; floating non-activating NSPanel shelf surface (bottom-right)
- ShelfView/ItemView with enter animations + reduce-motion support
- 35 XCTest cases; **94.4% line coverage** (Config 90 · Repo 98 · Runtime 93 · Service 97 · Types 100)
- EVAL PASS: live inbox-drop auto-indexed; menu bar + shelf panel on screen verified
- Fix: NSPanel hidesOnDeactivate=false so the shelf persists when app deactivates

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
