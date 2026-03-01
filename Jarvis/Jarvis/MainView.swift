import SwiftUI

struct MainView: View {
    @StateObject private var store = PlannerStore()
    @StateObject private var wellness = WellnessStore()
    @StateObject private var aiManager = AIManager()
    
    var body: some View {
        #if os(watchOS)
        watchOSView
        #elseif os(macOS)
        macOSView
        #else
        iOSView
        #endif
    }
    
    // MARK: - iOS/iPadOS
    
    #if os(iOS)
    private var iOSView: some View {
        TabView {
            PlannerView(store: store, aiManager: aiManager)
                .tabItem { Label("План", systemImage: "checklist") }
            
            CalendarView()
                .tabItem { Label("Календарь", systemImage: "calendar") }
            
            MailView()
                .tabItem { Label("Почта", systemImage: "envelope") }
            
            AnalyticsView(tasks: store.scheduledTasks, aiManager: aiManager)
                .tabItem { Label("Аналитика", systemImage: "chart.bar.xaxis") }
            
            WellnessView(store: store, wellness: wellness, aiManager: aiManager)
                .tabItem { Label("Здоровье", systemImage: "heart.text.square") }
            
            SettingsView(store: store, aiManager: aiManager)
                .tabItem { Label("Настройки", systemImage: "gearshape") }
        }
        .tint(JarvisTheme.accent)
    }
    #endif
    
    // MARK: - macOS (Structured-style)
    
    #if os(macOS)
    @State private var selectedTab: MacTab = .planner
    
    enum MacTab: String, CaseIterable {
        case planner = "План"
        case analytics = "Аналитика"
        case wellness = "Здоровье"
        case settings = "Настройки"
        
        var icon: String {
            switch self {
            case .planner: return "checklist"
            case .analytics: return "chart.bar.xaxis"
            case .wellness: return "heart.text.square"
            case .settings: return "gearshape"
            }
        }
    }
    
    private var macOSView: some View {
        VStack(spacing: 0) {
            // Top Navigation Bar
            macOSNavBar
            
            Divider()
            
            // Content
            Group {
                switch selectedTab {
                case .planner:
                    MacPlannerView(store: store, aiManager: aiManager)
                case .analytics:
                    AnalyticsView(tasks: store.scheduledTasks, aiManager: aiManager)
                case .wellness:
                    WellnessView(store: store, wellness: wellness, aiManager: aiManager)
                case .settings:
                    SettingsView(store: store, aiManager: aiManager)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(JarvisTheme.background)
    }
    
    private var macOSNavBar: some View {
        HStack(spacing: 16) {
            // Tab Buttons
            HStack(spacing: 4) {
                ForEach(MacTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                            Text(tab.rawValue)
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(selectedTab == tab ? .white : JarvisTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedTab == tab ? JarvisTheme.accent : .clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                }
            }
            .padding(4)
            .background(
                Capsule()
                    .fill(JarvisTheme.chipBackground)
            )
            
            Spacer()
            
            // Sync Status
            HStack(spacing: 8) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text("iCloud")
                    .font(.caption)
                    .foregroundStyle(JarvisTheme.textSecondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(JarvisTheme.cardBackground)
    }
    #endif
}

// MARK: - macOS Planner View

#if os(macOS)
struct MacPlannerView: View {
    @ObservedObject var store: PlannerStore
    @ObservedObject var aiManager: AIManager
    
    @State private var selectedDay = Date()
    @State private var showAddSheet = false
    @State private var editingTask: PlannerTask?
    @State private var activeTab: PlannerTab = .timeline
    
    enum PlannerTab: String, CaseIterable { 
        case timeline = "Таймлайн"
        case inbox = "Inbox" 
    }
    
    private let calendar = Calendar.current
    private let hourRowHeight: CGFloat = 56
    
    var body: some View {
        HSplitView {
            // Left: Timeline
            VStack(spacing: 0) {
                // Date Strip
                macDateStrip
                
                Divider()
                
                // Tab Picker
                HStack {
                    StructuredSegmentedControl(
                        items: PlannerTab.allCases,
                        selection: $activeTab,
                        title: { $0.rawValue }
                    )
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                // Content
                if activeTab == .timeline {
                    timelineView
                } else {
                    inboxView
                }
            }
            .frame(minWidth: 400)
            .background(JarvisTheme.background)
            
            // Right: Task Details / Quick Add
            rightPanel
                .frame(minWidth: 280, maxWidth: 350)
        }
        .sheet(isPresented: $showAddSheet) {
            StructuredAddTaskSheet(store: store, referenceDate: selectedDay) { task in
                if task.isInbox {
                    store.addToInbox(task)
                } else {
                    store.add(task)
                    NotificationManager.shared.scheduleAlarm(for: task)
                }
            }
        }
        .sheet(item: $editingTask) { task in
            StructuredEditTaskSheet(
                task: task,
                store: store,
                onSave: { updated in
                    store.update(updated)
                    NotificationManager.shared.cancelAlarm(for: task)
                    if updated.hasAlarm && !updated.isInbox {
                        NotificationManager.shared.scheduleAlarm(for: updated)
                    }
                },
                onDelete: { t in
                    NotificationManager.shared.cancelAlarm(for: t)
                    CalendarSyncService.shared.removeEvent(for: t)
                    store.remove(task: t)
                }
            )
        }
    }
    
    // MARK: - Date Strip
    
    private var macDateStrip: some View {
        VStack(spacing: 8) {
            HStack {
                Text(monthYearText)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(JarvisTheme.textPrimary)
                
                Spacer()
                
                Button("Сегодня") {
                    withAnimation { selectedDay = Date() }
                }
                .buttonStyle(.plain)
                .foregroundStyle(JarvisTheme.accent)
                
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(JarvisTheme.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(daysInRange, id: \.self) { day in
                        MacDateCell(
                            day: day,
                            isSelected: calendar.isDate(day, inSameDayAs: selectedDay),
                            isToday: calendar.isDateInToday(day),
                            taskCount: store.tasksForDay(day).count
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedDay = day
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 12)
        }
        .background(JarvisTheme.cardBackground)
    }
    
    private var monthYearText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: selectedDay).capitalized
    }
    
    private var daysInRange: [Date] {
        let start = calendar.date(byAdding: .day, value: -7, to: Date())!
        return (0..<30).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
    
    // MARK: - Timeline
    
    private var timelineView: some View {
        let bounds = store.dayBounds
        let dayStart = bounds.riseDate(on: selectedDay)
        let startHour = bounds.riseHour
        let endHour = bounds.windDownHour + 1
        let timelineTasks = store.timelineTasks(for: selectedDay)
        let allDayTasks = store.allDayTasks(for: selectedDay)
        
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // All Day
                if !allDayTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ВЕСЬ ДЕНЬ")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JarvisTheme.textTertiary)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        
                        ForEach(allDayTasks) { task in
                            MacTaskRow(task: task) {
                                store.toggleCompletion(task: task, onDay: selectedDay)
                            } onEdit: {
                                editingTask = task
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 12)
                    }
                }
                
                // Timeline Grid
                ZStack(alignment: .topLeading) {
                    // Hour lines
                    VStack(spacing: 0) {
                        ForEach(startHour..<endHour, id: \.self) { hour in
                            HStack(alignment: .top, spacing: 12) {
                                Text(String(format: "%02d:00", hour % 24))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(JarvisTheme.textTertiary)
                                    .frame(width: 40, alignment: .trailing)
                                
                                Rectangle()
                                    .fill(JarvisTheme.hourLine)
                                    .frame(height: 1)
                            }
                            .frame(height: hourRowHeight)
                        }
                    }
                    .padding(.leading, 16)
                    
                    // Tasks
                    ForEach(timelineTasks) { task in
                        let startOffset = max(0, task.date.timeIntervalSince(dayStart) / 3600 * hourRowHeight)
                        let height = max(32, CGFloat(task.durationMinutes) / 60 * hourRowHeight)
                        
                        MacTimelineBlock(task: task, height: height) {
                            store.toggleCompletion(task: task, onDay: selectedDay)
                        } onEdit: {
                            editingTask = task
                        }
                        .padding(.leading, 68)
                        .padding(.trailing, 16)
                        .offset(y: startOffset)
                    }
                }
                .padding(.bottom, 50)
            }
        }
    }
    
    // MARK: - Inbox
    
    private var inboxView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if store.inboxTasks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundStyle(JarvisTheme.textTertiary)
                        Text("Inbox пуст")
                            .font(.headline)
                            .foregroundStyle(JarvisTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    ForEach(store.inboxTasks) { task in
                        MacTaskRow(task: task) {
                            var t = task
                            t.isCompleted.toggle()
                            store.update(t)
                        } onEdit: {
                            editingTask = task
                        }
                    }
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Right Panel
    
    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Сводка")
                .font(.headline.weight(.semibold))
                .foregroundStyle(JarvisTheme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Today Stats
                    statsCard
                    
                    // Upcoming
                    upcomingCard
                    
                    // Quick Add
                    quickAddCard
                }
                .padding(16)
            }
        }
        .background(JarvisTheme.cardBackground)
    }
    
    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Сегодня")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(JarvisTheme.textSecondary)
            
            let todayTasks = store.tasksForDay(Date())
            let completed = todayTasks.filter(\.isCompleted).count
            
            HStack(spacing: 20) {
                VStack {
                    Text("\(todayTasks.count)")
                        .font(.title.weight(.bold))
                        .foregroundStyle(JarvisTheme.accent)
                    Text("всего")
                        .font(.caption)
                        .foregroundStyle(JarvisTheme.textTertiary)
                }
                
                VStack {
                    Text("\(completed)")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.green)
                    Text("готово")
                        .font(.caption)
                        .foregroundStyle(JarvisTheme.textTertiary)
                }
                
                VStack {
                    Text("\(store.inboxTasks.count)")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.orange)
                    Text("inbox")
                        .font(.caption)
                        .foregroundStyle(JarvisTheme.textTertiary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(JarvisTheme.background)
        )
    }
    
    private var upcomingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ближайшие")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(JarvisTheme.textSecondary)
            
            let upcoming = store.scheduledTasks
                .filter { $0.date > Date() && !$0.isCompleted }
                .prefix(3)
            
            if upcoming.isEmpty {
                Text("Нет предстоящих задач")
                    .font(.caption)
                    .foregroundStyle(JarvisTheme.textTertiary)
            } else {
                ForEach(Array(upcoming)) { task in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(task.taskColor)
                            .frame(width: 8, height: 8)
                        Text(task.title)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        Text(task.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(JarvisTheme.textTertiary)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(JarvisTheme.background)
        )
    }
    
    private var quickAddCard: some View {
        Button {
            showAddSheet = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(JarvisTheme.accent)
                Text("Новая задача")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(JarvisTheme.textPrimary)
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(JarvisTheme.background)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - macOS Components

struct MacDateCell: View {
    let day: Date
    let isSelected: Bool
    let isToday: Bool
    let taskCount: Int
    let action: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(weekdayShort)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isSelected ? .white : JarvisTheme.textTertiary)
                
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? .white : (isToday ? JarvisTheme.accent : JarvisTheme.textPrimary))
                
                if taskCount > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<min(taskCount, 3), id: \.self) { _ in
                            Circle()
                                .fill(isSelected ? .white.opacity(0.8) : JarvisTheme.accent)
                                .frame(width: 4, height: 4)
                        }
                    }
                } else {
                    Spacer().frame(height: 4)
                }
            }
            .frame(width: 44, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? JarvisTheme.accent : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isToday && !isSelected ? JarvisTheme.accent : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var weekdayShort: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: day).prefix(2)).uppercased()
    }
}

struct MacTaskRow: View {
    let task: PlannerTask
    let onToggle: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(task.taskColor)
                .frame(width: 4)
            
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(task.isCompleted ? task.taskColor : JarvisTheme.textTertiary, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    
                    if task.isCompleted {
                        Circle()
                            .fill(task.taskColor)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(task.isCompleted ? JarvisTheme.textTertiary : JarvisTheme.textPrimary)
                    .strikethrough(task.isCompleted)
                
                if !task.isAllDay {
                    Text(task.date.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(JarvisTheme.textTertiary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(JarvisTheme.cardBackground)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
    }
}

struct MacTimelineBlock: View {
    let task: PlannerTask
    let height: CGFloat
    let onToggle: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(task.taskColor)
                .frame(width: 4)
            
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(task.isCompleted ? task.taskColor : JarvisTheme.textTertiary, lineWidth: 2)
                        .frame(width: 18, height: 18)
                    
                    if task.isCompleted {
                        Circle()
                            .fill(task.taskColor)
                            .frame(width: 10, height: 10)
                    }
                }
            }
            .buttonStyle(.plain)
            
            Text(task.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(task.isCompleted ? JarvisTheme.textTertiary : JarvisTheme.textPrimary)
                .strikethrough(task.isCompleted)
                .lineLimit(2)
            
            Spacer()
            
            Text(task.date.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundStyle(JarvisTheme.textTertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(height: height - 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(JarvisTheme.cardBackground)
                .shadow(color: JarvisTheme.cardShadow, radius: 4, x: 0, y: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
    }
}
#endif

// MARK: - watchOS Views

#if os(watchOS)
extension MainView {
    var watchOSView: some View {
        NavigationStack {
            List {
                NavigationLink {
                    WatchPlannerView(store: store)
                } label: {
                    Label("План", systemImage: "checklist")
                }
                NavigationLink {
                    WatchWellnessView(wellness: wellness)
                } label: {
                    Label("Здоровье", systemImage: "heart.text.square")
                }
            }
            .navigationTitle("Jarvis")
        }
    }
}

struct WatchPlannerView: View {
    @ObservedObject var store: PlannerStore
    @State private var selectedDay = Date()
    
    var body: some View {
        List {
            Section {
                let tasks = store.tasksForDay(selectedDay)
                if tasks.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.green)
                        Text("Всё сделано!")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(tasks) { task in
                        WatchTaskRow(task: task) {
                            store.toggleCompletion(task: task, onDay: selectedDay)
                        }
                    }
                }
            } header: {
                Text("Сегодня")
            }
            
            if !store.inboxTasks.isEmpty {
                Section {
                    ForEach(store.inboxTasks.prefix(5)) { task in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(task.taskColor)
                                .frame(width: 8, height: 8)
                            Text(task.title)
                                .lineLimit(1)
                        }
                    }
                } header: {
                    Text("Inbox")
                }
            }
        }
        .navigationTitle("План")
    }
}

struct WatchTaskRow: View {
    let task: PlannerTask
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Circle()
                    .fill(task.taskColor)
                    .frame(width: 8, height: 8)
                
                ZStack {
                    Circle()
                        .strokeBorder(task.isCompleted ? task.taskColor : .secondary, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    
                    if task.isCompleted {
                        Circle()
                            .fill(task.taskColor)
                            .frame(width: 12, height: 12)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.footnote.weight(.medium))
                        .lineLimit(1)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    
                    if !task.isAllDay {
                        Text(task.date.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct WatchWellnessView: View {
    @ObservedObject var wellness: WellnessStore
    
    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(wellness.todayCalories)")
                        .font(.title2.weight(.semibold))
                    Text("ккал")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Калории")
            }
            
            if let lastSleep = wellness.sleep.last {
                Section {
                    HStack {
                        Image(systemName: "bed.double.fill")
                            .foregroundStyle(.indigo)
                        Text(String(format: "%.1f", lastSleep.hours))
                            .font(.title2.weight(.semibold))
                        Text("часов")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Сон")
                }
            }
            
            Section {
                let todayActivity = wellness.activities.filter { Calendar.current.isDateInToday($0.date) }
                let totalMinutes = todayActivity.reduce(0) { $0 + $1.minutes }
                HStack {
                    Image(systemName: "figure.run")
                        .foregroundStyle(.green)
                    Text("\(totalMinutes)")
                        .font(.title2.weight(.semibold))
                    Text("мин")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Активность")
            }
        }
        .navigationTitle("Здоровье")
    }
}
#endif
