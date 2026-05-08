import SwiftUI

struct ContentView: View {
    @EnvironmentObject var notesManager: NotesManager
    @FocusState private var isSearchFocused: Bool
    @State private var listHeight: CGFloat = 140

    var body: some View {
        VStack(spacing: 0) {
            SearchBarView(isSearchFocused: $isSearchFocused, notesManager: notesManager)
            Divider()
            NoteListView()
                .frame(height: listHeight)
            DraggableDivider(position: $listHeight, minPosition: 60, maxPosition: 300)
            EditorView()
                .frame(minHeight: 100)
        }
        .frame(minWidth: 400, minHeight: 350)
        .onAppear {
            isSearchFocused = true
        }
        .onKeyPress(.escape) {
            NotificationCenter.default.post(name: .searchBarFocused, object: nil)
            if !isSearchFocused {
                isSearchFocused = true
            } else if !notesManager.searchText.isEmpty {
                notesManager.searchText = ""
            } else {
                notesManager.saveCurrentNote()
                notesManager.selectedNoteID = nil
                notesManager.editorContent = ""
            }
            return .handled
        }
        .background(
            Group {
                Button("") {
                    isSearchFocused = true
                }
                .keyboardShortcut("l", modifiers: .command)
                .hidden()

                Button("") {
                    notesManager.forceSave()
                }
                .keyboardShortcut("s", modifiers: .command)
                .hidden()
            }
        )
    }
}

struct DraggableDivider: View {
    @Binding var position: CGFloat
    let minPosition: CGFloat
    let maxPosition: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Color(nsColor: Theme.borderColor)
                .frame(height: 1)
            Color(nsColor: Theme.oddRowColor)
                .frame(height: 1)
            Color(nsColor: Theme.sidebarBackground)
                .frame(height: 5)
            Color(nsColor: Theme.borderColor)
                .frame(height: 1)
        }
        .contentShape(Rectangle())
        .frame(height: 8)
        .cursor(.resizeUpDown)
        .gesture(
            DragGesture()
                .onChanged { value in
                    let new = position + value.translation.height
                    position = min(max(new, minPosition), maxPosition)
                }
        )
    }
}

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        onHover { inside in
            if inside { cursor.push() }
            else { NSCursor.pop() }
        }
    }
}

struct SearchBarView: View {
    @EnvironmentObject var envNotesManager: NotesManager
    var isSearchFocused: FocusState<Bool>.Binding
    var notesManager: NotesManager
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isFocused: Bool {
        isSearchFocused.wrappedValue
    }

    private var saveLabel: String? {
        if notesManager.hasUnsavedChanges { return "unsaved" }
        guard let saved = notesManager.lastSavedDate else { return nil }
        let seconds = Int(now.timeIntervalSince(saved))
        if seconds < 2 { return "saved just now" }
        if seconds < 60 { return "saved \(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "saved \(minutes)m ago" }
        return "saved \(minutes / 60)h ago"
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(isFocused ? .accentColor : .secondary)
            TextField("Search or create note...", text: $envNotesManager.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused(isSearchFocused)
                .onChange(of: notesManager.searchText) { _, _ in
                    notesManager.saveCurrentNote()
                    notesManager.selectedNoteID = nil
                    notesManager.editorContent = ""
                }
                .onSubmit {
                    notesManager.createOrSelectFromSearch()
                }
                .onKeyPress(.downArrow) {
                    notesManager.selectNextNote()
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    notesManager.selectPreviousNote()
                    return .handled
                }
            if !notesManager.searchText.isEmpty {
                Button(action: { notesManager.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            if let label = saveLabel {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(Color(nsColor: Theme.secondaryText))
            }
        }
        .onReceive(timer) { now = $0 }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: Theme.sidebarBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isFocused ? Color(nsColor: Theme.accentColor) : Color(nsColor: Theme.borderColor), lineWidth: 1)
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }
}

