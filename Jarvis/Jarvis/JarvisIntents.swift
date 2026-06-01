import AppIntents
import SwiftUI

// MARK: - Add Task Intent

struct AddJarvisTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "intent_add_task_title"
    static var description = IntentDescription("intent_add_task_description")
    static let supportedModes: IntentModes = [.foreground]

    @Parameter(title: "intent_param_task_title", description: "intent_param_task_title_desc")
    var title: String

    @Parameter(title: "intent_param_inbox", description: "intent_param_inbox_desc")
    var isInbox: Bool

    @Parameter(title: "intent_param_date", description: "intent_param_date_desc")
    var date: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("intent_add_summary \(\.$title)") {
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
    static var title: LocalizedStringResource = "intent_show_today_title"
    static var description = IntentDescription("intent_show_today_description")
    static let supportedModes: IntentModes = [.foreground]

    func perform() async throws -> some IntentResult {
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
                "Add task to \(.applicationName)",
                "Create task in \(.applicationName)",
                "New task in \(.applicationName)"
            ],
            shortTitle: "intent_shortcut_add_task",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: ShowJarvisTodayIntent(),
            phrases: [
                "Show tasks in \(.applicationName)",
                "What's today in \(.applicationName)"
            ],
            shortTitle: "intent_shortcut_show_today",
            systemImageName: "calendar"
        )
    }
}
