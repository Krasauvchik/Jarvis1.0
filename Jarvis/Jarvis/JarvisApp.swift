import SwiftUI

@main
struct JarvisApp: App {
    @StateObject private var container = DependencyContainer.shared
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    
    init() {
        NSUbiquitousKeyValueStore.default.synchronize()
    }
    
    var body: some Scene {
        WindowGroup {
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
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        #endif
    }
}
