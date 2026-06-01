import Foundation
import Combine

// MARK: - LLM Digest Service
/// Собирает данные из календаря, почты, Telegram (через бэкенд) и формирует
/// AI-выдержку по текущей ситуации пользователя.

@MainActor
final class LLMDigestService: ObservableObject {
    
    @Published var isLoading = false
    @Published var lastDigest: DigestResult?
    @Published var error: String?
    
    nonisolated init() { }
    
    struct DigestResult: Identifiable {
        let id = UUID()
        let summary: String
        let calendarEvents: [CalendarEventBrief]
        let mailHighlights: [MailHighlight]
        let messengerNotes: [MessengerNote]
        let generatedAt: Date
    }
    
    struct CalendarEventBrief: Identifiable {
        let id: String
        let title: String
        let time: String
    }
    
    struct MailHighlight: Identifiable {
        let id: String
        let subject: String
        let from: String
        let snippet: String
    }
    
    struct MessengerNote: Identifiable {
        let id = UUID()
        let source: String  // "telegram"
        let summary: String
    }
    
    // MARK: - Sources Configuration
    
    struct DigestSources: Sendable {
        var includeCalendar: Bool = true
        var includeMail: Bool = true
        var includeTelegram: Bool = false
        
        nonisolated init(
            includeCalendar: Bool = true,
            includeMail: Bool = true,
            includeTelegram: Bool = false
        ) {
            self.includeCalendar = includeCalendar
            self.includeMail = includeMail
            self.includeTelegram = includeTelegram
        }
    }
    
    // MARK: - Generate Digest
    
    /// Генерирует AI-выдержку по всем разрешённым источникам.
    func generateDigest(
        tasks: [PlannerTask],
        sources: DigestSources = DigestSources()
    ) async -> DigestResult? {
        // Return cached result if still fresh (5 min TTL)
        if let last = lastDigest, Date().timeIntervalSince(last.generatedAt) < 300 {
            return last
        }
        
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        // 1. Gather data from all sources in parallel
        async let calendarData = sources.includeCalendar ? fetchCalendarEvents() : []
        async let mailData = sources.includeMail ? fetchMailHighlights() : []
        async let messengerData = fetchMessengerNotes(
            telegram: sources.includeTelegram
        )
        
        let events = await calendarData
        let mails = await mailData
        let messengers = await messengerData
        
        // 2. Build context for LLM
        let context = buildDigestContext(
            tasks: tasks,
            events: events,
            mails: mails,
            messengers: messengers
        )
        
        // 3. Ask LLM for synthesis
        let summary = await requestLLMDigest(context: context)
        
        let result = DigestResult(
            summary: summary,
            calendarEvents: events,
            mailHighlights: mails,
            messengerNotes: messengers,
            generatedAt: Date()
        )
        
        lastDigest = result
        return result
    }
    
    // MARK: - Data Fetching
    
    private func fetchCalendarEvents() async -> [CalendarEventBrief] {
        let eventKit = EventKitService.shared
        
        // Request access if needed
        if !eventKit.calendarAccessGranted {
            _ = await eventKit.requestCalendarAccess()
        }
        
        guard eventKit.calendarAccessGranted else {
            Logger.shared.warning("Digest: no calendar access")
            return []
        }
        
        // Use local EventKit directly (no backend needed)
        let events = await eventKit.fetchEventsForWeek(from: Date())
        return events.prefix(15).map { event in
            CalendarEventBrief(
                id: event.id,
                title: event.title,
                time: event.startDate.formatted(date: .abbreviated, time: .shortened)
            )
        }
    }
    
    private func fetchMailHighlights() async -> [MailHighlight] {
        do {
            let messages = try await MailService.shared.fetchMessages(maxResults: 10)
            return messages.map { msg in
                MailHighlight(
                    id: msg.id,
                    subject: msg.subject,
                    from: msg.from,
                    snippet: msg.snippet
                )
            }
        } catch {
            Logger.shared.warning("Digest: failed to fetch mail: \(error.localizedDescription)")
            return []
        }
    }
    
    private func fetchMessengerNotes(telegram: Bool) async -> [MessengerNote] {
        var notes: [MessengerNote] = []
        
        if telegram {
            if let summary = await fetchFromBackend(endpoint: "integrations/telegram/digest") {
                notes.append(MessengerNote(source: "telegram", summary: summary))
            }
        }
        
        return notes
    }
    
    private func fetchFromBackend(endpoint: String) async -> String? {
        let url = Config.backendURL.appendingPathComponent(endpoint)
        var request = Config.authorizedRequest(url: url)
        request.timeoutInterval = 30
        
        do {
            let (data, response) = try await Config.urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            struct DigestResp: Decodable { let summary: String }
            return (try? JSONDecoder().decode(DigestResp.self, from: data))?.summary
        } catch {
            Logger.shared.warning("Digest backend (\(endpoint)): \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - LLM Context Building
    
    private func buildDigestContext(
        tasks: [PlannerTask],
        events: [CalendarEventBrief],
        mails: [MailHighlight],
        messengers: [MessengerNote]
    ) -> String {
        var context = "Дата: \(Date().formatted(date: .abbreviated, time: .shortened))\n\n"
        
        // Tasks
        let todayTasks = tasks.filter { Calendar.current.isDateInToday($0.date) && !$0.isCompleted }
        let overdue = tasks.filter { $0.date < Date() && !$0.isCompleted && !$0.isInbox }
        let inbox = tasks.filter { $0.isInbox && !$0.isCompleted }
        
        context += "📋 ЗАДАЧИ:\n"
        context += "На сегодня: \(todayTasks.count)\n"
        if !todayTasks.isEmpty {
            for t in todayTasks.prefix(10) {
                context += "  - \(t.title) (\(t.date.formatted(date: .omitted, time: .shortened)))\n"
            }
        }
        if !overdue.isEmpty {
            context += "Просрочено: \(overdue.count)\n"
            for t in overdue.prefix(5) {
                context += "  ⚠️ \(t.title) (с \(t.date.formatted(date: .abbreviated, time: .omitted)))\n"
            }
        }
        if !inbox.isEmpty {
            context += "Входящие (без даты): \(inbox.count)\n"
        }
        
        // Calendar
        if !events.isEmpty {
            context += "\n📅 КАЛЕНДАРЬ (ближайшие события):\n"
            for e in events.prefix(10) {
                context += "  - \(e.title) — \(e.time)\n"
            }
        }
        
        // Mail
        if !mails.isEmpty {
            context += "\n📧 ПОЧТА (последние):\n"
            for m in mails.prefix(8) {
                context += "  - От: \(m.from) | \(m.subject)\n    \(m.snippet.prefix(80))...\n"
            }
        }
        
        // Messengers
        if !messengers.isEmpty {
            context += "\n💬 МЕССЕНДЖЕРЫ:\n"
            for n in messengers {
                context += "  [\(n.source)] \(n.summary)\n"
            }
        }
        
        return context
    }
    
    // MARK: - LLM Request
    
    private static let digestSystemPrompt = """
    Ты — Jarvis, личный AI-ассистент. Сделай краткую выдержку по текущей ситуации пользователя.
    Формат:
    1. Главное сейчас (1-2 предложения)
    2. Задачи на сегодня — статус и приоритеты
    3. Календарь — ближайшие важные события
    4. Почта — что требует внимания
    5. Мессенджеры (если есть данные)
    6. Рекомендация на ближайший час
    
    Будь конкретен, кратко, по-русски.
    """
    
    private func requestLLMDigest(context: String) async -> String {
        // 1. Gemini — основной (встроенный ключ, всегда работает)
        if let result = await requestGeminiDigest(context: context) {
            return result
        }
        
        // 2. Backend /ai/digest — если доступен
        if let result = await requestBackendDigest(context: context) {
            return result
        }
        
        // Build simple text digest without LLM
        return buildFallbackDigest(context: context)
    }
    
    private func requestGeminiDigest(context: String) async -> String? {
        let gemini = GeminiService.shared
        guard gemini.isConfigured else { return nil }
        
        if let result = await gemini.generate(
            message: context,
            systemPrompt: Self.digestSystemPrompt,
            temperature: 0.4,
            maxTokens: 1024
        ) {
            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }
    
    private func requestBackendDigest(context: String) async -> String? {
        let url = Config.backendURL.appendingPathComponent("ai/digest")
        var request = Config.authorizedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        
        let body: [String: Any] = ["context": context]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await Config.urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            struct Resp: Decodable { let summary: String }
            return (try? JSONDecoder().decode(Resp.self, from: data))?.summary
        } catch {
            return nil
        }
    }
    
    private func buildFallbackDigest(context: String) -> String {
        // Extract numbers from context for simple summary
        return """
        \(L10n.digestBriefSummary)
        
        \(context)
        
        \(L10n.digestLLMUnavailable)
        """
    }
}
