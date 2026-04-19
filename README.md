# ShotMaker

macOS menubar app that watches your Desktop, runs OCR on every screenshot, and lets you search everything you've ever seen.

**[Download v1.0.0 →](https://github.com/fc-us/shotmaker/releases/latest/download/ShotMaker.dmg)**

---

## What it does

Takes a screenshot. ShotMaker detects it within 2 seconds, runs Apple Vision OCR in the background, and indexes the text locally in SQLite. Hit ⌥⌘F from anywhere and search by keyword or meaning.

No cloud. No account. No network calls ever.

## Features

- **Full-text search** via SQLite FTS5 — every word in every screenshot indexed
- **Semantic search** via on-device NLEmbedding — find screenshots by meaning, not just exact text
- **Auto-tagging** — classifies screenshots as code, article, conversation, receipt, notes, etc.
- **Global hotkey** ⌥⌘F — works from any app, no accessibility permission needed (Carbon API)
- **Clipboard ingestion** — paste any image to index it alongside your screenshots
- **Drag to export** — drag any thumbnail out into Finder, email, or another app

## Requirements

- macOS 13 Ventura or later
- Apple Silicon or Intel

## Install

1. Download `ShotMaker.dmg` from [Releases](https://github.com/fc-us/shotmaker/releases)
2. Open the DMG, drag ShotMaker to `/Applications`
3. Launch it — it runs as a menubar app with no Dock icon
4. Grant Desktop folder access when prompted

No installer. No setup wizard.

## Build from source

```bash
# Install xcodegen if you don't have it
brew install xcodegen

git clone https://github.com/fc-us/shotmaker
cd shotmaker

make generate   # generates ShotMaker.xcodeproj from project.yml
make run        # builds and launches
```

Requires Xcode 15+ installed from the App Store.

## Architecture

Single-process SwiftUI app. The interesting parts:

| File | What it does |
|---|---|
| `ScreenshotWatcher.swift` | FSEvents + poll loop, detects new PNGs, dispatches processing |
| `OCRService.swift` | Apple Vision `VNRecognizeTextRequest`, CoreGraphics thumbnail gen |
| `SQLiteStorage.swift` | SQLite3 direct (no ORM), FTS5 virtual table, serial queue for writes |
| `EmbeddingService.swift` | NLEmbedding vectors, cosine similarity, lazy backfill |
| `TaggerService.swift` | NLTagger-based classification into 8 tag categories |
| `HotkeyService.swift` | Carbon `RegisterEventHotKey`, no accessibility permission |

OCR runs on a background `DispatchQueue`. All SQLite access goes through a serial queue. UI updates dispatch to main.

The database lives at `~/Library/Application Support/org.frontiercommons.shot-maker/screenshots.db`.

## Privacy

Every part of this app runs locally:

- OCR: Apple Vision framework (on-device)
- Semantic embeddings: `NLEmbedding` (on-device, ships with macOS)
- Storage: SQLite file in your Application Support directory
- Network: zero outbound connections, ever

You can verify this in Activity Monitor → Network tab while the app is running.

## Distribution

The release DMG is notarized with a Developer ID certificate (Apple ID: andrewfengdts@gmail.com, Team: RJL4AN4QK9) and stapled, so Gatekeeper accepts it without prompting.

## License

MIT
