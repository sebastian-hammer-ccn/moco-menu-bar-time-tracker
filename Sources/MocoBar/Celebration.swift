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
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        confetti()
    }

    static func confetti() {
        guard let screen = NSScreen.main else { return }
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        window.contentView = view

        let emitter = CAEmitterLayer()
        emitter.frame = view.bounds
        emitter.emitterShape = .line
        emitter.emitterPosition = CGPoint(x: view.bounds.midX, y: view.bounds.maxY + 10)
        emitter.emitterSize = CGSize(width: view.bounds.width, height: 1)
        let colors: [NSColor] = [.systemRed, .systemBlue, .systemGreen, .systemYellow, .systemPink, .systemOrange, .systemPurple]
        emitter.emitterCells = colors.map { color in
            let c = CAEmitterCell()
            c.contents = piece(color: color)
            c.birthRate = 12
            c.lifetime = 8
            c.velocity = 260
            c.velocityRange = 120
            c.emissionLongitude = -.pi / 2
            c.emissionRange = .pi / 5
            c.yAcceleration = -120
            c.spin = 3
            c.spinRange = 4
            c.scale = 0.6
            c.scaleRange = 0.3
            return c
        }
        view.layer?.addSublayer(emitter)
        window.orderFrontRegardless()
        windows.append(window)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { emitter.birthRate = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 11) {
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
