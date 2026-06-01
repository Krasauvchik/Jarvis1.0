import SwiftUI
import Combine
import EventKit
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
    @ObservedObject private var langManager = LanguageManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var vm = StructuredMainViewModel()
    @State private var googleEvents: [CalendarService.EventDTO] = []
    @State private var isLoadingGoogleEvents = false
    
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
        .id(langManager.currentLanguage)
        #if os(macOS)
        .frame(minWidth: 900, minHeight: 600)
        #endif
        #if !os(watchOS)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        #endif
        .sheet(isPresented: $vm.showAddTask) {
            AddTaskSheet(date: vm.selectedDate, theme: theme)
        }
        .sheet(item: $vm.editingTask) { task in
            EditTaskSheet(task: task, theme: theme)
        }
        .sheet(isPresented: $vm.showSettings) {
            SettingsSheet(theme: theme)
        }
        .sheet(isPresented: $vm.showProfile) {
            ProfileSheet(theme: theme)
        }
        .sheet(isPresented: $vm.showSleepCalculator) {
            SleepCalculatorSheet(theme: theme)
        }
        .applyTheme(themeManager)
        #if !os(watchOS)
        .onReceive(deepLinkManager.$pendingTaskID.compactMap { $0 }) { taskID in
            if let task = store.tasks.first(where: { $0.id == taskID }) {
                vm.editingTask = task
                deepLinkManager.clearPendingTask()
            }
        }
        .onReceive(deepLinkManager.$pendingSection.compactMap { $0 }) { sectionName in
            if let section = deepLinkManager.resolveSection(sectionName) {
                vm.selectedSection = section
                // Map section to iPhone tab index
                switch section {
                case .today: vm.selectedTab = 0
                case .inbox: vm.selectedTab = 1
                case .mailSection: vm.selectedTab = 2
                case .chat: vm.selectedTab = 3
                case .analytics: vm.selectedTab = 4
                default: break
                }
            }
            deepLinkManager.clearPendingSection()
        }
        .onReceive(deepLinkManager.$pendingAddTask) { show in
            if show {
                vm.showAddTask = true
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
                    Button(action: { vm.showAddTask = true }) {
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
            Button(action: { vm.toggleTask(task) }) {
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
            
            TabView(selection: $vm.selectedTab) {
                if appMode == .work {
                    todayTab
                        .tabItem { Label(L10n.tabToday, systemImage: "calendar") }
                        .tag(0)
                    
                    inboxTab
                        .tabItem { Label(L10n.tabInbox, systemImage: "tray.fill") }
                        .tag(1)
                    
                    mailTab
                        .tabItem { Label(L10n.tabMail, systemImage: "envelope.fill") }
                        .tag(2)
                    
                    neuralTab
                        .tabItem { Label(L10n.tabAI, systemImage: "brain.head.profile") }
                        .tag(3)
                    
                    analyticsTab
                        .tabItem { Label(L10n.tabAnalytics, systemImage: "chart.bar.xaxis") }
                        .tag(4)
                    
                    settingsTab
                        .tabItem { Label(L10n.tabSettings, systemImage: "gearshape.fill") }
                        .tag(5)
                } else {
                    // Personal mode
                    todayTab
                        .tabItem { Label(L10n.tabToday, systemImage: "calendar") }
                        .tag(0)
                    
                    healthTab
                        .tabItem { Label(L10n.healthTitle, systemImage: "heart.text.square.fill") }
                        .tag(10)
                    
                    settingsTab
                        .tabItem { Label(L10n.tabSettings, systemImage: "gearshape.fill") }
                        .tag(5)
                }
            }
            .tint(appMode.color)
        }
    }
    
    private var iPhoneModeToggle: some View {
        HStack(spacing: 0) {
            ForEach(AppMode.allCases) { mode in
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        appModeRaw = mode.rawValue
                        vm.selectedTab = 0
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
                    selectedSection: $vm.selectedSection,
                    selectedCategoryId: $vm.selectedCategoryId,
                    appMode: appModeBinding,
                    store: store,
                    onHide: { withAnimation(.easeInOut(duration: 0.2)) { leftPanelHidden = true } },
                    onShowSleepCalculator: { vm.showSleepCalculator = true },
                    onShowSettings: { vm.showSettings = true },
                    onShowProfile: { vm.showProfile = true }
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
            
            if AppRouter.isTaskListSection(vm.selectedSection) {
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
                    selectedDate: $vm.selectedDate,
                    store: store,
                    onEditTask: { vm.editingTask = $0 },
                    onToggleTask: { vm.toggleTask($0) }
                )
                .frame(minWidth: 320)
            } else {
                AppRouter.destination(
                    for: vm.selectedSection,
                    dependencies: dependencies,
                    theme: theme,
                    store: store,
                    selectedDate: $vm.selectedDate,
                    editingTask: $vm.editingTask,
                    wellness: wellness,
                    toggleTask: { vm.toggleTask($0) }
                )
            }
        }
        .background(theme.background)
        .task { syncSystemCalendarEvents() }
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
                    Text(vm.selectedSection.localizedName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                    
                    Text(vm.sectionSubtitle)
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondary)
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.selectedSection)
                
                Spacer()
                
                Button(action: { vm.showAddTask = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(vm.selectedSection.color)
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
                TextField(L10n.searchTasks, text: $vm.searchQuery)
                    .textFieldStyle(.plain)
                    .accessibilityLabel(L10n.searchTasks)
                    .accessibilityHint(L10n.searchHint)
                if !vm.searchQuery.isEmpty {
                    Button(action: { vm.searchQuery = "" }) {
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
                    let tasks = vm.filteredTasksForCurrentSection
                    
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
                .animation(.spring(response: 0.45, dampingFraction: 0.75), value: vm.filteredTasksForCurrentSection.map(\.id))
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
            
            Spacer()
            
            // Add Button
            Button(action: { vm.showAddTask = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text(L10n.addButton)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(vm.selectedSection.color))
            }
            .buttonStyle(.plain)
            .bounceOnTap()
            .padding(.bottom, 16)
        }
        .background(theme.inboxBackground)
    }
    
    private var emptyStateForSection: some View {
        VStack(spacing: 12) {
            Image(systemName: vm.selectedSection.icon)
                .font(.system(size: 40))
                .foregroundColor(vm.selectedSection.color.opacity(0.5))
            
            Text(vm.emptyStateText)
                .font(.system(size: 15))
                .foregroundColor(theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .animateOnAppear(delay: 0.1)
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
                    Button(action: { vm.scheduleTaskToToday(task) }) {
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
            .onTapGesture { vm.editingTask = task }
            
            TaskCompletionCircle(task: task, size: 24) { vm.toggleTask(task) }
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
        .draggable(task.id.uuidString) { DragPreview(task: task, theme: theme) }
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
                        todayMeetingsSection
                        timelineList
                    }
                }
                .background(theme.background)
                .task {
                    await loadGoogleEvents()
                    syncSystemCalendarEvents()
                }
                .onChange(of: vm.selectedDate) { _, _ in
                    Task { await loadGoogleEvents() }
                }
                
                // Floating add task button
                floatingAddButton
                
                // AI Assistant overlay
                AIAssistantOverlay()
                
                // Monthly calendar overlay popup
                if vm.showMonthCalendar {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation(.spring(response: 0.3)) { vm.showMonthCalendar = false } }
                    
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
                    Button(action: { vm.showProfile = true }) {
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
            .navigationTitle(L10n.tabInbox)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
    }
    
    // MARK: - Completed Tab (iPhone) — extracted to CompletedTabView.swift
    
    private var completedTab: some View {
        CompletedTabView(
            theme: theme,
            store: store,
            editingTask: $vm.editingTask,
            onToggleTask: { vm.toggleTask($0) },
            onDeleteTask: { task in
                dependencies.calendarSyncService.removeEvent(for: task)
                store.delete(task)
            }
        )
    }
    
    // MARK: - Today Meetings Section
    
    private var mergedDayEvents: [CalendarEventItem] {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: vm.selectedDate)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        
        // Collect calendarEventIds already imported into PlannerStore
        let importedEventIds = Set(store.tasks.compactMap(\.calendarEventId))
        
        var items: [CalendarEventItem] = []
        
        // Google Calendar events for this day
        for dto in googleEvents {
            guard dto.startDate >= dayStart, dto.startDate < dayEnd else { continue }
            items.append(CalendarEventItem(
                id: dto.id,
                title: dto.title,
                notes: dto.notes,
                startDate: dto.startDate,
                endDate: dto.endDate,
                location: dto.location,
                isAllDay: dto.isAllDay ?? false,
                source: .google
            ))
        }
        
        // Local EventKit events — skip those already imported into PlannerStore
        let localEvents = dependencies.calendarSyncService.events(for: vm.selectedDate)
        for ek in localEvents {
            let ekId = ek.eventIdentifier ?? ""
            // Skip if already synced to store
            if !ekId.isEmpty && importedEventIds.contains(ekId) { continue }
            
            let ekTitle = (ek.title ?? "").trimmingCharacters(in: .whitespaces)
            // Deduplicate: skip if Google already has an event with same title and close start time
            let isDuplicate = items.contains { google in
                let titleMatch = google.title.trimmingCharacters(in: .whitespaces).lowercased() == ekTitle.lowercased()
                let timeDiff = abs(google.startDate.timeIntervalSince(ek.startDate))
                return titleMatch && timeDiff < 300 // within 5 minutes
            }
            if !isDuplicate {
                items.append(CalendarEventItem(
                    id: "ek_\(ek.eventIdentifier ?? UUID().uuidString)",
                    title: ek.title ?? L10n.noSubject,
                    notes: ek.notes,
                    startDate: ek.startDate,
                    endDate: ek.endDate,
                    location: ek.location,
                    isAllDay: ek.isAllDay,
                    source: .local
                ))
            }
        }
        
        return items.sorted { $0.startDate < $1.startDate }
    }
    
    private var todayMeetingsSection: some View {
        let events = mergedDayEvents
        
        return Group {
            if !events.isEmpty || isLoadingGoogleEvents {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(JarvisTheme.accent)
                        Text(L10n.calendarTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        if isLoadingGoogleEvents {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        Text("\(events.count)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(theme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(theme.textSecondary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    
                    // Vertical event list
                    ForEach(events) { event in
                        meetingRow(event)
                    }
                    
                    Divider()
                        .padding(.horizontal)
                        .padding(.top, 4)
                }
            }
        }
    }
    
    private func meetingRow(_ event: CalendarEventItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Time column
            VStack(alignment: .trailing, spacing: 2) {
                if event.isAllDay {
                    Text(L10n.allDay)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.purple)
                } else {
                    Text(event.startDate.formatted(date: .omitted, time: .shortened))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.textPrimary)
                    if let end = event.endDate {
                        Text(end.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
            .frame(width: 50, alignment: .trailing)
            
            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(event.source == .google ? Color.blue : Color.orange)
                .frame(width: 3)
            
            // Content
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)
                
                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
                
                if let notes = event.notes, !notes.isEmpty {
                    Text(String(notes.prefix(80))
                        .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
    
    private func loadGoogleEvents() async {
        isLoadingGoogleEvents = true
        defer { isLoadingGoogleEvents = false }
        
        do {
            let authorized = try await AuthService.shared.checkAuth()
            guard authorized else {
                googleEvents = []
                return
            }
            googleEvents = try await CalendarService.shared.fetchEventsAsDTO(daysAhead: 30)
        } catch {
            googleEvents = []
        }
    }
    
    private func syncSystemCalendarEvents() {
        let ekService = EventKitService.shared
        if ekService.calendarAccessGranted {
            ekService.loadCalendars()
            ekService.syncEventsToStore()
        }
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
    
    // MARK: - AI Overlay (for iPad/Mac three-column layout)
    
    private var aiOverlay: some View {
        AIAssistantOverlay()
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
            SettingsContent(theme: theme, showSleepCalculator: $vm.showSleepCalculator)
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
            vm.editingTask = task
        } label: {
            Label(L10n.editTask, systemImage: "pencil")
        }
        
        Button {
            vm.toggleTask(task)
        } label: {
            Label(task.isCompleted ? L10n.markIncomplete : L10n.markComplete, 
                  systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark.circle")
        }
        
        Divider()
        
        Button {
            vm.duplicateTask(task)
        } label: {
            Label(L10n.duplicateTask, systemImage: "doc.on.doc")
        }
        
        if !task.isInbox {
            Button {
                vm.moveToInbox(task)
            } label: {
                Label(L10n.moveToInbox, systemImage: "tray")
            }
        }
        
        Button {
            vm.scheduleForTomorrow(task)
        } label: {
            Label(L10n.moveToTomorrow, systemImage: "calendar.badge.plus")
        }
        
        Button {
            vm.moveTaskToFuturePlans(task)
        } label: {
            Label(L10n.moveToFuture, systemImage: "sparkles")
        }
        
        Divider()
        
        Menu(L10n.colorMenu) {
            ForEach(0..<JarvisTheme.taskColors.count, id: \.self) { index in
                Button {
                    vm.changeTaskColor(task, to: index)
                } label: {
                    Label(colorName(index), systemImage: task.colorIndex == index ? "checkmark.circle.fill" : "circle.fill")
                }
            }
        }
        
        Divider()
        
        #if !os(watchOS)
        Button {
            MessengerService.shared.shareTask(task, via: .telegram)
        } label: {
            Label("Telegram", systemImage: "paperplane.fill")
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
                withAnimation(.spring(response: 0.3)) { vm.showMonthCalendar.toggle() }
            }) {
                HStack(spacing: 4) {
                    Text("\(vm.selectedDate.formatted(.dateTime.day())) \(vm.selectedDate.formatted(.dateTime.month(.wide)))")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                    Text(vm.selectedDate.formatted(.dateTime.year()))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(JarvisTheme.accent)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(JarvisTheme.accent)
                        .rotationEffect(.degrees(vm.showMonthCalendar ? 90 : 0))
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
            Button(action: { vm.moveDate(by: -1) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(theme.cardBackground))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.previousDay)
            
            Button(action: { vm.selectedDate = Date() }) {
                Text(L10n.today)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(JarvisTheme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(theme.cardBackground))
            }
            .buttonStyle(.plain)
            
            Button(action: { vm.moveDate(by: 1) }) {
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
                    ForEach(vm.getWeekDays(), id: \.self) { date in
                        weekDayCell(date: date, compact: true)
                            .id(date)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    proxy.scrollTo(vm.selectedDate, anchor: .center)
                }
            }
        }
        .padding(.bottom, 12)
    }
    
    private func weekDayCell(date: Date, compact: Bool) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: vm.selectedDate)
        let isToday = Calendar.current.isDateInToday(date)
        let taskCount = store.tasksForDay(date).filter { !$0.isInbox && !$0.isCompleted }.count
        
        return Button(action: { vm.selectedDate = date }) {
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
                vm.moveTaskToDate(uuid, date: date)
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
                .fill(vm.completedDropHighlighted ? JarvisTheme.accentGreen.opacity(0.2) : theme.cardBackground.opacity(0.8))
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .dropDestination(for: String.self) { items, _ in
            guard let taskID = items.first, let uuid = UUID(uuidString: taskID) else { return false }
            vm.moveTask(taskID: uuid, to: .completed)
            vm.completedDropHighlighted = false
            return true
        } isTargeted: { vm.completedDropHighlighted = $0 }
    }
    
    private var timelineList: some View {
        let dayTasks = store.tasksForDay(vm.selectedDate).filter { !$0.isInbox && !$0.isCompleted }
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
    
    // MARK: - Structured Timeline (extracted to StructuredTimelineSection.swift)
    
    private func structuredTimeline(tasks: [PlannerTask]) -> AnyView {
        StructuredTimelineContent(
            theme: theme,
            tasks: tasks,
            selectedDate: vm.selectedDate,
            onEditTask: { vm.editingTask = $0 },
            onToggleTask: { vm.toggleTask($0) },
            onAddTaskAtTime: { vm.addTaskAtTime(hour: $0, minute: $1) }
        )
        .eraseToAnyView()
    }
    
    // MARK: - Task Rows
    
    private func taskRow(_ task: PlannerTask) -> some View {
        HStack(spacing: 12) {
            // Область для тапа «редактировать» — без кружка, чтобы кружок только переключал выполнение
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(task.taskColor)
                    .frame(width: 4)
                
                TaskIconBadge(task: task, size: 40)
                
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
                            Text(DurationFormatter.format(task.durationMinutes))
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
            .onTapGesture { vm.editingTask = task }
            
            Spacer(minLength: 8)
            
            TaskCompletionCircle(task: task, size: 24) { vm.toggleTask(task) }
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
            Button { vm.toggleTask(task) } label: {
                Label(task.isCompleted ? L10n.markIncomplete : L10n.markComplete, systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(JarvisTheme.accentGreen)
        }
    }
    
    private func draggableTaskRow(_ task: PlannerTask) -> some View {
        taskRow(task)
            .draggable(task.id.uuidString) { DragPreview(task: task, theme: theme) }
    }
    
    private func inboxTaskRow(_ task: PlannerTask) -> some View {
        HStack(spacing: 12) {
            TaskIconBadge(task: task, size: 40, defaultIcon: "tray.fill")
            
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
            
            Button(action: { vm.scheduleTaskToToday(task) }) {
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
        .onTapGesture { vm.editingTask = task }
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
            Button { vm.scheduleTaskToToday(task) } label: {
                Label(L10n.scheduleAction, systemImage: "calendar")
            }
            .tint(JarvisTheme.accentBlue)
        }
    }
    
    // MARK: - Empty States
    
    private var emptyTimelineView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)
            EmptyStateView(
                icon: "sun.max.fill",
                title: L10n.noTasksThisDay,
                description: L10n.emptyDayDescription,
                actionTitle: L10n.addTask,
                onAction: { vm.showAddTask = true }
            )
            Spacer()
        }
    }
    
    private var emptyInboxView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)
            EmptyStateView(
                icon: "tray.fill",
                title: L10n.inboxTitle,
                description: L10n.inboxEmptyDescription,
                actionTitle: L10n.newInboxTask,
                onAction: { vm.showAddTask = true }
            )
            Spacer()
        }
    }
    
    // Month Calendar Popup — extracted to MonthCalendarPopup.swift
    private var monthCalendarPopup: some View {
        MonthCalendarPopup(
            theme: theme,
            selectedDate: $vm.selectedDate,
            showMonthCalendar: $vm.showMonthCalendar,
            store: store
        )
    }
    
    private var floatingAddButton: some View {
        Button(action: { vm.showAddTask = true }) {
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
    
    #endif
}

// MARK: - Preview

#Preview {
    StructuredMainView()
}
