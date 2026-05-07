import Foundation

struct Note: Identifiable, Hashable {
    let id: UUID
    var title: String
    var content: String
    var fileURL: URL
    var modifiedDate: Date
}
