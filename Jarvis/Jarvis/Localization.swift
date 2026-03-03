import Foundation

// MARK: - Localization Infrastructure

/// Convenience namespace for accessing localized strings.
/// Uses LanguageManager for in-app language switching (ru/en).
/// Usage: `L10n.tabToday` returns "Today" or "Сегодня" based on user's language choice.
enum L10n {
    private static func _s(_ key: String) -> String {
        LanguageManager.shared.localizedString(key)
    }
    
    // MARK: - Tabs
    static var tabToday: String { _s("tab_today") }
    static var tabInbox: String { _s("tab_inbox") }
    static var tabCalendar: String { _s("tab_calendar") }
    static var tabMail: String { _s("tab_mail") }
    static var tabAI: String { _s("tab_ai") }
    static var tabAnalytics: String { _s("tab_analytics") }
    static var tabSettings: String { _s("tab_settings") }
    
    // MARK: - Sections
    static var sectionInbox: String { _s("section_inbox") }
    static var sectionToday: String { _s("section_today") }
    static var sectionScheduled: String { _s("section_scheduled") }
    static var sectionFuture: String { _s("section_future") }
    static var sectionCompleted: String { _s("section_completed") }
    static var sectionAll: String { _s("section_all") }
    static var sectionMessengers: String { _s("section_messengers") }
    static var sectionAnalytics: String { _s("section_analytics") }
    static var sectionNeural: String { _s("section_neural") }
    
    // MARK: - Actions
    static var addTask: String { _s("add_task") }
    static var editTask: String { _s("edit_task") }
    static var deleteTask: String { _s("delete_task") }
    static var duplicateTask: String { _s("duplicate_task") }
    static var moveToTomorrow: String { _s("move_to_tomorrow") }
    static var moveToInbox: String { _s("move_to_inbox") }
    static var share: String { _s("share") }
    static var searchTasks: String { _s("search_tasks") }
    static var refresh: String { _s("refresh") }
    static var addButton: String { _s("add_button") }
    
    // MARK: - Empty States
    static var noTasksToday: String { _s("no_tasks_today") }
    static var inboxEmpty: String { _s("inbox_empty") }
    static var noScheduled: String { _s("no_scheduled") }
    static var noFuturePlans: String { _s("no_future_plans") }
    static var noCompleted: String { _s("no_completed") }
    static var noTasks: String { _s("no_tasks") }
    
    // MARK: - Analytics
    static var statistics: String { _s("statistics") }
    static var total: String { _s("total") }
    static var completed: String { _s("completed") }
    static var avgPerDay: String { _s("avg_per_day") }
    static var streakDays: String { _s("streak_days") }
    static var completionTrend: String { _s("completion_trend") }
    static var productivityByHour: String { _s("productivity_by_hour") }
    static var taskCategories: String { _s("task_categories") }
    static var byPriority: String { _s("by_priority") }
    static var productivityStreak: String { _s("productivity_streak") }
    static var aiAnalysis: String { _s("ai_analysis") }
    static var noDataPeriod: String { _s("no_data_period") }
    static var noCategory: String { _s("no_category") }
    static var deepAnalysis: String { _s("deep_analysis") }
    static var advice: String { _s("advice") }
    static var weeklyActivity: String { _s("weekly_activity") }
    
    // MARK: - Periods
    static var periodWeek: String { _s("period_week") }
    static var periodMonth: String { _s("period_month") }
    static var periodQuarter: String { _s("period_quarter") }
    
    // MARK: - Priority
    static var priorityHigh: String { _s("priority_high") }
    static var priorityMedium: String { _s("priority_medium") }
    static var priorityLow: String { _s("priority_low") }
    
    // MARK: - Network
    static var online: String { _s("online") }
    static var offline: String { _s("offline") }
    
    // MARK: - Misc
    static var reminder: String { _s("reminder") }
    static var wellness: String { _s("wellness") }
    static var meals: String { _s("meals") }
    static var sleep: String { _s("sleep") }
    static var activity: String { _s("activity") }
    static var googleCalendar: String { _s("google_calendar") }
    static var gmail: String { _s("gmail") }
    static var whatsAppTelegram: String { _s("whatsapp_telegram") }
    static var chartsTrends: String { _s("charts_trends") }
    static var chatWithAI: String { _s("chat_with_ai") }
    static var showSidebar: String { _s("show_sidebar") }
    static var clearSearch: String { _s("clear_search") }
    
    // MARK: - Context Menu Actions
    static var markComplete: String { _s("mark_complete") }
    static var markIncomplete: String { _s("mark_incomplete") }
    static var moveToFuture: String { _s("move_to_future") }
    static var colorMenu: String { _s("color_menu") }
    static var scheduleToday: String { _s("schedule_today") }
    static var scheduleAction: String { _s("schedule_action") }
    
    // MARK: - Navigation
    static var previousDay: String { _s("previous_day") }
    static var nextDay: String { _s("next_day") }
    static var today: String { _s("today_label") }
    
    // MARK: - Placeholders / Hints
    static var dropToComplete: String { _s("drop_to_complete") }
    static var clearAction: String { _s("clear_action") }
    static var restoreTask: String { _s("restore_task") }
    static var completedAppearHere: String { _s("completed_appear_here") }
    static var unavailableWatchOS: String { _s("unavailable_watchos") }
    static var noTasksThisDay: String { _s("no_tasks_this_day") }
    static var tapPlusOrDrag: String { _s("tap_plus_or_drag") }
    static var inboxHint: String { _s("inbox_hint") }
    static var searchHint: String { _s("search_hint") }
    static var swipeToDelete: String { _s("swipe_to_delete") }
    
    // MARK: - Completed Section
    static var completedTitle: String { _s("completed_title") }
    static var thisWeek: String { _s("this_week") }
    
    // MARK: - Subtitles
    static var subtitleWellness: String { _s("subtitle_wellness") }
    static var subtitleProjects: String { _s("subtitle_projects") }
    
    // MARK: - Colors
    static var colorCoral: String { _s("color_coral") }
    static var colorOrange: String { _s("color_orange") }
    static var colorYellow: String { _s("color_yellow") }
    static var colorGreen: String { _s("color_green") }
    static var colorBlue: String { _s("color_blue") }
    static var colorPurple: String { _s("color_purple") }
    static var colorPink: String { _s("color_pink") }
    static var colorTurquoise: String { _s("color_turquoise") }
    
    // MARK: - Wellness
    static var healthTitle: String { _s("health_title") }
    static var tipsTitle: String { _s("tips_title") }
    static var addTasksForTips: String { _s("add_tasks_for_tips") }
    static var nutritionTitle: String { _s("nutrition_title") }
    static var dish: String { _s("dish") }
    static var kcal: String { _s("kcal") }
    static var addDish: String { _s("add_dish") }
    static var sleepSection: String { _s("sleep_section") }
    static var bedtime: String { _s("bedtime") }
    static var wakeUp: String { _s("wake_up") }
    static var saveNight: String { _s("save_night") }
    static var activitySection: String { _s("activity_section") }
    static var activityType: String { _s("activity_type") }
    static var minutesShort: String { _s("minutes_short") }
    static var addActivity: String { _s("add_activity") }
    static var photoRecognitionFailed: String { _s("photo_recognition_failed") }
    static var errorTitle: String { _s("error_title") }
    static var saveSleepLabel: String { _s("save_sleep_label") }
    static var saveSleepHint: String { _s("save_sleep_hint") }
    static var healthTipsLabel: String { _s("health_tips_label") }
    
    // MARK: - Analytics Extra
    static var tasksLabel: String { _s("tasks_label") }
    static var dateLabel: String { _s("date_label") }
    static var hourLabel: String { _s("hour_label") }
    static var countLabel: String { _s("count_label") }
    static var categoryLabel: String { _s("category_label") }
    static var periodLabel: String { _s("period_label") }
    static var analyticsHint: String { _s("analytics_hint") }
    
    // MARK: - Recurrence
    static var recurrenceDaily: String { _s("recurrence_daily") }
    static var recurrenceWeekdays: String { _s("recurrence_weekdays") }
    static var recurrenceWeekends: String { _s("recurrence_weekends") }
    static var recurrenceWeekly: String { _s("recurrence_weekly") }
    static var recurrenceMonthly: String { _s("recurrence_monthly") }
    static var recurrenceYearly: String { _s("recurrence_yearly") }
    
    // MARK: - Analytics UI
    static var analyticsTitle: String { _s("analytics_title") }
    static var periodPickerHint: String { _s("period_picker_hint") }
    static var priorityLabel: String { _s("priority_label") }
    static var aiAnalysisLabel: String { _s("ai_analysis_label") }
    static var streakDaysLabel: String { _s("streak_days_label") }
    
    // MARK: - Task Sheets
    static var taskName: String { _s("task_name") }
    static var notesField: String { _s("notes_field") }
    static var newTaskTitle: String { _s("new_task_title") }
    static var cancel: String { _s("cancel") }
    static var addAction: String { _s("add_action") }
    static var categorySection: String { _s("category_section") }
    static var tagsSection: String { _s("tags_section") }
    static var addTagsHint: String { _s("add_tags_hint") }
    static var inboxToggle: String { _s("inbox_toggle") }
    static var dateTimeField: String { _s("date_time_field") }
    static var allDayToggle: String { _s("all_day_toggle") }
    static var durationField: String { _s("duration_field") }
    static var reminderToggle: String { _s("reminder_toggle") }
    static var colorSection: String { _s("color_section") }
    static var iconSection: String { _s("icon_section") }
    static var statusScheduled: String { _s("status_scheduled") }
    static var fromInbox: String { _s("from_inbox") }
    static var toInbox: String { _s("to_inbox") }
    static var removeReminder: String { _s("remove_reminder") }
    static var prioritySection: String { _s("priority_section") }
    static var done: String { _s("done") }
    
    // MARK: - Planner Components
    static var tapToEdit: String { _s("tap_to_edit") }
    
    // MARK: - Settings
    static var settingsSync: String { _s("settings_sync") }
    static var settingsSyncEnabled: String { _s("settings_sync_enabled") }
    static var settingsSyncNow: String { _s("settings_sync_now") }
    static var settingsAppearance: String { _s("settings_appearance") }
    static var settingsHoverZoom: String { _s("settings_hover_zoom") }
    static var settingsHoverZoomDesc: String { _s("settings_hover_zoom_desc") }
    static var settingsAISection: String { _s("settings_ai_section") }
    static var settingsAIModel: String { _s("settings_ai_model") }
    static var settingsAIModelDesc: String { _s("settings_ai_model_desc") }
    static var settingsHealth: String { _s("settings_health") }
    static var settingsSleepCalc: String { _s("settings_sleep_calc") }
    static var settingsSleepCalcTime: String { _s("settings_sleep_calc_time") }
    static var settingsCalendar: String { _s("settings_calendar") }
    static var settingsCalendarAccess: String { _s("settings_calendar_access") }
    static var settingsCalendarSync: String { _s("settings_calendar_sync") }
    static var settingsAISkills: String { _s("settings_ai_skills") }
    static var settingsAISkillsDesc: String { _s("settings_ai_skills_desc") }
    static var settingsVoiceInput: String { _s("settings_voice_input") }
    static var settingsNotifications: String { _s("settings_notifications") }
    static var settingsReminders: String { _s("settings_reminders") }
    static var settingsSound: String { _s("settings_sound") }
    static var settingsStats: String { _s("settings_stats") }
    static var settingsTotalTasks: String { _s("settings_total_tasks") }
    static var settingsCompletedTasks: String { _s("settings_completed_tasks") }
    static var settingsInInbox: String { _s("settings_in_inbox") }
    static var settingsCategoryTags: String { _s("settings_category_tags") }
    static var settingsManageCategoryTags: String { _s("settings_manage_category_tags") }
    static var settingsData: String { _s("settings_data") }
    static var settingsExport: String { _s("settings_export") }
    static var settingsImport: String { _s("settings_import") }
    static var settingsClearCompleted: String { _s("settings_clear_completed") }
    static var settingsDeleteAll: String { _s("settings_delete_all") }
    static var settingsAbout: String { _s("settings_about") }
    static var settingsVersion: String { _s("settings_version") }
    static var settingsBuild: String { _s("settings_build") }
    static var settingsImportTitle: String { _s("settings_import_title") }
    static var settingsNoFileAccess: String { _s("settings_no_file_access") }
    static var settingsFileError: String { _s("settings_file_error") }
    static var settingsDeleteCompletedConfirm: String { _s("settings_delete_completed_confirm") }
    static var settingsDeleteCompletedDesc: String { _s("settings_delete_completed_desc") }
    static var settingsDeleteAllConfirm: String { _s("settings_delete_all_confirm") }
    static var settingsDeleteAllDesc: String { _s("settings_delete_all_desc") }
    static var deleteAction: String { _s("delete_action") }
    static var deleteAllAction: String { _s("delete_all_action") }
    static var settingsThemeLight: String { _s("settings_theme_light") }
    static var settingsThemeDark: String { _s("settings_theme_dark") }
    static var settingsThemeSystem: String { _s("settings_theme_system") }
    static var categoriesTitle: String { _s("categories_title") }
    static var tagsTitle: String { _s("tags_title") }
    static var addCategoryAction: String { _s("add_category_action") }
    static var addTagAction: String { _s("add_tag_action") }
    static var newCategoryTitle: String { _s("new_category_title") }
    static var editAction: String { _s("edit_action") }
    static var newTagTitle: String { _s("new_tag_title") }
    static var editTagTitle: String { _s("edit_tag_title") }
    static var nameField: String { _s("name_field") }
    static var tagNameField: String { _s("tag_name_field") }
    static var lastSleepHours: String { _s("last_sleep_hours") }
    static var calendarSectionLabel: String { _s("calendar_section_label") }
    static var mailSectionLabel: String { _s("mail_section_label") }
    
    // MARK: - Settings Tabs (two-column sheet)
    static var settingsTitle: String { _s("settings_title") }
    static var settingsTabAccount: String { _s("settings_tab_account") }
    static var settingsTabSubscription: String { _s("settings_tab_subscription") }
    static var settingsTabCalendars: String { _s("settings_tab_calendars") }
    static var settingsTabCustomization: String { _s("settings_tab_customization") }
    static var settingsTabAdvanced: String { _s("settings_tab_advanced") }
    static var settingsTabHelpFeedback: String { _s("settings_tab_help_feedback") }
    static var settingsTabPrivacy: String { _s("settings_tab_privacy") }
    static var settingsTabLogOut: String { _s("settings_tab_log_out") }
    
    // MARK: - Account Tab
    static var settingsStructuredCloud: String { _s("settings_structured_cloud") }
    static var settingsSyncLabel: String { _s("settings_sync_label") }
    static var settingsResync: String { _s("settings_resync") }
    static var settingsSyncInProgress: String { _s("settings_sync_in_progress") }
    static var settingsSynced: String { _s("settings_synced") }
    static var settingsICloudEnabled: String { _s("settings_icloud_enabled") }
    static var settingsAccountLabel: String { _s("settings_account_label") }
    static var settingsICloudAccount: String { _s("settings_icloud_account") }
    static var settingsDangerZone: String { _s("settings_danger_zone") }
    static var settingsDeleteAccount: String { _s("settings_delete_account") }
    static var settingsResetApp: String { _s("settings_reset_app") }
    static var settingsDeleteAllData: String { _s("settings_delete_all_data") }
    static var settingsDeleteEverything: String { _s("settings_delete_everything") }
    static var settingsDeleteAllDataDesc: String { _s("settings_delete_all_data_desc") }
    static var settingsResetAppConfirm: String { _s("settings_reset_app_confirm") }
    static var settingsResetAction: String { _s("settings_reset_action") }
    static var settingsResetDesc: String { _s("settings_reset_desc") }
    
    // MARK: - Subscription Tab
    static var settingsCurrentPlan: String { _s("settings_current_plan") }
    static var settingsFreePlan: String { _s("settings_free_plan") }
    static var settingsBasicFeatures: String { _s("settings_basic_features") }
    static var settingsProFeatures: String { _s("settings_pro_features") }
    static var settingsCloudSync: String { _s("settings_cloud_sync") }
    static var settingsCloudSyncDesc: String { _s("settings_cloud_sync_desc") }
    static var settingsAIAssistant: String { _s("settings_ai_assistant") }
    static var settingsAIAssistantDesc: String { _s("settings_ai_assistant_desc") }
    static var settingsAdvancedAnalytics: String { _s("settings_advanced_analytics") }
    static var settingsAdvancedAnalyticsDesc: String { _s("settings_advanced_analytics_desc") }
    static var settingsCalendarIntegration: String { _s("settings_calendar_integration") }
    static var settingsCalendarIntegrationDesc: String { _s("settings_calendar_integration_desc") }
    
    // MARK: - Calendars Tab
    static var settingsSystemCalendar: String { _s("settings_system_calendar") }
    static var settingsConnected: String { _s("settings_connected") }
    static var settingsTapToConnect: String { _s("settings_tap_to_connect") }
    static var settingsTwoWaySync: String { _s("settings_two_way_sync") }
    static var settingsTwoWaySyncDesc: String { _s("settings_two_way_sync_desc") }
    
    // MARK: - Customization Tab
    static var settingsAppearanceLabel: String { _s("settings_appearance_label") }
    static var settingsInteractions: String { _s("settings_interactions") }
    static var settingsDockMagnification: String { _s("settings_dock_magnification") }
    static var settingsDockMagnificationDesc: String { _s("settings_dock_magnification_desc") }
    static var settingsAIModelLabel: String { _s("settings_ai_model_label") }
    static var settingsAIModelDesc2: String { _s("settings_ai_model_desc_2") }
    static var settingsWellness: String { _s("settings_wellness") }
    static var settingsSleepCalculator: String { _s("settings_sleep_calculator") }
    static var settingsSleepCalcDesc: String { _s("settings_sleep_calc_desc") }
    static var settingsLanguage: String { _s("settings_language") }
    static var settingsLanguageDesc: String { _s("settings_language_desc") }
    
    // MARK: - Advanced Tab
    static var settingsNotificationsLabel: String { _s("settings_notifications_label") }
    static var settingsRemindersLabel: String { _s("settings_reminders_label") }
    static var settingsSoundLabel: String { _s("settings_sound_label") }
    static var settingsAISkillsLabel: String { _s("settings_ai_skills_label") }
    static var settingsCalendarSkill: String { _s("settings_calendar_skill") }
    static var settingsMailSkill: String { _s("settings_mail_skill") }
    static var settingsDeepAnalysis: String { _s("settings_deep_analysis") }
    static var settingsVoiceInputLabel: String { _s("settings_voice_input_label") }
    static var settingsTelegram: String { _s("settings_telegram") }
    static var settingsWhatsApp: String { _s("settings_whatsapp") }
    static var settingsConfigureMessengers: String { _s("settings_configure_messengers") }
    static var settingsConfigureMessengersDesc: String { _s("settings_configure_messengers_desc") }
    static var settingsDataManagement: String { _s("settings_data_management") }
    static var settingsExportData: String { _s("settings_export_data") }
    static var settingsImportData: String { _s("settings_import_data") }
    static var settingsClearCompletedLabel: String { _s("settings_clear_completed_label") }
    static var settingsStatistics: String { _s("settings_statistics") }
    static var settingsTotal: String { _s("settings_total") }
    static var settingsDone: String { _s("settings_done") }
    static var settingsInbox: String { _s("settings_inbox") }
    static var settingsAboutLabel: String { _s("settings_about_label") }
    static var settingsVersionLabel: String { _s("settings_version_label") }
    static var settingsBuildLabel: String { _s("settings_build_label") }
    static var settingsReplayOnboarding: String { _s("settings_replay_onboarding") }
    static var settingsClearCompletedConfirm: String { _s("settings_clear_completed_confirm") }
    static var settingsNoAccess: String { _s("settings_no_access") }
    static var settingsFileSelectionError: String { _s("settings_file_selection_error") }
    static var settingsImportLabel: String { _s("settings_import_label") }
    
    // MARK: - Help Tab
    static var settingsHelpFeedbackTitle: String { _s("settings_help_feedback_title") }
    static var settingsUserGuide: String { _s("settings_user_guide") }
    static var settingsUserGuideDesc: String { _s("settings_user_guide_desc") }
    static var settingsContactSupport: String { _s("settings_contact_support") }
    static var settingsContactSupportDesc: String { _s("settings_contact_support_desc") }
    static var settingsRateAppStore: String { _s("settings_rate_app_store") }
    static var settingsRateAppStoreDesc: String { _s("settings_rate_app_store_desc") }
    static var settingsReportBug: String { _s("settings_report_bug") }
    static var settingsReportBugDesc: String { _s("settings_report_bug_desc") }
    
    // MARK: - Privacy Tab
    static var settingsPrivacyTitle: String { _s("settings_privacy_title") }
    static var settingsPrivacyDesc: String { _s("settings_privacy_desc") }
    static var settingsDataHandling: String { _s("settings_data_handling") }
    static var settingsLocalStorage: String { _s("settings_local_storage") }
    static var settingsLocalStorageDesc: String { _s("settings_local_storage_desc") }
    static var settingsICloudSync: String { _s("settings_icloud_sync") }
    static var settingsICloudSyncDesc: String { _s("settings_icloud_sync_desc") }
    static var settingsAIProcessing: String { _s("settings_ai_processing") }
    static var settingsAIProcessingDesc: String { _s("settings_ai_processing_desc") }
    static var settingsLocationData: String { _s("settings_location_data") }
    static var settingsLocationDataDesc: String { _s("settings_location_data_desc") }
    static var settingsActive: String { _s("settings_active") }
    static var settingsOptional: String { _s("settings_optional") }
    static var settingsNever: String { _s("settings_never") }
    static var settingsLegal: String { _s("settings_legal") }
    static var settingsTerms: String { _s("settings_terms") }
    static var settingsPrivacyPolicy: String { _s("settings_privacy_policy") }
    static var settingsDataProcessing: String { _s("settings_data_processing") }
    static var settingsYourRights: String { _s("settings_your_rights") }
    static var settingsExportYourData: String { _s("settings_export_your_data") }
    static var settingsExportYourDataDesc: String { _s("settings_export_your_data_desc") }
    static var settingsDeleteAllDataLabel: String { _s("settings_delete_all_data_label") }
    static var settingsDeleteAllDataLabelDesc: String { _s("settings_delete_all_data_label_desc") }
    
    // MARK: - Log Out Tab
    static var settingsLogOutTitle: String { _s("settings_log_out_title") }
    static var settingsLogOutDesc: String { _s("settings_log_out_desc") }
    static var settingsLogOutAction: String { _s("settings_log_out_action") }
    
    // MARK: - Timeline Gap Messages
    static var almostTime: String { _s("gap_almost_time") }
    static var quickBreak: String { _s("gap_quick_break") }
    static var timeForFocus: String { _s("gap_time_for_focus") }
    static var aCanvasForIdeas: String { _s("gap_canvas_for_ideas") }
    static var plentyOfTime: String { _s("gap_plenty_of_time") }
    
    // MARK: - Improved Empty States
    static var emptyDayDescription: String { _s("empty_day_description") }
    static var inboxTitle: String { _s("inbox_title") }
    static var inboxEmptyDescription: String { _s("inbox_empty_description") }
    static var newInboxTask: String { _s("new_inbox_task") }
    
    // MARK: - Suggestions
    static var suggestions: String { _s("suggestions") }
    
    // MARK: - App Modes
    static var modeWork: String { _s("mode_work") }
    static var modePersonal: String { _s("mode_personal") }
    
    // MARK: - Navigation Sections (localized display names)
    static var sectionProjects: String { _s("section_projects") }
    static var sectionHealth: String { _s("section_health") }
    
    // MARK: - Sidebar
    static var profile: String { _s("profile") }
    static var hideSidebar: String { _s("hide_sidebar") }
    static var hidePanel: String { _s("hide_panel") }
    
    // MARK: - AI Command Bar
    static var askJarvis: String { _s("ask_jarvis") }
    static var openFullChat: String { _s("open_full_chat") }
    static var stopRecording: String { _s("stop_recording") }
    static var voiceCommand: String { _s("voice_command") }
    static var chipBriefing: String { _s("chip_briefing") }
    static var chipSearch: String { _s("chip_search") }
    static var chipDayOverview: String { _s("chip_day_overview") }
    static var chipCoach: String { _s("chip_coach") }
    static var chipDelegate: String { _s("chip_delegate") }
    static var promptBriefing: String { _s("prompt_briefing") }
    static var promptSearch: String { _s("prompt_search") }
    static var promptDayOverview: String { _s("prompt_day_overview") }
    static var promptCoach: String { _s("prompt_coach") }
    static var promptDelegate: String { _s("prompt_delegate") }
    static var openInChat: String { _s("open_in_chat") }
    
    // MARK: - Greetings
    static var greetingNight: String { _s("greeting_night") }
    static var greetingMorning: String { _s("greeting_morning") }
    static var greetingAfternoon: String { _s("greeting_afternoon") }
    static var greetingEvening: String { _s("greeting_evening") }
    static var defaultUserName: String { _s("default_user_name") }
    static var jarvisHelperSubtitle: String { _s("jarvis_helper_subtitle") }
    
    // MARK: - AI Chat
    static var hide: String { _s("hide") }
    static var voiceControlTitle: String { _s("voice_control_title") }
    static var voiceControlSubtitle: String { _s("voice_control_subtitle") }
    static var listening: String { _s("listening") }
    static var thinking: String { _s("thinking") }
    static var messageOrVoice: String { _s("message_or_voice") }
    static var gatheringData: String { _s("gathering_data") }
    static var updatedAt: String { _s("updated_at") }
    static var tapRefreshDigest: String { _s("tap_refresh_digest") }
    
    // MARK: - Analytics Motivational
    static var streakMotivation0: String { _s("streak_motivation_0") }
    static var streakMotivation1: String { _s("streak_motivation_1") }
    static var streakMotivation7: String { _s("streak_motivation_7") }
    static var streakMotivation14: String { _s("streak_motivation_14") }
    static var streakMotivation21: String { _s("streak_motivation_21") }
    static var streakMotivation30: String { _s("streak_motivation_30") }
    static var noTasksAdvice: String { _s("no_tasks_advice") }
    static var peakProductivity: String { _s("peak_productivity") }
    static var adviceGreat: String { _s("advice_great") }
    static var adviceGood: String { _s("advice_good") }
    static var adviceMany: String { _s("advice_many") }
    static var adviceFew: String { _s("advice_few") }
    
    // MARK: - Timeline
    static var currentTime: String { _s("current_time") }
    
    // MARK: - Projects
    static var projectsTitle: String { _s("projects_title") }
    static var archiveCount: String { _s("archive_count") }
    static var noProjects: String { _s("no_projects") }
    static var noProjectsDesc: String { _s("no_projects_desc") }
    static var createProject: String { _s("create_project") }
    static var moreItems: String { _s("more_items") }
    static var unarchive: String { _s("unarchive") }
    static var archive: String { _s("archive") }
    static var titleField: String { _s("title_field") }
    static var projectNamePlaceholder: String { _s("project_name_placeholder") }
    static var descriptionField: String { _s("description_field") }
    static var descriptionPlaceholder: String { _s("description_placeholder") }
    static var colorField: String { _s("color_field") }
    static var iconField: String { _s("icon_field") }
    static var newProject: String { _s("new_project") }
    static var edit: String { _s("edit") }
    static var save: String { _s("save") }
    static var subtasks: String { _s("subtasks") }
    static var addSubtask: String { _s("add_subtask") }
    
    // MARK: - Messenger Settings
    static var messengersTitle: String { _s("messengers_title") }
    static var close: String { _s("close") }
    static var telegramAPIDesc: String { _s("telegram_api_desc") }
    static var telegramGetKeys: String { _s("telegram_get_keys") }
    static var phoneNumber: String { _s("phone_number") }
    static var connect: String { _s("connect") }
    static var sendCode: String { _s("send_code") }
    static var codeSentDesc: String { _s("code_sent_desc") }
    static var confirmationCode: String { _s("confirmation_code") }
    static var confirm: String { _s("confirm") }
    static var twoFADesc: String { _s("two_fa_desc") }
    static var twoFAPassword: String { _s("two_fa_password") }
    static var connected: String { _s("connected") }
    static var selectChats: String { _s("select_chats") }
    static var disconnect: String { _s("disconnect") }
    static var selectChatsForMonitoring: String { _s("select_chats_monitoring") }
    static var loadingChats: String { _s("loading_chats") }
    static var greenAPIDesc: String { _s("green_api_desc") }
    static var greenAPIRegister: String { _s("green_api_register") }
    static var greenAPIScanQR: String { _s("green_api_scan_qr") }
    static var checkingConnection: String { _s("checking_connection") }
    static var dataSavedChecking: String { _s("data_saved_checking") }
    static var checkStatus: String { _s("check_status") }
    static var noChatsAvailable: String { _s("no_chats_available") }
    static var statusDisconnected: String { _s("status_disconnected") }
    static var statusConnecting: String { _s("status_connecting") }
    static var statusConnected: String { _s("status_connected") }
    static var statusError: String { _s("status_error") }
    static var chatTypePrivate: String { _s("chat_type_private") }
    static var chatTypeGroup: String { _s("chat_type_group") }
    static var chatTypeSupergroup: String { _s("chat_type_supergroup") }
    static var chatTypeChannel: String { _s("chat_type_channel") }
    static var errorSaveSettings: String { _s("error_save_settings") }
    static var errorBackendConnection: String { _s("error_backend_connection") }
    static var errorUnknown: String { _s("error_unknown") }
    static var errorConnection: String { _s("error_connection") }
    static var errorAuth: String { _s("error_auth") }
    static var errorLoadChats: String { _s("error_load_chats") }
    
    // MARK: - Calendar & Mail
    static var checking: String { _s("checking") }
    static var retry: String { _s("retry") }
    static var noEvents: String { _s("no_events") }
    static var noMails: String { _s("no_mails") }
    static var connectGoogle: String { _s("connect_google") }
    static var connectGoogleDesc: String { _s("connect_google_desc") }
    static var signInGoogle: String { _s("sign_in_google") }
    static var authRequired: String { _s("auth_required") }
    
    // MARK: - Sleep Calculator
    static var sleepCalcWakeUp: String { _s("sleep_calc_wake_up") }
    static var sleepCalcBedtime: String { _s("sleep_calc_bedtime") }
    static var sleepCalcMode: String { _s("sleep_calc_mode") }
    static var sleepCalcWakeQuestion: String { _s("sleep_calc_wake_question") }
    static var sleepCalcBedQuestion: String { _s("sleep_calc_bed_question") }
    static var sleepCalcRecommendedBed: String { _s("sleep_calc_recommended_bed") }
    static var sleepCalcRecommendedWake: String { _s("sleep_calc_recommended_wake") }
    static var sleepCalcAvgFallAsleep: String { _s("sleep_calc_avg_fall_asleep") }
    static var sleepCalcCycleDuration: String { _s("sleep_calc_cycle_duration") }
    static var sleepCalcOptimalCycles: String { _s("sleep_calc_optimal_cycles") }
    static var sleepCalcOptimal: String { _s("sleep_calc_optimal") }
    static var sleepCycleSingular: String { _s("sleep_cycle_singular") }
    static var sleepCycleFew: String { _s("sleep_cycle_few") }
    static var sleepCycleMany: String { _s("sleep_cycle_many") }
    
    // MARK: - Profile
    static var profileName: String { _s("profile_name") }
    static var profileNamePlaceholder: String { _s("profile_name_placeholder") }
    static var profileEmailPlaceholder: String { _s("profile_email_placeholder") }
    static var profileStats: String { _s("profile_stats") }
    static var profileSuccess: String { _s("profile_success") }
    static var profileTitle: String { _s("profile_title") }
    
    // MARK: - Task Sheets Duration
    static var duration15min: String { _s("duration_15min") }
    static var duration30min: String { _s("duration_30min") }
    static var duration45min: String { _s("duration_45min") }
    static var duration1h: String { _s("duration_1h") }
    static var duration1h30: String { _s("duration_1h30") }
    static var duration2h: String { _s("duration_2h") }
    
    // MARK: - Wellness Models
    static var mealBreakfast: String { _s("meal_breakfast") }
    static var mealLunch: String { _s("meal_lunch") }
    static var mealDinner: String { _s("meal_dinner") }
    static var mealSnack: String { _s("meal_snack") }
    static var sleepQualityBad: String { _s("sleep_quality_bad") }
    static var sleepQualityNormal: String { _s("sleep_quality_normal") }
    static var sleepQualityGood: String { _s("sleep_quality_good") }
    static var sleepQualityExcellent: String { _s("sleep_quality_excellent") }
    
    // MARK: - Export/Import
    static var exportReadError: String { _s("export_read_error") }
    static var exportMergeComplete: String { _s("export_merge_complete") }
    static var exportImported: String { _s("export_imported") }
    
    // MARK: - Messenger Share
    static var shareDayPlan: String { _s("share_day_plan") }
    static var shareSingleTask: String { _s("share_single_task") }
    static var shareModePicker: String { _s("share_mode_picker") }
    static var shareNoTasks: String { _s("share_no_tasks") }
    static var shareTitle: String { _s("share_title") }
    static var shareSent: String { _s("share_sent") }
    static var allDay: String { _s("all_day") }
    
    // MARK: - Voice commands
    static var voiceCommandJarvis: String { _s("voice_command_jarvis") }
    static var voiceCommandHint: String { _s("voice_command_hint") }
    
    // MARK: - Common Actions
    static var delete: String { _s("delete") }
    
    // MARK: - Calendar
    static var calendarTitle: String { _s("calendar_title") }
    static var connectGoogleCalDesc: String { _s("connect_google_cal_desc") }
    
    // MARK: - Mail
    static var mailTitle: String { _s("mail_title") }
    static var connectGoogleMailDesc: String { _s("connect_google_mail_desc") }
    static var noSubject: String { _s("no_subject") }
    
    // MARK: - Profile Extra
    static var statsTotal: String { _s("stats_total") }
    static var statsDone: String { _s("stats_done") }
    static var statsSuccess: String { _s("stats_success") }
    static var hoursShort: String { _s("hours_short") }
    static var sleepCalcTitle: String { _s("sleep_calc_title") }
    static var sleepOptimalLabel: String { _s("sleep_optimal_label") }
    static var email: String { _s("email") }
    
    // MARK: - Task Sheets Extra
    static var date: String { _s("date") }
    static var time: String { _s("time") }
    static var notesPlaceholder: String { _s("notes_placeholder") }
    static var updateTask: String { _s("update_task") }
    
    // MARK: - AI Chat Extra
    static var aiDigest: String { _s("ai_digest") }
    static var aiDigestTitle: String { _s("ai_digest_title") }
    static var aiDigestHelp: String { _s("ai_digest_help") }
    static var digestCalendar: String { _s("digest_calendar") }
    static var digestMail: String { _s("digest_mail") }
    static var digestMessengers: String { _s("digest_messengers") }
    static var digestGenerated: String { _s("digest_generated") }
    static var digestFullVersion: String { _s("digest_full_version") }
    static var upcomingEvents: String { _s("upcoming_events") }
    static var latestEmails: String { _s("latest_emails") }
    
    // MARK: - Voice Hints
    static var voiceHint1: String { _s("voice_hint_1") }
    static var voiceHint2: String { _s("voice_hint_2") }
    static var voiceHint3: String { _s("voice_hint_3") }
    static var voiceHint4: String { _s("voice_hint_4") }
    static var voiceHint5: String { _s("voice_hint_5") }
    static var voiceHint6: String { _s("voice_hint_6") }
    static var voiceHint7: String { _s("voice_hint_7") }
    static var voiceHint8: String { _s("voice_hint_8") }
    
    // MARK: - Messenger Settings Extra
    static var telegramAPIKeysSaved: String { _s("telegram_api_keys_saved") }
    static var telegram2FAHint: String { _s("telegram_2fa_hint") }
    static var chatsMonitored: String { _s("chats_monitored") }
    static var whatsappGreenAPIDesc: String { _s("whatsapp_green_api_desc") }
    static var whatsappRegisterGreenAPI: String { _s("whatsapp_register_green_api") }
    static var whatsappScanQRHint: String { _s("whatsapp_scan_qr_hint") }
    static var whatsappCheckingAuth: String { _s("whatsapp_checking_auth") }
    static var whatsappNoChats: String { _s("whatsapp_no_chats") }
    static var errorApiIdNumber: String { _s("error_api_id_number") }
    static var errorSaveSettingsBackend: String { _s("error_save_settings_backend") }
    static var errorLoadChatsQR: String { _s("error_load_chats_qr") }
    
    // MARK: - AI Services
    static var nothingFound: String { _s("nothing_found") }
    static var coachError: String { _s("coach_error") }
    
    // MARK: - AI Life Coach Categories
    static var coachFitness: String { _s("coach_fitness") }
    static var coachNutrition: String { _s("coach_nutrition") }
    static var coachLearning: String { _s("coach_learning") }
    static var coachMeditation: String { _s("coach_meditation") }
    static var coachOther: String { _s("coach_other") }
    static var coachSleep: String { _s("coach_sleep") }
    static var coachProductivity: String { _s("coach_productivity") }
    static var coachMotivation: String { _s("coach_motivation") }
    static var coachHealth: String { _s("coach_health") }
    
    // MARK: - Navigation Sections Extra (Sidebar display names)
    static var sectionCalendar: String { _s("section_calendar") }
    static var sectionMail: String { _s("section_mail") }
    
    // MARK: - Sidebar Extra
    static var sleepCalculator: String { _s("sleep_calculator") }
    static var totalTasks: String { _s("total_tasks") }
    
    // MARK: - Messenger Share Extra
    static var shareClose: String { _s("share_close") }
    static var shareMinutes: String { _s("share_minutes") }
    static var sharePriority: String { _s("share_priority") }
    static var shareSentFrom: String { _s("share_sent_from") }
    static var sharePlanFor: String { _s("share_plan_for") }
    static var shareCompleted: String { _s("share_completed") }
    static var shareOpenedIn: String { _s("share_opened_in") }
    static var shareWebOpened: String { _s("share_web_opened") }
    static var shareNotInstalled: String { _s("share_not_installed") }
    
    // MARK: - Food Fallback
    static var defaultDish: String { _s("default_dish") }
}
