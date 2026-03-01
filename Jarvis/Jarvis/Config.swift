import Foundation

enum Config: Sendable {
    static let backendURL = URL(string: "http://localhost:8000")!
    static let iCloudContainerID = "iCloud.com.jarvis.planner"
    /// App Group для обмена данными с виджетом (должен совпадать с entitlements).
    static let appGroupSuite = "group.com.jarvis.planner"
    
    enum Endpoints: Sendable {
        static let calendar = URL(string: "http://localhost:8000/calendar/events")!
        static let mail = URL(string: "http://localhost:8000/mail/messages")!
        static let authStatus = URL(string: "http://localhost:8000/auth/status")!
        static let authGoogle = URL(string: "http://localhost:8000/auth/google")!
        static let authLogout = URL(string: "http://localhost:8000/auth/logout")!
        static let analyzeMeal = URL(string: "http://localhost:8000/analyze-meal")!
        static let llmPlan = URL(string: "http://localhost:8000/llm/plan")!
        static let llmChat = URL(string: "http://localhost:8000/llm/chat")!
        static let aiCommand = URL(string: "http://localhost:8000/ai/command")!
        static let mailSend = URL(string: "http://localhost:8000/mail/send")!
        static let mailReply = URL(string: "http://localhost:8000/mail/reply")!
        /// Ollama API (локальная LLM, как в OpenClaw). По умолчанию localhost; можно переопределить через UserDefaults.
        static var ollamaBase: URL {
            if let path = UserDefaults.standard.string(forKey: Config.Storage.ollamaBaseURLKey),
               let url = URL(string: path), path.isEmpty == false {
                return url
            }
            return URL(string: "http://localhost:11434")!
        }
    }
    
    enum Ollama: Sendable {
        static let defaultModelName = "llama3.2"
    }
    
    enum Storage: Sendable {
        static let tasksKey = "jarvis_tasks_v4"
        static let wellnessKey = "jarvis_wellness_v3"
        static let aiModelKey = "jarvis_ai_model_v2"
        static let ollamaBaseURLKey = "jarvis_ollama_base_url"
        static let ollamaModelKey = "jarvis_ollama_model"
        static let categoriesKey = "jarvis_categories_v1"
        static let tagsKey = "jarvis_tags_v1"
        static let projectsKey = "jarvis_projects_v1"
        /// Навыки в духе OpenClaw (вкл/выкл интеграций)
        static let skillCalendarKey = "jarvis_skill_calendar"
        static let skillMailKey = "jarvis_skill_mail"
        static let skillDeepAnalysisKey = "jarvis_skill_deep_analysis"
        static let skillVoiceKey = "jarvis_skill_voice"
        /// Эффект увеличения при наведении (как Dock на Mac)
        static let dockMagnificationKey = "jarvis_dock_magnification_enabled"
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
