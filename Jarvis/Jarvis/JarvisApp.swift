import SwiftUI
import SwiftData

@main
struct JarvisApp: App {
    @StateObject private var container = DependencyContainer.shared
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    @StateObject private var onboardingManager = OnboardingManager.shared
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Activate crash reporter early
        CrashReporter.shared.activate()
        
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
            .animation(.easeInOut(duration: 0.5), value: onboardingManager.hasCompletedOnboarding)
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    // Сохраняем данные немедленно при уходе в фон — защита от потери данных при force-quit
                    PlannerStore.shared.persistNow()
                    Logger.shared.info("App moved to background — data persisted")
                case .inactive:
                    // Также сохраняем на inactive (переключение apps, notification center pull-down)
                    PlannerStore.shared.persistNow()
                case .active:
                    // Синхронизация с iCloud при возврате в приложение
                    NSUbiquitousKeyValueStore.default.synchronize()
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
            Button("Новая задача") {
                deepLinkManager.handle(URL(string: "jarvis://add")!)
            }
            .keyboardShortcut("n", modifiers: .command)
            
            Divider()
            
            Button("Сегодня") {
                deepLinkManager.handle(URL(string: "jarvis://today")!)
            }
            .keyboardShortcut("d", modifiers: .command)
            
            Button("Входящие") {
                deepLinkManager.handle(URL(string: "jarvis://inbox")!)
            }
            .keyboardShortcut("i", modifiers: .command)
            
            Button("Аналитика") {
                deepLinkManager.handle(URL(string: "jarvis://analytics")!)
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])
            
            Button("AI Чат") {
                deepLinkManager.handle(URL(string: "jarvis://chat")!)
            }
            .keyboardShortcut("l", modifiers: .command)
        }
        
        CommandGroup(after: .sidebar) {
            Button("Переключить боковую панель") {
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
