import SwiftUI

enum Theme: String, CaseIterable, Identifiable {
    case bunt, hell, dunkel
    var id: String { rawValue }

    var title: String {
        switch self {
        case .bunt: return "Bunt"
        case .hell: return "Hell"
        case .dunkel: return "Dunkel"
        }
    }

    var isColorful: Bool { self == .bunt }

    var scheme: ColorScheme? {
        switch self {
        case .bunt: return nil
        case .hell: return .light
        case .dunkel: return .dark
        }
    }

    var background: Color? {
        switch self {
        case .bunt: return nil
        case .hell: return Color(white: 0.96)
        case .dunkel: return Color(white: 0.11)
        }
    }

    var text: Color {
        switch self {
        case .bunt: return Color(nsColor: .labelColor)
        case .hell: return Color(white: 0.1)
        case .dunkel: return Color(white: 0.95)
        }
    }

    var secondaryText: Color {
        switch self {
        case .bunt: return Color(nsColor: .secondaryLabelColor)
        case .hell: return Color(white: 0.4)
        case .dunkel: return Color(white: 0.62)
        }
    }

    var fieldFill: Color {
        switch self {
        case .bunt: return Color(nsColor: .textBackgroundColor)
        case .hell: return .white
        case .dunkel: return Color(white: 0.19)
        }
    }

    var cardFill: Color {
        switch self {
        case .bunt: return .white.opacity(0.08)
        case .hell: return .white
        case .dunkel: return Color(white: 0.16)
        }
    }

    var border: Color {
        switch self {
        case .bunt: return .white.opacity(0.12)
        case .hell: return Color(white: 0.88)
        case .dunkel: return Color(white: 0.28)
        }
    }

    var summaryText: Color { isColorful ? .white : text }

    func tint(_ c: Color) -> Color { isColorful ? c : secondaryText }
    var accent: Color { isColorful ? .blue : (self == .hell ? Color(white: 0.15) : Color(white: 0.92)) }
    var accentText: Color { isColorful ? .white : (self == .hell ? .white : Color(white: 0.1)) }
}

private struct ThemedModifier: ViewModifier {
    let theme: Theme
    func body(content: Content) -> some View {
        Group {
            if let scheme = theme.scheme {
                content.environment(\.colorScheme, scheme)
            } else {
                content
            }
        }
        .background((theme.background ?? .clear).ignoresSafeArea())
    }
}

extension View {
    func themed(_ theme: Theme) -> some View { modifier(ThemedModifier(theme: theme)) }
}
