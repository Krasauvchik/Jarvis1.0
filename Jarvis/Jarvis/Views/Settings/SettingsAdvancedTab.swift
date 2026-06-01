import SwiftUI
#if os(iOS)
import UniformTypeIdentifiers
#endif

// MARK: - Advanced Tab

struct SettingsAdvancedTab: View {
    let theme: JarvisTheme
    @StateObject private var store = PlannerStore.shared
    @State private var shareURL: IdentifiableURL?
    @State private var showImportPicker = false
    @State private var importMessage: String?
    @State private var showImportResult = false
    @State private var showDeleteCompletedConfirm = false
    @State private var showMessengerSettings = false
    @State private var selectedSound: NotificationSoundChoice = {
        NotificationSoundChoice(rawValue: UserDefaults.standard.string(forKey: "jarvis_notification_sound_choice") ?? "default") ?? .default
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            notificationsSection
            aiSkillsSection
            dataSection
            statsSection
            aboutSection
        }
        .sheet(item: $shareURL) { item in
            #if os(iOS)
            ShareSheetView(items: [item.url])
            #else
            EmptyView()
            #endif
        }
        .alert(L10n.settingsImportLabel, isPresented: $showImportResult) {
            Button("OK", role: .cancel) { }
        } message: {
            if let msg = importMessage { Text(msg) }
        }
        .confirmationDialog(L10n.settingsClearCompletedConfirm, isPresented: $showDeleteCompletedConfirm, titleVisibility: .visible) {
            Button(L10n.deleteAction, role: .destructive) {
                NotificationManager.shared.cancelAll()
                store.removeCompleted()
            }
            Button(L10n.cancel, role: .cancel) { }
        }
        #if os(iOS)
        .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            Task { @MainActor in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    guard url.startAccessingSecurityScopedResource() else {
                        importMessage = L10n.settingsNoAccess
                        showImportResult = true
                        return
                    }
                    defer { url.stopAccessingSecurityScopedResource() }
                    importMessage = ExportImport.importFromURL(url, store: store, merge: true)
                    showImportResult = true
                case .failure:
                    importMessage = L10n.settingsFileSelectionError
                    showImportResult = true
                }
            }
        }
        #endif
    }
    
    // MARK: - Notifications Section
    
    @ViewBuilder
    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.settingsNotificationsLabel)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(theme.textPrimary)
            
            VStack(spacing: 0) {
                Toggle(isOn: Binding(
                    get: { UserDefaults.standard.object(forKey: "jarvis_notifications_enabled") as? Bool ?? true },
                    set: { UserDefaults.standard.set($0, forKey: "jarvis_notifications_enabled") }
                )) {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 18))
                            .foregroundColor(JarvisTheme.accentOrange)
                            .frame(width: 36)
                        Text(L10n.settingsRemindersLabel)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(theme.textPrimary)
                    }
                }
                .padding(.vertical, 6)
                
                Divider().foregroundColor(theme.divider).padding(.leading, 48)
                
                Toggle(isOn: Binding(
                    get: { UserDefaults.standard.object(forKey: "jarvis_notification_sound") as? Bool ?? true },
                    set: { UserDefaults.standard.set($0, forKey: "jarvis_notification_sound") }
                )) {
                    HStack(spacing: 12) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 18))
                            .foregroundColor(JarvisTheme.accentPurple)
                            .frame(width: 36)
                        Text(L10n.settingsSoundLabel)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(theme.textPrimary)
                    }
                }
                .padding(.vertical, 6)
                
                Divider().foregroundColor(theme.divider).padding(.leading, 48)
                
                HStack(spacing: 12) {
                    Image(systemName: "music.note")
                        .font(.system(size: 18))
                        .foregroundColor(JarvisTheme.accentTeal)
                        .frame(width: 36)
                    Picker(L10n.soundCustom, selection: $selectedSound) {
                        ForEach(NotificationSoundChoice.allCases, id: \.self) { sound in
                            Text(sound.displayName).tag(sound)
                        }
                    }
                    .onChange(of: selectedSound) { _, newValue in
                        UserDefaults.standard.set(newValue.rawValue, forKey: "jarvis_notification_sound_choice")
                    }
                }
                .padding(.vertical, 6)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.cardBackground)
            )
        }
    }
    
    // MARK: - AI Skills Section
    
    @ViewBuilder
    private var aiSkillsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.settingsAISkillsLabel)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(theme.textPrimary)
            
            VStack(spacing: 0) {
                aiSkillToggle(title: L10n.settingsCalendarSkill, icon: "calendar", key: Config.Storage.skillCalendarKey, color: JarvisTheme.accentBlue)
                Divider().foregroundColor(theme.divider).padding(.leading, 48)
                aiSkillToggle(title: L10n.settingsMailSkill, icon: "envelope.fill", key: Config.Storage.skillMailKey, color: JarvisTheme.accentOrange)
                Divider().foregroundColor(theme.divider).padding(.leading, 48)
                aiSkillToggle(title: L10n.settingsDeepAnalysis, icon: "brain", key: Config.Storage.skillDeepAnalysisKey, color: JarvisTheme.accentPurple)
                Divider().foregroundColor(theme.divider).padding(.leading, 48)
                aiSkillToggle(title: L10n.settingsVoiceInputLabel, icon: "mic.fill", key: Config.Storage.skillVoiceKey, color: JarvisTheme.accentTeal)
                Divider().foregroundColor(theme.divider).padding(.leading, 48)
                aiSkillToggle(title: L10n.settingsTelegram, icon: "paperplane.fill", key: Config.Storage.skillTelegramKey, color: Color(red: 0.07, green: 0.72, blue: 0.34))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.cardBackground)
            )
            
            Button(action: { showMessengerSettings = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                        .foregroundColor(JarvisTheme.accentTeal)
                        .frame(width: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.settingsConfigureTelegram)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(theme.textPrimary)
                        Text(L10n.settingsConfigureTelegramDesc)
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showMessengerSettings) {
                MessengerSettingsView()
            }
        }
    }
    
    // MARK: - Data Section
    
    @ViewBuilder
    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.settingsDataManagement)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(theme.textPrimary)
            
            VStack(spacing: 0) {
                Button(action: {
                    if let url = ExportImport.createExportURL(store: store) {
                        shareURL = IdentifiableURL(url: url)
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18))
                            .foregroundColor(JarvisTheme.accentBlue)
                            .frame(width: 36)
                        Text(L10n.settingsExportData)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(theme.textTertiary)
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                
                Divider().foregroundColor(theme.divider).padding(.leading, 48)
                
                Button(action: {
                    if let url = ExportImport.createCSVExportURL(store: store) {
                        shareURL = IdentifiableURL(url: url)
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "tablecells")
                            .font(.system(size: 18))
                            .foregroundColor(JarvisTheme.accentOrange)
                            .frame(width: 36)
                        Text(L10n.settingsExportCSV)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(theme.textTertiary)
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                
                Divider().foregroundColor(theme.divider).padding(.leading, 48)
                
                Button(action: { showImportPicker = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 18))
                            .foregroundColor(JarvisTheme.accentGreen)
                            .frame(width: 36)
                        Text(L10n.settingsImportData)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(theme.textTertiary)
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                
                Divider().foregroundColor(theme.divider).padding(.leading, 48)
                
                Button(action: { showDeleteCompletedConfirm = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "trash")
                            .font(.system(size: 18))
                            .foregroundColor(JarvisTheme.accentOrange)
                            .frame(width: 36)
                        Text(L10n.settingsClearCompletedLabel)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(JarvisTheme.accentOrange)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .disabled(store.tasks.filter(\.isCompleted).isEmpty)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.cardBackground)
            )
        }
    }
    
    // MARK: - Stats Section
    
    @ViewBuilder
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.settingsStatistics)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(theme.textPrimary)
            
            HStack(spacing: 12) {
                statBadge(title: L10n.settingsTotal, value: "\(store.tasks.count)", color: JarvisTheme.accent)
                statBadge(title: L10n.settingsDone, value: "\(store.tasks.filter(\.isCompleted).count)", color: JarvisTheme.accentGreen)
                statBadge(title: L10n.settingsInbox, value: "\(store.tasks.filter { $0.isInbox && !$0.isCompleted }.count)", color: JarvisTheme.accentOrange)
            }
        }
    }
    
    // MARK: - About Section
    
    @ViewBuilder
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.settingsAboutLabel)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(theme.textPrimary)
            
            VStack(spacing: 0) {
                HStack {
                    Text(L10n.settingsVersionLabel)
                        .font(.system(size: 15))
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    Text(Bundle.main.appVersion)
                        .font(.system(size: 14))
                        .foregroundColor(theme.textSecondary)
                }
                .padding(.vertical, 8)
                
                Divider().foregroundColor(theme.divider)
                
                HStack {
                    Text(L10n.settingsBuildLabel)
                        .font(.system(size: 15))
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    Text(Bundle.main.buildNumber)
                        .font(.system(size: 14))
                        .foregroundColor(theme.textSecondary)
                }
                .padding(.vertical, 8)
                
                Divider().foregroundColor(theme.divider)
                
                Button(action: { OnboardingManager.shared.resetOnboarding() }) {
                    HStack {
                        Text(L10n.settingsReplayOnboarding)
                            .font(.system(size: 15))
                            .foregroundColor(JarvisTheme.accentBlue)
                        Spacer()
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14))
                            .foregroundColor(JarvisTheme.accentBlue)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.cardBackground)
            )
        }
    }
    
    private func aiSkillToggle(title: String, icon: String, key: String, color: Color) -> some View {
        Toggle(isOn: Binding(
            get: { UserDefaults.standard.object(forKey: key) as? Bool ?? true },
            set: { UserDefaults.standard.set($0, forKey: key) }
        )) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 36)
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(theme.textPrimary)
            }
        }
        .padding(.vertical, 6)
    }
    
    private func statBadge(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBackground)
        )
    }
}
