#!/usr/bin/env swift
import AppKit

func generateIcon(size: Int) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = CGFloat(size) * 0.22

    let bgPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    NSColor(srgbRed: 0.0, green: 0.47, blue: 0.83, alpha: 1.0).setFill()
    bgPath.fill()

    let fontSize = CGFloat(size) * 0.38
    let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let text = "nv"
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white
    ]
    let textSize = text.size(withAttributes: attrs)
    let textRect = NSRect(
        x: (CGFloat(size) - textSize.width) / 2,
        y: (CGFloat(size) - textSize.height) / 2 - CGFloat(size) * 0.02,
        width: textSize.width,
        height: textSize.height
    )
    text.draw(in: textRect, withAttributes: attrs)

    img.unlockFocus()
    return img
}

func saveAsPNG(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else { return }
    try! pngData.write(to: URL(fileURLWithPath: path))
}

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/nvALL-icons"
try! FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

for size in sizes {
    let img = generateIcon(size: size)
    saveAsPNG(img, to: "\(outputDir)/icon_\(size).png")
}

print("Icons generated in \(outputDir)")

// Create iconset and convert to icns
let iconsetPath = "\(outputDir)/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let mappings: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, size) in mappings {
    let src = "\(outputDir)/icon_\(size).png"
    let dst = "\(iconsetPath)/\(name)"
    try! FileManager.default.copyItem(atPath: src, toPath: dst)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetPath, "-o", "\(outputDir)/AppIcon.icns"]
try! process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    print("AppIcon.icns created at \(outputDir)/AppIcon.icns")
} else {
    print("Failed to create icns")
}
