import Foundation
import SwiftUI
import Combine

// MARK: - Voice Command Executor
/// Принимает AIAction от LLM и выполняет их в PlannerStore.
/// Это мост между естественным языком (через LLM) и конкретными операциями приложения.

@MainActor
final class VoiceCommandExecutor: ObservableObject {
    
    @Published var lastExecutionLog: [String] = []
    
    private let store: PlannerStore
    private let calendar = Calendar.current
    
    init(store: PlannerStore? = nil) {
        self.store = store ?? PlannerStore.shared
    }
    
    // MARK: - Execute actions from AI response
    
    /// Выполняет массив AIAction, возвращает лог выполненных операций.
    @discardableResult
    func execute(actions: [AIAction]) -> [String] {
        var log: [String] = []
        
        for action in actions {
            let result = executeSingle(action)
            log.append(result)
        }
        
        lastExecutionLog = log
        return log
    }
    
    /// Выполняет полный AICommandResponse — actions + возвращает текст ответа с логом.
    func executeResponse(_ response: AICommandResponse) -> String {
        var text = response.response
        
        if let actions = response.actions, !actions.isEmpty {
            let log = execute(actions: actions)
            let logText = log.joined(separator: "\n")
            if !logText.isEmpty {
                text += "\n\n" + logText
            }
        }
        
        return text
    }
    
    // MARK: - Single action execution
    
    private func executeSingle(_ action: AIAction) -> String {
        switch action.type {
        case "create_task":
            return executeCreateTask(action.params)
        case "complete_task":
            return executeCompleteTask(action.params)
        case "delete_task":
            return executeDeleteTask(action.params)
        case "reschedule_task":
            return executeRescheduleTask(action.params)
        case "move_task":
            return executeMoveTask(action.params)
        case "create_event":
            return L10n.voiceEventCreated
        case "send_email":
            return L10n.voiceEmailSent
        case "show_calendar":
            return L10n.voiceCalendarLoaded
        case "show_mail":
            return L10n.voiceMailLoaded
        case "meeting_briefing":
            return L10n.voiceBriefingReady
        case "context_search":
            return L10n.voiceCrossSearchDone
        case "coaching":
            return L10n.voiceCoachReady
        case "delegate_task":
            let assignee = action.params["assignee"] ?? ""
            return L10n.voiceTaskDelegated(assignee)
        case "advice":
            return ""
        case "none":
            return ""
        default:
            return ""
        }
    }
    
    // MARK: - Task operations
    
    private func executeCreateTask(_ params: [String: String]) -> String {
        let title = params["title"] ?? L10n.voiceNewTaskDefault
        let notes = params["notes"] ?? ""
        let priorityStr = params["priority"] ?? "medium"
        let priority = TaskPriority(rawValue: priorityStr) ?? .medium
        let isAllDay = params["is_all_day"] == "true"
        
        // Parse date
        var taskDate = Date()
        if let dateStr = params["date"] {
            taskDate = parseDate(dateStr) ?? Date()
        }
        
        // Parse duration
        let duration = Int(params["duration"] ?? "60") ?? 60
        
        // Check if it should go to inbox
        let isInbox = params["folder"]?.lowercased() == "inbox" || params["is_inbox"] == "true"
        
        let task = PlannerTask(
            title: title,
            notes: notes,
            date: taskDate,
            durationMinutes: duration,
            isAllDay: isAllDay,
            isInbox: isInbox,
            priority: priority
        )
        
        if isInbox {
            store.addToInbox(task)
        } else {
            store.add(task)
        }
        
        triggerHaptic(.success)
        
        let dateFormatted = taskDate.formatted(date: .abbreviated, time: .shortened)
        return L10n.voiceTaskCreated(title, dateFormatted)
    }
    
    private func executeCompleteTask(_ params: [String: String]) -> String {
        guard let searchTitle = params["title"]?.lowercased() else {
            return L10n.voiceNoTaskNameComplete
        }
        
        if let task = findTask(byTitle: searchTitle) {
            store.toggleCompletion(task: task, onDay: nil)
            triggerHaptic(.success)
            return L10n.voiceTaskCompleted(task.title)
        }
        
        return L10n.voiceTaskNotFound(searchTitle)
    }
    
    private func executeDeleteTask(_ params: [String: String]) -> String {
        guard let searchTitle = params["title"]?.lowercased() else {
            return L10n.voiceNoTaskNameDelete
        }
        
        if let task = findTask(byTitle: searchTitle) {
            store.delete(task)
            triggerHaptic(.warning)
            return L10n.voiceTaskDeleted(task.title)
        }
        
        return L10n.voiceTaskNotFound(searchTitle)
    }
    
    private func executeRescheduleTask(_ params: [String: String]) -> String {
        guard let searchTitle = params["title"]?.lowercased() else {
            return L10n.voiceNoTaskNameReschedule
        }
        
        guard let newDateStr = params["new_date"] ?? params["date"],
              let newDate = parseDate(newDateStr) else {
            return L10n.voiceNoNewDate
        }
        
        if var task = findTask(byTitle: searchTitle) {
            task.date = newDate
            store.update(task)
            triggerHaptic(.success)
            return L10n.voiceTaskRescheduled(task.title, newDate.formatted(date: .abbreviated, time: .shortened))
        }
        
        return L10n.voiceTaskNotFound(searchTitle)
    }
    
    private func executeMoveTask(_ params: [String: String]) -> String {
        guard let searchTitle = params["title"]?.lowercased() else {
            return L10n.voiceNoTaskNameMove
        }
        
        guard let folder = params["folder"]?.lowercased() else {
            return L10n.voiceNoTargetFolder
        }
        
        guard let task = findTask(byTitle: searchTitle) else {
            return L10n.voiceTaskNotFound(searchTitle)
        }
        
        // Map folder name to NavigationSection
        let section = mapFolderToSection(folder)
        store.moveTask(taskID: task.id, to: section)
        triggerHaptic(.success)
        return L10n.voiceTaskMoved(task.title, sectionDisplayName(section))
    }
    
    // MARK: - Helpers
    
    /// Fuzzy search: exact match first, then contains, then Levenshtein.
    private func findTask(byTitle searchTitle: String) -> PlannerTask? {
        let lower = searchTitle.lowercased()
        
        // 1. Exact match
        if let exact = store.tasks.first(where: { $0.title.lowercased() == lower }) {
            return exact
        }
        
        // 2. Contains match (prioritize non-completed)
        let containing = store.tasks.filter { $0.title.lowercased().contains(lower) || lower.contains($0.title.lowercased()) }
        if let notCompleted = containing.first(where: { !$0.isCompleted }) {
            return notCompleted
        }
        if let any = containing.first {
            return any
        }
        
        // 3. Word intersection match
        let searchWords = Set(lower.components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 })
        var bestMatch: PlannerTask?
        var bestScore = 0
        
        for task in store.tasks {
            let taskWords = Set(task.title.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 })
            let intersection = searchWords.intersection(taskWords).count
            if intersection > bestScore {
                bestScore = intersection
                bestMatch = task
            }
        }
        
        return bestScore > 0 ? bestMatch : nil
    }
    
    private func parseDate(_ string: String) -> Date? {
        // ISO8601
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: string) { return d }
        
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: string) { return d }
        
        // Date-only
        iso.formatOptions = [.withFullDate]
        if let d = iso.date(from: string) { return d }
        
        // Relative: "завтра", "послезавтра", "через N дней"
        let lower = string.lowercased()
        if lower.contains("завтра") || lower.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: lower.contains("после") ? 2 : 1, to: Date())
        }
        if lower.contains("сегодня") || lower.contains("today") {
            return Date()
        }
        
        // "через N дней/часов"
        if let match = lower.range(of: #"через\s+(\d+)\s+(дн|час|минут)"#, options: .regularExpression) {
            let nums = String(lower[match]).components(separatedBy: .decimalDigits.inverted).compactMap { Int($0) }
            let text = String(lower[match])
            if let n = nums.first {
                if text.contains("дн") { return calendar.date(byAdding: .day, value: n, to: Date()) }
                if text.contains("час") { return calendar.date(byAdding: .hour, value: n, to: Date()) }
                if text.contains("минут") { return calendar.date(byAdding: .minute, value: n, to: Date()) }
            }
        }
        
        return nil
    }
    
    private func mapFolderToSection(_ folder: String) -> NavigationSection {
        let lower = folder.lowercased()
        switch lower {
        case "inbox", "входящие": return .inbox
        case "today", "сегодня": return .today
        case "scheduled", "запланированные": return .scheduled
        case "future", "планы", "будущие": return .futurePlans
        case "completed", "выполненные", "готово": return .completed
        case "all", "все": return .all
        default: return .today
        }
    }
    
    private func sectionDisplayName(_ section: NavigationSection) -> String {
        return section.localizedName
    }
}
