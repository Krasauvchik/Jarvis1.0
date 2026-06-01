import Foundation

enum Config: Sendable {
    // MARK: - Backend URL (configurable via Settings)
    
    /// Production backend URL. Users can override in Settings → Backend URL.
    /// Default: your VPS server. For local dev, change to https://localhost:8000.
    #if DEBUG
    private static let defaultBackendBase = "http://localhost:8000"
    #else
    // Production: domain with a valid TLS certificate (terminated by Caddy on :443).
    // Strict ATS requires a real cert — do not point this at a raw IP / self-signed host.
    private static let defaultBackendBase = "https://jarvis-app.mooo.com"
    #endif
    
    /// Current backend base URL (reads user override from UserDefaults).
    static var backendBase: String {
        if let custom = UserDefaults.standard.string(forKey: Storage.backendURLKey),
           !custom.isEmpty {
            return custom.hasSuffix("/") ? String(custom.dropLast()) : custom
        }
        return defaultBackendBase
    }
    
    static var backendURL: URL { URL(string: backendBase) ?? URL(string: defaultBackendBase)! }
    
    /// Current API key (reads from the Keychain via SecretStore, set in Settings).
    static var apiKey: String? {
        if let stored = SecretStore.get(.backendAPIKey), !stored.isEmpty { return stored }
        #if DEBUG
        return "test123"  // Default key for local development
        #else
        return nil
        #endif
    }
    
    /// Build a URLRequest with API key header attached.
    static func authorizedRequest(url: URL, method: String = "GET") -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let key = apiKey, !key.isEmpty {
            req.setValue(key, forHTTPHeaderField: "X-API-Key")
        }
        return req
    }
    
    /// Shared URLSession that trusts self-signed certificates in DEBUG builds.
    /// In RELEASE builds, returns default URLSession.shared.
    static let urlSession: URLSession = {
        #if DEBUG
        let delegate = SelfSignedCertDelegate()
        return URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        #else
        return URLSession.shared
        #endif
    }()
    
    static let iCloudContainerID = "iCloud.com.jarvis.planner"
    /// App Group для обмена данными с виджетом (должен совпадать с entitlements).
    static let appGroupSuite = "group.com.jarvis.planner"
    
    // MARK: - Endpoints (dynamic, based on backendBase)
    
    enum Endpoints: Sendable {
        private static var base: String { Config.backendBase }
        
        /// Safe URL builder — avoids force-unwraps. Falls back to backendURL if string is invalid.
        private static func url(_ path: String) -> URL {
            URL(string: "\(base)\(path)") ?? Config.backendURL
        }
        
        static var calendar: URL { url("/calendar/events") }
        static func calendar(daysAhead: Int) -> URL { url("/calendar/events?days=\(daysAhead)") }
        static func calendarEvent(_ id: String) -> URL {
            let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
            return URL(string: "\(base)/calendar/events/\(encoded)") ?? calendar
        }
        static var mail: URL { url("/mail/messages") }
        static var authStatus: URL { url("/auth/status") }
        static var authGoogle: URL { url("/auth/google") }
        static var authLogout: URL { url("/auth/logout") }
        static var analyzeMeal: URL { url("/analyze-meal") }
        static var llmPlan: URL { url("/llm/plan") }
        static var llmChat: URL { url("/llm/chat") }
        static var aiCommand: URL { url("/ai/command") }
        static var aiContextSearch: URL { url("/ai/context-search") }
        static var aiMeetingBriefing: URL { url("/ai/meeting-briefing") }
        static var aiDelegateTask: URL { url("/ai/delegate-task") }
        static var aiSummarize: URL { url("/ai/summarize") }
        static var aiGenerateReply: URL { url("/ai/generate-reply") }
        static var mailSend: URL { url("/mail/send") }
        static var mailReply: URL { url("/mail/reply") }
        static func mailMessage(_ id: String) -> URL {
            let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
            return URL(string: "\(base)/mail/messages/\(encoded)") ?? mail
        }
        static func mailDelete(_ id: String) -> URL {
            let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
            return URL(string: "\(base)/mail/messages/\(encoded)") ?? mail
        }
        
        // Telegram integration
        static var telegramStatus: URL { url("/integrations/telegram/status") }
        static var telegramApiCredentials: URL { url("/integrations/telegram/api-credentials") }
        static var telegramConfigure: URL { url("/integrations/telegram/configure") }
        static var telegramAuthStart: URL { url("/integrations/telegram/auth/start") }
        static var telegramAuthComplete: URL { url("/integrations/telegram/auth/complete") }
        static var telegramChats: URL { url("/integrations/telegram/chats") }
        static var telegramChatsSearch: URL { url("/integrations/telegram/chats/search") }
        static var telegramChatsSelect: URL { url("/integrations/telegram/chats/select") }
        static var telegramDigest: URL { url("/integrations/telegram/digest") }
        static var telegramDisconnect: URL { url("/integrations/telegram/disconnect") }
    }
    
    enum YandexGPT: Sendable {
        /// Endpoint для YandexGPT Foundation Models API
        static let completionURL = "https://llm.api.cloud.yandex.net/foundationModels/v1/completion"
        /// Async completion (для длинных запросов)
        static let asyncCompletionURL = "https://llm.api.cloud.yandex.net/foundationModels/v1/completionAsync"
        /// Модели: yandexgpt-lite, yandexgpt, yandexgpt-32k
        static let defaultModel = "yandexgpt-lite"
        /// Timeout для запросов
        static let timeout: TimeInterval = 30
    }
    
    enum Storage: Sendable {
        /// Custom backend URL override (set by user in Settings)
        static let backendURLKey = "jarvis_backend_url"
        /// API key for authenticating with backend
        static let apiKeyKey = "jarvis_api_key"
        static let tasksKey = "jarvis_tasks_v4"
        static let wellnessKey = "jarvis_wellness_v3"
        static let aiModelKey = "jarvis_ai_model_v2"
        /// YandexGPT API credentials
        static let yandexGPTApiKeyKey = "jarvis_yandexgpt_api_key"
        static let yandexGPTFolderIdKey = "jarvis_yandexgpt_folder_id"
        static let yandexGPTModelKey = "jarvis_yandexgpt_model"
        /// Gemini API credentials
        static let geminiApiKeyKey = "jarvis_gemini_api_key"
        static let geminiModelKey = "jarvis_gemini_model"
        static let categoriesKey = "jarvis_categories_v1"
        static let tagsKey = "jarvis_tags_v1"
        static let projectsKey = "jarvis_projects_v1"
        /// Навыки в духе OpenClaw (вкл/выкл интеграций)
        static let skillCalendarKey = "jarvis_skill_calendar"
        static let skillMailKey = "jarvis_skill_mail"
        static let skillDeepAnalysisKey = "jarvis_skill_deep_analysis"
        static let skillVoiceKey = "jarvis_skill_voice"
        /// Telegram integration
        static let skillTelegramKey = "jarvis_skill_telegram"
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

// MARK: - Self-Signed Certificate Trust (DEBUG only)

#if DEBUG
/// URLSessionDelegate that trusts self-signed certificates for local development.
final class SelfSignedCertDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
#endif
