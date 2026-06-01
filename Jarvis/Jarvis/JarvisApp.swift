import SwiftUI
import SwiftData

@main
struct JarvisApp: App {
    @StateObject private var container = DependencyContainer.shared
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    @StateObject private var onboardingManager = OnboardingManager.shared
    private var appLock = AppLockService.shared
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Activate crash reporter early
        CrashReporter.shared.activate()

        // Move any legacy plaintext secrets out of UserDefaults into the Keychain.
        SecretStore.migrateLegacySecretsIfNeeded()

        NSUbiquitousKeyValueStore.default.synchronize()
        // Trigger one-time migration from UserDefaults → SwiftData
        Task { @MainActor in
            let persistence = DataPersistence.shared
            if !persistence.isMigrated {
                persistence.migrateFromUserDefaultsIfNeeded(store: PlannerStore.shared)
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if !onboardingManager.hasCompletedOnboarding {
                    OnboardingView(onboardingManager: onboardingManager)
                } else {
                    #if os(macOS)
                    StructuredMainView()
                        .withDependencies(container)
                        .environmentObject(deepLinkManager)
                        .onOpenURL { url in
                            deepLinkManager.handle(url)
                        }
                    #elseif os(watchOS)
                    MainView()
                        .withDependencies(container)
                    #else
                    StructuredMainView()
                        .withDependencies(container)
                        .environmentObject(deepLinkManager)
                        .onOpenURL { url in
                            deepLinkManager.handle(url)
                        }
                    #endif
                }
            }
            .withErrorHandling()
            .modelContainer(DataPersistence.shared.container)
            .overlay {
                if appLock.isLocked && appLock.isEnabled {
                    AppLockView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: onboardingManager.hasCompletedOnboarding)
            .animation(.easeInOut(duration: 0.3), value: appLock.isLocked)
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    // Сохраняем данные немедленно при уходе в фон — защита от потери данных при force-quit
                    PlannerStore.shared.persistNow()
                    appLock.handleBackground()
                    Logger.shared.info("App moved to background — data persisted")
                case .inactive:
                    // Также сохраняем на inactive (переключение apps, notification center pull-down)
                    PlannerStore.shared.persistNow()
                case .active:
                    // Синхронизация с iCloud при возврате в приложение
                    NSUbiquitousKeyValueStore.default.synchronize()
                    appLock.handleForeground()
                    // Авто-подготовка выдержек для ближайших встреч
                    Task {
                        await MeetingBriefingService.shared.prefetchBriefings()
                    }
                @unknown default:
                    break
                }
            }
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        .commands {
            jarvisCommands
        }
        #endif
    }
    
    // MARK: - macOS Menu Commands
    
    #if os(macOS)
    @CommandsBuilder
    private var jarvisCommands: some Commands {
        CommandGroup(after: .newItem) {
            Button(L10n.addTask) {
                if let url = URL(string: "jarvis://add") { deepLinkManager.handle(url) }
            }
            .keyboardShortcut("n", modifiers: .command)
            
            Divider()
            
            Button(L10n.sectionToday) {
                if let url = URL(string: "jarvis://today") { deepLinkManager.handle(url) }
            }
            .keyboardShortcut("d", modifiers: .command)
            
            Button(L10n.sectionInbox) {
                if let url = URL(string: "jarvis://inbox") { deepLinkManager.handle(url) }
            }
            .keyboardShortcut("i", modifiers: .command)
            
            Button(L10n.sectionAnalytics) {
                if let url = URL(string: "jarvis://analytics") { deepLinkManager.handle(url) }
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])
            
            Button(L10n.sectionNeural) {
                if let url = URL(string: "jarvis://chat") { deepLinkManager.handle(url) }
            }
            .keyboardShortcut("l", modifiers: .command)
            
            Divider()
            
            Button(L10n.sectionCalendar) {
                if let url = URL(string: "jarvis://calendar") { deepLinkManager.handle(url) }
            }
            .keyboardShortcut("k", modifiers: .command)
            
            Button(L10n.sectionMail) {
                if let url = URL(string: "jarvis://mail") { deepLinkManager.handle(url) }
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
        }
        
        CommandGroup(after: .sidebar) {
            Button(L10n.hideSidebar) {
                NotificationCenter.default.post(name: .toggleSidebar, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .control])
        }
    }
    #endif
}

// MARK: - Notification for sidebar toggle

extension Notification.Name {
    static let toggleSidebar = Notification.Name("jarvis.toggleSidebar")
}
