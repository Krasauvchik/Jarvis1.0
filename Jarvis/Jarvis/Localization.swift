import Foundation

// MARK: - Localization Infrastructure (Phase 3)

/// Convenience namespace for accessing localized strings.
/// Usage: `L10n.tabToday` returns localized "Today"/"Сегодня" based on device language.
///
/// For strings with parameters, use String(localized:) directly:
///   `String(localized: "tasks_count \(count)")`
enum L10n {
    // MARK: - Tabs
    static var tabToday: String { String(localized: "tab_today") }
    static var tabInbox: String { String(localized: "tab_inbox") }
    static var tabCalendar: String { String(localized: "tab_calendar") }
    static var tabMail: String { String(localized: "tab_mail") }
    static var tabAI: String { String(localized: "tab_ai") }
    static var tabAnalytics: String { String(localized: "tab_analytics") }
    static var tabSettings: String { String(localized: "tab_settings") }
    
    // MARK: - Sections
    static var sectionInbox: String { String(localized: "section_inbox") }
    static var sectionToday: String { String(localized: "section_today") }
    static var sectionScheduled: String { String(localized: "section_scheduled") }
    static var sectionFuture: String { String(localized: "section_future") }
    static var sectionCompleted: String { String(localized: "section_completed") }
    static var sectionAll: String { String(localized: "section_all") }
    static var sectionMessengers: String { String(localized: "section_messengers") }
    static var sectionAnalytics: String { String(localized: "section_analytics") }
    static var sectionNeural: String { String(localized: "section_neural") }
    
    // MARK: - Actions
    static var addTask: String { String(localized: "add_task") }
    static var editTask: String { String(localized: "edit_task") }
    static var deleteTask: String { String(localized: "delete_task") }
    static var duplicateTask: String { String(localized: "duplicate_task") }
    static var moveToTomorrow: String { String(localized: "move_to_tomorrow") }
    static var moveToInbox: String { String(localized: "move_to_inbox") }
    static var share: String { String(localized: "share") }
    static var searchTasks: String { String(localized: "search_tasks") }
    static var refresh: String { String(localized: "refresh") }
    static var addButton: String { String(localized: "add_button") }
    
    // MARK: - Empty States
    static var noTasksToday: String { String(localized: "no_tasks_today") }
    static var inboxEmpty: String { String(localized: "inbox_empty") }
    static var noScheduled: String { String(localized: "no_scheduled") }
    static var noFuturePlans: String { String(localized: "no_future_plans") }
    static var noCompleted: String { String(localized: "no_completed") }
    static var noTasks: String { String(localized: "no_tasks") }
    
    // MARK: - Analytics
    static var statistics: String { String(localized: "statistics") }
    static var total: String { String(localized: "total") }
    static var completed: String { String(localized: "completed") }
    static var avgPerDay: String { String(localized: "avg_per_day") }
    static var streakDays: String { String(localized: "streak_days") }
    static var completionTrend: String { String(localized: "completion_trend") }
    static var productivityByHour: String { String(localized: "productivity_by_hour") }
    static var taskCategories: String { String(localized: "task_categories") }
    static var byPriority: String { String(localized: "by_priority") }
    static var productivityStreak: String { String(localized: "productivity_streak") }
    static var aiAnalysis: String { String(localized: "ai_analysis") }
    static var noDataPeriod: String { String(localized: "no_data_period") }
    static var noCategory: String { String(localized: "no_category") }
    static var deepAnalysis: String { String(localized: "deep_analysis") }
    static var advice: String { String(localized: "advice") }
    static var weeklyActivity: String { String(localized: "weekly_activity") }
    
    // MARK: - Periods
    static var periodWeek: String { String(localized: "period_week") }
    static var periodMonth: String { String(localized: "period_month") }
    static var periodQuarter: String { String(localized: "period_quarter") }
    
    // MARK: - Priority
    static var priorityHigh: String { String(localized: "priority_high") }
    static var priorityMedium: String { String(localized: "priority_medium") }
    static var priorityLow: String { String(localized: "priority_low") }
    
    // MARK: - Network
    static var online: String { String(localized: "online") }
    static var offline: String { String(localized: "offline") }
    
    // MARK: - Misc
    static var reminder: String { String(localized: "reminder") }
    static var wellness: String { String(localized: "wellness") }
    static var meals: String { String(localized: "meals") }
    static var sleep: String { String(localized: "sleep") }
    static var activity: String { String(localized: "activity") }
    static var googleCalendar: String { String(localized: "google_calendar") }
    static var gmail: String { String(localized: "gmail") }
    static var whatsAppTelegram: String { String(localized: "whatsapp_telegram") }
    static var chartsTrends: String { String(localized: "charts_trends") }
    static var chatWithAI: String { String(localized: "chat_with_ai") }
    static var showSidebar: String { String(localized: "show_sidebar") }
    static var clearSearch: String { String(localized: "clear_search") }
    
    // MARK: - Recurrence
    static var recurrenceDaily: String { String(localized: "recurrence_daily") }
    static var recurrenceWeekdays: String { String(localized: "recurrence_weekdays") }
    static var recurrenceWeekends: String { String(localized: "recurrence_weekends") }
    static var recurrenceWeekly: String { String(localized: "recurrence_weekly") }
    static var recurrenceMonthly: String { String(localized: "recurrence_monthly") }
    static var recurrenceYearly: String { String(localized: "recurrence_yearly") }
}
