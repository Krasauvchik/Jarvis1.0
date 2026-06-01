import SwiftUI

// MARK: - Sidebar Modules Settings View
// Allows users to toggle individual modules and choose presets.
// Inspired by Things 3's clean simplicity and Structured's focus timer/calendar approach.

struct SidebarModulesSettingsView: View {
    let theme: JarvisTheme
    @Bindable private var moduleManager = ModuleManager.shared
    @State private var selectedPreset: ModulePreset?
    @State private var isEditMode = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Quick Presets
                presetsSection

                // Individual Modules by Group
                ForEach(ModuleManager.ModuleGroup.allCases, id: \.rawValue) { group in
                    moduleGroupSection(group)
                }
            }
            .padding()
        }
        .background(theme.background)
    }

    // MARK: - Presets

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.modulePresets, systemImage: "wand.and.stars")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textSecondary)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(ModulePreset.allCases) { preset in
                    presetCard(preset)
                }
            }
        }
    }

    private func presetCard(_ preset: ModulePreset) -> some View {
        let isActive = isPresetActive(preset)
        return Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                applyPreset(preset)
            }
        }) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isActive ? preset.accentColor : preset.accentColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: preset.icon)
                        .font(.system(size: 20))
                        .foregroundColor(isActive ? .white : preset.accentColor)
                }

                VStack(spacing: 2) {
                    Text(preset.localizedName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                    Text(preset.description)
                        .font(.system(size: 11))
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isActive ? preset.accentColor : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Module Group

    private func moduleGroupSection(_ group: ModuleManager.ModuleGroup) -> some View {
        let modules = moduleManager.orderedModules.filter { $0.group == group }
        guard !modules.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Label(group.localizedName, systemImage: group.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textSecondary)

                VStack(spacing: 0) {
                    ForEach(Array(modules.enumerated()), id: \.element.id) { index, module in
                        moduleRow(module, isLast: index == modules.count - 1)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackground))
            }
        )
    }

    private func moduleRow(_ module: ModuleManager.Module, isLast: Bool) -> some View {
        let enabled = moduleManager.isEnabled(module.section)
        return VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Icon
                Image(systemName: module.section.icon)
                    .font(.system(size: 16))
                    .foregroundColor(enabled ? module.section.color : theme.textTertiary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(enabled ? module.section.color.opacity(0.15) : theme.divider.opacity(0.3))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(module.section.localizedName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(enabled ? theme.textPrimary : theme.textTertiary)

                    Text(L10n._moduleDesc(module.descriptionKey))
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { moduleManager.isEnabled(module.section) },
                    set: { moduleManager.setEnabled(module.section, enabled: $0) }
                ))
                .labelsHidden()
                .tint(module.section.color)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !isLast {
                Divider()
                    .padding(.leading, 58)
            }
        }
    }

    // MARK: - Helpers

    private func isPresetActive(_ preset: ModulePreset) -> Bool {
        preset.moduleIDs == moduleManager.enabledModuleIDs
    }

    private func applyPreset(_ preset: ModulePreset) {
        moduleManager.enabledModuleIDs = preset.moduleIDs
        selectedPreset = preset
    }
}

// MARK: - Onboarding Module Selection Page
// Clean page shown during onboarding — pick a preset or customize modules.

struct OnboardingModuleSelectionView: View {
    @Bindable private var moduleManager = ModuleManager.shared
    @State private var selectedPreset: ModulePreset? = .minimal
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 8) {
                Text(L10n.onboardingModulesTitle)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text(L10n.onboardingModulesSubtitle)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer().frame(height: 32)

            // Preset Cards
            VStack(spacing: 14) {
                ForEach(ModulePreset.allCases) { preset in
                    onboardingPresetRow(preset)
                }
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 16)

            Text(L10n.onboardingModulesHint)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button(action: {
                if let preset = selectedPreset {
                    moduleManager.enabledModuleIDs = preset.moduleIDs
                }
                onContinue()
            }) {
                Text(L10n.continueButton)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(JarvisTheme.accent)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 40)
    }

    private func onboardingPresetRow(_ preset: ModulePreset) -> some View {
        let isSelected = selectedPreset == preset
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedPreset = preset
            }
        }) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? preset.accentColor : preset.accentColor.opacity(0.2))
                        .frame(width: 48, height: 48)
                    Image(systemName: preset.icon)
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? .white : preset.accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.localizedName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text(preset.description)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? preset.accentColor : .white.opacity(0.3))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isSelected ? 0.12 : 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? preset.accentColor.opacity(0.6) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
