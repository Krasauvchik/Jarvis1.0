import AppIntents
import SwiftUI

// MARK: - Add Task Intent

struct AddJarvisTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Добавить задачу в Jarvis"
    static var description = IntentDescription("Создаёт новую задачу в планнере Jarvis.")
    static let supportedModes: IntentModes = [.foreground]

    @Parameter(title: "Название задачи", description: "Текст задачи")
    var title: String

    @Parameter(title: "В Inbox", description: "Добавить без даты (в папку Inbox)")
    var isInbox: Bool

    @Parameter(title: "Дата и время", description: "Когда выполнить")
    var date: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("Добавить задачу \(\.$title) в Jarvis") {
            \.$isInbox
            \.$date
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let taskDate = date ?? Date()
        let task = PlannerTask(
            title: title,
            date: taskDate,
            durationMinutes: 60,
            isInbox: isInbox
        )
        PlannerStore.shared.add(task)
        CalendarSyncService.shared.addOrUpdateEvent(for: task)
        return .result()
    }
}

// MARK: - Show Today Intent

struct ShowJarvisTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "Показать задачи Jarvis на сегодня"
    static var description = IntentDescription("Открывает Jarvis и показывает задачи на сегодня.")
    static let supportedModes: IntentModes = [.foreground]

    func perform() async throws -> some IntentResult {
        // Открытие приложения — система откроет app. Доп. логика (например открыть на «Сегодня») может быть через URL scheme или UserActivity.
        return .result()
    }
}

// MARK: - App Shortcuts Provider

struct JarvisShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddJarvisTaskIntent(),
            phrases: [
                "Добавь задачу в \(.applicationName)",
                "Создай задачу в \(.applicationName)",
                "Новая задача в \(.applicationName)"
            ],
            shortTitle: "Добавить задачу",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: ShowJarvisTodayIntent(),
            phrases: [
                "Покажи задачи в \(.applicationName)",
                "Что на сегодня в \(.applicationName)"
            ],
            shortTitle: "Задачи на сегодня",
            systemImageName: "calendar"
        )
    }
}
