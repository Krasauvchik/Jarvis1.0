import SwiftUI
import Combine
#if os(iOS)
import UniformTypeIdentifiers
import UIKit
#endif

// MARK: - Navigation Section

enum NavigationSection: String, CaseIterable, Identifiable {
    case inbox = "Inbox"
    case today = "Сегодня"
    case scheduled = "Запланир."
    case futurePlans = "Планы на будущее"
    case completed = "Выполнено"
    case all = "Все задачи"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .inbox: return "tray.fill"
        case .today: return "calendar"
        case .scheduled: return "calendar.badge.clock"
        case .futurePlans: return "sparkles"
        case .completed: return "checkmark.circle.fill"
        case .all: return "list.bullet"
        }
    }
    
    var color: Color {
        switch self {
        case .inbox: return JarvisTheme.accentBlue      // синий
        case .today: return JarvisTheme.accentOrange    // оранжевый
        case .scheduled: return JarvisTheme.accent      // коралловый/красный
        case .futurePlans: return JarvisTheme.accentTeal
        case .completed: return JarvisTheme.accentGreen // зелёный
        case .all: return JarvisTheme.accentPurple      // фиолетовый
        }
    }
}

// MARK: - Main Structured View

struct StructuredMainView: View {
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
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                CalendarSyncService.shared.removeEvent(for: task)
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
            
            completedTab
                .tabItem { Label("Выполнено", systemImage: "checkmark.circle.fill") }
                .tag(2)
            
            settingsTab
                .tabItem { Label("Настройки", systemImage: "gearshape.fill") }
                .tag(3)
        }
        .tint(JarvisTheme.accent)
    }
    
    // MARK: - Three Column Layout (iPad/Mac) — колонки меняют размер, левую можно скрыть
    
    private var threeColumnLayout: some View {
        HStack(spacing: 0) {
            if !leftPanelHidden {
                navigationSidebar(onHide: { withAnimation(.easeInOut(duration: 0.2)) { leftPanelHidden = true } })
                    .frame(width: Swift.max(160, Swift.min(400, sidebarWidth)))
                ColumnResizer(
                    theme: theme,
                    width: $sidebarWidth,
                    min: 160,
                    max: 400
                )
            }
            
            taskListPanel
                .frame(width: Swift.max(240, Swift.min(500, taskListWidth)))
            ColumnResizer(
                theme: theme,
                width: $taskListWidth,
                min: 240,
                max: 500
            )
            
            timelinePanel
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

    // MARK: - Navigation Sidebar
    
    private func navigationSidebar(onHide: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            // App Header + кнопка скрыть панель
            HStack {
                Circle()
                    .fill(LinearGradient(colors: [JarvisTheme.accent, JarvisTheme.accentOrange], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text("J")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    )
                
                Text("Jarvis")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                Spacer()
                
                Button(action: onHide) {
                    Image(systemName: "sidebar.leading")
                        .font(.system(size: 16))
                        .foregroundColor(theme.textSecondary)
                }
                .buttonStyle(.plain)
                .bounceOnTap()
                .help("Скрыть панель")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .animateOnAppear(delay: 0)
            
            Divider().background(theme.divider)
            
            // Navigation Items
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array(NavigationSection.allCases.enumerated()), id: \.element.id) { index, section in
                        navigationRow(section)
                            .animateOnAppear(delay: Double(index) * 0.04)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
            }
            
            Spacer()
            
            // Statistics
            VStack(spacing: 8) {
                Divider().background(theme.divider)
                
                HStack(spacing: 16) {
                    miniStatCard(value: store.tasks.count, label: "Всего", color: JarvisTheme.accent)
                    miniStatCard(value: completionPercentage, label: "%", color: JarvisTheme.accentGreen)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .animation(.spring(response: 0.4), value: store.tasks.count)
            }
            
            // Bottom Actions
            VStack(spacing: 8) {
                Divider().background(theme.divider)
                
                HStack(spacing: 12) {
                    Button(action: { showSleepCalculator = true }) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 16))
                            .foregroundColor(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                    .help("Калькулятор сна")
                    
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16))
                            .foregroundColor(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                    .help("Настройки")
                    
                    Spacer()
                    
                    Button(action: { showProfile = true }) {
                        profileAvatar
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(theme.sidebarBackground)
    }
    
    private func navigationRow(_ section: NavigationSection) -> some View {
        let isSelected = selectedSection == section
        let count = taskCount(for: section)
        
        return Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedSection = section
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: section.icon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .white : section.color)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected ? section.color : section.color.opacity(0.15))
                    )
                
                Text(section.rawValue)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? theme.textPrimary : theme.textSecondary)
                
                Spacer()
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isSelected ? section.color : theme.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? theme.cardBackground : Color.clear)
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? theme.cardBackground : Color.clear)
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(.plain)
        .bounceOnTap()
        .dropDestination(for: String.self) { items, _ in
            guard let taskID = items.first, let uuid = UUID(uuidString: taskID) else { return false }
            moveTask(taskID: uuid, to: section)
            return true
        }
    }
    
    private func taskCount(for section: NavigationSection) -> Int {
        let calendar = Calendar.current
        let startOfTomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        switch section {
        case .inbox:
            return store.tasks.filter { $0.isInbox && !$0.isCompleted }.count
        case .today:
            return store.tasksForDay(Date()).filter { !$0.isCompleted }.count
        case .scheduled:
            return store.tasks.filter { !$0.isInbox && !$0.isCompleted && $0.date < startOfTomorrow }.count
        case .futurePlans:
            return store.tasks.filter { !$0.isInbox && !$0.isCompleted && $0.date >= startOfTomorrow }.count
        case .completed:
            return store.tasks.filter { $0.isCompleted }.count
        case .all:
            return store.tasks.count
        }
    }
    
    private var completionPercentage: Int {
        guard store.tasks.count > 0 else { return 0 }
        return Int(Double(store.tasks.filter { $0.isCompleted }.count) / Double(store.tasks.count) * 100)
    }
    
    private func miniStatCard(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.cardBackground)
        )
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
                                .transition(.cardAppear)
                        }
                    }
                }
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
        }
    }
    
    private func taskListRow(_ task: PlannerTask) -> some View {
        HStack(spacing: 12) {
            // Color indicator
            Circle()
                .fill(task.taskColor)
                .frame(width: 10, height: 10)
            
            // Icon
            Image(systemName: task.icon.isEmpty ? "star.fill" : task.icon)
                .font(.system(size: 14))
                .foregroundColor(task.taskColor)
                .frame(width: 24, height: 24)
                .background(
                    Circle().fill(task.taskColor.opacity(0.15))
                )
            
            // Content
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
            
            Spacer()
            
            // Schedule button (for inbox)
            if task.isInbox && !task.isCompleted {
                Button(action: { scheduleTaskToToday(task) }) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 14))
                        .foregroundColor(JarvisTheme.accentOrange)
                }
                .buttonStyle(.plain)
            }
            
            // Кружочек справа: выполнить / отменить
            Button(action: { toggleTask(task) }) {
                Circle()
                    .stroke(task.taskColor, lineWidth: 2)
                    .frame(width: 24, height: 24)
                    .overlay(
                        task.isCompleted ?
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(task.taskColor) : nil
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.cardBackground)
        )
        .contentShape(Rectangle())
        .bounceOnTap()
        .onTapGesture { editingTask = task }
        .contextMenu { taskContextMenu(task) }
        .draggable(task.id.uuidString) {
            HStack {
                Circle().fill(task.taskColor).frame(width: 8, height: 8)
                Text(task.title).font(.system(size: 13))
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(theme.cardBackground))
        }
    }
    
    // MARK: - Timeline Panel
    
    private var timelinePanel: some View {
        VStack(spacing: 0) {
            // Date header
            HStack {
                Text(selectedDate.formatted(.dateTime.day().month(.wide).year()))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                Spacer()
                
                dateNavigation
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Week strip
            weekStripLarge
            
            Divider().background(theme.divider)
            
            // Timeline content
            ScrollView {
                timelineContent
            }
        }
        .background(theme.background)
    }
    
    // MARK: - Today Tab (iPhone)
    
    private var todayTab: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 0) {
                        dateHeader
                        weekStrip
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
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .background(theme.background)
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
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.cardBackground)
        )
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
        
        Button(role: .destructive) {
            CalendarSyncService.shared.removeEvent(for: task)
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
    
    private var weekStripLarge: some View {
        HStack(spacing: 0) {
            ForEach(getCurrentWeekDays(), id: \.self) { date in
                weekDayCell(date: date, compact: false)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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
    
    private var timelineList: some View {
        let dayTasks = store.tasksForDay(selectedDate).filter { !$0.isInbox && !$0.isCompleted }
        let sortedTasks = dayTasks.sorted { $0.date < $1.date }
        
        return VStack(alignment: .leading, spacing: 0) {
            if sortedTasks.isEmpty {
                emptyTimelineView
            } else {
                ForEach(sortedTasks) { task in
                    taskRow(task)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var timelineContent: some View {
        let dayTasks = store.tasksForDay(selectedDate).filter { !$0.isInbox && !$0.isCompleted }
        let sortedTasks = dayTasks.sorted { $0.date < $1.date }
        
        return VStack(alignment: .leading, spacing: 0) {
            if sortedTasks.isEmpty {
                emptyTimelineView
                    .padding(.top, 60)
            } else {
                ForEach(sortedTasks) { task in
                    draggableTaskRow(task)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .dropDestination(for: String.self) { items, _ in
            if let taskID = items.first, let uuid = UUID(uuidString: taskID) {
                moveTaskToDate(uuid, date: selectedDate)
                return true
            }
            return false
        }
    }
    
    // MARK: - Task Rows
    
    private func taskRow(_ task: PlannerTask) -> some View {
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
                }
            }
            
            Spacer()
            
            Button(action: { toggleTask(task) }) {
                Circle()
                    .stroke(task.taskColor, lineWidth: 2)
                    .frame(width: 24, height: 24)
                    .overlay(
                        task.isCompleted ?
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(task.taskColor) : nil
                    )
            }
            .buttonStyle(.plain)
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
        .onTapGesture { editingTask = task }
        .contextMenu { taskContextMenu(task) }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                CalendarSyncService.shared.removeEvent(for: task)
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
                Text(task.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(theme.textPrimary)
                
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
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.cardBackground)
                .shadow(color: theme.cardShadow, radius: 2, y: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { editingTask = task }
        .contextMenu { taskContextMenu(task) }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                CalendarSyncService.shared.removeEvent(for: task)
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
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }
    
    // MARK: - Actions
    
    private func toggleTask(_ task: PlannerTask) {
        var updated = task
        updated.isCompleted.toggle()
        store.update(updated)
    }
    
    private func restoreTask(_ task: PlannerTask) {
        var updated = task
        updated.isCompleted = false
        store.update(updated)
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
    
    private func moveToInbox(_ task: PlannerTask) {
        var updated = task
        updated.isInbox = true
        store.update(updated)
    }
    
    /// Перемещение задачи в папку при drag & drop на пункт навигации
    private func moveTask(taskID: UUID, to section: NavigationSection) {
        guard let task = store.tasks.first(where: { $0.id == taskID }) else { return }
        var updated = task
        let calendar = Calendar.current
        switch section {
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
        store.update(updated)
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
            tagIds: task.tagIds
        )
        store.add(newTask)
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
    
    private func getCurrentWeekDays() -> [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }
    #endif
}

// MARK: - Sleep Calculator Model

@MainActor
final class SleepCalculator: ObservableObject {
    @Published var wakeUpTime: Date = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    @Published var bedTime: Date = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date()) ?? Date()
    @Published var mode: CalculationMode = .wakeUp
    
    enum CalculationMode: String, CaseIterable {
        case wakeUp = "Когда проснуться"
        case bedTime = "Когда лечь спать"
    }
    
    private let sleepCycleDuration: TimeInterval = 90 * 60
    private let fallAsleepTime: TimeInterval = 14 * 60
    
    var recommendedWakeUpTimes: [Date] {
        guard mode == .bedTime else { return [] }
        let fallAsleepTime = bedTime.addingTimeInterval(self.fallAsleepTime)
        return (4...6).map { cycles in
            fallAsleepTime.addingTimeInterval(sleepCycleDuration * Double(cycles))
        }
    }
    
    var recommendedBedTimes: [Date] {
        guard mode == .wakeUp else { return [] }
        return (4...6).reversed().map { cycles in
            wakeUpTime.addingTimeInterval(-sleepCycleDuration * Double(cycles) - fallAsleepTime)
        }
    }
    
    func sleepDuration(cycles: Int) -> String {
        let hours = (cycles * 90) / 60
        let minutes = (cycles * 90) % 60
        if minutes == 0 { return "\(hours) ч" }
        return "\(hours) ч \(minutes) мин"
    }
    
    func cyclesDescription(cycles: Int) -> String {
        let forms = ["цикл", "цикла", "циклов"]
        let n = cycles % 100
        let n1 = n % 10
        let form: String
        if n > 10 && n < 20 { form = forms[2] }
        else if n1 > 1 && n1 < 5 { form = forms[1] }
        else if n1 == 1 { form = forms[0] }
        else { form = forms[2] }
        return "\(cycles) \(form)"
    }
}

// MARK: - Sleep Calculator Sheet

struct SleepCalculatorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var calculator = SleepCalculator()
    let theme: JarvisTheme
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Picker("Режим", selection: $calculator.mode) {
                        ForEach(SleepCalculator.CalculationMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        if calculator.mode == .wakeUp {
                            Text("Во сколько нужно проснуться?")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(theme.textSecondary)
                            
                            DatePicker("", selection: $calculator.wakeUpTime, displayedComponents: .hourAndMinute)
                                #if os(iOS)
                                .datePickerStyle(.wheel)
                                #endif
                                .labelsHidden()
                        } else {
                            Text("Во сколько ляжете спать?")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(theme.textSecondary)
                            
                            DatePicker("", selection: $calculator.bedTime, displayedComponents: .hourAndMinute)
                                #if os(iOS)
                                .datePickerStyle(.wheel)
                                #endif
                                .labelsHidden()
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackground))
                    .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "moon.zzz.fill")
                                .foregroundColor(JarvisTheme.accentPurple)
                            Text(calculator.mode == .wakeUp ? "Рекомендуемое время засыпания" : "Рекомендуемое время пробуждения")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(theme.textPrimary)
                        }
                        
                        let times = calculator.mode == .wakeUp ? calculator.recommendedBedTimes : calculator.recommendedWakeUpTimes
                        let cycles = calculator.mode == .wakeUp ? [6, 5, 4] : [4, 5, 6]
                        
                        ForEach(Array(zip(times.indices, times)), id: \.0) { index, time in
                            sleepTimeRow(time: time, cycles: cycles[index], isOptimal: index == 0)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Средний человек засыпает за 14 минут", systemImage: "info.circle")
                                .font(.system(size: 13))
                                .foregroundColor(theme.textSecondary)
                            
                            Label("Один цикл сна = 90 минут", systemImage: "clock")
                                .font(.system(size: 13))
                                .foregroundColor(theme.textSecondary)
                            
                            Label("Оптимально: 5-6 циклов (7.5-9 часов)", systemImage: "star")
                                .font(.system(size: 13))
                                .foregroundColor(JarvisTheme.accentGreen)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(theme.cardBackground.opacity(0.5)))
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackground))
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(theme.background)
            .navigationTitle("Калькулятор сна")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
    
    private func sleepTimeRow(time: Date, cycles: Int, isOptimal: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(time.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(isOptimal ? JarvisTheme.accentGreen : theme.textPrimary)
                
                Text("\(calculator.cyclesDescription(cycles: cycles)) • \(calculator.sleepDuration(cycles: cycles))")
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
            }
            
            Spacer()
            
            if isOptimal {
                Text("Оптимально")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(JarvisTheme.accentGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(JarvisTheme.accentGreen.opacity(0.15)))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isOptimal ? JarvisTheme.accentGreen.opacity(0.1) : theme.cardBackground.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isOptimal ? JarvisTheme.accentGreen.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
    }
}

// MARK: - User Profile Model

@MainActor
final class UserProfile: ObservableObject {
    static let shared = UserProfile()
    
    @Published var name: String {
        didSet { UserDefaults.standard.set(name, forKey: "jarvis_user_name") }
    }
    @Published var email: String {
        didSet { UserDefaults.standard.set(email, forKey: "jarvis_user_email") }
    }
    @Published var avatarEmoji: String {
        didSet { UserDefaults.standard.set(avatarEmoji, forKey: "jarvis_user_avatar") }
    }
    
    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
    
    private init() {
        name = UserDefaults.standard.string(forKey: "jarvis_user_name") ?? "User"
        email = UserDefaults.standard.string(forKey: "jarvis_user_email") ?? ""
        avatarEmoji = UserDefaults.standard.string(forKey: "jarvis_user_avatar") ?? "😊"
    }
}

// MARK: - Profile Sheet

struct ProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userProfile = UserProfile.shared
    @StateObject private var store = PlannerStore.shared
    let theme: JarvisTheme
    
    @State private var editedName: String = ""
    @State private var editedEmail: String = ""
    @State private var selectedEmoji: String = ""
    
    private let emojis = ["😊", "😎", "🚀", "⭐️", "🔥", "💪", "🎯", "💡", "🌟", "✨", "🎨", "📱", "💻", "🏆", "👤", "🦊"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [JarvisTheme.accent, JarvisTheme.accentOrange], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 100, height: 100)
                            
                            Text(selectedEmoji)
                                .font(.system(size: 50))
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(emojis, id: \.self) { emoji in
                                    Text(emoji)
                                        .font(.system(size: 28))
                                        .padding(8)
                                        .background(
                                            Circle()
                                                .fill(selectedEmoji == emoji ? JarvisTheme.accent.opacity(0.2) : Color.clear)
                                        )
                                        .onTapGesture { selectedEmoji = emoji }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 20)
                    
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Имя")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.textSecondary)
                            TextField("Введите имя", text: $editedName)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.textSecondary)
                            TextField("Введите email", text: $editedEmail)
                                .textFieldStyle(.roundedBorder)
                                #if os(iOS)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                                #endif
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    VStack(spacing: 12) {
                        Text("Статистика")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                        
                        HStack(spacing: 16) {
                            profileStatCard(value: "\(store.tasks.count)", label: "Всего", color: JarvisTheme.accent)
                            profileStatCard(value: "\(store.tasks.filter { $0.isCompleted }.count)", label: "Выполнено", color: JarvisTheme.accentGreen)
                            profileStatCard(value: "\(completionRate)%", label: "Успех", color: JarvisTheme.accentBlue)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
            .background(theme.background)
            .navigationTitle("Профиль")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        userProfile.name = editedName
                        userProfile.email = editedEmail
                        userProfile.avatarEmoji = selectedEmoji
                        dismiss()
                    }
                }
            }
            .onAppear {
                editedName = userProfile.name
                editedEmail = userProfile.email
                selectedEmoji = userProfile.avatarEmoji
            }
        }
    }
    
    private var completionRate: Int {
        let total = store.tasks.count
        guard total > 0 else { return 0 }
        let completed = store.tasks.filter { $0.isCompleted }.count
        return Int(Double(completed) / Double(total) * 100)
    }
    
    private func profileStatCard(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 12).fill(theme.cardBackground))
    }
}

// MARK: - Settings Content

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct SettingsContent: View {
    let theme: JarvisTheme
    @Binding var showSleepCalculator: Bool
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var store = PlannerStore.shared
    @StateObject private var cloudSync = CloudSync.shared
    @State private var shareURL: IdentifiableURL?
    @State private var showImportPicker = false
    @State private var importMessage: String?
    @State private var showImportResult = false
    @State private var importMerge = true
    @State private var showDeleteCompletedConfirm = false
    @State private var showDeleteAllConfirm = false
    @StateObject private var calendarSync = CalendarSyncService.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                settingsSection(title: "Синхронизация", icon: "icloud.fill") {
                    HStack {
                        Label("iCloud", systemImage: "icloud")
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        if cloudSync.isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if let date = cloudSync.lastSyncDate {
                            Text(date.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 13))
                                .foregroundColor(theme.textSecondary)
                        } else {
                            Text("Включено")
                                .font(.system(size: 13))
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                    .padding(.vertical, 8)
                    if let err = cloudSync.syncError {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundColor(JarvisTheme.accentOrange)
                            .padding(.vertical, 4)
                    }
                    Button(action: { cloudSync.forceSync() }) {
                        Label("Синхронизировать сейчас", systemImage: "arrow.clockwise")
                            .foregroundColor(JarvisTheme.accent)
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                    .disabled(cloudSync.isSyncing)
                    .padding(.vertical, 4)
                }
                
                settingsSection(title: "Оформление", icon: "paintbrush.fill") {
                    ForEach(ThemeMode.allCases, id: \.self) { mode in
                        themeRow(mode: mode)
                    }
                }
                
                settingsSection(title: "Здоровье", icon: "heart.fill") {
                    Button(action: { showSleepCalculator = true }) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(JarvisTheme.accentPurple.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "moon.zzz.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(JarvisTheme.accentPurple)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Калькулятор сна")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(theme.textPrimary)
                                Text("Рассчитать оптимальное время")
                                    .font(.system(size: 13))
                                    .foregroundColor(theme.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(theme.textTertiary)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                }
                
                settingsSection(title: "Календарь", icon: "calendar") {
                    Button(action: {
                        Task {
                            _ = await calendarSync.requestAccess()
                        }
                    }) {
                        HStack {
                            Label("Разрешить доступ к календарю", systemImage: "calendar.badge.plus")
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                            if calendarSync.isAuthorizedForCalendar {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(JarvisTheme.accentGreen)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                    Toggle(isOn: Binding(
                        get: { calendarSync.syncToCalendarEnabled },
                        set: { calendarSync.setSyncToCalendarEnabled($0) }
                    )) {
                        Label("Синхронизировать задачи с Календарём", systemImage: "calendar")
                            .foregroundColor(theme.textPrimary)
                    }
                    .padding(.vertical, 4)
                }
                
                settingsSection(title: "Уведомления", icon: "bell.badge.fill") {
                    settingsToggle(title: "Напоминания", icon: "bell.fill", isOn: .constant(true))
                    settingsToggle(title: "Звук", icon: "speaker.wave.2.fill", isOn: .constant(true))
                }
                
                settingsSection(title: "Статистика", icon: "chart.bar.fill") {
                    statsRow(title: "Всего задач", icon: "list.bullet", value: "\(store.tasks.count)", color: JarvisTheme.accent)
                    statsRow(title: "Выполнено", icon: "checkmark.circle", value: "\(store.tasks.filter { $0.isCompleted }.count)", color: JarvisTheme.accentGreen)
                    statsRow(title: "В Inbox", icon: "tray", value: "\(store.tasks.filter { $0.isInbox && !$0.isCompleted }.count)", color: JarvisTheme.accentOrange)
                }
                
                settingsSection(title: "Категории и теги", icon: "folder.fill") {
                    NavigationLink(destination: CategoriesTagsManageView(theme: theme)) {
                        HStack {
                            Label("Управление категориями и тегами", systemImage: "tag.fill")
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                            Text("\(store.categories.count) / \(store.tags.count)")
                                .foregroundColor(theme.textSecondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                settingsSection(title: "Данные", icon: "externaldrive.fill") {
                    Button(action: {
                        if let url = ExportImport.createExportURL(store: store) {
                            shareURL = IdentifiableURL(url: url)
                        }
                    }) {
                        HStack {
                            Label("Экспорт данных", systemImage: "square.and.arrow.up")
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                    
                    Button(action: { showImportPicker = true }) {
                        HStack {
                            Label("Импорт данных", systemImage: "square.and.arrow.down")
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                    #if os(iOS)
                    .fileImporter(
                        isPresented: $showImportPicker,
                        allowedContentTypes: [.json],
                        allowsMultipleSelection: false
                    ) { result in
                        Task { @MainActor in
                            switch result {
                            case .success(let urls):
                                guard let url = urls.first else { return }
                                guard url.startAccessingSecurityScopedResource() else {
                                    importMessage = "Нет доступа к файлу"
                                    showImportResult = true
                                    return
                                }
                                defer { url.stopAccessingSecurityScopedResource() }
                                importMessage = ExportImport.importFromURL(url, store: store, merge: importMerge)
                                showImportResult = true
                            case .failure:
                                importMessage = "Ошибка выбора файла"
                                showImportResult = true
                            }
                        }
                    }
                    #endif
                    
                    Button(action: { showDeleteCompletedConfirm = true }) {
                        HStack {
                            Label("Очистить выполненные", systemImage: "trash")
                                .foregroundColor(JarvisTheme.accentOrange)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                    .disabled(store.tasks.filter(\.isCompleted).isEmpty)
                    
                    Button(action: { showDeleteAllConfirm = true }) {
                        HStack {
                            Label("Удалить все задачи", systemImage: "trash.fill")
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                    .disabled(store.tasks.isEmpty)
                }
                .sheet(item: $shareURL) { item in
                    #if os(iOS)
                    ShareSheetView(items: [item.url])
                    #else
                    EmptyView()
                    #endif
                }
                .alert("Импорт", isPresented: $showImportResult) {
                    Button("OK", role: .cancel) { }
                } message: {
                    if let msg = importMessage { Text(msg) }
                }
                
                settingsSection(title: "О приложении", icon: "info.circle.fill") {
                    HStack {
                        Label("Версия", systemImage: "info.circle")
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Label("Сборка", systemImage: "hammer")
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Text("2026.03")
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
        }
        .background(theme.background)
        .confirmationDialog("Удалить выполненные?", isPresented: $showDeleteCompletedConfirm, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                NotificationManager.shared.cancelAll()
                store.removeCompleted()
            }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Будут удалены все задачи со статусом «выполнено».")
        }
        .confirmationDialog("Удалить все задачи?", isPresented: $showDeleteAllConfirm, titleVisibility: .visible) {
            Button("Удалить всё", role: .destructive) {
                NotificationManager.shared.cancelAll()
                store.removeAll()
            }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Все задачи и напоминания будут удалены. Это действие нельзя отменить.")
        }
    }
    
    private func settingsSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textSecondary)
            
            VStack(spacing: 0) {
                content()
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackground))
        }
    }
    
    private func themeRow(mode: ThemeMode) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                themeManager.currentTheme = mode
            }
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(themeBackgroundColor(for: mode))
                        .frame(width: 44, height: 44)
                    Image(systemName: themeIcon(for: mode))
                        .font(.system(size: 20))
                        .foregroundColor(themeIconColor(for: mode))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                    Text(themeDescription(for: mode))
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondary)
                }
                
                Spacer()
                
                if themeManager.currentTheme == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(JarvisTheme.accent)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
    
    private func settingsToggle(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: icon)
                .foregroundColor(theme.textPrimary)
        }
        .padding(.vertical, 4)
    }
    
    private func statsRow(title: String, icon: String, value: String, color: Color) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundColor(theme.textPrimary)
            Spacer()
            Text(value)
                .foregroundColor(color)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
    
    private func themeIcon(for mode: ThemeMode) -> String {
        switch mode {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }
    
    private func themeBackgroundColor(for mode: ThemeMode) -> Color {
        switch mode {
        case .light: return Color(red: 1.0, green: 0.95, blue: 0.8)
        case .dark: return Color(red: 0.15, green: 0.15, blue: 0.2)
        case .system: return Color(red: 0.5, green: 0.5, blue: 0.55)
        }
    }
    
    private func themeIconColor(for mode: ThemeMode) -> Color {
        switch mode {
        case .light: return Color.orange
        case .dark: return Color.purple
        case .system: return Color.white
        }
    }
    
    private func themeDescription(for mode: ThemeMode) -> String {
        switch mode {
        case .light: return "Яркая и светлая тема"
        case .dark: return "Комфортно для глаз в темноте"
        case .system: return "Следует настройкам устройства"
        }
    }
}

// MARK: - Categories & Tags Management (стиль как в Настройках — карточки)

struct CategoriesTagsManageView: View {
    let theme: JarvisTheme
    @StateObject private var store = PlannerStore.shared
    @State private var showAddCategory = false
    @State private var showAddTag = false
    @State private var editingCategory: TaskCategory?
    @State private var editingTag: TaskTag?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                categoriesCard
                    .animateOnAppear(delay: 0)
                tagsCard
                    .animateOnAppear(delay: 0.08)
            }
            .padding()
        }
        .background(theme.background)
        .navigationTitle("Категории и теги")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showAddCategory) {
            AddCategorySheet(theme: theme, category: nil)
        }
        .sheet(item: $editingCategory) { cat in
            AddCategorySheet(theme: theme, category: cat)
        }
        .sheet(isPresented: $showAddTag) {
            AddTagSheet(theme: theme, tag: nil)
        }
        .sheet(item: $editingTag) { tag in
            AddTagSheet(theme: theme, tag: tag)
        }
    }

    private var categoriesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Категории", systemImage: "folder.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textSecondary)
            VStack(spacing: 0) {
                ForEach(store.categories) { cat in
                    HStack(spacing: 12) {
                        Button(action: { editingCategory = cat }) {
                            HStack(spacing: 12) {
                                Image(systemName: cat.icon)
                                    .foregroundColor(cat.color)
                                    .frame(width: 28)
                                Text(cat.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(theme.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .bounceOnTap()
                        Button(action: { store.removeCategory(cat) }) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundColor(theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .bounceOnTap()
                    }
                    .padding(.vertical, 8)
                }
                Button(action: { showAddCategory = true }) {
                    Label("Добавить категорию", systemImage: "plus.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(JarvisTheme.accent)
                }
                .bounceOnTap()
                .padding(.top, 8)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackground))
        }
    }

    private var tagsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Теги", systemImage: "tag.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textSecondary)
            VStack(spacing: 0) {
                ForEach(store.tags) { tag in
                    HStack(spacing: 12) {
                        Button(action: { editingTag = tag }) {
                            HStack(spacing: 12) {
                                Circle().fill(tag.color).frame(width: 10, height: 10)
                                Text(tag.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(theme.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .bounceOnTap()
                        Button(action: { store.removeTag(tag) }) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundColor(theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .bounceOnTap()
                    }
                    .padding(.vertical, 8)
                }
                Button(action: { showAddTag = true }) {
                    Label("Добавить тег", systemImage: "plus.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(JarvisTheme.accent)
                }
                .bounceOnTap()
                .padding(.top, 8)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackground))
        }
    }
}

struct AddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = PlannerStore.shared
    let theme: JarvisTheme
    let category: TaskCategory?
    @State private var name: String = ""
    @State private var colorIndex: Int = 0
    @State private var icon: String = "folder.fill"

    var body: some View {
        NavigationStack {
            Form {
                TextField("Название", text: $name)
                Section("Цвет") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<JarvisTheme.taskColors.count, id: \.self) { i in
                                Circle()
                                    .fill(JarvisTheme.taskColors[i])
                                    .frame(width: 36, height: 36)
                                    .overlay(colorIndex == i ? Circle().stroke(theme.textPrimary, lineWidth: 3) : nil)
                                    .onTapGesture { colorIndex = i }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                Section("Иконка") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(TaskIcon.allCases, id: \.rawValue) { taskIcon in
                                Image(systemName: taskIcon.systemName)
                                    .font(.system(size: 20))
                                    .foregroundColor(icon == taskIcon.rawValue ? JarvisTheme.taskColors[colorIndex] : theme.textSecondary)
                                    .frame(width: 44, height: 44)
                                    .background(Circle().fill(icon == taskIcon.rawValue ? JarvisTheme.taskColors[colorIndex].opacity(0.2) : Color.clear))
                                    .onTapGesture { icon = taskIcon.rawValue }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.background)
            .navigationTitle(category == nil ? "Новая категория" : "Редактировать")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        if let cat = category {
                            var updated = cat
                            updated.name = name
                            updated.colorIndex = colorIndex
                            updated.icon = icon
                            store.updateCategory(updated)
                        } else {
                            store.addCategory(TaskCategory(name: name, colorIndex: colorIndex, icon: icon))
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let cat = category {
                    name = cat.name
                    colorIndex = cat.colorIndex
                    icon = cat.icon
                }
            }
        }
    }
}

struct AddTagSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = PlannerStore.shared
    let theme: JarvisTheme
    let tag: TaskTag?
    @State private var name: String = ""
    @State private var colorIndex: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                TextField("Название тега", text: $name)
                Section("Цвет") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<JarvisTheme.taskColors.count, id: \.self) { i in
                                Circle()
                                    .fill(JarvisTheme.taskColors[i])
                                    .frame(width: 36, height: 36)
                                    .overlay(colorIndex == i ? Circle().stroke(theme.textPrimary, lineWidth: 3) : nil)
                                    .onTapGesture { colorIndex = i }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.background)
            .navigationTitle(tag == nil ? "Новый тег" : "Редактировать тег")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        if let t = tag {
                            var updated = t
                            updated.name = name
                            updated.colorIndex = colorIndex
                            store.updateTag(updated)
                        } else {
                            store.addTag(TaskTag(name: name, colorIndex: colorIndex))
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let t = tag {
                    name = t.name
                    colorIndex = t.colorIndex
                }
            }
        }
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showSleepCalculator = false
    let theme: JarvisTheme
    
    var body: some View {
        NavigationStack {
            SettingsContent(theme: theme, showSleepCalculator: $showSleepCalculator)
                .navigationTitle("Настройки")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Готово") { dismiss() }
                    }
                }
                .sheet(isPresented: $showSleepCalculator) {
                    SleepCalculatorSheet(theme: theme)
                }
        }
    }
}

// MARK: - Add Task Sheet

struct AddTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = PlannerStore.shared
    let date: Date
    let theme: JarvisTheme
    
    @State private var title = ""
    @State private var notes = ""
    @State private var taskDate: Date
    @State private var duration = 30
    @State private var isAllDay = false
    @State private var hasAlarm = true
    @State private var isInbox = false
    @State private var colorIndex = 0
    @State private var icon = "star.fill"
    @State private var selectedCategoryId: UUID?
    @State private var selectedTagIds: Set<UUID> = []

    init(date: Date, theme: JarvisTheme) {
        self.date = date
        self.theme = theme
        self._taskDate = State(initialValue: date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название задачи", text: $title)
                    TextField("Заметки", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }
                .animateOnAppear(delay: 0)
                
                Section("Категория") {
                    Picker("Категория", selection: $selectedCategoryId) {
                        Text("Без категории").tag(nil as UUID?)
                        ForEach(store.categories) { cat in
                            HStack(spacing: 8) {
                                Image(systemName: cat.icon)
                                    .foregroundColor(cat.color)
                                Text(cat.name)
                            }
                            .tag(cat.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Теги") {
                    if store.tags.isEmpty {
                        Text("Добавьте теги в настройках")
                            .foregroundColor(theme.textSecondary)
                    } else {
                        ForEach(store.tags) { tag in
                            Toggle(isOn: Binding(
                                get: { selectedTagIds.contains(tag.id) },
                                set: { if $0 { selectedTagIds.insert(tag.id) } else { selectedTagIds.remove(tag.id) } }
                            )) {
                                HStack(spacing: 8) {
                                    Circle().fill(tag.color).frame(width: 8, height: 8)
                                    Text(tag.name)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Toggle("В Inbox (без времени)", isOn: $isInbox)
                    
                    if !isInbox {
                        DatePicker("Дата и время", selection: $taskDate)
                        Toggle("Весь день", isOn: $isAllDay)
                        
                        if !isAllDay {
                            Picker("Длительность", selection: $duration) {
                                Text("15 мин").tag(15)
                                Text("30 мин").tag(30)
                                Text("45 мин").tag(45)
                                Text("1 час").tag(60)
                                Text("1.5 часа").tag(90)
                                Text("2 часа").tag(120)
                            }
                        }
                    }
                    
                    Toggle("Напоминание", isOn: $hasAlarm)
                }
                
                Section("Цвет") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<JarvisTheme.taskColors.count, id: \.self) { i in
                                Circle()
                                    .fill(JarvisTheme.taskColors[i])
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        colorIndex == i ?
                                        Circle().stroke(theme.textPrimary, lineWidth: 3) : nil
                                    )
                                    .onTapGesture { colorIndex = i }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section("Иконка") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(TaskIcon.allCases, id: \.rawValue) { taskIcon in
                                Image(systemName: taskIcon.systemName)
                                    .font(.system(size: 20))
                                    .foregroundColor(icon == taskIcon.rawValue ? JarvisTheme.taskColors[colorIndex] : theme.textSecondary)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle()
                                            .fill(icon == taskIcon.rawValue ? JarvisTheme.taskColors[colorIndex].opacity(0.2) : Color.clear)
                                    )
                                    .onTapGesture { icon = taskIcon.rawValue }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.background)
            .navigationTitle("Новая задача")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        let task = PlannerTask(
                            title: title,
                            notes: notes,
                            date: taskDate,
                            durationMinutes: duration,
                            isAllDay: isAllDay,
                            hasAlarm: hasAlarm,
                            isInbox: isInbox,
                            colorIndex: colorIndex,
                            icon: icon,
                            categoryId: selectedCategoryId,
                            tagIds: Array(selectedTagIds)
                        )
                        store.add(task)
                        CalendarSyncService.shared.addOrUpdateEvent(for: task)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Edit Task Sheet

struct EditTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = PlannerStore.shared
    let task: PlannerTask
    let theme: JarvisTheme
    
    @State private var title: String
    @State private var notes: String
    @State private var taskDate: Date
    @State private var duration: Int
    @State private var isAllDay: Bool
    @State private var hasAlarm: Bool
    @State private var isInbox: Bool
    @State private var colorIndex: Int
    @State private var icon: String
    @State private var selectedCategoryId: UUID?
    @State private var selectedTagIds: Set<UUID>

    init(task: PlannerTask, theme: JarvisTheme) {
        self.task = task
        self.theme = theme
        self._title = State(initialValue: task.title)
        self._notes = State(initialValue: task.notes)
        self._taskDate = State(initialValue: task.date)
        self._duration = State(initialValue: task.durationMinutes)
        self._isAllDay = State(initialValue: task.isAllDay)
        self._hasAlarm = State(initialValue: task.hasAlarm)
        self._isInbox = State(initialValue: task.isInbox)
        self._colorIndex = State(initialValue: task.colorIndex)
        self._icon = State(initialValue: task.icon)
        self._selectedCategoryId = State(initialValue: task.categoryId)
        self._selectedTagIds = State(initialValue: Set(task.tagIds))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название задачи", text: $title)
                    TextField("Заметки", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }
                
                Section("Категория") {
                    Picker("Категория", selection: $selectedCategoryId) {
                        Text("Без категории").tag(nil as UUID?)
                        ForEach(store.categories) { cat in
                            HStack(spacing: 8) {
                                Image(systemName: cat.icon)
                                    .foregroundColor(cat.color)
                                Text(cat.name)
                            }
                            .tag(cat.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Теги") {
                    if store.tags.isEmpty {
                        Text("Добавьте теги в настройках")
                            .foregroundColor(theme.textSecondary)
                    } else {
                        ForEach(store.tags) { tag in
                            Toggle(isOn: Binding(
                                get: { selectedTagIds.contains(tag.id) },
                                set: { if $0 { selectedTagIds.insert(tag.id) } else { selectedTagIds.remove(tag.id) } }
                            )) {
                                HStack(spacing: 8) {
                                    Circle().fill(tag.color).frame(width: 8, height: 8)
                                    Text(tag.name)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Toggle("В Inbox (без времени)", isOn: $isInbox)
                    
                    if !isInbox {
                        DatePicker("Дата и время", selection: $taskDate)
                        Toggle("Весь день", isOn: $isAllDay)
                        
                        if !isAllDay {
                            Picker("Длительность", selection: $duration) {
                                Text("15 мин").tag(15)
                                Text("30 мин").tag(30)
                                Text("45 мин").tag(45)
                                Text("1 час").tag(60)
                                Text("1.5 часа").tag(90)
                                Text("2 часа").tag(120)
                            }
                        }
                    }
                    
                    Toggle("Напоминание", isOn: $hasAlarm)
                }
                
                Section("Цвет") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<JarvisTheme.taskColors.count, id: \.self) { i in
                                Circle()
                                    .fill(JarvisTheme.taskColors[i])
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        colorIndex == i ?
                                        Circle().stroke(theme.textPrimary, lineWidth: 3) : nil
                                    )
                                    .onTapGesture { colorIndex = i }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section("Иконка") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(TaskIcon.allCases, id: \.rawValue) { taskIcon in
                                Image(systemName: taskIcon.systemName)
                                    .font(.system(size: 20))
                                    .foregroundColor(icon == taskIcon.rawValue ? JarvisTheme.taskColors[colorIndex] : theme.textSecondary)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle()
                                            .fill(icon == taskIcon.rawValue ? JarvisTheme.taskColors[colorIndex].opacity(0.2) : Color.clear)
                                    )
                                    .onTapGesture { icon = taskIcon.rawValue }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section {
                    Button("Удалить задачу", role: .destructive) {
                        CalendarSyncService.shared.removeEvent(for: task)
                        store.delete(task)
                        dismiss()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.background)
            .navigationTitle("Редактирование")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        var updated = task
                        updated.title = title
                        updated.notes = notes
                        updated.date = taskDate
                        updated.durationMinutes = duration
                        updated.isAllDay = isAllDay
                        updated.hasAlarm = hasAlarm
                        updated.isInbox = isInbox
                        updated.colorIndex = colorIndex
                        updated.icon = icon
                        updated.categoryId = selectedCategoryId
                        updated.tagIds = Array(selectedTagIds)
                        store.update(updated)
                        CalendarSyncService.shared.addOrUpdateEvent(for: updated)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }
}

#if os(iOS)
struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - Preview

#Preview {
    StructuredMainView()
}
