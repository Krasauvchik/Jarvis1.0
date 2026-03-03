import Foundation

enum AIModel: String, CaseIterable, Identifiable, Codable, Sendable {
    case gemini
    case heuristic
    case ollama       // локальная модель через Ollama (как в OpenClaw)
    case onDeviceLarge
    case cloudGPT
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .gemini: return "Gemini"
        case .heuristic: return L10n.aiModelHeuristic
        case .ollama: return L10n.aiModelOllamaLocal
        case .onDeviceLarge: return L10n.aiModelOnDevice
        case .cloudGPT: return "Cloud GPT"
        }
    }
    
    /// Модель работает локально / не требует облака
    var isLocal: Bool {
        switch self {
        case .heuristic, .ollama, .onDeviceLarge: return true
        case .gemini, .cloudGPT: return false
        }
    }
}

final class HeuristicAdapter: Sendable {
    
    func extractTask(from transcript: String, referenceDate: Date) -> PlannerTask? {
        let lower = transcript.lowercased()
        let dayOffset = lower.contains("завтра") || lower.contains("tomorrow") ? 1 : 0
        var hour = 9, minute = 0
        
        if let match = lower.range(of: #"(?:в|at)\s*(\d{1,2})(?::(\d{2}))?"#, options: .regularExpression) {
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
        for word in ["напомни", "remind me", "сегодня", "завтра", "today", "tomorrow"] {
            title = title.replacingOccurrences(of: word, with: "")
        }
        title = title
            .replacingOccurrences(of: #"(?:в|at)\s*\d{1,2}(?::\d{2})?"#, with: "", options: .regularExpression)
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
