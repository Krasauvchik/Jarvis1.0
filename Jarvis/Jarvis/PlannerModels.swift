import Foundation
import Combine
import SwiftUI
import UserNotifications

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
    case pyrus        // импортирована из Pyrus
}

// MARK: - Approval Workflow

/// Status of task approval (Pyrus-like workflow).
enum ApprovalStatus: String, Codable, Hashable, CaseIterable, Sendable {
    case none           // no approval required
    case pending        // awaiting approval
    case approved       // approved by reviewer
    case rejected       // rejected — needs rework
    case revisionNeeded // sent back for revision

    var displayName: String {
        switch self {
        case .none: return L10n.approvalNone
        case .pending: return L10n.approvalPending
        case .approved: return L10n.approvalApproved
        case .rejected: return L10n.approvalRejected
        case .revisionNeeded: return L10n.approvalRevision
        }
    }

    var icon: String {
        switch self {
        case .none: return "minus.circle"
        case .pending: return "clock.badge.questionmark"
        case .approved: return "checkmark.seal.fill"
        case .rejected: return "xmark.seal.fill"
        case .revisionNeeded: return "arrow.uturn.backward.circle"
        }
    }

    var color: Color {
        switch self {
        case .none: return .secondary
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .red
        case .revisionNeeded: return .yellow
        }
    }
}

/// A single approval step in the workflow chain.
struct ApprovalStep: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var reviewerName: String        // display name or handle
    var reviewerHandle: String?     // telegram/email handle
    var status: ApprovalStatus
    var comment: String
    var decidedAt: Date?

    init(
        id: UUID = UUID(),
        reviewerName: String,
        reviewerHandle: String? = nil,
        status: ApprovalStatus = .pending,
        comment: String = "",
        decidedAt: Date? = nil
    ) {
        self.id = id
        self.reviewerName = reviewerName
        self.reviewerHandle = reviewerHandle
        self.status = status
        self.comment = comment
        self.decidedAt = decidedAt
    }
}

// MARK: - Registry (Catalog)

/// A configurable registry/catalog (like Pyrus catalogs).
/// Stores tabular data with custom columns — client lists, inventory, contacts, etc.
struct Registry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var icon: String
    var columns: [RegistryColumn]
    var rows: [RegistryRow]
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "tablecells",
        columns: [RegistryColumn] = [],
        rows: [RegistryRow] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.columns = columns
        self.rows = rows
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

/// Column definition for a registry.
struct RegistryColumn: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var type: ColumnType

    enum ColumnType: String, Codable, Hashable, Sendable, CaseIterable {
        case text
        case number
        case date
        case checkbox
        case singleChoice  // dropdown

        var displayName: String {
            switch self {
            case .text: return L10n.registryColumnText
            case .number: return L10n.registryColumnNumber
            case .date: return L10n.registryColumnDate
            case .checkbox: return L10n.registryColumnCheckbox
            case .singleChoice: return L10n.registryColumnChoice
            }
        }
    }

    /// Options for singleChoice columns.
    var options: [String]

    init(id: UUID = UUID(), name: String, type: ColumnType = .text, options: [String] = []) {
        self.id = id
        self.name = name
        self.type = type
        self.options = options
    }
}

/// A single row in a registry.
struct RegistryRow: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    /// Column ID → cell value (always stored as String for simplicity).
    var cells: [String: String]
    var createdAt: Date

    init(id: UUID = UUID(), cells: [String: String] = [:], createdAt: Date = Date()) {
        self.id = id
        self.cells = cells
        self.createdAt = createdAt
    }
}

// MARK: - Custom Notification Sound

/// Available notification sounds.
enum NotificationSoundChoice: String, Codable, CaseIterable, Sendable {
    case `default` = "default"
    case chime      = "chime"
    case bell       = "bell"
    case gentle     = "gentle"
    case urgent     = "urgent"
    case none       = "none"

    var displayName: String {
        switch self {
        case .default: return L10n.soundDefault
        case .chime:   return L10n.soundChime
        case .bell:    return L10n.soundBell
        case .gentle:  return L10n.soundGentle
        case .urgent:  return L10n.soundUrgent
        case .none:    return L10n.soundNone
        }
    }

    /// UNNotificationSound for this choice.
    var notificationSound: UNNotificationSound? {
        switch self {
        case .default: return .default
        case .chime:   return UNNotificationSound(named: UNNotificationSoundName("chime.caf"))
        case .bell:    return UNNotificationSound(named: UNNotificationSoundName("bell.caf"))
        case .gentle:  return UNNotificationSound(named: UNNotificationSoundName("gentle.caf"))
        case .urgent:  return UNNotificationSound.defaultCritical
        case .none:    return nil
        }
    }
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

// MARK: - Task Comment (activity log / discussion thread)

struct TaskComment: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var text: String
    var authorName: String
    var createdAt: Date
    /// Optional: time spent on this activity (minutes)
    var spentMinutes: Int?
    
    init(id: UUID = UUID(), text: String, authorName: String = "Me", createdAt: Date = Date(), spentMinutes: Int? = nil) {
        self.id = id
        self.text = text
        self.authorName = authorName
        self.createdAt = createdAt
        self.spentMinutes = spentMinutes
    }
}

// MARK: - Task Template (reusable task blueprints)

struct TaskTemplate: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var title: String
    var notes: String
    var durationMinutes: Int
    var priority: TaskPriority
    var colorIndex: Int
    var icon: String
    var categoryId: UUID?
    var subtaskTitles: [String]
    
    init(
        id: UUID = UUID(),
        name: String,
        title: String = "",
        notes: String = "",
        durationMinutes: Int = 60,
        priority: TaskPriority = .medium,
        colorIndex: Int = 4,
        icon: String = "doc.text.fill",
        categoryId: UUID? = nil,
        subtaskTitles: [String] = []
    ) {
        self.id = id
        self.name = name
        self.title = title
        self.notes = notes
        self.durationMinutes = durationMinutes
        self.priority = priority
        self.colorIndex = colorIndex
        self.icon = icon
        self.categoryId = categoryId
        self.subtaskTitles = subtaskTitles
    }
    
    /// Create a PlannerTask from this template (with optional subtasks)
    func instantiate(date: Date = Date(), isInbox: Bool = false) -> (PlannerTask, [PlannerTask]) {
        let parentId = UUID()
        let parent = PlannerTask(
            id: parentId,
            title: title.isEmpty ? name : title,
            notes: notes,
            date: date,
            durationMinutes: durationMinutes,
            isInbox: isInbox,
            colorIndex: colorIndex,
            icon: icon,
            categoryId: categoryId,
            priority: priority
        )
        let subs = subtaskTitles.map { subTitle in
            PlannerTask(
                title: subTitle,
                date: date,
                durationMinutes: 15,
                isInbox: isInbox,
                colorIndex: colorIndex,
                icon: "circle",
                categoryId: categoryId,
                priority: priority,
                parentTaskId: parentId
            )
        }
        return (parent, subs)
    }
    
    /// Built-in templates
    static let builtIn: [TaskTemplate] = [
        TaskTemplate(name: "Weekly Report", title: "Weekly Report", durationMinutes: 60, icon: "doc.text.fill", subtaskTitles: ["Gather data", "Write summary", "Send to team"]),
        TaskTemplate(name: "Meeting Prep", title: "Prepare for Meeting", durationMinutes: 30, priority: .high, icon: "person.3.fill", subtaskTitles: ["Review agenda", "Prepare notes", "Check calendar"]),
        TaskTemplate(name: "Morning Routine", title: "Morning Routine", durationMinutes: 45, icon: "sun.max.fill", subtaskTitles: ["Exercise", "Shower", "Breakfast", "Review day plan"]),
    ]
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
    /// Activity log / comments thread for this task
    var comments: [TaskComment]
    /// Total time spent on this task (minutes)
    var spentMinutes: Int
    /// External system ID (e.g. Pyrus task ID) for sync
    var externalId: String?
    /// Approval workflow steps
    var approvalSteps: [ApprovalStep]
    /// Overall approval status (derived from steps)
    var approvalStatus: ApprovalStatus

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
        attachments: [TaskAttachment] = [],
        comments: [TaskComment] = [],
        spentMinutes: Int = 0,
        externalId: String? = nil,
        approvalSteps: [ApprovalStep] = [],
        approvalStatus: ApprovalStatus = .none
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
        self.comments = comments
        self.spentMinutes = spentMinutes
        self.externalId = externalId
        self.approvalSteps = approvalSteps
        self.approvalStatus = approvalStatus
    }

    enum CodingKeys: String, CodingKey {
        case id, title, notes, date, durationMinutes, isAllDay, recurrenceRule, isCompleted, hasAlarm, isInbox, completedRecurrenceDates, colorIndex, icon, categoryId, tagIds, calendarEventId, priority, parentTaskId, projectId, createdAt, modifiedAt, completedAt, source, reminders, attachments, comments, spentMinutes, externalId, approvalSteps, approvalStatus
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        notes = try c.decode(String.self, forKey: .notes)
        date = try c.decode(Date.self, forKey: .date)
        durationMinutes = try c.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 30
        isAllDay = try c.decodeIfPresent(Bool.self, forKey: .isAllDay) ?? false
        recurrenceRule = try c.decodeIfPresent(RecurrenceRule.self, forKey: .recurrenceRule)
        isCompleted = try c.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        hasAlarm = try c.decodeIfPresent(Bool.self, forKey: .hasAlarm) ?? false
        isInbox = try c.decodeIfPresent(Bool.self, forKey: .isInbox) ?? false
        completedRecurrenceDates = try c.decodeIfPresent([Date].self, forKey: .completedRecurrenceDates) ?? []
        colorIndex = try c.decodeIfPresent(Int.self, forKey: .colorIndex) ?? 0
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
        comments = try c.decodeIfPresent([TaskComment].self, forKey: .comments) ?? []
        spentMinutes = try c.decodeIfPresent(Int.self, forKey: .spentMinutes) ?? 0
        externalId = try c.decodeIfPresent(String.self, forKey: .externalId)
        approvalSteps = try c.decodeIfPresent([ApprovalStep].self, forKey: .approvalSteps) ?? []
        approvalStatus = try c.decodeIfPresent(ApprovalStatus.self, forKey: .approvalStatus) ?? .none
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
        try c.encode(comments, forKey: .comments)
        if spentMinutes != 0 { try c.encode(spentMinutes, forKey: .spentMinutes) }
        try c.encodeIfPresent(externalId, forKey: .externalId)
        if !approvalSteps.isEmpty { try c.encode(approvalSteps, forKey: .approvalSteps) }
        if approvalStatus != .none { try c.encode(approvalStatus, forKey: .approvalStatus) }
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

