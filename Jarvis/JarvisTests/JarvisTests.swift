//
//  JarvisTests.swift
//  JarvisTests
//
//  Created by Bill on 12.02.2026.
//

import Testing
import Foundation
@testable import Jarvis

// MARK: - PlannerTask Tests

struct PlannerTaskTests {
    
    @Test func createDefaultTask() {
        let task = PlannerTask(title: "Test Task")
        #expect(task.title == "Test Task")
        #expect(task.priority == .medium)
        #expect(task.source == .manual)
        #expect(task.reminders.isEmpty)
        #expect(task.createdAt <= Date())
        #expect(task.completedAt == nil)
        #expect(!task.isCompleted)
        #expect(!task.isInbox)
        #expect(task.durationMinutes == 60)
    }
    
    @Test func taskMetadataFields() {
        let now = Date()
        let task = PlannerTask(
            title: "Meta Task",
            createdAt: now,
            modifiedAt: now,
            source: .voice
        )
        #expect(task.createdAt == now)
        #expect(task.modifiedAt == now)
        #expect(task.source == .voice)
        #expect(task.completedAt == nil)
    }
    
    @Test func taskWithReminders() {
        let reminder1 = TaskReminder.fifteenMinBefore
        let reminder2 = TaskReminder.oneHourBefore
        let task = PlannerTask(
            title: "Reminder Task",
            reminders: [reminder1, reminder2]
        )
        #expect(task.reminders.count == 2)
        #expect(task.reminders[0].offsetMinutes == -15)
        #expect(task.reminders[1].offsetMinutes == -60)
    }
    
    @Test func taskEncodeDecode() throws {
        let original = PlannerTask(
            title: "Encode Test",
            notes: "Some notes",
            durationMinutes: 30,
            recurrenceRule: .weekly,
            priority: .urgent,
            createdAt: Date(timeIntervalSince1970: 1000000),
            source: .calendar,
            reminders: [.fifteenMinBefore]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PlannerTask.self, from: data)
        
        #expect(decoded.title == original.title)
        #expect(decoded.notes == original.notes)
        #expect(decoded.durationMinutes == 30)
        #expect(decoded.recurrenceRule?.frequency == .weekly)
        #expect(decoded.priority == .urgent)
        #expect(decoded.source == .calendar)
        #expect(decoded.reminders.count == 1)
        #expect(decoded.reminders[0].offsetMinutes == -15)
        #expect(decoded.createdAt == original.createdAt)
    }
    
    @Test func taskDecodesFromLegacyFormat() throws {
        // Simulate old format without new fields
        let legacyJSON = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "title": "Legacy Task",
            "notes": "",
            "date": 1000000,
            "durationMinutes": 60,
            "isAllDay": false,
            "recurrenceRule": "daily",
            "isCompleted": false,
            "hasAlarm": true,
            "isInbox": false,
            "completedRecurrenceDates": [],
            "colorIndex": 4,
            "icon": "circle",
            "tagIds": [],
            "priority": "high"
        }
        """.data(using: .utf8)!
        
        let task = try JSONDecoder().decode(PlannerTask.self, from: legacyJSON)
        #expect(task.title == "Legacy Task")
        #expect(task.priority == .high)
        // Old "daily" string should decode into RecurrenceRule struct
        #expect(task.recurrenceRule != nil)
        #expect(task.recurrenceRule?.frequency == .daily)
        #expect(task.recurrenceRule?.interval == 1)
        // New fields should have defaults
        #expect(task.source == .manual)
        #expect(task.reminders.isEmpty)
        #expect(task.completedAt == nil)
    }
}

// MARK: - TaskPriority Tests

struct TaskPriorityTests {
    
    @Test func prioritySortOrder() {
        #expect(TaskPriority.urgent.sortOrder < TaskPriority.high.sortOrder)
        #expect(TaskPriority.high.sortOrder < TaskPriority.medium.sortOrder)
        #expect(TaskPriority.medium.sortOrder < TaskPriority.low.sortOrder)
    }
    
    @Test func priorityRawValues() {
        #expect(TaskPriority(rawValue: "urgent") == .urgent)
        #expect(TaskPriority(rawValue: "high") == .high)
        #expect(TaskPriority(rawValue: "medium") == .medium)
        #expect(TaskPriority(rawValue: "low") == .low)
        #expect(TaskPriority(rawValue: "invalid") == nil)
    }
    
    @Test func allCasesIncludesUrgent() {
        #expect(TaskPriority.allCases.count == 4)
        #expect(TaskPriority.allCases.contains(.urgent))
    }
}

// MARK: - RecurrenceRule Tests

struct RecurrenceRuleTests {
    
    @Test func staticConvenienceProperties() {
        let daily = RecurrenceRule.daily
        #expect(daily.frequency == .daily)
        #expect(daily.interval == 1)
        #expect(daily.daysOfWeek == nil)
        #expect(daily.endDate == nil)
        
        let weekly = RecurrenceRule.weekly
        #expect(weekly.frequency == .weekly)
    }
    
    @Test func customInterval() {
        let rule = RecurrenceRule(frequency: .daily, interval: 3)
        #expect(rule.interval == 3)
        #expect(rule.displayName == "Каждые 3 дн.")
    }
    
    @Test func customDaysOfWeek() {
        let rule = RecurrenceRule(frequency: .weekly, daysOfWeek: [2, 4, 6])
        #expect(rule.daysOfWeek == [2, 4, 6])
    }
    
    @Test func decodeFromLegacyString() throws {
        // Old format: plain string "daily"
        let json = "\"daily\"".data(using: .utf8)!
        let rule = try JSONDecoder().decode(RecurrenceRule.self, from: json)
        #expect(rule.frequency == .daily)
        #expect(rule.interval == 1)
    }
    
    @Test func decodeFromNewStructFormat() throws {
        let json = """
        {"frequency": "weekly", "interval": 2, "daysOfWeek": [2, 4]}
        """.data(using: .utf8)!
        let rule = try JSONDecoder().decode(RecurrenceRule.self, from: json)
        #expect(rule.frequency == .weekly)
        #expect(rule.interval == 2)
        #expect(rule.daysOfWeek == [2, 4])
    }
    
    @Test func encodeDecodeCycle() throws {
        let original = RecurrenceRule(frequency: .monthly, interval: 3, endDate: Date(timeIntervalSince1970: 2000000))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RecurrenceRule.self, from: data)
        #expect(decoded.frequency == .monthly)
        #expect(decoded.interval == 3)
        #expect(decoded.endDate != nil)
    }
    
    @Test func frequencyAllCases() {
        #expect(RecurrenceRule.Frequency.allCases.count == 6)
    }
    
    @Test func displayNames() {
        #expect(RecurrenceRule.daily.displayName == "Каждый день")
        #expect(RecurrenceRule.weekdays.displayName == "Будни")
        #expect(RecurrenceRule.weekends.displayName == "Выходные")
        #expect(RecurrenceRule.weekly.displayName == "Еженедельно")
        #expect(RecurrenceRule.monthly.displayName == "Ежемесячно")
        #expect(RecurrenceRule.yearly.displayName == "Ежегодно")
    }
}

// MARK: - TaskReminder Tests

struct TaskReminderTests {
    
    @Test func defaultReminder() {
        let reminder = TaskReminder()
        #expect(reminder.offsetMinutes == -15)
        #expect(reminder.isEnabled)
    }
    
    @Test func presetReminders() {
        #expect(TaskReminder.atStart.offsetMinutes == 0)
        #expect(TaskReminder.fiveMinBefore.offsetMinutes == -5)
        #expect(TaskReminder.fifteenMinBefore.offsetMinutes == -15)
        #expect(TaskReminder.thirtyMinBefore.offsetMinutes == -30)
        #expect(TaskReminder.oneHourBefore.offsetMinutes == -60)
        #expect(TaskReminder.oneDayBefore.offsetMinutes == -1440)
    }
    
    @Test func displayNames() {
        #expect(TaskReminder.atStart.displayName == "В момент начала")
        #expect(TaskReminder.fiveMinBefore.displayName == "5 мин. до")
        #expect(TaskReminder.oneHourBefore.displayName == "1 час до")
        #expect(TaskReminder.oneDayBefore.displayName == "1 дн. до")
    }
}

// MARK: - TaskCategory Tests

struct TaskCategoryTests {
    
    @Test func categoryWithNewFields() {
        let parent = TaskCategory(name: "Parent")
        let child = TaskCategory(name: "Child", parentID: parent.id, sortOrder: 1, isArchived: false)
        #expect(child.parentID == parent.id)
        #expect(child.sortOrder == 1)
        #expect(!child.isArchived)
    }
    
    @Test func categoryDecodeLegacy() throws {
        let json = """
        {"id": "12345678-1234-1234-1234-123456789012", "name": "Work", "colorIndex": 2, "icon": "briefcase.fill"}
        """.data(using: .utf8)!
        let cat = try JSONDecoder().decode(TaskCategory.self, from: json)
        #expect(cat.name == "Work")
        #expect(cat.parentID == nil)
        #expect(cat.sortOrder == 0)
        #expect(!cat.isArchived)
    }
}

// MARK: - TaskSource Tests

struct TaskSourceTests {
    
    @Test func allSources() {
        #expect(TaskSource(rawValue: "manual") == .manual)
        #expect(TaskSource(rawValue: "voice") == .voice)
        #expect(TaskSource(rawValue: "calendar") == .calendar)
        #expect(TaskSource(rawValue: "mail") == .mail)
        #expect(TaskSource(rawValue: "siri") == .siri)
        #expect(TaskSource(rawValue: "widget") == .widget)
        #expect(TaskSource(rawValue: "messenger") == .messenger)
    }
}

// MARK: - Wellness Model Tests

struct WellnessModelTests {
    
    @Test func mealEntryWithMacros() {
        let meal = MealEntry(title: "Lunch", calories: 600, protein: 30, carbs: 50, fat: 20, mealSource: .lunch)
        #expect(meal.title == "Lunch")
        #expect(meal.protein == 30)
        #expect(meal.carbs == 50)
        #expect(meal.fat == 20)
        #expect(meal.mealSource == .lunch)
    }
    
    @Test func mealDecodeLegacy() throws {
        let json = """
        {"id": "12345678-1234-1234-1234-123456789012", "title": "Old Meal", "calories": 400, "date": 1000000}
        """.data(using: .utf8)!
        let meal = try JSONDecoder().decode(MealEntry.self, from: json)
        #expect(meal.title == "Old Meal")
        #expect(meal.protein == nil)
        #expect(meal.carbs == nil)
        #expect(meal.mealSource == nil)
        #expect(meal.notes == "")
    }
    
    @Test func sleepEntryWithQuality() {
        let start = Date()
        let end = start.addingTimeInterval(8 * 3600)
        let entry = SleepEntry(start: start, end: end, quality: .good, notes: "Slept well")
        #expect(entry.quality == .good)
        #expect(entry.notes == "Slept well")
        #expect(abs(entry.hours - 8.0) < 0.01)
    }
    
    @Test func sleepDecodeLegacy() throws {
        let json = """
        {"id": "12345678-1234-1234-1234-123456789012", "start": 1000000, "end": 1028800}
        """.data(using: .utf8)!
        let entry = try JSONDecoder().decode(SleepEntry.self, from: json)
        #expect(entry.quality == nil)
        #expect(entry.notes == "")
    }
    
    @Test func activityEntryWithCalories() {
        let entry = ActivityEntry(title: "Run", minutes: 30, calories: 300, notes: "5K")
        #expect(entry.calories == 300)
        #expect(entry.notes == "5K")
    }
    
    @Test func activityDecodeLegacy() throws {
        let json = """
        {"id": "12345678-1234-1234-1234-123456789012", "title": "Walk", "minutes": 20, "date": 1000000}
        """.data(using: .utf8)!
        let entry = try JSONDecoder().decode(ActivityEntry.self, from: json)
        #expect(entry.calories == nil)
        #expect(entry.notes == "")
    }
    
    @Test func waterEntry() {
        let entry = WaterEntry(glasses: 2)
        #expect(entry.glasses == 2)
    }
    
    @Test func wellnessGoalsDefaults() {
        let goals = WellnessGoals.default
        #expect(goals.dailyCalorieTarget == 2000)
        #expect(goals.dailyWaterGlasses == 8)
        #expect(goals.dailySleepHours == 8.0)
        #expect(goals.dailyActivityMinutes == 30)
    }
    
    @Test func mealSourceDisplayNames() {
        #expect(MealSource.breakfast.displayName == "Завтрак")
        #expect(MealSource.lunch.displayName == "Обед")
        #expect(MealSource.dinner.displayName == "Ужин")
        #expect(MealSource.snack.displayName == "Перекус")
    }
    
    @Test func sleepQualityValues() {
        #expect(SleepQuality.poor.numericValue == 1)
        #expect(SleepQuality.fair.numericValue == 2)
        #expect(SleepQuality.good.numericValue == 3)
        #expect(SleepQuality.excellent.numericValue == 4)
    }
}

// MARK: - WellnessSnapshot Backward Compatibility

struct WellnessSnapshotTests {
    
    @Test func snapshotDecodeLegacyWithoutWaterAndGoals() throws {
        let json = """
        {
            "meals": [],
            "sleep": [],
            "activities": []
        }
        """.data(using: .utf8)!
        let snapshot = try JSONDecoder().decode(WellnessSnapshot.self, from: json)
        #expect(snapshot.waterEntries == nil)
        #expect(snapshot.goals == nil)
    }
    
    @Test func snapshotWithAllFields() throws {
        let snapshot = WellnessSnapshot(
            meals: [MealEntry(title: "Test", calories: 100)],
            sleep: [],
            activities: [],
            waterEntries: [WaterEntry(glasses: 3)],
            goals: WellnessGoals(dailyCalorieTarget: 1800)
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WellnessSnapshot.self, from: data)
        #expect(decoded.meals.count == 1)
        #expect(decoded.waterEntries?.count == 1)
        #expect(decoded.goals?.dailyCalorieTarget == 1800)
    }
}

// MARK: - DayBounds Tests

struct DayBoundsTests {
    
    @Test func defaultValues() {
        let bounds = DayBounds.default
        #expect(bounds.riseHour >= 0 && bounds.riseHour <= 23)
        #expect(bounds.windDownHour >= 0 && bounds.windDownHour <= 23)
    }
    
    @Test func riseDateCalculation() {
        let bounds = DayBounds(riseHour: 7, riseMinute: 30, windDownHour: 22, windDownMinute: 0)
        let today = Calendar.current.startOfDay(for: Date())
        let riseDate = bounds.riseDate(on: today)
        let components = Calendar.current.dateComponents([.hour, .minute], from: riseDate)
        #expect(components.hour == 7)
        #expect(components.minute == 30)
    }
}

// MARK: - Project Tests

struct ProjectTests {
    
    @Test func createProject() {
        let project = Project(name: "Test Project", description: "A test", colorIndex: 2)
        #expect(project.name == "Test Project")
        #expect(project.description == "A test")
        #expect(!project.isArchived)
        #expect(project.createdAt <= Date())
    }
}
