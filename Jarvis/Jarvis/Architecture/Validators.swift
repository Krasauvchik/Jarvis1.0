import Foundation

// MARK: - Task Validator

enum TaskValidator {
    /// Validates a task title. Returns nil if valid, or an error message.
    static func validateTitle(_ title: String) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return L10n.valTaskTitleEmpty
        }
        if trimmed.count > 500 {
            return L10n.valTaskTitleTooLong
        }
        return nil
    }
    
    /// Validates task duration in minutes.
    static func validateDuration(_ minutes: Int) -> String? {
        if minutes < 5 {
            return L10n.valDurationTooShort
        }
        if minutes > 1440 {
            return L10n.valDurationTooLong
        }
        return nil
    }
    
    /// Validates task notes length.
    static func validateNotes(_ notes: String) -> String? {
        if notes.count > 5000 {
            return L10n.valNotesTooLong
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
            return L10n.valMealTitleEmpty
        }
        if let cal = Int(calories), cal < 0 {
            return L10n.valCaloriesNegative
        }
        if let cal = Int(calories), cal > 10000 {
            return L10n.valCaloriesTooHigh
        }
        return nil
    }
    
    /// Validates sleep entry.
    static func validateSleep(start: Date, end: Date) -> String? {
        if end <= start {
            return L10n.valSleepEndBeforeStart
        }
        let hours = end.timeIntervalSince(start) / 3600
        if hours > 24 {
            return L10n.valSleepTooLong
        }
        return nil
    }
    
    /// Validates activity entry.
    static func validateActivity(title: String, minutes: String) -> String? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            return L10n.valActivityTitleEmpty
        }
        if let min = Int(minutes), min < 0 {
            return L10n.valActivityDurationNegative
        }
        if let min = Int(minutes), min > 1440 {
            return L10n.valActivityDurationTooLong
        }
        return nil
    }
}
