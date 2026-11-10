import AppKit
import UserNotifications

@MainActor
enum Celebration {
    private static var windows: [NSWindow] = []

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func goalReached(hours: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Feierabend! 🎉"
        content.body = "Tagesziel erreicht: \(Store.format(hours: hours))"
        content.sound = .default
        confetti()
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    static func confetti() {
        for screen in NSScreen.screens { confetti(on: screen) }
    }

    /// Kurzer Schuss aus allen vier Ecken, die Teilchen fallen langsam und verschwinden unten.
    private static func confetti(on screen: NSScreen) {
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false, screen: screen)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        window.contentView = view

        let b = view.bounds
        let colors: [NSColor] = [.systemRed, .systemBlue, .systemGreen, .systemYellow, .systemPink, .systemOrange, .systemPurple]
        let corners: [(CGPoint, CGFloat)] = [
            (CGPoint(x: b.minX, y: b.minY), .pi / 4),
            (CGPoint(x: b.maxX, y: b.minY), 3 * .pi / 4),
            (CGPoint(x: b.minX, y: b.maxY), -.pi / 4),
            (CGPoint(x: b.maxX, y: b.maxY), -3 * .pi / 4),
        ]
        for (position, angle) in corners {
            let emitter = CAEmitterLayer()
            emitter.frame = b
            emitter.emitterShape = .point
            emitter.emitterPosition = position
            emitter.emitterCells = colors.map { color in
                let c = CAEmitterCell()
                c.contents = piece(color: color)
                c.birthRate = 5
                c.lifetime = 8
                c.velocity = 750
                c.velocityRange = 250
                c.emissionLongitude = angle
                c.emissionRange = .pi / 6
                c.yAcceleration = -220
                c.spin = 3
                c.spinRange = 6
                c.scale = 1.2
                c.scaleRange = 0.5
                return c
            }
            view.layer?.addSublayer(emitter)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { emitter.birthRate = 0 }
        }
        window.orderFrontRegardless()
        windows.append(window)
        DispatchQueue.main.asyncAfter(deadline: .now() + 9) {
            window.orderOut(nil)
            windows.removeAll { $0 === window }
        }
    }

    private static func piece(color: NSColor) -> CGImage? {
        let image = NSImage(size: NSSize(width: 12, height: 8), flipped: false) { rect in
            color.setFill()
            NSBezierPath(rect: rect).fill()
            return true
        }
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
