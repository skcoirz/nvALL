import SwiftUI
import AppKit

struct NoteListView: NSViewRepresentable {
    @EnvironmentObject var notesManager: NotesManager

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let tableView = NSTableView()

        let titleCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        titleCol.title = "Title"
        titleCol.minWidth = 150
        titleCol.resizingMask = [.userResizingMask, .autoresizingMask]
        tableView.addTableColumn(titleCol)

        let dateCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("date"))
        dateCol.title = "Date"
        dateCol.width = 130
        dateCol.minWidth = 80
        dateCol.maxWidth = 200
        dateCol.resizingMask = .userResizingMask
        tableView.addTableColumn(dateCol)

        tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle

        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.rowHeight = 20
        tableView.intercellSpacing = NSSize(width: 4, height: 0)
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsColumnResizing = true
        tableView.allowsColumnReordering = false
        tableView.headerView?.frame.size.height = 19
        if let headerView = tableView.headerView {
            let border = NSView()
            border.wantsLayer = true
            border.layer?.backgroundColor = Theme.borderColor.cgColor
            border.translatesAutoresizingMaskIntoConstraints = false
            headerView.addSubview(border)
            NSLayoutConstraint.activate([
                border.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
                border.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
                border.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
                border.heightAnchor.constraint(equalToConstant: 1)
            ])
        }
        tableView.gridStyleMask = .solidHorizontalGridLineMask
        tableView.gridColor = Theme.borderColor
        tableView.style = .plain
        tableView.target = context.coordinator
        tableView.action = #selector(Coordinator.tableViewClicked(_:))
        tableView.doubleAction = #selector(Coordinator.tableViewClicked(_:))
        tableView.menu = NSMenu()
        tableView.menu?.delegate = context.coordinator

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        context.coordinator.tableView = tableView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.notesManager = notesManager
        let tableView = scrollView.documentView as! NSTableView

        let newNotes = notesManager.filteredNotes.map { $0.fileURL }
        if newNotes != coordinator.lastNotePaths {
            coordinator.lastNotePaths = newNotes
            coordinator.suppressSelectionChange = true
            tableView.reloadData()
            coordinator.suppressSelectionChange = false
        }

        if coordinator.editorHasFocus {
            if tableView.selectedRow >= 0 {
                coordinator.suppressSelectionChange = true
                tableView.deselectAll(nil)
                coordinator.suppressSelectionChange = false
            }
        } else if let selectedID = notesManager.selectedNoteID,
                  let index = notesManager.filteredNotes.firstIndex(where: { $0.id == selectedID }) {
            if tableView.selectedRow != index {
                coordinator.suppressSelectionChange = true
                tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                tableView.scrollRowToVisible(index)
                coordinator.suppressSelectionChange = false
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource, NSMenuDelegate {
        var notesManager: NotesManager?
        weak var tableView: NSTableView?
        var lastNotePaths: [URL] = []
        var suppressSelectionChange = false
        var editorHasFocus = false

        override init() {
            super.init()
            NotificationCenter.default.addObserver(
                self, selector: #selector(editorFocused),
                name: .editorDidFocus, object: nil
            )
            NotificationCenter.default.addObserver(
                self, selector: #selector(searchBarFocused),
                name: .searchBarFocused, object: nil
            )
        }

        @objc func editorFocused() {
            editorHasFocus = true
            tableView?.deselectAll(nil)
        }

        @objc func searchBarFocused() {
            editorHasFocus = false
        }

        private let dateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "MMM d, yyyy 'at' h:mma"
            f.amSymbol = "am"
            f.pmSymbol = "pm"
            return f
        }()

        private let evenColor = Theme.evenRowColor
        private let oddColor = Theme.oddRowColor

        func numberOfRows(in tableView: NSTableView) -> Int {
            notesManager?.filteredNotes.count ?? 0
        }

        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            let rowView = AlternatingRowView()
            rowView.rowColor = row % 2 == 0 ? evenColor : oddColor
            return rowView
        }

        private func makeCenteredCell(tableView: NSTableView, id: String) -> HighlightCellView {
            if let existing = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(id), owner: nil) as? HighlightCellView {
                return existing
            }
            let cellView = HighlightCellView()
            cellView.identifier = NSUserInterfaceItemIdentifier(id)
            let tf = NSTextField(labelWithString: "")
            tf.lineBreakMode = .byTruncatingTail
            tf.cell?.truncatesLastVisibleLine = true
            tf.cell?.wraps = false
            tf.cell?.isScrollable = false
            tf.maximumNumberOfLines = 1
            tf.usesSingleLineMode = true
            tf.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(tf)
            cellView.textField = tf
            let height = tf.heightAnchor.constraint(lessThanOrEqualToConstant: 16)
            height.priority = .defaultHigh
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 2),
                tf.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -2),
                tf.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                height
            ])
            return cellView
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let manager = notesManager,
                  row < manager.filteredNotes.count,
                  let column = tableColumn else { return nil }

            let note = manager.filteredNotes[row]

            switch column.identifier.rawValue {
            case "title":
                let cellView = makeCenteredCell(tableView: tableView, id: "TitleCell")

                let title = note.title
                let preview = String(note.content.prefix(80))
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespaces)

                let attributed = NSMutableAttributedString()
                attributed.append(NSAttributedString(
                    string: title,
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                        .foregroundColor: Theme.textColor
                    ]
                ))
                if !preview.isEmpty {
                    attributed.append(NSAttributedString(
                        string: " — " + preview,
                        attributes: [
                            .font: NSFont.systemFont(ofSize: 11),
                            .foregroundColor: Theme.secondaryText
                        ]
                    ))
                }
                cellView.configure(attributedString: attributed, defaultColor: .labelColor)
                return cellView

            case "date":
                let cellView = makeCenteredCell(tableView: tableView, id: "DateCell")
                let dateStr = NSAttributedString(
                    string: dateFormatter.string(from: note.modifiedDate),
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 10),
                        .foregroundColor: Theme.textColor
                    ]
                )
                cellView.configure(attributedString: dateStr, defaultColor: Theme.textColor)
                return cellView

            default:
                return nil
            }
        }

        @objc func tableViewClicked(_ sender: NSTableView) {
            let row = sender.clickedRow
            guard row >= 0,
                  let manager = notesManager,
                  row < manager.filteredNotes.count else { return }
            editorHasFocus = false
            let note = manager.filteredNotes[row]
            manager.selectedNoteID = note.id
            manager.onSelectionChanged(to: note.id)
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !suppressSelectionChange,
                  let tableView = notification.object as? NSTableView,
                  let manager = notesManager else { return }
            let row = tableView.selectedRow
            guard row >= 0, row < manager.filteredNotes.count else { return }
            editorHasFocus = false
            let note = manager.filteredNotes[row]
            if manager.selectedNoteID != note.id {
                manager.selectedNoteID = note.id
                manager.onSelectionChanged(to: note.id)
            }
        }

        func menuNeedsUpdate(_ menu: NSMenu) {
            menu.removeAllItems()
            guard let tableView = tableView else { return }
            let row = tableView.clickedRow
            guard row >= 0,
                  let manager = notesManager,
                  row < manager.filteredNotes.count else { return }

            let note = manager.filteredNotes[row]
            let versions = manager.versionManager.listVersions(of: note)

            let deleteItem = NSMenuItem(title: "Delete Note", action: #selector(deleteNoteAction(_:)), keyEquivalent: "")
            deleteItem.target = self
            deleteItem.representedObject = note.id
            menu.addItem(deleteItem)

            menu.addItem(NSMenuItem.separator())
            if versions.isEmpty {
                let noVersions = NSMenuItem(title: "No saved versions yet", action: nil, keyEquivalent: "")
                noVersions.isEnabled = false
                menu.addItem(noVersions)
            } else {
                let headerItem = NSMenuItem(title: "Revert to Version (\(versions.count) saved)", action: nil, keyEquivalent: "")
                headerItem.isEnabled = false
                menu.addItem(headerItem)

                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "yyyy-MM-dd"

                let recent = Array(versions.prefix(10))
                let older = Array(versions.dropFirst(10))

                for version in recent {
                    let title = timeFormatter.string(from: version.date)
                    let item = NSMenuItem(title: title, action: #selector(revertAction(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = ["noteID": note.id, "url": version.url] as [String: Any]
                    menu.addItem(item)
                }

                if !older.isEmpty {
                    menu.addItem(NSMenuItem.separator())
                    var grouped: [(String, [(date: Date, url: URL)])] = []
                    for version in older {
                        let day = dayFormatter.string(from: version.date)
                        if let last = grouped.last, last.0 == day {
                            grouped[grouped.count - 1].1.append(version)
                        } else {
                            grouped.append((day, [version]))
                        }
                    }
                    for (day, dayVersions) in grouped {
                        let submenu = NSMenu()
                        for version in dayVersions {
                            let title = timeFormatter.string(from: version.date)
                            let item = NSMenuItem(title: title, action: #selector(revertAction(_:)), keyEquivalent: "")
                            item.target = self
                            item.representedObject = ["noteID": note.id, "url": version.url] as [String: Any]
                            submenu.addItem(item)
                        }
                        let submenuItem = NSMenuItem(title: "\(day) (\(dayVersions.count) versions)", action: nil, keyEquivalent: "")
                        menu.addItem(submenuItem)
                        menu.setSubmenu(submenu, for: submenuItem)
                    }
                }
            }
        }

        @objc func deleteNoteAction(_ sender: NSMenuItem) {
            guard let noteID = sender.representedObject as? UUID,
                  let manager = notesManager,
                  let note = manager.notes.first(where: { $0.id == noteID }) else { return }
            manager.deleteNote(note)
        }

        @objc func revertAction(_ sender: NSMenuItem) {
            guard let info = sender.representedObject as? [String: Any],
                  let noteID = info["noteID"] as? UUID,
                  let url = info["url"] as? URL,
                  let manager = notesManager,
                  let note = manager.notes.first(where: { $0.id == noteID }) else { return }
            manager.revertNote(note, to: url)
        }
    }
}

class HighlightCellView: NSTableCellView {
    var defaultTextColor: NSColor = .labelColor
    var defaultAttributedString: NSAttributedString?

    func configure(attributedString: NSAttributedString, defaultColor: NSColor) {
        defaultTextColor = defaultColor
        defaultAttributedString = attributedString
        textField?.attributedStringValue = attributedString
        textField?.textColor = defaultColor
    }

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            guard let tf = textField else { return }
            if backgroundStyle == .emphasized {
                tf.textColor = .white
                if let attributed = tf.attributedStringValue.mutableCopy() as? NSMutableAttributedString {
                    let range = NSRange(location: 0, length: attributed.length)
                    attributed.addAttribute(.foregroundColor, value: NSColor.white, range: range)
                    tf.attributedStringValue = attributed
                }
            } else if let original = defaultAttributedString {
                tf.attributedStringValue = original
                tf.textColor = defaultTextColor
            }
        }
    }
}

class AlternatingRowView: NSTableRowView {
    var rowColor: NSColor = .white

    override func draw(_ dirtyRect: NSRect) {
        if isSelected {
            Theme.selectionColor.setFill()
        } else {
            rowColor.setFill()
        }
        dirtyRect.fill()
        super.draw(dirtyRect)
    }

    override var isEmphasized: Bool {
        get { true }
        set {}
    }
}
