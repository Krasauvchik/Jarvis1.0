import Foundation
import SwiftUI
import Combine

// MARK: - Dependency Container (Service Locator Pattern)

/// Central dependency container for managing app services.
/// Allows easy mocking for tests and flexible configuration.
final class DependencyContainer: ObservableObject {
    static let shared = DependencyContainer()
    
    // MARK: - Services (protocol-backed)
    
    lazy var authService: AuthServiceProtocol = AuthService.shared
    lazy var calendarService: CalendarServiceProtocol = CalendarService.shared
    lazy var mailService: MailServiceProtocol = MailService.shared
    lazy var nutritionService: NutritionServiceProtocol = NutritionService.shared
    
    // MARK: - Managers (protocol-backed where applicable)
    
    lazy var cloudSync: CloudSyncProtocol = CloudSync.shared
    lazy var networkMonitor: NetworkMonitorProtocol = NetworkMonitor.shared
    lazy var notificationManager: NotificationManagerProtocol = NotificationManager.shared
    lazy var themeManager: ThemeManagerProtocol = ThemeManager.shared
    
    // MARK: - Managers (concrete — complex API surface, protocol extraction deferred)
    
    lazy var plannerStore: PlannerStore = .shared
    lazy var aiManager: AIManager = AIManager()
    lazy var calendarSyncService: CalendarSyncService = .shared
    #if !os(watchOS)
    lazy var messengerService: MessengerService = .shared
    #endif
    
    // MARK: - Configuration
    
    private(set) var isTestEnvironment = false
    
    private init() {}
    
    // MARK: - Test Support
    
    /// Configure container for testing with mock services.
    /// Pass only the services you want to mock — the rest stay production.
    func configureForTesting(
        authService: AuthServiceProtocol? = nil,
        calendarService: CalendarServiceProtocol? = nil,
        mailService: MailServiceProtocol? = nil,
        nutritionService: NutritionServiceProtocol? = nil,
        cloudSync: CloudSyncProtocol? = nil,
        networkMonitor: NetworkMonitorProtocol? = nil,
        notificationManager: NotificationManagerProtocol? = nil,
        themeManager: ThemeManagerProtocol? = nil
    ) {
        isTestEnvironment = true
        if let v = authService { self.authService = v }
        if let v = calendarService { self.calendarService = v }
        if let v = mailService { self.mailService = v }
        if let v = nutritionService { self.nutritionService = v }
        if let v = cloudSync { self.cloudSync = v }
        if let v = networkMonitor { self.networkMonitor = v }
        if let v = notificationManager { self.notificationManager = v }
        if let v = themeManager { self.themeManager = v }
    }
    
    /// Reset all services to production singletons.
    func resetToProduction() {
        isTestEnvironment = false
        authService = AuthService.shared
        calendarService = CalendarService.shared
        mailService = MailService.shared
        nutritionService = NutritionService.shared
        cloudSync = CloudSync.shared
        networkMonitor = NetworkMonitor.shared
        notificationManager = NotificationManager.shared
        themeManager = ThemeManager.shared
        plannerStore = .shared
        aiManager = AIManager()
        calendarSyncService = .shared
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
