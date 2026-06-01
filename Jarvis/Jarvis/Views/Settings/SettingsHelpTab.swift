import SwiftUI

// MARK: - Help & Feedback Tab

struct SettingsHelpTab: View {
    let theme: JarvisTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsHelpFeedbackTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                VStack(spacing: 0) {
                    helpRow(icon: "book.fill", title: L10n.settingsUserGuide, subtitle: L10n.settingsUserGuideDesc, color: JarvisTheme.accentBlue)
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    helpRow(icon: "envelope.fill", title: L10n.settingsContactSupport, subtitle: L10n.settingsContactSupportDesc, color: JarvisTheme.accentGreen)
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    helpRow(icon: "star.fill", title: L10n.settingsRateAppStore, subtitle: L10n.settingsRateAppStoreDesc, color: JarvisTheme.accentYellow)
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    helpRow(icon: "ant.fill", title: L10n.settingsReportBug, subtitle: L10n.settingsReportBugDesc, color: JarvisTheme.accentOrange)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
        }
    }
    
    private func helpRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        Button(action: { }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 36)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(theme.textTertiary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}
