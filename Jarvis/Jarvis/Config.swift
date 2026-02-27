import Foundation

enum Config {
    static let backendURL = URL(string: "http://jarvis-app.mooo.com:8000")!
    
    enum Endpoints {
        static var calendar: URL { backendURL.appendingPathComponent("calendar/events") }
        static var mail: URL { backendURL.appendingPathComponent("mail/messages") }
        static var authStatus: URL { backendURL.appendingPathComponent("auth/status") }
        static var authGoogle: URL { backendURL.appendingPathComponent("auth/google") }
        static var analyzeMeal: URL { backendURL.appendingPathComponent("analyze-meal") }
        static var llmPlan: URL { backendURL.appendingPathComponent("llm/plan") }
    }
    
    enum Storage {
        static let tasksKey = "jarvis_tasks_v2"
        static let wellnessKey = "jarvis_wellness_v2"
        static let aiModelKey = "jarvis_ai_model_v2"
    }
    
    enum Defaults {
        static let dailyCalorieGoal = 2000
        static let dailySleepGoalHours = 8.0
    }
}
