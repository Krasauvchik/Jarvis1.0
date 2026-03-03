import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Auth Service

final class AuthService: Sendable {
    static let shared = AuthService()
    private init() {}
    
    struct StatusResponse: Decodable, Sendable {
        let authorized: Bool
    }
    
    func checkAuth() async throws -> Bool {
        var request = URLRequest(url: Config.Endpoints.authStatus)
        request.timeoutInterval = 10
        let (data, _) = try await URLSession.shared.data(for: request)
        let status = try JSONDecoder().decode(StatusResponse.self, from: data)
        return status.authorized
    }
    
    @MainActor
    func openAuthInBrowser() {
        let url = Config.Endpoints.authGoogle
        #if canImport(UIKit) && !os(watchOS)
        UIApplication.shared.open(url)
        #elseif canImport(AppKit)
        NSWorkspace.shared.open(url)
        #endif
    }
}

// MARK: - Calendar Service

final class CalendarService: Sendable {
    static let shared = CalendarService()
    private init() {}
    
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = ISO8601DateFormatter().date(from: str) { return date }
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withFullDate]
            return fallback.date(from: String(str.prefix(10))) ?? Date()
        }
        return d
    }()
    
    struct EventDTO: Decodable, Sendable {
        let id: String
        let title: String
        let notes: String?
        let startDate: Date
    }
    
    func fetchEvents() async throws -> [PlannerTask] {
        var request = URLRequest(url: Config.Endpoints.calendar)
        request.timeoutInterval = 15
        let (data, _) = try await URLSession.shared.data(for: request)
        let events = try Self.decoder.decode([EventDTO].self, from: data)
        
        return events.map {
            PlannerTask(title: $0.title, notes: $0.notes ?? "", date: $0.startDate)
        }
    }
    
    func fetchEventsAsDTO() async throws -> [EventDTO] {
        var request = URLRequest(url: Config.Endpoints.calendar)
        request.timeoutInterval = 15
        let (data, _) = try await URLSession.shared.data(for: request)
        return try Self.decoder.decode([EventDTO].self, from: data)
    }
}

// MARK: - Nutrition Service

final class NutritionService: Sendable {
    static let shared = NutritionService()
    private init() {}
    
    struct Result: Sendable {
        let title: String
        let calories: Int
    }
    
    func analyze(imageData: Data) async throws -> Result {
        var request = URLRequest(url: Config.Endpoints.analyzeMeal)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData
        request.timeoutInterval = 30
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct Response: Decodable { let title: String; let calories: Int }
        
        if let decoded = try? JSONDecoder().decode(Response.self, from: data) {
            return Result(title: decoded.title, calories: decoded.calories)
        }
        return Result(title: L10n.defaultDish, calories: 0)
    }
}

// MARK: - Mail Service

final class MailService: Sendable {
    static let shared = MailService()
    private init() {}
    
    struct MessageDTO: Decodable, Sendable {
        let id: String
        let subject: String
        let from: String
        let date: String
        let snippet: String
    }
    
    func fetchMessages(maxResults: Int = 10) async throws -> [MessageDTO] {
        var url = Config.Endpoints.mail
        if maxResults != 10 {
            var comp = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            comp.queryItems = [URLQueryItem(name: "max_results", value: String(maxResults))]
            url = comp.url ?? url
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, _) = try await URLSession.shared.data(for: request)
        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            throw MailError.notAuthorized(errorResponse.message)
        }
        return try JSONDecoder().decode([MessageDTO].self, from: data)
    }
}

struct ErrorResponse: Decodable, Sendable {
    let error: String?
    let message: String?
}

enum MailError: Error, Sendable {
    case notAuthorized(String?)
}
