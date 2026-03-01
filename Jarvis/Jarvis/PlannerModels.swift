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
        calendarEventId: String? = nil
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
    }

    enum CodingKeys: String, CodingKey {
        case id, title, notes, date, durationMinutes, isAllDay, recurrenceRule, isCompleted, hasAlarm, isInbox, completedRecurrenceDates, colorIndex, icon, categoryId, tagIds, calendarEventId
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

// MARK: - Store with iCloud Sync

@MainActor
final class PlannerStore: ObservableObject {
    static let shared = PlannerStore()
    
    @Published var tasks: [PlannerTask] = []
    @Published var dayBounds: DayBounds = .default
    @Published var categories: [TaskCategory] = []
    @Published var tags: [TaskTag] = []

    private let calendar = Calendar.current
    private var syncObserver: NSObjectProtocol?
    
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
            Task { @MainActor in
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
    
    private func save() {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: Config.Storage.tasksKey)
            UserDefaults(suiteName: Config.appGroupSuite)?.set(data, forKey: Config.Storage.tasksKey)
        }
        let widgetSnapshots = tasks.map { WidgetTaskSnapshot(id: $0.id, title: $0.title, date: $0.date, isCompleted: $0.isCompleted, isAllDay: $0.isAllDay, colorIndex: $0.colorIndex) }
        if let widgetData = try? JSONEncoder().encode(widgetSnapshots) {
            UserDefaults(suiteName: Config.appGroupSuite)?.set(widgetData, forKey: "jarvis_widget_tasks")
        }
        if let catData = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(catData, forKey: Config.Storage.categoriesKey)
        }
        if let tagData = try? JSONEncoder().encode(tags) {
            UserDefaults.standard.set(tagData, forKey: Config.Storage.tagsKey)
        }
        CloudSync.shared.saveTasks(tasks)
        CloudSync.shared.saveCategories(categories)
        CloudSync.shared.saveTags(tags)
        if let lastTask = tasks.last {
            CloudSync.shared.queueForSync(lastTask)
        }
    }
    
    private func load() {
        if let cloudTasks = CloudSync.shared.loadTasks() {
            tasks = cloudTasks
        } else if let data = UserDefaults.standard.data(forKey: Config.Storage.tasksKey),
                  let decoded = try? JSONDecoder().decode([PlannerTask].self, from: data) {
            tasks = decoded
        }
        if let cloudBounds = CloudSync.shared.loadDayBounds() {
            dayBounds = cloudBounds
        }
        if let cloudCategories = CloudSync.shared.loadCategories() {
            categories = cloudCategories
        } else if let data = UserDefaults.standard.data(forKey: Config.Storage.categoriesKey),
                  let decoded = try? JSONDecoder().decode([TaskCategory].self, from: data) {
            categories = decoded
        }
        if let cloudTags = CloudSync.shared.loadTags() {
            tags = cloudTags
        } else if let data = UserDefaults.standard.data(forKey: Config.Storage.tagsKey),
                  let decoded = try? JSONDecoder().decode([TaskTag].self, from: data) {
            tags = decoded
        }
    }

    // MARK: - Computed Properties
    
    var inboxTasks: [PlannerTask] {
        tasks.lazy.filter(\.isInbox).sorted { $0.date < $1.date }
    }
    
    var scheduledTasks: [PlannerTask] {
        tasks.lazy.filter { !$0.isInbox }.sorted { $0.date < $1.date }
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
        }.sorted { $0.date < $1.date }
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
        }.sorted { $0.date < $1.date }
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
    
    func remove(task: PlannerTask) {
        tasks.removeAll { $0.id == task.id }
        save()
    }
    
    func delete(_ task: PlannerTask) {
        remove(task: task)
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
}
