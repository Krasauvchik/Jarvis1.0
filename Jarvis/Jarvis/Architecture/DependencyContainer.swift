import Foundation
import SwiftUI
import Combine

// MARK: - Dependency Container (Service Locator Pattern)

/// Central dependency container for managing app services
/// Allows easy mocking for tests and flexible configuration
final class DependencyContainer: ObservableObject {
    static let shared = DependencyContainer()
    
    @Published private var _updated = false
    
    // MARK: - Services
    
    lazy var authService: AuthServiceProtocol = AuthService.shared
    lazy var calendarService: CalendarServiceProtocol = CalendarService.shared
    lazy var mailService: MailServiceProtocol = MailService.shared
    lazy var nutritionService: NutritionServiceProtocol = NutritionService.shared
    
    // MARK: - Managers
    
    lazy var plannerStore: PlannerStore = .shared
    lazy var cloudSync: CloudSync = .shared
    lazy var networkMonitor: NetworkMonitor = .shared
    lazy var themeManager: ThemeManager = .shared
    lazy var notificationManager: NotificationManager = .shared
    lazy var aiManager: AIManager = AIManager()
    
    // MARK: - Configuration
    
    private(set) var isTestEnvironment = false
    
    private init() {}
    
    // MARK: - Test Support
    
    /// Configure container for testing with mock services
    func configureForTesting(
        authService: AuthServiceProtocol? = nil,
        calendarService: CalendarServiceProtocol? = nil
    ) {
        isTestEnvironment = true
        if let auth = authService { self.authService = auth }
        if let calendar = calendarService { self.calendarService = calendar }
    }
    
    /// Reset to production services
    func resetToProduction() {
        isTestEnvironment = false
        authService = AuthService.shared
        calendarService = CalendarService.shared
        mailService = MailService.shared
        nutritionService = NutritionService.shared
    }
}

// MARK: - Environment Key

private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue = DependencyContainer.shared
}

extension EnvironmentValues {
    var dependencies: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    func withDependencies(_ container: DependencyContainer = .shared) -> some View {
        environment(\.dependencies, container)
    }
}

// MARK: - Property Wrapper for Dependency Injection

@propertyWrapper
struct Injected<T> {
    private let keyPath: KeyPath<DependencyContainer, T>
    
    init(_ keyPath: KeyPath<DependencyContainer, T>) {
        self.keyPath = keyPath
    }
    
    var wrappedValue: T {
        DependencyContainer.shared[keyPath: keyPath]
    }
}
