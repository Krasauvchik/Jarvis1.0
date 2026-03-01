import SwiftUI
import Combine

// MARK: - Theme Mode

enum ThemeMode: String, CaseIterable, Codable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "Светлая"
        case .dark: return "Тёмная"
        case .system: return "Системная"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// MARK: - Theme Manager

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: ThemeMode {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "jarvis_theme")
        }
    }
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: "jarvis_theme"),
           let theme = ThemeMode(rawValue: saved) {
            currentTheme = theme
        } else {
            currentTheme = .dark
        }
    }
}

// MARK: - Adaptive Theme Colors

struct JarvisTheme {
    let isDark: Bool
    
    // MARK: - Backgrounds
    var background: Color {
        isDark ? Color(red: 0.08, green: 0.08, blue: 0.10) : Color(red: 0.96, green: 0.96, blue: 0.97)
    }
    
    var cardBackground: Color {
        isDark ? Color(red: 0.12, green: 0.12, blue: 0.14) : Color.white
    }
    
    var sidebarBackground: Color {
        isDark ? Color(red: 0.10, green: 0.10, blue: 0.12) : Color(red: 0.94, green: 0.94, blue: 0.96)
    }
    
    var inboxBackground: Color {
        isDark ? Color(red: 0.14, green: 0.14, blue: 0.16) : Color(red: 0.98, green: 0.98, blue: 0.99)
    }
    
    // MARK: - Text Colors
    var textPrimary: Color {
        isDark ? Color.white : Color(red: 0.1, green: 0.1, blue: 0.12)
    }
    
    var textSecondary: Color {
        isDark ? Color(white: 0.6) : Color(white: 0.45)
    }
    
    var textTertiary: Color {
        isDark ? Color(white: 0.4) : Color(white: 0.6)
    }
    
    var textMuted: Color {
        isDark ? Color(white: 0.3) : Color(white: 0.7)
    }
    
    // MARK: - UI Elements
    var divider: Color {
        isDark ? Color(white: 0.2) : Color(white: 0.85)
    }
    
    var hourText: Color {
        isDark ? Color(white: 0.35) : Color(white: 0.5)
    }
    
    var hourLine: Color {
        isDark ? Color(white: 0.15) : Color(white: 0.9)
    }
    
    var chipBackground: Color {
        isDark ? Color(white: 0.18) : Color(white: 0.92)
    }
    
    var cardShadow: Color {
        isDark ? Color.black.opacity(0.3) : Color.black.opacity(0.08)
    }
    
    var timelineLine: Color {
        isDark ? Color(white: 0.25) : Color(white: 0.8)
    }
    
    var nowLine: Color {
        Color(red: 0.95, green: 0.45, blue: 0.45)
    }
    
    // MARK: - Static Colors (same for both themes)
    static let accent = Color(red: 0.95, green: 0.45, blue: 0.45)
    static let accentBlue = Color(red: 0.4, green: 0.6, blue: 0.95)
    static let accentGreen = Color(red: 0.4, green: 0.8, blue: 0.5)
    static let accentYellow = Color(red: 0.95, green: 0.8, blue: 0.3)
    static let accentPurple = Color(red: 0.7, green: 0.5, blue: 0.9)
    static let accentOrange = Color(red: 0.95, green: 0.6, blue: 0.3)
    static let accentPink = Color(red: 0.95, green: 0.5, blue: 0.7)
    static let accentTeal = Color(red: 0.3, green: 0.8, blue: 0.8)
    
    static let taskColors: [Color] = [
        Color(red: 0.95, green: 0.45, blue: 0.45),  // Coral
        Color(red: 0.95, green: 0.6, blue: 0.3),   // Orange
        Color(red: 0.95, green: 0.8, blue: 0.3),   // Yellow
        Color(red: 0.4, green: 0.8, blue: 0.5),    // Green
        Color(red: 0.4, green: 0.6, blue: 0.95),   // Blue
        Color(red: 0.7, green: 0.5, blue: 0.9),    // Purple
        Color(red: 0.95, green: 0.5, blue: 0.7),   // Pink
        Color(red: 0.3, green: 0.8, blue: 0.8),    // Teal
    ]
    
    static let categoryColors: [Color] = [
        Color(red: 0.3, green: 0.5, blue: 0.9),
        Color(red: 0.4, green: 0.8, blue: 0.4),
        Color(red: 0.95, green: 0.7, blue: 0.3),
        Color(red: 0.3, green: 0.7, blue: 0.5),
        Color(red: 0.7, green: 0.5, blue: 0.9),
    ]
    
    // MARK: - Dimensions
    enum Dimensions {
        static let cornerRadius: CGFloat = 12
        static let smallCornerRadius: CGFloat = 8
        static let taskBlockRadius: CGFloat = 10
        static let taskIconSize: CGFloat = 36
        static let checkboxSize: CGFloat = 22
        static let sidebarWidth: CGFloat = 220
        static let inboxWidth: CGFloat = 280
        static let hourRowHeight: CGFloat = 80
        static let floatingButtonSize: CGFloat = 56
    }
    
    // MARK: - Helpers
    static func taskColor(for index: Int) -> Color {
        taskColors[abs(index) % taskColors.count]
    }
    
    static func taskColor(for title: String) -> Color {
        let hash = abs(title.hashValue)
        return taskColors[hash % taskColors.count]
    }
    
    // MARK: - Theme Instance
    static func current(for colorScheme: ColorScheme) -> JarvisTheme {
        JarvisTheme(isDark: colorScheme == .dark)
    }
    
    // MARK: - Static Properties (for backward compatibility, uses dark theme)
    static var background: Color { JarvisTheme(isDark: true).background }
    static var cardBackground: Color { JarvisTheme(isDark: true).cardBackground }
    static var sidebarBackground: Color { JarvisTheme(isDark: true).sidebarBackground }
    static var inboxBackground: Color { JarvisTheme(isDark: true).inboxBackground }
    static var textPrimary: Color { JarvisTheme(isDark: true).textPrimary }
    static var textSecondary: Color { JarvisTheme(isDark: true).textSecondary }
    static var textTertiary: Color { JarvisTheme(isDark: true).textTertiary }
    static var textMuted: Color { JarvisTheme(isDark: true).textMuted }
    static var divider: Color { JarvisTheme(isDark: true).divider }
    static var hourText: Color { JarvisTheme(isDark: true).hourText }
    static var hourLine: Color { JarvisTheme(isDark: true).hourLine }
    static var chipBackground: Color { JarvisTheme(isDark: true).chipBackground }
    static var cardShadow: Color { JarvisTheme(isDark: true).cardShadow }
    static var timelineLine: Color { JarvisTheme(isDark: true).timelineLine }
    static var nowLine: Color { JarvisTheme(isDark: true).nowLine }
    static var floatingButtonShadow: Color { JarvisTheme.accent.opacity(0.4) }
    static var timelineDot: Color { Color(white: 0.3) }
}

// MARK: - Environment Key

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = JarvisTheme(isDark: true)
}

extension EnvironmentValues {
    var theme: JarvisTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - View Extensions

extension View {
    func structuredCard(theme: JarvisTheme) -> some View {
        self
            .padding()
            .background(
                RoundedRectangle(cornerRadius: JarvisTheme.Dimensions.cornerRadius)
                    .fill(theme.cardBackground)
                    .shadow(color: theme.cardShadow, radius: 4, y: 2)
            )
    }
    
    func structuredCard() -> some View {
        self
            .padding()
            .background(
                RoundedRectangle(cornerRadius: JarvisTheme.Dimensions.cornerRadius)
                    .fill(JarvisTheme.cardBackground)
            )
    }
    
    func jarvisSectionCard(theme: JarvisTheme) -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: JarvisTheme.Dimensions.cornerRadius)
                    .fill(theme.cardBackground)
                    .shadow(color: theme.cardShadow, radius: 4, y: 2)
            )
    }
    
    func jarvisSectionCard() -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: JarvisTheme.Dimensions.cornerRadius)
                    .fill(JarvisTheme.cardBackground)
            )
    }
    
    func applyTheme(_ themeManager: ThemeManager) -> some View {
        self.preferredColorScheme(themeManager.currentTheme.colorScheme)
    }
}

// MARK: - Button Styles

struct ChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(JarvisTheme.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(JarvisTheme.chipBackground)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(JarvisTheme.accent)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.5)
    }
}

