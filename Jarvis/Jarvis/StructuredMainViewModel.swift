import SwiftUI
import Observation

// MARK: - StructuredMainView ViewModel
// Extracts ~30 @State properties and ~15 action methods from StructuredMainView,
// keeping the View struct focused on layout and rendering.
// Uses @Observable (Observation framework, iOS 17+).

@Observable
@MainActor
final class StructuredMainViewModel {
    
    // MARK: - UI State
    
    var selectedDate = Date()
    var selectedSection: NavigationSection = .today
    var selectedCategoryId: UUID?
    var showAddTask = false
    var showSettings = false
    var showProfile = false
    var showSleepCalculator = false
    var selectedTab = 0
    var editingTask: PlannerTask?
    var draggedTask: PlannerTask?
    var searchQuery = ""
    var completedDropHighlighted = false
    var showMessengerShare = false
    var showMonthCalendar = false
    var showAIFullChat = false
    
    // MARK: - Store Reference
    
    /// Not owned — the View still holds @StateObject for publisher-based reactivity.
    private let store: PlannerStore
    
    init(store: PlannerStore = .shared) {
        self.store = store
    }
    
    // MARK: - Computed Helpers
    
    var sectionSubtitle: String {
        AppRouter.subtitle(for: selectedSection, taskCount: store.taskCount(for: selectedSection))
    }
    
    var emptyStateText: String {
        AppRouter.emptyStateText(for: selectedSection)
    }
    
    func taskCount(for section: NavigationSection) -> Int {
        store.taskCount(for: section)
    }
    
    var tasksForCurrentSection: [PlannerTask] {
        let calendar = Calendar.current
        let startOfTomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        switch selectedSection {
        case .inbox:
            return store.inboxTasks.filter { !$0.isCompleted }
        case .today:
            return store.tasksForDay(Date()).filter { !$0.isCompleted }
        case .scheduled:
            return store.scheduledTasks.filter { !$0.isCompleted && $0.date < startOfTomorrow }
        case .futurePlans:
            return store.scheduledTasks.filter { !$0.isCompleted && $0.date >= startOfTomorrow }
        case .completed:
            return store.completedTasks
        case .all:
            return store.tasks.sorted { $0.date < $1.date }
        case .calendarSection, .mailSection, .messengers, .analytics, .projects, .chat, .health, .kanban, .templates, .habits, .focus, .systemCalendar, .registries:
            return []
        }
    }
    
    var filteredTasksForCurrentSection: [PlannerTask] {
        var base = tasksForCurrentSection
        
        if let categoryId = selectedCategoryId {
            base = base.filter { $0.categoryId == categoryId }
        }
        
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter {
            $0.title.lowercased().contains(q) || $0.notes.lowercased().contains(q)
        }
    }
    
    // MARK: - Date Navigation
    
    func moveDate(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDate = newDate
            }
        }
    }
    
    func getWeekDays() -> [Date] {
        let calendar = Calendar.current
        let today = Date()
        return (-14...14).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }
    
    // MARK: - Task Actions
    
    func toggleTask(_ task: PlannerTask) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            store.toggleCompletion(task: task, onDay: Calendar.current.isDateInToday(selectedDate) ? nil : selectedDate)
        }
    }
    
    func restoreTask(_ task: PlannerTask) {
        var updated = task
        updated.isCompleted = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            store.update(updated)
        }
    }
    
    func scheduleTaskToToday(_ task: PlannerTask) {
        var updated = task
        updated.isInbox = false
        updated.date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        store.update(updated)
    }
    
    func moveTaskToInbox(_ taskID: UUID) {
        guard let task = store.tasks.first(where: { $0.id == taskID }) else { return }
        var updated = task
        updated.isInbox = true
        store.update(updated)
    }
    
    func moveTaskToDate(_ taskID: UUID, date: Date) {
        guard let task = store.tasks.first(where: { $0.id == taskID }) else { return }
        var updated = task
        updated.isInbox = false
        updated.date = Calendar.current.date(
            bySettingHour: Calendar.current.component(.hour, from: task.date),
            minute: Calendar.current.component(.minute, from: task.date),
            second: 0, of: date
        ) ?? date
        store.update(updated)
    }
    
    func moveTaskToDateAndTime(taskID: UUID, date: Date, hour: Int, minute: Int = 0) {
        guard let task = store.tasks.first(where: { $0.id == taskID }) else { return }
        var updated = task
        updated.isInbox = false
        updated.isAllDay = false
        let dayStart = Calendar.current.startOfDay(for: date)
        updated.date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart) ?? dayStart
        store.update(updated)
    }
    
    func moveToInbox(_ task: PlannerTask) {
        var updated = task
        updated.isInbox = true
        store.update(updated)
    }
    
    func moveTask(taskID: UUID, to section: NavigationSection) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            store.moveTask(taskID: taskID, to: section)
        }
    }
    
    func moveTaskToFuturePlans(_ task: PlannerTask) {
        var updated = task
        updated.isInbox = false
        updated.isCompleted = false
        if let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date()) {
            updated.date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: nextWeek) ?? nextWeek
        }
        store.update(updated)
    }
    
    func duplicateTask(_ task: PlannerTask) {
        let newTask = PlannerTask(
            title: task.title + " (\(L10n.copy))",
            notes: task.notes,
            date: task.date,
            durationMinutes: task.durationMinutes,
            isAllDay: task.isAllDay,
            hasAlarm: task.hasAlarm,
            isInbox: task.isInbox,
            colorIndex: task.colorIndex,
            icon: task.icon,
            categoryId: task.categoryId,
            tagIds: task.tagIds,
            priority: task.priority
        )
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            store.add(newTask)
        }
    }
    
    func scheduleForTomorrow(_ task: PlannerTask) {
        var updated = task
        updated.isInbox = false
        if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
            updated.date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        }
        store.update(updated)
    }
    
    func changeTaskColor(_ task: PlannerTask, to colorIndex: Int) {
        var updated = task
        updated.colorIndex = colorIndex
        store.update(updated)
    }
    
    func addTaskAtTime(hour: Int, minute: Int) {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: selectedDate)
        let taskDate = cal.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart) ?? dayStart
        selectedDate = taskDate
        showAddTask = true
    }
    
    // MARK: - Section Navigation
    
    func navigateToSection(_ section: NavigationSection) {
        selectedSection = section
        if let tabIdx = AppRouter.tabIndex(for: section) {
            selectedTab = tabIdx
        }
    }
    
    // MARK: - Timeline Helpers
    
    func taskMinutesOfDay(_ date: Date) -> CGFloat {
        let cal = Calendar.current
        return CGFloat(cal.component(.hour, from: date)) * 60 + CGFloat(cal.component(.minute, from: date))
    }
    
    func formatDuration(_ minutes: Int) -> String {
        DurationFormatter.format(minutes)
    }
    
    func gapMessage(_ gapMinutes: Int) -> String {
        if gapMinutes < 10 { return L10n.almostTime }
        if gapMinutes < 30 { return L10n.quickBreak }
        if gapMinutes < 60 { return L10n.timeForFocus }
        if gapMinutes < 120 { return L10n.aCanvasForIdeas }
        return L10n.plentyOfTime
    }
}
