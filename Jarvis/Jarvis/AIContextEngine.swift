import Foundation
import Combine

// MARK: - AI Context Engine
/// Центральный интеллектуальный движок Jarvis.
/// Агрегирует данные из ВСЕХ подключённых источников (календарь, почта, Telegram, WhatsApp)
/// и выполняет кросс-платформенный поиск по ключевым словам, участникам, датам.
///
/// Пример: пользователю прилетела встреча "Заведение нового соевого соуса" →
/// AIContextEngine.searchAllSources("соевый соус") → находит все переписки,
/// письма, встречи за последний месяц, связанные с этой темой.

@MainActor
final class AIContextEngine: ObservableObject {
    static let shared = AIContextEngine()
    
    @Published var isSearching = false
    @Published var lastSearchResult: CrossSourceSearchResult?
    
    // MARK: - Models
    
    struct CrossSourceSearchResult: Identifiable {
        let id = UUID()
        let query: String
        let calendarMatches: [CalendarMatch]
        let mailMatches: [MailMatch]
        let telegramMatches: [MessengerMatch]
        let whatsappMatches: [MessengerMatch]
        let taskMatches: [TaskMatch]
        let generatedAt: Date
        
        var totalMatches: Int {
            calendarMatches.count + mailMatches.count + telegramMatches.count + whatsappMatches.count + taskMatches.count
        }
    }
    
    struct CalendarMatch: Identifiable {
        let id: String
        let title: String
        let date: String
        let attendees: [String]
        let notes: String
        let relevanceScore: Double
    }
    
    struct MailMatch: Identifiable {
        let id: String
        let subject: String
        let from: String
        let date: String
        let snippet: String
        let relevanceScore: Double
    }
    
    struct MessengerMatch: Identifiable {
        let id = UUID()
        let source: String         // "telegram" | "whatsapp"
        let chatName: String
        let senderName: String
        let messageText: String
        let date: String
        let relevanceScore: Double
    }
    
    struct TaskMatch: Identifiable {
        let id: UUID
        let title: String
        let notes: String
        let date: Date
        let isCompleted: Bool
    }
    
    private init() {}
    
    // MARK: - Cross-Source Search
    
    /// Поиск по ВСЕМ подключённым источникам.
    /// Используется для Meeting Briefing, голосовых запросов типа "что по соевому соусу?".
    func searchAllSources(
        query: String,
        lookbackDays: Int = 30,
        localTasks: [PlannerTask] = []
    ) async -> CrossSourceSearchResult {
        isSearching = true
        defer { isSearching = false }
        
        // 1. Local task search (instant)
        let taskMatches = searchLocalTasks(query: query, tasks: localTasks)
        
        // 2. Backend cross-source search (calendar + mail + messengers)
        let remoteResults = await searchBackend(query: query, lookbackDays: lookbackDays)
        
        let result = CrossSourceSearchResult(
            query: query,
            calendarMatches: remoteResults?.calendarMatches ?? [],
            mailMatches: remoteResults?.mailMatches ?? [],
            telegramMatches: remoteResults?.telegramMatches ?? [],
            whatsappMatches: remoteResults?.whatsappMatches ?? [],
            taskMatches: taskMatches,
            generatedAt: Date()
        )
        
        lastSearchResult = result
        return result
    }
    
    /// Быстрый поиск только по локальным задачам (оффлайн).
    func searchLocalTasks(query: String, tasks: [PlannerTask]) -> [TaskMatch] {
        let keywords = query.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 }
        guard !keywords.isEmpty else { return [] }
        
        return tasks.compactMap { task in
            let titleLower = task.title.lowercased()
            let notesLower = task.notes.lowercased()
            let matchCount = keywords.filter { titleLower.contains($0) || notesLower.contains($0) }.count
            
            guard matchCount > 0 else { return nil }
            return TaskMatch(
                id: task.id,
                title: task.title,
                notes: task.notes,
                date: task.date,
                isCompleted: task.isCompleted
            )
        }
    }
    
    // MARK: - Backend API
    
    private struct BackendSearchResult: Decodable {
        let calendarMatches: [BackendCalendarMatch]?
        let mailMatches: [BackendMailMatch]?
        let telegramMatches: [BackendMessengerMatch]?
        let whatsappMatches: [BackendMessengerMatch]?
        
        // CodingKeys with snake_case support
        enum CodingKeys: String, CodingKey {
            case calendarMatches = "calendar_matches"
            case mailMatches = "mail_matches"
            case telegramMatches = "telegram_matches"
            case whatsappMatches = "whatsapp_matches"
        }
    }
    
    private struct BackendCalendarMatch: Decodable {
        let id: String
        let title: String
        let date: String
        let attendees: [String]?
        let notes: String?
        let relevance: Double?
    }
    
    private struct BackendMailMatch: Decodable {
        let id: String
        let subject: String
        let from: String
        let date: String
        let snippet: String
        let relevance: Double?
    }
    
    private struct BackendMessengerMatch: Decodable {
        let source: String
        let chat_name: String
        let sender_name: String
        let message_text: String
        let date: String
        let relevance: Double?
    }
    
    private func searchBackend(query: String, lookbackDays: Int) async -> CrossSourceSearchResult? {
        let url = Config.Endpoints.aiContextSearch
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        
        let body: [String: Any] = [
            "query": query,
            "lookback_days": lookbackDays,
            "sources": [
                "calendar": UserDefaults.standard.bool(forKey: Config.Storage.skillCalendarKey),
                "mail": UserDefaults.standard.bool(forKey: Config.Storage.skillMailKey),
                "telegram": UserDefaults.standard.bool(forKey: Config.Storage.skillTelegramKey),
                "whatsapp": UserDefaults.standard.bool(forKey: Config.Storage.skillWhatsAppKey),
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                Logger.shared.warning("AIContextEngine: backend returned non-200")
                return nil
            }
            
            let decoded = try JSONDecoder().decode(BackendSearchResult.self, from: data)
            
            return CrossSourceSearchResult(
                query: query,
                calendarMatches: (decoded.calendarMatches ?? []).map {
                    CalendarMatch(id: $0.id, title: $0.title, date: $0.date, attendees: $0.attendees ?? [], notes: $0.notes ?? "", relevanceScore: $0.relevance ?? 0.5)
                },
                mailMatches: (decoded.mailMatches ?? []).map {
                    MailMatch(id: $0.id, subject: $0.subject, from: $0.from, date: $0.date, snippet: $0.snippet, relevanceScore: $0.relevance ?? 0.5)
                },
                telegramMatches: (decoded.telegramMatches ?? []).map {
                    MessengerMatch(source: $0.source, chatName: $0.chat_name, senderName: $0.sender_name, messageText: $0.message_text, date: $0.date, relevanceScore: $0.relevance ?? 0.5)
                },
                whatsappMatches: (decoded.whatsappMatches ?? []).map {
                    MessengerMatch(source: $0.source, chatName: $0.chat_name, senderName: $0.sender_name, messageText: $0.message_text, date: $0.date, relevanceScore: $0.relevance ?? 0.5)
                },
                taskMatches: [],
                generatedAt: Date()
            )
        } catch {
            Logger.shared.warning("AIContextEngine: search error: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Format for LLM / Display
    
    /// Превращает результат поиска в текстовый контекст для LLM.
    func formatSearchResultForLLM(_ result: CrossSourceSearchResult) -> String {
        var text = "🔍 Результаты поиска по запросу: \"\(result.query)\"\n\n"
        
        if !result.taskMatches.isEmpty {
            text += "📋 ЗАДАЧИ (\(result.taskMatches.count)):\n"
            for t in result.taskMatches.prefix(10) {
                text += "  - \(t.isCompleted ? "✅" : "⬜") \(t.title) (\(t.date.formatted(date: .abbreviated, time: .shortened)))\n"
                if !t.notes.isEmpty { text += "    📝 \(t.notes.prefix(100))\n" }
            }
        }
        
        if !result.calendarMatches.isEmpty {
            text += "\n📅 КАЛЕНДАРЬ (\(result.calendarMatches.count)):\n"
            for e in result.calendarMatches.prefix(10) {
                text += "  - \(e.title) — \(e.date)\n"
                if !e.attendees.isEmpty { text += "    👥 \(e.attendees.joined(separator: ", "))\n" }
                if !e.notes.isEmpty { text += "    📝 \(e.notes.prefix(100))\n" }
            }
        }
        
        if !result.mailMatches.isEmpty {
            text += "\n📧 ПОЧТА (\(result.mailMatches.count)):\n"
            for m in result.mailMatches.prefix(10) {
                text += "  - \(m.from): \(m.subject) (\(m.date))\n    \(m.snippet.prefix(120))\n"
            }
        }
        
        if !result.telegramMatches.isEmpty {
            text += "\n💬 TELEGRAM (\(result.telegramMatches.count)):\n"
            for m in result.telegramMatches.prefix(15) {
                text += "  - [\(m.chatName)] \(m.senderName): \(m.messageText.prefix(150)) (\(m.date))\n"
            }
        }
        
        if !result.whatsappMatches.isEmpty {
            text += "\n💬 WHATSAPP (\(result.whatsappMatches.count)):\n"
            for m in result.whatsappMatches.prefix(15) {
                text += "  - [\(m.chatName)] \(m.senderName): \(m.messageText.prefix(150)) (\(m.date))\n"
            }
        }
        
        if result.totalMatches == 0 {
            text += L10n.nothingFound + "\n"
        }
        
        return text
    }
}
