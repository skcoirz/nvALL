import SwiftUI

struct AIChatView: View {
    @ObservedObject var assistant: AIAssistant

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("AI Chat")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(nsColor: Theme.secondaryText))
                Spacer()
                Text("ESC to close")
                    .font(.system(size: 9))
                    .foregroundColor(Color(nsColor: Theme.secondaryText))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(nsColor: Theme.sidebarBackground))

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(assistant.conversation.enumerated()), id: \.offset) { index, message in
                            HStack(alignment: .top, spacing: 6) {
                                Text(message.role == "user" ? "Q:" : "A:")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(message.role == "user"
                                        ? Color(nsColor: Theme.accentColor)
                                        : Color(nsColor: Theme.textColor))
                                    .frame(width: 16, alignment: .leading)

                                if message.role == "assistant" {
                                    MarkdownText(text: message.text)
                                } else {
                                    Text(message.text)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(nsColor: Theme.textColor))
                                        .textSelection(.enabled)
                                }
                            }
                            .id(index)
                            .padding(.horizontal, 10)
                        }

                        if assistant.isLoading {
                            HStack(alignment: .top, spacing: 6) {
                                Text("A:")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(nsColor: Theme.textColor))
                                    .frame(width: 16, alignment: .leading)
                                if assistant.streamingText.isEmpty {
                                    LoadingIndicator(id: assistant.conversation.count)
                                } else {
                                    MarkdownText(text: assistant.streamingText)
                                }
                            }
                            .padding(.horizontal, 10)
                            .id("loading")
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: assistant.conversation.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo(assistant.conversation.count - 1, anchor: .bottom)
                    }
                }
                .onChange(of: assistant.isLoading) { _, loading in
                    if loading {
                        withAnimation { proxy.scrollTo("loading", anchor: .bottom) }
                    }
                }
            }
        }
        .background(Color(nsColor: Theme.editorBackground))
    }
}

struct MarkdownText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                switch block {
                case .code(let code):
                    Text(code)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(nsColor: Theme.textColor))
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: Theme.sidebarBackground))
                        .cornerRadius(4)
                        .textSelection(.enabled)
                case .text(let line):
                    styledText(line)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private enum Block {
        case text(String)
        case code(String)
    }

    private func parseBlocks() -> [Block] {
        var blocks: [Block] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0
        while i < lines.count {
            if lines[i].hasPrefix("```") {
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                i += 1
                blocks.append(.code(codeLines.joined(separator: "\n")))
            } else {
                blocks.append(.text(lines[i]))
                i += 1
            }
        }
        return blocks
    }

    private func styledText(_ line: String) -> Text {
        var result = Text("")
        var remaining = line[...]

        while !remaining.isEmpty {
            if let boldRange = remaining.range(of: "**") {
                let before = remaining[remaining.startIndex..<boldRange.lowerBound]
                if !before.isEmpty {
                    result = result + Text(before)
                        .font(.system(size: 12))
                        .foregroundColor(Color(nsColor: Theme.textColor))
                }
                let after = remaining[boldRange.upperBound...]
                if let endBold = after.range(of: "**") {
                    let boldText = after[after.startIndex..<endBold.lowerBound]
                    result = result + Text(boldText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(nsColor: Theme.textColor))
                    remaining = after[endBold.upperBound...]
                } else {
                    result = result + Text(remaining)
                        .font(.system(size: 12))
                        .foregroundColor(Color(nsColor: Theme.textColor))
                    remaining = remaining[remaining.endIndex...]
                }
            } else if let codeRange = remaining.range(of: "`") {
                let before = remaining[remaining.startIndex..<codeRange.lowerBound]
                if !before.isEmpty {
                    result = result + Text(before)
                        .font(.system(size: 12))
                        .foregroundColor(Color(nsColor: Theme.textColor))
                }
                let after = remaining[codeRange.upperBound...]
                if let endCode = after.range(of: "`") {
                    let codeText = after[after.startIndex..<endCode.lowerBound]
                    result = result + Text(codeText)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(nsColor: Theme.accentColor))
                    remaining = after[endCode.upperBound...]
                } else {
                    result = result + Text(remaining)
                        .font(.system(size: 12))
                        .foregroundColor(Color(nsColor: Theme.textColor))
                    remaining = remaining[remaining.endIndex...]
                }
            } else {
                result = result + Text(remaining)
                    .font(.system(size: 12))
                    .foregroundColor(Color(nsColor: Theme.textColor))
                remaining = remaining[remaining.endIndex...]
            }
        }
        return result
    }
}

struct LoadingIndicator: View {
    @State private var elapsed: Int = 0
    @State private var dots = ""
    let id: Int
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            Text("Thinking\(dots)")
                .font(.system(size: 12))
                .foregroundColor(Color(nsColor: Theme.secondaryText))
                .italic()
            Text("(\(elapsed)s)")
                .font(.system(size: 10))
                .foregroundColor(Color(nsColor: Theme.secondaryText))
        }
        .onAppear {
            elapsed = 0
            dots = ""
        }
        .onReceive(timer) { _ in
            elapsed += 1
            dots = String(repeating: ".", count: (elapsed % 3) + 1)
        }
    }
}
