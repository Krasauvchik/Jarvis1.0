import Foundation
import UserNotifications
import Combine

@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published private(set) var isAuthorized = false
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestAuthorization() {
        Task {
            do {
                try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                let settings = await UNUserNotificationCenter.current().notificationSettings()
                isAuthorized = settings.authorizationStatus == .authorized
            } catch {
                print("Notification authorization failed: \(error)")
            }
        }
    }
    
    func scheduleAlarm(for task: PlannerTask) {
        guard !task.isInbox, task.hasAlarm else { return }
        
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            
            let content = UNMutableNotificationContent()
            content.title = task.title
            content.body = task.notes.isEmpty ? L10n.notificationReminder : task.notes
            content.sound = .default
            content.userInfo = ["taskID": task.id.uuidString]
            
            // Schedule notification 15 minutes before task time
            let reminderDate = task.date.addingTimeInterval(-15 * 60)
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: trigger)
            
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                Logger.shared.error("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }
    
    func cancelAlarm(for task: PlannerTask) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [task.id.uuidString])
    }
    
    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        #if os(watchOS)
        completionHandler([.sound])
        #else
        completionHandler([.banner, .sound, .badge, .list])
        #endif
    }
    
    /// Handle notification tap — deep link to the task
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let taskIDString = userInfo["taskID"] as? String,
           let uuid = UUID(uuidString: taskIDString) {
            Task { @MainActor in
                DeepLinkManager.shared.pendingTaskID = uuid
            }
        }
        completionHandler()
    }
}
