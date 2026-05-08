# nvALL

A fast, lightweight note-taking app for macOS, inspired by [nvALT](https://brettterpstra.com/projects/nvalt/). Built with Swift and SwiftUI.

Your notes are plain text files stored in a folder you choose. No cloud, no database, no lock-in.

## Features

- **Instant search** — SQLite FTS5 full-text search, ranked by relevance with BM25
- **Keyboard-driven** — arrow keys to navigate, Enter to select or create, Esc to go back
- **File-backed** — reads and writes Markdown (.md), plain text (.txt), and RTF (.rtf)
- **Inline Markdown** — bold, italic, strikethrough rendered inline with dimmed markers
- **Version history** — auto-saves snapshots on every edit, right-click to revert
- **Search highlighting** — matches highlighted in the editor with scrollbar markers
- **AI Q&A** — type `?` in the search bar to ask questions about your notes using Claude
- **Auto-indent** — Enter preserves indentation and continues list prefixes (-, *, 1.)
- **Cursor memory** — remembers your position in each note across sessions
- **Dark theme** — VS Code Dark Modern color scheme
- **CJK support** — Chinese/Japanese/Korean IME input without cursor jumping
- **Configurable** — choose storage folder and max versions in Preferences (Cmd+,)
- **Native macOS** — built with SwiftUI and AppKit, ad-hoc code signed

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+N | New note |
| Cmd+Enter | Force create new note from search text |
| Cmd+S | Force save |
| Cmd+L | Focus search bar |
| Cmd+F | Find in editor |
| Cmd+B | Toggle **bold** |
| Cmd+I | Toggle *italic* |
| Cmd+Y | Toggle ~~strikethrough~~ |
| Cmd+] | Indent |
| Cmd+[ | Unindent |
| Cmd+, | Preferences |
| Esc (1x) | Focus search bar / exit AI mode |
| Esc (2x) | Clear search text |
| Esc (3x) | Deselect note |
| Up/Down | Navigate notes from search bar |
| Enter | Select top match or create new note |
| Tab | Insert 2 spaces |

## AI Q&A (Experiment Branch)

Type `? your question` in the search bar to ask AI about your notes.

- Uses the local `claude` CLI — no API key needed
- Finds relevant notes via FTS5 search and provides them as context
- Streaming responses shown in real-time
- Conversations auto-saved as `_ai_chat_*.md` files
- Click a saved chat to resume the conversation
- Edit `_ai_instructions.md` to customize AI behavior
- ESC exits AI mode from anywhere

Requires Claude Code CLI installed at `/usr/local/bin/claude`.

## Build & Run

Requires macOS 14+ and Xcode Command Line Tools.

```sh
git clone https://github.com/skcoirz/nvALL.git
cd nvALL
swift build --disable-sandbox
.build/debug/nvALL
```

## Build App Bundle

```sh
bash scripts/build-app.sh
cp -R build/nvALL.app ~/Applications/
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
    SearchIndex.swift         — SQLite FTS5 search index
    Theme.swift               — VS Code Dark Modern color definitions
    AIAssistant.swift         — Claude CLI integration with streaming
    AIConversationManager.swift — AI chat persistence and instructions
  Views/
    ContentView.swift         — Main layout with draggable divider
    EditorView.swift          — Text editor with markdown and highlighting
    NoteListView.swift        — NSTableView-based note list
    AIChatView.swift          — AI conversation view with markdown rendering
    SettingsView.swift        — Preferences window
Tests/
  NotesManagerTests.swift     — 20 tests
  VersionManagerTests.swift   — 6 tests
Examples/
  (sample notes demonstrating features)
Resources/
  AppIcon.icns               — App icon
```

## Storage

Notes are stored as plain files in a configurable directory (default: `~/.nvALL/`). Version history lives in a `.versions` subfolder. Search index is cached in `.search_index.db`. On first run, the app loads the bundled `Examples/` folder so you can try it immediately.

Change the storage folder anytime via Preferences (Cmd+,).

## License

MIT
