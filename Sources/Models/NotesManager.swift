import Foundation
import SwiftUI

class NotesManager: ObservableObject {
    @Published var notes: [Note] = []
    @Published var searchText: String = ""
    @Published var selectedNoteID: UUID?
    @Published var editorContent: String = ""
    @Published var pendingCursorPosition: Int?

    var notesDirectory: URL
    var fileExtension: String
    var versionManager: VersionManager!
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
            let query = searchText.lowercased()
            result = notes
                .map { note -> (Note, Double) in
                    let score = searchScore(note: note, query: query)
                    return (note, score)
                }
                .sorted { a, b in
                    if a.1 != b.1 { return a.1 > b.1 }
                    return a.0.modifiedDate > b.0.modifiedDate
                }
                .map { $0.0 }
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
        let defaultPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".nvALL").path
        let path = defaults.string(forKey: "notesDirectory") ?? defaultPath
        let ext = defaults.string(forKey: "fileExtension") ?? "md"
        self.init(directory: URL(fileURLWithPath: path), fileExtension: ext)
        self.cursorPositions = (defaults.dictionary(forKey: "cursorPositions") as? [String: Int]) ?? [:]
    }

    init(directory: URL, fileExtension: String = "md") {
        self.notesDirectory = directory
        self.fileExtension = fileExtension
        try? FileManager.default.createDirectory(at: notesDirectory, withIntermediateDirectories: true)
        self.versionManager = VersionManager(notesDirectory: notesDirectory)
        loadNotes()
    }

    private func searchScore(note: Note, query: String) -> Double {
        var score = 0.0
        let title = note.title.lowercased()
        let content = note.content.lowercased()

        if title == query { score += 100 }
        else if title.hasPrefix(query) { score += 80 }
        else if title.contains(query) { score += 60 }

        let words = query.split(separator: " ").map { $0.lowercased() }
        let titleWordMatches = words.filter { title.contains($0) }.count
        if titleWordMatches > 0 && score == 0 {
            score += Double(titleWordMatches) / Double(words.count) * 40
        }

        if content.contains(query) {
            let occurrences = content.components(separatedBy: query).count - 1
            score += min(Double(occurrences) * 5, 30)
        }

        let contentWordMatches = words.filter { content.contains($0) }.count
        if contentWordMatches > 0 {
            score += Double(contentWordMatches) / Double(words.count) * 20
        }

        return score
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
    }

    func scheduleSave() {
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
        selectedNoteID = note.id
        loadedContent = content
        editorContent = content
        return note
    }

    func deleteNote(_ note: Note) {
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
