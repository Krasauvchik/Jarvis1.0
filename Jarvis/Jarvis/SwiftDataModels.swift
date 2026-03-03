import Foundation
import SwiftData

// MARK: - SwiftData Persistence Layer
// @Model classes that mirror the Codable structs for SwiftData + CloudKit persistence.
// PlannerStore converts between structs ↔ @Model objects to keep the view layer unchanged.

@Model
final class TaskEntity {
    @Attribute(.unique) var taskID: UUID
    var title: String
    var notes: String
    var date: Date
    var durationMinutes: Int
    var isAllDay: Bool
    // RecurrenceRule stored as JSON
    var recurrenceRuleData: Data?
    var isCompleted: Bool
    var hasAlarm: Bool
    var isInbox: Bool
    var completedRecurrenceDatesData: Data?
    var colorIndex: Int
    var icon: String
    var categoryId: UUID?
    var tagIdsData: Data?
    var calendarEventId: String?
    var priorityRaw: String
    var parentTaskId: UUID?
    var projectId: UUID?
    var createdAt: Date
    var modifiedAt: Date
    var completedAt: Date?
    var sourceRaw: String
    var remindersData: Data?
    
    init(from task: PlannerTask) {
        self.taskID = task.id
        self.title = task.title
        self.notes = task.notes
        self.date = task.date
        self.durationMinutes = task.durationMinutes
        self.isAllDay = task.isAllDay
        self.recurrenceRuleData = try? JSONEncoder().encode(task.recurrenceRule)
        self.isCompleted = task.isCompleted
        self.hasAlarm = task.hasAlarm
        self.isInbox = task.isInbox
        self.completedRecurrenceDatesData = try? JSONEncoder().encode(task.completedRecurrenceDates)
        self.colorIndex = task.colorIndex
        self.icon = task.icon
        self.categoryId = task.categoryId
        self.tagIdsData = try? JSONEncoder().encode(task.tagIds)
        self.calendarEventId = task.calendarEventId
        self.priorityRaw = task.priority.rawValue
        self.parentTaskId = task.parentTaskId
        self.projectId = task.projectId
        self.createdAt = task.createdAt
        self.modifiedAt = task.modifiedAt
        self.completedAt = task.completedAt
        self.sourceRaw = task.source.rawValue
        self.remindersData = try? JSONEncoder().encode(task.reminders)
    }
    
    func toStruct() -> PlannerTask {
        let decoder = JSONDecoder()
        let recurrenceRule = recurrenceRuleData.flatMap { try? decoder.decode(RecurrenceRule.self, from: $0) }
        let completedDates = (completedRecurrenceDatesData.flatMap { try? decoder.decode([Date].self, from: $0) }) ?? []
        let tagIds = (tagIdsData.flatMap { try? decoder.decode([UUID].self, from: $0) }) ?? []
        let reminders = (remindersData.flatMap { try? decoder.decode([TaskReminder].self, from: $0) }) ?? []
        
        return PlannerTask(
            id: taskID,
            title: title,
            notes: notes,
            date: date,
            durationMinutes: durationMinutes,
            isAllDay: isAllDay,
            recurrenceRule: recurrenceRule,
            isCompleted: isCompleted,
            hasAlarm: hasAlarm,
            isInbox: isInbox,
            completedRecurrenceDates: completedDates,
            colorIndex: colorIndex,
            icon: icon,
            categoryId: categoryId,
            tagIds: tagIds,
            calendarEventId: calendarEventId,
            priority: TaskPriority(rawValue: priorityRaw) ?? .medium,
            parentTaskId: parentTaskId,
            projectId: projectId,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            completedAt: completedAt,
            source: TaskSource(rawValue: sourceRaw) ?? .manual,
            reminders: reminders
        )
    }
    
    func update(from task: PlannerTask) {
        self.title = task.title
        self.notes = task.notes
        self.date = task.date
        self.durationMinutes = task.durationMinutes
        self.isAllDay = task.isAllDay
        self.recurrenceRuleData = try? JSONEncoder().encode(task.recurrenceRule)
        self.isCompleted = task.isCompleted
        self.hasAlarm = task.hasAlarm
        self.isInbox = task.isInbox
        self.completedRecurrenceDatesData = try? JSONEncoder().encode(task.completedRecurrenceDates)
        self.colorIndex = task.colorIndex
        self.icon = task.icon
        self.categoryId = task.categoryId
        self.tagIdsData = try? JSONEncoder().encode(task.tagIds)
        self.calendarEventId = task.calendarEventId
        self.priorityRaw = task.priority.rawValue
        self.parentTaskId = task.parentTaskId
        self.projectId = task.projectId
        self.createdAt = task.createdAt
        self.modifiedAt = task.modifiedAt
        self.completedAt = task.completedAt
        self.sourceRaw = task.source.rawValue
        self.remindersData = try? JSONEncoder().encode(task.reminders)
    }
}

@Model
final class CategoryEntity {
    @Attribute(.unique) var categoryID: UUID
    var name: String
    var colorIndex: Int
    var icon: String
    var parentID: UUID?
    var sortOrder: Int
    var isArchived: Bool
    
    init(from category: TaskCategory) {
        self.categoryID = category.id
        self.name = category.name
        self.colorIndex = category.colorIndex
        self.icon = category.icon
        self.parentID = category.parentID
        self.sortOrder = category.sortOrder
        self.isArchived = category.isArchived
    }
    
    func toStruct() -> TaskCategory {
        TaskCategory(
            id: categoryID,
            name: name,
            colorIndex: colorIndex,
            icon: icon,
            parentID: parentID,
            sortOrder: sortOrder,
            isArchived: isArchived
        )
    }
    
    func update(from category: TaskCategory) {
        self.name = category.name
        self.colorIndex = category.colorIndex
        self.icon = category.icon
        self.parentID = category.parentID
        self.sortOrder = category.sortOrder
        self.isArchived = category.isArchived
    }
}

@Model
final class TagEntity {
    @Attribute(.unique) var tagID: UUID
    var name: String
    var colorIndex: Int
    
    init(from tag: TaskTag) {
        self.tagID = tag.id
        self.name = tag.name
        self.colorIndex = tag.colorIndex
    }
    
    func toStruct() -> TaskTag {
        TaskTag(id: tagID, name: name, colorIndex: colorIndex)
    }
    
    func update(from tag: TaskTag) {
        self.name = tag.name
        self.colorIndex = tag.colorIndex
    }
}

@Model
final class ProjectEntity {
    @Attribute(.unique) var projectID: UUID
    var name: String
    var projectDescription: String
    var colorIndex: Int
    var icon: String
    var isArchived: Bool
    var createdAt: Date
    
    init(from project: Project) {
        self.projectID = project.id
        self.name = project.name
        self.projectDescription = project.description
        self.colorIndex = project.colorIndex
        self.icon = project.icon
        self.isArchived = project.isArchived
        self.createdAt = project.createdAt
    }
    
    func toStruct() -> Project {
        Project(
            id: projectID,
            name: name,
            description: projectDescription,
            colorIndex: colorIndex,
            icon: icon,
            isArchived: isArchived,
            createdAt: createdAt
        )
    }
    
    func update(from project: Project) {
        self.name = project.name
        self.projectDescription = project.description
        self.colorIndex = project.colorIndex
        self.icon = project.icon
        self.isArchived = project.isArchived
    }
}

// MARK: - Wellness Entities

@Model
final class MealEntity {
    @Attribute(.unique) var mealID: UUID
    var title: String
    var calories: Int
    var date: Date
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var mealSourceRaw: String?
    var notes: String
    
    init(from meal: MealEntry) {
        self.mealID = meal.id
        self.title = meal.title
        self.calories = meal.calories
        self.date = meal.date
        self.protein = meal.protein
        self.carbs = meal.carbs
        self.fat = meal.fat
        self.mealSourceRaw = meal.mealSource?.rawValue
        self.notes = meal.notes
    }
    
    func toStruct() -> MealEntry {
        MealEntry(
            id: mealID,
            title: title,
            calories: calories,
            date: date,
            protein: protein,
            carbs: carbs,
            fat: fat,
            mealSource: mealSourceRaw.flatMap { MealSource(rawValue: $0) },
            notes: notes
        )
    }
}

@Model
final class SleepEntity {
    @Attribute(.unique) var sleepID: UUID
    var start: Date
    var end: Date
    var qualityRaw: String?
    var notes: String
    
    init(from entry: SleepEntry) {
        self.sleepID = entry.id
        self.start = entry.start
        self.end = entry.end
        self.qualityRaw = entry.quality?.rawValue
        self.notes = entry.notes
    }
    
    func toStruct() -> SleepEntry {
        SleepEntry(
            id: sleepID,
            start: start,
            end: end,
            quality: qualityRaw.flatMap { SleepQuality(rawValue: $0) },
            notes: notes
        )
    }
}

@Model
final class ActivityEntity {
    @Attribute(.unique) var activityID: UUID
    var title: String
    var minutes: Int
    var date: Date
    var calories: Int?
    var notes: String
    
    init(from entry: ActivityEntry) {
        self.activityID = entry.id
        self.title = entry.title
        self.minutes = entry.minutes
        self.date = entry.date
        self.calories = entry.calories
        self.notes = entry.notes
    }
    
    func toStruct() -> ActivityEntry {
        ActivityEntry(
            id: activityID,
            title: title,
            minutes: minutes,
            date: date,
            calories: calories,
            notes: notes
        )
    }
}

@Model
final class WaterEntity {
    @Attribute(.unique) var waterID: UUID
    var glasses: Int
    var date: Date
    
    init(from entry: WaterEntry) {
        self.waterID = entry.id
        self.glasses = entry.glasses
        self.date = entry.date
    }
    
    func toStruct() -> WaterEntry {
        WaterEntry(id: waterID, glasses: glasses, date: date)
    }
}
