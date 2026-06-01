import SwiftUI

// MARK: - Subscription Tab

struct SettingsSubscriptionTab: View {
    let theme: JarvisTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Current plan
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsCurrentPlan)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(JarvisTheme.accentYellow.opacity(0.15))
                            .frame(width: 56, height: 56)
                        Image(systemName: "star.fill")
                            .font(.system(size: 26))
                            .foregroundColor(JarvisTheme.accentYellow)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.settingsFreePlan)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                        Text(L10n.settingsBasicFeatures)
                            .font(.system(size: 14))
                            .foregroundColor(theme.textSecondary)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
            
            // Features
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsProFeatures)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                VStack(spacing: 0) {
                    featureRow(icon: "icloud.fill", title: L10n.settingsCloudSync, subtitle: L10n.settingsCloudSyncDesc, included: true)
                    Divider().foregroundColor(theme.divider).padding(.leading, 52)
                    featureRow(icon: "brain.head.profile", title: L10n.settingsAIAssistant, subtitle: L10n.settingsAIAssistantDesc, included: true)
                    Divider().foregroundColor(theme.divider).padding(.leading, 52)
                    featureRow(icon: "chart.bar.fill", title: L10n.settingsAdvancedAnalytics, subtitle: L10n.settingsAdvancedAnalyticsDesc, included: true)
                    Divider().foregroundColor(theme.divider).padding(.leading, 52)
                    featureRow(icon: "calendar.badge.clock", title: L10n.settingsCalendarIntegration, subtitle: L10n.settingsCalendarIntegrationDesc, included: true)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
        }
    }
    
    private func featureRow(icon: String, title: String, subtitle: String, included: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(JarvisTheme.accentBlue)
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
            
            if included {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(JarvisTheme.accentGreen)
            }
        }
        .padding(.vertical, 8)
    }
}
