import SwiftUI
import Combine

// MARK: - Deep Link Manager (Phase 3)

/// Handles URL scheme routing for jarvis:// deep links.
/// Sources: Widget taps, notification taps, Siri Shortcuts, external apps.
///
/// URL Scheme:
///   jarvis://task/{uuid}        — open/edit a specific task
///   jarvis://today              — navigate to Today section
///   jarvis://inbox              — navigate to Inbox
///   jarvis://add                — open Add Task sheet
///   jarvis://analytics          — open Analytics
///   jarvis://chat               — open AI Chat
@MainActor
final class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()
    
    /// The task ID to navigate to (set by deep link, consumed by UI)
    @Published var pendingTaskID: UUID?
    /// Section to navigate to
    @Published var pendingSection: String?
    /// Whether to show the Add Task sheet
    @Published var pendingAddTask = false
    
    private init() {}
    
    /// Parse and route an incoming URL
    func handle(_ url: URL) {
        guard url.scheme == "jarvis" else {
            Logger.shared.warning("DeepLink: unknown scheme \(url.scheme ?? "nil")")
            return
        }
        
        let host = url.host ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        Logger.shared.info("DeepLink: \(url.absoluteString)")
        
        switch host {
        case "task":
            if let idString = pathComponents.first, let uuid = UUID(uuidString: idString) {
                pendingTaskID = uuid
            }
        case "today":
            pendingSection = "today"
        case "inbox":
            pendingSection = "inbox"
        case "add":
            pendingAddTask = true
        case "analytics":
            pendingSection = "analytics"
        case "chat":
            pendingSection = "chat"
        case "calendar":
            pendingSection = "calendar"
        case "mail":
            pendingSection = "mail"
        case "messengers":
            pendingSection = "messengers"
        default:
            Logger.shared.warning("DeepLink: unhandled host '\(host)'")
        }
    }
    
    /// Map a string section name to NavigationSection
    func resolveSection(_ name: String) -> NavigationSection? {
        switch name {
        case "today": return .today
        case "inbox": return .inbox
        case "scheduled": return .scheduled
        case "futurePlans": return .futurePlans
        case "completed": return .completed
        case "all": return .all
        case "calendar": return .calendarSection
        case "mail": return .mailSection
        case "messengers": return .messengers
        case "analytics": return .analytics
        case "chat": return .chat
        default: return nil
        }
    }
    
    /// Clear pending navigation after it's been consumed
    func clearPendingTask() {
        pendingTaskID = nil
    }
    
    func clearPendingSection() {
        pendingSection = nil
    }
    
    func clearPendingAddTask() {
        pendingAddTask = false
    }
    
    // MARK: - URL Builders
    
    /// Build a deep link URL for a specific task
    static func taskURL(id: UUID) -> URL {
        URL(string: "jarvis://task/\(id.uuidString)")!
    }
    
    /// Build a deep link URL for a section
    static func sectionURL(_ section: String) -> URL {
        URL(string: "jarvis://\(section)")!
    }
    
    static func addTaskURL() -> URL {
        URL(string: "jarvis://add")!
    }
}
