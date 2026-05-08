import SwiftUI
import AppKit

struct EditorView: View {
    @EnvironmentObject var notesManager: NotesManager

    var body: some View {
        Group {
            if notesManager.selectedNoteID != nil {
                HighlightingTextEditor(
                    text: $notesManager.editorContent,
                    searchText: notesManager.searchText,
                    onTextChange: { notesManager.scheduleSave() },
                    restoreCursorPosition: notesManager.pendingCursorPosition,
                    onSaveCursor: { pos in notesManager.saveCursorPosition(pos) }
                )
            } else {
                VStack(spacing: 4) {
                    Text("No note selected")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("Search or press Cmd+N to create a note")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

extension Notification.Name {
    static let editorDidFocus = Notification.Name("editorDidFocus")
    static let searchBarFocused = Notification.Name("searchBarFocused")
    static let saveCursorPosition = Notification.Name("saveCursorPosition")
}

struct HighlightingTextEditor: NSViewRepresentable {
    @Binding var text: String
    var searchText: String
    var onTextChange: () -> Void
    var restoreCursorPosition: Int?
    var onSaveCursor: (Int) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let textView = TabTextView()
        textView.font = NSFont.systemFont(ofSize: 12)
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.delegate = context.coordinator
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.drawsBackground = true
        textView.backgroundColor = Theme.editorBackground
        textView.insertionPointColor = Theme.textColor
        textView.autoresizingMask = [.width, .height]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.scrollerStyle = .legacy
        scrollView.autohidesScrollers = false

        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        let textView = scrollView.documentView as! NSTextView

        if coordinator.isUpdatingText { return }

        if textView.string != text {
            coordinator.isUpdatingText = true
            textView.string = text
            let pos = restoreCursorPosition
            if let pos = pos, pos <= text.count {
                textView.setSelectedRange(NSRange(location: pos, length: 0))
                DispatchQueue.main.async {
                    textView.scrollRangeToVisible(NSRange(location: pos, length: 0))
                }
            } else {
                textView.setSelectedRange(NSRange(location: 0, length: 0))
                textView.scrollToBeginningOfDocument(nil)
            }
            coordinator.lastAppliedSearch = nil
            Self.applyMarkdownAndHighlights(textView: textView, searchText: searchText)
            coordinator.lastAppliedSearch = searchText
            coordinator.isUpdatingText = false
            if !searchText.isEmpty {
                DispatchQueue.main.async {
                    self.updateScrollbarMarks(textView: textView, scrollView: scrollView)
                }
            }
        }

        if searchText != coordinator.lastAppliedSearch {
            coordinator.lastAppliedSearch = searchText
            Self.applySearchHighlights(textView: textView, searchText: searchText)
            DispatchQueue.main.async {
                self.updateScrollbarMarks(textView: textView, scrollView: scrollView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    static func applyMarkdownAndHighlights(textView: NSTextView, searchText: String) {
        guard let storage = textView.textStorage else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
        guard fullRange.length > 0 else { return }

        let scrollView = textView.enclosingScrollView
        let visibleRect = scrollView?.contentView.bounds
        let selectedRanges = textView.selectedRanges

        storage.beginEditing()

        let baseFont = NSFont.systemFont(ofSize: 12)
        storage.addAttribute(.font, value: baseFont, range: fullRange)
        storage.addAttribute(.foregroundColor, value: Theme.textColor, range: fullRange)
        storage.removeAttribute(.strikethroughStyle, range: fullRange)
        storage.removeAttribute(.backgroundColor, range: fullRange)

        applyMarkdownStyling(storage: storage, baseFont: baseFont)
        applySearchHighlightsToStorage(storage: storage, searchText: searchText)

        storage.endEditing()

        if let visibleRect {
            scrollView?.contentView.bounds = visibleRect
        }
        textView.selectedRanges = selectedRanges
    }

    static func applySearchHighlights(textView: NSTextView, searchText: String) {
        guard let storage = textView.textStorage else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
        guard fullRange.length > 0 else { return }

        storage.beginEditing()
        storage.removeAttribute(.backgroundColor, range: fullRange)
        applySearchHighlightsToStorage(storage: storage, searchText: searchText)
        storage.endEditing()
    }

    private static func applySearchHighlightsToStorage(storage: NSTextStorage, searchText: String) {
        guard !searchText.isEmpty else { return }
        let content = (storage.string as NSString)
        let query = searchText.lowercased()
        var searchStart = 0
        while searchStart < content.length {
            let remaining = NSRange(location: searchStart, length: content.length - searchStart)
            let found = content.range(of: query, options: .caseInsensitive, range: remaining)
            if found.location == NSNotFound { break }
            storage.addAttribute(.backgroundColor, value: Theme.searchHighlight, range: found)
            searchStart = found.location + found.length
        }
    }

    private static let boldPattern = try! NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*", options: [])
    private static let italicPattern = try! NSRegularExpression(pattern: "(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)", options: [])
    private static let boldItalicPattern = try! NSRegularExpression(pattern: "\\*\\*\\*(.+?)\\*\\*\\*", options: [])
    private static let strikethroughPattern = try! NSRegularExpression(pattern: "~~(.+?)~~", options: [])

    static func applyMarkdownStyling(storage: NSTextStorage, baseFont: NSFont) {
        let content = storage.string as NSString
        let fullRange = NSRange(location: 0, length: content.length)
        let markerColor = Theme.markerColor

        let fm = NSFontManager.shared
        Self.boldItalicPattern.enumerateMatches(in: storage.string, range: fullRange) { match, _, _ in
            guard let match else { return }
            let inner = match.range(at: 1)
            let boldFont = NSFont.systemFont(ofSize: baseFont.pointSize, weight: .bold)
            let font = fm.convert(boldFont, toHaveTrait: .italicFontMask)
            storage.addAttribute(.font, value: font, range: inner)
            let markerStart = NSRange(location: match.range.location, length: 3)
            let markerEnd = NSRange(location: match.range.location + match.range.length - 3, length: 3)
            storage.addAttribute(.foregroundColor, value: markerColor, range: markerStart)
            storage.addAttribute(.foregroundColor, value: markerColor, range: markerEnd)
        }

        Self.boldPattern.enumerateMatches(in: storage.string, range: fullRange) { match, _, _ in
            guard let match else { return }
            let inner = match.range(at: 1)
            storage.addAttribute(.font, value: NSFont.systemFont(ofSize: baseFont.pointSize, weight: .bold), range: inner)
            let markerStart = NSRange(location: match.range.location, length: 2)
            let markerEnd = NSRange(location: match.range.location + match.range.length - 2, length: 2)
            storage.addAttribute(.foregroundColor, value: markerColor, range: markerStart)
            storage.addAttribute(.foregroundColor, value: markerColor, range: markerEnd)
        }

        Self.italicPattern.enumerateMatches(in: storage.string, range: fullRange) { match, _, _ in
            guard let match else { return }
            let inner = match.range(at: 1)
            let italicFont = fm.convert(baseFont, toHaveTrait: .italicFontMask)
            storage.addAttribute(.font, value: italicFont, range: inner)
            let markerStart = NSRange(location: match.range.location, length: 1)
            let markerEnd = NSRange(location: match.range.location + match.range.length - 1, length: 1)
            storage.addAttribute(.foregroundColor, value: markerColor, range: markerStart)
            storage.addAttribute(.foregroundColor, value: markerColor, range: markerEnd)
        }

        Self.strikethroughPattern.enumerateMatches(in: storage.string, range: fullRange) { match, _, _ in
            guard let match else { return }
            let inner = match.range(at: 1)
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: inner)
            let markerStart = NSRange(location: match.range.location, length: 2)
            let markerEnd = NSRange(location: match.range.location + match.range.length - 2, length: 2)
            storage.addAttribute(.foregroundColor, value: markerColor, range: markerStart)
            storage.addAttribute(.foregroundColor, value: markerColor, range: markerEnd)
        }
    }

    private func updateScrollbarMarks(textView: NSTextView, scrollView: NSScrollView) {
        scrollView.verticalScroller?.subviews.filter { $0 is ScrollbarMarksView }.forEach { $0.removeFromSuperview() }
        guard !searchText.isEmpty,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let content = (textView.string as NSString)
        guard content.length > 0 else { return }

        layoutManager.ensureLayout(for: textContainer)
        let docHeight = layoutManager.usedRect(for: textContainer).height
        let visibleHeight = scrollView.contentView.bounds.height
        let totalScrollable = max(docHeight, visibleHeight)

        let query = searchText.lowercased()
        var positions: [CGFloat] = []
        var searchStart = 0
        while searchStart < content.length {
            let remaining = NSRange(location: searchStart, length: content.length - searchStart)
            let found = content.range(of: query, options: .caseInsensitive, range: remaining)
            if found.location == NSNotFound { break }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: found, actualCharacterRange: nil)
            let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            let inset = textView.textContainerInset.height
            positions.append((rect.midY + inset) / totalScrollable)
            searchStart = found.location + found.length
        }

        guard !positions.isEmpty,
              let scroller = scrollView.verticalScroller else { return }
        let overlay = ScrollbarMarksView(positions: positions)
        overlay.frame = scroller.bounds
        overlay.autoresizingMask = [.width, .height]
        scroller.addSubview(overlay)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HighlightingTextEditor
        var isUpdatingText = false
        var lastAppliedSearch: String?
        weak var textView: NSTextView?

        init(_ parent: HighlightingTextEditor) {
            self.parent = parent
            super.init()
            NotificationCenter.default.addObserver(
                self, selector: #selector(saveCursor),
                name: .saveCursorPosition, object: nil
            )
        }

        @objc func saveCursor() {
            guard let textView = textView else { return }
            let pos = textView.selectedRange().location
            parent.onSaveCursor(pos)
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdatingText,
                  let textView = notification.object as? NSTextView else { return }
            isUpdatingText = true
            parent.text = textView.string
            parent.onTextChange()
            isUpdatingText = false
        }

        func textDidBeginEditing(_ notification: Notification) {
            NotificationCenter.default.post(name: .editorDidFocus, object: nil)
        }
    }
}

class TabTextView: NSTextView {
    override func insertTab(_ sender: Any?) {
        insertText("  ", replacementRange: selectedRange())
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "b":
                wrapSelection(prefix: "**", suffix: "**")
                refreshMarkdown()
                return
            case "i":
                wrapSelection(prefix: "*", suffix: "*")
                refreshMarkdown()
                return
            case "y":
                wrapSelection(prefix: "~~", suffix: "~~")
                refreshMarkdown()
                return
            case "]":
                indentSelection(indent: true)
                return
            case "[":
                indentSelection(indent: false)
                return
            default: break
            }
        }
        super.keyDown(with: event)
    }

    override func insertNewline(_ sender: Any?) {
        let text = (string as NSString)
        let cursorPos = selectedRange().location
        let lineRange = text.lineRange(for: NSRange(location: max(cursorPos - 1, 0), length: 0))
        let currentLine = text.substring(with: lineRange)

        var leadingWhitespace = ""
        for ch in currentLine {
            if ch == " " || ch == "\t" { leadingWhitespace.append(ch) }
            else { break }
        }

        let trimmed = currentLine.trimmingCharacters(in: .whitespaces)
        var prefix = ""
        if trimmed.hasPrefix("- ") {
            prefix = "- "
        } else if trimmed.hasPrefix("* ") && !trimmed.hasPrefix("**") {
            prefix = "* "
        } else if let match = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
            let num = (Int(trimmed[match].trimmingCharacters(in: .punctuationCharacters).trimmingCharacters(in: .whitespaces)) ?? 0) + 1
            prefix = "\(num). "
        }

        insertText("\n" + leadingWhitespace + prefix, replacementRange: selectedRange())
    }

    private func indentSelection(indent: Bool) {
        let text = (string as NSString)
        let range = selectedRange()
        let lineRange = text.lineRange(for: range)
        let lines = text.substring(with: lineRange).components(separatedBy: "\n")

        var totalShift = 0
        var firstLineShift = 0
        var result: [String] = []
        for (i, line) in lines.enumerated() {
            if i == lines.count - 1 && line.isEmpty { result.append(line); continue }
            if indent {
                result.append("  " + line)
                if i == 0 { firstLineShift = 2 }
                totalShift += 2
            } else {
                if line.hasPrefix("  ") {
                    result.append(String(line.dropFirst(2)))
                    if i == 0 { firstLineShift = -2 }
                    totalShift -= 2
                } else if line.hasPrefix(" ") {
                    result.append(String(line.dropFirst(1)))
                    if i == 0 { firstLineShift = -1 }
                    totalShift -= 1
                } else {
                    result.append(line)
                }
            }
        }

        let replacement = result.joined(separator: "\n")
        insertText(replacement, replacementRange: lineRange)

        if range.length == 0 {
            let newPos = max(0, range.location + firstLineShift)
            setSelectedRange(NSRange(location: newPos, length: 0))
        } else {
            let newStart = max(0, range.location + firstLineShift)
            let newLength = max(0, range.length + totalShift - firstLineShift)
            setSelectedRange(NSRange(location: newStart, length: newLength))
        }
    }

    private func refreshMarkdown() {
        guard let storage = textStorage else { return }
        let text = storage.string as NSString
        let cursorPos = min(selectedRange().location, max(text.length - 1, 0))
        let lineRange = text.lineRange(for: NSRange(location: cursorPos, length: 0))
        let expandedStart = max(0, lineRange.location - 5)
        let expandedEnd = min(text.length, lineRange.location + lineRange.length + 5)
        let range = NSRange(location: expandedStart, length: expandedEnd - expandedStart)
        guard range.length > 0 else { return }

        let baseFont = NSFont.systemFont(ofSize: 12)
        let savedBounds = enclosingScrollView?.contentView.bounds

        storage.beginEditing()
        storage.addAttribute(.font, value: baseFont, range: range)
        storage.addAttribute(.foregroundColor, value: Theme.textColor, range: range)
        storage.removeAttribute(.strikethroughStyle, range: range)
        storage.removeAttribute(.backgroundColor, range: range)
        HighlightingTextEditor.applyMarkdownStyling(storage: storage, baseFont: baseFont)
        storage.endEditing()

        if let savedBounds {
            enclosingScrollView?.contentView.bounds = savedBounds
        }
    }

    private func wrapSelection(prefix: String, suffix: String) {
        let range = selectedRange()
        let text = (string as NSString)

        if range.length > 0 {
            let selected = text.substring(with: range)
            let lines = selected.components(separatedBy: "\n")

            if lines.count > 1 {
                let allWrapped = lines.allSatisfy {
                    $0.hasPrefix(prefix) && $0.hasSuffix(suffix) && $0.count > prefix.count + suffix.count
                }
                let result: String
                if allWrapped {
                    result = lines.map { String($0.dropFirst(prefix.count).dropLast(suffix.count)) }.joined(separator: "\n")
                } else {
                    result = lines.map { line in
                        if line.trimmingCharacters(in: .whitespaces).isEmpty { return line }
                        if line.hasPrefix(prefix) && line.hasSuffix(suffix) { return line }
                        return prefix + line + suffix
                    }.joined(separator: "\n")
                }
                insertText(result, replacementRange: range)
                setSelectedRange(NSRange(location: range.location, length: result.count))
            } else if selected.hasPrefix(prefix) && selected.hasSuffix(suffix) && selected.count > prefix.count + suffix.count {
                let unwrapped = String(selected.dropFirst(prefix.count).dropLast(suffix.count))
                insertText(unwrapped, replacementRange: range)
                setSelectedRange(NSRange(location: range.location, length: unwrapped.count))
            } else {
                let wrapped = prefix + selected + suffix
                insertText(wrapped, replacementRange: range)
                setSelectedRange(NSRange(location: range.location + prefix.count, length: range.length))
            }
        } else {
            insertText(prefix + suffix, replacementRange: range)
            setSelectedRange(NSRange(location: range.location + prefix.count, length: 0))
        }
    }
}

class ScrollbarMarksView: NSView {
    let positions: [CGFloat]

    init(positions: [CGFloat]) {
        self.positions = positions
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let trackRect: NSRect
        if let scroller = superview as? NSScroller {
            trackRect = scroller.rect(for: .knobSlot)
        } else {
            trackRect = bounds
        }

        Theme.searchHighlight.setFill()
        for pos in positions {
            let y = trackRect.origin.y + pos * trackRect.height
            let mark = NSRect(x: trackRect.origin.x, y: y - 1, width: trackRect.width, height: 3)
            mark.fill()
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
