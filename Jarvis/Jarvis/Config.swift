import Foundation

enum Config: Sendable {
    static let backendURL = URL(string: "http://jarvis-app.mooo.com:8000")!
    static let iCloudContainerID = "iCloud.com.jarvis.planner"
    /// App Group для обмена данными с виджетом (должен совпадать с entitlements).
    static let appGroupSuite = "group.com.jarvis.planner"
    
    enum Endpoints: Sendable {
        static let calendar = URL(string: "http://jarvis-app.mooo.com:8000/calendar/events")!
        static let mail = URL(string: "http://jarvis-app.mooo.com:8000/mail/messages")!
        static let authStatus = URL(string: "http://jarvis-app.mooo.com:8000/auth/status")!
        static let authGoogle = URL(string: "http://jarvis-app.mooo.com:8000/auth/google")!
        static let analyzeMeal = URL(string: "http://jarvis-app.mooo.com:8000/analyze-meal")!
        static let llmPlan = URL(string: "http://jarvis-app.mooo.com:8000/llm/plan")!
    }
    
    enum Storage: Sendable {
        static let tasksKey = "jarvis_tasks_v4"
        static let wellnessKey = "jarvis_wellness_v3"
        static let aiModelKey = "jarvis_ai_model_v2"
        static let categoriesKey = "jarvis_categories_v1"
        static let tagsKey = "jarvis_tags_v1"
    }

    enum Defaults: Sendable {
        static let dailyCalorieGoal = 2000
        static let dailySleepGoalHours = 8.0
        static let riseHour = 6
        static let riseMinute = 0
        static let windDownHour = 23
        static let windDownMinute = 0
    }
}
