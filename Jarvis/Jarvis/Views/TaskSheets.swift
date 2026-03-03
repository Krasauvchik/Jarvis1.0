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
            VStack(spacing: 0) {
                // Colored header (like Structured)
                ZStack(alignment: .topLeading) {
                    taskColor.opacity(0.35)
                    
                    VStack(spacing: 12) {
                        Spacer().frame(height: 60)
                        
                        HStack(alignment: .center, spacing: 14) {
                            // Icon circle
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.white.opacity(0.4))
                                    .frame(width: 56, height: 56)
                                Image(systemName: icon.isEmpty ? "star.fill" : icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(taskColor)
                            }
                            .onTapGesture { showIconPickerExpanded.toggle() }
                            
                            // Title field
                            TextField(L10n.taskName, text: $title)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .textFieldStyle(.plain)
                                .accessibilityLabel(L10n.taskName)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    }
                    
                    // Close button
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 16)
                        .padding(.trailing, 16)
                    }
                }
                .frame(minHeight: 140)
                .clipped()
                
                // Suggestions + Form
                ScrollView {
                    VStack(spacing: 16) {
                        // Quick suggestions if title is empty
                        if title.isEmpty {
                            taskSuggestionsSection
                        }
                        
                        // Compact form fields
                        VStack(spacing: 0) {
                            taskScheduleSection
                            taskCategorySection
                            taskTagsSection
                            taskColorSection
                            if showIconPickerExpanded {
                                taskIconSection
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(theme.cardBackground)
                        )
                        .padding(.horizontal, 16)
                        
                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            TextField(L10n.notesField, text: $notes, axis: .vertical)
                                .font(.system(size: 14))
                                .foregroundColor(theme.textPrimary)
                                .lineLimit(3...6)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(theme.cardBackground)
                        )
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 16)
                }
                .background(theme.background)
                
                // Bottom "Continue" button
                Button(action: addAndDismiss) {
                    Text(L10n.addAction)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(taskColor)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!TaskValidator.canSave(title: title))
                .opacity(TaskValidator.canSave(title: title) ? 1 : 0.5)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(theme.background)
            }
            .background(theme.background)
        }
        .presentationDetents([.large])
    }
    
    @State private var showIconPickerExpanded = false
    
    private var taskColor: Color {
        JarvisTheme.taskColors[colorIndex % JarvisTheme.taskColors.count]
    }
    
    private func addAndDismiss() {
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
    
    // MARK: - Task Suggestions (like Structured)
    
    private var taskSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.suggestions)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textSecondary)
                .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                ForEach(TaskSuggestion.defaults, id: \.title) { suggestion in
                    Button(action: {
                        title = suggestion.title
                        icon = suggestion.icon
                        duration = suggestion.durationMinutes
                        colorIndex = suggestion.colorIndex
                        if let hour = suggestion.suggestedHour {
                            taskDate = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: taskDate) ?? taskDate
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: suggestion.icon)
                                .font(.system(size: 18))
                                .foregroundColor(JarvisTheme.taskColors[suggestion.colorIndex % JarvisTheme.taskColors.count])
                                .frame(width: 32, height: 32)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.timeRange)
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.textTertiary)
                                Text(suggestion.title)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(theme.textPrimary)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    
                    if suggestion.title != TaskSuggestion.defaults.last?.title {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.cardBackground)
            )
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Shared Form Sections
    
    private var taskCategorySection: some View {
        Section(L10n.categorySection) {
            Picker(L10n.categorySection, selection: $selectedCategoryId) {
                Text(L10n.noCategory).tag(nil as UUID?)
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
        Section(L10n.tagsSection) {
            if store.tags.isEmpty {
                Text(L10n.addTagsHint)
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
            Toggle(L10n.inboxToggle, isOn: $isInbox)
            
            if !isInbox {
                DatePicker(L10n.dateTimeField, selection: $taskDate)
                Toggle(L10n.allDayToggle, isOn: $isAllDay)
                
                if !isAllDay {
                    Picker(L10n.durationField, selection: $duration) {
                        Text(L10n.duration15min).tag(15)
                        Text(L10n.duration30min).tag(30)
                        Text(L10n.duration45min).tag(45)
                        Text(L10n.duration1h).tag(60)
                        Text(L10n.duration1h30).tag(90)
                        Text(L10n.duration2h).tag(120)
                    }
                }
            }
            
            Toggle(L10n.reminderToggle, isOn: $hasAlarm)
        }
    }
    
    private var taskColorSection: some View {
        Section(L10n.colorSection) {
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
        Section(L10n.iconSection) {
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
    @State private var isCompleted: Bool
    @State private var showDatePicker = false
    @State private var showTimePicker = false
    @State private var showColorPicker = false
    @State private var showIconPicker = false

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
        self._isCompleted = State(initialValue: task.isCompleted)
    }
    
    private var taskColor: Color {
        JarvisTheme.taskColors[colorIndex % JarvisTheme.taskColors.count]
    }
    
    private var durationText: String {
        if duration >= 60 && duration % 60 == 0 {
            return "\(duration / 60)h"
        } else if duration >= 60 {
            return "\(duration / 60)h \(duration % 60)m"
        }
        return "\(duration)m"
    }
    
    private var locationLabel: String {
        if isInbox { return "Inbox" }
        if isCompleted { return L10n.completed }
        return L10n.statusScheduled
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Colored Header ──
            ZStack(alignment: .topTrailing) {
                taskColor.opacity(0.35)
                
                // Top-right buttons
                HStack(spacing: 12) {
                    Menu {
                        Button(action: { showColorPicker.toggle() }) {
                            Label(L10n.colorSection, systemImage: "paintpalette")
                        }
                        Button(action: { showIconPicker.toggle() }) {
                            Label(L10n.iconSection, systemImage: "star.fill")
                        }
                        Divider()
                        Button(action: {
                            isInbox.toggle()
                        }) {
                            Label(isInbox ? L10n.fromInbox : L10n.toInbox, systemImage: "tray")
                        }
                        Button(action: {
                            hasAlarm.toggle()
                        }) {
                            Label(hasAlarm ? L10n.removeReminder : L10n.reminderToggle, systemImage: hasAlarm ? "bell.slash" : "bell")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 16)
                .padding(.trailing, 16)
                
                // Header content
                VStack(spacing: 12) {
                    Spacer().frame(height: 20)
                    
                    HStack(alignment: .center, spacing: 14) {
                        // Task icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(taskColor.opacity(0.3))
                                .frame(width: 52, height: 52)
                            Image(systemName: icon.isEmpty ? "star.fill" : icon)
                                .font(.system(size: 22))
                                .foregroundColor(taskColor)
                        }
                        .onTapGesture { showIconPicker.toggle() }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            // Meta badges
                            HStack(spacing: 6) {
                                Text(durationText)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                Text("•")
                                    .foregroundColor(.white.opacity(0.5))
                                Text(locationLabel)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                if hasAlarm {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            
                            // Title field
                            TextField(L10n.taskName, text: $title)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .textFieldStyle(.plain)
                        }
                        
                        Spacer()
                        
                        // Completion circle
                        ZStack {
                            Circle()
                                .strokeBorder(.white.opacity(0.7), lineWidth: 2.5)
                                .frame(width: 30, height: 30)
                            if isCompleted {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                isCompleted.toggle()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .frame(minHeight: 130)
            .clipped()
            
            // ── Body ──
            ScrollView {
                VStack(spacing: 16) {
                    // Duration
                    HStack(spacing: 12) {
                        Image(systemName: "timer")
                            .font(.system(size: 16))
                            .foregroundColor(taskColor)
                        
                        Picker("", selection: $duration) {
                            Text("15m").tag(15)
                            Text("30m").tag(30)
                            Text("1h").tag(60)
                            Text("1.5h").tag(90)
                            Text("2h").tag(120)
                            Text("3h").tag(180)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.cardBackground)
                    )
                    .padding(.horizontal, 16)
                    
                    // Date / Time buttons
                    if !isInbox {
                        HStack(spacing: 12) {
                            Button(action: { showDatePicker.toggle() }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 14))
                                    Text(L10n.date)
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(theme.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(theme.cardBackground)
                                )
                            }
                            .buttonStyle(.plain)
                            
                            if !isAllDay {
                                Button(action: { showTimePicker.toggle() }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "clock")
                                            .font(.system(size: 14))
                                        Text(L10n.time)
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(theme.textPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(theme.cardBackground)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Toggle("", isOn: $isAllDay)
                                .labelsHidden()
                                .tint(taskColor)
                            
                            Text(L10n.allDay)
                                .font(.system(size: 13))
                                .foregroundColor(theme.textSecondary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        
                        // Inline Date Picker
                        if showDatePicker {
                            DatePicker("", selection: $taskDate, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .tint(taskColor)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(theme.cardBackground)
                                )
                                .padding(.horizontal, 16)
                        }
                        
                        // Inline Time Picker
                        if showTimePicker && !isAllDay {
                            DatePicker("", selection: $taskDate, displayedComponents: .hourAndMinute)
                                .tint(taskColor)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(theme.cardBackground)
                                )
                                .padding(.horizontal, 16)
                        }
                    }
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        TextField(L10n.notesPlaceholder, text: $notes, axis: .vertical)
                            .font(.system(size: 14))
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(4...8)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.cardBackground)
                    )
                    .padding(.horizontal, 16)
                    
                    // Color picker (expandable)
                    if showColorPicker {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.colorSection)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(theme.textSecondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(0..<JarvisTheme.taskColors.count, id: \.self) { i in
                                        Circle()
                                            .fill(JarvisTheme.taskColors[i])
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Circle().stroke(.white, lineWidth: colorIndex == i ? 3 : 0)
                                            )
                                            .onTapGesture { colorIndex = i }
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(theme.cardBackground)
                        )
                        .padding(.horizontal, 16)
                    }
                    
                    // Icon picker (expandable)
                    if showIconPicker {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.iconSection)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(theme.textSecondary)
                            LazyVGrid(columns: Array(repeating: GridItem(.adaptive(minimum: 36), spacing: 8), count: 6), spacing: 8) {
                                ForEach(TaskIcon.allCases, id: \.rawValue) { taskIcon in
                                    Image(systemName: taskIcon.systemName)
                                        .font(.system(size: 18))
                                        .foregroundColor(icon == taskIcon.rawValue ? taskColor : theme.textSecondary)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(icon == taskIcon.rawValue ? taskColor.opacity(0.2) : Color.clear)
                                        )
                                        .onTapGesture { icon = taskIcon.rawValue }
                                }
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(theme.cardBackground)
                        )
                        .padding(.horizontal, 16)
                    }
                    
                    // Priority
                    HStack(spacing: 12) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 14))
                            .foregroundColor(taskColor)
                        
                        Text(L10n.prioritySection)
                            .font(.system(size: 14))
                            .foregroundColor(theme.textPrimary)
                        
                        Spacer()
                        
                        Picker("", selection: $priority) {
                            ForEach(TaskPriority.allCases, id: \.self) { p in
                                Text(p.displayName).tag(p)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(taskColor)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.cardBackground)
                    )
                    .padding(.horizontal, 16)
                    
                    Spacer().frame(height: 16)
                }
                .padding(.top, 16)
            }
            
            // ── Bottom Bar ──
            HStack {
                Button(action: {
                    CalendarSyncService.shared.removeEvent(for: task)
                    NotificationManager.shared.cancelAlarm(for: task)
                    store.delete(task)
                    dismiss()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 18))
                        .foregroundColor(theme.textTertiary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(theme.cardBackground)
                        )
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: saveAndDismiss) {
                    Text(L10n.updateTask)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(taskColor)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!TaskValidator.canSave(title: title))
                .opacity(TaskValidator.canSave(title: title) ? 1 : 0.5)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(theme.background)
        }
        .background(theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .presentationDetents([.large])
    }
    
    private func saveAndDismiss() {
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
        updated.isCompleted = isCompleted
        store.update(updated)
        if hasAlarm {
            NotificationManager.shared.scheduleAlarm(for: updated)
        } else {
            NotificationManager.shared.cancelAlarm(for: updated)
        }
        CalendarSyncService.shared.addOrUpdateEvent(for: updated)
        dismiss()
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
