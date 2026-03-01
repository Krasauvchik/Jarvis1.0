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

// MARK: - Conformance Extensions

extension AuthService: AuthServiceProtocol {}
extension CalendarService: CalendarServiceProtocol {}
extension MailService: MailServiceProtocol {}
extension NutritionService: NutritionServiceProtocol {}
