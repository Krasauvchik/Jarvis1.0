import SwiftUI

#if !os(watchOS)

// MARK: - Structured-style Planner View

struct PlannerView: View {
    @ObservedObject var store: PlannerStore
    @ObservedObject var aiManager: AIManager
    
    #if os(iOS)
    @StateObject private var speech = SpeechRecognizer()
    #endif

    @State private var selectedDay = Date()
    @State private var showAddSheet = false
    @State private var editingTask: PlannerTask?
    @State private var taskToDelete: PlannerTask?
    @State private var activeTab: PlannerTab = .timeline
    @State private var timelineViewMode: TimelineViewMode = .day

    private let calendar = Calendar.current
    private let hourRowHeight: CGFloat = JarvisTheme.Dimensions.hourRowHeight

    enum PlannerTab: String, CaseIterable { case timeline = "Таймлайн", inbox = "Inbox" }
    enum TimelineViewMode: String, CaseIterable { case day = "День", week = "Неделя", month = "Месяц" }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    // Date Strip
                    StructuredDateStrip(
                        selectedDay: selectedDay,
                        onSelectDay: { selectedDay = $0 },
                        taskCountForDay: { store.tasksForDay($0).count }
                    )
                    
                    // Tab Picker
                    HStack {
                        StructuredSegmentedControl(
                            items: PlannerTab.allCases,
                            selection: $activeTab,
                            title: { $0.rawValue }
                        )
                        
                        Spacer()
                        
                        if activeTab == .timeline {
                            Menu {
                                ForEach(TimelineViewMode.allCases, id: \.self) { mode in
                                    Button(mode.rawValue) { timelineViewMode = mode }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(timelineViewMode.rawValue)
                                        .font(.subheadline.weight(.medium))
                                    Image(systemName: "chevron.down")
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundStyle(JarvisTheme.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    // Content
                    contentView
                }
                .background(JarvisTheme.background.ignoresSafeArea())
                
                // Floating Add Button
                FloatingAddButton { showAddSheet = true }
                    .padding(.trailing, 20)
                    .padding(.bottom, 24)
            }
            .navigationTitle("")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .sheet(isPresented: $showAddSheet) { addTaskSheet }
            .sheet(item: $editingTask) { editTaskSheet(for: $0) }
            .confirmationDialog("Удалить задачу?", isPresented: deleteBinding, titleVisibility: .visible) {
                deleteDialogButtons
            } message: {
                if let t = taskToDelete { Text("«\(t.title)» будет удалена.") }
            }
            .onAppear { NotificationManager.shared.requestAuthorization() }
            #if os(iOS)
            .onReceive(speech.$transcript) { handleSpeech($0) }
            #endif
        }
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        if activeTab == .timeline {
            switch timelineViewMode {
            case .day: dayTimelineView
            case .week: weekView
            case .month: monthView
            }
        } else {
            inboxView
        }
    }
    
    private var deleteBinding: Binding<Bool> {
        Binding(get: { taskToDelete != nil }, set: { if !$0 { taskToDelete = nil } })
    }
    
    @ViewBuilder
    private var deleteDialogButtons: some View {
        Button("Удалить", role: .destructive) {
            if let t = taskToDelete { deleteTask(t); taskToDelete = nil }
        }
        Button("Отмена", role: .cancel) { taskToDelete = nil }
    }

    // MARK: - Day Timeline (Structured-style)
    
    private var dayTimelineView: some View {
        let bounds = store.dayBounds
        let dayStart = bounds.riseDate(on: selectedDay)
        let startHour = bounds.riseHour
        let endHour = bounds.windDownHour + 1
        let timelineTasks = store.timelineTasks(for: selectedDay)
        let allDayTasks = store.allDayTasks(for: selectedDay)
        let currentHour = calendar.component(.hour, from: Date())
        let currentMinute = calendar.component(.minute, from: Date())

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // All Day Section
                if !allDayTasks.isEmpty {
                    allDaySection(allDayTasks)
                }
                
                // Timeline
                ZStack(alignment: .topLeading) {
                    // Hour Grid
                    TimelineHourGrid(
                        startHour: startHour,
                        endHour: endHour,
                        hourRowHeight: hourRowHeight,
                        currentHour: currentHour,
                        currentMinute: currentMinute
                    )
                    
                    // Task Blocks
                    VStack(spacing: 0) {
                        ForEach(timelineTasks) { task in
                            TaskBlockView(
                                task: task,
                                color: task.taskColor,
                                dayStart: dayStart,
                                hourRowHeight: hourRowHeight,
                                onTap: { editingTask = task },
                                onToggle: { store.toggleCompletion(task: task, onDay: selectedDay) }
                            )
                            .padding(.leading, 56)
                            .padding(.trailing, 16)
                            .draggable(task.id.uuidString)
                        }
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .scrollIndicators(.hidden)
    }
    
    private func allDaySection(_ tasks: [PlannerTask]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.orange)
                Text("Весь день")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(JarvisTheme.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            VStack(spacing: 8) {
                ForEach(tasks) { task in
                    AllDayTaskRow(
                        task: task,
                        color: task.taskColor,
                        onEdit: { editingTask = task },
                        onToggle: { store.toggleCompletion(task: task, onDay: selectedDay) }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Week View
    
    private var weekView: some View {
        let bounds = store.dayBounds
        let startHour = bounds.riseHour
        let endHour = min(bounds.windDownHour + 1, 24)

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                weekHeader
                
                ForEach(startHour..<endHour, id: \.self) { hour in
                    weekHourRow(hour: hour)
                }
            }
            .padding()
        }
    }
    
    private var weekHeader: some View {
        HStack(spacing: 0) {
            Text("")
                .frame(width: 44)
            
            ForEach(weekDates, id: \.self) { day in
                VStack(spacing: 2) {
                    Text(weekdayShort(day))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(JarvisTheme.textTertiary)
                    
                    Text("\(calendar.component(.day, from: day))")
                        .font(.subheadline.weight(calendar.isDateInToday(day) ? .bold : .medium))
                        .foregroundStyle(calendar.isDateInToday(day) ? JarvisTheme.accent : JarvisTheme.textPrimary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 8)
    }
    
    private func weekHourRow(hour: Int) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(String(format: "%02d", hour % 24))
                .font(.caption.monospacedDigit())
                .foregroundStyle(JarvisTheme.textTertiary)
                .frame(width: 44, alignment: .trailing)
            
            ForEach(weekDates, id: \.self) { day in
                let tasksInSlot = store.timelineTasks(for: day).filter {
                    calendar.component(.hour, from: $0.date) == (hour % 24)
                }
                
                VStack(spacing: 2) {
                    ForEach(tasksInSlot.prefix(2)) { task in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(task.taskColor.opacity(0.3))
                            .frame(height: 20)
                            .overlay(
                                Text(task.title)
                                    .font(.system(size: 9))
                                    .lineLimit(1)
                                    .padding(.horizontal, 4)
                            )
                    }
                    
                    if tasksInSlot.count > 2 {
                        Text("+\(tasksInSlot.count - 2)")
                            .font(.system(size: 8))
                            .foregroundStyle(JarvisTheme.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 28)
                .onTapGesture {
                    selectedDay = day
                    timelineViewMode = .day
                }
            }
        }
    }
    
    private var weekDates: [Date] {
        let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDay))!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
    
    private func weekdayShort(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: day).prefix(2)).uppercased()
    }

    // MARK: - Month View
    
    private var monthView: some View {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDay))!
        let range = calendar.range(of: .day, in: .month, for: monthStart)!
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let pad = (firstWeekday + 5) % 7
        let rows = (pad + range.count + 6) / 7

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Weekday headers
                HStack(spacing: 0) {
                    ForEach(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"], id: \.self) { day in
                        Text(day)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JarvisTheme.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Days grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(0..<(rows * 7), id: \.self) { i in
                        monthCell(index: i, pad: pad, daysInMonth: range.count, monthStart: monthStart)
                    }
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func monthCell(index: Int, pad: Int, daysInMonth: Int, monthStart: Date) -> some View {
        if index < pad {
            Color.clear.frame(height: 48)
        } else {
            let d = index - pad + 1
            if d <= daysInMonth, let day = calendar.date(byAdding: .day, value: d - 1, to: monthStart) {
                let taskCount = store.tasksForDay(day).count
                let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
                let isToday = calendar.isDateInToday(day)
                
                Button {
                    selectedDay = day
                    timelineViewMode = .day
                } label: {
                    VStack(spacing: 4) {
                        Text("\(d)")
                            .font(.subheadline.weight(isToday ? .bold : .medium))
                            .foregroundStyle(isSelected ? .white : (isToday ? JarvisTheme.accent : JarvisTheme.textPrimary))
                        
                        if taskCount > 0 {
                            HStack(spacing: 2) {
                                ForEach(0..<min(taskCount, 3), id: \.self) { _ in
                                    Circle()
                                        .fill(isSelected ? .white.opacity(0.8) : JarvisTheme.accent)
                                        .frame(width: 4, height: 4)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isSelected ? JarvisTheme.accent : .clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isToday && !isSelected ? JarvisTheme.accent : .clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(height: 48)
            }
        }
    }

    // MARK: - Inbox View
    
    private var inboxView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if store.inboxTasks.isEmpty {
                    emptyInboxView
                } else {
                    ForEach(store.inboxTasks) { task in
                        InboxTaskRow(
                            task: task,
                            color: task.taskColor,
                            onToggle: { var t = task; t.isCompleted.toggle(); store.update(t) },
                            onSchedule: { scheduleFromInbox(task) },
                            onEdit: { editingTask = task },
                            onDelete: { taskToDelete = task }
                        )
                        .draggable(task.id.uuidString)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }
    
    private var emptyInboxView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(JarvisTheme.textTertiary)
            
            Text("Inbox пуст")
                .font(.headline)
                .foregroundStyle(JarvisTheme.textSecondary)
            
            Text("Добавляйте задачи без времени —\nпотом перетащите на таймлайн")
                .font(.subheadline)
                .foregroundStyle(JarvisTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Actions
    
    private func scheduleFromInbox(_ task: PlannerTask) {
        activeTab = .timeline
        selectedDay = calendar.startOfDay(for: Date())
        store.scheduleFromInbox(task, date: selectedDay.addingTimeInterval(3600 * 9), durationMinutes: 60, isAllDay: false)
        if let updated = store.tasks.first(where: { $0.id == task.id }) {
            NotificationManager.shared.scheduleAlarm(for: updated)
        }
    }
    
    private func deleteTask(_ task: PlannerTask) {
        NotificationManager.shared.cancelAlarm(for: task)
        CalendarSyncService.shared.removeEvent(for: task)
        store.remove(task: task)
    }
    
    #if os(iOS)
    private func handleSpeech(_ text: String) {
        guard !text.isEmpty, let parsed = aiManager.extractTask(from: text, referenceDate: selectedDay) else { return }
        var t = parsed
        t.durationMinutes = 60
        store.add(t)
        NotificationManager.shared.scheduleAlarm(for: t)
    }
    #endif
    
    // MARK: - Sheets
    
    private var addTaskSheet: some View {
        StructuredAddTaskSheet(store: store, referenceDate: selectedDay) { task in
            if task.isInbox {
                store.addToInbox(task)
            } else {
                store.add(task)
                NotificationManager.shared.scheduleAlarm(for: task)
            }
        }
    }
    
    private func editTaskSheet(for task: PlannerTask) -> some View {
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
            onDelete: { deleteTask($0) }
        )
    }
}

// MARK: - Structured Add Task Sheet

struct StructuredAddTaskSheet: View {
    @ObservedObject var store: PlannerStore
    let referenceDate: Date
    let onAdd: (PlannerTask) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var notes = ""
    @State private var date: Date
    @State private var durationMinutes = 60
    @State private var isAllDay = false
    @State private var addToInbox = false
    @State private var hasAlarm = true
    @State private var recurrenceRule: RecurrenceRule?
    @State private var colorIndex = 4
    
    init(store: PlannerStore, referenceDate: Date, onAdd: @escaping (PlannerTask) -> Void) {
        self.store = store
        self.referenceDate = referenceDate
        self.onAdd = onAdd
        _date = State(initialValue: referenceDate.addingTimeInterval(3600))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Что нужно сделать?", text: $title)
                            .font(.title3.weight(.medium))
                            .padding()
                            .background(JarvisTheme.cardBackground)
                            .cornerRadius(JarvisTheme.Dimensions.cornerRadius)
                        
                        TextField("Заметки", text: $notes)
                            .font(.subheadline)
                            .padding()
                            .background(JarvisTheme.cardBackground)
                            .cornerRadius(JarvisTheme.Dimensions.cornerRadius)
                    }
                    
                    // Color Picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Цвет")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(JarvisTheme.textSecondary)
                        
                        HStack(spacing: 12) {
                            ForEach(0..<JarvisTheme.taskColors.count, id: \.self) { index in
                                Circle()
                                    .fill(JarvisTheme.taskColors[index])
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(.white, lineWidth: colorIndex == index ? 3 : 0)
                                    )
                                    .shadow(color: colorIndex == index ? JarvisTheme.taskColors[index].opacity(0.5) : .clear, radius: 4)
                                    .onTapGesture { colorIndex = index }
                            }
                        }
                    }
                    .padding()
                    .background(JarvisTheme.cardBackground)
                    .cornerRadius(JarvisTheme.Dimensions.cornerRadius)
                    
                    // Time Settings
                    VStack(spacing: 0) {
                        Toggle("В Inbox", isOn: $addToInbox)
                            .padding()
                        
                        Divider().padding(.leading)
                        
                        if !addToInbox {
                            Toggle("Весь день", isOn: $isAllDay)
                                .padding()
                            
                            Divider().padding(.leading)
                            
                            if !isAllDay {
                                DatePicker("Время", selection: $date, displayedComponents: [.date, .hourAndMinute])
                                    .padding()
                                
                                Divider().padding(.leading)
                                
                                HStack {
                                    Text("Длительность")
                                    Spacer()
                                    Stepper("\(durationMinutes) мин", value: $durationMinutes, in: 15...480, step: 15)
                                }
                                .padding()
                            } else {
                                DatePicker("День", selection: $date, displayedComponents: .date)
                                    .padding()
                            }
                            
                            Divider().padding(.leading)
                            
                            Picker("Повтор", selection: $recurrenceRule) {
                                Text("Без повтора").tag(RecurrenceRule?.none)
                                ForEach(RecurrenceRule.allCases, id: \.self) {
                                    Text($0.displayName).tag(RecurrenceRule?.some($0))
                                }
                            }
                            .padding()
                        }
                        
                        Divider().padding(.leading)
                        
                        Toggle("Напоминание", isOn: $hasAlarm)
                            .padding()
                    }
                    .background(JarvisTheme.cardBackground)
                    .cornerRadius(JarvisTheme.Dimensions.cornerRadius)
                }
                .padding()
            }
            .background(JarvisTheme.background.ignoresSafeArea())
            .navigationTitle("Новая задача")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") { submit() }
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func submit() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let cal = Calendar.current
        let task = PlannerTask(
            title: trimmed,
            notes: notes,
            date: addToInbox ? referenceDate : (isAllDay ? cal.startOfDay(for: date) : date),
            durationMinutes: addToInbox ? 60 : durationMinutes,
            isAllDay: addToInbox ? false : isAllDay,
            recurrenceRule: addToInbox ? nil : recurrenceRule,
            hasAlarm: hasAlarm,
            isInbox: addToInbox,
            colorIndex: colorIndex
        )
        onAdd(task)
        dismiss()
    }
}

// MARK: - Structured Edit Task Sheet

struct StructuredEditTaskSheet: View {
    let task: PlannerTask
    @ObservedObject var store: PlannerStore
    let onSave: (PlannerTask) -> Void
    let onDelete: (PlannerTask) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var notes: String
    @State private var date: Date
    @State private var durationMinutes: Int
    @State private var isAllDay: Bool
    @State private var isInbox: Bool
    @State private var hasAlarm: Bool
    @State private var recurrenceRule: RecurrenceRule?
    @State private var colorIndex: Int
    @State private var showDeleteConfirm = false

    init(task: PlannerTask, store: PlannerStore, onSave: @escaping (PlannerTask) -> Void, onDelete: @escaping (PlannerTask) -> Void) {
        self.task = task
        self.store = store
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: task.title)
        _notes = State(initialValue: task.notes)
        _date = State(initialValue: task.date)
        _durationMinutes = State(initialValue: task.durationMinutes)
        _isAllDay = State(initialValue: task.isAllDay)
        _isInbox = State(initialValue: task.isInbox)
        _hasAlarm = State(initialValue: task.hasAlarm)
        _recurrenceRule = State(initialValue: task.recurrenceRule)
        _colorIndex = State(initialValue: task.colorIndex)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Название", text: $title)
                            .font(.title3.weight(.medium))
                            .padding()
                            .background(JarvisTheme.cardBackground)
                            .cornerRadius(JarvisTheme.Dimensions.cornerRadius)
                        
                        TextField("Заметки", text: $notes)
                            .font(.subheadline)
                            .padding()
                            .background(JarvisTheme.cardBackground)
                            .cornerRadius(JarvisTheme.Dimensions.cornerRadius)
                    }
                    
                    // Color Picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Цвет")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(JarvisTheme.textSecondary)
                        
                        HStack(spacing: 12) {
                            ForEach(0..<JarvisTheme.taskColors.count, id: \.self) { index in
                                Circle()
                                    .fill(JarvisTheme.taskColors[index])
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(.white, lineWidth: colorIndex == index ? 3 : 0)
                                    )
                                    .shadow(color: colorIndex == index ? JarvisTheme.taskColors[index].opacity(0.5) : .clear, radius: 4)
                                    .onTapGesture { colorIndex = index }
                            }
                        }
                    }
                    .padding()
                    .background(JarvisTheme.cardBackground)
                    .cornerRadius(JarvisTheme.Dimensions.cornerRadius)
                    
                    // Time Settings
                    VStack(spacing: 0) {
                        Toggle("В Inbox", isOn: $isInbox)
                            .padding()
                        
                        Divider().padding(.leading)
                        
                        if !isInbox {
                            Toggle("Весь день", isOn: $isAllDay)
                                .padding()
                            
                            Divider().padding(.leading)
                            
                            if !isAllDay {
                                DatePicker("Время", selection: $date, displayedComponents: [.date, .hourAndMinute])
                                    .padding()
                                
                                Divider().padding(.leading)
                                
                                HStack {
                                    Text("Длительность")
                                    Spacer()
                                    Stepper("\(durationMinutes) мин", value: $durationMinutes, in: 15...480, step: 15)
                                }
                                .padding()
                            } else {
                                DatePicker("День", selection: $date, displayedComponents: .date)
                                    .padding()
                            }
                            
                            Divider().padding(.leading)
                            
                            Picker("Повтор", selection: $recurrenceRule) {
                                Text("Без повтора").tag(RecurrenceRule?.none)
                                ForEach(RecurrenceRule.allCases, id: \.self) {
                                    Text($0.displayName).tag(RecurrenceRule?.some($0))
                                }
                            }
                            .padding()
                        }
                        
                        Divider().padding(.leading)
                        
                        Toggle("Напоминание", isOn: $hasAlarm)
                            .padding()
                    }
                    .background(JarvisTheme.cardBackground)
                    .cornerRadius(JarvisTheme.Dimensions.cornerRadius)
                    
                    // Delete Button
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Удалить задачу")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .background(JarvisTheme.cardBackground)
                    .cornerRadius(JarvisTheme.Dimensions.cornerRadius)
                }
                .padding()
            }
            .background(JarvisTheme.background.ignoresSafeArea())
            .navigationTitle("Редактировать")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .fontWeight(.semibold)
                }
            }
            .confirmationDialog("Удалить задачу?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) { onDelete(task); dismiss() }
                Button("Отмена", role: .cancel) { }
            }
        }
    }

    private func save() {
        var updated = task
        let cal = Calendar.current
        updated.title = title
        updated.notes = notes
        updated.date = isInbox ? date : (isAllDay ? cal.startOfDay(for: date) : date)
        updated.durationMinutes = durationMinutes
        updated.isAllDay = isAllDay
        updated.isInbox = isInbox
        updated.hasAlarm = hasAlarm
        updated.recurrenceRule = recurrenceRule
        updated.colorIndex = colorIndex
        onSave(updated)
        dismiss()
    }
}

// MARK: - Day Bounds Sheet

struct DayBoundsSheet: View {
    @ObservedObject var store: PlannerStore
    @Environment(\.dismiss) private var dismiss
    @State private var riseHour: Int
    @State private var riseMinute: Int
    @State private var windHour: Int
    @State private var windMinute: Int

    init(store: PlannerStore) {
        self.store = store
        _riseHour = State(initialValue: store.dayBounds.riseHour)
        _riseMinute = State(initialValue: store.dayBounds.riseMinute)
        _windHour = State(initialValue: store.dayBounds.windDownHour)
        _windMinute = State(initialValue: store.dayBounds.windDownMinute)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Начало дня (Rise & Shine)") {
                    HStack {
                        Picker("Час", selection: $riseHour) {
                            ForEach(0..<24, id: \.self) { Text("\($0)").tag($0) }
                        }
                        #if os(iOS)
                        .pickerStyle(.wheel)
                        #endif
                        .frame(maxWidth: .infinity)
                        Picker("Мин", selection: $riseMinute) {
                            ForEach([0, 15, 30, 45], id: \.self) { Text("\($0)").tag($0) }
                        }
                        #if os(iOS)
                        .pickerStyle(.wheel)
                        #endif
                        .frame(maxWidth: .infinity)
                    }
                }
                Section("Конец дня (Wind Down)") {
                    HStack {
                        Picker("Час", selection: $windHour) {
                            ForEach(0..<24, id: \.self) { Text("\($0)").tag($0) }
                        }
                        #if os(iOS)
                        .pickerStyle(.wheel)
                        #endif
                        .frame(maxWidth: .infinity)
                        Picker("Мин", selection: $windMinute) {
                            ForEach([0, 15, 30, 45], id: \.self) { Text("\($0)").tag($0) }
                        }
                        #if os(iOS)
                        .pickerStyle(.wheel)
                        #endif
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Рамки дня")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        store.updateDayBounds(DayBounds(riseHour: riseHour, riseMinute: riseMinute, windDownHour: windHour, windDownMinute: windMinute))
                        dismiss()
                    }
                }
            }
        }
    }
}

#endif
