import Foundation

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

/// Task repository protocol
protocol TaskRepositoryProtocol: AnyObject {
    var tasks: [PlannerTask] { get }
    func add(_ task: PlannerTask)
    func update(_ task: PlannerTask)
    func delete(_ task: PlannerTask)
    func save()
    func load()
}

/// Cloud sync protocol
protocol CloudSyncProtocol: AnyObject {
    var isSyncing: Bool { get }
    var lastSyncDate: Date? { get }
    func forceSync()
    func saveTasks(_ tasks: [PlannerTask])
    func loadTasks() -> [PlannerTask]?
}

/// Network monitor protocol
protocol NetworkMonitorProtocol: AnyObject {
    var isConnected: Bool { get }
    var connectionType: NetworkMonitor.ConnectionType { get }
}

/// AI manager protocol
protocol AIManagerProtocol: AnyObject {
    var selectedModel: AIModel { get set }
    func extractTask(from input: String, referenceDate: Date) -> PlannerTask?
    func generateAdvice(from tasks: [PlannerTask]) -> [String]
}

// MARK: - Conformance Extensions

extension AuthService: AuthServiceProtocol {}
extension CalendarService: CalendarServiceProtocol {}
extension MailService: MailServiceProtocol {}
extension NutritionService: NutritionServiceProtocol {}
