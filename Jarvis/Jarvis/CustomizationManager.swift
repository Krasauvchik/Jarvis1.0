import SwiftUI

// MARK: - Accent Color Customization (inspired by Structured's accent system)
// Structured offers accent color selection that tints the entire app UI.

@MainActor @Observable
final class AccentColorManager {
    static let shared = AccentColorManager()
    
    var accentIndex: Int {
        didSet { UserDefaults.standard.set(accentIndex, forKey: "jarvis_accent_index") }
    }
    
    static let accentOptions: [(name: String, color: Color)] = [
        ("Coral", Color(red: 0.95, green: 0.45, blue: 0.45)),
        ("Orange", Color(red: 0.95, green: 0.6, blue: 0.3)),
        ("Yellow", Color(red: 0.95, green: 0.8, blue: 0.3)),
        ("Green", Color(red: 0.4, green: 0.8, blue: 0.5)),
        ("Blue", Color(red: 0.4, green: 0.6, blue: 0.95)),
        ("Purple", Color(red: 0.7, green: 0.5, blue: 0.9)),
        ("Pink", Color(red: 0.95, green: 0.5, blue: 0.7)),
        ("Teal", Color(red: 0.3, green: 0.8, blue: 0.8)),
    ]
    
    var currentAccent: Color {
        Self.accentOptions[abs(accentIndex) % Self.accentOptions.count].color
    }
    
    var currentName: String {
        Self.accentOptions[abs(accentIndex) % Self.accentOptions.count].name
    }
    
    private init() {
        self.accentIndex = UserDefaults.standard.integer(forKey: "jarvis_accent_index")
    }
}

// MARK: - Timeline Style Customization (inspired by Structured's timelineStyle/timelineTaskStyle)

enum TimelineStyle: String, CaseIterable, Codable {
    case standard
    case compact
    case detailed
    
    var displayName: String {
        switch self {
        case .standard: return L10n.timelineStyleStandard
        case .compact: return L10n.timelineStyleCompact
        case .detailed: return L10n.timelineStyleDetailed
        }
    }
}

enum TimelineTaskStyle: String, CaseIterable, Codable {
    case rounded
    case minimal
    case card
    
    var displayName: String {
        switch self {
        case .rounded: return L10n.taskStyleRounded
        case .minimal: return L10n.taskStyleMinimal
        case .card: return L10n.taskStyleCard
        }
    }
}

@MainActor @Observable
final class TimelineStyleManager {
    static let shared = TimelineStyleManager()
    
    var timelineStyle: TimelineStyle {
        didSet { UserDefaults.standard.set(timelineStyle.rawValue, forKey: "jarvis_timeline_style") }
    }
    
    var taskStyle: TimelineTaskStyle {
        didSet { UserDefaults.standard.set(taskStyle.rawValue, forKey: "jarvis_task_style") }
    }
    
    private init() {
        let rawTL = UserDefaults.standard.string(forKey: "jarvis_timeline_style") ?? TimelineStyle.standard.rawValue
        self.timelineStyle = TimelineStyle(rawValue: rawTL) ?? .standard
        let rawTS = UserDefaults.standard.string(forKey: "jarvis_task_style") ?? TimelineTaskStyle.rounded.rawValue
        self.taskStyle = TimelineTaskStyle(rawValue: rawTS) ?? .rounded
    }
}

// MARK: - Customization Settings View

struct CustomizationSettingsView: View {
    let theme: JarvisTheme
    @Bindable private var accentManager = AccentColorManager.shared
    @Bindable private var timelineManager = TimelineStyleManager.shared
    @Bindable private var hapticManager = HapticManager.shared
    @Bindable private var accessManager = AccessibilityManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Accent Color
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.accentColor)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                
                HStack(spacing: 10) {
                    ForEach(0..<AccentColorManager.accentOptions.count, id: \.self) { idx in
                        Button(action: {
                            accentManager.accentIndex = idx
                            hapticManager.selection()
                        }) {
                            Circle()
                                .fill(AccentColorManager.accentOptions[idx].color)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: accentManager.accentIndex == idx ? 3 : 0)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(theme.divider, lineWidth: accentManager.accentIndex == idx ? 0 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Divider()
            
            // Timeline Style
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.timelineStyleLabel)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                
                Picker(L10n.timelineStyleLabel, selection: Binding(
                    get: { timelineManager.timelineStyle },
                    set: { timelineManager.timelineStyle = $0 }
                )) {
                    ForEach(TimelineStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Task Style
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.taskStyleLabel)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                
                Picker(L10n.taskStyleLabel, selection: Binding(
                    get: { timelineManager.taskStyle },
                    set: { timelineManager.taskStyle = $0 }
                )) {
                    ForEach(TimelineTaskStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Divider()
            
            // Haptic Feedback
            Toggle(isOn: $hapticManager.isEnabled) {
                Label(L10n.hapticFeedback, systemImage: "waveform")
                    .foregroundColor(theme.textPrimary)
            }
            
            Divider()
            
            // Accessibility
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.accessibilityTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                
                Toggle(isOn: $accessManager.reducedMotion) {
                    Label(L10n.accessReducedMotion, systemImage: "figure.walk")
                        .foregroundColor(theme.textPrimary)
                }
                
                Toggle(isOn: $accessManager.largerText) {
                    Label(L10n.accessLargerText, systemImage: "textformat.size")
                        .foregroundColor(theme.textPrimary)
                }
                
                Toggle(isOn: $accessManager.highContrast) {
                    Label(L10n.accessHighContrast, systemImage: "circle.lefthalf.filled")
                        .foregroundColor(theme.textPrimary)
                }
                
                Toggle(isOn: $accessManager.dyslexiaFont) {
                    Label(L10n.accessDyslexiaFont, systemImage: "textformat.abc")
                        .foregroundColor(theme.textPrimary)
                }
            }
        }
    }
}
