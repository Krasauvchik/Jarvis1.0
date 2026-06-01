import SwiftUI

// MARK: - App Router (replaces if-else chain in StructuredMainView)
// Inspired by Structured's StructuredRouter module — clean separation of navigation logic.

/// Centralized section → View routing. Adding a new section only requires adding a case here.
@MainActor
enum AppRouter {
    
    /// Returns the destination view for a given navigation section in the detail column.
    /// - Parameters:
    ///   - section: The navigation section to route to.
    ///   - dependencies: DI container from environment.
    ///   - theme: Current resolved theme.
    ///   - store: The planner data store.
    ///   - selectedDate: Binding to the currently selected date.
    ///   - editingTask: Binding to trigger task editing.
    ///   - wellness: Wellness store for health view.
    /// - Returns: The appropriate destination view.
    @ViewBuilder
    static func destination(
        for section: NavigationSection,
        dependencies: DependencyContainer,
        theme: JarvisTheme,
        store: PlannerStore,
        selectedDate: Binding<Date>,
        editingTask: Binding<PlannerTask?>,
        wellness: WellnessStore,
        toggleTask: @escaping (PlannerTask) -> Void
    ) -> some View {
        switch section {
        case .chat:
            AIChatView(aiManager: dependencies.aiManager)
                .frame(maxWidth: .infinity)
            
        case .calendarSection:
            #if !os(watchOS)
            CalendarView()
                .frame(maxWidth: .infinity)
            #endif
            
        case .mailSection:
            #if !os(watchOS)
            MailView()
                .frame(maxWidth: .infinity)
            #endif
            
        case .messengers:
            #if !os(watchOS)
            ScrollView {
                VStack(spacing: 24) {
                    TelegramSetupSection()
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
            #endif
            
        case .analytics:
            #if !os(watchOS)
            ChartAnalyticsView(aiManager: dependencies.aiManager)
                .frame(maxWidth: .infinity)
            #endif
            
        case .health:
            #if !os(watchOS)
            WellnessView(store: store, wellness: wellness, aiManager: dependencies.aiManager)
                .frame(maxWidth: .infinity)
            #endif
            
        case .projects:
            #if !os(watchOS)
            ProjectsView()
                .frame(maxWidth: .infinity)
            #endif
            
        case .kanban:
            #if !os(watchOS)
            KanbanView(store: store)
                .frame(maxWidth: .infinity)
            #endif
            
        case .templates:
            #if !os(watchOS)
            TaskTemplatesView(store: store)
                .frame(maxWidth: .infinity)
            #endif
            
        case .habits:
            #if !os(watchOS)
            HabitTrackerView(theme: theme)
                .frame(maxWidth: .infinity)
            #endif
            
        case .focus:
            #if !os(watchOS)
            FocusTimerView(theme: theme, store: store)
                .frame(maxWidth: .infinity)
            #endif
            
        case .systemCalendar:
            #if !os(watchOS)
            EventKitCalendarView(theme: theme, store: store)
                .frame(maxWidth: .infinity)
            #endif
            
        case .registries:
            #if !os(watchOS)
            RegistryListView()
                .frame(maxWidth: .infinity)
            #endif
            
        // Task-list sections are handled by the caller (taskListPanel + timeline)
        case .inbox, .today, .scheduled, .futurePlans, .completed, .all:
            EmptyView() // Caller should use isTaskListSection() check
        }
    }
    
    /// Whether this section shows the task list + timeline panels (not a full-width view).
    static func isTaskListSection(_ section: NavigationSection) -> Bool {
        switch section {
        case .inbox, .today, .scheduled, .futurePlans, .completed, .all:
            return true
        default:
            return false
        }
    }
    
    /// Section subtitle text for the task list header.
    static func subtitle(for section: NavigationSection, taskCount: Int) -> String {
        switch section {
        case .inbox:       return "\(taskCount) \(L10n.tasksForPlanning)"
        case .today:       return Date().formatted(.dateTime.weekday(.wide).day().month())
        case .scheduled:   return "\(taskCount) \(L10n.scheduledCount)"
        case .futurePlans: return "\(taskCount) \(L10n.futurePlansCount)"
        case .completed:   return "\(taskCount) \(L10n.completedCount)"
        case .all:         return "\(taskCount) \(L10n.totalTasks)"
        case .calendarSection: return "Google Calendar"
        case .mailSection: return "Gmail"
        case .messengers:  return "WhatsApp & Telegram"
        case .analytics:   return L10n.chartsTrends
        case .health:      return L10n.subtitleWellness
        case .projects:    return L10n.subtitleProjects
        case .chat:        return L10n.chatWithAI
        case .kanban:      return L10n.kanbanBoard
        case .templates:   return L10n.templates
        case .habits:      return L10n.habitsSubtitle
        case .focus:       return L10n.focusTitle
        case .systemCalendar: return L10n.systemCalendarSubtitle
        case .registries:  return L10n.registries
        }
    }
    
    /// Empty state text when a task list section has no tasks.
    static func emptyStateText(for section: NavigationSection) -> String {
        switch section {
        case .inbox:       return L10n.inboxEmpty
        case .today:       return L10n.noTasksToday
        case .scheduled:   return L10n.noScheduled
        case .futurePlans: return L10n.noFuturePlans
        case .completed:   return L10n.noCompleted
        case .all:         return L10n.noTasks
        case .calendarSection: return L10n.calendarSectionLabel
        case .mailSection: return L10n.mailSectionLabel
        default:           return ""
        }
    }
    
    /// Maps a NavigationSection to iPhone tab index.
    static func tabIndex(for section: NavigationSection) -> Int? {
        switch section {
        case .today:           return 0
        case .inbox:           return 1
        case .mailSection:     return 2
        case .chat:            return 3
        case .analytics:       return 4
        default:               return nil
        }
    }
}
