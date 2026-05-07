import Foundation

class VersionManager {
    private let versionsDir: URL

    init(notesDirectory: URL) {
        versionsDir = notesDirectory.appendingPathComponent(".versions")
        try? FileManager.default.createDirectory(at: versionsDir, withIntermediateDirectories: true)
    }

    private func versionDir(for note: Note) -> URL {
        let name = note.fileURL.deletingPathExtension().lastPathComponent
        let dir = versionsDir.appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func saveVersion(of note: Note) {
        let dir = versionDir(for: note)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let ext = note.fileURL.pathExtension
        let versionFile = dir.appendingPathComponent("\(timestamp).\(ext)")
        try? note.content.write(to: versionFile, atomically: true, encoding: .utf8)

        let maxVersions = UserDefaults.standard.integer(forKey: "maxVersions")
        pruneVersions(in: dir, keepMax: maxVersions > 0 ? maxVersions : 50)
        pruneOldVersions(in: dir, daysToKeep: 5)
    }

    func listVersions(of note: Note) -> [(date: Date, url: URL)] {
        let dir = versionDir(for: note)
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return []
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"

        let cutoff = Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date()
        return files.compactMap { url -> (Date, URL)? in
            let name = url.deletingPathExtension().lastPathComponent
            guard let date = formatter.date(from: name), date >= cutoff else { return nil }
            return (date, url)
        }
        .sorted { $0.0 > $1.0 }
    }

    func loadVersion(at url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }

    private func pruneVersions(in dir: URL, keepMax: Int) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        let sorted = files.sorted { $0.lastPathComponent > $1.lastPathComponent }
        if sorted.count > keepMax {
            for file in sorted[keepMax...] {
                try? fm.removeItem(at: file)
            }
        }
    }

    private func pruneOldVersions(in dir: URL, daysToKeep: Int) {
        let fm = FileManager.default
        let cutoff = Calendar.current.date(byAdding: .day, value: -daysToKeep, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for file in files {
            let name = file.deletingPathExtension().lastPathComponent
            if let date = formatter.date(from: name), date < cutoff {
                try? fm.removeItem(at: file)
            }
        }
    }
}
