import Foundation

class AIConversationManager {
    let notesDirectory: URL
    static let instructionsFileName = "_ai_instructions.md"
    static let chatPrefix = "_ai_chat_"

    init(notesDirectory: URL) {
        self.notesDirectory = notesDirectory
        createDefaultInstructions()
    }

    private func createDefaultInstructions() {
        let path = notesDirectory.appendingPathComponent(Self.instructionsFileName)
        guard !FileManager.default.fileExists(atPath: path.path) else { return }
        let content = """
        # AI Assistant Instructions

        You are a helpful assistant that answers questions based on the user's notes.

        ## Notes Location
        - All notes are stored as plain text files in: \(notesDirectory.path)
        - Supported formats: .md (Markdown), .txt (Plain Text), .rtf (Rich Text)
        - When the user asks about a topic, the most relevant notes are automatically provided as context
        - You can reference specific notes by their file name

        ## Behavior
        - Be concise and direct in your responses
        - When referencing notes, mention the note title in **bold**
        - Summarize key points from multiple notes when relevant
        - If the notes don't contain relevant information, say so and suggest which note might help
        - When the user says "save this conversation", confirm it has been saved automatically

        ## Understanding the Notes
        - Notes may contain work todos, meeting notes, technical references, and personal information
        - Lines starting with `- [ ]` are incomplete tasks, `- [x]` are completed tasks
        - Notes with "todo" in the title are likely task lists organized by time period
        - Notes may reference internal tools, projects, and team members

        ## Format
        - Use **bold** for emphasis and note titles
        - Use `code` for technical terms, commands, file names, or URLs
        - Use code blocks for multi-line code or commands
        - Use bullet points for lists
        - Keep responses focused and scannable
        """
        try? content.write(to: path, atomically: true, encoding: .utf8)
    }

    func loadInstructions() -> String {
        let path = notesDirectory.appendingPathComponent(Self.instructionsFileName)
        return (try? String(contentsOf: path, encoding: .utf8)) ?? ""
    }

    func saveConversation(_ messages: [(role: String, text: String)]) -> URL? {
        guard !messages.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let timestamp = formatter.string(from: Date())
        let fileName = "\(Self.chatPrefix)\(timestamp).md"
        let fileURL = notesDirectory.appendingPathComponent(fileName)

        var content = "# AI Conversation — \(timestamp)\n\n"
        for message in messages {
            let prefix = message.role == "user" ? "**Q:**" : "**A:**"
            content += "\(prefix) \(message.text)\n\n"
        }

        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    func loadConversation(from url: URL) -> [(role: String, text: String)]? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        var messages: [(String, String)] = []
        let lines = content.components(separatedBy: "\n")
        var currentRole: String?
        var currentText = ""

        for line in lines {
            if line.hasPrefix("# AI Conversation") { continue }
            if line.hasPrefix("**Q:**") {
                if let role = currentRole {
                    messages.append((role, currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                currentRole = "user"
                currentText = String(line.dropFirst(5))
            } else if line.hasPrefix("**A:**") {
                if let role = currentRole {
                    messages.append((role, currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                currentRole = "assistant"
                currentText = String(line.dropFirst(5))
            } else if currentRole != nil {
                currentText += "\n" + line
            }
        }
        if let role = currentRole {
            messages.append((role, currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        return messages.isEmpty ? nil : messages
    }

    static func isAIFile(_ fileName: String) -> Bool {
        fileName == instructionsFileName || fileName.hasPrefix(chatPrefix)
    }

    static func isInstructionsFile(_ fileName: String) -> Bool {
        fileName == instructionsFileName
    }

    static func isChatFile(_ fileName: String) -> Bool {
        fileName.hasPrefix(chatPrefix)
    }
}
