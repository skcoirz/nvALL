import Foundation
import SQLite3

class SearchIndex {
    private var db: OpaquePointer?
    private let dbPath: String

    init(notesDirectory: URL) {
        dbPath = notesDirectory.appendingPathComponent(".search_index.db").path
        openDatabase()
        createTable()
    }

    deinit {
        sqlite3_close(db)
    }

    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            db = nil
        }
    }

    private func createTable() {
        exec("CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(title, content, path UNINDEXED, modified UNINDEXED)")
    }

    func rebuild(from notes: [Note]) {
        exec("DELETE FROM notes_fts")
        let stmt = prepare("INSERT INTO notes_fts(title, content, path, modified) VALUES (?, ?, ?, ?)")
        defer { sqlite3_finalize(stmt) }
        exec("BEGIN TRANSACTION")
        for note in notes {
            sqlite3_bind_text(stmt, 1, (note.title as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (note.content as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (note.fileURL.path as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 4, note.modifiedDate.timeIntervalSince1970)
            sqlite3_step(stmt)
            sqlite3_reset(stmt)
        }
        exec("COMMIT")
    }

    func update(note: Note) {
        delete(path: note.fileURL.path)
        let stmt = prepare("INSERT INTO notes_fts(title, content, path, modified) VALUES (?, ?, ?, ?)")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (note.title as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (note.content as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (note.fileURL.path as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 4, note.modifiedDate.timeIntervalSince1970)
        sqlite3_step(stmt)
    }

    func delete(path: String) {
        let stmt = prepare("DELETE FROM notes_fts WHERE path = ?")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (path as NSString).utf8String, -1, nil)
        sqlite3_step(stmt)
    }

    func search(query: String) -> [String] {
        let escaped = query.replacingOccurrences(of: "\"", with: "\"\"")
        let ftsQuery = escaped.split(separator: " ").map { "\"\($0)\"*" }.joined(separator: " OR ")
        let sql = "SELECT path FROM notes_fts WHERE notes_fts MATCH ? ORDER BY bm25(notes_fts, 10.0, 1.0) LIMIT 500"
        let stmt = prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (ftsQuery as NSString).utf8String, -1, nil)

        var paths: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let cStr = sqlite3_column_text(stmt, 0) {
                paths.append(String(cString: cStr))
            }
        }
        return paths
    }

    private func exec(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func prepare(_ sql: String) -> OpaquePointer? {
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        return stmt
    }
}
