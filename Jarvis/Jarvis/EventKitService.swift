import Foundation
import EventKit
import Combine

// MARK: - EventKit Service (native Calendar + Reminders integration)
// Inspired by Structured & TaskMind: both use NSCalendars + NSReminders entitlements
// to deeply integrate with the system Calendar & Reminders apps.

@MainActor @Observable
final class EventKitService {
    static let shared = EventKitService()
    
    private let eventStore = EKEventStore()
    
    var calendarAccessGranted = false
    var remindersAccessGranted = false
    var systemEvents: [SystemCalendarEvent] = []
    var systemReminders: [SystemReminder] = []
    var availableCalendars: [EKCalendar] = []
    var selectedCalendarIDs: Set<String> = []
    var isLoading = false
    
    // MARK: - Search Cache (avoid repeated EventKit queries)
    private var searchCache: (events: [SystemCalendarEvent], timestamp: Date, lookback: Int, lookAhead: Int)?
    private let searchCacheTTL: TimeInterval = 300 // 5 minutes
    
    private init() {
        // Load saved calendar selections
        if let saved = UserDefaults.standard.array(forKey: "jarvis_selected_calendars") as? [String] {
            selectedCalendarIDs = Set(saved)
        }
        checkAuthorization()
    }
    
    // MARK: - Authorization
    
    func checkAuthorization() {
        let calStatus = EKEventStore.authorizationStatus(for: .event)
        calendarAccessGranted = calStatus == .fullAccess || calStatus == .authorized
        
        let remStatus = EKEventStore.authorizationStatus(for: .reminder)
        remindersAccessGranted = remStatus == .fullAccess || remStatus == .authorized
    }
    
    func requestCalendarAccess() async -> Bool {
        do {
            if #available(iOS 17.0, macOS 14.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                calendarAccessGranted = granted
                if granted { loadCalendars() }
                return granted
            } else {
                let granted = try await eventStore.requestAccess(to: .event)
                calendarAccessGranted = granted
                if granted { loadCalendars() }
                return granted
            }
        } catch {
            Logger.shared.error("Calendar access error: \(error)")
            return false
        }
    }
    
    func requestRemindersAccess() async -> Bool {
        do {
            if #available(iOS 17.0, macOS 14.0, *) {
                let granted = try await eventStore.requestFullAccessToReminders()
                remindersAccessGranted = granted
                return granted
            } else {
                let granted = try await eventStore.requestAccess(to: .reminder)
                remindersAccessGranted = granted
                return granted
            }
        } catch {
            Logger.shared.error("Reminders access error: \(error)")
            return false
        }
    }
    
    // MARK: - Calendars
    
    func loadCalendars() {
        availableCalendars = eventStore.calendars(for: .event)
        if selectedCalendarIDs.isEmpty {
            // Default: select all calendars
            selectedCalendarIDs = Set(availableCalendars.map { $0.calendarIdentifier })
        }
    }
    
    func toggleCalendar(_ calendarID: String) {
        if selectedCalendarIDs.contains(calendarID) {
            selectedCalendarIDs.remove(calendarID)
        } else {
            selectedCalendarIDs.insert(calendarID)
        }
        UserDefaults.standard.set(Array(selectedCalendarIDs), forKey: "jarvis_selected_calendars")
    }
    
    // MARK: - Events
    
    func fetchEvents(for date: Date) async {
        guard calendarAccessGranted else { return }
        isLoading = true
        defer { isLoading = false }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }
        
        let calendars = availableCalendars.filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else {
            systemEvents = []
            return
        }
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: calendars)
        let ekEvents = eventStore.events(matching: predicate)
        
        systemEvents = ekEvents.map { event in
            SystemCalendarEvent(
                id: event.eventIdentifier,
                title: event.title ?? "",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                calendarName: event.calendar.title,
                calendarColor: event.calendar.cgColor,
                location: event.location,
                notes: event.notes,
                attendees: Self.extractAttendees(from: event)
            )
        }.sorted { $0.startDate < $1.startDate }
    }
    
    /// Поиск событий в диапазоне lookbackDays назад — lookAheadDays вперёд (синхронно, для AIContextEngine).
    func searchEvents(lookbackDays: Int = 30, lookAheadDays: Int = 7) -> [SystemCalendarEvent] {
        guard calendarAccessGranted else { return [] }
        
        // Return cached results if still fresh
        if let cache = searchCache,
           cache.lookback == lookbackDays,
           cache.lookAhead == lookAheadDays,
           Date().timeIntervalSince(cache.timestamp) < searchCacheTTL {
            return cache.events
        }
        
        let cal = Calendar.current
        let now = Date()
        guard let start = cal.date(byAdding: .day, value: -lookbackDays, to: now),
              let end = cal.date(byAdding: .day, value: lookAheadDays, to: now) else { return [] }
        
        let calendars = availableCalendars.filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else { return [] }
        
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let ekEvents = eventStore.events(matching: predicate)
        
        let results = ekEvents.map { event in
            SystemCalendarEvent(
                id: event.eventIdentifier,
                title: event.title ?? "",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                calendarName: event.calendar.title,
                calendarColor: event.calendar.cgColor,
                location: event.location,
                notes: event.notes,
                attendees: Self.extractAttendees(from: event)
            )
        }.sorted { $0.startDate < $1.startDate }
        
        searchCache = (events: results, timestamp: Date(), lookback: lookbackDays, lookAhead: lookAheadDays)
        return results
    }
    
    func fetchEventsForWeek(from date: Date) async -> [SystemCalendarEvent] {
        guard calendarAccessGranted else { return [] }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfDay) else { return [] }
        
        let calendars = availableCalendars.filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else { return [] }
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfWeek, calendars: calendars)
        let ekEvents = eventStore.events(matching: predicate)
        
        return ekEvents.map { event in
            SystemCalendarEvent(
                id: event.eventIdentifier,
                title: event.title ?? "",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                calendarName: event.calendar.title,
                calendarColor: event.calendar.cgColor,
                location: event.location,
                notes: event.notes,
                attendees: Self.extractAttendees(from: event)
            )
        }.sorted { $0.startDate < $1.startDate }
    }
    
    // MARK: - Create Event
    
    func createEvent(title: String, startDate: Date, endDate: Date, notes: String? = nil, calendarID: String? = nil) -> Bool {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = notes
        
        if let calID = calendarID,
           let cal = availableCalendars.first(where: { $0.calendarIdentifier == calID }) {
            event.calendar = cal
        } else {
            event.calendar = eventStore.defaultCalendarForNewEvents
        }
        
        do {
            try eventStore.save(event, span: .thisEvent)
            Logger.shared.info("EventKit: created event '\(title)'")
            searchCache = nil  // Invalidate search cache
            return true
        } catch {
            Logger.shared.error("EventKit: failed to create event: \(error)")
            return false
        }
    }
    
    // MARK: - Delete Event
    
    func deleteEvent(identifier: String) -> Bool {
        guard let event = eventStore.event(withIdentifier: identifier) else { return false }
        do {
            try eventStore.remove(event, span: .thisEvent)
            searchCache = nil  // Invalidate search cache
            return true
        } catch {
            Logger.shared.error("EventKit: failed to delete event: \(error)")
            return false
        }
    }
    
    // MARK: - Reminders
    
    func fetchReminders() async {
        guard remindersAccessGranted else { return }
        
        let calendars = eventStore.calendars(for: .reminder)
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: Calendar.current.date(byAdding: .month, value: 1, to: Date()),
            calendars: calendars
        )
        
        let ekReminders = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
        
        systemReminders = ekReminders.map { reminder in
            SystemReminder(
                id: reminder.calendarItemIdentifier,
                title: reminder.title ?? "",
                dueDate: reminder.dueDateComponents?.date,
                isCompleted: reminder.isCompleted,
                priority: reminder.priority,
                notes: reminder.notes,
                listName: reminder.calendar.title
            )
        }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }
    
    func createReminder(title: String, dueDate: Date?, notes: String? = nil) -> Bool {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        reminder.calendar = eventStore.defaultCalendarForNewReminders()
        
        if let due = dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)
        }
        
        do {
            try eventStore.save(reminder, commit: true)
            Logger.shared.info("EventKit: created reminder '\(title)'")
            return true
        } catch {
            Logger.shared.error("EventKit: failed to create reminder: \(error)")
            return false
        }
    }
    
    func completeReminder(identifier: String) -> Bool {
        let predicate = eventStore.predicateForReminders(in: nil)
        // Use sync fetch for a single item
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else { return false }
        reminder.isCompleted = true
        do {
            try eventStore.save(reminder, commit: true)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Import to Jarvis
    
    /// Convert system calendar events to PlannerTasks
    func importEventsAsTasks(for date: Date) -> [PlannerTask] {
        return systemEvents.map { event in
            let duration = Int(event.endDate.timeIntervalSince(event.startDate) / 60)
            let rawNotes = [event.location, event.notes].compactMap { $0 }.joined(separator: "\n")
            return PlannerTask(
                title: event.title,
                notes: Self.stripHTML(rawNotes),
                date: event.startDate,
                durationMinutes: max(15, duration),
                isAllDay: event.isAllDay,
                calendarEventId: event.id,
                source: .calendar
            )
        }
    }
    
    /// Convert system reminders to PlannerTasks (inbox)
    func importRemindersAsTasks() -> [PlannerTask] {
        return systemReminders.filter { !$0.isCompleted }.map { reminder in
            PlannerTask(
                title: reminder.title,
                notes: reminder.notes ?? "",
                date: reminder.dueDate ?? Date(),
                durationMinutes: 30,
                isInbox: reminder.dueDate == nil,
                source: .calendar
            )
        }
    }
    
    // MARK: - Auto-Sync Calendar Events → PlannerStore
    
    /// Automatically sync system calendar events into PlannerStore for the given date range.
    /// Adds new events, updates changed ones, and removes deleted ones.
    func syncEventsToStore(daysBack: Int = 7, daysForward: Int = 30) {
        guard calendarAccessGranted else { return }
        
        let cal = Calendar.current
        let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date())
        let end = cal.date(byAdding: .day, value: daysForward, to: start) ?? start
        
        let calendars = availableCalendars.filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else { return }
        
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let ekEvents = eventStore.events(matching: predicate)
        
        let store = PlannerStore.shared
        // Index existing calendar-sourced tasks by their calendarEventId for fast lookup
        let existingByEventId: [String: PlannerTask] = {
            var dict: [String: PlannerTask] = [:]
            for task in store.tasks where task.calendarEventId != nil {
                dict[task.calendarEventId!] = task
            }
            return dict
        }()
        
        // Track which calendarEventIds are still present in the system calendar
        var seenEventIds: Set<String> = []
        
        for ek in ekEvents {
            let eventId = ek.eventIdentifier ?? ""
            guard !eventId.isEmpty else { continue }
            seenEventIds.insert(eventId)
            
            let duration = Int(ek.endDate.timeIntervalSince(ek.startDate) / 60)
            let rawNotes = [ek.location, ek.notes].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
            let notes = Self.stripHTML(rawNotes)
            
            if let existing = existingByEventId[eventId] {
                // Update if changed
                if existing.title != (ek.title ?? "") ||
                   abs(existing.date.timeIntervalSince(ek.startDate)) > 60 ||
                   existing.durationMinutes != max(15, duration) ||
                   existing.isAllDay != ek.isAllDay {
                    var updated = existing
                    updated.title = ek.title ?? ""
                    updated.notes = notes
                    updated.date = ek.startDate
                    updated.durationMinutes = max(15, duration)
                    updated.isAllDay = ek.isAllDay
                    store.update(updated)
                }
            } else {
                // Add new
                let task = PlannerTask(
                    title: ek.title ?? "",
                    notes: notes,
                    date: ek.startDate,
                    durationMinutes: max(15, duration),
                    isAllDay: ek.isAllDay,
                    calendarEventId: eventId,
                    source: .calendar
                )
                store.add(task)
            }
        }
        
        // Remove tasks whose calendar events no longer exist (deleted from system calendar)
        for task in store.tasks where task.source == .calendar && task.calendarEventId != nil {
            if !seenEventIds.contains(task.calendarEventId!) {
                // Only remove if the event date was within our sync range
                if task.date >= start && task.date < end {
                    store.delete(task)
                }
            }
        }
        
        Logger.shared.info("EventKit: synced \(ekEvents.count) events to store")
    }
    
    /// Extracts attendee names/emails from an EKEvent.
    private static func extractAttendees(from event: EKEvent) -> [String] {
        guard let attendees = event.attendees else { return [] }
        return attendees.compactMap { participant in
            // Prefer name, fall back to email from URL
            if let name = participant.name, !name.isEmpty {
                // If URL has email, include both
                if let email = participant.url.absoluteString
                    .replacingOccurrences(of: "mailto:", with: "")
                    .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                   email.contains("@") {
                    let cleanEmail = participant.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
                    return "\(name) <\(cleanEmail)>"
                }
                return name
            }
            // Just email
            let email = participant.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
            return email.contains("@") ? email : nil
        }
    }
    
    /// Removes HTML tags and decodes HTML entities from calendar event notes.
    private static func stripHTML(_ html: String) -> String {
        guard html.contains("<") || html.contains("&") else { return html }
        // Remove HTML tags
        var result = html.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // Decode common HTML entities
        let entities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&nbsp;", " ")
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        // Collapse multiple blank lines
        result = result.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - LLM Calendar Context

    /// Формирует текстовый контекст календаря для системного промпта LLM.
    /// Включает встречи на сегодня, завтра и ближайшую неделю.
    func calendarContextForLLM() -> String {
        guard calendarAccessGranted else {
            return "Календарь: доступ не предоставлен."
        }

        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)
        guard let tomorrowStart = cal.date(byAdding: .day, value: 1, to: todayStart),
              let tomorrowEnd = cal.date(byAdding: .day, value: 2, to: todayStart),
              let weekEnd = cal.date(byAdding: .day, value: 7, to: todayStart) else {
            return "Календарь: ошибка расчёта дат."
        }

        let calendars = availableCalendars.filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else {
            return "Календарь: нет выбранных календарей."
        }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM (EEE)"

        func formatEvent(_ ev: EKEvent) -> String {
            let time: String
            if ev.isAllDay {
                time = "весь день"
            } else {
                time = "\(timeFormatter.string(from: ev.startDate))–\(timeFormatter.string(from: ev.endDate))"
            }
            var line = "  • \(time) — \(ev.title ?? "Без названия")"

            if let loc = ev.location, !loc.isEmpty {
                line += " 📍\(loc)"
            }

            let attendees = (ev.attendees ?? [])
                .compactMap { $0.name ?? $0.url.absoluteString }
                .prefix(5)
            if !attendees.isEmpty {
                line += " 👥\(attendees.joined(separator: ", "))"
            }

            if let notes = ev.notes, !notes.isEmpty {
                let short = String(notes.prefix(100))
                line += " | \(short)"
            }
            return line
        }

        // Today
        let todayPredicate = eventStore.predicateForEvents(withStart: todayStart, end: tomorrowStart, calendars: calendars)
        let todayEvents = eventStore.events(matching: todayPredicate).sorted { $0.startDate < $1.startDate }

        // Tomorrow
        let tomorrowPredicate = eventStore.predicateForEvents(withStart: tomorrowStart, end: tomorrowEnd, calendars: calendars)
        let tomorrowEvents = eventStore.events(matching: tomorrowPredicate).sorted { $0.startDate < $1.startDate }

        // Rest of the week (day-after-tomorrow .. +7 days)
        let restPredicate = eventStore.predicateForEvents(withStart: tomorrowEnd, end: weekEnd, calendars: calendars)
        let restEvents = eventStore.events(matching: restPredicate).sorted { $0.startDate < $1.startDate }

        var ctx = "📅 КАЛЕНДАРЬ ПОЛЬЗОВАТЕЛЯ:\n"

        // Today
        ctx += "\n🔵 Сегодня (\(dateFormatter.string(from: todayStart))):\n"
        if todayEvents.isEmpty {
            ctx += "  Нет встреч/событий.\n"
        } else {
            // Highlight upcoming (after now)
            for ev in todayEvents {
                var line = formatEvent(ev)
                if ev.startDate > now {
                    line += " ⏳"
                }
                ctx += line + "\n"
            }
        }

        // Tomorrow
        ctx += "\n🟡 Завтра (\(dateFormatter.string(from: tomorrowStart))):\n"
        if tomorrowEvents.isEmpty {
            ctx += "  Нет встреч/событий.\n"
        } else {
            for ev in tomorrowEvents {
                ctx += formatEvent(ev) + "\n"
            }
        }

        // Rest of week
        if !restEvents.isEmpty {
            ctx += "\n🗓 Ближайшая неделя:\n"
            // Group by day
            var grouped: [Date: [EKEvent]] = [:]
            for ev in restEvents {
                let dayStart = cal.startOfDay(for: ev.startDate)
                grouped[dayStart, default: []].append(ev)
            }
            for day in grouped.keys.sorted() {
                ctx += " \(dateFormatter.string(from: day)):\n"
                for ev in grouped[day]! {
                    ctx += formatEvent(ev) + "\n"
                }
            }
        }

        // Free slots today (simple: find gaps ≥ 30 min between 09:00–21:00)
        let workStart = cal.date(bySettingHour: 9, minute: 0, second: 0, of: todayStart) ?? todayStart
        let workEnd = cal.date(bySettingHour: 21, minute: 0, second: 0, of: todayStart) ?? tomorrowStart
        let nonAllDay = todayEvents.filter { !$0.isAllDay && $0.endDate > now }

        var freeSlots: [(Date, Date)] = []
        var cursor = max(now, workStart)
        for ev in nonAllDay where ev.startDate >= cursor {
            if ev.startDate.timeIntervalSince(cursor) >= 30 * 60 {
                freeSlots.append((cursor, ev.startDate))
            }
            cursor = max(cursor, ev.endDate)
        }
        if workEnd.timeIntervalSince(cursor) >= 30 * 60 {
            freeSlots.append((cursor, workEnd))
        }

        if !freeSlots.isEmpty {
            ctx += "\n🟢 Свободные окна сегодня:\n"
            for (start, end) in freeSlots.prefix(5) {
                let mins = Int(end.timeIntervalSince(start) / 60)
                ctx += "  • \(timeFormatter.string(from: start))–\(timeFormatter.string(from: end)) (\(mins) мин)\n"
            }
        }

        return ctx
    }
}

// MARK: - Models

struct SystemCalendarEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarName: String
    let calendarColor: CGColor?
    let location: String?
    let notes: String?
    let attendees: [String]  // email или имя участника
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SystemCalendarEvent, rhs: SystemCalendarEvent) -> Bool {
        lhs.id == rhs.id
    }
}

struct SystemReminder: Identifiable {
    let id: String
    let title: String
    let dueDate: Date?
    let isCompleted: Bool
    let priority: Int
    let notes: String?
    let listName: String
}
