import SwiftUI

// MARK: - Customization Tab

struct SettingsCustomizationTab: View {
    let theme: JarvisTheme
    @Binding var showSleepCalculator: Bool
    @StateObject private var themeManager = ThemeManager.shared
    @ObservedObject private var aiManager = DependencyContainer.shared.aiManager
    @ObservedObject private var langManager = LanguageManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Theme
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsAppearanceLabel)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                VStack(spacing: 0) {
                    ForEach(ThemeMode.allCases, id: \.self) { mode in
                        themeRow(mode: mode)
                        if mode != ThemeMode.allCases.last {
                            Divider().foregroundColor(theme.divider).padding(.leading, 56)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
            
            // Dock magnification
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsInteractions)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                VStack(spacing: 0) {
                    Toggle(isOn: Binding(
                        get: { UserDefaults.standard.object(forKey: Config.Storage.dockMagnificationKey) as? Bool ?? true },
                        set: { UserDefaults.standard.set($0, forKey: Config.Storage.dockMagnificationKey) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.settingsDockMagnification)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(theme.textPrimary)
                            Text(L10n.settingsDockMagnificationDesc)
                                .font(.system(size: 12))
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
            
            // AI Model
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsAIModelLabel)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                VStack(spacing: 0) {
                    Picker(L10n.settingsAIModelLabel, selection: Binding(
                        get: { aiManager.selectedModel },
                        set: { aiManager.selectedModel = $0 }
                    )) {
                        ForEach(AIModel.allCases) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                    .foregroundColor(theme.textPrimary)
                    
                    Text(L10n.settingsAIModelDesc2)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                        .padding(.top, 4)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
            
            // Sleep calculator
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsWellness)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                Button(action: { showSleepCalculator = true }) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(JarvisTheme.accentPurple.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 20))
                                .foregroundColor(JarvisTheme.accentPurple)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.settingsSleepCalculator)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(theme.textPrimary)
                            Text(L10n.settingsSleepCalcDesc)
                                .font(.system(size: 12))
                                .foregroundColor(theme.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(theme.textTertiary)
                    }
                }
                .buttonStyle(.plain)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
            
            // Language
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsLanguage)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                VStack(spacing: 0) {
                    ForEach(AppLanguage.allCases) { lang in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                langManager.language = lang
                            }
                        }) {
                            HStack(spacing: 16) {
                                Text(lang.flag)
                                    .font(.system(size: 24))
                                    .frame(width: 40, height: 40)
                                
                                Text(lang.displayName)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(theme.textPrimary)
                                
                                Spacer()
                                
                                if langManager.language == lang {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(JarvisTheme.accent)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        
                        if lang != AppLanguage.allCases.last {
                            Divider().foregroundColor(theme.divider).padding(.leading, 56)
                        }
                    }
                    
                    Text(L10n.settingsLanguageDesc)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                        .padding(.top, 8)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
        }
    }
    
    private func themeRow(mode: ThemeMode) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                themeManager.currentTheme = mode
            }
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(themeBackgroundColor(for: mode))
                        .frame(width: 40, height: 40)
                    Image(systemName: themeIcon(for: mode))
                        .font(.system(size: 18))
                        .foregroundColor(themeIconColor(for: mode))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                }
                
                Spacer()
                
                if themeManager.currentTheme == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(JarvisTheme.accent)
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
    
    private func themeIcon(for mode: ThemeMode) -> String {
        switch mode {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }
    
    private func themeBackgroundColor(for mode: ThemeMode) -> Color {
        switch mode {
        case .light: return Color(red: 1.0, green: 0.95, blue: 0.8)
        case .dark: return Color(red: 0.15, green: 0.15, blue: 0.2)
        case .system: return Color(red: 0.5, green: 0.5, blue: 0.55)
        }
    }
    
    private func themeIconColor(for mode: ThemeMode) -> Color {
        switch mode {
        case .light: return Color.orange
        case .dark: return Color.purple
        case .system: return Color.white
        }
    }
}
