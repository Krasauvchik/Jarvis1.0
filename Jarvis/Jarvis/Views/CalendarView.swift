#if !os(watchOS)
import SwiftUI
import EventKit

struct CalendarView: View {
    @State private var events: [CalendarEventItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isAuthorized = false
    @State private var checkingAuth = true
    @State private var showCreateEvent = false
    @StateObject private var calSync = CalendarSyncService.shared
    
    private var groupedEvents: [(key: String, date: Date, events: [CalendarEventItem])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: events) { event in
            cal.startOfDay(for: event.startDate)
        }
        return grouped.sorted { $0.key < $1.key }.map { (date, items) in
            let label = daySectionLabel(for: date)
            return (key: label, date: date, events: items.sorted { $0.startDate < $1.startDate })
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                JarvisTheme.background.ignoresSafeArea()
                contentView
            }
            .navigationTitle(L10n.calendarTitle)
            .toolbar { toolbarContent }
            .task { await checkAuth() }
            .refreshable {
                await checkAuth()
                await loadEvents()
            }
            .sheet(isPresented: $showCreateEvent) {
                CreateEventSheet { await loadEvents() }
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if checkingAuth {
            ProgressView(L10n.checking)
        } else if !isAuthorized && !calSync.isAuthorizedForCalendar {
            authPromptView
        } else if let err = errorMessage, events.isEmpty {
            errorView(err)
        } else if events.isEmpty {
            emptyView
        } else {
            eventsList
        }
    }
    
    private var eventsList: some View {
        List {
            ForEach(groupedEvents, id: \.key) { section in
                Section {
                    ForEach(section.events) { event in
                        CalendarEventRow(event: event)
                            .listRowBackground(JarvisTheme.cardBackground)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if event.source == .google {
                                    Button(role: .destructive) {
                                        Task { await deleteGoogleEvent(event) }
                                    } label: {
                                        Label(L10n.delete, systemImage: "trash")
                                    }
                                }
                            }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Text(section.key)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Calendar.current.isDateInToday(section.date) ? JarvisTheme.accent : JarvisTheme.textPrimary)
                        if Calendar.current.isDateInToday(section.date) {
                            Circle()
                                .fill(JarvisTheme.accent)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private func daySectionLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return L10n.dateToday + " — " + date.formatted(.dateTime.day().month(.wide))
        } else if cal.isDateInTomorrow(date) {
            return L10n.dateTomorrow + " — " + date.formatted(.dateTime.day().month(.wide))
        } else {
            return date.formatted(.dateTime.weekday(.wide).day().month(.wide)).localizedCapitalized
        }
    }
    
    private func errorView(_ err: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text(err)
                .multilineTextAlignment(.center)
                .foregroundStyle(JarvisTheme.textSecondary)
                .padding()
            Button(L10n.retry) { Task { await loadEvents() } }
                .buttonStyle(PrimaryButtonStyle())
                .bounceOnTap()
        }
        .padding()
        .animateOnAppear(delay: 0.1)
    }
    
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(JarvisTheme.textSecondary)
            Text(L10n.noEvents)
                .font(.headline)
                .foregroundStyle(JarvisTheme.textSecondary)
        }
        .animateOnAppear(delay: 0.1)
    }
    
    private var authPromptView: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(JarvisTheme.accent)
            Text(L10n.connectGoogle)
                .font(.title2.weight(.semibold))
                .foregroundStyle(JarvisTheme.textPrimary)
            Text(L10n.connectGoogleCalDesc)
                .multilineTextAlignment(.center)
                .foregroundStyle(JarvisTheme.textSecondary)
                .padding(.horizontal)
            Button {
                AuthService.shared.openAuthInBrowser()
            } label: {
                Label(L10n.signInGoogle, systemImage: "link")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(PrimaryButtonStyle())
            .bounceOnTap()
            .padding(.horizontal, 32)
        }
        .animateOnAppear(delay: 0)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            if isAuthorized || calSync.isAuthorizedForCalendar {
                HStack(spacing: 12) {
                    if isAuthorized {
                        Button { showCreateEvent = true } label: {
                            Image(systemName: "plus")
                        }
                        .bounceOnTap()
                    }
                    
                    Button { Task { await loadEvents() } } label: {
                        if isLoading { ProgressView() }
                        else { Image(systemName: "arrow.clockwise") }
                    }
                    .bounceOnTap()
                    .disabled(isLoading)
                }
            }
        }
    }
    
    private func checkAuth() async {
        checkingAuth = true
        defer { checkingAuth = false }
        
        do {
            isAuthorized = try await AuthService.shared.checkAuth()
        } catch {
            isAuthorized = false
        }
        
        if !calSync.isAuthorizedForCalendar {
            let granted = await calSync.requestAccess()
            if granted {
                EventKitService.shared.checkAuthorization()
                EventKitService.shared.loadCalendars()
                EventKitService.shared.syncEventsToStore()
            }
        }
        
        await loadEvents()
    }
    
    private func loadEvents() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        var merged: [CalendarEventItem] = []
        
        // Google Calendar events
        if isAuthorized {
            do {
                let dtos = try await CalendarService.shared.fetchEventsAsDTO(daysAhead: 30)
                merged += dtos.map { dto in
                    CalendarEventItem(
                        id: dto.id,
                        title: dto.title,
                        notes: dto.notes,
                        startDate: dto.startDate,
                        endDate: dto.endDate,
                        location: dto.location,
                        isAllDay: dto.isAllDay ?? false,
                        source: .google
                    )
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        
        // Local EventKit events
        if calSync.isAuthorizedForCalendar {
            let local = calSync.localEvents(daysAhead: 30)
            merged += local.map { ek in
                CalendarEventItem(
                    id: "ek_\(ek.eventIdentifier ?? UUID().uuidString)",
                    title: ek.title ?? L10n.noSubject,
                    notes: ek.notes,
                    startDate: ek.startDate,
                    endDate: ek.endDate,
                    location: ek.location,
                    isAllDay: ek.isAllDay,
                    source: .local
                )
            }
        }
        
        events = merged.sorted { $0.startDate < $1.startDate }
    }
    
    private func deleteGoogleEvent(_ event: CalendarEventItem) async {
        do {
            try await CalendarService.shared.deleteEvent(id: event.id)
            events.removeAll { $0.id == event.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Model

struct CalendarEventItem: Identifiable {
    enum Source { case google, local }
    let id: String
    let title: String
    let notes: String?
    let startDate: Date
    let endDate: Date?
    let location: String?
    let isAllDay: Bool
    var source: Source = .google
}

// MARK: - Event Row

struct CalendarEventRow: View {
    let event: CalendarEventItem
    
    private var sourceColor: Color {
        event.source == .google ? .blue : .orange
    }
    
    private var timeLabel: String {
        if event.isAllDay {
            return L10n.allDay
        }
        let start = event.startDate.formatted(date: .omitted, time: .shortened)
        if let end = event.endDate {
            let endStr = end.formatted(date: .omitted, time: .shortened)
            return "\(start) — \(endStr)"
        }
        return start
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time column
            VStack(alignment: .trailing, spacing: 2) {
                if event.isAllDay {
                    Text(L10n.allDay)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(sourceColor)
                } else {
                    Text(event.startDate.formatted(date: .omitted, time: .shortened))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(JarvisTheme.textPrimary)
                    if let end = event.endDate {
                        Text(end.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(JarvisTheme.textSecondary)
                    }
                }
            }
            .frame(width: 56, alignment: .trailing)
            
            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(sourceColor)
                .frame(width: 4)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(JarvisTheme.textPrimary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    // Source badge
                    Text(event.source == .google ? "Google" : L10n.calendarTitle)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(sourceColor.opacity(0.12))
                        .clipShape(Capsule())
                        .foregroundStyle(sourceColor)
                    
                    if event.isAllDay {
                        Text(L10n.allDay)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.12))
                            .clipShape(Capsule())
                            .foregroundStyle(.purple)
                    }
                }
                
                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(JarvisTheme.textSecondary)
                        .lineLimit(1)
                }
                
                if let notes = event.notes, !notes.isEmpty {
                    Text(String(notes.prefix(100))
                        .replacingOccurrences(of: "<br>", with: " ")
                        .replacingOccurrences(of: "<br/>", with: " "))
                        .font(.caption)
                        .foregroundStyle(JarvisTheme.textSecondary)
                        .lineLimit(2)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Create Event Sheet

struct CreateEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600)
    @State private var isSaving = false
    @State private var errorMessage: String?
    let onCreated: () async -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.eventTitle, text: $title)
                    TextField(L10n.eventDescription, text: $description)
                }
                
                Section {
                    DatePicker(L10n.eventStart, selection: $startDate)
                    DatePicker(L10n.eventEnd, selection: $endDate)
                }
                
                if let err = errorMessage {
                    Section {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(L10n.newEvent)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(L10n.createEvent) { Task { await save() } }
                            .disabled(title.isEmpty)
                    }
                }
            }
        }
    }
    
    private func save() async {
        isSaving = true
        errorMessage = nil
        do {
            _ = try await CalendarService.shared.createEvent(
                summary: title,
                start: startDate,
                end: endDate,
                description: description,
                timeZone: TimeZone.current.identifier
            )
            await onCreated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
#endif
