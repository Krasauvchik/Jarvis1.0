import SwiftUI

// MARK: - AI Provider Settings View
// Beautiful card-based AI provider selection with status indicators, descriptions, and sub-model pickers.
// Replaces the old plain Picker in Settings.

struct AIProviderSettingsView: View {
    let theme: JarvisTheme
    @ObservedObject var aiManager: AIManager
    @State private var expandedProvider: AIModel?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Provider Cards
            ForEach(AIModel.allCases) { model in
                providerCard(model)
            }
        }
    }

    // MARK: - Provider Card

    private func providerCard(_ model: AIModel) -> some View {
        let isSelected = aiManager.selectedModel == model
        let isExpanded = expandedProvider == model

        return VStack(spacing: 0) {
            Button(action: {
                guard !model.isComingSoon else { return }  // нельзя выбрать нереализованный провайдер
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    aiManager.selectedModel = model
                }
            }) {
                HStack(spacing: 14) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? model.accentColor : model.accentColor.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: model.icon)
                            .font(.system(size: 20))
                            .foregroundColor(isSelected ? .white : model.accentColor)
                    }

                    // Name + Description
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(model.displayName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(theme.textPrimary)

                            if model.isComingSoon {
                                Text(L10n.aiModelBadgeComingSoon)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.gray))
                            } else if let badge = model.badge {
                                Text(badge)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(model.accentColor))
                            }

                            // Status indicator
                            if !model.isComingSoon {
                                statusDot(for: model)
                            }
                        }
                        Text(model.descriptionText)
                            .font(.system(size: 12))
                            .foregroundColor(theme.textSecondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    // Selection indicator
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? model.accentColor : theme.textTertiary)
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            // Expand/collapse for settings
            if isSelected && hasSubSettings(model) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        expandedProvider = isExpanded ? nil : model
                    }
                }) {
                    HStack {
                        Text(L10n.aiProviderSettings)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(model.accentColor)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11))
                            .foregroundColor(model.accentColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                }
                .buttonStyle(.plain)
            }

            // Expanded sub-settings
            if isExpanded {
                Divider().padding(.horizontal, 14)
                subSettings(for: model)
                    .padding(14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? model.accentColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
                )
        )
        .opacity(model.isComingSoon ? 0.55 : 1.0)
    }

    // MARK: - Status Dot

    private func statusDot(for model: AIModel) -> some View {
        Circle()
            .fill(model.isReady ? Color.green : Color.orange)
            .frame(width: 8, height: 8)
    }

    // MARK: - Sub-Settings

    private func hasSubSettings(_ model: AIModel) -> Bool {
        switch model {
        case .gemini, .yandexGPT, .cloudGPT: return true
        case .heuristic: return false
        }
    }

    @ViewBuilder
    private func subSettings(for model: AIModel) -> some View {
        switch model {
        case .gemini:
            geminiSettings
        case .yandexGPT:
            EmptyView()
        case .cloudGPT:
            cloudGPTSettings
        case .heuristic:
            EmptyView()
        }
    }

    // MARK: - Gemini Settings

    private var geminiSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Model picker
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.settingsAIModel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                Picker("", selection: Binding(
                    get: {
                        GeminiService.Model(rawValue: UserDefaults.standard.string(forKey: Config.Storage.geminiModelKey) ?? "") ?? .flash
                    },
                    set: {
                        UserDefaults.standard.set($0.rawValue, forKey: Config.Storage.geminiModelKey)
                    }
                )) {
                    ForEach(GeminiService.Model.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Optional API key
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.apiKeyOptional)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                SecureField(L10n.geminiApiKeyPlaceholder, text: Binding(
                    get: { SecretStore.get(.geminiAPIKey) ?? "" },
                    set: { SecretStore.set($0, for: .geminiAPIKey) }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
            }

            Text(L10n.aiGeminiHint)
                .font(.system(size: 11))
                .foregroundColor(theme.textTertiary)
        }
    }

    // MARK: - CloudGPT Settings

    private var cloudGPTSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.backendURLLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                TextField("https://...", text: Binding(
                    get: { UserDefaults.standard.string(forKey: Config.Storage.backendURLKey) ?? "" },
                    set: { UserDefaults.standard.set($0, forKey: Config.Storage.backendURLKey) }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.apiKeyLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                SecureField(L10n.backendApiKeyPlaceholder, text: Binding(
                    get: { SecretStore.get(.backendAPIKey) ?? "" },
                    set: { SecretStore.set($0, for: .backendAPIKey) }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
            }

            Text(L10n.aiCloudHint)
                .font(.system(size: 11))
                .foregroundColor(theme.textTertiary)
        }
    }
}
