import AppKit

let output = CommandLine.arguments.dropFirst().first ?? "Support/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)

func render(size: CGFloat) -> Data? {
    let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        let inset = rect.insetBy(dx: size * 0.1, dy: size * 0.1)
        let shape = NSBezierPath(roundedRect: inset, xRadius: size * 0.2, yRadius: size * 0.2)
        NSGradient(colors: [NSColor(red: 0.98, green: 0.45, blue: 0.25, alpha: 1), NSColor(red: 0.85, green: 0.18, blue: 0.35, alpha: 1)])?
            .draw(in: shape, angle: -90)
        let config = NSImage.SymbolConfiguration(pointSize: size * 0.38, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
        guard let symbol = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return true }
        let origin = NSPoint(x: rect.midX - symbol.size.width / 2, y: rect.midY - symbol.size.height / 2)
        symbol.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1)
        return true
    }
    guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
    return bitmap.representation(using: .png, properties: [:])
}

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        let url = URL(fileURLWithPath: "\(output)/icon_\(base)x\(base)\(suffix).png")
        try render(size: CGFloat(base * scale))?.write(to: url)
    }
}
