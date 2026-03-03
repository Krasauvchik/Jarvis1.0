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

// MARK: - Task Suggestion (quick templates like Structured)

struct TaskSuggestion {
    let title: String
    let icon: String
    let durationMinutes: Int
    let colorIndex: Int
    let suggestedHour: Int?
    
    var timeRange: String {
        guard let hour = suggestedHour else { return "\(durationMinutes) min" }
        let endMinutes = hour * 60 + durationMinutes
        let endH = endMinutes / 60
        let endM = endMinutes % 60
        let durText: String
        if durationMinutes >= 60 {
            let h = durationMinutes / 60
            let m = durationMinutes % 60
            durText = m == 0 ? "\(h) hr" : "\(h) hr, \(m) min"
        } else {
            durText = "\(durationMinutes) min"
        }
        return String(format: "%02d:00 – %02d:%02d (%@)", hour, endH, endM, durText)
    }
    
    static let defaults: [TaskSuggestion] = [
        TaskSuggestion(title: "Answer Emails", icon: "envelope.fill", durationMinutes: 15, colorIndex: 0, suggestedHour: 10),
        TaskSuggestion(title: "Go for a Run!", icon: "figure.run", durationMinutes: 60, colorIndex: 3, suggestedHour: 12),
        TaskSuggestion(title: "Go Shopping", icon: "cart.fill", durationMinutes: 60, colorIndex: 4, suggestedHour: 17),
        TaskSuggestion(title: "Watch a Movie", icon: "tv.fill", durationMinutes: 90, colorIndex: 5, suggestedHour: 20),
        TaskSuggestion(title: "Read a Book", icon: "book.fill", durationMinutes: 30, colorIndex: 1, suggestedHour: 21),
        TaskSuggestion(title: "Meditate", icon: "brain.head.profile", durationMinutes: 15, colorIndex: 6, suggestedHour: 7),
    ]
}

// MARK: - Task Category

struct TaskCategory: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var colorIndex: Int
    var icon: String
    var parentID: UUID?
    var sortOrder: Int
    var isArchived: Bool

    init(id: UUID = UUID(), name: String, colorIndex: Int = 0, icon: String = "folder.fill", parentID: UUID? = nil, sortOrder: Int = 0, isArchived: Bool = false) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
        self.icon = icon
        self.parentID = parentID
        self.sortOrder = sortOrder
        self.isArchived = isArchived
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, colorIndex, icon, parentID, sortOrder, isArchived
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        colorIndex = try c.decode(Int.self, forKey: .colorIndex)
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "folder.fill"
        parentID = try c.decodeIfPresent(UUID.self, forKey: .parentID)
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        isArchived = try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }

    var color: Color {
        let count = JarvisTheme.taskColors.count
        guard count > 0 else { return .gray }
        return JarvisTheme.taskColors[((colorIndex % count) + count) % count]
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
    case urgent = "urgent"
    case high = "high"
    case medium = "medium"
    case low = "low"

    var displayName: String {
        switch self {
        case .urgent: return L10n.priorityUrgent
        case .high: return L10n.priorityHigh
        case .medium: return L10n.priorityMedium
        case .low: return L10n.priorityLow
        }
    }

    var icon: String {
        switch self {
        case .urgent: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.circle.fill"
        case .medium: return "circle.fill"
        case .low: return "arrow.down.circle.fill"
        }
    }

    /// Порядок для сортировки: критичный первый (0), высокий (1), средний (2), низкий (3).
    var sortOrder: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }
    
    var color: Color {
        switch self {
        case .urgent: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .green
        }
    }
}

// MARK: - Task Source

enum TaskSource: String, Codable, Hashable, Sendable {
    case manual
    case voice
    case calendar
    case mail
    case siri
    case widget
    case messenger
    case delegated    // задача назначена другим пользователем
    case aiCoach      // создана AI-коучем
}

// MARK: - Task Delegation

/// Модель делегирования задач другим пользователям через мессенджеры.
struct TaskDelegation: Codable, Identifiable, Sendable {
    let id: UUID
    let taskId: UUID
    let assigneeHandle: String     // ник в Telegram/WhatsApp
    let assigneePlatform: String   // "telegram" | "whatsapp"
    let assignedAt: Date
    var status: DelegationStatus
    var responseMessage: String?
    
    enum DelegationStatus: String, Codable, Sendable {
        case pending    // отправлено, ждём подтверждения
        case accepted   // пользователь принял
        case declined   // пользователь отклонил
        case completed  // задача выполнена
    }
    
    init(taskId: UUID, assigneeHandle: String, platform: String) {
        self.id = UUID()
        self.taskId = taskId
        self.assigneeHandle = assigneeHandle
        self.assigneePlatform = platform
        self.assignedAt = Date()
        self.status = .pending
    }
}

// MARK: - Recurrence

struct RecurrenceRule: Codable, Hashable, Sendable {
    var frequency: Frequency
    var interval: Int
    var daysOfWeek: [Int]?
    var endDate: Date?
    var maxOccurrences: Int?
    
    enum Frequency: String, Codable, CaseIterable, Sendable {
        case daily, weekdays, weekends, weekly, monthly, yearly
        
        var displayName: String {
            switch self {
            case .daily: return L10n.recurrenceDaily
            case .weekdays: return L10n.recurrenceWeekdays
            case .weekends: return L10n.recurrenceWeekends
            case .weekly: return L10n.recurrenceWeekly
            case .monthly: return L10n.recurrenceMonthly
            case .yearly: return L10n.recurrenceYearly
            }
        }
    }
    
    var displayName: String {
        if interval <= 1 {
            return frequency.displayName
        }
        switch frequency {
        case .daily: return String(format: L10n.recurrenceEveryDays, interval)
        case .weekly: return String(format: L10n.recurrenceEveryWeeks, interval)
        case .monthly: return String(format: L10n.recurrenceEveryMonths, interval)
        case .yearly: return String(format: L10n.recurrenceEveryYears, interval)
        case .weekdays, .weekends: return frequency.displayName
        }
    }
    
    // Convenience static constructors for backward compatibility
    static let daily = RecurrenceRule(frequency: .daily)
    static let weekdays = RecurrenceRule(frequency: .weekdays)
    static let weekends = RecurrenceRule(frequency: .weekends)
    static let weekly = RecurrenceRule(frequency: .weekly)
    static let monthly = RecurrenceRule(frequency: .monthly)
    static let yearly = RecurrenceRule(frequency: .yearly)
    
    init(frequency: Frequency, interval: Int = 1, daysOfWeek: [Int]? = nil, endDate: Date? = nil, maxOccurrences: Int? = nil) {
        self.frequency = frequency
        self.interval = max(1, interval)
        self.daysOfWeek = daysOfWeek
        self.endDate = endDate
        self.maxOccurrences = maxOccurrences
    }
    
    // MARK: Backward-compatible Codable (decodes old string format "daily" and new struct format)
    
    enum CodingKeys: String, CodingKey {
        case frequency, interval, daysOfWeek, endDate, maxOccurrences
    }
    
    init(from decoder: Decoder) throws {
        // Try plain string first (old enum format: "daily", "weekly", etc.)
        if let singleContainer = try? decoder.singleValueContainer(),
           let string = try? singleContainer.decode(String.self),
           let freq = Frequency(rawValue: string) {
            self.frequency = freq
            self.interval = 1
            self.daysOfWeek = nil
            self.endDate = nil
            self.maxOccurrences = nil
            return
        }
        // New struct format
        let c = try decoder.container(keyedBy: CodingKeys.self)
        frequency = try c.decode(Frequency.self, forKey: .frequency)
        interval = try c.decodeIfPresent(Int.self, forKey: .interval) ?? 1
        daysOfWeek = try c.decodeIfPresent([Int].self, forKey: .daysOfWeek)
        endDate = try c.decodeIfPresent(Date.self, forKey: .endDate)
        maxOccurrences = try c.decodeIfPresent(Int.self, forKey: .maxOccurrences)
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(frequency, forKey: .frequency)
        if interval != 1 { try c.encode(interval, forKey: .interval) }
        try c.encodeIfPresent(daysOfWeek, forKey: .daysOfWeek)
        try c.encodeIfPresent(endDate, forKey: .endDate)
        try c.encodeIfPresent(maxOccurrences, forKey: .maxOccurrences)
    }
}

// MARK: - Task Reminder

struct TaskReminder: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var offsetMinutes: Int  // negative = before task start (e.g. -15 = 15 min before)
    var isEnabled: Bool
    
    init(id: UUID = UUID(), offsetMinutes: Int = -15, isEnabled: Bool = true) {
        self.id = id
        self.offsetMinutes = offsetMinutes
        self.isEnabled = isEnabled
    }
    
    var displayName: String {
        let abs = abs(offsetMinutes)
        if abs == 0 { return L10n.reminderAtStart }
        if abs < 60 { return String(format: L10n.reminderMinBefore, abs) }
        if abs == 60 { return L10n.reminderHourBefore }
        if abs < 1440 { return String(format: L10n.reminderHoursBefore, abs / 60) }
        return String(format: L10n.reminderDaysBefore, abs / 1440)
    }
    
    /// Common reminder presets
    static let atStart = TaskReminder(offsetMinutes: 0)
    static let fiveMinBefore = TaskReminder(offsetMinutes: -5)
    static let fifteenMinBefore = TaskReminder(offsetMinutes: -15)
    static let thirtyMinBefore = TaskReminder(offsetMinutes: -30)
    static let oneHourBefore = TaskReminder(offsetMinutes: -60)
    static let oneDayBefore = TaskReminder(offsetMinutes: -1440)
}

// MARK: - Task Attachments

struct TaskAttachment: Identifiable, Codable, Hashable, Sendable {
    enum AttachmentType: String, Codable, CaseIterable, Hashable, Sendable {
        case image
        case file
    }

    let id: UUID
    var type: AttachmentType
    var fileName: String
    /// Absolute file path in the app container (Documents/TaskAttachments/...)
    var filePath: String
    var fileSize: Int64?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        type: AttachmentType,
        fileName: String,
        filePath: String,
        fileSize: Int64? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.fileName = fileName
        self.filePath = filePath
        self.fileSize = fileSize
        self.createdAt = createdAt
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
    /// Timestamp when task was created
    var createdAt: Date
    /// Timestamp of last modification
    var modifiedAt: Date
    /// Timestamp when task was completed (nil if not completed)
    var completedAt: Date?
    /// How the task was created
    var source: TaskSource
    /// Multiple reminders per task (replaces simple hasAlarm)
    var reminders: [TaskReminder]
    /// Attached files or images for this task
    var attachments: [TaskAttachment]

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
        projectId: UUID? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        completedAt: Date? = nil,
        source: TaskSource = .manual,
        reminders: [TaskReminder] = [],
        attachments: [TaskAttachment] = []
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
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.completedAt = completedAt
        self.source = source
        self.reminders = reminders
        self.attachments = attachments
    }

    enum CodingKeys: String, CodingKey {
        case id, title, notes, date, durationMinutes, isAllDay, recurrenceRule, isCompleted, hasAlarm, isInbox, completedRecurrenceDates, colorIndex, icon, categoryId, tagIds, calendarEventId, priority, parentTaskId, projectId, createdAt, modifiedAt, completedAt, source, reminders, attachments
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
        // New fields — backward compatible with default values
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? (try c.decode(Date.self, forKey: .date))
        modifiedAt = try c.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? Date()
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        source = try c.decodeIfPresent(TaskSource.self, forKey: .source) ?? .manual
        reminders = try c.decodeIfPresent([TaskReminder].self, forKey: .reminders) ?? []
        attachments = try c.decodeIfPresent([TaskAttachment].self, forKey: .attachments) ?? []
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
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(modifiedAt, forKey: .modifiedAt)
        try c.encodeIfPresent(completedAt, forKey: .completedAt)
        try c.encode(source, forKey: .source)
        try c.encode(reminders, forKey: .reminders)
        try c.encode(attachments, forKey: .attachments)
    }

    var endDate: Date {
        isAllDay ? date : date.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }
    
    var taskColor: Color {
        let count = JarvisTheme.taskColors.count
        guard count > 0 else { return .gray }
        return JarvisTheme.taskColors[((colorIndex % count) + count) % count]
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
    
    @Published var tasks: [PlannerTask] = [] {
        didSet { invalidateCaches() }
    }
    @Published var dayBounds: DayBounds = .default
    @Published var categories: [TaskCategory] = []
    @Published var tags: [TaskTag] = []
    @Published var projects: [Project] = []

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
        
        // Save categories, tags, projects to SwiftData
        for category in categories { DataPersistence.shared.saveCategory(category) }
        for tag in tags { DataPersistence.shared.saveTag(tag) }
        for project in projects { DataPersistence.shared.saveProject(project) }
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
    
    var scheduledTasks: [PlannerTask] {
        tasks.lazy.filter { !$0.isInbox }.sorted { ($0.priority.sortOrder, $0.date) < ($1.priority.sortOrder, $1.date) }
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

    /// Task count for a given navigation section (cached per invalidation cycle).
    func taskCount(for section: NavigationSection) -> Int {
        if let cached = sectionCountCache[section] { return cached }
        let startOfTomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        let count: Int
        switch section {
        case .inbox:
            count = tasks.count { $0.isInbox && !$0.isCompleted }
        case .today:
            count = tasksForDay(Date()).count { !$0.isCompleted }
        case .scheduled:
            count = tasks.count { !$0.isInbox && !$0.isCompleted && $0.date < startOfTomorrow }
        case .futurePlans:
            count = tasks.count { !$0.isInbox && !$0.isCompleted && $0.date >= startOfTomorrow }
        case .completed:
            count = cachedCompletedTasks.count
        case .all:
            count = tasks.count
        case .calendarSection, .mailSection, .messengers, .analytics, .projects, .chat, .health:
            count = 0
        }
        sectionCountCache[section] = count
        return count
    }

    /// Move a task to the given navigation section (for drag & drop).
    func moveTask(taskID: UUID, to section: NavigationSection) {
        switch section {
        case .chat, .calendarSection, .mailSection, .messengers, .analytics, .projects, .health:
            return
        default: break
        }
        guard let task = tasks.first(where: { $0.id == taskID }) else { return }
        var updated = task
        switch section {
        case .chat, .calendarSection, .mailSection, .messengers, .analytics, .projects, .health:
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
