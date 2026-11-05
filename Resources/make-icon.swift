#!/usr/bin/env swift
// Erzeugt Resources/AppIcon.icns (Aufruf: swift Resources/make-icon.swift)
import AppKit

func render(_ size: Int) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let inset = s * 0.05
    let bg = NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset),
                          xRadius: s * 0.225, yRadius: s * 0.225)
    NSColor(red: 0.95, green: 0.98, blue: 0.99, alpha: 1).setFill(); bg.fill()
    NSColor(red: 0.8, green: 0.88, blue: 0.9, alpha: 1).setStroke(); bg.lineWidth = s * 0.004; bg.stroke()

    let r = s * 0.125, k: CGFloat = 1.07
    let h = sqrt(3) / 2 * r
    let cells: [(CGFloat, CGFloat, NSColor)] = [
        (0, h, NSColor(red: 0.42, green: 0.69, blue: 0.76, alpha: 1)),
        (-1.5 * r, 0, NSColor(red: 0.0, green: 0.44, blue: 0.56, alpha: 1)),
        (1.5 * r, 0, NSColor(red: 0.60, green: 0.80, blue: 0.86, alpha: 1)),
        (0, -h, NSColor(red: 0.20, green: 0.56, blue: 0.66, alpha: 1)),
    ]
    for (dx, dy, color) in cells {
        let cx = s / 2 + dx * k, cy = s / 2 + dy * k
        let p = NSBezierPath()
        for i in 0..<6 {
            let a = CGFloat(i) * .pi / 3
            let pt = NSPoint(x: cx + r * cos(a), y: cy + r * sin(a))
            i == 0 ? p.move(to: pt) : p.line(to: pt)
        }
        p.close(); p.lineJoinStyle = .round
        color.setFill(); p.fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let dir = "Resources/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: dir)
try! FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: URL(fileURLWithPath: "\(dir)/icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: URL(fileURLWithPath: "\(dir)/icon_\(base)x\(base)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", dir, "-o", "Resources/AppIcon.icns"]
try! p.run(); p.waitUntilExit()
try? FileManager.default.removeItem(atPath: dir)
