import Foundation

enum AIModel: String, CaseIterable, Identifiable, Codable {
    case heuristic, onDeviceLarge, cloudGPT
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .heuristic: return "Эвристика"
        case .onDeviceLarge: return "На устройстве"
        case .cloudGPT: return "Cloud GPT"
        }
    }
}

protocol AIAdapter {
    func extractTask(from transcript: String, referenceDate: Date) -> PlannerTask?
    func generateAdvice(from tasks: [PlannerTask]) -> [String]
}

final class HeuristicAdapter: AIAdapter {
    
    func extractTask(from transcript: String, referenceDate: Date) -> PlannerTask? {
        let lower = transcript.lowercased()
        
        let dayOffset = lower.contains("завтра") || lower.contains("tomorrow") ? 1 : 0
        var hour = 9, minute = 0
        
        if let match = lower.range(of: #"(?:в|at)\s*(\d{1,2})(?::(\d{2}))?"#, options: .regularExpression) {
            let timeStr = String(lower[match])
            let numbers = timeStr.components(separatedBy: CharacterSet.decimalDigits.inverted)
                .compactMap { Int($0) }
            if let h = numbers.first, (0...23).contains(h) { hour = h }
            if numbers.count > 1, (0...59).contains(numbers[1]) { minute = numbers[1] }
        }
        
        let calendar = Calendar.current
        guard var components = Optional(calendar.dateComponents([.year, .month, .day], from: referenceDate)) else {
            return nil
        }
        components.day! += dayOffset
        components.hour = hour
        components.minute = minute
        
        guard let taskDate = calendar.date(from: components) else { return nil }
        
        var title = lower
        for word in ["напомни", "remind me", "сегодня", "завтра", "today", "tomorrow"] {
            title = title.replacingOccurrences(of: word, with: "")
        }
        title = title.replacingOccurrences(of: #"(?:в|at)\s*\d{1,2}(?::\d{2})?"#, with: "", options: .regularExpression)
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if title.isEmpty { title = "Задача" }
        
        return PlannerTask(
            title: title.prefix(1).uppercased() + title.dropFirst(),
            notes: transcript,
            date: taskDate
        )
    }
    
    func generateAdvice(from tasks: [PlannerTask]) -> [String] {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let todayTasks = tasks.filter { calendar.isDateInToday($0.date) }
        
        var advice: [String] = []
        
        switch hour {
        case 0..<9: advice.append("Доброе утро! Начни день с лёгкого завтрака.")
        case 9..<12: advice.append("Утро — лучшее время для сложных задач.")
        case 12..<17: advice.append("Не забывай пить воду и делать перерывы.")
        case 17..<21: advice.append("Вечер — время подвести итоги дня.")
        default: advice.append("Пора готовиться ко сну.")
        }
        
        switch todayTasks.count {
        case 0: advice.append("Сегодня нет задач — отличный день для отдыха.")
        case 1...3: advice.append("Немного задач — планируй время эффективно.")
        case 4...6: advice.append("Насыщенный день — расставь приоритеты.")
        default: advice.append("Много задач — делегируй или перенеси часть.")
        }
        
        return advice
    }
}

final class OnDeviceLargeAdapter: AIAdapter {
    private let fallback = HeuristicAdapter()
    func extractTask(from transcript: String, referenceDate: Date) -> PlannerTask? {
        fallback.extractTask(from: transcript, referenceDate: referenceDate)
    }
    func generateAdvice(from tasks: [PlannerTask]) -> [String] {
        fallback.generateAdvice(from: tasks)
    }
}

final class CloudGPTAdapter: AIAdapter {
    private let fallback = HeuristicAdapter()
    func extractTask(from transcript: String, referenceDate: Date) -> PlannerTask? {
        fallback.extractTask(from: transcript, referenceDate: referenceDate)
    }
    func generateAdvice(from tasks: [PlannerTask]) -> [String] {
        fallback.generateAdvice(from: tasks)
    }
}
