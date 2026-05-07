import AppKit

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let r = CGFloat((value >> 16) & 0xFF) / 255.0
        let g = CGFloat((value >> 8) & 0xFF) / 255.0
        let b = CGFloat(value & 0xFF) / 255.0
        self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}

enum Theme {
    static let editorBackground = NSColor(hex: "#1e1e1e")
    static let sidebarBackground = NSColor(hex: "#252526")
    static let titlebarBackground = NSColor(hex: "#1e1e1e")
    static let textColor = NSColor(hex: "#e0e0e0")
    static let secondaryText = NSColor(hex: "#858585")
    static let selectionColor = NSColor(hex: "#264f78")
    static let borderColor = NSColor(hex: "#3e3e42")
    static let evenRowColor = NSColor(hex: "#1e1e1e")
    static let oddRowColor = NSColor(hex: "#252526")
    static let markerColor = NSColor(hex: "#585858")
    static let searchHighlight = NSColor(hex: "#623800")
    static let accentColor = NSColor(hex: "#0078d4")
}
