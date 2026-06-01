import SwiftUI
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

// MARK: - App Lock Service (inspired by TaskMind's FaceID app lock)
// TaskMind uses NSFaceIDUsageDescription to offer biometric app protection.

@MainActor @Observable
final class AppLockService {
    static let shared = AppLockService()
    
    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "jarvis_app_lock_enabled") }
    }
    var isUnlocked: Bool = true
    var biometricType: BiometricType = .none
    var isLocked: Bool { isEnabled && !isUnlocked }
    
    enum BiometricType {
        case none, faceID, touchID
        
        var displayName: String {
            switch self {
            case .none: return L10n.appLockPasscode
            case .faceID: return "Face ID"
            case .touchID: return "Touch ID"
            }
        }
        
        var icon: String {
            switch self {
            case .none: return "lock.fill"
            case .faceID: return "faceid"
            case .touchID: return "touchid"
            }
        }
    }
    
    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "jarvis_app_lock_enabled")
        checkBiometricType()
        // If lock not enabled, always unlocked
        if !isEnabled { isUnlocked = true }
    }
    
    func checkBiometricType() {
        #if canImport(LocalAuthentication) && !os(watchOS)
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometricType = .none
            return
        }
        switch context.biometryType {
        case .faceID: biometricType = .faceID
        case .touchID: biometricType = .touchID
        default: biometricType = .none
        }
        #else
        biometricType = .none
        #endif
    }
    
    func lock() {
        guard isEnabled else { return }
        isUnlocked = false
    }
    
    func authenticate() async -> Bool {
        #if canImport(LocalAuthentication) && !os(watchOS)
        let context = LAContext()
        context.localizedCancelTitle = L10n.cancel
        
        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: L10n.appLockReason
            )
            isUnlocked = result
            return result
        } catch {
            Logger.shared.error("Biometric auth failed: \(error)")
            return false
        }
        #else
        isUnlocked = true
        return true
        #endif
    }
    
    /// Called when app moves to background
    func handleBackground() {
        if isEnabled {
            isUnlocked = false
        }
    }
    
    /// Called when app returns to foreground
    func handleForeground() {
        if isEnabled && !isUnlocked {
            Task {
                await authenticate()
            }
        }
    }
}

// MARK: - App Lock Overlay View

struct AppLockView: View {
    private var lockService = AppLockService.shared
    var theme: JarvisTheme = JarvisTheme(isDark: ThemeManager.shared.currentTheme == .dark)
    
    var body: some View {
        if lockService.isLocked {
            ZStack {
                theme.background.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Image(systemName: lockService.biometricType.icon)
                        .font(.system(size: 56))
                        .foregroundColor(JarvisTheme.accent)
                    
                    Text("Jarvis")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                    
                    Text(L10n.appLockMessage)
                        .font(.system(size: 16))
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        Task { await lockService.authenticate() }
                    }) {
                        Label(L10n.appLockUnlock, systemImage: lockService.biometricType.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(JarvisTheme.accent))
                    }
                    .buttonStyle(.plain)
                }
                .padding(40)
            }
            .transition(.opacity)
        }
    }
}
