import Foundation
import SwiftUI

class NotesManager: ObservableObject {
    @Published var notes: [Note] = []
    @Published var searchText: String = ""
    @Published var selectedNoteID: UUID?
    @Published var editorContent: String = ""
    @Published var pendingCursorPosition: Int?
    @Published var lastSavedDate: Date?
    @Published var hasUnsavedChanges: Bool = false

    var notesDirectory: URL
    var fileExtension: String
    var versionManager: VersionManager!
    var searchIndex: SearchIndex!
    private var saveTask: DispatchWorkItem?
    private var loadedContent: String = ""
    private var cursorPositions: [String: Int] = [:]
    private var cachedFilteredNotes: [Note] = []
    private var lastSearchText: String?
    private var lastNotesCount: Int = -1

    var filteredNotes: [Note] {
        if searchText == lastSearchText && notes.count == lastNotesCount {
            return cachedFilteredNotes
        }
        let result: [Note]
        if searchText.isEmpty {
            result = notes.sorted { $0.modifiedDate > $1.modifiedDate }
        } else {
            let rankedPaths = searchIndex.search(query: searchText)
            let pathToNote = Dictionary(notes.map { ($0.fileURL.path, $0) }, uniquingKeysWith: { first, _ in first })
            let matched = rankedPaths.compactMap { pathToNote[$0] }
            let matchedSet = Set(rankedPaths)
            let unmatched = notes.filter { !matchedSet.contains($0.fileURL.path) }
                .sorted { $0.modifiedDate > $1.modifiedDate }
            result = matched + unmatched
        }
        cachedFilteredNotes = result
        lastSearchText = searchText
        lastNotesCount = notes.count
        return result
    }

    func selectPreviousNote() {
        NotificationCenter.default.post(name: Notification.Name("searchBarFocused"), object: nil)
        let list = filteredNotes
        guard !list.isEmpty else { return }
        guard let currentID = selectedNoteID,
              let index = list.firstIndex(where: { $0.id == currentID }) else {
            let note = list.first!
            selectedNoteID = note.id
            onSelectionChanged(to: note.id)
            return
        }
        let newIndex = max(index - 1, 0)
        let note = list[newIndex]
        selectedNoteID = note.id
        onSelectionChanged(to: note.id)
    }

    func selectNextNote() {
        NotificationCenter.default.post(name: Notification.Name("searchBarFocused"), object: nil)
        let list = filteredNotes
        guard !list.isEmpty else { return }
        guard let currentID = selectedNoteID,
              let index = list.firstIndex(where: { $0.id == currentID }) else {
            let note = list.first!
            selectedNoteID = note.id
            onSelectionChanged(to: note.id)
            return
        }
        let newIndex = min(index + 1, list.count - 1)
        let note = list[newIndex]
        selectedNoteID = note.id
        onSelectionChanged(to: note.id)
    }

    convenience init() {
        let defaults = UserDefaults.standard
        let fallbackPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".nvALL").path
        let storedPath = defaults.string(forKey: "notesDirectory")
        let path: String
        if let storedPath {
            path = storedPath
        } else {
            let examplesDir = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Examples")
            if FileManager.default.fileExists(atPath: examplesDir.path) {
                path = examplesDir.path
            } else {
                path = fallbackPath
            }
        }
        self.init(directory: URL(fileURLWithPath: path), fileExtension: "md")
        self.cursorPositions = (defaults.dictionary(forKey: "cursorPositions") as? [String: Int]) ?? [:]
    }

    init(directory: URL, fileExtension: String = "md") {
        self.notesDirectory = directory
        self.fileExtension = fileExtension
        try? FileManager.default.createDirectory(at: notesDirectory, withIntermediateDirectories: true)
        self.versionManager = VersionManager(notesDirectory: notesDirectory)
        self.searchIndex = SearchIndex(notesDirectory: notesDirectory)
        loadNotes()
        searchIndex.rebuild(from: notes)
    }

    func loadNotes() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: notesDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }

        let validExtensions: Set<String> = ["md", "txt", "rtf"]
        notes = files.compactMap { url -> Note? in
            let ext = url.pathExtension.lowercased()
            guard validExtensions.contains(ext) else { return nil }
            let content: String
            if ext == "rtf" {
                guard let data = try? Data(contentsOf: url),
                      let attributed = NSAttributedString(rtf: data, documentAttributes: nil) else { return nil }
                content = attributed.string
            } else {
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                content = text
            }
            let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            let modDate = attrs?.contentModificationDate ?? Date()
            let title = url.deletingPathExtension().lastPathComponent
            return Note(id: UUID(), title: title, content: content, fileURL: url, modifiedDate: modDate)
        }
    }

    func saveCursorPosition(_ position: Int) {
        guard let id = selectedNoteID,
              let note = notes.first(where: { $0.id == id }) else { return }
        let key = note.fileURL.lastPathComponent
        cursorPositions[key] = position
        UserDefaults.standard.set(cursorPositions, forKey: "cursorPositions")
    }

    func onSelectionChanged(to newID: UUID?) {
        NotificationCenter.default.post(name: .saveCursorPosition, object: nil)
        saveCurrentNote()
        if let newID, let note = notes.first(where: { $0.id == newID }) {
            loadedContent = note.content
            editorContent = note.content
            pendingCursorPosition = cursorPositions[note.fileURL.lastPathComponent]
        } else {
            loadedContent = ""
            editorContent = ""
            pendingCursorPosition = nil
        }
    }

    func saveCurrentNote() {
        saveTask?.cancel()
        guard let id = selectedNoteID,
              let index = notes.firstIndex(where: { $0.id == id }) else { return }
        guard editorContent != loadedContent else { return }
        guard !editorContent.isEmpty || loadedContent.isEmpty else { return }
        versionManager.saveVersion(of: notes[index])
        notes[index].content = editorContent
        notes[index].modifiedDate = Date()
        loadedContent = editorContent
        try? editorContent.write(to: notes[index].fileURL, atomically: true, encoding: .utf8)
        searchIndex.update(note: notes[index])
        lastSavedDate = Date()
        hasUnsavedChanges = false
    }

    func forceSave() {
        saveCurrentNote()
    }

    func scheduleSave() {
        hasUnsavedChanges = true
        saveTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.saveCurrentNote()
        }
        saveTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)
    }

    @discardableResult
    func createNote(title: String) -> Note {
        saveCurrentNote()
        let sanitized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = sanitized.isEmpty ? "Untitled" : sanitized
        var fileName = baseName
        var counter = 1
        let fm = FileManager.default

        while fm.fileExists(atPath: notesDirectory.appendingPathComponent("\(fileName).\(fileExtension)").path) {
            fileName = "\(baseName) \(counter)"
            counter += 1
        }

        let fileURL = notesDirectory.appendingPathComponent("\(fileName).\(fileExtension)")
        let content = ""
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)

        let note = Note(id: UUID(), title: fileName, content: content, fileURL: fileURL, modifiedDate: Date())
        notes.insert(note, at: 0)
        searchIndex.update(note: note)
        selectedNoteID = note.id
        loadedContent = content
        editorContent = content
        return note
    }

    func deleteNote(_ note: Note) {
        searchIndex.delete(path: note.fileURL.path)
        try? FileManager.default.removeItem(at: note.fileURL)
        notes.removeAll { $0.id == note.id }
        if selectedNoteID == note.id {
            selectedNoteID = nil
            loadedContent = ""
            editorContent = ""
        }
    }

    func revertNote(_ note: Note, to versionURL: URL) {
        guard let content = versionManager.loadVersion(at: versionURL),
              let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        versionManager.saveVersion(of: notes[index])
        notes[index].content = content
        notes[index].modifiedDate = Date()
        try? content.write(to: notes[index].fileURL, atomically: true, encoding: .utf8)
        if selectedNoteID == note.id {
            loadedContent = content
            editorContent = content
        }
    }

    func createOrSelectFromSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        if let first = filteredNotes.first {
            selectedNoteID = first.id
            onSelectionChanged(to: first.id)
        } else {
            createNote(title: query)
        }
        searchText = ""
    }
}
