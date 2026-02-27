import SwiftUI

struct PlannerView: View {
    @ObservedObject var store: PlannerStore
    @ObservedObject var aiManager: AIManager
    @StateObject private var speech = SpeechRecognizer()
    
    @State private var title = ""
    @State private var notes = ""
    @State private var date = Date().addingTimeInterval(3600)
    @State private var editingTask: PlannerTask?
    @State private var isSyncing = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    suggestionsSection
                    formSection
                    taskListSection
                }
                .padding()
            }
            .background(JarvisTheme.background.ignoresSafeArea())
            .navigationTitle("AI Planner")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    syncButton
                }
            }
            .onAppear { NotificationManager.shared.requestAuthorization() }
            .sheet(item: $editingTask) { task in
                RescheduleSheet(task: task) { updated in
                    store.update(updated)
                    NotificationManager.shared.cancelAlarm(for: task)
                    if updated.hasAlarm { NotificationManager.shared.scheduleAlarm(for: updated) }
                }
            }
            .onReceive(speech.$transcript) { text in
                guard !text.isEmpty else { return }
                if let parsed = aiManager.extractTask(from: text, referenceDate: Date()) {
                    title = parsed.title
                    notes = parsed.notes
                    date = parsed.date
                } else {
                    title = text
                }
            }
        }
    }
    
    // MARK: - Suggestions
    
    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Популярные задачи")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(JarvisTheme.textSecondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion) { title = suggestion }
                            .buttonStyle(ChipButtonStyle())
                    }
                }
            }
        }
        .jarvisSectionCard()
    }
    
    private var suggestions: [String] {
        let defaults = ["Тренировка", "Прогулка", "Медитация", "Звонок", "Учёба", "Работа", "Чтение"]
        let frequent = Dictionary(grouping: store.tasks.map(\.title), by: { $0 })
            .sorted { $0.value.count > $1.value.count }
            .map(\.key)
            .filter { !defaults.contains($0) }
            .prefix(4)
        return defaults + frequent
    }
    
    // MARK: - Form
    
    private var formSection: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Новая задача", text: $title)
                    .textFieldStyle(.roundedBorder)
                
                Button {
                    speech.isRecording ? speech.stop() : speech.start()
                } label: {
                    Image(systemName: speech.isRecording ? "mic.fill" : "mic")
                        .font(.title2)
                        .foregroundColor(speech.isRecording ? .red : JarvisTheme.accent)
                }
                .buttonStyle(.plain)
            }
            
            TextField("Заметки", text: $notes)
                .textFieldStyle(.roundedBorder)
            
            DatePicker("Когда", selection: $date, displayedComponents: [.date, .hourAndMinute])
            
            HStack(spacing: 12) {
                Button { addTask() } label: {
                    Label("Добавить", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                
                Button { applyAI() } label: {
                    Label("AI", systemImage: "sparkles")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty && speech.transcript.isEmpty)
            }
        }
        .jarvisSectionCard()
    }
    
    // MARK: - Task List
    
    private var taskListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Задачи")
                .font(.headline.weight(.semibold))
                .foregroundColor(JarvisTheme.textPrimary)
            
            if store.tasks.isEmpty {
                Text("Пока нет задач")
                    .font(.subheadline)
                    .foregroundColor(JarvisTheme.textSecondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(store.tasks) { task in
                    TaskRow(task: task, onToggle: { toggleTask(task) }, onEdit: { editingTask = task })
                }
            }
        }
        .jarvisSectionCard()
    }
    
    // MARK: - Actions
    
    private func addTask() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let task = PlannerTask(title: trimmed, notes: notes, date: date)
        store.add(task)
        NotificationManager.shared.scheduleAlarm(for: task)
        
        title = ""
        notes = ""
        date = Date().addingTimeInterval(3600)
    }
    
    private func toggleTask(_ task: PlannerTask) {
        var updated = task
        updated.isCompleted.toggle()
        store.update(updated)
    }
    
    private func applyAI() {
        let source = speech.transcript.isEmpty ? title : speech.transcript
        guard !source.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        if let parsed = aiManager.extractTask(from: source, referenceDate: Date()) {
            title = parsed.title
            notes = parsed.notes
            date = parsed.date
        }
    }
    
    private var syncButton: some View {
        Button {
            Task { await syncCalendar() }
        } label: {
            if isSyncing {
                ProgressView()
            } else {
                Image(systemName: "calendar.badge.plus")
            }
        }
        .disabled(isSyncing)
    }
    
    private func syncCalendar() async {
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            let events = try await CalendarService.shared.fetchEvents()
            await MainActor.run {
                for event in events where !store.tasks.contains(where: { $0.title == event.title && abs($0.date.timeIntervalSince(event.date)) < 60 }) {
                    store.add(event)
                    NotificationManager.shared.scheduleAlarm(for: event)
                }
            }
        } catch {
            print("Calendar sync failed: \(error)")
        }
    }
}

// MARK: - Task Row

struct TaskRow: View {
    let task: PlannerTask
    let onToggle: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(task.isCompleted ? JarvisTheme.accent : JarvisTheme.textSecondary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body.weight(.medium))
                    .foregroundColor(task.isCompleted ? JarvisTheme.textSecondary : JarvisTheme.textPrimary)
                    .strikethrough(task.isCompleted)
                Text(task.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(JarvisTheme.textSecondary)
            }
            
            Spacer()
            
            if task.hasAlarm {
                Image(systemName: "alarm.fill")
                    .font(.caption)
                    .foregroundColor(JarvisTheme.accent)
            }
            
            Button(action: onEdit) {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(JarvisTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Reschedule Sheet

struct RescheduleSheet: View {
    let task: PlannerTask
    let onSave: (PlannerTask) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var newDate: Date
    
    init(task: PlannerTask, onSave: @escaping (PlannerTask) -> Void) {
        self.task = task
        self.onSave = onSave
        _newDate = State(initialValue: task.date)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(task.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                DatePicker("Новое время", selection: $newDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Отложить")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        var updated = task
                        updated.date = newDate
                        onSave(updated)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Button Styles

struct ChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(JarvisTheme.chipBackground)
            .foregroundColor(JarvisTheme.chipText)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundColor(.white)
            .background(JarvisTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.5)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundColor(JarvisTheme.chipText)
            .background(JarvisTheme.chipBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(JarvisTheme.accent.opacity(0.3)))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.5)
    }
}
