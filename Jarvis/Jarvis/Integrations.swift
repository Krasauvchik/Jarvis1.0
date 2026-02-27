import Foundation

// MARK: - Auth Service

final class AuthService {
    static let shared = AuthService()
    private init() {}
    
    struct StatusResponse: Decodable {
        let authorized: Bool
    }
    
    func checkAuth() async throws -> Bool {
        let (data, _) = try await URLSession.shared.data(from: Config.Endpoints.authStatus)
        let status = try JSONDecoder().decode(StatusResponse.self, from: data)
        return status.authorized
    }
    
    func openAuthInBrowser() {
        let url = Config.Endpoints.authGoogle
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }
}

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Calendar Service

final class CalendarService {
    static let shared = CalendarService()
    private init() {}
    
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = ISO8601DateFormatter().date(from: str) {
                return date
            }
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withFullDate]
            return fallback.date(from: String(str.prefix(10))) ?? Date()
        }
        return d
    }()
    
    struct EventDTO: Decodable {
        let id: String
        let title: String
        let notes: String?
        let startDate: Date
    }
    
    func fetchEvents() async throws -> [PlannerTask] {
        let (data, _) = try await URLSession.shared.data(from: Config.Endpoints.calendar)
        let events = try decoder.decode([EventDTO].self, from: data)
        
        return events.map {
            PlannerTask(
                title: $0.title,
                notes: $0.notes ?? "Импорт из Google Calendar",
                date: $0.startDate
            )
        }
    }
    
    func fetchEventsAsDTO() async throws -> [EventDTO] {
        let (data, _) = try await URLSession.shared.data(from: Config.Endpoints.calendar)
        return try decoder.decode([EventDTO].self, from: data)
    }
}

// MARK: - Nutrition Service

final class NutritionService {
    static let shared = NutritionService()
    private init() {}
    
    struct Result {
        let title: String
        let calories: Int
    }
    
    func analyze(imageData: Data) async throws -> Result {
        var request = URLRequest(url: Config.Endpoints.analyzeMeal)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct Response: Decodable { let title: String; let calories: Int }
        
        if let decoded = try? JSONDecoder().decode(Response.self, from: data) {
            return Result(title: decoded.title, calories: decoded.calories)
        }
        return Result(title: "Блюдо", calories: 0)
    }
}

// MARK: - Mail Service

final class MailService {
    static let shared = MailService()
    private init() {}
    
    struct MessageDTO: Decodable {
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
        let (data, _) = try await URLSession.shared.data(from: url)
        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            throw MailError.notAuthorized(errorResponse.message)
        }
        return try JSONDecoder().decode([MessageDTO].self, from: data)
    }
}

struct ErrorResponse: Decodable {
    let error: String?
    let message: String?
}

enum MailError: Error {
    case notAuthorized(String?)
}
