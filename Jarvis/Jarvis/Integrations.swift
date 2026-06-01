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
        var request = Config.authorizedRequest(url: Config.Endpoints.authStatus)
        request.timeoutInterval = 10
        let (data, response) = try await Config.urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return false
        }
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
        let endDate: Date?
        let location: String?
        let isAllDay: Bool?
        let htmlLink: String?
    }
    
    func fetchEvents() async throws -> [PlannerTask] {
        var request = Config.authorizedRequest(url: Config.Endpoints.calendar)
        request.timeoutInterval = 15
        let (data, _) = try await Config.urlSession.data(for: request)
        let events = try Self.decoder.decode([EventDTO].self, from: data)
        
        return events.map {
            PlannerTask(title: $0.title, notes: $0.notes ?? "", date: $0.startDate)
        }
    }
    
    func fetchEventsAsDTO(daysAhead: Int = 30) async throws -> [EventDTO] {
        var request = Config.authorizedRequest(url: Config.Endpoints.calendar(daysAhead: daysAhead))
        request.timeoutInterval = 15
        let (data, response) = try await Config.urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw NSError(domain: "CalendarService", code: code, userInfo: [
                NSLocalizedDescriptionKey: "Server returned status \(code)"
            ])
        }
        return try Self.decoder.decode([EventDTO].self, from: data)
    }
    
    struct CreateEventResult: Decodable, Sendable {
        let id: String?
        let title: String?
        let htmlLink: String?
    }
    
    func createEvent(summary: String, start: Date, end: Date, description: String = "", timeZone: String = "Europe/Moscow") async throws -> CreateEventResult {
        var request = Config.authorizedRequest(url: Config.Endpoints.calendar, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        let fmt = ISO8601DateFormatter()
        let payload: [String: String] = [
            "summary": summary,
            "description": description,
            "start": fmt.string(from: start),
            "end": fmt.string(from: end),
            "timeZone": timeZone
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await Config.urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(domain: "CalendarService", code: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return try JSONDecoder().decode(CreateEventResult.self, from: data)
    }
    
    func deleteEvent(id: String) async throws {
        let url = Config.Endpoints.calendarEvent(id)
        var request = Config.authorizedRequest(url: url, method: "DELETE")
        request.timeoutInterval = 15
        let (_, response) = try await Config.urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(domain: "CalendarService", code: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }
}

// MARK: - Nutrition Service

final class NutritionService: Sendable {
    static let shared = NutritionService()
    private static let decoder = JSONDecoder()
    private init() {}
    
    struct Result: Sendable {
        let title: String
        let calories: Int
    }
    
    func analyze(imageData: Data) async throws -> Result {
        var request = Config.authorizedRequest(url: Config.Endpoints.analyzeMeal, method: "POST")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData
        request.timeoutInterval = 30
        
        let (data, response) = try await Config.urlSession.data(for: request)
        
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw NSError(domain: "NutritionService", code: statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Server returned status \(statusCode)"
            ])
        }
        
        struct Response: Decodable { let title: String; let calories: Int }
        let decoded = try Self.decoder.decode(Response.self, from: data)
        return Result(title: decoded.title, calories: decoded.calories)
    }
}

// MARK: - Mail Service

final class MailService: Sendable {
    static let shared = MailService()
    private static let decoder = JSONDecoder()
    private init() {}
    
    struct MessageDTO: Decodable, Sendable, Identifiable {
        let id: String
        let subject: String
        let from: String
        let date: String
        let snippet: String
    }
    
    func fetchMessages(maxResults: Int = 10) async throws -> [MessageDTO] {
        var url = Config.Endpoints.mail
        if maxResults != 10 {
            if var comp = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                comp.queryItems = [URLQueryItem(name: "max_results", value: String(maxResults))]
                url = comp.url ?? url
            }
        }
        var request = Config.authorizedRequest(url: url)
        request.timeoutInterval = 30
        let (data, _) = try await Config.urlSession.data(for: request)
        if let errorResponse = try? Self.decoder.decode(ErrorResponse.self, from: data) {
            throw MailError.notAuthorized(errorResponse.message)
        }
        return try Self.decoder.decode([MessageDTO].self, from: data)
    }
    
    struct MessageDetail: Decodable, Sendable {
        let id: String
        let threadId: String?
        let subject: String
        let from: String
        let to: String?
        let date: String
        let body: String
        let snippet: String
        let isUnread: Bool?
    }
    
    func fetchMessage(id: String) async throws -> MessageDetail {
        let url = Config.Endpoints.mailMessage(id)
        var request = Config.authorizedRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await Config.urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            if let errorResponse = try? Self.decoder.decode(ErrorResponse.self, from: data) {
                throw MailError.notAuthorized(errorResponse.message)
            }
            throw MailError.sendFailed("Failed to fetch message")
        }
        return try Self.decoder.decode(MessageDetail.self, from: data)
    }
    
    func deleteMessage(id: String) async throws {
        let url = Config.Endpoints.mailDelete(id)
        var request = Config.authorizedRequest(url: url, method: "DELETE")
        request.timeoutInterval = 15
        let (data, response) = try await Config.urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw MailError.sendFailed("Failed to delete message")
        }
    }
    
    func markAsRead(id: String) async throws {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        guard let url = URL(string: "\(Config.backendBase)/mail/messages/\(encoded)/read") else { return }
        var request = Config.authorizedRequest(url: url, method: "POST")
        request.timeoutInterval = 10
        let (_, response) = try await Config.urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw MailError.sendFailed("Failed to mark as read")
        }
    }
    
    struct SummarizeResult: Decodable, Sendable {
        let summary: String
        let source: String?
    }
    
    func summarize(text: String, maxSentences: Int = 3) async throws -> String {
        var request = Config.authorizedRequest(url: Config.Endpoints.aiSummarize, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        let payload: [String: Any] = ["text": text, "max_sentences": maxSentences]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await Config.urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw MailError.sendFailed("Summarize failed")
        }
        let result = try Self.decoder.decode(SummarizeResult.self, from: data)
        return result.summary
    }
    
    struct GenerateReplyResult: Decodable, Sendable {
        let reply: String
        let source: String?
        let error: String?
    }
    
    func generateReplyDraft(originalText: String, instruction: String = "", tone: String = "professional") async throws -> String {
        var request = Config.authorizedRequest(url: Config.Endpoints.aiGenerateReply, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        let payload: [String: String] = [
            "original_text": originalText,
            "instruction": instruction,
            "tone": tone
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await Config.urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw MailError.sendFailed("Generate reply failed")
        }
        let result = try Self.decoder.decode(GenerateReplyResult.self, from: data)
        if let error = result.error, !error.isEmpty, result.reply.isEmpty {
            throw MailError.sendFailed(error)
        }
        return result.reply
    }
    
    struct SendResult: Decodable, Sendable {
        let status: String?
        let id: String?
    }
    
    func sendMessage(to: String, subject: String, body: String) async throws -> SendResult {
        var request = Config.authorizedRequest(url: Config.Endpoints.mailSend, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        let payload: [String: String] = ["to": to, "subject": subject, "body": body]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await Config.urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw MailError.sendFailed("Server error")
        }
        return try Self.decoder.decode(SendResult.self, from: data)
    }
    
    func replyToMessage(messageId: String, body: String) async throws -> SendResult {
        var request = Config.authorizedRequest(url: Config.Endpoints.mailReply, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        let payload: [String: String] = ["message_id": messageId, "body": body]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await Config.urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw MailError.sendFailed("Server error")
        }
        return try Self.decoder.decode(SendResult.self, from: data)
    }
}

struct ErrorResponse: Decodable, Sendable {
    let error: String?
    let message: String?
}

enum MailError: Error, LocalizedError, Sendable {
    case notAuthorized(String?)
    case sendFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized(let msg): return msg ?? "Not authorized"
        case .sendFailed(let msg): return msg
        }
    }
}
