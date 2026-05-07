import XCTest
@testable import nvALL

final class VersionManagerTests: XCTestCase {
    var tempDir: URL!
    var versionManager: VersionManager!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        versionManager = VersionManager(notesDirectory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func makeNote(title: String, content: String) -> Note {
        let url = tempDir.appendingPathComponent("\(title).md")
        try! content.write(to: url, atomically: true, encoding: .utf8)
        return Note(id: UUID(), title: title, content: content, fileURL: url, modifiedDate: Date())
    }

    func testSaveVersionCreatesFile() {
        let note = makeNote(title: "test", content: "original")
        versionManager.saveVersion(of: note)
        let versions = versionManager.listVersions(of: note)
        XCTAssertEqual(versions.count, 1)
    }

    func testSaveMultipleVersions() {
        let note = makeNote(title: "multi", content: "v1")
        versionManager.saveVersion(of: note)
        usleep(1100000)
        var updated = note
        updated.content = "v2"
        versionManager.saveVersion(of: updated)
        let versions = versionManager.listVersions(of: note)
        XCTAssertEqual(versions.count, 2)
    }

    func testLoadVersion() {
        let note = makeNote(title: "load", content: "saved content")
        versionManager.saveVersion(of: note)
        let versions = versionManager.listVersions(of: note)
        let loaded = versionManager.loadVersion(at: versions.first!.url)
        XCTAssertEqual(loaded, "saved content")
    }

    func testVersionsAreSortedNewestFirst() {
        let note = makeNote(title: "sorted", content: "v1")
        versionManager.saveVersion(of: note)
        usleep(1100000)
        var updated = note
        updated.content = "v2"
        versionManager.saveVersion(of: updated)
        let versions = versionManager.listVersions(of: note)
        XCTAssertTrue(versions.first!.date >= versions.last!.date)
    }

    func testListVersionsReturnsEmptyForNewNote() {
        let note = makeNote(title: "new", content: "no versions")
        let versions = versionManager.listVersions(of: note)
        XCTAssertTrue(versions.isEmpty)
    }

    func testPruneKeepsMaxVersions() {
        UserDefaults.standard.set(3, forKey: "maxVersions")
        let note = makeNote(title: "prune", content: "c")
        for i in 0..<5 {
            var n = note
            n.content = "version \(i)"
            versionManager.saveVersion(of: n)
            usleep(1100000)
        }
        let versions = versionManager.listVersions(of: note)
        XCTAssertLessThanOrEqual(versions.count, 3)
        UserDefaults.standard.removeObject(forKey: "maxVersions")
    }
}
