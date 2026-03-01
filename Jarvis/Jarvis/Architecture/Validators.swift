import Foundation

// MARK: - Task Validator

enum TaskValidator {
    /// Validates a task title. Returns nil if valid, or an error message.
    static func validateTitle(_ title: String) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Название задачи не может быть пустым"
        }
        if trimmed.count > 500 {
            return "Название слишком длинное (макс. 500 символов)"
        }
        return nil
    }
    
    /// Validates task duration in minutes.
    static func validateDuration(_ minutes: Int) -> String? {
        if minutes < 5 {
            return "Минимальная длительность — 5 минут"
        }
        if minutes > 1440 {
            return "Максимальная длительность — 24 часа"
        }
        return nil
    }
    
    /// Validates task notes length.
    static func validateNotes(_ notes: String) -> String? {
        if notes.count > 5000 {
            return "Заметки слишком длинные (макс. 5000 символов)"
        }
        return nil
    }
    
    /// Returns true if the task can be saved.
    static func canSave(title: String) -> Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Wellness Validator

enum WellnessValidator {
    /// Validates meal entry.
    static func validateMeal(title: String, calories: String) -> String? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            return "Укажите название блюда"
        }
        if let cal = Int(calories), cal < 0 {
            return "Калории не могут быть отрицательными"
        }
        if let cal = Int(calories), cal > 10000 {
            return "Слишком большое количество калорий (макс. 10000)"
        }
        return nil
    }
    
    /// Validates sleep entry.
    static func validateSleep(start: Date, end: Date) -> String? {
        if end <= start {
            return "Время подъёма должно быть позже времени отбоя"
        }
        let hours = end.timeIntervalSince(start) / 3600
        if hours > 24 {
            return "Длительность сна не может превышать 24 часа"
        }
        return nil
    }
    
    /// Validates activity entry.
    static func validateActivity(title: String, minutes: String) -> String? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            return "Укажите тип активности"
        }
        if let min = Int(minutes), min < 0 {
            return "Длительность не может быть отрицательной"
        }
        if let min = Int(minutes), min > 1440 {
            return "Максимальная длительность — 24 часа"
        }
        return nil
    }
}
