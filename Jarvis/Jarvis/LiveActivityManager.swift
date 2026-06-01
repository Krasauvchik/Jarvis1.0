import Foundation
import SwiftUI
import Combine
#if os(iOS)
import ActivityKit
#endif

// MARK: - Task Live Activity Attributes

#if os(iOS)
/// ActivityKit attributes for a running task Live Activity (iOS 16.2+).
struct TaskActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var taskTitle: String
        var endTime: Date
        var isCompleted: Bool
        var colorIndex: Int
    }

    var taskId: String
    var startTime: Date
    var durationMinutes: Int
}
#endif

// MARK: - Live Activity Manager

/// Manages Live Activities for active tasks (iOS 16.2+).
@MainActor
final class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    @Published private(set) var isActivityActive = false
    private var currentActivityId: String?

    private init() {}

    /// Start a Live Activity for the given task.
    func startActivity(for task: PlannerTask) {
        #if os(iOS)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            Logger.shared.debug("Live Activities not enabled")
            return
        }

        // End any existing activity first
        endCurrentActivity()

        let attributes = TaskActivityAttributes(
            taskId: task.id.uuidString,
            startTime: task.date,
            durationMinutes: task.durationMinutes
        )

        let endTime = task.date.addingTimeInterval(TimeInterval(task.durationMinutes * 60))
        let state = TaskActivityAttributes.ContentState(
            taskTitle: task.title,
            endTime: endTime,
            isCompleted: false,
            colorIndex: task.colorIndex
        )

        let content = ActivityContent(state: state, staleDate: endTime.addingTimeInterval(300))

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            currentActivityId = activity.id
            isActivityActive = true
            Logger.shared.info("Live Activity started for task: \(task.title)")
        } catch {
            Logger.shared.error("Failed to start Live Activity: \(error.localizedDescription)")
        }
        #endif
    }

    /// Update the Live Activity when task is completed.
    func markCompleted(for task: PlannerTask) {
        #if os(iOS)
        guard let activityId = currentActivityId else { return }

        let state = TaskActivityAttributes.ContentState(
            taskTitle: task.title,
            endTime: Date(),
            isCompleted: true,
            colorIndex: task.colorIndex
        )

        Task {
            for activity in Activity<TaskActivityAttributes>.activities {
                if activity.id == activityId {
                    await activity.end(
                        ActivityContent(state: state, staleDate: nil),
                        dismissalPolicy: .after(.now + 60)
                    )
                    break
                }
            }
            currentActivityId = nil
            isActivityActive = false
        }
        #endif
    }

    /// End the current Live Activity.
    func endCurrentActivity() {
        #if os(iOS)
        guard let activityId = currentActivityId else { return }

        Task {
            for activity in Activity<TaskActivityAttributes>.activities {
                if activity.id == activityId {
                    await activity.end(nil, dismissalPolicy: .immediate)
                    break
                }
            }
            currentActivityId = nil
            isActivityActive = false
            Logger.shared.info("Live Activity ended")
        }
        #endif
    }

    /// End all Jarvis Live Activities.
    func endAllActivities() {
        #if os(iOS)
        Task {
            for activity in Activity<TaskActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            currentActivityId = nil
            isActivityActive = false
        }
        #endif
    }
}
