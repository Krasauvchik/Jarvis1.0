import SwiftUI
import Combine
#if os(iOS)
import UniformTypeIdentifiers
import UIKit
#endif

// MARK: - Main Structured View

struct StructuredMainView: View {
    @Environment(\.dependencies) private var dependencies
    @EnvironmentObject private var deepLinkManager: DeepLinkManager
    @StateObject private var store = PlannerStore.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var userProfile = UserProfile.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedDate = Date()
    @State private var selectedSection: NavigationSection = .today
    @State private var showAddTask = false
    @State private var showSettings = false
    @State private var showProfile = false
    @State private var showSleepCalculator = false
    @State private var selectedTab = 0
    @State private var editingTask: PlannerTask?
    @State private var draggedTask: PlannerTask?
    @State private var searchQuery = ""
    @State private var completedDropHighlighted = false
    @State private var showMessengerShare = false
    @State private var showMonthCalendar = false
    @State private var showAIFullChat = false
    
    // App Mode (Work / Personal)
    @AppStorage("jarvis_app_mode") private var appModeRaw: String = AppMode.work.rawValue
    @StateObject private var wellness = WellnessStore()
    
    private var appMode: AppMode {
        get { AppMode(rawValue: appModeRaw) ?? .work }
    }
    private var appModeBinding: Binding<AppMode> {
        Binding(
            get: { AppMode(rawValue: appModeRaw) ?? .work },
            set: { appModeRaw = $0.rawValue }
        )
    }
    
    // Размеры колонок (только iPad/Mac) — сохраняются между запусками
    @AppStorage("jarvis_sidebar_width") private var sidebarWidth: Double = 200
    @AppStorage("jarvis_tasklist_width") private var taskListWidth: Double = 320
    @AppStorage("jarvis_sidebar_hidden") private var leftPanelHidden: Bool = false
    
    private var theme: JarvisTheme {
        JarvisTheme.current(for: themeManager.currentTheme.colorScheme ?? colorScheme)
    }
    
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }
    #elseif os(watchOS)
    private var isCompact: Bool { true }
    #else
    private var isCompact: Bool { false }
    #endif
    
    var body: some View {
        Group {
            #if os(watchOS)
            watchOSLayout
            #else
            if isCompact {
                iPhoneLayout
            } else {
                threeColumnWithAIBar
            }
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 900, minHeight: 600)
        #endif
        #if !os(watchOS)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        #endif
        .sheet(isPresented: $showAddTask) {
            AddTaskSheet(date: selectedDate, theme: theme)
        }
        .sheet(item: $editingTask) { task in
            EditTaskSheet(task: task, theme: theme)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(theme: theme)
        }
        .sheet(isPresented: $showProfile) {
            ProfileSheet(theme: theme)
        }
        .sheet(isPresented: $showSleepCalculator) {
            SleepCalculatorSheet(theme: theme)
        }
        .applyTheme(themeManager)
        #if !os(watchOS)
        .onReceive(deepLinkManager.$pendingTaskID.compactMap { $0 }) { taskID in
            if let task = store.tasks.first(where: { $0.id == taskID }) {
                editingTask = task
                deepLinkManager.clearPendingTask()
            }
        }
        .onReceive(deepLinkManager.$pendingSection.compactMap { $0 }) { sectionName in
            if let section = deepLinkManager.resolveSection(sectionName) {
                selectedSection = section
                // Map section to iPhone tab index
                switch section {
                case .today: selectedTab = 0
                case .inbox: selectedTab = 1
                case .calendarSection: selectedTab = 2
                case .mailSection: selectedTab = 3
                case .chat: selectedTab = 4
                case .analytics: selectedTab = 5
                default: break
                }
            }
            deepLinkManager.clearPendingSection()
        }
        .onReceive(deepLinkManager.$pendingAddTask) { show in
            if show {
                showAddTask = true
                deepLinkManager.clearPendingAddTask()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) { leftPanelHidden.toggle() }
        }
        #endif
    }
    
    // MARK: - watchOS Layout
    
    #if os(watchOS)
    private var watchOSLayout: some View {
        NavigationStack {
            List {
                let todayTasks = store.tasksForDay(Date())
                if todayTasks.isEmpty {
                    Text(L10n.noTasks)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(todayTasks) { task in
                        watchTaskRow(task)
                    }
                }
            }
            .navigationTitle("Jarvis")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { showAddTask = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
    
    private func watchTaskRow(_ task: PlannerTask) -> some View {
        HStack {
            Circle()
                .fill(task.taskColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading) {
                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.isCompleted)
                if !task.isAllDay {
                    Text(task.date.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Button(action: { toggleTask(task) }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.taskColor)
            }
            .buttonStyle(.plain)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.title)\(task.isCompleted ? ", \(L10n.completed)" : "")")
        .accessibilityHint(L10n.swipeToDelete)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                dependencies.calendarSyncService.removeEvent(for: task)
                store.delete(task)
            } label: {
                Label(L10n.deleteTask, systemImage: "trash")
            }
        }
    }
    #endif
    
    // MARK: - iPhone Layout
    
    #if !os(watchOS)
    private var iPhoneLayout: some View {
        VStack(spacing: 0) {
            // Mode toggle at top
            iPhoneModeToggle
            
            TabView(selection: $selectedTab) {
                if appMode == .work {
                    todayTab
                        .tabItem { Label(L10n.tabToday, systemImage: "calendar") }
                        .tag(0)
                    
                    inboxTab
                        .tabItem { Label(L10n.tabInbox, systemImage: "tray.fill") }
                        .tag(1)
                    
                    calendarTab
                        .tabItem { Label(L10n.tabCalendar, systemImage: "calendar.circle") }
                        .tag(2)
                    
                    mailTab
                        .tabItem { Label(L10n.tabMail, systemImage: "envelope.fill") }
                        .tag(3)
                    
                    neuralTab
                        .tabItem { Label(L10n.tabAI, systemImage: "brain.head.profile") }
                        .tag(4)
                    
                    analyticsTab
                        .tabItem { Label(L10n.tabAnalytics, systemImage: "chart.bar.xaxis") }
                        .tag(5)
                    
                    settingsTab
                        .tabItem { Label(L10n.tabSettings, systemImage: "gearshape.fill") }
                        .tag(6)
                } else {
                    // Personal mode
                    todayTab
                        .tabItem { Label(L10n.tabToday, systemImage: "calendar") }
                        .tag(0)
                    
                    healthTab
                        .tabItem { Label(L10n.healthTitle, systemImage: "heart.text.square.fill") }
                        .tag(10)
                    
                    calendarTab
                        .tabItem { Label(L10n.tabCalendar, systemImage: "calendar.circle") }
                        .tag(2)
                    
                    settingsTab
                        .tabItem { Label(L10n.tabSettings, systemImage: "gearshape.fill") }
                        .tag(6)
                }
            }
            .tint(appMode.color)
            
            // Inline AI Command Bar — under tabs, above tab bar
            AICommandBar(aiManager: dependencies.aiManager)
        }
    }
    
    private var iPhoneModeToggle: some View {
        HStack(spacing: 0) {
            ForEach(AppMode.allCases) { mode in
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        appModeRaw = mode.rawValue
                        selectedTab = 0
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(mode.localizedName)
                            .font(.system(size: 12, weight: appMode == mode ? .bold : .medium))
                    }
                    .foregroundColor(appMode == mode ? .white : JarvisTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(appMode == mode ? mode.color : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(JarvisTheme.cardBackground))
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }
    
    // MARK: - Three Column Layout (iPad/Mac) — колонки меняют размер, левую можно скрыть
    
    private var threeColumnLayout: some View {
        HStack(spacing: 0) {
            if !leftPanelHidden {
                SidebarView(
                    theme: theme,
                    selectedSection: $selectedSection,
                    appMode: appModeBinding,
                    store: store,
                    onHide: { withAnimation(.easeInOut(duration: 0.2)) { leftPanelHidden = true } },
                    onShowSleepCalculator: { showSleepCalculator = true },
                    onShowSettings: { showSettings = true },
                    onShowProfile: { showProfile = true }
                )
                .frame(width: Swift.max(160, Swift.min(400, sidebarWidth)))
                .layoutPriority(1)
                ColumnResizer(
                    theme: theme,
                    width: $sidebarWidth,
                    min: 160,
                    max: 400
                )
            }
            
            if selectedSection == .chat {
                AIChatView(aiManager: dependencies.aiManager)
                    .frame(maxWidth: .infinity)
            } else if selectedSection == .calendarSection {
                #if !os(watchOS)
                CalendarView()
                    .frame(maxWidth: .infinity)
                #endif
            } else if selectedSection == .mailSection {
                #if !os(watchOS)
                MailView()
                    .frame(maxWidth: .infinity)
                #endif
            } else if selectedSection == .messengers {
                #if !os(watchOS)
                MessengerShareSheet(
                    tasks: store.tasksForDay(selectedDate).filter { !$0.isCompleted },
                    date: selectedDate
                )
                .frame(maxWidth: .infinity)
                #endif
            } else if selectedSection == .analytics {
                #if !os(watchOS)
                ChartAnalyticsView(aiManager: dependencies.aiManager)
                    .frame(maxWidth: .infinity)
                #endif
            } else if selectedSection == .health {
                #if !os(watchOS)
                WellnessView(store: store, wellness: wellness, aiManager: dependencies.aiManager)
                    .frame(maxWidth: .infinity)
                #endif
            } else if selectedSection == .projects {
                #if !os(watchOS)
                ProjectsView()
                    .frame(maxWidth: .infinity)
                #endif
            } else {
                taskListPanel
                    .frame(width: Swift.max(240, Swift.min(500, taskListWidth)))
                ColumnResizer(
                    theme: theme,
                    width: $taskListWidth,
                    min: 240,
                    max: 500
                )
                TimelinePanelView(
                    theme: theme,
                    selectedDate: $selectedDate,
                    store: store,
                    onEditTask: { editingTask = $0 },
                    onToggleTask: { toggleTask($0) }
                )
                .frame(minWidth: 320)
            }
        }
        .background(theme.background)
        .overlay(alignment: .leading) {
            if leftPanelHidden {
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { leftPanelHidden = false } }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 18))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 28, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.showSidebar)
                .padding(.leading, 8)
            }
        }
    }
    
    // MARK: - Three Column + AI Bar (iPad/Mac)
    
    private var threeColumnWithAIBar: some View {
        VStack(spacing: 0) {
            threeColumnLayout
            // Inline AI Command Bar — bottom of window, not overlay
            AICommandBar(aiManager: dependencies.aiManager)
        }
    }
    
    // MARK: - Resizable Column Divider (перетаскивание меняет ширину соседней колонки слева)

    private struct ColumnResizer: View {
        let theme: JarvisTheme
        @Binding var width: Double
        let min: CGFloat
        let max: CGFloat
        @State private var dragStartWidth: CGFloat?
        @State private var isHovered = false

        private let visibleWidth: CGFloat = 4
        private let hitAreaWidth: CGFloat = 14

        var body: some View {
            ZStack {
                Color.clear.frame(width: hitAreaWidth)
                RoundedRectangle(cornerRadius: 2)
                    .fill(isHovered ? theme.divider : theme.divider.opacity(0.4))
                    .frame(width: visibleWidth)
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
            }
            .frame(width: hitAreaWidth)
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            #if os(macOS)
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    NSCursor.resizeLeftRight.push()
                case .ended:
                    NSCursor.pop()
                }
            }
            #endif
            .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            if dragStartWidth == nil { dragStartWidth = CGFloat(width) }
                            let base = dragStartWidth ?? CGFloat(width)
                            let newWidth = base + value.translation.width
                            width = Double(Swift.min(Swift.max(newWidth, min), max))
                        }
                        .onEnded { _ in
                            dragStartWidth = nil
                        }
                )
        }
    }

    // MARK: - Task List Panel
    
    private var taskListPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedSection.localizedName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                    
                    Text(sectionSubtitle)
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondary)
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedSection)
                
                Spacer()
                
                Button(action: { showAddTask = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(selectedSection.color)
                }
                .buttonStyle(.plain)
                .bounceOnTap()
                .accessibilityLabel(L10n.addTask)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            
            Divider().background(theme.divider)
            
            // Search (поиск по задачам)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(theme.textTertiary)
                TextField(L10n.searchTasks, text: $searchQuery)
                    .textFieldStyle(.plain)
                    .accessibilityLabel(L10n.searchTasks)
                    .accessibilityHint(L10n.searchHint)
                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.clearSearch)
                }
            }
            .padding(10)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            // Task List
            ScrollView {
                LazyVStack(spacing: 4) {
                    let tasks = filteredTasksForCurrentSection
                    
                    if tasks.isEmpty {
                        emptyStateForSection
                            .padding(.top, 60)
                    } else {
                        ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                            taskListRow(task)
                                .animateOnAppear(delay: Double(index) * 0.05)
                                .transition(.taskRowTransition)
                        }
                    }
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.75), value: filteredTasksForCurrentSection.map(\.id))
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
            
            Spacer()
            
            // Add Button
            Button(action: { showAddTask = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text(L10n.addButton)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(selectedSection.color))
            }
            .buttonStyle(.plain)
            .bounceOnTap()
            .padding(.bottom, 16)
        }
        .background(theme.inboxBackground)
    }
    
    func taskCount(for section: NavigationSection) -> Int {
        store.taskCount(for: section)
    }
    
    private var sectionSubtitle: String {
        let count = taskCount(for: selectedSection)
        switch selectedSection {
        case .inbox:
            return "\(count) задач для планирования"
        case .today:
            return Date().formatted(.dateTime.weekday(.wide).day().month())
        case .scheduled:
            return "\(count) запланированных"
        case .futurePlans:
            return "\(count) на будущее"
        case .completed:
            return "\(count) выполнено"
        case .all:
            return "\(count) всего задач"
        case .calendarSection:
            return "Google Calendar"
        case .mailSection:
            return "Gmail"
        case .messengers:
            return "WhatsApp & Telegram"
        case .analytics:
            return L10n.chartsTrends
        case .health:
            return L10n.subtitleWellness
        case .projects:
            return L10n.subtitleProjects
        case .chat:
            return L10n.chatWithAI
        }
    }
    
    private var tasksForCurrentSection: [PlannerTask] {
        let calendar = Calendar.current
        let startOfTomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        switch selectedSection {
        case .inbox:
            return store.inboxTasks.filter { !$0.isCompleted }
        case .today:
            return store.tasksForDay(Date()).filter { !$0.isCompleted }
        case .scheduled:
            return store.tasks.filter { !$0.isInbox && !$0.isCompleted && $0.date < startOfTomorrow }.sorted { $0.date < $1.date }
        case .futurePlans:
            return store.tasks.filter { !$0.isInbox && !$0.isCompleted && $0.date >= startOfTomorrow }.sorted { $0.date < $1.date }
        case .completed:
            return store.completedTasks
        case .all:
            return store.tasks.sorted { $0.date < $1.date }
        case .calendarSection, .mailSection, .messengers, .analytics, .projects, .chat, .health:
            return []
        }
    }

    private var filteredTasksForCurrentSection: [PlannerTask] {
        let base = tasksForCurrentSection
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter {
            $0.title.lowercased().contains(q) || $0.notes.lowercased().contains(q)
        }
    }
    
    private var emptyStateForSection: some View {
        VStack(spacing: 12) {
            Image(systemName: selectedSection.icon)
                .font(.system(size: 40))
                .foregroundColor(selectedSection.color.opacity(0.5))
            
            Text(emptyStateText)
                .font(.system(size: 15))
                .foregroundColor(theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .animateOnAppear(delay: 0.1)
    }
    
    private var emptyStateText: String {
        switch selectedSection {
        case .inbox: return L10n.inboxEmpty
        case .today: return L10n.noTasksToday
        case .scheduled: return L10n.noScheduled
        case .futurePlans: return L10n.noFuturePlans
        case .completed: return L10n.noCompleted
        case .all: return L10n.noTasks
        case .calendarSection: return L10n.calendarSectionLabel
        case .mailSection: return L10n.mailSectionLabel
        case .messengers: return ""
        case .analytics: return ""
        case .health: return ""
        case .projects: return ""
        case .chat: return ""
        }
    }
    
    private func taskListRow(_ task: PlannerTask) -> some View {
        HStack(spacing: 12) {
            // Область для тапа «редактировать»
            HStack(spacing: 12) {
                Circle()
                    .fill(task.taskColor)
                    .frame(width: 10, height: 10)
                
                Image(systemName: task.icon.isEmpty ? "star.fill" : task.icon)
                    .font(.system(size: 14))
                    .foregroundColor(task.taskColor)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle().fill(task.taskColor.opacity(0.15))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(task.isCompleted ? theme.textTertiary : task.taskColor)
                        .strikethrough(task.isCompleted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    
                    if !task.isInbox && !task.isAllDay {
                        Text(task.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11))
                            .foregroundColor(theme.textTertiary)
                    }
                }
                
                Spacer(minLength: 0)
                
                if task.isInbox && !task.isCompleted {
                    Button(action: { scheduleTaskToToday(task) }) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 14))
                            .foregroundColor(JarvisTheme.accentOrange)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.scheduleToday)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { editingTask = task }
            
            // Кружок: тап — выполнить/отменить (увеличенная зона нажатия и приоритет жеста)
            ZStack {
                Circle()
                    .stroke(task.taskColor, lineWidth: 2)
                    .frame(width: 24, height: 24)
                if task.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(task.taskColor)
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityLabel(task.isCompleted ? "\(L10n.markIncomplete) \(task.title)" : "\(L10n.markComplete) \(task.title)")
            .accessibilityAddTraits(.isButton)
            .highPriorityGesture(
                TapGesture().onEnded { _ in toggleTask(task) }
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.cardBackground)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(L10n.addTask): \(task.title)")
        .dockMagnificationEffect()
        .contextMenu { taskContextMenu(task) }
        .draggable(task.id.uuidString) {
            HStack {
                Circle().fill(task.taskColor).frame(width: 8, height: 8)
                Text(task.title).font(.system(size: 13))
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(theme.cardBackground))
            .scaleEffect(1.08)
        }
    }
    
    // MARK: - Today Tab (iPhone)
    
    private var todayTab: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 0) {
                        AIWelcomeHeader()
                        dateHeader
                        weekStrip
                        completedDropZone
                        timelineList
                    }
                }
                .background(theme.background)
                
                floatingDualFAB
                
                // Monthly calendar overlay popup
                if showMonthCalendar {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation(.spring(response: 0.3)) { showMonthCalendar = false } }
                    
                    VStack(spacing: 0) {
                        Spacer()
                        monthCalendarPopup
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationTitle("Jarvis")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: { showProfile = true }) {
                        profileAvatar
                    }
                }
            }
        }
    }
    
    // MARK: - Inbox Tab (iPhone)
    
    private var inboxTab: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        let inboxTasks = store.inboxTasks.filter { !$0.isCompleted }
                        
                        if inboxTasks.isEmpty {
                            emptyInboxView
                        } else {
                            ForEach(inboxTasks) { task in
                                inboxTaskRow(task)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
                .background(theme.background)
                
                floatingAddButton
            }
            .navigationTitle("Inbox")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
    }
    
    // MARK: - Completed Tab (iPhone)
    
    private var completedTab: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    let completedTasks = store.completedTasks
                    
                    if completedTasks.isEmpty {
                        emptyCompletedView
                    } else {
                        completedStatsCard
                        
                        ForEach(completedTasks) { task in
                            completedTaskRow(task)
                                .transition(.taskRowTransition)
                        }
                    }
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.75), value: store.completedTasks.map(\.id))
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .background(theme.background)
            .dropDestination(for: String.self) { items, _ in
                guard let taskID = items.first, let uuid = UUID(uuidString: taskID) else { return false }
                moveTask(taskID: uuid, to: .completed)
                return true
            } isTargeted: { _ in }
            .navigationTitle(L10n.completedTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                if !store.completedTasks.isEmpty {
                    ToolbarItem(placement: .automatic) {
                        Button(L10n.clearAction) {
                            store.removeCompleted()
                        }
                        .foregroundColor(JarvisTheme.accent)
                    }
                }
            }
        }
    }
    
    private var completedStatsCard: some View {
        let completed = store.completedTasks
        let todayCompleted = completed.filter { Calendar.current.isDateInToday($0.date) }.count
        let weekCompleted = completed.filter {
            guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else { return false }
            return $0.date >= weekAgo
        }.count
        
        return VStack(spacing: 16) {
            HStack(spacing: 20) {
                statItem(value: "\(completed.count)", label: L10n.total, color: JarvisTheme.accent)
                statItem(value: "\(todayCompleted)", label: L10n.tabToday, color: JarvisTheme.accentGreen)
                statItem(value: "\(weekCompleted)", label: L10n.thisWeek, color: JarvisTheme.accentBlue)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBackground)
                .shadow(color: theme.cardShadow, radius: 4, y: 2)
        )
        .padding(.bottom, 8)
    }
    
    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func completedTaskRow(_ task: PlannerTask) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(task.taskColor.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(task.taskColor)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                    .strikethrough()
                
                Text(task.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12))
                    .foregroundColor(theme.textTertiary)
            }
            
            Spacer()
            
            Button(action: { restoreTask(task) }) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16))
                    .foregroundColor(theme.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.restoreTask)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.cardBackground)
        )
        .dockMagnificationEffect()
        .contextMenu { taskContextMenu(task) }
    }
    
    private var emptyCompletedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(theme.textTertiary)
            Text(L10n.noCompleted)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            Text(L10n.completedAppearHere)
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
    
    // MARK: - Calendar Tab (iPhone)
    
    private var calendarTab: some View {
        #if !os(watchOS)
        NavigationStack {
            CalendarView()
        }
        #else
        Text(L10n.unavailableWatchOS)
        #endif
    }
    
    // MARK: - Mail Tab (iPhone)
    
    private var mailTab: some View {
        #if !os(watchOS)
        NavigationStack {
            MailView()
        }
        #else
        Text(L10n.unavailableWatchOS)
        #endif
    }
    
    // MARK: - Neural Chat Tab (iPhone)
    
    private var neuralTab: some View {
        NavigationStack {
            AIChatView(aiManager: dependencies.aiManager)
        }
    }
    
    // MARK: - Analytics Tab (iPhone)
    
    private var analyticsTab: some View {
        ChartAnalyticsView(aiManager: dependencies.aiManager)
    }
    
    // MARK: - Health Tab (iPhone)
    
    private var healthTab: some View {
        WellnessView(store: store, wellness: wellness, aiManager: dependencies.aiManager)
    }
    
    // MARK: - Settings Tab (iPhone)
    
    private var settingsTab: some View {
        NavigationStack {
            SettingsContent(theme: theme, showSleepCalculator: $showSleepCalculator)
                .navigationTitle(L10n.tabSettings)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.large)
                #endif
        }
    }
    
    // MARK: - Profile Avatar
    
    private var profileAvatar: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [JarvisTheme.accent, JarvisTheme.accentOrange], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 32, height: 32)
            
            Text(userProfile.initials)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Task Context Menu
    
    @ViewBuilder
    private func taskContextMenu(_ task: PlannerTask) -> some View {
        Button {
            editingTask = task
        } label: {
            Label(L10n.editTask, systemImage: "pencil")
        }
        
        Button {
            toggleTask(task)
        } label: {
            Label(task.isCompleted ? L10n.markIncomplete : L10n.markComplete, 
                  systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark.circle")
        }
        
        Divider()
        
        Button {
            duplicateTask(task)
        } label: {
            Label(L10n.duplicateTask, systemImage: "doc.on.doc")
        }
        
        if !task.isInbox {
            Button {
                moveToInbox(task)
            } label: {
                Label(L10n.moveToInbox, systemImage: "tray")
            }
        }
        
        Button {
            scheduleForTomorrow(task)
        } label: {
            Label(L10n.moveToTomorrow, systemImage: "calendar.badge.plus")
        }
        
        Button {
            moveTaskToFuturePlans(task)
        } label: {
            Label(L10n.moveToFuture, systemImage: "sparkles")
        }
        
        Divider()
        
        Menu(L10n.colorMenu) {
            ForEach(0..<JarvisTheme.taskColors.count, id: \.self) { index in
                Button {
                    changeTaskColor(task, to: index)
                } label: {
                    Label(colorName(index), systemImage: task.colorIndex == index ? "checkmark.circle.fill" : "circle.fill")
                }
            }
        }
        
        Divider()
        
        #if !os(watchOS)
        Menu(L10n.share) {
            Button {
                MessengerService.shared.shareTask(task, via: .whatsapp)
            } label: {
                Label("WhatsApp", systemImage: "message.fill")
            }
            Button {
                MessengerService.shared.shareTask(task, via: .telegram)
            } label: {
                Label("Telegram", systemImage: "paperplane.fill")
            }
        }
        #endif
        
        Divider()
        
        Button(role: .destructive) {
            dependencies.calendarSyncService.removeEvent(for: task)
            store.delete(task)
        } label: {
            Label(L10n.deleteTask, systemImage: "trash")
        }
    }
    
    private func colorName(_ index: Int) -> String {
        let names = [L10n.colorCoral, L10n.colorOrange, L10n.colorYellow, L10n.colorGreen, L10n.colorBlue, L10n.colorPurple, L10n.colorPink, L10n.colorTurquoise]
        return names[index % names.count]
    }
    
    // MARK: - Shared Components
    
    private var dateHeader: some View {
        HStack {
            Button(action: {
                withAnimation(.spring(response: 0.3)) { showMonthCalendar.toggle() }
            }) {
                HStack(spacing: 4) {
                    Text("\(selectedDate.formatted(.dateTime.day())) \(selectedDate.formatted(.dateTime.month(.wide)))")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                    Text(selectedDate.formatted(.dateTime.year()))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(JarvisTheme.accent)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(JarvisTheme.accent)
                        .rotationEffect(.degrees(showMonthCalendar ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            dateNavigation
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    private var dateNavigation: some View {
        HStack(spacing: 8) {
            Button(action: { moveDate(by: -1) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(theme.cardBackground))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.previousDay)
            
            Button(action: { selectedDate = Date() }) {
                Text(L10n.today)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(JarvisTheme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(theme.cardBackground))
            }
            .buttonStyle(.plain)
            
            Button(action: { moveDate(by: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(theme.cardBackground))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.nextDay)
        }
    }
    
    private var weekStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(getWeekDays(), id: \.self) { date in
                        weekDayCell(date: date, compact: true)
                            .id(date)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    proxy.scrollTo(selectedDate, anchor: .center)
                }
            }
        }
        .padding(.bottom, 12)
    }
    
    private func weekDayCell(date: Date, compact: Bool) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isToday = Calendar.current.isDateInToday(date)
        let taskCount = store.tasksForDay(date).filter { !$0.isInbox && !$0.isCompleted }.count
        
        return Button(action: { selectedDate = date }) {
            VStack(spacing: compact ? 6 : 4) {
                Text(date.formatted(.dateTime.weekday(.short)))
                    .font(.system(size: compact ? 11 : 12, weight: .medium))
                    .foregroundColor(theme.textTertiary)
                
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: compact ? 16 : 18, weight: .semibold))
                    .foregroundColor(isSelected ? .white : (isToday ? JarvisTheme.accent : theme.textPrimary))
                    .frame(width: compact ? 36 : 40, height: compact ? 36 : 40)
                    .background(
                        Circle()
                            .fill(isSelected ? JarvisTheme.accent : (isToday ? JarvisTheme.accent.opacity(0.15) : Color.clear))
                    )
                
                HStack(spacing: 2) {
                    ForEach(0..<Swift.min(taskCount, 4), id: \.self) { i in
                        Circle()
                            .fill(JarvisTheme.taskColors[i % JarvisTheme.taskColors.count])
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(width: compact ? 50 : nil)
        }
        .buttonStyle(.plain)
        .dropDestination(for: String.self) { items, _ in
            if let taskID = items.first, let uuid = UUID(uuidString: taskID) {
                moveTaskToDate(uuid, date: date)
                return true
            }
            return false
        }
    }
    
    /// Зона сброса на экране «Сегодня»: перетащите задачу сюда — в Выполнено
    private var completedDropZone: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 14))
                .foregroundColor(JarvisTheme.accentGreen)
            Text(L10n.dropToComplete)
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(completedDropHighlighted ? JarvisTheme.accentGreen.opacity(0.2) : theme.cardBackground.opacity(0.8))
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .dropDestination(for: String.self) { items, _ in
            guard let taskID = items.first, let uuid = UUID(uuidString: taskID) else { return false }
            moveTask(taskID: uuid, to: .completed)
            completedDropHighlighted = false
            return true
        } isTargeted: { completedDropHighlighted = $0 }
    }
    
    private var timelineList: some View {
        let dayTasks = store.tasksForDay(selectedDate).filter { !$0.isInbox && !$0.isCompleted }
        let sortedTasks = dayTasks.sorted { $0.date < $1.date }
        
        return VStack(alignment: .leading, spacing: 0) {
            if sortedTasks.isEmpty {
                emptyTimelineView
            } else {
                structuredTimeline(tasks: sortedTasks)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: sortedTasks.map(\.id))
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
    
    // MARK: - Structured Timeline (proportional blocks + dashed line)
    
    private func structuredTimeline(tasks: [PlannerTask]) -> some View {
        let cal = Calendar.current
        let hrH: CGFloat = 80
        let isToday = cal.isDateInToday(selectedDate)
        
        let firstMinutes = taskMinutesOfDay(tasks.first!.date)
        let lastTask = tasks.last!
        let lastEnd = taskMinutesOfDay(lastTask.date) + CGFloat(max(lastTask.durationMinutes, 30))
        let totalHeight = (lastEnd / 60.0) * hrH + 60
        
        return ZStack(alignment: .topLeading) {
            // Dashed vertical timeline line
            timelineDashedLine(startMinutes: firstMinutes, endMinutes: lastEnd, hourRowHeight: hrH)
            
            // Now indicator
            if isToday {
                timelineNowIndicator(hourRowHeight: hrH)
            }
            
            // Task blocks
            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                timelineTaskGroup(task: task, index: index, allTasks: tasks, hourRowHeight: hrH)
            }
        }
        .frame(height: totalHeight)
    }
    
    private func taskMinutesOfDay(_ date: Date) -> CGFloat {
        let cal = Calendar.current
        return CGFloat(cal.component(.hour, from: date)) * 60 + CGFloat(cal.component(.minute, from: date))
    }
    
    private func timelineDashedLine(startMinutes: CGFloat, endMinutes: CGFloat, hourRowHeight: CGFloat) -> some View {
        let startY = (startMinutes / 60.0) * hourRowHeight + 20
        let endY = (endMinutes / 60.0) * hourRowHeight + 20
        return Path { path in
            let x: CGFloat = 36
            var y = startY
            while y < endY {
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x, y: min(y + 6, endY)))
                y += 12
            }
        }
        .stroke(theme.textTertiary.opacity(0.4), lineWidth: 2)
    }
    
    private func timelineNowIndicator(hourRowHeight: CGFloat) -> some View {
        let cal = Calendar.current
        let h = cal.component(.hour, from: Date())
        let m = cal.component(.minute, from: Date())
        let nowY = (CGFloat(h) + CGFloat(m) / 60.0) * hourRowHeight + 20
        return HStack(spacing: 0) {
            Text(String(format: "%02d:%02d", h, m))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(JarvisTheme.accent)
                .frame(width: 36, alignment: .trailing)
            Circle()
                .fill(JarvisTheme.accent)
                .frame(width: 10, height: 10)
                .offset(x: -5)
            Rectangle()
                .fill(JarvisTheme.accent)
                .frame(height: 2)
        }
        .offset(y: nowY - 7)
        .zIndex(50)
    }
    
    @ViewBuilder
    private func timelineTaskGroup(task: PlannerTask, index: Int, allTasks: [PlannerTask], hourRowHeight: CGFloat) -> some View {
        let mins = taskMinutesOfDay(task.date)
        let taskY = (mins / 60.0) * hourRowHeight + 20
        let dur = max(task.durationMinutes, 30)
        let blockH = CGFloat(dur) / 60.0 * hourRowHeight
        let endMins = mins + CGFloat(task.durationMinutes)
        
        // Time label
        timeLabel(date: task.date)
            .offset(y: taskY - 7)
        
        // Icon circle
        taskIconCircle(task: task)
            .offset(x: 14, y: taskY - 2)
            .zIndex(10)
        
        // Card
        timelineTaskCard(task: task, blockHeight: blockH)
            .padding(.leading, 62)
            .padding(.trailing, 4)
            .offset(y: taskY)
        
        // End time
        if task.durationMinutes >= 60 {
            timeLabel(minutesOfDay: Int(endMins))
                .offset(y: taskY + blockH - 7)
        }
        
        // Gap to next task
        if index < allTasks.count - 1 {
            let nextMins = taskMinutesOfDay(allTasks[index + 1].date)
            let gap = Int(nextMins - endMins)
            if gap > 5 {
                timelineGapView(gapMinutes: gap, endMinutes: endMins, hourRowHeight: hourRowHeight)
            }
        }
    }
    
    private func timeLabel(date: Date) -> some View {
        Text(date.formatted(date: .omitted, time: .shortened))
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(theme.textTertiary)
            .frame(width: 36, alignment: .trailing)
    }
    
    private func timeLabel(minutesOfDay: Int) -> some View {
        Text(String(format: "%02d:%02d", minutesOfDay / 60, minutesOfDay % 60))
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(theme.textTertiary)
            .frame(width: 36, alignment: .trailing)
    }
    
    private func taskIconCircle(task: PlannerTask) -> some View {
        ZStack {
            Circle()
                .fill(task.taskColor.opacity(0.2))
                .frame(width: 44, height: 44)
            Image(systemName: task.icon.isEmpty ? "star.fill" : task.icon)
                .font(.system(size: 18))
                .foregroundColor(task.taskColor)
        }
    }
    
    private func timelineTaskCard(task: PlannerTask, blockHeight: CGFloat) -> some View {
        let cal = Calendar.current
        let endTime = cal.date(byAdding: .minute, value: task.durationMinutes, to: task.date) ?? task.date
        let timeRange = "\(task.date.formatted(date: .omitted, time: .shortened)) – \(endTime.formatted(date: .omitted, time: .shortened)) (\(formatDuration(task.durationMinutes)))"
        
        return HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(task.taskColor)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(timeRange)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                
                Text(task.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(blockHeight > 60 ? 2 : 1)
                
                if !task.notes.isEmpty && blockHeight > 80 {
                    Text(task.notes)
                        .font(.system(size: 13))
                        .foregroundColor(theme.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            ZStack {
                Circle()
                    .stroke(task.taskColor, lineWidth: 2)
                    .frame(width: 26, height: 26)
                if task.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(task.taskColor)
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .highPriorityGesture(
                TapGesture().onEnded { _ in toggleTask(task) }
            )
            .padding(.trailing, 8)
        }
        .frame(height: max(blockHeight - 6, 50))
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.cardBackground)
                .shadow(color: theme.cardShadow, radius: 3, y: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { editingTask = task }
        .contextMenu { taskContextMenu(task) }
        .draggable(task.id.uuidString) {
            HStack {
                Circle().fill(task.taskColor).frame(width: 8, height: 8)
                Text(task.title).font(.system(size: 14, weight: .medium))
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(theme.cardBackground))
        }
    }
    
    @ViewBuilder
    private func timelineGapView(gapMinutes: Int, endMinutes: CGFloat, hourRowHeight: CGFloat) -> some View {
        let gapY = (endMinutes / 60.0) * hourRowHeight + 20 + (CGFloat(gapMinutes) / 120.0 * hourRowHeight)
        
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 12))
                .foregroundColor(JarvisTheme.accent.opacity(0.7))
            Text("\(formatDuration(gapMinutes)): \(gapMessage(gapMinutes))")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.textSecondary)
        }
        .padding(.leading, 62)
        .offset(y: gapY)
        
        if gapMinutes >= 15 {
            Button(action: {
                addTaskAtTime(hour: Int(endMinutes) / 60, minute: Int(endMinutes) % 60)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text(L10n.addTask)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(JarvisTheme.accent)
            }
            .buttonStyle(.plain)
            .padding(.leading, 62)
            .offset(y: gapY + 22)
        }
    }
    
    // MARK: - Timeline Helpers
    
    private func formatDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            if m == 0 { return "\(h) hr" }
            return "\(h) hr, \(m) min"
        }
        return "\(minutes)m"
    }
    
    private func gapMessage(_ gapMinutes: Int) -> String {
        if gapMinutes < 10 { return L10n.almostTime }
        if gapMinutes < 30 { return L10n.quickBreak }
        if gapMinutes < 60 { return L10n.timeForFocus }
        if gapMinutes < 120 { return L10n.aCanvasForIdeas }
        return L10n.plentyOfTime
    }
    
    private func addTaskAtTime(hour: Int, minute: Int) {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: selectedDate)
        let taskDate = cal.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart) ?? dayStart
        // Create a quick task at the specified time — show add sheet with pre-set time
        self.selectedDate = taskDate
        self.showAddTask = true
    }
    
    // MARK: - Task Rows
    
    private func taskRow(_ task: PlannerTask) -> some View {
        HStack(spacing: 12) {
            // Область для тапа «редактировать» — без кружка, чтобы кружок только переключал выполнение
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(task.taskColor)
                    .frame(width: 4)
                
                Circle()
                    .fill(task.taskColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: task.icon.isEmpty ? "star.fill" : task.icon)
                            .font(.system(size: 16))
                            .foregroundColor(task.taskColor)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(task.isCompleted ? theme.textTertiary : theme.textPrimary)
                        .strikethrough(task.isCompleted)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        if !task.isAllDay {
                            Label(task.date.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                                .font(.system(size: 12))
                                .foregroundColor(theme.textSecondary)
                        }
                        if task.durationMinutes > 0 && !task.isAllDay {
                            Text("\(task.durationMinutes) мин")
                                .font(.system(size: 12))
                                .foregroundColor(theme.textTertiary)
                        }
                        if task.priority != .medium {
                            Image(systemName: task.priority.icon)
                                .font(.system(size: 10))
                                .foregroundColor(theme.textTertiary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { editingTask = task }
            
            Spacer(minLength: 8)
            
            // Кружок: тап — галочка и задача уходит в «Выполнено» (приоритет выше, чем у draggable)
            ZStack {
                Circle()
                    .stroke(task.taskColor, lineWidth: 2)
                    .frame(width: 24, height: 24)
                if task.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(task.taskColor)
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .highPriorityGesture(
                TapGesture().onEnded { _ in toggleTask(task) }
            )
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.cardBackground)
                .shadow(color: theme.cardShadow, radius: 2, y: 1)
        )
        .padding(.bottom, 8)
        .contentShape(Rectangle())
        .dockMagnificationEffect()
        .contextMenu { taskContextMenu(task) }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                dependencies.calendarSyncService.removeEvent(for: task)
                store.delete(task)
            } label: {
                Label(L10n.deleteTask, systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { toggleTask(task) } label: {
                Label(task.isCompleted ? L10n.markIncomplete : L10n.markComplete, systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(JarvisTheme.accentGreen)
        }
    }
    
    private func draggableTaskRow(_ task: PlannerTask) -> some View {
        taskRow(task)
            .draggable(task.id.uuidString) {
                HStack {
                    Circle()
                        .fill(task.taskColor)
                        .frame(width: 8, height: 8)
                    Text(task.title)
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(theme.cardBackground))
                .scaleEffect(1.08)
            }
    }
    
    private func inboxTaskRow(_ task: PlannerTask) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(task.taskColor.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: task.icon.isEmpty ? "tray.fill" : task.icon)
                        .font(.system(size: 16))
                        .foregroundColor(task.taskColor)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(task.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(2)
                    if task.priority != .medium {
                        Image(systemName: task.priority.icon)
                            .font(.system(size: 10))
                            .foregroundColor(theme.textTertiary)
                    }
                }
                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(2)
                }
            }
            
            Spacer(minLength: 8)
            
            Button(action: { scheduleTaskToToday(task) }) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 18))
                    .foregroundColor(JarvisTheme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.scheduleToday)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.cardBackground)
                .shadow(color: theme.cardShadow, radius: 2, y: 1)
        )
        .contentShape(Rectangle())
        .dockMagnificationEffect()
        .onTapGesture { editingTask = task }
        .contextMenu { taskContextMenu(task) }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                dependencies.calendarSyncService.removeEvent(for: task)
                store.delete(task)
            } label: {
                Label(L10n.deleteTask, systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { scheduleTaskToToday(task) } label: {
                Label(L10n.scheduleAction, systemImage: "calendar")
            }
            .tint(JarvisTheme.accentBlue)
        }
    }
    
    // MARK: - Empty States
    
    private var emptyTimelineView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)
            
            ZStack {
                Circle()
                    .fill(JarvisTheme.accent.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 44))
                    .foregroundColor(JarvisTheme.accent.opacity(0.6))
            }
            
            Text(L10n.noTasksThisDay)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            
            Text(L10n.emptyDayDescription)
                .font(.system(size: 15))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { showAddTask = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text(L10n.addTask)
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(JarvisTheme.accent)
                )
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private var emptyInboxView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)
            
            ZStack {
                Circle()
                    .fill(JarvisTheme.accent.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "tray.fill")
                    .font(.system(size: 44))
                    .foregroundColor(JarvisTheme.accent.opacity(0.6))
            }
            
            Text(L10n.inboxTitle)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            
            Text(L10n.inboxEmptyDescription)
                .font(.system(size: 15))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: { showAddTask = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text(L10n.newInboxTask)
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(JarvisTheme.accent)
                )
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Month Calendar Popup
    
    private var monthCalendarPopup: some View {
        let cal = Calendar.current
        let month = cal.component(.month, from: selectedDate)
        let year = cal.component(.year, from: selectedDate)
        let firstOfMonth = cal.date(from: DateComponents(year: year, month: month, day: 1))!
        let daysInMonth = cal.range(of: .day, in: .month, for: firstOfMonth)!.count
        let firstWeekday = (cal.component(.weekday, from: firstOfMonth) + 5) % 7 // Mon=0
        let weekDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        
        return VStack(spacing: 12) {
            // Header
            HStack {
                Text("\(selectedDate.formatted(.dateTime.month(.wide)))")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                Text(selectedDate.formatted(.dateTime.year()))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(JarvisTheme.accent)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(JarvisTheme.accent)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: { moveMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { moveMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: { withAnimation(.spring(response: 0.3)) { showMonthCalendar = false } }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(theme.cardBackground))
                }
                .buttonStyle(.plain)
            }
            
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Days grid
            let totalCells = firstWeekday + daysInMonth
            let rows = (totalCells + 6) / 7
            
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let dayIndex = row * 7 + col - firstWeekday + 1
                        if dayIndex >= 1 && dayIndex <= daysInMonth {
                            let dayDate = cal.date(from: DateComponents(year: year, month: month, day: dayIndex))!
                            let isSelected = cal.isDate(dayDate, inSameDayAs: selectedDate)
                            let isToday = cal.isDateInToday(dayDate)
                            let taskCount = store.tasksForDay(dayDate).filter { !$0.isInbox && !$0.isCompleted }.count
                            
                            Button(action: {
                                selectedDate = dayDate
                                withAnimation(.spring(response: 0.3)) { showMonthCalendar = false }
                            }) {
                                VStack(spacing: 2) {
                                    Text("\(dayIndex)")
                                        .font(.system(size: 16, weight: isSelected || isToday ? .bold : .regular))
                                        .foregroundColor(isSelected ? .white : (isToday ? JarvisTheme.accent : theme.textPrimary))
                                        .frame(width: 36, height: 36)
                                        .background(
                                            Circle()
                                                .fill(isSelected ? JarvisTheme.accent : Color.clear)
                                        )
                                    
                                    // Task dots
                                    HStack(spacing: 2) {
                                        ForEach(0..<Swift.min(taskCount, 3), id: \.self) { _ in
                                            Circle()
                                                .fill(isSelected ? JarvisTheme.accent : JarvisTheme.accent.opacity(0.6))
                                                .frame(width: 4, height: 4)
                                        }
                                    }
                                    .frame(height: 4)
                                }
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 42)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.background)
                .shadow(color: .black.opacity(0.15), radius: 20, y: -5)
        )
        .padding(.horizontal, 8)
    }
    
    private func moveMonth(by offset: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: offset, to: selectedDate) {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDate = newDate
            }
        }
    }
    
    private var floatingAddButton: some View {
        Button(action: { showAddTask = true }) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(JarvisTheme.accent))
                .shadow(color: JarvisTheme.accent.opacity(0.4), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.addTask)
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }
    
    // MARK: - Dual FAB (Add Task + AI Voice)
    
    private var floatingDualFAB: some View {
        VStack(spacing: 12) {
            // Secondary: Add Task
            Button(action: { showAddTask = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(JarvisTheme.accent))
                    .shadow(color: JarvisTheme.accent.opacity(0.3), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.addTask)
            
            // Primary: AI Voice (larger, gradient)
            Button(action: { showAIFullChat = true }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [JarvisTheme.accent, JarvisTheme.accentPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: JarvisTheme.accentPurple.opacity(0.4), radius: 8, y: 4)
                    
                    Image(systemName: "mic.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Голосовая команда Jarvis")
            .accessibilityHint("Нажмите для управления голосом")
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
        .sheet(isPresented: $showAIFullChat) {
            NavigationStack {
                AIChatView(aiManager: dependencies.aiManager)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Готово") { showAIFullChat = false }
                        }
                    }
            }
        }
    }
    
    // MARK: - Actions
    
    private func toggleTask(_ task: PlannerTask) {
        var updated = task
        updated.isCompleted.toggle()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            store.update(updated)
        }
    }
    
    private func restoreTask(_ task: PlannerTask) {
        var updated = task
        updated.isCompleted = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            store.update(updated)
        }
    }
    
    private func scheduleTaskToToday(_ task: PlannerTask) {
        var updated = task
        updated.isInbox = false
        updated.date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        store.update(updated)
    }
    
    private func moveTaskToInbox(_ taskID: UUID) {
        guard let task = store.tasks.first(where: { $0.id == taskID }) else { return }
        var updated = task
        updated.isInbox = true
        store.update(updated)
    }
    
    private func moveTaskToDate(_ taskID: UUID, date: Date) {
        guard let task = store.tasks.first(where: { $0.id == taskID }) else { return }
        var updated = task
        updated.isInbox = false
        updated.date = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: task.date),
                                              minute: Calendar.current.component(.minute, from: task.date),
                                              second: 0, of: date) ?? date
        store.update(updated)
    }
    
    private func moveTaskToDateAndTime(taskID: UUID, date: Date, hour: Int, minute: Int = 0) {
        guard let task = store.tasks.first(where: { $0.id == taskID }) else { return }
        var updated = task
        updated.isInbox = false
        updated.isAllDay = false
        let dayStart = Calendar.current.startOfDay(for: date)
        updated.date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart) ?? dayStart
        store.update(updated)
    }
    
    private func moveToInbox(_ task: PlannerTask) {
        var updated = task
        updated.isInbox = true
        store.update(updated)
    }
    
    /// Перемещение задачи в папку при drag & drop на пункт навигации
    private func moveTask(taskID: UUID, to section: NavigationSection) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            store.moveTask(taskID: taskID, to: section)
        }
    }
    
    private func moveTaskToFuturePlans(_ task: PlannerTask) {
        var updated = task
        updated.isInbox = false
        updated.isCompleted = false
        if let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date()) {
            updated.date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: nextWeek) ?? nextWeek
        }
        store.update(updated)
    }
    
    private func duplicateTask(_ task: PlannerTask) {
        let newTask = PlannerTask(
            title: task.title + " (копия)",
            notes: task.notes,
            date: task.date,
            durationMinutes: task.durationMinutes,
            isAllDay: task.isAllDay,
            hasAlarm: task.hasAlarm,
            isInbox: task.isInbox,
            colorIndex: task.colorIndex,
            icon: task.icon,
            categoryId: task.categoryId,
            tagIds: task.tagIds,
            priority: task.priority
        )
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            store.add(newTask)
        }
    }
    
    private func scheduleForTomorrow(_ task: PlannerTask) {
        var updated = task
        updated.isInbox = false
        if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
            updated.date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        }
        store.update(updated)
    }
    
    private func changeTaskColor(_ task: PlannerTask, to colorIndex: Int) {
        var updated = task
        updated.colorIndex = colorIndex
        store.update(updated)
    }
    
    private func moveDate(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDate = newDate
            }
        }
    }
    
    private func getWeekDays() -> [Date] {
        let calendar = Calendar.current
        let today = Date()
        return (-14...14).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }
    #endif
}

// MARK: - Preview

#Preview {
    StructuredMainView()
}
