import SwiftUI
import EventKit

// MARK: - EventKit Calendar View
// Native system Calendar & Reminders integration view
// Inspired by Structured's deep calendar overlay & TaskMind's reminder sync

struct EventKitCalendarView: View {
    let theme: JarvisTheme
    var store: PlannerStore
    var eventKit = EventKitService.shared
    
    @State private var selectedDate = Date()
    @State private var showingCalendarPicker = false
    @State private var showingAddEvent = false
    @State private var showingReminders = false
    @State private var importedCount = 0
    @State private var showImportAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                
                if !eventKit.calendarAccessGranted {
                    calendarAccessCard
                } else {
                    datePickerSection
                    eventsSection
                    
                    if eventKit.remindersAccessGranted {
                        remindersSection
                    } else {
                        remindersAccessCard
                    }
                }
            }
            .padding()
        }
        .background(theme.background)
        .task {
            if eventKit.calendarAccessGranted {
                await eventKit.fetchEvents(for: selectedDate)
            }
            if eventKit.remindersAccessGranted {
                await eventKit.fetchReminders()
            }
        }
        .onChange(of: selectedDate) { _, newDate in
            Task { await eventKit.fetchEvents(for: newDate) }
        }
        .sheet(isPresented: $showingCalendarPicker) {
            CalendarPickerSheet(eventKit: eventKit, theme: theme)
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventSheet(eventKit: eventKit, theme: theme, date: selectedDate)
        }
        .alert(L10n.importComplete, isPresented: $showImportAlert) {
            Button("OK") { }
        } message: {
            Text(String(format: L10n.importedTasksCount, importedCount))
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.systemCalendarTitle)
                    .font(.title2.bold())
                    .foregroundColor(theme.textPrimary)
                Text(L10n.systemCalendarSubtitle)
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondary)
            }
            
            Spacer()
            
            if eventKit.calendarAccessGranted {
                HStack(spacing: 12) {
                    Button {
                        showingCalendarPicker = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title3)
                            .foregroundColor(JarvisTheme.accent)
                    }
                    
                    Button {
                        showingAddEvent = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(JarvisTheme.accent)
                    }
                }
            }
        }
    }
    
    // MARK: - Access Cards
    
    private var calendarAccessCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(JarvisTheme.accent)
            
            Text(L10n.calendarAccessRequired)
                .font(.headline)
                .foregroundColor(theme.textPrimary)
            
            Text(L10n.calendarAccessDescription)
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                Task {
                    let granted = await eventKit.requestCalendarAccess()
                    if granted {
                        await eventKit.fetchEvents(for: selectedDate)
                        eventKit.syncEventsToStore()
                    }
                }
            } label: {
                Label(L10n.grantAccess, systemImage: "lock.open.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(JarvisTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var remindersAccessCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 36))
                .foregroundColor(.orange)
            
            Text(L10n.remindersAccessRequired)
                .font(.headline)
                .foregroundColor(theme.textPrimary)
            
            Button {
                Task {
                    let granted = await eventKit.requestRemindersAccess()
                    if granted {
                        await eventKit.fetchReminders()
                    }
                }
            } label: {
                Label(L10n.grantAccess, systemImage: "lock.open.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.orange)
                    .clipShape(Capsule())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Date Picker
    
    private var datePickerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(JarvisTheme.accent)
                }
                
                Spacer()
                
                Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                
                Spacer()
                
                Button {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundColor(JarvisTheme.accent)
                }
            }
            
            if !Calendar.current.isDateInToday(selectedDate) {
                Button {
                    selectedDate = Date()
                } label: {
                    Text(L10n.today)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(JarvisTheme.accent)
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Events
    
    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.calendarEvents)
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                
                Spacer()
                
                if !eventKit.systemEvents.isEmpty {
                    Button {
                        let tasks = eventKit.importEventsAsTasks(for: selectedDate)
                        importedCount = tasks.count
                        for task in tasks {
                            store.add(task)
                        }
                        showImportAlert = true
                    } label: {
                        Label(L10n.importToJarvis, systemImage: "square.and.arrow.down")
                            .font(.caption.bold())
                            .foregroundColor(JarvisTheme.accent)
                    }
                }
            }
            
            if eventKit.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if eventKit.systemEvents.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.title)
                        .foregroundColor(theme.textSecondary.opacity(0.5))
                    Text(L10n.noEventsForDay)
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(eventKit.systemEvents) { event in
                    EventRow(event: event, theme: theme)
                }
            }
        }
        .padding()
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Reminders
    
    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.remindersTitle)
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                
                Spacer()
                
                Text("\(eventKit.systemReminders.filter { !$0.isCompleted }.count)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.orange)
                    .clipShape(Capsule())
            }
            
            if eventKit.systemReminders.isEmpty {
                Text(L10n.noReminders)
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(eventKit.systemReminders.prefix(10)) { reminder in
                    ReminderRow(reminder: reminder, theme: theme) {
                        let _ = eventKit.completeReminder(identifier: reminder.id)
                        Task { await eventKit.fetchReminders() }
                    }
                }
            }
        }
        .padding()
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Event Row

private struct EventRow: View {
    let event: SystemCalendarEvent
    let theme: JarvisTheme
    @ObservedObject var briefingService = MeetingBriefingService.shared
    @State private var showBriefing = false
    
    private var hasCachedBriefing: Bool {
        briefingService.cachedBriefing(for: event.title, date: event.startDate) != nil
    }
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(calendarColor)
                .frame(width: 4, height: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline.bold())
                    .foregroundColor(theme.textPrimary)
                
                HStack(spacing: 6) {
                    if event.isAllDay {
                        Text(L10n.allDay)
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                    } else {
                        Text("\(event.startDate.formatted(date: .omitted, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                    }
                    
                    if let location = event.location, !location.isEmpty {
                        Image(systemName: "mappin")
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)
                        Text(location)
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Briefing button
            Button {
                showBriefing = true
            } label: {
                if briefingService.isGenerating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: hasCachedBriefing ? "doc.text.fill" : "doc.text.magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(hasCachedBriefing ? JarvisTheme.accentGreen : JarvisTheme.accent)
                }
            }
            .buttonStyle(.plain)
            .help("Выдержка по встрече")
            
            Text(event.calendarName)
                .font(.caption2)
                .foregroundColor(calendarColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(calendarColor.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showBriefing) {
            MeetingBriefingSheet(event: event, theme: theme)
        }
    }
    
    private var calendarColor: Color {
        if let cgColor = event.calendarColor {
            return Color(cgColor: cgColor)
        }
        return JarvisTheme.accent
    }
}

// MARK: - Reminder Row

private struct ReminderRow: View {
    let reminder: SystemReminder
    let theme: JarvisTheme
    let onComplete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                onComplete()
            } label: {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(reminder.isCompleted ? .green : theme.textSecondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.subheadline)
                    .foregroundColor(theme.textPrimary)
                    .strikethrough(reminder.isCompleted)
                
                HStack(spacing: 6) {
                    if let due = reminder.dueDate {
                        Text(due.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(due < Date() ? .red : theme.textSecondary)
                    }
                    Text(reminder.listName)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Calendar Picker Sheet

private struct CalendarPickerSheet: View {
    var eventKit: EventKitService
    let theme: JarvisTheme
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(eventKit.availableCalendars, id: \.calendarIdentifier) { calendar in
                    Button {
                        eventKit.toggleCalendar(calendar.calendarIdentifier)
                    } label: {
                        HStack {
                            Circle()
                                .fill(Color(cgColor: calendar.cgColor))
                                .frame(width: 12, height: 12)
                            
                            Text(calendar.title)
                                .foregroundColor(theme.textPrimary)
                            
                            Spacer()
                            
                            if eventKit.selectedCalendarIDs.contains(calendar.calendarIdentifier) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(JarvisTheme.accent)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.selectCalendars)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) {
                        Task {
                            await eventKit.fetchEvents(for: Date())
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Add Event Sheet

private struct AddEventSheet: View {
    var eventKit: EventKitService
    let theme: JarvisTheme
    let date: Date
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var notes = ""
    
    init(eventKit: EventKitService, theme: JarvisTheme, date: Date) {
        self.eventKit = eventKit
        self.theme = theme
        self.date = date
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.isDateInToday(date) ? now : calendar.startOfDay(for: date).addingTimeInterval(9 * 3600)
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: start.addingTimeInterval(3600))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                TextField(L10n.title, text: $title)
                
                DatePicker(L10n.startDate, selection: $startDate)
                DatePicker(L10n.endDate, selection: $endDate)
                
                Section(L10n.notes) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(L10n.newEvent)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        let _ = eventKit.createEvent(
                            title: title,
                            startDate: startDate,
                            endDate: endDate,
                            notes: notes.isEmpty ? nil : notes
                        )
                        Task { await eventKit.fetchEvents(for: date) }
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - Meeting Briefing Sheet

private struct MeetingBriefingSheet: View {
    let event: SystemCalendarEvent
    let theme: JarvisTheme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var briefingService = MeetingBriefingService.shared
    @State private var briefing: MeetingBriefingService.MeetingBriefing?
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Event header
                    eventHeader
                    
                    Divider()
                    
                    if isLoading {
                        loadingView
                    } else if let briefing {
                        briefingContent(briefing)
                    } else {
                        generatePrompt
                    }
                }
                .padding()
            }
            .background(theme.background)
            .navigationTitle("📋 Выдержка")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.close) { dismiss() }
                }
                if briefing != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            briefing = nil
                            generateBriefing()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .task {
                // Auto-load cached or generate
                if let cached = briefingService.cachedBriefing(for: event.title, date: event.startDate) {
                    briefing = cached
                } else {
                    generateBriefing()
                }
            }
        }
    }
    
    private var eventHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(event.title)
                .font(.title3.bold())
                .foregroundColor(theme.textPrimary)
            
            HStack(spacing: 12) {
                if event.isAllDay {
                    Label("Весь день", systemImage: "sun.max")
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                } else {
                    Label(
                        "\(event.startDate.formatted(date: .abbreviated, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened))",
                        systemImage: "clock"
                    )
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondary)
                }
                
                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "mappin")
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }
            }
            
            if let notes = event.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)
                    .lineLimit(3)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Ищу информацию в почте и мессенджерах...")
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
            Text("Анализирую переписки и генерирую выдержку")
                .font(.caption)
                .foregroundColor(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var generatePrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(JarvisTheme.accent)
            
            Text("Подготовить выдержку по встрече?")
                .font(.headline)
                .foregroundColor(theme.textPrimary)
            
            Text("Jarvis проанализирует почту, мессенджеры и задачи, связанные с этой встречей")
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                generateBriefing()
            } label: {
                Label("Сгенерировать выдержку", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(JarvisTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    private func briefingContent(_ b: MeetingBriefingService.MeetingBriefing) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Stats bar
            HStack(spacing: 16) {
                statBadge(icon: "envelope", count: b.relatedEmails, label: "писем")
                statBadge(icon: "bubble.left.and.bubble.right", count: b.relatedMessages, label: "сообщений")
                statBadge(icon: "checklist", count: b.relatedTasks, label: "задач")
            }
            .padding()
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Key topics
            if !b.keyTopics.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Ключевые темы", systemImage: "key")
                        .font(.subheadline.bold())
                        .foregroundColor(theme.textPrimary)
                    ForEach(b.keyTopics, id: \.self) { topic in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .foregroundColor(JarvisTheme.accent)
                            Text(topic)
                                .font(.subheadline)
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                }
                .padding()
                .background(theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Main summary
            VStack(alignment: .leading, spacing: 8) {
                Label("Выдержка", systemImage: "doc.text")
                    .font(.subheadline.bold())
                    .foregroundColor(theme.textPrimary)
                Text(b.structuredSummary)
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondary)
            }
            .padding()
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Action items
            if !b.actionItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Нужно подготовить", systemImage: "bolt")
                        .font(.subheadline.bold())
                        .foregroundColor(JarvisTheme.accentOrange)
                    ForEach(b.actionItems, id: \.self) { item in
                        HStack(alignment: .top, spacing: 6) {
                            Text("⚡")
                            Text(item)
                                .font(.subheadline)
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                }
                .padding()
                .background(theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Generated at
            Text("Сгенерировано: \(b.generatedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2)
                .foregroundColor(theme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
    
    private func statBadge(icon: String, count: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(count > 0 ? JarvisTheme.accent : theme.textTertiary)
            Text("\(count)")
                .font(.headline)
                .foregroundColor(count > 0 ? theme.textPrimary : theme.textTertiary)
            Text(label)
                .font(.caption2)
                .foregroundColor(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func generateBriefing() {
        isLoading = true
        Task {
            let tasks = PlannerStore.shared.tasks
            let result = await briefingService.generateBriefing(for: event, allTasks: tasks)
            isLoading = false
            briefing = result
        }
    }
}
