import SwiftUI

// MARK: - Privacy Tab

struct SettingsPrivacyTab: View {
    let theme: JarvisTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Hero section
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [JarvisTheme.accentBlue.opacity(0.3), JarvisTheme.accentPurple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 36))
                        .foregroundColor(JarvisTheme.accentBlue)
                }
                
                Text(L10n.settingsPrivacyTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                Text(L10n.settingsPrivacyDesc)
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            
            // Data handling 
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsDataHandling)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                VStack(spacing: 0) {
                    privacyRow(icon: "iphone", title: L10n.settingsLocalStorage, description: L10n.settingsLocalStorageDesc, status: L10n.settingsActive)
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    privacyRow(icon: "icloud.fill", title: L10n.settingsICloudSync, description: L10n.settingsICloudSyncDesc, status: L10n.settingsActive)
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    privacyRow(icon: "brain.head.profile", title: L10n.settingsAIProcessing, description: L10n.settingsAIProcessingDesc, status: L10n.settingsOptional)
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    privacyRow(icon: "location.slash.fill", title: L10n.settingsLocationData, description: L10n.settingsLocationDataDesc, status: L10n.settingsNever)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
            
            // Legal links
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsLegal)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                VStack(spacing: 0) {
                    legalRow(title: L10n.settingsTerms, icon: "doc.text.fill")
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    legalRow(title: L10n.settingsPrivacyPolicy, icon: "hand.raised.fill")
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    legalRow(title: L10n.settingsDataProcessing, icon: "doc.on.doc.fill")
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
            
            // Data rights
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsYourRights)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                VStack(spacing: 0) {
                    rightRow(icon: "arrow.down.doc.fill", title: L10n.settingsExportYourData, description: L10n.settingsExportYourDataDesc, color: JarvisTheme.accentBlue)
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    rightRow(icon: "trash.fill", title: L10n.settingsDeleteAllDataLabel, description: L10n.settingsDeleteAllDataLabelDesc, color: .red)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
        }
    }
    
    private func privacyRow(icon: String, title: String, description: String, status: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(JarvisTheme.accentBlue)
                .frame(width: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(theme.textPrimary)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)
            }
            
            Spacer()
            
            Text(status)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(status == "Never" ? JarvisTheme.accentGreen : JarvisTheme.accentBlue)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill((status == "Never" ? JarvisTheme.accentGreen : JarvisTheme.accentBlue).opacity(0.15))
                )
        }
        .padding(.vertical, 8)
    }
    
    private func legalRow(title: String, icon: String) -> some View {
        Button(action: { }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(JarvisTheme.accentPurple)
                    .frame(width: 36)
                
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(theme.textPrimary)
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12))
                    .foregroundColor(theme.textTertiary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
    
    private func rightRow(icon: String, title: String, description: String, color: Color) -> some View {
        Button(action: { }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 36)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(color)
                    Text(description)
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
