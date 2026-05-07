# nvALL - Claude Code Guidelines

## Build & Test

```sh
swift build --disable-sandbox
swift test --disable-sandbox
.build/debug/nvALL
```

The `--disable-sandbox` flag is required — Swift Package Manager's sandbox conflicts with macOS security on some setups.

## Architecture

- **NotesManager** is the central ObservableObject shared via @EnvironmentObject. It owns notes, search state, editor content, and cursor positions.
- **VersionManager** handles file-based version snapshots in `.versions/` subdirectory.
- **NoteListView** wraps NSTableView (not SwiftUI List/Table) for tight row control and context menus.
- **EditorView** wraps NSTextView via NSViewRepresentable for find bar, Emacs keybindings, and search highlighting.
- Communication between views uses NotificationCenter (editorDidFocus, searchBarFocused, saveCursorPosition).

## Key Design Decisions

- Notes are plain files on disk — no database. The app reads from and writes to a user-chosen folder.
- RTF files are read-only (content extracted as plain text). New notes are always md or txt.
- `filteredNotes` is a cached computed property — invalidated when `searchText` or `notes.count` changes.
- Auto-save uses a 0.5s debounce via DispatchWorkItem.
- Empty content is never saved over non-empty files (safety guard in saveCurrentNote).
- The NSTableView `updateNSView` only reloads when the note file URLs change, not on every editor keystroke.
- Scrollbar search marks are computed in DispatchQueue.main.async to avoid layout manager crashes.

## Common Tasks

- **Add a new file format**: update `validExtensions` in `loadNotes()` and add reading logic.
- **Change search ranking**: modify `searchScore(note:query:)` in NotesManager.
- **Adjust UI spacing**: NoteListView row height is set via `tableView.rowHeight`. Divider style is in DraggableDivider.
- **Add a preference**: add @AppStorage in SettingsView, read from UserDefaults in the relevant model.
