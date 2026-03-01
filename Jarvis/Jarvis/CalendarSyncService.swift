import Foundation
import Combine
import EventKit
#if canImport(UIKit)
import UIKit
#endif

/// Синхронизация задач Jarvis с приложением «Календарь» (EventKit).
@MainActor
final class CalendarSyncService: ObservableObject {
    static let shared = CalendarSyncService()
    
    @Published private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published private(set) var syncToCalendarEnabled: Bool = false
    
    private let eventStore = EKEventStore()
    private let defaultsKey = "jarvis_calendar_sync_enabled"

    /// Доступ к календарю (fullAccess на iOS 17+ / authorized на старых версиях без deprecated warning).
    private var hasEventAccess: Bool {
        let status = authorizationStatus
        if #available(iOS 17.0, macOS 14.0, *) {
            return status == .fullAccess
        }
        return status.rawValue == 3 // EKAuthorizationStatus.authorized
    }

    /// Для UI: true, если доступ к календарю выдан (без импорта EventKit во view).
    var isAuthorizedForCalendar: Bool { hasEventAccess }
    
    init() {
        syncToCalendarEnabled = UserDefaults.standard.bool(forKey: defaultsKey)
        updateAuthorizationStatus()
    }
    
    func updateAuthorizationStatus() {
        if #available(iOS 17.0, macOS 14.0, *) {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        } else {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        }
    }
    
    func setSyncToCalendarEnabled(_ enabled: Bool) {
        syncToCalendarEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: defaultsKey)
    }
    
    /// Запросить доступ к календарю.
    func requestAccess() async -> Bool {
        if #available(iOS 17.0, macOS 14.0, *) {
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                await MainActor.run { updateAuthorizationStatus() }
                return granted
            } catch {
                await MainActor.run { updateAuthorizationStatus() }
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, _ in
                    Task { @MainActor in
                        CalendarSyncService.shared.updateAuthorizationStatus()
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }
    
    /// Создать или обновить событие в календаре для задачи.
    func addOrUpdateEvent(for task: PlannerTask) {
        guard syncToCalendarEnabled else { return }
        guard hasEventAccess else { return }
        
        let calendar = eventStore.defaultCalendarForNewEvents ?? eventStore.calendars(for: .event).first
        guard let calendar else { return }
        
        if let existingId = task.calendarEventId,
           let existing = eventStore.event(withIdentifier: existingId) {
            existing.title = task.title
            existing.notes = task.notes
            existing.startDate = task.date
            existing.endDate = task.endDate
            existing.isAllDay = task.isAllDay
            existing.calendar = calendar
            do {
                try eventStore.save(existing, span: .thisEvent)
            } catch {}
            return
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = task.title
        event.notes = task.notes
        event.startDate = task.date
        event.endDate = task.endDate
        event.isAllDay = task.isAllDay
        do {
            try eventStore.save(event, span: .thisEvent)
            var updated = task
            updated.calendarEventId = event.eventIdentifier
            PlannerStore.shared.update(updated)
        } catch {}
    }
    
    /// Удалить событие календаря, привязанное к задаче.
    func removeEvent(for task: PlannerTask) {
        guard let id = task.calendarEventId,
              let event = eventStore.event(withIdentifier: id) else { return }
        do {
            try eventStore.remove(event, span: .thisEvent)
            var updated = task
            updated.calendarEventId = nil
            PlannerStore.shared.update(updated)
        } catch {}
    }
    
    /// События календаря на указанный день (для отображения в таймлайне при необходимости).
    func events(for day: Date) -> [EKEvent] {
        guard hasEventAccess else { return [] }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        return eventStore.events(matching: predicate)
    }
}
