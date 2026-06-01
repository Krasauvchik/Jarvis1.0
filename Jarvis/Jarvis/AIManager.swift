import Foundation
import Combine

// MARK: - AI Action (parsed from AI response)

struct AIAction: Codable, Identifiable {
    let stableId: String
    var id: String { stableId }
    let type: String   // create_task, complete_task, delete_task, reschedule_task, create_event, send_email, show_calendar, show_mail, advice, none
    let params: [String: String]
    
    init(type: String, params: [String: String] = [:]) {
        self.stableId = type + (params["title"] ?? UUID().uuidString)
        self.type = type
        self.params = params
    }
    
    enum CodingKeys: String, CodingKey {
        case type, params
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decode(String.self, forKey: .type)
        params = try c.decodeIfPresent([String: String].self, forKey: .params) ?? [:]
        stableId = type + (params["title"] ?? UUID().uuidString)
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(params, forKey: .params)
    }
}

struct AICommandResponse: Codable {
    let response: String
    let actions: [AIAction]?
    let executed: [[String: AnyCodable]]?
    
    init(response: String, actions: [AIAction]? = nil, executed: [[String: AnyCodable]]? = nil) {
        self.response = response
        self.actions = actions
        self.executed = executed
    }
}

/// Type-erased Codable wrapper for heterogeneous JSON
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) { self.value = value }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { value = NSNull() }
        else if let b = try? container.decode(Bool.self) { value = b }
        else if let i = try? container.decode(Int.self) { value = i }
        else if let d = try? container.decode(Double.self) { value = d }
        else if let s = try? container.decode(String.self) { value = s }
        else if let arr = try? container.decode([AnyCodable].self) { value = arr.map(\.value) }
        else if let dict = try? container.decode([String: AnyCodable].self) { value = dict.mapValues(\.value) }
        else { value = NSNull() }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let b as Bool: try container.encode(b)
        case let i as Int: try container.encode(i)
        case let d as Double: try container.encode(d)
        case let s as String: try container.encode(s)
        case let arr as [Any]: try container.encode(arr.map(AnyCodable.init))
        case let dict as [String: Any]: try container.encode(dict.mapValues(AnyCodable.init))
        default: try container.encodeNil()
        }
    }
}

// MARK: - AI Manager

@MainActor
final class AIManager: ObservableObject {
    @Published var selectedModel: AIModel {
        didSet { saveModel() }
    }
    @Published var isProcessing = false
    @Published var lastCommandResponse: AICommandResponse?
    
    /// Conversation history for context retention (last N turns)
    private var conversationHistory: [(role: String, content: String)] = []
    private let maxHistoryTurns = 10
    
    /// Adds a user+assistant turn to conversation history
    private func addToHistory(user: String, assistant: String) {
        conversationHistory.append((role: "user", content: user))
        conversationHistory.append((role: "assistant", content: assistant))
        // Keep only last N turns (each turn = 2 entries)
        let maxEntries = maxHistoryTurns * 2
        if conversationHistory.count > maxEntries {
            conversationHistory = Array(conversationHistory.suffix(maxEntries))
        }
    }
    
    /// Extracts JSON object from LLM response that may contain extra text
    private func extractJSON(from text: String) -> AICommandResponse? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try direct decode first
        if let data = cleaned.data(using: .utf8),
           let response = try? JSONDecoder().decode(AICommandResponse.self, from: data) {
            return response
        }
        
        // Find first { and last } to extract JSON object
        guard let firstBrace = cleaned.firstIndex(of: "{"),
              let lastBrace = cleaned.lastIndex(of: "}") else { return nil }
        
        let jsonStr = String(cleaned[firstBrace...lastBrace])
        guard let data = jsonStr.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AICommandResponse.self, from: data)
    }
    
    private let heuristic = HeuristicAdapter()
    private let gemini = GeminiService.shared
    private let eventKit = EventKitService.shared
    private var syncObserver: NSObjectProtocol?

    /// Текущее время пользователя с часовым поясом для LLM промптов
    static func currentDateTimeForLLM() -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "yyyy-MM-dd HH:mm (EEEE), часовой пояс: ZZZZZ (VV)"
        return df.string(from: Date())
    }
    
    /// Текущий offset часового пояса в формате +03:00
    static func currentTimezoneOffset() -> String {
        let seconds = TimeZone.current.secondsFromGMT()
        let hours = abs(seconds) / 3600
        let minutes = (abs(seconds) % 3600) / 60
        let sign = seconds >= 0 ? "+" : "-"
        return String(format: "%@%02d:%02d", sign, hours, minutes)
    }

    /// Пример даты для LLM-промптов (завтра в 14:00 локального времени)
    static func exampleDateForLLM() -> String {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = .current
        return "\(df.string(from: tomorrow))T14:00:00\(currentTimezoneOffset())"
    }

    /// Краткое знание о навигации/папках Jarvis для LLM.
    /// Используется в системных промптах, чтобы модель понимала структуру приложения.
    private let navigationContextForLLM: String = """
    Ты работаешь внутри приложения Jarvis Planner.

    Важные разделы (папки) приложения:
    - Inbox — входящий ящик для всех новых задач без даты.
    - Today — задачи, запланированные на сегодня.
    - Scheduled — все задачи с конкретной датой/временем (краткосрочный горизонт).
    - Future Plans — долгосрочные и личные планы на будущее (более дальний горизонт).
    - Completed — выполненные задачи (история и база для аналитики).
    - All Tasks — полный список всех задач.
    - Health (Wellness) — раздел здоровья: питание, сон, активность, вода.
    - Calendar — интеграция с Google Calendar (встречи и события).
    - Mail — интеграция с Gmail (письма, которые могут порождать задачи).
    - Messengers — Telegram/WhatsApp, откуда берётся контекст переписок.
    - Analytics — аналитика по задачам и времени.
    - Projects — задачи, сгруппированные по проектам.
    - AI Chat (Neural) — главный экран общения с тобой, Jarvis‑ИИ.

    Пользователь может создавать СВОИ категории (кастомные папки) — они хранятся как TaskCategory
    и используются для фильтрации задач (например: Работа, Семья, Хобби).
    Если пользователь спрашивает про папки/разделы, используй эти определения.
    """
    
    init() {
        if let model = CloudSync.shared.loadAIModel() {
            selectedModel = model
        } else if let data = UserDefaults.standard.data(forKey: Config.Storage.aiModelKey),
                  let model = try? JSONDecoder().decode(AIModel.self, from: data) {
            selectedModel = model
        } else {
            // По умолчанию Gemini — бесплатный, быстрый, встроенный ключ
            selectedModel = .gemini
        }
        setupCloudSync()
    }
    
    deinit {
        if let observer = syncObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupCloudSync() {
        syncObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] _ in
            let service = self
            Task { @MainActor in
                guard let service else { return }
                if let model = CloudSync.shared.loadAIModel() {
                    service.selectedModel = model
                }
            }
        }
    }
    
    // MARK: - Smart Intent Detection
    
    enum UserIntent {
        case standard                          // обычная команда → /ai/command
        case meetingBriefing(String)            // "подготовь выдержку по встрече X"
        case contextSearch(String)             // "найди всё по теме X" / "что по соевому соусу?"
        case coaching(String, AILifeCoach.LifeCategory) // "качать плечи" → фитнес-план
        case delegateTask(String, String)       // "поставь задачу {title} пользователю {user}"
        case calendarQuery(String)             // "какие встречи сегодня?" / "когда я свободен?"
        case planDay                            // "распланируй мой день" — авто-расстановка задач
    }
    
    /// Определяет намерение пользователя по тексту сообщения.
    func detectIntent(_ message: String) -> UserIntent {
        let lower = message.lowercased()
        
        // 1. Meeting briefing (ru + en)
        let briefingPatterns = ["подготовь выдержку", "подготовь брифинг", "что по встрече",
                               "инфо по встрече", "подготовься к встрече", "briefing for",
                               "prepare for meeting", "выдержку по встрече",
                               "meeting prep", "meeting summary", "meeting info", "brief me on"]
        if briefingPatterns.contains(where: { lower.contains($0) }) {
            let topic = extractTopic(from: lower, triggers: briefingPatterns)
            return .meetingBriefing(topic)
        }
        
        // 2. Context search (ru + en)
        let searchPatterns = ["найди всё по", "найди все по", "что по теме", "поищи информацию",
                             "поиск по", "собери инфо по", "search for", "find everything about",
                             "look up", "find info on", "research about"]
        if searchPatterns.contains(where: { lower.contains($0) }) {
            let topic = extractTopic(from: lower, triggers: searchPatterns)
            return .contextSearch(topic)
        }
        
        // 3. Task delegation (ru + en)
        let delegatePatterns = ["поставь задачу .+ пользователю", "назначь .+ на ",
                               "делегируй .+ ", "assign .+ to ",
                               "delegate .+ to "]
        for pattern in delegatePatterns {
            if let match = lower.range(of: pattern, options: .regularExpression) {
                let afterMatch = String(lower[match.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                let beforeUser = String(lower[lower.startIndex..<match.lowerBound])
                return .delegateTask(beforeUser.isEmpty ? afterMatch : beforeUser, afterMatch)
            }
        }
        
        // 4. Coaching (fitness, nutrition, learning etc.) — ru + en
        let coach = AILifeCoach.shared
        let category = coach.classifyCategory(message)
        let coachingTriggers = ["план тренировк", "программа тренировк", "план занят",
                               "как качать", "упражнения для", "план питания",
                               "меню на", "план медитац", "workout plan", "exercise plan",
                               "добавь в личные", "в личную",
                               "training plan", "meal plan", "meditation plan",
                               "fitness plan", "nutrition plan", "learning plan"]
        let isCoachingByTrigger = coachingTriggers.contains(where: { lower.contains($0) })
        let isCoachingByCategory = category != AILifeCoach.LifeCategory.other && (lower.contains("задач") || lower.contains("поставь"))
        
        if isCoachingByTrigger || isCoachingByCategory {
            return .coaching(message, category)
        }
        
        // 4.5 Plan my day — авто-расстановка незапланированных задач (ru + en)
        let planDayPatterns = ["распланируй день", "распланируй мой день", "расставь задачи",
                               "распиши день", "спланируй день", "организуй день",
                               "разложи задачи по дню", "plan my day", "plan my tasks",
                               "organize my day", "schedule my day", "auto-plan", "autoplan"]
        if planDayPatterns.contains(where: { lower.contains($0) }) {
            return .planDay
        }

        // 5. Calendar queries (ru + en)
        let calendarPatterns = ["какие встречи", "что в календаре", "расписание на",
                               "мои встречи", "свободные окна", "когда я свободен",
                               "свободное время", "покажи календарь", "ближайшие встречи",
                               "events today", "my meetings", "what's on my calendar",
                               "free slots", "when am i free", "schedule for",
                               "show calendar", "upcoming meetings", "next meeting",
                               "следующая встреча", "перенеси встречу", "отмени встречу",
                               "создай встречу", "запланируй встречу", "добавь в календарь",
                               "назначь встречу", "создай событие", "reschedule meeting",
                               "cancel meeting", "create meeting", "schedule meeting",
                               "add to calendar", "create event",
                               "поставь встречу", "запиши встречу", "забронируй",
                               "встреча в ", "встреча на ", "встреча с ",
                               "событие на ", "событие в ",
                               "поставь событие", "запиши событие",
                               "добавь встречу", "добавь событие",
                               "новая встреча", "новое событие",
                               "удали встречу", "удали событие",
                               "book meeting", "new meeting", "new event"]
        if calendarPatterns.contains(where: { lower.contains($0) }) {
            return .calendarQuery(message)
        }
        
        // 6. Default
        return .standard
    }
    
    private func extractTopic(from text: String, triggers: [String]) -> String {
        var result = text
        for trigger in triggers {
            if let range = result.range(of: trigger) {
                result = String(result[range.upperBound...])
                break
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }
    
    // MARK: - Unified AI Command (main entry point)
    
    /// Отправляет команду на естественном языке. AI анализирует намерение, маршрутизирует
    /// к нужному сервису (MeetingBriefing, ContextSearch, LifeCoach или стандартный /ai/command).
    func sendCommand(_ message: String, tasks: [PlannerTask] = [], date: Date = Date()) async -> AICommandResponse {
        isProcessing = true
        defer { isProcessing = false }
        
        // Smart routing based on intent
        let intent = detectIntent(message)
        
        switch intent {
        case .meetingBriefing(let topic):
            return await handleMeetingBriefing(topic: topic, tasks: tasks)
            
        case .contextSearch(let query):
            return await handleContextSearch(query: query, tasks: tasks)
            
        case .coaching(let text, let category):
            return await handleCoaching(text: text, category: category, tasks: tasks)
            
        case .delegateTask(let taskTitle, let assignee):
            return await handleDelegation(taskTitle: taskTitle, assignee: assignee)
            
        case .calendarQuery(let query):
            return await handleCalendarQuery(query: query, tasks: tasks)

        case .planDay:
            return await handlePlanDay(tasks: tasks, date: date)

        case .standard:
            return await handleStandardCommand(message: message, tasks: tasks, date: date)
        }
    }

    // MARK: - Intent Handlers
    
    private func handleMeetingBriefing(topic: String, tasks: [PlannerTask]) async -> AICommandResponse {
        let briefing = MeetingBriefingService.shared
        let info = MeetingBriefingService.MeetingInfo(title: topic, date: Date())
        
        if let result = await briefing.generateBriefing(for: info, tasks: tasks) {
            return AICommandResponse(
                response: result.structuredSummary,
                actions: [AIAction(type: "meeting_briefing", params: [
                    "title": result.meetingTitle,
                    "related_emails": String(result.relatedEmails),
                    "related_messages": String(result.relatedMessages),
                ])]
            )
        }
        return AICommandResponse(response: L10n.aiBriefingFailed)
    }
    
    private func handleContextSearch(query: String, tasks: [PlannerTask]) async -> AICommandResponse {
        let engine = AIContextEngine.shared
        let result = await engine.searchAllSources(query: query, lookbackDays: 30, localTasks: tasks)
        let formatted = engine.formatSearchResultForLLM(result)
        
        return AICommandResponse(
            response: "🔍 Поиск по \"\(query)\" — найдено \(result.totalMatches) результатов:\n\n\(formatted)",
            actions: [AIAction(type: "context_search", params: [
                "query": query,
                "total_matches": String(result.totalMatches),
            ])]
        )
    }
    
    private func handleCoaching(text: String, category: AILifeCoach.LifeCategory, tasks: [PlannerTask]) async -> AICommandResponse {
        let coach = AILifeCoach.shared
        let result = await coach.getCoachingAdvice(
            taskDescription: text,
            category: category
        )
        
        var responseText = "\(result.category.emoji) \(result.category.displayName)\n\n\(result.content)"
        if let progress = result.progressAnalysis {
            responseText += "\n\n📊 Анализ прогресса:\n\(progress)"
        }
        
        return AICommandResponse(
            response: responseText,
            actions: [AIAction(type: "coaching", params: [
                "category": result.category.rawValue,
            ])]
        )
    }
    
    private func handleDelegation(taskTitle: String, assignee: String) async -> AICommandResponse {
        // Call backend delegate-task endpoint
        let url = Config.Endpoints.aiDelegateTask
        var request = Config.authorizedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let payload: [String: String] = [
            "task_title": taskTitle,
            "assignee_handle": assignee,
            "platform": "telegram",
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        do {
            let (data, response) = try await Config.urlSession.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let status = json["status"] as? String ?? "unknown"
                let preview = json["message_preview"] as? String ?? ""
                let error = json["error"] as? String
                
                let statusText: String
                switch status {
                case "sent": statusText = "✅ Отправлено в Telegram"
                case "error": statusText = "❌ Ошибка: \(error ?? "неизвестная")"
                case "not_implemented": statusText = "⏳ Платформа пока не поддерживается"
                default: statusText = "📋 Подготовлено"
                }
                
                return AICommandResponse(
                    response: "📤 Задача «\(taskTitle)» → \(assignee)\n\(statusText)\n\n\(preview)",
                    actions: [AIAction(type: "delegate_task", params: [
                        "title": taskTitle,
                        "assignee": assignee,
                        "status": status,
                    ])]
                )
            }
        } catch {
            Logger.shared.warning("Delegate task error: \(error.localizedDescription)")
        }
        
        // Fallback if backend unavailable
        return AICommandResponse(
            response: "📤 Задача «\(taskTitle)» назначена пользователю \(assignee).\n(Бэкенд недоступен — задача сохранена локально)",
            actions: [AIAction(type: "delegate_task", params: [
                "title": taskTitle,
                "assignee": assignee,
            ])]
        )
    }
    
    private func handleCalendarQuery(query: String, tasks: [PlannerTask]) async -> AICommandResponse {
        let calendarCtx = eventKit.calendarContextForLLM()
        let tasksList = tasks.prefix(15).map { "- \($0.title)\($0.isCompleted ? " ✓" : "")" }.joined(separator: "\n")
        
        let systemPrompt = """
        Ты — Jarvis, AI-ассистент. Пользователь спрашивает про календарь и встречи.
        
        \(calendarCtx)

        Текущие задачи пользователя:
        \(tasksList.isEmpty ? "Нет задач" : tasksList)
        Дата сейчас: \(Self.currentDateTimeForLLM())
        Часовой пояс пользователя: \(Self.currentTimezoneOffset())

        ВАЖНО: Все даты в params возвращай СТРОГО с часовым поясом пользователя, например: "\(Self.exampleDateForLLM())".
        Когда пользователь говорит "на 10", "на 11", "в 10 утра" — это ЛОКАЛЬНОЕ время.

        Если пользователь просит СОЗДАТЬ встречу/событие — верни ТОЛЬКО JSON без лишнего текста:
        {"response": "✅ Встреча создана", "actions": [{"type": "create_event", "params": {"title": "...", "date": "ISO8601+TZ", "end_date": "ISO8601+TZ", "location": "...", "notes": "..."}}]}
        Если просит УДАЛИТЬ встречу — верни ТОЛЬКО JSON:
        {"response": "🗑 Встреча удалена", "actions": [{"type": "delete_event", "params": {"title": "название встречи для поиска"}}]}
        Если просит ПЕРЕНЕСТИ встречу — верни ТОЛЬКО JSON:
        {"response": "📅 Встреча перенесена", "actions": [{"type": "reschedule_event", "params": {"title": "...", "new_date": "ISO8601+TZ", "new_end_date": "ISO8601+TZ"}}]}
        Если просит найти свободное время — ответь текстом, используя данные о свободных окнах из календаря выше.
        Иначе просто ответь на вопрос о расписании, используя данные из календаря.

        КРИТИЧНО: Когда нужно действие (создать/удалить/перенести) — отвечай СТРОГО JSON без пояснений вокруг.
        Отвечай по-русски, кратко и по делу.
        """
        
        // 1. Gemini — основной (встроенный ключ)
        if gemini.isConfigured {
            var messages = conversationHistory
            messages.append((role: "user", content: query))
            if let text = await gemini.chat(messages: messages, systemPrompt: systemPrompt, temperature: 0.3, maxTokens: 1500) {
                addToHistory(user: query, assistant: text)
                if let response = extractJSON(from: text) {
                    return response
                }
                return AICommandResponse(response: text, actions: nil)
            }
        }
        
        // Offline fallback — just show raw calendar context
        return AICommandResponse(
            response: "📅 Расписание:\n\n\(calendarCtx)",
            actions: nil
        )
    }
    
    // MARK: - Plan My Day (AI auto-scheduling)

    private struct PlanSlot: Decodable {
        let index: Int
        let start: String
        let durationMinutes: Int?
    }

    /// Берёт незапланированные (inbox) задачи и раскладывает их по свободным слотам дня
    /// с учётом календарных событий и уже запланированных задач. Сигнатурная фича Structured AI.
    private func handlePlanDay(tasks: [PlannerTask], date: Date) async -> AICommandResponse {
        let cal = Calendar.current
        let inbox = tasks.filter { $0.isInbox && !$0.isCompleted }
        guard !inbox.isEmpty else {
            return AICommandResponse(response: "📭 Во входящих нет незапланированных задач — день уже чист.", actions: nil)
        }
        guard gemini.isConfigured else {
            return AICommandResponse(response: "Чтобы планировать день через ИИ, добавьте Gemini-ключ в Настройки → AI.", actions: nil)
        }

        // Занятость дня: события календаря + уже запланированные задачи на этот день.
        await eventKit.fetchEvents(for: date)
        let dayEvents = eventKit.systemEvents.filter { cal.isDate($0.startDate, inSameDayAs: date) && !$0.isAllDay }
        let scheduled = tasks.filter { !$0.isInbox && !$0.isAllDay && cal.isDate($0.date, inSameDayAs: date) }

        let riseH = (UserDefaults.standard.object(forKey: "jarvis_rise_hour") as? Int) ?? Config.Defaults.riseHour
        let windH = (UserDefaults.standard.object(forKey: "jarvis_winddown_hour") as? Int) ?? Config.Defaults.windDownHour

        let tf = DateFormatter()
        tf.dateFormat = "HH:mm"
        tf.timeZone = .current

        let taskLines = inbox.enumerated().map { i, t in
            "\(i): \(t.title) (~\(t.durationMinutes > 0 ? t.durationMinutes : 60) мин)"
        }.joined(separator: "\n")

        var busyLines = dayEvents.map { "\(tf.string(from: $0.startDate))–\(tf.string(from: $0.endDate)) \($0.title)" }
        busyLines += scheduled.map {
            let end = $0.date.addingTimeInterval(TimeInterval(max($0.durationMinutes, 15) * 60))
            return "\(tf.string(from: $0.date))–\(tf.string(from: end)) \($0.title)"
        }

        let systemPrompt = """
        Ты — Jarvis, планировщик дня. Разложи незапланированные задачи пользователя по СВОБОДНЫМ слотам.
        Дата: \(Self.currentDateTimeForLLM()). Часовой пояс: \(Self.currentTimezoneOffset()).
        Рабочие часы: с \(riseH):00 до \(windH):00. Не накладывай задачи на занятые интервалы и друг на друга, оставляй 5–10 минут буфера, уважай приоритет (более ранние в списке — важнее).

        Незапланированные задачи (индекс: название (длительность)):
        \(taskLines)

        Занятые интервалы:
        \(busyLines.isEmpty ? "нет" : busyLines.joined(separator: "\n"))

        Верни СТРОГО JSON-массив без пояснений и без markdown:
        [{"index": 0, "start": "\(Self.exampleDateForLLM())", "durationMinutes": 60}]
        Используй ISO8601 со смещением часового пояса. Если задача не помещается в день — не включай её.
        """

        guard let text = await gemini.chat(
            messages: [(role: "user", content: "Распланируй мой день")],
            systemPrompt: systemPrompt,
            temperature: 0.2,
            maxTokens: 1200
        ) else {
            return AICommandResponse(response: "Не удалось связаться с ИИ для планирования. Попробуйте позже.", actions: nil)
        }

        // Парсим JSON-массив (убираем возможные ```-ограждения).
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned.replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let data = cleaned.data(using: .utf8),
              let slots = try? JSONDecoder().decode([PlanSlot].self, from: data),
              !slots.isEmpty else {
            return AICommandResponse(response: "Не удалось разложить задачи по слотам. Попробуйте переформулировать.", actions: nil)
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let store = PlannerStore.shared
        var placed: [(time: Date, title: String)] = []
        var usedIndices = Set<Int>()

        for slot in slots {
            guard slot.index >= 0, slot.index < inbox.count, !usedIndices.contains(slot.index) else { continue }
            guard let start = iso.date(from: slot.start) else { continue }
            let task = inbox[slot.index]
            let dur = (slot.durationMinutes ?? 0) > 0 ? slot.durationMinutes! : (task.durationMinutes > 0 ? task.durationMinutes : 60)
            store.scheduleFromInbox(task, date: start, durationMinutes: dur, isAllDay: false)
            usedIndices.insert(slot.index)
            placed.append((start, task.title))
        }

        guard !placed.isEmpty else {
            return AICommandResponse(response: "Не удалось распланировать задачи на сегодня.", actions: nil)
        }

        placed.sort { $0.time < $1.time }
        let lines = placed.map { "• \(tf.string(from: $0.time)) — \($0.title)" }.joined(separator: "\n")
        let leftover = inbox.count - placed.count
        var footer = ""
        if leftover > 0 { footer = "\n\nОсталось во входящих: \(leftover) (не поместились в день)." }
        return AICommandResponse(response: "🗓 Распланировано задач: \(placed.count)\n\(lines)\(footer)", actions: nil)
    }

    private func handleStandardCommand(message: String, tasks: [PlannerTask], date: Date) async -> AICommandResponse {
        // 0. Чисто эвристический режим или оффлайн без облака
        if selectedModel == .heuristic || (!NetworkMonitor.shared.isConnected && !selectedModel.isLocal) {
            let advice = heuristic.generateAdvice(from: tasks).joined(separator: "\n")
            let response = AICommandResponse(
                response: advice.isEmpty ? L10n.aiOfflineProcessError : advice,
                actions: nil
            )
            lastCommandResponse = response
            return response
        }

        // 1. Gemini — основной (встроенный ключ)
        if gemini.isConfigured {
            if let response = await sendToGemini(message: message, tasks: tasks) {
                lastCommandResponse = response
                return response
            }
        }
        
        // 2. Try backend /ai/command
        let taskDicts: [[String: Any]] = tasks.prefix(30).map { t in
            [
                "title": t.title,
                "notes": t.notes,
                "date": ISO8601DateFormatter().string(from: t.date),
                "isCompleted": t.isCompleted,
                "priority": t.priority.rawValue,
                "isInbox": t.isInbox,
            ]
        }
        let body: [String: Any] = [
            "message": message,
            "context": [
                "tasks": taskDicts,
                "date": ISO8601DateFormatter().string(from: date),
            ]
        ]
        if let response = await sendToBackend(body) {
            lastCommandResponse = response
            return response
        }
        
        // Final fallback: heuristic
        let advice = heuristic.generateAdvice(from: tasks).joined(separator: "\n")
        let response = AICommandResponse(
            response: advice.isEmpty ? L10n.aiCannotConnect : advice,
            actions: nil
        )
        lastCommandResponse = response
        return response
    }
    
    private func sendToBackend(_ body: [String: Any]) async -> AICommandResponse? {
        let url = Config.Endpoints.aiCommand
        var request = Config.authorizedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15  // Быстрый таймаут — не заставляем юзера ждать
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await Config.urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                Logger.shared.warning("AI command backend returned non-200")
                return nil
            }
            return try JSONDecoder().decode(AICommandResponse.self, from: data)
        } catch {
            Logger.shared.warning("AI command backend error: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func sendToGemini(message: String, tasks: [PlannerTask]) async -> AICommandResponse? {
        let systemPrompt = buildStandardSystemPrompt(tasks: tasks)
        
        // Build messages with conversation history for context retention
        var messages = conversationHistory
        messages.append((role: "user", content: message))
        
        if let text = await gemini.chat(messages: messages, systemPrompt: systemPrompt, temperature: 0.3, maxTokens: 1000) {
            addToHistory(user: message, assistant: text)
            if let response = extractJSON(from: text) {
                return response
            }
            return AICommandResponse(response: text, actions: nil)
        }
        return nil
    }
    
    /// Shared system prompt for standard command handling
    private func buildStandardSystemPrompt(tasks: [PlannerTask]) -> String {
        let tasksList = tasks.prefix(20).map { "- \($0.title)\($0.isCompleted ? " ✓" : "")" }.joined(separator: "\n")
        let calendarCtx = eventKit.calendarContextForLLM()
        
        return """
        Ты — Jarvis, AI-ассистент планировщик. Пользователь управляет приложением голосом и текстом.

        \(navigationContextForLLM)

        Текущие задачи пользователя:
        \(tasksList.isEmpty ? "Нет задач" : tasksList)

        \(calendarCtx)

        Дата и время сейчас: \(Self.currentDateTimeForLLM())

        ВАЖНО: Все даты в params возвращай СТРОГО в формате ISO8601 С ЧАСОВЫМ ПОЯСОМ пользователя.
        Пример: "\(Self.exampleDateForLLM())" (НЕ UTC, а локальное время пользователя!).
        Когда пользователь говорит "на 10", "на 11", "в 10", "в 11 утра" — это ЛОКАЛЬНОЕ время.

        Если пользователь просит создать/выполнить/удалить/перенести задачу или СОБЫТИЕ В КАЛЕНДАРЕ — верни СТРОГО JSON без лишнего текста:
        {"response": "текст ответа", "actions": [{"type": "create_task", "params": {"title": "...", "date": "ISO8601+TZ"}}]}
        Допустимые типы действий:
        - create_task, complete_task, delete_task, reschedule_task, move_task — для задач
        - create_event — создать событие в календаре. params: title, date (ISO8601+TZ), end_date (ISO8601+TZ), location, notes
        - delete_event — удалить событие из календаря. params: title (название для поиска)
        - reschedule_event — перенести событие. params: title, new_date (ISO8601+TZ), new_end_date (ISO8601+TZ)
        - find_free_slots — найти свободные окна в календаре. params: date (ISO8601+TZ, по умолчанию сегодня), duration_minutes
        - advice, none — для советов и информационных ответов

        Когда пользователь спрашивает про встречи, расписание, свободное время — используй данные из календаря выше.
        Когда пользователь просит создать встречу/событие — используй тип create_event.

        КРИТИЧНО: Когда нужно действие (создать/удалить/перенести) — отвечай СТРОГО JSON без пояснений вокруг.
        Иначе просто отвечай текстом кратко и по делу. По умолчанию отвечай на русском.
        """
    }
    
    // MARK: - Legacy methods (backward compatible)
    
    func generateAdvice(from tasks: [PlannerTask]) -> [String] {
        heuristic.generateAdvice(from: tasks)
    }
    
    func generateLLMAdvice(from tasks: [PlannerTask]) async -> String? {
        guard !tasks.isEmpty else { return nil }
        
        let heuristicFallback: () -> String = { [heuristic] in
            heuristic.generateAdvice(from: tasks).joined(separator: "\n")
        }
        
        if !NetworkMonitor.shared.isConnected {
            return L10n.aiOfflineHeuristic + "\n" + heuristicFallback()
        }
        
        let tasksList = tasks.prefix(20).map { "- \($0.title) \($0.isCompleted ? "(выполнено)" : "")" }.joined(separator: "\n")
        let prompt = "Дай 3-5 кратких практических советов по планированию дня. Задачи:\n\(tasksList)"
        let systemPrompt = "Ты — AI-планировщик Jarvis. Отвечай по-русски, кратко и конкретно."
        
        // Gemini — основной (встроенный ключ)
        if gemini.isConfigured {
            if let result = await gemini.generate(message: prompt, systemPrompt: systemPrompt) {
                return result
            }
        }
        
        // Cloud models go through backend
        struct TaskDTO: Encodable { let title: String; let notes: String; let date: Date; let isCompleted: Bool }
        struct Payload: Encodable { let tasks: [TaskDTO] }
        struct Response: Decodable { let advice: String }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let url = Config.Endpoints.llmPlan
        var request = Config.authorizedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let payload = Payload(tasks: tasks.map { TaskDTO(title: $0.title, notes: $0.notes, date: $0.date, isCompleted: $0.isCompleted) })
        request.httpBody = try? encoder.encode(payload)
        
        do {
            let (data, response) = try await Config.urlSession.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                Logger.shared.warning("LLM API returned status \(httpResponse.statusCode)")
                return L10n.aiServerError + "\n" + heuristicFallback()
            }
            return try? JSONDecoder().decode(Response.self, from: data).advice
        } catch {
            return L10n.aiCannotConnect + "\n" + heuristicFallback()
        }
    }
    
    // MARK: - Check services status
    
    func checkBackendStatus() async -> (running: Bool, llmConnected: Bool) {
        struct HealthResp: Decodable { let status: String; let llm: Bool? }
        do {
            guard let url = URL(string: "\(Config.backendBase)/health") else { return (false, false) }
            var request = Config.authorizedRequest(url: url)
            request.timeoutInterval = 5
            let (data, response) = try await Config.urlSession.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return (false, false) }
            let health = try? JSONDecoder().decode(HealthResp.self, from: data)
            return (true, health?.llm ?? false)
        } catch {
            return (false, false)
        }
    }
    
    func checkGoogleAuthStatus() async -> Bool {
        struct AuthResp: Decodable { let authorized: Bool }
        do {
            let request = Config.authorizedRequest(url: Config.Endpoints.authStatus)
            let (data, response) = try await Config.urlSession.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return false }
            return (try? JSONDecoder().decode(AuthResp.self, from: data))?.authorized ?? false
        } catch {
            return false
        }
    }
    
    private func saveModel() {
        CloudSync.shared.saveAIModel(selectedModel)
        if let data = try? JSONEncoder().encode(selectedModel) {
            UserDefaults.standard.set(data, forKey: Config.Storage.aiModelKey)
        }
    }
}
