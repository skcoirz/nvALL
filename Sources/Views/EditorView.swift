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
        textView.font = NSFont.systemFont(ofSize: 13)
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
        textView.backgroundColor = .textBackgroundColor
        textView.autoresizingMask = [.width, .height]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

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
            coordinator.isUpdatingText = false
        }

        if searchText != coordinator.lastAppliedSearch {
            coordinator.lastAppliedSearch = searchText
            applyHighlights(in: textView)
            DispatchQueue.main.async {
                self.updateScrollbarMarks(textView: textView, scrollView: scrollView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func applyHighlights(in textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
        guard fullRange.length > 0 else { return }

        storage.beginEditing()
        storage.removeAttribute(.backgroundColor, range: fullRange)

        if !searchText.isEmpty {
            let content = (storage.string as NSString)
            let query = searchText.lowercased()
            var searchStart = 0
            while searchStart < content.length {
                let remaining = NSRange(location: searchStart, length: content.length - searchStart)
                let found = content.range(of: query, options: .caseInsensitive, range: remaining)
                if found.location == NSNotFound { break }
                storage.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.4), range: found)
                searchStart = found.location + found.length
            }
        }
        storage.endEditing()
    }

    private func updateScrollbarMarks(textView: NSTextView, scrollView: NSScrollView) {
        for sub in scrollView.subviews where sub is ScrollbarMarksView {
            sub.removeFromSuperview()
        }
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

        guard !positions.isEmpty else { return }
        let markerWidth: CGFloat = 12
        let overlay = ScrollbarMarksView(positions: positions)
        overlay.frame = NSRect(
            x: scrollView.bounds.width - markerWidth,
            y: 0,
            width: markerWidth,
            height: scrollView.bounds.height
        )
        overlay.autoresizingMask = [.minXMargin, .height]
        scrollView.addSubview(overlay)
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
}

class ScrollbarMarksView: NSView {
    let positions: [CGFloat]

    init(positions: [CGFloat]) {
        self.positions = positions
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemOrange.withAlphaComponent(0.8).setFill()
        for pos in positions {
            let y = pos * bounds.height
            let mark = NSRect(x: 0, y: y - 1, width: bounds.width, height: 2)
            mark.fill()
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
