import Foundation
import SwiftUI

enum AIModel: String, CaseIterable, Identifiable, Codable, Sendable {
    case gemini       // Google Gemini — прямой вызов, бесплатный free tier
    case yandexGPT    // YandexGPT — лучший русский, требует API-ключ
    case cloudGPT     // Cloud GPT через бэкенд (OpenAI-compatible)
    case heuristic    // Оффлайн-эвристика (без LLM)
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .gemini: return "Google Gemini"
        case .yandexGPT: return "YandexGPT"
        case .cloudGPT: return "Cloud GPT"
        case .heuristic: return L10n.aiModelHeuristic
        }
    }
    
    var descriptionText: String {
        switch self {
        case .gemini: return L10n.aiModelGeminiDesc
        case .yandexGPT: return L10n.aiModelYandexDesc
        case .cloudGPT: return L10n.aiModelCloudDesc
        case .heuristic: return L10n.aiModelHeuristicDesc
        }
    }
    
    var icon: String {
        switch self {
        case .gemini: return "sparkle"
        case .yandexGPT: return "text.bubble.fill"
        case .cloudGPT: return "cloud.fill"
        case .heuristic: return "cpu"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .gemini: return .blue
        case .yandexGPT: return .red
        case .cloudGPT: return .purple
        case .heuristic: return .gray
        }
    }
    
    var badge: String? {
        switch self {
        case .gemini: return L10n.aiModelBadgeFree
        case .yandexGPT: return "🇷🇺 \(L10n.aiModelBadgeBestRu)"
        case .cloudGPT: return nil
        case .heuristic: return L10n.aiModelBadgeOffline
        }
    }
    
    /// Модель работает локально / не требует облака
    var isLocal: Bool {
        switch self {
        case .heuristic: return true
        case .yandexGPT, .gemini, .cloudGPT: return false
        }
    }
    
    /// Нужна ли настройка (API key и т.д.) для работы
    var needsSetup: Bool {
        switch self {
        case .gemini: return !GeminiService.shared.isConfigured
        case .yandexGPT: return true  // YandexGPT removed — always needs setup
        case .cloudGPT: return Config.apiKey == nil
        case .heuristic: return false
        }
    }
    
    /// Провайдер полностью готов к использованию
    var isReady: Bool { !needsSetup }

    /// Провайдер заявлен, но ещё не реализован — показываем «Скоро» и блокируем выбор.
    var isComingSoon: Bool {
        switch self {
        case .yandexGPT: return true   // нет реального клиента YandexGPT
        case .gemini, .cloudGPT, .heuristic: return false
        }
    }
}

final class HeuristicAdapter: Sendable {
    
    func extractTask(from transcript: String, referenceDate: Date) -> PlannerTask? {
        let lower = transcript.lowercased()
        let dayOffset = lower.contains("завтра") || lower.contains("tomorrow") ? 1 : 0
        var hour = 9, minute = 0
        
        if let match = lower.range(of: #"(?:в|на|at)\s*(\d{1,2})(?::(\d{2}))?(?:\s*(?:утра|часов|часа|час))?"#, options: .regularExpression) {
            let numbers = String(lower[match])
                .components(separatedBy: CharacterSet.decimalDigits.inverted)
                .compactMap { Int($0) }
            if let h = numbers.first, (0...23).contains(h) { hour = h }
            if numbers.count > 1, (0...59).contains(numbers[1]) { minute = numbers[1] }
        }
        
        let calendar = Calendar.current
        guard let baseDate = calendar.date(byAdding: .day, value: dayOffset, to: referenceDate) else { return nil }
        var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
        components.hour = hour
        components.minute = minute
        
        guard let taskDate = calendar.date(from: components) else { return nil }
        
        var title = lower
        for word in ["напомни", "remind me", "сегодня", "завтра", "today", "tomorrow",
                     "поставь задачу", "создай задачу", "добавь задачу", "новая задача",
                     "поставь", "создай", "добавь", "задачу", "задача",
                     "утра", "вечера", "часов", "часа", "час"] {
            title = title.replacingOccurrences(of: word, with: "")
        }
        title = title
            .replacingOccurrences(of: #"(?:в|на|at)\s*\d{1,2}(?::\d{2})?"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\s*[-–—]\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*[-–—]\s*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if title.isEmpty { title = L10n.heuristicDefaultTask }
        
        return PlannerTask(
            title: title.prefix(1).uppercased() + title.dropFirst(),
            notes: transcript,
            date: taskDate
        )
    }
    
    func generateAdvice(from tasks: [PlannerTask]) -> [String] {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let todayTasks = tasks.lazy.filter { !$0.isInbox && calendar.isDateInToday($0.date) }
        let count = todayTasks.count
        
        var advice: [String] = []
        
        switch hour {
        case 0..<9: advice.append(L10n.adviceMorning)
        case 9..<12: advice.append(L10n.adviceMidMorning)
        case 12..<17: advice.append(L10n.adviceAfternoon)
        case 17..<21: advice.append(L10n.adviceEvening)
        default: advice.append(L10n.adviceNight)
        }
        
        switch count {
        case 0: advice.append(L10n.adviceNoTasks)
        case 1...3: advice.append(L10n.adviceFewTasks)
        case 4...6: advice.append(L10n.adviceBusyDay)
        default: advice.append(L10n.adviceTooManyTasks)
        }
        
        return advice
    }
}
