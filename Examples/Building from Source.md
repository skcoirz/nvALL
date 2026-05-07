nvALL is built with Swift and SwiftUI. No Xcode project is needed.

Requirements
  - macOS 14 or later
  - Xcode Command Line Tools (xcode-select --install)
  - Or full Xcode from the App Store

Build and Run
  swift build --disable-sandbox
  .build/debug/nvALL

The --disable-sandbox flag is needed because Swift Package Manager's sandbox can conflict with macOS security on some setups.

Run Tests
  swift test --disable-sandbox

Project Structure
  nvALL/
    Package.swift          — Swift Package Manager config
    Sources/
      nvALLApp.swift       — App entry point and window setup
      Models/
        Note.swift         — Note data model
        NotesManager.swift — Core logic: loading, saving, searching, navigation
        VersionManager.swift — Version history: save, list, revert, prune
      Views/
        ContentView.swift  — Main layout: search bar, list, editor, divider
        EditorView.swift   — Text editor with highlighting and scrollbar marks
        NoteListView.swift — NSTableView-based note list with context menus
        SettingsView.swift — Preferences window
    Tests/
      NotesManagerTests.swift  — 20 tests for core note operations
      VersionManagerTests.swift — 6 tests for version history
    Examples/
      (these example notes)
