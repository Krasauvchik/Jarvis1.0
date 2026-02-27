import SwiftUI

enum JarvisTheme {
    static let background = Color(white: 0.95)
    static let cardBackground = Color.white
    static let accent = Color(red: 0.2, green: 0.4, blue: 0.9)
    static let textPrimary = Color(white: 0.1)
    static let textSecondary = Color(white: 0.45)
    static let chipBackground = Color(red: 0.9, green: 0.94, blue: 1.0)
    static let chipText = Color(red: 0.15, green: 0.35, blue: 0.75)
}

extension View {
    func jarvisSectionCard() -> some View {
        self
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(JarvisTheme.cardBackground)
                    .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
            )
    }
}
