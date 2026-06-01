import Foundation
import Combine
import SwiftUI

// MARK: - Store with iCloud Sync

@MainActor
final class PlannerStore: ObservableObject {
    static let shared = PlannerStore()
    
    @Published var tasks: [PlannerTask] = [] {
        didSet { invalidateCaches() }
    }
    @Published var dayBounds: DayBounds = .default
    @Published var categories: [TaskCategory] = []
    @Published var tags: [TaskTag] = []
    @Published var projects: [Project] = []
    @Published var templates: [TaskTemplate] = TaskTemplate.builtIn

    // MARK: - Cached Computations
    
    /// Кэш inbox-задач — пересчитывается только при изменении tasks
    private(set) var cachedInboxTasks: [PlannerTask] = []
    /// Кэш выполненных задач
    private(set) var cachedCompletedTasks: [PlannerTask] = []
    /// Кэш задач по дню (ключ: startOfDay)
    private var tasksByDayCache: [Date: [PlannerTask]] = [:]
    /// Кэш timeline-задач по дню
    private var timelineByDayCache: [Date: [PlannerTask]] = [:]
    /// Кэш allDay-задач по дню
    private var allDayByDayCache: [Date: [PlannerTask]] = [:]
    /// Кэш количества задач по секции (для sidebar badges)
    private var sectionCountCache: [NavigationSection: Int] = [:]

    private let calendar = Calendar.current
    private var syncObserver: NSObjectProtocol?
    private var saveTask: Task<Void, Never>?
    private var cloudSaveTask: Task<Void, Never>?
    private let appGroupDefaults = UserDefaults(suiteName: Config.appGroupSuite)
    
    /// Сбрасывает все кэши — вызывается при любом изменении tasks
    private func invalidateCaches() {
        cachedInboxTasks = tasks.lazy.filter(\.isInbox).sorted { ($0.priority.sortOrder, $0.date) < ($1.priority.sortOrder, $1.date) }
        cachedCompletedTasks = tasks.filter(\.isCompleted).sorted { $0.date > $1.date }
        cachedScheduledTasks = tasks.lazy.filter { !$0.isInbox }.sorted { ($0.priority.sortOrder, $0.date) < ($1.priority.sortOrder, $1.date) }
        tasksByDayCache.removeAll(keepingCapacity: true)
        timelineByDayCache.removeAll(keepingCapacity: true)
        allDayByDayCache.removeAll(keepingCapacity: true)
        sectionCountCache.removeAll(keepingCapacity: true)
    }
    
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
    /// Local persist is fast (0.3s debounce), cloud sync is slower (2s debounce) to avoid iCloud throttling.
    private func save() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            // 0.3s debounce for rapid successive changes
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, let self else { return }
            self.persistLocal()
        }
        
        // Cloud sync with longer debounce to avoid hammering iCloud KV store
        cloudSaveTask?.cancel()
        cloudSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s debounce
            guard !Task.isCancelled, let self else { return }
            self.persistCloud()
        }
    }
    
    /// Local-only write — SwiftData (primary) + UserDefaults/AppGroup (widget fallback). Called on debounce or background.
    private func persistLocal() {
        // Write to SwiftData (primary persistence)
        DataPersistence.shared.saveTasks(tasks)
        
        // Widget snapshot via AppGroup (still needed for widget extension)
        if let widgetData = try? encoder.encode(
            tasks.prefix(20).map { WidgetTaskSnapshot(id: $0.id, title: $0.title, date: $0.date, isCompleted: $0.isCompleted, isAllDay: $0.isAllDay, colorIndex: $0.colorIndex) }
        ) {
            appGroupDefaults?.set(widgetData, forKey: "jarvis_widget_tasks")
        }
        
        // Batch save categories, tags, projects to SwiftData (single call each instead of N loops)
        DataPersistence.shared.saveCategories(categories)
        DataPersistence.shared.saveTags(tags)
        DataPersistence.shared.saveProjects(projects)
    }
    
    /// Cloud write — SwiftData handles CloudKit sync automatically.
    /// Legacy iCloud KV store still updated for backward compatibility with older app versions.
    private func persistCloud() {
        // SwiftData+CloudKit sync is automatic; this is legacy fallback only
        CloudSync.shared.saveTasks(tasks)
        CloudSync.shared.saveCategories(categories)
        CloudSync.shared.saveTags(tags)
    }
    
    /// Immediate full write — call only when you need guaranteed persistence (e.g. app backgrounding).
    func persistNow() {
        persistLocal()
        persistCloud()
    }
    
    private func load() {
        // Try SwiftData first (primary source after migration)
        let sdTasks = DataPersistence.shared.loadTasks()
        if !sdTasks.isEmpty {
            tasks = sdTasks
        } else if let cloudTasks = CloudSync.shared.loadTasks() {
            tasks = cloudTasks
        } else if let data = UserDefaults.standard.data(forKey: Config.Storage.tasksKey),
                  let decoded = try? decoder.decode([PlannerTask].self, from: data) {
            tasks = decoded
        }
        
        if let cloudBounds = CloudSync.shared.loadDayBounds() {
            dayBounds = cloudBounds
        }
        
        let sdCategories = DataPersistence.shared.loadCategories()
        if !sdCategories.isEmpty {
            categories = sdCategories
        } else if let cloudCategories = CloudSync.shared.loadCategories() {
            categories = cloudCategories
        } else if let data = UserDefaults.standard.data(forKey: Config.Storage.categoriesKey),
                  let decoded = try? decoder.decode([TaskCategory].self, from: data) {
            categories = decoded
        }
        
        let sdTags = DataPersistence.shared.loadTags()
        if !sdTags.isEmpty {
            tags = sdTags
        } else if let cloudTags = CloudSync.shared.loadTags() {
            tags = cloudTags
        } else if let data = UserDefaults.standard.data(forKey: Config.Storage.tagsKey),
                  let decoded = try? decoder.decode([TaskTag].self, from: data) {
            tags = decoded
        }
        
        // Load projects
        let sdProjects = DataPersistence.shared.loadProjects()
        if !sdProjects.isEmpty {
            projects = sdProjects
        } else if let data = UserDefaults.standard.data(forKey: Config.Storage.projectsKey),
           let decoded = try? decoder.decode([Project].self, from: data) {
            projects = decoded
        }
    }

    // MARK: - Computed Properties (backed by cache)
    
    var inboxTasks: [PlannerTask] {
        cachedInboxTasks
    }
    
    private(set) var cachedScheduledTasks: [PlannerTask] = []
    var scheduledTasks: [PlannerTask] {
        cachedScheduledTasks
    }

    var completedTasks: [PlannerTask] {
        cachedCompletedTasks
    }

    // MARK: - Task Queries (with per-day caching)
    
    func timelineTasks(for day: Date) -> [PlannerTask] {
        let dayStart = calendar.startOfDay(for: day)
        if let cached = timelineByDayCache[dayStart] { return cached }
        let result = tasks.compactMap { task -> PlannerTask? in
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
        timelineByDayCache[dayStart] = result
        return result
    }
    
    func allDayTasks(for day: Date) -> [PlannerTask] {
        let dayStart = calendar.startOfDay(for: day)
        if let cached = allDayByDayCache[dayStart] { return cached }
        let result = tasks.compactMap { task -> PlannerTask? in
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
        allDayByDayCache[dayStart] = result
        return result
    }
    
    func tasksForDay(_ day: Date) -> [PlannerTask] {
        let dayStart = calendar.startOfDay(for: day)
        if let cached = tasksByDayCache[dayStart] { return cached }
        let result = allDayTasks(for: day) + timelineTasks(for: day)
        tasksByDayCache[dayStart] = result
        return result
    }
    
    private func recurrenceMatches(day: Date, task: PlannerTask, rule: RecurrenceRule) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        let taskDayStart = calendar.startOfDay(for: task.date)
        guard dayStart >= taskDayStart else { return false }
        
        // Check end date
        if let endDate = rule.endDate, dayStart > calendar.startOfDay(for: endDate) { return false }
        
        let weekday = calendar.component(.weekday, from: day)
        let dayOfMonth = calendar.component(.day, from: day)
        
        // Check custom daysOfWeek for weekly rules
        if rule.frequency == .weekly, let days = rule.daysOfWeek, !days.isEmpty {
            return days.contains(weekday)
        }
        
        // Check interval (every N occurrences)
        let interval = rule.interval
        
        switch rule.frequency {
        case .daily:
            if interval <= 1 { return true }
            let daysBetween = calendar.dateComponents([.day], from: taskDayStart, to: dayStart).day ?? 0
            return daysBetween % interval == 0
        case .weekdays: return (2...6).contains(weekday)
        case .weekends: return weekday == 1 || weekday == 7
        case .weekly:
            if interval <= 1 { return weekday == calendar.component(.weekday, from: task.date) }
            let weeksBetween = calendar.dateComponents([.weekOfYear], from: taskDayStart, to: dayStart).weekOfYear ?? 0
            return weeksBetween % interval == 0 && weekday == calendar.component(.weekday, from: task.date)
        case .monthly:
            if interval <= 1 { return dayOfMonth == calendar.component(.day, from: task.date) }
            let monthsBetween = calendar.dateComponents([.month], from: taskDayStart, to: dayStart).month ?? 0
            return monthsBetween % interval == 0 && dayOfMonth == calendar.component(.day, from: task.date)
        case .yearly:
            if interval <= 1 {
                return calendar.component(.month, from: day) == calendar.component(.month, from: task.date) && dayOfMonth == calendar.component(.day, from: task.date)
            }
            let yearsBetween = calendar.dateComponents([.year], from: taskDayStart, to: dayStart).year ?? 0
            return yearsBetween % interval == 0 && calendar.component(.month, from: day) == calendar.component(.month, from: task.date) && dayOfMonth == calendar.component(.day, from: task.date)
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
        var updated = task
        updated.modifiedAt = Date()
        tasks[idx] = updated
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
            tasks[idx].completedAt = tasks[idx].isCompleted ? Date() : nil
        }
        tasks[idx].modifiedAt = Date()
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
        guard !ids.isEmpty else { return [] }
        let tagDict = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0) })
        return ids.compactMap { tagDict[$0] }
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

    /// Task count for a given navigation section (cached per invalidation cycle).
    func taskCount(for section: NavigationSection) -> Int {
        if let cached = sectionCountCache[section] { return cached }
        let startOfTomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        let count: Int
        switch section {
        case .inbox:
            count = cachedInboxTasks.count { !$0.isCompleted }
        case .today:
            count = tasksForDay(Date()).count { !$0.isCompleted }
        case .scheduled:
            count = cachedScheduledTasks.count { !$0.isCompleted && $0.date < startOfTomorrow }
        case .futurePlans:
            count = cachedScheduledTasks.count { !$0.isCompleted && $0.date >= startOfTomorrow }
        case .completed:
            count = cachedCompletedTasks.count
        case .all:
            count = tasks.count
        case .calendarSection, .mailSection, .messengers, .analytics, .projects, .chat, .health, .kanban, .templates, .habits, .focus, .systemCalendar, .registries:
            count = 0
        }
        sectionCountCache[section] = count
        return count
    }

    /// Move a task to the given navigation section (for drag & drop).
    func moveTask(taskID: UUID, to section: NavigationSection) {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return }
        var updated = task
        switch section {
        case .chat, .calendarSection, .mailSection, .messengers, .analytics, .projects, .health, .kanban, .templates, .habits, .focus, .systemCalendar, .registries:
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
