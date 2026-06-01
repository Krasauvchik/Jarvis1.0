import Foundation
import Combine

// MARK: - AI Life Coach
/// Персональный AI-коуч: фитнес-планы, анализ прогресса, рекомендации.
/// Пример: "сходить в зал — качать плечи" → AI даёт план тренировки
/// или анализ прогресса, если ранее были похожие сессии.

@MainActor
final class AILifeCoach: ObservableObject {
    static let shared = AILifeCoach()

    @Published var isProcessing = false
    @Published var lastCoachResponse: CoachResponse?

    private let historyKey = "jarvis_life_coach_history"
    private(set) var sessionHistory: [CoachSession] = []

    private init() { loadHistory() }

    // MARK: - Models

    struct CoachResponse: Identifiable {
        let id = UUID()
        let category: LifeCategory
        let content: String
        let plan: [String]?
        let progressAnalysis: String?
        let generatedAt: Date
    }

    struct CoachSession: Codable, Identifiable {
        let id: UUID
        let category: LifeCategory
        let taskDescription: String
        let coachAdvice: String
        let date: Date
    }

    enum LifeCategory: String, Codable, CaseIterable {
        case fitness = "fitness"
        case nutrition = "nutrition"
        case learning = "learning"
        case meditation = "meditation"
        case finance = "finance"
        case health = "health"
        case hobby = "hobby"
        case other = "other"

        var emoji: String {
            switch self {
            case .fitness: return "💪"
            case .nutrition: return "🥗"
            case .learning: return "📚"
            case .meditation: return "🧘"
            case .finance: return "💰"
            case .health: return "❤️"
            case .hobby: return "🎨"
            case .other: return "🌟"
            }
        }

        var displayName: String {
            switch self {
            case .fitness: return L10n.coachFitness
            case .nutrition: return L10n.coachNutrition
            case .learning: return L10n.coachLearning
            case .meditation: return L10n.coachMeditation
            case .finance: return L10n.coachFinance
            case .health: return L10n.coachHealth
            case .hobby: return L10n.coachHobby
            case .other: return L10n.coachOther
            }
        }
    }

    // MARK: - Category Classification

    func classifyCategory(_ text: String) -> LifeCategory {
        let lower = text.lowercased()

        // Bilingual keywords (ru + en) for robust classification
        let fitnessWords = ["зал", "трениров", "качать", "пресс", "бег", "плечи", "спорт", "штанг", "гантел", "отжим", "присед", "кардио", "растяж",
                            "gym", "workout", "train", "abs", "run", "shoulder", "sport", "barbell", "dumbbell", "pushup", "squat", "cardio", "stretch", "exercise", "fitness"]
        let nutritionWords = ["еда", "питан", "калори", "диет", "рецепт", "готов", "завтрак", "обед", "ужин", "перекус", "белок", "углевод",
                              "food", "nutrit", "calori", "diet", "recipe", "cook", "breakfast", "lunch", "dinner", "snack", "protein", "carb", "meal"]
        let learningWords = ["учить", "курс", "книг", "читать", "практик", "изуч", "язык", "програм", "экзамен",
                             "learn", "course", "book", "read", "practic", "study", "language", "program", "exam", "lecture", "tutorial"]
        let meditationWords = ["медитац", "дыхан", "релакс", "йога", "осознан", "спокойств", "сон", "mindful",
                               "meditat", "breath", "relax", "yoga", "calm", "sleep", "awareness"]
        let financeWords = ["бюджет", "деньги", "инвест", "накоп", "доход", "расход", "финанс", "сбережен",
                            "budget", "money", "invest", "saving", "income", "expens", "financ", "salary"]
        let healthWords = ["здоров", "врач", "лекарств", "витамин", "анализ", "давлен", "вес", "сердц",
                           "health", "doctor", "medic", "vitamin", "checkup", "pressure", "weight", "heart"]

        if fitnessWords.contains(where: { lower.contains($0) }) { return .fitness }
        if nutritionWords.contains(where: { lower.contains($0) }) { return .nutrition }
        if learningWords.contains(where: { lower.contains($0) }) { return .learning }
        if meditationWords.contains(where: { lower.contains($0) }) { return .meditation }
        if financeWords.contains(where: { lower.contains($0) }) { return .finance }
        if healthWords.contains(where: { lower.contains($0) }) { return .health }
        return .other
    }

    // MARK: - Get Coaching Advice

    func getCoachingAdvice(
        taskDescription: String,
        taskNotes: String? = nil,
        category: LifeCategory? = nil
    ) async -> CoachResponse {
        isProcessing = true
        defer { isProcessing = false }

        let resolvedCategory = category ?? classifyCategory(taskDescription)
        let previousSessions = sessionHistory.filter { $0.category == resolvedCategory }
        let hasPriorSessions = !previousSessions.isEmpty

        let prompt = buildPrompt(
            task: taskDescription,
            notes: taskNotes,
            category: resolvedCategory,
            history: previousSessions,
            hasPrior: hasPriorSessions
        )

        let advice = await callLLM(prompt: prompt)
        let plan = extractPlan(from: advice)
        let progress = hasPriorSessions ? extractProgress(from: advice) : nil

        let response = CoachResponse(
            category: resolvedCategory,
            content: advice,
            plan: plan,
            progressAnalysis: progress,
            generatedAt: Date()
        )

        let session = CoachSession(
            id: UUID(),
            category: resolvedCategory,
            taskDescription: taskDescription,
            coachAdvice: advice,
            date: Date()
        )
        sessionHistory.append(session)
        saveHistory()

        lastCoachResponse = response
        return response
    }

    // MARK: - LLM Call

    private func callLLM(prompt: String) async -> String {
        let systemPrompt = "Ты — персональный AI-коуч Jarvis. Давай конкретные, практичные советы. Отвечай по-русски."
        
        // 1. Gemini — основной (встроенный ключ)
        let gemini = GeminiService.shared
        if gemini.isConfigured {
            if let result = await gemini.generate(
                message: prompt,
                systemPrompt: systemPrompt,
                temperature: 0.6,
                maxTokens: 1024
            ) {
                let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        
        // Try backend proxy
        let url = Config.backendURL.appendingPathComponent("ai/command")
        var request = Config.authorizedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        let body: [String: Any] = ["command": prompt]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await Config.urlSession.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let resp = json["response"] as? String {
                return resp
            }
        } catch {
            Logger.shared.error("AILifeCoach backend error: \(error.localizedDescription)")
        }

        return L10n.coachFailed
    }

    // MARK: - Prompt Builder

    private func buildPrompt(
        task: String,
        notes: String?,
        category: LifeCategory,
        history: [CoachSession],
        hasPrior: Bool
    ) -> String {
        var prompt = """
        Ты — персональный AI-коуч в категории "\(category.displayName)".
        Задача пользователя: \(task)
        """
        if let notes = notes, !notes.isEmpty {
            prompt += "\nДоп. заметки: \(notes)"
        }
        if hasPrior {
            prompt += "\n\nИстория (последние 5 сессий):\n"
            for s in history.suffix(5) {
                prompt += "- [\(s.date.formatted(.dateTime.day().month()))]: \(s.taskDescription)\n"
            }
            prompt += "\nДай анализ прогресса И обновлённый план."
        } else {
            prompt += "\nЭто первая сессия. Дай конкретный план действий (шаги)."
        }
        prompt += "\nОтвечай на русском. Формат: 1) краткий анализ 2) план по шагам."
        return prompt
    }

    // MARK: - Helpers

    private func extractPlan(from text: String) -> [String]? {
        let lines = text.components(separatedBy: "\n")
        let planLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("1.") || trimmed.hasPrefix("2.") ||
                   trimmed.hasPrefix("3.") || trimmed.hasPrefix("4.") ||
                   trimmed.hasPrefix("5.") || trimmed.hasPrefix("- ")
        }
        return planLines.isEmpty ? nil : planLines
    }

    private func extractProgress(from text: String) -> String? {
        let lower = text.lowercased()
        if lower.contains("прогресс") || lower.contains("улучшен") || lower.contains("динамик") {
            let sentences = text.components(separatedBy: ".")
            let progressSentences = sentences.filter {
                let l = $0.lowercased()
                return l.contains("прогресс") || l.contains("улучш") || l.contains("динамик") || l.contains("результат")
            }
            return progressSentences.isEmpty ? nil : progressSentences.joined(separator: ". ").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    // MARK: - Persistence

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([CoachSession].self, from: data) else { return }
        sessionHistory = decoded
    }

    private func saveHistory() {
        let recent = Array(sessionHistory.suffix(50))
        if let data = try? JSONEncoder().encode(recent) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }
}
