import Foundation
import Combine

// MARK: - AI Context Engine
/// Центральный интеллектуальный движок Jarvis.
/// Агрегирует данные из ВСЕХ подключённых источников (календарь, почта, Telegram)
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
        let taskMatches: [TaskMatch]
        let generatedAt: Date
        
        var totalMatches: Int {
            calendarMatches.count + mailMatches.count + telegramMatches.count + taskMatches.count
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
        let source: String         // "telegram"
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

    // MARK: - Relevance Tokenization

    /// Common filler words that carry no signal for matching similar meetings.
    /// Kept deliberately small and bilingual (RU/EN) — these are the words that
    /// appear in almost every meeting title ("weekly call", "созвон обсудить").
    private static let stopwords: Set<String> = [
        // English
        "the", "and", "for", "with", "you", "your", "this", "that", "from", "about",
        "meeting", "meet", "call", "sync", "catch", "chat", "discuss", "review",
        "weekly", "daily", "monthly", "quick", "team", "online", "zoom", "google",
        // Russian
        "встреча", "созвон", "звонок", "обсуждение", "обсудить", "про", "для", "как",
        "это", "что", "еженедельный", "ежедневный", "который", "нужно", "будет", "наш",
        "team", "онлайн", "зум", "митинг", "встречу", "встрече",
    ]

    /// Splits text into a set of meaningful lowercase tokens (length > 2, no stopwords).
    private func tokenize(_ text: String) -> Set<String> {
        let lowered = text.lowercased()
        let parts = lowered.components(separatedBy: CharacterSet.alphanumerics.inverted)
        return Set(parts.filter { $0.count > 2 && !Self.stopwords.contains($0) })
    }

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
        
        // 2. Local EventKit calendar search (no backend needed)
        let localCalendarMatches = searchLocalCalendar(query: query, lookbackDays: lookbackDays)
        
        // 3. Backend cross-source search (mail + messengers)
        let remoteResults = await searchBackend(query: query, lookbackDays: lookbackDays)
        
        // Merge: prefer local calendar, use remote for mail/telegram
        let calendarMatches = localCalendarMatches.isEmpty
            ? (remoteResults?.calendarMatches ?? [])
            : localCalendarMatches
        
        let result = CrossSourceSearchResult(
            query: query,
            calendarMatches: calendarMatches,
            mailMatches: remoteResults?.mailMatches ?? [],
            telegramMatches: remoteResults?.telegramMatches ?? [],
            taskMatches: taskMatches,
            generatedAt: Date()
        )
        
        lastSearchResult = result
        return result
    }
    
    // MARK: - Local Calendar Search
    
    /// Поиск похожих встреч в локальном EventKit календаре.
    ///
    /// Скоринг взвешенный: совпадение в названии важнее, чем среди участников, а оно —
    /// важнее, чем в заметках/месте. Дополнительно учитывается свежесть: недавняя похожая
    /// встреча информативнее для подготовки, чем такая же годичной давности.
    private func searchLocalCalendar(query: String, lookbackDays: Int) -> [CalendarMatch] {
        let eventKit = EventKitService.shared
        guard eventKit.calendarAccessGranted else { return [] }

        let queryTokens = tokenize(query)
        guard !queryTokens.isEmpty else { return [] }

        let events = eventKit.searchEvents(lookbackDays: lookbackDays, lookAheadDays: 7)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy HH:mm"

        let now = Date()
        // Field weights: title carries the strongest signal, participants next, body last.
        let titleWeight = 1.0, attendeeWeight = 0.6, bodyWeight = 0.3

        let scored: [CalendarMatch] = events.compactMap { event in
            let titleTokens = tokenize(event.title)
            let attendeeTokens = tokenize(event.attendees.joined(separator: " "))
            let bodyTokens = tokenize("\(event.notes ?? "") \(event.location ?? "")")

            let titleHits = queryTokens.intersection(titleTokens).count
            let attendeeHits = queryTokens.intersection(attendeeTokens).count
            let bodyHits = queryTokens.intersection(bodyTokens).count

            let weighted = Double(titleHits) * titleWeight
                + Double(attendeeHits) * attendeeWeight
                + Double(bodyHits) * bodyWeight
            guard weighted > 0 else { return nil }

            // Normalize against query size so scores are comparable across queries.
            let base = min(1.0, weighted / Double(queryTokens.count))

            // Recency factor: ~1.0 today, ~0.5 at 30 days, decaying smoothly afterwards.
            let days = abs(now.timeIntervalSince(event.startDate)) / 86_400
            let recency = 1.0 / (1.0 + days / 30.0)
            let score = base * (0.7 + 0.3 * recency)

            return CalendarMatch(
                id: event.id,
                title: event.title,
                date: dateFormatter.string(from: event.startDate),
                attendees: event.attendees,
                notes: event.notes ?? "",
                relevanceScore: score
            )
        }

        // Drop weak noise matches and keep the strongest, most recent similar meetings.
        return Array(
            scored
                .filter { $0.relevanceScore >= 0.15 }
                .sorted { $0.relevanceScore > $1.relevanceScore }
                .prefix(15)
        )
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
        
        // CodingKeys with snake_case support
        enum CodingKeys: String, CodingKey {
            case calendarMatches = "calendar_matches"
            case mailMatches = "mail_matches"
            case telegramMatches = "telegram_matches"
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
        var request = Config.authorizedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        
        let body: [String: Any] = [
            "query": query,
            "lookback_days": lookbackDays,
            "sources": [
                "calendar": UserDefaults.standard.bool(forKey: Config.Storage.skillCalendarKey),
                "mail": UserDefaults.standard.bool(forKey: Config.Storage.skillMailKey),
                "telegram": UserDefaults.standard.bool(forKey: Config.Storage.skillTelegramKey),
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await Config.urlSession.data(for: request)
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
        
        if result.totalMatches == 0 {
            text += L10n.nothingFound + "\n"
        }
        
        return text
    }
}
