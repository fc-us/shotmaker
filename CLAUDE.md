# ShotMaker

Private on-device screenshot OCR and search app for macOS. Watches a directory for new PNGs, runs Apple Vision OCR, auto-tags, stores in SQLite with FTS5 full-text search.

## Tech Stack
- Swift 5.9+ / SwiftUI / macOS 13+
- SQLite3 (system library, no dependencies)
- Apple Vision framework (VNRecognizeTextRequest)
- NaturalLanguage framework (NLTagger)
- FSEvents for directory watching
- XcodeGen for project generation

## Project Structure
- `ShotMaker/` -- all source code
  - `Models/` -- ScreenshotItem, AppSettings
  - `Services/` -- ScreenshotWatcher (FSEvents), OCRService, TaggerService, SQLiteStorage
  - `Views/` -- MainWindowView, SidebarView, ThumbnailGridView, DetailPanelView, SettingsView
- `project.yml` -- XcodeGen spec
- `Makefile` -- build commands

## Build
```bash
make setup    # install xcodegen (one-time)
make generate # create .xcodeproj
make run      # build + launch
```

## Architecture
- Single-process SwiftUI app
- Menubar icon (LSUIElement=true, no dock icon) + standalone search window
- FSEvents watches configurable directory (default ~/Desktop)
- OCR runs on background DispatchQueue, never blocks UI
- SQLite with FTS5 for full-text search on OCR text
- Protocol-based storage for testability

## SQLite Schema
- screenshots: id, file_path, ocr_text, tag, app_name, created_at, thumbnail (BLOB)
- screenshots_fts: FTS5 virtual table on ocr_text

## Tag Categories
code, conversation, article, notes, receipt, design, data, other

## Distribution
- Bundle ID: org.frontiercommons.shot-maker
- Requires Apple Developer account for notarization
- Without signing: users right-click -> Open on first launch

## Prerequisites
- Xcode (full install from App Store)
- xcodegen (`brew install xcodegen`)

## Status
- All source code written
- NOT YET COMPILED -- needs Xcode installed
- Next: Install Xcode -> `make run` -> test -> iterate
