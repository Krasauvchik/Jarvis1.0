import SwiftUI

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
    @State private var priority: TaskPriority = .medium

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
                        .accessibilityLabel("Название задачи")
                    if let error = TaskValidator.validateTitle(title), !title.isEmpty {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    TextField("Заметки", text: $notes, axis: .vertical)
                        .lineLimit(3)
                    if let error = TaskValidator.validateNotes(notes) {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .animateOnAppear(delay: 0)
                
                taskCategorySection
                taskTagsSection
                taskScheduleSection
                taskColorSection
                taskIconSection
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
                            tagIds: Array(selectedTagIds),
                            priority: priority
                        )
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                            store.add(task)
                        }
                        if hasAlarm {
                            NotificationManager.shared.scheduleAlarm(for: task)
                        }
                        CalendarSyncService.shared.addOrUpdateEvent(for: task)
                        dismiss()
                    }
                    .disabled(!TaskValidator.canSave(title: title))
                }
            }
        }
        .presentationDetents([.large])
    }
    
    // MARK: - Shared Form Sections
    
    private var taskCategorySection: some View {
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
    }
    
    private var taskTagsSection: some View {
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
    }
    
    private var taskScheduleSection: some View {
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
    }
    
    private var taskColorSection: some View {
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
    }
    
    private var taskIconSection: some View {
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
    @State private var priority: TaskPriority

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
        self._priority = State(initialValue: task.priority)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название задачи", text: $title)
                        .accessibilityLabel("Название задачи")
                    if let error = TaskValidator.validateTitle(title), !title.isEmpty {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    TextField("Заметки", text: $notes, axis: .vertical)
                        .lineLimit(3)
                    if let error = TaskValidator.validateNotes(notes) {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
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

                Section("Приоритет") {
                    Picker("Приоритет", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { p in
                            Label(p.displayName, systemImage: p.icon)
                                .tag(p)
                        }
                    }
                    .pickerStyle(.menu)
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
                        NotificationManager.shared.cancelAlarm(for: task)
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
                        updated.priority = priority
                        store.update(updated)
                        if hasAlarm {
                            NotificationManager.shared.scheduleAlarm(for: updated)
                        } else {
                            NotificationManager.shared.cancelAlarm(for: updated)
                        }
                        CalendarSyncService.shared.addOrUpdateEvent(for: updated)
                        dismiss()
                    }
                    .disabled(!TaskValidator.canSave(title: title))
                }
            }
        }
        .presentationDetents([.large])
    }
}

#if os(iOS)
// MARK: - Share Sheet

struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
