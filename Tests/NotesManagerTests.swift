import XCTest
@testable import nvALL

final class NotesManagerTests: XCTestCase {
    var tempDir: URL!
    var manager: NotesManager!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        manager = NotesManager(directory: tempDir, fileExtension: "md")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testCreateNote() {
        let note = manager.createNote(title: "Test Note")
        XCTAssertEqual(note.title, "Test Note")
        XCTAssertEqual(manager.notes.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: note.fileURL.path))
    }

    func testCreateNoteDeduplicatesName() {
        manager.createNote(title: "Duplicate")
        manager.createNote(title: "Duplicate")
        XCTAssertEqual(manager.notes.count, 2)
        let titles = Set(manager.notes.map { $0.title })
        XCTAssertTrue(titles.contains("Duplicate"))
        XCTAssertTrue(titles.contains("Duplicate 1"))
    }

    func testCreateNoteWithEmptyTitle() {
        let note = manager.createNote(title: "")
        XCTAssertEqual(note.title, "Untitled")
    }

    func testDeleteNote() {
        let note = manager.createNote(title: "To Delete")
        let path = note.fileURL.path
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
        manager.deleteNote(note)
        XCTAssertEqual(manager.notes.count, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
    }

    func testDeleteSelectedNoteClearsEditor() {
        let note = manager.createNote(title: "Selected")
        manager.selectedNoteID = note.id
        manager.editorContent = "some content"
        manager.deleteNote(note)
        XCTAssertNil(manager.selectedNoteID)
        XCTAssertEqual(manager.editorContent, "")
    }

    func testLoadNotes() {
        try! "Hello".write(to: tempDir.appendingPathComponent("note1.md"), atomically: true, encoding: .utf8)
        try! "World".write(to: tempDir.appendingPathComponent("note2.txt"), atomically: true, encoding: .utf8)
        manager.loadNotes()
        XCTAssertEqual(manager.notes.count, 2)
    }

    func testLoadNotesIgnoresInvalidExtensions() {
        try! "data".write(to: tempDir.appendingPathComponent("file.json"), atomically: true, encoding: .utf8)
        try! "note".write(to: tempDir.appendingPathComponent("file.md"), atomically: true, encoding: .utf8)
        manager.loadNotes()
        XCTAssertEqual(manager.notes.count, 1)
        XCTAssertEqual(manager.notes.first?.title, "file")
    }

    func testFilteredNotesWithEmptySearch() {
        manager.createNote(title: "Older")
        usleep(10000)
        manager.createNote(title: "Newer")
        manager.searchText = ""
        let filtered = manager.filteredNotes
        XCTAssertEqual(filtered.first?.title, "Newer")
    }

    func testFilteredNotesWithSearch() {
        try! "Swift programming guide".write(to: tempDir.appendingPathComponent("swift.md"), atomically: true, encoding: .utf8)
        try! "Python basics".write(to: tempDir.appendingPathComponent("python.md"), atomically: true, encoding: .utf8)
        manager.loadNotes()
        manager.searchText = "swift"
        let filtered = manager.filteredNotes
        XCTAssertEqual(filtered.first?.title, "swift")
        XCTAssertEqual(filtered.count, 2)
    }

    func testSearchScoreExactTitleMatch() {
        try! "content".write(to: tempDir.appendingPathComponent("hello.md"), atomically: true, encoding: .utf8)
        try! "hello world".write(to: tempDir.appendingPathComponent("other.md"), atomically: true, encoding: .utf8)
        manager.loadNotes()
        manager.searchText = "hello"
        let filtered = manager.filteredNotes
        XCTAssertEqual(filtered.first?.title, "hello")
    }

    func testSearchShowsAllNotes() {
        manager.createNote(title: "Match")
        manager.createNote(title: "NoMatch")
        manager.searchText = "Match"
        XCTAssertEqual(manager.filteredNotes.count, 2)
    }

    func testSaveCurrentNoteWritesToDisk() {
        let note = manager.createNote(title: "SaveTest")
        manager.selectedNoteID = note.id
        manager.onSelectionChanged(to: note.id)
        manager.editorContent = "Updated content"
        manager.saveCurrentNote()
        let saved = try! String(contentsOf: note.fileURL, encoding: .utf8)
        XCTAssertEqual(saved, "Updated content")
    }

    func testSaveCurrentNoteSkipsWhenUnchanged() {
        let note = manager.createNote(title: "NoChange")
        manager.selectedNoteID = note.id
        manager.onSelectionChanged(to: note.id)
        let modBefore = manager.notes.first { $0.id == note.id }!.modifiedDate
        manager.saveCurrentNote()
        let modAfter = manager.notes.first { $0.id == note.id }!.modifiedDate
        XCTAssertEqual(modBefore, modAfter)
    }

    func testSaveCurrentNotePreventsSavingEmptyOverContent() {
        let note = manager.createNote(title: "Safety")
        manager.selectedNoteID = note.id
        try! "Important data".write(to: note.fileURL, atomically: true, encoding: .utf8)
        manager.loadNotes()
        let loaded = manager.notes.first { $0.title == "Safety" }!
        manager.selectedNoteID = loaded.id
        manager.onSelectionChanged(to: loaded.id)
        manager.editorContent = ""
        manager.saveCurrentNote()
        let onDisk = try! String(contentsOf: loaded.fileURL, encoding: .utf8)
        XCTAssertEqual(onDisk, "Important data")
    }

    func testOnSelectionChangedLoadsContent() {
        try! "File content".write(to: tempDir.appendingPathComponent("load.md"), atomically: true, encoding: .utf8)
        manager.loadNotes()
        let note = manager.notes.first!
        manager.onSelectionChanged(to: note.id)
        XCTAssertEqual(manager.editorContent, "File content")
    }

    func testCreateOrSelectFromSearchSelectsExisting() {
        manager.createNote(title: "Existing")
        manager.searchText = "Existing"
        manager.createOrSelectFromSearch()
        XCTAssertEqual(manager.notes.count, 1)
        XCTAssertEqual(manager.searchText, "")
    }

    func testCreateOrSelectFromSearchCreatesNew() {
        manager.searchText = "Brand New"
        manager.createOrSelectFromSearch()
        XCTAssertEqual(manager.notes.count, 1)
        XCTAssertEqual(manager.notes.first?.title, "Brand New")
        XCTAssertEqual(manager.searchText, "")
    }

    func testSelectNextNote() {
        manager.createNote(title: "A")
        manager.createNote(title: "B")
        manager.searchText = ""
        manager.selectedNoteID = nil
        manager.selectNextNote()
        XCTAssertNotNil(manager.selectedNoteID)
    }

    func testSelectPreviousNote() {
        manager.createNote(title: "A")
        manager.createNote(title: "B")
        manager.searchText = ""
        manager.selectedNoteID = nil
        manager.selectPreviousNote()
        XCTAssertNotNil(manager.selectedNoteID)
    }

    func testCursorPositionSaveAndRestore() {
        let note = manager.createNote(title: "Cursor")
        manager.selectedNoteID = note.id
        manager.saveCursorPosition(42)
        manager.onSelectionChanged(to: note.id)
        XCTAssertEqual(manager.pendingCursorPosition, 42)
    }
}
