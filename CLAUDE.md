# nvALL - Claude Code Guidelines

## Build & Test

```sh
swift build --disable-sandbox
swift test --disable-sandbox
.build/debug/nvALL
bash scripts/build-app.sh   # builds signed .app bundle in build/
```

The `--disable-sandbox` flag is required — Swift Package Manager's sandbox conflicts with macOS security on some setups.

## Architecture

- **NotesManager** is the central ObservableObject shared via @EnvironmentObject. It owns notes, search state, editor content, cursor positions, and save status.
- **SearchIndex** wraps SQLite FTS5 for fast full-text search with BM25 ranking. Title matches weighted 10x over content.
- **VersionManager** handles file-based version snapshots in `.versions/` subdirectory.
- **AIAssistant** shells out to the `claude` CLI with `--output-format stream-json` for streaming AI responses. Uses `-c` flag for multi-turn conversations.
- **AIConversationManager** handles AI chat persistence (`_ai_chat_*.md` files) and the instructions file (`_ai_instructions.md`).
- **NoteListView** wraps NSTableView (not SwiftUI List/Table) for tight row control, context menus, and custom cell coloring for AI files.
- **EditorView** wraps a custom `TabTextView` (NSTextView subclass) via NSViewRepresentable for find bar, Emacs keybindings, markdown rendering, and search highlighting.
- **Theme** centralizes all colors (VS Code Dark Modern palette).
- Communication between views uses NotificationCenter (editorDidFocus, searchBarFocused, saveCursorPosition).

## Key Design Decisions

- Notes are plain files on disk — no database. SQLite is only used as a search index cache.
- RTF files are read-only (content extracted as plain text). New notes are always .md.
- `filteredNotes` is a cached computed property — invalidated when `searchText` or `notes.count` changes. Search uses FTS5, not in-memory scanning.
- Auto-save uses a 0.5s debounce via DispatchWorkItem. Cmd+S force saves immediately.
- Empty content is never saved over non-empty files (safety guard in saveCurrentNote).
- The NSTableView `updateNSView` only reloads when the note file URLs change, not on every editor keystroke.
- Markdown styling (bold/italic/strikethrough) applies on note load and after Cmd+B/I/Y, NOT during typing — avoids editor flashing.
- Current-line markdown refresh runs with 0.3s debounce after edits for responsive marker removal.
- Scrollbar search marks are computed in DispatchQueue.main.async to avoid layout manager crashes.
- Chinese/Japanese/Korean IME: both `textDidChange` and `updateNSView` skip when `hasMarkedText()` is true.
- AI conversations auto-save after each response and reload the notes list.
- AI mode uses `?` prefix to enter, ESC to exit. Once in AI mode, no prefix needed for follow-ups.

## Common Tasks

- **Add a new file format**: update `validExtensions` in `loadNotes()` and add reading logic.
- **Change search ranking**: modify the FTS5 BM25 weights in `SearchIndex.search()`.
- **Adjust UI spacing**: NoteListView row height is set via `tableView.rowHeight`. Divider style is in DraggableDivider.
- **Add a preference**: add @AppStorage in SettingsView, read from UserDefaults in the relevant model.
- **Change theme colors**: edit `Theme.swift` — all colors are centralized there.
- **Modify AI behavior**: edit `_ai_instructions.md` in the notes folder, or change the system prompt in `AIAssistant.ask()`.
- **Add a keyboard shortcut**: add a case in `TabTextView.keyDown()` for editor shortcuts, or a hidden Button with `.keyboardShortcut()` in ContentView for global shortcuts.
