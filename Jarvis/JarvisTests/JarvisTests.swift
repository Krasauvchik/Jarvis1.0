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
    
    @Test func projectArchiveToggle() {
        var project = Project(name: "Archivable")
        #expect(!project.isArchived)
        project.isArchived = true
        #expect(project.isArchived)
    }
    
    @Test func projectEncodeDecode() throws {
        let original = Project(name: "Coded", description: "desc", colorIndex: 3, icon: "star.fill")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Project.self, from: data)
        #expect(decoded.name == original.name)
        #expect(decoded.description == original.description)
        #expect(decoded.colorIndex == 3)
        #expect(decoded.icon == "star.fill")
    }
}

// MARK: - NavigationSection Tests

struct NavigationSectionTests {
    
    @Test func allCasesCount() {
        #expect(NavigationSection.allCases.count == 13)
    }
    
    @Test func localizedNames() {
        // Each section should return a non-empty localized name
        for section in NavigationSection.allCases {
            #expect(!section.localizedName.isEmpty)
        }
    }
    
    @Test func uniqueIcons() {
        let icons = NavigationSection.allCases.map(\.icon)
        let unique = Set(icons)
        #expect(unique.count == icons.count, "Each section should have a unique icon")
    }
    
    @Test func uniqueRawValues() {
        let raw = NavigationSection.allCases.map(\.rawValue)
        let unique = Set(raw)
        #expect(unique.count == raw.count, "Each section should have a unique rawValue")
    }
    
    @Test func idMatchesRawValue() {
        for section in NavigationSection.allCases {
            #expect(section.id == section.rawValue)
        }
    }
}

// MARK: - AppMode Tests

struct AppModeTests {
    
    @Test func allCases() {
        #expect(AppMode.allCases.count == 2)
        #expect(AppMode.allCases.contains(.work))
        #expect(AppMode.allCases.contains(.personal))
    }
    
    @Test func localizedNames() {
        #expect(!AppMode.work.localizedName.isEmpty)
        #expect(!AppMode.personal.localizedName.isEmpty)
    }
    
    @Test func workModeSectionsContainKeyAreas() {
        let sections = AppMode.work.visibleSections
        #expect(sections.contains(.today))
        #expect(sections.contains(.inbox))
        #expect(sections.contains(.chat))
        #expect(sections.contains(.analytics))
        #expect(sections.contains(.calendarSection))
        #expect(sections.contains(.mailSection))
    }
    
    @Test func personalModeHasHealth() {
        let sections = AppMode.personal.visibleSections
        #expect(sections.contains(.health))
        #expect(sections.contains(.today))
        #expect(!sections.contains(.inbox))
    }
    
    @Test func icons() {
        #expect(AppMode.work.icon == "briefcase.fill")
        #expect(AppMode.personal.icon == "heart.fill")
    }
}

// MARK: - L10n Infrastructure Tests

struct L10nTests {
    
    @Test func tabKeysNonEmpty() {
        #expect(!L10n.tabToday.isEmpty)
        #expect(!L10n.tabInbox.isEmpty)
        #expect(!L10n.tabCalendar.isEmpty)
        #expect(!L10n.tabMail.isEmpty)
        #expect(!L10n.tabAI.isEmpty)
        #expect(!L10n.tabAnalytics.isEmpty)
        #expect(!L10n.tabSettings.isEmpty)
    }
    
    @Test func sectionKeysNonEmpty() {
        #expect(!L10n.sectionInbox.isEmpty)
        #expect(!L10n.sectionToday.isEmpty)
        #expect(!L10n.sectionScheduled.isEmpty)
        #expect(!L10n.sectionFuture.isEmpty)
        #expect(!L10n.sectionCompleted.isEmpty)
        #expect(!L10n.sectionAll.isEmpty)
        #expect(!L10n.sectionMessengers.isEmpty)
        #expect(!L10n.sectionAnalytics.isEmpty)
        #expect(!L10n.sectionNeural.isEmpty)
        #expect(!L10n.sectionHealth.isEmpty)
        #expect(!L10n.sectionCalendar.isEmpty)
        #expect(!L10n.sectionMail.isEmpty)
        #expect(!L10n.sectionProjects.isEmpty)
    }
    
    @Test func actionKeysNonEmpty() {
        #expect(!L10n.addTask.isEmpty)
        #expect(!L10n.editTask.isEmpty)
        #expect(!L10n.deleteTask.isEmpty)
        #expect(!L10n.save.isEmpty)
        #expect(!L10n.delete.isEmpty)
        #expect(!L10n.close.isEmpty)
    }
    
    @Test func modeKeysNonEmpty() {
        #expect(!L10n.modeWork.isEmpty)
        #expect(!L10n.modePersonal.isEmpty)
    }
    
    @Test func shareKeysNonEmpty() {
        #expect(!L10n.shareTitle.isEmpty)
        #expect(!L10n.shareSent.isEmpty)
        #expect(!L10n.shareNoTasks.isEmpty)
        #expect(!L10n.shareClose.isEmpty)
        #expect(!L10n.sharePriority.isEmpty)
    }
    
    @Test func voiceControlKeysNonEmpty() {
        #expect(!L10n.voiceControlTitle.isEmpty)
        #expect(!L10n.voiceControlSubtitle.isEmpty)
    }
    
    @Test func coachKeysNonEmpty() {
        #expect(!L10n.coachFitness.isEmpty)
        #expect(!L10n.coachNutrition.isEmpty)
        #expect(!L10n.coachSleep.isEmpty)
        #expect(!L10n.coachProductivity.isEmpty)
    }
}

// MARK: - LogLevel Tests

struct LogLevelTests {
    
    @Test func ordering() {
        #expect(LogLevel.debug < LogLevel.info)
        #expect(LogLevel.info < LogLevel.warning)
        #expect(LogLevel.warning < LogLevel.error)
        #expect(LogLevel.error < LogLevel.critical)
    }
    
    @Test func emojis() {
        #expect(LogLevel.debug.emoji == "🔍")
        #expect(LogLevel.error.emoji == "❌")
        #expect(LogLevel.critical.emoji == "🔥")
    }
    
    @Test func rawValues() {
        #expect(LogLevel.debug.rawValue == 0)
        #expect(LogLevel.critical.rawValue == 4)
    }
}

// MARK: - NetworkError Tests

struct NetworkErrorTests {
    
    @Test func errorDescriptions() {
        #expect(NetworkError.noConnection.errorDescription != nil)
        #expect(NetworkError.invalidURL.errorDescription != nil)
        #expect(NetworkError.timeout.errorDescription != nil)
        #expect(NetworkError.unauthorized.errorDescription != nil)
    }
    
    @Test func httpErrorIncludesCode() {
        let error = NetworkError.httpError(statusCode: 404, message: "Not Found")
        #expect(error.errorDescription?.contains("404") == true)
    }
    
    @Test func serverErrorIncludesMessage() {
        let error = NetworkError.serverError("DB down")
        #expect(error.errorDescription?.contains("DB down") == true)
    }
}

// MARK: - TaskIcon Tests

struct TaskIconTests {
    
    @Test func allCasesCount() {
        #expect(TaskIcon.allCases.count >= 40)
    }
    
    @Test func systemNameMatchesRawValue() {
        for icon in TaskIcon.allCases {
            #expect(icon.systemName == icon.rawValue)
        }
    }
    
    @Test func commonIcons() {
        #expect(TaskIcon.star.rawValue == "star.fill")
        #expect(TaskIcon.heart.rawValue == "heart.fill")
        #expect(TaskIcon.briefcase.rawValue == "briefcase.fill")
    }
}

// MARK: - TaskSuggestion Tests

struct TaskSuggestionTests {
    
    @Test func defaultSuggestionsExist() {
        #expect(!TaskSuggestion.defaults.isEmpty)
        #expect(TaskSuggestion.defaults.count >= 3)
    }
    
    @Test func timeRangeFormatting() {
        let suggestion = TaskSuggestion(title: "Test", icon: "star", durationMinutes: 60, colorIndex: 0, suggestedHour: 10)
        let range = suggestion.timeRange
        #expect(range.contains("10:00"))
        #expect(range.contains("11:00"))
    }
    
    @Test func timeRangeWithoutHour() {
        let suggestion = TaskSuggestion(title: "Test", icon: "star", durationMinutes: 30, colorIndex: 0, suggestedHour: nil)
        #expect(suggestion.timeRange == "30 min")
    }
}

// MARK: - DependencyContainer Tests

struct DependencyContainerTests {
    
    @Test func sharedInstanceExists() {
        let container = DependencyContainer.shared
        #expect(container.isTestEnvironment == false)
    }
    
    @Test func configureForTesting() {
        let container = DependencyContainer.shared
        container.configureForTesting()
        #expect(container.isTestEnvironment == true)
        container.resetToProduction()
        #expect(container.isTestEnvironment == false)
    }
}

// MARK: - PlannerStore Tests

@MainActor
struct PlannerStoreTests {
    
    @Test func addAndRetrieveTask() {
        let store = PlannerStore()
        let task = PlannerTask(title: "Store Test")
        store.add(task)
        #expect(store.tasks.contains(where: { $0.id == task.id }))
    }
    
    @Test func deleteTask() {
        let store = PlannerStore()
        let task = PlannerTask(title: "To Delete")
        store.add(task)
        store.delete(task)
        #expect(!store.tasks.contains(where: { $0.id == task.id }))
    }
    
    @Test func addToInbox() {
        let store = PlannerStore()
        let task = PlannerTask(title: "Inbox Task")
        store.addToInbox(task)
        #expect(store.tasks.first(where: { $0.id == task.id })?.isInbox == true)
    }
    
    @Test func removeCompleted() {
        let store = PlannerStore()
        store.removeAll() // clear any pre-existing
        var task = PlannerTask(title: "Done Task")
        task.isCompleted = true
        store.add(task)
        store.add(PlannerTask(title: "Active"))
        store.removeCompleted()
        #expect(store.tasks.allSatisfy { !$0.isCompleted })
        #expect(store.tasks.contains(where: { $0.title == "Active" }))
    }
    
    @Test func removeAll() {
        let store = PlannerStore()
        store.add(PlannerTask(title: "Task 1"))
        store.add(PlannerTask(title: "Task 2"))
        store.removeAll()
        #expect(store.tasks.isEmpty)
    }
    
    @Test func addCategory() {
        let store = PlannerStore()
        let cat = TaskCategory(name: "Work")
        store.addCategory(cat)
        #expect(store.categories.contains(where: { $0.id == cat.id }))
    }
    
    @Test func removeCategory() {
        let store = PlannerStore()
        let cat = TaskCategory(name: "Remove Me")
        store.addCategory(cat)
        store.removeCategory(cat)
        #expect(!store.categories.contains(where: { $0.id == cat.id }))
    }
    
    @Test func addTag() {
        let store = PlannerStore()
        let tag = TaskTag(name: "urgent")
        store.addTag(tag)
        #expect(store.tags.contains(where: { $0.id == tag.id }))
    }
    
    @Test func removeTag() {
        let store = PlannerStore()
        let tag = TaskTag(name: "removable")
        store.addTag(tag)
        store.removeTag(tag)
        #expect(!store.tags.contains(where: { $0.id == tag.id }))
    }
    
    @Test func addProject() {
        let store = PlannerStore()
        let project = Project(name: "Test Project")
        store.addProject(project)
        #expect(store.projects.contains(where: { $0.id == project.id }))
    }
    
    @Test func removeProject() {
        let store = PlannerStore()
        let project = Project(name: "Del Project")
        store.addProject(project)
        store.removeProject(project)
        #expect(!store.projects.contains(where: { $0.id == project.id }))
    }
    
    @Test func taskCountForSections() {
        let store = PlannerStore()
        store.removeAll()
        
        var inboxTask = PlannerTask(title: "Inbox")
        inboxTask.isInbox = true
        store.add(inboxTask)
        
        let todayTask = PlannerTask(title: "Today", date: Date())
        store.add(todayTask)
        
        #expect(store.taskCount(for: .all) == 2)
    }
    
    @Test func addSubTask() {
        let store = PlannerStore()
        let parent = PlannerTask(title: "Parent")
        store.add(parent)
        store.addSubTask(title: "Child", parentId: parent.id)
        let subs = store.subTasks(of: parent.id)
        #expect(subs.count == 1)
        #expect(subs.first?.title == "Child")
    }
    
    @Test func tasksForProject() {
        let store = PlannerStore()
        store.removeAll()
        let project = Project(name: "My Project")
        store.addProject(project)
        var task = PlannerTask(title: "Project Task")
        task.projectId = project.id
        store.add(task)
        let projectTasks = store.tasksForProject(project.id)
        #expect(projectTasks.count == 1)
    }
}

// MARK: - WellnessGoals Tests

struct WellnessGoalsTests {
    
    @Test func customGoals() {
        let goals = WellnessGoals(
            dailyCalorieTarget: 2500,
            dailyWaterGlasses: 10,
            dailySleepHours: 7.5,
            dailyActivityMinutes: 45
        )
        #expect(goals.dailyCalorieTarget == 2500)
        #expect(goals.dailyWaterGlasses == 10)
        #expect(goals.dailySleepHours == 7.5)
        #expect(goals.dailyActivityMinutes == 45)
    }
    
    @Test func encodeDecode() throws {
        let original = WellnessGoals(dailyCalorieTarget: 1800)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WellnessGoals.self, from: data)
        #expect(decoded.dailyCalorieTarget == 1800)
    }
}

// MARK: - SleepEntry Calculation Tests

struct SleepCalculationTests {
    
    @Test func hoursCalculation() {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 7 * 3600) // 7 hours
        let entry = SleepEntry(start: start, end: end)
        #expect(abs(entry.hours - 7.0) < 0.01)
    }
    
    @Test func shortSleep() {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 3 * 3600) // 3 hours
        let entry = SleepEntry(start: start, end: end)
        #expect(abs(entry.hours - 3.0) < 0.01)
    }
}

// MARK: - MealEntry Tests

struct MealEntryTests {
    
    @Test func mealWithAllMacros() {
        let meal = MealEntry(
            title: "Pasta",
            calories: 500,
            protein: 20,
            carbs: 60,
            fat: 15,
            mealSource: .dinner,
            notes: "Delicious"
        )
        #expect(meal.calories == 500)
        #expect(meal.protein == 20)
        #expect(meal.carbs == 60)
        #expect(meal.fat == 15)
        #expect(meal.mealSource == .dinner)
        #expect(meal.notes == "Delicious")
    }
    
    @Test func mealMinimal() {
        let meal = MealEntry(title: "Snack", calories: 100)
        #expect(meal.protein == nil)
        #expect(meal.carbs == nil)
        #expect(meal.fat == nil)
        #expect(meal.mealSource == nil)
    }
}

// MARK: - TaskTag Tests

struct TaskTagTests {
    
    @Test func createTag() {
        let tag = TaskTag(name: "important")
        #expect(tag.name == "important")
    }
    
    @Test func tagEncodeDecode() throws {
        let original = TaskTag(name: "work", colorIndex: 2)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TaskTag.self, from: data)
        #expect(decoded.name == "work")
        #expect(decoded.colorIndex == 2)
    }
}
