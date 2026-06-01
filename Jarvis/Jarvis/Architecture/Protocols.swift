import Foundation
import SwiftUI

// MARK: - Service Protocols (Protocol-Oriented Design)

/// Base protocol for all services
protocol Service: AnyObject, Sendable {}

/// Authentication service protocol
protocol AuthServiceProtocol: Service {
    func checkAuth() async throws -> Bool
    @MainActor func openAuthInBrowser()
}

/// Calendar service protocol
protocol CalendarServiceProtocol: Service {
    func fetchEvents() async throws -> [PlannerTask]
}

/// Mail service protocol
protocol MailServiceProtocol: Service {
    func fetchMessages(maxResults: Int) async throws -> [MailService.MessageDTO]
}

/// Nutrition analysis protocol
protocol NutritionServiceProtocol: Service {
    func analyze(imageData: Data) async throws -> NutritionService.Result
}

// MARK: - Manager Protocols

/// Cloud sync protocol — abstracts iCloud KV store sync
protocol CloudSyncProtocol: AnyObject {
    var isSyncing: Bool { get }
    var lastSyncDate: Date? { get }
    var syncError: String? { get }
    func forceSync()
    func saveTasks(_ tasks: [PlannerTask])
    func loadTasks() -> [PlannerTask]?
    func saveCategories(_ categories: [TaskCategory])
    func loadCategories() -> [TaskCategory]?
    func saveTags(_ tags: [TaskTag])
    func loadTags() -> [TaskTag]?
    func saveDayBounds(_ bounds: DayBounds)
    func loadDayBounds() -> DayBounds?
}

/// Network reachability monitoring
protocol NetworkMonitorProtocol: AnyObject {
    var isConnected: Bool { get }
}

/// Notification scheduling & management
protocol NotificationManagerProtocol: AnyObject {
    func scheduleAlarm(for task: PlannerTask)
    func cancelAll()
}

/// Theme management
protocol ThemeManagerProtocol: AnyObject {
    var currentTheme: ThemeMode { get set }
}

// MARK: - Conformance Extensions

extension AuthService: AuthServiceProtocol {}
extension CalendarService: CalendarServiceProtocol {}
extension MailService: MailServiceProtocol {}
extension NutritionService: NutritionServiceProtocol {}
extension CloudSync: CloudSyncProtocol {}
extension NetworkMonitor: NetworkMonitorProtocol {}
extension NotificationManager: NotificationManagerProtocol {}
extension ThemeManager: ThemeManagerProtocol {}
