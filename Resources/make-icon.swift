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

    let c = NSPoint(x: s / 2, y: s / 2)
    func circle(_ rad: CGFloat, _ off: NSPoint = .zero, _ color: NSColor) {
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: c.x + off.x - rad, y: c.y + off.y - rad, width: 2 * rad, height: 2 * rad)).fill()
    }
    func hexagon(_ r: CGFloat, _ color: NSColor) {
        let p = NSBezierPath()
        for i in 0..<6 {
            let a = CGFloat(i) * .pi / 3 + .pi / 6
            let pt = NSPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
            i == 0 ? p.move(to: pt) : p.line(to: pt)
        }
        p.close(); p.lineJoinStyle = .round; p.lineWidth = r * 0.06
        color.setFill(); color.setStroke(); p.fill(); p.stroke()
    }
    let teal = NSColor(red: 0.0, green: 0.44, blue: 0.56, alpha: 1)
    circle(s * 0.40, .zero, .black)
    circle(s * 0.31, .zero, .white)
    hexagon(s * 0.235, teal)
    hexagon(s * 0.235 * 0.62, NSColor(red: 0.20, green: 0.56, blue: 0.66, alpha: 1))
    circle(s * 0.105, .zero, .black)
    circle(s * 0.065, NSPoint(x: -s * 0.12, y: s * 0.12), .white)
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
