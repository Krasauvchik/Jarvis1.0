import Foundation
import Combine

// MARK: - AI Action (parsed from AI response)

struct AIAction: Codable, Identifiable {
    var id: String { type + (params["title"] ?? UUID().uuidString) }
    let type: String   // create_task, complete_task, delete_task, reschedule_task, create_event, send_email, show_calendar, show_mail, advice, none
    let params: [String: String]
    
    init(type: String, params: [String: String] = [:]) {
        self.type = type
        self.params = params
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
    
    private let heuristic = HeuristicAdapter()
    private var syncObserver: NSObjectProtocol?
    
    init() {
        if let model = CloudSync.shared.loadAIModel() {
            selectedModel = model
        } else if let data = UserDefaults.standard.data(forKey: Config.Storage.aiModelKey),
                  let model = try? JSONDecoder().decode(AIModel.self, from: data) {
            selectedModel = model
        } else {
            selectedModel = .ollama
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
    }
    
    /// Определяет намерение пользователя по тексту сообщения.
    func detectIntent(_ message: String) -> UserIntent {
        let lower = message.lowercased()
        
        // 1. Meeting briefing
        let briefingPatterns = ["подготовь выдержку", "подготовь брифинг", "что по встрече",
                               "инфо по встрече", "подготовься к встрече", "briefing for",
                               "prepare for meeting", "выдержку по встрече"]
        if briefingPatterns.contains(where: { lower.contains($0) }) {
            let topic = extractTopic(from: lower, triggers: briefingPatterns)
            return .meetingBriefing(topic)
        }
        
        // 2. Context search
        let searchPatterns = ["найди всё по", "найди все по", "что по теме", "поищи информацию",
                             "поиск по", "собери инфо по", "search for", "find everything about"]
        if searchPatterns.contains(where: { lower.contains($0) }) {
            let topic = extractTopic(from: lower, triggers: searchPatterns)
            return .contextSearch(topic)
        }
        
        // 3. Task delegation
        let delegatePatterns = ["поставь задачу .+ пользователю", "назначь .+ на ",
                               "делегируй .+ ", "assign .+ to "]
        for pattern in delegatePatterns {
            if let match = lower.range(of: pattern, options: .regularExpression) {
                let afterMatch = String(lower[match.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                let beforeUser = String(lower[lower.startIndex..<match.lowerBound])
                return .delegateTask(beforeUser.isEmpty ? afterMatch : beforeUser, afterMatch)
            }
        }
        
        // 4. Coaching (fitness, nutrition, learning etc.)
        let coach = AILifeCoach.shared
        let category = coach.classifyCategory(message)
        let coachingTriggers = ["план тренировк", "программа тренировк", "план занят",
                               "как качать", "упражнения для", "план питания",
                               "меню на", "план медитац", "workout plan", "exercise plan",
                               "добавь в личные", "в личную"]
        let isCoachingByTrigger = coachingTriggers.contains(where: { lower.contains($0) })
        let isCoachingByCategory = category != AILifeCoach.LifeCategory.other && (lower.contains("задач") || lower.contains("поставь"))
        
        if isCoachingByTrigger || isCoachingByCategory {
            return .coaching(message, category)
        }
        
        // 5. Default
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
        return AICommandResponse(response: "Не удалось подготовить выдержку по \"\(topic)\". Проверьте подключение к AI.")
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
        // TODO: реальная отправка через Telegram/WhatsApp API
        return AICommandResponse(
            response: "📤 Задача «\(taskTitle)» назначена пользователю \(assignee).\n(Интеграция с мессенджерами для делегирования задач будет в следующем обновлении)",
            actions: [AIAction(type: "delegate_task", params: [
                "title": taskTitle,
                "assignee": assignee,
            ])]
        )
    }
    
    private func handleStandardCommand(message: String, tasks: [PlannerTask], date: Date) async -> AICommandResponse {
        // 0. Чисто эвристический режим или оффлайн без облака
        if selectedModel == .heuristic || (!NetworkMonitor.shared.isConnected && !selectedModel.isLocal) {
            let advice = heuristic.generateAdvice(from: tasks).joined(separator: "\n")
            let response = AICommandResponse(
                response: advice.isEmpty ? "Офлайн: не удалось обработать запрос." : advice,
                actions: nil
            )
            lastCommandResponse = response
            return response
        }

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
        
        let dateStr = ISO8601DateFormatter().string(from: date)
        
        let body: [String: Any] = [
            "message": message,
            "context": [
                "tasks": taskDicts,
                "date": dateStr,
            ]
        ]
        
        // Try backend /ai/command first (which uses Ollama)
        if let response = await sendToBackend(body) {
            lastCommandResponse = response
            return response
        }
        
        // Fallback: direct Ollama
        if let response = await sendDirectOllama(message: message, tasks: tasks) {
            lastCommandResponse = response
            return response
        }
        
        // Final fallback: heuristic
        let advice = heuristic.generateAdvice(from: tasks).joined(separator: "\n")
        let response = AICommandResponse(
            response: advice.isEmpty ? "Не удалось обработать запрос. Проверьте, что Ollama запущена." : advice,
            actions: nil
        )
        lastCommandResponse = response
        return response
    }
    
    private func sendToBackend(_ body: [String: Any]) async -> AICommandResponse? {
        let url = Config.Endpoints.aiCommand
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
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
    
    private func sendDirectOllama(message: String, tasks: [PlannerTask]) async -> AICommandResponse? {
        let modelName = UserDefaults.standard.string(forKey: Config.Storage.ollamaModelKey) ?? Config.Ollama.defaultModelName
        let url = Config.Endpoints.ollamaBase.appendingPathComponent("api/chat")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        
        let tasksList = tasks.prefix(20).map { "- \($0.title)\($0.isCompleted ? " ✓" : "")" }.joined(separator: "\n")
        
        let systemPrompt = """
        Ты — Jarvis, AI-ассистент планировщик. Пользователь управляет приложением голосом.
        Задачи пользователя:
        \(tasksList.isEmpty ? "Нет задач" : tasksList)
        Дата: \(Date().formatted(date: .abbreviated, time: .shortened))
        
        Если пользователь просит создать/выполнить/удалить/перенести задачу — верни JSON:
        {"response": "текст", "actions": [{"type": "тип", "params": {}}]}
        
        Типы: create_task, complete_task, delete_task, reschedule_task, move_task, advice, none
        Для create_task params: title, date (ISO-8601), priority (low/medium/high), folder (inbox/today)
        Для complete_task/delete_task: title (приблизительное название)
        Для move_task: title, folder (inbox/today/completed/scheduled/future)
        Для reschedule_task: title, new_date (ISO-8601)
        
        Если это простой вопрос — отвечай текстом по-русски, кратко и полезно.
        """
        
        struct OllamaChatReq: Encodable {
            let model: String
            let messages: [AIManager.ChatMessagePayload]
            let stream: Bool
        }
        struct OllamaChatResp: Decodable {
            let message: ChatMessagePayload?
        }
        
        let payload = OllamaChatReq(
            model: modelName,
            messages: [
                ChatMessagePayload(role: "system", content: systemPrompt),
                ChatMessagePayload(role: "user", content: message),
            ],
            stream: false
        )
        
        request.httpBody = try? JSONEncoder().encode(payload)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let decoded = try? JSONDecoder().decode(OllamaChatResp.self, from: data),
               let text = decoded.message?.content.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                // Try to parse as AICommandResponse JSON (for action execution)
                if let jsonData = text.data(using: .utf8),
                   let cmdResponse = try? JSONDecoder().decode(AICommandResponse.self, from: jsonData) {
                    return cmdResponse
                }
                return AICommandResponse(response: text)
            }
        } catch {
            Logger.shared.warning("Direct Ollama error: \(error.localizedDescription)")
        }
        return nil
    }
    
    // MARK: - Legacy methods (backward compatible)
    
    func extractTask(from input: String, referenceDate: Date) -> PlannerTask? {
        heuristic.extractTask(from: input, referenceDate: referenceDate)
    }
    
    func generateAdvice(from tasks: [PlannerTask]) -> [String] {
        heuristic.generateAdvice(from: tasks)
    }
    
    func generateLLMAdvice(from tasks: [PlannerTask]) async -> String? {
        guard !tasks.isEmpty else { return nil }
        
        let heuristicFallback: () -> String = { [heuristic] in
            heuristic.generateAdvice(from: tasks).joined(separator: "\n")
        }
        
        if !NetworkMonitor.shared.isConnected && !selectedModel.isLocal {
            return "Офлайн (эвристика):\n" + heuristicFallback()
        }
        
        if selectedModel == .ollama || selectedModel == .onDeviceLarge {
            return await requestOllamaAdvice(tasks: tasks) ?? "Ollama недоступна. Советы:\n" + heuristicFallback()
        }
        
        // Cloud models go through backend
        struct TaskDTO: Encodable { let title: String; let notes: String; let date: Date; let isCompleted: Bool }
        struct Payload: Encodable { let tasks: [TaskDTO] }
        struct Response: Decodable { let advice: String }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let url = Config.Endpoints.llmPlan
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let payload = Payload(tasks: tasks.map { TaskDTO(title: $0.title, notes: $0.notes, date: $0.date, isCompleted: $0.isCompleted) })
        request.httpBody = try? encoder.encode(payload)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                Logger.shared.warning("LLM API returned status \(httpResponse.statusCode)")
                return "Сервер вернул ошибку (\(httpResponse.statusCode)).\n" + heuristicFallback()
            }
            return try? JSONDecoder().decode(Response.self, from: data).advice
        } catch {
            return "Не удалось связаться с сервером.\n" + heuristicFallback()
        }
    }
    
    private func requestOllamaAdvice(tasks: [PlannerTask]) async -> String? {
        let modelName = UserDefaults.standard.string(forKey: Config.Storage.ollamaModelKey) ?? Config.Ollama.defaultModelName
        let prompt = buildPromptForOllama(tasks: tasks)
        
        let url = Config.Endpoints.ollamaBase.appendingPathComponent("api/generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        struct OllamaRequest: Encodable { let model: String; let prompt: String; let stream: Bool }
        struct OllamaResponse: Decodable { let response: String }
        
        request.httpBody = try? JSONEncoder().encode(OllamaRequest(model: modelName, prompt: prompt, stream: false))
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let text = (try? JSONDecoder().decode(OllamaResponse.self, from: data))?.response.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }
    
    private func buildPromptForOllama(tasks: [PlannerTask]) -> String {
        let list = tasks.prefix(20).map { "- \($0.title) \($0.isCompleted ? "(выполнено)" : "")" }.joined(separator: "\n")
        return """
        Ты — AI-планировщик Jarvis. Дай 3-5 кратких практических советов по-русски.
        Задачи: \(list)
        """
    }
    
    // MARK: - Chat
    
    struct ChatMessagePayload: Encodable, Decodable {
        let role: String
        let content: String
    }
    
    /// Отправить сообщения в чат. Работает через бэкенд (Ollama) или напрямую.
    func sendChatMessage(messages: [(role: String, content: String)]) async -> String? {
        guard !messages.isEmpty else { return nil }
        
        // Try backend proxy first (supports all models)
        if let result = await sendChatViaBackend(messages: messages) {
            return result
        }
        
        // Direct Ollama fallback
        if selectedModel == .ollama || selectedModel == .onDeviceLarge {
            return await requestOllamaChat(messages: messages)
        }
        
        if !NetworkMonitor.shared.isConnected {
            return "Нет сети. Запустите Ollama для офлайн-чата."
        }
        
        return "Бэкенд недоступен. Запустите сервер: cd jarvis-backend && python3 -m uvicorn main:app --port 8000"
    }
    
    private func sendChatViaBackend(messages: [(role: String, content: String)]) async -> String? {
        let modelName = UserDefaults.standard.string(forKey: Config.Storage.ollamaModelKey) ?? Config.Ollama.defaultModelName
        
        let url = Config.Endpoints.llmChat
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        
        struct OllamaChatRequest: Encodable {
            let model: String
            let messages: [ChatMessagePayload]
            let stream: Bool
        }
        struct OllamaChatResponse: Decodable {
            let message: ChatMessagePayload?
        }
        
        let payload = OllamaChatRequest(
            model: modelName,
            messages: messages.map { ChatMessagePayload(role: $0.role, content: $0.content) },
            stream: false
        )
        request.httpBody = try? JSONEncoder().encode(payload)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            let decoded = try? JSONDecoder().decode(OllamaChatResponse.self, from: data)
            return decoded?.message?.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
    
    private func requestOllamaChat(messages: [(role: String, content: String)]) async -> String? {
        let modelName = UserDefaults.standard.string(forKey: Config.Storage.ollamaModelKey) ?? Config.Ollama.defaultModelName
        let url = Config.Endpoints.ollamaBase.appendingPathComponent("api/chat")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        
        struct Req: Encodable { let model: String; let messages: [ChatMessagePayload]; let stream: Bool }
        struct Resp: Decodable { let message: ChatMessagePayload? }
        
        let payload = Req(model: modelName, messages: messages.map { ChatMessagePayload(role: $0.role, content: $0.content) }, stream: false)
        request.httpBody = try? JSONEncoder().encode(payload)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let text = (try? JSONDecoder().decode(Resp.self, from: data))?.message?.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return text.isEmpty ? nil : text
        } catch {
            return "Ollama не отвечает. Проверьте: ollama serve"
        }
    }
    
    // MARK: - Check services status
    
    func checkOllamaStatus() async -> Bool {
        do {
            let url = Config.Endpoints.ollamaBase.appendingPathComponent("api/version")
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    func checkBackendStatus() async -> (running: Bool, ollamaConnected: Bool) {
        struct HealthResp: Decodable { let status: String; let ollama: Bool? }
        do {
            let url = URL(string: "https://localhost:8000/health")!
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return (false, false) }
            let health = try? JSONDecoder().decode(HealthResp.self, from: data)
            return (true, health?.ollama ?? false)
        } catch {
            return (false, false)
        }
    }
    
    func checkGoogleAuthStatus() async -> Bool {
        struct AuthResp: Decodable { let authorized: Bool }
        do {
            let (data, response) = try await URLSession.shared.data(from: Config.Endpoints.authStatus)
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
