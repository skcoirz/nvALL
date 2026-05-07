# nvALL

A fast, lightweight note-taking app for macOS, inspired by [nvALT](https://brettterpstra.com/projects/nvalt/). Built with Swift and SwiftUI.

Your notes are plain text files stored in a folder you choose. No cloud, no database, no lock-in.

## Features

- **Instant search** — filters by title and content, ranked by relevance
- **Keyboard-driven** — arrow keys to navigate, Enter to select or create, Esc to go back
- **File-backed** — reads and writes Markdown (.md), plain text (.txt), and RTF (.rtf)
- **Version history** — auto-saves snapshots on every edit, right-click to revert
- **Search highlighting** — matches highlighted in the editor with scrollbar markers
- **Cursor memory** — remembers your position in each note across sessions
- **Configurable** — choose storage folder, file format, and max versions in Preferences (Cmd+,)
- **Native macOS** — built with SwiftUI and AppKit, runs as a standard Mac app

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+N | New note |
| Cmd+L | Focus search bar |
| Cmd+F | Find in editor |
| Cmd+, | Preferences |
| Esc (1x) | Focus search bar |
| Esc (2x) | Clear search text |
| Esc (3x) | Deselect note |
| Up/Down | Navigate notes from search bar |
| Enter | Select top match or create new note |
| Tab | Insert 2 spaces |

## Build & Run

Requires macOS 14+ and Xcode Command Line Tools.

```sh
git clone https://github.com/skcoirz/nvALL.git
cd nvALL
swift build --disable-sandbox
.build/debug/nvALL
```

## Run Tests

```sh
swift test --disable-sandbox
```

26 tests covering note CRUD, search ranking, version history, and save safety.

## Project Structure

```
Sources/
  nvALLApp.swift              — App entry point
  Models/
    Note.swift                — Note data model
    NotesManager.swift        — Core logic: load, save, search, navigate
    VersionManager.swift      — Version history: save, list, revert, prune
  Views/
    ContentView.swift         — Main layout with draggable divider
    EditorView.swift          — Text editor with search highlighting
    NoteListView.swift        — NSTableView-based note list
    SettingsView.swift        — Preferences window
Tests/
  NotesManagerTests.swift     — 20 tests
  VersionManagerTests.swift   — 6 tests
Examples/
  (sample notes demonstrating features)
```

## Storage

Notes are stored as plain files in a configurable directory (default: `~/.nvALL/`). Version history lives in a `.versions` subfolder. On first run, the app loads the bundled `Examples/` folder so you can try it immediately.

Change the storage folder anytime via Preferences (Cmd+,).

## License

MIT
