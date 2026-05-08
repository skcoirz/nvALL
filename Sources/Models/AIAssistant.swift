import Foundation

class AIAssistant: ObservableObject {
    @Published var isActive = false
    @Published var conversation: [(role: String, text: String)] = []
    @Published var isLoading = false
    @Published var streamingText = ""
    @Published var currentChatFile: URL?

    private var sessionStarted = false
    private var currentTask: Process?
    var conversationManager: AIConversationManager?
    var onConversationSaved: (() -> Void)?

    func ask(question: String, noteContext: String) {
        isLoading = true
        conversation.append((role: "user", text: question))

        let instructions = conversationManager?.loadInstructions() ?? ""

        let prompt: String
        if !sessionStarted {
            prompt = """
            \(instructions)

            Here are the user's relevant notes for context:

            \(noteContext)

            User question: \(question)
            """
        } else {
            prompt = question
        }

        streamingText = ""
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = self.runClaudeStreaming(prompt: prompt, continueSession: self.sessionStarted)
            DispatchQueue.main.async {
                self.isLoading = false
                let finalText = result ?? self.streamingText
                if !finalText.isEmpty {
                    self.conversation.append((role: "assistant", text: finalText))
                    self.streamingText = ""
                    self.sessionStarted = true
                    self.autoSave()
                    self.onConversationSaved?()
                } else {
                    self.conversation.append((role: "assistant", text: "(No response — check that claude CLI is available)"))
                    self.streamingText = ""
                }
            }
        }
    }

    func pause() {
        isActive = false
    }

    func resume() {
        isActive = true
    }

    func reset() {
        conversation = []
        sessionStarted = false
        isActive = false
        isLoading = false
        currentChatFile = nil
        currentTask?.terminate()
        currentTask = nil
    }

    func loadFromFile(_ url: URL) {
        guard let messages = conversationManager?.loadConversation(from: url) else { return }
        conversation = messages
        currentChatFile = url
        sessionStarted = false
        isActive = true
    }

    private func autoSave() {
        guard let manager = conversationManager else { return }

        let content = formatConversation()

        if let existing = currentChatFile {
            try? content.write(to: existing, atomically: true, encoding: .utf8)
        } else {
            let title = generateTitle()
            let fileName = "\(AIConversationManager.chatPrefix)\(title).md"
            let fileURL = manager.notesDirectory.appendingPathComponent(fileName)
            try? content.write(to: fileURL, atomically: true, encoding: .utf8)
            currentChatFile = fileURL
        }
    }

    private func formatConversation() -> String {
        var content = "# AI Conversation\n\n"
        for message in conversation {
            let prefix = message.role == "user" ? "**Q:**" : "**A:**"
            content += "\(prefix) \(message.text)\n\n"
        }
        return content
    }

    private func generateTitle() -> String {
        let firstQ = conversation.first(where: { $0.role == "user" })?.text ?? "chat"
        let words = firstQ.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .prefix(6)
            .joined(separator: " ")
        return words
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\"", with: "")
            .prefix(50).description
    }

    private func runClaudeStreaming(prompt: String, continueSession: Bool) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/claude")

        var args = ["--dangerously-disable-osx-sandbox"]
        if continueSession { args.append("-c") }
        args.append(contentsOf: ["-p", prompt, "--output-format", "stream-json", "--verbose"])
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        currentTask = process

        do { try process.run() } catch { return nil }

        var fullResult = ""
        let handle = pipe.fileHandleForReading

        while process.isRunning || handle.availableData.count > 0 {
            let data = handle.availableData
            if data.isEmpty { usleep(50000); continue }
            guard let chunk = String(data: data, encoding: .utf8) else { continue }

            for line in chunk.components(separatedBy: "\n") where !line.isEmpty {
                guard let jsonData = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { continue }

                let type = json["type"] as? String ?? ""

                if type == "assistant", let message = json["message"] as? [String: Any],
                   let content = message["content"] as? [[String: Any]] {
                    for item in content {
                        if let text = item["text"] as? String {
                            fullResult = text
                            DispatchQueue.main.async { self.streamingText = text }
                        }
                    }
                } else if type == "result", let result = json["result"] as? String {
                    fullResult = result
                    DispatchQueue.main.async { self.streamingText = result }
                }
            }
        }

        currentTask = nil
        return fullResult.isEmpty ? nil : fullResult
    }

    private func runClaude(prompt: String, continueSession: Bool) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/claude")

        var args = ["--dangerously-disable-osx-sandbox"]
        if continueSession {
            args.append("-c")
        }
        args.append(contentsOf: ["-p", prompt, "--output-format", "json"])
        process.arguments = args

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        currentTask = process

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return "Error launching claude: \(error.localizedDescription)"
        }

        currentTask = nil

        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
            let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errData, encoding: .utf8) ?? "unknown error"
            return "Claude error: \(errStr)"
        }

        for line in output.components(separatedBy: "\n") {
            guard let jsonData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let result = json["result"] as? String else { continue }
            return result
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
