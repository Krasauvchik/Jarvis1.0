import Foundation
import Combine
import SwiftUI

// MARK: - Task Icons

enum TaskIcon: String, CaseIterable, Codable, Sendable {
    case star = "star.fill"
    case heart = "heart.fill"
    case bolt = "bolt.fill"
    case flame = "flame.fill"
    case checkmark = "checkmark.seal.fill"
    case flag = "flag.fill"
    case bell = "bell.fill"
    case bookmark = "bookmark.fill"
    case tag = "tag.fill"
    case folder = "folder.fill"
    case doc = "doc.fill"
    case person = "person.fill"
    case house = "house.fill"
    case briefcase = "briefcase.fill"
    case cart = "cart.fill"
    case gift = "gift.fill"
    case phone = "phone.fill"
    case envelope = "envelope.fill"
    case camera = "camera.fill"
    case gamecontroller = "gamecontroller.fill"
    case car = "car.fill"
    case airplane = "airplane"
    case sportscourt = "sportscourt.fill"
    case dumbbell = "dumbbell.fill"
    case fork = "fork.knife"
    case cup = "cup.and.saucer.fill"
    case pill = "pill.fill"
    case cross = "cross.fill"
    case music = "music.note"
    case book = "book.fill"
    case graduationcap = "graduationcap.fill"
    case paintbrush = "paintbrush.fill"
    case wrench = "wrench.fill"
    case laptop = "laptopcomputer"
    case desktopcomputer = "desktopcomputer"
    case tv = "tv.fill"
    case headphones = "headphones"
    case lightbulb = "lightbulb.fill"
    case moon = "moon.fill"
    case sun = "sun.max.fill"
    
    var systemName: String { rawValue }
}

// MARK: - Task Category

struct TaskCategory: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var colorIndex: Int
    var icon: String

    init(id: UUID = UUID(), name: String, colorIndex: Int = 0, icon: String = "folder.fill") {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
        self.icon = icon
    }

    var color: Color {
        JarvisTheme.taskColors[colorIndex % JarvisTheme.taskColors.count]
    }
}

// MARK: - Task Tag

struct TaskTag: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var colorIndex: Int

    init(id: UUID = UUID(), name: String, colorIndex: Int = 0) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
    }

    var color: Color {
        JarvisTheme.taskColors[colorIndex % JarvisTheme.taskColors.count]
    }
}

// MARK: - Task Priority (по мотивам таск-менеджеров: React-Django Task Manager, Task-Sync-Pro)

enum TaskPriority: String, Codable, Hashable, CaseIterable, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"

    var displayName: String {
        switch self {
        case .low: return "Низкий"
        case .medium: return "Средний"
        case .high: return "Высокий"
        }
    }

    var icon: String {
        switch self {
        case .low: return "arrow.down.circle.fill"
        case .medium: return "circle.fill"
        case .high: return "exclamationmark.circle.fill"
        }
    }

    /// Порядок для сортировки: высокий первый (0), затем средний (1), низкий (2).
    var sortOrder: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }
}

// MARK: - Recurrence

enum RecurrenceRule: String, Codable, Hashable, CaseIterable, Sendable {
    case daily, weekdays, weekends, weekly, monthly, yearly

    var displayName: String {
        switch self {
        case .daily: return "Каждый день"
        case .weekdays: return "Будни"
        case .weekends: return "Выходные"
        case .weekly: return "Еженедельно"
        case .monthly: return "Ежемесячно"
        case .yearly: return "Ежегодно"
        }
    }
}

// MARK: - Task Model

struct PlannerTask: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var notes: String
    var date: Date
    var durationMinutes: Int
    var isAllDay: Bool
    var recurrenceRule: RecurrenceRule?
    var isCompleted: Bool
    var hasAlarm: Bool
    var isInbox: Bool
    var completedRecurrenceDates: [Date]
    var colorIndex: Int
    var icon: String
    var categoryId: UUID?
    var tagIds: [UUID]
    var calendarEventId: String?
    var priority: TaskPriority
    /// Parent task ID for sub-task hierarchy (Phase 3)
    var parentTaskId: UUID?
    /// Project ID for project grouping (Phase 3)
    var projectId: UUID?

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        date: Date = Date(),
        durationMinutes: Int = 60,
        isAllDay: Bool = false,
        recurrenceRule: RecurrenceRule? = nil,
        isCompleted: Bool = false,
        hasAlarm: Bool = true,
        isInbox: Bool = false,
        completedRecurrenceDates: [Date] = [],
        colorIndex: Int = 4,
        icon: String = "circle",
        categoryId: UUID? = nil,
        tagIds: [UUID] = [],
        calendarEventId: String? = nil,
        priority: TaskPriority = .medium,
        parentTaskId: UUID? = nil,
        projectId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.date = date
        self.durationMinutes = durationMinutes
        self.isAllDay = isAllDay
        self.recurrenceRule = recurrenceRule
        self.isCompleted = isCompleted
        self.hasAlarm = hasAlarm
        self.isInbox = isInbox
        self.completedRecurrenceDates = completedRecurrenceDates
        self.colorIndex = colorIndex
        self.icon = icon
        self.categoryId = categoryId
        self.tagIds = tagIds
        self.calendarEventId = calendarEventId
        self.priority = priority
        self.parentTaskId = parentTaskId
        self.projectId = projectId
    }

    enum CodingKeys: String, CodingKey {
        case id, title, notes, date, durationMinutes, isAllDay, recurrenceRule, isCompleted, hasAlarm, isInbox, completedRecurrenceDates, colorIndex, icon, categoryId, tagIds, calendarEventId, priority, parentTaskId, projectId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        notes = try c.decode(String.self, forKey: .notes)
        date = try c.decode(Date.self, forKey: .date)
        durationMinutes = try c.decode(Int.self, forKey: .durationMinutes)
        isAllDay = try c.decode(Bool.self, forKey: .isAllDay)
        recurrenceRule = try c.decodeIfPresent(RecurrenceRule.self, forKey: .recurrenceRule)
        isCompleted = try c.decode(Bool.self, forKey: .isCompleted)
        hasAlarm = try c.decode(Bool.self, forKey: .hasAlarm)
        isInbox = try c.decode(Bool.self, forKey: .isInbox)
        completedRecurrenceDates = try c.decodeIfPresent([Date].self, forKey: .completedRecurrenceDates) ?? []
        colorIndex = try c.decode(Int.self, forKey: .colorIndex)
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "circle"
        categoryId = try c.decodeIfPresent(UUID.self, forKey: .categoryId)
        tagIds = try c.decodeIfPresent([UUID].self, forKey: .tagIds) ?? []
        calendarEventId = try c.decodeIfPresent(String.self, forKey: .calendarEventId)
        priority = try c.decodeIfPresent(TaskPriority.self, forKey: .priority) ?? .medium
        parentTaskId = try c.decodeIfPresent(UUID.self, forKey: .parentTaskId)
        projectId = try c.decodeIfPresent(UUID.self, forKey: .projectId)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(notes, forKey: .notes)
        try c.encode(date, forKey: .date)
        try c.encode(durationMinutes, forKey: .durationMinutes)
        try c.encode(isAllDay, forKey: .isAllDay)
        try c.encodeIfPresent(recurrenceRule, forKey: .recurrenceRule)
        try c.encode(isCompleted, forKey: .isCompleted)
        try c.encode(hasAlarm, forKey: .hasAlarm)
        try c.encode(isInbox, forKey: .isInbox)
        try c.encode(completedRecurrenceDates, forKey: .completedRecurrenceDates)
        try c.encode(colorIndex, forKey: .colorIndex)
        try c.encode(icon, forKey: .icon)
        try c.encodeIfPresent(categoryId, forKey: .categoryId)
        try c.encode(tagIds, forKey: .tagIds)
        try c.encodeIfPresent(calendarEventId, forKey: .calendarEventId)
        try c.encode(priority, forKey: .priority)
        try c.encodeIfPresent(parentTaskId, forKey: .parentTaskId)
        try c.encodeIfPresent(projectId, forKey: .projectId)
    }

    var endDate: Date {
        isAllDay ? date : date.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }
    
    var taskColor: Color {
        JarvisTheme.taskColors[colorIndex % JarvisTheme.taskColors.count]
    }
}

// MARK: - Widget Snapshot (минимум полей для виджета; пишется в App Group)

struct WidgetTaskSnapshot: Codable {
    let id: UUID
    let title: String
    let date: Date
    let isCompleted: Bool
    let isAllDay: Bool
    let colorIndex: Int
}

// MARK: - Day Bounds

struct DayBounds: Equatable, Codable, Sendable {
    var riseHour: Int
    var riseMinute: Int
    var windDownHour: Int
    var windDownMinute: Int

    static let `default` = DayBounds(
        riseHour: Config.Defaults.riseHour,
        riseMinute: Config.Defaults.riseMinute,
        windDownHour: Config.Defaults.windDownHour,
        windDownMinute: Config.Defaults.windDownMinute
    )

    func riseDate(on day: Date) -> Date {
        Calendar.current.date(bySettingHour: riseHour, minute: riseMinute, second: 0, of: day) ?? day
    }

    func windDownDate(on day: Date) -> Date {
        Calendar.current.date(bySettingHour: windDownHour, minute: windDownMinute, second: 0, of: day) ?? day
    }
}

// MARK: - Project (Phase 3)

struct Project: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var description: String
    var colorIndex: Int
    var icon: String
    var isArchived: Bool
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        colorIndex: Int = 0,
        icon: String = "folder.fill",
        isArchived: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.colorIndex = colorIndex
        self.icon = icon
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
    
    var color: Color {
        JarvisTheme.taskColors[colorIndex % JarvisTheme.taskColors.count]
    }
}

// MARK: - Store with iCloud Sync

@MainActor
final class PlannerStore: ObservableObject {
    static let shared = PlannerStore()
    
    @Published var tasks: [PlannerTask] = []
    @Published var dayBounds: DayBounds = .default
    @Published var categories: [TaskCategory] = []
    @Published var tags: [TaskTag] = []
    @Published var projects: [Project] = []

    private let calendar = Calendar.current
    private var syncObserver: NSObjectProtocol?
    private var saveTask: Task<Void, Never>?
    private let appGroupDefaults = UserDefaults(suiteName: Config.appGroupSuite)
    
    init() {
        load()
        setupCloudSync()
    }
    
    deinit {
        if let observer = syncObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupCloudSync() {
        syncObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] _ in
            // Диспатч на main без захвата self в Swift Task (Swift 6)
            DispatchQueue.main.async { [weak self] in
                self?.loadFromCloud()
            }
        }
        NSUbiquitousKeyValueStore.default.synchronize()
    }
    
    private func loadFromCloud() {
        if let cloudTasks = CloudSync.shared.loadTasks() {
            tasks = cloudTasks
        }
        if let cloudBounds = CloudSync.shared.loadDayBounds() {
            dayBounds = cloudBounds
        }
        if let cloudCategories = CloudSync.shared.loadCategories() {
            categories = cloudCategories
        }
        if let cloudTags = CloudSync.shared.loadTags() {
            tags = cloudTags
        }
    }
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    /// Debounced save — coalesces rapid changes (e.g. drag-to-reschedule) into a single disk write.
    private func save() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            // 0.3s debounce for rapid successive changes
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, let self else { return }
            self.persistNow()
        }
    }
    
    /// Immediate write — call only when you need guaranteed persistence (e.g. app backgrounding).
    func persistNow() {
        do {
            let data = try encoder.encode(tasks)
            UserDefaults.standard.set(data, forKey: Config.Storage.tasksKey)
            appGroupDefaults?.set(data, forKey: Config.Storage.tasksKey)
        } catch {
            Logger.shared.error("Failed to save tasks: \(error.localizedDescription)")
        }
        if let widgetData = try? encoder.encode(
            tasks.prefix(20).map { WidgetTaskSnapshot(id: $0.id, title: $0.title, date: $0.date, isCompleted: $0.isCompleted, isAllDay: $0.isAllDay, colorIndex: $0.colorIndex) }
        ) {
            appGroupDefaults?.set(widgetData, forKey: "jarvis_widget_tasks")
        }
        if let catData = try? encoder.encode(categories) {
            UserDefaults.standard.set(catData, forKey: Config.Storage.categoriesKey)
        }
        if let tagData = try? encoder.encode(tags) {
            UserDefaults.standard.set(tagData, forKey: Config.Storage.tagsKey)
        }
        if let projectData = try? encoder.encode(projects) {
            UserDefaults.standard.set(projectData, forKey: Config.Storage.projectsKey)
        }
        CloudSync.shared.saveTasks(tasks)
        CloudSync.shared.saveCategories(categories)
        CloudSync.shared.saveTags(tags)
    }
    
    private func load() {
        if let cloudTasks = CloudSync.shared.loadTasks() {
            tasks = cloudTasks
        } else if let data = UserDefaults.standard.data(forKey: Config.Storage.tasksKey),
                  let decoded = try? decoder.decode([PlannerTask].self, from: data) {
            tasks = decoded
        }
        if let cloudBounds = CloudSync.shared.loadDayBounds() {
            dayBounds = cloudBounds
        }
        if let cloudCategories = CloudSync.shared.loadCategories() {
            categories = cloudCategories
        } else if let data = UserDefaults.standard.data(forKey: Config.Storage.categoriesKey),
                  let decoded = try? decoder.decode([TaskCategory].self, from: data) {
            categories = decoded
        }
        if let cloudTags = CloudSync.shared.loadTags() {
            tags = cloudTags
        } else if let data = UserDefaults.standard.data(forKey: Config.Storage.tagsKey),
                  let decoded = try? decoder.decode([TaskTag].self, from: data) {
            tags = decoded
        }
        // Load projects from local storage
        if let data = UserDefaults.standard.data(forKey: Config.Storage.projectsKey),
           let decoded = try? decoder.decode([Project].self, from: data) {
            projects = decoded
        }
    }

    // MARK: - Computed Properties
    
    var inboxTasks: [PlannerTask] {
        tasks.lazy.filter(\.isInbox).sorted { ($0.priority.sortOrder, $0.date) < ($1.priority.sortOrder, $1.date) }
    }
    
    var scheduledTasks: [PlannerTask] {
        tasks.lazy.filter { !$0.isInbox }.sorted { ($0.priority.sortOrder, $0.date) < ($1.priority.sortOrder, $1.date) }
    }

    // MARK: - Task Queries
    
    func timelineTasks(for day: Date) -> [PlannerTask] {
        tasks.compactMap { task -> PlannerTask? in
            guard !task.isInbox, !task.isAllDay else { return nil }
            if let rule = task.recurrenceRule {
                guard recurrenceMatches(day: day, task: task, rule: rule) else { return nil }
                var copy = task
                let time = calendar.dateComponents([.hour, .minute], from: task.date)
                copy.date = calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: 0, of: day) ?? day
                copy.isCompleted = isRecurrenceCompleted(task: task, on: day)
                return copy
            }
            return calendar.isDate(task.date, inSameDayAs: day) ? task : nil
        }.sorted { ($0.priority.sortOrder, $0.date) < ($1.priority.sortOrder, $1.date) }
    }
    
    func allDayTasks(for day: Date) -> [PlannerTask] {
        tasks.compactMap { task -> PlannerTask? in
            guard !task.isInbox, task.isAllDay else { return nil }
            if let rule = task.recurrenceRule {
                guard recurrenceMatches(day: day, task: task, rule: rule) else { return nil }
                var copy = task
                copy.date = calendar.startOfDay(for: day)
                copy.isCompleted = isRecurrenceCompleted(task: task, on: day)
                return copy
            }
            return calendar.isDate(task.date, inSameDayAs: day) ? task : nil
        }.sorted { ($0.priority.sortOrder, $0.date) < ($1.priority.sortOrder, $1.date) }
    }
    
    func tasksForDay(_ day: Date) -> [PlannerTask] {
        (allDayTasks(for: day) + timelineTasks(for: day))
    }
    
    private func recurrenceMatches(day: Date, task: PlannerTask, rule: RecurrenceRule) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        let taskDayStart = calendar.startOfDay(for: task.date)
        guard dayStart >= taskDayStart else { return false }
        let weekday = calendar.component(.weekday, from: day)
        let dayOfMonth = calendar.component(.day, from: day)
        switch rule {
        case .daily: return true
        case .weekdays: return (2...6).contains(weekday)
        case .weekends: return weekday == 1 || weekday == 7
        case .weekly: return weekday == calendar.component(.weekday, from: task.date)
        case .monthly: return dayOfMonth == calendar.component(.day, from: task.date)
        case .yearly: return calendar.component(.month, from: day) == calendar.component(.month, from: task.date) && dayOfMonth == calendar.component(.day, from: task.date)
        }
    }
    
    private func isRecurrenceCompleted(task: PlannerTask, on day: Date) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        return task.completedRecurrenceDates.contains { calendar.isDate($0, inSameDayAs: dayStart) }
    }

    // MARK: - CRUD Operations
    
    func add(_ task: PlannerTask) {
        tasks.append(task)
        sortAndSave()
    }
    
    func addToInbox(_ task: PlannerTask) {
        var t = task
        t.isInbox = true
        tasks.append(t)
        sortAndSave()
    }
    
    func update(_ task: PlannerTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx] = task
        sortAndSave()
    }
    
    func delete(_ task: PlannerTask) {
        tasks.removeAll { $0.id == task.id }
        save()
    }
    
    func removeCompleted() {
        tasks.removeAll(where: \.isCompleted)
        save()
    }
    
    func removeAll() {
        tasks.removeAll()
        save()
    }
    
    func scheduleFromInbox(_ task: PlannerTask, date: Date, durationMinutes: Int, isAllDay: Bool) {
        var t = task
        t.isInbox = false
        t.date = date
        t.durationMinutes = durationMinutes
        t.isAllDay = isAllDay
        update(t)
    }
    
    func toggleCompletion(task: PlannerTask, onDay day: Date?) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        if task.recurrenceRule != nil, let d = day {
            let dayStart = calendar.startOfDay(for: d)
            if let i = tasks[idx].completedRecurrenceDates.firstIndex(where: { calendar.isDate($0, inSameDayAs: dayStart) }) {
                tasks[idx].completedRecurrenceDates.remove(at: i)
            } else {
                tasks[idx].completedRecurrenceDates.append(dayStart)
            }
        } else {
            tasks[idx].isCompleted.toggle()
        }
        save()
    }
    
    func updateDayBounds(_ bounds: DayBounds) {
        dayBounds = bounds
        CloudSync.shared.saveDayBounds(bounds)
    }
    
    private func sortAndSave() {
        tasks.sort { t1, t2 in
            if t1.isInbox != t2.isInbox { return !t1.isInbox }
            return t1.date < t2.date
        }
        save()
    }

    // MARK: - Categories

    func addCategory(_ category: TaskCategory) {
        categories.append(category)
        save()
    }

    func updateCategory(_ category: TaskCategory) {
        guard let idx = categories.firstIndex(where: { $0.id == category.id }) else { return }
        categories[idx] = category
        save()
    }

    func removeCategory(_ category: TaskCategory) {
        categories.removeAll { $0.id == category.id }
        for i in tasks.indices where tasks[i].categoryId == category.id {
            tasks[i].categoryId = nil
        }
        save()
    }

    func category(for id: UUID?) -> TaskCategory? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
    }

    // MARK: - Tags

    func addTag(_ tag: TaskTag) {
        tags.append(tag)
        save()
    }

    func updateTag(_ tag: TaskTag) {
        guard let idx = tags.firstIndex(where: { $0.id == tag.id }) else { return }
        tags[idx] = tag
        save()
    }

    func removeTag(_ tag: TaskTag) {
        tags.removeAll { $0.id == tag.id }
        for i in tasks.indices {
            tasks[i].tagIds.removeAll { $0 == tag.id }
        }
        save()
    }

    func tags(for ids: [UUID]) -> [TaskTag] {
        ids.compactMap { id in tags.first { $0.id == id } }
    }

    // MARK: - Projects (Phase 3)
    
    func addProject(_ project: Project) {
        projects.append(project)
        save()
    }
    
    func updateProject(_ project: Project) {
        guard let idx = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[idx] = project
        save()
    }
    
    func removeProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        // Unlink tasks from removed project
        for i in tasks.indices where tasks[i].projectId == project.id {
            tasks[i].projectId = nil
        }
        save()
    }
    
    func project(for id: UUID?) -> Project? {
        guard let id else { return nil }
        return projects.first { $0.id == id }
    }
    
    /// Get all tasks belonging to a project
    func tasksForProject(_ projectId: UUID) -> [PlannerTask] {
        tasks.filter { $0.projectId == projectId }
            .sorted { ($0.priority.sortOrder, $0.date) < ($1.priority.sortOrder, $1.date) }
    }
    
    /// Get sub-tasks of a given parent task
    func subTasks(of parentId: UUID) -> [PlannerTask] {
        tasks.filter { $0.parentTaskId == parentId }
            .sorted { $0.date < $1.date }
    }
    
    /// Check if a task is a top-level task (not a sub-task)
    func isTopLevelTask(_ task: PlannerTask) -> Bool {
        task.parentTaskId == nil
    }
    
    /// Get progress for a project (completed / total)
    func projectProgress(_ projectId: UUID) -> (completed: Int, total: Int) {
        let projectTasks = tasksForProject(projectId)
        let completed = projectTasks.filter(\.isCompleted).count
        return (completed, projectTasks.count)
    }
    
    /// Add a sub-task under a parent task
    func addSubTask(title: String, parentId: UUID) {
        guard let parent = tasks.first(where: { $0.id == parentId }) else { return }
        let subTask = PlannerTask(
            title: title,
            date: parent.date,
            durationMinutes: 30,
            colorIndex: parent.colorIndex,
            icon: parent.icon,
            categoryId: parent.categoryId,
            priority: parent.priority,
            parentTaskId: parentId,
            projectId: parent.projectId
        )
        add(subTask)
    }

    // MARK: - Import

    func replaceWithImported(tasks newTasks: [PlannerTask], categories newCategories: [TaskCategory], tags newTags: [TaskTag], dayBounds newBounds: DayBounds?) {
        tasks = newTasks
        categories = newCategories
        tags = newTags
        if let b = newBounds { dayBounds = b }
        save()
    }

    func mergeImported(tasks newTasks: [PlannerTask], categories newCategories: [TaskCategory], tags newTags: [TaskTag]) {
        let existingIds = Set(tasks.map(\.id))
        for t in newTasks where !existingIds.contains(t.id) { tasks.append(t) }
        let existingCatIds = Set(categories.map(\.id))
        for c in newCategories where !existingCatIds.contains(c.id) { categories.append(c) }
        let existingTagIds = Set(tags.map(\.id))
        for tag in newTags where !existingTagIds.contains(tag.id) { tags.append(tag) }
        sortAndSave()
    }

    // MARK: - Shared Navigation Helpers (used by SidebarView & StructuredMainView)

    /// Task count for a given navigation section.
    func taskCount(for section: NavigationSection) -> Int {
        let startOfTomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        switch section {
        case .inbox:
            return tasks.count { $0.isInbox && !$0.isCompleted }
        case .today:
            return tasksForDay(Date()).count { !$0.isCompleted }
        case .scheduled:
            return tasks.count { !$0.isInbox && !$0.isCompleted && $0.date < startOfTomorrow }
        case .futurePlans:
            return tasks.count { !$0.isInbox && !$0.isCompleted && $0.date >= startOfTomorrow }
        case .completed:
            return tasks.count { $0.isCompleted }
        case .all:
            return tasks.count
        case .calendarSection, .mailSection, .messengers, .analytics, .projects, .chat:
            return 0
        }
    }

    /// Move a task to the given navigation section (for drag & drop).
    func moveTask(taskID: UUID, to section: NavigationSection) {
        switch section {
        case .chat, .calendarSection, .mailSection, .messengers, .analytics, .projects:
            return
        default: break
        }
        guard let task = tasks.first(where: { $0.id == taskID }) else { return }
        var updated = task
        switch section {
        case .chat, .calendarSection, .mailSection, .messengers, .analytics, .projects:
            return
        case .inbox:
            updated.isInbox = true
            updated.isCompleted = false
        case .today:
            updated.isInbox = false
            updated.isCompleted = false
            let hour = calendar.component(.hour, from: task.date)
            let minute = calendar.component(.minute, from: task.date)
            updated.date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        case .scheduled:
            updated.isInbox = false
            updated.isCompleted = false
            if calendar.isDateInToday(task.date) || task.date < Date() {
                if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) {
                    updated.date = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
                }
            }
        case .futurePlans:
            updated.isInbox = false
            updated.isCompleted = false
            if let nextWeek = calendar.date(byAdding: .day, value: 7, to: Date()) {
                updated.date = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: nextWeek) ?? nextWeek
            }
        case .completed:
            updated.isCompleted = true
        case .all:
            break
        }
        update(updated)
    }
}
