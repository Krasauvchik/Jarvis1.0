import Foundation
import Combine
import UserNotifications

// MARK: - Use Case Protocol

protocol UseCase {
    associatedtype Input
    associatedtype Output
    
    func execute(_ input: Input) async throws -> Output
}

// MARK: - Task Use Cases

/// Add new task use case
struct AddTaskUseCase: UseCase {
    typealias Input = PlannerTask
    typealias Output = PlannerTask
    
    @MainActor
    func execute(_ task: PlannerTask) async throws -> PlannerTask {
        // Validate
        guard !task.title.trimmed.isEmpty else {
            throw ValidationError.emptyTitle
        }
        
        // Add to repository
        let repository = TaskRepository.shared
        repository.add(task)
        
        // Schedule notification if needed
        if !task.isInbox && task.date.isFuture {
            await scheduleNotification(for: task)
        }
        
        // Sync to cloud
        CloudSync.shared.queueForSync(task)
        
        Logger.shared.info("Task added via UseCase: \(task.title)")
        
        return task
    }
    
    @MainActor
    private func scheduleNotification(for task: PlannerTask) async {
        await NotificationManager.shared.scheduleTaskReminder(for: task)
    }
}

/// Complete task use case
struct CompleteTaskUseCase: UseCase {
    typealias Input = UUID
    typealias Output = PlannerTask?
    
    @MainActor
    func execute(_ taskId: UUID) async throws -> PlannerTask? {
        let repository = TaskRepository.shared
        
        guard var task = repository.get(by: taskId) else {
            Logger.shared.warning("Task not found: \(taskId)")
            return nil
        }
        
        task.isCompleted = true
        repository.update(task)
        
        // Cancel any pending notifications
        NotificationManager.shared.cancelNotification(for: taskId)
        
        // Trigger haptic feedback
        #if os(iOS)
        triggerHaptic(.success)
        #endif
        
        Logger.shared.info("Task completed: \(task.title)")
        
        return task
    }
}

/// Reschedule task use case
struct RescheduleTaskUseCase: UseCase {
    struct Input {
        let taskId: UUID
        let newDate: Date
    }
    typealias Output = PlannerTask?
    
    @MainActor
    func execute(_ input: Input) async throws -> PlannerTask? {
        let repository = TaskRepository.shared
        
        guard var task = repository.get(by: input.taskId) else {
            return nil
        }
        
        task.date = input.newDate
        task.isInbox = false
        repository.update(task)
        
        // Reschedule notification
        if input.newDate.isFuture {
            await NotificationManager.shared.scheduleTaskReminder(for: task)
        }
        
        Logger.shared.info("Task rescheduled: \(task.title) to \(input.newDate.relativeDescription)")
        
        return task
    }
}

/// Delete task use case
struct DeleteTaskUseCase: UseCase {
    typealias Input = UUID
    typealias Output = Bool
    
    @MainActor
    func execute(_ taskId: UUID) async throws -> Bool {
        let repository = TaskRepository.shared
        
        guard let task = repository.get(by: taskId) else {
            return false
        }
        
        repository.delete(by: taskId)
        NotificationManager.shared.cancelNotification(for: taskId)
        
        Logger.shared.info("Task deleted: \(task.title)")
        
        return true
    }
}

// MARK: - Sync Use Cases

/// Sync all data use case
struct SyncAllDataUseCase: UseCase {
    typealias Input = Void
    typealias Output = SyncResult
    
    struct SyncResult {
        let tasksUpdated: Int
        let success: Bool
        let error: Error?
    }
    
    @MainActor
    func execute(_ input: Void) async throws -> SyncResult {
        guard NetworkMonitor.shared.isConnected else {
            throw NetworkError.noConnection
        }
        
        let cloudSync = CloudSync.shared
        
        cloudSync.forceSync()
        
        // Wait for sync to complete
        try await Task.sleep(seconds: 1)
        
        let tasksCount = TaskRepository.shared.items.count
        
        return SyncResult(
            tasksUpdated: tasksCount,
            success: true,
            error: nil
        )
    }
}

// MARK: - Import Use Cases

/// Import calendar events use case
struct ImportCalendarEventsUseCase: UseCase {
    typealias Input = Void
    typealias Output = [PlannerTask]
    
    func execute(_ input: Void) async throws -> [PlannerTask] {
        let events = try await CalendarService.shared.fetchEvents()
        
        Logger.shared.info("Imported \(events.count) calendar events")
        
        return events
    }
}

// MARK: - AI Use Cases

/// Extract task from text use case
struct ExtractTaskFromTextUseCase: UseCase {
    struct Input {
        let text: String
        let referenceDate: Date
    }
    typealias Output = PlannerTask?
    
    @MainActor
    func execute(_ input: Input) async throws -> PlannerTask? {
        let aiManager = DependencyContainer.shared.aiManager
        
        return aiManager.extractTask(from: input.text, referenceDate: input.referenceDate)
    }
}

/// Get AI advice use case
struct GetAIAdviceUseCase: UseCase {
    typealias Input = [PlannerTask]
    typealias Output = [String]
    
    @MainActor
    func execute(_ tasks: [PlannerTask]) async throws -> [String] {
        let aiManager = DependencyContainer.shared.aiManager
        
        return aiManager.generateAdvice(from: tasks)
    }
}

// MARK: - Statistics Use Cases

/// Get task statistics use case
struct GetTaskStatisticsUseCase: UseCase {
    typealias Input = Void
    typealias Output = DetailedStatistics
    
    struct DetailedStatistics {
        let taskStats: TaskStatistics
        let weeklyProgress: [DayProgress]
        let categoryBreakdown: [CategoryCount]
    }
    
    struct DayProgress {
        let date: Date
        let completed: Int
        let total: Int
    }
    
    struct CategoryCount {
        let icon: String
        let count: Int
    }
    
    @MainActor
    func execute(_ input: Void) async throws -> DetailedStatistics {
        let repository = TaskRepository.shared
        let tasks = repository.items
        
        // Basic stats
        let taskStats = repository.statistics()
        
        // Weekly progress
        let calendar = Calendar.current
        let today = Date()
        var weeklyProgress: [DayProgress] = []
        
        for dayOffset in -6...0 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            
            let dayTasks = tasks.filter { calendar.isDate($0.date, inSameDayAs: date) && !$0.isInbox }
            let completed = dayTasks.filter { $0.isCompleted }.count
            
            weeklyProgress.append(DayProgress(
                date: date,
                completed: completed,
                total: dayTasks.count
            ))
        }
        
        // Category breakdown
        var iconCounts: [String: Int] = [:]
        for task in tasks where !task.isCompleted {
            iconCounts[task.icon, default: 0] += 1
        }
        
        let categoryBreakdown = iconCounts.map { CategoryCount(icon: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
        
        return DetailedStatistics(
            taskStats: taskStats,
            weeklyProgress: weeklyProgress,
            categoryBreakdown: categoryBreakdown
        )
    }
}

// MARK: - Convenience Extensions

extension NotificationManager {
    func scheduleTaskReminder(for task: PlannerTask) async {
        guard !task.isInbox, !task.isCompleted else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Напоминание"
        content.body = task.title
        content.sound = .default
        
        let triggerDate = task.date.adding(minutes: -15) // 15 min before
        guard triggerDate.isFuture else { return }
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: task.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            Logger.shared.debug("Notification scheduled for: \(task.title)")
        } catch {
            Logger.shared.error(error, context: "Failed to schedule notification")
        }
    }
    
    func cancelNotification(for taskId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [taskId.uuidString])
    }
}
