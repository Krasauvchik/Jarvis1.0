import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Haptic Feedback Manager (inspired by Structured's haptic system)
// Structured has dedicated _playHaptic and _sliderHaptics settings for rich tactile feedback.
// Also serves as our accessibility improvement layer.

@MainActor @Observable
final class HapticManager {
    static let shared = HapticManager()
    
    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "jarvis_haptics_enabled") }
    }
    
    private init() {
        self.isEnabled = UserDefaults.standard.object(forKey: "jarvis_haptics_enabled") as? Bool ?? true
    }
    
    // MARK: - Impact Feedback
    
    func impact(_ style: HapticStyle = .medium) {
        guard isEnabled else { return }
        #if os(iOS)
        let generator: UIImpactFeedbackGenerator
        switch style {
        case .light: generator = UIImpactFeedbackGenerator(style: .light)
        case .medium: generator = UIImpactFeedbackGenerator(style: .medium)
        case .heavy: generator = UIImpactFeedbackGenerator(style: .heavy)
        case .soft: generator = UIImpactFeedbackGenerator(style: .soft)
        case .rigid: generator = UIImpactFeedbackGenerator(style: .rigid)
        }
        generator.impactOccurred()
        #endif
    }
    
    // MARK: - Notification Feedback
    
    func notification(_ type: NotificationType) {
        guard isEnabled else { return }
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        switch type {
        case .success: generator.notificationOccurred(.success)
        case .warning: generator.notificationOccurred(.warning)
        case .error: generator.notificationOccurred(.error)
        }
        #endif
    }
    
    // MARK: - Selection Feedback
    
    func selection() {
        guard isEnabled else { return }
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #endif
    }
    
    // MARK: - Types
    
    enum HapticStyle {
        case light, medium, heavy, soft, rigid
    }
    
    enum NotificationType {
        case success, warning, error
    }
}

// MARK: - Accessibility Configuration (inspired by Structured's extensive accessibility)
// Structured supports: VoiceOver, Voice Control, Dyslexia Font, Larger Text, Reduced Motion, Sufficient Contrast

@MainActor @Observable
final class AccessibilityManager {
    static let shared = AccessibilityManager()
    
    var reducedMotion: Bool {
        didSet { UserDefaults.standard.set(reducedMotion, forKey: "jarvis_reduced_motion") }
    }
    var largerText: Bool {
        didSet { UserDefaults.standard.set(largerText, forKey: "jarvis_larger_text") }
    }
    var highContrast: Bool {
        didSet { UserDefaults.standard.set(highContrast, forKey: "jarvis_high_contrast") }
    }
    var dyslexiaFont: Bool {
        didSet { UserDefaults.standard.set(dyslexiaFont, forKey: "jarvis_dyslexia_font") }
    }
    
    private init() {
        self.reducedMotion = UserDefaults.standard.bool(forKey: "jarvis_reduced_motion")
        self.largerText = UserDefaults.standard.bool(forKey: "jarvis_larger_text")
        self.highContrast = UserDefaults.standard.bool(forKey: "jarvis_high_contrast")
        self.dyslexiaFont = UserDefaults.standard.bool(forKey: "jarvis_dyslexia_font")
    }
    
    /// Font family: OpenDyslexic if enabled, otherwise system
    var fontDesign: Font.Design {
        dyslexiaFont ? .rounded : .default
    }
    
    /// Multiplier for text sizes
    var textScale: CGFloat {
        largerText ? 1.2 : 1.0
    }
    
    /// Whether to use animations
    var shouldAnimate: Bool {
        !reducedMotion
    }
}

// MARK: - View Modifier for Accessibility

struct AccessibleModifier: ViewModifier {
    private var accessibility = AccessibilityManager.shared
    
    func body(content: Content) -> some View {
        content
            .animation(accessibility.shouldAnimate ? .default : .none, value: UUID())
    }
}

extension View {
    func accessibleStyle() -> some View {
        modifier(AccessibleModifier())
    }
}
