import Foundation
import Combine

// MARK: - Meeting Briefing Service
/// Автоматически генерирует подготовительную выдержку для встречи из календаря.
///
/// Сценарий: В календарь прилетает "Заведение нового соевого соуса" с участниками →
/// MeetingBriefingService:
/// 1. Извлекает название, участников, описание встречи
/// 2. Через AIContextEngine ищет ВСЕ переписки (Telegram, email) за последний месяц
/// 3. Формирует структурированную выдержку через LLM
/// 4. Сохраняет в заметках задачи/встречи

@MainActor
final class MeetingBriefingService: ObservableObject {
    static let shared = MeetingBriefingService()
    
    @Published var isGenerating = false
    @Published var lastBriefing: MeetingBriefing?
    @Published var error: String?
    
    /// Кэш выдержек по ключу (title + date). Хранится в памяти на время сессии.
    @Published var cachedBriefings: [String: MeetingBriefing] = [:]
    
    private let contextEngine = AIContextEngine.shared
    
    private init() {}
    
    /// Возвращает ключ кэша для события.
    func cacheKey(title: String, date: Date) -> String {
        "\(title.lowercased())_\(Int(date.timeIntervalSince1970 / 3600))"
    }
    
    /// Возвращает кэшированную выдержку, если есть.
    func cachedBriefing(for title: String, date: Date) -> MeetingBriefing? {
        cachedBriefings[cacheKey(title: title, date: date)]
    }
    
    // MARK: - Models
    
    struct MeetingBriefing: Identifiable {
        let id = UUID()
        let meetingTitle: String
        let meetingDate: Date
        let participants: [String]
        let structuredSummary: String
        let keyTopics: [String]
        let actionItems: [String]
        let relatedEmails: Int
        let relatedMessages: Int
        let relatedTasks: Int
        let generatedAt: Date
    }
    
    struct MeetingInfo {
        let title: String
        let date: Date
        let participants: [String]
        let description: String
        
        /// Создаёт MeetingInfo из события Google Calendar
        init(title: String, date: Date, participants: [String] = [], description: String = "") {
            self.title = title
            self.date = date
            self.participants = participants
            self.description = description
        }
        
        /// Создаёт MeetingInfo из PlannerTask
        init(from task: PlannerTask) {
            self.title = task.title
            self.date = task.date
            self.participants = []
            self.description = task.notes
        }
    }
    
    // MARK: - Generate Briefing
    
    /// Главная точка входа: даём встречу — получаем полный брифинг.
    func generateBriefing(for meeting: MeetingInfo, tasks: [PlannerTask] = []) async -> MeetingBriefing? {
        // Check cache first
        let key = cacheKey(title: meeting.title, date: meeting.date)
        if let cached = cachedBriefings[key] {
            lastBriefing = cached
            return cached
        }
        
        isGenerating = true
        error = nil
        defer { isGenerating = false }
        
        // 1. Build search queries from meeting title + participants
        let searchQueries = buildSearchQueries(from: meeting)
        
        // 2. Cross-source search for each query
        var allResults: [AIContextEngine.CrossSourceSearchResult] = []
        for query in searchQueries {
            let result = await contextEngine.searchAllSources(
                query: query,
                lookbackDays: 30,
                localTasks: tasks
            )
            if result.totalMatches > 0 {
                allResults.append(result)
            }
        }
        
        // 3. Merge all cross-source results
        let mergedContext = mergeSearchResults(allResults, meeting: meeting)
        
        // 4. Ask LLM for structured briefing
        let briefingText = await requestLLMBriefing(context: mergedContext, meeting: meeting)
        
        // 5. Parse structured response
        let briefing = MeetingBriefing(
            meetingTitle: meeting.title,
            meetingDate: meeting.date,
            participants: meeting.participants,
            structuredSummary: briefingText,
            keyTopics: extractKeyTopics(from: briefingText),
            actionItems: extractActionItems(from: briefingText),
            relatedEmails: allResults.flatMap(\.mailMatches).count,
            relatedMessages: allResults.flatMap(\.telegramMatches).count,
            relatedTasks: allResults.flatMap(\.taskMatches).count,
            generatedAt: Date()
        )
        
        lastBriefing = briefing
        cachedBriefings[key] = briefing
        // Evict oldest entries if cache grows too large
        if cachedBriefings.count > 20 {
            let sorted = cachedBriefings.sorted { $0.value.generatedAt < $1.value.generatedAt }
            for entry in sorted.prefix(cachedBriefings.count - 15) {
                cachedBriefings.removeValue(forKey: entry.key)
            }
        }
        return briefing
    }
    
    /// Создаёт MeetingInfo из SystemCalendarEvent.
    func meetingInfo(from event: SystemCalendarEvent) -> MeetingInfo {
        MeetingInfo(
            title: event.title,
            date: event.startDate,
            participants: event.attendees,
            description: [event.location, event.notes].compactMap { $0 }.joined(separator: "\n")
        )
    }
    
    /// Генерирует брифинг для системного события календаря.
    func generateBriefing(for event: SystemCalendarEvent, allTasks: [PlannerTask] = []) async -> MeetingBriefing? {
        let info = meetingInfo(from: event)
        return await generateBriefing(for: info, tasks: allTasks)
    }
    
    /// Генерирует брифинг для задачи (если она выглядит как встреча).
    func generateBriefing(for task: PlannerTask, allTasks: [PlannerTask] = []) async -> MeetingBriefing? {
        let meetingInfo = MeetingInfo(from: task)
        return await generateBriefing(for: meetingInfo, tasks: allTasks)
    }
    
    // MARK: - Auto-Briefing for Upcoming Events
    
    /// Автоматически генерирует выдержки для ближайших событий календаря (в пределах lookAheadHours).
    /// Пропускает события, для которых уже есть кэш, и all-day события.
    func prefetchBriefings(lookAheadHours: Int = 4) async {
        let events = EventKitService.shared.systemEvents
        let now = Date()
        let cutoff = now.addingTimeInterval(TimeInterval(lookAheadHours * 3600))
        
        let upcoming = events.filter { event in
            !event.isAllDay &&
            event.startDate > now &&
            event.startDate <= cutoff &&
            cachedBriefing(for: event.title, date: event.startDate) == nil
        }
        
        guard !upcoming.isEmpty else { return }
        
        let tasks = PlannerStore.shared.tasks
        for event in upcoming.prefix(3) { // limit concurrent to avoid overloading
            _ = await generateBriefing(for: event, allTasks: tasks)
        }
    }
    
    // MARK: - Search Query Building
    
    /// Извлекает ключевые слова и фразы для поиска.
    private func buildSearchQueries(from meeting: MeetingInfo) -> [String] {
        var queries: [String] = []
        
        // Full title as primary query
        queries.append(meeting.title)
        
        // Key phrases from title (drop common words)
        let stopWords: Set<String> = [
            "встреча", "митинг", "обсуждение", "совещание", "звонок", "call",
            "meeting", "с", "по", "на", "для", "и", "или", "в", "к", "от",
            "the", "a", "an", "of", "for", "with", "about", "to", "at"
        ]
        let titleWords = meeting.title
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 2 && !stopWords.contains($0) }
        
        if titleWords.count > 1 {
            queries.append(titleWords.joined(separator: " "))
        }
        
        // Each participant as separate search
        for participant in meeting.participants.prefix(5) {
            queries.append(participant)
        }
        
        // Key phrases from description
        if !meeting.description.isEmpty {
            let descWords = meeting.description
                .lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.count > 3 && !stopWords.contains($0) }
            if !descWords.isEmpty {
                queries.append(descWords.prefix(5).joined(separator: " "))
            }
        }
        
        return Array(Set(queries)) // Deduplicate
    }
    
    // MARK: - Result Merging
    
    private func mergeSearchResults(
        _ results: [AIContextEngine.CrossSourceSearchResult],
        meeting: MeetingInfo
    ) -> String {
        let cleanDesc = Self.stripHTMLSimple(meeting.description)
        var context = """
        📋 ВСТРЕЧА: \(meeting.title)
        📅 Дата: \(meeting.date.formatted(date: .abbreviated, time: .shortened))
        👥 Участники: \(meeting.participants.isEmpty ? "не указаны" : meeting.participants.joined(separator: ", "))
        📝 Описание: \(cleanDesc.isEmpty ? "нет" : cleanDesc)
        
        ---
        НАЙДЕННАЯ ИНФОРМАЦИЯ ПО СВЯЗАННЫМ ИСТОЧНИКАМ:
        
        """
        
        for result in results {
            context += contextEngine.formatSearchResultForLLM(result)
            context += "\n"
        }
        
        if results.isEmpty {
            context += "По данной встрече не найдено связанной информации в подключённых источниках.\n"
        }
        
        return context
    }
    
    // MARK: - LLM Briefing Request
    
    private static let briefingSystemPrompt = """
    Ты — Jarvis, AI-ассистент для подготовки к встречам.
    Пользователь даёт тебе информацию о встрече и связанные данные из календаря, почты, мессенджеров.
    
    Сделай СТРУКТУРИРОВАННУЮ ВЫДЕРЖКУ для подготовки к встрече:
    
    📋 СУТЬ ВСТРЕЧИ
    (1-2 предложения: о чём встреча, кто участвует, цель)
    
    🔑 КЛЮЧЕВЫЕ ТЕМЫ
    (Пронумерованный список тем, которые обсуждались / будут обсуждаться)
    
    📨 ИЗ ПЕРЕПИСОК
    (Самое важное из найденных писем и сообщений — решения, договорённости, открытые вопросы)
    
    👥 УЧАСТНИКИ
    (Кто что обсуждал / чего ждёт / о чём спрашивал)
    
    ⚡ НУЖНО ПОДГОТОВИТЬ
    (Конкретный список: что взять, что проверить, какие решения принять)
    
    💡 РЕКОМЕНДАЦИЯ
    (Твой AI-совет на основе всей собранной информации)
    
    Будь конкретен, упоминай имена, даты, цифры. Отвечай по-русски.
    """
    
    private func requestLLMBriefing(context: String, meeting: MeetingInfo) async -> String {
        // 1. Gemini — основной (встроенный ключ, всегда работает)
        if let result = await requestGeminiBriefing(context: context) {
            return result
        }
        
        // 2. Backend — если доступен
        if let result = await requestBackendBriefing(context: context, meeting: meeting) {
            return result
        }
        
        return L10n.briefingAIUnavailable(String(context.prefix(3000)))
    }
    
    private func requestGeminiBriefing(context: String) async -> String? {
        let gemini = GeminiService.shared
        guard gemini.isConfigured else { return nil }
        
        if let result = await gemini.generate(
            message: context,
            systemPrompt: Self.briefingSystemPrompt,
            temperature: 0.4,
            maxTokens: 2048
        ) {
            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }
    
    private func requestBackendBriefing(context: String, meeting: MeetingInfo) async -> String? {
        let url = Config.Endpoints.aiMeetingBriefing
        var request = Config.authorizedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90
        
        let body: [String: Any] = [
            "meeting_title": meeting.title,
            "meeting_date": ISO8601DateFormatter().string(from: meeting.date),
            "participants": meeting.participants,
            "description": meeting.description,
            "context": context,
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await Config.urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            struct Resp: Decodable { let briefing: String }
            return (try? JSONDecoder().decode(Resp.self, from: data))?.briefing
        } catch {
            Logger.shared.warning("MeetingBriefing backend error: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Text Parsing Helpers
    
    private func extractKeyTopics(from text: String) -> [String] {
        extractSection(from: text, header: "КЛЮЧЕВЫЕ ТЕМЫ")
    }
    
    private func extractActionItems(from text: String) -> [String] {
        extractSection(from: text, header: "НУЖНО ПОДГОТОВИТЬ")
    }
    
    private func extractSection(from text: String, header: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var capturing = false
        var items: [String] = []
        
        for line in lines {
            if line.uppercased().contains(header.uppercased()) {
                capturing = true
                continue
            }
            if capturing {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                // Stop at next section header (starts with emoji or is empty after items)
                if trimmed.isEmpty && !items.isEmpty { break }
                if (trimmed.hasPrefix("📋") || trimmed.hasPrefix("🔑") || trimmed.hasPrefix("📨") ||
                    trimmed.hasPrefix("👥") || trimmed.hasPrefix("⚡") || trimmed.hasPrefix("💡")) && !items.isEmpty {
                    break
                }
                if !trimmed.isEmpty {
                    // Clean numbered/bullet items
                    let cleaned = trimmed
                        .replacingOccurrences(of: #"^[\d]+[.\)]\s*"#, with: "", options: .regularExpression)
                        .replacingOccurrences(of: #"^[-•]\s*"#, with: "", options: .regularExpression)
                    if !cleaned.isEmpty {
                        items.append(cleaned)
                    }
                }
            }
        }
        
        return items
    }
    
    /// Simple HTML stripping for meeting descriptions.
    private static func stripHTMLSimple(_ html: String) -> String {
        guard html.contains("<") || html.contains("&") else { return html }
        var result = html.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&nbsp;", " ")
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        result = result.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
