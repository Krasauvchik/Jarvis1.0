import SwiftUI

// MARK: - Account Tab

struct SettingsAccountTab: View {
    let theme: JarvisTheme
    @StateObject private var cloudSync = CloudSync.shared
    @StateObject private var store = PlannerStore.shared
    @State private var showDeleteAllConfirm = false
    @State private var showResetConfirm = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Structured Cloud section
            settingsCard(title: L10n.settingsStructuredCloud) {
                VStack(spacing: 12) {
                    // Sync status
                    HStack {
                        Text(L10n.settingsSyncLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.textTertiary)
                        Spacer()
                        Button(action: { cloudSync.forceSync() }) {
                            Text(L10n.settingsResync)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(JarvisTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: cloudSync.isSyncing ? "icloud" : "checkmark.icloud.fill")
                            .font(.system(size: 18))
                            .foregroundColor(theme.textSecondary)
                        
                        Text(cloudSync.isSyncing ? L10n.settingsSyncInProgress : (cloudSync.lastSyncDate != nil ? L10n.settingsSynced : L10n.settingsICloudEnabled))
                            .font(.system(size: 15))
                            .foregroundColor(theme.textPrimary)
                        
                        if cloudSync.isSyncing {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        
                        Spacer()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.cardBackground.opacity(0.5))
                    )
                    
                    if let err = cloudSync.syncError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(JarvisTheme.accentOrange)
                            Text(err)
                                .font(.system(size: 12))
                                .foregroundColor(JarvisTheme.accentOrange)
                        }
                    }
                    
                    // Account
                    HStack {
                        Text(L10n.settingsAccountLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.textTertiary)
                        Spacer()
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "at")
                            .font(.system(size: 16))
                            .foregroundColor(theme.textSecondary)
                        Text(L10n.settingsICloudAccount)
                            .font(.system(size: 15))
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.cardBackground.opacity(0.5))
                    )
                }
            }
            
            // Danger Zone
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsDangerZone)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                HStack(spacing: 12) {
                    Button(action: { showDeleteAllConfirm = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 14))
                            Text(L10n.settingsDeleteAccount)
                                .font(.system(size: 14, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .fixedSize()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.red.opacity(0.5), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { showResetConfirm = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 14))
                            Text(L10n.settingsResetApp)
                                .font(.system(size: 14, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundColor(JarvisTheme.accentOrange)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .fixedSize()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(JarvisTheme.accentOrange.opacity(0.5), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
            }
        }
        .confirmationDialog(L10n.settingsDeleteAllData, isPresented: $showDeleteAllConfirm, titleVisibility: .visible) {
            Button(L10n.settingsDeleteEverything, role: .destructive) {
                NotificationManager.shared.cancelAll()
                store.removeAll()
            }
            Button(L10n.cancel, role: .cancel) { }
        } message: {
            Text(L10n.settingsDeleteAllDataDesc)
        }
        .confirmationDialog(L10n.settingsResetAppConfirm, isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button(L10n.settingsResetAction, role: .destructive) {
                UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
                NotificationManager.shared.cancelAll()
                store.removeAll()
            }
            Button(L10n.cancel, role: .cancel) { }
        } message: {
            Text(L10n.settingsResetDesc)
        }
    }
    
    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(theme.textPrimary)
            
            VStack(spacing: 0) {
                content()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.cardBackground)
            )
        }
    }
}
