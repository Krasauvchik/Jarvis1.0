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
            case .fitness: return "Фитнес"
            case .nutrition: return "Питание"
            case .learning: return "Обучение"
            case .meditation: return "Медитация"
            case .finance: return "Финансы"
            case .health: return "Здоровье"
            case .hobby: return "Хобби"
            case .other: return "Другое"
            }
        }
    }

    // MARK: - Category Classification

    func classifyCategory(_ text: String) -> LifeCategory {
        let lower = text.lowercased()

        let fitnessWords = ["зал", "трениров", "качать", "пресс", "бег", "плечи", "спорт", "штанг", "гантел", "отжим", "присед", "кардио", "растяж"]
        let nutritionWords = ["еда", "питан", "калори", "диет", "рецепт", "готов", "завтрак", "обед", "ужин", "перекус", "белок", "углевод"]
        let learningWords = ["учить", "курс", "книг", "читать", "практик", "изуч", "язык", "програм", "экзамен"]
        let meditationWords = ["медитац", "дыхан", "релакс", "йога", "осознан", "спокойств", "сон", "mindful"]
        let financeWords = ["бюджет", "деньги", "инвест", "накоп", "доход", "расход", "финанс", "сбережен"]
        let healthWords = ["здоров", "врач", "лекарств", "витамин", "анализ", "давлен", "вес", "сердц"]

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
        let url = Config.Endpoints.ollamaBase.appendingPathComponent("api/generate")
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let model = UserDefaults.standard.string(forKey: Config.Storage.ollamaModelKey) ?? Config.Ollama.defaultModelName
        let body: [String: Any] = ["model": model, "prompt": prompt, "stream": false]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let resp = json["response"] as? String {
                return resp
            }
        } catch {
            Logger.shared.error("AILifeCoach LLM error: \(error.localizedDescription)")
        }

        return "Не удалось получить рекомендацию. Попробуйте позже."
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
