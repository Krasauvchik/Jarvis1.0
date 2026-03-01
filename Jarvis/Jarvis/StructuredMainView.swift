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
                threeColumnLayout
            }
            #endif
        }
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
        #endif
    }
    
    // MARK: - watchOS Layout
    
    #if os(watchOS)
    private var watchOSLayout: some View {
        NavigationStack {
            List {
                let todayTasks = store.tasksForDay(Date())
                if todayTasks.isEmpty {
                    Text("Нет задач")
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
        .accessibilityLabel("\(task.title)\(task.isCompleted ? ", выполнена" : "")")
        .accessibilityHint("Смахните для удаления")
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                dependencies.calendarSyncService.removeEvent(for: task)
                store.delete(task)
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }
    #endif
    
    // MARK: - iPhone Layout
    
    #if !os(watchOS)
    private var iPhoneLayout: some View {
        TabView(selection: $selectedTab) {
            todayTab
                .tabItem { Label("Сегодня", systemImage: "calendar") }
                .tag(0)
            
            inboxTab
                .tabItem { Label("Inbox", systemImage: "tray.fill") }
                .tag(1)
            
            calendarTab
                .tabItem { Label("Календарь", systemImage: "calendar.circle") }
                .tag(2)
            
            mailTab
                .tabItem { Label("Почта", systemImage: "envelope.fill") }
                .tag(3)
            
            neuralTab
                .tabItem { Label("AI", systemImage: "brain.head.profile") }
                .tag(4)
            
            analyticsTab
                .tabItem { Label("Аналитика", systemImage: "chart.bar.xaxis") }
                .tag(5)
            
            settingsTab
                .tabItem { Label("Настройки", systemImage: "gearshape.fill") }
                .tag(6)
        }
        .tint(JarvisTheme.accent)
    }
    
    // MARK: - Three Column Layout (iPad/Mac) — колонки меняют размер, левую можно скрыть
    
    private var threeColumnLayout: some View {
        HStack(spacing: 0) {
            if !leftPanelHidden {
                SidebarView(
                    theme: theme,
                    selectedSection: $selectedSection,
                    store: store,
                    onHide: { withAnimation(.easeInOut(duration: 0.2)) { leftPanelHidden = true } },
                    onShowSleepCalculator: { showSleepCalculator = true },
                    onShowSettings: { showSettings = true },
                    onShowProfile: { showProfile = true }
                )
                .frame(width: Swift.max(160, Swift.min(400, sidebarWidth)))
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
                .accessibilityLabel("Показать боковую панель")
                .padding(.leading, 8)
            }
        }
    }
    
    // MARK: - Resizable Column Divider (перетаскивание меняет ширину соседней колонки слева)

    private struct ColumnResizer: View {
        let theme: JarvisTheme
        @Binding var width: Double
        let min: CGFloat
        let max: CGFloat
        @State private var dragStartWidth: CGFloat?

        private let gripWidth: CGFloat = 10

        var body: some View {
            Rectangle()
                .fill(theme.divider.opacity(0.5))
                .frame(width: gripWidth)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
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
                    Text(selectedSection.rawValue)
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
                .accessibilityLabel("Добавить задачу")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            
            Divider().background(theme.divider)
            
            // Search (поиск по задачам)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(theme.textTertiary)
                TextField("Поиск по задачам", text: $searchQuery)
                    .textFieldStyle(.plain)
                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Очистить поиск")
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
                    Text("Добавить")
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
            return "Графики и тренды"
        case .projects:
            return "Группировка задач"
        case .chat:
            return "Чат с нейросетью"
        }
    }
    
    private var tasksForCurrentSection: [PlannerTask] {
        let calendar = Calendar.current
        let startOfTomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        switch selectedSection {
        case .inbox:
            return store.tasks.filter { $0.isInbox && !$0.isCompleted }
        case .today:
            return store.tasksForDay(Date()).filter { !$0.isCompleted }
        case .scheduled:
            return store.tasks.filter { !$0.isInbox && !$0.isCompleted && $0.date < startOfTomorrow }.sorted { $0.date < $1.date }
        case .futurePlans:
            return store.tasks.filter { !$0.isInbox && !$0.isCompleted && $0.date >= startOfTomorrow }.sorted { $0.date < $1.date }
        case .completed:
            return store.tasks.filter { $0.isCompleted }.sorted { $0.date > $1.date }
        case .all:
            return store.tasks.sorted { $0.date < $1.date }
        case .calendarSection, .mailSection, .messengers, .analytics, .projects, .chat:
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
        case .inbox: return "Inbox пуст\nЗаписывайте идеи сюда"
        case .today: return "Нет задач на сегодня"
        case .scheduled: return "Нет запланированных задач"
        case .futurePlans: return "Нет планов на будущее\nПеретащите сюда задачу"
        case .completed: return "Нет выполненных задач"
        case .all: return "Нет задач"
        case .calendarSection: return "Календарь"
        case .mailSection: return "Почта"
        case .messengers: return ""
        case .analytics: return ""
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
                        .lineLimit(1)
                    
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
                    .accessibilityLabel("Запланировать на сегодня")
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
            .accessibilityLabel(task.isCompleted ? "Отменить выполнение \(task.title)" : "Выполнить \(task.title)")
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
        .accessibilityLabel("Задача: \(task.title)")
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
                        dateHeader
                        weekStrip
                        completedDropZone
                        timelineList
                    }
                }
                .background(theme.background)
                
                floatingAddButton
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
                        let inboxTasks = store.tasks.filter { $0.isInbox && !$0.isCompleted }
                        
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
                    let completedTasks = store.tasks.filter { $0.isCompleted }
                        .sorted { $0.date > $1.date }
                    
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
                .animation(.spring(response: 0.45, dampingFraction: 0.75), value: store.tasks.filter { $0.isCompleted }.map(\.id))
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .background(theme.background)
            .dropDestination(for: String.self) { items, _ in
                guard let taskID = items.first, let uuid = UUID(uuidString: taskID) else { return false }
                moveTask(taskID: uuid, to: .completed)
                return true
            } isTargeted: { _ in }
            .navigationTitle("Выполнено")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                if !store.tasks.filter({ $0.isCompleted }).isEmpty {
                    ToolbarItem(placement: .automatic) {
                        Button("Очистить") {
                            store.removeCompleted()
                        }
                        .foregroundColor(JarvisTheme.accent)
                    }
                }
            }
        }
    }
    
    private var completedStatsCard: some View {
        let completed = store.tasks.filter { $0.isCompleted }
        let todayCompleted = completed.filter { Calendar.current.isDateInToday($0.date) }.count
        let weekCompleted = completed.filter {
            guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else { return false }
            return $0.date >= weekAgo
        }.count
        
        return VStack(spacing: 16) {
            HStack(spacing: 20) {
                statItem(value: "\(completed.count)", label: "Всего", color: JarvisTheme.accent)
                statItem(value: "\(todayCompleted)", label: "Сегодня", color: JarvisTheme.accentGreen)
                statItem(value: "\(weekCompleted)", label: "За неделю", color: JarvisTheme.accentBlue)
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
            .accessibilityLabel("Восстановить задачу")
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
            Text("Нет выполненных задач")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            Text("Выполненные задачи\nпоявятся здесь")
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
        Text("Недоступно на watchOS")
        #endif
    }
    
    // MARK: - Mail Tab (iPhone)
    
    private var mailTab: some View {
        #if !os(watchOS)
        NavigationStack {
            MailView()
        }
        #else
        Text("Недоступно на watchOS")
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
    
    // MARK: - Settings Tab (iPhone)
    
    private var settingsTab: some View {
        NavigationStack {
            SettingsContent(theme: theme, showSleepCalculator: $showSleepCalculator)
                .navigationTitle("Настройки")
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
            Label("Редактировать", systemImage: "pencil")
        }
        
        Button {
            toggleTask(task)
        } label: {
            Label(task.isCompleted ? "Отменить выполнение" : "Выполнить", 
                  systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark.circle")
        }
        
        Divider()
        
        Button {
            duplicateTask(task)
        } label: {
            Label("Дублировать", systemImage: "doc.on.doc")
        }
        
        if !task.isInbox {
            Button {
                moveToInbox(task)
            } label: {
                Label("В Inbox", systemImage: "tray")
            }
        }
        
        Button {
            scheduleForTomorrow(task)
        } label: {
            Label("На завтра", systemImage: "calendar.badge.plus")
        }
        
        Button {
            moveTaskToFuturePlans(task)
        } label: {
            Label("В планы на будущее", systemImage: "sparkles")
        }
        
        Divider()
        
        Menu("Цвет") {
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
        Menu("Поделиться") {
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
            Label("Удалить", systemImage: "trash")
        }
    }
    
    private func colorName(_ index: Int) -> String {
        let names = ["Коралловый", "Оранжевый", "Жёлтый", "Зелёный", "Синий", "Фиолетовый", "Розовый", "Бирюзовый"]
        return names[index % names.count]
    }
    
    // MARK: - Shared Components
    
    private var dateHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
                Text(selectedDate.formatted(.dateTime.day().month(.wide)))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(theme.textPrimary)
            }
            
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
            .accessibilityLabel("Предыдущий день")
            
            Button(action: { selectedDate = Date() }) {
                Text("Сегодня")
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
            .accessibilityLabel("Следующий день")
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
            Text("Перетащите сюда — в Выполнено")
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
        
        // Group tasks by hour for structured display with drop zones
        let cal = Calendar.current
        let tasksByHour = Dictionary(grouping: sortedTasks) { cal.component(.hour, from: $0.date) }
        
        // Determine visible hours: from earliest task hour (or 6) to latest (or 22)
        let earliestHour = sortedTasks.first.map { cal.component(.hour, from: $0.date) } ?? 6
        let latestHour = sortedTasks.last.map { cal.component(.hour, from: $0.date) } ?? 22
        let startHour = max(0, min(earliestHour, 6))
        let endHour = min(24, max(latestHour + 2, 22))
        
        return VStack(alignment: .leading, spacing: 0) {
            if sortedTasks.isEmpty {
                emptyTimelineView
            } else {
                ForEach(startHour..<endHour, id: \.self) { hour in
                    let hourTasks = tasksByHour[hour] ?? []

                    // Hour header + drop zone
                    HStack(spacing: 8) {
                        Text(String(format: "%02d:00", hour))
                            .font(.caption.weight(.medium).monospacedDigit())
                            .foregroundColor(theme.textTertiary)
                            .frame(width: 40, alignment: .trailing)
                        
                        Rectangle()
                            .fill(theme.textTertiary.opacity(0.15))
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, hourTasks.isEmpty ? 4 : 8)
                    .contentShape(Rectangle())
                    .dropDestination(for: String.self) { items, _ in
                        guard let taskID = items.first, let uuid = UUID(uuidString: taskID) else { return false }
                        withAnimation(.easeOut(duration: 0.25)) {
                            moveTaskToDateAndTime(taskID: uuid, date: selectedDate, hour: hour, minute: 0)
                        }
                        return true
                    }
                    
                    // Tasks at this hour
                    ForEach(hourTasks) { task in
                        draggableTaskRow(task)
                            .transition(.taskRowTransition)
                    }
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: sortedTasks.map(\.id))
        .padding(.horizontal, 16)
        .padding(.top, 8)
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
                Label("Удалить", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { toggleTask(task) } label: {
                Label(task.isCompleted ? "Отменить" : "Готово", systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
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
            
            Spacer()
            
            Button(action: { scheduleTaskToToday(task) }) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 18))
                    .foregroundColor(JarvisTheme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Запланировать на сегодня")
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
                Label("Удалить", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { scheduleTaskToToday(task) } label: {
                Label("Запланировать", systemImage: "calendar")
            }
            .tint(JarvisTheme.accentBlue)
        }
    }
    
    // MARK: - Empty States
    
    private var emptyTimelineView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 50))
                .foregroundColor(theme.textTertiary)
            Text("Нет задач на этот день")
                .font(.system(size: 16))
                .foregroundColor(theme.textTertiary)
            Text("Нажмите + или перетащите задачу")
                .font(.system(size: 14))
                .foregroundColor(theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
    
    private var emptyInboxView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(JarvisTheme.accent.opacity(0.5))
            Text("Inbox пуст")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            Text("Записывайте мысли и задачи\nдля планирования позже")
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
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
        .accessibilityLabel("Добавить задачу")
        .padding(.trailing, 20)
        .padding(.bottom, 20)
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
